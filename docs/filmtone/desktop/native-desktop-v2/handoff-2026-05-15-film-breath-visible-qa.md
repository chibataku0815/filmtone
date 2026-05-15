# Handoff — Film Breath Visible QA

Created: 2026-05-15 23:27 JST

This document is a complete handoff for the Film Breath implementation and the
follow-up visual QA issue where Desktop showed no visible difference between
Amount `0` and max.

## Current Status

- Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
- Branch: `feature/film-breath`
- Product target: Native Desktop v2 / macOS native app at
  `apps/filmtone-desktop-macos/`
- Shared targets: `packages/film-lab-core/`,
  `packages/film-lab-swift-core/`
- iOS target: `apps/capacitor-film-lab-ios/`
- Current lane file:
  `docs/filmtone/desktop/native-desktop-v2/active.md`
- Active task: `Film Breath Visible QA Fix`
- No commit, stage, push, or portfolio submodule bump has been done.
- There is a running Desktop debug process:
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app/Contents/MacOS/Filmtone`
- Important: after the latest retune, the Desktop debug build passed, but the
  app was not relaunched and visually rechecked. The running process may still
  be the pre-retune binary.

## User Intent And Product Constraints

The original user request was to implement `Film Breath` / `フィルムブレス` for
Desktop and iOS simultaneously, for video preview and video export only.

Core product decisions from the user request:

- One control only: `Film Breath` Amount.
- No Dehancer-compatible multi-control UI.
- Reference Dehancer only for category framing: temporal exposure, contrast,
  and color changes.
- Still images must not show the UI.
- If a saved Look or sidecar carries `filmBreathAmount` into still processing,
  still output must stay exact identity because `timeSeconds = 0`.
- First version does not include Gate Weave, screen shake, scratches, dust, or
  scan jitter.
- iOS live capture monitor is out of scope. iOS editor preview/export is in
  scope.
- Sidecar schema remains V1 and additive. Emit
  `gradeParams.filmBreathAmount`; do not bake temporal changes into static LUTs.
- Product quality is prioritized over conservative minimalism.

The user later reported that visual QA showed no visible difference between
Amount `0` and max, including screenshots around `24.72s`. That changed the
active goal from "implementation complete" to "make max visibly useful."

## Repository Rules That Matter

From `AGENTS.md`:

- Desktop means native macOS app under `apps/filmtone-desktop-macos/`.
  Do not use or edit the legacy Electron app unless the user explicitly says
  legacy Electron / old Desktop / rollback.
- Native Desktop v2 work requires exactly one current
  `docs/filmtone/desktop/native-desktop-v2/active.md`.
- Work only inside current `active.md` scope.
- On completion, record verification in `active.md`, move it to
  `archive/YYYY-MM-DD-{slug}.md`, and append only a short note to
  `strategy.md`.
- Do not stage, commit, push, notarize, or bump the portfolio submodule unless
  explicitly asked.
- Use `bun`, not npm/yarn/pnpm.
- Generated Swift must be regenerated, not hand-edited.
- Product changes that affect public copy/history require context/copy impact
  notes and checks.

## Documents Created Or Changed

Created / changed lane and article docs:

- `docs/filmtone/desktop/native-desktop-v2/active.md`
  - Current active task: `Film Breath Visible QA Fix`.
  - This should remain active until visual QA confirms the retune.
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-15-film-breath.md`
  - Archive of the first Film Breath implementation pass. It was archived too
    early, before visual QA found the max/no-op issue.
- `docs/filmtone/desktop/native-desktop-v2/paused/2026-05-15-twilight-bundled-look.md`
  - Previous Twilight active task was paused before Film Breath work started.
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
  - Has a short Film Breath completion note from the first pass. If final visual
    QA changes direction materially, update with only a short corrected note.
- `docs/filmtone/articles/2026-05-15-film-breath/README.md`
  - Article foundation only, not publish-ready copy.
