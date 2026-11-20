import SwiftUI
import UserNotifications
import AdjustSdk
import FirebaseCore
import FirebaseMessaging

/// App delegate for the online launch path: initializes Adjust and Firebase, then
/// obtains notification permission and an FCM registration token used by launch resolution.
///
/// Firebase is configured only when `GoogleService-Info.plist` is bundled, so the app
/// still builds and runs (going straight to the game) before that file is added.
final class OnlineAppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    private var firebaseReady = false
    private var pushTokenContinuation: CheckedContinuation<String?, Never>?
    private var pushTokenTimeout: Task<Void, Never>?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
            firebaseReady = true
            Messaging.messaging().delegate = self
            UNUserNotificationCenter.current().delegate = self
        }
        if let token = OnlineConfiguration.bundled?.adjustAppToken, !token.isEmpty,
           let config = ADJConfig(appToken: token, environment: ADJEnvironmentProduction) {
            Adjust.initSdk(config)
        }
        return true
    }

    /// Asks for notification permission, registers with APNs and returns the FCM
    /// registration token. Returns nil if the user declines, Firebase is not configured,
    /// or registration does not complete in time. A nil result never blocks the game.
    @MainActor
    func requestNotificationPermissionAndToken() async -> String? {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        guard firebaseReady else { return nil }
        return await withCheckedContinuation { continuation in
            pushTokenContinuation = continuation
            pushTokenTimeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                self?.finishPushRegistration(token: nil)
            }
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { [weak self] token, _ in
            Task { @MainActor in self?.finishPushRegistration(token: token) }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in finishPushRegistration(token: nil) }
    }

    @MainActor
    private func finishPushRegistration(token: String?) {
        pushTokenTimeout?.cancel()
        pushTokenTimeout = nil
        pushTokenContinuation?.resume(returning: token?.isEmpty == false ? token : nil)
        pushTokenContinuation = nil
    }

    // Allow notifications to show while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

/// Gates the app behind launch resolution: shows the splash while the backend decides,
/// then opens either the resolved web destination or the local game.
struct LaunchGateView: View {
    let dependencies: AppDependencies
    let pushRegistration: OnlineAppDelegate
    @StateObject private var online = PlayerOnlineStore()
    @State private var phase: Phase = .loading
    @State private var started = false

    private enum Phase: Equatable {
        case loading
        case web(URL)
        case game
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                SplashView()
            case .web(let url):
                if let config = online.config {
                    WebContainer(url: url, configuration: config)
                        .background(Color.black.ignoresSafeArea())
                        .ignoresSafeArea()
                } else {
                    RootView(dependencies: dependencies, online: online)
                }
            case .game:
                RootView(dependencies: dependencies, online: online)
            }
        }
        .task {
            guard !started else { return }
            started = true
            // UI tests and autopilot runs must never wait on the network or notifications.
            if dependencies.isUITesting || online.config == nil {
                phase = .game
                return
            }
            try? await Task.sleep(for: .seconds(1))
            let pushToken = await pushRegistration.requestNotificationPermissionAndToken()
            // Always resolve the launch route — even without a push token — so the request
            // still reaches the API.
            await online.resolveLaunch(pushToken: pushToken ?? "")
            if let decision = online.launch, let config = online.config,
               let resolvedURL = decision.destination(using: config) {
                phase = .web(resolvedURL)
                return
            }
            phase = .game
        }
    }
}

/// The launch splash, in the candlelit-court style of the game.
private struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.Colors.velvetDeep.ignoresSafeArea()
            VStack(spacing: 22) {
                Image(Art.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .accessibilityHidden(true)
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.Colors.saffron)
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}
