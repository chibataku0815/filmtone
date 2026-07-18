# Progress: Film Damage Quality

Plan authority: Film Damage quality prompt (this chat); peers own Film Breath
and Gate Weave. Master state remains coordinator-owned.
Last synced: 2026-07-18 JST

## State

`Accepted for current cycle — source/build/setup complete and the owner awarded
Film Damage the passing visual verdict; later family refinements remain optional`

## Assignment

- Repository: Filmtone
- Worktree: `.claude/worktrees/film-damage-quality-3ca76c` (dedicated, clean)
- Assigned base: `fabf3fdece0d7fe540a4f49d25afc1798d18bab1`
  (`feature/davinci-ofx-foundation` tip)
- Start-gate deviation, resolved: the worktree harness created this dedicated
  worktree from `main` (`a840634`), which is an ancestor of the assigned base.
  `fabf3fd` is a strict descendant of that HEAD, the FilmDamage tree at
  `fabf3fd` is byte-identical to the DAMAGE worker branch tip (`3ddc56c`), and
  no owner change overlapped the exclusive scope. The worktree was moved to
  the exact assigned base with a detached checkout (no ref or history write).
  `git status --short --branch` is clean at `fabf3fd`.
- Exclusive write scope:
  `apps/filmtone-resolve-ofx/Sources/Effects/FilmDamage/` and this record.

## Research Findings

| # | Finding | Source | Product implication | Decision |
|---|---|---|---|---|
| R1 | Public damage taxonomy: dust / hairs / scratches; polarity is production-chain dependent — particles at the negative stage invert to one polarity, print/scan-stage particles keep the other; real footage mixes both with a chain-dependent ratio | <https://www.dehancer.com/learn/articles/dehancer-film-damage> (taxonomy only) | Filmtone's dark-dominant mixed polarity (rare light accents) is physically defensible; keep dark-led polarity weights | Adopt (already in place) |
| R2 | Defect density is uneven along a roll; artifacts arrive in clusters; a global period concept describes cluster cadence along the roll | same as R1 | Add a slow deterministic per-frame density modulation (dirt-burst clustering) driven by `global.period`; do not leave per-cell cadence as the only temporal structure | Adopt |
| R3 | Statistically learned artifact shape/occurrence models are indistinguishable from real damage to experts; earlier uniform procedural noise was distinguishable | <https://arxiv.org/abs/2302.10004> | Uniform dots and low-order harmonic contours read as fake; silhouettes need non-convexity, raggedness, and a skewed size distribution | Adopt |
| R4 | Restoration literature models dirt/sparkle as temporally impulsive, spatially random dark and bright blotches | Kokaram et al., IEEE TIP 4(11) 1495–1508 via <https://link.springer.com/article/10.1007/s11265-014-0942-8> | True per-frame impulsiveness conflicts with Filmtone's coherent-presence acceptance; keep contract lifetimes (3–18 frames) but keep attacks/releases fast so presence still reads impulsive-ish, not ghostly | Adopt (bounded) |
| R5 | Base-side scratches: thin, dark, continuous, wet-gate treatable. Emulsion-side scratches: image layers physically removed; on colour prints they read pale green (partial dye removal), cyan/blue when deeper, white when all layers gone | <https://unwritten-record.blogs.archives.gov/2017/04/13/film-preservation-101-scratch-hazards-and-fixes/>, <http://www.brianpritchard.com/FAOL/contents/2604200faol/Foncd/TEXTS/sect_6/scratches6.html> | Dark scratches stay neutral (base-side); the rare light scratch deserves a restrained pale green–cyan tendency instead of pure white | Adopt |
| R6 | Scratch vocabulary: "tramlines" = continuous parallel scratches; "cinch marks" = short fine parallel scratches from coil slippage; "rain" = intermittent fine scratching | <https://www.nfsa.gov.au/preservation/preservation-glossary/tramline-scratching>, <https://www.kodak.com/en/motion/page/handling-of-processed-film/>, <https://www.sprocketschool.org/wiki/Film_damage> | One homogeneous scratch population is under-modelled; split events into long-lived tramline class and short-lived fine cinch class within the same contract ranges | Adopt |
| R7 | "Hair in the gate": debris/celluloid slivers lodge at the gate aperture edge, producing a dark line intruding from the frame edge, persisting across frames of a shot; gate transport also vibrates the film | <https://nextshoot.com/A-to-Z-of-film-and-video-production/page/what-is-hair-in-the-gate>, <https://en.wikipedia.org/wiki/Film_gate> | Fibers must anchor at frame edges and intrude partway with curved/hooked paths, tremble subtly, and persist; free-floating full-height vertical strands are wrong | Adopt |
| R8 | Water/drying marks: mineral deposits with defined edges concentrated where the droplet boundary dried; interiors lower contrast; distinct from dust | <https://www.learnfilm.photography/4-ways-to-get-rid-of-water-spots-on-film/>, <https://cinestillfilm.com/blogs/news/preventing-and-removing-water-spots-on-your-film> | Stains need an edge-deposit ring profile with irregular boundary and faint interior veil, not a filled translucent blob | Adopt |
| R9 | OFX spatial logic belongs in canonical coordinates; render scale converts only at buffer I/O so proxies keep apparent artifact geometry | <https://openfx.readthedocs.io/en/latest/Reference/ofxCoordSystem.html> | Event grids, noise cells, and pattern phases must not depend on `antialiasWidth` (a pixel-derived quantity); AA belongs only in edge transitions | Adopt |
| R10 | Scan-derived asset libraries are a competitor differentiator ("thousands of unique samples") | R1 article framing | Filmtone has no licensed scan library; hybrid scan-derived synthesis is rejected for this pass — procedural realization with statistically richer shape vocabulary is the boundary-safe path; revisit only with a Filmtone-owned asset spec | Reject (scan assets), Adopt (procedural upgrade) |
| R11 | External reference semantics include per-frame scratch lateral jitter and continuous-time fiber sway; the Metal port weakened both to near-static | `visual-render-core` `reference.ts` (read-only) | Restoring restrained per-frame/temporal liveliness moves the Metal realization closer to the public reference semantics without any contract change | Adopt |

