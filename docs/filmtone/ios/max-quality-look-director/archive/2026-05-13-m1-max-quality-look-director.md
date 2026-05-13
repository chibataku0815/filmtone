# M1 - Max Quality Look Director Pilot

Opened: 2026-05-13 JST
Lane: iOS Max Quality Look Director
Branch: `feature/ios-max-quality-look-director`
Worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-ios-max-quality-look-director`

## Status

**M1C black-floor-first pivot (2026-05-13 JST)**: Owner-side review after
M1A-strong / M1B showed the visual direction was still wrong on
night/practical material. The Look Director was reaching for `fade`,
lowering `bloomThreshold` on night, and adding broad diffusion — all three
of those handles read as global haze (gray shadows, milky veil, lantern
glow bleeding into the whole frame) instead of film signature. M1C
replaces that approach instead of tuning numbers:

- **dropped from the resolver**: the `fade` adaptation block (the black
  floor must not be lifted), the `bloomThreshold` night-lowering line,
  the broad `night * opticsScale` bloom drive, and the broad
  `night * opticsScale` diffusion drive.
- **night quality now built from**: the display-domain Stone cube, modest
  contrast and saturation drives, vignette where shadow coverage is genuinely
  heavy, plus
  localized bloom and halation gated against `highKey` so the kernel
  cannot blow a daylight sky.
- **persisted refresh hardened**: the editor store's launch / source /
  profile refresh now writes the FULL Pack 01 catalog baseline on top of
  the persisted `paramOverrides` (not just the adaptation overlay keys).
  This is the migration mechanism for projects saved from earlier
  installs — stale `grainIntensity`, `lensSoftness`, `halationHue`,
  `bloomRadius`, and `rgbShift` values get overwritten with the current
  M1C catalog every refresh.
- **Pack 01 catalog baselines**: the conservative M1B-shape baselines
  (Stone diffusion 0.045, lensSoftness 0.11, bloomStrength 0.18,
  bloomThreshold 0.66, printContrast 0; Urban diffusion 0.045, lensSoftness 0.10,
  bloomThreshold 0.67; Noir keeps its denser print structure) are the
  static texture; the resolver does the directional work on top.

The tests now lock M1C anti-haze invariants (no `fade` written ever,
`bloomThreshold` never written by the resolver, night `diffusion` delta
< 0.005, night bloom / halation deltas capped at small localized
values) and include a persisted-refresh case asserting stale M1A-strong
overlay + baseline values are wiped on merge.

**Previous AI-executable scope**: Implementation at `27a14e30` carried the Look
Director resolver, source-aware wiring into `applyCameraProfile` / `applyProbe`,
the `fade`-not-`shadowTone` correction, the 1px-edge Laplacian guard, six
resolver test cases, and green `bun run verify:ios` + `git diff --check` gates.

**Final Owner Gate**: Closed for M1 after owner-side review. The M1 gate failed
on visual delta; M1A-strong / M1B / M1C failed on visual direction (global haze
or gray Stone output instead of a black-floor-safe signature). M2 stopped the
breakage but lost too much of the Palermo character. M3 restored Palermo safely
but remained conservative. M4 made Stone passable by restoring source-aware
localized optics without reintroducing haze, then raised Urban to the same
visible practical-light direction before closeout. Further image-quality
improvement moves to a separate task.

**No-Look passthrough correction (2026-05-13 JST)**: Owner found exports look
wrong even with Look set to `None`. Code inspection showed the chip only cleared
`creativeLut`; Stone's baked `paramOverrides` / quick state / derived params
could remain active. `None` now resets the project to reset preset defaults,
empty overrides, zero quick state, and nil Creative LUT so it behaves as a true
no-Look baseline. Owner confirmed the `None` export is now correct, so the
remaining visual work can compare Stone against a valid source-equivalent
baseline instead of debugging the base export path.

**M2 Stone cube / recipe re-authoring (2026-05-13 JST)**: Owner confirmed the
remaining failure is option 2 — Stone itself is still visually wrong against the
now-correct `None` baseline. Code inspection found two root causes:

- Stone's bundled cube was derived from `DJI_DLOG-M-Palermo.cube`, a source
  transform intended for Log-like input, then applied as a downstream Creative
  LUT on display-referred material. That explains the gray / sleepy direction.
- The M1C assumption that `printContrast` deepens blacks was wrong for the
  current `printStage`: its sigmoid can lift the deepest shadows. Night must
  not use strong print as a black-floor lever.

M2 changes Stone to a display-referred Filmtone recipe cube, removes Stone's
Palermo Reference source-cube dependency, reduces Stone runtime
`printContrast` to a guarded floor on night, and keeps high-key / Log print
movement only where black-floor preservation is less critical.

**M3 Stone Palermo display adaptation (2026-05-13 JST)**: Owner confirmed M2
removed the breakage but the image quality was still too low; the key question
was whether the good part of `DJI_DLOG-M-Palermo` had been preserved. It had
not: M2 intentionally cut the source cube. M3 restores Palermo through a
correct-domain adapter instead of direct reuse:

- build-time Stone now maps each display Rec.709 lattice point into an
  approximate D-Log M / D-Gamut M input, samples `DJI_DLOG-M-Palermo.cube`,
  then protects the black floor before writing the display-domain cube;
- Stone optical baseline is pulled back hard (`diffusion`, `lensSoftness`,
  `rgbShift`, `bloomStrength`) so existing lens blur/glow in the footage does
  not become sleepy haze;
- cube tests now assert Stone is source-derived from Palermo, not a byte copy,
  and that black/shadow/mid/skin/red-lantern sample points stay bounded.

**M4 Stone optics/glow adaptation (2026-05-13 JST)**: Owner confirmed M3 is
safe but still conservative, and explicitly requested optical/glow adaptation.
M4 keeps the M1C anti-haze invariant (`fade` nil, no `bloomThreshold` lowering,
no broad night diffusion) while making the optical response source-aware:

- Stone night/practical now raises localized `bloomStrength` and
  `halationIntensity` from measured `highlightCoverage` multiplied by
  `nightPracticalScore`, not from night alone;
- `rgbShift` becomes an adaptation overlay key and receives a tiny
  practical-light-only lift, replacing stale persisted over-strong values with
  a bounded source-aware value;
- high-key material still emits no bloom / halation / rgbShift so sky wash
  remains structurally blocked;
- low-saturation flat material keeps only a small bloom tail and mild
  diffusion texture.

**M4 Urban closeout (2026-05-13 JST)**: Owner judged Stone acceptable, with
compression working but still conservative, and requested the same treatment on
Urban to close this task. Urban now keeps its cooler 0.7x Look scale but raises
its source-aware practical-light bloom / halation / `rgbShift` gains so the
effective optical delta is visible and below Stone rather than disappearing into
restraint. The same anti-haze guards remain in force: no `fade`, no
`bloomThreshold` lowering, no broad night diffusion, and no high-key sky glow.

## Goal

Implement the first batched iOS pilot that materially raises built-in Look image
quality through source-aware decisions, while keeping verification intentionally
small. This active should produce a shippable-quality direction or a concrete
measured reason to route follow-up tuning/performance work to M2/M3.

## Product Posture

Maximum image quality is the primary objective. Do not avoid optical/detail
changes just because they cost more than color-only changes. Instead, make the
cost visible through existing profiler/sidecar metrics and keep preview/export
behavior tiered.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Source/SourceProbeService.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneBuiltInCatalog.swift`
- Potential new Swift file:
  `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneLookDirector.swift`
