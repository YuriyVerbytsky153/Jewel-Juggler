import Foundation

/// Lifetime numbers the rosettes are measured against.
struct PlayerStats: Equatable, Sendable {
    var totalShows = 0
    var totalBanks = 0
    var totalCrowns = 0
    var totalEncores = 0
    var totalDecrees = 0
    var totalJokers = 0
    var totalSweetCatches = 0
    var totalTomatoesDodged = 0
    var bestScore = 0
    var bestAirborne = 0
    var totalRoses = 0
    var ownedCostumes = 1
}

/// A rosette on the Playbills wall.
struct Achievement: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let goal: Int
    let progress: Int

    var isEarned: Bool { progress >= goal }
    var fraction: Double { min(1, Double(progress) / Double(max(1, goal))) }
}

enum AchievementCatalog {
    private struct Rule {
        let id: String
        let title: String
        let detail: String
        let goal: Int
        let value: (PlayerStats) -> Int
    }

    private static let rules: [Rule] = [
        Rule(id: "debut", title: "Debut", detail: "Perform your first show.", goal: 1) { $0.totalShows },
        Rule(id: "treasurer", title: "Treasurer", detail: "Bank 100 gems.", goal: 100) { $0.totalBanks },
        Rule(id: "crowned", title: "Crowned", detail: "Fuse 10 Crown Gems.", goal: 10) { $0.totalCrowns },
        Rule(id: "standing", title: "Standing Ovation", detail: "Earn 5 Encores.", goal: 5) { $0.totalEncores },
        Rule(id: "loyal", title: "Loyal Subject", detail: "Weather 10 royal decrees.", goal: 10) { $0.totalDecrees },
        Rule(id: "harlequin", title: "Harlequin's Friend", detail: "Bank 5 Joker gems.", goal: 5) { $0.totalJokers },
        Rule(id: "sweet", title: "Sweet Spot", detail: "Make 200 sweet-spot catches.", goal: 200) { $0.totalSweetCatches },
        Rule(id: "dodger", title: "Tomato Dodger", detail: "Let 30 tomatoes fall.", goal: 30) { $0.totalTomatoesDodged },
        Rule(id: "five", title: "Five Aloft", detail: "Keep 5 gems in the air at once.", goal: 5) { $0.bestAirborne },
        Rule(id: "star", title: "Star of the Court", detail: "Score 5,000 in one show.", goal: 5000) { $0.bestScore },
        Rule(id: "bouquet", title: "Bouquet", detail: "Collect 30 roses from the acts.", goal: 30) { $0.totalRoses },
        Rule(id: "wardrobe", title: "Wardrobe Keeper", detail: "Own 4 costumes.", goal: 4) { $0.ownedCostumes },
    ]

    static var count: Int { rules.count }

    static func evaluate(_ stats: PlayerStats) -> [Achievement] {
        rules.map { Achievement(id: $0.id, title: $0.title, detail: $0.detail, goal: $0.goal, progress: min($0.goal, $0.value(stats))) }
    }
}
