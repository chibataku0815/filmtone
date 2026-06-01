# Film Damage Fast Easing And Soft Blur Follow-Up

Date opened: 2026-06-01 JST
Milestone: M3 Native Color And Optics Parity

## Goal

Tune Film Damage timing toward the reference observation: damage should enter
and leave with fast easing, while keeping a slight blurred / unstable material
feel instead of hard mechanical frame pops.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-01-film-damage-v3-plate-material-proof.md`
- `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-visual-probe-v3-proof/`

## Checklist

- [x] Shorten Film Damage event fade-in / fade-out without reverting to one-frame popping.
- [x] Add a softer fade-edge blur/smear feel for dust, dirt, scratches, and fibers.
- [x] Keep Desktop and iOS kernels behaviorally aligned.
- [x] Generate visual probe output for timing inspection.
- [x] Run verification.
- [x] Record results and archive this task.

## Results

- `damageHeldVisibility` now reaches held visibility faster, so events do not
  spend most of their life in a weak ramp.
- Dust/dirt/stain events use shorter fade windows and transition-edge softness
  plus slightly stronger drift during in/out.
- Scratch/fiber events use shorter fade windows, transition-edge width lift, and
  a small deterministic smear during in/out to reduce rigid mechanical pops.
- Desktop and iOS kernel changes were kept aligned.
- Visual probe output:
  `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-fast-easing-proof/`

## Known Remaining Product Risk

- This remains a single-sample `CIColorKernel` approximation. True optical blur,
  plate defocus, or texture-material motion should move to a sampler kernel /
  plate compositor rather than adding more procedural tuning here.

## Copy / History Impact

No copy/history impact: internal Film Damage timing and material behavior changed
without public copy, release, platform, export, privacy, or implementation-history
claims.

Article Opportunity: No story.

Change-History Opportunity: Developer note only if a future Film Damage material
model write-up explains why this CIColorKernel approximation preceded a real
plate/sampler compositor.

## Verification

- `xcrun swiftc apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift -framework AppKit -framework CoreImage -o /tmp/FilmDamageVisualProbe && /tmp/FilmDamageVisualProbe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-fast-easing-proof` - passed
- `apps/filmtone-desktop-macos/Verify/run.sh` - passed, 161/161
- `bun run verify:desktop` - passed
- `bun run verify:ios` - passed
- `git diff --check` - passed
- `bun run check:filmtone-context` - passed

## Done Conditions

- Damage in/out easing is visibly faster than the v3 proof.
- Persistent events still avoid rigid one-frame mechanical popping.
- Dust and scratches have slightly softer/blurred edges around transition.
- Existing Desktop and iOS verification passes.

## Stop Conditions

- Done conditions are met and verification is recorded.
- A true sample blur / texture plate compositor is required; that is out of
  scope for this follow-up.
- The same verification class fails 3 consecutive times.

## Out Of Scope

- Public schema changes.
- New visible UI controls.
- Real texture plate assets.
- Moving Film Damage to a multi-sampler CIKernel blur compositor.

## Unexpected

True sample blur / plate defocus is outside the current kernel architecture, so
this pass intentionally uses transition-edge softness, width lift, and
deterministic smear as the bounded approximation.
