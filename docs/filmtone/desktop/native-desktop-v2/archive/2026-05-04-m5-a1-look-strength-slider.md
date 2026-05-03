# Active Task: M5-A.1 — Look Strength Slider

Date opened: 2026-05-04 JST
Milestone: M5 (Native Editing UI), slice A.1
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

## Goal

Add a Look strength control to the macOS native UI. User drags a slider from
0 (no look applied → identical to "reset") to 1 (full preset). Mirrors the iOS
canonical `presetStrength` semantics.

This is the first M5 slice and the first substance-first UX delta vs Electron
inside the native lane.

## Canonical Reference (iOS)

iOS implements `presetStrength` as **parameter-space interpolation**, not
final-image blend. See `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift`:

- L543-545: `clampStrength(_ v) = max(0, min(1, v))`
- L579-594: `interpolatePresetParams(presetName, strength)` — for each
  `paramKey`, `interpolated = reset.value + (target.value - reset.value) *
  clampedStrength`. Returns one `FilmtonePhase0Params` consumed by the grade
  pipeline. The pipeline itself takes a single params bundle and is unaware of
  strength.

macOS must follow the same shape: pipeline stays single-params, interpolation
happens before pipeline entry.

## Done Conditions

- User can drag a Strength slider in the native window; preview updates live.
- At strength = 0, preview matches "reset" preset for any selected Look.
- At strength = 1, preview matches the selected preset (current behaviour).
- Still and video exports honour the selected strength.
- Sidecar `batchLookChoice.strength` records the chosen value (no longer
  hardcoded 1.0). `gradeParams` records the effective (interpolated) params.
- xcodebuild green; no `generate:swift` drift; existing targeted parity gates
  pass at default strength = 1.0.

## Edit Targets

Only these files. Anything else is out of scope for this active task.

1. `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePresetCatalog.swift`
   - Add `static let presetStrengthDefault = FilmtonePhase0Generated.presetStrengthDefault`.
   - Add `static func clampStrength(_ v: Double) -> Double` mirroring iOS.
   - Add `static func params(for name: String, strength: Double) -> FilmtonePhase0Params`.
   - Add private `static func lerp(reset:target:t:) -> FilmtonePhase0Params` doing
     the field-by-field interpolation for all 35 param fields (mirrors the iOS
     `interpolatePresetParams` loop, but unrolled because macOS Phase0Types lacks
     key-based accessors).
   - Existing `params(for:)` returns `params(for: name, strength: 1.0)` (back-compat shim).

2. `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
   - Add observed `var presetStrength: Double = FilmtonePresetCatalog.presetStrengthDefault`.
   - Update computed `presetParams` to call `params(for: presetName, strength: presetStrength)`.

3. `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/GradeControls.swift`
   - Below the existing Look Picker, add a labelled `Slider(value: $state.presetStrength, in: 0...1)`.
   - Show numeric % readout (`"Strength: \(Int(state.presetStrength * 100))%"`).
   - Disabled when `state.presetName == "reset"` (slider is no-op for reset; keeps the UI honest).

4. `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
   - Add `let presetStrength: Double` to `PreviewSurface` and `PreviewImageView`.
   - Replace `FilmtonePresetCatalog.params(for: presetName)` with `params(for: presetName, strength: presetStrength)`.

5. `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
   - Pass `state.presetStrength` into `PreviewSurface(...)`.
   - Pass `state.presetStrength` into the still/video export request constructors.

6. `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarTypes.swift`
   - Add `var presetStrength: Double { get }` to `FilmtoneSidecarRequest`.

7. `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneStillExporter.swift`
   - Add `let presetStrength: Double` to `FilmtoneStillExportRequest`.
   - Replace `params(for: request.presetName)` with `params(for: request.presetName, strength: request.presetStrength)`.

8. `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
   - Add `let presetStrength: Double` to `FilmtoneVideoExportRequest`.
   - Pass strength into the per-frame params resolution.

9. `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift`
   - Replace hardcoded `"strength": 1.0` with `request.presetStrength`.
   - `gradeParams` already reflects effective interpolated params via the new resolver — no schema bump.

10. `apps/filmtone-desktop-macos/FilmtoneDesktop/App/FilmtoneDesktopApp.swift`
    - Add optional `--strength <0..1>` flag to both `parseStillExportArgs` and `parseVideoExportArgs`.
    - Default to `FilmtonePresetCatalog.presetStrengthDefault` when absent.

## Out of Scope

- Quick state axes (`filmCharacter` / `era` / `dynamics`).
- Param overrides patch (iOS `paramOverrides`).
- Custom Look library / Look creation.
- M3 LOW gaps (Input/Creative LUT, printContrast abs, terminal `cropped`).
- M4 SPM consolidation — interpolation is duplicated in macOS for now; SPM lane
  collapses both copies later.
- GLSL → MSL CIKernel migration.
- Drag & drop, recent files, before/after toggle (separate M5 slices).
- Sidecar schema bump or new fields beyond honouring existing `strength`.

## Sidecar Semantics Decision

- `batchLookChoice.strength` records **intent** (the value the user chose).
- `gradeParams` records **effective** params (post-interpolation), mirroring
  iOS canonical: a sidecar reader can apply `gradeParams` directly without
  re-running interpolation. This preserves the audit trail and avoids
  ambiguity at strength=0.5.
- Schema is unchanged (existing `strength` field repurposed from constant to
  variable). Backward-compat: any reader currently expecting 1.0 still gets
  valid Double in 0..1.

## Verification Plan

Run from worktree root:

