# Archived: M13-M-1 — Cockpit Layout Shell + Selected Pill Fix

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **archived — partial PASS, superseded by M13-M-2 before owner acceptance**

## Archive verdict (2026-05-09)

Cockpit shape, preview ownership, and selected-pill correctness landed
on iPhone 17 Pro #7. Owner walk surfaced two material-quality gaps that
M13-M-1 did not anticipate, blocking acceptance:

1. **Corner radii read as too round** — `Capsule()` on parameter chips,
   lens chips, and the top HUD pill produced pill silhouettes; the
   bottom shelf at `cornerRadius: 26` read as a soft slab. Pro camera
   surfaces (Halide / Blackmagic / ARRI) use angular rounded rectangles
   ~6-10pt for chips; Capsule is reserved for affordances that strongly
   imply "tappable text only" (e.g. system status pills).
2. **Material reads as plain frosted glass, not Apple Liquid Glass** —
   the bottom shelf `captureGlassRail` wraps a large surface that the
   chip rows and shutter cluster sit on top of. Glass-on-glass collapses
   the per-edge specular / refraction signature into one flat haze. The
   `selectedGlassTint = white.opacity(0.18)` is also more opaque than
   Apple HIG's tint-as-hint pattern, drowning the refraction the
   selected chip should still show.

M13-M-2 carries the cockpit composition forward unchanged and rebuilds
the material layer + per-component shape vocabulary on top of it. The
former M13-M-1 sub-task chain (M13-M-3 ruler wiring, M13-M-4 mode
toggles, M13-M-5 owner walk) is preserved and slid one step back.

(Below is the original M13-M-1 active.md content for traceability.)

---

## Original active.md content

### Title

Active: M13-M-1 — Cockpit Layout Shell + Selected Pill Fix

Status (at active time): **scoped — owner approved cockpit pivot 2026-05-09 with locked decisions**

## Owner-locked decisions (2026-05-09)

1. **Look placement** — Look chip lives in the **top parameter row**, not
   in a fixed bottom horizontal row. Tap opens a picker **structured as a
   Sheet** so it scales beyond the 3 built-in entries (Filmtone / Stone /
   Urban) to future saved Looks and arbitrary loaded LUT files. Look is
   not frequently changed at capture time, so the bottom chip-row real
   estate is reserved for lens (which IS frequent).
2. **Ruler scrubber position** — expands **directly below the active
   parameter chip** in the top row (Blackmagic pattern). One-thumb reach
   to the top is acceptable because parameter selection is occasional;
   the visual link between active chip and scrubber matters more than
   thumb travel.
3. **Continuous lens zoom (`videoZoomFactor`)** — out of M13 scope.
   Discrete lens chips in the bottom row are sufficient. Defer to a
   later capture-controls lane.

## Why this active exists

M13-L superseded before owner acceptance: the atmosphere-first vertical
rail composition did not exceed the 65 % owner read, and selected pills
overflowed their rail capsule, and the preview was cropped above the
shelf leaving a dominant black band on the lower half of the screen.
Owner pivoted UI direction to a Blackmagic-style parameter cockpit:
preview as the stage, top parameter row with single-active ruler
scrubber, horizontal lens chip row, quiet shutter on a compact bottom
shelf.

M13-L's Liquid Glass primitives (`captureGlassRail`, `captureGlassControl`,
`captureGlassHUD`, `captureGlassSelected`) and the rebuilt
`FilmtoneCaptureTopStatusBar` are retained as the material vocabulary —
M13-M does not re-derive Liquid Glass; it rebuilds **spatial composition**
on top of those primitives.

## M13-L Failure Summary (preserved here for continuity)

- Selected look / lens pill rendered as a non-glass `Capsule` background
  inside a glass rail. The pill's frame did not match the rail's clip
  shape, so the selected segment **overflowed the rail capsule** —
  visible at `apps/.../FilmtoneCaptureView.swift:434-501`. This must be
  fixed in M13-M-1: selected = same-shape tint pass on the **rail's
  geometry**, not a separate inner shape.
- Bottom shelf occupied ~28 % of screen height; preview was sized
  proportionally above and shrank to ~50 % of the screen, leaving a
  dominant black band between the shelf and the actual preview.
  Investigation in M13-M-1 will confirm whether `previewLayer` itself is
  short or whether layout is reserving space for the shelf via
  `Spacer()`. Either way: preview must visually own the entire screen.
- Atmosphere-first composition did not differentiate Filmtone from
  generic Liquid Glass apps. Cockpit pivot reframes the surface around
  parameter access density.

## Cockpit reference (Blackmagic Camera, owner-provided 2026-05-09)

Reference structure (do not copy branding / iconography):

- **Top parameter row** — レンズ / FPS / シャッター / IRIS / ISO / WB /
  Tint as compact chips with current value beneath the label. Tapping a
  chip activates it (one chip active at a time). The active chip
  expands a **horizontal ruler scrubber** below the row showing the
  current value with center-pinned indicator and tick marks.
