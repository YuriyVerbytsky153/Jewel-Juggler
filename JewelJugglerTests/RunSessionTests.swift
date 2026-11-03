import Foundation
import Testing
@testable import JewelJuggler

@MainActor
@Suite("Core juggling")
struct JugglingTests {
    @Test func catchingTossesTheGemBackUp() {
        var s = Fixtures.quietSession()
        let events = Fixtures.catchOne(&s, .plain(.ruby))
        #expect(events.contains { if case .caught = $0 { true } else { false } })
        #expect(s.catches == 1)
        #expect(s.gems.count == 1)
        #expect(s.gems[0].tosses == 1)
        #expect(s.gems[0].vy > 0)
    }

    @Test func aMissedGemCostsABell() {
        var s = Fixtures.quietSession()
        s.setJesterForTesting(0.9)
        s.insertForTesting(.plain(.emerald), x: 0.1, y: 0.1, vy: -0.5)
        let events = s.advance(by: 0.5)
        #expect(events.contains { if case .dropped(_, 1) = $0 { true } else { false } })
        #expect(s.bells == s.maxBells - 1)
        #expect(s.gems.isEmpty)
    }

    @Test func dragMovesTheJesterAtLimitedSpeed() {
        var s = Fixtures.quietSession()
        s.moveJester(to: 1.5)
        _ = s.advance(by: 0.1)
        #expect(s.jesterX > 0.6)
        #expect(s.jesterX < 0.95)
        _ = s.advance(by: 1)
        #expect(abs(s.jesterX - (1 - RunSession.wallInset)) < 0.001)
    }

    @Test func losingEveryBellEndsTheShow() {
        var s = Fixtures.quietSession()
        s.setJesterForTesting(0.9)
        for _ in 0..<3 {
            s.insertForTesting(.plain(.topaz), x: 0.1, y: 0.05, vy: -0.5)
            _ = s.advance(by: 0.3)
        }
        #expect(s.result == .bellsOut)
        #expect(s.isOver)
        #expect(s.summary.bellsLost == 3)
    }

    @Test func invincibleShowsKeepTheLastBell() {
        var s = Fixtures.quietSession()
        s.isInvincible = true
        s.setJesterForTesting(0.9)
        for _ in 0..<5 {
            s.insertForTesting(.plain(.topaz), x: 0.1, y: 0.05, vy: -0.5)
            _ = s.advance(by: 0.3)
        }
        #expect(s.bells == 1)
        #expect(!s.isOver)
    }

    @Test func sameSeedReplaysIdentically() {
        func play() -> RunSession {
            var s = RunSession(setup: RunSetup(mode: .endless, seed: 7, loadout: .standard))
            _ = Fixtures.run(&s, seconds: 40, autopilot: true)
            return s
        }
        let a = play(), b = play()
        #expect(a.score == b.score)
        #expect(a.gems == b.gems)
        #expect(a.banks == b.banks)
    }

    @Test func autopilotCanFinishTheFirstAct() {
        var s = RunSession(setup: RunSetup(mode: .act(0), seed: 99, loadout: .standard))
        _ = Fixtures.run(&s, seconds: 120, autopilot: true)
        #expect(s.result == .goalComplete)
        #expect(s.banks >= 5)
    }
}

@MainActor
@Suite("Wear and Bank")
struct WearAndBankTests {
    @Test func armedBankSendsTheNextCatchToTheChest() {
        var s = Fixtures.quietSession()
        let events = Fixtures.catchOne(&s, .plain(.sapphire), bank: true)
        #expect(events.contains { if case .banked(_, 10, 2) = $0 { true } else { false } })
        #expect(s.banks == 1)
        #expect(s.ducats == 2)
        #expect(s.gems.isEmpty)
        #expect(!s.bankArmed)
    }

