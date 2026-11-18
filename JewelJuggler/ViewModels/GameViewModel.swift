import Foundation
import Observation

/// Snapshot of the show for the SwiftUI HUD (refreshed about ten times a second).
struct ShowHUD: Equatable {
    var score = 0
    var ducats = 0
    var bells = 3
    var maxBells = 3
    var applause = 0.0
    var isEncore = false
    var encoreFraction = 0.0
    var decree: DecreeState = .none
    var chordColor: GemColor?
    var chordCount = 0
    var jingleFraction = 0.0
    var isJingleReady = false
    var isJingling = false
    var bankArmed = false
    var airborne = 0
    var goalProgress: Int?
    var hasGrace = false

    init() {}

    init(session s: RunSession) {
        score = s.score
        ducats = s.ducats
        bells = s.bells
        maxBells = s.maxBells
        applause = s.applause
        isEncore = s.isEncore
        encoreFraction = s.encoreFraction
        decree = s.decree
        chordColor = s.chordColor
        chordCount = s.chordCount
        jingleFraction = s.jingleFraction
        isJingleReady = s.isJingleReady
        isJingling = s.isJingling
        bankArmed = s.bankArmed
        airborne = s.airborne
        goalProgress = s.goalProgress
        hasGrace = s.hasGrace && !s.graceUsed
    }
}

/// Drives one show: playbill, drum-roll countdown, the act itself, pause and the Curtain Call.
@MainActor
@Observable
final class GameViewModel {
    enum Phase: Equatable {
        case ready
        case countdown(Int)
        case running
        case paused
        /// The last gem is falling before the curtain closes.
        case ending
        case finished(ShowOutcome)
    }

    /// A short callout over the stage.
    struct Callout: Equatable, Identifiable {
        enum Style { case gold, teal, rose }
        let id = UUID()
        let title: String
        let detail: String?
        let style: Style
    }

    private(set) var phase: Phase = .ready
    private(set) var hud = ShowHUD()
    private(set) var mode: RunMode
    private(set) var scene: JugglerScene?
    private(set) var sceneID = UUID()
    private(set) var callout: Callout?
    /// Bumps on every lost bell to shake the cap.
    private(set) var bellShake = 0
    private(set) var startError: String?

    private let profileStore: ProfileStore
    let settings: SettingsStore
    private let haptics: HapticsService
    private let sound: SoundService
    let autopilot: Bool
    private let invincible: Bool
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var calloutTask: Task<Void, Never>?
    @ObservationIgnored private var endingTask: Task<Void, Never>?
    @ObservationIgnored private var hudClock = 0.0

    init(mode: RunMode, profileStore: ProfileStore, settings: SettingsStore, haptics: HapticsService, sound: SoundService,
         autopilot: Bool = false, invincible: Bool = false) {
        self.mode = mode
        self.profileStore = profileStore
        self.settings = settings
        self.haptics = haptics
        self.sound = sound
        self.autopilot = autopilot
        self.invincible = invincible
    }

    var act: Act? { mode.actIndex.flatMap(ActCatalog.act) }
    var title: String { mode.title }
    var costume: Costume { profileStore.profile.selectedCostume }
    var bestScore: Int { profileStore.profile.bestScore }
    var goal: ActGoal? { mode.goal }
    var tourStop: TourStop? { mode.tourStop }
    var isTour: Bool { tourStop != nil }
    /// Tarot cards carried into this tour stop.
    var tourCards: [TourCard] { isTour ? profileStore.tour?.cards ?? [] : [] }
    var tourBells: Int { profileStore.tour?.bells ?? 0 }
    var tourMaxBells: Int { profileStore.tourMaxBells }
    var enchantments: [Enchantment] { profileStore.profile.equippedEnchantments }
    var isRunning: Bool { phase == .running }
    var previousRoses: Int { act.map { profileStore.profile.roses(forAct: $0.index) } ?? 0 }
    var festivalBest: Int { profileStore.festivalBestToday }

