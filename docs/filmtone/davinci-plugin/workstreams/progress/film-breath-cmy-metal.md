# Progress: Film Breath CMY Metal Response

Date: 2026-07-19 JST  
Workstream: `FILM-BREATH-CMY-METAL`  
Plan: `../film-breath-cmy-metal.md`  
Owner: `/root/film_breath_cmy_metal`; master state is coordinator-owned

## State

`Accepted — source interface and implementation; runtime verification deferred`

## Assignment

- Task ID: `/root/film_breath_cmy_metal`
- Worktree:
  `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone`
- Base: `202907ea34b43d1e03e78c2db5125d4d7a722fef`
- Start-gate exception: exact assigned-file hash replaces the clean-status gate;
  see the immutable plan.
- Authorized operations: source edits and this progress record only.
- Explicitly unauthorized: tests, build, Resolve, install, generation, and Git
  writes.

## Checklist

- [x] Base and assigned-file hash confirmed
- [x] Five-component Metal uniform layout implemented
- [x] Subtractive CMY density transmission implemented
- [x] Identity, black/sign, HDR, and alpha invariants retained
- [x] Runtime kernel/cache revision bumped
- [x] Scoped diff inspected read-only
- [x] Handoff recorded

## Worker Record

- 2026-07-19 JST: confirmed implementation HEAD
  `202907ea34b43d1e03e78c2db5125d4d7a722fef` and assigned-file SHA-256
  `361eaeec4cfd98c01fd25a39f4cfe4f08d170aa67be0d6a1ab0f48a9ebcc849e`.
  The coordinator-authorized dirty-snapshot start gate passed.
- Replaced the four-effect-float v3 payload with exposure, contrast, and signed
  C/M/Y stop-density values. Explicit scalar padding keeps the host and Metal
  uniform structs at 48 bytes with 16-byte host alignment.
- Positive C/M/Y primarily absorbs R/G/B through a documented non-negative
  cross-coupled matrix. Transmission uses `exp2(-density)` and is deliberately
  not luminance-normalized, so subtractive filtering can alter both colour and
  density.
- Exposure remains a neutral stop gain. Contrast remains a separately bounded
  log-luminance slope. The exact-zero fast path, positive multiplier response,
  unclamped RGB, and direct alpha pass-through preserve identity, black,
  channel sign, negative/HDR range, and alpha invariants.
- Bumped the embedded function and pipeline cache boundary to v4. Static source
  inspection found no remaining temperature/tint/v3 uniform or function read
  in the assigned file. Final assigned-file SHA-256:
  `4c11e3935cc85510437cc6ff14c443348bce3a12f908252706e98ded07fb4e1a`.

## Copy / History Impact

- No public copy was edited. Future characterization of this response must say
  subtractive CMY colour movement, not temperature/tint white balance.
- Article Opportunity: `Developer note`, after visual acceptance.
- Change-History Opportunity: `Yes` — the incorrect v3 temperature/tint model
  was replaced by the research-backed subtractive-density model.

## Handoff

Terminal state: `Review — source complete; coordinator verification pending`  
Repository / worktree / base:
`filmtone` / `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone` / `202907ea34b43d1e03e78c2db5125d4d7a722fef`  
Changed files:
`apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathProcessor.mm`;
this progress record  
Public interfaces or artifacts: no public parameter or processor interface
change; internal 48-byte five-component uniform payload and embedded Metal
kernel/cache revision v4  
Decisions fixed: signed CMY stop-density transmission with non-negative
cross-coupling; no white-balance normalization; independent neutral exposure
and bounded log-luminance contrast  
Remaining work: coordinator review with peer model/UI handoffs, then authorized
build, Resolve A/B, and owner visual acceptance  
Blocker: none for assigned source; runtime proof remains coordinator-owned  
Verification performed: exact base and start hash; read-only source/diff/status
inspection; static absence search for temperature/tint and v3 symbols; final
file hash recorded  
Verification not performed: tests, test-like checks, build, generation,
Resolve, install, or Git writes, per authorization  
Stop reason: implementation requirements reached; further proof requires
coordinator-owned runtime operations

## Coordinator Acceptance

- Accepted at assigned-file SHA-256
  `4c11e3935cc85510437cc6ff14c443348bce3a12f908252706e98ded07fb4e1a`.
- Cross-workstream inspection confirmed exact field-name/layout agreement with
  the local five-component offset object. The subtractive matrix has
  non-negative absorption coefficients and no luminance normalization.
- Compilation, embedded-Metal proof, and visual encoding-domain judgment remain
  explicit verification debt.
