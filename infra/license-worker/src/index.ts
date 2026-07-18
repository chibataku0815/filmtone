// Filmtone trial license worker (Cloudflare Workers, free tier).
// Single endpoint: POST /trial { email, turnstileToken } -> signs a trial
// license with the trial key and emails it via Resend.
// Abuse posture (implementation-plan §5): Turnstile REQUIRED (fail-closed),
// hostname/action-bound Siteverify, streaming 4 KB body cap, per-IP throttle,
// per-email soft limit (HMAC key in KV), generic responses that do not reveal
// whether an email already claimed a trial, deterministic payload + Resend
// Idempotency-Key for safe retries.
// The full-license key is never deployed here by design (implementation-plan §2).

import {
  EDITION_V1,
  LICENSE_SCHEMA,
  PRODUCT_ID,
  TRIAL_MAX_DAYS,
  type LicensePayload,
  bytesToBase64,
  isoAfterDays,
  isoNow,
  signLicense,
} from "../../../scripts/license/core.ts";

interface KVNamespaceLite {
  get(key: string): Promise<string | null>;
  put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
}

interface Env {
  TRIAL_KV: KVNamespaceLite;
  TRIAL_PRIVATE_KEY: string; // wrangler secret: privateKeyPkcs8Hex from filmtone-trial.key.json
  RESEND_API_KEY: string; // wrangler secret
  TRIAL_HASH_SECRET: string; // wrangler secret: random string; HMAC key for KV identifiers
  TURNSTILE_SECRET: string; // wrangler secret: REQUIRED (use Turnstile test keys pre-launch)
  FROM_EMAIL: string;
  ALLOWED_ORIGIN: string; // comma-separated origin allowlist
  TRIAL_DAYS?: string;
  PRODUCT_URL?: string;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const MAX_BODY_BYTES = 4096;
const DEFAULT_TRIAL_DAYS = 14;
const IP_WINDOW_SECONDS = 3600;
const IP_MAX_REQUESTS_PER_WINDOW = 5;
const HOUR_MS = 3_600_000;
const USER_AGENT = "filmtone-license-worker/1.0";
const TURNSTILE_ACTION = "filmtone_trial";
// Keeping the record ~13 months implements the documented retention limit; a
// re-trial becomes possible after it expires, which is accepted (and useful).
const EMAIL_RECORD_TTL_SECONDS = 400 * 86_400;

function trialDays(env: Env): number {
  const parsed = Number(env.TRIAL_DAYS ?? `${DEFAULT_TRIAL_DAYS}`);
  const valid = Number.isInteger(parsed) && parsed >= 1 && parsed < TRIAL_MAX_DAYS;
  return valid ? parsed : DEFAULT_TRIAL_DAYS;
}

function corsHeaders(env: Env, request: Request): Record<string, string> {
  const origin = request.headers.get("Origin") ?? "";
  const allowed = env.ALLOWED_ORIGIN.split(",").map((o) => o.trim()).filter(Boolean);
  const match = allowed.find((o) => o === origin);
  const base = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    Vary: "Origin",
  };
  return match ? { ...base, "Access-Control-Allow-Origin": match } : base;
}

function json(
  env: Env,
  request: Request,
  status: number,
  body: Record<string, unknown>,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(env, request),
      ...extraHeaders,
    },
  });
}

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret) as unknown as ArrayBuffer,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message) as unknown as ArrayBuffer,
  );
  return Array.from(new Uint8Array(mac), (b) => b.toString(16).padStart(2, "0")).join("");
}

// Effective byte cap: reject via Content-Length when present, and abort the
// stream as soon as it exceeds the cap (never buffer an unbounded body).
async function readBodyBytesCapped(request: Request, maxBytes: number): Promise<Uint8Array | null> {
  const contentLength = request.headers.get("Content-Length");
  if (contentLength !== null && Number(contentLength) > maxBytes) return null;
  const reader = request.body?.getReader();
  if (!reader) return null;
  const chunks: Uint8Array[] = [];
  let total = 0;
  let next = await reader.read();
  while (!next.done) {
    total += next.value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      return null;
    }
    chunks.push(next.value);
    next = await reader.read();
  }
  const out = new Uint8Array(total);
  chunks.reduce((offset, chunk) => {
    out.set(chunk, offset);
    return offset + chunk.byteLength;
  }, 0);
  return out;
}

