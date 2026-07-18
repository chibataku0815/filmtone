# LICENSE (MON-2) progress

Document role: worker-owned execution record for [workstreams/license.md](../license.md).
Coordinator writes the authoritative result into `monetization/progress.md`.

## Handoff — 2026-07-19 (crypto core checkpoint)

```text
Terminal state: Running — license verification core complete and build-verified;
  WatermarkPass + render-graph/param integration remain.
Repository / worktree / base: filmtone / davinci-plugin-pricing-plan-4cb87b /
  edf8d4b (identity migration + launch gates) plus this checkpoint commit.
Changed files:
  apps/filmtone-resolve-ofx/Sources/License/PublicKeys.h
  apps/filmtone-resolve-ofx/Sources/License/LicenseStore.h
  apps/filmtone-resolve-ofx/Sources/License/LicenseStore.mm
  apps/filmtone-resolve-ofx/Sources/License/vendor/ed25519/*  (verify path + LICENSE)
  apps/filmtone-resolve-ofx/Makefile  (license .mm + ed25519 .c units, C compile rule)
Public interfaces:
  filmtone::resolve::license::LicenseStore::{evaluate(), refreshNow(), evaluateBytes()}
  LicenseState { status, name, expiresAt, watermarked(), statusLine() }
  LicenseStatus { Unlicensed, Licensed, Trial, Expired, Invalid }
Decisions fixed:
  - Vendored orlp/ed25519 verify-only subset (verify/ge/fe/sc/sha512 + headers),
    pinned commit b1f19fab4aebe607805620d25a5e42566ce46a0e, zlib license kept.
  - Parse with Foundation NSJSONSerialization; canonical-form check via a
    JSON.stringify-compatible canonicalizer compared byte-for-byte to the signed
    payload — mirrors core.ts decodePayloadStrict()/structuralError() exactly.
  - Kind-bound public-key selection (trial key can never verify a `full`).
  - MRC-safe (no ARC): autoreleased NSData, no static ObjC objects.
  - Render-path evaluate() caches the verified Base; re-reads only on stat
    (mtime+size) change throttled to 1/5s; trial expiry derived per call.
  - Public keys embedded from MON-3 keygen output (rotation-ready lists).
Remaining work:
  - WatermarkPass.h/.mm: deterministic Metal trial watermark (global output-bounds
    coords, alpha unchanged, extended-range safe, pre-rasterized bitmap text).
  - Render-graph final stage: append watermark after Breath->Weave->Damage when
    !valid-licensed; preserve bit-exact identity when licensed/all-off.
  - OFX descriptor: read-only License group status string (statusLine()), updated
    at create + instanceChanged only.
  - Cross-verify TS-issued envelope + adversarial vectors on the C side.
Blocker: none for the core. Owner gates for the remaining work: watermark visual
  direction (2-3 candidates), testing authorization (cross-verify / vectors),
  final public module scope (MON-6).
Verification performed:
  - make -C apps/filmtone-resolve-ofx => exit 0. Compiles + links; LicenseStore
    symbols present; ed25519 linked; identity strings intact; behavior unchanged
    (verifier not yet wired, so default identity preserved).
Verification not performed:
  - TS<->C cross-verification and adversarial vectors (owner testing authorization
    pending). No Resolve run. No runtime license evaluation exercised.
Stop reason: natural checkpoint at a build-verified, behavior-neutral core before
  the identity-invariant-sensitive watermark integration.
```

## Cross-verification plan (when owner authorizes testing)

`LicenseStore::evaluateBytes(bytes, len, nowUnix)` is the pure entry point. Feed
it: one real `scripts/license/issue.ts` envelope (expect Licensed/Trial), plus the
adversarial vectors from implementation-plan §3 (trial-signed `full`, future
issuedAt, non-canonical payload, unknown/dup/missing fields, type errors,
date-only/offset datetimes, 31-day overflow, bad base64, non-64-byte sig,
oversize) — all must return Invalid, matching `core.ts`.
