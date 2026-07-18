// Verify a Filmtone Finish license file (envelope format).
// The signed `kind` selects the public key — pass the keys you trust:
//   bun run license:verify -- --file <FilmtoneFinish.license> \
//     [--full-key <full.key.json>] [--trial-key <trial.key.json>] \
//     [--full-pub <rawHex32>] [--trial-pub <rawHex32>]
// At least one key source is required.
// Exit codes: 0 = valid (licensed or in-trial), 2 = valid signature but expired,
// 1 = invalid (structure, signature, kind/key mismatch) / usage error.

import { readFileSync, statSync } from "node:fs";
import {
  KEY_FILE_SCHEMA,
  MAX_LICENSE_FILE_BYTES,
  type KeyFile,
  type LicenseEnvelope,
  type VerifyKeys,
  verifyLicense,
} from "./core.ts";

function parseFlagPairs(argv: string[]): Map<string, string> {
  const queue = [...argv];
  const map = new Map<string, string>();
  while (queue.length > 0) {
    const flag = queue.shift() as string;
    if (!flag.startsWith("--")) throw new Error(`unexpected argument: ${flag}`);
    const value = queue.shift();
    if (value === undefined) throw new Error(`${flag} requires a value`);
    map.set(flag.slice(2), value);
  }
  return map;
}

function publicKeyFromKeyFile(path: string, expectedRole: "full" | "trial"): string {
  const keyFile = JSON.parse(readFileSync(path, "utf8")) as KeyFile;
  if (keyFile.schema !== KEY_FILE_SCHEMA) throw new Error(`key file schema must be ${KEY_FILE_SCHEMA}`);
  if (keyFile.role !== expectedRole) {
    throw new Error(`key role mismatch: ${path} is "${keyFile.role}", expected "${expectedRole}"`);
  }
  return keyFile.publicKeyRawHex;
}

function buildKeys(map: Map<string, string>): VerifyKeys {
  const keys: VerifyKeys = {};
  const fullKeyPath = map.get("full-key");
  const trialKeyPath = map.get("trial-key");
  if (fullKeyPath) keys.fullPublicKeyHex = publicKeyFromKeyFile(fullKeyPath, "full");
  if (trialKeyPath) keys.trialPublicKeyHex = publicKeyFromKeyFile(trialKeyPath, "trial");
  if (map.get("full-pub")) keys.fullPublicKeyHex = map.get("full-pub");
  if (map.get("trial-pub")) keys.trialPublicKeyHex = map.get("trial-pub");
  if (!keys.fullPublicKeyHex && !keys.trialPublicKeyHex) {
    throw new Error("provide at least one of --full-key/--trial-key/--full-pub/--trial-pub");
  }
  return keys;
}

let exitCode = 1;
try {
  const map = parseFlagPairs(process.argv.slice(2));
  const file = map.get("file");
  if (!file) throw new Error("--file is required");
  const keys = buildKeys(map);

  if (statSync(file).size > MAX_LICENSE_FILE_BYTES) {
    throw new Error(`license file exceeds ${MAX_LICENSE_FILE_BYTES} bytes`);
  }
  const envelope = JSON.parse(readFileSync(file, "utf8")) as LicenseEnvelope;
  const result = await verifyLicense(envelope, keys);

  console.log(`file:    ${file}`);
  console.log(`status:  ${result.status}`);
  if (result.reason) console.log(`reason:  ${result.reason}`);
  if (result.payload) {
    console.log(`kind:    ${result.payload.kind}`);
    console.log(`name:    ${result.payload.name}`);
    console.log(`email:   ${result.payload.email}`);
    console.log(`order:   ${result.payload.orderRef}`);
    console.log(`issued:  ${result.payload.issuedAt}`);
    console.log(`expires: ${result.payload.expiresAt ?? "never"}`);
  }
  if (!result.valid) {
    exitCode = 1;
  } else if (result.status === "expired") {
    exitCode = 2;
  } else {
    exitCode = 0;
  }
} catch (error) {
  console.error(String(error));
  exitCode = 1;
}
process.exit(exitCode);
