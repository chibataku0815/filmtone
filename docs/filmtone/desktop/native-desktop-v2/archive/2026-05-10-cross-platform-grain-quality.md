# Active - Cross-Platform Grain Quality

Date opened: 2026-05-10 JST
Date completed: 2026-05-10 JST
Milestone: `M3 Native Color And Optics Parity` / `M4 Shared Contract Consolidation`

## Goal

Improve Filmtone grain quality on iOS and Native Desktop with the same Core
Image kernel and add UI-only grain recipe chips for `none`, `fine`, `classic`,
and `push`. Preserve deterministic preview/export behavior and avoid all
schema, sidecar, generated Swift, or release-rail changes.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheetData.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtoneDesktopStrings.swift`
- `apps/filmtone-desktop-macos/Verify/main.swift`
- `scripts/check-ios-grain-catalog.mjs`
- `scripts/verify-ios.sh`

## Checklist

- [x] Pause the v1.6 release `active.md` and record the grain-quality interrupt.
- [x] Replace iOS and Native Desktop grain kernels with matching seeded
  luma/chroma-aware CIKL.
- [x] Add iOS grain recipe chips `none/fine/classic/push` without adding saved
  grain-type identity.
- [x] Add Native Desktop grain recipe chips `none/fine/classic/push` without
  adding saved grain-type identity.
- [x] Add or update verification for recipe ids, `grainIntensityMax` clamp, and
  unchanged param-key surface.
- [x] Run `bun run verify:ios`, `bun run verify:macos`,
  `bun run check:filmtone-copy`, and `git diff --check`.

## Verification

2026-05-10 JST:

- `node scripts/check-ios-grain-catalog.mjs` passed.
- iOS and Native Desktop grain kernel source diff check passed with no diff.
- Runtime Core Image kernel parse smoke passed for both iOS and Native Desktop
  grain kernels. Swift emitted the expected deprecation warning for the existing
  CIKL API surface.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed (`124/124`).
- `bun run verify:ios` passed, including generated Swift drift check, iOS
  Xcode build, the new iOS grain catalog check, Swift contract fixtures, and
  native script tests.
- `bun run verify:macos` passed (`** BUILD SUCCEEDED **`).
- `bun run check:filmtone-copy` passed.
- `git diff --check` passed.

## Done Conditions

- iOS `OpticalKernels.grain` and Native Desktop `FilmtoneGradeKernels.grain`
  use identical kernel logic.
- Low grain size renders fine rotated noise with restrained chroma; larger grain
  sizes use seeded pixel/cell hash and clump density for coarser grain.
- iOS and Native Desktop Advanced Grain recipe chips expose ids
  `none/fine/classic/push`.
- No `Phase0Params` field, generated Swift contract, sidecar V1 field, schema
  bump, stage-order change, or release-rail mutation is introduced.
- Required verification commands passed.

## Out Of Scope

- Legacy Electron/WebGL/WebGPU implementation changes.
- Desktop v1.6 public DMG upload or update metadata publication.
- App Store/TestFlight release state changes.
- Portfolio submodule bump, staging, commit, or push.

## Completion Log

Implemented the shared native grain kernel and UI-only grain recipes on iOS and
Native Desktop without schema, sidecar, generated Swift, release rail, or stage
order changes. Real-footage visual QA scenarios remain a product-review pass
after build verification because no task-specific sample media was supplied.
