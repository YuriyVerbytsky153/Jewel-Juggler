import SwiftUI

/// The season's programme: fifteen numbered acts, each with a goal and up to three roses.
struct ActsView: View {
    @State private var viewModel: ActsViewModel
    let onBack: () -> Void
    let onPerform: (RunMode) -> Void

    init(viewModel: ActsViewModel, onBack: @escaping () -> Void, onPerform: @escaping (RunMode) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onBack = onBack
        self.onPerform = onPerform
    }

    var body: some View {
        VStack(spacing: 0) {
            CourtHeader(title: "Acts", onBack: onBack)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Text("The Season's Programme")
                                .font(.engraved(22, relativeTo: .title2))
                                .foregroundStyle(Theme.Colors.ink)
                            HStack(spacing: 6) {
                                Image(Art.rose).resizable().scaledToFit().frame(width: 22, height: 22)
                                Text("\(viewModel.totalRoses) of \(viewModel.maxRoses) roses")
                                    .font(.court(.subheadline, weight: .bold))
                                    .foregroundStyle(Theme.Colors.inkSoft)
                            }
                            Text("Earn a rose to open the next act. Three roses: no bell lost. Two: at most one.")
                                .font(.court(.footnote, weight: .medium))
                                .foregroundStyle(Theme.Colors.inkSoft)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 10)
                        ForEach(viewModel.acts) { act in
                            row(act)
                                .id(act.index)
                            if act.index < viewModel.acts.count - 1 {
                                Rectangle()
                                    .fill(Theme.Colors.gold.opacity(0.5))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .parchmentPanel(padding: 22)
                    .frame(maxWidth: 560)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onAppear { reader.scrollTo(viewModel.nextIndex, anchor: .center) }
            }
        }
        .tiled(Art.Tile.velvet)
        .toast($viewModel.toast)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Acts.screen)
    }

    private func row(_ act: Act) -> some View {
        let unlocked = viewModel.isUnlocked(act)
        let roses = viewModel.roses(act)
        let isNext = act.index == viewModel.nextIndex
        return Button {
            if let mode = viewModel.request(act) { onPerform(mode) }
        } label: {
            HStack(spacing: 12) {
                Text(RomanNumeral.string(act.number))
                    .font(.engraved(20, relativeTo: .title3))
                    .foregroundStyle(unlocked ? Theme.Colors.rose : Theme.Colors.inkSoft)
                    .frame(width: 52, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(act.name)
                        .font(.engraved(17, relativeTo: .headline))
                        .foregroundStyle(Theme.Colors.ink)
                    Text(act.goal.text)
                        .font(.court(.footnote, weight: .medium))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if !act.decrees.isEmpty || act.jokers {
                        HStack(spacing: 4) {
                            ForEach(act.decrees, id: \.self) { decree in
                                Image(Art.decree(decree)).resizable().scaledToFit().frame(width: 20, height: 20)
                            }
                            if act.jokers {
                                Image(Art.joker).resizable().scaledToFit().frame(width: 18, height: 18)
                            }
                            Text(extrasText(act))
                                .font(.court(.caption2, weight: .semibold))
                                .foregroundStyle(Theme.Colors.inkSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                Spacer(minLength: 6)
                if unlocked {
                    VStack(spacing: 4) {
                        RoseRow(roses: roses, size: 18)
                        if isNext {
                            Text("Next")
                                .font(.court(.caption2, weight: .bold))
                                .foregroundStyle(Theme.Colors.ivory)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.Colors.teal))
                        }
                    }
                } else {
                    Image(Art.lock).resizable().scaledToFit().frame(width: 30, height: 30)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .opacity(unlocked ? 1 : 0.78)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Act \(act.number), \(act.name). \(act.goal.text). \(extrasText(act))")
        .accessibilityValue(unlocked ? "\(roses) of 3 roses" : "Locked")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(AccessibilityID.Acts.act(act.index))
    }
}

extension ActsView {
    /// Names the decrees and the Joker that appear in an act.
    func extrasText(_ act: Act) -> String {
        var parts = act.decrees.count == Decree.allCases.count ? ["All decrees"] : act.decrees.map(\.title)
        if act.jokers { parts.append("Jokers") }
        return parts.joined(separator: " · ")
    }
}

enum RomanNumeral {
    static func string(_ value: Int) -> String {
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var remaining = value
        var result = ""
        for (number, numeral) in table {
            while remaining >= number {
                result += numeral
                remaining -= number
            }
        }
        return result
    }
}
