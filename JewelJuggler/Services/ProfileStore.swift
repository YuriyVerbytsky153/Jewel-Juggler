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
    case notEnoughShards(needed: Int)
    case enchantmentOwned
    case enchantmentLocked
    case jewelCaseFull
    case jewelCaseMaxed
    case noTour
    case tourStopClosed
    case tourCardUnavailable

    var errorDescription: String? {
        switch self {
        case .notEnoughDucats(let needed): "You need \(Formatters.integer(needed)) more ducats."
        case .upgradeMaxed: "This prop is already at its finest."
        case .costumeAlreadyOwned: "This costume already hangs in your wardrobe."
        case .costumeLocked: "Buy this costume first."
        case .actLocked: "Earn a rose in the previous act first."
        case .notEnoughShards(let needed): "You need \(Formatters.integer(needed)) more shards."
        case .enchantmentOwned: "This enchantment is already in your jewel case."
        case .enchantmentLocked: "Cut this enchantment first."
        case .jewelCaseFull: "Every setting in the jewel case is taken. Remove one first."
        case .jewelCaseMaxed: "The jewel case has no room for another setting."
        case .noTour: "Set out on a Royal Tour first."
        case .tourStopClosed: "No road leads there from where you stand."
        case .tourCardUnavailable: "That card is not on offer."
        }
    }
}

/// What a tour stop's show did to the Royal Tour.
enum TourReport: Equatable, Sendable {
    /// The stop was cleared; a tarot card waits on the map.
    case cleared(shards: Int)
    /// The King's Banquet was won.
    case won(shards: Int, ducats: Int)
    /// The bells fell silent (or the jester left) and the tour ended.
    case lost(depth: Int)
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
    /// Shards from the show itself plus any tour reward.
    var shardsEarned = 0
    var tour: TourReport?

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
    /// The Royal Tour in progress or last finished.
    private(set) var tour: TourState?
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
        tour = profile.tourData.flatMap { try? JSONDecoder().decode(TourState.self, from: $0) }
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

    var shards: Int { profile.shards }

    /// Bells on a full cap for the current tour.
    var tourMaxBells: Int { tour?.maxBells(base: profile.loadout.bells) ?? profile.loadout.bells }

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

    // MARK: - Jeweller's Workshop

    func buyEnchantment(_ enchantment: Enchantment) throws {
        guard !profile.owns(enchantment) else { throw ProfileError.enchantmentOwned }
        guard profile.shards >= enchantment.price else { throw ProfileError.notEnoughShards(needed: enchantment.price - profile.shards) }
        profile.shards -= enchantment.price
        profile.ownedEnchantmentIDs.append(enchantment.rawValue)
        // Set it straight into a free slot.
        if profile.equippedEnchantments.count < profile.jewelSlots {
            profile.equippedEnchantmentIDs = profile.equippedEnchantments.map(\.rawValue) + [enchantment.rawValue]
        }
        try save()
    }

    func isEquipped(_ enchantment: Enchantment) -> Bool { profile.equippedEnchantments.contains(enchantment) }

    /// Sets an owned enchantment into the jewel case, or takes it out.
    func toggleEquip(_ enchantment: Enchantment) throws {
        guard profile.owns(enchantment) else { throw ProfileError.enchantmentLocked }
        var worn = profile.equippedEnchantments
        if let index = worn.firstIndex(of: enchantment) {
            worn.remove(at: index)
        } else {
            guard worn.count < profile.jewelSlots else { throw ProfileError.jewelCaseFull }
            worn.append(enchantment)
        }
        profile.equippedEnchantmentIDs = worn.map(\.rawValue)
        try save()
    }

    var nextSlotPrice: Int? { JewelCase.slotPrice(forSlot: profile.jewelSlots + 1) }

    func buySlot() throws {
        guard let price = nextSlotPrice else { throw ProfileError.jewelCaseMaxed }
        guard profile.shards >= price else { throw ProfileError.notEnoughShards(needed: price - profile.shards) }
        profile.shards -= price
        profile.jewelSlots += 1
        try save()
    }

    // MARK: - Royal Tour

    /// Starts a fresh tour (replacing any finished or abandoned one) with a full cap of bells.
    func startTour(seed: UInt64) throws {
        tour = TourState(seed: seed, bells: profile.loadout.bells)
        try saveTour()
    }

    /// Gives up the current tour. Shards already earned are kept.
    func retireTour() throws {
        tour = nil
        try saveTour()
    }