- If a new Swift file is added:
  `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- Focused Swift script test under
  `apps/capacitor-film-lab-ios/scripts/swift/`
- This lane doc, for checklist and verification updates only.

## Read-Only References

- `AGENTS.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `docs/filmtone/ios/README.md`
- `docs/filmtone/detail-softness/strategy.md`
- `apps/capacitor-film-lab-ios/docs/builtin-catalog.md`
- Existing editor apply paths:
  `FilmtoneEditorStore`, `EditorProjectMutationCoordinator`,
  `EditorCaptureRelay`
- Existing performance/profiler code:
  `FilmtoneExportSession`, `ExportMetrics`, `OpticsCompositor`

## Implementation Checklist

- [x] Create dedicated worktree from latest `origin/main`.
- [x] Create lane placement under
      `docs/filmtone/ios/max-quality-look-director/`.
- [x] Fix `sourceDetailBias` resolution so explicit built-in
      `CameraProfileSelection` contributes the matching `sourceProfileId`.
      (`FilmtoneExportSession.resolveSourceDetailBias(from:cameraProfile:)`
      now threads `cameraProfile.builtIn.catalogId` into the
      `FilmtoneSourceDetailCompensationInput.sourceProfileId` slot.)
- [x] Strengthen source tone analysis without per-frame render cost:
      - images: same thumbnail, but now also computes a 4-neighbor
        Laplacian and warm/saturated highlight ratios;
      - videos: sample at 20% / 50% / 80% (max 3 frames) and merge with
        percentile averaging plus max-merging coverage/score signals;
      - derived compact scores: `nightPracticalScore`, `highKeyScore`,
        `lowSaturationFlatScore`, `digitalHardnessScore` — all optional
        on `FilmtoneSourceToneDescriptor`.
