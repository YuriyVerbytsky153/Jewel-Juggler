import Foundation
import Testing
@testable import JewelJuggler

@MainActor
@Suite("Royal Tour")
struct TourTests {
    @Test func theMapIsSeededAndEndsAtTheBanquet() {
        let a = TourRules.makeMap(seed: 11)
        let b = TourRules.makeMap(seed: 11)
        #expect(a == b)
        #expect(a.count == TourRules.rows)
        #expect(a.last?.count == 1)
        #expect(a.last?.first?.kind == .banquet)
        #expect(a.first?.allSatisfy { $0.kind == .show } == true)
        #expect(a[3].contains { $0.kind == .tavern })
        for seed in UInt64(1)...30 {
            let names = TourRules.makeMap(seed: seed).joined().map(\.name)
            #expect(Set(names).count == names.count, "Repeated stop name on seed \(seed)")
        }
    }

    @Test func everyStopHasARoadOnward() {
        for seed in UInt64(1)...40 {
            let tour = TourState(seed: seed, bells: 3)
            for stop in tour.rows.dropLast().joined() {
                #expect(!tour.roads(from: stop).isEmpty, "Dead end at \(stop.id) for seed \(seed)")
            }
            for row in tour.rows {
                #expect(row.contains { $0.kind.isPerformance })
            }
        }
    }

    @Test func offersAreThreeDistinctUnheldCards() {
        let held: [TourCard] = [.theFool, .theStar]
        let offer = TourRules.offer(for: .tournament, excluding: held, seed: 5)
        #expect(offer.count == 3)
        #expect(Set(offer).count == 3)
        #expect(offer.allSatisfy { !held.contains($0) })
        #expect(offer.contains { $0.isRare })
    }

    @Test func clearingAStopCarriesBellsAndDealsCards() throws {
        let (store, _) = try Fixtures.store()
        try store.startTour(seed: 21)
        let first = try #require(store.tour?.reachable.first)
        let mode = try #require(try store.travel(to: first))
        let setup = try store.setup(for: mode, seed: 1)
        #expect(setup.startBells == 3)

        var summary = Fixtures.summary(mode: mode, result: .goalComplete, ducats: 12)
        summary.bellsLeft = 2
        summary.shards = 1
        let outcome = store.record(summary)
        #expect(outcome.tour == .cleared(shards: TourRules.showShards))
        #expect(outcome.shardsEarned == 1 + TourRules.showShards)
        #expect(store.shards == 1 + TourRules.showShards)

        let tour = try #require(store.tour)
        #expect(tour.bells == 2)
        #expect(tour.current == first)
        #expect(tour.offer.count == 3)
        #expect(tour.reachable.isEmpty, "The road waits until a card is chosen")

        let card = tour.offer[0]
        try store.chooseCard(card)
        #expect(store.tour?.cards == [card])
        #expect(store.tour?.offer.isEmpty == true)
        #expect(store.tour?.reachable.isEmpty == false)
    }

    @Test func losingAStopEndsTheTour() throws {
        let (store, _) = try Fixtures.store()
        try store.startTour(seed: 4)
        let first = try #require(store.tour?.reachable.first)
        let outcome = store.record(Fixtures.summary(mode: .tour(first), result: .bellsOut))
        #expect(outcome.tour == .lost(depth: 0))
        #expect(store.tour?.status == .lost)
        #expect(store.tour?.reachable.isEmpty == true)
        #expect(throws: ProfileError.tourStopClosed) { _ = try store.setup(for: .tour(first), seed: 1) }
    }

    @Test func farStopsAreClosed() throws {
        let (store, _) = try Fixtures.store()
        try store.startTour(seed: 9)
        let banquet = try #require(store.tour?.rows.last?.first)
        #expect(throws: ProfileError.tourStopClosed) { _ = try store.travel(to: banquet) }
    }

