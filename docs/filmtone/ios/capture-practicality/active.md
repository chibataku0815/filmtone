# S7 - Capture Custom LUT Intake

Date: 2026-05-10 JST

## Milestone

S7 - Capture Custom LUT Intake

## Goal

Allow capture to use an owner-imported `.cube` creative LUT while recording.
Filmtone owns Apple Log 2 input conversion before the creative LUT slot. If a
loaded LUT looks like a technical transform LUT, warn that the image may break
because the conversion stage is already handled by the app.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureLookModel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureLookSheet.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCapturePackage.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCapturePackagePersistence.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift`

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `docs/filmtone/ios/capture-practicality/strategy.md`
- `docs/filmtone/ios/capture-practicality/2026-05-10-s7-capture-custom-lut-plan.md`

## Product Locks

- Do not bake the user LUT into the ProRes 422 HQ Apple Log 2 master.
- Treat imported capture LUTs as creative Look LUTs, not replacement input
  transforms.
- App-owned conversion must happen before the creative LUT in live preview,
  editor adoption, and export.
- No silent fallback: failed import, missing library blob, unsupported cube
  shape, and preview-grade build failure must be visible.
- Package and sidecar truth must identify the capture-time LUT and conversion
  policy.
- Keep the UI path inside the existing LOOK sheet.

## Checklist

- [x] Extend capture Look selection to represent Filmtone, built-in Looks, and
  user creative LUT entries.
- [x] Add User LUT import / recent-selection rows to the existing LOOK sheet.
- [x] Reuse `.cube` parsing and the LUT library with `preferredSlot = .creative`.
- [x] Add transform-LUT suspicion warning using title / filename keywords and
  neutral-ramp shape heuristics.
- [x] Preserve the imported `.cube` filename through capture import so filename
  keywords still warn when the cube `TITLE` is harmless.
- [x] Add a focused classifier contract test for filename-only, title,
  neutral-ramp, and creative-LUT non-warning cases.
- [x] Present Cancel / Use anyway before applying a likely transform LUT.
- [x] Build live capture preview processors for user LUTs without mutating the
  editor project before adoption.
- [x] Persist custom-LUT capture truth in `FilmtoneCapturePackage` and
  `capture-package.json`.
- [x] Apply the same user LUT on editor adoption when opening a captured take.
- [x] Add custom-LUT provenance to export sidecar capture metadata.
- [x] Run focused coder-side verification.

## Verification

Coder-side:

- [x] `git diff --check`
- [x] `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`
- [x] `cd apps/capacitor-film-lab-ios && bun run verify:swift-contract`

Owner-device smoke:

- [ ] Import a normal creative `.cube` from the capture LOOK sheet.
- [ ] Confirm the LOOK chip shows the custom LUT and live preview is graded.
- [ ] Record one short take and adopt it into the editor; the proxy opens with
  the same LUT.
- [ ] Export a short clip; sidecar records the custom LUT and conversion policy.
- [ ] Import a likely transform LUT such as Log-to-Rec709; warning appears
  before applying.
- [ ] Choose "Use anyway" once and verify package / sidecar record that the
  warning was accepted.

## Done Conditions

- Coder-side checks above stay green.
- Owner-device smoke passes on real capture hardware.
- No regression to S1-S5 product locks: stabilization truth, active lens
  visibility, continuous take selection, SSD 5 minute cap, and preview fallback
  badge behavior remain intact.

## Stop Conditions

- Done conditions met.
- Unexpected product conflict with S6 orientation work.
- Three consecutive verification failures on the same gate.

## Out Of Scope

- Baking LUTs into the recorded ProRes master.
- Using user LUTs as input transforms.
- Full library management, batch import, folders, marketplace, or cloud sync.
- Non-`.cube` LUT formats.
- Broad QA, screenshots, App Store work, and release work.

## Verification Log

- 2026-05-10: S7 implementation pass completed in isolated worktree
  `worktree-feature+ios-s7-capture-custom-lut-plan`.
- 2026-05-10: `git diff --check` clean.
- 2026-05-10: `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` -> `** BUILD SUCCEEDED **`.
- 2026-05-10: `cd apps/capacitor-film-lab-ios && bun run verify:swift-contract`
  passed through phase0 contract, motion blur, cube parser, cache store,
  source-color-classifier, ray-angle optics, source profile math, look x veil
  energy merge, and sidecar builder.
- 2026-05-10: Signed Debug build for `千葉工のiPhone (7)`
  (`00008150-001674883C84401C`) succeeded and was installed with
  `xcrun devicectl device install app`; bundle id
  `com.chibatakumi.film.lab.ios`.
- 2026-05-10: `千葉工のiPhone (6)` install path was not used because the
  device is not registered in the current development provisioning profile.
- 2026-05-10: Transform-LUT warning revision — capture import now preserves
  `originalFilename`, classifier output is structured as filename keyword /
  title keyword / neutral-ramp shape, warning copy is Japanese, and
  package/sidecar provenance records warning kind + matched signal.
- 2026-05-10: Added `test-capture-transform-lut-classifier.swift` to
  `verify:swift-contract`; it covers filename-only `AppleLog_to_Rec709.cube`,
  title keyword, neutral-ramp transform shape, and creative-LUT non-warning.
- 2026-05-10: Revision verification green: `git diff --check`,
  xcodebuild Debug build with `CODE_SIGNING_ALLOWED=NO`, and
  `cd apps/capacitor-film-lab-ios && bun run verify:swift-contract`.
- 2026-05-10: Revision signed Debug build installed to `千葉工のiPhone (7)`
  (`00008150-001674883C84401C`) with bundle id
  `com.chibatakumi.film.lab.ios`.
