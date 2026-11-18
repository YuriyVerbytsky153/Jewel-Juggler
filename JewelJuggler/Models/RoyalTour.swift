import Foundation

// MARK: - Tarot cards

/// Major Arcana dealt after each cleared stop of the Royal Tour. Every card bends a rule
/// for the rest of the tour, so each tour builds into a different show.
enum TourCard: String, CaseIterable, Identifiable, Codable, Sendable {
    case theFool
    case theMagician
    case theLovers
    case theHermit
    case wheelOfFortune
    case strength
    case theHangedMan
    case temperance
    case theDevil
    case theTower
    case theStar
    case theSun
    case judgement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .theFool: "The Fool"
        case .theMagician: "The Magician"
        case .theLovers: "The Lovers"
        case .theHermit: "The Hermit"
        case .wheelOfFortune: "Wheel of Fortune"
        case .strength: "Strength"
        case .theHangedMan: "The Hanged Man"
        case .temperance: "Temperance"
        case .theDevil: "The Devil"
        case .theTower: "The Tower"
        case .theStar: "The Star"
        case .theSun: "The Sun"
        case .judgement: "Judgement"
        }
    }

    var numeral: String {
        switch self {
        case .theFool: "0"
        case .theMagician: "I"
        case .theLovers: "VI"
        case .strength: "VIII"
        case .theHermit: "IX"
        case .wheelOfFortune: "X"
        case .theHangedMan: "XII"
        case .temperance: "XIV"
        case .theDevil: "XV"
        case .theTower: "XVI"
        case .theStar: "XVII"
        case .theSun: "XIX"
        case .judgement: "XX"
        }
    }

    var effect: String {
        switch self {
        case .theFool: "Your hands reach 25% further."
        case .theMagician: "The Jingle charges with 3 fewer sweet catches and lasts 2 s longer."
        case .theLovers: "Two matching catches are enough to fuse a Crown."
        case .theHermit: "One gem fewer in the air, but every point ×1.5."
        case .wheelOfFortune: "Jokers appear three times as often, from the very first second."
        case .strength: "Crown Gems bank for double points."
        case .theHangedMan: "Gems fall 15% slower."
        case .temperance: "Caught tomatoes cost nothing and stir the applause."
        case .theDevil: "Banked gems score ×2, but a drop silences all applause."
        case .theTower: "Every catch scores ×3, but gems crack one toss sooner."
        case .theStar: "One more bell on the cap, and one bell restored at once."
        case .theSun: "Applause fills 50% faster and Encores last 4 s longer."
        case .judgement: "The first dropped gem of every stop is forgiven."
        }
    }

    /// Rare cards are dealt less often; a Tournament always offers one.
    var isRare: Bool {
        switch self {
        case .theLovers, .theDevil, .theTower, .judgement: true
        default: false
        }
    }

    /// SF Symbol for the card face.
    var symbol: String {
        switch self {
        case .theFool: "hand.raised.fill"
        case .theMagician: "wand.and.stars"
        case .theLovers: "heart.fill"
        case .theHermit: "lamp.desk.fill"
        case .wheelOfFortune: "circle.hexagongrid.fill"
        case .strength: "crown.fill"
        case .theHangedMan: "arrow.down.to.line"
        case .temperance: "drop.fill"
        case .theDevil: "flame.fill"
        case .theTower: "bolt.fill"
        case .theStar: "star.fill"
        case .theSun: "sun.max.fill"
        case .judgement: "bell.fill"
        }
    }
}

/// Rule changes a show inherits from the tarot cards in hand. `.none` leaves every rule as written.
struct RunModifiers: Equatable, Sendable {
    var catchWidth = 1.0
    var jingleChargeDelta = 0
    var jingleBonus = 0.0
    var chordLength = 3
    var maxGemsDelta = 0
    var points = 1.0
    var jokerChance = 1.0
    var earlyJokers = false
    var crownBank = 1.0
    var gravity = 1.0
    var harmlessTomatoes = false
    var bankPoints = 1.0
    var drainApplauseOnDrop = false
    var catchPoints = 1.0
    var tossLimitDelta = 0
    var extraBells = 0
    var applauseRate = 1.0
    var encoreBonus = 0.0
    var grace = false

    static let none = RunModifiers()

    init() {}

    init(cards: [TourCard]) {
        for card in cards {
            switch card {
            case .theFool: catchWidth *= 1.25
            case .theMagician:
                jingleChargeDelta -= 3
                jingleBonus += 2
            case .theLovers: chordLength = 2
            case .theHermit:
                maxGemsDelta -= 1
                points *= 1.5
            case .wheelOfFortune:
                jokerChance *= 3
                earlyJokers = true
            case .strength: crownBank *= 2
            case .theHangedMan: gravity *= 0.85
            case .temperance: harmlessTomatoes = true
            case .theDevil:
                bankPoints *= 2
                drainApplauseOnDrop = true
            case .theTower:
                catchPoints *= 3
                tossLimitDelta -= 1
            case .theStar: extraBells += 1
            case .theSun:
                applauseRate *= 1.5
                encoreBonus += 4
            case .judgement: grace = true
            }
        }
    }
}

