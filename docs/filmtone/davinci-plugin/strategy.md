# Filmtone DaVinci Resolve Plugin Strategy

Date opened: 2026-07-18 JST
Status: Foundation frozen; feature wave dispatched

This file is the long-term source of truth for the Filmtone DaVinci Resolve
OpenFX lane. Current coordination state lives in `progress.md`. Each bounded
new-chat assignment lives under `workstreams/`.

## Placement

Planning and product coordination live in this repository:

```text
docs/filmtone/davinci-plugin/
├── strategy.md
├── progress.md
├── delegation.md
└── workstreams/
    ├── *.md             # immutable workstream plans
    └── progress/*.md    # worker-owned execution records
```

The proposed Filmtone product wrapper lives at:

```text
apps/filmtone-resolve-ofx/
```

Generic Film Damage and Gate Weave authority remains outside Filmtone:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/visual-effect-core/
├── packages/visual-effect-core/src/features/film-damage/
├── packages/visual-render-core/src/features/film-damage/
└── packages/filmtone-pack/
```

Do not copy those contracts, defaults, reference fixtures, or renderer
assumptions into Filmtone. The OFX product wrapper must consume a public,
versioned handoff from the owning packages or bridge.

The existing `docs/filmtone/davinci-bridge/` lane remains a separate package /
sidecar / LUT / DCTL / Lua workflow. It is not the OpenFX implementation source
and must not be repurposed as one.

## Goal

Build a macOS Apple Silicon OpenFX effect that adds Filmtone's living-film
finish to DaVinci Resolve without becoming a Dehancer clone or replacing
Resolve and CinePrint35.

Dehancer Pro is a reference for control depth and temporal quality only. The
product identity is Filmtone: deterministic, restrained by default, visually
coherent with existing Filmtone output, and portable through the shared effect
contract ecosystem.

The first finish owns three independently bypassable modules:

1. **Film Breath** — an OFX realization of the existing Filmtone temporal
   exposure, contrast, and color movement.
2. **Gate Weave** — a new Filmtone capability that remaps the source image to
   model mechanical film transport instability.
3. **Film Damage** — an OFX realization of Filmtone's existing dark debris and
   broken scratch character, expanded through the generic Dust / Fiber /
   Scratch / Stain / Gate Wear contract.

`Film Breach` is a typo. Durable docs, identifiers, and UI use `Film Breath`.

## Product Boundary

Filmtone Finish owns:

- deterministic frame-to-frame photometric drift;
- subpixel X/Y transport movement and rotation;
- safe edge compensation for geometric movement;
- dust, fibers/hairs, scratches, stains, and gate-surface wear;
- Filmtone taste, compact Basic controls, and optional Advanced controls;
- explicit variation/seed behavior that survives scrub, cache, and export;
- Resolve-project persistence through normal OFX parameters.

It does not own:

- camera or log input profiles;
- CST, Resolve Color Management, or source normalization;
- negative stock measurement or film-stock catalogs;
- print-film emulation, CMY color-head controls, or print toning;
- halation, standalone film grain, or general primary grading;
- CinePrint35 replacement or Dehancer compatibility;
- automatic insertion of an OFX node through an undocumented Resolve API.

Resolve owns input color management. The effect consumes the float RGB values
provided by the host and must not infer a camera profile. It must preserve
negative and greater-than-one values wherever the operation permits; a global
`0...1` clamp is forbidden. If a transfer-specific operation proves necessary,
the user must establish the required working encoding with Resolve nodes rather
than Filmtone introducing camera-input management.

## Resolve And CinePrint35 Placement

Recommended node responsibility:

```text
Resolve input color management
  -> Filmtone Optics
  -> CinePrint35
  -> Filmtone Finish
  -> output transform
