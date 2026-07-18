# Film Breath CMY Metal Response

Date: 2026-07-19 JST  
Workstream ID: `FILM-BREATH-CMY-METAL`  
Coordinator: Spatial Director  
State at dispatch: `Ready`

## Goal

Replace Film Breath's white-balance-like temperature/tint pixel response with
a subtractive CMY optical-density response while retaining exact identity,
unclamped extended-range RGB, source alpha, and the existing Metal-only host
path.

## Product Evidence And Fixed Interpretation

- Film Breath Color is described as a random subtractive transformation similar
  to CMY Color Head: <https://www.dehancer.com/learn/article/breath>
- CMY Color Head uses Cyan-Red, Magenta-Green, and Yellow-Blue subtractive
  filtration: <https://www.dehancer.com/learn/article/cmy-color-head-and-print-toning>

This fixes the physical direction and axis semantics only. Do not claim or
reverse-engineer competitor parity. Temperature/tint RGB gain is rejected.

## Repository And Start Snapshot

- Implementation worktree:
  `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone`
- Git base: `202907ea34b43d1e03e78c2db5125d4d7a722fef`
- Pre-dispatch tracked diff SHA-256:
  `ca3ba2b4548e8dd7907748b3ae208ec66ffa5884257842f143e8a45f0e07bc40`
- Assigned-file start hash: `FilmBreathProcessor.mm`
  `361eaeec4cfd98c01fd25a39f4cfe4f08d170aa67be0d6a1ab0f48a9ebcc849e`

The integration worktree is intentionally dirty while the owner reviews its
installed bundle. The coordinator authorizes the same narrow clean-start
exception as the model task: verify base and the assigned-file hash, then edit
only the exclusive area. Do not touch the installed bundle or Resolve session.

## Exclusive Edit Area

- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathProcessor.mm`
- `docs/filmtone/davinci-plugin/workstreams/progress/film-breath-cmy-metal.md`

## Frozen Input Interface

The peer model workstream provides:

```cpp
struct FilmBreathOffsets final {
    double exposure;
    double contrast;
    double cyanDensity;
    double magentaDensity;
    double yellowDensity;
};
```

Use these field names exactly. Do not change `FilmBreathProcessor`'s public
constructor or encode interface.

## Implementation Requirements

1. Replace temperature/tint uniforms with exposure, contrast, cyan density,
   magenta density, and yellow density. Preserve 16-byte host/Metal layout
   agreement with explicit padding if needed.
2. Treat positive C, M, and Y density as primarily absorbing R, G, and B
   respectively. A small documented cross-coupled absorption matrix is allowed
   to avoid idealized digital primaries; all coefficients must be finite and
   non-negative.
3. Convert density to multiplicative channel transmission in stop/log space.
   Negative random density is the complementary direction. Do not normalize
   channel transmission back to equal luminance: subtractive color filtering
   may also change exposure/density.
4. Exposure remains a neutral density/exposure factor. Contrast remains a
   separate bounded log-luminance slope, not a second exposure control.
5. Preserve exact source RGB when all five offsets are zero, exact numeric
   black, channel sign, negative values, values above one, and source alpha.
   RGB must not be clamped.
6. Bump the runtime Metal function and pipeline cache revision so an existing
   cached v3 pipeline cannot be reused.
7. Keep the implementation encoding-agnostic in its claims: no universal
   scene/display-referred equivalence claim is permitted.

## Acceptance

- There is no temperature or tint uniform, field read, or white-balance-style
  channel equation in the assigned file.
- Positive CMY density follows subtractive axis directions; identity and
  extended-range invariants are explicit in code.
- The local runtime cache/kernel revision changes.
- No public parameter ID, graph, other feature, build file, or generated
  contract is modified.
- Build and Resolve A/B remain coordinator work after all three handoffs.

## Prohibitions And Stop Conditions

Do not run tests, test-like checks, builds, Resolve, install, generation, or Git
writes. Do not edit this plan after dispatch. Stop on assigned-file drift,
interface conflict, out-of-scope dependency, or implementation completion.

