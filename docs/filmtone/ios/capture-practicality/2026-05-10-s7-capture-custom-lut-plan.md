# S7 - Capture Custom LUT Intake Plan

Date: 2026-05-10 JST

## Goal

Allow the capture surface to use an owner-imported `.cube` creative LUT while
recording. Filmtone owns source conversion: Apple Log 2 capture frames are
converted by the app before the user LUT is applied. If the imported LUT looks
like a technical transform LUT, show a warning that the image may break because
the conversion stage is already handled.

This worktree queues S7 separately from the shared S6 orientation work. On
2026-05-10 the owner explicitly switched this worktree to S7 implementation.

## Product Locks

- Preserve master quality: do not bake user LUTs into the ProRes 422 HQ Apple
  Log 2 master in this lane.
- Treat capture-imported LUTs as creative Look LUTs, not input transforms.
- App-owned conversion happens before the creative LUT in live preview and
  export.
- No silent fallback: failed import, missing blob, unsupported cube shape, or
  live-grade build failure must be visible.
- Package and sidecar truth must identify the capture-time LUT and conversion
  policy.
- Keep UI surface minimal: extend the existing LOOK picker; do not build a
  full library manager.

## Implementation Plan

- [x] Extend `FilmtoneCaptureLook` from built-in-only records to a unified
  capture Look selection that can represent Filmtone default, built-in Looks,
  and user creative LUT entries.
- [x] Add a User LUT section to `FilmtoneCaptureLookSheet` with import,
  recent entries, and selected-state display.
- [x] Reuse `FilmtoneCubeParser`, `LibraryStoreActor.importLut`, and
  `.creative` slot storage for capture imports.
- [x] Add a transform-LUT suspicion classifier for imported `.cube` files:
  filename/title/profile keywords plus simple cube-shape heuristics over
  neutral ramp samples.
- [x] Present a warning when classifier result is transform-likely:
  "Filmtone already handles conversion. This LUT may double-transform the
  image and break color." Allow Cancel / Use anyway.
- [x] Build live-preview processors for user LUT selections by materializing a
  transient Saved Look / creative LUT request against the synthetic Apple Log 2
  capture source.
- [x] Persist custom-LUT selection on `FilmtoneCapturePackage` and
  `capture-package.json`: library id if available, title, size, source hash or
  embedded fallback, intensity, conversion policy, and warning acceptance.
- [x] Update editor adoption so capture packages with user LUTs open with the
  same creative LUT applied to the proxy.
- [x] Update export sidecar provenance so capture-time custom LUT and
  app-owned input conversion are auditable.
- [x] Run focused verification and record results.

## Verification Plan

Coder-side:

- `git diff --check` on S7-owned files.
- `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`
- `cd apps/capacitor-film-lab-ios && bun run verify:swift-contract` because
  package / sidecar wire shape changed.

Owner-device smoke:

1. Import a normal creative `.cube` from the capture LOOK sheet.
2. Confirm the LOOK chip shows the custom LUT and live preview is graded.
3. Record one short take and adopt it into the editor; the proxy opens with
   the same LUT.
4. Export a short clip; sidecar records the custom LUT and conversion policy.
5. Import a likely transform LUT such as Log-to-Rec709; warning appears before
   applying.
6. Choose "Use anyway" once and verify package/sidecar record that the warning
   was accepted.

## Risks

- Automatic transform-LUT detection is heuristic. The product contract should
  say "likely transform LUT" and warn loudly rather than pretending perfect
  classification.
- Long SSD takes make LUT choice quality more important than thumbnails alone;
  the selected take metadata must include the custom LUT title so the take
  chooser remains legible.

## Implementation Status

- 2026-05-10: Code-side S7 implementation is complete in the isolated
  worktree. `git diff --check`, xcodebuild, and app-level
  `verify:swift-contract` are green.
- Pending: owner-device smoke for real `.cube` import, live preview, capture
  package truth, editor adoption, export sidecar provenance, and transform-LUT
  warning acceptance.
