# M5-C.3a Quick Adjust Parity And Saved-Look Round-Trip

Date opened: 2026-05-04 JST

## Milestone

M5 Native Editing UI. M5-C.3 from the
`archive/2026-05-04-m5-c-ios-feature-parity-audit.md` parity gap list:
"Adjustment parity: the native app needs quick and advanced parameter
editing, not just Look strength." Splits into M5-C.3a (this slice —
Quick 3 axes + paramOverrides round-trip wiring) and M5-C.3b (advanced
per-parameter override editing UX).

## Goal

Land the **iOS Quick Adjust 3-axis surface** (filmCharacter / era /
dynamics) so the same axes that move iOS preview / export also move the
native macOS preview / export, and **complete the saved-Look round-trip**
so a Look saved with Quick offsets restores those offsets verbatim on
recall. paramOverrides storage + apply path lights up here even though
the per-parameter editing UI lands in M5-C.3b — that way Quick offsets
made in this slice survive Save → Load loops the moment they exist.

## Why this slice (本質)

- iOS users have 3 named editing axes that ripple into ~8 underlying
  params via `FilmtonePhase0Generated.quickWeights`. macOS today renders
  with `quickState` permanently `.zero` regardless of what was saved
  into a Look, which means **a saved iOS Look opened on macOS produces
  a different image than on iOS**. That is a correctness gap, not a
  cosmetic one.
- M5-C.2a wrote `paramOverrides` and `quickState` into the on-disk
  schema but the runtime never reads them back: `applySavedLook` ignores
  both, and `currentLookSavePayload` always serializes
  `(.zero, .empty)`. The library is a write-only loop for everything
  beyond `(presetName, strength, lookSlug)`. Closing this loop is
  prerequisite for the Saved Look feature to mean anything.
- The render pipeline is already param-driven — every consumer
  (PreviewSurface, StillExporter, VideoExporter, SidecarWriter) reads
  `FilmtonePresetCatalog.resolved(...)`. Folding quickState +
  paramOverrides into that single resolve site makes the whole pipeline
  honor them with no per-consumer changes.

## Scope

In-scope:

- `FilmtoneQuickState` extension (in `Domain/Phase0Types.swift` to keep
  Sendable conformance same-file): `clamped()`, `value(forAxis:)`, and
  `static func clampAxis(_:)` — verbatim port of iOS canonical
  `FilmtonePhase0Math.swift:41-65`.
- `FilmtonePresetCatalog.applyQuickState(to:quickState:)` static func —
  walks `FilmtonePhase0Generated.quickAxisIds` × `quickWeights[axis]`
  and adds `axisValue * weight` to each affected key, clamped per-key
  via the existing `paramOverrides.applyingPatch`-equivalent setter.
  Verbatim port of iOS canonical `FilmtonePhase0Math.applyQuickState`.
- `FilmtonePresetCatalog.resolved(...)` extended signature:
  `(presetName, strength, lookSlug, quickState, paramOverrides)`.
  Resolution order locked to iOS canonical: `interpolatePresetParams →
  applyingPatch(paramOverrides) → applyQuickState`. Existing 3-arg
  callers updated to thread `state.quickState` /
  `state.paramOverrides` through.
- `EditorState` adds `var quickState: FilmtoneQuickState = .zero` and
  `var paramOverrides: FilmtonePhase0ParamsPatch = .empty` storage,
  with helper `resetQuickState()` for the Reset Quick button. Existing
  `presetParams` rewires to the new 5-arg `resolved(...)`.
- `EditorState.applySavedLook(_:)` writes `entry.quickState` and
  `entry.paramOverrides` into live state (was previously dropped on
  the floor).
- `EditorState.currentLookSavePayload()` reads live `quickState` and
  `paramOverrides` (was previously hard-coded to `(.zero, .empty)`).
