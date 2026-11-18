import Foundation

/// The king's decrees, announced on a scroll a few seconds before they take effect.
enum Decree: String, CaseIterable, Codable, Sendable {
    /// Rubies score triple, every other gem scores nothing.
    case rubyHour
    /// Tomatoes rain down; they must be let fall.
    case rottenTomatoes
    /// The candles gutter; only the gems glow. Points are boosted while it lasts.
    case candleGust

    var title: String {
        switch self {
        case .rubyHour: "Ruby Hour"
        case .rottenTomatoes: "Rotten Tomatoes"
        case .candleGust: "Candle Gust"
        }
    }

    var instruction: String {
        switch self {
        case .rubyHour: "Rubies score ×3. Other gems score nothing."
        case .rottenTomatoes: "Let the tomatoes fall. Catching one costs a bell."
        case .candleGust: "The hall goes dark. Every point is boosted."
        }
    }
}

/// What an act asks the jester to do.
enum ActGoal: Codable, Hashable, Sendable {
    case bank(Int)
    case crowns(Int)
    case airborne(Int)
    case cleanBanks(Int)
    case decrees(Int)
    case encores(Int)
    case jokers(Int)
    case survive(seconds: Int)
    case score(Int)

    var target: Int {
        switch self {
        case .bank(let n), .crowns(let n), .airborne(let n), .cleanBanks(let n), .decrees(let n),
             .encores(let n), .jokers(let n), .score(let n): n
        case .survive(let seconds): seconds
        }
    }

    var text: String {
        switch self {
        case .bank(let n): "Bank \(n) gems in the chest"
        case .crowns(let n): n == 1 ? "Fuse a Crown Gem" : "Fuse \(n) Crown Gems"
        case .airborne(let n): "Keep \(n) gems in the air at once"
        case .cleanBanks(let n): "Bank \(n) gems in a row without losing a bell"
        case .decrees(let n): n == 1 ? "Weather a royal decree" : "Weather \(n) royal decrees"
        case .encores(let n): n == 1 ? "Earn an Encore" : "Earn \(n) Encores"
        case .jokers(let n): "Bank \(n) Joker gems"
        case .survive(let seconds): "Perform for \(seconds / 60 > 0 && seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds) s")"
        case .score(let n): "Score \(Formatters.integer(n)) points"
        }
    }
}

/// One of the fifteen staged acts.
struct Act: Identifiable, Equatable, Sendable {
    let index: Int
    let name: String
    let goal: ActGoal
    let maxGems: Int
    let decrees: [Decree]
    let jokers: Bool

    var id: Int { index }
    var number: Int { index + 1 }
}

enum ActCatalog {
    static let all: [Act] = [
        Act(index: 0, name: "First Toss", goal: .bank(5), maxGems: 2, decrees: [], jokers: false),
        Act(index: 1, name: "Three Aloft", goal: .airborne(3), maxGems: 3, decrees: [], jokers: false),
        Act(index: 2, name: "The Chord", goal: .crowns(1), maxGems: 3, decrees: [], jokers: false),
        Act(index: 3, name: "Steady Hands", goal: .cleanBanks(8), maxGems: 3, decrees: [], jokers: false),
        Act(index: 4, name: "Ruby Hour", goal: .decrees(1), maxGems: 3, decrees: [.rubyHour], jokers: false),
        Act(index: 5, name: "Applause!", goal: .encores(1), maxGems: 4, decrees: [], jokers: false),
        Act(index: 6, name: "Crown Jewels", goal: .crowns(3), maxGems: 4, decrees: [.rubyHour], jokers: false),
        Act(index: 7, name: "Rotten Luck", goal: .decrees(2), maxGems: 4, decrees: [.rottenTomatoes], jokers: false),
        Act(index: 8, name: "The Harlequin", goal: .jokers(2), maxGems: 4, decrees: [], jokers: true),
        Act(index: 9, name: "Candlelight", goal: .decrees(2), maxGems: 4, decrees: [.candleGust], jokers: true),
        Act(index: 10, name: "Full Hands", goal: .airborne(5), maxGems: 5, decrees: [.rubyHour], jokers: true),
        Act(index: 11, name: "The Long Show", goal: .survive(seconds: 120), maxGems: 5, decrees: Decree.allCases, jokers: true),
        Act(index: 12, name: "Treasury", goal: .score(2500), maxGems: 5, decrees: Decree.allCases, jokers: true),
        Act(index: 13, name: "Double Encore", goal: .encores(2), maxGems: 5, decrees: Decree.allCases, jokers: true),
        Act(index: 14, name: "Royal Gala", goal: .score(6000), maxGems: 6, decrees: Decree.allCases, jokers: true),
    ]