    /// The act after this one, if it is open after this show.
    var nextAct: Act? {
        guard let act, let next = ActCatalog.act(act.index + 1), profileStore.profile.isActUnlocked(next.index) else { return nil }
        return next
    }

    var subtitle: String {
        switch mode {
        case .endless: "Keep the gems aloft as long as the bells last. Bank them for ducats."
        case .festival: "Tonight's seeded show. Every juggler gets the same gems. Ducats ×1.5."
        case .act: goal?.text ?? ""
        case .tour(let stop): "\(stop.kind.title) · \(goal?.text ?? ""). Bells carry over to the next stop."
        }
    }

    // MARK: - Scene

    func prepareScene() {
        guard scene == nil else { return }
        installScene()
    }

    private func installScene() {
        scene?.showDelegate = nil
        do {
            let setup = try profileStore.setup(for: mode, seed: AppDependencies.randomSeed())
            var session = RunSession(setup: setup)
            session.isInvincible = invincible
            let newScene = JugglerScene(session: session)
            newScene.showDelegate = self
            newScene.autopilot = autopilot
            scene = newScene
            sceneID = UUID()
            hud = ShowHUD(session: session)
            startError = nil
        } catch {
            startError = error.localizedDescription
        }
    }

    // MARK: - Flow

    func begin() {
        guard phase == .ready else { return }
        prepareScene()
        guard scene != nil else { return }
        sound.playMusic(.run)
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            for value in [3, 2, 1] {
                guard let self, !Task.isCancelled else { return }
                self.phase = .countdown(value)
                self.sound.play(.count)
                self.haptics.impact(.light)
                try? await Task.sleep(for: .milliseconds(autopilot ? 350 : 700))
            }
            guard let self, !Task.isCancelled else { return }
            self.phase = .running
            self.sound.play(.go)
            self.haptics.impact(.medium)
            self.scene?.isRunning = true
        }
    }

    func pause() {
        guard phase == .running || phase.isCountdown else { return }
        countdownTask?.cancel()
        scene?.isRunning = false
        phase = .paused
        sound.pauseMusic()
    }

    func resume() {
        guard phase == .paused else { return }
        sound.resumeMusic()
        phase = .ready
        begin()
    }

    /// Ends the show from the pause menu. Banked ducats are kept.
    func leave() {
        countdownTask?.cancel()
        endingTask?.cancel()
        if let scene, !scene.session.isOver, scene.session.elapsed > 1 {
            scene.abandon()
            profileStore.record(scene.session.summary)
        }
        scene?.isRunning = false
        sound.stopMusic()
        sound.playMusic(.menu)
    }

    /// Starts a fresh show of the same mode, or of another act.
    func restart(mode newMode: RunMode? = nil) {
        // A tour stop is played once: replaying it would undo a lost show.
        guard newMode != nil || !isTour else { return }
        countdownTask?.cancel()
        endingTask?.cancel()
        if case .paused = phase, let scene, scene.session.elapsed > 1, !scene.session.isOver {
            scene.abandon()
            profileStore.record(scene.session.summary)
        }
        if let newMode { mode = newMode }
        scene?.isRunning = false
        scene = nil
        callout = nil
        phase = .ready
        installScene()
        begin()
    }

    // MARK: - Input

    func bankTapped() {
        // The chest can be armed during the countdown too, ready for the first catch.
        guard isRunning || phase.isCountdown, let scene else { return }
        scene.toggleBank()
        haptics.selection()
        refreshHUD()
    }

    func jingleTapped() {
        guard isRunning, let scene else { return }
        if scene.activateJingle() {
            haptics.impact(.heavy)
            sound.play(.jingle)
            show(Callout(title: "Jingle!", detail: "The court holds its breath", style: .teal))
        } else {
            haptics.notify(.warning)
        }
        refreshHUD()
    }

    // MARK: - Helpers

    private func refreshHUD() {
        guard let scene else { return }
        hud = ShowHUD(session: scene.session)
    }

    private func show(_ newCallout: Callout) {
        callout = newCallout
        calloutTask?.cancel()
        calloutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard let self, !Task.isCancelled else { return }
            if self.callout?.id == newCallout.id { self.callout = nil }
        }
    }

    private func finish(_ session: RunSession) {
        guard phase == .running else { return }
        phase = .ending
        scene?.isRunning = false
        sound.stopMusic()
        let summary = session.summary
        sound.play(summary.result == .goalComplete ? .finish : .curtain)
        haptics.notify(summary.result == .goalComplete ? .success : .error)
        endingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.3))
            guard let self, !Task.isCancelled else { return }
            let outcome = self.profileStore.record(summary)
            self.phase = .finished(outcome)
            if outcome.newRoses > 0 || outcome.isNewBest { self.sound.play(.rose) }
        }
    }
}

