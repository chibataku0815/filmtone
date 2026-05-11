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
- Bundle grain: default to one product-relevant boundary per commit, not
  one helper per commit. Use active.md to define boundaries, invariants,
  stale-grep gates, and stop conditions; add line-level implementation
  detail only when the current seam proves risky.

## Closed Acceptance

The lane is closed on product-boundary outcomes, not on every helper-sized
implementation step:

1. Source layout is feature-vertical: 109 former flat-root source files moved
   into 10 feature folders (`Root/`, `Capture/`, `Editor/`, `Export/`,
   `Look/`, `Optics/`, `Source/`, `Services/`, `Smoke/`, `Strings/`) plus
   the existing `ExportActivity/` folder. There are no flat root `.swift`
   sources. `Root/` is used instead of `App/` to avoid `App/App/` nesting in
   the Xcode group hierarchy.
2. Export is no longer a single god object: `FilmtoneExportSession.swift`
   moved from ~5032 lines to 1078 lines and now coordinates collaborators
   for grade, optics, media writing, frame appending, source normalization,
   mezzanine routing, preview rendering, Connect package assembly, sidecar
   writing, video timing, queue pumps, completion, geometry, and IO setup.
   `FilmtoneExportSidecarBuilder.swift` remains the schema owner. Formal
   sidecar/PNG parity fixtures were intentionally not added; parity was
   guarded by `bun run verify:ios`, pbxproj registration checks, diff checks,
   and final owner smoke.
3. Editor state is split behind the existing facade: `FilmtoneEditorStore.swift`
   moved from 3441 to 1723 lines with project, library, preview, mutation,
   export/cache, and capture-relay collaborators. View files stayed unchanged;
   moved published state is bridged through the facade.
4. Capture is split behind the existing facade: `FilmtoneCaptureSession.swift`
   moved from 1849 to 880 lines with device, recording-state, and package
   assembly collaborators. `AVCaptureSession`, `sessionQueue`, movie output,
   preview VDO, and preview layer remain singularly owned by the facade.
5. Verification is intentionally minimal but product-relevant: `bun run
   verify:ios` stayed green across phase commits, `git diff --check` stayed
   clean, iOS truth script passed at closeout, and the owner-confirmed device
   smoke completed record -> adopt -> grade -> export.

## Milestones

- **Phase 1 — Source layout migration** — lane docs, mapping,
  filesystem moves, pbxproj rewrite, path repair, `verify:ios`, and
  rename-only diff gate. Complete.
- **Phase 2A/2B — ExportSession split** — accepted after the 2B-10D
  video IO setup bundle. The planned 2B-11 / 2C final orchestrator pass
  was skipped by owner decision to keep momentum; `FilmtoneExportSession`
  is thin enough for Phase 3 at 1078 lines.
- **Phase 3 — EditorStore split** — three larger bundles:
  - **Phase 3A** — access inventory + project/library/preview
    controller extraction.
  - **Phase 3B** — project mutation + export/cache coordination
    extraction.
  - **Phase 3C** — `CaptureRelay`, facade bridge cleanup, and
    focused UI reactivity verification. View code remains unchanged
    unless the compatibility table proves a minimal bridge adjustment is
    necessary.
- **Phase 4 — CaptureSession split** — one large implementation bundle
  plus closeout smoke:
  - **Phase 4A** — sessionQueue ownership decision +
    `CaptureDeviceManager`, `RecordingStateController`, and
    `CapturePackageAssembler` extraction.
  - **Phase 4B** — facade closeout and real-device record → grade →
    export smoke.

## Out Of Scope

- View body decomposition (`FilmtoneFullscreenLutEditor` 1262 lines /
  `FilmtoneCaptureView` 1086 lines). SwiftUI body size is structural;
  velocity impact is small relative to god-object splits.
- XCTest expansion, formal QA matrices, and PSNR / byte-parity fixtures.
  The owner accepted the minimal product-relevant gate set for this lane.

## Interrupt / Decision Log

- 2026-05-11 JST — Lane opened on
  `feature/ios-feature-architecture` branch fast-forwarded to
  `main @ dac08c81`. 1.8 release dirty state on owner's main worktree is
  not carried into this branch (owner commits when ready; merge strategy
  is straight merge because 1.8 bump touches build settings while refactor
  touches file references — different pbxproj sections).
