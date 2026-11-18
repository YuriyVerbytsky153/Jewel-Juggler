import Foundation

/// Accessibility identifiers shared with the UI tests (duplicated there as plain strings).
enum AccessibilityID {
    enum Stage {
        static let screen = "stage.screen"
        static let raiseCurtain = "stage.raiseCurtain"
        static let festival = "stage.festival"
        static let ducats = "stage.ducats"
        static let settings = "stage.settings"
        static let guide = "stage.guide"
        static let best = "stage.best"
        static let tour = "stage.tour"
        static func card(_ key: String) -> String { "stage.card.\(key)" }
    }

    enum Common {
        static let back = "common.back"
        static let toast = "toast"
    }

    enum Wardrobe {
        static let screen = "wardrobe.screen"
        static let action = "wardrobe.action"
        static let perk = "wardrobe.perk"
        static func costume(_ costume: Costume) -> String { "wardrobe.costume.\(costume.rawValue)" }
    }

    enum Trunk {
        static let screen = "trunk.screen"
        static func buy(_ kind: UpgradeKind) -> String { "trunk.buy.\(kind.rawValue)" }
        static func level(_ kind: UpgradeKind) -> String { "trunk.level.\(kind.rawValue)" }
    }

    enum Acts {
        static let screen = "acts.screen"
        static func act(_ index: Int) -> String { "acts.act.\(index)" }
    }

    enum Playbills {
        static let screen = "playbills.screen"
        static let stats = "playbills.stats"
        static func rosette(_ id: String) -> String { "playbills.rosette.\(id)" }
    }

    enum Settings {
        static let screen = "settings.screen"
        static let sound = "settings.sound"
        static let music = "settings.music"
        static let haptics = "settings.haptics"
        static let leftHanded = "settings.leftHanded"
        static let reset = "settings.reset"
        static let confirmReset = "settings.confirmReset"
        static let guide = "settings.guide"
    }

    enum Guide {
        static let screen = "guide.screen"
        static let next = "guide.next"
        static let done = "guide.done"
    }

    enum Game {
        static let screen = "game.screen"
        static let begin = "game.begin"
        static let pause = "game.pause"
        static let resume = "game.resume"
        static let quit = "game.quit"
        static let restart = "game.restart"
        static let bank = "game.bank"
        static let jingle = "game.jingle"
        static let score = "game.score"
        static let bells = "game.bells"
        static let applause = "game.applause"
        static let chord = "game.chord"
        static let decree = "game.decree"
        static let goal = "game.goal"
    }

    enum Curtain {
        static let screen = "curtain.screen"
        static let again = "curtain.again"
        static let leave = "curtain.leave"
        static let score = "curtain.score"
        static let ducats = "curtain.ducats"
        static let next = "curtain.next"
        static let shards = "curtain.shards"
        static let tour = "curtain.tour"
        static let map = "curtain.map"
    }

    enum Tour {
        static let screen = "tour.screen"
        static let start = "tour.start"
        static let retire = "tour.retire"
        static let perform = "tour.perform"
        static let bells = "tour.bells"
        static func stop(_ id: String) -> String { "tour.stop.\(id)" }
        static func offer(_ card: TourCard) -> String { "tour.offer.\(card.rawValue)" }
    }

    enum Workshop {
        static let screen = "workshop.screen"
        static let shards = "workshop.shards"
        static let buySlot = "workshop.buySlot"
        static func action(_ enchantment: Enchantment) -> String { "workshop.action.\(enchantment.rawValue)" }
    }
}
