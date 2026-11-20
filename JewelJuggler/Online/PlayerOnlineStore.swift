import Foundation
import Combine
import UIKit
import WebKit
import AdjustSdk

// Declared at file scope and `nonisolated` so their Codable conformances are not
// MainActor-isolated and satisfy the Sendable requirements of `PlayerAPI.call`.
private nonisolated struct ResolveRequest: Encodable, Sendable {
    let appid, ad_id, request_url, name, avatar: String
    let adjust_json: String
    let deeplink = ""
}
private nonisolated struct ProfileBody: Encodable, Sendable { let appid, ad_id, name: String }
private nonisolated struct ProfileAck: Decodable, Sendable { let updated: Bool }
private nonisolated struct ScoreBody: Encodable, Sendable {
    let appid, ad_id, gameId, mode, completedAt, avatar: String
    let score, duration: Int
}
private nonisolated struct ScoreAck: Decodable, Sendable { let accepted: Bool }

/// Drives launch resolution: authenticates anonymously, waits for Adjust attribution,
/// then asks the backend whether to open a web destination or the local game.
@MainActor
final class PlayerOnlineStore: ObservableObject {
    @Published private(set) var launch: LaunchDecision?
    @Published private(set) var players: [TopPlayer] = []
    @Published private(set) var leaderboardMessage: String?
    @Published var syncMessage: String? = nil
    @Published private(set) var isLoading = false
    @Published var playerName: String {
        didSet { defaults.set(playerName, forKey: "online.playerName"); Task { await updateProfile() } }
    }

    let config = OnlineConfiguration.bundled
    private let api: PlayerAPI?
    private let defaults = UserDefaults.standard
    private var appid: String { Bundle.main.bundleIdentifier ?? "" }
    private var identity: String? { UIDevice.current.identifierForVendor?.uuidString }

    init() {
        api = config.map(PlayerAPI.init(config:))
        playerName = defaults.string(forKey: "online.playerName") ?? "Juggler \(UUID().uuidString.prefix(4))"
    }

    func refreshLeaderboard() async {
        guard !isLoading else { return }
        let cacheKey = "online.leaderboard.\(appid)"
        if players.isEmpty, let data = defaults.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([TopPlayer].self, from: data) { players = cached }
        guard let api else { leaderboardMessage = "Online leaderboard is not configured."; return }
        isLoading = true; defer { isLoading = false }
        do {
            players = try await api.leaderboard(appid: appid)
            defaults.set(try JSONEncoder().encode(players), forKey: cacheKey)
            leaderboardMessage = nil
        } catch { leaderboardMessage = "Offline — showing the last saved standings." }
    }

    func resolveLaunch(pushToken: String) async {
        guard let config, let api, let identity,
              var parts = URLComponents(string: config.checkURL) else {
            launch = .localGame; return
        }
        let userAgent = await webViewUserAgent()
        parts.queryItems = [
            URLQueryItem(name: "appid", value: appid),
            URLQueryItem(name: "idfv", value: identity),
            URLQueryItem(name: "deviceName", value: UIDevice.current.name),
            URLQueryItem(name: "pushToken", value: pushToken),
            URLQueryItem(name: "userAgent", value: userAgent),
            URLQueryItem(name: "appVersion", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
        ]
        guard let requestURL = parts.url?.absoluteString else { launch = .localGame; return }
        do {
            guard let token = config.adjustAppToken, !token.isEmpty else {
                throw OnlineError.unavailable
            }
            let attribution = await adjustAttributionJSON()
            let request = ResolveRequest(appid: appid, ad_id: identity, request_url: requestURL,
                                         name: playerName, avatar: "clover", adjust_json: attribution)
            let response = try await api.call("resolve-player", body: request, as: LaunchDecision.self)
            launch = response.isValid(using: config) ? response : .localGame
        } catch { launch = .localGame }
        await updateProfile()
    }

    /// Submits a finished show's score to the online leaderboard, then refreshes it.
    func submitScore(_ summary: RunSummary) async {
        guard let api, let identity, config != nil else { return }
        let modeKey: String
        switch summary.mode {
        case .endless: modeKey = "endless"
        case .festival: modeKey = "festival"
        case .act: modeKey = "act"
        case .tour: modeKey = "tour"
        }
        let completedAt = ISO8601DateFormatter().string(from: Date())
        let body = ScoreBody(appid: appid, ad_id: identity, gameId: UUID().uuidString, mode: modeKey,
                             completedAt: completedAt, avatar: "clover", score: max(0, summary.score), duration: max(1, summary.seconds))
        _ = try? await api.call("submit-score", body: body, as: ScoreAck.self)
        await refreshLeaderboard()
    }

    /// Waits for Adjust attribution to become available (a fresh install receives it a few
    /// seconds after the first session), then returns its JSON. If it does not arrive within
    /// the wait window, returns an empty object so the launch request is still sent — the API
    /// call must not be skipped just because attribution is not ready yet.
    private func adjustAttributionJSON() async -> String {
        for attempt in 0..<20 { // up to ~10s, polling every 0.5s
            if let value = await currentAttributionJSON() { return value }
            if attempt < 19 { try? await Task.sleep(for: .milliseconds(500)) }
        }
        return "{}"
    }

    private func currentAttributionJSON() async -> String? {
        await withCheckedContinuation { continuation in
            Adjust.attribution { attribution in
                guard let data = attribution?.jsonResponse, !data.isEmpty,
                      let json = try? JSONSerialization.data(withJSONObject: data),
                      let value = String(data: json, encoding: .utf8) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: value)
            }
        }
    }

    /// The device's default WKWebView user agent, forwarded to launch resolution so the
    /// upstream click is attributed with the real browser-engine UA rather than a static name.
    private func webViewUserAgent() async -> String {
        let webView = WKWebView(frame: .zero)
        let value = try? await webView.evaluateJavaScript("navigator.userAgent")
        if let ua = value as? String, !ua.isEmpty { return ua }
        return "JewelJuggler"
    }

    private func updateProfile() async {
        guard let api, let identity else { return }
        _ = try? await api.call("player-profile", body: ProfileBody(appid: appid, ad_id: identity, name: playerName), as: ProfileAck.self)
    }
}
