# Workstream: Resolve Integration

Document role: immutable workstream plan
Execution progress: [INTEGRATION progress](progress/resolve-integration.md)
Runs alone after feature handoffs

## New Chat Start

Read the Filmtone `AGENTS.md`, plugin `strategy.md`, coordinator `progress.md`,
`delegation.md`, all completed foundation/feature handoffs, and this file. Use
this plan with `progress/resolve-integration.md`, and use a clean dedicated
integration worktree. This is the only worker allowed to edit shared OFX
product files. The coordinator remains the only editor of the master progress
record.

## Goal

Connect the three isolated modules into one stable Filmtone OpenFX
effect, expose the compact Resolve control surface, and preserve a clear
boundary from the existing LUT/DCTL/Lua Bridge.

## Context

The feature chats deliberately do not edit the factory, registry, source list,
pass graph, parameter pages, sidecar, or Lua integration. Resolve's public
scripting surface does not currently provide a reliable general API for adding
an arbitrary OFX filter to a Color node, so manual node placement is acceptable
for the first product result.

## Constraints

- One bundle and one movable Filmtone filter effect.
- Render order: Film Breath -> Gate Weave -> Film Damage.
- Every module has an independent bypass and zero-default identity.
- Compact Basic controls; Advanced groups may expose the frozen module
  controls.
- No Dehancer-compatible naming, profile values, or presets.
- No input transforms, film stocks, print, halation, or standalone grain.
- CinePrint companion defaults must not double Gate Weave or Dust.
- DCTL remains a lower-capability fallback and must not claim OFX parity.
- Do not attempt undocumented OFX auto-insertion through Lua.
- Read `docs/filmtone/filmtone-copy-quality-harness.md` before finalizing any
  user-facing control labels or help strings.

## Exclusive Shared Ownership

This chat alone may edit:

- root OFX factory and `OFX::Plugin::getPluginIDs`;
- effect descriptor and parameter pages;
- shared Metal pass graph/cache integration;
- root Makefile/source list and bundle resources;
- `package.json` only if a necessary, focused command is approved;
- optional sidecar mapping and
  `apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua`;

## Expected Output

- One registered Filmtone effect containing all three modules.
- Stable parameter IDs and Resolve-project persistence.
- Module bypass/identity short-circuiting and Metal pass scheduling.
- Manual CinePrint companion node placement guidance.
- If sidecar integration is in scope: additive finish metadata and an honest
  manual restoration report. Automatic OFX node creation is not required.
- A structured handoff that lets the coordinator record the exact integrated
  files, unresolved risks, and whether the QUALITY lane is unblocked.

## Acceptance Criteria

- Each module can be enabled alone and in combination.
- All modules disabled returns exact input and avoids unnecessary passes.
- Pass order keeps film-surface artifacts after the source-image remap.
- Stable seed/time/fps/render-scale data reaches every module.
- Parameter changes invalidate the correct frame without changing unrelated
  random streams.
- Wide-gamut float values and alpha survive the combined graph.
- CinePrint Gate Wv/Dust overlap is explicit and off by default in companion
  usage.
- No bridge surface claims unsupported automatic application.

## Non-Goals

- Broad visual tuning and final quality judgment.
- Real-time playback guarantee.
- SDK vendoring, notarization, installer, licensing, payment, or public release.
- Rewriting the existing DaVinci Bridge or DRX importer.

## Stop Conditions

- Any module handoff is incomplete or changes the frozen shared contract.
- Merge conflicts touch the owner's dirty native work.
- Resolve integration requires undocumented host behavior to meet the first
  product result.
- Three consecutive failures of the same explicitly authorized verification.

## Handoff

Recorded in [INTEGRATION progress](progress/resolve-integration.md).
