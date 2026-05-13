# M2 — Stone / Urban Tuning Pass

Opened: 2026-05-13 JST
Lane: iOS Max Quality Look Director
Branch: `feature/ios-max-quality-look-director`
Worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-ios-max-quality-look-director`

## Goal

Raise the visible image ceiling on Stone and Urban while keeping the M1C
anti-haze invariants. Owner closed M1 with Stone "passable but still
conservative, compression working" and Urban "below Stone but visible".
M2 turns the existing handles up so Stone reads as a flagship product
Look and Urban reads as a cooler urban sibling rather than a watered-down
Stone.

None passthrough stays exactly as M1 closed it (reset preset + cleared
overrides). Noir stays untouched in this pass — its print structure is
already where the catalog wants it.

## Product Posture

- Push compression / printContrast / contrast / saturation / detailSoftness
  / practical-glow gains by larger increments than M1.
- Keep the M1C anti-haze invariants structurally in force: no `fade`
  emitted by the resolver, `bloomThreshold` never lowered, no broad
  night diffusion drive, no high-key sky glow, no `shadowTone` written
  as a latitude knob.
- Catalog optical baselines get small bumps so a "no descriptor signal"
  export still reads as a real Look on first glance, not a near-passthrough.
- Performance: no new render stages, no new analysis passes. All changes
  are uniform value bumps on existing `Print` / `Color` / `GlowFamily` /
  radial RGB split / `DetailSoftness` / `Vignette` paths and on
  baseline patch values that already drove those stages in M1.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneLookDirector.swift`
  (resolver weights + small unconditional floor bump)
- `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneCreativePack01Patches.swift`
  (Stone / Urban catalog baselines)
- `packages/film-lab-core/src/creative-pack-01.ts`
  (mirror Stone / Urban baselines for cross-platform parity)
- `apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json`
  (regenerated via `bun run scripts/build-creative-luts.ts --regenerate`)
- `apps/capacitor-film-lab-ios/scripts/swift/test-look-director.swift`
  (lock M2 numeric intent on Stone night / high-key / low-sat / Log /
  Urban-below-Stone / persisted refresh)

Out of scope for M2:
- Cube generation. The cube SHAs do not change because `colorParams` is
  untouched; only `paramOverrides` shifts in the manifest re-bake.
- Resolver structure / new score fields. M2 is constants-only.

## Anti-haze Invariants (carry-over from M1C)

The resolver must never write any of these:

- `fade`
- `bloomThreshold`
- `shadowTone` as a latitude lever
- `diffusion` from a broad `night * opticsScale` driver
- `bloomStrength` / `halationIntensity` / `rgbShift` when `highKey` is high

Tests below assert each invariant.

## Implementation Plan

1. **Resolver gains (Stone)** — flagship pass:
   - `highKeyCompressionGain` 0.40 → 0.48
   - `logFlatCompression`     0.36 → 0.44
   - `highKeyPrintGain`       0.22 → 0.28
   - `logFlatPrintGain`       0.30 → 0.36
   - `contrastGain`           0.13 → 0.17
   - `saturationGain`         0.18 → 0.23
   - `digitalSoftnessGain`    0.26 → 0.30
   - `practicalBloomGain`     0.58 → 0.86
   - `practicalHalationGain`  0.50 → 0.72
   - `practicalRgbShiftGain`  0.018 → 0.028
   - `vignetteGain`           0.09 → 0.11

2. **Resolver gains (Urban)** — cooler sibling, visible below Stone:
   - `highKeyCompressionGain` 0.28 → 0.34
   - `logFlatCompression`     0.26 → 0.32
   - `highKeyPrintGain`       0.16 → 0.20
   - `logFlatPrintGain`       0.21 → 0.26
   - `contrastGain`           0.10 → 0.13
   - `saturationGain`         0.13 → 0.17
   - `digitalSoftnessGain`    0.20 → 0.24
   - `practicalBloomGain`     0.72 → 1.00
   - `practicalHalationGain`  0.62 → 0.86
   - `practicalRgbShiftGain`  0.026 → 0.038
   - `vignetteGain`           0.07 → 0.09

3. **Resolver unconditional floor** — Stone-scale ordinary material
   should already feel like a Look on first frame:
   - `compressionAdd` floor 0.075 * scale → 0.105 * scale
   - `printAdd` floor       0.010 * scale → 0.014 * scale

4. **Catalog baselines (Stone)** — modest texture lift:
   - `grainIntensity` 0.010 → 0.013
   - `lensSoftness`   0.045 → 0.070
   - `vignette`       0.085 → 0.100

