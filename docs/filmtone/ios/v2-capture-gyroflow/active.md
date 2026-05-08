# Active: M10 — Native Camera Capture Surface + Proxy Workflow

Date: 2026-05-08 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Base: `main` after M9 landed (`436304d2`)

Status: **IMPLEMENTATION COMPLETE — S7 owner walk PENDING**

This active exists to pin the implemented state of M10 before S7. Not a
plan doc. After S7 PASS, fill `## Outcome` and archive.

## Goal

Native camera surface as the iOS entry: SSD master + local proxy +
editor handoff. Replaces the React/Capacitor `recordClip` UI as the
primary owner flow.

## Locked capture contract

- 3840×2160 **24 fps** (cinematic 24p) — `FilmtoneCaptureSession.lockedFPS = 24`
- ProRes 422 HQ — `apch` FourCC verified post-finalize via `AVURLAsset`
- Apple Log 2 colorspace (rawValue 4) verified active before record start
- `cinematicExtendedEnhanced` stabilization, exact-match gate (no downgrade)
- Single-cam rear `builtInWideAngleCamera`, format index 56

## Storage modes

- **No-SSD**: local Caches package dir, **10s hard cap** (product-enforced)
- **SSD**: external security-scoped folder, **60s soft cap**
- Preflight requires ≥10 GB free + capacity-divergence hard reject so
  "On My iPhone" can't be misclassified as external

## Editor handoff

- Proxy generated next to package; editor adopts via
  `FilmtoneEditorStore.adoptCaptureResult(_:)`
- `capture-package.json` persisted next to proxy + best-effort mirrored
  into the external folder; relaunch reconnects via
  `currentCapturePackageRef` on the persistence snapshot

## S1 findings

- External storage pattern (security-scoped picker, capacity probe,
  `.atomic` write probe, statfs(3) fallback for userfsd / FileProvider
  mounts that return 0 from capacity APIs) imported from
  **DualLogCamera** and adapted; `classify()` promotes
  `volumeTotalCapacity` divergence to a hard reject (DualLog only logs).

## Implementation summary

New Swift files (6):

- `FilmtoneCaptureSession.swift` — AVCaptureSession + MovieFileOutput
  pipeline, exact stabilization / colorspace / codec gates
- `FilmtoneCaptureView.swift` — SwiftUI capture surface, spec readout,
  teardown on completion / failure / disappear
- `FilmtoneCapturePackage.swift` — package + parameters + failure enum
- `FilmtoneCapturePackagePersistence.swift` — `capture-package.json`
  read / write, local + external mirror
- `FilmtoneCapturePreflight.swift` — capacity / classification / 10 GB
  gate
- `FilmtoneProxyGenerator.swift` — master → editor proxy export

Modified:

- `FilmtoneEditorStore.swift` — `adoptCaptureResult`,
  `currentCapturePackageRef`, source-replacement linkage clear
- `FilmtoneRootView.swift` — capture surface entry wiring
- `FilmtonePersistence.swift` — additive Codable
  `currentCapturePackageRef`
- `App.xcodeproj/project.pbxproj` — 4-section registration for the 6
  new files (verified)

## Review fixes (post-first-pass, 2026-05-08)

- **P1-1** classification 厳格化: `volumeTotalCapacity` 一致時 hard reject
- **P1-2** teardown 保証: `.completed` / `.failed` / `.onDisappear` 全
  経路
- **P1-3** master truth gate: stabilization exact-match + AVURLAsset
  `apch` FourCC verify
- **P1-4** capture-package.json + `currentCapturePackageRef` (B-anchor:
  decoupled from `SourceInfoDTO`)
- **P2-1** spec label: display-only readout + nearest-K rounding
  (`4K24` not `3K30`)
- **P2-2** preflight 10 GB gate (was 5 GB)
- **F1** capture-package.json 書き込み失敗を `packagePersistenceFailed`
  でvisible failure 化、editor は実 file 存在保証時のみ ref を set
- **F2** M10 contract を 30fps → **24fps** に変更 (cinematic 24p)

## S7 owner walk (BLOCKED on S8 product-surface gaps)

Hardware: iPhone 17 Pro / iOS 26.4.2. Two paths to land:

1. **No-SSD path** — record (10s cap) → editor → preset → export → save
2. **SSD path** — record (≥10s, ≤60s) → editor → preset → export → save

Acceptance: both paths land an artifact the owner can open in Photos
without a stuck `isBusy`, silent failure, or stabilization / codec /
colorspace downgrade banner.  Resumes at S8-E once S8-A..D have shipped.

## S8 — capture surface product completion

- [x] **S8-A** Re-record entry from editor (Record button in editor chrome).
- [x] **S8-B** Rear lens selector — runtime enumeration + 4K24 /
  Apple Log 2 / cinematicEE format-level gate, default = wide,
  capture package records lens identifier / display name / device type.
- [x] **S8-C** Capture parameter operate / readout UI — locked
  contract banner (4K24 / ProRes 422 HQ / Apple Log 2 / Cinematic EE
  / Proxy → Editor) + storage pill with cap (`Internal master · 10s
  cap` / `External master · <folder> · 60s cap`); operable surface
  remains lens · storage target · record/stop, no exposure / WB /
  focus / zoom.
- [x] **S8-D** Look-applied preview on capture surface — reference
  thumbnail strip route. Capture surface receives a snapshot of the
  editor's current Look state (`FilmtoneCaptureLookReference =
  selectedPreviewURI + lookProfileLabel`) at fullScreenCover
  present time and renders a small "LOOK REFERENCE" panel below
  the storage pill: graded poster thumbnail (120×90) + look label
  + "Live ungraded" disclaimer. Owner can judge color direction
  before recording without coupling capture loop to editor
  publishers. Decode runs on `Task.detached(.utility)` keyed by
  `displayURI` so recording state ticks do not redecode.
  Omitted (recorded as out-of-scope for M10):
    - **Live frame grading** — applying the grade to the
      `AVCaptureVideoPreviewLayer` would require swapping it for a
      `AVCaptureVideoDataOutput` + CIFilter compositor, which
      conflicts with the ProRes 422 HQ + Apple Log 2 + cinematicEE
      record pipeline (M2-A: iOS 26.4 does not deliver 10-bit
      `x422`/`x420` from VDO under `.appleLog2`). Live preview
      remains the raw camera pass-through; this is labelled "Live
      ungraded" in the panel.
    - **Reference for video sources without a baked still poster** —
      `FilmtonePreviewState.video` exposes an `AVPlayer`, not a
      file URI; `selectedPreviewURI` returns nil there and the
      panel is hidden. Falling back to a player-frame snapshot
      would re-introduce a CIFilter pass and was not pursued.
    - **Reference for editor mid-render** — when the editor
      preview is rendering at the moment Record is tapped,
      `selectedPreviewURI` is nil and the panel is hidden until
      the next session.
- [ ] **S8-E** S7 owner walk resume (no-SSD + SSD).

## Outcome

Pending S7. Fill on PASS, then archive as
`archive/YYYY-MM-DD-m10-native-camera-capture-surface.md`.