- [x] Descriptor shape: backward-compatible optional fields on
      `FilmtoneSourceToneDescriptor` (no schema bump). Codable uses
      `decodeIfPresent` so legacy sidecars / saved looks load unchanged.
      Type moved to its own file `Source/FilmtoneSourceToneDescriptor.swift`
      so the focused test can link it without UIKit dependencies.
- [x] Implement Look Director resolution for current Creative Pack 01
      built-ins. (`Look/FilmtoneLookDirector.swift` +
      `Look/FilmtoneCreativePack01Adaptation.swift`.) Per-Look weights:
      Stone is the flagship at full scale, Urban at 0.7x, Noir at 0.55x
      with optics restraint because the bundled cube already carries
      heavy print structure.
- [x] Make the resolver intentionally high-impact:
      - `creativeLut.intensity` lifted up to 1.0 on Log/flat material,
        pulled back to ≥0.82 on night-practical to protect saturated
        signage;
      - `compressionAmount` / `compressionRange` adjusted on high-key
        and flat material;
      - `fade` (shadow-only toe-lift, the actual latitude handle) raised
        on shadow-heavy frames, capped at 0.10 so it never reads matte.
        The earlier draft wrote `shadowTone`, but `shadowTone` in
        baseGradeV2 is the density-dependent split-tone chroma direction
        (multiplies `shadowChroma` from `shadowHue`), not a latitude
        knob — using it would tip shadow color cast instead of giving
        the toe headroom;
      - `detailSoftness` added on digital-hardness source, then pulled
        back proportionally to `sourceDetailBias` so the export-stage
        bias is not double-applied;
      - `bloomStrength` / `bloomThreshold` / `halationIntensity` /
        `diffusion` raised over the catalog baseline for night
        material (Noir holds steady);
      - `vignette` deepens only on shadow-heavy frames on Stone /
        Urban; Noir's deep catalog vignette is preserved.
- [x] Preserve existing built-in apply surfaces so editor, saved-look
      apply, and capture relay resolve the same adaptation. All three
      now pass `sourceProfileId` + `sourceDetailBias` via
      `FilmtoneLookDirector.sourceProfileId(for:)` and
      `FilmtoneLookDirector.resolveSourceDetailBias(probe:cameraProfile:)`
      so they pick the same profile as the export pipeline.
- [x] Re-resolve adaptation when source / Camera Profile changes after
      the Look is already applied. The first draft baked adaptation at
      apply-time and never re-derived, so swapping clips or changing
      profile left a stale overlay. `FilmtoneEditorStore.refreshCreative`
      `Pack01AdaptationIfApplicable()` recomputes overlay + intensity
      from the current `probe.sourceToneDescriptor` /
      `sourceProfileId` / `sourceDetailBias`, restores catalog baseline
      on dropped overlay keys (no lingering values from a prior source),
      and is wired into both `applyCameraProfile` and `applyProbe`.
      Trade-off: user tweaks on overlay keys
      (`fade` / `compressionAmount` / `detailSoftness` / bloom / halation
      / diffusion / vignette) are overwritten on source/profile change —
      consistent with the M1 thesis that the Look is supposed to respond
      to the new source.
- [x] Guard the source-probe 4-neighbor Laplacian on
      `width > 2 && height > 2`. The first draft would trap with an
      invalid `1..<(n - 1)` range on 1px-edge images; the gate keeps the
      Laplacian a no-op for degenerate thumbnails and the descriptor
      still emits its base luma / saturation signals.
- [x] Add focused resolver tests covering five cases:
      night/practical light, bright/high-key, low-saturation, Log/profile
      material, and ordinary material. Plus a sixth `runLegacyDescriptorCase`
      that verifies the resolver still works when optional scores are nil.
- [x] Run minimum automated verification:
      - `bash apps/capacitor-film-lab-ios/scripts/swift/test-look-director.swift`
        is invoked via `verify-phase0-contract.sh` step
        `==> look director resolver test`. Reports `Look Director
        resolver tests passed`.
      - `bun run verify:ios` exit 0 (Phase 0 contract + iOS xcodebuild
        on Debug for `arm64-apple-ios26.0-simulator`).
      - `git diff --check` exit 0.
- [x] Prepare the three-source visual/performance check protocol for the
      owner. The on-device export run itself is the **Final Owner Gate**
      below — physical iPhone hardware + owner-owned footage + visual
      delta judgement cannot run inside the AI-executable scope, so it
      is split out as a final-stage gate rather than an
      AI-blocking implementation task.