    @Test func wellTravelledGemsPayMore() {
        var fresh = Fixtures.quietSession()
        Fixtures.catchOne(&fresh, .plain(.ruby), tosses: 0, bank: true)
        var worn = Fixtures.quietSession()
        Fixtures.catchOne(&worn, .plain(.ruby), tosses: 2, bank: true)
        #expect(worn.ducats > fresh.ducats)
        #expect(worn.score > fresh.score)
    }

    @Test func aGemPastItsLimitShattersInTheHands() {
        var s = Fixtures.quietSession()
        let events = Fixtures.catchOne(&s, .plain(.emerald), tosses: s.loadout.tossLimit)
        #expect(events.contains { if case .shattered = $0 { true } else { false } })
        #expect(s.bells == s.maxBells - 1)
        #expect(s.gems.isEmpty)
    }

    @Test func bankingAtTheLimitSavesTheGem() {
        var s = Fixtures.quietSession()
        let events = Fixtures.catchOne(&s, .plain(.emerald), tosses: s.loadout.tossLimit, bank: true)
        #expect(!events.contains { if case .shattered = $0 { true } else { false } })
        #expect(s.bells == s.maxBells)
        #expect(s.banks == 1)
    }

    @Test func crackStagesClimbToTheWarning() {
        let s = Fixtures.quietSession()
        let limit = s.loadout.tossLimit
        let stages = (0...limit).map { s.crackStage(for: FlyingGem(id: 1, kind: .plain(.ruby), x: 0.5, y: 0.5, vx: 0, vy: 0, tosses: $0)) }
        #expect(stages.first == 0)
        #expect(stages.last == 3)
        #expect(stages == stages.sorted())
    }

    @Test func silkSleevesAndTidewaterAddTosses() {
        #expect(Loadout(levels: [.silkSleeves: 4], costume: .motley).tossLimit == 5)
        let s = Fixtures.quietSession(costume: .tidewaterMime)
        let sapphire = FlyingGem(id: 1, kind: .plain(.sapphire), x: 0, y: 0, vx: 0, vy: 0)
        let ruby = FlyingGem(id: 2, kind: .plain(.ruby), x: 0, y: 0, vx: 0, vy: 0)
        #expect(s.tossLimit(for: sapphire) == s.tossLimit(for: ruby) + 2)
    }

    @Test func emberHarlequinDoublesRubyDucats() {
        var plain = Fixtures.quietSession()
        Fixtures.catchOne(&plain, .plain(.ruby), bank: true)
        var ember = Fixtures.quietSession(costume: .emberHarlequin)
        Fixtures.catchOne(&ember, .plain(.ruby), bank: true)
        #expect(ember.ducats == plain.ducats * 2)
    }
}

@MainActor
@Suite("Chord Fusion and the Joker")
struct ChordTests {
    @Test func threeMatchingCatchesFuseACrown() {
        var s = Fixtures.quietSession()
        Fixtures.catchOne(&s, .plain(.ruby))
        Fixtures.catchOne(&s, .plain(.ruby))
        #expect(s.chordCount == 2)
        let events = Fixtures.catchOne(&s, .plain(.ruby), tosses: 2)
        #expect(events.contains { if case .fused(_, .ruby) = $0 { true } else { false } })
        #expect(s.crownsFused == 1)
        #expect(s.chordCount == 0)
        let crown = s.gems.first { $0.kind == .crown(.ruby) }
        #expect(crown?.tosses == 1, "Fusing resets wear before the toss")
    }

    @Test func aDifferentColourRestartsTheChord() {
        var s = Fixtures.quietSession()
        Fixtures.catchOne(&s, .plain(.ruby))
        Fixtures.catchOne(&s, .plain(.ruby))
        Fixtures.catchOne(&s, .plain(.emerald))
        #expect(s.chordColor == .emerald)
        #expect(s.chordCount == 1)
        #expect(s.crownsFused == 0)
    }