    /// Moves to a stop. A tavern is resolved at once (returns nil); a show returns the mode to perform.
    func travel(to stop: TourStop) throws -> RunMode? {
        guard var current = tour else { throw ProfileError.noTour }
        guard current.isReachable(stop) else { throw ProfileError.tourStopClosed }
        guard stop.kind.isPerformance else {
            current.bells = min(current.maxBells(base: profile.loadout.bells), current.bells + TourRules.tavernBells)
            current.current = stop
            current.clearedIDs.append(stop.id)
            tour = current
            profile.bestTourDepth = max(profile.bestTourDepth, current.depth)
            try saveTour()
            return nil
        }
        return .tour(stop)
    }

    /// Takes one of the offered tarot cards into the hand.
    func chooseCard(_ card: TourCard) throws {
        guard var current = tour else { throw ProfileError.noTour }
        guard current.offer.contains(card) else { throw ProfileError.tourCardUnavailable }
        current.cards.append(card)
        current.offer = []
        if card == .theStar {
            current.bells = min(current.maxBells(base: profile.loadout.bells), current.bells + 1)
        }
        tour = current
        try saveTour()
    }

    /// Settles a tour stop's show. Returns the report and the shard and ducat rewards.
    private func settleTour(_ summary: RunSummary) -> (report: TourReport, shards: Int, ducats: Int)? {
        guard let stop = summary.mode.tourStop, var current = tour, current.isReachable(stop) else { return nil }
        let report: TourReport
        var shards = 0
        var ducats = 0
        if summary.result == .goalComplete {
            current.current = stop
            current.clearedIDs.append(stop.id)
            current.bells = max(1, summary.bellsLeft)
            switch stop.kind {
            case .banquet:
                shards = TourRules.banquetShards
                ducats = TourRules.banquetDucats
                current.status = .won
                profile.toursWon += 1
                report = .won(shards: shards, ducats: ducats)
            case .tournament:
                shards = TourRules.tournamentShards
                report = .cleared(shards: shards)
            case .show, .tavern:
                shards = TourRules.showShards
                report = .cleared(shards: shards)
            }
            if current.status == .active {
                current.offer = TourRules.offer(for: stop.kind, excluding: current.cards, seed: current.offerSeed)
            }
        } else {
            current.status = .lost
            report = .lost(depth: current.depth)
        }
        current.shardsEarned += shards
        current.ducatsEarned += ducats + summary.ducats
        profile.bestTourDepth = max(profile.bestTourDepth, current.depth)
        tour = current
        return (report, shards, ducats)
    }

    // MARK: - Shows

    /// Builds the setup for a show, checking that an act is open.
    func setup(for mode: RunMode, seed: UInt64) throws -> RunSetup {
        if let index = mode.actIndex, !profile.isActUnlocked(index) { throw ProfileError.actLocked }
        let finalSeed: UInt64
        if case .festival(let dayKey) = mode { finalSeed = FestivalSeed.seed(for: dayKey) } else { finalSeed = seed }
        var setup = RunSetup(mode: mode, seed: finalSeed, loadout: profile.loadout, enchantments: profile.equippedEnchantments)
        if let stop = mode.tourStop {
            guard let tour else { throw ProfileError.noTour }
            guard tour.isReachable(stop) else { throw ProfileError.tourStopClosed }
            setup.modifiers = tour.modifiers
            setup.startBells = tour.bells
        }
        return setup
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

        let tourResult = settleTour(summary)
        let shardsEarned = summary.shards + (tourResult?.shards ?? 0)
        profile.shards += shardsEarned
        profile.totalShards += shardsEarned

        let earned = summary.ducats + roseBonus + (tourResult?.ducats ?? 0)
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
        if tourResult != nil { encodeTour() }
        persistQuietly()
        pruneOldShows()
        try? reloadShows()

        let after = achievements.filter { $0.isEarned && !before.contains($0.id) }.map(\.title)
        return ShowOutcome(summary: summary, ducatsEarned: earned, roseBonus: roseBonus, previousRoses: previousRoses,
                           isNewBest: isNewBest && summary.score > 0, isNewFestivalBest: isNewFestivalBest,
                           newAchievements: after, totalDucats: profile.ducats, shardsEarned: shardsEarned, tour: tourResult?.report)
    }

    /// Wipes every bit of progress (Settings → Reset).
    func resetProgress() throws {
        try context.delete(model: ShowRecord.self)
        context.delete(profile)
        let fresh = PlayerProfile()
        context.insert(fresh)
        profile = fresh
        tour = nil
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

    private func encodeTour() {
        profile.tourData = tour.flatMap { try? JSONEncoder().encode($0) }
    }

    private func saveTour() throws {
        encodeTour()
        try save()
    }

    /// Seeds shards for UI tests.
    func grantShards(_ amount: Int) throws {
        profile.shards += amount
        try save()
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