- This handoff:
  `docs/filmtone/desktop/native-desktop-v2/handoff-2026-05-15-film-breath-visible-qa.md`

## Implementation Summary

### Shared TypeScript Core

Files:

- `packages/film-lab-core/src/params.ts`
- `packages/film-lab-core/src/phase0-schema.ts`
- `packages/film-lab-core/src/schema.ts`
- `packages/film-lab-core/src/presets.ts`
- `packages/film-lab-core/src/index.ts`
- `packages/film-lab-core/src/film-breath.ts`
- `packages/film-lab-core/src/film-breath.test.ts`
- `packages/film-lab-core/src/phase0-schema.test.ts`
- `packages/film-lab-core/src/schema.test.ts`
- `packages/film-lab-core/src/ios-phase0.test.ts`
- `packages/film-lab-core/src/ios-swift-payload.test.ts`
- `packages/film-lab-core/dist/index.js`
- `packages/film-lab-core/dist/index.d.ts`

Changes:

- Added `filmBreathAmount` to `PARAM_KEYS` and `Params` immediately after
  `trailIntensity`.
- Added `filmBreathAmount` to `PHASE0_PARAM_KEYS` directly after
  `trailIntensity`.
- Added schema/default/range support:
  - Default: `0`
  - Accepted range: `0...1`
  - Out-of-range rejected.
- Added `filmBreathAmount: 0` to all preset defaults.
- Added `deriveFilmBreathOffsets(amount, timeSeconds, sourceSeed)`.
- Exported Film Breath helper/types from `src/index.ts`.
- Built `dist/` via `bun run build:core`.

Current TypeScript Film Breath limits after retune:

```ts
const FILM_BREATH_LIMITS = {
  exposure: 0.16,
  contrast: 0.055,
  temperature: 0.09,
  tint: 0.04,
} as const;
```

Original limits from the first plan were:

```text
exposure ±0.055EV
contrast ±0.020
temperature ±0.030
tint ±0.015
```

Reason for retune:

- User-provided screenshots showed Amount `0` and max looked visually identical
  at around `24.72s`.
- Propagation and frame-time wiring appeared correct.
- Therefore max needed a stronger visible range while preserving `0` identity
  and subtle default/Strong behavior.

### Shared Swift Core

Files:

- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtonePhase0Params.swift`
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneFilmBreath.swift`
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift`
- `packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/FilmBreathTests.swift`
- `packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/GeneratedLandmarkTests.swift`
- `packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/Phase0CodableTests.swift`

Changes:

- Added `filmBreathAmount` to `FilmtonePhase0Params` property/init/keyPaths.
- Regenerated generated Swift payload with `bun run generate:ios-swift`.
- Added `FilmtoneFilmBreath` and `FilmtoneFilmBreathOffsets`.
- Swift helper mirrors the TypeScript helper and applies offsets to:
  - `exposure`
  - `contrast`
  - `temperature`
  - `tint`
- Clamp after applying:
  - exposure `-2...2`
  - contrast `0...2`
  - temperature `-1...1`
  - tint `-1...1`
- Current Swift limits after retune:
  - exposure `0.16`
  - contrast `0.055`
  - temperature `0.09`
  - tint `0.04`

### Film Breath Algorithm

Identity:

- `amount <= 0` returns zero offsets.
- `timeSeconds <= 0` returns zero offsets.
- Non-finite time returns zero offsets.
- This is required so still paths remain identity.

Drive:

```text
drive = amount^1.35
envelope = smoothstep(timeSeconds / 1.25)
scale = drive * envelope
```

Noise:

- Deterministic seed from source URL via existing stable source seed.
- Smooth low-frequency value noise, no frame-random flicker.
- Combined periods:
  - slow: `4.8s`
  - medium: `8.6s`
  - long: `15.5s`
- Output is bounded and smooth between adjacent 24fps frames.

Important product implication:

- `Strong` recipe remains `filmBreathAmount = 0.28`.
- With `amount^1.35`, Strong remains subtle even after max retune.
- Amount max is intended to be visibly inspectable.

### Desktop

Files:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePresetCatalog.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtoneDesktopStrings.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
- `apps/filmtone-desktop-macos/Verify/CoreCatalogStoreStringTests.swift`
- `apps/filmtone-desktop-macos/Verify/run.sh`

Changes:

- `FilmtoneGradePipeline.apply(...)` now computes:

```swift
let renderParams = FilmtoneFilmBreath.applying(
    to: params,
    timeSeconds: frameTimeSeconds,
    sourceSeed: sourceSeed
)
```

- The pipeline then uses `renderParams` for base grade, compression, shadow
  latitude, detail softness, edge optics, glow, vignette, grain, creative LUT,
  and print stage.
- Stage placement is after source/input transform and before base grade.
- `frameTimeSeconds` and `sourceSeed` already existed for video/grain.
- Still path does not pass frame time, so default `0` keeps identity.
- Advanced Motion group has a video-only `Film Breath` row:
  - range `0...1`
  - digits `2`
  - label `Film Breath` / `フィルムブレス`
- Motion recipes:
  - Default: `filmBreathAmount = 0`
  - Strong: `filmBreathAmount = 0.28`
- Sidecar `gradeParams` now includes `filmBreathAmount`.
- Sidecar writer also gained missing `detailSoftness` because contract expansion
  surfaced that existing omission in verification.
- Desktop verifier object list includes `FilmtoneFilmBreath.swift.o`.

Desktop visual QA follow-up change:

- `EditorState.startVideoSessionPrepare(for:)` now seeks to
  `videoPreviewSeconds` if it already exists and the session is paused.
- `EditorState.startVideoDurationProbe(for:)` now sets
  `initialPreviewSeconds = duration * 0.5` and seeks the session there if it
  already exists, paused, and not scrubbing.
- This fixes the first suspected issue: opening a video could leave AVPlayer at
  `0s`, where Film Breath is intentionally identity.

However:

- The user then provided screenshots at around `24.72s` showing no visible
  difference between `0` and max.
- That indicates the initial-time fix was not enough.
- Latest retune raised the shared max limits.
- Retuned build passed, but the app has not yet been relaunched and visually
  rechecked.

### iOS

Files:

- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtonePhase0Math.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneStrengthSheetData.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Strings/FilmtoneStrings.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift`

Changes:

- `Phase0ParamsDTO` includes `filmBreathAmount` after `trailIntensity`.
- Production DTO decode defaults missing `filmBreathAmount` to `0`.
- Contract verifier support DTO mirrors that additive decode behavior.
- `FilmtonePhase0Math.asDTO()` includes `filmBreathAmount`.
- `clampParam` handles `filmBreathAmount` as `0...1`.
- Backlight Veil merge path preserves `filmBreathAmount`.
- `FilmtoneExportSession.applyGrade(...)` wraps params with Film Breath offsets
  before applying grade.
- iOS editor/export paths use `timeSeconds` / `sourceSeed`.
- iOS live capture monitor intentionally not changed.
- Strength sheet Motion group includes `Film Breath` / `フィルムブレス`.
- Motion recipes:
  - Default: `0`
  - Strong: `0.28`

Important:

- Full `bun run verify:ios` passed before the latest max-range retune.
- After the retune, only Swift package Film Breath tests and Desktop build were
  rerun. A future agent should rerun `bun run verify:ios` before considering the
  task complete because iOS consumes the shared Swift helper.

## Visual QA Timeline

1. Initial implementation completed and verified by automated gates.
2. Debug Desktop app was launched from:

```bash
open -n /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
```

3. User reported: `0でも1でも変化がないです`.
4. A new current active lane was created:
   `docs/filmtone/desktop/native-desktop-v2/active.md`
