# Desktop iOS Parity: Built-in Conversion LUT Handoff (2026-05-02 JST)

## Purpose

次のチャットでは、Filmtone Desktop の Log Conversion を iOS の Camera Profile / Source Profile 体験に追いつかせる。

具体的には、Desktop でユーザーが `.cube` を自前で読み込まなくても、備え付けの変換 LUT を選べるようにする。対象は iOS 側で進んでいる Source Profile catalog と同等の入力変換で、ルック適用前の `lut1` lane に入る。

この handoff は実装前提を残すためのもの。ここに書いた内容は次チャットの入口として使い、実装前に必ず live source と照合する。

## Current Repository State

- Repo root: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
- Current branch at handoff time: `main`
- `git status --short --branch` at handoff time:
  - `## main...origin/main`
  - iOS app / fastlane / source-profile related dirty changesあり
  - 新規 docs / fixtures / screenshots もあり
- HEAD at handoff time:
  - `72c7c5e Fix iOS Files import from external storage`
- HEAD and `origin/main` both resolved to `72c7c5e` when checked for this handoff.
- Recent relevant commits include:
  - `95b6321 Add Stone and Urban creative LUTs`
  - `6aeaf3d feat(ios): stamp optics+glow into saved Look identity`
  - `fea09ff feat(ios): land fullscreen-first Liquid Glass IA + Recipe→Look unification`
  - `41ad634 fix(ios): preserve Look optics+glow signature on apply`
  - `c430e35 feat(creative-pack-01): add rgbShift to Stone + Urban as Filmtone signature`
  - `d70eef6 feat(creative-pack-01): differentiate Stone and Urban personalities`
  - `0400611 chore(filmtone-ios): bump to v1.4 build 1 (Phase I)`
  - `72c7c5e Fix iOS Files import from external storage`

Important dirty-worktree note:

- Do not revert or overwrite the current iOS dirty worktree.
- The iOS source-profile files are the reference surface for the next Desktop parity work.
- If a file is dirty and outside the Desktop parity scope, leave it alone.
- Do not stage, commit, push, or touch portfolio unless explicitly asked.

Release/version truth was not checked for this handoff. If the next chat needs to state current public Desktop/iOS versions, it must run:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

## Repo Rules That Matter

Read these first in the next chat:

- `AGENTS.md`
- `apps/desktop-film-lab-batch/README.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md` only for iOS reference rules

Operational rules to preserve:

- Use `bun`, not npm/yarn/pnpm.
- Product quality is priority. Do not choose a weaker implementation just to avoid touching shared core if shared core is the right product move.
- Core behavior first, outer-shell QA/doc polish last.
- Use `sequential-thinking` for architecture, source-profile parity decisions, and product-quality tradeoffs.
- Prefer independent parallel reads/checks.
- Do not hand-edit generated Swift.
- Do not remove tracked `packages/film-lab-renderer/dist/`.
- Copy rule: use `動画`, not `短尺動画`; use `video`, `videos`, or `footage`, not active positioning such as `short-form video`.

## What Just Happened Before This Handoff

### Optical filter profile work is implemented

Recent Desktop/shared work added the new Lens Filter profile system:

- New core catalog:
  - `packages/film-lab-core/src/optical-filter-profiles.ts`
  - `packages/film-lab-core/src/optical-filter-profiles.test.ts`
- New API:
  - `OpticalFilterFamily`
  - `OpticalFilterDensity`
  - `OPTICAL_FILTER_PROFILES`
  - `getOpticalFilterProfile(id)`
  - `buildOpticalFilterParamPatch(id): Partial<Params>`
- Initial profiles:
  - `blackMist-1-8`, `blackMist-1-4`, `blackMist-1-2`
  - `cineBloom-5`, `cineBloom-10`, `cineBloom-20`
  - `warmMist-1-8`, `warmMist-1-4`
  - `pearlGlow-subtle`, `pearlGlow-1-4`
  - `cleanSoft-subtle`
- New neutral-default optical direct/scatter Params:
  - `opticalDirectTransmission`
  - `opticalBlackRetention`
  - `opticalScatterStrength`
  - `opticalHighlightReactivity`
  - `opticalWarmScatter`
  - `opticalSpectralTail`
