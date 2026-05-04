# Active: M5-B Apple Liquid Glass Visual Smoke (Pass 1 + Pass 2)

Date: 2026-05-04 JST
Milestone: M5 (slice M5-B)
Type: User-driven visual smoke (no implementation work)

## Why this slice

Pass 1 (commit `f7ee950`) migrated three floating control panels from
`.regularMaterial` to `.glassEffect(.regular, in: …)`. Pass 2 (commit
`e603067`) wrapped the right-rail VStack in `GlassEffectContainer` so the
three panels refract as one cohesive Apple Liquid Glass surface, and the
toolbar / window chrome audit confirmed macOS 26 default Apple Liquid
Glass chrome is in force without explicit opt-in.

Both passes shipped without visual validation by design (build clean,
Swift 6 strict concurrency clean, CLI smoke physically non-applicable
to a SwiftUI material change). This active slice closes that gap by
running an actual visual smoke against bright + dark preview backdrops
before any Pass 3 (tint / variant exploration) is opened. Doing tint
work before validating the `.regular` base posture risks tuning against
unverified ground truth.

## Scope

User runs the rebuilt `.app`, loads at least one bright-content source
and one dark-content source, and confirms each visual checkpoint below.
No code or doc edit by the agent until smoke result lands.

The `.app` binary at
`apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app`
was rebuilt 2026-05-04 12:16 JST after Pass 2 commit `e603067` and
contains both Pass 1 and Pass 2 changes.

## Launch

```bash
open /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
```

## Source materials

- **Bright backdrop**: any high-key still or video — sky, snow, beach, white
  studio. The whole frame should be near-white so the right-rail panels sit
  on a bright surface and refraction is most visible. User-provided via
  `Cmd+O` Open dialog.
- **Dark backdrop**: any low-key still or video — night scene, shadow, black
  studio. The whole frame should be near-black so the panels sit on a dark
  surface and the rim/edge highlight of Apple Liquid Glass is most visible.
  User-provided via `Cmd+O`.
- **Optional video probe** (for the bottom-center scrub bar): any of the
  bundled synthetic 1-second clips at
  `apps/desktop-film-lab-batch/fixtures/video/sdr/synthetic-bt709-1s-20260424.mp4`
  is sufficient — content is uniform but the scrub bar's standalone Liquid
  Glass posture is what's being judged, not the frame content.

## Visual checkpoints

| ID | What to look at | Expected (Pass 1) | Expected (Pass 2) |
|---|---|---|---|
| V1 | Top-right `GlassControlGroup` (Open / Export buttons, Look picker) | Apple Liquid Glass capsule (was already Liquid Glass pre-Pass-1; baseline reference) | Same shape, but visibly belongs to the same refraction system as V2 / V3 below |
| V2 | Top-right `GradeControls` panel (preset name, strength slider) — visible after a source is loaded | Apple Liquid Glass rounded rect (was `.regularMaterial` pre-Pass-1) | Refracts in coordination with V1 above when content moves underneath; does not look like an independent disc |
| V3 | Top-right `ExportProgressBar` panel — visible only during an active export | Apple Liquid Glass rounded rect (was `.regularMaterial` pre-Pass-1) | When it appears mid-export, joins V1 + V2 as part of the same coordinated refraction surface, not a third disconnected lens |
| V4 | Bottom-center `VideoScrubBar` (visible only with a video source) | Apple Liquid Glass rounded rect (was `.regularMaterial` pre-Pass-1) | Standalone — intentionally not part of the right-rail container; should look like a single isolated lens, not coordinated with the right-rail |
| V5 | Window toolbar (camera-aperture icon, Open, Export buttons in the title-bar row) | macOS 26 default Apple Liquid Glass — translucent, bright/dark backdrop visible underneath | (no Pass 2 delta) |
| V6 | Traffic-light buttons + window background frame | macOS 26 default Apple Liquid Glass chrome | (no Pass 2 delta) |

## How to read each checkpoint

For each of V1–V6, do the smoke against **both** the bright source (high-key
still / video) and the dark source (low-key still / video). Move the window
so the panel of interest sits over varying content underneath if possible
(drag the window across the desktop to slide background colour through it).

The base posture being validated is `.glassEffect(.regular, in: <Shape>)`.
What "looking right" means in plain terms: translucent, light-bending,
clearly distinct from the flat frosted-pane look of `.regularMaterial`.
Edges should pick up a thin specular rim. Content underneath should warp
slightly at the panel boundary (refraction), not just dim through frost.

For V2 / V3 specifically (Pass 2 coordination): when content moves
underneath one of them, the refraction in adjacent panels should respond
as part of the same lens system, not as three independent surfaces.

## Exit criteria

- All six checkpoints pass on **both** bright and dark backdrops →
  agent archives this active slice and updates strategy.md Current State
  to mark M5-B base-posture validation done. Pass 3 (tint / variant
  exploration) becomes a candidate for the next active.md.
- Any checkpoint fails on either backdrop → user reports which `Vn`
  failed and what was observed; agent triages whether the failure is
  (a) a Pass 1 / Pass 2 implementation bug, (b) a macOS 26 / hardware
  rendering quirk, or (c) an expectation mismatch in this active.md.
  No Pass 3 work is opened until the failure is resolved.

## Stages

| Stage | Owner | Action |
|---|---|---|
| S1 | Agent | Rebuild `.app` so it contains Pass 1 + Pass 2 (done 2026-05-04 12:16 JST) |
| S2 | Agent | Author this active slice and commit (in progress) |
| S3 | User | Launch `.app`, run V1–V6 against bright + dark sources, report result |
| S4 | Agent | If pass: archive + strategy log. If fail: triage and propose follow-up active slice |

## Out of scope

- Tint / variant exploration (`.tinted` / `.identity` / `.clear`) — Pass 3,
  blocked on this slice's exit.
- Sidebar / inspector panels — those surfaces do not yet exist in the
  current product layout.
- Performance measurement of the new `GlassEffectContainer` — only
  validated qualitatively here. If a perceptible scroll/render hitch
  appears during smoke, capture it as Unexpected and triage separately.
- Any iOS work — iOS lane is untouched per strategy constraints.
- Electron Desktop — unrelated rail.

## Unexpected / Follow-up

(empty — populated by user smoke result and agent triage)
