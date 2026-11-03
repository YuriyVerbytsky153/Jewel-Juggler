import Foundation
import Observation
import SwiftData

/// Errors surfaced to the interface when a purchase or selection is not possible.
enum ProfileError: LocalizedError, Equatable {
    case notEnoughDucats(needed: Int)
    case upgradeMaxed
    case costumeAlreadyOwned
    case costumeLocked
    case actLocked

    var errorDescription: String? {
        switch self {
        case .notEnoughDucats(let needed): "You need \(Formatters.integer(needed)) more ducats."
        case .upgradeMaxed: "This prop is already at its finest."
        case .costumeAlreadyOwned: "This costume already hangs in your wardrobe."
        case .costumeLocked: "Buy this costume first."
        case .actLocked: "Earn a rose in the previous act first."
        }
    }
}

/// What a finished show changed, for the Curtain Call.
struct ShowOutcome: Equatable, Sendable {
    let summary: RunSummary
    /// Ducats from banking plus the rose bonus.
    let ducatsEarned: Int
    let roseBonus: Int
    let previousRoses: Int
    let isNewBest: Bool
    let isNewFestivalBest: Bool
    let newAchievements: [String]
    let totalDucats: Int

    var newRoses: Int { max(0, summary.roses - previousRoses) }
}

/// Owns the profile and show history on top of SwiftData. Every mutation goes through here.
@MainActor
@Observable
final class ProfileStore {
    private let context: ModelContext
    let now: () -> Date

    private(set) var profile: PlayerProfile
    private(set) var recentShows: [ShowRecord] = []
    private(set) var persistenceErrorMessage: String?

    static let recentShowLimit = 24
    static let ducatsPerNewRose = 40