## Family Matrix

| Family | Physical origin | Spatial form | Polarity | Lifetime/motion | Current implementation gap |
|---|---|---|---|---|---|
| Dust | particles on print/scan surface (dark); negative-stage (light, rare) | irregular non-convex specks, skewed size distribution, rare chunks | dark-led | short-lived, impulsive-ish, cluster bursts along roll | wobbly-ellipse contour (2 sine harmonics), uniform size distribution, no clustering, AA-dependent cell grid breaks proxy coherence |
| Fibers/hairs | debris lodged at gate aperture edge | edge-anchored curved/hooked strands intruding partway, width taper toward tip | dark | persistent (seconds), subtle tremble/flutter | free-floating near-vertical full-height strands, pure-sine curvature, effectively static over up to 180 frames |
| Scratches | base-side (dark, continuous tramlines) and emulsion-side (light, green-cyan cast); cinch marks short and fine | thin lanes with breakup, gaps, taper, core+scuff cross-profile | dark-led mixed; light rare | tramlines long-lived with micro-instability; cinch short-lived | single homogeneous population; internal gap/breakup pattern frozen for whole event; pure-sine path; light accents pure white |
| Stains | drying marks / chemical deposits with boundary-concentrated minerals | ring-weighted irregular contour, faint mottled interior veil | dark (per mapping) | long-lived, quasi-static with slow evolution | filled soft ellipse; hard-edged 18 px square-block interior texture (visible grid); harmonic contour |
| Gate Wear | worn/dirty gate rails at left/right frame edges | broken edge bands, streaky buildup, per-side asymmetry | dark | quasi-static, epoch-stepped evolution | fixed-frequency sinusoidal streak (~29 px periodic stripe), symmetric sides |

## Selected Design

Procedural, single-pass Metal realization is retained (R10). Scan-derived and
hybrid synthesis are rejected for this pass: no Filmtone-owned scan library
exists, external assets are licensing-unsafe, and the deterministic
random-access contract plus UHD tiling constraints are already satisfied by
the event/cell architecture. The correction path upgrades, per family, the
shape vocabulary (non-convex ragged silhouettes, skewed size statistics), the
temporal texture (held presence, stepped micro-instability, cluster bursts),
and material profiles (ring stains, core+scuff scratches, edge-anchored
trembling hairs, streaky asymmetric gate wear), while decoupling all pattern
geometry from render scale (R9).

