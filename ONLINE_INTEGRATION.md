# Online launch integration (IOS-1214)

The shared `IOS_Config` canon (Splash → push/FCM token → launch resolution → WKWebView,
with the local game as the fallback) is wired into Jewel Juggler, in the game's own
architecture and style. Deploy steps and values: **`Backend/DEPLOY.md`**.

## iOS (done, builds clean)

New `JewelJuggler/Online/`:
- `OnlineConfiguration.swift` — bundled config + launch decision model.
- `OnlineConfiguration.json` — config resource. Adjust token filled; `supabaseURL` /
  `publishableKey` / `checkURL` are empty until the backend exists. **While empty, the
  app is inert and opens straight into the game.**
- `PlayerAPI.swift` — anonymous Supabase session (keychain-backed) authorizing resolution.
- `PlayerOnlineStore.swift` — launch resolution + profile update; Adjust attribution.
- `WebContainer.swift` — the resolved-destination WKWebView (navigation/back/downloads/
  external links/error + timeout handling carried over 1:1 from the canon).
- `LaunchFlow.swift` — app delegate (Adjust init, Firebase, notification permission + FCM
  token) and the splash/launch gate in the candlelit-court style.

Wiring:
- `JewelJugglerApp.swift` now hosts the launch gate; `RootView` (the game) is the fallback.
- `JewelJuggler.entitlements` adds `aps-environment`; Push capability added to the target.
- SPM: `AdjustSdk` (adjust/ios_sdk 5.x) and `FirebaseMessaging` (firebase-ios-sdk 11.x).

pushToken is the **FCM registration token**. Firebase is configured only when
`GoogleService-Info.plist` is bundled, so the app still builds/runs without it.

## Backend sources (deploy-ready, in `Backend/`)

Supabase functions + migrations and the Cloudflare Worker, adapted for
`appid = com.jeweljuggler.circus`. All secrets are read from env / secret bindings — none
are committed. The launch-routes seed is already the Jewel Juggler app id.

## Still required (see Backend/DEPLOY.md)

1. **GoogleService-Info.plist** (Jira attachment) added to `JewelJuggler/` — could not be
   downloaded here (Jira attachment auth).
2. **Provision** the Supabase project + Cloudflare Worker, then fill the three config values.
3. **Push setup**: Push capability on the App ID, regenerated profiles, APNs `.p8` uploaded
   to Firebase.

## Top Players (in-game leaderboard)

- `JewelJuggler/Online/TopPlayersView.swift` — a WKWebView + HTML board styled to the court,
  reading `public.leaderboard` live; entry point is a trophy medallion in the Stage top bar
  (not on the main launch WebView). Stage name edits go through `player-profile`.
- Score submission: a finished show calls `PlayerOnlineStore.submitScore` → the `submit-score`
  Edge Function (adapted to Jewel Juggler's score + duration + mode) → `save_score`, then the
  board refreshes. Verified end-to-end (a submitted score appears as the top standing).

## Not changed / not included

- The game's existing screens, mechanics and tests are untouched; the game remains the fallback.
- Pre-existing uncommitted work in the tree (Royal Tour / Workshop) was left as-is.
