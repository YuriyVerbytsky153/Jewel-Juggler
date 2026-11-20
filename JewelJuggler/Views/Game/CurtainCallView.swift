import SwiftUI

/// The Curtain Call: velvet curtains close, roses land and the evening's programme lists the tally.
struct CurtainCallView: View {
    let outcome: ShowOutcome
    let viewModel: GameViewModel
    let onLeave: () -> Void
    @State private var curtainsClosed = false
    @State private var showProgramme = false
    @State private var rosesLanded = 0
    @Environment(\.calmDecor) private var calm

    private var summary: RunSummary { outcome.summary }

    var body: some View {
        ZStack {
            CurtainPair(closed: curtainsClosed)
            if showProgramme {
                VStack(spacing: 0) {
                    ScrollView {
                        programme
                            .padding(.horizontal, 18)
                            .padding(.top, 24)
                            .padding(.bottom, 12)
                            .frame(maxWidth: 460)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    // The choices stay pinned under the programme so they never scroll off a short screen.
                    actions
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                        .frame(maxWidth: 460)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Curtain.screen)
        .task {
            withAnimation(.easeInOut(duration: calm ? 0.1 : 0.7)) { curtainsClosed = true }
            try? await Task.sleep(for: .milliseconds(calm ? 100 : 550))
            withAnimation(.spring(duration: 0.5)) { showProgramme = true }
            for index in 0..<max(summary.roses, 0) {
                try? await Task.sleep(for: .milliseconds(calm ? 20 : 260))
                withAnimation(.spring(duration: 0.4, bounce: 0.5)) { rosesLanded = index + 1 }
            }
        }
    }

    private var headline: String {
        switch summary.result {
        case .goalComplete:
            if case .won = outcome.tour { "Long live the Jester!" } else { "Bravo!" }
        case .bellsOut: "The bells fell silent"
        case .abandoned: "Curtain"
        }
    }

    private var programme: some View {
        VStack(spacing: 14) {
            Text(viewModel.title)
                .font(.court(.caption, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Theme.Colors.inkSoft)
                .multilineTextAlignment(.center)
            Text(headline)
                .font(.engraved(32, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)

            if summary.mode.actIndex != nil {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(index < rosesLanded ? Art.rose : Art.roseEmpty)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 46, height: 46)
                            .scaleEffect(index < rosesLanded ? 1 : 0.8)
                            .rotationEffect(.degrees(index < rosesLanded ? Double(index - 1) * 12 : 0))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(summary.roses) of 3 roses")
                if summary.result == .goalComplete {
                    Text(summary.roses == 3 ? "Flawless: not a single bell lost." : summary.roses == 2 ? "Keep every bell for the third rose." : "Lose at most one bell for a second rose.")
                        .font(.court(.footnote, weight: .medium))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 4) {
                Text(Formatters.integer(summary.score))
                    .font(.engraved(44, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.Colors.ink)
                    .monospacedDigit()
                    .accessibilityLabel("Score \(summary.score)")
                    .accessibilityIdentifier(AccessibilityID.Curtain.score)
                if outcome.isNewBest {
                    tag("New best performance!", color: Theme.Colors.rose)
                } else if outcome.isNewFestivalBest {
                    tag("Tonight's best!", color: Theme.Colors.teal)
                }
            }

            VStack(spacing: 0) {
                line("Gems banked", Formatters.integer(summary.banks), art: Art.chestOpen)
                line("Crowns fused", Formatters.integer(summary.crowns), art: Art.crown(.ruby))
                line("Encores", Formatters.integer(summary.encores), art: Art.rosetteEarned)
                line("Decrees weathered", Formatters.integer(summary.decrees), art: Art.decree(.candleGust))
                line("Most gems aloft", Formatters.integer(summary.maxAirborne), art: Art.gem(.sapphire))
                line("Show length", Formatters.duration(summary.seconds), art: Art.cap)
            }
            .padding(.vertical, 4)
            .overlay(alignment: .top) { Divider().overlay(Theme.Colors.gold) }
            .overlay(alignment: .bottom) { Divider().overlay(Theme.Colors.gold) }

            HStack(spacing: 10) {
                Image(Art.ducat)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("+\(Formatters.integer(outcome.ducatsEarned)) ducats")
                        .font(.engraved(20, relativeTo: .title3))
                        .foregroundStyle(Theme.Colors.ink)
                    if outcome.roseBonus > 0 {
                        Text("Includes \(outcome.roseBonus) for new roses")
                            .font(.court(.caption, weight: .medium))
                            .foregroundStyle(Theme.Colors.inkSoft)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Purse \(Formatters.integer(outcome.totalDucats))")
                        .font(.court(.footnote, weight: .bold))
                        .foregroundStyle(Theme.Colors.inkSoft)
                    if outcome.shardsEarned > 0 {
                        Text("+\(Formatters.integer(outcome.shardsEarned)) shards")
                            .font(.court(.caption, weight: .bold))
                            .foregroundStyle(Theme.Colors.velvetLight)
                            .accessibilityIdentifier(AccessibilityID.Curtain.shards)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.Curtain.ducats)

            if let report = outcome.tour {
                Text(tourText(report))
                    .font(.court(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Colors.ink.opacity(0.06)))
                    .accessibilityIdentifier(AccessibilityID.Curtain.tour)
            }

            if !outcome.newAchievements.isEmpty {
                VStack(spacing: 4) {
                    Text("New rosettes")
                        .font(.court(.caption, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.inkSoft)
                    ForEach(outcome.newAchievements, id: \.self) { title in
                        HStack(spacing: 6) {
                            Image(Art.rosetteEarned).resizable().scaledToFit().frame(width: 26, height: 26)
                            Text(title).font(.court(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.ink)
                        }
                    }
                }
            }

        }
        .parchmentPanel(padding: 24)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if viewModel.isTour {
                Button(isTourOver ? "Back to the map" : "Choose a tarot card", action: onLeave)
                    .buttonStyle(CourtButtonStyle(kind: .gold, size: 20, minHeight: 54))
                    .accessibilityIdentifier(AccessibilityID.Curtain.map)
            } else {
                if summary.result == .goalComplete, let next = viewModel.nextAct {
                    Button("Next: \(next.name)") { viewModel.restart(mode: .act(next.index)) }
                        .buttonStyle(CourtButtonStyle(kind: .gold, size: 20, minHeight: 54))
                        .accessibilityIdentifier(AccessibilityID.Curtain.next)
                }
                HStack(spacing: 10) {
                    Button("Perform again") { viewModel.restart() }
                        .buttonStyle(CourtButtonStyle(kind: summary.result == .goalComplete && viewModel.nextAct != nil ? .teal : .gold, size: 17, minHeight: 50))
                        .accessibilityIdentifier(AccessibilityID.Curtain.again)
                    Button("Leave", action: onLeave)
                        .buttonStyle(CourtButtonStyle(kind: .plum, size: 17, minHeight: 50))
                        .accessibilityLabel("Leave the stage")
                        .accessibilityIdentifier(AccessibilityID.Curtain.leave)
                }
            }
        }
    }

    /// True when there is no card to choose: the tour was won or lost.
    private var isTourOver: Bool {
        if case .cleared = outcome.tour { return false }
        return true
    }

    private func tourText(_ report: TourReport) -> String {
        switch report {
        case .cleared: "Stop cleared! Your bells travel on with you. The Fates deal three tarot cards on the map."
        case .won(_, let ducats): "The King's Banquet is won! The court pays \(ducats) ducats and the tour is complete."
        case .lost(let depth): depth == 0 ? "The Royal Tour ends before the first stop." : "The Royal Tour ends after \(depth) \(depth == 1 ? "stop" : "stops")."
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.court(.caption, weight: .bold))
            .foregroundStyle(Theme.Colors.ivory)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(color))
    }

    private func line(_ title: String, _ value: String, art: String) -> some View {
        HStack(spacing: 10) {
            Image(art)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
            Text(title)
                .font(.court(.subheadline, weight: .medium))
            Spacer(minLength: 8)
            Text(value)
                .font(.engraved(17, relativeTo: .headline))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.Colors.ink)
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

/// Two velvet curtains with gilded fringe that slide together.
struct CurtainPair: View {
    let closed: Bool

    var body: some View {
        GeometryReader { proxy in
            let half = proxy.size.width / 2 + 2
            HStack(spacing: 0) {
                curtain(width: half)
                    .offset(x: closed ? 0 : -half)
                curtain(width: half)
                    .scaleEffect(x: -1)
                    .offset(x: closed ? 0 : half)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func curtain(width: CGFloat) -> some View {
        Image(Art.Tile.velvet)
            .resizable(resizingMode: .tile)
            .overlay {
                // Folds: darker bands every few points.
                LinearGradient(stops: (0..<8).flatMap { i -> [Gradient.Stop] in
                    let start = Double(i) / 8
                    return [.init(color: .black.opacity(0.35), location: start),
                            .init(color: .clear, location: start + 0.06),
                            .init(color: .black.opacity(0.18), location: start + 0.12)]
                }, startPoint: .leading, endPoint: .trailing)
            }
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(LinearGradient(colors: [Theme.Colors.goldDeep, Theme.Colors.saffron, Theme.Colors.goldDeep], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 10)
            }
            .frame(width: width)
    }
}
