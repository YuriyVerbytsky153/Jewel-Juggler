import SwiftUI

// MARK: - Environment

extension EnvironmentValues {
    /// True under UI tests: decorative animations stay still so XCUITest can reach idle.
    @Entry var calmDecor: Bool = false
}

// MARK: - Panels

/// 9-slice insets of the generated panels, in points.
enum PanelInsets {
    static let parchment = EdgeInsets(top: 34, leading: 34, bottom: 34, trailing: 34)
    static let velvet = EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30)
    static let poster = EdgeInsets(top: 30, leading: 26, bottom: 30, trailing: 26)
    static let scroll = EdgeInsets(top: 22, leading: 40, bottom: 22, trailing: 40)
    static let ribbon = EdgeInsets(top: 20, leading: 46, bottom: 20, trailing: 46)
    static let button = EdgeInsets(top: 20, leading: 26, bottom: 20, trailing: 26)
}

extension View {
    /// Places content on a stretchable parchment sheet with ink-friendly contrast.
    func parchmentPanel(padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .background {
                Image(Art.Panel.parchment)
                    .resizable(capInsets: PanelInsets.parchment, resizingMode: .stretch)
            }
    }

    func velvetPanel(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background {
                Image(Art.Panel.velvet)
                    .resizable(capInsets: PanelInsets.velvet, resizingMode: .stretch)
            }
    }

    /// A full-bleed bitmap behind the view that never widens the layout.
    func fullBleed(_ image: String, alignment: Alignment = .center) -> some View {
        background {
            GeometryReader { proxy in
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: alignment)
                    .clipped()
            }
            .ignoresSafeArea()
        }
    }

    /// A repeating texture behind the view.
    func tiled(_ image: String) -> some View {
        background {
            Image(image)
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Buttons

/// Gilded, teal or plum lacquer buttons drawn from the generated plates.
struct CourtButtonStyle: ButtonStyle {
    enum Kind {
        case gold, teal, plum

        var image: String {
            switch self {
            case .gold: Art.Panel.gold
            case .teal: Art.Panel.teal
            case .plum: Art.Panel.plum
            }
        }

        var text: Color {
            switch self {
            case .gold: Theme.Colors.ink
            case .teal, .plum: Theme.Colors.ivory
            }
        }
    }

    var kind: Kind = .gold
    var size: CGFloat = 20
    var minHeight: CGFloat = 56
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.engraved(size, relativeTo: .headline))
            .foregroundStyle(kind.text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 24)
            .frame(minHeight: minHeight)
            .background {
                Image(kind.image)
                    .resizable(capInsets: PanelInsets.button, resizingMode: .stretch)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .saturation(isEnabled ? 1 : 0.2)
            .opacity(isEnabled ? 1 : 0.7)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// A round brass medallion (back, pause, settings, help).
struct MedallionButton: View {
    let image: String
    let label: String
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .frame(minWidth: Theme.Metrics.minTarget, minHeight: Theme.Metrics.minTarget)
        .contentShape(Circle())
        .accessibilityLabel(label)
    }
}

// MARK: - Badges

/// Ducat count on a small velvet purse.
struct DucatBadge: View {
    let amount: Int
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Image(Art.ducat)
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
            Text(Formatters.integer(amount))
                .font(.engraved(compact ? 16 : 19, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.saffron)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.Colors.velvetDeep.opacity(0.88)))
        .overlay(Capsule().strokeBorder(Theme.Colors.gold.opacity(0.85), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Formatters.integer(amount)) ducats")
    }
}

/// A row of five tassels showing a prop's level.
struct TasselRow: View {
    let level: Int
    var maxLevel = UpgradeKind.maxLevel
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<maxLevel, id: \.self) { index in
                Image(index < level ? Art.tasselOn : Art.tasselOff)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size * 1.6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level) of \(maxLevel)")
    }
}

/// A rose rating 0...3 for acts.
struct RoseRow: View {
    let roses: Int
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(index < roses ? Art.rose : Art.roseEmpty)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(roses) of 3 roses")
    }
}

// MARK: - Header