5. Source inspection found:
   - Desktop Advanced value should reach `currentGradeRecipe`.
   - Video preview passes `request.compositionTime` to the grade pipeline.
   - Video export passes positive frame time to the grade pipeline.
   - But initial AVPlayer frame could remain at `0s`.
6. Patched initial midpoint seek in `EditorState.swift`.
7. Ran `bun run verify:desktop` and `git diff --check`; both passed.
8. Relaunched Debug app.
9. User provided screenshots at max and `0`, still showing no visible difference.
10. Sequential reasoning concluded this is now amount-response tuning, not just
    propagation.
11. Retuned max caps:
    - exposure: `0.055 -> 0.16`
    - contrast: `0.02 -> 0.055`
    - temperature: `0.03 -> 0.09`
    - tint: `0.015 -> 0.04`
12. Added tests that max is visually inspectable on a representative frame and
    still smooth at 24fps.
13. Ran post-retune focused verification and Desktop build successfully.
14. User interrupted and requested this handoff before relaunching the app and
    visually rechecking the retuned build.

## Verification History

Initial implementation verification passed:

- `bun test packages/film-lab-core/src/film-breath.test.ts packages/film-lab-core/src/phase0-schema.test.ts packages/film-lab-core/src/schema.test.ts packages/film-lab-core/src/ios-phase0.test.ts packages/film-lab-core/src/ios-swift-payload.test.ts`
  - 109 pass.
- `bun run build:core`
  - passed.
- `bun run generate:ios-swift`
  - regenerated generated Swift payload.
- `swift test --package-path packages/film-lab-swift-core`
  - 76 pass.
- `bun run verify:desktop`
  - native macOS build passed.
- `bash apps/filmtone-desktop-macos/Verify/run.sh`
  - 143 pass.
- `./apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh`
  - passed after additive `filmBreathAmount = 0` decode fix.
- `bun run verify:ios`
  - passed before latest max-range retune.
- `bun run check:filmtone-context`
  - passed.
- `bun run check:filmtone-copy`
  - passed.
- `git diff --check`
  - passed.

After first no-op report / midpoint seek fix:

- `bun run verify:desktop`
  - passed.
- `git diff --check`
  - passed.
- Debug app relaunched.

After user screenshots / max-range retune:

- `bun test packages/film-lab-core/src/film-breath.test.ts`
  - 5 pass.
- `swift test --package-path packages/film-lab-swift-core --filter FilmBreathTests`
  - 4 tests pass.
- `bun run build:core`
  - passed and regenerated `packages/film-lab-core/dist/`.
- `git diff --check`
  - passed.
- `bun run verify:desktop`
  - passed. The command completed successfully after the user interruption.

Still needed before final completion:

- Relaunch the Desktop debug app after retune.
- Recheck visual difference at Amount `0` vs max on the same footage.
- If visual QA passes:
  - run `swift test --package-path packages/film-lab-swift-core`
  - run `bun run verify:ios`
  - run `bash apps/filmtone-desktop-macos/Verify/run.sh`
  - run `bun run check:filmtone-context`
  - run `bun run check:filmtone-copy`
  - run `git diff --check`
  - update `active.md`, archive it, and add a short strategy note.
- If visual QA still fails:
  - continue tuning Film Breath amount response and/or confirm the exact runtime
    value in the app with instrumentation.

## Current Dirty Worktree Shape

Expected dirty/untracked areas include:

- Desktop app source changes under `apps/filmtone-desktop-macos/`
- iOS app source changes under `apps/capacitor-film-lab-ios/`
- Core TypeScript source/tests/dist under `packages/film-lab-core/`
- Swift package source/tests/generated payload under
  `packages/film-lab-swift-core/`
- Active/archive/paused/article docs under `docs/filmtone/`

Do not revert these. They are the current Film Breath implementation and
follow-up work.

## Immediate Next Steps

1. Relaunch the Desktop debug app so it uses the retuned binary:

```bash
pkill -f '/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app/Contents/MacOS/Filmtone' || true
open -n /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
```