Native Filmtone kernels (macOS `FilmtoneGradeKernels.swift` filmDamage, iOS
`OpticalKernels.swift`) are Filmtone-owned taste evidence: held visibility
floors, transition-phase drift/morph, two-lobe chip silhouettes, mottled
interiors, tick-stepped scratch jumps, gap flutter, density breathing, and
core+scuff profiles. Mechanisms are re-realized in MSL against the frozen
recipe; no constants are copied verbatim, and no native source is edited.

Rejected alternatives:

- Byte-parity port of the 8-bit CPU reference — rejected: the accepted DAMAGE
  handoff already fixed a native realization; parity would delete Filmtone
  character decisions and add none of the missing material behavior.
- Texture-atlas/scan stamping — rejected (R10, licensing and repetition risk).
- Multi-pass architecture (separate mask buffers) — rejected: all upgrades fit
  the single-pass signed-mask model; a shared architecture change is out of
  boundary.

## Owner-Observable Symptoms (diagnosis map)

- Density failure: too many/few events at normal Amounts; bursts absent
  (roll feels metronomic) — governed by presence gates and cluster modulation.
- Scale failure: dust reads as uniform same-size dots; no rare chunks —
  governed by size-distribution skew.
- Shape failure: blobs read as wobbly ellipses; stains read as filled discs;
  scratches read as clean vector lines — governed by contour/profile terms.
- Compositing failure: artifacts read as a screen overlay (visible on black,
  additive white sparkle everywhere) — governed by polarity/material math.
- Temporal failure: artifacts pop in one frame, ghost in/out slowly, or sit
  frozen (frozen scratch texture, static hairs) — governed by
  attack/release, held visibility, tick/flutter terms.
- Render-scale failure: preview (proxy) shows artifacts in different places
  than export — governed by AA-decoupling of event geometry.

## Family Log

### 1. Dust — source Done

Diagnosis (traced `dustFamilyMask`, ex-`spotFamilyMask` dust branch):

- Silhouette was an ellipse modulated by two fixed sine harmonics (5θ, 9θ) —
  a low-order harmonic contour with a visible procedural signature (R3).
- Size was drawn uniformly from the contract range: same-scale dots, no rare
  chunks, no small-mote majority.
- Interior texture was piecewise-constant axis-aligned block noise.
- Population was metronomic: per-cell periodic events only, no roll-position
  clustering (R2).
- `antialiasWidth` (pixel-derived) participated in `cellSize` and radius, so
  proxy and full-resolution renders resolved different event grids —
  preview and export showed dust in different places (R9 violation).
- Temporal profile was a plain symmetric fade: dust ghosted in/out rather
  than arriving.

Correction (one coherent change set):

- Split `spotFamilyMask` into `dustFamilyMask` and `stainFamilyMask`
  (stain body preserved verbatim for step 4).
- Silhouette: per-event wrapped angular value noise (5- and 11-cell octaves,
  no seam, no harmonic signature) with stronger raggedness for chunks, plus a
  secondary chip lobe (max-combined) for non-convex two-lobe debris; wider
  anisotropy range.
- Size statistics: `sizeT^2.35` skew (small-mote majority) with a ~4.5% chunk
  draw remapped to the top of the contract size range — the contract range is
  respected, never exceeded.
- Interior: smooth 2D value-noise mottle in event-local coordinates.
- Temporal: contract lifetime/fade retained; `heldVisibility` (fast soft
  attack into a held floor) replaces the raw fade; a `transitionPhase` swells
  radius, softens the boundary, and adds a small directional drift only while
  the event materializes/dissolves (native Filmtone taste, re-realized).
- Clustering: `clusterGain` — slow two-octave noise plus burst term over
  `frameIndex/(global.period*3.2)`, sampled at the event birth frame so an
  event can never vanish mid-life; amplitude tied to `frameEntryVariation`.
- Render-scale: event geometry (cell grid, radii, noise lattices) is now
  purely canonical; `antialiasWidth` only widens smoothstep transitions and
  sub-pixel visibility floors. Metal cache key bumped to
  `filmtone.finish.damage.metal.v2` (stale-pipeline hygiene).

Acceptance re-check: varied irregular contours (angular noise + chip, per-event
streams) — pass by construction; coherent short-lived presence without
one-frame sparkle (held attack ≥1 fade frame, contract lifetimes) — pass;
no uniform dots (skewed sizes, rare chunks) — pass; deterministic random
access (all draws are hashes of cell/cycle/stream; birth-frame cluster) —
pass; 3x3 neighborhood sufficiency re-derived with worst-case chip + drift +
transition extent ~2.1 x maxRadius < cellSize 3.65 x maxRadius — pass.
Runtime/visual proof: not authorized (debt).



