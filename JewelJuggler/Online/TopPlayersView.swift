import SwiftUI
import WebKit
import Combine

/// The Top Players leaderboard, shown inside the game. Rendered as a WKWebView + HTML
/// page (as in the reference configuration) but styled to the candlelit-court look and
/// fed from `public.leaderboard` for this app id.
struct TopPlayersView: View {
    @ObservedObject var online: PlayerOnlineStore
    let onClose: () -> Void

    var body: some View {
        TopPlayersWebPage(online: online, close: onClose)
            .background(Theme.Colors.velvetDeep.ignoresSafeArea())
            .task { await online.refreshLeaderboard() }
    }
}

struct TopPlayersWebPage: UIViewRepresentable {
    let online: PlayerOnlineStore
    let close: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(online: online, close: close) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "leaderboard")
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.navigationDelegate = context.coordinator
        context.coordinator.web = web
        web.loadHTMLString(Self.page, baseURL: nil)
        return web
    }
    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.render()
    }
    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "leaderboard")
        web.navigationDelegate = nil
    }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let online: PlayerOnlineStore
        let close: () -> Void
        weak var web: WKWebView?
        var ready = false
        private var cancellable: AnyCancellable?

        init(online: PlayerOnlineStore, close: @escaping () -> Void) {
            self.online = online; self.close = close
            super.init()
            // Re-render whenever the store changes, independent of SwiftUI's update timing.
            cancellable = online.objectWillChange.sink { [weak self] _ in
                DispatchQueue.main.async { self?.render() }
            }
        }

        private var payload: [String: Any] {
            ["name": online.playerName, "loading": online.isLoading,
             "message": [online.leaderboardMessage, online.syncMessage].compactMap { $0 }.joined(separator: " · "),
             "players": online.players.map { ["name": $0.name, "score": $0.best_score, "avatar": $0.avatar ?? "clover"] as [String: Any] }]
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { ready = true; render() }
        func render() {
            guard ready, let data = try? JSONSerialization.data(withJSONObject: payload), let json = String(data: data, encoding: .utf8) else { return }
            web?.evaluateJavaScript("window.renderLeaderboard(\(json))", completionHandler: nil)
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: String] else { return }
            switch body["action"] {
            case "close": close()
            case "refresh": Task { await online.refreshLeaderboard() }
            case "save":
                let name = (body["name"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { online.playerName = String(name.prefix(32)) }
            default: break
            }
        }
    }
    private static let page = #"""
    <!doctype html><html lang="en"><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><meta charset="utf-8">
    <style>
    *{box-sizing:border-box}
    body{margin:0;background:#121030;color:#f7edd6;font:700 16px -apple-system,BlinkMacSystemFont,"Avenir Next",sans-serif}
    main{max-width:700px;margin:auto;padding:16px 18px 40px}
    button,input{font:inherit;color:inherit}
    button{cursor:pointer;border:3px solid #1f1733;border-radius:14px;background:#f2b33d;color:#1f1733;box-shadow:0 4px #1f1733;padding:12px 16px;min-height:48px}
    header{display:flex;align-items:center;justify-content:space-between;gap:16px}
    header strong{letter-spacing:2px;color:#f2b33d;font-size:15px}
    h1{font-size:32px;letter-spacing:2px;margin:0;color:#f2b33d}
    .sign{margin:22px 0 20px;text-align:center;background:#1c2b4a;border:5px solid #1f1733;border-radius:24px;padding:22px 12px;box-shadow:inset 0 0 0 4px #eddbb5,0 6px #1f1733}
    .sign p{color:#f7edd6;margin:10px 0 0;font-size:13px;letter-spacing:1px}
    .profile{background:#eddbb5;color:#1f1733;border:3px solid #1f1733;border-radius:18px;padding:16px;margin-bottom:22px}
    .profile label{display:block;font-size:12px;letter-spacing:1px;margin-bottom:10px}
    .form{display:flex;gap:10px}
    input{width:100%;min-width:0;border:2px solid #1f1733;border-radius:10px;padding:12px;background:#fffaf0;color:#1f1733}
    #status{text-align:center;line-height:1.5;color:#e9dcc0}
    ol{padding:0;list-style:none;display:grid;gap:12px}
    li{display:flex;align-items:center;gap:12px;background:#eddbb5;color:#1f1733;border:3px solid #1f1733;border-radius:16px;padding:14px;box-shadow:0 4px #1f1733}
    li:first-child{background:#f2cf6a}
    .rank{font-size:22px;min-width:28px}
    .gem{font-size:28px}
    .name{overflow-wrap:anywhere;flex:1}
    .score{text-align:right;font-size:22px}
    .score small{display:block;font-size:10px;letter-spacing:1px;color:#5b4a2e}
    footer{text-align:center;font-size:12px;margin-top:24px;letter-spacing:1px;color:#b9a985}
    @media(max-width:360px){h1{font-size:26px}.form{flex-wrap:wrap}.score{font-size:18px}}
    </style></head><body><main>
    <header><button onclick="send('close')" aria-label="Back">←</button><strong>JEWEL JUGGLER</strong><button onclick="send('refresh')" aria-label="Refresh">↻</button></header>
    <section class="sign"><h1>TOP PLAYERS</h1><p>THE FINEST JUGGLERS AT COURT</p></section>
    <section class="profile"><label for="stage">YOUR STAGE NAME</label><form class="form" onsubmit="event.preventDefault();send('save',document.querySelector('#stage').value)"><input id="stage" maxlength="32" autocomplete="nickname"><button>Save</button></form></section>
    <p id="status" role="status" aria-live="polite">Loading performers…</p>
    <ol id="players"></ol>
    <footer>RAISE THE CURTAIN. SET YOUR RECORD. TOP THE BILL.</footer>
    </main><script>
    function send(action,name=''){window.webkit.messageHandlers.leaderboard.postMessage({action,name})}
    window.renderLeaderboard=function(data){const input=document.querySelector('#stage');if(document.activeElement!==input)input.value=data.name||'';const rows=data.players||[];document.querySelector('#status').textContent=data.message||(data.loading?'Loading performers…':rows.length?'BEST SHOWS · LIVE STANDINGS':'No performers yet. Finish a show to join the board.');const list=document.querySelector('#players');list.replaceChildren();rows.forEach((player,index)=>{const row=document.createElement('li');const rank=document.createElement('span');rank.className='rank';rank.textContent=index+1;const gem=document.createElement('span');gem.className='gem';gem.textContent='💎';const name=document.createElement('span');name.className='name';name.textContent=player.name;const score=document.createElement('span');score.className='score';score.textContent=Number(player.score).toLocaleString();const label=document.createElement('small');label.textContent='BEST SCORE';score.append(label);row.append(rank,gem,name,score);list.append(row)})};
    </script></body></html>
    """#
}
