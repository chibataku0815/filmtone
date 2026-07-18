// Filmtone license core — runtime-agnostic (Bun CLI + Cloudflare Worker).
// Uses only WebCrypto (Ed25519), TextEncoder/TextDecoder, atob/btoa. No dependencies.
// Spec: docs/filmtone/davinci-plugin/monetization/implementation-plan.md §2
//
// Wire format (envelope): the signature covers the EXACT payload bytes carried in
// the file, so no verifier ever re-canonicalizes before checking the signature:
//   { "schema": "filmtone-license/1", "payload": base64(payloadBytes), "sig": base64(ed25519) }
// payloadBytes MUST be the canonical JSON (sorted keys, no whitespace) of exactly
// the PAYLOAD_KEY_SEQUENCE fields. Verifiers decode, check canonical form, then
// select the public key by the signed `kind` (full/trial) — never by caller choice.

export const LICENSE_SCHEMA = "filmtone-license/1";
export const PRODUCT_ID = "com.chibatakumi.filmtone.resolve";
export const EDITION_V1 = "v1";
export const TRIAL_MAX_DAYS = 31;
// Trial containment: issuedAt may not be further in the future than this skew.
// The C-side verifier (MON-2) must apply the same constant.
export const ISSUED_AT_CLOCK_SKEW_MS = 3 * 86_400_000;
export const MAX_PAYLOAD_BYTES = 4096;
export const MAX_LICENSE_FILE_BYTES = 16_384;
export const NAME_MAX_CHARS = 120;
export const EMAIL_MAX_CHARS = 254;
export const ORDER_REF_MAX_CHARS = 120;

// Exact signed field set, in canonical (sorted) order. The C parser may rely on
// this exact key sequence appearing in this order.
export const PAYLOAD_KEY_SEQUENCE = [
  "edition",
  "email",
  "expiresAt",
  "issuedAt",
  "kind",
  "name",
  "orderRef",
  "product",
  "schema",
] as const;

export type LicenseKind = "full" | "trial";

export interface LicensePayload {
  schema: string;
  product: string;
  edition: string;
  kind: LicenseKind;
  name: string;
  email: string;
  orderRef: string;
  issuedAt: string;
  expiresAt: string | null;
}

export interface LicenseEnvelope {
  schema: string;
  payload: string;
  sig: string;
}

export interface KeyFile {
  schema: string;
  role: LicenseKind;
  createdAt: string;
  privateKeyPkcs8Hex: string;
  publicKeyRawHex: string;
}

export const KEY_FILE_SCHEMA = "filmtone-license-key/1";

export interface VerifyKeys {
  fullPublicKeyHex?: string;
  trialPublicKeyHex?: string;
}

// --- encoding helpers ---

export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

export function hexToBytes(hex: string): Uint8Array {
  const clean = hex.trim().toLowerCase();
  if (!/^[0-9a-f]*$/.test(clean) || clean.length % 2 !== 0) {
    throw new Error("invalid hex string");
  }
  return Uint8Array.from({ length: clean.length / 2 }, (_, i) =>
    parseInt(clean.slice(i * 2, i * 2 + 2), 16),
  );
}

const BASE64_CHUNK = 0x8000;

export function bytesToBase64(bytes: Uint8Array): string {
  const chunkCount = Math.ceil(bytes.length / BASE64_CHUNK);
  const binary = Array.from({ length: chunkCount }, (_, c) =>
    String.fromCharCode(...bytes.subarray(c * BASE64_CHUNK, (c + 1) * BASE64_CHUNK)),
  ).join("");
  return btoa(binary);
}

export function base64ToBytes(b64: string): Uint8Array {
  return Uint8Array.from(atob(b64), (ch) => ch.charCodeAt(0));
}

// --- canonical JSON (sorted keys, no whitespace, undefined dropped) ---

