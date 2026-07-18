# Progress: Film Breath Quality

Owner: Film Breath quality worker; master state is coordinator-owned
Base: `fabf3fdece0d7fe540a4f49d25afc1798d18bab1`
Date: 2026-07-18 JST

## State

`Closed with future iteration — source/build/setup complete, but the owner did not award Film Breath a passing visual verdict in this cycle`

This is a working-tree integration only. No stage, commit, build, install, or
Resolve verification was performed during coordinator integration.

## Scope And Integration

Worker source:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/film-breath-quality-ac552b`

Integrated tracked source:

- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathProcessor.mm`

Coordinator evidence record:

- `docs/filmtone/davinci-plugin/workstreams/progress/film-breath-quality.md`

The same source correction was also applied to the tracked source in the
QUALITY worktree at `/Users/chibatakumi/.codex/worktrees/1433/filmtone`. Its
existing untracked build artifacts remain the previous v1 build until an
explicitly authorized rebuild replaces them.

## Research Decisions

| Finding | Evidence | Product decision |
|---|---|---|
| Film breath comprises accidental exposure, contrast, and colour movement caused by emulsion, shutter, development, and transfer instability. | [Dehancer capability explanation](https://www.dehancer.com/learn/learn_articles/film-breath-gate-weave) | Retain the canonical Filmtone four-offset model; do not copy competitor values or profiles. |
| Archived-film flicker literature models intensity variation with a dominant multiplicative component and, in nonlinear work, through film density/exposure response. | [van Roosmalen et al.](https://repository.tudelft.nl/file/File_d1ba9f68-7c17-4294-98d3-3c895dbf7864), [Vlachos](https://www.researchgate.net/publication/3308625_Flicker_Correction_for_Archived_Film_Sequences_Using_a_Nonlinear_Model) | Prefer gain-type colour movement over additive RGB offsets, subject to owner A/B in actual Resolve encodings. |
| Neutral light flicker and differential colour movement can have separate physical causes. | Telecine references and public patent literature recorded by the worker | Preserve independent canonical exposure, contrast, temperature, and tint streams. |
| No public measured Film Breath spectrum suitable as Filmtone source truth was found. | Worker web research, 2026-07-18 | Keep the deterministic canonical multi-band value-noise facade. Do not invent measured-spectrum parity. |
| OpenFX time may be effect-relative, while the facade suppresses and ramps motion at onset. | [OpenFX coordinate systems](https://openfx.readthedocs.io/en/latest/Reference/ofxCoordSystem.html) | Check every-cut onset in Resolve. Any correction belongs at the facade/contract boundary, not in this feature folder. |

The worker compared correlated multi-band value noise, an
Ornstein–Uhlenbeck process, and a sampled sinusoid bank. The canonical
multi-band lattice model remains because it is continuous, deterministic under
random access, and does not require history. The quality change is confined to
the pixel response.

## Working-Domain Decision

The plugin does not know the host working encoding. Neither additive RGB nor a
per-channel gain has encoding-independent perceptual behavior.

The accepted claim is narrower:

- positive per-channel gains preserve exact numeric black `0.0`;
- they preserve channel sign;
- they do not clamp negative or greater-than-one values;
- their perceived strength and colour character remain encoding-dependent.

The gain implementation was selected because its failure mode is less
destructive for linear-like and display-referred inputs: it does not animate
the black floor. This is not a universal correctness or colour-management
claim. Host-managed Rec.709 and one scene-referred Resolve workflow must both
be judged before product acceptance.

## Diagnosis

The exact time and contract path remains:

`OFX time -> Resolve context -> generated Film Breath facade -> canonical offsets -> local response controls -> Metal uniforms`

Static findings:

- The canonical time generator, seed streams, facade, and exact host-seconds
  path remain unchanged.
- The previous Metal colour response added temperature/tint constants directly
  to RGB. This can visibly move the black floor and read as digital white-
  balance wobble.
- Exposure remains EV gain through `exp2`.
- The canonical three-piece tonal response remains unchanged.
- Amount zero still reaches exact identity; RGB remains unclamped and alpha is
  preserved.
- Feature-local cadence remains deferred. It must not bypass the frozen
  facade.

## Integrated Implementation

The temperature/tint response now applies positive per-channel gains after the
canonical exposure and tonal stages:

```text
R *= 1 + temperature*0.10 + tint*0.05
G *= 1 - tint*0.08
B *= 1 - temperature*0.10 + tint*0.05
```

The coefficients retain the canonical unit-signal displacement. The `1 + Δ`
form is affine in the zero-mean temperature/tint streams, so the colour
modulation is mean-neutral conditional on the incoming pre-colour value. This
claim does not include the separate nonlinear `exp2` exposure response.

Pixel semantics changed, so the local runtime Metal names are bumped:

- kernel: `filmtoneFilmBreathV1` -> `filmtoneFilmBreathV2`
- cache key: `filmtone.finish.film-breath.photometric.v1` ->
  `filmtone.finish.film-breath.photometric.v2`

Uniform layout, public module interface, generated contracts, parameter
surface, and Integration wiring are unchanged.

## Coordinator Review

- Source: **statically accepted**.
- Coordinator integration: **complete in the working tree**.
- QUALITY source synchronization: **complete in the working tree**.
- Contract and scope violations: **none found**.
- Product quality: **not accepted**; compile/render and owner A/B remain.

## Owner A/B Protocol

1. Build the old state from base `fabf3fde` with the v1 kernel and the new state
   from the same base plus this single source correction with the v2 kernel.
2. Compare both at Amount `0.2–0.4` using deep shadows, skin tones, and
   saturated highlights.
3. Watch the first approximately `1.25 s` after each edit point for dead motion
   or a visible fade-in.
4. At high Amount, check whether offsets visibly hold at their extremes.

Decision routing:

- Gain looks better in both working-space checks: retain v2.
- Gain fixes shadows but damages log/scene-referred colour: tune or reconsider
  the response; do not claim universal domain safety.
- Every-cut onset is visible: open a facade/contract-boundary proposal.
- High-Amount plateaus are visible: propose facade calibration revision.

## Verification

Performed:

- worker clean/base gate;
- source, generated contract, canonical TS/Swift, Integration, and scoped-diff
  inspection;
- research and static reasoning recorded above;
- coordinator source-diff and exclusive-scope review;
- working-tree source integration into coordinator and QUALITY.
- subsequent QUALITY combined C++/Objective-C++ build, exact embedded Breath
  Metal compile, evaluation install/hash, Resolve restart, and exact registry
  enumeration.

Not performed:

- tests;
- revised-source Resolve render or visual A/B;
- numerical golden comparison or performance measurement;
- stage, commit, merge, rebase, or push.

## Remaining Risks

- Perceived gain strength is encoding-dependent.
- The `1.25 s` facade onset may repeat at edit boundaries depending on actual
  Resolve time semantics.
- The facade calibration clamp may create high-Amount plateaus.
- Existing v1 build artifacts do not contain the integrated v2 source until a
  rebuild occurs.

## Copy / History Impact

- No public copy/history change yet: this is an unverified internal quality
  correction and cannot support an availability or parity claim.
- Article Opportunity: **No story** until owner visual acceptance.
- Change-History Opportunity: **Developer note** if v2 is retained, explaining
  why numeric invariants and failure modes replaced a universal-domain claim.
