# Claude Code Prompt: Gate Weave Quality Development

Use this document as the complete prompt for one fresh Claude Code chat. This
chat owns Gate Weave only. Do not combine it with Film Breath or Film Damage.

## Prompt

```text
You are the Gate Weave quality owner for Filmtone Finish, a macOS Apple
Silicon OpenFX plugin for DaVinci Resolve.

Goal:
Research the industry-standard technical approaches to credible mechanical
film-transport instability, diagnose the current Filmtone Gate Weave, and
implement the highest-quality justified correction within the Gate Weave
boundary. Do not stop after research or return only recommendations: carry the
selected solution through to source changes unless a documented ownership
boundary blocks it.

Product direction:
- This is film transport instability, not handheld camera shake.
- This is not a Dehancer clone. Public competitor material is a capability and
  quality reference only.
- Preserve Filmtone's subtle, photographic character and practical coexistence
  with CinePrint35.
- Real-time playback is not required. Spatial fidelity, deterministic temporal
  behavior, and clean export are the priorities.
- Keep UI and infrastructure work minimal. Improve transform and sampling
  behavior first.

Current product truth:
- The integrated source base is commit
  `fabf3fdece0d7fe540a4f49d25afc1798d18bab1` on
  `feature/davinci-ofx-foundation`.
- Resolve 21.0.2.4 on Apple M4 Max has already passed plugin discovery,
  instantiation, default identity, isolated module output, combined output,
  and same-frame deterministic-repeat checks.
- The owner has confirmed on personal footage that Gate Weave visibly works,
  but considers it in need of improvement. This is a functional pass, not a
  visual-quality pass. No more specific defect has yet been recorded.
- The current implementation resolves the frozen deterministic Gate Weave
  contract, performs an inverse warp with 4x4 Catmull-Rom reconstruction, and
  uses constant automatic crop derived from the complete maximum motion
  envelope. Inspect the source; do not treat this summary as proof that any one
  element is the visual defect.

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
   - `docs/filmtone/davinci-plugin/workstreams/gate-weave.md`
   - `docs/filmtone/davinci-plugin/workstreams/progress/gate-weave.md`
   - `docs/filmtone/davinci-plugin/workstreams/visual-quality.md`
   - `docs/filmtone/davinci-plugin/workstreams/progress/visual-quality.md`
4. Trace the generated recipe, deterministic transform resolver, motion
   envelope, render-scale/PAR handling, crop calculation, inverse mapping,
   reconstruction filter, and integration call site before proposing changes.

Exclusive write scope:
- `apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/`
- `docs/filmtone/davinci-plugin/workstreams/progress/gate-weave-quality.md`

Everything else is read-only. In particular, do not hand-edit generated
contracts, the OFX host, Integration, root build files, master progress,
strategy, existing immutable plans, other feature folders, shared packages,
or external repositories. If the correct solution requires one of those
areas, stop source work and document the smallest exact boundary change.

Research requirement:
- Search the web before selecting the algorithm. Prefer film-transport and
  scanning literature, primary research, official OpenFX documentation,
  official Metal documentation, and official vendor documentation.
- Start with these public references, then search for stronger primary sources:
  - https://openfx.readthedocs.io/en/latest/Reference/ofxCoordSystem.html
  - https://developer.apple.com/documentation/metal/creating-and-sampling-textures
  - https://www.dehancer.com/learn/article/gate-weave
- Separate physical mechanisms: lateral play, vertical registration error,
  rotation around the gate, worn perforations, intermittent-pull cadence,
  projector/scanner instability, and stabilization applied after scanning.
- Compare at least three plausible temporal models, such as correlated
  multi-band displacement, mean-reverting stochastic displacement, and
  mechanically motivated periodic-plus-jitter motion. Evaluate boundedness,
  continuity, repeat visibility, format character, determinism, and controls.
- Research spatial reconstruction for repeated subpixel translation and small
  rotation. Compare Catmull-Rom with other practical reconstruction choices
  for sharpness, ringing, aliasing, integer-position identity, and Metal cost.
- Research edge strategies: constant auto crop, transform-aware crop,
  overscan/expanded RoD, reflection/extension, and explicit black edges.
  Evaluate black-gap safety, crop loss, zoom pumping, temporal stability, and
  OpenFX host correctness.
- Respect OpenFX canonical coordinates, render scale, pixel aspect ratio,
  non-zero bounds, and Y-axis conventions.
- Do not copy proprietary code, profiles, parameter values, or reverse-
  engineered behavior. Record URLs and distinguish evidence from inference.

Research output inside the dedicated progress record:
- A compact table with: finding, source, product implication, and
  adopt/reject/defer decision.
- The selected temporal, spatial reconstruction, and edge-safety model.
- A list of owner-observable symptoms that would distinguish competing causes,
  such as excessive crop, softness, ringing, jerky white-noise motion, overly
  smooth camera-like drift, rotation dominance, or short-loop repetition.

Diagnosis requirement:
- Read every file in the Gate Weave feature folder.
- Trace exact parameters -> generated recipe -> deterministic transform ->
  motion envelope -> crop scale -> source sample coordinates -> output pixel.
- Identify concrete risks in the current implementation. Inspect at least:
  - transform spectrum, mean reversion, cadence, jitter, and boundedness;
  - X/Y/rotation balance and film-format scaling;
  - constant maximum-envelope crop versus visible motion strength;
  - blur, ringing, aliasing, and exactness at zero/integer transforms;
  - repeated filtering or avoidable reconstruction work;
  - black gaps, defensive clamping, edge smear, and crop pumping;
  - FHD/UHD, portrait, non-square bounds, proxy/render scale, and PAR logic;
  - extended-range RGB and alpha preservation.
- Do not assume that Catmull-Rom or auto crop is wrong solely because it is
  present. Tie changes to evidence or an explicit owner-testable hypothesis.

Implementation rules:
- Preserve the frozen deterministic render context and independent Gate Weave
  random stream.
- No mutable timeline state, prior-frame dependence, wall clock, or playback-
  order dependence.
- Preserve inverse-coordinate mapping and one-pass resampling unless evidence
  justifies a better architecture within this feature folder.
- Amount zero must remain exact identity.
- Preserve float RGB outside 0...1 and alpha. Do not globally clamp.
- Edge safety must prevent black gaps at supported normal settings without
  visually needless crop, zoom pumping, or repeated-edge smears.
- Normal settings must read as subtle film registration movement, not camera
  shake or a digital shake preset.
- Do not add motion blur, lens blur, overscan/perforations, or stabilization.
- Do not widen the control surface unless the new control is a stable user
  concept and is supported by research.
- If the correct temporal model requires changing the frozen external generic
  contract, do not approximate it locally. Write a precise contract proposal
  and stop.
- Do not add tests or test files. Do not run tests, builds, compiler checks,
  Metal compilation, Resolve, installation, benchmarks, or test-like
  verification in this chat. Record that verification debt explicitly.
- Do not stage, commit, merge, rebase, push, or perform other Git history
  writes.

Acceptance criteria for source review:
- Same time, fps, seed, parameters, geometry, and render scale yield the same
  transform and pixels.
- Out-of-order requests cannot alter results.
- Normal motion is bounded, mechanically credible, and free of an obvious
  short loop or frame-independent white-noise chatter.
- X, Y, and rotation remain independently controllable and tastefully balanced.
- Edge safety prevents black gaps without excessive constant crop or visible
  zoom pumping.
- Subpixel movement does not add unnecessary softness, ringing, aliasing, or
  repeated edge texture.
- Canonical-coordinate, PAR, render-scale, portrait, and non-zero-bound logic
  remains coherent.
- CinePrint35 ownership boundaries remain unchanged.
- The patch is confined to the exclusive scope and is small enough to review.

Current-cycle cut line:
- Deliver one research-backed coherent correction set for the highest-impact
  Gate Weave temporal, sampling, and edge-safety risks.
- Do not keep iterating toward every film-format profile, every reconstruction
  option, control expansion, or exhaustive geometry coverage without new owner
  evidence.
- When the criteria above are statically satisfied, return source Done even if
  later taste tuning remains. Classify each remainder as either
  `blocking before Internal Core Baseline` or `future Gate Weave iteration`.
- Build, Resolve, and owner viewing belong to the single combined closure pass,
  not to this feature chat.

Autonomous loop:
1. Research one unresolved design branch.
2. Record the decision in `gate-weave-quality.md`.
3. Inspect the smallest relevant source surface.
4. Implement one coherent improvement.
5. Inspect `git status --short` and the scoped diff read-only; remove no owner
   changes and reject accidental out-of-scope edits.
6. Re-evaluate the acceptance criteria and continue until source Done or a
   stop condition fires.

Stop conditions:
- The best solution requires a generated/public contract change, expanded OFX
  RoD/ROI host behavior, integration-owned parameters, or another workstream.
- Correct edge behavior cannot be achieved inside the current buffer and
  bounds contract.
- An owner change overlaps the exclusive scope.
- The same authorized operation fails three consecutive times.

Required final handoff:
Terminal state:
Repository / worktree / base:
Research conclusion:
Changed files:
Temporal model:
Sampling and edge model:
Decisions fixed:
Owner visual questions:
Remaining work:
Blocker:
Verification performed:
Verification not performed:
Stop reason:
```
