import SwiftUI

/// The Royal Tour: a road map of stops from the village green to the King's Banquet.
/// Bells carry from stop to stop and every cleared show deals a tarot card that bends the rules.
struct TourView: View {
    @State private var viewModel: TourViewModel
    let onBack: () -> Void
    let onPerform: (RunMode) -> Void
    @State private var pulse = false
    @Environment(\.calmDecor) private var calm

    private let rowHeight: CGFloat = 96

    init(viewModel: TourViewModel, onBack: @escaping () -> Void, onPerform: @escaping (RunMode) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onBack = onBack
        self.onPerform = onPerform
    }

    var body: some View {
        VStack(spacing: 0) {
            CourtHeader(title: "Royal Tour", onBack: onBack)
            statusBar
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .frame(maxWidth: 560)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 14) {
                        if let tour = viewModel.tour {
                            if tour.status != .active {
                                resultPanel(tour)
                            }
                            map(tour)
                                .id("map")
                            if tour.isActive {
                                Button("Retire from the tour") { viewModel.isConfirmingRetire = true }
                                    .buttonStyle(CourtButtonStyle(kind: .plum, size: 16, minHeight: 46))
                                    .accessibilityIdentifier(AccessibilityID.Tour.retire)
                            }
                        } else {
                            introPanel
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .defaultScrollAnchor(.bottom)
                .onAppear { reader.scrollTo("map", anchor: .bottom) }
            }
        }
        .overlay {
            // The Fates' deal sits over the map so it is never scrolled out of sight.
            if let offer = viewModel.tour?.offer, !offer.isEmpty {
                ZStack {
                    Theme.Colors.velvetDeep.opacity(0.78)
                        .ignoresSafeArea()
                    ScrollView {
                        offerPanel(offer)
                            .frame(maxWidth: 480)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .defaultScrollAnchor(.center)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let stop = viewModel.selected {
                stopDetails(stop)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: viewModel.selected)
        .animation(.spring(duration: 0.35), value: viewModel.tour)
        .tiled(Art.Tile.velvet)
        .toast($viewModel.toast)
        .confirmationDialog("Retire from the Royal Tour?", isPresented: $viewModel.isConfirmingRetire, titleVisibility: .visible) {
            Button("Retire", role: .destructive) { viewModel.retire() }
        } message: {
            Text("The map, your bells and your tarot cards are lost. Shards already earned are kept.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Tour.screen)
        .onAppear {
            guard !calm else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    // MARK: - Status

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let tour = viewModel.tour, tour.isActive {
                BellCap(bells: tour.bells, maxBells: viewModel.maxBells, hasGrace: tour.modifiers.grace, shake: 0)
                    .accessibilityIdentifier(AccessibilityID.Tour.bells)
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(tour.cards) { card in
                            TarotChip(card: card, size: 22)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                Spacer(minLength: 0)
            }
            ShardBadge(amount: viewModel.shards, compact: true)
        }
    }

    // MARK: - Intro and result

    private var introPanel: some View {
        VStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.Colors.rose)
                .accessibilityHidden(true)
            Text("The Royal Tour")
                .font(.engraved(24, relativeTo: .title2))
                .foregroundStyle(Theme.Colors.ink)
            VStack(alignment: .leading, spacing: 8) {
                rule("theatermasks.fill", "Travel the road from stop to stop. Each show has its own goal.")
                rule("bell.fill", "Your bells carry over. Lose them all and the tour is over.")
                rule("suit.spade.fill", "Clear a show and pick one of three tarot cards. Each one changes the rules for the rest of the tour.")
                rule("mug.fill", "Rest at a tavern to restore bells. Tournaments are harder but always deal a rare card.")
                rule("crown.fill", "Win the King's Banquet for \(TourRules.banquetDucats) ducats and \(TourRules.banquetShards) shards.")
            }
            if viewModel.toursWon > 0 || viewModel.bestDepth > 0 {
                Text("Tours won: \(viewModel.toursWon) · Furthest stop: \(viewModel.bestDepth) of \(TourRules.rows)")
                    .font(.court(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
            Button("Set out on tour") { viewModel.start() }
                .buttonStyle(CourtButtonStyle(kind: .gold, size: 22, minHeight: 58))
                .accessibilityIdentifier(AccessibilityID.Tour.start)
        }
        .parchmentPanel(padding: 24)
    }

    private func rule(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.Colors.rose)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.court(.subheadline, weight: .medium))
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resultPanel(_ tour: TourState) -> some View {
        let won = tour.status == .won
        return VStack(spacing: 10) {
            Text(won ? "The Grand Tour is complete!" : "The tour has ended")
                .font(.engraved(22, relativeTo: .title2))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
            Text(won ? "The king himself applauded. Your name is sung in every tavern on the road."
                     : "The bells fell silent after \(tour.depth) \(tour.depth == 1 ? "stop" : "stops"). The road will be different next time.")
                .font(.court(.subheadline, weight: .medium))
                .foregroundStyle(Theme.Colors.inkSoft)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                RewardLine(icon: Image(Art.ducat), text: Formatters.integer(tour.ducatsEarned))
                RewardLine(icon: Image(systemName: "rhombus.fill"), text: Formatters.integer(tour.shardsEarned))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Earned on tour: \(tour.ducatsEarned) ducats and \(tour.shardsEarned) shards")
            Button("Set out again") { viewModel.start() }
                .buttonStyle(CourtButtonStyle(kind: .gold, size: 20))
                .accessibilityIdentifier(AccessibilityID.Tour.start)
        }
        .parchmentPanel(padding: 22)
    }

    // MARK: - Tarot offer

    private func offerPanel(_ offer: [TourCard]) -> some View {
        VStack(spacing: 10) {
            Text("The Fates deal three cards")
                .font(.engraved(20, relativeTo: .title3))
                .foregroundStyle(Theme.Colors.ink)
            Text("Take one. It stays in your hand until the tour ends.")
                .font(.court(.footnote, weight: .medium))
                .foregroundStyle(Theme.Colors.inkSoft)
            ForEach(offer) { card in
                Button {
                    viewModel.choose(card)
                } label: {
                    TarotOfferRow(card: card)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.Tour.offer(card))
            }
        }
        .parchmentPanel(padding: 20)
    }

    // MARK: - Map

    private func map(_ tour: TourState) -> some View {
        let height = rowHeight * CGFloat(tour.rows.count)
        return GeometryReader { proxy in
            let width = proxy.size.width
            let center: (TourStop) -> CGPoint = { stop in
                CGPoint(x: width * stop.position, y: height - rowHeight * (CGFloat(stop.row) + 0.5))
            }
            ZStack {
                Canvas { context, _ in
                    for stop in tour.rows.joined() {
                        for next in tour.roads(from: stop) {
                            var path = Path()
                            path.move(to: center(stop))
                            path.addLine(to: center(next))
                            let travelled = tour.isCleared(stop) && tour.isCleared(next)
                            let open = tour.current == stop && tour.isReachable(next)
                            let color = travelled ? Theme.Colors.saffron : open ? Theme.Colors.ivory.opacity(0.85) : Theme.Colors.gold.opacity(0.3)
                            context.stroke(path, with: .color(color),
                                           style: StrokeStyle(lineWidth: travelled ? 4 : 2, lineCap: .round, dash: travelled ? [] : [5, 7]))
                        }
                    }
                }
                ForEach(Array(tour.rows.joined())) { stop in
                    stopButton(stop, in: tour)
                        .position(center(stop))
                }
                if tour.current == nil, tour.isActive {
                    // The jester waits at the edge of the map before the first stop.
                    jesterMarker
                        .position(x: width / 2, y: height + 4)
                }
            }
        }
        .frame(height: height)
        .padding(.top, 8)
        .padding(.bottom, tour.current == nil ? 34 : 8)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.Colors.velvetDeep.opacity(0.55)))
        .accessibilityElement(children: .contain)
    }

    private var jesterMarker: some View {
        Image(Art.jester(viewModel.costume))
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 40)
            .shadow(color: Theme.Colors.candle.opacity(0.6), radius: 6)
            .accessibilityHidden(true)
    }

    private func stopButton(_ stop: TourStop, in tour: TourState) -> some View {
        let reachable = tour.isReachable(stop)
        let cleared = tour.isCleared(stop)
        let isCurrent = tour.current == stop
        let isSelected = viewModel.selected == stop
        let bypassed = !cleared && stop.row < tour.depth
        let size: CGFloat = stop.kind == .banquet ? 58 : 46
        return Button {
            viewModel.select(stop)
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(cleared ? Theme.Colors.tealDeep : stop.kind == .banquet ? Theme.Colors.rose.opacity(0.85) : Theme.Colors.velvet)
                    Circle()
                        .strokeBorder(reachable ? Theme.Colors.saffron : Theme.Colors.gold.opacity(0.6), lineWidth: isSelected ? 4 : 2)
                    Image(systemName: stop.kind.symbol)
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(reachable ? Theme.Colors.saffron : Theme.Colors.ivory)
                }
                .frame(width: size, height: size)
                .shadow(color: reachable ? Theme.Colors.saffron.opacity(pulse ? 0.9 : 0.35) : .clear, radius: pulse ? 12 : 5)
                .overlay(alignment: .topTrailing) {
                    if isCurrent {
                        jesterMarker
                            .offset(x: 16, y: -14)
                    } else if cleared {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Colors.ivory, Theme.Colors.teal)
                            .offset(x: 4, y: -4)
                    }
                }
                Text(stop.name)
                    .font(.court(.caption2, weight: .bold))
                    .foregroundStyle(Theme.Colors.ivory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: 110)
            }
            .opacity(bypassed ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(stop.kind.title): \(stop.name)")
        .accessibilityValue(cleared ? "Cleared" : reachable ? "Open" : "Closed")
        .accessibilityIdentifier(AccessibilityID.Tour.stop(stop.id))
    }

    // MARK: - Stop details

    private func stopDetails(_ stop: TourStop) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: stop.kind.symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Colors.rose)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(stop.kind.title)
                        .font(.court(.caption, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.inkSoft)
                    Text(stop.name)
                        .font(.engraved(19, relativeTo: .headline))
                        .foregroundStyle(Theme.Colors.ink)
                }
                Spacer(minLength: 0)
                Button {
                    viewModel.selected = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            if let goal = stop.goal {
                VStack(alignment: .leading, spacing: 4) {
                    RewardLine(icon: Image(Art.rose), text: goal.text, size: 15)
                    HStack(spacing: 6) {
                        Text("Up to \(stop.maxGems) gems")
                        ForEach(stop.decrees, id: \.self) { decree in
                            Image(Art.decree(decree)).resizable().scaledToFit().frame(width: 20, height: 20)
                        }
                        if stop.jokers {
                            Image(Art.joker).resizable().scaledToFit().frame(width: 18, height: 18)
                        }
                    }
                    .font(.court(.footnote, weight: .medium))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    Text(rewardText(stop))
                        .font(.court(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.Colors.rose)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Rest by the fire: restore up to \(TourRules.tavernBells) bells. No show tonight.")
                    .font(.court(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.Colors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(stop.kind.isPerformance ? "Perform here" : "Rest here") {
                if let mode = viewModel.travel() { onPerform(mode) }
            }
            .buttonStyle(CourtButtonStyle(kind: .gold, size: 20, minHeight: 54))
            .accessibilityIdentifier(AccessibilityID.Tour.perform)
        }
        .parchmentPanel(padding: 20)
        .frame(maxWidth: 520)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private func rewardText(_ stop: TourStop) -> String {
        switch stop.kind {
        case .show: "Clear it: +\(TourRules.showShards) shards and a tarot card"
        case .tournament: "Clear it: +\(TourRules.tournamentShards) shards and a rare tarot card"
        case .banquet: "Win it: +\(TourRules.banquetDucats) ducats, +\(TourRules.banquetShards) shards"
        case .tavern: ""
        }
    }
}

/// One offered tarot card: the face on the left, the rule it changes on the right.
struct TarotOfferRow: View {
    let card: TourCard

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(card.numeral)
                    .font(.engraved(12, relativeTo: .caption))
                    .foregroundStyle(Theme.Colors.saffron)
                Image(systemName: card.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.Colors.saffron)
            }
            .frame(width: 54, height: 76)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.Colors.velvet))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(card.isRare ? Theme.Colors.rose : Theme.Colors.gold, lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(card.title)
                        .font(.engraved(16, relativeTo: .headline))
                        .foregroundStyle(Theme.Colors.ink)
                    if card.isRare {
                        Text("Rare")
                            .font(.court(.caption2, weight: .bold))
                            .foregroundStyle(Theme.Colors.ivory)
                            .padding(.horizontal, 6)
                            .background(Capsule().fill(Theme.Colors.rose))
                    }
                }
                Text(card.effect)
                    .font(.court(.footnote, weight: .medium))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Colors.ink.opacity(0.06)))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.title)\(card.isRare ? ", rare" : ""). \(card.effect)")
        .accessibilityAddTraits(.isButton)
    }
}

/// An icon and an engraved value, for reward lines on parchment.
struct RewardLine: View {
    let icon: Image
    let text: String
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 6) {
            icon
                .resizable()
                .scaledToFit()
                .frame(width: size + 6, height: size + 6)
                .foregroundStyle(Theme.Colors.gem(.amethyst))
            Text(text)
                .font(.engraved(size, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
