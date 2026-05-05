# Filmtone Native Desktop v2 Strategy

Date opened: 2026-05-04 JST
Last updated: 2026-05-05 JST

This file is the compact source of truth for the Native Desktop v2 lane.
Implementation logs, chat handoffs, and detailed verification records belong in
`archive/`.

## Goal

Replace the legacy Electron Desktop product lane with a macOS 26 native
SwiftUI/AppKit app that follows the iOS Filmtone product model and ships as
Desktop v1.4.

Native Desktop v2 is a single-product cutover, not a parallel product. Electron
Desktop remains frozen as the public legacy rail at 1.0.4 for pre-macOS-26
users; the native app takes over the Desktop Bundle ID
`com.chibatakumi.film-lab-desktop` and the fixed Desktop download/update rail
when v1.4 is released.

Apple Liquid Glass is the primary material for control surfaces: toolbar,
sidebar, inspector, picker, menus, scrub bar, and editing panels. The preview
content layer stays glass-free so color judgment is not compromised.

## Measurable Done Conditions

- Native macOS app opens still images and videos with native Mac controls.
- Still preview, video preview, still export, and video export use the
  iOS-canonical Filmtone grade path for supported built-in Looks.
- Exports write compatible sidecars without a schema bump.
- Look / Preset / adjustment vocabulary matches iOS and is localized for
  Japanese and English surfaces that are visible in the native app.
- Video playback is smooth enough for editing review, with audio, scrub, and
  rate control.
- Compare is a real preview tool, not only a fixed 50:50 debug split.
- Liquid Glass control surfaces are readable, elegant, and consistent on the
  4px / 8px spacing grid.
- The app can be built, smoke-tested, signed/notarized, stapled, packaged, and
  published as the primary Desktop release candidate.

## Milestones

| ID | Milestone | Depends on | Status | Done Condition |
|---|---|---|---|---|
| M1 | Native Contract And Skeleton | none | Complete | Native window, SwiftUI/AppKit shell, no Electron rail regression. |
| M2 | Still And Video Vertical Slice | M1 | Complete | Still/video open, preview, export, and sidecar paths work in the native app. |
| M3 | Native Color And Optics Parity | M2 | In progress | Built-in Looks use iOS-canonical color/optics stages; remaining parity gaps are explicit. |
| M4 | Shared Contract Consolidation | M3 | In progress | Shared Swift ownership is clear and iOS/macOS consume the same canonical contract where practical. |
| M5 | Native Editing UI | M3 | Validation / thin fixes | Core editing workflows are usable and visually acceptable in the native UI. |
| M6 | Release Cutover | M5 | Released 2026-05-05 | Public update metadata reports Desktop `1.4`, and the fixed Desktop download rail points to the notarized Native DMG. |

## Current Strategic State

- Branch: `feature/native-desktop-plan`
- Current integrated code HEAD for the public artifact: `4f2e5eba`
  (`Merge remote-tracking branch 'origin/main' into feature/native-desktop-plan`)
- Integration base before M5-K1/K2/K3/K4: `0b79861f`
- No M5-K product `active.md` should remain open. If `active.md` exists during
  DHM / release-cutover interrupts, do not treat it as current M5-K state.
- Public Desktop latest from truth script: `1.4` via update metadata.
- iOS public and local marketing version from truth script: `1.4`.
- Native Desktop v2 public release: Desktop v1.4, aligned with iOS.

M1 and M2 are closed. M3 and M4 stay open for parity hardening and shared-core
promotion, but they no longer block M5 UI validation. M5-C P0, M5-G
architecture thin cuts, M5-H/I parity recovery, and M5-J sidebar / compare /
slider polish have been integrated into the native plan branch.

The user visually accepted the current M5-J integrated state on 2026-05-05.
M5-K1 / K2 / K3 / K4 are integrated: chrome/opening readability, Look + strength
grouping, draggable still/video compare split, and graded scrub thumbnail
preview. K4 hover follow-up fixes are included in `6097acdd`; the user visually
confirmed on 2026-05-05 that the scrub hover behavior is acceptable.

## Current M5-K State

M5-K visual follow-ups from the post-J handoff are integrated. Create exactly
one `active.md` before opening any new follow-up.

### M5-K1 Chrome Stability + Opening Readability

Closed 2026-05-05. Toolbar items now keep stable identity through sidebar
toggles, and the empty opening screen has a bounded readable Liquid Glass field.