5. **Catalog baselines (Urban)** — same direction, slightly stronger:
   - `grainIntensity` 0.010 → 0.013
   - `lensSoftness`   0.10  → 0.115
   - `vignette`       0.08  → 0.095

6. **TS-side parity** — mirror the same `paramOverrides` values into
   `packages/film-lab-core/src/creative-pack-01.ts` for Stone / Urban.
   Re-run `bun run scripts/build-creative-luts.ts --regenerate` so the
   manifest reflects the new baked `paramOverrides`. Cubes themselves
   are recomputed deterministically from `colorParams` and should keep
   the same SHA-256 values.

7. **Test thresholds** — update
   `apps/capacitor-film-lab-ios/scripts/swift/test-look-director.swift`
   to lock M2 numeric intent:
   - Night Stone: `compressionAmount > 0.10`, `contrast > 1.06`,
     `saturation > 1.07`, bloom delta 0.045–0.080, halation delta
     0.040–0.075, rgbShift delta 0.0015–0.0028, anti-haze invariants
     unchanged.
   - High-key Stone: `compressionAmount > 0.36`, `compressionRange <
     0.36`, print > base + 0.22, `contrast > 1.10`, glow keys still
     nil.
   - Low-sat Stone: `compressionAmount > 0.36`, print > base + 0.28,
     `saturation > 1.16`, `contrast > 1.08`, diffusion delta 0.012 –
     0.035, bloom delta < 0.020.
   - Log Stone: `compressionAmount > 0.36`, print > base + 0.28,
     log softness ≤ non-log softness.
   - Ordinary Stone: `compressionAmount < 0.22`, print < base + 0.20,
     bloom < base + 0.025.
   - Urban below Stone on bloom / halation / rgbShift deltas (Urban
     scale 0.7 keeps effective magnitude below the flagship).
   - Persisted refresh: stale `fade` / `bloomThreshold` overlay wiped,
     stale strong `bloomStrength` / `halationIntensity` overlays wiped,
     non-overlay grain / lensSoftness keys reset to new M2 baseline.

## Verification

- `bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh`
- `bun test packages/film-lab-core/src/creative-pack-01.test.ts`
- `bun run scripts/build-creative-luts.ts --verify`
- `bun run verify:ios`
- `git diff --check`
- Debug iOS build for the paired iPhone, then `xcrun devicectl device
  install app` so owner can open the M2 build immediately.

## Done Conditions

- Resolver / catalog / TS-side / manifest / tests all aligned.
- Anti-haze invariants assertable from the resolver test output.
- All verification gates exit 0.
- iPhone install completes (or hardware is unavailable and noted).
- None / Noir / persisted refresh paths still pass tests.

## Stop Conditions

- A descriptor / schema change demands a `Profile.version` bump (M2 is
  constants only — none expected).
- Cube SHA-256s drift unexpectedly under `--regenerate` (would mean a
  bake input changed by accident).
- Tests fail in a way that suggests the anti-haze invariants moved.
- Performance posture changes (a new stage would need to be added). M2
  is uniform changes only.

## Out Of Scope

- Cube re-authoring (Stone display-Palermo + Urban Green-Density bakes
  remain identical).
- Noir tuning.
- New score fields on the source descriptor.
- New Look entries.
- Commit / push / PR / portfolio bump (waiting on owner instruction).

## Copy / History Impact

- Copy: none changed in M2.
- Article Opportunity: pending owner-side visual judgement.
- Change-History Opportunity: bundled to the same "source-aware Look
  Director" narrative as M1 — M2 is a tuning pass, not a new
  architecture story.

## Verification

Run on 2026-05-13 JST in the dedicated worktree on top of the M1 closeout
state. All gates green:

```bash
bun run scripts/build-creative-luts.ts --regenerate  # exit 0 (no SHA change)
bun run scripts/build-creative-luts.ts --verify      # exit 0
bun test packages/film-lab-core/src/creative-pack-01.test.ts  # 7 pass / 0 fail / 121 expects
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh
# reports: Look Director resolver tests passed
bun run verify:ios       # exit 0
git diff --check         # exit 0
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -configuration Debug \
  -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -derivedDataPath .build/ios-device build   # BUILD SUCCEEDED
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  .build/ios-device/Build/Products/Debug-iphoneos/App.app
# App installed: bundleID com.chibatakumi.film.lab.ios
```

