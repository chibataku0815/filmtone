# Filmtone for DaVinci Resolve — Film Damage Case Study

Status: candidate Behance article (pre-launch). Do not publish until owner
approval of public price, launch date, and compatibility scope is confirmed in
the monetization progress.md (coordinator-owned truth). The iOS / Desktop truth
scripts do not apply to this product.

Publication switch:

- Before launch: keep `adds`, `is built to`, `at launch` framing. Avoid
  `released`, `is available`, `we shipped`.
- After launch: confirm the case-study copy matches the public release notes,
  add the product-page / purchase links, insert the real visual assets, and
  remove any `candidate` qualifiers.

TOC policy: Behance case studies are scroll-based visual sequences and expose no
TOC widget. The H2 sections below (Cover, Project Summary, Problem, Design
Direction, Visual System Notes, Case Study Copy, Asset Checklist, Publish Guard,
External Links) are production checkpoints for the layout, not reader
navigation. Do not add a TOC, and do not rename or number these headings — they
map to Behance project blocks.

Asset note: the visual assets for this case study (before/after crops,
proxy-vs-export comparisons, the parameter panel) require rendered frames from
DaVinci Resolve and are not produced in this draft. Every `[ ]` below is a
placeholder to be filled with a real asset before publishing.

## Cover

Title:

```text
Filmtone: Film Damage for DaVinci Resolve
```

Subtitle:

```text
Filmtone for DaVinci Resolve is a small OpenFX plugin that adds film damage to a grade inside DaVinci Resolve. This case study covers how it renders dust, fibers, scratches, stains, and gate-edge wear as physical, repeatable marks that land in the same place on the proxy and the export.
```

Suggested cover visual:

- Split frame: a clean grade on one side, the same grade with restrained film damage on the other (a little dust, one hair at the frame edge, a faint scratch).
- Small UI crop of the Film Damage control group and the read-only `License` `Status` line.
- Caption the damage side `material-dependent` — do not imply every shot needs it.

## Project Summary

Filmtone for DaVinci Resolve adds film damage on top of a finished grade — it does not change color. Drop it on a clip or Color node and it composites five families of wear: dust, fibers (a hair in the gate), scratches, stains, and gate-edge wear.

Two ideas define it:

- **Physical, not uniform or random.** Dust is mostly small and dark with rare chips; scratches break up and taper; hairs anchor at the edge and tremble. The bias matches how film actually wears.
- **Repeatable.** Given the same settings and the same point in time, it renders the same damage every pass, and the proxy and the full-resolution export agree.

It is a one-time purchase, with a permanent no-signup watermarked trial and a 14-day clean trial, so an evaluation can go all the way to a real delivery.

## Problem

Reaching for a film-damage overlay usually introduces three tells at once:

- The dust jumps to a new position every frame and flickers.
- A scratch sits on a dark shot like a sticker on glass — an additive overlay, not part of the image.
- The marks placed on a proxy resolve elsewhere in the full-resolution export, so the approved version is not the delivered one.

There is a commercial problem too: the nearest equivalent tool for this kind of work is sold subscription-only, which is a lot of standing cost for an effect used a few times a year.

Both problems show up at the finish — exactly where the picture is supposed to be locked.

## Design Direction

The direction was to make damage read as physical and stay reproducible, and to keep the surface honest.

- **Physical bias.** Dark marks lead; bright sparkle stays rare and subordinate. Silhouettes are ragged, sizes are skewed, scratches carry a scuffed edge, stains deposit at the rim, gate wear is asymmetric side to side. Gate-edge wear is deliberately not a vignette.
- **Determinism by construction.** Artifact placement lives in normalized coordinates, decoupled from render scale, so proxy and export match and re-renders are identical — while lifetimes, fades, and stepped micro-instability keep the marks alive rather than frozen.
- **Adds wear, not color.** The plugin has one job on top of the grade. No color transform, no new color decisions.
- **Offline by design.** Licensing is a local signed-file check with no network code; the only email involved is a trial request.

