import Foundation
import SwiftData

/// The single persistent profile: ducats, props, costumes, act roses and lifetime stats.
@Model
final class PlayerProfile {
    var ducats: Int = 0

    var velvetGlovesLevel: Int = 0
    var silkSleevesLevel: Int = 0
    var silverBellsLevel: Int = 0
    var courtFavorLevel: Int = 0
    var lanternOilLevel: Int = 0
    var jingleCharmLevel: Int = 0

    var ownedCostumeIDs: [String] = [Costume.starter.rawValue]
    var selectedCostumeID: String = Costume.starter.rawValue

    /// Roses per act index (0...3).
    var actRoses: [Int] = []

    var bestScore: Int = 0
    var bestAirborne: Int = 0
    var totalShows: Int = 0
    var totalBanks: Int = 0
    var totalCrowns: Int = 0
    var totalEncores: Int = 0
    var totalDecrees: Int = 0
    var totalJokers: Int = 0
    var totalSweetCatches: Int = 0
    var totalTomatoesDodged: Int = 0
    var totalDucatsEarned: Int = 0
    var totalSeconds: Int = 0

    var festivalDayKey: String = ""
    var festivalBest: Int = 0

    var createdAt: Date = Date.now

    init() {}

    // MARK: - Derived values

    var selectedCostume: Costume { Costume(rawValue: selectedCostumeID) ?? .starter }

    func owns(_ costume: Costume) -> Bool {
        costume.price == 0 || ownedCostumeIDs.contains(costume.rawValue)
    }

    func level(for kind: UpgradeKind) -> Int {
        switch kind {
        case .velvetGloves: velvetGlovesLevel
        case .silkSleeves: silkSleevesLevel
        case .silverBells: silverBellsLevel
        case .courtFavor: courtFavorLevel
        case .lanternOil: lanternOilLevel
        case .jingleCharm: jingleCharmLevel
        }
    }

    func setLevel(_ level: Int, for kind: UpgradeKind) {
        switch kind {
        case .velvetGloves: velvetGlovesLevel = level
        case .silkSleeves: silkSleevesLevel = level
        case .silverBells: silverBellsLevel = level
        case .courtFavor: courtFavorLevel = level
        case .lanternOil: lanternOilLevel = level
        case .jingleCharm: jingleCharmLevel = level
        }
    }

    func roses(forAct index: Int) -> Int {
        actRoses.indices.contains(index) ? actRoses[index] : 0
    }

    /// Acts open one after another: the next opens once the previous has a rose.
    func isActUnlocked(_ index: Int) -> Bool {
        index == 0 || roses(forAct: index - 1) > 0
    }

    var totalRoses: Int { actRoses.reduce(0, +) }

    /// The first act without a rose (or the last one).
    var nextActIndex: Int {
        (0..<ActCatalog.count).first { roses(forAct: $0) == 0 } ?? ActCatalog.count - 1
    }

    var loadout: Loadout {
        Loadout(levels: Dictionary(uniqueKeysWithValues: UpgradeKind.allCases.map { ($0, level(for: $0)) }), costume: selectedCostume)
    }

    var stats: PlayerStats {
        PlayerStats(totalShows: totalShows, totalBanks: totalBanks, totalCrowns: totalCrowns, totalEncores: totalEncores,
                    totalDecrees: totalDecrees, totalJokers: totalJokers, totalSweetCatches: totalSweetCatches,
                    totalTomatoesDodged: totalTomatoesDodged, bestScore: bestScore, bestAirborne: bestAirborne,
                    totalRoses: totalRoses, ownedCostumes: Costume.allCases.filter { owns($0) }.count)
    }
}

/// One finished show, pinned to the Playbills wall.
@Model
final class ShowRecord {
    var date: Date = Date.now
    var modeKey: String = "endless"
    var actIndex: Int = -1
    var costumeID: String = Costume.starter.rawValue
    var resultRaw: String = RunResult.bellsOut.rawValue
    var score: Int = 0
    var ducats: Int = 0
    var banks: Int = 0
    var crowns: Int = 0
    var roses: Int = 0
    var seconds: Int = 0

    init(summary: RunSummary, date: Date = .now) {
        self.date = date
        modeKey = summary.mode.storageKey
        actIndex = summary.mode.actIndex ?? -1
        costumeID = summary.costume.rawValue
        resultRaw = summary.result.rawValue
        score = summary.score
        ducats = summary.ducats
        banks = summary.banks
        crowns = summary.crowns
        roses = summary.roses
        seconds = summary.seconds
    }

    var result: RunResult { RunResult(rawValue: resultRaw) ?? .bellsOut }
    var costume: Costume { Costume(rawValue: costumeID) ?? .starter }
    var act: Act? { ActCatalog.act(actIndex) }

    var title: String {
        switch modeKey {
        case "festival": "Festival Night"
        case "act": act.map { "Act \($0.number): \($0.name)" } ?? "Act"
        default: "Royal Performance"
        }
    }
}
