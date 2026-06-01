# Film Damage Visual Target Report

Date: 2026-06-01 JST

Scope: Investigate why the current Film Damage pass still reads as low quality,
with special attention to white dust / sparkle dominance. This report supports
the active task in `active.md` and does not change the renderer.

## Evidence

Generated current-renderer comparison sheets:

- `artifacts/film-damage-visual-probe/film-damage-current-dark.png`
- `artifacts/film-damage-visual-probe/film-damage-current-midtone.png`
- `artifacts/film-damage-visual-probe/film-damage-current-bright.png`

Generation source:

- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`

The probe compiles against the production Desktop kernel file:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`

Cases:

- `none`: `dustAmount = 0`, `scratchAmount = 0`
- `default`: `dustAmount = 0.18`, `scratchAmount = 0.10`
- `strong`: `dustAmount = 0.34`, `scratchAmount = 0.28`
- `dust-only-strong`: `dustAmount = 0.80`, `scratchAmount = 0`
- `scratch-only-strong`: `dustAmount = 0`, `scratchAmount = 0.80`
- `stress`: `dustAmount = 1`, `scratchAmount = 1`

## Research Summary

White dust is not categorically wrong.

- AV Artifact Atlas defines sparkle as small white spots on a positive image,
  commonly due to tiny dust or dirt on the negative or internegative used to
  make the positive image:
  https://www.avartifactatlas.com/artifacts/sparkle.html
- Dehancer describes light and dark dust / hair / scratch artifacts as dependent
  on the stage of production, duplication, printing, scanning, and processing.
  It exposes a White-Black parameter because a positive image can contain both:
  https://www.dehancer.com/learn/articles/dehancer-film-damage

Implementation consequence:

- Filmtone should not eliminate white sparkle.
- Filmtone should not let white sparkle become the primary dust body for
  `Default` or normal `Strong`.
- A premium archival target needs a darker / neutral / translucent dirt bed,
  with white sparkle as a minority accent.

## Current Renderer Findings

1. Current Default and Strong are visually quiet on controlled plates.

   In the generated comparison sheets, `default` and `strong` do not create
   enough visible structure to read as a mature film-damage layer. This explains
   why the effect can feel underdeveloped even after the v2-inspired host port.

2. When Dust is raised, the primitive shape becomes the problem.

   `dust-only-strong` and `stress` reveal the actual failure mode: marks read as
   separate high-contrast dots. Even when mixed polarity exists, the dots do not
   form an integrated film-surface dirt bed.

3. White sparkle dominates perception despite not being the numeric majority.

   The Desktop kernel currently splits dust as:

   - `darkDust`: about 58 percent of dust events by hash threshold.
   - `lightDust`: about 42 percent of dust events by hash threshold.

   However, light dust blends toward a warm near-white target
   (`vec3(1.0, 0.96, 0.86)`), while dark dust only multiplies the existing
   image darker. On dark and mid-tone footage, the light component has much
   higher perceptual contrast, so the viewer remembers the white dots.

4. Scratch polarity is even more light-biased.

   Scratch target selection currently makes roughly 72 percent of scratch events
   light. This is defensible for some archival print damage, but it pushes the
   current result toward bright novelty scratches rather than controlled
   projector/gate character.

5. Scratches and fibers are still mathematically clean.

   The scratch-only comparison shows faint clean curves/lines. They are broken
   and deterministic, but they still lack the material irregularity of film
   transport damage: frayed edges, uneven density, pressure marks, partial
   smear, and gate-side accumulation.

6. Bright footage behaves differently from dark/mid footage.

   The current light-dust path has a highlight guard, so on bright plates the
   white specks are less visible and dark specks take over. On mid/dark plates,
   white specks pop immediately. Owner footage can therefore make the same
   algorithm feel very different depending on luma distribution.

## Diagnosis

The issue is not simply "white dust is wrong." The issue is that current white
dust is authored as isolated high-contrast sparkle without enough surrounding
film-material context.

Current weak points:

- White sparkle target is too close to pure white for a product-default taste.
- Dust has too little low-contrast dirt bed.
- Dust shapes are too circular and discrete.
- Stronger dust increases dot count before it increases material believability.
- Scratches are still too clean and too light-biased.
- Gate/projector identity is weaker than point-dust identity.
- Current CIColorKernel pass cannot perform real source-resampling gate weave,
  so all transport character is simulated as color marks.

## Target Hierarchy

Accepted product direction from the conversation:

- Default: subtle archival.
- Strong: projector gate damage.
- Distressed leader: out of scope for the default product path.

Practical hierarchy:

1. Footage remains the primary read.
2. Edge/gate dirt and subtle flicker provide the film-transport read.
3. Dark/neutral/translucent dirt forms the dust bed.
4. Scratches/fibers are occasional, broken, and temporally coherent.
5. White sparkle exists, but only as a rare accent.

## Recommended Next Implementation Pass

Start with a constrained CIColorKernel candidate because the biggest current
failure is polarity, texture, and hierarchy. Do not widen the UI contract yet.

Changes for the next candidate:

1. Rebalance dust polarity and contrast.
   - Default target: approximately 75-85 percent dark/neutral/translucent dirt,
     10-20 percent light sparkle, 5-10 percent warm stain/soft deposit.
   - Strong target: still keep light sparkle below the dirt/gate read.
   - Replace near-white blend with luma-aware additive sparkle that usually
     lands below pure white.

2. Split dust into two internal layers.
   - `dirtBed`: low-contrast, soft, mottled, mostly dark/gray/warm, longer
     lifetime.
   - `sparkle`: small, short-lived, sparse, high contrast, minority component.

3. Make dust shapes less analytic.
   - Break circular silhouettes with small value-noise contouring.
   - Add anisotropic smears and soft deposits.
   - Bias more activity toward edges and gate-adjacent regions.

4. Shift Strong toward projector/gate identity.
   - Increase edge wear and gate dirt before increasing full-frame dust.
   - Keep scratch/fiber events occasional but more materially irregular.
   - Reduce light scratch probability and add dark/neutral hair/fiber forms.

5. Add visual review artifacts to the next pass.
   - Generate the same three comparison sheets for candidate A.
   - Compare current vs candidate before launching the app.
   - Owner review should inspect the contact sheets first, then the live app.

Escalate beyond CIColorKernel only if candidate A still reads as overlay:

- Add a sampler/transform stage for gate weave, slight transport instability,
  and source smear.
- Consider moving more of the generic effect back into visual-effect-core only
  if the core recipe/algorithm is also missing the polarity/texture model.

## Acceptance Gate For Candidate A

Pass:

- Default no longer first-reads as white dots.
- Dust-up does not just mean "more bright specks."
- Strong reads more like edge/gate/projector handling than dirt overlay.
- Mid-tone and dark plates no longer make white sparkle dominate.
- Bright plates still retain some visible artifact behavior.
- Scratches are less clean, less uniformly light, and less line-like.

Reject:

- White dots remain the most memorable artifact.
- Reduced white sparkle makes the whole effect disappear.
- Strong looks like television noise or a distressed leader.
- The effect is only lower-opacity, not more material.
