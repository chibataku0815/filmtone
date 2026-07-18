// Issue a signed Filmtone Finish license file (envelope format).
// Usage:
//   bun run license:issue -- --key <key.json> --kind full \
//     --name "Taro Yamada" --email taro@example.com --order polar_ord_x [--out <path>]
//   bun run license:issue -- --key <key.json> --kind trial \
//     --name ... --email ... --order trial-manual [--days 14] [--out <path>]

import { readFileSync, writeFileSync } from "node:fs";
import {
  EDITION_V1,
  KEY_FILE_SCHEMA,
  LICENSE_SCHEMA,
  PRODUCT_ID,
  type KeyFile,
  type LicenseKind,
  type LicensePayload,
  type VerifyKeys,
  isoAfterDays,
  isoNow,
  signLicense,
  verifyLicense,
} from "./core.ts";

interface Args {
  key: string;
  kind: LicenseKind;
  name: string;
  email: string;
  order: string;
  days: number;
  out: string;
}

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

function parseArgs(argv: string[]): Args {
  const map = parseFlagPairs(argv);
  const required = ["key", "kind", "name", "email", "order"] as const;
  const missing = required.filter((field) => !map.get(field));
  if (missing.length > 0) throw new Error(`missing required flags: ${missing.map((f) => `--${f}`).join(", ")}`);
  const kind = map.get("kind");
  if (kind !== "full" && kind !== "trial") throw new Error("--kind must be full|trial");
  const days = Number(map.get("days") ?? "14");
  if (!Number.isInteger(days) || days <= 0) throw new Error("--days must be a positive integer");
  return {
    key: map.get("key") as string,
    kind,
    name: map.get("name") as string,
    email: map.get("email") as string,
    order: map.get("order") as string,
    days,
    out: map.get("out") ?? "FilmtoneFinish.license",
  };
}

const args = parseArgs(process.argv.slice(2));

const keyFile = JSON.parse(readFileSync(args.key, "utf8")) as KeyFile;
if (keyFile.schema !== KEY_FILE_SCHEMA) {
  throw new Error(`key file schema must be ${KEY_FILE_SCHEMA}`);
}
if (keyFile.role !== args.kind) {
  throw new Error(
    `key role mismatch: key is "${keyFile.role}" but --kind is "${args.kind}". ` +
      "Full licenses are signed only with the full key, trials only with the trial key.",
  );
}

const issuedAt = isoNow();
const payload: LicensePayload = {
  schema: LICENSE_SCHEMA,
  product: PRODUCT_ID,
  edition: EDITION_V1,
  kind: args.kind,
  name: args.name.trim(),
  email: args.email.trim().toLowerCase(),
  orderRef: args.order.trim(),
  issuedAt,
  expiresAt: args.kind === "trial" ? isoAfterDays(issuedAt, args.days) : null,
};

const envelope = await signLicense(payload, keyFile.privateKeyPkcs8Hex);

const selfCheckKeys: VerifyKeys =
  args.kind === "full"
    ? { fullPublicKeyHex: keyFile.publicKeyRawHex }
    : { trialPublicKeyHex: keyFile.publicKeyRawHex };
const selfCheck = await verifyLicense(envelope, selfCheckKeys);
if (!selfCheck.valid || selfCheck.status === "expired") {
  throw new Error(`self-verification failed after signing: ${selfCheck.reason}`);
}

try {
  // flag "wx" refuses existing files atomically; 0600 because this is a bearer
  // entitlement carrying the customer's name/email.
  writeFileSync(args.out, `${JSON.stringify(envelope, null, 2)}\n`, { mode: 0o600, flag: "wx" });
} catch (error) {
  const code = (error as NodeJS.ErrnoException).code;
  if (code === "EEXIST") throw new Error(`refusing to overwrite existing file: ${args.out} (use --out)`);
  throw error;
}

console.log(`Issued ${payload.kind} license -> ${args.out}`);
console.log(`  name:    ${payload.name}`);
console.log(`  email:   ${payload.email}`);
console.log(`  order:   ${payload.orderRef}`);
console.log(`  issued:  ${payload.issuedAt}`);
console.log(`  expires: ${payload.expiresAt ?? "never"}`);
console.log(`  self-check: ${selfCheck.status}`);
console.log('Install path: ~/Library/Application Support/Filmtone/FilmtoneFinish.license');