- WebGPU composite now supports profile-enabled `direct + scatter` using existing bloom/halation/diffusion signals.
- Desktop export metadata can carry selected optical filter profile metadata.
- `FilmLabControlPanelCore` now has a compact `Lens Filter` selector at the head of Finish Tools.
- Halo Prism is frozen from the product surface by `HALO_PRISM_CONTROLS_VISIBLE = false` in `FilmLabControlPanelCore.tsx`.

Verification already run during prior work:

```bash
bun test packages/film-lab-core/src/optical-filter-profiles.test.ts
bun test packages/film-lab-core/src/optical-recommendation.test.ts
bun run build:core
bun run build:renderer
bun test apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.test.ts
bun run check:filmtone-copy
bun run typecheck:desktop
bun run verify:desktop
git diff --check
```

Desktop UI was browser-checked with Playwright after the Lens Filter refinement:

- `Lens Filter` is now family row + density chip, not a two-column large card grid.
- `Black Mist 1/4` selection was confirmed.
- Native `title` tooltip was removed from the Lens Filter buttons.
- `Halo Prism` is not visible; `Lens Filter` is followed by `Mist` and `Cross`.

This matters because the next Desktop Log Conversion UI should match this more compact, tool-like direction. Avoid returning to large marketing/card selector layouts inside the control panel.

## Next Task Product Goal

Desktop currently has two LUT lanes:

- `lut1`: Log Conversion / input transform, applied before the look
- `lut2`: Creative LUT / look grade, applied after core grade path

Desktop has a `Log Conversion` section today, but it only loads arbitrary `.cube` files. The product gap is that iOS now has built-in Camera Profiles / Source Profiles, while Desktop still requires users to supply their own conversion LUT.

Target behavior:

- Desktop Log Conversion should expose built-in input profiles, at minimum:
  - Rec.709 / none
  - Apple Log
  - Apple Log 2
  - DJI D-Log
  - Canon C-Log
  - Panasonic V-Log
  - Sony S-Log3
  - Custom `.cube`
- Selecting a built-in profile should immediately update the preview by calling `viewport.setLUT1(data, size)` and `viewport.setLUT1Intensity(1)`.
- Export should use the same `lut1` data as preview.
- Custom `.cube` remains supported.
- The built-in selected profile id / curve / display name should be saved as optional metadata. Do not put profile id into `Params`.
- If a session is restored from metadata, built-in source-profile metadata should be enough to reconstruct `lut1` without requiring an absolute `.cube` path.

## iOS Reference Surface

The iOS side currently has active source-profile work in dirty files. Treat these as the reference, but do not modify them unless the user explicitly asks.

