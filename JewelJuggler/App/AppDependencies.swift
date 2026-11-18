import Foundation
import SwiftData

/// Composition root: builds the stores and services the whole app shares.
@MainActor
final class AppDependencies {
    let container: ModelContainer
    let profileStore: ProfileStore
    let settings: SettingsStore
    let haptics: HapticsService
    let sound: SoundService
    let isUITesting: Bool
    /// The jester performs by itself (UI tests and screenshot tours).
    let autopilot: Bool
    /// Bells never run out (UI tests that must not end mid-way).
    let invincible: Bool

    static let uiTestingArgument = "--uitesting"
    static let freshStartArgument = "--freshstart"
    static let autopilotArgument = "--autopilot"
    static let invincibleArgument = "--invincible"
    private static let uiTestingDefaultsSuite = "com.jeweljuggler.game29.uitesting"

    init(launchArguments: [String] = CommandLine.arguments) throws {
        #if DEBUG
        isUITesting = launchArguments.contains(Self.uiTestingArgument)
        autopilot = launchArguments.contains(Self.autopilotArgument)
        invincible = launchArguments.contains(Self.invincibleArgument)
        #else
        isUITesting = false
        autopilot = false
        invincible = false
        #endif

        let defaults: UserDefaults
        if isUITesting, let suite = UserDefaults(suiteName: Self.uiTestingDefaultsSuite) {
            suite.removePersistentDomain(forName: Self.uiTestingDefaultsSuite)
            defaults = suite
        } else {
            defaults = .standard
        }

        container = try PersistenceController.makeContainer(inMemory: isUITesting)
        profileStore = try ProfileStore(container: container)
        settings = SettingsStore(defaults: defaults)
        let settings = self.settings
        haptics = HapticsService { settings.hapticsEnabled }
        sound = isUITesting ? .silent : SoundService(soundEnabled: { settings.soundEnabled }, musicEnabled: { settings.musicEnabled })

        if isUITesting && !launchArguments.contains(Self.freshStartArgument) {
            // Deterministic state so UI tests can shop without performing first.
            settings.hasSeenGuide = true
            try profileStore.grantDucats(5000)
            try profileStore.grantShards(200)
        }
    }

    /// A fresh random seed for a new show.
    static func randomSeed() -> UInt64 {
        UInt64.random(in: 1...UInt64.max)
    }
}
