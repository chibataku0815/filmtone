# Progress: Visual Quality And Acceptance

Plan: [Visual Quality And Acceptance](../visual-quality.md)
Owner: future `QUALITY` worker; master state is coordinator-owned
Last synced: 2026-07-18 JST

## State

`Review — Resolve discovery/project evidence and the direct-Metal smoke, bounds, and FHD timing matrix pass; Color-page instantiation and owner visual acceptance remain unproven`

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
project now contains the 24 fps, 1920 x 1080 timeline
`Filmtone Finish QUALITY Baseline 24fps FHD`, one built-in `Solid Color`
generator, and one empty Fusion composition created during API inspection.
ProjectManager `SaveProject()` returned true.

Public API instantiation could not be proved. `AddFusionComp()` increased the
composition count to one but returned a stale false value; the current Fusion
composition was visible through `resolve.Fusion().GetCurrentComp()`, yet
`AddTool()` returned false for both the Filmtone registry ID and a built-in
`Background` control. The documented Color node graph API has no arbitrary OFX
add operation. Three UI space-switch attempts were then exhausted; the owner
explicitly closed that path and directed QUALITY to the temporary direct-Metal
harness. Computer Use `get_app_state` was not retried.

The temporary untracked Objective-C++ harness links the accepted render graph,
module processors, identity blit, and pipeline cache objects. It allocates
RGBA32Float Metal buffers and invokes `encodeFilmtoneFinishMetal` directly.
The narrowed 64 x 48 smoke matrix passed, followed by exactly one non-zero-
origin Gate Weave bounds case and one warm FHD combined stopped-frame sample.
No product source correction was justified.

## Checklist

- [x] Receive explicit build/test/Resolve/install authorization and scope.
- [x] Confirm integrated effect and exact evaluation build.
- [x] Clean-build and inspect the arm64 bundle and OFX entry points.
- [x] Compile all three embedded Metal programs and link a temporary metallib.
- [x] Install the recoverable evaluation bundle without replacing another OFX.
- [x] Prove Resolve discovery of `com.chibatakumi.filmtone.finish` in its log.
- [ ] Evaluate module isolation and combined pass order. Direct-Metal module
  isolation and combined activity pass; host instantiation and an independent
  order comparison remain open.
- [ ] Evaluate cadence, determinism, wide-gamut values, alpha, and bounds.
  Same-frame repeat, wide RGB, alpha, and one bounds case pass; random access
  and the fps matrix remain open.
- [ ] Tune Film Breath, Gate Weave, and Film Damage to Filmtone character.
- [ ] Evaluate CinePrint35 coexistence without double Gate Weave/Dust.
- [x] Record one stopped-frame performance sample on the owner target Mac.
- [ ] Obtain owner visual acceptance before packaging decisions.
- [x] Record copy/history, article, and change-history classifications.

## Changed Files

Tracked and unstaged:

- `docs/filmtone/davinci-plugin/workstreams/progress/visual-quality.md`

Generated, temporary, untracked, and not staged:

- `apps/filmtone-resolve-ofx/build/FilmtoneFinish.ofx.bundle`
- `apps/filmtone-resolve-ofx/build/quality-harness/FilmtoneFinishQualityHarness.mm`
- `apps/filmtone-resolve-ofx/build/quality-harness/FilmtoneFinishQualityHarness`
- normal Makefile object output under `apps/filmtone-resolve-ofx/build/objects/`

The harness is evidence-only build output, not product test infrastructure. No
plugin source, immutable plan, strategy, master progress, accepted feature
record, unrelated app/package, existing Resolve project, or external
repository changed. No Git write was performed.

## Evaluation Installation

- Built bundle:
  `apps/filmtone-resolve-ofx/build/FilmtoneFinish.ofx.bundle`
- Installed evaluation bundle:
  `/Users/chibatakumi/Library/Application Support/Filmtone/Resolve-OFX-Evaluation/FilmtoneFinish.ofx.bundle`
- Binary SHA-256 at both paths:
  `df547c5725ae395bd8d16f8e3c69a67c9965e8d04ecba2599fa8280ab1bb69a9`
- Launch environment:
  `OFX_PLUGIN_PATH=/Library/OFX/Plugins:/Users/chibatakumi/Library/Application Support/Filmtone/Resolve-OFX-Evaluation`
- Existing Filmtone Finish bundle: none; no backup was needed.
- Existing `/Library/OFX/Plugins` contents were not modified.
- Cleanup/restore after coordinator review: quit Resolve, run
  `launchctl unsetenv OFX_PLUGIN_PATH`, then remove only the user-owned
  `Resolve-OFX-Evaluation/FilmtoneFinish.ofx.bundle`. There is no prior
  Filmtone bundle or environment value to restore.
- Per continuation instruction, the evaluation bundle, launch environment,
  disposable project, and temporary harness were left intact at handoff.

## Resolve Discovery And Disposable-Project Evidence

