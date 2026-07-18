# Progress: Visual Quality And Acceptance

Plan: [Visual Quality And Acceptance](../visual-quality.md)
Owner: future `QUALITY` worker; master state is coordinator-owned
Last synced: 2026-07-18 JST

## State

`Closed by owner with partial acceptance — Film Damage passes this cycle; Film Breath and Gate Weave remain below the owner quality bar and move to future independent iterations`

## Assignment

- Delegated from task: `019f73e6-0bad-7fd2-948a-1e26d7963eff`
- Repository: Filmtone plus local DaVinci Resolve
- Worktree: `/Users/chibatakumi/.codex/worktrees/1433/filmtone`
- Exact starting HEAD: `f16aa4a6bdeaff740f59a60c5029af40c491e905`
- Starting state: clean detached HEAD; accepted coordinator Integration commit
  `915012a`, source worker commit
  `57434fc1187df8a8175d74b69c18e63c94ee5a52`
- Runs last

## Current Loop

The authorization and exact clean/base start gates passed. The documented
Makefile produced the arm64 bundle on its first clean build. Bundle layout,
plist identity, architecture, OFX exports, linked frameworks, and all three
embedded Metal programs passed focused inspection and compilation.

The recoverable user-owned evaluation bundle remains installed through
`OFX_PLUGIN_PATH`. Resolve's startup log records
`OFX: loading com.chibatakumi.filmtone.finish`. The official Resolve Scripting
API connects to Resolve `21.0.2.4` and reads only the authorized disposable
project `Filmtone Finish QUALITY 2026-07-18`. No owner project was opened or
modified.

The public Resolve API exposed the exact Fusion registry entry
`ofx.com.chibatakumi.filmtone.finish` / `Filmtone Finish`. The disposable
project retains the original 24 fps, 1920 x 1080 baseline timeline and now also
contains `Filmtone Finish QUALITY Host 24fps FHD`, built from a temporary ProRes
source generated inside untracked QUALITY build output.

After the owner brought Resolve to the visible macOS Space, Computer Use and
the official Resolve API completed the Color-host path. The effect was found
through the Effects library, applied to the Color node, and independently
confirmed through `GetToolsInNode(1)` as `OFX: Filmtone Finish`. The full
parameter surface appeared in Resolve. No owner project or media was used.

The temporary untracked Objective-C++ harness links the accepted render graph,
module processors, identity blit, and pipeline cache objects. It allocates
RGBA32Float Metal buffers and invokes `encodeFilmtoneFinishMetal` directly.
The narrowed 64 x 48 smoke matrix passed, followed by exactly one non-zero-
origin Gate Weave bounds case and one warm FHD combined stopped-frame sample.
No product source correction was justified.

Subsequent feature-focused quality work statically accepted and synchronized
Film Breath v2, Gate Weave revision 2.3, and Film Damage v2 source into the
QUALITY worktree. Film Damage now has distinct Dust, Fibers, Scratches, Stains,
and Gate Wear material behavior with deterministic temporal structure;
coordinator correction keeps Scratch and Fiber lengths inside the public recipe
semantics. Gate Weave now consumes the owner-generated revision 2.3 handoff and
mirrors its bounded correlated multi-band motion. These changes were then
clean-built together. All three exact embedded Metal programs compiled and
linked into a temporary metallib, bundle identity and OpenFX exports passed
inspection, and the new arm64 bundle replaced only the user-owned evaluation
installation. Resolve 21.0.2.4 restarted to Project Manager and its Fusion
registry enumerates the exact Filmtone Finish OpenFX id. No owner project was
opened. Revised-source image/output verdicts remain owner-owned.

The coordinator has fixed the current cutoff at Internal Core Baseline. All
three modules now have one source-level quality correction, so QUALITY next
performs one rebuilt combined closure pass and the owner performs one
restrained-setting personal-footage check. Only disqualifying defects found
there remain in this cycle. Optional taste refinement, exhaustive format/
temporal matrices, CinePrint coexistence, and packaging are explicitly later
work and do not prevent this milestone from closing.

## Closure Readiness

- Source gate: **pass**. Film Breath v2, Gate Weave revision 2.3, Film Damage
  v2, the revision-pinned generator, and generated contract artifacts match
  between Foundation and QUALITY.
