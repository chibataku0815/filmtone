// MON-2 cross-verification vector generator (TS reference side).
//
// Signs a battery of license envelopes with the REAL private keys in
// ~/.filmtone/secrets (whose public keys are embedded in
// apps/filmtone-resolve-ofx/Sources/License/PublicKeys.h), records the
// authoritative core.ts verdict for each, and writes vectors.json. The C++
// harness (harness.mm) then reproduces each verdict via
// LicenseStore::evaluateBytes() and must match exactly.
//
// Adversarial vectors that target the canonical/structural layer are signed
// over the exact (possibly non-canonical) payload bytes, so any mismatch
// isolates the C++ canonicalizer rather than the signature path.
//
// Usage: bun run scripts/license/parity/gen_vectors.ts <output-vectors.json>

import {
  LICENSE_SCHEMA,
  PRODUCT_ID,
  EDITION_V1,
  signLicense,
  verifyLicense,
  importPrivateKey,
  payloadBytes,
  bytesToBase64,
  isoNow,
  type LicensePayload,
  type LicenseEnvelope,
} from "../core.ts";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { dirname } from "node:path";

const outPath = process.argv[2] ?? "vectors.json";

const secrets = `${homedir()}/.filmtone/secrets`;
const fullKey = JSON.parse(readFileSync(`${secrets}/filmtone-full.key.json`, "utf8"));
const trialKey = JSON.parse(readFileSync(`${secrets}/filmtone-trial.key.json`, "utf8"));

// Verdicts are computed against the SAME public keys embedded in PublicKeys.h.
const EMBEDDED = {
  fullPublicKeyHex: "4b887963416f325a290203b086caf40d811dd7724252f780f3c15fbfe7fdd376",
  trialPublicKeyHex: "39af05f555ecdf06702470a09b2c0384e0ff34457b25f148fa98ee0e232fa4e0",
};

const NOW = Date.parse("2026-07-19T12:00:00Z"); // fixed, whole-second reference
const day = 86_400_000;
const iso = (ms: number) => isoNow(ms);

const basePayload: LicensePayload = {
  schema: LICENSE_SCHEMA,
  product: PRODUCT_ID,
  edition: EDITION_V1,
  kind: "full",
  name: "Test User",
  email: "test@example.com",
  orderRef: "order-123",
  issuedAt: iso(NOW - 10 * day),
  expiresAt: null,
};

interface Vector {
  name: string;
  envelope: string;
  nowMs: number;
  tsStatus: string;
  tsValid: boolean;
}

const vectors: Vector[] = [];

async function record(name: string, env: LicenseEnvelope, nowMs: number) {
  const r = await verifyLicense(env, EMBEDDED, nowMs);
  vectors.push({ name, envelope: JSON.stringify(env), nowMs, tsStatus: r.status, tsValid: r.valid });
}

async function envelopeOverBytes(bytes: Uint8Array, privHex: string): Promise<LicenseEnvelope> {
  const key = await importPrivateKey(privHex);
  const sig = await crypto.subtle.sign({ name: "Ed25519" }, key, bytes as unknown as ArrayBuffer);
  return { schema: LICENSE_SCHEMA, payload: bytesToBase64(bytes), sig: bytesToBase64(new Uint8Array(sig)) };
}

const enc = (s: string) => new TextEncoder().encode(s);

