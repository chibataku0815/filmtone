# Workstream: Visual Quality And Acceptance

Document role: immutable workstream plan
Execution progress: [QUALITY progress](progress/visual-quality.md)
Runs last

## New Chat Start

Open this chat only after the integration handoff says all three modules render
through Resolve. Explicitly authorize the required builds, test files/tests,
local OFX installation, Resolve launch, and visual verification scope. Read the
Filmtone `AGENTS.md`, plugin `strategy.md`, `progress.md`, `delegation.md`,
every accepted handoff, this plan, and `progress/visual-quality.md`.

## Goal

Tune and validate the integrated effect as a Filmtone product, then decide
whether packaging/release work is justified. This is the first lane allowed to
spend broadly on QA because core behavior must already work.

## Context

Real-time playback is not required. The quality bar is deterministic output,
credible temporal/material behavior, practical stopped-frame adjustment,
CinePrint coexistence, and no hidden loss of wide-gamut or alpha information.

## Required Evaluation Matrix

Temporal:

- 23.976, 24, 25, 30, and 60 fps;
- sequential playback, backward scrub, random frame requests, cache rebuild,
  project reopen, and offline export;
- at least two explicit seeds and repeated renders of identical settings.

Image geometry and format:

- landscape, portrait, and non-square source aspect ratios;
- FHD and UHD, plus Resolve proxy/render-scale changes;
- translation/rotation maxima with edge safety on and off;
- alpha-bearing input if Resolve supplies it to the effect.

Color values:

- neutral ramp, saturated highlights, deep shadows, negative float values, and
  values above 1.0;
- host-managed Rec.709 and one scene-referred Resolve working-space workflow;
- no camera-profile inference inside the plugin.

Product combinations:

- Breath only, Weave only, every Damage family alone, and all modules together;
- CinePrint35 with its Gate Wv/Dust enabled versus disabled;
- CinePrint Grain and Halation retained while Filmtone does not duplicate them;
- normal Filmtone settings and deliberate stress settings.

## Visual Acceptance

Film Breath:

- continuous and mean-neutral;
- visible in motion without obvious periodic pumping;
- color movement does not dirty neutral highlights or clip saturated colors.

Gate Weave:

- mechanical rather than handheld-camera movement;
- subpixel motion does not soften detail unnecessarily;
- no black-edge flash with edge safety enabled;
- no repeating short loop visible at normal settings.

Film Damage:

- dark/neutral debris is primary;
- dust, fibers, scratches, stains, and gate wear remain distinguishable;
- scratches break, taper, and age rather than appearing as clean vector lines;
- artifacts have temporal life and do not become fixed screen dirt;
- white sparkle, obvious tiling, and repeated patterns fail acceptance.

CinePrint coexistence:

- the recommended companion setup has one Gate Weave owner and one Dust owner;
- no doubled movement or doubled dust density;
- negative/print color, grain, and halation remain CinePrint responsibilities.

## Performance Acceptance

- Record target Mac model, memory, Resolve version, timeline format, render
  scale, and module settings.
- Real-time playback is informational only.
- Provisional target: normal-strength UHD stopped-frame update median <= 500 ms
  on the owner target Mac.
- Stress settings may be slower but must not hang Resolve, leak GPU resources,
  or return nondeterministic output.
- Optimize only measured bottlenecks that affect product interaction or export;
  do not broaden into unrelated infrastructure.

## Expected Output

- Authorized verification results and reproducible environment details.
- Before/after and motion evidence sufficient for owner visual judgment.
- Tuning changes limited to the effect contract/profile surfaces that failed.
- A clear go / tune / block verdict per module and for CinePrint companion use.
- Packaging recommendation only after all product gates pass.
- Final Copy / History Impact, Article Opportunity, and remaining product risks.

## Non-Goals Until Visual Acceptance

- Installer, signing, notarization, licensing, sales, website, ASO, or release
  announcement.
- Broad repository cleanup or archival work.
- Windows/Linux support or Intel Mac support.
- Dehancer feature-count comparison.

## Stop Conditions

- A deterministic or wide-gamut invariant fails.
- Gate Weave produces unresolved black edges or unacceptable softness.
- Damage remains white-sparkle dominated or visibly tiled after three tuning
  attempts.
- Resolve crashes or the same authorized verification fails three consecutive
  times.
- Product acceptance would require adding input transforms, film stocks,
  print, grain, or halation to this effect.

## Handoff

Recorded in [QUALITY progress](progress/visual-quality.md).