interface TrialRequestBody {
  email: string;
  turnstileToken: string;
}

interface TurnstileResult {
  success?: boolean;
  hostname?: unknown;
  action?: unknown;
}

async function readBody(request: Request): Promise<TrialRequestBody | null> {
  const contentType = request.headers.get("Content-Type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) return null;
  const bytes = await readBodyBytesCapped(request, MAX_BODY_BYTES);
  if (!bytes) return null;
  try {
    const body = JSON.parse(new TextDecoder().decode(bytes)) as {
      email?: unknown;
      turnstileToken?: unknown;
    };
    // Strict types: no coercion of numbers/objects into strings.
    if (typeof body.email !== "string" || typeof body.turnstileToken !== "string") return null;
    return { email: body.email.trim().toLowerCase(), turnstileToken: body.turnstileToken };
  } catch {
    return null;
  }
}

async function turnstilePasses(env: Env, request: Request, token: string): Promise<boolean> {
  const form = new FormData();
  form.set("secret", env.TURNSTILE_SECRET);
  form.set("response", token);
  const ip = request.headers.get("CF-Connecting-IP");
  if (ip) form.set("remoteip", ip);
  const verified = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    body: form,
  });
  if (!verified.ok) return false;
  let result: TurnstileResult;
  try {
    result = (await verified.json()) as TurnstileResult;
  } catch {
    return false;
  }
  if (result.success !== true || result.action !== TURNSTILE_ACTION) return false;
  if (typeof result.hostname !== "string") return false;

  const allowedHostnames = new Set(
    env.ALLOWED_ORIGIN.split(",").flatMap((origin) => {
      try {
        return [new URL(origin.trim()).hostname.toLowerCase()];
      } catch {
        return [];
      }
    }),
  );
  return allowedHostnames.has(result.hostname.toLowerCase());
}

// Soft per-IP throttle. KV is not atomic, so this is best-effort by design;
// Turnstile is the strong gate.
async function ipThrottled(env: Env, request: Request): Promise<boolean> {
  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const key = `ip:${await hmacHex(env.TRIAL_HASH_SECRET, ip)}`;
  const count = Number((await env.TRIAL_KV.get(key)) ?? "0");
  if (count >= IP_MAX_REQUESTS_PER_WINDOW) return true;
  await env.TRIAL_KV.put(key, String(count + 1), { expirationTtl: IP_WINDOW_SECONDS });
  return false;
}

function trialEmailText(days: number, expiresAt: string, productUrl: string): string {
  return [
    `Filmtone — ${days}日無料体験ライセンス / ${days}-day trial license`,
    "",
    "[日本語]",
    "添付の Filmtone.license を次の場所に置いてください:",
    "  ~/Library/Application Support/Filmtone/Filmtone.license",
    "DaVinci Resolve でフレームを再レンダーすると、ウォーターマークが消えます。",
    `体験期限: ${expiresAt}(UTC)。期限が切れると、ウォーターマーク付きの試用状態に戻ります。`,
    "",
    "[English]",
    "Place the attached Filmtone.license at:",
    "  ~/Library/Application Support/Filmtone/Filmtone.license",
    "Re-render a frame in DaVinci Resolve and the watermark disappears.",
    `Trial ends: ${expiresAt} (UTC). After that the plugin simply returns to the watermarked trial mode.`,
    "",
    `Purchase / 購入: ${productUrl}`,
  ].join("\n");
}