/// Back medallion, a gilded title ribbon and the purse.
struct CourtHeader: View {
    let title: String
    var ducats: Int?
    var shards: Int?
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.engraved(22, relativeTo: .title2))
                .foregroundStyle(Theme.Colors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 30)
                .padding(.vertical, 8)
                .background {
                    Image(Art.Panel.ribbon)
                        .resizable(capInsets: PanelInsets.ribbon, resizingMode: .stretch)
                }
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, ducats == nil && shards == nil ? 56 : 110)
            HStack {
                MedallionButton(image: Art.Medallion.back, label: "Back", action: onBack)
                    .accessibilityIdentifier(AccessibilityID.Common.back)
                Spacer()
                if let ducats { DucatBadge(amount: ducats, compact: true) }
                if let shards {
                    ShardBadge(amount: shards, compact: true)
                        .accessibilityIdentifier(AccessibilityID.Workshop.shards)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}

// MARK: - Toggle

/// A lacquered switch whose off state stays visible on parchment.
struct CourtToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer(minLength: 12)
                Capsule()
                    .fill(configuration.isOn ? Theme.Colors.teal : Theme.Colors.inkSoft.opacity(0.35))
                    .overlay(Capsule().strokeBorder(Theme.Colors.ink.opacity(0.6), lineWidth: 1.5))
                    .frame(width: 54, height: 32)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Theme.Colors.ivory)
                            .overlay(Circle().strokeBorder(Theme.Colors.goldDeep, lineWidth: 1.5))
                            .padding(3)
                    }
                    .animation(.spring(duration: 0.25), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

// MARK: - Toast

struct Toast: Equatable, Identifiable {
    enum Style { case info, success, warning }
    let id = UUID()
    let message: String
    var style: Style = .info
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        Text(toast.message)
            .font(.court(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.Colors.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                Image(Art.Panel.scroll)
                    .resizable(capInsets: PanelInsets.scroll, resizingMode: .stretch)
            }
            .overlay(alignment: .leading) {
                Circle()
                    .fill(toast.style == .warning ? Theme.Colors.rose : toast.style == .success ? Theme.Colors.teal : Theme.Colors.gold)
                    .frame(width: 8, height: 8)
                    .padding(.leading, 12)
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(toast.message)
            .accessibilityIdentifier(AccessibilityID.Common.toast)
    }
}

extension View {
    /// Shows a toast at the bottom for a couple of seconds.
    func toast(_ toast: Binding<Toast?>) -> some View {
        overlay(alignment: .bottom) {
            if let current = toast.wrappedValue {
                ToastView(toast: current)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: current.id) {
                        try? await Task.sleep(for: .seconds(2.4))
                        if toast.wrappedValue?.id == current.id {
                            withAnimation(.easeInOut(duration: 0.25)) { toast.wrappedValue = nil }
                        }
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: toast.wrappedValue)
    }
}

// MARK: - Art icon

/// A generated bitmap on a tinted disc, for rows on light parchment.
struct ArtIcon: View {
    let image: String
    var size: CGFloat = 52
    var tint: Color = Theme.Colors.velvet

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .padding(size * 0.12)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.opacity(0.92)))
            .overlay(Circle().strokeBorder(Theme.Colors.gold, lineWidth: 2))
            .accessibilityHidden(true)
    }
}

// MARK: - Candlelight

/// Drifting warm motes over the velvet, drawn with Canvas.
struct CandleMotes: View {
    var count = 26
    @Environment(\.calmDecor) private var calm

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: calm)) { timeline in
            Canvas { context, size in
                let t = calm ? 0 : timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<count {
                    var g = SeededGenerator(seed: UInt64(index + 7) &* 2_654_435_761)
                    let speed = g.value(in: 0.012...0.035)
                    let phase = g.unit()
                    let progress = (phase + t * speed).truncatingRemainder(dividingBy: 1)
                    let x = size.width * g.unit() + sin(t * g.value(in: 0.3...0.9) + Double(index)) * 14
                    let y = size.height * (1 - progress)
                    let radius = g.value(in: 1.2...3.2)
                    let alpha = sin(progress * .pi) * 0.7
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                                 with: .color(Theme.Colors.candle.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