Primary files:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileSchema.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/test-source-profile-math.swift`
- `apps/capacitor-film-lab-ios/src/features/editor/CameraProfilePill.tsx`
- `apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx`
- `apps/capacitor-film-lab-ios/src/lib/messages.ts`
- `apps/capacitor-film-lab-ios/src/presets/luts/README.md`
- Source profile docs:
  - `apps/capacitor-film-lab-ios/docs/source-profile-math/dji-dlog.md`
  - `apps/capacitor-film-lab-ios/docs/source-profile-math/canon-clog.md`
  - `apps/capacitor-film-lab-ios/docs/source-profile-math/panasonic-vlog.md`
  - `apps/capacitor-film-lab-ios/docs/source-profile-math/sony-slog3.md`
- Fixtures:
  - `apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/dji-dlog/`
  - `apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/canon-clog/`
  - `apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/panasonic-vlog/`
  - `apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/sony-slog3/`

### iOS data model

`CameraProfileSelection` is a discriminated union:

```swift
case auto
case builtIn(catalogId: String)
case userImport(libraryId: UUID)
```

Wire shape:

```json
{ "kind": "auto" }
{ "kind": "builtIn", "catalogId": "built-in:source-profile.panasonic-vlog" }
{ "kind": "userImport", "libraryId": "12345678-..." }
```

`SourceProfileCurve` values:

```text
apple-log
apple-log-2
dji-dlog
canon-clog
panasonic-vlog
sony-slog3
```

`SourceProfileImpl` cases:

```swift
case nilProfile
case nativePolicy(SourceInputTransformStrategyDTO)
case synthesized(SourceProfileCurve)
case bundledCube(libraryId: UUID)
```

Interpretation:

- `.nilProfile`: Rec.709 passthrough
- `.nativePolicy`: Apple Log / Apple Log 2, reused from existing Apple Log path in iOS
- `.synthesized`: D-Log, C-Log, V-Log, S-Log3 generated from math into 33^3 cubes
- `.bundledCube`: reserved path for future bundled `.cube`

### iOS built-in catalog

`FilmtoneSourceProfileCatalog.allProfiles` currently contains:

| Catalog id | Display | Impl | Auto detection |
|---|---|---|---|
| `built-in:source-profile.apple-log` | Apple Log | nativePolicy `.appleLogToRec709` | `appleLog` |
| `built-in:source-profile.apple-log-2` | Apple Log 2 | nativePolicy `.appleLog2ToRec709` | `appleLog2` |
| `built-in:source-profile.dji-dlog` | DJI D-Log | synthesized `.djiDLog` | none |
| `built-in:source-profile.canon-clog` | Canon C-Log | synthesized `.canonCLog` | none |
| `built-in:source-profile.panasonic-vlog` | V-Log | synthesized `.panasonicVLog` | none |
| `built-in:source-profile.sony-slog3` | S-Log3 | synthesized `.sonySLog3` | none |
| `built-in:source-profile.rec709` | Rec.709 | nilProfile | `sdrBt709` |

iOS intentionally keeps Auto separate from the catalog. V-Log / S-Log3 / D-Log / C-Log are manual because container metadata cannot reliably distinguish them.

For Desktop, do not overpromise Auto unless source metadata can prove the curve. A high-quality first step is explicit selection.

### iOS math and cube generation

`FilmtoneSourceProfileMath.swift` is the source for deterministic math:

- Shared:
  - `filmtoneSdrShoulder(_:)`
  - `rec709Encode(_:)`
  - `appleLogDecode(_:)`
- DJI D-Log:
  - `dlogDecode(_:)`
  - `dgamutToRec709(...)`
  - `dlogPixelToRec709(...)`
  - `makeDlogToRec709Cube(size: 33)`
- Canon C-Log:
  - `canonLogDecode(_:)`
  - `canonClogPixelToRec709(...)`
  - `makeCanonClogToRec709Cube(size: 33)`
- Panasonic V-Log:
  - `vlogDecode(_:)`
  - `vgamutToRec709(...)`
  - `vlogPixelToRec709(...)`
  - `makeVlogToRec709Cube(size: 33)`
- Sony S-Log3:
  - `slog3Decode(_:)`
  - `sgamut3CineToRec709(...)`
  - `slog3PixelToRec709(...)`
  - `makeSlog3ToRec709Cube(size: 33)`
- Rec.2020:
  - `rec2020ToRec709(...)`

`FilmtoneExportSession.swift` wires source-profile export:

- `makeAutomaticInputLut(for:)`
- `makeActiveInputLut(selection:probe:)`
- `makeInputLut(forImpl:)`
- `makeSynthesizedInputLut(curve:)`
- `packRgbToRgbaCubeData(rgb:size:)`
- `makeAppleLogToRec709Lut(size:rec2020GamutMap:)`
- `appleLogPixelToRec709(...)`

iOS cube ordering is sample-major with R fastest, then G, then B. Desktop renderer already accepts `Float32Array` LUT data for `setLUT1`; confirm expected RGB/RGBA layout before porting. Existing `parseCube` returns data used successfully by `viewport.setLUT1`.

## Desktop Current Surface

Primary Desktop/shared files:

- `packages/film-lab-ui/src/LUTPanel.tsx`
- `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx`
- `apps/desktop-film-lab-batch/src/renderer/App.tsx`
- `apps/desktop-film-lab-batch/src/renderer/effective-export-grade.ts`
- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts`
- `apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.ts`
- `apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts`
- `apps/desktop-film-lab-batch/src/renderer/offscreen/apply-batch-grade-to-viewport.ts`
- Renderer:
  - `packages/film-lab-renderer/src/webgpu/`
  - `packages/film-lab-renderer/src/webgl/`
- Core parser:
  - `packages/film-lab-core/src/cube-parser.ts`

Current `LUTPanel.tsx`:

- Maintains `lut2` as Creative LUT.
- Maintains `lut1` as Log Conversion.
- Has `handleLogLoad()` that opens a file picker, parses `.cube`, then calls:
  - `viewport!.setLUT1(lut.data, lut.size)`
  - `fireLutChange({ lut1: { name, data, size, intensity } })`
