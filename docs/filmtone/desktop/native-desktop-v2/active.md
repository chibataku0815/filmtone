# M5-C.3b Advanced Per-Parameter Override Editing UX

Date opened: 2026-05-04 JST (proposal — awaiting user approval)

## Milestone

M5 Native Editing UI. M5-C.3b closes the M5-C.3 series opened by the
parity gap "Adjustment parity: the native app needs quick and advanced
parameter editing, not just Look strength" (see
`archive/2026-05-04-m5-c-ios-feature-parity-audit.md`). M5-C.3a lit up
the `paramOverrides` storage / apply / Codable / sidecar pipeline; this
slice surfaces the editor UI on top of it.

## Goal

Land a **per-parameter override editor** so the user can dial any of
the 35 `FilmtonePhase0Params` keys above the resolved (preset + Look +
Quick) baseline, with the same correctness / round-trip guarantees the
M5-C.3a Quick path already provides:

- live preview reflects each edit immediately
- per-key overrides persist into the saved Look (already wired via
  `EditorState.paramOverrides` ⇄ `SavedLookEntry.paramOverrides`)
- export sidecar's `gradeParams` block reflects the override-applied
  resolved params (already wired via `FilmtoneSidecarWriter`)

## Why this slice (本質)

- M5-C.3a closed the storage / apply / serialization gap but the user
  has no way to *write* paramOverrides — the only path that produces
  non-empty overrides today is a future iOS-saved Look opened on
  Desktop. Without UI, the field is dead weight.
- iOS canonical has a per-parameter editor that lets users drift any
  of the 35 keys above the preset baseline. macOS lacking this means
  any creative session that needs (e.g.) "Stone but with halation
  spread −15%" forces the user to bake that into a custom preset
  generator output, breaking the workflow loop.
- This slice is purely additive UI on top of M5-C.3a's lit storage —
  no math changes, no protocol changes, no new resolve sites.

## Scope

### In

1. **`UI/ParamRow.swift`** — single-row component
   - label + signed value readout + Slider + per-row Reset button
   - Reset removes the key from `state.paramOverrides.values`, falling
     back to the resolved (preset + Look + Quick) baseline
   - bind via `state.paramOverrides.values[key]` (computed slider value
     = `overrides[key] ?? resolvedBaseline.value(for: key)`)
   - Slider range derived from per-key bounds. Generator-bounded keys
     (`rgbShift`, `grainIntensity`) use the generated max constants;
     unbounded keys use sensible UX caps (e.g. exposure ±2 stops,
     saturation 0…2, temperature −0.5…+0.5 — match iOS conventions
     by reading `apps/capacitor-film-lab-ios/ios/App/App/...` if a
     canonical bounds map exists, otherwise inline the same caps the
     iOS UI uses today)

2. **`UI/AdvancedParamControls.swift`** — DisclosureGroup container
   - DisclosureGroups by category, collapsed by default:
     - **Tone**: exposure, contrast, saturation, temperature, tint,
       fade, shadowTone, highlightTone, shadowHue, highlightHue,
       printContrast
     - **Color Cast**: cyan, magenta, yellow
     - **Optics**: rgbShift, lensSoftness, diffusion
     - **Bloom**: bloomThreshold, bloomStrength, bloomRadius,
       bloomSoftKnee
     - **Halation**: halationIntensity, halationSpread, halationHue,
       halationThreshold, halationRadius, halationSoftKnee
     - **Grain**: grainIntensity, grainSize, grainRadialMix
     - **Compression**: compressionAmount, compressionRange
     - **Motion**: shutterAngle, trailIntensity
     - **Vignette**: vignette
   - Footer: "Reset All Overrides" button (clears
     `state.paramOverrides.values` entirely; disabled when empty)
   - Same Pass 4 dark-tint `.clear` Liquid Glass posture as
     `QuickAdjustControls` / `GradeControls`

3. **`State/EditorState.swift`** — minor extension
   - `paramOverridesIsActive: Bool` (mirrors `quickStateIsActive`)
   - `setParamOverride(key:value:)` — writes through to
     `paramOverrides.values[key] = value`
   - `clearParamOverride(key:)` — removes the key from
     `paramOverrides.values`
   - `resetAllParamOverrides()` — sets `paramOverrides = .empty`
   - `resolvedBaselineForOverrides() -> FilmtonePhase0Params` — exposes
     the (preset + Look + Quick) baseline (= `resolved` with
     `paramOverrides = .empty`) so `ParamRow` knows what value to
     display when a key has no override yet