- [x] M1A visible-pass correction after owner-side failure on all three
      representative sources:
      - strengthen Stone / Urban / Noir Pack 01 baseline optics and print
        density so selected Looks have a product-level signature before
        source-specific adaptation;
      - strengthen source-aware compression, compression knee, printContrast,
        contrast, saturation, diffusion, fade, bloom, and halation where the
        descriptor indicates high-key, Log/flat, low-saturation, or night
        practical material;
      - keep the implementation on existing params / optics stages so no new
        per-frame render path is introduced in M1A.
- [x] M1A-strong follow-up after pre-retest review showed the unconditional
      floor and Pack 01 baseline still looked light when descriptor scores
      stayed near zero:
      - Pack 01 catalog bumps (Stone printContrast 0.075→0.115, bloomStrength
        0.26→0.31, halationIntensity 0.105→0.125, diffusion 0.10→0.12,
        lensSoftness 0.13→0.15, grainIntensity 0.012→0.019, vignette 0.085
        →0.105; Urban / Noir scaled proportionally);
      - resolver weight bumps (Stone highKeyCompressionGain 0.34→0.40,
        logFlatCompression 0.30→0.36, highKeyPrintGain 0.18→0.22,
        logFlatPrintGain 0.24→0.30, contrastGain 0.10→0.13, saturationGain
        0.14→0.18, digitalSoftnessGain 0.22→0.26, nightFadeBoost 0.09→0.11,
        vignetteGain 0.075→0.09; Urban / Noir scaled proportionally);
      - director unconditional floor (`compressionAdd 0.045 → 0.075`,
        `printAdd 0.055 → 0.085` per `weights.scale`) so even ordinary
        material shows a visible Look signature;
      - glow-family adds and clamps (`bloomAdd 0.18→0.22`, `halationAdd
        0.075→0.10`, `diffusionAdd 0.08→0.105`, clamps loosened to match);
      - compressionRange knee shift `-0.24*lowSat - 0.12*highKey` →
        `-0.28*lowSat - 0.16*highKey`, lower clamp 0.22→0.20.
- [x] Re-run focused resolver tests with stricter "visible delta" thresholds.
      Night Stone fade>0.06→>0.08, compressionAmount>0.08→>0.10,
      printContrast>base+0.08→>base+0.10. High-key Stone
      compressionAmount>0.30→>0.40, compressionRange<0.40→<0.36,
      printContrast>base+0.20→>base+0.25, contrast>1.05→>1.08. Low-sat
      compressionAmount>0.30→>0.40, printContrast>base+0.25→>base+0.28,
      saturation>1.10→>1.13, contrast>1.04→>1.06. Log compressionAmount>0.30
      →>0.40, printContrast>base+0.25→>base+0.28. Ordinary clamps loosened
      (compressionAmount<0.14→<0.20, printContrast<base+0.12→<base+0.18) to
      admit the new floor while keeping the source-specific bands distinct.
- [x] Re-run `bun run verify:ios` and `git diff --check`.
- [x] Rebuild and install the M1A-strong app onto the paired iPhone for owner
      retest.
- [x] Ensure persisted Pack 01 projects pick up M1A-strong on app launch,
      not only when the owner re-taps a Look or swaps source.
- [x] M1B black-floor correction after owner screenshot showed M1A-strong
      moved night/practical material in the wrong direction:
      - reduce Stone / Urban / Noir broad diffusion and low-threshold bloom
        baselines so shadows stay black instead of gray;
      - cap night `fade` as a small toe lift only, with focused tests checking
        both lower and upper bounds;
      - keep visible compression / print separation while removing the
        aggressive unconditional floor that caused the milky veil;
      - keep launch-time Pack 01 refresh so installed retunes reach persisted
        projects immediately.
- [x] M1C black-floor-first pivot after owner-side review showed M1B still
      lifted the black floor on night/practical material:
      - drop the `fade` adaptation block entirely because it lifts the black
        floor instead of preserving night depth;
      - drop the `bloomThreshold` night-lowering line (catalog threshold
        stays — lowering it pulled midtones into the bloom kernel and read
        as milky veil);
      - drop the broad `night * opticsScale` bloom and diffusion drives;
        bloom and halation are now `highlightCoverage`-driven and gated
        against `highKey` so the practical-glow path cannot wash a daylight
        sky or a shadow-heavy night frame;
      - use contrast + saturation for visible separation while avoiding the
        optical haze handles that wash the frame;
      - expand `refreshCreativePack01AdaptationIfApplicable` to write the
        FULL Pack 01 catalog baseline (all keys, not just
        `adaptationOverlayKeys`) on every refresh so persisted projects
        from earlier installs migrate their stale `grainIntensity` /
        `lensSoftness` / `halationHue` / `bloomRadius` / `rgbShift`
        baseline values to the M1C catalog automatically;
      - extract the merge logic into
        `FilmtoneCreativePack01Patches.refreshedParamOverrides(...)` so it
        is unit-testable;
      - tighten focused tests to enforce M1C anti-haze invariants and add
        a `runPersistedRefreshCase` that simulates an M1A-strong-era
        persisted project and asserts the merge wipes stale overlay and
        baseline keys.
