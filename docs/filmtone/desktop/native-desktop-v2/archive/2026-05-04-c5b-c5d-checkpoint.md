# Active Task: M3 C5b/C5d Checkpoint

Date: 2026-05-04 JST

## Scope

Strategy milestone: **M3 Native Color And Optics Parity**.

This active task exists to checkpoint the current uncommitted C5b/C5d work,
verify that it still matches the intended iOS-canonical pipeline direction, and
prepare it for review/commit. Do not add new rendering features in this task.

## Current Worktree Context

- Branch: `feature/native-desktop-plan`
- Current HEAD at task creation: `ad23753`
- Observed uncommitted scope: C5b A.2, C5b A.3, C5d, and related plan updates.
- Existing code changes are treated as in-progress user/agent work. Do not
  revert them.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneStillExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `docs/filmtone/desktop/native-desktop-v2/active.md`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/native-desktop-transition-plan-2026-05-03-jst/01-current-state-and-decision.md`
- `docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md`
- `docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/native-desktop-transition-plan-2026-05-03-jst/06-quality-gates-risks.md`
- iOS canonical color/optics sources under `apps/capacitor-film-lab-ios/ios/App/App/`
- Desktop Look Unification status in the main checkout

## Steps

- [x] Confirm the dirty worktree still contains only the C5b/C5d checkpoint plus
      the new planning docs.
- [x] Review the pipeline order against the iOS canonical driver.
- [x] Confirm source-seed wiring is present for still export, video export, and
      preview.
- [x] Run the minimum contract checks.
- [x] Run the native macOS build.
- [x] Run targeted parity/smoke checks for reset and iphone.
- [x] Record any expected PSNR changes in this file.
- [x] If the checkpoint is clean, ask for review/commit direction.
      Direction received 2026-05-04: proceed with recommendation (single
      bundled commit; agent archives active and updates strategy; INV-7 leaves
      git commit to user).
- [x] After completion, move this file to `archive/2026-05-04-c5b-c5d-checkpoint.md`
      and append a 1-3 line note to `strategy.md`.

## Verification Results (2026-05-04 JST)

Worktree scope (5 Swift Edit Targets + 4 in-progress plan docs from prior
session + new v2 docs untracked):

```
 M apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift
 M apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift
 M apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneStillExporter.swift
 M apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift
 M apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift
 M docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/filmtone-native-desktop-transition-plan-2026-05-03-jst.md
 M docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/native-desktop-transition-plan-2026-05-03-jst/01-current-state-and-decision.md
 M docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md
 M docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/native-desktop-transition-plan-2026-05-03-jst/06-quality-gates-risks.md
?? docs/filmtone/desktop/native-desktop-v2/
```

Out-of-scope (iOS / Electron / shared-core schema) is not touched.

Pipeline order vs iOS canonical (`FilmtoneExportSession.swift:1547-1563`):

| Stage | iOS | macOS (`FilmtoneGradePipeline.swift`) | Status |
|---|---|---|---|
| applyInputLutStage | L1547 | absent | LOW (built-in 4 presets are no-op) |
| applyBaseGradeV2 | implied | L47 | match |
| applyFilmCompressionV2 | implied | L50 | match |
| applyEdgeOpticsStage | L1553 | L52 | match |
| applyGlowFamilyStage | L1555 | L53 | match |
| applyVignetteStage | L1557 | L55 | match |
| applyGrainStage | L1559 | L59 (`sourceSeed` passed) | match |
| applyCreativeLutStage | L1561 | absent | LOW (built-in 4 presets are no-op) |
| applyPrintStage | L1563 | L68 | match (printContrast gate is non-abs; built-in non-negative only) |

Source-seed wiring (`FilmtoneGradePipeline.makeStableSourceSeed(from:)`,
verbatim FNV-1a from iOS L2411-2418):

- `FilmtoneStillExporter.swift:74` — computed from `request.sourceURL`
- `FilmtoneVideoExporter.swift:90` — computed once outside per-frame loop, passed at L147
- `PreviewSurface.swift:97` — computed from `sourceURL`, parity with export

Contract / build:

- `bun run generate:swift -- --check`: pass (no drift)
- `diff -q apps/capacitor-film-lab-ios/.../FilmtonePhase0Generated.swift apps/filmtone-desktop-macos/.../FilmtonePhase0Generated.swift`: byte-identical
- `bun run verify:macos`: BUILD SUCCEEDED
- `git diff --check`: no whitespace errors

Targeted parity (informational baseline-B, baseline-C is PENDING):

- `--preset reset`: macOS↔source mean 28.08 dB, byte-identical to A.3 (grainIntensity=0 → sourceSeed is no-op)
- `--preset iphone --image 09-skin-light`: macOS↔source 28.81 dB (mathematically invariant — sourceSeed alters grain pattern only, not intensity, so source-delta is unchanged)

The real C5d effect is observable only on macOS↔baseline-C, which is gated on
baseline-C population (out of scope for this checkpoint).

## Remaining Risks

- LOW: `applyInputLutStage` / `applyCreativeLutStage` not yet ported. No effect
  on built-in 4 presets (reset / iphone / dehancer / kodak) which carry no LUT.
  Required only when LUT-bearing custom Looks are added.
- LOW: macOS `applyPrintStage` gates on `printContrast > epsilon` (no `abs`);
  iOS gate is symmetric. All built-in presets use non-negative printContrast.
- LOW: macOS apply driver does not end with `cropped(to: image.extent)`. All
  individual stages preserve extent today, so this is currently latent.

These are tracked as separate follow-ups, not blockers for this checkpoint.

## Verification

Minimum commands:

```bash
bun run generate:swift -- --check
diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
        apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
bun run verify:macos
bun run scripts/golden-parity-macos.ts --preset reset
bun run scripts/golden-parity-macos.ts --preset iphone --image 09-skin-light
git diff --check
```

Optional only when formal QA is requested:

```bash
bun run scripts/golden-parity-ios-vs-macos.ts --preset reset
```

## Done Conditions

- Worktree scope is understood and no unrelated files are mixed into the active
  task.
- Native macOS build passes.
- Generated Swift drift is zero.
- Reset and iphone smoke/parity numbers are recorded.
- Any remaining C5b/C5d risks are explicit.
- No iOS project, Electron runtime behavior, or shared core schema change is
  introduced by this checkpoint task.

## Out Of Scope

- SPM consolidation.
- Baseline-C population.
- New UI work beyond existing preview/source-seed wiring.
- Look Unification implementation or sidecar dual emit.
- Metal CIKernel migration.
- Packaging, signing, notarization, portfolio, or public copy.

## Unexpected

Record unexpected findings here before changing direction.
