# Filmtone Halo Prism Filter Handoff - 2026-05-01 JST

## Purpose

This document preserves the full context for a new chat whose sole task is to
plan implementation of a Filmtone Halo lens-filter effect.

The user wants to focus on the Halo-like lens filter effect shown in the
attached references, then open a new chat to create the implementation plan.
This handoff should let the next chat begin without rediscovering the same
context.

No implementation was performed in this chat. This is a research and handoff
artifact only.

## User Direction To Preserve

- Focus only on Halo for the next chat.
- Prioritize core product quality over conservative general advice.
- Keep outer-shell work minimal until the core result is good.
- Use sequential-thinking for real design branches, architecture choices,
  release-lane decisions, product-quality tradeoffs, or ambiguous plans.
- If a material question cannot be answered from local files or the current
  handoff, search with Gemini if available or web search before asking the
  user.
- When multiple independent reads/checks are needed, run them in parallel.
- Do not stage, commit, push, or bump the portfolio submodule unless explicitly
  asked.
- This is a Filmtone repo task, not a portfolio implementation task.

## Repository State At Handoff

Repo:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

The working tree was already dirty before this handoff document was created.
Do not revert unrelated changes. At the time of the document write, notable
pre-existing dirty areas included iOS Swift/App project files, generated/core
dist files, and several new creative LUT/core files. The Halo handoff document
is the only intended change from this chat.

No release/version truth scripts were run because this chat did not state a
Desktop/iOS latest version, next version, public App Store state, or release
scope. If the next chat starts making release/version claims, it must run:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

## Original Reference Images

The user attached two CleanShot images:

```text
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_3GUn3huxWQ/CleanShot 2026-05-01 at 12.47.09@2x.png
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_DtLJuGR1Gn/CleanShot 2026-05-01 at 12.47.26@2x.png
```

Image 1 characteristics:

- Bright daylight water/ground speculars.
- Hand and lemon near the center.
- Strong white glow and bloom around local specular highlights.
- Sparkling water points, soft highlight diffusion, mild film texture.
- No large geometric arc. This is mostly diffusion, bloom, halation, grain,
  highlight rolloff, and lens softness.

Image 2 characteristics:

- Night/dusk scene with a dark silhouette and streetlights.
- Large rainbow-tinted circular arcs crossing the lower half of the frame.
- Multiple partial rings/semicircles with cyan/red chromatic edges.
- Center subject remains readable while outer-field optical distortion/glow
  appears strong.
- The effect is not just straight cross-filter streaks. It is closer to a
  Halo/Split Halo prism or front-element refraction artifact.

## Research Summary

Web search was used because the exact physical filter family was not certain
from local files alone.

Useful external references:

- Prism Lens FX Halo FX Filter:
  `https://prismlensfx.com/collections/filters/products/halo-fx-filter-2`
- Prism Lens FX Split Halo FX Filter:
  `https://prismlensfx.com/products/split-halo-fx-filter-1`
- Tiffen Black Pro-Mist:
  `https://tiffen.com/products/black-pro-mist-filter`
- CineStill CineBloom:
  `https://cinestillfilm.com/products/cinebloom-diffusion-filters`

Interpretation:

- Image 1 is best described as diffusion / Pro-Mist / CineBloom-like highlight
  bloom and soft halation. Filmtone already has most of this stack.
- Image 2 is best described as Halo Prism / Split Halo style refraction. It
  has circular/annular geometry, chromatic edges, and light-reactive arcs.
- The desired feature should not be called just "Rainbow Flare" or merged into
  the existing Cross Filter concept. "Halo Prism", "Prism Ring", or "Halo"
  is more accurate.

## Current Codebase Findings

The relevant implementation surface is primarily the renderer, then shared
params/UI once the look is proven.

Renderer package:

```text
packages/film-lab-renderer/
```

Core parameter package:

```text
packages/film-lab-core/
```

Shared UI package:

```text
packages/film-lab-ui/
```

Relevant files and why they matter:

- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`
  - Main WebGPU render graph.
  - Current order is effectively:
    `filmlab -> bloom/halation/diffusion -> composite -> cross filter -> light shafts -> motion blur/present`.
  - A Halo pass should probably run after composite and before motion blur,
    near the existing post chain.
- `packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts`
  - Existing bloom/halation/diffusion/lens softness/grain composition.
  - Good reference for screen-blend glow shoulder and center/detail protection.
- `packages/film-lab-renderer/src/webgpu/shaders/cross-filter-source.frag.wgsl.ts`
  - Existing compact highlight extraction.
  - Useful input logic for Halo. It suppresses broad white regions and keeps
    compact point/specular highlights.
- `packages/film-lab-renderer/src/webgpu/shaders/cross-filter-streak.frag.wgsl.ts`
  - Existing straight streak march.
  - Do not reuse the straight streak output for Halo, but study its chromatic
    dispersion and source weighting.
- `packages/film-lab-renderer/src/webgpu/shaders/lightshafts.frag.wgsl.ts`
  - Existing radial sampling pattern. Useful as a reference for post-composite
    additive light effects, not the desired geometry.
- `packages/film-lab-core/src/params.ts`
  - Single source for shared numeric params.
  - Existing relevant params include bloom, halation, diffusion, rgbShift,
    lensSoftness, shaft, and crossFilter fields.
- `packages/film-lab-core/src/optical-recommendation.ts`
  - Current optical families are `mist`, `glow`, `cross`, `lens`.
  - Halo may become a new family or a sub-mode under lens/cross. Quality-wise,
    a distinct family looks cleaner once shader proof exists.
- `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx`
  - Current Finish Tools section already has Mist, Glow, Cross, Texture, Lens,
    and Motion.
  - A Halo control can fit near Lens or between Glow and Cross after the shader
    is proven.

## Current Capability Versus Target

Already close for Image 1:

- `diffusion`
- `bloomStrength`, `bloomThreshold`, `bloomRadius`
- `halationIntensity`, `halationSpread`, `halationHue`, `halationRadius`
- `grainIntensity`, `grainSize`, `grainRadialMix`
- `lensSoftness`

Not sufficient for Image 2:

- Existing Cross Filter creates straight star/cross streaks from compact lights.
- Existing Light Shafts creates radial rays from an origin.
- Existing rgbShift/lensSoftness only creates subtle edge softness/chromatic
  behavior.
- None of the existing effects creates large circular, multi-arc, halo-prism
  refractions that react to highlights.

Conclusion:

- A dedicated Halo Prism pass is required for product-quality Image 2 behavior.
- The best reuse point is highlight extraction and post-chain infrastructure,
  not the existing cross-filter streak shader itself.

## Product-Quality Target

The Halo effect should meet these criteria:

1. Light-reactive
   - It should respond to point lights/specular highlights.
   - It should not look like a fixed PNG overlay.

2. Circular/annular geometry
   - It should generate partial rings or large arcs, especially lower-frame
     semicircles similar to the second reference.
   - Multiple arcs should be possible, but they should not become decorative
     clutter.

3. Chromatic edges
   - Cyan/red/blue edge separation is essential.
   - The core of the arc can be warm/white, but the rim should show dispersion.

4. Center protection
   - Faces, hands, silhouettes, and the central subject should remain readable.
   - The effect should bias toward outer field and strong highlight sources.

5. Video stability
   - Avoid per-frame random jitter that makes export flicker.
   - If procedural randomness is used, it should be deterministic from source
     coordinates or slowly varying time.

6. Product taste
   - The default should be beautiful before it is dramatic.
   - A stronger "Hard" or "Showcase" starter state can exist later, but the
     base implementation should feel optical rather than graphic.

## Recommended Architecture

Recommended next implementation direction:

1. Add a WebGPU-only proof first.
   - Do not start by building UI.
   - Do not start by solving iOS/WebGL parity.
   - Prove the image quality in the active Desktop/WebGPU path.

2. Introduce a dedicated Halo Prism shader pass.
   - Candidate shader name:
     `halo-prism.frag.wgsl.ts`
   - Candidate pipeline label:
     `halo.prism`
   - Candidate runtime texture:
     `rt.haloPrism`
   - Candidate placement:
     after `renderCrossFilter(...)` or integrated into the post chain before
     light shafts and motion blur.

3. Reuse compact highlight extraction as the light source.
   - The existing cross-filter compact source path is a good starting point.
   - Avoid broad bright areas causing full-frame rings.

4. Generate arcs procedurally.
   - For each pixel, evaluate distance to one or more ring centers/radii.
   - Modulate by highlight energy and field/ray-angle mask.
   - Use a center protection mask.
   - Use RGB channel offsets or wavelength tint to create chromatic rims.

5. Blend with scene using a controlled optical shoulder.
   - Reuse the `glowShoulder` / screen-blend style from composite, or a similar
     soft additive shoulder.
   - Avoid clipping to flat white.

6. Only after proof, add shared params.
   - Candidate params:
     - `haloStrength`
     - `haloRadius`
     - `haloWidth`
     - `haloChromatic`
     - `haloThreshold`
     - `haloSourceMix` or `haloLightReactivity`
     - `haloSplit`
     - `haloAngle`
     - `haloCenterX`
     - `haloCenterY`
     - `haloRandomness` only if deterministic and tasteful
   - Keep the first implementation smaller if needed:
     strength, radius, width, chromatic, threshold, split.

7. Then wire UI.
   - Add a new Finish Tools family only if it earns its own control surface.
   - Otherwise add under Lens as a "Halo" subtool.
   - Suggested user-facing name: `Halo Prism`.

## Implementation Design Notes For Next Chat

Potential shader approach:

- Input:
  - post-composite or color-graded source texture
  - compact highlight mask/source texture
  - depth texture if already available, optional
  - params uniform
  - sampler

- For each output pixel:
  - Convert UV to centered field coordinates with aspect correction.
  - Compute several arc masks:
    - base ring radius
    - secondary ring offset
    - split arc mask, e.g. only one side or lower half depending on angle
    - edge fade near center to protect subject
  - Sample source/compact highlight energy along transformed/reflected UV or
    use a global/low-res source proxy.
  - Apply chromatic dispersion:
    - Slightly different radii for R/G/B, or
    - separate ring masks per channel, or
    - spectral tint function like the cross-filter shader.
  - Blend result back into the post-composite texture.

Important quality choice:

- Avoid a purely screen-space fixed ring with no source coupling. It may look
  good in a still but will fail as a product feature on arbitrary footage.
- The ring should be strengthened by real highlights and suppressed when the
  frame has no bright sources.

Possible MVP:

- One pass that samples the current composited scene and compact highlight
  source.
- One or two procedural rings.
- Params hardcoded in WebGPU backend for proof.
- No UI yet.
- A debug/dev toggle can be temporary, but avoid committing a hidden permanent
  behavior without params.

Possible v1 after proof:

- Core params and preset starter.
- UI controls under Finish Tools.
- Desktop export parity verification.
- WebGL/iOS parity decision.

## Non-Goals For The Next Chat

- Do not solve public website/portfolio work.
- Do not update portfolio `vendor/filmtone`.
- Do not start broad release/version work.
- Do not turn this into a generic effect taxonomy project.
- Do not implement a static overlay asset as the main solution.
- Do not begin with iOS native parity. Keep the core Desktop/WebGPU proof first.

## Open Product Questions

These should be answered during implementation planning, preferably by local
prototype evidence rather than abstract debate:

1. Should Halo be a new optical family or a Lens subtool?
   - My recommendation: shader proof first, then decide. If the effect is
     visually prominent like Image 2, it deserves its own `Halo Prism` family.

2. Should the first release support automatic source-reactive positioning?
   - Recommendation: yes, at least source-reactive intensity. Fully automatic
     ring center can wait if it risks instability.

3. Should center/ring position be user-adjustable?
   - Recommendation: not in the first proof. Use a tasteful default and expose
     only after seeing real footage behavior.

4. Should this integrate with existing Cross Filter compact source?
   - Recommendation: yes for source extraction, no for output geometry.

## Suggested Verification Path

Smallest meaningful verification after implementation begins:

```bash
bun run build:renderer
git diff --check
```

If shared params/core are changed:

```bash
bun run build:core
bun run build:renderer
```

If Desktop UI/export behavior is changed:

```bash
bun run verify:desktop
```

If iOS shared payload/schema is touched:

```bash
bun run verify:ios
```

Do not run broad QA before the visual core is good, unless the user explicitly
asks for QA or release preparation.

## Highest-Precision Next-Chat Prompt

Paste the following into the next chat:

```text
We are in:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

