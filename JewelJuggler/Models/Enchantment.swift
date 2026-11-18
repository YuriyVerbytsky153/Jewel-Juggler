import Foundation

/// Enchanted settings cut in the Jeweller's Workshop. An equipped enchantment now and then
/// turns a plain gem in any show into a gem with a special power.
enum Enchantment: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Falls at a little over half the usual speed.
    case featherstone
    /// Reforms once instead of shattering or hitting the floor.
    case phoenixOpal
    /// Drifts towards the jester's hands while it falls.
    case lodestone
    /// Banking it sweeps every other gem in the air into the chest too.
    case powderGarnet
    /// Fits any chord and always lands on the sweet spot.
    case prismQuartz
    /// Pays triple ducats when banked.
    case midasTopaz

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featherstone: "Featherstone"
        case .phoenixOpal: "Phoenix Opal"
        case .lodestone: "Lodestone"
        case .powderGarnet: "Powder Garnet"
        case .prismQuartz: "Prism Quartz"
        case .midasTopaz: "Midas Topaz"
        }
    }

    var detail: String {
        switch self {
        case .featherstone: "Floats down at little more than half speed."
        case .phoenixOpal: "Once per gem, a shatter or a fall is undone and it flies back up."
        case .lodestone: "Pulled towards your hands as it falls."
        case .powderGarnet: "Bank it and every other gem in the air follows it into the chest."
        case .prismQuartz: "Fits any chord and always counts as a sweet-spot catch."
        case .midasTopaz: "Pays triple ducats when banked."
        }
    }

    /// Shards needed to cut it in the workshop.
    var price: Int {
        switch self {
        case .featherstone: 12
        case .lodestone: 20
        case .prismQuartz: 28
        case .midasTopaz: 36
        case .phoenixOpal: 45
        case .powderGarnet: 60
        }
    }

    /// The gem colour the enchanted gem is cut from.
    var color: GemColor {
        switch self {
        case .featherstone: .emerald
        case .phoenixOpal: .ruby
        case .lodestone: .sapphire
        case .powderGarnet: .ruby
        case .prismQuartz: .amethyst
        case .midasTopaz: .topaz
        }
    }

    /// SF Symbol drawn over the gem so the power reads at a glance.
    var symbol: String {
        switch self {
        case .featherstone: "wind"
        case .phoenixOpal: "flame.fill"
        case .lodestone: "scope"
        case .powderGarnet: "burst.fill"
        case .prismQuartz: "rainbow"
        case .midasTopaz: "sparkles"
        }
    }

    /// Gravity multiplier while it flies.
    var gravityScale: Double { self == .featherstone ? 0.55 : 1 }
}

/// The workshop's jewel case: how many enchantments can be worn at once.
enum JewelCase {
    static let baseSlots = 1
    static let maxSlots = 3
    /// Shards for the second and third slot.
    static func slotPrice(forSlot slot: Int) -> Int? {
        switch slot {
        case 2: 30
        case 3: 70
        default: nil
        }
    }

    /// Chance that a fresh plain gem is enchanted, once at least one enchantment is worn.
    static let spawnChance = 0.14
    /// Enchanted gems only appear after the warm-up.
    static let firstSecond = 8.0
}
