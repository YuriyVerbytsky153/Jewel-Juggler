import SwiftUI

/// The Jeweller's Workshop: shards from broken gems are cut into enchanted settings.
/// Enchantments set in the jewel case now and then turn up as special gems in every show.
struct WorkshopView: View {
    @State private var viewModel: WorkshopViewModel
    let onBack: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(viewModel: WorkshopViewModel, onBack: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            CourtHeader(title: "Workshop", shards: viewModel.shards, onBack: onBack)
            ScrollView {
                VStack(spacing: 14) {
                    Text("Shattered gems and banked crowns leave shards behind. The Royal Tour pays in shards too.")
                        .font(.court(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.Colors.ivory)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Colors.velvetDeep.opacity(0.8)))
                    jewelCase
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 3 : 2), spacing: 12) {
                        ForEach(Enchantment.allCases) { enchantment in
                            bench(enchantment)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: Theme.Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .tiled(Art.Tile.wood)
        .toast($viewModel.toast)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Workshop.screen)
    }

    // MARK: - Jewel case

    private var jewelCase: some View {
        VStack(spacing: 10) {
            Text("Jewel Case")
                .font(.engraved(18, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.saffron)
            HStack(spacing: 14) {
                ForEach(0..<JewelCase.maxSlots, id: \.self) { slot in
                    socket(slot)
                }
            }
            Text("About one gem in seven is enchanted once the show warms up.")
                .font(.court(.caption, weight: .medium))
                .foregroundStyle(Theme.Colors.ivory)
                .multilineTextAlignment(.center)
            if let price = viewModel.nextSlotPrice {
                Button {
                    viewModel.buySlot()
                } label: {
                    HStack(spacing: 6) {
                        Text("Fit a setting")
                        Image(systemName: "rhombus.fill").font(.system(size: 13, weight: .bold))
                        Text(Formatters.integer(price))
                    }
                }
                .buttonStyle(CourtButtonStyle(kind: viewModel.canAfford(price) ? .gold : .teal, size: 16, minHeight: 46))
                .accessibilityLabel("Fit another setting for \(price) shards")
                .accessibilityIdentifier(AccessibilityID.Workshop.buySlot)
            }
        }
        .frame(maxWidth: .infinity)
        .velvetPanel(padding: 18)
    }

    private func socket(_ slot: Int) -> some View {
        let isOpen = slot < viewModel.slots
        let enchantment = slot < viewModel.equipped.count ? viewModel.equipped[slot] : nil
        return ZStack {
            Circle()
                .fill(Theme.Colors.velvetDeep)
                .overlay(Circle().strokeBorder(isOpen ? Theme.Colors.saffron : Theme.Colors.gold.opacity(0.35), lineWidth: 2.5))
            if let enchantment {
                EnchantedGemIcon(enchantment: enchantment, size: 44)
            } else if !isOpen {
                Image(Art.lock).resizable().scaledToFit().frame(width: 26, height: 26).opacity(0.7)
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(enchantment.map { "Setting \(slot + 1): \($0.title)" } ?? (isOpen ? "Setting \(slot + 1): empty" : "Setting \(slot + 1): not fitted"))
    }

    // MARK: - Enchantments

    private func bench(_ enchantment: Enchantment) -> some View {
        let action = viewModel.action(for: enchantment)
        let owned = viewModel.owns(enchantment)
        return VStack(spacing: 8) {
            EnchantedGemIcon(enchantment: enchantment, size: 62)
                .saturation(owned ? 1 : 0.55)
                .accessibilityHidden(true)
            Text(enchantment.title)
                .font(.engraved(15, relativeTo: .headline))
                .foregroundStyle(Theme.Colors.saffron)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(enchantment.detail)
                .font(.court(.caption, weight: .medium))
                .foregroundStyle(Theme.Colors.ivory)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: .infinity, alignment: .top)
            Button {
                viewModel.perform(enchantment)
            } label: {
                switch action {
                case .cut(let price):
                    HStack(spacing: 4) {
                        Image(systemName: "rhombus.fill").font(.system(size: 13, weight: .bold))
                        Text(Formatters.integer(price))
                    }
                case .wear:
                    Text("Set in case")
                case .remove:
                    Text("Take out")
                }
            }
            .buttonStyle(CourtButtonStyle(kind: buttonKind(action), size: 16, minHeight: 46))
            .accessibilityLabel(accessibilityText(action, enchantment))
            .accessibilityIdentifier(AccessibilityID.Workshop.action(enchantment))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .velvetPanel(padding: 16)
        .accessibilityElement(children: .contain)
    }

    private func buttonKind(_ action: WorkshopViewModel.Action) -> CourtButtonStyle.Kind {
        switch action {
        case .cut(let price): viewModel.canAfford(price) ? .gold : .teal
        case .wear: .gold
        case .remove: .plum
        }
    }

    private func accessibilityText(_ action: WorkshopViewModel.Action, _ enchantment: Enchantment) -> String {
        switch action {
        case .cut(let price): "Cut \(enchantment.title) for \(price) shards"
        case .wear: "Set \(enchantment.title) in the jewel case"
        case .remove: "Take \(enchantment.title) out of the jewel case"
        }
    }
}