    static var count: Int { all.count }

    static func act(_ index: Int) -> Act? {
        all.indices.contains(index) ? all[index] : nil
    }
}

/// Which show the player is putting on.
enum RunMode: Equatable, Hashable, Sendable {
    /// Royal Performance: endless, for the high score.
    case endless
    /// Festival Night: one seeded show per day with bonus ducats.
    case festival(dayKey: String)
    /// A staged act with a goal.
    case act(Int)
    /// One stop of the Royal Tour.
    case tour(TourStop)

    var storageKey: String {
        switch self {
        case .endless: "endless"
        case .festival: "festival"
        case .act: "act"
        case .tour: "tour"
        }
    }

    var actIndex: Int? {
        if case .act(let index) = self { return index }
        return nil
    }

    var tourStop: TourStop? {
        if case .tour(let stop) = self { return stop }
        return nil
    }

    /// The goal that ends the show, if any.
    var goal: ActGoal? { RunConfig.make(for: self).goal }

    var title: String {
        switch self {
        case .endless: "Royal Performance"
        case .festival: "Festival Night"
        case .act(let index): ActCatalog.act(index).map { "Act \($0.number): \($0.name)" } ?? "Act"
        case .tour(let stop): "Royal Tour: \(stop.name)"
        }
    }
}

/// Rules fixed at the start of a show, derived from the mode.
struct RunConfig: Equatable, Sendable {
    var maxGems: Int
    var decrees: [Decree]
    var jokers: Bool
    var goal: ActGoal?
    var ducatMultiplier: Double
    /// When the first decree is announced.
    var firstDecree = 20.0
    /// Seconds between the end of one decree and the next.
    var decreeGap: ClosedRange<Double> = 14...20

    static func make(for mode: RunMode) -> RunConfig {
        switch mode {
        case .endless:
            RunConfig(maxGems: 7, decrees: Decree.allCases, jokers: true, goal: nil, ducatMultiplier: 1)
        case .festival:
            RunConfig(maxGems: 7, decrees: Decree.allCases, jokers: true, goal: nil, ducatMultiplier: 1.5)
        case .act(let index):
            if let act = ActCatalog.act(index) {
                RunConfig(maxGems: act.maxGems, decrees: act.decrees, jokers: act.jokers, goal: act.goal, ducatMultiplier: 1)
            } else {
                make(for: .endless)
            }
        case .tour(let stop):
            if stop.kind == .banquet {
                // The king's own table: decrees come thick and fast.
                RunConfig(maxGems: stop.maxGems, decrees: stop.decrees, jokers: stop.jokers, goal: stop.goal, ducatMultiplier: 1,
                          firstDecree: 12, decreeGap: 8...11)
            } else {
                RunConfig(maxGems: max(1, stop.maxGems), decrees: stop.decrees, jokers: stop.jokers, goal: stop.goal, ducatMultiplier: 1)
            }
        }
    }
}

/// Everything needed to start a show.
struct RunSetup: Equatable, Sendable {
    let mode: RunMode
    let seed: UInt64
    let loadout: Loadout
    /// Tarot rules carried by a Royal Tour.
    var modifiers: RunModifiers = .none
    /// Bells carried in from the previous tour stop; nil starts with a full cap.
    var startBells: Int?
    /// Enchantments worn from the Jeweller's Workshop.
    var enchantments: [Enchantment] = []

    var config: RunConfig { RunConfig.make(for: mode) }
}

/// The seed shared by every player for one Festival Night.
enum FestivalSeed {
    static func seed(for dayKey: String) -> UInt64 {
        // FNV-1a over the key keeps the seed stable across launches and devices.
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in dayKey.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

/// Calendar keys such as `2026-11-03` for daily content.
enum PeriodKey {
    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