- `EditorState.clearSavedLookSelection()` also resets `quickState` and
  `paramOverrides` to defaults — picking "None" returns to a clean
  bareline so the next Save isn't contaminated by a previous Look's
  offsets.
- New `UI/QuickAdjustControls.swift` — Liquid Glass panel with 3
  signed sliders (range -1…+1, step 0.01) + "Reset Quick" button.
  Signed-percent label per axis (`+24%` / `-12%` / `0%` matches iOS
  `formatSignedPercentLabel`). Same Pass 4 dark-tint `.clear` posture
  as the rest of the right rail.
- `RootWindowView` inserts `QuickAdjustControls` panel between
  `LookLibraryControls` and `GradeControls` (Quick sits below Look
  selection, above Strength — mirrors iOS visual order).
- `FilmtoneSidecarWriter` reads live `quickState` from EditorState
  instead of hard-coded `[0,0,0]`. (Already has the field — just
  threading the value through.)

Out-of-scope (deferred):

- M5-C.3b advanced per-parameter override editing UX (~30 sliders
  organized by category). Storage + apply path lights up here so
  M5-C.3b is purely additive UI.
- M5-C.3c Recipe chips, reset posture beyond "Reset Quick", help
  sheets.
- M5-C.2b favorite / rename / delete UX (lower 本質 priority — closes
  out the M5-C.2 series after M5-C.3 lands).
- M5-C.4 Export panel parity (separate slice).
- Sidecar additive `paramOverrides` / `savedLookId` /
  `savedLookName` provenance — `quickState` moves to live values in
  this slice, but the broader sidecar shape is left to the M5-C.4
  Export panel slice that owns sidecar review end-to-end.
- Custom undo / redo. macOS responder-chain undo will follow once the
  per-parameter editing surface (M5-C.3b) introduces a meaningful
  edit granularity. Slider drags here remain coalesce-on-end like the
  Strength slider already does.

## Approach

1. Add `FilmtoneQuickState` helpers (`clamped`, `value(forAxis:)`,
   `clampAxis`) directly to `Domain/Phase0Types.swift` so Sendable
   stays same-file. Static `axisIds` reference comes from
   `FilmtonePhase0Generated.quickAxisIds` so the order tracks the
   generator output without a second source of truth.
2. Lift iOS `applyQuickState(to:quickState:)` verbatim into
   `FilmtonePresetCatalog` (only place that already owns the 35-key
   `FilmtonePhase0Params` shape). Per-key clamp mirrors iOS by reusing
   the existing `applyingPatch` semantics — i.e. the additive offset
   is applied through `setValue(for:)` and the resulting params object
   stays inside the existing resolve chain.
3. Extend `resolved(...)` rather than introducing a parallel resolve
   path: `lerp → applyingPatch(paramOverrides) → applyQuickState`.
   That ordering matches iOS canonical (`interpolatePresetParams` →
   `applyingPatch` happens at preset save time / catalog material →
   `applyQuickState` is the last layer before the pipeline). Param
   clamps stay on the per-key setters.
4. EditorState wiring: add the two stored properties + helper, point
   `presetParams` at the 5-arg resolve, route `applySavedLook` to
   write the offsets, route `currentLookSavePayload` to read them.
   `selectedSavedLookId == nil` flow + `clearSavedLookSelection` both
   reset Quick so the user always sees "None" as a clean bareline.
5. UI: `QuickAdjustControls` follows the same shape as
   `LookLibraryControls` / `GradeControls` — VStack inside the
   existing `GlassEffectContainer` right rail. Each axis row is
   `(Label – signed percent – Slider)` with the same Strength-row
   typography. "Reset Quick" sits at the panel footer, disabled when
   `quickState == .zero`.
6. Sidecar `quickState` block already exists at the right shape;
   just thread `request.quickState` through and serialize live values.
7. Verify: build clean, then user verifies visually that
   (a) Quick sliders move preview, (b) save a Look with Quick
   offsets, switch to None, switch back — Quick offsets restore on
   the active Look, (c) the resulting export sidecar carries the
   live `quickState` block.

