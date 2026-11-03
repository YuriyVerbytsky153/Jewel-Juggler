import Foundation

/// Jester costumes in the Wardrobe. Each one carries a passive perk that bends one rule of the act.
enum Costume: String, CaseIterable, Identifiable, Codable, Sendable {
    case motley
    case moonlitFool
    case saffronSprite
    case tidewaterMime
    case emberHarlequin
    case velvetHerald
    case starlitJoker

    static let starter: Costume = .motley

    var id: String { rawValue }

    var name: String {
        switch self {
        case .motley: "Classic Motley"
        case .moonlitFool: "Moonlit Fool"
        case .saffronSprite: "Saffron Sprite"
        case .tidewaterMime: "Tidewater Mime"
        case .emberHarlequin: "Ember Harlequin"
        case .velvetHerald: "Velvet Herald"
        case .starlitJoker: "Starlit Jester"
        }
    }

    var price: Int {
        switch self {
        case .motley: 0
        case .moonlitFool: 600
        case .saffronSprite: 900
        case .tidewaterMime: 1300
        case .emberHarlequin: 1800
        case .velvetHerald: 2400
        case .starlitJoker: 3200
        }
    }

    var perkTitle: String {
        switch self {
        case .motley: "Steady Hands"
        case .moonlitFool: "Moon Chord"
        case .saffronSprite: "Quick Feet"
        case .tidewaterMime: "Tide Glaze"
        case .emberHarlequin: "Ember Tithe"
        case .velvetHerald: "Royal Ear"
        case .starlitJoker: "Harlequin Luck"
        }
    }

    var perkDetail: String {
        switch self {
        case .motley: "No tricks, no frills. Every rule as the court wrote it."
        case .moonlitFool: "An amethyst catch counts twice towards a chord."
        case .saffronSprite: "Moves 20% faster across the stage."
        case .tidewaterMime: "Sapphires survive two extra tosses before cracking apart."
        case .emberHarlequin: "Banked rubies pay double ducats."
        case .velvetHerald: "Decree warnings last 2 s longer and Candle Gust pays ×2."
        case .starlitJoker: "Joker gems appear twice as often and a dropped one costs a single bell."
        }
    }

    /// One-line flavour shown on the wardrobe tag.
    var tagline: String {
        switch self {
        case .motley: "Teal, saffron and a well-worn cap."
        case .moonlitFool: "Stitched from a midnight curtain."
        case .saffronSprite: "Light as a festival kite."
        case .tidewaterMime: "Smells faintly of the harbour."
        case .emberHarlequin: "Warm as the great hall hearth."
        case .velvetHerald: "Once read the king's decrees aloud."
        case .starlitJoker: "Embroidered with the night sky."
        }
    }

    // MARK: - Perk values used by the rules

    var speedMultiplier: Double { self == .saffronSprite ? 1.2 : 1 }

    func chordWeight(for color: GemColor) -> Int {
        self == .moonlitFool && color == .amethyst ? 2 : 1
    }

    func extraTosses(for kind: GemKind) -> Int {
        self == .tidewaterMime && kind == .plain(.sapphire) ? 2 : 0
    }

    func ducatMultiplier(for kind: GemKind) -> Int {
        guard self == .emberHarlequin, kind.color == .ruby else { return 1 }
        return 2
    }

    var decreeWarningBonus: Double { self == .velvetHerald ? 2 : 0 }
    var gustMultiplier: Double { self == .velvetHerald ? 2 : 1.5 }
    var jokerChanceMultiplier: Double { self == .starlitJoker ? 2 : 1 }
}