The `.build/ios-device` tree was removed after install. Creative Pack 01
cube SHA-256 values did not change (only `colorParams` would shift them
and that input was untouched); pinned values in `FilmtoneBuiltInCatalog`
remain valid.

## Unexpected Blockers

None.

## Implementation Capture

- **Motivation**: M1 closed Stone as "passable but conservative,
  compression working" and Urban "below Stone but visible". Owner asked
  for a stronger image ceiling without revisiting the M1A→M1C haze
  failure modes (gray toe, milky veil, broad sky bloom).

- **Approach**: M2 is constants-only. No new render stages, no new
  source-descriptor fields, no cube re-bake — just bigger pushes through
  the same handles that survived the M1 anti-haze filter. The Stone
  display-Palermo cube (M3-era) is preserved; the Urban Palermo Green
  Density cube is preserved; Noir is untouched.

- **Stone resolver gains**: highKey / log-flat compression, print, contrast,
  saturation, digital softness, practical bloom / halation / rgbShift and
  vignette all stepped up. The "unconditional floor" on compression
  (0.075 → 0.105 * scale) and print (0.010 → 0.014 * scale) means ordinary
  material now also reads as a Look, not a near-passthrough, while the
  high-key / log / low-sat bands move proportionally further up.

- **Urban resolver gains**: same direction but kept below Stone by the
  Urban 0.7x scale and 0.85x night optics scale. Raw practical bloom /
  halation / rgbShift gains are now higher than Stone's raw values
  (1.00 / 0.86 / 0.038 vs Stone 0.86 / 0.72 / 0.028) to compensate for
  the scale factors; effective deltas still come out below Stone, as
  asserted by the resolver tests.

- **Catalog baselines**: Stone gets `lensSoftness 0.045 → 0.07`,
  `grainIntensity 0.010 → 0.013`, `vignette 0.085 → 0.10`. Urban gets
  `lensSoftness 0.10 → 0.115`, `grainIntensity 0.010 → 0.013`,
  `vignette 0.08 → 0.095`. Noir is preserved. These bumps keep ordinary
  material visibly Look-treated and pair with the new compression /
  print floor.

- **TS-side parity**: Stone TS values are kept fully aligned with Stone
  Swift M2. Urban TS values were already out of sync with Urban Swift
  after M1 closeout (TS Urban runs with a cooler optical recipe than
  iOS Urban — `bloomStrength 0.18 / halation 0.055 / vignette 0.06`
  vs iOS `0.16 / 0.06 / 0.08`). Rather than overwrite that uncommitted
  state, M2 applies the same *delta* to Urban TS (lensSoftness +0.015,
  grainIntensity +0.003, vignette +0.015) so the catalog moves in the
  same direction on both sides. Bringing Urban TS / iOS to identical
  optical recipe values is left as a follow-up that the owner can size
  separately.

- **Test thresholds**: night Stone compression > 0.10, contrast > 1.06,
  saturation > 1.07, bloom delta 0.045 – 0.085, halation 0.040 – 0.075,
  rgbShift 0.0014 – 0.0028. High-key / low-sat / log compression > 0.36
  with print > base + 0.22 / + 0.28. Ordinary stays below 0.22 / base +
  0.12 / base + 0.030. Urban below Stone on each glow metric.
  Persisted-refresh fade / threshold / diffusion / strong-bloom /
  strong-halation overlays all wiped; grain / lensSoftness reset to new
  M2 baseline automatically.

- **Performance posture**: zero new render stages. All changes are
  uniform value lifts on existing `Print` / color ops / `GlowFamily` /
  radial RGB split / `DetailSoftness` / `Vignette` paths. The catalog
  baseline grain / softness / vignette were already non-zero pre-M2, so
  no stage gets enabled here. Sidecar profiling (`avgRenderMsPerFrame`,
  `GlowFamily`, `DetailSoftness`) remains the measurement surface; M2 is
  expected to land in the same envelope as M1 closeout because the
  uniforms are the only delta.

- **Anti-haze invariants preserved**: resolver still never writes
  `fade`, `bloomThreshold`, `shadowTone` as a latitude lever, broad
  night `diffusion`, or any glow on high-key material. Tests assert
  each invariant in the night / high-key cases.

- **Follow-ups for the owner**: (a) on-device three-source visual A/B
  vs the M1 build; (b) decide whether Urban TS / iOS optical recipes
  should be unified or kept divergent; (c) whether to revisit Noir in a
  later M2.x pass — it stayed completely untouched here.
