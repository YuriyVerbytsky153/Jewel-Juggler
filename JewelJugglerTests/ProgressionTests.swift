import Foundation
import SwiftData
import Testing
@testable import JewelJuggler

@MainActor
@Suite("Prop Trunk and Wardrobe")
struct ShopTests {
    @Test func buyingAPropSpendsDucatsAndRaisesTheLevel() throws {
        let (store, _) = try Fixtures.store()
        try store.grantDucats(1000)
        let cost = try #require(store.nextCost(of: .velvetGloves))
        try store.purchaseUpgrade(.velvetGloves)
        #expect(store.level(of: .velvetGloves) == 1)
        #expect(store.ducats == 1000 - cost)
        #expect(store.loadout.catchHalfWidth > Loadout.baseCatchHalfWidth)
    }

    @Test func cannotBuyWithoutDucats() throws {
        let (store, _) = try Fixtures.store()
        #expect(throws: ProfileError.notEnoughDucats(needed: UpgradeKind.silverBells.cost(forLevel: 1)!)) {
            try store.purchaseUpgrade(.silverBells)
        }
        #expect(store.level(of: .silverBells) == 0)
    }

    @Test func propsStopAtFiveTassels() throws {
        let (store, _) = try Fixtures.store()
        try store.grantDucats(100_000)
        for _ in 0..<UpgradeKind.maxLevel { try store.purchaseUpgrade(.jingleCharm) }
        #expect(store.nextCost(of: .jingleCharm) == nil)
        #expect(throws: ProfileError.upgradeMaxed) { try store.purchaseUpgrade(.jingleCharm) }
    }

    @Test func propCostsRiseEveryLevel() {
        for kind in UpgradeKind.allCases {
            let costs = (1...UpgradeKind.maxLevel).compactMap { kind.cost(forLevel: $0) }
            #expect(costs.count == 5)
            #expect(costs == costs.sorted() && Set(costs).count == 5)
            #expect(kind.cost(forLevel: 6) == nil)
        }
    }

    @Test func buyingACostumeWearsIt() throws {
        let (store, _) = try Fixtures.store()
        try store.grantDucats(Costume.saffronSprite.price)
        try store.buyCostume(.saffronSprite)
        #expect(store.profile.selectedCostume == .saffronSprite)
        #expect(store.ducats == 0)
        #expect(throws: ProfileError.costumeAlreadyOwned) { try store.buyCostume(.saffronSprite) }
        try store.wear(.motley)
        #expect(store.profile.selectedCostume == .motley)
    }

    @Test func cannotWearAnUnboughtCostume() throws {
        let (store, _) = try Fixtures.store()
        #expect(throws: ProfileError.costumeLocked) { try store.wear(.velvetHerald) }
        #expect(throws: ProfileError.notEnoughDucats(needed: Costume.velvetHerald.price)) { try store.buyCostume(.velvetHerald) }
    }

    @Test func everyCostumeHasAPerkAndRisingPrice() {
        let prices = Costume.allCases.map(\.price)
        #expect(prices == prices.sorted())
        #expect(Set(Costume.allCases.map(\.perkTitle)).count == Costume.allCases.count)
        #expect(Costume.saffronSprite.speedMultiplier > 1)
    }
}

@MainActor
@Suite("Shows and records")
struct RecordTests {
    @Test func recordingAShowPaysAndKeepsStats() throws {
        let (store, _) = try Fixtures.store()
        let outcome = store.record(Fixtures.summary(score: 800, ducats: 55, banks: 7))
        #expect(outcome.ducatsEarned == 55)
        #expect(outcome.isNewBest)
        #expect(store.ducats == 55)
        #expect(store.profile.bestScore == 800)
        #expect(store.profile.totalBanks == 7)
        #expect(store.recentShows.count == 1)
        #expect(outcome.newAchievements.contains("Debut"))
        let second = store.record(Fixtures.summary(score: 300))
        #expect(!second.isNewBest)
    }