    @Test func crownsBankForFiveTimesThePoints() {
        var plain = Fixtures.quietSession()
        Fixtures.catchOne(&plain, .plain(.topaz), bank: true)
        var crown = Fixtures.quietSession()
        Fixtures.catchOne(&crown, .crown(.topaz), bank: true)
        #expect(crown.score - 1 == (plain.score - 1) * 5)
        #expect(GemKind.crown(.topaz).gravityScale > GemKind.plain(.topaz).gravityScale)
    }

    @Test func theJokerCompletesAnyChord() {
        var s = Fixtures.quietSession()
        Fixtures.catchOne(&s, .plain(.sapphire))
        Fixtures.catchOne(&s, .plain(.sapphire))
        let events = Fixtures.catchOne(&s, .joker)
        #expect(events.contains { if case .fused(_, .sapphire) = $0 { true } else { false } })
        #expect(s.gems.contains { $0.kind == .crown(.sapphire) })
    }

    @Test func droppingTheJokerCostsTwoBells() {
        var s = Fixtures.quietSession()
        s.setJesterForTesting(0.9)
        s.insertForTesting(.joker, x: 0.1, y: 0.05, vy: -0.5)
        _ = s.advance(by: 0.3)
        #expect(s.bells == s.maxBells - 2)

        var starlit = Fixtures.quietSession(costume: .starlitJoker)
        starlit.setJesterForTesting(0.9)
        starlit.insertForTesting(.joker, x: 0.1, y: 0.05, vy: -0.5)
        _ = starlit.advance(by: 0.3)
        #expect(starlit.bells == starlit.maxBells - 1)
    }

    @Test func moonlitAmethystsCountTwice() {
        var s = Fixtures.quietSession(costume: .moonlitFool)
        Fixtures.catchOne(&s, .plain(.amethyst))
        #expect(s.chordCount == 2)
        Fixtures.catchOne(&s, .plain(.amethyst))
        #expect(s.crownsFused == 1)
    }
}

@MainActor
@Suite("Applause, decrees and the Jingle")
struct CourtTests {
    @Test func fullApplauseStartsAnEncoreWithAGift() {
        var s = Fixtures.quietSession()
        s.insertForTesting(.plain(.ruby), x: 0.2, y: 0.9)
        s.insertForTesting(.plain(.emerald), x: 0.8, y: 0.9)
        s.setApplauseForTesting(0.9999)
        let events = s.advance(by: 0.05)
        #expect(events.contains(.encoreStarted))
        #expect(s.isEncore)
        #expect(s.encores == 1)
        #expect(s.airborne == 3)
        #expect(s.gems.contains { $0.isEncoreGift })
        #expect(s.points(base: 10, for: .plain(.ruby)) == 20)
    }

    @Test func encoreRunsOutAndCourtFavourLengthensIt() {
        var s = Fixtures.quietSession()
        s.insertForTesting(.plain(.ruby), x: 0.2, y: 50)
        s.insertForTesting(.plain(.emerald), x: 0.8, y: 50)
        s.setApplauseForTesting(0.9999)
        _ = s.advance(by: 0.05)
        let events = s.advance(by: s.loadout.encoreDuration + 0.1)
        #expect(events.contains(.encoreEnded))
        #expect(!s.isEncore)
        #expect(Loadout(levels: [.courtFavor: 5], costume: .motley).encoreDuration > Loadout.standard.encoreDuration)
    }

    @Test func moreGemsAloftFillTheApplauseFaster() {
        var two = Fixtures.quietSession()
        for x in [0.2, 0.8] { two.insertForTesting(.plain(.ruby), x: x, y: 50) }
        _ = two.advance(by: 1)
        var four = Fixtures.quietSession()
        for x in [0.2, 0.4, 0.6, 0.8] { four.insertForTesting(.plain(.ruby), x: x, y: 50) }
        _ = four.advance(by: 1)
        #expect(four.applause > two.applause * 2)
    }

