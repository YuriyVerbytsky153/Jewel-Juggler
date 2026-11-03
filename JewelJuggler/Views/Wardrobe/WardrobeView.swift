import SwiftUI

/// The Wardrobe: costumes hang on a brass rail; the focused one shows its perk tag.
struct WardrobeView: View {
    @State private var viewModel: WardrobeViewModel
    let onBack: () -> Void
    @State private var scrolledID: Costume?

    init(viewModel: WardrobeViewModel, onBack: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            CourtHeader(title: "Wardrobe", ducats: viewModel.ducats, onBack: onBack)
            ScrollView {
                VStack(spacing: 16) {
                    rack
                    detail
                        .frame(maxWidth: 520)
                        .padding(.horizontal, 18)
                }
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .tiled(Art.Tile.velvet)
        .toast($viewModel.toast)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Wardrobe.screen)
        .onAppear { scrolledID = viewModel.focused }
        .onChange(of: scrolledID) { _, new in
            if let new { viewModel.focused = new }
        }
    }

    private var rack: some View {
        GeometryReader { proxy in
        ZStack(alignment: .top) {
            Image(Art.rackRod)
                .resizable(capInsets: EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30), resizingMode: .stretch)
                .frame(height: 30)
                .padding(.top, 8)
                .accessibilityHidden(true)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Costume.allCases) { costume in
                        hanger(costume)
                            .id(costume)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledID, anchor: .center)
            // Centre the focused hanger: half the screen minus half a hanger on each side.
            .safeAreaPadding(.horizontal, max(0, (proxy.size.width - 140) / 2))
        }
        }
        .frame(height: 330)
    }

    private func hanger(_ costume: Costume) -> some View {
        let isFocused = viewModel.focused == costume
        let owned = viewModel.owns(costume)
        return Button {
            withAnimation(.spring(duration: 0.35)) {
                viewModel.focused = costume
                scrolledID = costume
            }
        } label: {
            VStack(spacing: 0) {
                // Hook and hanger bar drawn in SwiftUI so they line up with the rail.
                Path { path in
                    path.move(to: CGPoint(x: 70, y: 22))
                    path.addCurve(to: CGPoint(x: 70, y: 8), control1: CGPoint(x: 82, y: 22), control2: CGPoint(x: 82, y: 6))
                    path.move(to: CGPoint(x: 70, y: 22))
                    path.addLine(to: CGPoint(x: 70, y: 34))
                    path.move(to: CGPoint(x: 26, y: 50))
                    path.addLine(to: CGPoint(x: 70, y: 34))
                    path.addLine(to: CGPoint(x: 114, y: 50))
                }
                .stroke(Theme.Colors.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 140, height: 52)
                Image(Art.jester(costume))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 190)
                    .saturation(owned ? 1 : 0.55)
                    .brightness(owned ? 0 : -0.12)
                    .overlay(alignment: .topTrailing) {
                        if !owned {
                            Image(Art.lock).resizable().scaledToFit().frame(width: 34, height: 34)
                        }
                    }
                Text(costume.name)
                    .font(.engraved(14, relativeTo: .caption))
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background {
                        Image(Art.Panel.scroll)
                            .resizable(capInsets: PanelInsets.scroll, resizingMode: .stretch)
                    }
                    .padding(.top, 6)
                Group {
                    if viewModel.worn == costume {
                        Text("Wearing")
                    } else if owned {
                        Text("Owned")
                    } else {
                        Text("\(Formatters.integer(costume.price)) ducats")
                    }
                }
                .font(.court(.caption, weight: .bold))
                .foregroundStyle(Theme.Colors.ivory)
                .padding(.top, 4)
            }
            .frame(width: 140)
            .scaleEffect(isFocused ? 1 : 0.86)
            .opacity(isFocused ? 1 : 0.8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(costume.name)
        .accessibilityValue(viewModel.worn == costume ? "Wearing" : owned ? "Owned" : "\(costume.price) ducats")
        .accessibilityIdentifier(AccessibilityID.Wardrobe.costume(costume))
    }

    private var detail: some View {
        let costume = viewModel.focused
        return VStack(spacing: 12) {
            Text(costume.tagline)
                .font(.court(.subheadline, weight: .medium))
                .italic()
                .foregroundStyle(Theme.Colors.inkSoft)
                .multilineTextAlignment(.center)
            VStack(spacing: 4) {
                Text("Perk · \(costume.perkTitle)")
                    .font(.engraved(18, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.ink)
                Text(costume.perkDetail)
                    .font(.court(.body, weight: .medium))
                    .foregroundStyle(Theme.Colors.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.Wardrobe.perk)
            actionButton
        }
        .parchmentPanel(padding: 22)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch viewModel.action {
        case .wearing:
            HStack(spacing: 8) {
                Image(Art.rosetteEarned).resizable().scaledToFit().frame(width: 30, height: 30)
                Text("Wearing")
                    .font(.engraved(20, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.tealDeep)
            }
            .frame(minHeight: 56)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Wearing")
            .accessibilityIdentifier(AccessibilityID.Wardrobe.action)
        case .wear:
            Button("Wear this costume") { viewModel.performAction() }
                .buttonStyle(CourtButtonStyle(kind: .teal, size: 20))
                .accessibilityIdentifier(AccessibilityID.Wardrobe.action)
        case .buy(let price):
            Button {
                viewModel.performAction()
            } label: {
                HStack(spacing: 8) {
                    Text("Buy for")
                    Image(Art.ducat).resizable().scaledToFit().frame(width: 24, height: 24)
                    Text(Formatters.integer(price))
                }
            }
            .buttonStyle(CourtButtonStyle(kind: .gold, size: 20))
            .accessibilityLabel("Buy for \(price) ducats")
            .accessibilityIdentifier(AccessibilityID.Wardrobe.action)
        }
    }
}
