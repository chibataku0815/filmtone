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

### 2026-05-04 user smoke result: V1–V6 base posture FAIL — 4 substantive findings

User ran S3 against the rebuilt `.app` and surfaced 4 distinct issues. The
base `.regular` posture without the surrounding chrome opt-in does not
deliver Apple Liquid Glass — it falls back to a `.regularMaterial`-shaped
frosted pane. Pass 3 (variant exploration) is now strictly blocked behind
fixing this base setup; tinting a still-broken base does not help.

| # | User report | Root cause (verified vs SDK swiftinterface) | Fix |
|---|---|---|---|
| F1 | "プリセットは必要ない" — Preset row in `GradeControls` is redundant alongside the Look picker | Vocabulary lock landed; Look-tier is now the SSOT; Preset has been internally pinned to `reset` whenever a Look is selected, so the row only matters in the unused "no Look" mode | Remove the Preset Picker from `GradeControls`. Keep Look + Strength only. Internally `state.presetName` stays at `defaultName`. |
| F2 | "Apple Liquid Glass ではなく、ただの磨りガラスのようなもの" — panels look frosted, not refractive | macOS 26's `.glassEffect(.regular, in:)` reads as frosted material when there's no extended content beneath it. The system needs the underlying content layer to extend into the toolbar / chrome region (`backgroundExtensionEffect()`) so the glass has something visually rich to refract. Without that, both Pass 1 panels and the system chrome read as flat material. | Apply `.backgroundExtensionEffect()` to `PreviewSurface` so it extends into the toolbar / window-edge region. Add `.tint(...)` to the right-rail glass to nudge edge specularity. |
| F3 | "ヘッダー部分も Apple Liquid Glass になっていない" — toolbar is opaque white, not translucent | `WindowGroup` currently inherits `DefaultWindowToolbarStyle` (`.automatic`). On macOS 26, the unified Apple Liquid Glass toolbar requires explicit opt-in via `.windowToolbarStyle(.unified)` or `.unifiedCompact`. Without it, the toolbar paints as a solid bar. | Add `.windowToolbarStyle(.unified)` to `WindowGroup` in `FilmtoneDesktopApp`. |
| F4 | "スクラブの位置もおかしい" — bottom-center scrub bar overlay reads as floating in the preview area, awkwardly placed | Scrub bar is overlaid inside the `ZStack` with `Spacer() + .padding(20)`, sitting too far above the window's bottom edge and visually disconnected from the preview boundary. With the new `backgroundExtensionEffect`, the scrub bar should sit naturally near the bottom chrome edge. | Tighten bottom padding (`.padding(.bottom, 12)`) and let the inner `.frame(maxWidth: 560)` keep horizontal containment but allow the scrub bar to sit closer to the window edge as a chrome-adjacent control. |

### F1–F4 implementation plan

1. **`GradeControls.swift`** — remove the Preset `Picker`, drop
   `presetDisabled` / related opacity, simplify `strengthDisabled` to
   "disabled when Look = None" (since the Reset preset path is no longer
   user-selectable).
2. **`FilmtoneDesktopApp.swift`** — `.windowToolbarStyle(.unified)` on
   `WindowGroup`.
3. **`RootWindowView.swift`** —
   - Add `.backgroundExtensionEffect()` on the `ZStack` (or the
     `PreviewSurface`) so content extends into chrome.
   - Switch `.glassEffect(.regular, in: …)` to
     `.glassEffect(.regular.tint(.white.opacity(0.06)), in: …)` to give
     edges visible specularity without changing the underlying neutrality.
   - Move `VideoScrubBar` overlay closer to the window bottom edge via
     `.padding(.bottom, 12)` instead of the wrapping `.padding(20)`.

### F1–F4 stages

| Stage | Action |
|---|---|
| F-S1 | Edit `GradeControls.swift` (F1) |
| F-S2 | Edit `FilmtoneDesktopApp.swift` (F3) |
| F-S3 | Edit `RootWindowView.swift` (F2 + F4) |
| F-S4 | Rebuild `.app` |
| F-S5 | Single bundled commit (per `feedback_dont_overengineer_dirty_state_split` — these four findings are one product-quality fix) |
| F-S6 | Re-launch and request user re-smoke against the same V1–V6 + the four findings |

Pass 3 (tint / variant exploration beyond `.tint(.white.opacity(0.06))`)
remains deferred until the F-cycle smoke validates the corrected base
posture.

### 2026-05-04 F-cycle re-smoke result: F2/F3/F4 visual non-effect — true root cause identified

User ran F-S6 re-smoke against fresh build (12:28 JST, commit `1f4d4db0`).
F1 (Preset row removed) ✅ visible. F2 / F3 / F4 visual effects reported
as **almost no visible change** vs pre-F-cycle build. Triage in the prior
table identified candidate causes; ground truth obtained via Apple
Landmarks sample (`developer.apple.com/.../Landmarks-Applying-a-background-extension-effect`)
+ official `View.backgroundExtensionEffect()` reference + community
Liquid Glass references shows the **real** root cause is architectural,
not API-call-shape:

**`PreviewSurface` rendered the source image via `NSViewRepresentable`
wrapping `NSImageView`.** SwiftUI's Liquid Glass refraction system
(`.glassEffect`, `.backgroundExtensionEffect()`, unified toolbar
chrome) samples pixels from the SwiftUI render tree to compute
lensing. NSViewRepresentable content is **opaque** to that sampler:
the Liquid Glass code sees no content beneath it and falls back to a
flat material appearance. This explains the symptom set in one stroke:

- Toolbar reads as solid white because there is no SwiftUI-visible
  content extending into the chrome region for it to refract.
- Right-rail panels read as frosted because `.glassEffect` cannot
  sample the NSImageView pixels under them — same fallback.
- `.backgroundExtensionEffect()` applied to PreviewSurface had no
  observable effect because Color.black was the modifier's actual
  target (the modifier mirrors and blurs the receiver into the safe
  area; black-on-black mirroring is invisible).

Apple's verbatim Landmarks pattern is `Image(...).resizable().scaledToFill().backgroundExtensionEffect()` —
the modifier expects to receive an `Image` view as the content to
extend, not a surrounding container.

### F-S6.1 fix (real)

Refactor `PreviewSurface` to render via SwiftUI `Image(nsImage:)`
instead of `NSViewRepresentable`/`NSImageView`. Pipeline (URL →
CIImage → grade → CGImage → NSImage) preserved verbatim, but final
display step is a SwiftUI Image with `.resizable().scaledToFill()
.clipped().backgroundExtensionEffect()`. Rendering moved into a
`@State private var renderedImage: NSImage?` driven by `.task(id:)`
so source / preset / scrub-bar updates re-render. Heavy CIImage work
runs in `Task.detached(priority: .userInitiated)` to keep the main
actor responsive.

Side effect: removes the duplicate `.backgroundExtensionEffect()` call
on PreviewSurface in `RootWindowView`, since the modifier is now
attached to the actual sampleable Image inside.

### F-S6.1 stages

| Stage | Action |
|---|---|
| F-S6.1-A | Refactor `PreviewSurface.swift` to SwiftUI Image(nsImage:) (done) |
| F-S6.1-B | Remove duplicate `.backgroundExtensionEffect()` on PreviewSurface in `RootWindowView` (done) |
| F-S6.1-C | Build clean, Swift 6 strict concurrency clean (`** BUILD SUCCEEDED **`, only pre-existing CI deprecation warnings) |
| F-S6.1-D | Re-launch fresh `.app` (done — PID confirmed) |
| F-S6.1-E | User re-smoke against same V1–V6 + F1–F4 expectations |