extension GameViewModel.Phase {
    var isCountdown: Bool {
        if case .countdown = self { return true }
        return false
    }
}

// MARK: - Scene delegate

extension GameViewModel: JugglerSceneDelegate {
    func scene(_ scene: JugglerScene, didProduce events: [RunEvent], dt: Double) {
        let session = scene.session
        for event in events {
            handle(event, session: session)
        }
        hudClock += dt
        if hudClock >= 0.1 || !events.isEmpty {
            hudClock = 0
            hud = ShowHUD(session: session)
        }
        if session.isOver { finish(session) }
    }

    private func handle(_ event: RunEvent, session: RunSession) {
        switch event {
        case .caught(_, let sweet):
            sound.playCatch(airborne: session.airborne)
            if sweet { sound.play(.sweet, volume: 0.5) }
            haptics.impact(.light)
        case .fused(_, let color):
            sound.play(.fuse)
            haptics.notify(.success)
            show(Callout(title: "Crown Gem!", detail: "\(color.title) chord fused · ×5 when banked", style: .gold))
        case .banked:
            sound.play(.bank)
        case .shattered:
            sound.play(.shatter)
            haptics.notify(.error)
            bellShake += 1
            show(Callout(title: "Shattered!", detail: "Bank cracked gems before the last toss", style: .rose))
        case .dropped(let gem, let bells):
            guard bells > 0 else { return }
            sound.play(.drop)
            haptics.notify(.error)
            bellShake += 1
            if gem.kind.isJoker { show(Callout(title: "Joker dropped!", detail: "Two bells lost", style: .rose)) }
        case .graceUsed:
            sound.play(.grace)
            show(Callout(title: "Silver Grace", detail: "The first drop is forgiven", style: .teal))
        case .tomatoCaught:
            sound.play(.tomatoHit)
            haptics.notify(.error)
            bellShake += 1
            show(Callout(title: "Splat!", detail: "Let the tomatoes fall", style: .rose))
        case .tomatoSplat:
            sound.play(.tomatoSplat, volume: 0.6)
        case .tomatoFeast:
            sound.play(.tomatoSplat, volume: 0.6)
            haptics.impact(.light)
            show(Callout(title: "Temperance", detail: "The court laughs along", style: .teal))
        case .reborn:
            sound.play(.grace)
            haptics.notify(.success)
            show(Callout(title: "Phoenix!", detail: "The opal reforms and flies again", style: .gold))
        case .powderBurst(let count):
            sound.play(.encore)
            haptics.impact(.heavy)
            show(Callout(title: "Powder Garnet!", detail: count == 1 ? "One more gem swept into the chest" : "\(count) more gems swept into the chest", style: .gold))
        case .encoreStarted:
            sound.play(.encore)
            haptics.notify(.success)
            show(Callout(title: "Encore!", detail: "Double points · the king adds a gem", style: .gold))
        case .decreeWarning:
            sound.play(.decree)
            haptics.impact(.medium)
        case .decreeStarted:
            sound.play(.decreeStart)
        case .jingleReady:
            sound.play(.jingleReady)
            haptics.impact(.medium)
        case .goalCompleted:
            show(Callout(title: "Bravo!", detail: "Act complete", style: .gold))
        case .spawned, .decreeEnded, .encoreEnded, .jingleStarted, .jingleEnded, .curtain:
            break
        }
    }
}
