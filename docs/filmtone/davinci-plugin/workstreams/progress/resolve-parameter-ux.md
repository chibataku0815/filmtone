# Progress: Resolve Parameter UX (Quick Enable + Factory Defaults)

Owner: `RESOLVE-PARAMETER-UX`; master state is coordinator-owned
Date: 2026-07-19 JST

## State

`Review — source implementation complete; build / Metal / Resolve UI proof not
authorized in this task`

## Assignment

- Worktree:
  `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone`
- Base HEAD confirmed: `202907ea34b43d1e03e78c2db5125d4d7a722fef` on
  `feature/resolve-spatial-integration`.
- Start gate: the worktree already carried owner/Codex uncommitted changes
  (DeepGlow, FilmBreath, GateWeave, TextureSoftness, Vignette, Integration,
  generated contracts, `resolve-spatial-contract.ts`) plus untracked `build/`.
  None were reverted, staged, or committed. The pre-existing
  `FilmtoneFinishParameters.cpp/.h` dirty content (Film Breath CMY/Period,
  Gate Weave copy, Deep Glow copy) was preserved verbatim and edited on top.
- Start MD5 of files this task edited:
  - `Sources/Integration/FilmtoneFinishParameters.h`
    `5290af67f83c150bc4743e52ecb688d9`
  - `Sources/Integration/FilmtoneFinishParameters.cpp`
    `b62b6e3bc7b0653a05db72b23ac7179d`
- Concurrent work observed mid-session: the Deep Glow quality-redesign task
  updated `packages/film-lab-core/src/resolve-spatial-contract.ts`
  (`f6aed9d1…` → `3d5bbcd8…`), the DeepGlow sources, and
  `workstreams/progress/deep-glow.md` while this task ran. No file overlap
  with this task's edit surface occurred; this task did not edit the contract
  TS, any Effects folder, or any generated file.

## Changed Files

- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneResolveFactoryDefaults.h`
  (new)
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishParameters.cpp`
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishParameters.h`
  (doc comment only)
- `docs/filmtone/davinci-plugin/workstreams/progress/resolve-parameter-ux.md`
  (this record)

## Quick Enable Structure

New always-open group, defined immediately after Node Role:

- ID: `com.chibatakumi.filmtone.finish.group.quickEnable`
- Label: `Quick Enable`
- Hint: `Turns individual Filmtone modules on or off without changing their
  stored controls.`
- Default: open.

The eight existing persistent Enabled parameters were **moved**, not
duplicated. Each keeps its persistent ID, boolean kind, false default,
animate/persist flags, and evaluate-on-change; only the UI parent group,
display label, and hint changed:

| Quick Enable row (label) | Reused persistent ID |
|---|---|
| Deep Glow | `com.forestone.filmtone.finish.deepGlow.enabled` |
| Peripheral Chromatic Shift | `com.forestone.filmtone.finish.peripheralChromaticShift.enabled` |
| Lens Softness | `com.forestone.filmtone.finish.lensSoftness.enabled` |
| Texture Softness | `com.forestone.filmtone.finish.textureSoftness.enabled` |
| Vignette | `com.forestone.filmtone.finish.vignette.enabled` |
| Film Breath | `com.forestone.filmtone.finish.filmBreath.enabled` |
| Gate Weave | `com.forestone.filmtone.finish.gateWeave.enabled` |
| Film Damage | `com.forestone.filmtone.finish.filmDamage.enabled` |

Spatial rows take their labels directly from
`kFilmtoneSpatialFeatureDefinitionsV1[n].label`, so checkbox names cannot
drift from the generated feature names. Every enable hint uses the unified
copy `Turns <Feature> on or off without changing its stored controls.`

Page/definition order (the Resolve inspector lays out by parameter-definition
order — confirmed against the 2026-07-19 owner screenshot where Node Role,
first page child but defined after the groups, rendered below them):

1. Node Role (root)
2. Quick Enable (open): the eight enables above
3. Variation (root)
4. Deep Glow (closed): Strength, Threshold, Radius, Threshold Smooth
5. Peripheral Chromatic Shift (closed): Amount
6. Lens Softness (closed): Amount
7. Texture Softness (closed): Amount
8. Vignette (closed): Amount
9. Film Breath (closed): Amount, then Advanced (closed): Exposure Variation,
   Tonal Variation, Subtractive Color, Period (Frames)
10. Gate Weave (closed): Amount, then Advanced (closed): movement/rotation/
    cadence/instability
11. Film Damage (closed): Amount, then Advanced (closed): five families

Every persistent parameter is defined and paged exactly once (35 total: 14
spatial + 17 film + 4 local Film Breath). Detail groups contain only stored
adjustment controls; no duplicated Enabled row remains. The previously open
Film Breath / Gate Weave / Film Damage groups are now default closed, and all
three Advanced subgroups stay closed. Advanced subgroups are now defined
after their group's Amount so Advanced renders below Amount (the old UI
showed Advanced above the value rows).

## Resolve Factory Defaults

Single source: `Sources/Integration/FilmtoneResolveFactoryDefaults.h`
(`kFilmtoneResolveFactoryDefaults` + constexpr `resolveFactoryDefault`).
Both consumers resolve through it:

- descriptor `setDefault` for every real-kind generated parameter;
- the non-finite runtime fallbacks `readFiniteReal` / `readSpatialReal` in
  `FilmtoneFinishParameters.cpp`.

Values: Deep Glow Strength 0.40 / Threshold 0.75 / Radius 0.60 / Threshold
Smooth 0.50; Peripheral Chromatic Shift 0.0015; Lens Softness 0.30; Texture
Softness 0.50; Vignette 0.40; Film Breath Amount 0.45; Gate Weave Amount
0.40; Film Damage Amount 0.40, Dust 0.40, Scratches 0.30, Fibers 0.20,
Stains 0.20, Gate Wear 0.25.

Compile-time enforcement in `FilmtoneFinishParameters.cpp`:

- every table entry must match one existing generated real-kind definition
  and sit inside its accepted range (`resolveFactoryDefaultsMatchDefinitions`
  static_assert) — booleans (Enabled), Node Role, and Variation therefore
  cannot receive an override and keep identity defaults;
- Film Breath Exposure/Tonal/Subtractive Color/Period are asserted to hold
  1.0 / 1.0 / 1.0 / 24.0 in their Resolve-local descriptor array instead of
  being duplicated into the table (one default source per parameter);
- Gate Weave Horizontal/Vertical/Cadence/Instability defaults are asserted
  non-zero.

Generated-contract vs Resolve-UI difference (explicit): the generated
contracts (`filmtone_resolve_spatial.hpp`,
`forestone_filmtone_finish_mapping.hpp`) keep identity-oriented defaults
(amounts 0) and their struct initializers; generic consumers and old projects
still resolve neutral. Only the Resolve descriptor/evaluate layer applies the
factory table. `PRESETS.reset`, Desktop/iOS/shared reset values, canonical
contract TS, and all generated files are untouched by this task, and no
contract regeneration was run (regeneration requires the frozen external
artifact worktree per `progress/optics-contract.md` and is a separate
authorized step).

Identity invariants preserved: all eight Enabled defaults stay false, Node
Role stays `All`, Variation stays 0, and the runtime gate remains
`effective active = stored Enabled && effective Amount > 0` (unchanged
`mapFilmtoneFinish` and generated views). Add-time and full-reset output is
exact identity; a reset restores Enabled=false plus the recommended
adjustment values above.

## Decisions

- **Gate Weave advanced defaults kept**: accepted contract defaults are
  Horizontal 0.012, Vertical 0.0066, Cadence 1.6, Instability 0.25 — already
  non-zero, so enabling Gate Weave with Amount 0.40 moves the frame
  immediately. Rotation stays at its accepted 0 default: translation alone
  provides the enable-time motion, rotation is a taste addition, and setting
  it non-zero was not required by the "moves on enable" rule. Static asserts
  pin the non-zero trajectory values.
- **`Soft Knee` → `Threshold Smooth`**: applied as a display label with the
  persistent ID `com.forestone.filmtone.finish.deepGlow.softKnee` unchanged.
  Conditions verified: the extraction knee is a continuous quadratic
  threshold rolloff (unchanged by the Deep Glow redesign), and the
  concurrent Deep Glow quality-redesign task made the same rename in
  `resolve-spatial-contract.ts` this session (label-only, regeneration
  pending there). Until that regeneration lands, the integration-layer
  `labelOverride` is what shows `Threshold Smooth`; after regeneration both
  sources carry the identical string, so the override stays consistent.
- **Deep Glow redesign coordination**: this task read the 2026-07-19
  redesign record before fixing defaults. Strength 0.40 / Threshold 0.75 /
  Radius 0.60 / Threshold Smooth 0.50 all sit inside the redesigned ranges
  and semantics (Strength remains the sole diffusion-energy control with
  `strengthGain` max 1.5; Threshold default range stays within 0…1 while the
  contract max widens to 4; Radius stays 0…1 log-PSF storage). No DeepGlow
  source or contract row was modified by this task, and the 0.75 threshold
  clamp always passes the processor's `kDeepGlowThresholdMaximum = 4`
  fail-closed guard.
- **CinePrint35 note relocation**: the unified Quick Enable hint replaces
  the old Gate Weave Enabled hint, so the required CinePrint co-use warning
  moved into the Gate Weave detail-group hint (`… If CinePrint35 Gate Wv is
  active, leave one Gate Weave treatment off.`). The Dust-row CinePrint note
  is unchanged.
- **Presentation ownership**: group membership and order are now expressed
  once, explicitly, in `describeFilmtoneFinishParameters` (definition order =
  page order); the per-parameter `ParameterGroup` routing tables were
  removed. Hint copy from the concurrent Film Breath CMY/Period, Gate Weave,
  and Deep Glow copy passes is preserved character-for-character.

## Compatibility

- Public display name `Filmtone` and plugin ID
  `com.chibatakumi.filmtone.finish` untouched.
- No persistent parameter ID changed; no group ID removed (the five spatial
  group IDs, three film group IDs, and three advanced group IDs are all still
  defined; `…group.quickEnable` is additive).
- Stored Enabled values, Amounts, and keyframes load unchanged (OFX persists
  by ID; animate/persist flags unchanged; no value writes anywhere — there is
  no changedParam handler in the plugin).
- Old projects with Enabled=false and stored Amount>0 stay inactive; toggling
  a Quick Enable checkbox writes only that boolean.
- Node Role choices, render graph order, fps gating, and every feature
  processor's image path are unchanged by this task.

## Verification

Performed (read-only / static only):

- Start gate (`git status --short --branch`, HEAD = assigned base), start
  hashes, and full required reading (strategy/progress/delegation, copy
  harness, optics-contract, spatial-metal-host/spatial-integration records,
  Film Breath quality record, Deep Glow redesign record, generated
  contracts, owner UI screenshot).
- Post-edit static review: no leftover references to removed symbols,
  balanced braces/parens, exactly one `setOpen(true)` (Quick Enable), all 35
  value parameters defined/paged once, `git diff --check` clean, and
  re-verification that concurrent Deep Glow edits did not touch this task's
  files.

Not performed (prohibited in this task): build, Metal/shader compilation,
tests or test files, contract generation, OFX install, Resolve launch or UI
confirmation, stage/commit/push. Source completion here is not a Resolve UI
acceptance claim; the Quick Enable layout, definition-order rendering, open
states, and enable-time visual defaults still need one authorized rebuild and
an owner Resolve session.

## Copy / History Impact

- UI-strings-only change (labels/hints are literal and task-focused); no
  public copy, release, version, or availability claim changed.
- Future Resolve usage/release copy may describe the Quick Enable workflow
  ("enable a module at the top; each switch turns it on with a working
  starting value") only after Resolve UI verification passes.
- Article Opportunity: **Release-note only** (fold into the eventual Resolve
  plugin release notes; no standalone story).
- Change-History Opportunity: **Developer note** — identity-at-add via
  Enabled=false combined with non-identity stored factory adjustments is a
  durable UX decision worth one paragraph when the plugin's history is told.
