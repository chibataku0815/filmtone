// Generates the MON-2 Resolve runtime state-matrix license files.
// Writes real, signed .license files (production keys) plus expired/tampered
// variants, so the owner's Resolve session can exercise every state by copying
// one file to ~/Library/Application Support/Filmtone/Filmtone.license.
//
// Usage: bun run scripts/license/parity/gen_license_files.ts <out-dir>

import {
  LICENSE_SCHEMA, PRODUCT_ID, EDITION_V1,
  signLicense, isoNow, type LicensePayload,
} from "../core.ts";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const outDir = process.argv[2] ?? "license-files";
mkdirSync(outDir, { recursive: true });

const secrets = `${homedir()}/.filmtone/secrets`;
const fullKey = JSON.parse(readFileSync(`${secrets}/filmtone-full.key.json`, "utf8"));
const trialKey = JSON.parse(readFileSync(`${secrets}/filmtone-trial.key.json`, "utf8"));

const now = Date.now();
const day = 86_400_000;
const iso = (ms: number) => isoNow(ms);

const base: LicensePayload = {
  schema: LICENSE_SCHEMA, product: PRODUCT_ID, edition: EDITION_V1, kind: "full",
  name: "Owner Verification", email: "owner@fores-tone.co.jp", orderRef: "verify-001",
  issuedAt: iso(now - day), expiresAt: null,
};

function write(name: string, env: unknown) {
  const p = join(outDir, name);
  writeFileSync(p, `${JSON.stringify(env, null, 2)}\n`);
  console.log(`  ${name}`);
}

async function main() {
  console.log(`writing test license files -> ${outDir}`);

  // full.license -> valid, expect CLEAN
  write("full.license", await signLicense(base, fullKey.privateKeyPkcs8Hex));

  // trial.license -> valid trial (+14d), expect CLEAN
  write("trial.license", await signLicense(
    { ...base, kind: "trial", issuedAt: iso(now - day), expiresAt: iso(now + 14 * day) },
    trialKey.privateKeyPkcs8Hex));

  // trial-expired.license -> trial already past expiry, expect WATERMARK
  write("trial-expired.license", await signLicense(
    { ...base, kind: "trial", issuedAt: iso(now - 20 * day), expiresAt: iso(now - day) },
    trialKey.privateKeyPkcs8Hex));

  // tampered.license -> a valid full license with one payload byte flipped, expect WATERMARK
  const good = await signLicense(base, fullKey.privateKeyPkcs8Hex);
  write("tampered.license", { ...good, payload: good.payload.slice(0, 5) + (good.payload[5] === "A" ? "B" : "A") + good.payload.slice(6) });

  console.log("\nState matrix: no file / tampered / trial-expired -> WATERMARK; full / trial -> CLEAN.");
}

await main();