// MARK: - The map

/// What waits at a stop on the tour.
enum TourStopKind: String, Codable, Sendable {
    /// A show with a goal.
    case show
    /// A harder show that always deals a rare card.
    case tournament
    /// No show: rest and restore bells.
    case tavern
    /// The final show before the king.
    case banquet

    var title: String {
        switch self {
        case .show: "Show"
        case .tournament: "Tournament"
        case .tavern: "Tavern"
        case .banquet: "The King's Banquet"
        }
    }

    var symbol: String {
        switch self {
        case .show: "theatermasks.fill"
        case .tournament: "flag.2.crossed.fill"
        case .tavern: "mug.fill"
        case .banquet: "crown.fill"
        }
    }

    var isPerformance: Bool { self != .tavern }
}

/// One stop on the tour map.
struct TourStop: Codable, Hashable, Sendable, Identifiable {
    let row: Int
    let column: Int
    let columns: Int
    let kind: TourStopKind
    let name: String
    let goal: ActGoal?
    let maxGems: Int
    let decrees: [Decree]
    let jokers: Bool

    var id: String { "\(row)-\(column)" }

    /// Horizontal place on the map, 0...1.
    var position: Double { (Double(column) + 0.5) / Double(max(1, columns)) }
}

/// Tuning for the tour.
enum TourRules {
    static let rows = 7
    static let tavernBells = 2
    static let showShards = 3
    static let tournamentShards = 6
    static let banquetShards = 15
    static let banquetDucats = 300
    /// How far apart two stops may be on neighbouring rows and still be joined by a road.
    static let roadReach = 0.51

    private static let showNames = ["Village Green", "Market Square", "Harvest Fair", "Riverside Inn Yard", "Duke's Courtyard",
                                    "Abbey Cloister", "Guild Hall", "Moonlit Bridge", "Lantern Street", "Merchant's Wedding",
                                    "Miller's Barn", "Bishop's Garden", "Fishers' Wharf", "Old Mill Pond", "Castle Gatehouse",
                                    "Weavers' Hall", "Orchard Feast", "Shepherd's Hill"]
    private static let tournamentNames = ["Jousting Lists", "Champion's Field", "Tourney of Fools", "Baron's Challenge",
                                          "Knights' Meadow", "Earl's Tilt-Yard"]
    private static let tavernNames = ["The Gilded Goose", "The Sleeping Bear", "The Three Bells", "The Merry Lute",
                                      "The Crooked Crown", "The Laughing Fox"]

    /// Builds the map for a seed: six rows of two or three stops, then the banquet.
    static func makeMap(seed: UInt64) -> [[TourStop]] {
        var rng = SeededGenerator(seed: seed)
        var names = showNames
        var taverns = tavernNames
        var tourneys = tournamentNames
        var map: [[TourStop]] = []
        for row in 0..<(rows - 1) {
            let columns = row == 0 ? 2 : 2 + Int(rng.next() % 2)
            var kinds: [TourStopKind] = (0..<columns).map { _ in
                let roll = rng.unit()
                if row >= 2, roll < 0.2 { return .tavern }
                if row >= 1, roll < 0.42 { return .tournament }
                return .show
            }
            // A tavern halfway, and never a row with only taverns.
            if row == 3, !kinds.contains(.tavern) { kinds[columns - 1] = .tavern }
            if kinds.allSatisfy({ $0 == .tavern }) { kinds[0] = .show }

            map.append(kinds.enumerated().map { column, kind in
                stop(row: row, column: column, columns: columns, kind: kind, names: &names, taverns: &taverns, tourneys: &tourneys, rng: &rng)
            })
        }
        map.append([stop(row: rows - 1, column: 0, columns: 1, kind: .banquet, names: &names, taverns: &taverns, tourneys: &tourneys, rng: &rng)])
        return map
    }