```

`Filmtone Finish` remains movable because a colorist may intentionally place
Film Breath before a film-emulation tree. The CinePrint companion default is
post-CinePrint because it provides one predictable working relationship and
keeps the new feature outside CinePrint's negative/print color model.

CinePrint35 overlap policy:

| Capability | CinePrint35 official surface | Filmtone policy |
|---|---|---|
| Film Breath | No equivalent documented | Filmtone core differentiator. |
| Gate Weave | `Gate Wv` node | Use CinePrint or Filmtone, never both by default. |
| Dust | Optional Resolve Film Damage node | CinePrint companion default keeps Filmtone Dust off. |
| Fibers / hairs | No CinePrint use documented | Available as Filmtone material finish. |
| Scratches | No CinePrint use documented | Available as Filmtone material finish. |
| Grain | Tuned Resolve Film Grain OFX | Do not add standalone Filmtone grain here. |
| Halation | Linear-space CinePrint node | Do not add it to Filmtone Finish. |
| Negative / print response | Core CinePrint responsibility | Do not duplicate. |

When Filmtone Gate Weave or Dust is enabled, the usage note must tell the user
which CinePrint node to disable. No preset may silently stack both versions.

## Source Ownership

| Responsibility | Canonical owner | Filmtone consumption rule |
|---|---|---|
| Film Breath amount and temporal character | `packages/film-lab-core/src/film-breath.ts` | Reuse the Filmtone behavior through a generated/versioned C++ handoff; do not tune an unrelated OFX clone. |
| Film Breath Swift parity evidence | `packages/film-lab-swift-core/.../FilmtoneFilmBreath.swift` | Read-only parity evidence for the OFX port. |
| Generic Film Damage / Gate Weave recipe | `@forestone/visual-effect-core` Film Damage contract v2 / revision 2.2 | Consume the frozen public handoff; never add a second Filmtone-local contract. |
| Generic deterministic reference | `@forestone/visual-render-core` Film Damage reference | Use as the semantic and fixture authority for the Metal realization. |
| Filmtone taste and compatibility mapping | `@forestone/filmtone-pack` | Add a finish-specific public mapping instead of hiding Dust/Scratch as lossy grade fields. |
| OFX host wrapper, product IDs, UI groups, bundle | Filmtone `apps/filmtone-resolve-ofx/` | Product-specific only; no generic contract ownership. |
| Package/LUT/DCTL/Lua workflow | Existing Filmtone DaVinci Bridge | Preserve as a distinct fallback/orchestration rail. |

The current generic Gate Weave contract supplies amount, frequency, jitter, and
travel axis, but not rotation or independent X/Y amplitudes. The contract
workstream must resolve that gap in the owning repo before the feature modules
freeze their uniforms. Edge compensation is host/render behavior and does not
belong in the generic recipe.

## OpenFX Architecture

Initial target:

- DaVinci Resolve 21 on macOS Apple Silicon;
- one `FilmtoneFinish.ofx.bundle` product bundle;
- one movable Filter effect with separate Film Breath, Gate Weave, and Film
  Damage control groups;
- OpenFX float RGBA input/output;
- Metal as the product render path;
- no silent reduced-quality renderer fallback;
- all modules default off and a true identity result at defaults;
- spatial awareness enabled; this effect is not LUT-generatable;
- random-access deterministic rendering without prior-frame dependencies.

The installed Resolve 21.0.2 Developer SDK is the initial read-only build
reference:

```text
/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX/
```

Use its OpenFX 1.4 headers, C++ support wrapper, Gain sample, and random-frame
sample as reference. The first core implementation may use the installed SDK
path; SDK pinning or vendoring is release-shell work after the effect is good.

Internal render order:

```text
source
  -> Film Breath photometric modulation
  -> Gate Weave inverse-coordinate resampling
  -> Film Damage surface/gate composite
  -> output