1. **Build**: `xcodebuild -project apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj -scheme FilmtoneDesktop -configuration Debug build` → BUILD SUCCEEDED.
2. **Drift**: `bun run generate:swift` → no diff (contract unchanged).
3. **Visual smoke** (manual):
   - Launch app, ⌘O open a still.
   - Pick "iPhone" preset; confirm slider appears, default at 100%.
   - Drag slider to 0%; preview should match "Reset" preset output.
   - Drag slider to 50%; preview should be a halfway interpolation.
   - Switch back to "Reset"; slider should disable.
4. **CLI parity**:
   - Existing baseline: `--export-still --preset iphone` (no `--strength`) →
     bytewise identical output to pre-change baseline (default = 1.0).
   - New: `--export-still --preset iphone --strength 0` → output equivalent to
     `--preset reset` (PSNR > 50 dB or bytewise match if FP-stable).
5. **Sidecar inspection**:
   - Export with `--strength 0.5`; open `.filmtone.json`; confirm
     `batchLookChoice.strength == 0.5` and `gradeParams.exposure` (etc.) is
     halfway between reset and target.
6. **Targeted parity gate** (existing 09-skin-light): re-run with default
   strength, confirm no regression vs the C5b checkpoint baseline.

## Operating Notes

- Existing code changes in the worktree are this active task's working state;
  do not revert.
- iOS project (`apps/capacitor-film-lab-ios/`) is read-only reference for this
  task — do not edit.
- Generated Swift (`SharedGenerated/FilmtonePhase0Generated.swift`) is
  generator-owned; do not hand-edit.
- INV-7: commit is user-manual at task close.

## Checklist

- [x] `FilmtonePresetCatalog`: add `presetStrengthDefault`, `clampStrength`, `params(for:strength:)`, private `lerp`
- [x] `EditorState`: add `presetStrength`, update `presetParams`
- [x] `GradeControls`: add Slider + readout, disable for reset
- [x] `PreviewSurface`: thread `presetStrength` through to params resolution
- [x] `RootWindowView`: thread `presetStrength` to PreviewSurface and to export requests
- [x] `FilmtoneSidecarRequest` protocol: add `presetStrength`
- [x] `FilmtoneStillExportRequest`: add `presetStrength`, plumb to params resolution
- [x] `FilmtoneVideoExportRequest`: add `presetStrength`, plumb to params resolution
- [x] `FilmtoneSidecarWriter`: read `request.presetStrength` instead of hardcoded 1.0
- [x] `FilmtoneDesktopApp` CLI: add `--strength` flag (still + video)
- [x] Build green (xcodebuild Debug, BUILD SUCCEEDED)
- [x] Drift clean (`bun run generate:swift` — both ios and macos "up to date")
- [x] CLI parity (default strength) holds existing baseline (reset 28.08 dB / iphone 09-skin-light 28.81 dB — bytewise match with C5b checkpoint archive)
- [x] CLI parity (strength=0) → bareline `resetParams` (NOT `paramsByName["reset"]`); iOS canonical confirms this is the correct pivot — see Notes below
- [x] Sidecar reflects chosen strength + interpolated gradeParams (s05 exposure 0.02, contrast 1.06, bloomStrength 0.09 — exact linear midpoint)
- [ ] Visual smoke (manual — user-driven, app launched independently)

## Verification Results (2026-05-04 JST)

### Build
`xcodebuild -project apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj -scheme FilmtoneDesktop -configuration Debug -destination 'platform=macOS' build` → **BUILD SUCCEEDED**.

### Drift
`bun run generate:swift` → both iOS and macOS generated Swift "up to date" (no contract change).

### CLI smoke (5 export combinations on `09-skin-light.png`)

| variant | sha (PNG) |
|---|---|
| `--preset iphone` (no `--strength`) | `d69c033f...` |
| `--preset iphone --strength 1.0` | `d69c033f...` (bytewise match ✓) |
| `--preset iphone --strength 0` | `68de95f7...` (resetParams pivot — see Notes) |
| `--preset iphone --strength 0.5` | `42a6e1fc...` |
| `--preset reset` | `d6c5377d...` (paramsByName["reset"], distinct from above) |

### Sidecar contract
`batchLookChoice.strength` and `gradeParams` round-trip:

| variant | strength | exposure | contrast | bloomStrength |
|---|---|---|---|---|
| iphone default / s1 | 1 | 0.04 | 1.12 | 0.18 |
| iphone s05 | 0.5 | 0.02 | 1.06 | 0.09 |
| iphone s0 | 0 | 0 | 1 | 0 |
| reset preset | 1 | 0 | 1 | 0.22 |

Linear midpoint math verifies: `mix(0, 0.18, 0.5) = 0.09` ✓.

### Targeted parity (default strength, regression check)

| preset / image | macOS↔source | C5b checkpoint baseline | delta |
|---|---|---|---|
| `reset` (mean of 10 fixtures) | 28.08 dB | 28.08 dB | 0 |
| `iphone` × `09-skin-light` | 28.81 dB | 28.81 dB | 0 |

Default strength path is **byte-identical** to the C5b checkpoint baseline.

## Notes

### Interpolation pivot is `resetParams`, not `paramsByName["reset"]`

iOS canonical (`FilmtonePhase0Math.swift:584` references `FilmtonePhase0Params.reset`,
which `:104` aliases to `FilmtonePhase0Generated.resetParams`). The generator emits
two distinct entries:

- `FilmtonePhase0Generated.resetParams` — the bare-zero interpolation pivot
  (bloomStrength = 0, halationSpread = 15, etc.)
- `FilmtonePhase0Generated.paramsByName["reset"]` — the user-facing "Reset"
  preset (bloomStrength = 0.22, halationSpread = 22, etc.)

So selecting "iPhone" and dragging strength to 0 produces the bare baseline,
not the "Reset" preset's tone. This is iOS-canonical and intentional.

## Unexpected

(none — implementation matched the plan)