- **Histogram + audio meter** — overlay on lower-left / lower-right of
  preview (out of M13-M scope; deferred to a later honest-preview lane).
- **Lens chip row** — horizontal row at the bottom (above shutter)
  with focal-length pills (13mm, 24mm, 48mm, ...) using the existing
  M12 `FilmtoneCaptureLensCatalog.magnificationLabel`. Active chip is
  highlighted via `captureGlassSelected`.
- **Bottom controls** — shutter (center, quiet), folder pick (left),
  folder clear (right). Already on M13-L's bottom shelf — M13-M keeps
  the shelf shape and primitive but reduces footprint and adds the
  lens chip row above it.

Filmtone-specific differences (do **not** match Blackmagic 1:1):

- **Look chip row** — Filmtone-only concept (Filmtone / Stone / Urban).
  Either as a chip in the top parameter row (active = expand horizontal
  Look chip strip below) or as a fixed horizontal Look chip row above
  the lens chip row. M13-M-1 adopts the **fixed horizontal Look chip
  row** approach to keep Look one tap away (Look is the primary
  Filmtone differentiator and should not require a parameter-row tap).
- **No FPS / IRIS chips** — FPS is locked at 24 (M10 contract); IRIS is
  fixed by iPhone hardware (no aperture control). These appear in the
  HUD readout (`Internal 10s | 4K24 · Log2 · ProRes`) but are not
  scrubbable and have no chip in the parameter row.
- **No Tint chip** — M12 does not expose a chromaticity / tint
  setter on `FilmtoneCaptureSession`. Deferred to a later capture
  controls lane.

## M13-M-1 Scope (this active)

Layout shell only. **No ruler scrubber wiring.** The chips render
correctly, are tappable, show current values, and surface the active
state — but tapping does not yet swap to a scrubber view (deferred to
M13-M-2). Acceptance is whether the layout reads as a cockpit and the
two M13-L bugs are gone.

### Spatial composition

```
ZStack {
  preview.ignoresSafeArea()                 // hero, owns 100 % of screen
  interactionOverlay                         // tap-to-focus (M12, unchanged)
  GlassEffectContainer(spacing: 8) {
    VStack(spacing: 0) {
      topZone                               // safe-area top
      Spacer()
      bottomZone                             // safe-area bottom
    }
  }
  failureOverlay / diagnosticOverlay
}
```

**topZone**:
- Row 1: close circle + storage HUD capsule + quality contract chip
  (existing `FilmtoneCaptureTopStatusBar`, kept as is).
- Row 2 (NEW): parameter chip row — chips for `ISO`, `Shutter`, `EV`,
  `WB`, `Look` (5 chips, Lens is NOT here — it lives in the bottom
  chip row because lens swap is frequent). Each chip is its own Liquid
  Glass capsule rendered inside a shared `GlassEffectContainer` so the
  chips merge as adjacent shapes, not stacked materials. Each chip
  shows a small label and a larger current value. Active chip uses
  `captureGlassSelected` tint pass on the same capsule shape (no inner
  pill — fixes M13-L overflow).
- Row 3 (NEW, conditional): inline ruler placeholder beneath the
  active chip's column. **In M13-M-1 the ruler is a stub** (empty
  rounded rect) — it expands when an ISO / Shutter / EV chip is
  active just to prove the layout reserves space and animates in.
  Real ruler scrubber primitive comes in M13-M-2.

**bottomZone**:
- Row 1 (NEW): Lens chip row — horizontal `GlassEffectContainer`
  containing one capsule per available lens (`lens.magnificationLabel`).
  Selected = `captureGlassSelected` tint pass. Hidden when
  `lenses.count <= 1`. Replaces the M13-L vertical lens rail.
- Row 2 (kept, slimmed): shutter shelf with folder pick, shutter,
  folder clear. Reduce shelf vertical inset (`shelfTopInset` 12 → 8,
  `shelfBottomInset` 14 → 10). Status text stays above the shelf
  (M13-L treatment retained).

**Look picker (Sheet)**:
- Tap on the `Look` chip in the top parameter row presents a
  `.sheet(isPresented:)` with a vertical list of available Looks.
  M13-M-1 ships with the 3 built-in entries (Filmtone / Stone / Urban)
  rendered as a simple List inside the sheet. The Sheet container
  pattern is forward-compatible with future saved Looks and
  user-loaded LUT files — those entries will append to the same list
  in a later capture-Look lane (out of M13 scope).
- Sheet is dismissible by drag down or tap outside. Selecting a Look
  applies it via the existing `captureLookSelection` state path so
  live preview rebuild + package persistence (M11) keep working
  unchanged.

### Selected-pill fix (the M13-L bug)

Single rule: **selected = `captureGlassSelected(in: Capsule())` on the
same capsule used by the rail's segment**, not a `Capsule().background`
inside a different glass rail capsule. Implementation pattern (pseudocode):