- 2026-05-11 JST — Owner directed larger bundle grain after Phase 2B-10C.
  Planning changed from helper-sized sub-stages to product-boundary
  bundles. Active docs should name the boundary, invariants, and gates;
  line-level detail is added only when a seam is risky or verification
  fails. Target remaining cycles: 5-7.
- 2026-05-11 JST — Owner skipped the planned Phase 2B-11 / 2C
  ExportSession finalization pass. The post-2B-10D ExportSession state
  is accepted as Phase 2 complete enough for the product lane; move
  directly to Phase 3 EditorStore extraction.

## Completion Log

- **2026-05-11 JST — Phase 1: Feature-folder migration.**
  109 former flat-root source files moved into 10 feature folders plus
  the existing `ExportActivity/` target folder. pbxproj file refs and
  active script paths were repaired; rename-only diff and
  `bun run verify:ios` were green. Detail:
  `archive/2026-05-11-phase-1b-feature-folder-migration.md`.

- **2026-05-11 JST — Phase 2: ExportSession split.**
  The early Phase 2 work was executed too granularly (2B-1 through
  2B-10D), and those sub-stage archives are retained only as evidence.
  The product boundary result is the important state: the original
  ~5032-line export god object is now a 1078-line orchestrator backed by
  27 `Export/Internal/` collaborators plus cross-cutting extracted types
  in `Look/` and `Optics/`. Responsibilities now have clear owners:
  source-profile/input LUT, depth payload + depth matching, optics
  resampling/composition, grade rendering, media writing + frame append,
  source normalization, Connect package assembly, sidecar writing, still
  writing, mezzanine routing, preview rendering, video timeline, video
  queue pumps, completion coordination, geometry, and video IO setup.
  `FilmtoneExportSidecarBuilder.swift` stayed schema-owned; render /
  sidecar / writer invariants were guarded by `bun run verify:ios`,
  pbxproj 4-section greps, and `git diff --check` at each commit. The
  planned 2B-11 / 2C final pass was skipped by owner decision because
  2B-10D left the facade thin enough for Phase 3. Detail archives:
  `archive/2026-05-11-phase-2a-export-session-helper-extraction.md`
  through
  `archive/2026-05-11-phase-2b-11-export-finalization-skipped.md`.

- **2026-05-11 JST — Phase 3: EditorStore split.**
  `FilmtoneEditorStore.swift` moved from 3441 to 1723 lines. Six real
  collaborators landed under `Editor/Internal/`:
  `EditorProjectController`, `EditorLibraryController`,
  `EditorPreviewOrchestrator`, `EditorProjectMutationCoordinator`,
  `EditorExportCoordinator`, and `EditorCaptureRelay`. View files stayed
  unchanged; moved `@Published` state is bridged back through the facade
  with `objectWillChange` forwarding. The only target-band overshoot is
  documented: remaining live-preview processor factory code spans
  non-capture labels/cache state and was intentionally not folded into
  capture relay. Detail:
  `archive/2026-05-11-phase-3a-editor-project-library-preview-bundle.md`,
  `archive/2026-05-11-phase-3b-editor-mutation-export-coordinators.md`,
  and `archive/2026-05-11-phase-3c-editor-capture-relay-closeout.md`.

- **2026-05-11 JST — Phase 4: CaptureSession split.**
  `FilmtoneCaptureSession.swift` moved from 1849 to 880 lines. Three
  real collaborators landed under `Capture/Internal/`:
  `CaptureDeviceManager`, `RecordingStateController`, and
  `CapturePackageAssembler`. `AVCaptureSession`, `sessionQueue`, movie
  output, preview VDO, and preview layer remain singularly owned by the
  facade; collaborator state is bridged back through
  `objectWillChange`. View files stayed unchanged. Detail:
  `archive/2026-05-11-phase-4a-capturesession-large-split.md`.

- **2026-05-12 JST — Phase 4B / lane closeout.**
  `bun run verify:ios` green, iOS truth script green, no stale flat-path
  references in `RELEASE.md` or feature-architecture docs. Device
  build/install used `-workspace App.xcworkspace` and owner-confirmed
  smoke PASS on 千葉工のiPhone (7): record -> adopt -> grade -> export,
  one cycle. **Feature-architecture lane CLOSED.** Detail:
  `archive/2026-05-12-phase-4b-capture-smoke-and-lane-closeout.md`.