- [x] Fix `None` Look semantics after owner reported Stone and None exports
      both looked wrong:
      - clear the Creative LUT;
      - reset preset/strength/quick state to generated reset defaults;
      - clear all `paramOverrides`;
      - recompute `project.params` from the reset baseline so stale Stone
        overrides cannot survive behind the `None` chip.
- [x] M2 Stone cube / recipe re-authoring after owner confirmed Stone itself
      remains the failure against a now-correct `None` baseline:
      - stop deriving Stone from the `DJI_DLOG-M-Palermo.cube` source cube;
      - bake Stone as a display-referred Filmtone recipe cube;
      - set Stone runtime baseline `printContrast` to 0;
      - remove the night-specific print boost and guard print movement on
        night because the print sigmoid can lift the deepest shadows;
      - regenerate Creative Pack 01 cubes / manifest and update iOS pinned
        SHA-256 values;
      - add cube-level tests proving Stone is display-domain, protects deep
        shadows, and remains distinct from Urban.
- [x] M3 Stone Palermo display adaptation after owner confirmed M2 no longer
      broke the image but did not yet produce product-quality Stone:
      - reintroduce `DJI_DLOG-M-Palermo.cube` as a build-only source for
        Stone, but through a Rec.709 display → D-Log M approximation before
        sampling so Rec.709 values are not treated as Log values;
      - protect shadow luma during the adaptation so black floor cannot drift
        gray;
      - reduce Stone post-cube optical baseline to avoid adding softness,
        diffusion, and chromatic smear on already-lensed footage;
      - regenerate Stone cube / manifest and update iOS pinned SHA-256;
      - update cube tests and persisted-refresh tests to lock current Stone
        baseline instead of M1C constants.
- [x] M4 Stone optics/glow adaptation after owner confirmed M3 was stable but
      too conservative:
      - increase localized Stone practical glow by driving bloom / halation
        from `highlightCoverage * nightPracticalScore` rather than broad night
        score;
      - add `rgbShift` to adaptation overlay keys so source/profile refresh
        replaces stale persisted optical values with a bounded practical-light
        value;
- [x] M4 Urban closeout after owner accepted Stone as passable:
      - raise Urban practical-light bloom / halation / `rgbShift` effective
        deltas so it follows Stone's successful source-aware optical direction;
      - keep Urban below Stone's flagship optical delta and preserve the same
        high-key / anti-haze guards.
      - keep `fade`, `bloomThreshold`, and night diffusion structurally absent
        from the night path;
      - update focused resolver tests for visible localized glow, high-key
        optics suppression, and persisted rgbShift refresh.
- [x] Record Copy / History Impact and Article / Change-History Opportunity
      after the actual visual delta is known. (Recorded below; final
      Article Opportunity classification waits on the three-source
      visual run.)

## Verification

Run on 2026-05-13 JST in the dedicated worktree.

Re-verified after the three review-driven fixes (`fade`-not-`shadowTone`,
source/profile re-resolve in `applyCameraProfile` / `applyProbe`, small-image
Laplacian guard on `width > 2 && height > 2`) and once more on AI-executable
closeout — both gates green each time.

Minimum automated checks — all pass:

```bash
bun run verify:ios       # exit 0
git diff --check         # exit 0
```

M1A visible-pass correction, run on 2026-05-13 JST after owner reported all
three representative sources were too conservative. Re-run on the M1A-strong
follow-up the same day after the pre-retest review pushed the floor and
catalog signature further:

```bash
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh  # exit 0
bun run verify:ios                                                  # exit 0 (generated swift contract drift + xcodebuild Debug simulator + grain catalog + Phase 0 + Look Director resolver tests)
git diff --check                                                    # exit 0
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -configuration Debug \
  -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -derivedDataPath .build/ios-device build                          # exit 0 (BUILD SUCCEEDED)
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  .build/ios-device/Build/Products/Debug-iphoneos/App.app            # exit 0
```

