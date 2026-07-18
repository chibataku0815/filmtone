# Progress: Film Damage

Plan: [Film Damage](../film-damage.md)
Owner: `DAMAGE` worker; master state is coordinator-owned
Last synced: 2026-07-18 JST

## State

`Review — source Done; build and Resolve verification not authorized`

## Assignment

- Task: `019f7470-635b-7770-a419-fe02051fbe74`
- Repository: Filmtone
- Worktree: `/Users/chibatakumi/.codex/worktrees/751b9f41-bc21-4e13-b82d-1c94af7b9d62/filmtone`
- Base: `6130aae610de9f8c535f4e72d2078f2f1aabed66`
- Parallel peers: `BREATH`, `WEAVE`

## Current Loop

Source implementation and read-only changed-file inspection are complete. The
module consumes Film Damage 2.2, deterministic context 1, and Finish mapping 1
through the stable generated adapter. No shared integration surface changed.

## Checklist

- [x] Confirm accepted Film Damage contract and module interface.
- [x] Confirm Foundation Freeze SHA and exclusive feature directory.
- [x] Implement independent Dust, Fibers, Scratches, Stains, and Gate Wear.
- [x] Preserve Filmtone's dark debris and broken-scratch character.
- [x] Avoid a fixed screen-overlay appearance and dominant white sparkle.
- [x] Preserve deterministic cadence, wide-gamut floats, and alpha.
- [x] Record contract fields, approximations, artifacts, and limitations.
- [x] Return terminal handoff for coordinator review.

## Changed Files

- `apps/filmtone-resolve-ofx/Sources/Effects/FilmDamage/FilmDamageProcessor.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/FilmDamage/FilmDamageProcessor.mm`
- `apps/filmtone-resolve-ofx/Sources/Effects/FilmDamage/FilmDamageMetalSource.h`
- `docs/filmtone/davinci-plugin/workstreams/progress/film-damage.md`

## Implemented Contract

- `FilmDamageProcessor` is a local `host::ModuleProcessor` implementation. Its
  mapping/context constructor calls
  `makeFilmtoneFinishFilmDamageUniformsV1`; the frozen generated and HOST files
  remain read-only.
- Exact material identity is resolved before dispatch. Only Dust density,
  Scratch density, Fiber density, Stain density, and Gate Wear amount can make
  this module active; Gate Weave, Flicker, and Defocus fields are ignored.
- The single Metal pass derives decorrelated local family streams from the
  frozen `filmDamageStreamSeed`. Each spatial cell/lane resolves an immutable
  lifetime, period, entry offset, cycle, age, fade-in, and fade-out from the
  requested frame and recipe fields. No prior-frame state exists.
- Dust and Stains use non-repeating full-frame cells with irregular contours,
  texture, edge bias, slow event drift, and contract lifetimes/fades.
- Scratches use persistent lanes with contract area/gate bias, length, width,
  roughness, waviness, jitter, taper, breakup, and soft variable gaps.
- Fibers use long-lived persistent lanes with curved multi-frequency paths,
  contract curl/wiggle, organic width change, taper, gate bias, and fades.
- Gate Wear uses broken left/right gate-edge bands and coherent deterministic
  period/jitter epochs. The frozen Gate Wear contract has no lifetime/fade
  fields, so no invented public fields were added.
- Render pixels are converted through the frozen render scale and canonical
  full-frame bounds. Artifact dimensions derive from canonical image size, so
  proxy/full-resolution requests retain normalized apparent size.
- Mixed polarity is intentionally dark-weighted; positive sparkle/scratches
  are rare and lower gain. RGB material math has no output clamp, and source
  alpha is copied unchanged. Local mask clamps do not clamp image RGB.
- Local debug views expose Dust, Fibers, Scratches, Stains, Gate Wear, and a
  combined mask without adding shared parameters or UI.

## Intentional Approximations And Limits

- This is a deterministic Metal realization of the public semantics, not a
  byte/hash parity port of the external 8-bit CPU reference. Procedural shape,
  format response, family substreams, and dark-weighted mixed polarity are
  Filmtone-local decisions for later visual acceptance.
- No native macOS/iOS kernel code, assets, or tuning values were copied. Those
  sources were used only as read-only evidence for dark debris, broken marks,
  persistent fibers, restrained sparkle, and gate-edge character.
- The source is intentionally not registered in the root factory, Makefile, or
  shared pass graph. Those edits belong to `INTEGRATION`.
- Runtime Metal compilation, ABI/layout proof, Resolve behavior, visual tuning,
  and performance remain unproven because verification was not authorized.

## Verification

- Performed: exact clean/base start gate; read-only frozen-plan, handoff,
  generated-contract, HOST-interface, external-reference, native-taste, source,
  status, and changed-file scope inspection.
- Not performed: tests or test files; `make` or any build; C++/Objective-C++/MSL
  compiler checks; lint, formatting, or `git diff --check`; contract ABI/layout
  checks; identity pixel comparison; deterministic scrub/cache/export checks;
  proxy/full-resolution scale comparison; extended-range RGB/alpha measurement;
  UHD tiling/repetition inspection; visual-quality acceptance; performance
  measurement; bundle inspection; Resolve launch/render; installation.
- Git writes not performed: stage, commit, merge, rebase, or push.

## Blockers

No source blocker. Compiled proof and integration require coordinator-owned
work outside this assignment; builds/tests remain outside worker authorization.

## Next Action

Coordinator reviews the isolated diff. `INTEGRATION` may then add the source to
the build/pass graph and perform only separately authorized verification.

## Copy / History Impact

- No copy/history impact: isolated, unregistered source adds no public or
  release claim and follows the already-recorded Resolve OpenFX direction.
- Article Opportunity: **No story** for this workstream alone; the strategy's
  post-acceptance Resolve launch classification remains authoritative.
- Change-History Opportunity: **No new direction**; external contract ownership
  and Filmtone-local Metal realization remain unchanged.

## Handoff

Terminal state: `Review — source Done; verification not authorized`

Repository / worktree / base: Filmtone / assigned DAMAGE worktree /
`6130aae610de9f8c535f4e72d2078f2f1aabed66`

Changed files: three files in the exclusive Film Damage folder plus this DAMAGE
progress record.

Public interfaces or artifacts: `FilmDamageProcessor`, `FilmDamageDebugView`,
and the local embedded Metal material pass.

Decisions fixed: procedural random-access events; five material families only;
dark-weighted mixed polarity; canonical scale normalization; unclamped RGB;
unchanged alpha; no fallback.

Remaining work: coordinator review, shared integration, authorized compile /
Resolve / visual-quality proof, and later tuning.

Blocker: none for source; verification and integration are outside scope.

Verification performed: clean/base and read-only interface/source/scope
inspection only.

Verification not performed: all compiled, runtime, visual, performance, and
test verification listed above.

Stop reason: assigned source Done; further proof requires unauthorized or
coordinator-owned work.
