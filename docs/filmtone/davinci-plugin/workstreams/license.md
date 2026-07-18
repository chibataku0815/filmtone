# Workstream: License (MON-2)

Document role: immutable workstream plan
Execution progress: [LICENSE progress](progress/license.md) (worker creates on start)
Spec source of truth: [monetization/implementation-plan.md](../monetization/implementation-plan.md) §2 (鍵設計 / wire format) + §3 (MON-2)
Coordinator-owned exception: this monetization workstream may make the **minimal**
integration edits named below (render-graph final stage + one read-only License
param). The general feature-worker prohibition on editing shared pass/param files
does not apply to those two named points; everything else stays disjoint.

## New Chat Start

Read Filmtone `AGENTS.md`, plugin `strategy.md`, coordinator `progress.md`,
`monetization/progress.md`, `monetization/implementation-plan.md` (§2/§3 are the
binding spec), `delegation.md`, this plan, and `progress/license.md`. The TS
reference implementation `scripts/license/core.ts` is the authoritative behavior
for envelope decode + verification; the C/Metal side must match it exactly.

## Goal

Add offline license enforcement to the OFX product: verify an ed25519 license
envelope, composite a deterministic trial watermark whenever the state is not a
valid full/trial license, and expose one read-only status string — with zero
network code and without breaking the all-modules-off bit-exact identity
invariant.

## Dispatch Gate (owner decision 2026-07-19)

The former precondition "Film Breath / Gate Weave owner pass + combined/public
acceptance" was **waived by the owner on 2026-07-19** (progress 改訂 17): proceed
to MON-2 now. MON-2 licensing/watermark is scope-independent of which creative
modules ship, so the still-open module-scope decision (all-three-as-is vs
Film-Damage-first) does not block this workstream and is resolved before MON-6.

Base: the current reviewed integration ref that contains the identity migration
(`1f0959a` or its successor after the coordinator's launch-gate commit). Do not
cut from a stale plan branch or local-only `main`.

## Exclusive Edit Area

```text
apps/filmtone-resolve-ofx/Sources/License/            # new: LicenseStore, WatermarkPass, PublicKeys.h
apps/filmtone-resolve-ofx/Sources/License/vendor/ed25519/   # vendored orlp/ed25519 verify path + LICENSE
```

Named minimal integration points (this workstream only):

- render-graph final stage: append the watermark pass after Breath → Weave →
  Damage when state is not valid-licensed.
- OFX descriptor: one read-only `License` group status string.
- `Makefile`: add the new `Sources/License/` compilation units + vendored source.

## Constraints (binding — from implementation-plan §2/§3)

- **Network 0 lines.** No sockets, DNS, telemetry, or time fetch.
- **Identity invariant preserved.** Valid license + all modules off = bit-exact
  identity. Watermark only composites when state is not valid-licensed.
- Wire format `filmtone-license/1` envelope: signature target is the `payload`
  bytes themselves; strict decode (exact 9-key set, canonical re-serialize must
  equal payload bytes, reject unknown/dup/reordered/whitespace), strict UTC
  datetimes, size caps (sig 64 B, payload ≤ 4096 B, file ≤ 16 KB).
- Kind-based key selection is internal (caller cannot pick the verifying key);
  `full` needs the full public key, `trial` needs the trial key + `expiresAt`
  present + `expiresAt ≤ issuedAt + 31d` + `issuedAt ≤ now + 3d` skew.
- License path: `~/Library/Application Support/Filmtone/Filmtone.license`.
- State is an immutable snapshot swapped atomically (multi-thread render-safe).
- Reload only on `stat()` mtime+size change, throttled ≤ 1/5 s; file deletion →
  immediately unlicensed. Expiry compared per render request.
- Watermark pixel discipline: **alpha unchanged**, out-of-badge pixels bit-exact,
  no clamp of negative/>1 extended-range RGB, no NaN, deterministic (seed-fixed,
  no time animation), global output-bounds coordinates (never per-tile repeat),
  scales with renderScale/proxy, robust for portrait/aspect.
- Watermark text is pre-rasterized bitmap embedded in the header (no font-env
  assumption). `PublicKeys.h` carries full+trial public-key **lists** (rotation).
- Vendored ed25519: orlp/ed25519 verify path (`fe/ge/sc/sha512/verify` + headers)
  + its LICENSE (zlib, multi-file — not single-file public-domain); record the
  pinned commit hash. Exclude seed/keypair/sign units only if build stays whole.

## Expected Output

- `LicenseStore.h/.mm`, `WatermarkPass.h/.mm`, `PublicKeys.h`, `vendor/ed25519/`.
- Minimal render-graph + descriptor + Makefile integration (named points only).
- Handoff (delegation Handoff Schema) recording pinned ed25519 commit, files,
  the exact status-string states, and verification performed / not performed.

## Acceptance Criteria (from implementation-plan §3)

- Unlicensed: all modules off still composites only the watermark (trial view).
- Valid full license placed → re-render clears watermark, status updates.
- Valid trial: clean; past `expiresAt` (system clock advanced) → watermark back.
- Tampered (1-byte edit / key mismatch / trial without expires) → all invalid =
  watermark.
- Adversarial vectors all rejected on the C side, matching the TS reference:
  trial key signing `kind:"full"`, future `issuedAt` (>+3d), non-canonical
  payload, unknown/missing/dup fields, type errors, date-only/offset datetimes,
  31-day-boundary overflow, bad base64, non-64-byte sig, oversize.
- Cross-verify: one real envelope emitted by `scripts/license/issue.ts` verifies
  on the C side, plus the adversarial vector list.

## Owner-Authorization Gates (must be recorded in the dispatch note before doing)

- **Testing / harness / adversarial-vector execution / test files**: only after
  explicit owner testing authorization (global rule + implementation-plan §3).
  Until then MON-2 may reach `Review — verification blocked` with code complete.
- **Watermark visual** (final wording/position/opacity): owner visual judgment;
  deliver 2–3 candidates.
- **Vendoring external ed25519 source** (download): confirm the source repo +
  pinned commit with the owner before adding it (supply-chain).

## Non-Goals

- No network / online activation / telemetry.
- No Polar→full auto-issue (that is Phase L2), no full key in cloud.
- No change to Breath / Weave / Damage image processing.
- No signing, notarization, packaging (MON-5), or public copy (MON-6).

## Stop Conditions

- The C verification cannot be made to match `core.ts` for any vector.
- The identity invariant cannot be preserved with the watermark integrated.
- Progress requires a shared change beyond the three named integration points.
- Three consecutive failures of the same explicitly authorized verification.

## Handoff

Recorded in [LICENSE progress](progress/license.md) using the delegation Handoff
Schema; the coordinator writes the authoritative result into `monetization/progress.md`.