Installed bundle: `com.chibatakumi.film.lab.ios` on iPhone 17 Pro
(`3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`). The M1A-strong changes are uncommitted
and sit on top of the prior lane commits (HEAD `3ad3cf80`, branch
`feature/ios-max-quality-look-director`, 2 commits ahead of `origin/main`). The
`.build/ios-device` artifact tree was removed after install so only intentional
source / doc changes remain in the worktree.

Launch-refresh follow-up after owner still saw no visible delta from the
installed M1A-strong build:

```bash
bun run verify:ios       # exit 0
git diff --check         # exit 0
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -configuration Debug \
  -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -derivedDataPath .build/ios-device build                          # exit 0
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  .build/ios-device/Build/Products/Debug-iphoneos/App.app            # exit 0
```

Installed bundle remains `com.chibatakumi.film.lab.ios`; `.build` removed after
install.

M1B black-floor correction after owner screenshot showed M1A-strong moved
night/practical material in the wrong direction:

```bash
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh  # exit 0
bun run verify:ios                                                  # exit 0
git diff --check                                                    # exit 0
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -configuration Debug \
  -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -derivedDataPath .build/ios-device build                          # exit 0 (BUILD SUCCEEDED)
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  .build/ios-device/Build/Products/Debug-iphoneos/App.app            # exit 0
```

Installed bundle remains `com.chibatakumi.film.lab.ios`; `.build` removed after
install.

Focused logic check — wired into the iOS swift contract gate, also
runnable standalone:

```bash
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh
# reports: ==> look director resolver test
#          Look Director resolver tests passed
```

M2 Stone cube / recipe re-authoring checks:

```bash
bun test packages/film-lab-core/src/creative-pack-01.test.ts         # exit 0
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh  # exit 0
bun run scripts/build-creative-luts.ts --verify                     # exit 0
bun run verify:ios                                                  # exit 0
git diff --check                                                    # exit 0
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -configuration Debug \
  -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -derivedDataPath .build/ios-device build                          # exit 0 (BUILD SUCCEEDED)
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  .build/ios-device/Build/Products/Debug-iphoneos/App.app            # exit 0
```

Installed M2 bundle remains `com.chibatakumi.film.lab.ios` on iPhone 17 Pro.

M3 Stone Palermo display adaptation checks:

```bash
bun test packages/film-lab-core/src/creative-pack-01.test.ts         # exit 0
bun run scripts/build-creative-luts.ts --verify                     # exit 0
bun run build:core                                                  # exit 0
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh  # exit 0
bun run verify:ios                                                  # exit 0
git diff --check                                                    # exit 0
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -configuration Debug \
  -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -derivedDataPath .build/ios-device build                          # exit 0 (BUILD SUCCEEDED)
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  .build/ios-device/Build/Products/Debug-iphoneos/App.app            # exit 0
```

Installed M3 bundle remains `com.chibatakumi.film.lab.ios` on iPhone 17 Pro.

M4 Stone optics/glow adaptation checks:

```bash
bun test packages/film-lab-core/src/creative-pack-01.test.ts         # exit 0
bun run scripts/build-creative-luts.ts --verify                     # exit 0
bun run build:core                                                  # exit 0
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh  # exit 0
bun run verify:ios                                                  # exit 0
git diff --check                                                    # exit 0
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -configuration Debug \
  -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -derivedDataPath .build/ios-device build                          # exit 0 (BUILD SUCCEEDED)
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  .build/ios-device/Build/Products/Debug-iphoneos/App.app            # exit 0
```

The focused test compiles `FilmtoneSourceToneDescriptor.swift`,
`FilmtoneCreativePack01Patches.swift`, `FilmtoneLookDirector.swift`,
`FilmtoneCreativePack01Adaptation.swift`, and
`test-look-director.swift` against the host-built `FilmLabSwiftCore`
module, then asserts seven cases: night/practical, high-key,
low-saturation flat, Log/profile (Apple Log catalog id + bias 0.06),
ordinary, a legacy descriptor with all optional scores nil, and M1C
persisted Pack 01 refresh.

Installed M4 bundle remains `com.chibatakumi.film.lab.ios` on iPhone 17 Pro.

M4 Urban closeout checks:

```bash
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh  # exit 0
bun run verify:ios                                                  # exit 0
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -configuration Debug \
  -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -derivedDataPath .build/ios-device build                          # exit 0 (BUILD SUCCEEDED)
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  .build/ios-device/Build/Products/Debug-iphoneos/App.app            # exit 0
```

The focused test now asserts Urban practical-light `bloomStrength`,
`halationIntensity`, and `rgbShift` deltas are visible, below Stone, and still
under the same anti-haze / high-key guards.