### 2. Fibers/Hairs — source Done

Diagnosis (traced ex-`fiberMask`):

- Fibers were free-floating near-vertical strands spanning up to 90% of frame
  height, placed anywhere along X with only a probability bias toward the
  vertical edges — not attached to the gate (R7 contradiction).
- Curvature was three fixed sines; the wiggle phase advanced only ~0.55 rad
  across an entire 48–180-frame life, so a hair stood effectively frozen for
  up to 7.5 s (fixed-screen-dirt failure; reference semantics R11 include
  continuous-time sway).
- No width taper toward a free tip; both ends faded identically.
- `antialiasWidth` participated in band geometry (proxy incoherence).

Correction:

- Full re-architecture to edge-anchored hairs: four sides each own an
  anchor-slot lane array along the edge; vertical sides dominate via the
  contract `gateBias`, horizontal sides carry the remainder. The root sits at
  the frame boundary (slightly outset) and the hair intrudes partway.
- Length = the contract length range applied directly to the relevant
  side-normal frame extent, skewed toward the configured lower end (`t^1.4`);
  per-event tilt (capped), quadratic bend plus cubic hook (curl),
  two-octave value-noise wander (wiggle) — organic curved/hooked paths, no
  repeated straight lines.
- Width tapers to 26% at the free tip with value-noise width texture; root is
  thickest.
- Tremble: two per-event sinusoids over host time (~1.1–2.9 Hz and
  ~4.6–8.4 Hz) plus a stepped tick jump every 3–7 frames, with a `t^1.6`
  envelope so the anchored root stays still and the free tip flutters
  subtly. Deterministic (pure functions of host time / frame index).
- Persistence: contract lifetimes with `heldVisibility` floor 0.78.
- Coverage proof: along-edge travel (tilt + bend + hook + wiggle + sway) is
  capped below two anchor slots, so the ±2-lane iteration covers every
  reachable event. Wiggle and sway are explicitly slot-bounded so applying the
  full configured length range cannot invalidate the search neighborhood.
- All slot/length geometry canonical; AA only in line transitions.

Acceptance re-check: organic curvature/width variation/taper — pass by
construction; persistence without static freeze (tremble + held floor) —
pass; independence (own family stream, per-side event streams) — pass;
determinism — pass. Runtime/visual proof: debt.

### 3. Scratches — source Done

Diagnosis (traced `scratchAxisMask`):

- One homogeneous population: every scratch drew length/lifetime uniformly
  from the full contract ranges — no tramline vs cinch distinction (R6).
- The entire internal structure (gaps, breakup, edge variation, wave phase)
  was keyed by (lane, cycle) only: frozen for the whole event, so a 12–90
  frame scratch was a static overlay drifting slightly. The public reference
  (R11) has per-frame lateral jitter; the Metal port had dropped it.
- Cross-profile was a single soft line — no abraded scuff halo; taper only
  affected opacity, not width; light scratches were pure white (R5).
- `antialiasWidth` participated in band/gap-cell geometry (proxy
  incoherence).

Correction:

- Two populations sharing the contract ranges (R6): a stable per-lane class
  draw makes ~38% of lanes "tramline" (lifetime drawn from the upper 55% of
  the contract range, full width/opacity, held floor 0.72, position recurs
  like a persistent gate defect) and the rest "cinch" (lower 35% of the
  lifetime range, lower 35% of the configured length range, width x0.72,
  opacity x0.8, with breakup/gaps producing the short visible runs).
- Micro-instability: stepped tick jump every 4–9 frames plus a very small
  per-frame shimmer, both scaled by contract `jitter` (restores R11
  semantics in a restrained stepped form); slow held drift retained.
- Living structure: the gap pattern slides slowly along the run
  (per-event travel + slow noise), gap depth flutters on a 5–8 frame
  cadence, fine breakup boils on a 2–4 frame tick, and each event breathes
  in intensity (~0.82–1.14) on a 7–15 frame noise — the scratch reads as a
  groove crossing different physical frames, not a frozen decal.
- Path: two sines plus a non-periodic value-noise wander component.
- Cross-profile: core line plus a faint noise-gated scuff halo (2.4–3.6x
  width, roughness-driven) — abraded channel, not a vector line.