    @Test func actsOpenOneByOneAndPayForNewRoses() throws {
        let (store, _) = try Fixtures.store()
        #expect(store.profile.isActUnlocked(0))
        #expect(!store.profile.isActUnlocked(1))
        #expect(throws: ProfileError.actLocked) { _ = try store.setup(for: .act(1), seed: 1) }

        let first = store.record(Fixtures.summary(mode: .act(0), result: .goalComplete, ducats: 10, roses: 2))
        #expect(first.roseBonus == 2 * ProfileStore.ducatsPerNewRose)
        #expect(first.ducatsEarned == 10 + first.roseBonus)
        #expect(store.profile.isActUnlocked(1))
        #expect(store.profile.nextActIndex == 1)

        let worse = store.record(Fixtures.summary(mode: .act(0), result: .goalComplete, ducats: 10, roses: 1))
        #expect(worse.roseBonus == 0)
        #expect(store.profile.roses(forAct: 0) == 2)

        let better = store.record(Fixtures.summary(mode: .act(0), result: .goalComplete, ducats: 0, roses: 3))
        #expect(better.roseBonus == ProfileStore.ducatsPerNewRose)
        #expect(better.newRoses == 1)
    }

    @Test func festivalBestIsKeptPerDay() throws {
        var day = Date(timeIntervalSince1970: 1_800_000_000)
        let container = try PersistenceController.makeContainer(inMemory: true)
        let store = try ProfileStore(container: container, now: { day })
        let key = store.todayKey
        let setup = try store.setup(for: .festival(dayKey: key), seed: 123)
        #expect(setup.seed == FestivalSeed.seed(for: key))
        let a = store.record(Fixtures.summary(mode: .festival(dayKey: key), score: 400))
        #expect(a.isNewFestivalBest)
        store.record(Fixtures.summary(mode: .festival(dayKey: key), score: 200))
        #expect(store.festivalBestToday == 400)
        day = day.addingTimeInterval(86_400)
        #expect(store.festivalBestToday == 0)
    }

    @Test func progressSurvivesANewStoreOnTheSameContainer() throws {
        let (store, container) = try Fixtures.store()
        try store.grantDucats(2000)
        try store.buyCostume(.moonlitFool)
        store.record(Fixtures.summary(score: 999))
        let reopened = try ProfileStore(container: container)
        #expect(reopened.profile.selectedCostume == .moonlitFool)
        #expect(reopened.profile.bestScore == 999)
        #expect(reopened.recentShows.count == 1)
    }

    @Test func historyKeepsOnlyTheLatestPosters() throws {
        let (store, _) = try Fixtures.store()
        for i in 0..<(ProfileStore.recentShowLimit + 6) { store.record(Fixtures.summary(score: i)) }
        #expect(store.recentShows.count == ProfileStore.recentShowLimit)
        #expect(store.profile.totalShows == ProfileStore.recentShowLimit + 6)
    }

    @Test func resetStartsANewSeason() throws {
        let (store, _) = try Fixtures.store()
        try store.grantDucats(5000)
        try store.purchaseUpgrade(.courtFavor)
        store.record(Fixtures.summary(mode: .act(0), result: .goalComplete, roses: 3))
        try store.resetProgress()
        #expect(store.ducats == 0)
        #expect(store.level(of: .courtFavor) == 0)
        #expect(store.profile.totalRoses == 0)
        #expect(store.recentShows.isEmpty)
    }

    @Test func achievementsTrackLifetimeProgress() {
        var stats = PlayerStats()
        stats.totalBanks = 50
        stats.bestAirborne = 5
        let list = AchievementCatalog.evaluate(stats)
        #expect(list.count == AchievementCatalog.count)
        #expect(list.first { $0.id == "treasurer" }?.fraction == 0.5)
        #expect(list.first { $0.id == "five" }?.isEarned == true)
    }
}

@MainActor
@Suite("Settings")
struct SettingsTests {
    @Test func settingsPersistInUserDefaults() throws {
        let suite = "jj.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.soundEnabled && settings.musicEnabled && settings.hapticsEnabled)
        settings.musicEnabled = false
        settings.leftHanded = true
        settings.hasSeenGuide = true
        let again = SettingsStore(defaults: defaults)
        #expect(!again.musicEnabled)
        #expect(again.leftHanded)
        #expect(again.hasSeenGuide)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func formattersUseGroupedDigits() {
        #expect(Formatters.integer(12_345) == "12,345")
        #expect(Formatters.duration(75) == "1:15")
        #expect(RomanNumeral.string(14) == "XIV")
    }
}