```swift
// Wrong (M13-L): pill overflows because the inner Capsule's frame
// does not match the rail's clip path.
HStack { Text(...).background(selectedTint, in: Capsule()) }
  .background(rail glass, in: Capsule())

// Right (M13-M-1): the row uses a single GlassEffectContainer; each
// chip is its own Liquid Glass shape that morphs between idle and
// selected via tint, all inside the same container so they merge.
GlassEffectContainer {
  HStack {
    ForEach(chips) { chip in
      Text(chip).captureGlassSelected/Idle(in: Capsule())
    }
  }
}
```

The container's `spacing:` controls how close adjacent chip shapes can
get before the material merges. For chip rows, target ~6 pt so chips
read as distinct pills without floating glass-on-glass.

### Preview-fill fix

Audit `previewLayer` aspect handling. The capture VDO delivers
3840×2160 (16:9). iPhone 17 Pro display is ~19.5:9, so 16:9 preview
will pillar-box left/right (acceptable) **or** scale-fit fill top to
bottom + crop sides (preferred for a cockpit feel — preview owns the
full vertical). Confirm `videoGravity = .resizeAspectFill` on the
preview layer / Metal renderer; if it's already set, the black band on
the M13-L screenshot is layout (Spacer pushing the shelf down) not
preview cropping. Either way, M13-M-1 must end with the preview
visually owning the entire screen.

### Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift`
  — replace `sideRails` block with a top parameter chip row and bottom
  Look + lens chip rows. Confirm preview fills the screen.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureBottomDeck.swift`
  — reduce shelf vertical inset; insert Look + lens chip rows above
  the shutter cluster (or hand them in as `@ViewBuilder` rows).
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureChrome.swift`
  — add `captureGlassChip(in:)` (idle) helper if useful for chip rows;
  otherwise reuse `captureGlassRail` / `captureGlassSelected` directly.
  No new geometry tokens beyond what's needed for the chip dimensions.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureAdvancedDrawer.swift`
  — **deferred to M13-M-3+**: drawer body remains as is in M13-M-1
  (its segmented controls are unused once the parameter chip row +
  rulers wire in M13-M-3+). Do NOT delete in M13-M-1; we want a
  working app at every step.

Do **not** edit:

- `FilmtoneCaptureSession.swift` (no parameter API changes).
- writer / movie output / package / proxy / export pipeline.
- React / Capacitor surfaces (dead code per memory).
- master truth scripts.

No new `.swift` files in M13-M-1 → no `project.pbxproj` 4-section grep.

## Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/feature+ios-m9-recording-export-completion
git diff --check
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Then install on iPhone 17 Pro #7 and run owner walk.

## Owner walk (acceptance gate)

Each must be clearly true before M13-M-1 archives:

1. **Cockpit shape reads** — top has a parameter chip row, bottom has
   Look chip row + lens chip row + compact shutter shelf. No vertical
   side rails are visible. The screen reads as an authored camera
   surface, not a generic Liquid Glass app.
2. **Preview owns the screen** — no dominant black band. Preview fills
   100 % vertically; chips and shelf overlay on top of preview, not
   below it.
3. **Selected pill renders correctly** — the active chip in each row
   is highlighted via tint on the **same** capsule shape used by the
   row, with no overflow / no floating inner shape. Tap a different
   chip → highlight moves cleanly with no clip-shape mismatch.

If any of those fail, iterate before moving to M13-M-2.

## Stop Conditions

- Any edit to session / writer / package / proxy / export / Capacitor.
- Any new capture feature.
- Two simulator build failures from the same root cause.
- Owner says the cockpit shape still reads as black-card UI or has
  the same M13-L bugs.

## Out of Scope (deferred to later M13-M-N)

- **M13-M-2** — `RulerScrubber` SwiftUI primitive (Canvas tick marks +
  `DragGesture` translation → value mapping + center-pinned indicator
  + `UISelectionFeedbackGenerator` per tick). No session wiring yet;
  primitive ships with a SwiftUI Preview only.
- **M13-M-3** — wire `RulerScrubber` to `session.exposureBiasEV` (auto
  mode), `session.manualISO` (manual), `session.manualShutterSeconds`
  (manual). Active chip in the top parameter row → scrubber slides in
  below the row.
- **M13-M-4** — Auto / Manual exposure mode toggle integration into
  the cockpit (currently in advanced drawer's `exposureModeSegment`).
  WB auto / locked toggle integration. Drawer goes away.
- **M13-M-5** — owner walk on iPhone 17 Pro / iOS 26.4 with
  parameter scrubbing across ISO / shutter / EV / lens. M13 archive
  if the read is "プロ機の顔をした撮影アプリ".
- Continuous lens zoom (`videoZoomFactor`) — not in M13. Adds
  capability, deferred to a later capture-controls lane unless owner
  explicitly opens it.
- Tint / chromaticity manual setter — needs a session API (out of M12);
  deferred.
- Histogram / audio meter overlay — honest-preview lane, separate
  from M13.
- Reverting M13-L's Liquid Glass primitive extraction — primitives are
  retained as the material vocabulary for cockpit chips.

## Outcome

(Filled at archive time after owner acceptance of M13-M-5.)