- Ends: width tapers with the segment envelope (x0.52 at tips).
- Light scratches: `applyMaterialDamage` gained a per-family `lightTint`;
  scratches pass a pale green–cyan bias (emulsion-side dye removal, R5);
  all other families stay neutral.
- Mild birth-frame `clusterGain` (amplitude 0.18); geometry canonical.

Acceptance re-check: breakup/gaps/taper/edge variation — pass; plausible
persistence without clean-vector appearance (tramline class + scuff + boil)
— pass; polarity dark-led with rare non-white light accents — pass;
determinism (all ticks are hashes of floor-divided frame index) — pass.
Runtime/visual proof: debt.

### 4. Stains — source Done

Diagnosis (traced ex-`spotFamilyMask` stain branch):

- A stain was a filled soft ellipse with a 3θ/7θ harmonic contour — a
  generic translucent blob, not a drying mark (R8).
- The interior texture was piecewise-constant noise on an axis-aligned ~18 px
  (canonical) square grid with hard value jumps of up to 42% — a visible
  grid inside every stain (explicit acceptance failure).
- `antialiasWidth` participated in radius and cell size (proxy incoherence).

Correction:

- Rim-weighted deposit profile: most density sits in an irregular rim band
  (`rimCenter` 0.86–0.94, width 0.05–0.12 per event) with a comparatively
  defined outer edge (transition 0.035–0.16, softness-scaled); the interior
  is a faint veil (16–30%) modulated by coarse smooth mottle (R8).
- Irregular tide line: wrapped angular value noise (4- and 9-cell octaves)
  replaces the sine harmonics; a merged second pool lobe (min-distance
  union, 0.55–0.95 reach) makes non-elliptical merged-puddle outlines.
- Both texture layers are smooth 2D value noise in event-local coordinates —
  the square-grid texture is gone.
- Temporal: contract lifetimes/fades with `heldVisibility` floor 0.80
  (quasi-static presence); tiny life drift retained; birth-frame
  `clusterGain` amplitude 0.30 (water damage clusters along the roll, R2).
- Chroma: the shared dark-material path now leans deposits warm at
  `chroma*0.060/0.045` (visible but restrained sepia on stains only — the
  contract stain chromaticity 0.25 was previously a ±0.6% no-op; dust,
  fibers, scratches, gate wear pass zero chroma and stay neutral).
- Geometry canonical; lobe reach proof: max extent 1.59 x maxRadius <
  cell 2.55 x maxRadius.

Acceptance re-check: soft but materially structured (rim + veil), distinct
from dust (scale, profile, warmth, quasi-static life) — pass; no screen
overlay read (luminance-coupled dark material, defined edge) — pass; no
visible grid (smooth noise only) — pass; determinism — pass. Runtime/visual
proof: debt.

### 5. Gate Wear — source Done

Diagnosis (traced `gateWearMask`):

- The streak texture was a fixed-frequency sinusoid (~29 px canonical
  period along Y): a regular periodic stripe pattern inside the wear band —
  an explicit "visible grid/pattern" acceptance risk.
- Both rails carried identical wear (symmetric), unlike real gates.
- The wear band was a smooth-gradient border with uniform depth — closer to
  a static vignette strip than worn rails; `antialiasWidth` sat in geometry
  floors (proxy incoherence).
- Epoch-blended break pattern was already sound and is retained.

Correction:

- Streaks: two-scale (0.42x / 1.6x wearBase) epoch-blended value noise
  replaces the sinusoid — non-periodic vertical dirt streaking that morphs
  with the existing epoch machinery.
- Depth grit: value noise across the band depth breaks the smooth gradient.
- Width wobble: the band width varies 0.72–1.32x along the edge
  (epoch-blended noise), so the wear boundary is a worn contour, not a rule.
- Side asymmetry: complementary per-seed side gains (`d` vs `1-d`, floor
  0.72) — one rail always carries near-full wear, the other reads lighter.
- Geometry floors canonical; AA only in the outer edge transition.

Acceptance re-check: attached to gate edges (edge-distance profile
unchanged) — pass; varies coherently (epoch morph + wobble) — pass;
distinct from static vignette/border (streaks + grit + wobble + asymmetry +
break pattern) — pass; determinism — pass. Runtime/visual proof: debt.

### 6. Cross-family balance — source Done