export function canonicalize(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalize).join(",")}]`;
  const record = value as Record<string, unknown>;
  const keys = Object.keys(record)
    .filter((k) => record[k] !== undefined)
    .sort();
  const body = keys.map((k) => `${JSON.stringify(k)}:${canonicalize(record[k])}`);
  return `{${body.join(",")}}`;
}

// --- time helpers (ISO UTC, second precision, strict) ---

const ISO_UTC_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;

export function isoNow(nowMs: number = Date.now()): string {
  return new Date(nowMs).toISOString().replace(/\.\d{3}Z$/, "Z");
}

export function isoAfterDays(fromIso: string, days: number): string {
  const from = parseIsoStrict(fromIso);
  if (from === null) throw new Error(`invalid issuedAt: ${fromIso}`);
  return isoNow(from + days * 86_400_000);
}

// Strict RFC 3339 UTC seconds form; round-trips exactly through isoNow.
export function parseIsoStrict(value: string): number | null {
  if (typeof value !== "string" || !ISO_UTC_RE.test(value)) return null;
  const ms = Date.parse(value);
  if (Number.isNaN(ms)) return null;
  return isoNow(ms) === value ? ms : null;
}

// --- payload construction and strict validation ---

export function structuralError(license: LicensePayload): string | null {
  if (license.schema !== LICENSE_SCHEMA) return `schema must be ${LICENSE_SCHEMA}`;
  if (license.product !== PRODUCT_ID) return `product must be ${PRODUCT_ID}`;
  if (license.edition !== EDITION_V1) return `edition must be ${EDITION_V1}`;
  if (license.kind !== "full" && license.kind !== "trial") return "kind must be full|trial";
  if (typeof license.name !== "string" || !license.name.trim()) return "name is required";
  if (license.name.length > NAME_MAX_CHARS) return `name exceeds ${NAME_MAX_CHARS} chars`;
  if (typeof license.email !== "string" || !license.email.trim()) return "email is required";
  if (license.email.length > EMAIL_MAX_CHARS) return `email exceeds ${EMAIL_MAX_CHARS} chars`;
  if (typeof license.orderRef !== "string" || !license.orderRef.trim()) return "orderRef is required";
  if (license.orderRef.length > ORDER_REF_MAX_CHARS) return `orderRef exceeds ${ORDER_REF_MAX_CHARS} chars`;
  const issued = parseIsoStrict(license.issuedAt);
  if (issued === null) return "issuedAt must be strict UTC (YYYY-MM-DDThh:mm:ssZ)";
  if (license.kind === "full") {
    if (license.expiresAt !== null) return "full license must carry expiresAt: null";
    return null;
  }
  if (typeof license.expiresAt !== "string") return "trial license requires expiresAt";
  const expires = parseIsoStrict(license.expiresAt);
  if (expires === null) return "expiresAt must be strict UTC (YYYY-MM-DDThh:mm:ssZ)";
  if (expires <= issued) return "expiresAt must be after issuedAt";
  if (expires - issued > TRIAL_MAX_DAYS * 86_400_000) {
    return `trial length exceeds ${TRIAL_MAX_DAYS} days`;
  }
  return null;
}

function exactPayload(payload: LicensePayload): LicensePayload {
  const { schema, product, edition, kind, name, email, orderRef, issuedAt, expiresAt } = payload;
  return { schema, product, edition, kind, name, email, orderRef, issuedAt, expiresAt };
}

export function payloadBytes(payload: LicensePayload): Uint8Array {
  return new TextEncoder().encode(canonicalize(exactPayload(payload)));
}

export interface DecodeResult {
  payload: LicensePayload | null;
  reason: string | null;
}

// Strict decode: canonical-form equality kills duplicate keys, reordered keys,
// inserted whitespace, and unknown fields cannot pass the exact key-set check.
export function decodePayloadStrict(payloadText: string): DecodeResult {
  let parsed: unknown;
  try {
    parsed = JSON.parse(payloadText);
  } catch {
    return { payload: null, reason: "payload is not valid JSON" };
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    return { payload: null, reason: "payload must be a JSON object" };
  }
  const keys = Object.keys(parsed as Record<string, unknown>).sort();
  const expected = [...PAYLOAD_KEY_SEQUENCE];
  if (keys.length !== expected.length || keys.some((k, i) => k !== expected[i])) {
    return { payload: null, reason: "payload field set must be exactly the signed schema fields" };
  }
  if (canonicalize(parsed) !== payloadText) {
    return { payload: null, reason: "payload is not in canonical form" };
  }
  const candidate = parsed as LicensePayload;
  const structural = structuralError(candidate);
  if (structural) return { payload: null, reason: structural };
  return { payload: candidate, reason: null };
}

// --- Ed25519 via WebCrypto ---

const ED25519 = { name: "Ed25519" } as const;

export async function importPrivateKey(pkcs8Hex: string): Promise<CryptoKey> {
  const bytes = hexToBytes(pkcs8Hex);
  const buf = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  return crypto.subtle.importKey("pkcs8", buf, ED25519, false, ["sign"]);
}

export async function importPublicKey(rawHex: string): Promise<CryptoKey> {
  const bytes = hexToBytes(rawHex);
  if (bytes.length !== 32) throw new Error("public key must be 32 raw bytes");
  const buf = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  return crypto.subtle.importKey("raw", buf, ED25519, false, ["verify"]);
}

export async function signLicense(
  payload: LicensePayload,
  privateKeyPkcs8Hex: string,
): Promise<LicenseEnvelope> {
  const structural = structuralError(payload);
  if (structural) throw new Error(`refusing to sign invalid license: ${structural}`);
  const bytes = payloadBytes(payload);
  if (bytes.length > MAX_PAYLOAD_BYTES) throw new Error("payload exceeds size limit");
  const key = await importPrivateKey(privateKeyPkcs8Hex);
  const sigBuf = await crypto.subtle.sign(ED25519, key, bytes as unknown as ArrayBuffer);
  return {
    schema: LICENSE_SCHEMA,
    payload: bytesToBase64(bytes),
    sig: bytesToBase64(new Uint8Array(sigBuf)),
  };
}

export interface VerifyResult {
  valid: boolean;
  reason: string | null;
  status: "licensed" | "trial" | "expired" | "invalid";
  payload: LicensePayload | null;
}

function invalid(reason: string): VerifyResult {
  return { valid: false, reason, status: "invalid", payload: null };
}

// Kind-bound verification: the signed `kind` selects which public key may verify
// it. A trial key can therefore never mint anything that verifies as "full".
export async function verifyLicense(
  envelope: LicenseEnvelope,
  keys: VerifyKeys,
  nowMs: number = Date.now(),
): Promise<VerifyResult> {
  if (envelope === null || typeof envelope !== "object") return invalid("envelope must be an object");
  if (envelope.schema !== LICENSE_SCHEMA) return invalid(`schema must be ${LICENSE_SCHEMA}`);
  const extraKeys = Object.keys(envelope).filter((k) => !["schema", "payload", "sig"].includes(k));
  if (extraKeys.length > 0) return invalid(`unexpected envelope fields: ${extraKeys.join(",")}`);
  if (typeof envelope.payload !== "string" || typeof envelope.sig !== "string") {
    return invalid("payload and sig must be base64 strings");
  }

  let bytes: Uint8Array;
  let sig: Uint8Array;
  try {
    bytes = base64ToBytes(envelope.payload);
    sig = base64ToBytes(envelope.sig);
  } catch {
    return invalid("payload/sig are not valid base64");
  }
  if (bytes.length === 0 || bytes.length > MAX_PAYLOAD_BYTES) return invalid("payload size out of range");
  if (sig.length !== 64) return invalid("signature must be 64 bytes");

  const decoded = decodePayloadStrict(new TextDecoder().decode(bytes));
  if (!decoded.payload) return invalid(decoded.reason ?? "invalid payload");
  const payload = decoded.payload;

  const publicKeyHex = payload.kind === "full" ? keys.fullPublicKeyHex : keys.trialPublicKeyHex;
  if (!publicKeyHex) return invalid(`no public key provided for kind "${payload.kind}"`);

  let signatureOk = false;
  try {
    const key = await importPublicKey(publicKeyHex);
    signatureOk = await crypto.subtle.verify(
      ED25519,
      key,
      sig as unknown as ArrayBuffer,
      bytes as unknown as ArrayBuffer,
    );
  } catch (error) {
    return invalid(`signature check failed: ${String(error)}`);
  }
  if (!signatureOk) return invalid("signature mismatch");

  if (payload.kind === "full") return { valid: true, reason: null, status: "licensed", payload };

  const issuedMs = parseIsoStrict(payload.issuedAt) as number;
  if (issuedMs > nowMs + ISSUED_AT_CLOCK_SKEW_MS) {
    return invalid("issuedAt is in the future beyond clock-skew tolerance");
  }
  const expired = (parseIsoStrict(payload.expiresAt as string) as number) <= nowMs;
  return expired
    ? { valid: true, reason: "trial period ended", status: "expired", payload }
    : { valid: true, reason: null, status: "trial", payload };
}