## Visual System Notes

Suggested case-study sections (each maps to a Behance image block):

1. **The Five Families**
   - One clean crop per family at a moderate amount: dust, fibers/hairs, scratches, stains, gate-edge wear.
   - Caption each with its physical note (e.g. `hair anchored at the frame edge`, `rim-weighted drying mark`).

2. **Before / After on a Real Shot**
   - Full-frame clean grade vs the same grade with restrained damage.
   - Prefer a darker, quieter shot where wear reads clearly. Caption `material-dependent`.

3. **Proxy vs Export**
   - Same frame at proxy and at full resolution, side by side, showing the dust and scratches in the same positions.
   - This is the core differentiator — give it a full-width block.

4. **Same Frame, Rendered Twice**
   - Two exports of the identical frame overlaid or diffed, showing the damage is reproducible, not re-rolled.

5. **Dark-Led Polarity**
   - A crop on a bright and a dark region showing marks read as dark wear, not additive white sparkle.

6. **Control Panel**
   - The Film Damage control group with per-family amounts, and the read-only `License` `Status` line.

## Case Study Copy

Filmtone for DaVinci Resolve adds film damage to a grade inside DaVinci Resolve — dust, fibers, scratches, stains, and gate-edge wear — without changing color. It renders damage the way film actually wears: dust mostly small and dark with rare chips, scratches that break up and taper, a hair that anchors at the frame edge and trembles, drying stains deposited at an irregular rim, and asymmetric gate-edge wear. Dark marks lead; bright sparkle stays rare.

The property that makes it usable in a finish is repeatability. Every mark is placed in normalized coordinates, decoupled from render scale, so the proxy you grade on and the full-resolution file you deliver show the same damage in the same place. Render the same point in time again with the same settings and the result is identical. It is not static — scratches shimmer, dust clusters swell and fade, hair tips flutter — but that life is driven by time, not by a fresh dice roll each frame, and there is no visible tiling at UHD.

It is a one-time purchase where the nearest equivalent tool is subscription-only. Without a license the plugin runs fully, with a visible trial watermark on the output — no signup, evaluate any time. A 14-day clean trial, requested by email, removes the watermark so you can take one real job to delivery before deciding. The effect is material-dependent: not every shot wants damage, and the right amount changes with the cut.

## Asset Checklist

- [ ] Cover split frame: clean grade vs restrained film damage.
- [ ] Five per-family crops: dust, fibers/hairs, scratches, stains, gate-edge wear.
- [ ] Full-frame before/after on a real shot (darker/quieter cut).
- [ ] Proxy vs full-resolution comparison showing identical mark placement.
- [ ] Same-frame-rendered-twice comparison (or diff) showing reproducibility.
- [ ] Dark-led polarity crop (bright vs dark region).
- [ ] Film Damage control-group screenshot with the `License` `Status` line.
- [ ] Remove all unchecked placeholders before publishing.

## Publish Guard

Before publishing (this product's gate — the iOS / Desktop truth scripts do not
apply, and no Bash is used here; grep is the mechanical check):

- confirm owner approval of public price, launch date, and compatibility scope
  in the monetization progress.md;
- keep compatibility to the measured pair only — macOS 26.5.1 with DaVinci
  Resolve Studio 21.0.2 — never a `macOS 14.0+` or `Resolve 21.x` floor;
- add the product-page / Polar purchase and trial links;
- add the actual visual assets and remove every unchecked asset placeholder;
- keep positioning at function level — no competitor names, no quality-parity
  implication, no market-wide "subscription-only" claim.

## External Links

Product page and purchase / trial links (Polar) are added here at launch:

```text
〔product page / Polar checkout — TBD〕
```

When publishing on Behance, add the product-page URL to the project's external
link / description field once it is confirmed.