- Compositing order (stain -> gate wear -> dust -> fibers -> scratches) and
  the signed-mask material model are unchanged.
- Dark/neutral leadership: dust, fibers, stains, and gate wear are mapped
  dark by the frozen product mapping; only scratches carry the rare (7.5%)
  light polarity, now tinted pale green-cyan instead of pure white. No
  family gained additive white behavior; sparkle remains subordinate.
- No global amount was reduced anywhere; every correction is per-family
  material behavior (the prompt forbids hiding weak families globally).
  Gate wear side asymmetry lowers one rail only (complementary draw).
- Repetition audit: the two remaining fixed-frequency signatures (stain
  square-grid texture, gate wear sinusoid stripe) are gone; every texture
  is now smooth value noise / wrapped angular noise keyed by per-event
  streams; scratch wave sines gained a non-periodic wander term. No
  repeated stamps are possible (per-event `eventStream` draws).
- Family independence: five distinct family streams (plus per-side and
  per-direction substreams) are preserved; every family early-outs on its
  own density; cluster gains are family-local so no cross-family pulsing.
- Render-scale coherence: all event geometry (cells, lanes, slots, radii,
  noise lattices, pattern phases) is canonical; `antialiasWidth` appears
  only in smoothstep transitions and sub-pixel visibility floors. The
  identity path, debug views, extended-range RGB, and alpha handling are
  untouched; `FilmDamageMetalUniforms` ABI is unchanged (kernel-only
  changes; the Metal cache key was bumped to v2).

## Owner Visual Questions

1. Dust: is the ~4.5% chunk rate and the ragged-contour amplitude right for
   normal Filmtone settings, or should chunks be rarer/smaller?
2. Fibers: at moderate Amounts roughly one hair is present at a time — is
   the population, intrusion depth (up to the configured 90% of the relevant
   side-normal frame extent, with samples skewed shorter), and bounded tip
   tremble the intended character?
3. Scratches: does the 38/62 tramline/cinch lane split and the 4–9-frame
   tick cadence read as living grooves without feeling nervous at 24 fps?
4. Stains: does the rim-weighted drying-mark profile (faint 16–30% interior
   veil, warm lean) read as material on real footage, and is the defined
   outer edge too hard at high softness?
5. Gate wear: is the complementary side asymmetry (weak side down to 0.72)
   acceptable, or should both rails stay closer?
6. Clustering: are the dirt-burst windows (dust strongest, stains medium,
   scratches mild) noticeable on long takes without reading as a gimmick?

## Boundary Notes (no stop condition fired)

- Coordinator follow-up corrected two hidden local reinterpretations without
  changing the selected material design: cinch-like scratches now sample only
  inside `scratches.length`, and fibers apply `fibers.length` directly to the
  side-normal frame extent. If owner viewing later calls for values outside
  those ranges, the Filmtone mapping/contract boundary must be reopened rather
  than adding another feature-local multiplier.

- The generated recipe, adapter, mapping, and uniform ABI are consumed
  unchanged; all realization constants live in the kernel as before. The
  Metal realization's size interpretation intentionally differs from the
  8-bit CPU reference's larger radii — that was fixed in the accepted DAMAGE
  handoff as a Filmtone character decision and is retained.
- Scan-derived material remains rejected for licensing/boundary reasons; if
  the owner's visual pass still wants scan-grade silhouettes, the next step
  is a Filmtone-owned asset acquisition/generation spec, not external media.
- Native macOS/iOS kernels were used as read-only taste evidence; no native
  file was edited and no constants were copied verbatim.

## Changed Files

- `apps/filmtone-resolve-ofx/Sources/Effects/FilmDamage/FilmDamageMetalSource.h`
  (+738/-212; kernel-internal only, uniform struct and processor ABI
  untouched; cache key v1 -> v2)
- `docs/filmtone/davinci-plugin/workstreams/progress/film-damage-quality.md`
  (this record, new)

`git status --short` shows exactly these two paths; no other tracked file
changed and no owner change was removed.

## Verification Debt (explicit)

No build, compile, Metal compilation, Resolve launch, install, test, or image-
output verification was performed in the feature chat. Subsequent QUALITY
closure passed the combined C++/Objective-C++ build, exact embedded Damage
Metal compile, evaluation install/hash, Resolve restart, and exact registry
enumeration. Revised-source image output and owner visual proof remain.
