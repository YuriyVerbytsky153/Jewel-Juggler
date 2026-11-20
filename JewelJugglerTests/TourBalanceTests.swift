import Foundation
import Testing
@testable import JewelJuggler

@MainActor
@Suite("Royal Tour balance")
struct TourBalanceTests {
    /// Plays a stop with the autopilot (bells never run out) and returns seconds to the goal and bells it would have lost.
    private func play(_ stop: TourStop, seed: UInt64, limit: Double = 400) -> (seconds: Double, bellsLost: Int, done: Bool) {
        var s = RunSession(setup: RunSetup(mode: .tour(stop), seed: seed, loadout: .standard))
        s.isInvincible = true
        var t = 0.0
        while t < limit, !s.isOver {
            s.autopilot()
            _ = s.advance(by: 1.0 / 60)
            t += 1.0 / 60
        }
        return (s.elapsed, s.bellsLost, s.result == .goalComplete)
    }

    @Test func everyStopGoalCanBeReached() {
        var report: [String] = []
        for seed in UInt64(1)...10 {
            let map = TourRules.makeMap(seed: seed)
            for stop in map.joined() where stop.kind.isPerformance {
                let r = play(stop, seed: seed &* 31 &+ UInt64(stop.row))
                report.append("seed \(seed) row \(stop.row) \(stop.kind.rawValue) \(stop.goal.map { "\($0)" } ?? "-") → \(Int(r.seconds)) s, lost \(r.bellsLost)\(r.done ? "" : " UNFINISHED")")
                #expect(r.done, "Stop \(stop.id) of seed \(seed) (\(String(describing: stop.goal))) was not reached")
                // A stop should feel like one show, not an endless marathon.
                #expect(r.seconds < (stop.kind == .banquet ? 300 : 200), "Stop \(stop.id) of seed \(seed) took \(Int(r.seconds)) s")
            }
        }
        print("TOUR BALANCE\n" + report.joined(separator: "\n"))
    }
}
