# Native Desktop v2 Active Task: Film Damage 2.1 Host Bridge

Milestone: M3 / M4 Native Color And Optics Parity

Goal: Review the visual-effect-core Film Damage contract revision 2.1, then
port the bridgeable quality-ceiling semantics into native Desktop and iPad
without changing the public Filmtone Film Damage UI or sidecar shape.

Placement: This is the single current Native Desktop v2 active task. It follows
`archive/2026-06-01-film-damage-candidate-a.md` and the visual-effect-core
2.1 bridge note.

Edit targets:
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`
- This active task doc
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only on completion

Read-only references:
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/packages/visual-effect-core/src/features/film-damage/types.ts`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/packages/visual-effect-core/src/features/film-damage/defaults.ts`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/packages/visual-render-core/src/features/film-damage/reference.ts`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/docs/bridge-verification/film-damage-gpu-parity.md`
- `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-candidate-a3/film-damage-current-*.png`

## Scope

Implement now:
- Keep Filmtone controls as `dustAmount` / `scratchAmount`.
- Add internal v2.1-style format/global scaling derived from product intensity.
- Add stronger temporal lifetime / fade behavior for dust, stains, scratches,
  and fibers.
- Add scratch gap/taper/roughness behavior that avoids uniform full-height lines.
- Add fiber persistence/wiggle behavior that survives across adjacent frames.
- Keep Desktop and iPad kernel semantics matched.

Defer:
- True `gateWeave` source-coordinate remap.
- True `defocus` source sampling.
- Dedicated debug mask export surfaces beyond the visual probe.
- New public controls, labels, or sidecar schema changes.

## Acceptance Criteria

Pass if:
- visual-effect-core 2.1 was reviewed and mapped into host-bridge categories.
- Desktop and iPad kernels compile with matching semantics.
- Generated comparison sheets show less static overlay behavior than A3,
  especially for Strong and scratch-only cases.
- Scratches show visible gaps/taper/nonuniformity.
- Fibers/hairs read as persistent material marks rather than new random lines
  every frame.
- Default remains subtle and does not first-read as damage.

Reject if:
- The result returns to white sparkle dominance.
- Strong reads as TV/VHS noise rather than projector/gate damage.
- Scratches become clean full-frame vertical strokes.
- The single color-kernel path cannot achieve visible improvement without
  sampler/multi-pass support.

## Checklist

- [x] Confirm visual-effect-core 2.1 contract and bridge note.
- [x] Create the host bridge implementation plan.
- [x] Implement 2.1 bridge semantics in Desktop kernel.
- [x] Port matching semantics to iPad/iOS export kernel.
- [x] Regenerate comparison sheets.
- [x] Visually inspect generated dark/midtone/bright sheets.
- [x] Run Desktop runtime/kernel verification.
- [x] Run Desktop build verification.
- [x] Run iOS verification.
- [x] Run context/diff checks.
- [x] Launch Desktop debug app for owner review.
- [x] Record verification, copy/history impact, and archive this task.

## Verification

- `swiftc apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift -o /tmp/filmtone-film-damage-visual-probe && /tmp/filmtone-film-damage-visual-probe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-v21-host-bridge-c` passed with existing Core Image deprecation warnings.
- Visual sheet C: default remains subtle; dust-only no longer first-reads as white sparkle; scratch-only no longer first-reads as clean sinusoidal strokes; stress remains intentionally extreme and still shows the single-kernel bridge ceiling.
- `apps/filmtone-desktop-macos/Verify/run.sh` passed, 161/161.
- `bun run verify:desktop` passed with existing Core Image / AVFoundation deprecation warnings.
- `bun run verify:ios` passed with existing Core Image / AVFoundation deprecation warnings.
- `git diff --check` passed.
- `bun run check:filmtone-context` passed.
- Desktop debug app launched from `apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`; process observed as PID 92742.

## Copy / History Impact

- No copy/history impact: this changes native Film Damage rendering behavior only,
  with no public copy, release claim, App Store metadata, or implementation
  history wording changed.
- Article Opportunity: Release-note only. The user-facing story is improved Film
  Damage realism after owner review, not a standalone article yet.
- Change-History Opportunity: Developer note. The important implementation
  record is that visual-effect-core v2.1 bridgeable fields were mapped into the
  current single-`CIColorKernel` path, while sampler/multi-pass-only items remain
  deferred.

## Known Remaining Product Risks

- The single color-kernel bridge still cannot implement true source-coordinate
  gate weave or defocus source sampling.
- Stress sheets expose the remaining single-kernel ceiling; real footage owner
  review is still needed before calling the effect finished.

## Stop Conditions

- Done conditions met and app is launched for owner visual review.
- 2 targeted tuning passes still cannot improve A3 without sampler/multi-pass
  support; record the issue and propose the sampler phase.
- 3 consecutive verification failures on the same unresolved root cause.

## Unexpected Blockers

- None yet.
