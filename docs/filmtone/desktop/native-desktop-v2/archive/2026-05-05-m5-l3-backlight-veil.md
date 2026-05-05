# M5-L3 Backlight Veil

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-l2-advanced-chips`
Branch: `feature/native-desktop-m5-l2-advanced-chips`

## Milestone

M5 / Native optics parity thin fix.

## Goal

Add a visible Backlight Veil optical filter/effect to Native Desktop using the
shared product profile values where the current Native render contract already
supports them, and preserve the named profile identity through preview, export,
and sidecar metadata.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarTypes.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneStillExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift`
- `apps/filmtone-desktop-macos/Verify/main.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Read-Only References

- `packages/film-lab-core/src/optical-filter-profiles.ts`
- `packages/film-lab-core/src/optical-filter-profiles.test.ts`
- `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-05-m5-h2-adjust-library-parity.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-05-m5-l2-advanced-recipe-chip-discoverability.md`

## Checklist

- [x] Port Backlight Veil 1/8, 1/4, and 1/2 supported profile values into a Native catalog.
- [x] Add a discoverable Desktop control that applies/clears the named profile.
- [x] Feed the profile-derived param patch through preview, still export, video export, and sidecar.
- [x] Preserve manual advanced slider overrides and existing Quick/Preset/Look behavior.
- [x] Add focused Verify coverage for catalog values, sidecar identity, and profile param resolution.
- [x] Run required verification.
- [x] Relaunch the Debug app for visual smoke.
- [x] Record completion and archive this active task.

## Verification

- `bash apps/filmtone-desktop-macos/Verify/run.sh` => 97/97 passed.
- `bun run verify:macos` => xcodebuild Debug succeeded.
- `git diff --check` => clean.
- Relaunch Debug app:
  `pkill -x Filmtone 2>/dev/null || true`
  `open -n /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-l2-advanced-chips/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`
  Confirmed `Filmtone` process is running.

## Done Conditions

- Native Desktop exposes Backlight Veil as a named optical filter with None /
  1/8 / 1/4 / 1/2 choices.
- Selecting a Backlight Veil density visibly affects preview and is included in
  still/video export render params.
- Sidecar metadata records the selected Backlight Veil profile identity without
  a schema version bump.
- Verification is green.

## Stop Conditions

- Done met.
- Unexpected blocker.
- 3 consecutive verification failures.

## Out Of Scope

- M5-L1 Source Auto changes.
- M5-L2 recipe chip layout beyond preserving the completed surface.
- Adding new hidden optical-scatter/depth params to `FilmLabSwiftCore`.
- Full optical filter family adoption for Black Mist / Cine Bloom / Warm Mist /
  Pearl Glow / Clean Soft.
- Portfolio, release artifact, notarization, staging, commit, push.

## Unexpected Blockers

- None yet.

## Remaining Product Risks

- Native Desktop now renders the supported Backlight Veil bloom / halation /
  diffusion / lens values, but the shared profile's hidden depth and optical
  scatter lanes are still not represented in `FilmLabSwiftCore`.
- Saved Look entries do not yet preserve the named `opticalFilterProfile`
  identity; exports and sidecars do.
- Real footage still needs visual tuning across bright window / sun-backlight
  cases to decide whether the Native subset needs a follow-up strength curve.
