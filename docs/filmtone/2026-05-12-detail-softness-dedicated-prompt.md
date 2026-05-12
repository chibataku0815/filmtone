# Detail Softness Dedicated Prompt

Date: 2026-05-12 JST
Purpose: prompt for starting a new chat dedicated to
`docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`.

Use this when the general handoff routes the next chat toward export audio but
the owner wants to start the Detail Softness / Source Detail Compensation lane.

## Prompt

```text
You are working in:

/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

Read AGENTS.md first, then run `git status --short --branch`. Do not begin with
broad repository discovery. Route directly to the Detail Softness task.

This chat is dedicated to:

docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md

Do not work on export audio in this chat. If the current branch is
`feature/export-audio-preservation` or contains unrelated export-audio changes,
do not implement Detail Softness on that branch. Create or move to a clean
Detail Softness branch/worktree from main before product-code edits, or ask the
owner for the branch/worktree action if that cannot be done safely.

Current repository context:

- The iOS feature-architecture refactor has already been merged into main.
- Use current post-refactor paths:
  - iOS export facade:
    `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - iOS export internals:
    `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/`
  - iOS shared grade processor:
    `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneSharedGradeProcessor.swift`
  - Native Desktop:
    `apps/filmtone-desktop-macos/`
  - Shared core:
    `packages/film-lab-core/`
  - Swift core:
    `packages/film-lab-swift-core/`
- Gyroflow is not part of this task.
- Export audio preservation is not part of this task.
- Product quality and core progress are the priority. Keep broad outer-shell
  work minimal.
- Use coherent implementation bundles, not tiny administrative sub-stages.

Goal:

Start the Detail Softness / Source Detail Compensation lane. The feature should
reduce hard digital fine detail and local acutance without making footage look
simply blurred. It must be distinct from `lensSoftness`, which is lens/periphery
softness.

Primary plan document:

docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md

Create lane docs if they do not already exist:

docs/filmtone/detail-softness/
├── strategy.md
├── active.md
└── archive/

The first active task should be Phase 1: Contract and Neutral Plumbing.

Phase 1 objective:

Add `detailSoftness` everywhere as a shared parameter with default `0`, without
changing visual output when unset or zero.

Required behavior:

- Add `detailSoftness` with range `0...1`.
- Default value must be `0`.
- Existing projects, Looks, presets, and patches must load unchanged.
- `detailSoftness: 0` must be neutral.
- Do not implement the visual render pass yet.
- Do not implement Source Detail Compensation yet.
- Do not expose new UI controls yet unless the owner explicitly expands scope.
- Do not overload or rename `lensSoftness`.
- Do not bake source compensation into saved Look identity.

Expected Phase 1 targets:

- `packages/film-lab-core/src/params.ts`
- `packages/film-lab-core/src/schema.ts`
- `packages/film-lab-core/src/phase0-schema.ts`
- `packages/film-lab-core/src/quick-semantics.ts`
- `packages/film-lab-core/src/ios-swift-payload.ts`
- relevant core tests such as schema / iOS payload / patch round-trip tests
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtonePhase0Params.swift`
- generated Swift payloads produced by the repo generator
- any Desktop or iOS param catalogs that must know the key to preserve decode,
  clamp, and sidecar behavior

Generated Swift rule:

Do not hand-edit generated Swift. Use the repo generator:

`bun run generate:ios-swift`

If the generator has a check mode, use it. Otherwise run it and inspect the
generated diff.

Decision to make during Phase 1:

Determine whether `detailSoftness` should be included in optical/Look patch
identity, for example in:

`packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtonePhase0ParamsPatch.swift`

Default decision unless code evidence suggests otherwise:

- Include user-authored `detailSoftness` wherever normal user grade params are
  stored or round-tripped.
- Do not include future automatic `sourceDetailBias` in saved Looks.
- If the existing optical recipe merge model requires optical keys to preserve
  creative intent, include `detailSoftness` as a user optical key, but document
  the reason in the lane doc.

Future phases, not for Phase 1 implementation:

Phase 2: real render pass.
- Placement target: after input LUT/base grade/tone compression, before edge
  optics, glow family, vignette, grain, creative LUT, and print.
- Do not implement as plain Gaussian blur.
- Use local-reference/high-frequency-detail reduction with major-edge
  protection, stronger luma than chroma attenuation, and grain applied after it.

Phase 3: UI exposure and recipe tuning.
- Add Advanced control only after the contract and render pass are stable.
- Copy must go through the copy harness.

Phase 4: Source Detail Compensation.
- Add a conservative source profile resolver.
- Keep automatic source bias separate from saved Look identity.
- Use metadata such as camera make/model, lens model, log transfer function,
  input transform policy, and codec family.

Phase 5: visual tuning matrix.
- Test iPhone SDR HEVC, iPhone Apple Log/ProRes, DJI/action Rec.709,
  Sony/Canon/Panasonic Log, low-light noisy footage, hair/foliage/brick/text,
  and strong practical lights.

Verification for Phase 1:

- `bun run build:core`
- `bun run generate:ios-swift` and inspect the generated diff, or use generator
  check mode if available
- `bun run verify:ios` if Swift payload or iOS generated payload changes
- `bun run verify:macos` if Native Desktop Swift model/catalog changes
- `git diff --check`

Run broader visual/render verification only after Phase 2 introduces the render
effect. Do not create a broad QA matrix for Phase 1 unless the contract change
breaks existing behavior.

Stop conditions:

- `detailSoftness: 0` changes existing output or serialized defaults.
- Existing projects, Looks, presets, or patch decoding break.
- The implementation requires hand-editing generated Swift.
- The work starts pulling in render algorithm, UI copy, or source compensation
  before Phase 1 is complete.
- You discover multiple incompatible storage models for user params vs source
  compensation. Stop, document the options, and ask the owner.

Expected output for this chat:

1. Create or update `docs/filmtone/detail-softness/strategy.md`.
2. Create `docs/filmtone/detail-softness/active.md` for Phase 1.
3. If the owner has asked you to implement, complete Phase 1 in the same chat
   after the active doc exists.
4. Keep the final report focused:
   - what changed
   - exact files changed
   - verification run
   - whether `detailSoftness: 0` remains neutral
   - remaining risks / next phase

Do not push, bump portfolio submodules, or edit portfolio implementation unless
the owner explicitly asks. Work with any dirty worktree changes; do not revert
changes you did not make.
```
