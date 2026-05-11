# Filmtone iOS Feature-Based Architecture Refactor

Date: 2026-05-11 JST

## Placement

```text
docs/filmtone/ios/feature-architecture-refactor/
├── strategy.md   ← this file
├── active.md     ← current ≤ 30-min sub-task
└── archive/      ← per-task PASS/REJECT logs
```

This lane is downstream of v2-capture-gyroflow (closed M14+M15 PASS) and
capture-practicality (S1-S5 paused awaiting owner smoke). The 1.8 release
is `PENDING_DEVELOPER_RELEASE` (ASC approved, manual public release pending)
on top of public 1.7. The refactor branch (`feature/ios-feature-architecture`)
is based on `main @ dac08c81` (1.8 build 7 dirty state remains on main and
is not carried into this branch — to be committed by owner separately).

## Product Direction

Make the iOS native SwiftUI codebase ready for Gyroflow integration and V2
capture extensions by removing structural drag from three god objects and
the flat 111-file namespace.

This is essence work, not cosmetic reorg:

- `FilmtoneExportSession.swift` 5032 lines / 99 methods bundles decode,
  grade, Metal optics, writer, and sidecar metrics. Performance work and
  metrics work cannot proceed independently while they live in one file.
- `FilmtoneEditorStore.swift` 3441 lines / 106 methods / 14 types is the
  single ObservableObject every new project state must thread through.
- `FilmtoneCaptureSession.swift` 1849 lines / 43 methods bundles device,
  format, storage policy, state machine, and writer handoff. Gyroflow and
  V2 capture extensions cannot land cleanly through this monolith.
- `ios/App/App/` flat with 111 .swift files plus one .metal forces every
  search to scan the whole namespace.

## Execution Bias

- Essence first: split god objects to enable next product moves; do not
  treat folder reorg as the goal.
- No silent fallback: parity gates fail loud; thermal, lens, codec, color
  invariants are preserved exactly.
- Outer shell minimal: no new XCTest matrices, no formal QA grid, no
  banner / i18n decoration unless owner explicitly asks for QA.
- No conservative hedge: do not defer god-object splits if they are the
  blocker. Do not introduce silent fallbacks during extraction.

## Measurable Done Conditions

This lane is done when:

1. Every Swift source file lives in one of 10 feature folders (`Root/`,
   `Capture/`, `Editor/`, `Export/`, `Look/`, `Optics/`, `Source/`,
   `Services/`, `Smoke/`, `Strings/`) + the existing `ExportActivity/`
   target folder. No flat root `.swift` files. Note: `Root/` (not `App/`)
   houses entry surfaces because the pbxproj parent group is already named
   `App` and `App/App/` nesting would be confusing.
2. `FilmtoneExportSession` is a thin orchestrator (~1000 lines) backed by
   GradeRenderPipeline / OpticsCompositor / ExportMediaWriter /
   DepthPayloadManager / ExportMetrics. Sidecar canonical diff against a
   committed fixture is byte-identical. Still-export PNG byte diff is 0
   (or sidecar parity alone if encoder non-determinism shows up).
3. `FilmtoneEditorStore` is a thin facade (~500 lines) over ProjectState /
   LibraryManager / PreviewOrchestrator / ExportCoordinator / CaptureRelay.
   View files are unchanged except where the Phase 3A inventory ruled
   minimal adjustments necessary.
4. `FilmtoneCaptureSession` is a thin facade (~600 lines) over
   CaptureDeviceManager / RecordingStateController / CapturePackageAssembler
   with `sessionQueue` ownership decided in Phase 4A.
5. `bun run verify:ios` is green at every commit.
6. Real-device (iPhone 17 Pro Max iOS 26.2, UDID
   `D3011FE4-52CA-4B7F-B181-A55D9998E192`) capture smoke after Phase 4
   completes one record → grade → export cycle.

## Milestones

- **Phase 1A** — Lane docs + 111-file mapping + external reference
  inventory + Ruby pbxproj dry-run. No filesystem changes. ~0.5 day.
- **Phase 1B** — `git mv` + pbxproj rewrite + path repair on 3 external
  scripts + `verify:ios` + `git diff --find-renames` gate. ~1 day.
- **Phase 2A** — Extract top-level private helpers from ExportSession to
  `Export/Internal/` without changing public surface. ~0.5 day.
- **Phase 2B** — Public surface split into 6 files, `FilmtoneSharedGrade
  Processor` moves to `Look/` with API unchanged. ~2 days.
- **Phase 2C** — Sidecar canonical diff + still PNG byte diff against
  committed fixture. ~0.5 day.
- **Phase 3A** — `$store.` and `store.` access inventory across views,
  compatibility table written into active.md. No code changes. ~0.5 day.
- **Phase 3B** — Sub-store extraction with bridge strategy per
  compatibility table. ~3 days.
- **Phase 3C** — Simulator view-side smoke covering all sheets, library,
  compare. ~0.5 day.
- **Phase 4A** — sessionQueue + delegate ownership decisions written into
  active.md. ~0.5 day.
- **Phase 4B** — Capture extraction + real-device smoke. ~2 days.

Total: 11-13 working days.

## Out Of Scope

- View body decomposition (`FilmtoneFullscreenLutEditor` 1262 lines /
  `FilmtoneCaptureView` 1086 lines). SwiftUI body size is structural;
  velocity impact is small relative to god-object splits.
- XCTest expansion, formal QA matrices, PSNR fixtures beyond Phase 2C.

## Interrupt / Decision Log

- 2026-05-11 JST — Lane opened on
  `feature/ios-feature-architecture` branch fast-forwarded to
  `main @ dac08c81`. 1.8 release dirty state on owner's main worktree is
  not carried into this branch (owner commits when ready; merge strategy
  is straight merge because 1.8 bump touches build settings while refactor
  touches file references — different pbxproj sections).

## Completion Log

- 2026-05-11 JST — Phase 1B source layout migration is complete in the
  feature worktree: 109 former root files moved into 10 feature folders,
  pbxproj and active script paths repaired, `bun run verify:ios` green.
- 2026-05-11 JST — Phase 2A helper extraction is complete: export models,
  render-stage metrics, and prepared LUT helpers moved into
  `Export/Internal/`; pbxproj registration and `bun run verify:ios` green.
