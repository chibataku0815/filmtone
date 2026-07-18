# Claude Code Prompt: Film Damage Quality Development

Use this document as the complete prompt for one fresh Claude Code chat. This
chat owns Film Damage only. Do not combine it with Film Breath or Gate Weave.

## Prompt

```text
You are the Film Damage quality owner for Filmtone, a macOS Apple
Silicon OpenFX plugin for DaVinci Resolve.

Goal:
Research the industry-standard technical approaches to credible film-damage
synthesis, diagnose each current Filmtone damage family, and implement the
highest-quality justified corrections within the Film Damage boundary. Work
family by family and do not stop after research or return only recommendations.
Carry each selected solution through to source changes unless a documented
ownership boundary blocks it.

Product direction:
- This is not a Dehancer clone. Use public competitor documentation only to
  understand artifact taxonomy, controls, and quality expectations.
- Preserve Filmtone's own character: dark/neutral debris, organic broken
  scratches, restrained sparkle, material variation, and subtle use beside
  CinePrint35.
- Film Damage owns Dust, Fibers/Hairs, Scratches, Stains, and Gate Wear. It does
  not own Gate Weave, Film Breath, grain, halation, bloom, overscan, film stock,
  print response, or input color management.
- Real-time playback is not required. Deterministic temporal/material quality
  and clean export are the priorities.
- Keep UI and infrastructure work minimal. Improve material behavior first.

Current product truth:
- The integrated source base is commit
  `fabf3fdece0d7fe540a4f49d25afc1798d18bab1` on
  `feature/davinci-ofx-foundation`.
- Resolve 21.0.2.4 on Apple M4 Max has already passed plugin discovery,
  instantiation, default identity, isolated module output, combined output,
  and same-frame deterministic-repeat checks.
- The owner has confirmed on personal footage that Film Damage visibly works,
  but considers it in need of improvement. This is a functional pass, not a
  visual-quality pass. No more specific defect has yet been recorded.
- The current implementation is a deterministic procedural Metal pass for
  Dust, Fibers, Scratches, Stains, and Gate Wear. It uses immutable event
  lifetimes, dark-weighted polarity, canonical scale normalization, and local
  family debug masks. Inspect the actual code and generated recipe; do not
  accept this summary as a visual verdict.

Start gate:
1. Read the repository `AGENTS.md` completely.
2. Confirm that this chat is running in its own clean dedicated worktree at
   the exact base above. Run `git status --short --branch` and
   `git rev-parse HEAD`. If the worktree is dirty, the base differs, or owner
   changes overlap the assigned area, stop without editing and report it.
3. Read:
   - `docs/filmtone/davinci-plugin/strategy.md`
   - `docs/filmtone/davinci-plugin/progress.md`
   - `docs/filmtone/davinci-plugin/delegation.md`
   - `docs/filmtone/davinci-plugin/workstreams/film-damage.md`
   - `docs/filmtone/davinci-plugin/workstreams/progress/film-damage.md`
   - `docs/filmtone/davinci-plugin/workstreams/visual-quality.md`
   - `docs/filmtone/davinci-plugin/workstreams/progress/visual-quality.md`
4. Trace the generated Film Damage recipe and adapter, event generation,
   family substreams, lifetime/fade logic, spatial cells/lanes, procedural
   masks, polarity/compositing, canonical sizing, and integration call site
   before proposing changes.

Exclusive write scope:
- `apps/filmtone-resolve-ofx/Sources/Effects/FilmDamage/`
- `docs/filmtone/davinci-plugin/workstreams/progress/film-damage-quality.md`

Everything else is read-only. In particular, do not hand-edit generated
contracts, the OFX host, Integration, root build files, master progress,
strategy, existing immutable plans, other feature folders, shared packages,
or external repositories. If the correct solution requires one of those
areas, stop source work and document the smallest exact boundary change.

Research requirement:
- Search the web before selecting the algorithm. Prefer film-preservation and
  restoration literature, scanned-film studies, primary research, official
  OpenFX and Metal documentation, and official vendor documentation.
- Start with these public references, then search for stronger primary sources:
  - https://www.dehancer.com/learn/articles/dehancer-film-damage
  - https://arxiv.org/abs/2302.10004
  - https://openfx.readthedocs.io/en/latest/Reference/ofxCoordSystem.html
  - https://developer.apple.com/documentation/metal/creating-and-sampling-textures
- Separate physical origin and image behavior for:
  - dust/debris on or near the film surface;
  - hairs/fibers and their persistence, curvature, and depth softness;
  - base-side versus emulsion-side scratches, polarity, continuity, breakup,
    taper, and affected dye layers;
  - stains, processing marks, chemical irregularities, and soft boundaries;
  - gate-edge wear/dirt tied to the transported film frame.
- Compare procedural, scan-derived, and hybrid synthesis. Evaluate uniqueness,
  licensing, temporal coherence, tiling, controllability, UHD behavior, memory,
  and Metal cost. Filmtone may use only Filmtone-owned or safely licensed
  material; do not download or add external visual assets in this task.
- Research event-process design: birth rate, on-screen population, lifetime,
  fade, persistence, motion, temporal clustering, and independence among
  families. Distinguish density from opacity and scale.
- Research light/dark/chromatic polarity based on where damage occurs in the
  negative/positive/scan chain. Avoid a universal white-overlay model.
- Research format-relative artifact scale without copying competitor profiles.
- Do not copy proprietary code, assets, samples, profiles, parameter values,
  or reverse-engineered behavior. Record URLs and distinguish evidence from
  inference.

Research output inside the dedicated progress record:
- A compact table with: finding, source, product implication, and
  adopt/reject/defer decision.
- A family matrix covering physical origin, spatial form, polarity, lifetime,
  motion/persistence, compositing behavior, and current implementation gap.
- The selected procedural or hybrid design and why it fits Filmtone better than
  the rejected alternatives.
- Owner-observable symptoms that distinguish density, scale, shape,
  compositing, and temporal failures.

Family-by-family order:
1. Dust/debris.
2. Fibers/hairs.
3. Scratches.
4. Stains.
5. Gate Wear.
6. Cross-family balance and combined behavior.

Complete the diagnosis, decision, and source correction for one family before
moving to the next. Do not hide weak families by reducing the global amount.

Diagnosis requirement:
- Read every file in the Film Damage feature folder.
- Trace exact parameters -> generated recipe -> uniform/event state -> spatial
  generator -> mask -> polarity/material compositing -> output pixel.
- For every family inspect:
  - shape vocabulary, silhouette variety, edge texture, scale distribution,
    and repeated motifs;
  - event birth, lifetime, fade, persistence, drift, and frame-to-frame popping;
  - screen-space versus film-surface attachment;
  - polarity, opacity, local color, and interaction with image luminance;
  - spatial uniformity, cell/lane seams, tiling, hash artifacts, and UHD scale;
  - normal-strength restraint versus stress-setting behavior;
  - deterministic random access and independence from other families;
  - negative RGB, RGB above 1.0, and alpha preservation.
- Explicitly inspect whether current generic recipe ranges are merely consumed
  or are being locally distorted. Do not duplicate or silently override
  external defaults just to avoid a proper contract decision.
- Do not claim a defect merely because scan assets could look richer. Tie each
  change to evidence or an explicit owner-testable hypothesis.

Implementation rules:
- Preserve the public Film Damage 2.3 recipe semantics and generated adapter.
- Preserve deterministic random access: no prior-frame fetch, playback-history
  state, wall clock, or mutable RNG.
- Keep family random streams decorrelated and artifact events stable for their
  resolved lifetimes.
- Preserve canonical image-size/render-scale behavior so apparent artifact size
  remains coherent across FHD, UHD, portrait, and proxies.
- Preserve float RGB outside 0...1 and source alpha. Local mask saturation is
  allowed; global image clamping is not.
- All family amounts zero must remain exact identity, and each family must
  remain independently usable.
- Dark/neutral material should dominate normal Filmtone settings. White marks
  may occur only where physically and aesthetically justified, and must remain
  subordinate rather than sparkle noise.
- Avoid fixed screen dirt, one-frame random popping, clean vector lines,
  repeated stamps, visible grids, and obvious procedural noise contours.
- Do not add external texture assets. If research proves scan-derived material
  is necessary for the target quality, stop with a precise Filmtone-owned asset
  acquisition/generation specification rather than adding unlicensed media.
- Do not widen the control surface unless the control represents a stable user
  concept and cannot be expressed by current family Amount controls.
- Do not add tests or test files. Do not run tests, builds, compiler checks,
  Metal compilation, Resolve, installation, benchmarks, or test-like
  verification in this chat. Record that verification debt explicitly.
- Do not stage, commit, merge, rebase, push, or perform other Git history
  writes.

Acceptance criteria for source review:
- Same time, fps, seed, parameters, and geometry yield the same events and
  pixels; out-of-order requests cannot alter results.
- Dust has varied irregular contours and coherent short-lived presence without
  uniform dots or frame-random sparkle.
- Fibers have organic curvature, width variation, taper, and persistence without
  repeated straight paths.
- Scratches show breakup, gaps, taper, edge variation, and plausible persistence
  without clean vector-line appearance.
- Stains are soft, materially distinct from dust, and do not read as generic
  translucent blobs or screen overlays.
- Gate Wear stays attached to gate edges, varies coherently, and remains
  distinct from a static vignette or border.
- Cross-family normal settings remain restrained, dark/neutral-led, and free of
  visible grids, tiling, repeated stamps, or dominant white sparkle.
- Format, render-scale, extended-range RGB, alpha, and CinePrint35 boundaries
  remain intact.
- The patch is confined to the exclusive scope and is small enough to review.

Current-cycle cut line:
- Give every listed family one credible research-backed baseline, then fix the
  shared cross-family defects that would disqualify normal use.
- Do not continue into exhaustive shape libraries, all possible damage types,
  scan-asset acquisition, profile systems, or repeated taste polishing without
  new owner evidence.
- When every family meets the baseline criteria above, return source Done even
  if optional realism improvements remain. Classify each remainder as either
  `blocking before Internal Core Baseline` or `future Film Damage iteration`.
- Build, Resolve, family-isolated viewing, and owner judgment belong to the
  single combined closure pass, not to this feature chat.

Autonomous loop:
1. Select the next unfinished family in the required order.
2. Research its unresolved design branch.
3. Record the decision in `film-damage-quality.md`.
4. Inspect the smallest relevant source surface.
5. Implement one coherent family improvement.
6. Inspect `git status --short` and the scoped diff read-only; remove no owner
   changes and reject accidental out-of-scope edits.
7. Re-evaluate that family's acceptance criteria, then continue through the
   family list and combined balance until source Done or a stop condition fires.

Stop conditions:
- The best solution requires a generated/public recipe change, integration-
  owned parameters, external/shared code, or licensed/scanned assets that do
  not exist.
- The current single-pass/buffer contract cannot represent the required
  material behavior without a shared architecture change.
- An owner change overlaps the exclusive scope.
- The same authorized operation fails three consecutive times.

Required final handoff:
Terminal state:
Repository / worktree / base:
Research conclusion:
Changed files:
Family verdicts (Dust / Fibers / Scratches / Stains / Gate Wear):
Combined-balance decision:
Decisions fixed:
Owner visual questions:
Remaining work:
Blocker:
Verification performed:
Verification not performed:
Stop reason:
```
