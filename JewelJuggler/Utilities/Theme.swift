import SwiftUI

/// The candlelit court palette, fonts and metrics.
enum Theme {
    enum Colors {
        /// Night velvet behind everything.
        static let velvetDeep = Color(red: 0.07, green: 0.06, blue: 0.17)
        static let velvet = Color(red: 0.14, green: 0.12, blue: 0.33)
        static let velvetLight = Color(red: 0.24, green: 0.21, blue: 0.48)
        static let teal = Color(red: 0.11, green: 0.52, blue: 0.51)
        static let tealDeep = Color(red: 0.05, green: 0.31, blue: 0.32)
        static let saffron = Color(red: 0.95, green: 0.70, blue: 0.24)
        static let gold = Color(red: 0.80, green: 0.60, blue: 0.24)
        static let goldDeep = Color(red: 0.52, green: 0.36, blue: 0.12)
        static let ivory = Color(red: 0.97, green: 0.93, blue: 0.84)
        static let parchment = Color(red: 0.93, green: 0.86, blue: 0.71)
        /// Text on parchment and ivory.
        static let ink = Color(red: 0.12, green: 0.09, blue: 0.20)
        static let inkSoft = Color(red: 0.30, green: 0.25, blue: 0.36)
        static let rose = Color(red: 0.80, green: 0.18, blue: 0.27)
        static let candle = Color(red: 1.0, green: 0.86, blue: 0.55)

        static func gem(_ color: GemColor) -> Color {
            switch color {
            case .ruby: Color(red: 0.86, green: 0.15, blue: 0.24)
            case .sapphire: Color(red: 0.18, green: 0.42, blue: 0.92)
            case .emerald: Color(red: 0.12, green: 0.70, blue: 0.42)
            case .topaz: Color(red: 0.98, green: 0.72, blue: 0.16)
            case .amethyst: Color(red: 0.62, green: 0.36, blue: 0.88)
            }
        }
    }

    enum Metrics {
        static let maxContentWidth: CGFloat = 720
        static let corner: CGFloat = 18
        static let minTarget: CGFloat = 44
    }
}

extension Font {
    /// Engraved display face used for titles and buttons.
    static func engraved(_ size: CGFloat, relativeTo style: TextStyle = .title) -> Font {
        .custom("Copperplate-Bold", size: size, relativeTo: style)
    }

    static func engravedLight(_ size: CGFloat, relativeTo style: TextStyle = .title3) -> Font {
        .custom("Copperplate", size: size, relativeTo: style)
    }

    /// Body face.
    static func court(_ style: TextStyle, weight: Weight = .regular) -> Font {
        let size: CGFloat
        switch style {
        case .largeTitle: size = 34
        case .title: size = 28
        case .title2: size = 22
        case .title3: size = 20
        case .headline: size = 17
        case .subheadline: size = 15
        case .footnote: size = 13
        case .caption: size = 12
        case .caption2: size = 11
        default: size = 17
        }
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "AvenirNext-Bold"
        case .semibold: name = "AvenirNext-DemiBold"
        case .medium: name = "AvenirNext-Medium"
        default: name = "AvenirNext-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
    }
}
