import SwiftUI

/// Navigation root: the stage, screens pushed from the tarot fan, the show cover and the first-run guide.
struct RootView: View {
    let dependencies: AppDependencies
    let online: PlayerOnlineStore
    @State private var path: [AppRoute] = []
    @State private var show: ShowRequest?
    @State private var pendingShow: RunMode?
    @State private var isShowingFirstGuide = false
    @State private var showTopPlayers = false
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            StageView(
                viewModel: StageViewModel(profileStore: dependencies.profileStore),
                zoom: zoom,
                onOpen: { path.append($0) },
                onPerform: start,
                onTopPlayers: { showTopPlayers = true }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                destination(route)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationTransition(.zoom(sourceID: route, in: zoom))
            }
        }
        .fullScreenCover(item: $show) { request in
            GameView(
                viewModel: GameViewModel(mode: request.mode, profileStore: dependencies.profileStore, settings: dependencies.settings,
                                         haptics: dependencies.haptics, sound: dependencies.sound,
                                         autopilot: dependencies.autopilot, invincible: dependencies.invincible,
                                         onShowFinished: { summary in Task { await online.submitScore(summary) } }),
                onExit: { show = nil }
            )
            .environment(\.calmDecor, dependencies.isUITesting)
        }
        .fullScreenCover(isPresented: $isShowingFirstGuide, onDismiss: startPending) {
            GuideView(isFirstRun: true, onBack: { isShowingFirstGuide = false })
                .environment(\.calmDecor, dependencies.isUITesting)
        }
        .fullScreenCover(isPresented: $showTopPlayers) {
            TopPlayersView(online: online, onClose: { showTopPlayers = false })
        }
        .environment(\.calmDecor, dependencies.isUITesting)
        .preferredColorScheme(.dark)
        .tint(Theme.Colors.saffron)
        .onAppear { dependencies.sound.playMusic(.menu) }
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        let back = { _ = path.popLast() }
        switch route {
        case .wardrobe:
            WardrobeView(viewModel: WardrobeViewModel(profileStore: dependencies.profileStore, haptics: dependencies.haptics, sound: dependencies.sound), onBack: back)
        case .trunk:
            TrunkView(viewModel: TrunkViewModel(profileStore: dependencies.profileStore, haptics: dependencies.haptics, sound: dependencies.sound), onBack: back)
        case .acts:
            ActsView(viewModel: ActsViewModel(profileStore: dependencies.profileStore), onBack: back, onPerform: start)
        case .playbills:
            PlaybillsView(viewModel: PlaybillsViewModel(profileStore: dependencies.profileStore), onBack: back)
        case .tour:
            TourView(viewModel: TourViewModel(profileStore: dependencies.profileStore, haptics: dependencies.haptics, sound: dependencies.sound),
                     onBack: back, onPerform: start)
        case .workshop:
            WorkshopView(viewModel: WorkshopViewModel(profileStore: dependencies.profileStore, haptics: dependencies.haptics, sound: dependencies.sound), onBack: back)
        case .settings:
            SettingsView(viewModel: SettingsViewModel(settings: dependencies.settings, profileStore: dependencies.profileStore, sound: dependencies.sound),
                         onBack: back, onGuide: { path.append(.guide) })
        case .guide:
            GuideView(isFirstRun: false, onBack: back)
        }
    }

    /// Starts a show, showing the guide first on the very first one.
    private func start(_ mode: RunMode) {
        dependencies.sound.play(.tap)
        if !dependencies.settings.hasSeenGuide {
            pendingShow = mode
            isShowingFirstGuide = true
            return
        }
        show = ShowRequest(mode: mode)
    }

    private func startPending() {
        dependencies.settings.hasSeenGuide = true
        guard let mode = pendingShow else { return }
        pendingShow = nil
        show = ShowRequest(mode: mode)
    }
}