Read AGENTS.md, run git status --short --branch, then open this handoff:
docs/filmtone/filmtone-halo-prism-filter-handoff-2026-05-01-jst.md

Task:
Plan the implementation of a new Filmtone Halo Prism lens-filter effect,
focused only on the Halo/circular prism effect from the reference images.
Do not implement yet unless I explicitly ask after the plan. I want a precise,
product-quality-first implementation plan that can then be executed.

Product direction:
- Core product quality is the priority.
- Keep outer-shell work minimal until the core visual result is good.
- Do not give conservative generic advice first.
- Think through real design branches with sequential-thinking.
- If local files and this handoff do not answer a material question, search with
  Gemini if available or web search before asking me.
- Use parallel tool calls for independent reads/checks.
- Do not stage, commit, push, or touch portfolio/vendor unless explicitly asked.

Reference intent:
- Image 1 is mostly diffusion/glow/halation and is already close to existing
  Filmtone capabilities.
- Image 2 is the target for Halo: large circular/semicircular rainbow arcs,
  light-reactive, center-preserving, chromatic, optical rather than decorative.

Known code entry points:
- packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts
- packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts
- packages/film-lab-renderer/src/webgpu/shaders/cross-filter-source.frag.wgsl.ts
- packages/film-lab-renderer/src/webgpu/shaders/cross-filter-streak.frag.wgsl.ts
- packages/film-lab-core/src/params.ts
- packages/film-lab-core/src/optical-recommendation.ts
- packages/film-lab-ui/src/FilmLabControlPanelCore.tsx

Planning constraints:
- Prefer a WebGPU/Desktop visual proof first.
- Do not start with UI or iOS parity.
- Do not solve this as a static PNG overlay.
- Consider a dedicated Halo Prism post pass that reuses compact highlight
  extraction but generates annular/circular chromatic arcs.
- Include proposed params, shader/pass placement, render graph changes, UI
  timing, verification commands, risks, and a staged implementation sequence.

Deliverable:
Give me a rigorous implementation plan, with concrete file paths and sequencing,
that maximizes the chance of producing the Image 2 Halo look at product quality.
```