- Official API: connected; Resolve version `21.0.2.4`.
- Current project: exactly `Filmtone Finish QUALITY 2026-07-18`.
- Timeline: `Filmtone Finish QUALITY Baseline 24fps FHD`, 24 fps,
  1920 x 1080, one `Solid Color` generator.
- Fusion registry summary: exact ID
  `ofx.com.chibatakumi.filmtone.finish`, name `Filmtone Finish`, class type 3.
- Resolve startup log:
  `/Users/chibatakumi/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt`
  records the plugin load.
- Fusion composition: one empty composition exists only in the disposable
  project. Filmtone and built-in Background `AddTool()` both returned false,
  so no Resolve-host effect instance or rendered frame is claimed.
- Project save: ProjectManager `SaveProject()` returned true.
- Screenshots: Screen Recording permission and full-display capture worked,
  but Resolve remained on an inaccessible macOS Space. No screenshot proved
  product UI or rendering, so no screenshot was promoted into repository
  evidence.
- Owner safety: no owner project was opened, changed, or used for media.

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

- Resolve Color-page listing screenshot, actual OFX instantiation, host default
  identity, host Breath/Weave/Damage/combined frames, cache/export, and project
  reopen are not proved.
- Random-access determinism and fps `23.976/24/25/30/60` coverage are not run.
- UHD, proxy/render-scale, portrait/non-square, and supplied-host alpha
  variations are not run.
- Damage family isolation, white-sparkle rate, tiling/repetition, Film Breath
  mean neutrality/periodicity, and neutral/saturated color behavior are not
  evaluated.
- CinePrint35 coexistence was not attempted; no owner asset was used and no
  owner project was touched.
- Owner must judge Film Breath character, Gate Weave crop/softness, Damage
  family balance/repetition/sparkle behavior, and combined taste before any
  product acceptance or availability claim.

## Module Verdicts

- Film Breath: **direct-Metal smoke passes** for activity, finite wide RGB,
  exact constant alpha, and runtime MSL pipeline creation; Resolve-host and
  visual-character verdicts remain open.
- Gate Weave: **direct-Metal smoke and one non-zero-origin bounds case pass**;
  no black edge was measured and the smooth-gradient edge jump was `0.018054`.
  Resolve-host and owner softness/crop verdicts remain open.
- Film Damage: **direct-Metal smoke passes** for activity, finite wide RGB, and
  exact alpha; family isolation, tiling, sparkle, and owner-character verdicts
  remain open.
- Combined pass: **direct-Metal smoke, same-frame bit-exact repeat, and warm FHD
  sample pass**. Independent fixed-order comparison and Resolve-host rendering
  remain open.
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

Terminal state: `Review — build/bundle/Metal/install/discovery pass; direct-Metal smoke, one bounds case, and one warm FHD timing sample pass; Resolve-host instantiation and owner visual acceptance remain`

Repository / worktree / base: Filmtone / `/Users/chibatakumi/.codex/worktrees/1433/filmtone` / `f16aa4a6bdeaff740f59a60c5029af40c491e905` (clean detached start; `feature/davinci-ofx-foundation` target ref)

Changed files: this QUALITY progress record only; untracked Makefile build output and temporary harness remain under `apps/filmtone-resolve-ofx/build/`; no plugin source or coordinator-owned file changed

Public interfaces or artifacts: arm64 `FilmtoneFinish.ofx.bundle`, exact `com.chibatakumi.filmtone.finish` OFX bundle, recoverable evaluation installation, disposable Resolve project/timeline, and temporary untracked direct-Metal harness

Decisions fixed: one Filter, exact plugin ID, Metal-only, Breath -> Weave -> Damage source order, system plus evaluation OFX search path, no owner project/plugin replacement, and no product source correction without a demonstrated product failure

Remaining work: Resolve Color-page instantiation/render proof, random-access/fps/format matrices, module-specific visual gates, CinePrint coexistence when safe assets exist, and owner visual acceptance

Blocker: public Resolve scripting cannot add an arbitrary Color OFX; the Fusion composition/API path could not add even a built-in tool, and the explicitly closed UI space-switch mechanism failed three times. Direct-Metal proof does not substitute for a Resolve-host frame.

Verification performed: exact start gate; clean arm64 build; bundle/plist/architecture/export/linkage inspection; exact embedded MSL compile/metallib link; recoverable install/hash; Resolve log and Fusion registry discovery; authorized disposable project/timeline/save; 64 x 48 default/Breath/Weave/Damage/combined/repeat smoke; 96 x 64 non-zero-origin Weave bounds; warm 1920 x 1080 combined stopped-frame sample

Verification not performed: actual Resolve OFX instantiation/render/export, product screenshots, random access, fps matrix, UHD/proxy/portrait, Damage family/tiling/sparkle, Film Breath mean/periodicity/color behavior, CinePrint35, real-time playback, owner visual judgment, or Git writes

Stop reason: the owner directed the continuation to return when the authorized temporary harness matrix reached a terminal result; that matrix passed with zero failed assertions, while the remaining Resolve-host/UI and visual gates are explicitly preserved for coordinator/owner review
