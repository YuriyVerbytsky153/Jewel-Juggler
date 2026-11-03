import SwiftUI

/// Sound, music, haptics, handedness, the guide and the progress reset.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    let onBack: () -> Void
    let onGuide: () -> Void

    init(viewModel: SettingsViewModel, onBack: @escaping () -> Void, onGuide: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onBack = onBack
        self.onGuide = onGuide
    }

    var body: some View {
        @Bindable var settings = viewModel.settings
        VStack(spacing: 0) {
            CourtHeader(title: "Settings", onBack: onBack)
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        toggle("Sound effects", detail: "Catches, the chest, the court.", isOn: $settings.soundEnabled, id: AccessibilityID.Settings.sound)
                        divider
                        toggle("Music", detail: "Lute and drum loops.", isOn: $settings.musicEnabled, id: AccessibilityID.Settings.music)
                            .onChange(of: settings.musicEnabled) { viewModel.musicChanged() }
                        divider
                        toggle("Haptics", detail: "Feel every catch and lost bell.", isOn: $settings.hapticsEnabled, id: AccessibilityID.Settings.haptics)
                        divider
                        toggle("Left-handed", detail: "Swaps the BANK and JINGLE buttons.", isOn: $settings.leftHanded, id: AccessibilityID.Settings.leftHanded)
                    }
                    .parchmentPanel(padding: 18)

                    Button("How to play", action: onGuide)
                        .buttonStyle(CourtButtonStyle(kind: .teal, size: 18))
                        .accessibilityIdentifier(AccessibilityID.Settings.guide)

                    VStack(spacing: 10) {
                        Text("Start a new season")
                            .font(.engraved(17, relativeTo: .headline))
                            .foregroundStyle(Theme.Colors.ink)
                        Text("Erases ducats, props, costumes, roses and posters. Settings stay.")
                            .font(.court(.footnote, weight: .medium))
                            .foregroundStyle(Theme.Colors.inkSoft)
                            .multilineTextAlignment(.center)
                        Button("Reset progress") { viewModel.isConfirmingReset = true }
                            .buttonStyle(CourtButtonStyle(kind: .plum, size: 17))
                            .accessibilityIdentifier(AccessibilityID.Settings.reset)
                    }
                    .frame(maxWidth: .infinity)
                    .parchmentPanel(padding: 18)

                    Text("Jewel Juggler · Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")\nOffline, no ads, no real money. Ducats exist only inside the game.")
                        .font(.court(.footnote, weight: .medium))
                        .foregroundStyle(Theme.Colors.ivory)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .tiled(Art.Tile.velvet)
        .toast($viewModel.toast)
        .confirmationDialog("Reset all progress?", isPresented: $viewModel.isConfirmingReset, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) { viewModel.resetProgress() }
                .accessibilityIdentifier(AccessibilityID.Settings.confirmReset)
            Button("Keep my progress", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Settings.screen)
    }

    private var divider: some View {
        Rectangle().fill(Theme.Colors.gold.opacity(0.45)).frame(height: 1)
    }

    private func toggle(_ title: String, detail: String, isOn: Binding<Bool>, id: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.court(.headline, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink)
                Text(detail)
                    .font(.court(.footnote))
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
        }
        .toggleStyle(CourtToggleStyle())
        .frame(minHeight: 48)
        .accessibilityIdentifier(id)
    }
}
