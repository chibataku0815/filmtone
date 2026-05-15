# Active — Twilight bundled built-in Look (iOS + macOS)

Inserted 2026-05-12 as a short interrupt against M9 v1.7 release prep.

## Goal

Add a 4th bundled built-in Look — `Twilight` — to Filmtone's Look library
on Native macOS Desktop AND iOS simultaneously. Twilight is a preset-only
Look (no Creative LUT cube) sourced from
`packages/film-lab-core/src/presets.ts:632-689` `vision3500t` (tungsten 500T
blue-hour recipe). UI surface stays under the existing Look library
(Stone / Urban / Noir + Twilight) — `Preset` is **not** exposed as a
user-facing label per CLAUDE.md §6 term lock.

## Why a Look, not a "Preset" panel

Internal classification: Twilight's body is a Preset (curve / grade
foundation, not a Creative LUT Pack entry). But UI vocabulary is locked
to `Look` for user-facing surfaces. Solution: bundled `SavedLookEntry`
with `creativeLut: nil`, materialized into the existing Look strip /
Look library menu. `EditorState.applySavedLook` keeps `lookSlug == nil`
so the Creative LUT pipeline (`FilmtoneSidecarWriter` /
`FilmtoneCreativeLutLoader` / `lookSlug` lookup sites) never sees
Twilight.

## Cross-Stream Visibility

iOS and macOS land in one lane — no silent stream split. Twilight's
canonical UUID `FB1A0001-0000-4000-8000-000000000011` is identical
across both Swift catalogs; parity is verified with two independent
greps (slug and UUID must each match in both `apps/` subtrees, since
they sit on different lines in the Swift catalogs):

```
rg "filmtone-built-in-twilight" apps/capacitor-film-lab-ios apps/filmtone-desktop-macos
rg "FB1A0001-0000-4000-8000-000000000011" apps/capacitor-film-lab-ios apps/filmtone-desktop-macos
```

## Native-supported subset (vs `vision3500t`)

`vision3500t` in `packages/film-lab-core/src/presets.ts:632-689` carries
two keys that are **not** declared in
`FilmtonePhase0Generated.paramKeys` and are therefore intentionally
dropped from `twilightPatch` on both OSes:

- `highlights: -0.12`
- `shadows: -0.16`

The native tone is reproduced via `shadowTone` / `highlightTone` /
`compressionAmount` / `printContrast`. Extending Phase0 to carry
`highlights` / `shadows` is **out of scope** for this bundled-Look lane
(would touch the generated Phase0 contract, sidecar V1 readers, and
every preset row). Track it under a separate lane if a future preset
truly needs them.

## Edits landed

- `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneBuiltInCatalog.swift`
  — appended `BuiltInLook` (slug `filmtone-built-in-twilight`,
  `creativeLut: nil`, `packId: nil`, `presetName: "reset"`) plus
  `twilightPatch` static let and `BuiltInLookUUID.twilight`.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCreativePackCatalog.swift`
  — added parallel `BuiltInPresetLook` struct + `presetOnlyLooks` array +
  preset-only `materializeAsSavedLookEntry` overload + unified
  `builtInSlug(canonicalUUID:)` and `materializeAnyBuiltIn(canonicalUUID:)`
  helpers. Cube-bound `BuiltInLook` shape untouched.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSavedLookStore.swift`
  — routed `deleteLook` / `renameLook` / `setFavorite` / `loadLook` /
  `currentSnapshot` through the new unified helpers so Twilight is
  immutable + favorite-able + loadable.
- `apps/filmtone-desktop-macos/Verify/main.swift` — appended 5 Twilight
  assertions (catalog registration, materialize creativeLut nil,
  representative Phase0 values, unified helper resolution, sidecar
  gradeParams + no creativeLut block).

## Stop conditions

- iOS / macOS `canonicalUUID` mismatch (parity grep fails).
- Cube-bound code path (`FilmtoneCreativeLutLoader` / `FilmtoneSidecarWriter`
  `find(slug:)` sites) sees a Twilight slug.
- `Verify/main.swift` Twilight assertions fail.
- `bun run check:filmtone-context` flags doc / sync drift.
- xcodebuild fails on either OS.

## Out of scope

- New "Preset" UI label or panel.
- `ios-preset-overrides.ts` edits / `FilmtonePhase0Generated.paramsByName`
  expansion / `GeneratedLandmarkTests.swift` update.
- iOS V2 capture / Gyroflow lane.
- Web preset UI / Electron / legacy Desktop.
- M9 release-prep scope change (logged as an Interrupt only).
- portfolio submodule bump / App Store / release notes copy.
- Native preview orientation bug.

## Unexpected / Follow-up

- 2026-05-15 JST: Owner requested hiding the visible Desktop-only Imported
  Grade / DaVinci PowerGrade import UI and the Twilight Look surface. Keep the
  underlying runtime/catalog code available for internal compatibility, but
  remove the current product entry points from Native Desktop UI.
  Verification: `bash apps/filmtone-desktop-macos/Verify/run.sh` (144/144),
  `bun run verify:desktop`, and `git diff --check` passed.

## Done

Archive this file into `archive/2026-05-12-twilight-bundled-look.md` once
both verification commands return clean:

- `bash apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run check:filmtone-context`
- Parity grep (run **both** — slug and UUID sit on different lines):
  `rg "filmtone-built-in-twilight" apps/capacitor-film-lab-ios apps/filmtone-desktop-macos`
  and
  `rg "FB1A0001-0000-4000-8000-000000000011" apps/capacitor-film-lab-ios apps/filmtone-desktop-macos`

xcodebuild and Simulator visual confirmation are the user's call before
the lane is fully closed (commit / push remains user-driven per
CLAUDE.md §9).