async function main() {
  await record("full-valid", await signLicense(basePayload, fullKey.privateKeyPkcs8Hex), NOW);

  // Canonicalizer edge cases — all valid full licenses that MUST decode as
  // licensed, i.e. C++ escapeJsonString must byte-match TS JSON.stringify.
  await record("full-name-nonascii",
    await signLicense({ ...basePayload, name: "田中 太郎", email: "tanaka@例え.jp" }, fullKey.privateKeyPkcs8Hex), NOW);
  await record("full-name-json-escapes",
    await signLicense({ ...basePayload, name: 'O\'Brien "Ace" \\ /\t x' }, fullKey.privateKeyPkcs8Hex), NOW);
  await record("full-name-emoji-surrogate",
    await signLicense({ ...basePayload, name: "Test 🎬 User" }, fullKey.privateKeyPkcs8Hex), NOW);

  const trialValid: LicensePayload = { ...basePayload, kind: "trial", issuedAt: iso(NOW - day), expiresAt: iso(NOW + 4 * day) };
  await record("trial-valid", await signLicense(trialValid, trialKey.privateKeyPkcs8Hex), NOW);

  const trialExpired: LicensePayload = { ...basePayload, kind: "trial", issuedAt: iso(NOW - 20 * day), expiresAt: iso(NOW - 5 * day) };
  await record("trial-expired", await signLicense(trialExpired, trialKey.privateKeyPkcs8Hex), NOW);

  await record("full-signed-with-trial-key", await signLicense(basePayload, trialKey.privateKeyPkcs8Hex), NOW);

  const futureIssued: LicensePayload = { ...basePayload, kind: "trial", issuedAt: iso(NOW + 4 * day), expiresAt: iso(NOW + 5 * day) };
  await record("trial-future-issuedAt", await signLicense(futureIssued, trialKey.privateKeyPkcs8Hex), NOW);

  const tooLong: LicensePayload = { ...basePayload, kind: "trial", issuedAt: iso(NOW - day), expiresAt: iso(NOW + 40 * day) };
  await record("trial-length-over-31d", await envelopeOverBytes(payloadBytes(tooLong), trialKey.privateKeyPkcs8Hex), NOW);

  const good = await signLicense(basePayload, fullKey.privateKeyPkcs8Hex);
  const p = good.payload;
  await record("payload-tampered", { ...good, payload: p.slice(0, 5) + (p[5] === "A" ? "B" : "A") + p.slice(6) }, NOW);

  const canonicalText = JSON.stringify({
    edition: "v1", email: "test@example.com", expiresAt: null, issuedAt: basePayload.issuedAt,
    kind: "full", name: "Test User", orderRef: "order-123", product: PRODUCT_ID, schema: LICENSE_SCHEMA,
  });
  await record("payload-non-canonical-space", await envelopeOverBytes(enc(canonicalText.replace('","', '", "')), fullKey.privateKeyPkcs8Hex), NOW);

  const reordered = `{"schema":"${LICENSE_SCHEMA}","product":"${PRODUCT_ID}","edition":"v1","kind":"full","name":"Test User","email":"test@example.com","orderRef":"order-123","issuedAt":"${basePayload.issuedAt}","expiresAt":null}`;
  await record("payload-reordered-keys", await envelopeOverBytes(enc(reordered), fullKey.privateKeyPkcs8Hex), NOW);

  const extra = `{"edition":"v1","email":"test@example.com","expiresAt":null,"extra":"x","issuedAt":"${basePayload.issuedAt}","kind":"full","name":"Test User","orderRef":"order-123","product":"${PRODUCT_ID}","schema":"${LICENSE_SCHEMA}"}`;
  await record("payload-unknown-field", await envelopeOverBytes(enc(extra), fullKey.privateKeyPkcs8Hex), NOW);

  const longName: LicensePayload = { ...basePayload, name: "X".repeat(121) };
  await record("name-over-120", await envelopeOverBytes(payloadBytes(longName), fullKey.privateKeyPkcs8Hex), NOW);

  await record("bad-base64-payload", { ...good, payload: "@@@not-base64@@@" }, NOW);
  await record("sig-wrong-length", { ...good, sig: bytesToBase64(new Uint8Array(32)) }, NOW);
  await record("envelope-extra-field", { ...good, extra: "x" } as unknown as LicenseEnvelope, NOW);

  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, JSON.stringify(vectors, null, 2));
  console.log(`wrote ${vectors.length} vectors -> ${outPath}`);
}

await main();
