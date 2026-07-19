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

## Handoff — 2026-07-19 (watermark enforcement + render-graph integration)

```text
Terminal state: Running — trial watermark enforcement implemented and build-verified;
  only the read-only License status-string parameter remains for MON-2 code.
Changed files (added to the prior checkpoint):
  apps/filmtone-resolve-ofx/Sources/License/WatermarkPass.h/.mm  (new)
  apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneRenderGraph.mm
    (extract encodeModulesGraph(); evaluate license once; composite watermark
     on the final output when watermarked)
  apps/filmtone-resolve-ofx/Sources/Host/FilmtonePlugin.cpp
    (isIdentity() returns false when watermarked so the Host renders the frame)
  apps/filmtone-resolve-ofx/Makefile  (WatermarkPass.mm)
Behavior:
  - Licensed / active-trial: no watermark; encodeModulesGraph unchanged, and
    isIdentity() falls through to the original module-identity logic, so the
    bit-exact identity invariant is preserved for licensed users.
  - Unlicensed / invalid / expired-trial: isIdentity() returns false; the graph
    runs (identity blit when all modules off) then composites the watermark.
  - Watermark: deterministic, in-place per-pixel on the output (no cross-pixel
    dependency), alpha preserved, extended-range RGB not clamped, global
    output-bounds canonical coords (proxy == full), diagonal tiled "FILMTONE
    TRIAL" from an embedded 5x7 font.
Default look (OWNER VISUAL REVIEW pending, §3): mid-gray 0.5, opacity 0.16,
  30-degree diagonal tile, ~28-canonical-px text. Constants in WatermarkPass.mm
  (kOpacity/kColor*/kRotationDegrees/kTexel*/kTileGap*) — provide 2-3 candidates
  for owner acceptance; not final.
Remaining MON-2 code: read-only License status-string param (statusLine()).
Verification performed: make -C apps/filmtone-resolve-ofx => exit 0. Symbols
  (encodeMetalTrialWatermark) + embedded MSL present; identity strings intact.
Verification not performed: no Resolve run; watermark not visually inspected;
  no TS<->C cross-verify (owner testing authorization pending).
```

## Handoff — 2026-07-19 (License status param; MON-2 code complete)

```text
Terminal state: Review — verification blocked. MON-2 code scope is complete;
  proof (cross-verification, Resolve) requires owner testing authorization.
Changed files (added to the prior increments):
  apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneParameters.h/.cpp
    (read-only "License" group + eStringTypeLabel status param; updateLicenseStatus())
  apps/filmtone-resolve-ofx/Sources/Host/FilmtonePlugin.cpp
    (set status at instance creation; refresh on changedParam, guarded)
Status label states (statusLine()):
  "Licensed to <name>" / "Trial — expires YYYY-MM-DD" / "Trial mode (watermarked)"
Limitation (documented, implementation-plan §3): the label reflects the license
  file at instance creation and on any param change; it is not push-updated when
  the file changes with the panel already open (panel-refresh dependent). Not
  persisted; default shows "Trial mode (watermarked)".
Verification performed: make -C apps/filmtone-resolve-ofx => exit 0. updateLicenseStatus
  symbol + status param ids/labels embedded; identity strings intact.
Verification not performed: no Resolve run; label not visually confirmed; no
  TS<->C cross-verify (owner testing authorization pending).

MON-2 code checklist (implementation-plan §3):
  [x] LicenseStore: envelope + strict canonical decode + kind-bound Ed25519 +
      trial skew/expiry, matching core.ts. Immutable snapshot + stat cache.
  [x] WatermarkPass: deterministic, in-place, alpha-safe, extended-range-safe,
      global output-bounds coords, embedded font.
  [x] Render-graph final-stage integration; identity invariant preserved for
      licensed users; isIdentity reports non-identity when watermarked.
  [x] Read-only License status string.
  [x] PublicKeys.h (rotation-ready) + vendored ed25519 (pin b1f19fab).
  [x] Builds arm64 (make PASS).
  [x] TS<->C cross-verification + adversarial + canonicalizer edge cases —
      17/17 PASS, 2026-07-19 (scripts/license/parity/run.sh). Canonical parity
      (crown jewel) cleared, incl. non-ASCII / JSON-escape / emoji-surrogate names.
  [ ] watermark visual accepted by owner (default is a placeholder).
  [ ] runtime proof in Resolve (unlicensed->watermark, full->clean, trial->clean
      then expired->watermark, tamper->watermark) (owner authorization).
```

## Verification results — 2026-07-19 (canonical parity: PASS)

Owner authorized MON-2 testing. Cross-verification harness:
`scripts/license/parity/{gen_vectors.ts, harness.mm, run.sh}` — the TS core.ts
reference signs 14 envelopes (real `~/.filmtone/secrets` keys, verified against
the embedded `PublicKeys.h`) and records each verdict; the C++
`LicenseStore::evaluateBytes()` must reproduce all 14.

