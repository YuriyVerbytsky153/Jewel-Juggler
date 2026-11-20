import { createClient } from "npm:@supabase/supabase-js@2.57.4";

// EDIT APPLICATION / INTEGRATION SETTINGS HERE. No application-ID or destination-host lists.
// Keep this file on the server. Supabase injects its own project credentials automatically.
export const SETTINGS = Object.freeze({
  CHECK_URL: Deno.env.get("CHECK_URL") ?? "",
  CHECK_API_KEY: "",
  SUPABASE_URL: Deno.env.get("SUPABASE_URL")!,
  SERVICE_ROLE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  AVATARS: ["clover", "pip", "rusty", "mabel", "nova", "duchess", "zippy"],
  NAME_MAX_LENGTH: 32,
  APP_ID_MAX_LENGTH: 200,
  MAX_REQUEST_BYTES: 16_384,
  MAX_CHECK_URL_LENGTH: 12_000,
  MAX_TARGET_URL_LENGTH: 4096,
  CHECK_TIMEOUT_MS: 30_000,
  CHECK_RESPONSE_BYTES: 16_384,
  MAX_REDIRECTS: 5,
  DEVICE_NAME_MAX_LENGTH: 200,
  PUSH_TOKEN_MAX_LENGTH: 4096,
  USER_AGENT_MAX_LENGTH: 4096,
  RATE_LIMITS: { SUBMIT: 120, OTHER: 30 },
  SCORE: {
    MAX_VALUE: 2_000_000_000, MAX_DURATION: 86_400,
    // Jewel Juggler reports a show score and its duration in seconds. This is a lenient
    // plausibility bound (not proof of play); keep it generous so real high scores pass.
    POINTS_PER_SECOND: 1_000_000, POINTS_SLACK: 1_000_000,
    MODE_MAX_LENGTH: 32,
    FUTURE_TOLERANCE_MS: 300_000, EARLIEST_COMPLETION: Date.UTC(2020, 0, 1),
  },
});


export class Failure extends Error { constructor(public status: number, message: string) { super(message); } }
export const db = createClient(SETTINGS.SUPABASE_URL, SETTINGS.SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
  global: {
    fetch: (input, init) => {
      const timeout = AbortSignal.timeout(SETTINGS.CHECK_TIMEOUT_MS);
      const upstream = init?.signal ?? (input instanceof Request ? input.signal : undefined);
      return fetch(input, { ...init, signal: upstream ? AbortSignal.any([upstream, timeout]) : timeout });
    },
  },
});
export const avatars = new Set(SETTINGS.AVATARS);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function uuidValue(value: unknown): string {
  if (typeof value !== "string" || !uuid.test(value)) throw new Failure(400, "Invalid UUID");
  return value;
}
export function text(value: unknown, max: number): string {
  if (typeof value !== "string" || value.length > max || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value)) throw new Failure(400, "Invalid text");
  return value;
}
export function name(value: unknown): string {
  const result = text(value, SETTINGS.NAME_MAX_LENGTH).trim();
  if (!result) throw new Failure(400, "Empty name");
  return result;
}
export function avatar(value: unknown): string {
  if (typeof value !== "string" || !avatars.has(value)) throw new Failure(400, "Unknown avatar");
  return value;
}
export async function rpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await db.rpc(fn, args);
  if (error) throw new Failure(error.code === "42501" ? 403 : 409, "Operation could not be completed");
  return data as T;
}
export async function context(request: Request, bucket: string) {
  if (request.method !== "POST") throw new Failure(405, "POST required");
  const token = request.headers.get("authorization")?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) throw new Failure(401, "Authentication required");
  const { data, error } = await db.auth.getUser(token);
  if (error || !data.user) throw new Failure(401, "Invalid session");
  if (!await rpc<boolean>("player_rate_limit", { p_owner: data.user.id, p_bucket: bucket, p_limit: bucket === "submit-score" ? SETTINGS.RATE_LIMITS.SUBMIT : SETTINGS.RATE_LIMITS.OTHER })) throw new Failure(429, "Try later");
  const bytes = await request.arrayBuffer();
  if (bytes.byteLength > SETTINGS.MAX_REQUEST_BYTES) throw new Failure(413, "Request too large");
  let body;
  try { body = JSON.parse(new TextDecoder().decode(bytes)); } catch { throw new Failure(400, "Invalid JSON"); }
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new Failure(400, "Invalid body");
  const appid = text(body.appid, SETTINGS.APP_ID_MAX_LENGTH);
  if (!appid.trim() || appid !== appid.trim()) throw new Failure(400, "Invalid application ID");
  return { body, owner: data.user.id, appid, ad_id: uuidValue(body.ad_id) };
}
export function webURL(value: unknown): URL {
  if (typeof value !== "string" || value.length > SETTINGS.MAX_TARGET_URL_LENGTH) throw new Failure(502, "Invalid target");
  let url: URL;
  try { url = new URL(value); } catch { throw new Failure(502, "Invalid target"); }
  if (url.protocol !== "https:" || url.username || url.password || !url.hostname) throw new Failure(502, "Target not allowed");
  return url;
}
export function decision(target?: string | null) {
  if (target === "blocked") return { action: "game", targetUrl: null, cacheable: true };
  if (target) return { action: "webview", targetUrl: webURL(target).href, cacheable: true };
  return { action: "game", targetUrl: null, cacheable: false };
}
export function serve(handler: (request: Request) => Promise<unknown>) {
  Deno.serve(async request => {
    try { return Response.json(await handler(request), { headers: { "Cache-Control": "no-store" } }); }
    catch (error) {
      return Response.json({ error: error instanceof Failure ? error.message : "Service unavailable" }, {
        status: error instanceof Failure ? error.status : 503, headers: { "Cache-Control": "no-store" },
      });
    }
  });
}


serve(async request => {
  const { body, owner, appid, ad_id } = await context(request, "submit-score");
  // Jewel Juggler: a show's score and its duration. Plausibility validation, not proof of play.
  if (!Number.isSafeInteger(body.score) || body.score < 0 || body.score > SETTINGS.SCORE.MAX_VALUE) throw new Failure(400, "Invalid score");
  if (typeof body.duration !== "number" || !Number.isFinite(body.duration) || body.duration < 0 || body.duration > SETTINGS.SCORE.MAX_DURATION) throw new Failure(400, "Invalid duration");
  if (body.score > body.duration * SETTINGS.SCORE.POINTS_PER_SECOND + SETTINGS.SCORE.POINTS_SLACK) throw new Failure(422, "Impossible score");
  if (typeof body.mode !== "string" || body.mode.length < 1 || body.mode.length > SETTINGS.SCORE.MODE_MAX_LENGTH) throw new Failure(400, "Invalid mode");
  const timestampWithoutZone = typeof body.completedAt === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$/.test(body.completedAt);
  const completedAt = timestampWithoutZone ? `${body.completedAt}Z` : body.completedAt;
  if (typeof completedAt !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/.test(completedAt)) throw new Failure(400, "Invalid completion time");
  const completed = Date.parse(completedAt);
  if (!Number.isFinite(completed) || completed > Date.now() + SETTINGS.SCORE.FUTURE_TOLERANCE_MS || completed < SETTINGS.SCORE.EARLIEST_COMPLETION) throw new Failure(400, "Invalid completion time");
  return await rpc("save_score", { p_appid: appid, p_ad_id: ad_id, p_owner: owner, p_game_id: uuidValue(body.gameId),
    p_score: body.score, p_completed_at: completedAt, p_avatar: avatar(body.avatar) });
});
