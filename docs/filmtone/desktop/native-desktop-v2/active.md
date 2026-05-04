# M5-C.1 Native Source Profile And Source Gate Parity

Date opened: 2026-05-04 JST

## Milestone

M5 Native Editing UI (with M3 color/optics implications). Recommended next
slice from the M5-C audit (`archive/2026-05-04-m5-c-ios-feature-parity-audit
.md`).

## Goal

Bring iOS-canonical source-profile selection (Auto + built-in profiles such
as Apple Log, Apple Log 2, DJI D-Log / D-Log M, Canon C-Log / Cinema Gamut,
Canon Log 3, Panasonic V-Log, Sony S-Log3, Rec.709) to Native Desktop v2 so
that the same footage that grades correctly on iOS grades correctly on
macOS, and so that unsupported / policy-relevant sources surface a
user-visible gate before export rather than failing late.

## Why this slice (本質)

This is the highest correctness gap in the M5-C audit:

- iOS already normalizes log / wide-gamut footage through an explicit source
  profile catalog. Native Desktop currently has metadata classification but
  **no user-facing profile picker and no input transform**, so the same
  source can export with different color truth between platforms.
- The Look layer (M5-A.2 Stone / Urban) and Strength (M5-A.1) are correct
  *given* a normalized source. Without source-side normalization, all Look
  parity work compounds the source-side mismatch.
- A Mac release candidate cannot ship if footage that the user knows works
  on iOS exports differently (or unusably) on macOS.

## Scope

In-scope:

- Source profile catalog Swift module mirroring iOS canonical names (Auto +
  built-in profiles). Catalog is the SSOT for profile slugs and labels.
- `EditorState` extension for `sourceProfileSlug` (Auto by default).
- A user-visible source profile control surface — minimum is a Picker in
  the right rail under or alongside `GradeControls`; richer Source sheet /
  inspector deferred unless audit P0 surfacing demands it within this slice.
- Wiring through preview / still export / video export so the selected
  profile actually affects output. Auto must preserve current Rec.709 /
  iPhone behavior bytewise.
- Source-cap / HDR policy gate: if a probed source falls outside what the
  Desktop pipeline can faithfully render, show a non-blocking notice in the
  source surface and disable Export with a clear reason (parity with iOS
  source-cap behavior).
- Sidecar additive `sourceProfile` field if (and only if) the existing
  sidecar contract has a safe additive slot. No schema bump.
- CLI `--source-profile` (or equivalent) parity if the CLI is the surface
  the user / tests rely on; otherwise out-of-scope for this slice and noted
  as Follow-up.

Out-of-scope (this slice):

- Custom Input LUT import / library (P1, follow-up slice).
- Saved Looks / Look library persistence (separate P0 slice).
- Adjustment parameter editing beyond Strength (separate P0 slice).
- Export panel / inspector parity (separate P0 slice).
- iOS-style Source Sheet UI literally; we want a *macOS-native* surface,
  not a phone sheet.

## Approach

1. Read the iOS source profile catalog and source state to get the
   canonical slug list and any per-profile transform parameters that exist
   today. Do **not** copy iOS UI code; copy the *contract*.
2. Add `FilmtoneSourceProfileCatalog` (or equivalent) under
   `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/` mirroring slug names
   exactly (no rename / abbreviation drift).
3. Wire `EditorState.sourceProfileSlug` (default = Auto) and route it
   through `PreviewSurface`, `FilmtoneStillExporter`, and
   `FilmtoneVideoExporter` so that preview and export both apply the same
   transform.
4. Add a Picker to the right rail (under `GradeControls` or in a sibling
   panel; reuse the Pass 4 `.clear.tint(.black.opacity(0.30))` glass +
   `.colorScheme(.dark)` Picker pattern for visual consistency).
5. Add the source-cap gate: when `FilmtoneSourceProber` (or the equivalent)
   reports a metadata combination that cannot be honored, the source
   surface shows a notice and Export becomes disabled with that reason.
6. Sidecar additive write only if a safe field exists; otherwise log as
   Follow-up and keep the sidecar untouched.
7. Verify Auto path bytewise against the M5-A.2 Stone CLI hash record (the
   existing canonical) — no regression on Rec.709/iPhone sources.
8. Build, run, manual visual smoke on at least one log source if available
   (Apple Log preferred).

## Done conditions

- `bun run verify:macos` (or the local equivalent xcodebuild + smoke
  script) passes.
- Auto path is the default and Stone hash @ strength 1.0 on the canonical
  iPhone sample is byte-identical to the M5-A.2 archive record.
- At least one log profile (preferably Apple Log) demonstrably changes
  preview and export output vs. Auto on a log source, and matches iOS
  output on the same source within the established parity tolerance.
- Source profile is recorded in sidecar additively if and only if the
  contract supports it without bumping schema.
- Source-cap gate disables Export with a visible reason when the prober
  flags an unsupported combination.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSourceProfileCatalog.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift` (Picker wiring)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/GradeControls.swift` or a new sibling control
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneSourceProber.swift` (gate signal)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneStillExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift` (only if safe additive)
- `docs/filmtone/desktop/native-desktop-v2/active.md` (this file)

## Read-Only References

- iOS canonical: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`
- iOS canonical: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileSheet.swift`
- iOS canonical: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift` (source state model)
- M5-C audit: `archive/2026-05-04-m5-c-ios-feature-parity-audit.md`
- Pass 4 readability pattern: `archive/2026-05-04-m5-b-liquid-glass-fcycle-and-pass3.md` (and current
  `RootWindowView.swift` / `GradeControls.swift`)

## Out Of Scope

- Implementing other M5-C P0 slices (Look library, Adjustments, Export
  panel) in this active.
- Changing iOS behavior.
- Changing Electron Desktop behavior.

## Unexpected / Blockers

- None yet.