Installed M4 Urban closeout bundle remains `com.chibatakumi.film.lab.ios` on
iPhone 17 Pro.

## Final Owner Gate

Status: **closed for M1** by owner-side product judgment. Owner confirmed
`None` passthrough is correct, Stone is now passable with compression working
and no haze regression, and requested only that Urban receive the same
source-aware optical/glow direction before closing this task. Further image
quality improvements are intentionally split to a separate task.

Run on the target iPhone against the M4 installed build, comparing
each export to the prior installed build or to a no-Look baseline of the same
source. Stone is the flagship — start there. Urban / Noir should follow the
same direction at smaller magnitude:

1. **Night / practical-light** source.
2. **Bright outdoor / high-key** source.
3. **Log / profile or low-saturation flat** source.

For one representative export, enable render-stage profiling:

```bash
xcrun devicectl device process launch --device <UDID> \
  --environment-variables FILMTONE_EXPORT_RENDER_STAGE_PROFILE=24 \
  com.chibatakumi.film.lab.ios
```

For each of the three sources, paste back the following row (sidecar JSON
fields are listed for reference):

| field | source |
|---|---|
| `avgRenderMsPerFrame` | sidecar `performance.avgRenderMsPerFrame` |
| `GlowFamily` substage ms | sidecar `performance.renderStageProfile.stages[GlowFamily].incrementalAvgMsPerSample` |
| `DetailSoftness` substage ms | sidecar `performance.renderStageProfile.stages[DetailSoftness].incrementalAvgMsPerSample` |
| thermal start → end | sidecar `thermalStateAtStart` / `thermalStateAtEnd` |
| export elapsed (ms) | sidecar `exportElapsedMs` |
| preview usability | manual: does the matching preview stay responsive? |
| visual delta clearly better | manual A/B against the prior build |

Owner-side numeric sidecar table was not captured before closeout. Performance
classification for M1 is **acceptable to close / profile in follow-up**: the
final Stone + Urban closeout adds no render stages and only raises uniforms on
existing `GlowFamily` / radial RGB split paths. Any stronger optical direction
belongs to the next quality task with fresh sidecar profiling.

## Done Conditions

AI-executable conditions:

- Implementation checklist items complete or explicitly moved out with a reason.
- Resolver cases pass (`Look Director resolver tests passed`).
- Creative Pack 01 cube tests pass.
- `bun run verify:ios` passes.
- `git diff --check` passes.

Final Owner Gate conditions:

- [x] Owner confirmed no-Look passthrough is correct.
- [x] Owner confirmed Stone is passable: conservative, but compression is
      working and the previous haze / gray failure is gone.
- [x] Urban received the same source-aware practical-light optical direction
      before closeout.
- [x] Performance classified as `acceptable to close / profile in follow-up`
      because the final closeout adds no new render stages.
- [x] Further image-quality improvements moved to a separate task.

## Stop Conditions

Stop and report instead of looping when any of these fires:

- Done conditions are met.
- A descriptor/schema change requires a real `Profile.version` bump.
- New Swift file registration becomes ambiguous after one pbxproj repair
  attempt.
- `bun run verify:ios` or the Xcode build fails three consecutive times.
- The three-source check shows `avgRenderMsPerFrame` regresses by more than
  35% on all three sources, or thermal end state reaches `serious` / `critical`
  on the short check.
- Visual direction fails on two or more representative sources.

## Out Of Scope

- Metal optics productionization, unless M1 closes by routing to M3.
- Depth-aware video rendering.
- Depth-aware still-image implementation; only notes may be captured for M4.
- Desktop/macOS parity.
- Public web, App Store metadata, release notes, or portfolio updates.
- New settings UI or user-facing copy.
- Commit, push, PR, or portfolio submodule bump without explicit owner request.

## Unexpected Blockers

- 2026-05-13 JST: owner-side visual check reported all three representative
  sources were nearly indistinguishable from source. This fired the visual
  direction stop condition for the first M1 pass. Owner clarified the failure
  applies to night/practical, bright/high-key, and Log/flat, so the lane was
  reopened as M1A visible-pass correction instead of waiting on final signoff.
- 2026-05-13 JST: pre-retest review of the uncommitted M1A direction showed
  the unconditional floor and Pack 01 baseline still looked light when
  descriptor scores stay near zero — the very scenario the first M1 retest
  failed on. Lane was strengthened in place as M1A-strong (Pack 01 baselines,
  resolver weights, unconditional floor, glow-family adds, knee shift, test
  thresholds) and re-installed on the paired iPhone for owner retest in a
  single pass.