Archive:

```text
archive/2026-05-05-m5-k1-chrome-opening.md
```

### M5-K2 Look + Strength Grouping

Closed 2026-05-05. Look strength now lives directly under the Look picker in the
same panel; the empty `GradeControls` panel was removed.

Archive:

```text
archive/2026-05-05-m5-k2-look-strength-grouping.md
```

### M5-K3 Draggable Compare Bar

Closed 2026-05-05. Compare now has a clamped split fraction, a draggable preview
bar, still-preview masking, and AVPlayer video composition split threading.

Archive:

```text
archive/2026-05-05-m5-k3-compare-bar.md
```

### M5-K4 Scrub Thumbnail Preview

Closed 2026-05-05. Hover/drag over the video scrub bar now requests graded,
cached thumbnails via a small-canvas AVAssetImageGenerator composition. Review
fixes added in-flight request coalescing, duration-safe quantization, measured
capsule clamping, and portrait-safe letterboxing. Parent integration follow-ups
then moved hover tracking to a non-hit-testing AppKit tracking layer, disabled
video scrub hover knob expansion, and rendered the thumbnail as a non-layout
overlay so hover does not shake or move the scrub bar.

Archives:

```text
archive/2026-05-05-m5-k4-scrub-thumbnail-preview.md
archive/2026-05-05-m5-k4-review-fixes.md
archive/2026-05-05-m5-k4-review-fix-2-quantize-within-duration.md
archive/2026-05-05-m5-k4-integration.md
```

### M5-M Portrait Layout + Backlight Veil + Compact Opening

Closed 2026-05-05. Portrait sources reserve sidebar/scrub geometry, Backlight
Veil profile/intensity is wired through still/video preview and export, and the
empty launch opens compact. Archive:
`archive/2026-05-05-m5-m-portrait-backlight-opening.md`

## Release Cutover State

Native Desktop v2 replaced the public Desktop release rail on 2026-05-05 after
the parent branch was corrected, `origin/main` was merged, and the clean v1.4
release run completed from code HEAD `4f2e5eba`.

Current public state:

- update metadata reports `latestVersion: "1.4"`
- fixed download page:
  `https://www.chibatakumi.studio/film-lab/download`
