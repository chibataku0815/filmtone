# M5-B Apple Liquid Glass Adoption (Pass 2)

Date: 2026-05-04 JST
Milestone: M5
Classification: Continuation — Pass 1 follow-up (`GlassEffectContainer`
grouping + chrome audit)
Status: In progress
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

## Why

Pass 1 (commit f7ee950) migrated each floating panel's material to
`.glassEffect(.regular, in: …)`. Each panel now refracts independently,
which on macOS 26 produces three uncoordinated lens surfaces in the
right-rail stack (`GlassControlGroup` + `GradeControls` +
`ExportProgressBar`). Apple's intended posture for nearby/grouped glass
shapes is `GlassEffectContainer`, which coordinates refraction across
its children so they read as one cohesive glass system rather than
three disconnected lenses. Pass 2 lands that grouping where it actually
helps (the right rail) and documents the toolbar/window chrome posture
so the Liquid Glass adoption story is complete on visible surfaces.

## Scope (本質, Pass 2)

- Wrap the right-rail VStack in `GlassEffectContainer` so
  `GlassControlGroup` / `GradeControls` / `ExportProgressBar` refract
  as a coordinated set. Spacing on the inner VStack stays 12pt; the
  container does not add layout, only refraction coordination.
- Document the toolbar / window chrome posture in `strategy.md`:
  macOS 26 auto-applies Apple Liquid Glass to standard `WindowGroup`
  chrome (toolbar + traffic lights + window background) without
  explicit modifiers. The current `FilmtoneDesktopApp` declares no
  custom `windowToolbarStyle` or `toolbarBackground`, so the system
  default is in force.
- The bottom-center `VideoScrubBar` is a single-panel surface in its
  own overlay; `GlassEffectContainer` is for coordinating multiple
  nearby glass shapes, so a single-child container would be no-op.
  Decision: leave it standalone, revisit only if a sibling glass
  surface is added to the bottom region.

## Out of scope (外殻 / later)

- Tint / variant exploration (`.tinted` / `.identity`) — deferred
  until base posture has user visual smoke. Doing tint before smoke
  risks tuning against unverified base appearance.
- New sidebar / inspector design — none currently exist; out of any
  Liquid Glass slice until those surfaces are introduced.
- `EmptyPreviewLabel` glass treatment — preview content layer is
  intentionally glass-free per strategy, and the empty label sits on
  that backdrop. Borderline but per-spec excluded.
- iOS surface — untouched.
- Export / pipeline logic — untouched.
- `ContentView.swift`-style preference panes — none in this app.

## Stages

- [x] S1 — Wrap the right-rail `VStack(alignment: .trailing, spacing: 12)`
  body in `GlassEffectContainer { … }` in `RootWindowView.swift`.
  Preserve all existing children, padding (`.padding(20)`), and
  conditional rendering. **Done** — `RootWindowView.swift:19-37`.
- [x] S2 — Build via `xcodebuild` → `BUILD SUCCEEDED` under Swift 6
  strict concurrency. **Done** — exit 0,
  `** BUILD SUCCEEDED **`. `GlassEffectContainer` resolves on
  macOS 26 SDK without imports beyond the existing `import SwiftUI`.
- [x] S3 — Strategy doc updated. Toolbar / window chrome posture
  recorded: `FilmtoneDesktopApp` declares only `WindowGroup` +
  `windowResizability(.contentMinSize)` and no explicit
  `windowToolbarStyle` / `toolbarBackground`, so macOS 26's default
  Apple Liquid Glass chrome is in force. Visual confirmation deferred
  to user.
- [x] S4 — Commit. One feat (code) + one docs (archive + strategy log).

## Stage granularity

- S1 ~5 min
- S2 ~10 min
- S3 ~5 min
- S4 ~5 min

Total ≈ 25 min.

## Invariants

- Grade pipeline + sidecar + export paths: zero behavioural change.
  Pass 2 is a SwiftUI view-tree wrap; it does not touch any file the
  CLI grade pipeline reaches (rationale identical to Pass 1 S5 skip
  — Electron CLI is in TS/JS, separate process, separate package).
- Existing `.glassEffect(.regular, in: …)` modifiers on each panel are
  preserved verbatim. The container coordinates refraction; it does
  not replace per-panel materials.
- Spacing 12pt between right-rail children preserved.
- `.padding(20)` outer offset on the right-rail VStack preserved.
- Bottom-center `VideoScrubBar` overlay remains standalone (single-child
  container is a no-op; intentional).
- `RootWindowView.swift` is the only Swift file modified.

## Unexpected

(filled during implementation)

## Follow-up

- Pass 3 candidate: tint / variant exploration (`.tinted` /
  `.identity`) once user visual smoke confirms `.regular` base posture
  on both bright and dark preview backdrops. Tint before smoke is
  premature.
- Pass 3 candidate: revisit the bottom scrub region if a sibling glass
  surface (e.g. transport controls, in/out markers) is introduced —
  that would justify a `GlassEffectContainer` there too.
- Visual smoke deferred to user: confirm right-rail panels read as one
  cohesive glass surface (refraction coordinated) rather than three
  independent lenses; confirm toolbar / traffic lights render as
  Apple Liquid Glass under macOS 26 default chrome.

## Result

M5-B Pass 2 implementation complete.

**Diff surface**: single file, `RootWindowView.swift`, single
structural wrap. `GlassEffectContainer { … }` now wraps the right-rail
`VStack(alignment: .trailing, spacing: 12) { … }` body. Per-panel
`.glassEffect(.regular, in: …)` modifiers preserved verbatim; spacing,
conditional rendering, and outer `.padding(20)` preserved.

**Refraction posture**: the three right-rail surfaces
(`GlassControlGroup` / `GradeControls` / `ExportProgressBar`) now
refract as a coordinated set per Apple's `GlassEffectContainer`
contract for nearby Apple Liquid Glass shapes.

**Bottom scrub region**: `VideoScrubBar` left standalone — single-child
container is a no-op, intentional. Recorded for revisit if a sibling
glass surface is added later.

**Toolbar / window chrome audit**: `FilmtoneDesktopApp` (`App/FilmtoneDesktopApp.swift:30-44`)
declares only `WindowGroup("Filmtone Desktop")` +
`.windowResizability(.contentMinSize)` and no explicit
`windowToolbarStyle` / `toolbarBackground` / window-chrome modifier.
On macOS 26 the system default delivers Apple Liquid Glass for
toolbar + traffic lights + window background without any opt-in
modifier, so the current source already matches the strategy
Done Condition. No code change needed; visual confirmation deferred
to user.

**Build evidence**: `xcodebuild -project FilmtoneDesktop.xcodeproj
-scheme FilmtoneDesktop -configuration Debug -destination 'platform=macOS'
build` → exit 0, `** BUILD SUCCEEDED **`. Swift 6 strict concurrency
clean.

**Commit**: see follow-up commit hash.

**Deferred to user**: visual smoke confirming (a) right-rail panels
read as a coordinated glass system rather than three independent
lenses, and (b) toolbar + traffic lights render as Apple Liquid Glass
under macOS 26 system defaults.

**Pass 3 candidates** (Follow-up): tint / variant exploration
(`.tinted` / `.identity`) once visual smoke validates `.regular`
posture; revisit bottom-scrub region if sibling glass is added.
