import SwiftUI

/// Home: the court stage with the jester in the spotlight, the big curtain button and a fan of tarot cards.
struct StageView: View {
    @State private var viewModel: StageViewModel
    let zoom: Namespace.ID
    let onOpen: (AppRoute) -> Void
    let onPerform: (RunMode) -> Void
    let onTopPlayers: () -> Void
    @State private var liftedCard: AppRoute?
    @State private var bob = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.calmDecor) private var calm

    init(viewModel: StageViewModel, zoom: Namespace.ID, onOpen: @escaping (AppRoute) -> Void,
         onPerform: @escaping (RunMode) -> Void, onTopPlayers: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.zoom = zoom
        self.onOpen = onOpen
        self.onPerform = onPerform
        self.onTopPlayers = onTopPlayers
    }

    var body: some View {
        GeometryReader { proxy in
            let wide = sizeClass == .regular && proxy.size.width > proxy.size.height
            VStack(spacing: 0) {
                topBar
                if wide {
                    HStack(alignment: .center, spacing: 32) {
                        VStack(spacing: 10) {
                            logo
                            spotlightJester
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: 18) {
                            Spacer(minLength: 0)
                            performButtons
                            tarotFan(cardWidth: 100)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: 460)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                } else {
                    VStack(spacing: 10) {
                        logo
                        spotlightJester
                        performButtons
                            .frame(maxWidth: 420)
                        tarotFan(cardWidth: min(90, (proxy.size.width - 40) / 4.9))
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .fullBleed(Art.stageBackdrop, alignment: .bottom)
        .overlay { CandleMotes().ignoresSafeArea() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Stage.screen)
        .onAppear {
            liftedCard = nil
            guard !calm else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true }
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack(spacing: 6) {
            MedallionButton(image: Art.Medallion.settings, label: "Settings", size: 44) { onOpen(.settings) }
                .matchedTransitionSource(id: AppRoute.settings, in: zoom)
                .accessibilityIdentifier(AccessibilityID.Stage.settings)
            MedallionButton(image: Art.Medallion.help, label: "How to play", size: 44) { onOpen(.guide) }
                .matchedTransitionSource(id: AppRoute.guide, in: zoom)
                .accessibilityIdentifier(AccessibilityID.Stage.guide)
            topPlayersButton
            Spacer()
            DucatBadge(amount: viewModel.ducats)
                .accessibilityIdentifier(AccessibilityID.Stage.ducats)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }

    /// Brass-style medallion opening the online Top Players board.
    private var topPlayersButton: some View {
        Button(action: onTopPlayers) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.Colors.saffron)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.Colors.velvetDeep.opacity(0.88)))
                .overlay(Circle().strokeBorder(Theme.Colors.gold.opacity(0.85), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .frame(minWidth: Theme.Metrics.minTarget, minHeight: Theme.Metrics.minTarget)
        .contentShape(Circle())
        .accessibilityLabel("Top Players")
        .accessibilityIdentifier("stage.topPlayers")
    }

    private var logo: some View {
        Image(Art.logo)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 340, maxHeight: 120)
            .accessibilityLabel("Jewel Juggler")
            .accessibilityAddTraits(.isHeader)
    }

    private var spotlightJester: some View {
        VStack(spacing: 6) {
            Image(Art.jester(viewModel.costume, frame: bob ? 1 : 0))
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .offset(y: bob ? -4 : 2)
                .shadow(color: Theme.Colors.candle.opacity(0.35), radius: 24)
                .layoutPriority(-1)
                .accessibilityHidden(true)
            VStack(spacing: 1) {
                Text(viewModel.costume.name)
                    .font(.engraved(17, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.ink)
                Text(viewModel.bestScore > 0 ? "Best performance \(Formatters.integer(viewModel.bestScore))" : "Your first show awaits")
                    .font(.court(.caption, weight: .semibold))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .accessibilityIdentifier(AccessibilityID.Stage.best)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 6)
            .background {
                Image(Art.Panel.scroll)
                    .resizable(capInsets: PanelInsets.scroll, resizingMode: .stretch)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var performButtons: some View {
        VStack(spacing: 10) {
            Button {
                onPerform(.endless)
            } label: {
                VStack(spacing: 0) {
                    Text("Raise the Curtain")
                    Text("Royal Performance")
                        .font(.court(.caption, weight: .bold))
                        .opacity(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CourtButtonStyle(kind: .gold, size: 24, minHeight: 66))
            .accessibilityIdentifier(AccessibilityID.Stage.raiseCurtain)

            HStack(spacing: 10) {
                Button {
                    onPerform(viewModel.festivalMode)
                } label: {
                    VStack(spacing: 0) {
                        Text("Festival")
                        Text(viewModel.festivalBest > 0 ? "Best \(Formatters.integer(viewModel.festivalBest))" : "Ducats ×1.5")
                            .font(.court(.caption, weight: .bold))
                            .opacity(0.85)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CourtButtonStyle(kind: .teal, size: 18, minHeight: 56))
                .accessibilityIdentifier(AccessibilityID.Stage.festival)

                Button {
                    open(.tour)
                } label: {
                    VStack(spacing: 0) {
                        Text("Royal Tour")
                        Text(viewModel.tourNote)
                            .font(.court(.caption, weight: .bold))
                            .opacity(0.85)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CourtButtonStyle(kind: .plum, size: 18, minHeight: 56))
                .matchedTransitionSource(id: AppRoute.tour, in: zoom)
                .accessibilityIdentifier(AccessibilityID.Stage.tour)
            }
        }
    }

    private struct CardSpec: Identifiable {
        let route: AppRoute
        let art: String
        let note: String
        /// Drawn on the card back for screens without their own illustration.
        var symbol: String?
        var id: AppRoute { route }
    }

    private var cards: [CardSpec] {
        [
            CardSpec(route: .wardrobe, art: Art.Card.wardrobe, note: "Costumes"),
            CardSpec(route: .trunk, art: Art.Card.trunk, note: "Props"),
            CardSpec(route: .acts, art: Art.Card.acts, note: "\(viewModel.totalRoses) roses"),
            CardSpec(route: .workshop, art: Art.Card.back, note: "\(viewModel.shards) shards", symbol: "hammer.fill"),
            CardSpec(route: .playbills, art: Art.Card.playbills, note: "Records"),
        ]
    }

    private func tarotFan(cardWidth: CGFloat) -> some View {
        HStack(spacing: -cardWidth * 0.08) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let angle = (Double(index) - Double(cards.count - 1) / 2) * 7
                let isLifted = liftedCard == card.route
                Button {
                    open(card.route)
                } label: {
                    TarotCard(art: card.art, title: card.route.title, note: card.note, width: cardWidth, symbol: card.symbol)
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: card.route, in: zoom)
                .rotation3DEffect(.degrees(isLifted ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .rotationEffect(.degrees(isLifted ? 0 : angle), anchor: .bottom)
                .offset(y: isLifted ? -24 : abs(angle) * 0.9)
                .zIndex(isLifted ? 10 : Double(index))
                .accessibilityLabel(card.route.title)
                .accessibilityHint(card.note)
                .accessibilityIdentifier(AccessibilityID.Stage.card(card.route.rawValue))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func open(_ route: AppRoute) {
        guard liftedCard == nil else { return }
        if calm {
            onOpen(route)
            return
        }
        withAnimation(.easeIn(duration: 0.22)) { liftedCard = route }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            onOpen(route)
            try? await Task.sleep(for: .milliseconds(500))
            liftedCard = nil
        }
    }
}

/// A gilded tarot card with an illustrated face and a parchment name plate.
struct TarotCard: View {
    let art: String
    let title: String
    let note: String
    let width: CGFloat
    var symbol: String?

    var body: some View {
        Image(art)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: width * 1.6)
            .overlay {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: width * 0.34, weight: .bold))
                        .foregroundStyle(Theme.Colors.saffron)
                        .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
                        .offset(y: -width * 0.22)
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    Text(title)
                        .font(.engraved(max(11, width * 0.135), relativeTo: .caption))
                        .foregroundStyle(Theme.Colors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(note)
                        .font(.court(.caption2, weight: .semibold))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, width * 0.1)
                .padding(.bottom, width * 0.12)
            }
            .shadow(color: .black.opacity(0.45), radius: 6, y: 4)
            .contentShape(Rectangle())
    }
}