Result: **17 PASS / 0 FAIL** (`sh scripts/license/parity/run.sh`). Clears the
crown-jewel risk:
- `full-valid -> licensed`, `trial-valid -> trial`, `trial-expired -> expired`
  (a real full license is NOT wrongly watermarked; C++ canonicalize is byte-equal
  to TS for canonical payloads; embedded public keys correct).
- Canonicalizer edge cases `full-name-nonascii` (田中 太郎 / 例え.jp),
  `full-name-json-escapes` (quote/backslash/slash/tab), `full-name-emoji-surrogate`
  (non-BMP) all -> `licensed` — C++ escapeJsonString byte-matches TS JSON.stringify.
- `non-canonical-space`, `reordered-keys`, `unknown-field`, `payload-tampered`,
  `full-signed-with-trial-key`, `trial-future-issuedAt` (+3d skew),
  `trial-length-over-31d`, `name-over-120`, `bad-base64`, `sig-wrong-length`,
  `envelope-extra-field` -> all `invalid`, matching TS exactly.

Still pending (need Resolve): GPU cross-command-buffer watermark ordering, the
in-Resolve state matrix, and the watermark visual (owner judgment). A turnkey
package is prepared for the owner's one Resolve session:
[mon2-resolve-verification-runbook.md](../../monetization/mon2-resolve-verification-runbook.md)
plus `scripts/license/parity/gen_license_files.ts` (writes full / trial /
trial-expired / tampered `.license` files for the state matrix). Only the admin
install (`/Library/OFX/Plugins` is root-owned) + launching Resolve + the visual
judgment are owner actions. The GPU-ordering remedy (source->output watermark via
a tracked intermediate) is documented, ready to apply iff the determinism export
shows a race.

## Resolve live confirmation — 2026-07-19 (owner)

Integration bundle (`com.chibatakumi.filmtone.resolve`, arm64) installed to
`/Library/OFX/Plugins` and applied on a real clip in DaVinci Resolve. Owner
confirmed live:
- Plugin loads; param panel shows all groups (spatial + film + Node Role) and the
  read-only `License > Status` label.
- **No license file -> trial watermark renders** (the diagonal FILMTONE TRIAL tile).
- **`full.license` placed -> clean image + `Licensed to Owner Verification`.**

So the core enforcement (watermark on when unlicensed, off when licensed) is
proven live in both directions. The remaining verdict rows (trial / expired /
tampered) are already covered by the 17/17 harness cross-check, and the licensed
identity invariant holds by construction (watermark is skipped and the module
graph is unchanged when licensed).

Residual (owner elected not to run): **GPU determinism** — a same-frame double
export + `md5` compare would definitively rule out the cross-command-buffer
watermark-ordering race. Not run. Treated as a narrow residual risk
(possible watermark-band flicker on an untracked host buffer); the source->output
tracked-intermediate remedy is documented and ready to apply if it ever appears.
Watermark visual is a placeholder pending owner preferences.

## Runtime risks to verify FIRST (owner testing authorization)

1. **Canonical-JSON parity (crown jewel).** The C++ `canonicalize`
   (NSJSONSerialization parse -> re-serialize -> byte-compare) must produce bytes
   identical to the TS `issue.ts` `canonicalize`, or a genuinely valid **full**
   license decodes as `Invalid` and a paying customer is watermarked. Subtle
   surface: string escaping, key sort order, non-ASCII names, NSJSONSerialization
   quirks. VERIFY THIS BEFORE ANYTHING ELSE: issue a real full + trial envelope
   with `issue.ts`, run each through `evaluateBytes()`, confirm `Licensed`/`Trial`.
2. **GPU cross-command-buffer ordering (newly introduced).** The watermark reads
   `invocation.output` in a *separate* command buffer after the final module wrote
   it. The prior passes synchronized through Metal hazard tracking on private
   intermediates; the host output buffer's hazard-tracking mode is set by Resolve.
   If it is untracked, the watermark can race the module write (flicker/garbage in
   the watermark region only). CHECK: watermark samples the completed module
   output. If it races, the fix is a same-command-buffer encode or an explicit
   barrier — not a constant tweak.
3. **`eStringTypeLabel` host compatibility** — confirm the read-only License status
   renders in Resolve's OFX param panel.

## Cross-verification plan (when owner authorizes testing)

`LicenseStore::evaluateBytes(bytes, len, nowUnix)` is the pure entry point. Feed
it: one real `scripts/license/issue.ts` envelope (expect Licensed/Trial), plus the
adversarial vectors from implementation-plan §3 (trial-signed `full`, future
issuedAt, non-canonical payload, unknown/dup/missing fields, type errors,
date-only/offset datetimes, 31-day overflow, bad base64, non-64-byte sig,
oversize) — all must return Invalid, matching `core.ts`. Then the runtime state
matrix in Resolve: unlicensed->watermark, full->clean, trial->clean then
expired->watermark, tamper->watermark, and licensed + all modules off = bit-exact
identity.
