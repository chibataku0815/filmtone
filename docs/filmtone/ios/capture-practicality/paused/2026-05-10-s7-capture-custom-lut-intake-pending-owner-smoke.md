# S7 - Capture Custom LUT Intake

Date: 2026-05-10 JST

## State

Code-side implementation is complete and merged. The lane is paused only for
owner-device smoke.

## Product Result

- Capture LOOK sheet can import and select user `.cube` creative LUTs.
- Filmtone keeps Apple Log 2 conversion app-owned before the creative LUT.
- Likely transform LUTs warn before use; accepting the warning is recorded.
- Capture package, editor adoption, and export sidecar carry custom-LUT
  provenance.
- The transform-LUT classifier preserves the imported filename and records the
  matched warning kind / signal.

## Verification

- `git diff --check` clean.
- `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` succeeded.
- `cd apps/capacitor-film-lab-ios && bun run verify:swift-contract` passed,
  including `test-capture-transform-lut-classifier.swift`.
- Signed Debug build installed to `千葉工のiPhone (7)`
  (`00008150-001674883C84401C`) with bundle id
  `com.chibatakumi.film.lab.ios`.

## Owner-Device Smoke

- [ ] Import a normal creative `.cube` from the capture LOOK sheet.
- [ ] Confirm the LOOK chip shows the custom LUT and live preview is graded.
- [ ] Record one short take and adopt it into the editor; the proxy opens with
  the same LUT.
- [ ] Export a short clip; sidecar records the custom LUT and conversion policy.
- [ ] Import a likely transform LUT such as `AppleLog_to_Rec709.cube`; warning
  appears before applying.
- [ ] Choose "そのまま使う" once and verify package / sidecar record that the
  warning was accepted.
