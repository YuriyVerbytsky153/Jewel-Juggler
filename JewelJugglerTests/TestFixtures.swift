import Foundation
import SwiftData
@testable import JewelJuggler

@MainActor
enum Fixtures {
    static func store(now: Date = Date(timeIntervalSince1970: 1_800_000_000)) throws -> (ProfileStore, ModelContainer) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let store = try ProfileStore(container: container, now: { now })
        return (store, container)
    }

    /// A session with spawning and decrees frozen, so tests place exactly what they need.
    static func quietSession(mode: RunMode = .endless, costume: Costume = .motley, levels: [UpgradeKind: Int] = [:], seed: UInt64 = 42) -> RunSession {
        var session = RunSession(setup: RunSetup(mode: mode, seed: seed, loadout: Loadout(levels: levels, costume: costume)))
        session.freezeSpawningForTesting()
        session.setJesterForTesting(0.5)
        return session
    }

    /// Drops a gem straight into the jester's hands and runs until it has been caught.
    @discardableResult
    static func catchOne(_ session: inout RunSession, _ kind: GemKind, tosses: Int = 0, offset: Double = 0, bank: Bool = false) -> [RunEvent] {
        if bank { session.armBank() }
        session.insertForTesting(kind, x: session.jesterX + offset, y: RunSession.handY + 0.02, vy: -0.4, tosses: tosses)
        return session.advance(by: 0.1)
    }

    static func run(_ session: inout RunSession, seconds: Double, autopilot: Bool = false) -> [RunEvent] {
        var events: [RunEvent] = []
        var t = 0.0
        while t < seconds && !session.isOver {
            if autopilot { session.autopilot() }
            events += session.advance(by: 1.0 / 60)
            t += 1.0 / 60
        }
        return events
    }

    static func summary(mode: RunMode = .endless, result: RunResult = .bellsOut, score: Int = 500, ducats: Int = 40, banks: Int = 6,
                        crowns: Int = 1, roses: Int = 0, airborne: Int = 3) -> RunSummary {
        RunSummary(mode: mode, costume: .motley, result: result, score: score, ducats: ducats, banks: banks, crowns: crowns,
                   encores: 1, decrees: 2, jokers: 0, maxAirborne: airborne, catches: 40, sweetCatches: 10, bellsLost: 3,
                   tomatoesDodged: 2, seconds: 75, roses: roses)
    }
}
