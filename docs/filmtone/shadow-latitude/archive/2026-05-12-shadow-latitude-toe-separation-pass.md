# Shadow Latitude / Toe Separation Pass

## Milestone

Shadow latitude foundation.

## Goal

Add hidden `shadowLatitude` plumbing and a separate `toeSeparation` render pass that restores recoverable low-shadow separation without lifting black cores.

## Edit Targets

- `packages/film-lab-core/`
- `packages/film-lab-renderer/`
- `packages/film-lab-swift-core/`
- `apps/capacitor-film-lab-ios/`
- `apps/filmtone-desktop-macos/`

## Read-Only References

- User-provided high-contrast city, tree, and building screenshots.
- Existing `detailSoftness`, `filmCompressionV3`, Phase0 schema, and renderer uniform plumbing.

## Checklist

- [x] Add core `shadowLatitude` contract, defaults, schema, clamp behavior, and scalar math.
- [x] Add scalar tests for black anchor, toe separation, release, hue direction, and clamp safety.
- [x] Propagate Swift payload/native DTO contracts without hand-editing generated Swift.
- [x] Add native Core Image toe separation stage after film compression and before detail softness.
- [x] Add WebGL/WebGPU toe separation stage after film compression and before LUT2.
- [x] Keep built-in Looks neutral; this pass only wires the shared render parameter.
- [x] Run targeted and requested verification.
- [x] Record product impact and archive this active task.

## Verification

- `bun test src/shadow-latitude.test.ts src/phase0-schema.test.ts src/schema.test.ts src/ios-swift-payload.test.ts src/creative-pack-01.test.ts` in `packages/film-lab-core` passed.
- `bun run build:core` passed.
- `bun run generate:ios-swift` passed; generated Swift was up to date.
- `swift test --package-path packages/film-lab-swift-core` passed.
- `bun run build:renderer` passed.
- `bun run verify:macos` passed.
- `git diff --check` passed.
- `bun run check:filmtone-context` passed.
- `bun run verify:ios` passed generated Swift drift check, then stopped in `xcodebuild` destination resolution for the scripted simulator check. No code-level iOS failure was reached.

## Done Conditions

- Requested contract/build checks completed, with the iOS environment blocker documented.
- Deep blacks remain anchored by scalar tests.
- Default `shadowLatitude = 0` is identity.
- UI remains unchanged.

## Stop Conditions

- Stop after 3 consecutive verification failures.
- Stop immediately if black-anchor invariants fail and cannot be fixed within the scalar model.

## Out of Scope

- UI controls, labels, or Advanced panel exposure.
- Frame-stat adaptive gates.
- General fade/shadow lift changes.
- Broad visual QA beyond the provided target failure class.

## Unexpected Blockers

- The scripted `verify:ios` simulator destination did not resolve in local Xcode. This is separate from device launch/visual checking and should not be treated as evidence that the app cannot run on the paired iPhone.

## Product Impact

No copy/history impact: no public copy or release notes are touched.

Article Opportunity: Developer note.

Change-History Opportunity: Yes, because this clarifies how Filmtone separates black density from recoverable shadow latitude.