- Has `handleLogClear()` calling `viewport?.clearLUT1()`.
- Has `handleLogIntensity()` calling `viewport?.setLUT1Intensity(value)`.
- UI copy currently says:
  - `For Log footage (S-Log3, V-Log, Apple Log). Applied before color grading.`
  - empty state `S-Log3, V-Log, Apple Log ...`

Current Desktop export path:

- `App.tsx` stores edit LUT state:

```ts
type EditLutState = {
  lut1: { name: string; data: Float32Array; size: number; intensity: number } | null;
  lut2: { name: string; data: Float32Array; size: number; intensity: number } | null;
};
```

- `FilmLabControlPanelCore` receives `onLutChange={handleEditLutChange}`.
- `buildEffectiveExportGradeSnapshot()` copies `editLut.lut1` into:
  - `grade.lut1Data`
  - `grade.lut1Size`
  - `grade.lut1Intensity`
  - `lutRefs.lut1`
- Offscreen export applies `lut1`:
  - `apps/desktop-film-lab-batch/src/renderer/offscreen/apply-batch-grade-to-viewport.ts`
  - calls `viewport.setLUT1(grade.lut1Data, grade.lut1Size)` and `viewport.setLUT1Intensity(...)`.
- Batch pipeline supports `lut1CubeRelPath`, but built-in selection currently has no catalog id or regeneration path.
- Metadata currently stores `lutRefs.lut1` as:

```ts
type MetadataLutRef = {
  enabled: boolean;
  intensity: number;
  displayName: string | null;
  absolutePath: string | null;
};
```

This is path-oriented. Built-ins need an optional metadata field that is not path-based.

## Recommended Implementation Shape

Quality-first path:

1. Move source-profile catalog/math into shared core, not Desktop-only UI code.
2. Desktop UI consumes the shared catalog to build built-in `lut1`.
3. Desktop metadata stores source-profile provenance.
4. iOS can remain untouched for this task unless shared extraction is deliberately coordinated later.

Suggested new core file:

```text
packages/film-lab-core/src/source-profile-conversion.ts
packages/film-lab-core/src/source-profile-conversion.test.ts
```

Suggested exported API:

```ts
export type SourceProfileCurve =
  | "apple-log"
  | "apple-log-2"
  | "dji-dlog"
  | "canon-clog"
  | "panasonic-vlog"
  | "sony-slog3";

export type SourceProfileId =
  | "built-in:source-profile.rec709"
  | "built-in:source-profile.apple-log"
  | "built-in:source-profile.apple-log-2"
  | "built-in:source-profile.dji-dlog"
  | "built-in:source-profile.canon-clog"
  | "built-in:source-profile.panasonic-vlog"
  | "built-in:source-profile.sony-slog3";

export type SourceProfileImplKind =
  | "nil-profile"
  | "native-policy"
  | "synthesized";

export interface SourceProfileCatalogEntry {
  id: SourceProfileId;
  displayName: string;
  curve: SourceProfileCurve | null;
  impl: SourceProfileImplKind;
  builtIn: true;
  immutable: true;
}

export const SOURCE_PROFILE_CATALOG: readonly SourceProfileCatalogEntry[];
export function getSourceProfile(id: SourceProfileId | string): SourceProfileCatalogEntry | null;
export function buildSourceProfileLut(id: SourceProfileId | string, size?: number): {
  id: SourceProfileId;
  displayName: string;
  data: Float32Array;
  size: number;
};
```

Implementation notes:

- Generate 33^3 RGB `Float32Array` in Desktop/core format.
- Confirm renderer LUT upload expects 3-channel data, because `.cube` parser output is used directly by `setLUT1`.
- Rec.709 should clear `lut1` rather than generate identity LUT, unless metadata needs an explicit selection. Product-wise, Rec.709 means no transform.
- Apple Log / Apple Log 2 should be generated deterministically in Desktop, not delegated to AVFoundation.
- iOS uses `rec2020GamutMap: true` for Apple Log and Apple Log 2 in the current export path. Mirror that unless live source shows a better current path.
- Use the same Filmtone SDR shoulder and Rec.709 encode as iOS.
- Add a small cache for built-in LUT data if generation happens in UI. A 33^3 cube is not huge, but repeated generation on render is unacceptable.

## UI Direction

