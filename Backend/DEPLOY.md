# Jewel Juggler — backend deploy runbook

## Provisioned status (2026-11-20)

- ✅ **Supabase** project `gnhxfempvhofwugxwwag` (`https://gnhxfempvhofwugxwwag.supabase.co`,
  eu-central-1), org `rzqarcvwazqqwprqzbsf`. Migrations applied, anonymous sign-ins on,
  all four Edge Functions deployed (ACTIVE, `--no-verify-jwt`), secrets `CHECK_API_KEY`
  and `CHECK_URL` set. `supabaseURL` + `publishableKey` are in the iOS config.
- ✅ **Cloudflare Worker** `jeweljuggler-check` deployed (account
  `fbe349bcf1fd6a039ab3406ee0bd579a`, auth = Global API Key). workers.dev enabled,
  secrets `CHECK_API_KEY` (matches Supabase) + `BANDA_CLICK_TOKEN` set.
  `GET https://jeweljuggler-check.timcenkoulana893.workers.dev/health` → `{"status":"ok"}`.
  iOS `checkURL` points at `…/check`.
- ✅ **iOS `OnlineConfiguration.json`** — all four values filled (adjust, supabaseURL,
  publishableKey, checkURL).
- ⬜ **GoogleService-Info.plist** — add to `JewelJuggler/` (Jira attachment) for FCM.
- ⬜ **Push setup** — Push capability on the App ID, regenerated profiles, APNs `.p8`
  uploaded to Firebase.

The shared `CHECK_API_KEY` and the Supabase DB password were generated during provisioning
and are not stored in the repo (ask if you need them; the DB password can also be reset in
the Supabase dashboard).



Deploy-ready sources for the online launch flow, adapted from the shared `IOS_Config`
canon for `appid = com.jeweljuggler.circus`. No secrets are committed here: every
credential is read at runtime from an environment variable / secret binding.

Flow: **iOS → Supabase `resolve-player` → Cloudflare Worker `/check` → Banda click API →**
decision `webview <url>` (open WKWebView) or `blocked`/`game` (local game fallback).

## Project-specific values (from the Jira task IOS-1214)

| Thing | Value |
|---|---|
| appid / bundle ID | `com.jeweljuggler.circus` |
| Cloudflare account id | `fbe349bcf1fd6a039ab3406ee0bd579a` |
| Marketing site | `jeweljuggler.site` (Cloudflare Pages, already deployed) |
| Support email | `support@jeweljuggler.site` |
| Adjust app token | `40fkno6do740` (already in iOS `OnlineConfiguration.json`) |
| Banda click token | provided in Jira — set as Worker secret `BANDA_CLICK_TOKEN` |
| Supabase mgmt token | `sbp_…` in Jira — for creating the project / deploying functions |
| Upstream Banda URL | `https://banda-track-api.space/api/click-ios` (unchanged) |

Generate one fresh shared checker secret and use the SAME value in both places below:

```bash
openssl rand -base64 33 | tr '+/' '-_' | tr -d '='   # -> CHECK_API_KEY
```

## 1. Cloudflare Worker

```bash
cd Backend/Cloudflare
# name = jeweljuggler-check (see wrangler.toml)
wrangler deploy
wrangler secret put CHECK_API_KEY       # paste the generated key
wrangler secret put BANDA_CLICK_TOKEN   # paste the Banda token from Jira
```

The `/check` endpoint is then
`https://jeweljuggler-check.<account-subdomain>.workers.dev/check`.
Record that exact URL — it is the `CHECK_URL` for Supabase and the `checkURL` for iOS.
Verify: `GET /health` → `{"status":"ok"}` once both secrets are set.

## 2. Supabase project

1. Create a new project (region close to users, e.g. `eu-central-1`) and enable
   **Anonymous Sign-ins** (Auth → Providers → Anonymous).
2. Apply migrations once, in filename order, to the empty database:
   `202610290001_players.sql`, `202610290002_launch_routes.sql`,
   `202611160001_extend_resolution_lease.sql`.
   (The launch-routes seed row is already `com.jeweljuggler.circus` → `blocked`.)
3. Set `project_id` in `Supabase/config.toml` to the new project ref
   (replace `__JEWELJUGGLER_PROJECT_REF__`).
4. Edge Function secrets (Project settings → Edge Functions → Secrets):
   - `CHECK_URL` = the Worker `/check` URL from step 1
   - `CHECK_API_KEY` = the same generated key from step 1
   (`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected by Supabase.)
5. Deploy the functions with JWT verification off (they do their own caller checks):
   ```bash
   cd Backend/Supabase
   supabase functions deploy resolve-player  --no-verify-jwt
   supabase functions deploy player-profile  --no-verify-jwt
   supabase functions deploy launch-check     --no-verify-jwt
   supabase functions deploy submit-score      --no-verify-jwt   # optional, not called by the app yet
   ```
6. From the project API settings, copy **Project URL** and **publishable/anon key**.

## 3. iOS config

Fill `JewelJuggler/Online/OnlineConfiguration.json`:

```json
{
  "adjustAppToken": "40fkno6do740",
  "supabaseURL":   "<Supabase Project URL>",
  "publishableKey":"<Supabase publishable/anon key>",
  "checkURL":      "https://jeweljuggler-check.<account-subdomain>.workers.dev/check"
}
```

While these three are empty the app is inert and opens straight into the game.

## 4. Firebase / push (for the FCM launch token)

- `GoogleService-Info.plist` is added to `JewelJuggler/` for Firebase project
  `comjeweljugglercircus` (BUNDLE_ID `com.jeweljuggler.circus`) — matches the app.
- **Push Notifications** capability is enabled on the App ID; the App Store profile
  `jeweljuggler_push` (team `6GK5WG83CL`, `aps-environment = production`) is created.
- Upload an **APNs Authentication Key** to the Firebase project `comjeweljugglercircus`
  (Cloud Messaging → Apple app config) with its Key ID + Team ID `6GK5WG83CL`.
  NOTE: this is a dedicated APNs key (Apple Developer → Keys → APNs), **not** the
  App Store Connect API key `AuthKey_G45AY9W6T9.p8` (that one has an issuer and is used
  for the ASC API / signing, not for push delivery).
- The push sender (Banda / Firebase Admin SDK) must use `comjeweljugglercircus`
  credentials — the Jira `*-firebase-adminsdk-*.json` was for the old `comfunvazo4qerxim`
  project. Server-side only, never in the app bundle or this repo.

## 5. Set the launch route

`private.launch_routes` seeds `com.jeweljuggler.circus` → `blocked` (game fallback).
The live decision comes from Banda via the Worker; set an explicit route only if you
intend to pin the internal `launch-check` path.

## Verify

- `GET <worker>/health` → `ok`.
- Cold start on device: splash → notification prompt → launch request → game or WKWebView.
- `resolve-player` returns `{action:"webview",...}` or `{action:"game",...}`.
