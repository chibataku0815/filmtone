# Native Desktop v2 Active Task: Film Damage Visual Target Alignment

Milestone: M3 / M4 Native Color And Optics Parity

Goal: Establish a shared visual target and evidence-backed implementation plan
for Film Damage before changing the renderer again. The immediate problem is
not only implementation correctness; owner review found the effect still looks
low quality, with white dust drawing too much attention.

User finding:
- Current Desktop visual review still reads as low quality.
- White dust / sparkle dominates the effect.
- The preferred direction is broadly `subtle archival` plus `projector gate
  damage`, not distressed leader damage as the default product taste.

## Interpretation

Source intent:
- Film Damage should read as damage from film material, printing, scanning, and
  projection handling, not as a generic digital overlay.
- The product should feel premium and editorial. Damage may be visible, but it
  should not become the first read unless the user intentionally pushes it.

Known facts:
- Existing product controls remain `dustAmount` and `scratchAmount`.
- Current Desktop and iPad ports map those two controls into procedural dust,
  stains, flicker, gate wear, scratches, and fiber-like marks.
- Current default recipes are conservative: Default uses `dustAmount = 0.18`
  and `scratchAmount = 0.10`; Strong uses `0.34` and `0.28`.
- Research supports both light and dark artifacts. White sparkle can be
  legitimate, especially from dust or dirt in negative / internegative workflows,
  but positive images may contain both light and dark artifacts depending on
  shooting, printing, scanning, and processing stages.

Assumptions:
- Filmtone Default should lean toward dark / neutral / translucent dirt with
  white sparkle only as a restrained accent.
- Filmtone Strong should lean toward projector / gate damage: edge dirt, gate
  wear, running scratches, occasional hair/fiber, subtle exposure instability.
- Heavy distressed leader damage is out of product-default scope until the
  owner explicitly asks for a more destructive effect.

Risks:
- A direct numeric tuning pass can make the effect louder without making it
  more authentic.
- A two-slider UI can hide too many algorithmic choices, making both presets
  ambiguous.
- CoreImage color kernels cannot fully reproduce gate weave via source
  resampling; exact visual-effect-core v2 parity may require a sampler kernel
  or a separate transform stage.

Reference decomposition:
- Preserve:
  - Mixed light/dark dust polarity.
  - Sparse white sparkle as a real but secondary artifact.
  - Edge-biased gate dirt and wear.
  - Long-lived scratches and fibers that feel attached to film transport.
  - Temporal continuity: marks should appear, persist, fade, or drift; they
    should not feel like independent TV noise.
- Why it works:
  - Film-origin damage reads as a layered process. Different artifacts come
    from different physical stages and therefore differ in polarity, softness,
    scale, persistence, and edge bias.
- Ignore:
  - Uniform white random dots.
  - Full-frame equal-density dirt.
  - Perfect circles and clean sinusoidal scratches as the final appearance.
  - Distressed leader intensity for the normal Default / Strong product path.
- Operationalize as:
  - Add an explicit internal polarity model even if the UI stays two-slider.
  - Make white sparkle a minority component, not the main dust body.
  - Promote edge/gate behavior and translucent dirt over isolated white dots.
  - Decide whether the next implementation can stay in `CIColorKernel` or needs
    a sampler / transform stage for gate weave and smear.

## Visual Spec

Intent:
- Default: a premium archival texture. The viewer notices the footage first,
  then sees film-origin imperfections on second read.
- Strong: a visible but still tasteful projector/gate character. The damage
  should be readable at playback speed without looking like a novelty filter.

Motion / temporal thesis:
- Damage should feel carried by film transport: some artifacts stay attached to
  the strip for multiple frames, while brief dust and sparkle enter and leave
  with restrained irregularity.

Signature law:
- White sparkle is a glint, not the dirt bed. The dirt bed is mostly dark,
  gray, warm-brown, translucent, edge-biased, or softly stained.

Focal hierarchy:
- Primary:
  - The graded footage.
