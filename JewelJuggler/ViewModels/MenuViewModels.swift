import Foundation
import Observation

/// The stage (home): purse, best show, worn costume and today's festival.
@MainActor
@Observable
final class StageViewModel {
    let profileStore: ProfileStore

    init(profileStore: ProfileStore) {
        self.profileStore = profileStore
    }

    var ducats: Int { profileStore.ducats }
    var bestScore: Int { profileStore.profile.bestScore }
    var costume: Costume { profileStore.profile.selectedCostume }
    var festivalBest: Int { profileStore.festivalBestToday }
    var festivalMode: RunMode { .festival(dayKey: profileStore.todayKey) }
    var totalRoses: Int { profileStore.profile.totalRoses }
    var nextAct: Act? { ActCatalog.act(profileStore.profile.nextActIndex) }
}

/// The Wardrobe rack: browse, buy and wear costumes.
@MainActor
@Observable
final class WardrobeViewModel {
    private let profileStore: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService

    var focused: Costume
    var toast: Toast?

    init(profileStore: ProfileStore, haptics: HapticsService, sound: SoundService) {
        self.profileStore = profileStore
        self.haptics = haptics
        self.sound = sound
        focused = profileStore.profile.selectedCostume
    }

    var ducats: Int { profileStore.ducats }
    var worn: Costume { profileStore.profile.selectedCostume }
    func owns(_ costume: Costume) -> Bool { profileStore.profile.owns(costume) }
    func canAfford(_ costume: Costume) -> Bool { profileStore.canAfford(costume.price) }

    enum Action: Equatable {
        case wearing
        case wear
        case buy(Int)
    }

    var action: Action {
        if focused == worn { return .wearing }
        if owns(focused) { return .wear }
        return .buy(focused.price)
    }

    func performAction() {
        do {
            switch action {
            case .wearing:
                return
            case .wear:
                try profileStore.wear(focused)
                haptics.selection()
                sound.play(.tap)
                toast = Toast(message: "Now wearing \(focused.name).", style: .success)
            case .buy:
                try profileStore.buyCostume(focused)
                haptics.notify(.success)
                sound.play(.buy)
                toast = Toast(message: "\(focused.name) joins your wardrobe!", style: .success)
            }
        } catch {
            haptics.notify(.warning)
            toast = Toast(message: error.localizedDescription, style: .warning)
        }
    }
}

/// The Prop Trunk: level up props with ducats.
@MainActor
@Observable
final class TrunkViewModel {
    private let profileStore: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService
    var toast: Toast?

    init(profileStore: ProfileStore, haptics: HapticsService, sound: SoundService) {
        self.profileStore = profileStore
        self.haptics = haptics
        self.sound = sound
    }

    var ducats: Int { profileStore.ducats }
    func level(_ kind: UpgradeKind) -> Int { profileStore.level(of: kind) }
    func cost(_ kind: UpgradeKind) -> Int? { profileStore.nextCost(of: kind) }
    func canAfford(_ kind: UpgradeKind) -> Bool { cost(kind).map(profileStore.canAfford) ?? false }

    func buy(_ kind: UpgradeKind) {
        do {
            try profileStore.purchaseUpgrade(kind)
            haptics.notify(.success)
            sound.play(.buy)
            toast = Toast(message: "\(kind.title) raised to level \(level(kind)).", style: .success)
        } catch {
            haptics.notify(.warning)
            toast = Toast(message: error.localizedDescription, style: .warning)
        }
    }
}

/// The Acts programme.
@MainActor
@Observable
final class ActsViewModel {
    private let profileStore: ProfileStore
    var toast: Toast?

    init(profileStore: ProfileStore) {
        self.profileStore = profileStore
    }

    var acts: [Act] { ActCatalog.all }
    var totalRoses: Int { profileStore.profile.totalRoses }
    var maxRoses: Int { ActCatalog.count * 3 }
    var nextIndex: Int { profileStore.profile.nextActIndex }
    func roses(_ act: Act) -> Int { profileStore.profile.roses(forAct: act.index) }
    func isUnlocked(_ act: Act) -> Bool { profileStore.profile.isActUnlocked(act.index) }

    /// Returns the mode to play, or shows why the act is closed.
    func request(_ act: Act) -> RunMode? {
        guard isUnlocked(act) else {
            toast = Toast(message: ProfileError.actLocked.localizedDescription, style: .warning)
            return nil
        }
        return .act(act.index)
    }
}

/// The Playbills wall: recent shows, rosettes and lifetime numbers.
@MainActor
@Observable
final class PlaybillsViewModel {
    private let profileStore: ProfileStore

    init(profileStore: ProfileStore) {
        self.profileStore = profileStore
    }

    var shows: [ShowRecord] { profileStore.recentShows }
    var achievements: [Achievement] { profileStore.achievements }
    var earnedCount: Int { achievements.filter(\.isEarned).count }
    var profile: PlayerProfile { profileStore.profile }

    struct StatLine: Identifiable {
        let id: String
        let title: String
        let value: String
        let art: String
    }

    var statLines: [StatLine] {
        let p = profile
        return [
            StatLine(id: "best", title: "Best show", value: Formatters.integer(p.bestScore), art: Art.rose),
            StatLine(id: "shows", title: "Shows performed", value: Formatters.integer(p.totalShows), art: Art.jester(p.selectedCostume)),
            StatLine(id: "banks", title: "Gems banked", value: Formatters.integer(p.totalBanks), art: Art.chestOpen),
            StatLine(id: "crowns", title: "Crowns fused", value: Formatters.integer(p.totalCrowns), art: Art.crown(.topaz)),
            StatLine(id: "encores", title: "Encores", value: Formatters.integer(p.totalEncores), art: Art.rosetteEarned),
            StatLine(id: "decrees", title: "Decrees weathered", value: Formatters.integer(p.totalDecrees), art: Art.decree(.rubyHour)),
            StatLine(id: "aloft", title: "Most gems aloft", value: Formatters.integer(p.bestAirborne), art: Art.gem(.sapphire)),
            StatLine(id: "ducats", title: "Ducats earned", value: Formatters.integer(p.totalDucatsEarned), art: Art.ducat),
        ]
    }
}

/// Settings: switches and the progress reset.
@MainActor
@Observable
final class SettingsViewModel {
    let settings: SettingsStore
    private let profileStore: ProfileStore
    private let sound: SoundService
    var toast: Toast?
    var isConfirmingReset = false

    init(settings: SettingsStore, profileStore: ProfileStore, sound: SoundService) {
        self.settings = settings
        self.profileStore = profileStore
        self.sound = sound
    }

    func musicChanged() {
        sound.refreshMusic(default: .menu)
    }

    func resetProgress() {
        do {
            try profileStore.resetProgress()
            toast = Toast(message: "A fresh season begins. All progress was reset.", style: .info)
        } catch {
            toast = Toast(message: error.localizedDescription, style: .warning)
        }
    }
}