async function handleTrial(request: Request, env: Env): Promise<Response> {
  // Fail-closed: a launch deployment must never silently skip the bot check.
  if (!env.TURNSTILE_SECRET) {
    console.error("config error: TURNSTILE_SECRET is not set");
    return json(env, request, 500, { error: "server_misconfigured" });
  }

  const body = await readBody(request);
  if (!body) return json(env, request, 400, { error: "invalid_request" });
  if (!EMAIL_RE.test(body.email) || body.email.length > 254) {
    return json(env, request, 400, { error: "invalid_email" });
  }
  if (!(await turnstilePasses(env, request, body.turnstileToken))) {
    return json(env, request, 403, { error: "verification_failed" });
  }
  if (await ipThrottled(env, request)) {
    return json(env, request, 429, { error: "rate_limited" });
  }

  const emailHmac = await hmacHex(env.TRIAL_HASH_SECRET, body.email);
  // v2 separates licenses issued for the current product identity from the
  // discarded pre-release identity without retaining plaintext email.
  const emailKey = `trial:v2:${emailHmac}`;
  if ((await env.TRIAL_KV.get(emailKey)) !== null) {
    // Generic response: do not reveal whether this email already claimed a trial.
    return json(env, request, 200, { ok: true });
  }

  // Deterministic payload per (email, hour): issuedAt is truncated to the hour
  // and orderRef derives from the email HMAC, so a retry re-signs byte-identical
  // content (Ed25519 is deterministic) and Resend's Idempotency-Key contract
  // ("same key must carry the same payload") holds within the retry window.
  const days = trialDays(env);
  const issuedAt = isoNow(Math.floor(Date.now() / HOUR_MS) * HOUR_MS);
  const payload: LicensePayload = {
    schema: LICENSE_SCHEMA,
    product: PRODUCT_ID,
    edition: EDITION_V1,
    kind: "trial",
    name: body.email,
    email: body.email,
    orderRef: `trial-${emailHmac.slice(0, 16)}`,
    issuedAt,
    expiresAt: isoAfterDays(issuedAt, days),
  };
  const envelope = await signLicense(payload, env.TRIAL_PRIVATE_KEY);
  const attachment = bytesToBase64(
    new TextEncoder().encode(`${JSON.stringify(envelope, null, 2)}\n`),
  );

  const sent = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
      "User-Agent": USER_AGENT,
      "Idempotency-Key": `trial-v2-${emailHmac}`,
    },
    body: JSON.stringify({
      from: env.FROM_EMAIL,
      to: [body.email],
      subject: `Filmtone — ${days}日無料体験ライセンス / ${days}-day trial license`,
      text: trialEmailText(days, payload.expiresAt as string, env.PRODUCT_URL ?? ""),
      attachments: [{ filename: "Filmtone.license", content: attachment }],
    }),
  });
  let delivered = sent.ok;
  if (sent.status === 409) {
    // Only invalid_idempotent_request means Resend already accepted this key.
    // Do not inspect or log message/body fields because they can contain PII.
    let conflictName: string | null = null;
    try {
      const conflict = (await sent.json()) as { name?: unknown };
      if (typeof conflict?.name === "string") conflictName = conflict.name;
    } catch {
      // An invalid JSON response is an unknown conflict and must remain retryable.
    }

    if (conflictName === "invalid_idempotent_request") {
      delivered = true;
    } else if (conflictName === "concurrent_idempotent_requests") {
      console.error(`resend failed: status ${sent.status}`);
      return json(
        env,
        request,
        503,
        { error: "email_delivery_retry" },
        { "Retry-After": "2" },
      );
    }
  }
  if (!delivered) {
    // Log status only — Resend error bodies can echo the recipient address (PII).
    console.error(`resend failed: status ${sent.status}`);
    return json(env, request, 502, { error: "email_delivery_failed" });
  }

  await env.TRIAL_KV.put(
    emailKey,
    JSON.stringify({ issuedAt, expiresAt: payload.expiresAt }),
    { expirationTtl: EMAIL_RECORD_TTL_SECONDS },
  );
  return json(env, request, 200, { ok: true });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(env, request) });
    }
    if (request.method === "POST" && url.pathname === "/trial") {
      return handleTrial(request, env);
    }
    return json(env, request, 404, { error: "not_found" });
  },
};
