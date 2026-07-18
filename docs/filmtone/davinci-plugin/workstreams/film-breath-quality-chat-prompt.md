# Claude Code Prompt: Film Breath Quality Development

Use this document as the complete prompt for one fresh Claude Code chat. This
chat owns Film Breath only. Do not combine it with Gate Weave or Film Damage.

## Prompt

```text
You are the Film Breath quality owner for Filmtone, a macOS Apple
Silicon OpenFX plugin for DaVinci Resolve.

Goal:
Research the industry-standard technical approaches to credible film-breath
simulation, diagnose the current Filmtone implementation, and implement the
highest-quality justified correction within the Film Breath boundary. Do not
stop after research or produce only recommendations: carry the selected
solution through to source changes unless a documented ownership boundary
blocks it.

Product direction:
- This is not a Dehancer clone. Use public competitor documentation only to
  understand capability and quality expectations.
- Preserve Filmtone's existing character: subtle, living, photographic,
  restrained, and useful beside CinePrint35.
- DaVinci Resolve owns input color management. Do not add camera profiles,
  CSTs, log interpretation, film stocks, print response, grain, halation, or
  bloom.
- Real-time playback is not required. Deterministic render quality is the
  priority.
- Keep UI and infrastructure work minimal. Improve the image behavior first.

Current product truth:
- The integrated source base is commit
  `fabf3fdece0d7fe540a4f49d25afc1798d18bab1` on
  `feature/davinci-ofx-foundation`.
- Resolve 21.0.2.4 on Apple M4 Max has already passed plugin discovery,
  instantiation, default identity, isolated module output, combined output,
  and same-frame deterministic-repeat checks.
- Film Breath has direct-Metal and Resolve-host activity evidence, but the
  owner has not yet issued a real-footage character verdict.
- The canonical Film Breath model uses correlated time bands near 1.8, 4.8,
  8.6, and 15.5 seconds and bounded exposure, contrast, temperature, and tint
  offsets. Inspect the actual source and generated contract; do not rely on
  this summary as a substitute.
- Adjustable cadence was deliberately deferred because exact Resolve host
  seconds must pass through the frozen Film Breath facade. Do not reintroduce
  a feature-local time multiplier. If research proves cadence control is
  essential, return a separate contract-boundary proposal instead of bypassing
  the facade.

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
   - `docs/filmtone/davinci-plugin/workstreams/film-breath.md`
   - `docs/filmtone/davinci-plugin/workstreams/progress/film-breath.md`
   - `docs/filmtone/davinci-plugin/workstreams/visual-quality.md`
   - `docs/filmtone/davinci-plugin/workstreams/progress/visual-quality.md`
4. Trace the current Film Breath source, the generated Finish mapping, the
   generated Film Breath facade, the Resolve time adapter, and integration
   call site before proposing changes.

Exclusive write scope:
- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/`
- `docs/filmtone/davinci-plugin/workstreams/progress/film-breath-quality.md`

Everything else is read-only. In particular, do not hand-edit generated
contracts, the OFX host, Integration, root build files, master progress,
strategy, existing immutable plans, other feature folders, shared packages,
or external repositories. If the correct solution requires one of those
areas, stop source work and document the smallest exact boundary change.

Research requirement:
- Search the web before selecting the algorithm. Prefer primary research,
  archival/restoration literature, official OpenFX documentation, official
  Metal documentation, and official vendor documentation.
- Start with these public references, then search for stronger primary sources:
  - https://www.dehancer.com/learn/learn_articles/film-breath-gate-weave
  - https://openfx.readthedocs.io/en/latest/Reference/ofxCoordSystem.html
- Study the physical causes separately: emulsion-coating variation, shutter
  instability, development variation, and scanner/telecine contribution.
- Compare at least three plausible temporal models, such as correlated
  multi-band noise, mean-reverting stochastic motion, and measured/sampled
  low-frequency spectra. Evaluate continuity, mean neutrality, random-access
  determinism, short-loop visibility, parameter interpretability, and cost.
- Study whether exposure, tonal contrast, and chromatic movement should be
  independent, partially correlated, or coupled through a photographic model.
- Study the correct working-domain behavior for scene-referred and
  display-referred float RGB without assuming the plugin knows the input color
  space.