```

This order lets the photographed image move while dust, scratches, fibers, and
gate wear remain attached to the film/scan surface.

## Temporal Contract

Every module must use the same immutable render context:

```text
host time + source/timeline frame rate + explicit seed + normalized parameters
```

Required invariants:

- the same time, frame rate, seed, and parameters always produce the same
  result;
- result does not depend on playback history, render order, thread order,
  cache state, or whether Resolve requests frames randomly;
- no module hard-codes a 24 fps material clock;
- cadence remains intentional across 23.976, 24, 25, 30, and 60 fps;
- module random streams are decorrelated so Breath, Weave, and Damage do not
  pulse in phase;
- proxy and full-resolution renders preserve apparent cadence and normalized
  artifact scale;
- alpha is preserved;
- a disabled module performs no image work.

The seed is an explicit OFX parameter stored in the Resolve project. Do not use
a local file URL hash as the Resolve source of truth.

## Control Direction

Working control names are architectural, not final public copy.

- Basic: one Amount control per module, module bypass, and Variation.
- Film Breath Advanced: cadence, exposure response, tonal response, color
  response.
- Gate Weave Advanced: horizontal movement, vertical movement, rotation,
  cadence, instability, edge safety.
- Film Damage Advanced: Dust, Fibers, Scratches, Stains, polarity, scale,
  persistence, opacity, chromaticity, gate wear.

Do not copy Dehancer's UI hierarchy, profile values, random distributions,
assets, or exact labels. Physical film-format concepts may be consumed from
the generic contract, but Filmtone presets and defaults must be independently
authored from Filmtone evidence.

## Execution Waves

| Wave | Parallel work | Exit condition |
|---|---|---|
| Foundation | External contract / product mapping and OFX host scaffold run concurrently; the Filmtone adapter follows the accepted external contract. | Versioned contract handoff, reproducible Filmtone C++ adapter, and an identity Metal-capable bundle boundary are frozen. |
| Feature modules | Film Breath, Gate Weave, and Film Damage run in three independent chats. | Each module compiles behind its isolated interface and does not edit shared registration/build files. |
| Integration | Resolve descriptor, pass graph, controls, bundle build, and optional Bridge metadata are connected in one chat. | Resolve can apply the effect manually and each module works independently. |
| Product quality | Visual tuning, CinePrint coexistence, timing, bounds, wide-gamut, and packaging are evaluated last. | Measurable Done conditions pass with evidence and owner visual acceptance. |

Real-time playback is not a Done condition. A stopped-frame parameter change
must remain practically interactive. The provisional quality target is a
normal-strength UHD frame update within 500 ms median on the owner target Mac;
the quality workstream records the actual machine and may revise the threshold
before acceptance.

## Measurable Done Conditions

- Resolve 21 on Apple Silicon discovers and instantiates Filmtone Finish.
- All modules off returns the input unchanged and preserves alpha.
- Film Breath produces continuous, mean-neutral photometric movement with no
  cumulative drift.
- Gate Weave performs subpixel source remapping with independent X/Y movement
  and rotation, without black-edge flashes when edge safety is enabled.
- Film Damage exposes independent Dust, Fibers/Hairs, Scratches, Stains, and
  Gate Wear families and does not look like a fixed screen overlay.
- Dark and neutral debris remains the primary Filmtone character; white
  sparkle does not dominate.
- Identical time / fps / seed / parameters reproduce identically after scrub,
  cache invalidation, project reopen, and offline export.
- Negative and greater-than-one float RGB values are not globally clipped.
- CinePrint companion usage does not double-apply Gate Weave or Dust.
- Input color, film stocks, print response, halation, and standalone grain are
  absent from this product surface.
- DCTL fallback and OpenFX capability are described as different quality
  levels; no parity claim is made.
- Normal stopped-frame adjustment is practically interactive; real-time
  playback remains optional.

## Operating Rules For Parallel Chats

- Follow `delegation.md` for the state machine, worker loop, handoff schema,
  prohibitions, and initial planning-source exception.
- Use one repository and a dedicated branch/worktree per workstream. Do not run
  parallel implementation chats in the current dirty worktree.
- All worktrees branch from one recorded clean integration base after these
  planning docs are integrated.
- Each worker reads `strategy.md`, master `progress.md`, its assigned immutable
  workstream plan, and its dedicated `workstreams/progress/*.md` record.
- Worker chats update only their dedicated progress record when it exists in
  their clean base. The coordinator alone changes plans and master
  `progress.md`.
- Feature chats do not edit the root plugin registry, build source list,
  product manifest, sidecar writer, or Lua importer.
- Stop after three consecutive failures of the same authorized verification
  command, on unexpected source-of-truth conflict, or when the work expands
  beyond the assigned effect.
- Automated tests, test files, and test-like verification require an explicit
  owner request in the chat that performs them. Product-quality verification
  is intentionally last, after core behavior works.
- Foundation commits are coordinator-owned and were created only after owner
  authorization. Feature workers still do not stage, commit, push, release,
  install into `/Library/OFX/Plugins`, or mutate external repositories.

## Research Sources

- Dehancer Film Breath:
  <https://www.dehancer.com/learn/article/breath>
- Dehancer Gate Weave:
  <https://www.dehancer.com/learn/article/gate-weave>
- Dehancer Film Damage:
  <https://www.dehancer.com/learn/article/damage>
- CinePrint35 feature and node order:
  <https://www.tombolles.net/cineprint35>
- Local Blackmagic Design OpenFX SDK README and samples at the installed path
  above.

## Copy / History Impact

- Planning only: no public copy or release claim changes yet.
- Future implementation must record that Resolve OpenFX is a new Filmtone
  product surface, not a Dehancer-compatible mode and not a replacement for
  the existing package/LUT/DCTL Bridge.
- Article Opportunity: **Full article**, only after the Resolve effect is
  visually accepted and the distribution claim is true.
- Change-History Opportunity: **Yes** — this is the point where Filmtone adds a
  native Resolve temporal/material finish while preserving external generic
  effect ownership.
