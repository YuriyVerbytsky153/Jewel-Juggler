import Foundation

/// The five gem colours the court throws at the jester.
enum GemColor: String, CaseIterable, Codable, Sendable {
    case ruby, sapphire, emerald, topaz, amethyst

    var title: String { rawValue.capitalized }
}

/// What kind of object is flying over the stage.
enum GemKind: Equatable, Hashable, Sendable {
    /// A plain cut gem of one colour.
    case plain(GemColor)
    /// Three same-colour catches in a row fused into a heavier, valuable crown gem.
    case crown(GemColor)
    /// The harlequin gem: completes any chord, but dropping it costs two bells.
    case joker
    /// Thrown during the Rotten Tomatoes decree. Must be let fall; catching it costs a bell.
    case tomato

    var color: GemColor? {
        switch self {
        case .plain(let color), .crown(let color): color
        case .joker, .tomato: nil
        }
    }

    var isTomato: Bool { self == .tomato }
    var isJoker: Bool { self == .joker }
    var isCrown: Bool {
        if case .crown = self { return true }
        return false
    }

    /// Base points a bank is worth before multipliers.
    var bankValue: Int {
        switch self {
        case .plain: 10
        case .crown: 50
        case .joker: 30
        case .tomato: 0
        }
    }

    /// Crowns are heavier and fall faster.
    var gravityScale: Double {
        switch self {
        case .crown: 1.25
        case .tomato: 0.9
        default: 1
        }
    }

    /// Bells lost if this object hits the floor.
    func dropCost(costume: Costume) -> Int {
        switch self {
        case .tomato: 0
        case .joker: costume == .starlitJoker ? 1 : 2
        default: 1
        }
    }
}

/// One object in flight. Coordinates are normalised: x in 0...1 across the stage, y in 0...1 from floor to ceiling.
struct FlyingGem: Identifiable, Equatable, Sendable {
    let id: Int
    var kind: GemKind
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    /// How many times the jester has tossed it. Each toss deepens the cracks.
    var tosses: Int = 0
    /// Set when the gem was thrown in by the king at the start of an Encore.
    var isEncoreGift = false
    /// A power cut in the Jeweller's Workshop.
    var enchantment: Enchantment?
    /// A Phoenix Opal that has already reformed once.
    var reborn = false

    var isFalling: Bool { vy < 0 }
    /// Joker-like: completes any chord.
    var isWild: Bool { kind.isJoker || enchantment == .prismQuartz }
}
