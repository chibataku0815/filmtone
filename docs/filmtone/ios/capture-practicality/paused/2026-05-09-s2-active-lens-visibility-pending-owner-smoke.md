# Active: S2 - Active Lens Visibility

Date: 2026-05-09 JST
Status: Paused — code-complete, pending owner-device smoke

Paused reason: Coder-side S2 work (always-on lens magnification prefix
in the cockpit's quality-contract line) is landed and verified
(`xcodebuild` BUILD SUCCEEDED). Remaining done condition is the
owner-device smoke that confirms multi-lens chip → contract line
agreement, mid-record disable behavior, and the single-lens device
readout. That smoke can only run on owner hardware. S3 - Continuous
Capture Flow proceeds in parallel because it depends only on the
cockpit having settled, which it has code-side.

## Milestone

S2 - Active Lens Visibility

## Goal

Make the currently active lens unambiguous at a glance from the capture
cockpit, so the owner does not need to infer it from framing or from a
chip's selected-state styling that may be subtle while shooting.

This is owner-visible readout work only. Do not expand into new lens
switching behavior, continuous zoom, or per-lens quality renegotiation.

## Product Locks

- The capture cockpit shows the active lens magnification label
  (e.g. `1×`) inline with the existing quality-contract line
  regardless of single- or multi-lens topology.
- On multi-lens devices the lens chip row's selected-state styling
  remains the primary control affordance; the contract line carries
  the canonical text readout.
- The contract line and the lens chip row never disagree.
- Lens visibility coexists with stabilization On / Off (S1 toggle) and
  with recording-disable rules — no new control becomes tappable
  during a recording.
- No new behavior ships: no new lens switching, no zoom, no format
  renegotiation.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureView.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureChrome.swift`
  (only if a small pure helper for the contract line lands here)
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureLensChipRow.swift`
  (only if the selected-state chip needs a clarity tweak)

Only add new Swift files if the existing components become too
crowded. If a new Swift file is added, register it in the Xcode project
4-section gate.

## Read-Only References

- `docs/filmtone/ios/capture-practicality/strategy.md`
- `docs/filmtone/ios/capture-practicality/paused/2026-05-09-s1-stabilization-toggle-pending-owner-smoke.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`

## Checklist

- [x] Survey current contract-line composition in
  `FilmtoneCaptureView.qualityContractText` and confirm the
  `shouldShowLensPrefix` conditional is the readout gap.
- [x] Decide whether to extract contract-line composition into a pure
  helper for responsibility separation, or keep it inline (god-object
  audit per `feedback_audit_layer_fit_before_placing_new_files`).
- [x] Always include the lens magnification label in the contract line
  when a `selectedLens` is non-nil (single- and multi-lens topology).
- [x] Verify the lens chip row continues to communicate selection on
  multi-lens devices. Tighten the selected-state styling only if it is
  already weaker than the contract-line text.
- [x] Confirm recording disables remain intact — chip row already
  inherits `isRecordingOrStopping` and the contract line is read-only.
- [x] Run focused verification and record results here.

## Verification

Required before archive:

```bash
git diff --check
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

If Swift package contracts or generated bridge contracts are touched:

```bash
cd apps/capacitor-film-lab-ios
bun run verify:swift-contract
```

Owner-device smoke before declaring product PASS:

1. Launch capture surface on iPhone 17 Pro Max (multi-lens) and confirm
   the contract line shows `1×` (or active lens) before any chip tap.
2. Tap a different lens chip; confirm the contract line updates to the
   new magnification and the chip row reflects the same selection.
3. Confirm stabilization On / Off chip still toggles independently and
   shows its own value next to lens text.
4. Start a record; confirm the lens chip row disables and the contract
   line remains readable but the lens prefix does not change mid-write.
5. Confirm `capture-package.json` still records the correct
   `lensDisplayName` for the run.

## Done Conditions

- Capture cockpit always displays the active lens magnification label
  in the contract line for any device topology.
- The contract line and lens chip row never disagree about which lens
  is active.
- Recording does not change the lens-readout state, only its
  interactivity.
- Existing capture loop still works: record, proxy, editor adoption,
  export.
- Verification results are appended to this file.
- This file is moved to
  `archive/YYYY-MM-DD-s2-active-lens-visibility.md` after the
  owner-device smoke passes; otherwise it pauses to
  `paused/<date>-s2-active-lens-visibility-pending-owner-smoke.md`
  while S3 begins.
- `strategy.md` gets only a 1-3 line completion log entry.

## Stop Conditions

Stop and report if any of these fires:

- The fix requires changing the lens enumeration / contract gate
  itself (out of scope; that is V2 capture milestone surface).
- The contract line needs a new render path beyond
  `FilmtoneCaptureTopStatusBar` to land lens text correctly.
- Three consecutive verification failures from the same root cause.
- The work starts to require S3 continuous capture flow, S4 SSD
  duration, or S5 preview render-loop changes.

## Out of Scope

- New lens switching behavior or gestures.
- Continuous / pinch zoom.
- Per-lens quality renegotiation, ProRes / Apple Log 2 / 4K24 / mode
  contract changes.
- Settings page or persistent lens-default UI.
- Broad multi-device QA.

## Verification Log

- 2026-05-09 JST — S2 implementation pass:
  - `git diff --check` clean on
    `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureView.swift`.
  - `xcodebuild -workspace
    apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App
    -destination 'generic/platform=iOS Simulator' -configuration
    Debug build CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **`.
  - `bun run verify:swift-contract` not re-run because S2 only
    touches a SwiftUI computed property — no Phase0 contract,
    sidecar shape, or Look math surface was reached. The S1
    revision pass left the contract gates green and S2 is text-only.
- Owner-device smoke (multi-lens contract-line readout, mid-record
  disable, single-lens device contract line) — pending owner-device
  run.

## Implementation Notes

- `FilmtoneCaptureView.qualityContractText` no longer gates the lens
  prefix on `lenses.count <= 1`. The active-lens magnification label
  is always prepended when `selectedLens` is non-nil. Single-lens
  devices keep the existing string shape (`"1× · 4K24 · Log2 ·
  ProRes"`); multi-lens devices now also get a text-readable
  companion to the chip row's selected-state styling instead of
  relying on chip selection alone.
- No new Swift file added. The change is a 1-getter edit; extracting
  it into a separate composer file would have added a `pbxproj`
  4-section gate cost without a corresponding god-object payoff
  (`FilmtoneCaptureView` already cleanly forwards a finished string
  to `FilmtoneCaptureCockpitTopBar`, which forwards to
  `FilmtoneCaptureTopStatusBar` — the layering was sound).
- `FilmtoneCaptureLensChipRow` left intentionally untouched. Its
  selected-state styling (bold weight + `captureGlassChip(active:
  true)` tint + 0.6pt rim stroke) is the control affordance; the
  contract line is the readout. Tightening the chip styling further
  would have started toward decorative work, which strategy / S1
  excluded.
- Recording disables remain intact: `FilmtoneCaptureLensChipRow`
  already applies `.disabled(isRecordingOrStopping || ... ||
  isSelected)` per chip, and the contract-line string is read-only
  text rendered by `FilmtoneCaptureTopStatusBar`.
