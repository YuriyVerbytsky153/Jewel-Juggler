import Foundation

/// Names of the generated bitmaps in `Assets.xcassets/Generated` (see `Artwork/generate_assets.swift`).
nonisolated enum Art {
    static let logo = "logo"
    static let stageBackdrop = "bg_stage"
    static let ducat = "ducat"
    static let bellOn = "bell_on"
    static let bellOff = "bell_off"
    static let cap = "cap_jingle"
    static let chestClosed = "chest_closed"
    static let chestOpen = "chest_open"
    static let rose = "rose"
    static let roseEmpty = "rose_empty"
    static let tasselOn = "tassel_on"
    static let tasselOff = "tassel_off"
    static let lock = "lock"
    static let crowd = "crowd"
    static let crowdLit = "crowd_lit"
    static let rosetteEarned = "rosette_earned"
    static let rosetteLocked = "rosette_locked"
    static let rackRod = "rack_rod"
    static let tomato = "tomato"
    static let joker = "gem_joker"

    static func hall(_ stage: Int) -> String { "bg_hall_\(min(3, max(0, stage)))" }
    static func gem(_ color: GemColor) -> String { "gem_\(color.rawValue)" }
    static func crown(_ color: GemColor) -> String { "crown_\(color.rawValue)" }
    static func crack(_ stage: Int) -> String { "crack_\(min(3, max(1, stage)))" }
    static func jester(_ costume: Costume, frame: Int = 0) -> String { "jester_\(costume.rawValue)_\(frame)" }
    static func upgrade(_ kind: UpgradeKind) -> String { "up_\(kind.rawValue)" }
    static func decree(_ decree: Decree) -> String { "decree_\(decree.rawValue)" }

    static func sprite(for kind: GemKind) -> String {
        switch kind {
        case .plain(let color): gem(color)
        case .crown(let color): crown(color)
        case .joker: joker
        case .tomato: tomato
        }
    }

    enum Card {
        static let wardrobe = "card_wardrobe"
        static let trunk = "card_trunk"
        static let acts = "card_acts"
        static let playbills = "card_playbills"
        static let back = "card_back"
    }

    enum Panel {
        static let parchment = "panel_parchment"
        static let velvet = "panel_velvet"
        static let poster = "panel_poster"
        static let scroll = "panel_scroll"
        static let ribbon = "ribbon"
        static let gold = "btn_gold"
        static let teal = "btn_teal"
        static let plum = "btn_plum"
    }

    enum Tile {
        static let velvet = "tile_velvet"
        static let wood = "tile_wood"
        static let wall = "tile_wall"
    }

    enum Medallion {
        static let back = "med_back"
        static let pause = "med_pause"
        static let settings = "med_settings"
        static let help = "med_help"
    }

    enum Guide {
        static let move = "guide_move"
        static let toss = "guide_catch"
        static let bank = "guide_bank"
        static let wear = "guide_wear"
        static let chord = "guide_chord"
        static let applause = "guide_applause"
        static let decree = "guide_decree"
        static let joker = "guide_joker"
        static let jingle = "guide_jingle"
    }

    /// Sprites used only inside the SpriteKit scene.
    enum Scene {
        static let floor = "stage_floor"
        static let soft = "p_soft"
        static let spark = "p_spark"
        static let shard = "p_shard"
        static let petal = "p_petal"
        static let juice = "p_juice"
        static let shadow = "shadow_oval"
        static let spotlight = "spotlight"
    }

    /// Every generated name, for the asset smoke test.
    static var allNames: [String] {
        var names = [logo, stageBackdrop, ducat, bellOn, bellOff, cap, chestClosed, chestOpen, rose, roseEmpty,
                     tasselOn, tasselOff, lock, crowd, crowdLit, rosetteEarned, rosetteLocked, rackRod, tomato, joker,
                     Card.wardrobe, Card.trunk, Card.acts, Card.playbills, Card.back,
                     Panel.parchment, Panel.velvet, Panel.poster, Panel.scroll, Panel.ribbon, Panel.gold, Panel.teal, Panel.plum,
                     Tile.velvet, Tile.wood, Tile.wall,
                     Medallion.back, Medallion.pause, Medallion.settings, Medallion.help,
                     Guide.move, Guide.toss, Guide.bank, Guide.wear, Guide.chord, Guide.applause, Guide.decree, Guide.joker, Guide.jingle,
                     Scene.floor, Scene.soft, Scene.spark, Scene.shard, Scene.petal, Scene.juice, Scene.shadow, Scene.spotlight]
        names += (0...3).map(hall)
        names += (1...3).map(crack)
        names += GemColor.allCases.flatMap { [gem($0), crown($0)] }
        names += Costume.allCases.flatMap { [jester($0, frame: 0), jester($0, frame: 1)] }
        names += UpgradeKind.allCases.map(upgrade)
        names += Decree.allCases.map(decree)
        return names
    }
}
