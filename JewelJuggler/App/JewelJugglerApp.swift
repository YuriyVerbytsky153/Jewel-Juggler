import SwiftUI

@main
struct JewelJugglerApp: App {
    private let bootstrap: Result<AppDependencies, Error>

    init() {
        bootstrap = Result { try AppDependencies() }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .success(let dependencies):
                RootView(dependencies: dependencies)
            case .failure(let error):
                StartupErrorView(message: error.localizedDescription)
            }
        }
    }
}

/// Shown only if the local save cannot be opened.
struct StartupErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(Art.jester(.motley))
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .accessibilityHidden(true)
            Text("The curtain is stuck")
                .font(.engraved(28))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
            Text("Jewel Juggler could not open its save data. Please restart the app. If it keeps happening, reinstalling creates a fresh save.")
                .font(.court(.body))
                .foregroundStyle(Theme.Colors.inkSoft)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.Colors.inkSoft)
                .multilineTextAlignment(.center)
        }
        .parchmentPanel(padding: 28)
        .padding(24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.velvetDeep)
        .preferredColorScheme(.dark)
    }
}
