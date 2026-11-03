import Foundation

/// Screens pushed from the stage by the tarot fan or the corner medallions.
enum AppRoute: String, Hashable, CaseIterable, Identifiable {
    case wardrobe
    case trunk
    case acts
    case playbills
    case settings
    case guide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wardrobe: "Wardrobe"
        case .trunk: "Prop Trunk"
        case .acts: "Acts"
        case .playbills: "Playbills"
        case .settings: "Settings"
        case .guide: "How to Play"
        }
    }
}

/// A show the root view should present full screen.
struct ShowRequest: Identifiable, Equatable {
    let id = UUID()
    let mode: RunMode
}