- 2026-05-13 JST: owner reported the installed M1A-strong build still looked
  indistinguishable. Code inspection found a product-path gap: a persisted
  project that already had a Pack 01 Look keeps the old baked
  `project.paramOverrides` across app installs. The new catalog/resolver values
  only reached the image after re-tapping the Look, changing source, or changing
  Camera Profile. Added launch-time Pack 01 refresh so the installed build
  updates the active preview/export state immediately.
- 2026-05-13 JST: after launch refresh made the M1A-strong values visible,
  owner screenshots showed the image quality was wrong: black floor lifted to
  gray, scene contrast collapsed, and lantern glow became a broad veil. This
  identifies the primary bad handles as high night `fade`, low bloom threshold,
  broad diffusion, and oversized glow uniforms. Retuned as M1B to preserve
  deep shadows and localize practical-light optics.
- 2026-05-13 JST: M1B preserved the M1A-strong number-tuning approach (smaller
  fade, higher bloom threshold) but kept the same handles in play, so the
  black floor still drifted on night material. Pivoted to M1C: structural
  removal of every adapter that can lift the black floor or wash the frame —
  no `fade`, no threshold lowering, no broad diffusion, no broad bloom drive.
  Persisted refresh expanded to force the full Pack 01 baseline on every merge
  so old installs migrate cleanly without a `Profile.version` bump.
- 2026-05-13 JST: owner confirmed `None` is now correct but Stone remains
  wrong, which fired the M1 visual-direction stop condition and moved the lane
  into M2 Stone cube / recipe re-authoring. Root cause: Stone was using a
  D-Log M-oriented Palermo source cube as a downstream Creative LUT, and the
  assumed black-floor lever (`printContrast`) actually lifts deepest shadows
  through the current sigmoid print stage. Reauthored Stone as a
  display-referred recipe cube and guarded night print movement.
- 2026-05-13 JST: owner confirmed M2 removed the breakage but Stone no longer
  carried enough `DJI_DLOG-M-Palermo` quality. Pivoted to M3: preserve the
  Palermo source as a build-only reference, but adapt it into display Rec.709
  with a D-Log M inverse approximation and black-floor guard. Also reduced
  Stone optics so the Look is not adding broad softness to already-blurred
  footage.
- 2026-05-13 JST: owner judged M4 Stone acceptable but still conservative,
  with compression visibly working. Closed M1 by applying the same
  source-aware localized optical/glow direction to Urban at a visible
  below-Stone effective delta, then moving stronger future quality work to a
  separate task.

## Copy / History Impact

Implementation landed in the worktree on 2026-05-13 JST. The first owner-side
three-source visual check failed for weak delta, M1A-strong / M1B failed for
visual direction, M1C exposed that Stone itself was authored in the wrong
domain, and M2 showed that removing the bad-domain Palermo source also removed
too much quality. M3 restored the Palermo character safely; M4 closed the task
by making Stone passable and lifting Urban into the same source-aware
optical/glow direction.

- Copy / History Impact: No public-copy change in this active. The
  user-facing strings, Look picker labels, and App Store metadata are
  untouched. A future release note may mention "Stone / Urban / Noir
  now respond to source material" without specifying parameters, but
  that wording is deferred until the visual delta is signed off.
- Article Opportunity: **Developer note**. The result is important product
  direction but still conservative visually; the next quality task should earn
  a Short post only after a stronger before/after is demonstrable.
- Change-History Opportunity: **Developer note**. M1 changes the
  Filmtone iOS Look authoring narrative from "static recipes per
  Look" toward "source-aware Look Director coordinating LUT
  intensity, optics, and detail bias from import-time signals." This
  is worth recording because it explains why
  `FilmtoneCreativePack01Adaptation.resolve(...)` returns non-nil for
  Creative Pack 01 entries when it used to no-op, and why
  `FilmtoneSourceToneDescriptor` gained optional score fields.

## Performance posture

Per the lane brief, performance is treated as gate-by-measurement, not
a reason to dial back image quality. M1 records:

- Source probe: image path adds one 4-neighbor Laplacian sweep over
  the same 96-pixel-long-edge thumbnail (≤9216 pixels). Constant cost
  per import, runs off the render path.
- Video probe: was sampling 1 frame mid-clip; now samples 3 (20% /
  50% / 80%). Triples import-time decode but stays bounded and runs
  once per import.
- Per-frame export after M4: no new custom render path or new analysis pass.
  Stone and Urban use the existing `CreativeLut`, `Print`, `GlowFamily`,
  radial RGB split, and `DetailSoftness` paths. M1 is acceptable to close; the
  next stronger image-quality task should capture sidecar stage timing before
  increasing optical ambition further.
