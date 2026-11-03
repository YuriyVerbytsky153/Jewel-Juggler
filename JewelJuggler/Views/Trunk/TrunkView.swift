import SwiftUI

/// The Prop Trunk: an open wooden chest with velvet-lined compartments, one prop in each.
struct TrunkView: View {
    @State private var viewModel: TrunkViewModel
    let onBack: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(viewModel: TrunkViewModel, onBack: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            CourtHeader(title: "Prop Trunk", ducats: viewModel.ducats, onBack: onBack)
            ScrollView {
                VStack(spacing: 14) {
                    Text("Every prop has five tassels. Ducats come only from gems you bank in the chest.")
                        .font(.court(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.Colors.ivory)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Colors.velvetDeep.opacity(0.8)))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 3 : 2), spacing: 12) {
                        ForEach(UpgradeKind.allCases) { kind in
                            compartment(kind)
                        }
                    }
                }
                .padding(14)
                .background {
                    // The trunk's inner rim.
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(LinearGradient(colors: [Theme.Colors.saffron, Theme.Colors.goldDeep], startPoint: .top, endPoint: .bottom), lineWidth: 5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: Theme.Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .tiled(Art.Tile.wood)
        .toast($viewModel.toast)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Trunk.screen)
    }

    private func compartment(_ kind: UpgradeKind) -> some View {
        let level = viewModel.level(kind)
        let cost = viewModel.cost(kind)
        return VStack(spacing: 8) {
            Image(Art.upgrade(kind))
                .resizable()
                .scaledToFit()
                .frame(height: 74)
                .accessibilityHidden(true)
            Text(kind.title)
                .font(.engraved(15, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.saffron)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(kind.detail)
                .font(.court(.caption, weight: .medium))
                .foregroundStyle(Theme.Colors.ivory)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: .infinity, alignment: .top)
            TasselRow(level: level, size: 14)
                .accessibilityIdentifier(AccessibilityID.Trunk.level(kind))
            Text(kind.effectText(level: level))
                .font(.court(.caption2, weight: .bold))
                .foregroundStyle(Theme.Colors.candle)
            Button {
                viewModel.buy(kind)
            } label: {
                if let cost {
                    HStack(spacing: 4) {
                        Image(Art.ducat).resizable().scaledToFit().frame(width: 18, height: 18)
                        Text(Formatters.integer(cost))
                    }
                } else {
                    Text("Finest")
                }
            }
            .buttonStyle(CourtButtonStyle(kind: cost == nil ? .plum : viewModel.canAfford(kind) ? .gold : .teal, size: 16, minHeight: 46))
            .disabled(cost == nil)
            .accessibilityLabel(cost.map { "Raise \(kind.title) for \($0) ducats" } ?? "\(kind.title) is maxed")
            .accessibilityIdentifier(AccessibilityID.Trunk.buy(kind))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .velvetPanel(padding: 16)
        .accessibilityElement(children: .contain)
    }
}