- active DMG:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.4.dmg`
- DMG sha256:
  `40d2b2fd745c648849d310856e2bcd5d0db0afd948b3842fd83800f68e705cb8`
- production Vercel deployment:
  `chibatakumi-portfolio-1bttmm5np-forestones-projects.vercel.app`

Release gates passed:

- `bun run release:cutover-preflight`
- `bash apps/filmtone-desktop-macos/Verify/run.sh` (`99/99`)
- `bun run verify:macos`
- `git diff --check`
- `scripts/release-macos.sh`
- `scripts/package-dmg.sh`
- public DMG HEAD check
- public update-meta check
- release truth script

Remaining post-release product risks:

- Broader real-media Source Auto / Conversion LUT coverage still needs more
  population testing beyond the accepted Apple Log / Apple Log 2 parity path.
- Backlight Veil is implemented in the Native app, but visual tuning should be
  watched against iOS on difficult backlit footage.
- Advanced recipe chips are visible, but the full iOS editing mental model still
  needs longer-session product QA on Desktop.

Release-cutover details live in:

```text
docs/filmtone/desktop/release-cutover/
```

## Evidence Index

Use these archives as evidence, not as current truth.

### Current Handoff Evidence

- `archive/2026-05-05-native-desktop-v2-post-j-visual-handoff.md`
- `archive/2026-05-04-native-desktop-v2-m4b-m5c4-handoff.md`

### Recent Product Milestones

- `archive/2026-05-05-m5-i-integration-product-parity-recovery.md`
- `archive/2026-05-05-m5-i1-localization-copy-parity.md`
- `archive/2026-05-05-m5-i2-avplayer-preview-route.md`
- `archive/2026-05-05-m5-i3-control-spacing-and-slider-polish.md`
- `archive/2026-05-05-m5-j1-sidebar-shell-v2.md`
- `archive/2026-05-05-m5-j2-compare-v2.md`
- `archive/2026-05-05-m5-j3-slider-polish-v2.md`
- `archive/2026-05-05-m5-j1-j2-v2-integration-intake.md`
- `archive/2026-05-05-m5-j3-v2-integration-intake.md`
- `archive/2026-05-05-m5-k1-chrome-opening.md`
- `archive/2026-05-05-m5-k2-look-strength-grouping.md`
- `archive/2026-05-05-m5-k3-compare-bar.md`
- `archive/2026-05-05-m5-k4-scrub-thumbnail-preview.md`
- `archive/2026-05-05-m5-k4-review-fixes.md`
- `archive/2026-05-05-m5-k4-review-fix-2-quantize-within-duration.md`
- `archive/2026-05-05-m5-k4-integration.md`
- `archive/2026-05-05-m5-m-portrait-backlight-opening.md`
- `archive/2026-05-05-dhm-shared-highlight-marker-mvp.md`
- `archive/2026-05-05-dhm-5-davinci-e2e-smoke-harness.md`
- `archive/2026-05-05-dhm-5-marker-highlight-reel.md`

### Architecture / Parity Evidence

- `archive/2026-05-04-m4-a-shared-swift-boundary-cut-line.md`
- `archive/2026-05-04-m4-b-shared-phase0-core-package.md`
- `archive/2026-05-04-m5-c-ios-feature-parity-audit.md`
- `archive/2026-05-04-m5-c4-export-inspector.md`
- `archive/2026-05-05-m5-c3b-advanced-adjust-editor.md`
- `archive/2026-05-05-m5-g-architecture-thin-cuts.md`
- `archive/2026-05-05-m5-h1-chrome-preview-layout.md`
- `archive/2026-05-05-m5-h2-adjust-library-parity.md`
- `archive/2026-05-05-m5-h3-dual-lut-spike.md`
- `archive/2026-05-05-m5-d2-avplayer-playback-spike.md`

### Future Product Direction

- `davinci-highlight-marker-handoff-plan.md`

Future cross-device SSD / sidecar / DaVinci work is a compatibility constraint,
not a v1.4 gate unless the user explicitly changes release scope.

2026-05-05: M5-K1/K2/K3/K4 integrated into `feature/native-desktop-plan` as
`6097acdd`: chrome/opening readability, Look + strength grouping, draggable
still/video compare, and graded scrub thumbnail preview. Verification was green
(`Verify/run.sh` 86/86, `bun run verify:macos`, `git diff --check`), and K4
visual follow-ups for hover hit-testing, hover geometry stability, and overlay
layout are included. User visual confirmation of scrub thumbnail hover stability
passed on 2026-05-05.

2026-05-05: Replacement cutover readiness prep added a read-only
`release:cutover-preflight`, Native Desktop `RELEASE_NOTES-v1.4.md`, and a
public runbook / rollback checklist under `docs/filmtone/desktop/release-cutover/`.
At creation time, public update-meta remained on Desktop `1.0.4`; this was later
superseded by the M5-L parity follow-ups and M6 clean public release.

2026-05-05: DHM-5 marker Highlight Reel is implemented across shared Swift
core, iOS, Native Desktop, and DaVinci. Verification covered shared Swift tests,
iOS verify + Simulator build, Native Desktop Verify + Debug build/launch, and
DaVinci dry-run plus Resolve smoke for `customData` and `Highlight_Auto`.

2026-05-05: Phase 9 replacement cutover was attempted, then rolled back after
the user clarified the desired order: parent branch correction, `main` merge,
then release. The generated `Filmtone.app` and `Filmtone-1.4.dmg` were signed,
notarized, stapled, and Gatekeeper accepted, and the DMG remains uploaded to
Vercel Blob. Public update metadata and the download surface have been restored
to the legacy Desktop rail (`latestVersion: "1.0.4"`).

2026-05-05: DHM shared highlight marker MVP landed in isolated worktree
`feature/shared-highlight-markers`: source-relative marker contract, iOS/Desktop
sidecar read/write, and DaVinci marker/rough-cut import path verified.

2026-05-05: DHM-5 added a repeatable DaVinci Resolve smoke harness and
customData-based duplicate protection for highlight marker import.

2026-05-05: DHM-6 proved the app-generated sidecar path end to end: Filmtone
app code emits `highlightMarkers`, and the production DaVinci importer reads it
back through real Resolve marker customData and `Highlight_Auto` verification.

2026-05-05: DHM-7 hardened repeated DaVinci import: the importer refreshes
existing highlight markers by Filmtone customData, and the Resolve smoke now
imports the same app-generated package twice while verifying customData
uniqueness.

2026-05-05: DHM-8 completed the first in-app marker editing loop: iOS fullscreen
video and Native Desktop scrubbers expose marker chips for source-relative jump
and delete while preserving the shared sidecar marker contract.

2026-05-05: DHM-8 direct smoke evidence captured Desktop marker chip UI and
real DaVinci repeated-import readback under
`evidence/2026-05-05-dhm-8-direct-smoke/`.

2026-05-05: M5-L1 Source Auto / Conversion LUT parity landed on
`feature/native-desktop-m5-l1-source-auto`: Desktop Auto now uses the iOS-style
first-sample Apple Log fallback, source-profile retention, and visible Auto
detection labels. Verification was green (`Verify/run.sh` 93/93,
`bun run verify:macos`, `git diff --check`); Debug app launched, and the user
confirmed real-device / real-media visual smoke.

2026-05-05: M5-L2 Advanced Recipe Chip Discoverability landed on
`feature/native-desktop-m5-l2-advanced-chips`: Desktop advanced editing now
surfaces iOS-style recipe chips beside their groups before slider expansion.
Verification was green (`Verify/run.sh` 94/94, `bun run verify:macos`,
`git diff --check`); Debug app launched.

2026-05-05: M5-L3 Backlight Veil landed on
`feature/native-desktop-m5-l2-advanced-chips`: Native Desktop now exposes
Backlight Veil 1/8, 1/4, and 1/2 as a named optical filter, resolves its
supported values through preview/export, and emits sidecar profile identity.
Verification was green (`Verify/run.sh` 97/97, `bun run verify:macos`,
`git diff --check`); Debug app launched.

2026-05-05: M5-M Portrait Layout + Backlight Veil + Compact Opening — code
verification passed (`Verify/run.sh` 111/111, `bun run verify:macos`,
`git diff --check`); portrait video / still / Backlight Veil cursor visual
smoke remains user-pending. Lane is open as `active.md`; do not archive
until the user confirms visual smoke.

2026-05-05: M6 clean public release completed after parent-branch correction and
`origin/main` merge. Native Desktop v1.4 is now the active public Desktop rail;
update metadata reports `latestVersion: "1.4"`, and the fixed download page
points at the notarized/stapled `Filmtone-1.4.dmg` built from code HEAD
`4f2e5eba`.

2026-05-05: M6 post-release source finalization closed the Electron workspace
as frozen legacy source for pre-macOS-26 access and emergency rollback. Native
Desktop is the active Desktop product lane; Electron remains source-retained,
not deleted.

2026-05-05: M6 source permanence finished: `feature/native-desktop-plan` was
pushed, `main` was updated through merge commit `3ce0f1b0`, `desktop-v1.4` was
tagged, and portfolio `vendor/filmtone` was bumped to that source state.

## Constraints

- macOS target is macOS 26 only.
- SwiftUI-first; AppKit is allowed for platform behavior and interop.
- iOS remains the canonical color/optics/product reference.
- Do not hand-edit generated Swift.
- Sidecar changes are additive only unless a product need requires a schema
  bump.
- Use `bun`; do not introduce npm/yarn/pnpm lockfile churn.
- Keep `packages/film-lab-renderer/dist/` and
  `packages/film-lab-smart-look/dist/` tracked.
- Do not stage, commit, push, notarize, or bump portfolio submodules unless the
  user explicitly asks.
- Do not use old handoffs as current truth; rerun truth scripts for version or
  release-state claims.

## Open Questions

- Does the current AVPlayer preview route fully satisfy visual playback smoothness
  on the user's real footage set?
- Should Dual LUT intensity wiring land as a v1.4 thin fix or move with the full
  Dual LUT surface to v1.5?
- Does baseline-C need formal population now, or only when release QA asks for
  broader parity proof?
- What source identity / relink fields should the sidecar carry for SSD movement
  between Mac and iPhone?
- What source relink/content identity should v2 add beyond filename/duration/fps
  for cross-device SSD moves?

## Operating Rules

- Read this file at Native Desktop v2 session start.
- Read `active.md` every implementation turn.
- If `active.md` is missing, propose or create exactly one scoped task before
  editing.
- Keep only one `active.md` at a time.
- Archive completed active tasks into `archive/`.
- Append only short strategy notes here; detailed logs belong in archive files.
- Product code changes require the smallest verification that proves the changed
  surface, usually:

```bash
bash apps/filmtone-desktop-macos/Verify/run.sh
bun run verify:macos
git diff --check
```