Do not use large cards for this control.

Preferred Desktop UI in `LUTPanel.tsx`:

- Keep the `Log Conversion` disclosure.
- Inside it, add a compact built-in selector before the custom `.cube` row.
- Use rows/chips or a compact segmented/dropdown style:
  - None / Rec.709
  - Apple Log
  - Apple Log 2
  - DJI D-Log
  - Canon C-Log
  - V-Log
  - S-Log3
  - Custom `.cube`
- Keep `Custom .cube` as an explicit action.
- Avoid native `title` tooltips.
- Avoid manufacturer-certified wording unless absolutely needed.
- For copy, keep it factual:
  - English: `Choose a camera profile before the look.`
  - Japanese: `ルックの前に適用するカメラプロファイルを選びます。`
- If legal/certification copy is needed, keep it subdued:
  - `Built from public color science references; not manufacturer-certified.`
  - Japanese equivalent should be short.

State model suggestion:

```ts
type LogConversionSelection =
  | { kind: "none" }
  | { kind: "builtIn"; sourceProfileId: SourceProfileId }
  | { kind: "custom"; name: string };
```

Do not store this in `Params`.

## Metadata and Restore Requirements

This is the main Desktop pitfall.

Current metadata can restore path-based LUTs by `absolutePath`, but a built-in profile has no `.cube` path. If built-in profiles are only represented as runtime `Float32Array`, session restore/export metadata import will lose the selection.

Recommended metadata addition:

```ts
export type AppliedSourceProfileMetadata = {
  selectionKind: "built-in" | "none" | "custom";
  catalogId: string | null;
  curve: SourceProfileCurve | null;
  impl: SourceProfileImplKind | null;
  displayName: string;
  appliedAtIso: string;
};
```

Possible placement:

- Add `look.sourceProfile` or `input.sourceProfile` to `FilmtoneExportSessionV1`.
- `input.sourceProfile` is semantically clean because this is source/input transform, not a look parameter.
- Existing optical profile metadata lives under `look.opticalFilterProfile`; source profile should not be conflated with optical look metadata.

Restore path should:

- If `sourceProfile.selectionKind === "built-in"` and `catalogId` exists:
  - regenerate `lut1` via `buildSourceProfileLut(catalogId)`
  - set `batchGrade.lut1Data`, `lut1Size`, `lut1Intensity`
  - restore display metadata without requiring an absolute path
- If custom `.cube`:
  - preserve current absolute-path restore path
- If none/Rec.709:
  - clear `lut1`

Update or add tests around:

- `export-metadata-session.test.ts`
- `metadata-json-runtime.test.ts`
- `effective-export-grade.test.ts`

## Suggested Work Plan for Next Chat

1. Read `AGENTS.md` and run `git status --short --branch`.
2. Read this handoff and verify live source around iOS source profiles.
3. Port source-profile catalog/math to `film-lab-core`.
4. Add core tests against iOS fixtures where practical.
5. Extend `LUTPanel.tsx` with compact built-in Log Conversion selector.
6. Wire built-in selection to `viewport.setLUT1`, `onLutChange`, and clear/custom flows.
7. Add source-profile metadata and restore logic.
8. Verify Desktop preview/export path.
9. Keep iOS dirty worktree untouched unless the user explicitly expands scope.

## Test Plan for Next Chat

Core:

```bash
bun test packages/film-lab-core/src/source-profile-conversion.test.ts
bun run build:core
```

Desktop targeted tests:

```bash
bun test apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts
bun test apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.test.ts
bun run typecheck:desktop
```

Renderer/package:

```bash
bun run build:renderer
```

Final Desktop gate:

```bash
bun run verify:desktop
git diff --check
```

If UI copy changes:

```bash
bun run check:filmtone-copy
```

If the next chat uses a browser to visually verify:

- Start Vite in `apps/desktop-film-lab-batch`.
- Open `http://127.0.0.1:5173`.
- Confirm:
  - Log Conversion shows built-in camera profiles.
  - Selecting each built-in updates the active state.
  - `lut1` intensity remains available.
  - Custom `.cube` still works.
  - Export sync picks up the built-in `lut1`.
  - No large tooltip overlays.

## Known Product Risks

