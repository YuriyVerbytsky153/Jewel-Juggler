import Foundation

/// Props in the Prop Trunk. Each has five levels bought with ducats.
enum UpgradeKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case velvetGloves
    case silkSleeves
    case silverBells
    case courtFavor
    case lanternOil
    case jingleCharm

    static let maxLevel = 5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .velvetGloves: "Velvet Gloves"
        case .silkSleeves: "Silk Sleeves"
        case .silverBells: "Silver Bells"
        case .courtFavor: "Court Favour"
        case .lanternOil: "Lantern Oil"
        case .jingleCharm: "Jingle Charm"
        }
    }

    var detail: String {
        switch self {
        case .velvetGloves: "Wider hands catch gems further from the centre."
        case .silkSleeves: "Gems survive one more toss before they crack apart (levels 2 and 4)."
        case .silverBells: "One more bell on the cap (levels 1 and 3). The fifth level makes the first dropped gem free."
        case .courtFavor: "Each Encore lasts longer."
        case .lanternOil: "The hall stays brighter during a Candle Gust."
        case .jingleCharm: "Fewer sweet-spot catches to charge the Jingle."
        }
    }

    /// Price of buying `level` (1...5). `nil` past the maximum.
    func cost(forLevel level: Int) -> Int? {
        guard (1...Self.maxLevel).contains(level) else { return nil }
        let base: Int
        switch self {
        case .velvetGloves: base = 140
        case .silkSleeves: base = 180
        case .silverBells: base = 220
        case .courtFavor: base = 120
        case .lanternOil: base = 100
        case .jingleCharm: base = 130
        }
        // 1x, 2.2x, 3.8x, 5.8x, 8.2x of the base, rounded to tens.
        let factors = [1.0, 2.2, 3.8, 5.8, 8.2]
        return Int((Double(base) * factors[level - 1] / 10).rounded()) * 10
    }

    /// Short description of what the current level gives, e.g. "+12% reach".
    func effectText(level: Int) -> String {
        let stats = Loadout(levels: [self: level], costume: .motley)
        switch self {
        case .velvetGloves: return "Reach \(Int((stats.catchHalfWidth / Loadout.baseCatchHalfWidth * 100).rounded()))%"
        case .silkSleeves: return "\(stats.tossLimit) tosses"
        case .silverBells: return level >= 5 ? "\(stats.bells) bells + grace" : "\(stats.bells) bells"
        case .courtFavor: return String(format: "%.0f s Encore", stats.encoreDuration)
        case .lanternOil: return "\(Int(((1 - stats.gustDarkness) * 100).rounded()))% light"
        case .jingleCharm: return "\(stats.jingleCharges) catches"
        }
    }
}

/// Everything the profile contributes to a run: prop levels and the worn costume.
struct Loadout: Equatable, Sendable {
    var levels: [UpgradeKind: Int]
    var costume: Costume

    static let baseCatchHalfWidth = 0.08

    static let standard = Loadout(levels: [:], costume: .motley)

    func level(_ kind: UpgradeKind) -> Int { min(UpgradeKind.maxLevel, max(0, levels[kind] ?? 0)) }

    var catchHalfWidth: Double { Self.baseCatchHalfWidth * (1 + 0.06 * Double(level(.velvetGloves))) }
    /// Tosses a gem survives. A catch past this limit shatters it.
    var tossLimit: Int { 3 + (level(.silkSleeves) >= 2 ? 1 : 0) + (level(.silkSleeves) >= 4 ? 1 : 0) }
    var bells: Int { 3 + (level(.silverBells) >= 1 ? 1 : 0) + (level(.silverBells) >= 3 ? 1 : 0) }
    /// Silver Bells V forgives the first dropped gem.
    var hasGrace: Bool { level(.silverBells) >= 5 }
    var encoreDuration: Double { 8 + 1.5 * Double(level(.courtFavor)) }
    var gustDarkness: Double { 0.78 - 0.1 * Double(level(.lanternOil)) }
    var jingleCharges: Int { 7 - level(.jingleCharm) }
}
