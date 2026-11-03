import SwiftUI

/// The Playbills wall: posters of recent shows, rosettes and a programme of lifetime records.
struct PlaybillsView: View {
    @State private var viewModel: PlaybillsViewModel
    let onBack: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(viewModel: PlaybillsViewModel, onBack: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            CourtHeader(title: "Playbills", onBack: onBack)
            ScrollView {
                VStack(spacing: 22) {
                    posters
                    rosettes
                    records
                }
                .padding(16)
                .frame(maxWidth: Theme.Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .tiled(Art.Tile.wall)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Playbills.screen)
    }

    private func sectionTitle(_ text: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.engraved(19, relativeTo: .title3))
                .foregroundStyle(Theme.Colors.saffron)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.court(.footnote, weight: .bold))
                    .foregroundStyle(Theme.Colors.ivory)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.Colors.velvetDeep.opacity(0.85)))
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Posters

    private var posters: some View {
        VStack(spacing: 10) {
            sectionTitle("Recent shows", detail: viewModel.shows.isEmpty ? nil : "\(viewModel.shows.count) posters")
            if viewModel.shows.isEmpty {
                Text("No posters yet. Raise the curtain and your first show will be pinned here.")
                    .font(.court(.body, weight: .medium))
                    .foregroundStyle(Theme.Colors.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .parchmentPanel(padding: 20)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.shows) { show in
                            poster(show)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func poster(_ show: ShowRecord) -> some View {
        VStack(spacing: 6) {
            Text(show.title)
                .font(.engraved(13, relativeTo: .caption))
                .foregroundStyle(Theme.Colors.rose)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(height: 34)
            Image(Art.jester(show.costume))
                .resizable()
                .scaledToFit()
                .frame(height: 70)
                .accessibilityHidden(true)
            Text(Formatters.integer(show.score))
                .font(.engraved(24, relativeTo: .title2))
                .foregroundStyle(Theme.Colors.ink)
                .monospacedDigit()
            if show.modeKey == "act" {
                RoseRow(roses: show.roses, size: 16)
            } else {
                Text("\(show.banks) banked · \(show.crowns) crowns")
                    .font(.court(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
            Text(Formatters.showDate(show.date))
                .font(.court(.caption2, weight: .medium))
                .foregroundStyle(Theme.Colors.inkSoft)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(width: 150)
        .background {
            Image(Art.Panel.poster)
                .resizable(capInsets: PanelInsets.poster, resizingMode: .stretch)
        }
        .rotationEffect(.degrees(Double((show.score % 5) - 2) * 0.8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(show.title), \(show.score) points, \(Formatters.showDate(show.date))")
    }

    // MARK: - Rosettes

    private var rosettes: some View {
        VStack(spacing: 10) {
            sectionTitle("Rosettes", detail: "\(viewModel.earnedCount) of \(viewModel.achievements.count)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: sizeClass == .regular ? 4 : 3), spacing: 10) {
                ForEach(viewModel.achievements) { achievement in
                    VStack(spacing: 4) {
                        Image(achievement.isEarned ? Art.rosetteEarned : Art.rosetteLocked)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 58, height: 58)
                        Text(achievement.title)
                            .font(.court(.caption, weight: .bold))
                            .foregroundStyle(Theme.Colors.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(achievement.detail)
                            .font(.court(.caption2, weight: .medium))
                            .foregroundStyle(Theme.Colors.inkSoft)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if !achievement.isEarned {
                            ProgressView(value: achievement.fraction)
                                .tint(Theme.Colors.teal)
                                .padding(.horizontal, 6)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 170, alignment: .top)
                    .parchmentPanel(padding: 12)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(achievement.title): \(achievement.detail)")
                    .accessibilityValue(achievement.isEarned ? "Earned" : "\(achievement.progress) of \(achievement.goal)")
                    .accessibilityIdentifier(AccessibilityID.Playbills.rosette(achievement.id))
                }
            }
        }
    }

    // MARK: - Records

    private var records: some View {
        VStack(spacing: 10) {
            sectionTitle("Programme of records")
            VStack(spacing: 0) {
                ForEach(viewModel.statLines) { line in
                    HStack(spacing: 12) {
                        ArtIcon(image: line.art, size: 40)
                        Text(line.title)
                            .font(.court(.subheadline, weight: .medium))
                        Spacer()
                        Text(line.value)
                            .font(.engraved(18, relativeTo: .headline))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }
            }
            .parchmentPanel(padding: 18)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Playbills.stats)
        }
    }
}