4. **`UI/RootWindowView.swift`** — insert `AdvancedParamControls` below
   `QuickAdjustControls` so right rail reads top-down: Source Profile
   → Look → Quick → **Advanced** → Strength → Grade

5. **`apps/filmtone-desktop-macos/Verify/main.swift`** — extend harness
   - per-key override write/read round-trip via `EditorState` API
   - "set then clear" empties the dict (no orphan zero entries)
   - resolvedBaseline matches `resolved(..., paramOverrides: .empty)`
     for any non-empty override state

### Out (deferred to M5-C.3c if desired)

- "Show only modified" filter toggle (UX polish)
- Per-group Reset (only top-level "Reset All" lands here)
- Drag-numeric scrub (slider only)
- Numeric text-field input (slider only)
- Hidden defaults editor (`FilmtonePhase0HiddenDefaults` —
  intentionally hidden per name)
- Curve-editor surfaces (LUT-like nodes, beyond per-key sliders)

## Approach

iOS canonical has a per-key sliders surface with categorization. The
storage shape (`FilmtonePhase0ParamsPatch.values: [String: Double]`)
matches iOS verbatim, so this slice is mostly UI mechanics — no math
to port. Resolve order is already locked
(`interpolate → applyingPatch(paramOverrides) → applyQuickState`).

Per-key bound caps: where the generator emits a max constant
(`rgbShiftMax`, `grainIntensityMax`), use it. Otherwise pick
sensible UX caps that mirror what iOS exposes today — verify by
reading `apps/capacitor-film-lab-ios/ios/App/App/Filmtone*.swift`
during implementation. Do not invent caps.

ParamRow value resolution:

```swift
let displayValue = state.paramOverrides.values[key]
    ?? state.resolvedBaselineForOverrides().value(for: key)
```

Slider edit calls `state.setParamOverride(key:value:)`. Per-row Reset
calls `state.clearParamOverride(key:)`. Both trigger `@Observable`
re-render → preview re-renders via `PreviewRenderKey`'s existing
`paramOverrides` Hashable participation.

## Done conditions

- `xcodebuild -scheme FilmtoneDesktop -configuration Debug
  -destination 'platform=macOS' build` passes clean (Swift 6 strict
  concurrency)
- All 35 `FilmtonePhase0Params` keys appear in some category — no
  silent drops. Verify count == `FilmtonePhase0Params.keyPaths.count`
  at compile time (constant array enumeration).
- Per-row override + per-row reset works end-to-end (write → preview
  reacts → reset → preview returns to baseline)
- "Reset All Overrides" empties `paramOverrides.values` and the
  preview returns to (preset + Look + Quick) baseline
- Save Look with overrides → switch Picker away → return → overrides
  restore (M5-C.3a round-trip path; just verify it works through the
  new UI)
- `Verify/run.sh` extended with per-key override harness tests, all
  PASS

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ParamRow.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedParamControls.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift` (extend)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift` (extend)
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj` (register new files)
- `apps/filmtone-desktop-macos/Verify/main.swift` (extend harness)

## Read-Only References

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePhase0ParamsPatch.swift` (storage shape)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePresetCatalog.swift` (resolve order)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift` (per-key max constants)
- `apps/capacitor-film-lab-ios/ios/App/App/...` (iOS canonical UI bound caps reference)
- M5-C.3a archive: `archive/2026-05-04-m5-c3a-quick-adjust-parity-and-saved-look-round-trip.md`

## Out Of Scope

- Math changes (none — storage / apply path is already correct)
- Protocol changes (FilmtoneSidecarRequest already carries paramOverrides)
- New resolve sites (one resolve site, all consumers benefit — preserved)
- iOS canonical bound-cap re-derivation if iOS doesn't have an
  authoritative map (use sensible UX caps; do not block on iOS
  authoritative bounds — log as Unexpected for a future audit)

## Estimated size

Multi-hour slice (~M5-C.3a comparable: 6 files, ~600 LOC including
~35 ParamRow registrations and harness extensions). Single commit at
landing. No interim partial-state commits because the editor must be
end-to-end functional before it's user-facing.

## Approval gate

Per `strategy.md` Operating Rules — implementation paused until user
approves this active.md or amends scope (e.g. defer to M5-C.4 / M5-C.2b
first).