    @Test func decreesAreAnnouncedThenWeathered() {
        var s = Fixtures.quietSession()
        s.scheduleDecreeForTesting(at: s.elapsed + 0.01)
        var events = s.advance(by: 0.05)
        #expect(events.contains { if case .decreeWarning = $0 { true } else { false } })
        events = s.advance(by: RunSession.decreeWarning + 0.1)
        #expect(events.contains { if case .decreeStarted = $0 { true } else { false } })
        #expect(s.decree.activeDecree != nil)
        events = s.advance(by: RunSession.decreeDuration + 0.1)
        #expect(events.contains { if case .decreeEnded = $0 { true } else { false } })
        #expect(s.decreesWeathered == 1)
        #expect(s.decree == .none)
    }

    @Test func rubyHourScoresOnlyRubies() {
        var s = Fixtures.quietSession(mode: .act(4))
        s.scheduleDecreeForTesting(at: s.elapsed + 0.01)
        _ = s.advance(by: RunSession.decreeWarning + 0.2)
        #expect(s.decree.activeDecree == .rubyHour)
        #expect(s.points(base: 10, for: .plain(.ruby)) == 30)
        #expect(s.points(base: 10, for: .plain(.emerald)) == 0)
    }

    @Test func candleGustDarkensAndLanternOilHelps() {
        var dim = Fixtures.quietSession(mode: .act(9))
        dim.scheduleDecreeForTesting(at: dim.elapsed + 0.01)
        _ = dim.advance(by: RunSession.decreeWarning + 0.2)
        #expect(dim.decree.activeDecree == .candleGust)
        #expect(dim.darkness > 0.7)
        #expect(dim.points(base: 10, for: .plain(.ruby)) == 15)

        var oiled = Fixtures.quietSession(mode: .act(9), levels: [.lanternOil: 5])
        oiled.scheduleDecreeForTesting(at: oiled.elapsed + 0.01)
        _ = oiled.advance(by: RunSession.decreeWarning + 0.2)
        #expect(oiled.darkness < dim.darkness - 0.4)
    }

    @Test func tomatoesMustBeLetFall() {
        var s = Fixtures.quietSession()
        let caught = Fixtures.catchOne(&s, .tomato)
        #expect(caught.contains { if case .tomatoCaught = $0 { true } else { false } })
        #expect(s.bells == s.maxBells - 1)

        s.setJesterForTesting(0.9)
        s.insertForTesting(.tomato, x: 0.1, y: 0.05, vy: -0.5)
        _ = s.advance(by: 0.3)
        #expect(s.tomatoesDodged == 1)
        #expect(s.bells == s.maxBells - 1)
    }

    @Test func rottenTomatoDecreeThrowsTomatoes() {
        var s = Fixtures.quietSession(mode: .act(7))
        s.scheduleDecreeForTesting(at: s.elapsed + 0.01)
        _ = s.advance(by: RunSession.decreeWarning + 0.2)
        #expect(s.decree.activeDecree == .rottenTomatoes)
        _ = s.advance(by: 2)
        #expect(s.gems.contains { $0.kind.isTomato } || s.tomatoesDodged > 0)
    }

    @Test func sweetSpotCatchesChargeTheJingle() {
        var s = Fixtures.quietSession()
        for _ in 0..<s.loadout.jingleCharges {
            #expect(!s.isJingleReady)
            Fixtures.catchOne(&s, .plain(.topaz), bank: true)
        }
        #expect(s.isJingleReady)
        let started = s.activateJingle()
        #expect(started)
        #expect(s.isJingling)
        let again = s.activateJingle()
        #expect(!again, "Cannot stack a second Jingle")
    }

    @Test func offCentreCatchesDoNotCharge() {
        var s = Fixtures.quietSession()
        Fixtures.catchOne(&s, .plain(.topaz), offset: s.catchHalfWidth * 0.8, bank: true)
        #expect(s.catches == 1)
        #expect(s.jingleCharge == 0)
    }