- Desktop source metadata may not distinguish V-Log / S-Log3 / D-Log / C-Log. Do not ship an unreliable Auto detection story for these.
- Apple Log / Apple Log 2 parity must be checked carefully because iOS currently uses native policy semantics but ultimately builds a LUT in export. Desktop should generate the same transform.
- Metadata restore is easy to miss. Built-in LUT data must be reconstructable from catalog id, not from an absolute `.cube` path.
- If source-profile math is copied from Swift to TypeScript, fixture tests are mandatory. Silent math drift is a product-quality bug.
- Built-in input transform is not a creative LUT. Keep it in `lut1`, before the look.
- Do not make this a new landing-page-like UI surface. It belongs in Log Conversion as a compact tool.

## Highest-Precision Handoff Prompt for the Next Chat

Paste this into the next chat:

```text
We are in /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone.

Task: make Filmtone Desktop catch up to iOS for built-in conversion LUTs / Camera Profiles. Specifically, Desktop Log Conversion currently only loads custom .cube files; add built-in source-profile conversion choices equivalent to iOS: Rec.709/none, Apple Log, Apple Log 2, DJI D-Log, Canon C-Log, Panasonic V-Log, Sony S-Log3, plus Custom .cube.

First:
1. Read AGENTS.md.
2. Run git status --short --branch.
3. Read docs/filmtone/desktop/desktop-ios-parity-built-in-conversion-lut-handoff-2026-05-02-jst.md.
4. Inspect the live iOS reference files, but do not revert or overwrite dirty iOS worktree changes:
   - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileSchema.swift
   - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift
   - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift
   - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
   - apps/capacitor-film-lab-ios/scripts/swift/test-source-profile-math.swift
   - apps/capacitor-film-lab-ios/docs/source-profile-math/
   - apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/
5. Inspect the Desktop/shared surfaces:
   - packages/film-lab-ui/src/LUTPanel.tsx
   - packages/film-lab-ui/src/FilmLabControlPanelCore.tsx
   - apps/desktop-film-lab-batch/src/renderer/App.tsx
   - apps/desktop-film-lab-batch/src/renderer/effective-export-grade.ts
   - apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts
   - apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.ts
   - apps/desktop-film-lab-batch/src/renderer/offscreen/apply-batch-grade-to-viewport.ts
   - packages/film-lab-core/src/cube-parser.ts

Use sequential-thinking for the architecture decision before implementation.

Implementation target:
- Put source-profile catalog/math in shared core, likely packages/film-lab-core/src/source-profile-conversion.ts.
- Export a catalog and buildSourceProfileLut(id, size=33) returning a Float32Array compatible with viewport.setLUT1.
- Port/mirror iOS math for Apple Log, Apple Log 2, DJI D-Log, Canon C-Log, V-Log, and S-Log3, including Filmtone SDR shoulder and Rec.709 encode.
- Add tests, preferably using the iOS source-profile fixtures where practical.
- Update LUTPanel Log Conversion UI with a compact built-in Camera Profile selector. Do not use large card grids. Avoid native title tooltips.
- Selecting a built-in profile must immediately call viewport.setLUT1(data, size), set intensity to 1, update active state, and flow through onLutChange so export uses the same lut1 data.
- Custom .cube must continue to work.
- Rec.709/none should clear lut1, while preserving explicit metadata if needed.
- Add optional source-profile metadata so built-in selections can be restored without an absolute .cube path. Do not put profile id into Params.
- Update metadata restore so a built-in catalog id regenerates lut1 on import/resume/export.
- Keep iOS parity in mind but do not edit iOS unless necessary and explicitly within scope.

Verification:
- bun test packages/film-lab-core/src/source-profile-conversion.test.ts
- bun run build:core
- bun test apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts
- bun test apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.test.ts
- bun run build:renderer
- bun run typecheck:desktop
- bun run verify:desktop
- bun run check:filmtone-copy if UI copy changes
- git diff --check
- If UI is changed, run a local Desktop renderer browser check and confirm the built-in Log Conversion selector is compact, active state works, Custom .cube remains, and no tooltip overlays appear.

Important constraints:
- Use bun only.
- Product quality is priority; do not choose a weaker Desktop-only shortcut if shared core is the right architecture.
- Do not touch/revert unrelated dirty iOS/fastlane/screenshot changes.
- Do not stage/commit/push unless explicitly asked.
- Do not claim latest release/version/App Store state unless truth scripts are run.
```