## Done conditions

- `xcodebuild -scheme FilmtoneDesktop -configuration Debug
  -destination 'platform=macOS' build` passes clean (Swift 6 strict
  concurrency).
- Open a still / video, drag `filmCharacter` / `era` / `dynamics`
  sliders — preview updates with the same per-key offsets iOS applies
  (saturation / temperature / vignette for filmCharacter; fade /
  saturation / contrast for era; exposure / contrast / bloom for
  dynamics).
- Pick Stone, drag Strength to ~0.6, set `era = +0.4`, click "Save
  Current Look…", name it "Stone Era". Switch Picker to None — Quick
  resets to zero and Look clears. Switch Picker back to "Stone Era" —
  Strength returns to 0.6 and `era` returns to `+0.4`.
- "Reset Quick" button restores `quickState = .zero` without touching
  Strength or Look selection. Disabled when already zero.
- Export PNG/JPEG/MP4 with non-zero Quick — open the resulting
  `.json` sidecar and verify the `quickState` block carries the live
  axis values (not the hard-coded zero block).
- Built-in Stone / Urban remain selectable with identical render
  output to pre-M5-C.3a when Quick is `.zero` (their `.bundled` cube
  + paramOverrides patch are unchanged).

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift` (FilmtoneQuickState helpers)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePresetCatalog.swift` (extend resolved + add applyQuickState)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift` (quickState + paramOverrides storage, applySavedLook wiring)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift` (insert panel)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift` (live quickState)
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj` (new file ref)
- `docs/filmtone/desktop/native-desktop-v2/active.md` (this file)
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` (1–3 line completion entry)

## Read-Only References

- iOS canonical: `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift:41-65` (FilmtoneQuickState helpers), `:596-616` (applyQuickState)
- iOS canonical: `apps/capacitor-film-lab-ios/src/features/editor/StrengthSheet.tsx` (Quick 3-axis UI shape)
- M5-C audit: `archive/2026-05-04-m5-c-ios-feature-parity-audit.md`
- M5-C.2a archived active: `archive/2026-05-04-m5-c2a-saved-look-library-foundation.md`

## Out Of Scope

- M5-C.3b (advanced per-parameter override editing UX)
- M5-C.3c (recipe chips, additional reset posture, help sheets)
- M5-C.2b (favorite / rename / delete UX)
- M5-C.4 (Export panel parity)
- Custom undo / redo
- Sidecar provenance fields beyond live quickState

## Unexpected / Blockers

- `FilmtonePhase0ParamsPatch` and `FilmtoneQuickState` had to gain
  `Hashable` conformance to satisfy `PreviewRenderKey` (`.task(id:)`
  needs Hashable). Trivial — `[String: Double]` is already Hashable —
  but worth recording so a future deserialization shape change does
  not silently break preview re-render.

## Completion (this active is ready to archive)

- `xcodebuild -scheme FilmtoneDesktop -configuration Debug
  -destination 'platform=macOS' build` passes clean (Swift 6 strict
  concurrency; only the pre-existing CI-kernel deprecation warnings
  on `FilmtoneGradeKernels.swift` — unrelated to this slice).
- `FilmtoneQuickState` (`Domain/Phase0Types.swift`) now matches iOS
  canonical: `clamped()`, `value(forAxis:)`, `static clampAxis(_:)`
  ported verbatim from `apps/capacitor-film-lab-ios/ios/App/App/
  FilmtonePhase0Math.swift:41-65`. `Hashable` added so the struct can
  ride inside `PreviewRenderKey`.
- `FilmtonePhase0ParamsPatch` widened to `Hashable` for the same
  PreviewRenderKey reason.
- `FilmtonePresetCatalog.resolved(...)` extended to a 5-arg surface
  `(presetName, strength, lookSlug, quickState, paramOverrides)` with
  default `.zero` / `.empty` for the trailing pair so existing 3-arg
  call sites continue to compile. Resolution order locked to iOS
  canonical: `interpolatePresetParams → applyingPatch(paramOverrides)
  → applyQuickState`. New `applyQuickState(to:quickState:)` static
  func mirrors `FilmtonePhase0Math.applyQuickState` — walks
  `FilmtonePhase0Generated.quickAxisIds × quickWeights[axis]` and
  adds `axisValue * weight` to each affected param key.
- `EditorState` adds `quickState: FilmtoneQuickState = .zero` and
  `paramOverrides: FilmtonePhase0ParamsPatch = .empty` storage,
  `quickStateIsActive` / `resetQuickState()` helpers, and threads
  both into `presetParams`. `applySavedLook` now restores
  `entry.quickState.clamped()` + `entry.paramOverrides` (was
  previously dropped). `currentLookSavePayload` reads live values
  (was hard-coded to `(.zero, .empty)`). `clearSavedLookSelection`
  also resets quickState + paramOverrides so the next Save isn't
  contaminated by a previous Look's offsets.
- Render pipeline threading: `PreviewSurface`, `FilmtoneStillExporter`,
  `FilmtoneVideoExporter`, and `FilmtoneSidecarWriter` all accept and
  thread `quickState` + `paramOverrides`. `FilmtoneSidecarRequest`
  protocol gains both as default-`.zero` / default-`.empty` requirements
  so any future request type stays backward-compatible. The previously
  hard-coded `quickState: [0,0,0]` block in the sidecar payload now
  serializes the live `request.quickState.clamped()` values.
- New `UI/QuickAdjustControls.swift` — Liquid Glass panel with three
  signed sliders (range -1…+1, step 0.01 from
  `FilmtonePhase0Generated.quickAxisStep`) labeled Film / Era /
  Dynamics + signed-percent readout (`+24%` / `-12%` / `0%`) +
  "Reset Quick" footer button (disabled when quickState is already
  zero). Same Pass 4 dark-tint `.clear` posture as
  `LookLibraryControls` / `GradeControls`.
- `RootWindowView` inserts `QuickAdjustControls` between
  `LookLibraryControls` and `GradeControls` so the right rail reads
  top-down: Source Profile → Look → Quick → Strength. Both export
  request constructors (`presentStillExportPanel`,
  `presentVideoExportPanel`) thread `state.quickState` /
  `state.paramOverrides` through.
- Saved-Look round-trip closed end-to-end: a Look saved with
  `era = +0.4` / `paramOverrides = {…}` recalls those offsets
  verbatim on Picker re-selection, and the export sidecar carries
  the live quickState block instead of `[0,0,0]`.

User to verify visually:

1. Open a still / video, drag `Film` / `Era` / `Dynamics` —
   preview updates with the iOS-canonical per-key offsets
   (saturation / temperature / vignette for filmCharacter; fade /
   saturation / contrast for era; exposure / contrast / bloom for
   dynamics).
2. Pick Stone, drag Strength to ~0.6, set `Era = +40%`, click "Save
   Current Look…", name it "Stone Era". Switch Picker to None →
   Quick zeroes, Look clears. Switch Picker back to "Stone Era" →
   Strength returns to 0.6 and Era returns to +40%.
3. "Reset Quick" restores zero across all 3 axes without touching
   Strength or Look. Disabled when already zero.
4. Export PNG/JPEG/MP4 with non-zero Quick — open the resulting
   `.json` sidecar and verify the `quickState` block carries the
   live axis values (not `[0,0,0]`).
5. Built-in Stone / Urban remain selectable with identical render
   output to pre-M5-C.3a when Quick is `.zero`.

This active.md moves to archive when the next slice (M5-C.3b
advanced per-parameter override editing UX, M5-C.2b favorite /
rename / delete UX, or M5-C.4 Export panel parity) opens.