- Secondary:
  - Edge/gate wear, subtle flicker, occasional scratch/fiber.
- Accent:
  - Small white sparkle, rare brighter dust, brief tiny specks.
- Ambient:
  - Translucent stains, low-contrast dirt, softened edge deposits.

Motif vocabulary:
- Allowed artifact families:
  - Tiny dust specks with mixed polarity and nonuniform opacity.
  - Soft translucent stains and dirt smears.
  - Gate-edge dirt and chipped/worn borders.
  - Thin scratches and fibers with finite lifetime, broken length, and slight
    transport wobble.
  - Very subtle exposure flicker.
- Value hierarchy:
  - Dark/neutral dirt should dominate count.
  - White sparkle should dominate only a few pixels and a few moments.
  - Large white blobs are rejected unless the chosen target becomes distressed
    leader.

Negative constraints:
- Do not make white dots the most memorable part of Default.
- Do not use equal-size, equal-opacity specks.
- Do not use clean, full-height vertical lines as the primary scratch form.
- Do not add more simultaneous artifact types to compensate for weak taste.
- Do not widen the UI contract until the internal target is accepted.

Blandness risks:
- A technically varied procedural overlay can still look cheap if the marks are
  mathematically clean.
- Low opacity alone can make the effect weak, not premium.
- Stronger values can make the same wrong shape more obvious.

## Investigation Plan

1. Audit current renderer behavior.
   - Confirm Desktop and iPad use identical Film Damage semantics.
   - Quantify current light/dark dust ratio from the kernel.
   - Inspect whether white sparkle is visually dominant because of polarity,
     opacity, blend target, or recipe density.
   - Identify which visible artifacts are coming from `Dust` and which are
     coming from `Scratches`.

2. Build visual evidence.
   - Produce controlled comparison frames for:
     - No Film Damage
     - Current Default
     - Current Strong
     - Dust-only strong
     - Scratch-only strong
     - White-suppressed candidate
     - Gate/projector candidate
   - Use at least one mid-tone frame, one dark frame, and one bright/sky-like
     frame so dust polarity can be judged honestly.
   - Prefer local generated fixtures if real owner footage is not available in
     the repo.

3. Define target presets before implementation.
   - Default target:
     - `subtle archival`
     - mostly dark/neutral/translucent dust
     - rare white sparkle
     - no obvious novelty scratches
   - Strong target:
     - `projector gate damage`
     - edge dirt / gate wear visibly stronger
     - occasional scratches/fibers
     - white sparkle still restrained
   - Out-of-scope target:
     - `distressed leader`
     - heavy white snow, large burn marks, torn frames, aggressive dirt.

4. Decide implementation surface.
   - First choice:
     - Tune the existing Desktop/iPad CoreImage kernels only if evidence shows
       the target can be met by polarity, opacity, density, softness, and edge
       bias changes.
   - Escalate to sampler / transform work if:
     - Gate weave, source smear, or transport instability is necessary for the
       accepted target.
     - White dust suppression alone still leaves the result looking like an
       overlay.
   - Escalate back to visual-effect-core if:
     - The generic v2 algorithm itself lacks the polarity/texture model needed
       for the target, not just the Filmtone host port.

5. Implement only after the target is accepted.
   - Keep existing public controls and sidecar shape unless the investigation
     proves the two-slider model cannot express the accepted target.
   - Apply Desktop and iPad changes together.
   - Add at least one runtime smoke that catches kernel compile/apply failure.
   - Add visual/debug fixtures only if they materially improve review quality.

## Implementation Surface Decision

Chosen lane:
- design/spec discussion now; renderer implementation later.

Recommended execution surface:
- Current `active.md` for target alignment and investigation.
- Desktop/iPad CoreImage renderer files only after owner accepts the visual
  target.
- Optional generated visual fixtures under the Desktop verification surface if
  the investigation needs stable before/after frames.