    @Test func jingleSlowsTheGems() {
        var normal = Fixtures.quietSession()
        normal.insertForTesting(.plain(.ruby), x: 0.3, y: 0.9)
        _ = normal.advance(by: 0.3)

        var slow = Fixtures.quietSession()
        for _ in 0..<slow.loadout.jingleCharges { Fixtures.catchOne(&slow, .plain(.topaz), bank: true) }
        slow.activateJingle()
        slow.insertForTesting(.plain(.ruby), x: 0.3, y: 0.9)
        _ = slow.advance(by: 0.3)
        let fallNormal = 0.9 - normal.gems[0].y
        let fallSlow = 0.9 - (slow.gems.first { $0.kind == .plain(.ruby) }?.y ?? 0)
        #expect(fallSlow < fallNormal * 0.5)
    }

    @Test func silverGraceForgivesTheFirstDrop() {
        var s = Fixtures.quietSession(levels: [.silverBells: 5])
        #expect(s.maxBells == 5)
        s.setJesterForTesting(0.9)
        s.insertForTesting(.plain(.ruby), x: 0.1, y: 0.05, vy: -0.5)
        let events = s.advance(by: 0.3)
        #expect(events.contains { if case .graceUsed = $0 { true } else { false } })
        #expect(s.bells == 5)
        s.insertForTesting(.plain(.ruby), x: 0.1, y: 0.05, vy: -0.5)
        _ = s.advance(by: 0.3)
        #expect(s.bells == 4)
    }
}

@MainActor
@Suite("Acts and modes")
struct ActTests {
    @Test func reachingTheGoalCompletesTheAct() {
        var s = Fixtures.quietSession(mode: .act(0))
        for _ in 0..<5 { Fixtures.catchOne(&s, .plain(.ruby), bank: true) }
        #expect(s.result == .goalComplete)
        #expect(s.roses == 3)
    }

    @Test func rosesDropWithLostBells() {
        var s = Fixtures.quietSession(mode: .act(0))
        s.setJesterForTesting(0.9)
        for _ in 0..<2 {
            s.insertForTesting(.plain(.topaz), x: 0.1, y: 0.05, vy: -0.5)
            _ = s.advance(by: 0.3)
        }
        s.setJesterForTesting(0.5)
        for _ in 0..<5 { Fixtures.catchOne(&s, .plain(.ruby), bank: true) }
        #expect(s.result == .goalComplete)
        #expect(s.roses == 1)
    }

    @Test func cleanBankStreakResetsOnALostBell() {
        var s = Fixtures.quietSession(mode: .act(3))
        for _ in 0..<4 { Fixtures.catchOne(&s, .plain(.ruby), bank: true) }
        #expect(s.cleanStreak == 4)
        s.setJesterForTesting(0.9)
        s.insertForTesting(.plain(.topaz), x: 0.1, y: 0.05, vy: -0.5)
        _ = s.advance(by: 0.3)
        #expect(s.cleanStreak == 0)
        #expect(s.bestCleanStreak == 4)
    }

    @Test func everyActHasADistinctGoalAndOpensInOrder() {
        #expect(ActCatalog.count == 15)
        #expect(Set(ActCatalog.all.map(\.name)).count == 15)
        #expect(ActCatalog.all.map(\.index) == Array(0..<15))
        #expect(ActCatalog.all.allSatisfy { $0.maxGems >= 2 })
    }

    @Test func festivalSeedIsStablePerDay() {
        #expect(FestivalSeed.seed(for: "2026-11-03") == FestivalSeed.seed(for: "2026-11-03"))
        #expect(FestivalSeed.seed(for: "2026-11-03") != FestivalSeed.seed(for: "2026-11-04"))
        #expect(RunConfig.make(for: .festival(dayKey: "x")).ducatMultiplier == 1.5)
    }

    @Test func spawningRampsUpWithTime() {
        var s = RunSession(setup: RunSetup(mode: .endless, seed: 3, loadout: .standard))
        #expect(s.desiredGems == 1)
        s.setElapsedForTesting(65)
        #expect(s.desiredGems == 5)
        #expect(s.colorsInPlay.count == 5)
    }
}
