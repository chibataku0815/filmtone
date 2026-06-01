# Native Desktop v2 Active Task: Film Damage v2 Host Port

Milestone: M3 / M4 Native Color And Optics Parity

Goal: Port the visual-effect-core FilmDamage v2 semantics into Filmtone's
native Desktop and iPad renderers so the existing Film Damage controls are
visibly higher quality and ready for owner visual review.

Edit targets:
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- Verification harness files only if needed
- This active task doc

Read-only references:
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/docs/bridge-verification/film-damage-gpu-parity.md`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/packages/visual-render-core/src/features/film-damage/reference.ts`
- `packages/film-lab-core/src/phase0-schema.ts`
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtonePhase0Params.swift`

Checklist:
- [x] Confirm current Filmtone film damage host wiring.
- [x] Replace simple point/line kernels with v2-inspired native channels.
- [x] Keep the existing `dustAmount` / `scratchAmount` product controls and
      sidecar shape.
- [x] Verify Desktop build.
- [x] Verify iOS build/contract path.
- [x] Launch Desktop debug app for visual review.
- [x] Record verification and archive this task.

Verification:
- `apps/filmtone-desktop-macos/Verify/run.sh` -> 161/161 pass, including
  `filmDamage kernel compiles and renders through CoreImage`.
- `bun run verify:desktop` -> pass.
- `bun run verify:ios` -> pass.
- `bun run check:filmtone-context` -> pass.
- `git diff --check` -> pass.
- Launched
  `apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app` for
  owner visual review.

Done conditions:
- Desktop preview/export and iPad export use richer film damage marks from the
  existing Film Damage controls.
- `Dust` drives varied dust/stain/flicker/gate-edge wear behavior.
- `Scratches` drives broken scratches/fiber-like marks with varied width,
  breakup, waviness, and temporal behavior.
- Existing Phase0 payload shape remains compatible.
- Verification passes or any blocker is recorded.

Stop conditions:
- Done conditions met.
- A host-native CoreImage limitation prevents a visible v2-style improvement
  without a larger renderer rewrite.
- 3 consecutive verification failures on the same unresolved root cause.

Out of scope:
- Adding new user-facing controls for every visual-effect-core v2 field.
- Importing visual-effect-core runtime into Swift apps.
- Public release packaging/upload.
- Legacy Electron Desktop.

Unexpected blockers:
- CoreImage kernel language treats `active` as an invalid identifier in this
  context. Renamed the local event-presence variable and added a runtime smoke
  so the kernel cannot silently compile to nil.

Copy / History Impact:
- No copy/history impact: this is an internal renderer quality change using the
  existing Film Damage / Dust / Scratches product controls and existing payload
  shape. It does not make release, platform, App Store, privacy, codec, or
  implementation-history claims.

Article Opportunity:
- Release-note only. The visible quality improvement is product-facing, but no
  public narrative is ready until owner visual review accepts the result.

Change-History Opportunity:
- Developer note. The source-of-truth path changed from generic
  visual-effect-core v2 contract to host-native CoreImage port while keeping
  Filmtone UI and payload stable.

Known Remaining Product Risks:
- Owner visual taste review is still pending on real footage.
- Host-native CoreImage cannot do full source-resampling gate weave inside this
  color-kernel slice, so this port simulates v2-style marks, flicker, and gate
  wear without exact visual-effect-core gateWeave sampling parity.