    init(container: ModelContainer, now: @escaping () -> Date = Date.init) throws {
        self.now = now
        context = ModelContext(container)
        context.autosaveEnabled = false
        var descriptor = FetchDescriptor<PlayerProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            profile = existing
        } else {
            let created = PlayerProfile()
            context.insert(created)
            profile = created
            try context.save()
        }
        try reloadShows()
    }

    // MARK: - Derived state

    var ducats: Int { profile.ducats }
    var loadout: Loadout { profile.loadout }
    var achievements: [Achievement] { AchievementCatalog.evaluate(profile.stats) }
    var todayKey: String { PeriodKey.day(now()) }

    /// Today's Festival Night best (zero once the day has rolled over).
    var festivalBestToday: Int { profile.festivalDayKey == todayKey ? profile.festivalBest : 0 }

    func level(of kind: UpgradeKind) -> Int { profile.level(for: kind) }

    func nextCost(of kind: UpgradeKind) -> Int? { kind.cost(forLevel: profile.level(for: kind) + 1) }

    func canAfford(_ amount: Int) -> Bool { profile.ducats >= amount }

    // MARK: - Trunk and wardrobe

    func purchaseUpgrade(_ kind: UpgradeKind) throws {
        guard let cost = nextCost(of: kind) else { throw ProfileError.upgradeMaxed }
        guard canAfford(cost) else { throw ProfileError.notEnoughDucats(needed: cost - profile.ducats) }
        profile.ducats -= cost
        profile.setLevel(profile.level(for: kind) + 1, for: kind)
        try save()
    }

    func buyCostume(_ costume: Costume) throws {
        guard !profile.owns(costume) else { throw ProfileError.costumeAlreadyOwned }
        guard canAfford(costume.price) else { throw ProfileError.notEnoughDucats(needed: costume.price - profile.ducats) }
        profile.ducats -= costume.price
        profile.ownedCostumeIDs.append(costume.rawValue)
        profile.selectedCostumeID = costume.rawValue
        try save()
    }

    func wear(_ costume: Costume) throws {
        guard profile.owns(costume) else { throw ProfileError.costumeLocked }
        profile.selectedCostumeID = costume.rawValue
        try save()
    }

    // MARK: - Shows

    /// Builds the setup for a show, checking that an act is open.
    func setup(for mode: RunMode, seed: UInt64) throws -> RunSetup {
        if let index = mode.actIndex, !profile.isActUnlocked(index) { throw ProfileError.actLocked }
        let finalSeed: UInt64
        if case .festival(let dayKey) = mode { finalSeed = FestivalSeed.seed(for: dayKey) } else { finalSeed = seed }
        return RunSetup(mode: mode, seed: finalSeed, loadout: profile.loadout)
    }

    /// Records a finished show and pays out. Abandoned shows still keep the ducats already banked.
    @discardableResult
    func record(_ summary: RunSummary) -> ShowOutcome {
        let before = Set(achievements.filter(\.isEarned).map(\.id))
        let isNewBest = summary.score > profile.bestScore

        var previousRoses = 0
        var roseBonus = 0
        if let index = summary.mode.actIndex, ActCatalog.act(index) != nil {
            previousRoses = profile.roses(forAct: index)
            if summary.roses > previousRoses {
                while profile.actRoses.count <= index { profile.actRoses.append(0) }
                profile.actRoses[index] = summary.roses
                roseBonus = (summary.roses - previousRoses) * Self.ducatsPerNewRose
            }
        }

        var isNewFestivalBest = false
        if case .festival(let dayKey) = summary.mode {
            if profile.festivalDayKey != dayKey {
                profile.festivalDayKey = dayKey
                profile.festivalBest = 0
            }
            if summary.score > profile.festivalBest {
                profile.festivalBest = summary.score
                isNewFestivalBest = summary.score > 0
            }
        }

        let earned = summary.ducats + roseBonus
        profile.ducats += earned
        profile.totalDucatsEarned += earned
        profile.bestScore = max(profile.bestScore, summary.score)
        profile.bestAirborne = max(profile.bestAirborne, summary.maxAirborne)
        profile.totalShows += 1
        profile.totalBanks += summary.banks
        profile.totalCrowns += summary.crowns
        profile.totalEncores += summary.encores
        profile.totalDecrees += summary.decrees
        profile.totalJokers += summary.jokers
        profile.totalSweetCatches += summary.sweetCatches
        profile.totalTomatoesDodged += summary.tomatoesDodged
        profile.totalSeconds += summary.seconds

        context.insert(ShowRecord(summary: summary, date: now()))
        persistQuietly()
        pruneOldShows()
        try? reloadShows()

        let after = achievements.filter { $0.isEarned && !before.contains($0.id) }.map(\.title)
        return ShowOutcome(summary: summary, ducatsEarned: earned, roseBonus: roseBonus, previousRoses: previousRoses,
                           isNewBest: isNewBest && summary.score > 0, isNewFestivalBest: isNewFestivalBest,
                           newAchievements: after, totalDucats: profile.ducats)
    }

    /// Wipes every bit of progress (Settings → Reset).
    func resetProgress() throws {
        try context.delete(model: ShowRecord.self)
        context.delete(profile)
        let fresh = PlayerProfile()
        context.insert(fresh)
        profile = fresh
        try save()
        try reloadShows()
    }

    /// Seeds ducats for UI tests.
    func grantDucats(_ amount: Int) throws {
        profile.ducats += amount
        try save()
    }

    // MARK: - Persistence

    private func save() throws {
        do {
            try context.save()
            persistenceErrorMessage = nil
        } catch {
            persistenceErrorMessage = "Progress could not be saved: \(error.localizedDescription)"
            throw error
        }
    }

    private func persistQuietly() {
        do { try save() } catch {}
    }

    private func reloadShows() throws {
        var descriptor = FetchDescriptor<ShowRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = Self.recentShowLimit
        recentShows = try context.fetch(descriptor)
    }

    private func pruneOldShows() {
        let descriptor = FetchDescriptor<ShowRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let all = try? context.fetch(descriptor), all.count > Self.recentShowLimit else { return }
        for record in all.dropFirst(Self.recentShowLimit) { context.delete(record) }
        persistQuietly()
    }
}
