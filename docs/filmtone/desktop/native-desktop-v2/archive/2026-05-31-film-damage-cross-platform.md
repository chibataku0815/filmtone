# Native Desktop v2 Active Task: Film Damage Cross-Platform Interrupt

Milestone: Interrupt

Goal: Add a Film Damage effect to native Desktop and iPad, based on the generic
`visual-effect-core` FilmDamageRecipe contract while keeping Filmtone product
taste and UI wiring in this repository.

Edit targets:
- `packages/film-lab-core/`
- `packages/film-lab-swift-core/`
- `apps/filmtone-desktop-macos/`
- `apps/capacitor-film-lab-ios/`
- Native Desktop / iOS docs only as needed for state tracking

Read-only references:
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/packages/visual-effect-core/src/features/film-damage/`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/packages/visual-render-core/src/features/film-damage/`
- Current Filmtone grain / Film Breath / optics parameter paths

Checklist:
- [x] Map the generic FilmDamageRecipe shape to Filmtone core params without
  importing generic-package runtime code.
- [x] Add shared Swift/native effect math for dust and scratches where the
  existing render/export paths can consume it; keep flicker on the existing
  Film Breath control and defer gate weave until a shared product param exists.
- [x] Add native Desktop UI controls and preview/export application.
- [x] Add iPad/iOS UI controls and preview/export application.
- [x] Add focused parity/unit coverage for the shared math and affected app
  surfaces.
- [x] Run the smallest verification that proves Desktop and iPad behavior.
- [x] Record Copy / History Impact, Article Opportunity, and Change-History
  Opportunity.

Verification:
- `bun test packages/film-lab-core/src/phase0-schema.test.ts packages/film-lab-core/src/ios-swift-payload.test.ts packages/film-lab-core/src/ios-phase0.test.ts` — passed.
- `swift test --package-path packages/film-lab-swift-core` — passed.
- `bun run build:core` — passed.
- `bun run verify:desktop` — passed.
- `bun run verify:ios` — passed after updating the iOS Swift contract support DTO.
- `bun run check:filmtone-copy` — passed.
- `bun run check:filmtone-context` — passed.
- `git diff --check` — passed.

Copy / History Impact:
- UI copy added for the new Advanced Adjust group and two controls only:
  `Film Damage`, `Dust`, `Scratches`, and concise iOS help copy. No public
  release, version, App Store, privacy, platform, or export-capability claim was
  changed.
- Article Opportunity: Release-note only once the feature is included in a
  shipped Desktop/iPad build.
- Change-History Opportunity: Developer note. The implementation connects the
  dormant `dustAmount` / `scratchAmount` shared params and the generic
  `visual-effect-core` FilmDamageRecipe concept to native Desktop/iPad render
  paths without importing the generic package runtime.

Done conditions:
- Desktop and iPad expose a user-controllable Film Damage effect.
- Still/video preview and export apply the same deterministic effect model.
- Existing presets remain neutral unless explicitly changed.
- Verification for shared core, Desktop, and iOS passes or any remaining gap is
  explicitly documented with a product risk.

Stop conditions:
- Done conditions met.
- The current dirty worktree overlaps the required effect surfaces in a way that
  would require reverting user changes.
- 3 consecutive verification failures on the same unresolved root cause.

Out of scope:
- Public release packaging/upload.
- Portfolio submodule bump.
- Pixel-perfect parity with `visual-effect-core` CPU reference.
- Legacy Electron Desktop.

Unexpected blockers:
- None yet.