Why this stays isolated:
- The issue is product taste and artifact modeling, not a failing build or
  schema mismatch.
- A blind code change would likely produce another pass that is merely louder.

Promotion trigger:
- Promote to implementation when the owner accepts the target hierarchy:
  `Default = subtle archival`, `Strong = projector gate damage`, and white
  sparkle is only an accent.

## Acceptance Criteria

Pass if:
- Default does not first-read as white dots.
- Strong reads as projector/gate character, not a random dirt overlay.
- Dust has mixed polarity and varied opacity, size, softness, and lifetime.
- White sparkle exists but is a minority accent.
- Scratches are broken, temporally coherent, edge/gate-biased where appropriate,
  and not clean full-height vertical lines.
- The effect remains deterministic for a given source seed and time.
- Desktop and iPad behavior remain aligned.

Reject if:
- White dust remains the most visible artifact in normal Default use.
- Turning up Dust only creates more white dots.
- Turning up Scratches only creates more vertical lines.
- Still frames look like procedural circles and mathematical curves.
- The result feels like a novelty filter before it feels like film-origin
  material damage.

## Checklist

- [x] Confirm no competing `active.md` exists and keep this as the only active
      task.
- [x] Audit current Desktop/iPad film damage renderer and recipe mapping.
- [x] Summarize white-vs-dark dust research with implementation consequences.
- [x] Produce or define controlled visual comparison evidence.
- [x] Decide whether the next pass can stay in `CIColorKernel`.
- [x] Present target hierarchy and implementation recommendation for owner
      review before renderer edits.

## Verification

- `swiftc apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift -o /tmp/filmtone-film-damage-visual-probe && /tmp/filmtone-film-damage-visual-probe docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-visual-probe`
  -> generated current renderer comparison sheets.
- Required before closing:
  - `git diff --check` -> pass.
  - `bun run check:filmtone-context` -> pass.
- Renderer/app verification is deferred because this task did not change the
  production renderer.

## Stop Conditions

- Stop when the target hierarchy and next implementation surface are ready for
  owner review.
- Stop if real footage or owner-selected references are required to resolve the
  target and cannot be inferred from local evidence.
- Stop after 3 consecutive attempts to define visual criteria still leave the
  owner's target ambiguous.

## Out Of Scope

- Renderer edits before target approval.
- Adding new public controls for every visual-effect-core v2 field.
- Public release packaging/upload.
- Legacy Electron Desktop.
- Distressed leader mode as the default product taste.

## Unexpected Blockers

- None yet.

## Findings

- White sparkle is historically valid in some positive-image workflows, but it
  should be a minority accent for Filmtone's product taste.
- Current dust nominally emits more dark events than light events, but light
  events blend toward near-white and therefore dominate perception on dark and
  mid-tone footage.
- Current Default / Strong are quiet on controlled plates; when Dust is raised,
  the failure mode becomes obvious isolated dots rather than a film-material
  dirt bed.
- The next candidate can start in `CIColorKernel` because the immediate failure
  is polarity, contrast, texture, and hierarchy. Escalate to a sampler/transform
  stage only if a white-suppressed, dirt-bed candidate still reads as overlay.

Detailed report:
- `docs/filmtone/desktop/native-desktop-v2/film-damage-visual-target-report.md`

Generated visual evidence:
- `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-visual-probe/film-damage-current-dark.png`
- `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-visual-probe/film-damage-current-midtone.png`
- `docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-visual-probe/film-damage-current-bright.png`

Copy / History Impact:
- No copy/history impact yet: this is a planning and target-alignment task. It
  does not change public copy, release claims, platform claims, App Store state,
  codec/export claims, or implementation-history claims.

Article Opportunity:
- No story. This is not publishable until the visual target is accepted and the
  implementation reaches a demonstrably better result.

Change-History Opportunity:
- Developer note only if the next pass changes the implementation strategy, such
  as moving from color-kernel overlay to sampler/transform-stage film transport
  modeling.