    @Test func theTourSurvivesARelaunch() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let store = try ProfileStore(container: container)
        try store.startTour(seed: 77)
        let reopened = try ProfileStore(container: container)
        #expect(reopened.tour == store.tour)
    }

    @Test func cardsBendTheRules() {
        let lovers = RunModifiers(cards: [.theLovers])
        var s = RunSession(setup: RunSetup(mode: .endless, seed: 1, loadout: .standard, modifiers: lovers))
        s.freezeSpawningForTesting()
        s.setJesterForTesting(0.5)
        Fixtures.catchOne(&s, .plain(.ruby))
        let events = Fixtures.catchOne(&s, .plain(.ruby))
        #expect(events.contains { if case .fused = $0 { true } else { false } })

        let tower = RunSession(setup: RunSetup(mode: .endless, seed: 1, loadout: .standard, modifiers: RunModifiers(cards: [.theTower])))
        #expect(tower.tossLimit(for: FlyingGem(id: 1, kind: .plain(.ruby), x: 0, y: 0, vx: 0, vy: 0)) == 2)

        let star = RunSession(setup: RunSetup(mode: .endless, seed: 1, loadout: .standard, modifiers: RunModifiers(cards: [.theStar]), startBells: 2))
        #expect(star.maxBells == 4)
        #expect(star.bells == 2)
    }

    @Test func temperanceMakesTomatoesHarmless() {
        var s = RunSession(setup: RunSetup(mode: .endless, seed: 1, loadout: .standard, modifiers: RunModifiers(cards: [.temperance])))
        s.freezeSpawningForTesting()
        s.setJesterForTesting(0.5)
        let events = Fixtures.catchOne(&s, .tomato)
        #expect(events.contains { if case .tomatoFeast = $0 { true } else { false } })
        #expect(s.bells == s.maxBells)
    }
}

@MainActor
@Suite("Jeweller's Workshop")
struct WorkshopTests {
    @Test func cuttingCostsShardsAndFillsTheCase() throws {
        let (store, _) = try Fixtures.store()
        #expect(throws: ProfileError.notEnoughShards(needed: Enchantment.featherstone.price)) { try store.buyEnchantment(.featherstone) }
        try store.grantShards(200)
        try store.buyEnchantment(.featherstone)
        #expect(store.shards == 200 - Enchantment.featherstone.price)
        #expect(store.profile.equippedEnchantments == [.featherstone])

        try store.buyEnchantment(.lodestone)
        #expect(store.profile.equippedEnchantments == [.featherstone], "One setting to begin with")
        #expect(throws: ProfileError.jewelCaseFull) { try store.toggleEquip(.lodestone) }

        try store.buySlot()
        try store.toggleEquip(.lodestone)
        #expect(store.profile.equippedEnchantments == [.featherstone, .lodestone])
        try store.toggleEquip(.featherstone)
        #expect(store.profile.equippedEnchantments == [.lodestone])

        let setup = try store.setup(for: .endless, seed: 1)
        #expect(setup.enchantments == [.lodestone])
    }

    @Test func enchantedGemsAppearInShows() {
        var s = RunSession(setup: RunSetup(mode: .endless, seed: 3, loadout: .standard, enchantments: [.midasTopaz]))
        s.isInvincible = true
        var seen = false
        var t = 0.0
        while t < 90, !seen {
            s.autopilot()
            _ = s.advance(by: 1.0 / 60)
            seen = s.gems.contains { $0.enchantment == .midasTopaz }
            t += 1.0 / 60
        }
        #expect(seen)
    }

    @Test func phoenixRisesFromTheFloorOnce() {
        var s = Fixtures.quietSession()
        s.setJesterForTesting(0.9)
        s.insertForTesting(.plain(.ruby), x: 0.1, y: 0.05, vy: -0.5, enchantment: .phoenixOpal)
        let events = s.advance(by: 0.3)
        #expect(events.contains { if case .reborn = $0 { true } else { false } })
        #expect(s.bells == s.maxBells)
        #expect(s.gems.first?.reborn == true)
    }

    @Test func powderGarnetSweepsTheAir() {
        var s = Fixtures.quietSession()
        s.insertForTesting(.plain(.emerald), x: 0.2, y: 0.8)
        s.insertForTesting(.plain(.topaz), x: 0.7, y: 0.9)
        let events = Fixtures.catchOne(&s, .plain(.ruby), bank: true, enchantment: .powderGarnet)
        #expect(events.contains { if case .powderBurst(2) = $0 { true } else { false } })
        #expect(s.banks == 3)
        #expect(s.airborne == 0)
    }

    @Test func midasTopazPaysTriple() {
        var plain = Fixtures.quietSession()
        Fixtures.catchOne(&plain, .plain(.topaz), bank: true)
        var midas = Fixtures.quietSession()
        Fixtures.catchOne(&midas, .plain(.topaz), bank: true, enchantment: .midasTopaz)
        #expect(midas.ducats == plain.ducats * 3)
    }

    @Test func shatteredGemsLeaveShards() {
        var s = Fixtures.quietSession()
        Fixtures.catchOne(&s, .plain(.ruby), tosses: 3)
        #expect(s.shards == 1)
        #expect(s.summary.shards == 1)
    }
}