- Do not copy proprietary code, assets, sampled profiles, parameter values, or
  reverse-engineered behavior. Record source URLs and distinguish evidence
  from inference.

Research output inside the dedicated progress record:
- A compact table with: finding, source, product implication, and
  adopt/reject/defer decision.
- The selected model and why it is more credible than the alternatives for
  Filmtone.
- Any uncertainty that can only be resolved by owner viewing.

Diagnosis requirement:
- Read every file in the Film Breath feature folder.
- Trace exact host time -> Resolve context -> generated facade -> offsets ->
  local response controls -> Metal pixel math.
- Identify concrete quality risks in the current implementation. Inspect at
  least:
  - temporal spectrum, periodicity, continuity, and mean drift;
  - coupling among exposure, tonal, temperature, and tint movement;
  - whether contrast pivots and color operations behave photographically;
  - highlights, deep shadows, saturated colors, negative RGB, RGB above 1.0,
    and alpha;
  - exact Amount-zero identity and deterministic random access;
  - whether local response controls are genuinely useful or only expose
    implementation detail.
- Do not claim a defect merely because a different implementation is possible.
  Tie every change to evidence, source analysis, or a clearly stated visual
  hypothesis for owner review.

Implementation rules:
- Preserve the frozen generated facade and exact Resolve host seconds.
- Preserve random-access determinism: no playback-history state, prior-frame
  dependence, wall clock, or mutable RNG.
- Preserve mean neutrality and bounded behavior. No cumulative brightness,
  contrast, warmth, or tint drift.
- Preserve float RGB outside 0...1 and source alpha. Do not globally clamp.
- Amount zero must remain exact identity.
- Prefer one coherent photographic model over several corrective hacks.
- Keep normal-strength behavior restrained. Stress settings may reveal the
  model but must not define the default character.
- Do not widen the control surface unless the new control represents a stable
  user concept and cannot be expressed by existing controls.
- Do not add tests or test files. Do not run tests, builds, compiler checks,
  Metal compilation, Resolve, installation, benchmarks, or test-like
  verification in this chat. Record that verification debt explicitly.
- Do not stage, commit, merge, rebase, push, or perform other Git history
  writes.

Acceptance criteria for source review:
- Same time, fps, seed, and parameters resolve to the same offsets and pixels.
- Out-of-order frame requests cannot alter results.
- Motion is continuous and non-looping at normal viewing durations.
- Long-run expected exposure, tone, and chromatic displacement are neutral.
- The result avoids obvious digital white-balance wobble and generic opacity
  pulsing.
- Neutral highlights remain perceptually neutral at normal strength; saturated
  colors and extended-range values are not destroyed.
- Existing input-color and CinePrint35 boundaries remain intact.
- The patch is confined to the exclusive scope and is small enough to review.

Current-cycle cut line:
- Deliver one research-backed coherent correction for the highest-impact Film
  Breath quality risk and document the remaining owner-visible risks.
- Do not keep iterating toward universal colour-space behavior, new cadence
  controls, profile systems, or perfect taste without new owner evidence.
- When the criteria above are statically satisfied, return source Done even if
  later A/B tuning remains. Classify each remainder as either
  `blocking before Internal Core Baseline` or `future Film Breath iteration`.
- Build, Resolve, and owner A/B belong to the single combined closure pass, not
  to this feature chat.

Autonomous loop:
1. Research one unresolved design branch.
2. Record the decision in `film-breath-quality.md`.
3. Inspect the smallest relevant source surface.
4. Implement one coherent improvement.
5. Inspect `git status --short` and the scoped diff read-only; remove no owner
   changes and reject accidental out-of-scope edits.
6. Re-evaluate the acceptance criteria and continue until source Done or a
   stop condition fires.

Stop conditions:
- The best solution requires changing the generated/public contract, shared
  adapter, Resolve time semantics, or integration-owned parameter surface.
- The working-domain question cannot be resolved without a product decision
  that materially changes color behavior.
- An owner change overlaps the exclusive scope.
- The same authorized operation fails three consecutive times.

Required final handoff:
Terminal state:
Repository / worktree / base:
Research conclusion:
Changed files:
Algorithm and photographic model:
Decisions fixed:
Owner visual questions:
Remaining work:
Blocker:
Verification performed:
Verification not performed:
Stop reason:
```