- Ownership gate: **pass**. Breath and Damage changes remain feature-local;
  Gate Weave temporal semantics were corrected through the canonical external
  contract owner and regenerated into Filmtone.
- Source stop conditions: **none open**.
- Build/setup gate: **pass**. The revised combined source builds; embedded
  Breath/Weave/Damage Metal compiles; the installed evaluation binary matches
  the build; Resolve 21 enumerates the effect after restart.
- Runtime image gate: **owner-reviewed**. Codex did not ingest or retain the
  personal footage.
- Owner closure gate: **closed with split verdict**. Film Damage passes this
  cycle; Film Breath and Gate Weave do not pass. The owner elected to end this
  long-running task and continue those modules only as later independent work.

## Owner Closure Verdict

- Film Damage: **Pass for the current internal cycle**. This is not a release,
  parity, packaging, or final feature-completeness claim.
- Film Breath: **Below pass**. No specific defect breakdown was supplied in
  this closure turn; the next independent iteration must begin by capturing the
  most visible failure rather than assuming a cause.
- Gate Weave: **Below pass**. No specific defect breakdown was supplied in
  this closure turn; the next independent iteration must begin by capturing the
  most visible failure rather than assuming a cause.
- Combined/public product acceptance: **not granted**.
- Coordinator disposition: close the current task without further tuning;
  preserve the revised evaluation bundle and all recorded verification debt.

## Checklist

- [x] Receive explicit build/test/Resolve/install authorization and scope.
- [x] Confirm integrated effect and exact evaluation build.
- [x] Clean-build and inspect the arm64 bundle and OFX entry points.
- [x] Compile all three embedded Metal programs and link a temporary metallib.
- [x] Install the recoverable evaluation bundle without replacing another OFX.
- [x] Prove Resolve discovery of `com.chibatakumi.filmtone.finish` in its log.
- [x] Rebuild the combined Breath v2 / Weave 2.3 / Damage v2 source and compile
  all three revised embedded Metal programs.
- [x] Update only the recoverable evaluation bundle, restart Resolve, and
  confirm the exact effect in the Resolve 21 Fusion registry.
- [ ] Evaluate module isolation and combined pass order. Direct-Metal module
  isolation and combined activity pass; actual Resolve module-isolation and
  combined exports also pass. An independent order comparison remains open.
- [ ] Evaluate cadence, determinism, wide-gamut values, alpha, and bounds.
  Same-frame repeat, wide RGB, alpha, and one bounds case pass; random access
  and the fps matrix remain open.
- [x] Complete and record the first research-backed quality pass for Film
  Breath, Gate Weave, and Film Damage; only Film Damage received owner pass.
- [ ] Evaluate CinePrint35 coexistence without double Gate Weave/Dust.
- [x] Record one stopped-frame performance sample on the owner target Mac.
- [x] Record owner visual disposition before packaging decisions: partial
  acceptance only, so packaging remains deferred.
- [x] Record copy/history, article, and change-history classifications.

## Changed Files

Tracked and unstaged:

- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathProcessor.mm`
- `apps/filmtone-resolve-ofx/Sources/Effects/FilmDamage/FilmDamageMetalSource.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/GateWeaveTransform.cpp`
- `apps/filmtone-resolve-ofx/Sources/Effects/GateWeave/GateWeaveTransform.h`
- `apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts`
- generated Film Damage contract and provenance files under
  `apps/filmtone-resolve-ofx/Sources/Generated/Contracts/`
- `docs/filmtone/davinci-plugin/workstreams/progress/visual-quality.md`

Generated, temporary, untracked, and not staged:

- `apps/filmtone-resolve-ofx/build/FilmtoneFinish.ofx.bundle`
- normal Makefile object output under `apps/filmtone-resolve-ofx/build/objects/`

The clean closure build removed the previous temporary untracked harness and
quality-evidence build output; no product test infrastructure was created. No
unrelated app/package or existing Resolve project changed. The coordinator
updated the canonical strategy/master/feature records in its own worktree and
the external owner contract in its dedicated worktree. No Git write was
performed.

## Evaluation Installation

- Built bundle:
  `apps/filmtone-resolve-ofx/build/FilmtoneFinish.ofx.bundle`
- Installed evaluation bundle:
  `/Users/chibatakumi/Library/Application Support/Filmtone/Resolve-OFX-Evaluation/FilmtoneFinish.ofx.bundle`
- Binary SHA-256 at both paths:
  `596c7736fc63afbd1bee17b69dddd32daf91885ba3dad373b587c664447a1fa3`
- Launch environment:
  `OFX_PLUGIN_PATH=/Library/OFX/Plugins:/Users/chibatakumi/Library/Application Support/Filmtone/Resolve-OFX-Evaluation`
- Previous evaluation binary SHA-256:
  `df547c5725ae395bd8d16f8e3c69a67c9965e8d04ecba2599fa8280ab1bb69a9`.
  Its complete bundle is preserved outside the OFX search path at
  `/Users/chibatakumi/Library/Application Support/Filmtone/Resolve-OFX-Evaluation-Backups/FilmtoneFinish.ofx.bundle.pre-core-baseline`.
- Existing `/Library/OFX/Plugins` contents were not modified.
- Cleanup/restore after owner review: quit Resolve, move the current user-owned
  evaluation bundle aside, restore the preserved pre-baseline bundle if
  needed, and unset `OFX_PLUGIN_PATH` only when evaluation is finished.
- The revised evaluation bundle and launch environment remain active for the
  owner closure check. Resolve is open at Project Manager.

## Resolve Discovery And Disposable-Project Evidence

- Official API: connected; Resolve version `21.0.2.4`.
- Current project: exactly `Filmtone Finish QUALITY 2026-07-18`.
- Host timeline: `Filmtone Finish QUALITY Host 24fps FHD`, 24 fps,
  1920 x 1080, temporary 48-frame ProRes 4444 source.
- Fusion registry summary: exact ID
  `ofx.com.chibatakumi.filmtone.finish`, name `Filmtone Finish`, class type 3.
- Revised closure launch: Resolve `21.0.2.4` restarted after bundle replacement;
  the official API again enumerated the same exact registry id/name/class. No
  project was opened during this launch.
- Resolve startup log:
  `/Users/chibatakumi/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt`
  records the plugin load.
- Color node graph: one node contains exactly `OFX: Filmtone Finish`.
- Resolve UI: the Settings panel exposed all module bypasses, amounts,
  Advanced controls, Damage families, and Variation.
- Project save: ProjectManager `SaveProject()` returned true.
- Screenshots and 16-bit PNG exports proved product UI and actual host output;
  evidence remains untracked in the QUALITY build directory.
- Owner safety: no owner project was opened, changed, or used for media.

## Resolve Color-Host Output Evidence

Resolve rendered frame `86412` from the disposable FHD/24 fps timeline to
16-bit PNG. Hashes below are decoded raw-frame MD5 values, not container-file
hashes.

| Case | Result | Raw-frame MD5 | Differing pixels versus default |
|---|---|---|---:|
| Node disabled | Pass | `2691d0207dd971aff6209202cca93c0a` | 0 |
| Node enabled, all modules at defaults | Pass | `2691d0207dd971aff6209202cca93c0a` | 0 |
| Film Breath only, Amount 1.0 | Pass | `9fa9887d1f2aa6fe03163e4a84712347` | 2,073,600 |
| Gate Weave only, Amount 1.0 | Pass | `3456e8c8c6e05f2772287a5a3e5ca09a` | 365,883 |
| Film Damage Dust only, Amount/Dust 1.0 | Pass | `a37d571b0a0c72aedd3c12db95c8247b` | 6,711 |
| Combined repeat A | Pass | `e8ce94223a5e2ab2b4cdadbe1715f958` | 2,073,600 |
| Combined repeat B | Pass | `e8ce94223a5e2ab2b4cdadbe1715f958` | 2,073,600 |

Default node-off/node-on comparison and combined A/B comparison each had zero
differing pixels. Every Resolve render job completed. The Resolve log contains
no Filmtone-specific OFX, Metal, or render error during this matrix.

## Direct-Metal Evidence

The terminal run used Apple M4 Max and RGBA32Float source values spanning
negative and greater-than-one RGB with constant alpha `0.375`.

| Case | Result | Hash | Key measurement |
|---|---|---|---|
| Default identity, 64 x 48 | Pass | `d4246f9ae62793d3` | 0 changed pixels; bit-exact RGBA |
| Film Breath only, 64 x 48 | Pass | `20f84098e892f6be` | RGB `-0.292422` to `1.641380`; alpha error 0 |
| Gate Weave only, 64 x 48 | Pass | `726151dd478cb29a` | RGB `-0.176234` to `1.276178`; alpha error 0 |
| Film Damage only, 64 x 48 | Pass | `2df2a65f5cc0661c` | 557 changed pixels; RGB `-0.238657` to `1.339524`; alpha error 0 |
| Combined, 64 x 48 | Pass | `ccf4a5b0be04aedd` | all 3,072 pixels changed; alpha error 0 |
| Combined repeat, same frame/seed | Pass | `ccf4a5b0be04aedd` | bit-exact match to first combined render |
| Gate Weave bounds, 96 x 64, origin -23/+17 | Pass | `84341472f4e9ffc0` | edge minimum RGB energy `0.394033`; maximum edge neighbor jump `0.018054`; alpha error 0 |
| Warm combined FHD, 1920 x 1080 | Pass | `ad8388592cafeb65` | `13.631250 ms`; RGB `-0.202586` to `1.553167`; alpha error 0 |

The first smoke run also passed before the bounds/timing code was added. Its
initial per-module times included runtime Metal source compilation; the table
records the terminal run, and only the FHD sample is characterized as warm
stopped-frame timing. Real-time playback is not inferred.

## Commands And Results

- Closure build from the combined revised source:
  `make -C apps/filmtone-resolve-ofx clean` then
  `make -C apps/filmtone-resolve-ofx` passed first attempt in approximately
  `7.4 s`. Only the existing macOS 15 Metal API deprecation warning and the
  OpenFX SDK unused-parameter warning were emitted.
- Exact revised Breath, Weave, and Damage MSL extraction, three
  `xcrun metal` compiles, and one `xcrun metallib` link passed in approximately
  `0.94 s`.
- The revised bundle passed plist identity, arm64, OpenFX export, and system-
  framework linkage inspection. Build and evaluation-install binaries match at
  SHA-256 `596c7736fc63afbd1bee17b69dddd32daf91885ba3dad373b587c664447a1fa3`.
- Resolve restarted successfully and the official API enumerated
  `ofx.com.chibatakumi.filmtone.finish` / `Filmtone Finish` / class type `3`.
  No revised-source image verdict was performed.
- Earlier pre-tuning evidence follows for historical comparison:
- `make -C apps/filmtone-resolve-ofx clean && make -C apps/filmtone-resolve-ofx`
  passed first attempt in approximately `8.6 s`.
- Exact embedded MSL extraction, three `xcrun metal` compiles, and one
  `xcrun metallib` link passed in approximately `2.5 s`.
- `plutil`, `file`, `nm -gjU`, and `otool -L` inspection passed for bundle
  identity, arm64 architecture, OFX exports, and system-only linkage.
- Official Resolve API project/timeline/registry read-back and disposable
  project save passed. Fusion `AddTool()` remained unavailable as recorded
  above.
- First harness compile failed once because the command omitted the installed
  OFX Support include path. Adding the two exact Makefile SDK include paths
  fixed the command; the next compile passed with one unused temporary-harness
  helper warning.
- `apps/filmtone-resolve-ofx/build/quality-harness/FilmtoneFinishQualityHarness`
  passed the first narrow smoke run, then passed the terminal smoke + one
  bounds + one FHD timing run with zero failed assertions.

## Remaining Quality And Owner Decisions

- Owner manual closure used personal footage that Codex did not ingest or
  store. Film Damage received the current-cycle pass. Film Breath and Gate
  Weave remained below the owner's quality bar; their detailed defect capture
  and further tuning are deferred to separate future iterations.
- Cache invalidation, random-access order, and project reopen remain unproved;
  actual Color-page instantiation, default identity, module-isolation exports,
  combined export, and same-frame repeated export now pass.
- Random-access determinism and fps `23.976/24/25/30/60` coverage are not run.
- UHD, proxy/render-scale, portrait/non-square, and supplied-host alpha
  variations are not run.
- Damage family isolation, white-sparkle rate, tiling/repetition, Film Breath
  mean neutrality/periodicity, and neutral/saturated color behavior are not
  evaluated. Film Damage v2, Gate Weave 2.3, and Film Breath v2 are compiled and
  installed but not yet visually judged; their owner verdicts remain open.
- CinePrint35 coexistence was not attempted; no owner asset was used and no
  owner project was touched.
- Full combined product acceptance and any availability claim remain blocked
  by the below-pass Film Breath and Gate Weave verdicts.

## Module Verdicts

- Film Breath: **direct-Metal and Resolve-host activity pass on v1; v2
  additive-to-gain colour-response correction is statically accepted and
  compiled, Metal-compiled, installed, and enumerated by Resolve**. Real-
  footage owner verdict: **below pass; current task closed and future feature
  iteration required**.
- Gate Weave: **direct-Metal, non-zero-origin bounds, and Resolve-host activity
  pass on the pre-tuning source; owner also confirmed visible activity on
  personal footage; revision 2.3 correlated multi-band motion is synchronized
  to QUALITY source, compiled, installed, and enumerated by Resolve**.
  Owner verdict: **below pass; current task closed and future feature iteration
  required**.
- Film Damage: **direct-Metal and Resolve-host Dust activity pass on the
  pre-tuning source; owner also confirmed visible activity on personal
  footage; v2 detailed material source is statically accepted and synchronized
  to QUALITY, compiled, Metal-compiled, installed, and enumerated by Resolve**.
  Owner verdict: **pass for the current internal cycle**. Optional family
  refinement remains future work, not a closure blocker.
- Combined pass: **direct-Metal and Resolve-host same-frame exact repeats
  pass**. Independent fixed-order comparison remains open.
- CinePrint35: **not evaluated**; no owner asset/project was used.

## Copy / History Impact

- No public copy/history impact: the result proves an internal arm64 evaluation
  bundle, Resolve discovery, and direct accepted-processor execution only. It
  does not prove Resolve-host rendering, compatibility, availability, or
  distribution.
- Article Opportunity: **Full article remains deferred** until Resolve-host
  rendering, owner visual acceptance, and distribution are true.
- Change-History Opportunity: **No new direction**; the work follows the
  recorded one-Filter, Metal-only OpenFX decision.

## Handoff

Current state: `Closed by owner with partial acceptance — Film Damage passes; Film Breath and Gate Weave remain below pass and are deferred to future independent iterations`

Repository / worktree / base: Filmtone / `/Users/chibatakumi/.codex/worktrees/1433/filmtone` / `f16aa4a6bdeaff740f59a60c5029af40c491e905` (clean detached start; `feature/davinci-ofx-foundation` target ref)

Changed files: Film Breath, Gate Weave, and Film Damage quality source; generated Film Damage revision 2.3 handoff/provenance; contract generator pins; this QUALITY progress record. Untracked Makefile bundle/object output remains under `apps/filmtone-resolve-ofx/build/`; the clean closure build removed the temporary harness/evidence output

Public interfaces or artifacts: arm64 `FilmtoneFinish.ofx.bundle`, exact `com.chibatakumi.filmtone.finish` OFX id, recoverable evaluation installation, and preserved pre-baseline evaluation backup

Decisions fixed: one Filter, exact plugin ID, Metal-only, Breath -> Weave -> Damage source order, system plus evaluation OFX search path, no owner project/plugin replacement, and no product source correction without a demonstrated product failure

Remaining work: none in this task. Future work must open separate Film Breath and Gate Weave iterations beginning with concrete owner-observed defects. Broader temporal/format/CinePrint and packaging work remains deferred

Blocker: no implementation blocker keeps this task open. Full product acceptance remains unavailable because Film Breath and Gate Weave are below the owner quality bar.

Verification performed: exact start gate; pre-tuning host evidence listed above; revised-source clean arm64 build; revised bundle/plist/architecture/export/linkage inspection; exact revised embedded MSL compile/metallib link; recoverable evaluation replacement and matching hash; Resolve restart at Project Manager; official Resolve 21 Fusion registry enumeration; no owner project opened

Verification not performed by Codex: revised-source image/render verdicts, default/isolated/combined/repeat visual checks, random access, fps matrix, cache rebuild/project reopen, UHD/proxy/portrait/non-square, supplied-host alpha, CinePrint35, real-time playback, or Git writes. Owner visual disposition was reported directly: Damage pass; Breath/Weave below pass

Stop reason: the owner elected to close the long-running current task after the
manual split verdict. Film Damage passes this cycle; Film Breath and Gate Weave
remain explicit future work rather than keeping this task open.