    private static func stop(row: Int, column: Int, columns: Int, kind: TourStopKind, names: inout [String],
                             taverns: inout [String], tourneys: inout [String], rng: inout SeededGenerator) -> TourStop {
        let depth = row
        switch kind {
        case .show:
            let name = names.isEmpty ? "Roadside Stage \(row + 1)-\(column + 1)" : names.remove(at: Int(rng.next() % UInt64(names.count)))
            let maxGems = min(6, 3 + (depth + 1) / 2)
            var goals: [ActGoal] = [
                .bank(5 + depth * 2),
                .score(400 + depth * 250),
                .crowns(2 + depth / 2),
                .survive(seconds: 45 + depth * 10),
                .airborne(min(maxGems, 3 + depth / 2)),
            ]
            // An unbroken banking streak is near impossible once the air is crowded.
            if depth < 4 { goals.append(.cleanBanks(3 + depth)) }
            let goal = goals[Int(rng.next() % UInt64(goals.count))]
            let decreeCount = depth == 0 ? 0 : depth < 3 ? 1 : 2
            return TourStop(row: row, column: column, columns: columns, kind: kind, name: name, goal: goal, maxGems: maxGems,
                            decrees: pick(decreeCount, from: Decree.allCases, rng: &rng), jokers: depth >= 2)
        case .tournament:
            let name = tourneys.isEmpty ? "Grand Melee \(row + 1)-\(column + 1)" : tourneys.remove(at: Int(rng.next() % UInt64(tourneys.count)))
            return TourStop(row: row, column: column, columns: columns, kind: kind, name: name, goal: .score(800 + depth * 300),
                            maxGems: min(6, 4 + depth / 2), decrees: Decree.allCases, jokers: true)
        case .tavern:
            let name = taverns.isEmpty ? "Roadside Inn \(row + 1)-\(column + 1)" : taverns.remove(at: Int(rng.next() % UInt64(taverns.count)))
            return TourStop(row: row, column: column, columns: columns, kind: kind, name: name, goal: nil, maxGems: 0, decrees: [], jokers: false)
        case .banquet:
            return TourStop(row: row, column: column, columns: columns, kind: kind, name: "The King's Banquet", goal: .score(3000),
                            maxGems: 6, decrees: Decree.allCases, jokers: true)
        }
    }

    /// `count` distinct items in a seeded order.
    private static func pick<T>(_ count: Int, from items: [T], rng: inout SeededGenerator) -> [T] {
        var pool = items
        var result: [T] = []
        while result.count < count, !pool.isEmpty {
            result.append(pool.remove(at: Int(rng.next() % UInt64(pool.count))))
        }
        return result
    }

    /// Three cards to choose from after clearing a stop. A Tournament always deals a rare one.
    static func offer(for kind: TourStopKind, excluding held: [TourCard], seed: UInt64) -> [TourCard] {
        var rng = SeededGenerator(seed: seed)
        var commons = TourCard.allCases.filter { !$0.isRare && !held.contains($0) }
        var rares = TourCard.allCases.filter { $0.isRare && !held.contains($0) }
        var result: [TourCard] = []
        if kind == .tournament || kind == .banquet || rng.unit() < 0.3, !rares.isEmpty {
            result.append(rares.remove(at: Int(rng.next() % UInt64(rares.count))))
        }
        while result.count < 3, !(commons.isEmpty && rares.isEmpty) {
            if !commons.isEmpty {
                result.append(commons.remove(at: Int(rng.next() % UInt64(commons.count))))
            } else {
                result.append(rares.remove(at: Int(rng.next() % UInt64(rares.count))))
            }
        }
        return result
    }
}

// MARK: - Tour state

/// One Royal Tour in progress (or just finished), saved with the profile.
struct TourState: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case active
        case won
        case lost
    }

    let seed: UInt64
    let rows: [[TourStop]]
    /// The last stop cleared; nil before the first.
    var current: TourStop?
    var clearedIDs: [String] = []
    /// Bells carried from stop to stop.
    var bells: Int
    var cards: [TourCard] = []
    /// Cards waiting to be chosen; empty when there is no choice to make.
    var offer: [TourCard] = []
    var status: Status = .active
    var shardsEarned = 0
    var ducatsEarned = 0

    init(seed: UInt64, bells: Int) {
        self.seed = seed
        rows = TourRules.makeMap(seed: seed)
        self.bells = bells
    }

    var modifiers: RunModifiers { RunModifiers(cards: cards) }

    /// Rows cleared so far.
    var depth: Int { current.map { $0.row + 1 } ?? 0 }

    var isActive: Bool { status == .active }

    func maxBells(base: Int) -> Int { base + modifiers.extraBells }

    func isCleared(_ stop: TourStop) -> Bool { clearedIDs.contains(stop.id) }

    /// Whether a road joins two stops on neighbouring rows.
    static func isRoad(from a: TourStop, to b: TourStop) -> Bool {
        b.row == a.row + 1 && abs(b.position - a.position) <= TourRules.roadReach
    }

    /// Stops in the next row a road leads to from `stop`.
    func roads(from stop: TourStop) -> [TourStop] {
        guard rows.indices.contains(stop.row + 1) else { return [] }
        return rows[stop.row + 1].filter { Self.isRoad(from: stop, to: $0) }
    }

    /// Where the jester may go next.
    var reachable: [TourStop] {
        guard isActive, offer.isEmpty else { return [] }
        guard let current else { return rows.first ?? [] }
        return roads(from: current)
    }

    func isReachable(_ stop: TourStop) -> Bool { reachable.contains(stop) }

    /// Seed for the offer after the n-th cleared stop, so a tour replays the same deal.
    var offerSeed: UInt64 { seed &+ UInt64(clearedIDs.count) &* 0x9E37_79B9_7F4A_7C15 }
}
