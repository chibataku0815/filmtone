# Active: M8 — Native Recording Product Flow

Date: 2026-05-08 JST
Worktree: `filmtone-worktrees/ios-v2-m6-avfoundation-stabilization-smoke` (lane shipped on the M6 worktree branch since its tip already includes the M7 commit; the post-M7 main worktree had unrelated WIP that owner triages separately)
Branch: `feature/ios-v2-capture-m6-avfoundation-stabilization-smoke` (M7 PASS commit `98a334e4` + this M8 commit)
Base: M6 worktree branch tip (= M7 PASS)

Status: **LANDED — xcodebuild PASS on this branch; owner device acceptance pending**

## Why this active exists

M7 landed the underlying capability — `FilmtoneEmptyView` has a Record
CTA, `FilmtoneEditorStore.recordProductClip()` is wired,
`FilmtoneProductCapture` runs on iPhone 17 Pro / iOS 26.4.2. What is
not yet a finished product is **the user-facing recording loop**: tap
record → see that recording is happening → end → land in the editor
on that clip → use Preset / export normally. M8 closes that loop on
top of M7.

Framing rule: this lane is **product UX**, not infra. Deletes,
audits, doc cleanup, React/Capacitor 撤去 are explicitly **not** in
this lane.

## Product loop M8 must deliver

1. From `FilmtoneEmptyView`, tapping Record starts capture immediately
   (no extra modal between tap and capture starting).
2. While recording, the user can clearly see that recording is in
   progress — not just `isBusy`. The signal must be unambiguous on
   the device, not only in code.
3. The recording duration is fixed at 5s (M7 owner-locked design).
   The simplest natural gesture is "wait for the visible countdown to
   complete" — no stop button. Tap-to-stop is explicitly out of
   scope; revisiting the capture-surface contract belongs in a
   later lane.
4. Once stopped, the clip auto-loads as the editor source. The user
   lands directly on `FilmtoneFullscreenLutEditor` with that clip,
   no extra confirmation step.
5. The clip behaves exactly like a Photo Library / Files source from
   that point on: existing Preset selection works, existing export
   pipeline works. No record-only branch in the editor.
6. If recording fails (permission denied, hardware unavailable,
   write error, user cancel), the user sees a clear, localized
   message and the app returns cleanly to `FilmtoneEmptyView`. Not
   silent, not a crash, not a stuck `isBusy`.

That is the entire product surface. Anything beyond it is out of
scope for M8.

## Implementation notes (non-prescriptive)

- The capture surface itself already exists (`FilmtoneProductCapture`).
  M8 is mostly UI / state-machine work in
  `FilmtoneEditorStore` + a recording-state view, not new AVFoundation
  code.
- Status text strings (`recordProductClip` / `.running` / `.failed`)
  exist in `FilmtoneStrings` from M7. Reuse and extend only as needed.
- Mirror the existing `pickSource` pattern for the post-recording
  handoff: `applyProbe(source:probe:)` → `persist()` →
  `reclaimCacheForCurrentState()` → `schedulePreviewRender()`.
  The recorded clip should not be a special case in the editor.
- Recording-in-progress UI: keep it minimal and SwiftUI-native (no
  NSViewRepresentable / UIKit bridges — see
  `feedback_nsviewrepresentable_blocks_liquid_glass`). A clear visual
  state on the existing surface is enough; do not design a new
  fullscreen overlay unless the simpler option fails the "user can
  tell recording is happening" bar.
- Errors: surface through the existing alert / banner pattern in
  `FilmtoneRootView` if there is one; otherwise a SwiftUI `.alert`
  bound to `store.errorMessage` (or equivalent) is sufficient.

## Out of scope for M8

- React/Capacitor stack purge. Deferred as **tech debt**, picked up
  in a separate lane after M8 is shipping. Do not delete React /
  Capacitor files in this lane even opportunistically.
- Directory rename `apps/capacitor-film-lab-ios/` →
  `apps/filmtone-ios/`. Same — separate lane.
- Background recording, multi-clip recording, recording presets,
  pre-record exposure / look preview. Single-take, default capture
  config only.
- Gyroflow / Core Motion sample alignment. Already separately
  scoped in `strategy.md`; not a M8 dependency.
- Formal QA matrix. Verification is "the loop works on the device",
  see below.

## Acceptance

Owner-visible acceptance on iPhone 17 Pro / iOS 26.4.2: owner can
see recording start, recording-in-progress, automatic editor entry
on the recorded clip, the existing Preset and export path working
on that clip, and a clear localized message on permission /
hardware / write failures with a clean return to the empty view.

The bar is owner-visible behavior, not a manual test matrix. No
per-commit device cycle, no automated capture smoke beyond what is
already in `#if DEBUG`.

## Done conditions

1. Acceptance above is observed by owner on iPhone 17 Pro /
   iOS 26.4.2.
2. The recording-in-progress state is unambiguous to a user who
   does not know the codebase (smoke-test bar: an outsider can tell
   they are recording without being told).
3. No new error path silently swallows a failure. Every failure
   surfaces a localized user-visible message.
4. No regression in Photo Library / Files source flows or in
   existing Preset / export.
5. No React/Capacitor file is touched.

## Rollback plan

If end-of-lane verification fails, isolate the failing step and
revert the smallest commit that introduced it. Do not amend M7.

## Preconditions (note)

M7 commit `98a334e4` will land on main once owner triages the
unrelated WIP in the main worktree. The clean home for M8 is a
fresh worktree off post-M7 main; starting on the M6 branch (whose
tip already includes M7) is also acceptable so the product work
does not stall.

## Note on the React/Capacitor purge lane

The previous draft of this file scoped a React/Capacitor 撤去 lane.
That work is still legitimate but is **not the main fight right now**
and has been demoted to deferred tech debt. It will get its own
active when M8 is shipping and the runtime story is settled.

## Outcome (2026-05-08)

Shipped:

- `FilmtoneEditorStore` — `FilmtoneRecordingUIState` struct
  (`startedAt`, `durationSeconds`); `@Published var recordingState`
  set on entry to `recordProductClip(durationSeconds:)`, cleared the
  moment `capture.recordClip` returns (before the probe phase) and
  also cleared on the failure path; `@Published var recordingError`
  set with the localized capture-error detail (no prefix), distinct
  from the generic `error` bag so the alert binds only to recording
  failures.
- `FilmtoneRootView` — `recordingOverlay` private @ViewBuilder
  mounted at `zIndex(30)` above `adjustmentHelpOverlay`. Translucent
  backdrop blocks empty-view CTAs; `TimelineView(.periodic(by: 0.05))`
  drives a circular progress ring (red), an integer countdown (5 →
  1) in monospaced rounded face, and a pulsing red dot beside the
  localized `recordProductClipRunning` label. Body chain gains a
  `.alert` bound to `store.recordingError` with title =
  `recordProductClipFailed`, body = detail, role-`.cancel` OK.
- Verification: `xcodebuild -workspace App.xcworkspace -scheme App
  -configuration Debug -destination 'generic/platform=iOS'` ⇒ BUILD
  SUCCEEDED. Owner device acceptance (5-step loop + permission
  failure path) is the remaining gate.

Boundary respected: no React/Capacitor file was touched in this
lane; no directory rename; no strategy doc rewrite beyond the
single Completion Log line. The capture surface contract
(fixed-duration only) is unchanged from M7.