2. Ask the user to compare the same frame/clip with Film Breath `0` vs max.

3. If the difference is now visible and acceptable:

- Mark the visual QA item complete in `active.md`.
- Run the full verification set listed above.
- Archive `active.md` to something like:
  `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-15-film-breath-visible-qa-fix.md`
- Add a short strategy note only if the strategy state changed.

4. If still not visible enough:

- Do not add Gate Weave, scratches, dust, image shake, or translation.
- Increase amount response again or adjust noise phase/axis balance.
- Keep `amount = 0` and `timeSeconds = 0` exact identity.
- Preserve one-control UI.
- Keep iOS and Desktop in sync by editing both TS and Swift helpers.

## High-Precision English Handoff Prompt

Use the following prompt in a new chat for maximum continuity:

```text
You are continuing work in the Filmtone repository at
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone on branch
feature/film-breath.

First, read AGENTS.md and follow it exactly. This is Native Desktop v2 work, so
use apps/filmtone-desktop-macos/ as the Desktop target and do not touch the
legacy Electron app. Read:
- docs/filmtone/desktop/native-desktop-v2/active.md
- docs/filmtone/desktop/native-desktop-v2/handoff-2026-05-15-film-breath-visible-qa.md
- docs/filmtone/desktop/native-desktop-v2/archive/2026-05-15-film-breath.md

Context:
Film Breath / フィルムブレス has been implemented as a single video-only Motion
Amount control across shared TypeScript core, shared Swift core, Native Desktop,
and iOS. It adds filmBreathAmount after trailIntensity in the shared contract,
uses deterministic low-frequency temporal offsets for exposure/contrast/
temperature/tint, and must remain exact identity when amount = 0 or
timeSeconds = 0. Still-image UI must remain hidden and still renders must stay
identity even if saved Looks carry filmBreathAmount.

Important current state:
- The first implementation passed automated verification but Desktop visual QA
  showed no visible difference between Amount 0 and max.
- A follow-up active task exists: "Film Breath Visible QA Fix".
- The first suspected issue was that AVPlayer could remain at 0s, where Film
  Breath is intentionally identity. EditorState.swift was patched to seek the
  paused video preview to the midpoint after session/duration probing.
- The user then provided screenshots at about 24.72s showing 0 and max still
  looked visually identical.
- The latest change retuned max Film Breath caps from the originally subtle
  values to:
  exposure 0.16, contrast 0.055, temperature 0.09, tint 0.04.
  Keep drive = amount^1.35.
- After that retune, these passed:
  bun test packages/film-lab-core/src/film-breath.test.ts
  swift test --package-path packages/film-lab-swift-core --filter FilmBreathTests
  bun run build:core
  git diff --check
  bun run verify:desktop
- The Desktop debug app has NOT yet been relaunched and visually rechecked after
  the retune. There may still be a running pre-retune Filmtone process.

Your immediate task:
1. Check git status.
2. Relaunch the retuned Desktop debug app:
   pkill -f '/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app/Contents/MacOS/Filmtone' || true
   open -n /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
3. Ask or help the user visually compare the same video frame with Film Breath
   Amount 0 vs max.
4. If max is now visibly useful, run the remaining full verification:
   swift test --package-path packages/film-lab-swift-core
   bun run verify:ios
   bash apps/filmtone-desktop-macos/Verify/run.sh
   bun run check:filmtone-context
   bun run check:filmtone-copy
   git diff --check
   Then update active.md, archive it, and append only a short strategy note if
   needed.
5. If max is still not visible enough, continue product-quality tuning. Do not
   add Gate Weave, scratches, dust, image translation, or multi-control UI. Keep
   one control, keep 0/timeSeconds=0 identity, and keep Desktop/iOS shared logic
   in sync.

Do not stage, commit, push, or edit the portfolio submodule unless explicitly
asked. Do not revert existing dirty worktree changes; they are part of the Film
Breath implementation and QA follow-up.
```

