# Archived: M13-M-3 — Ruler Scrubber Primitive + Session Wiring (with M13-M-4 drawer cleanup addendum)

Status: **PASS** — owner accepted 2026-05-09 ("OK"). RulerScrubber
Canvas primitive, session wiring (`setExposureBias` / `setManualISO` /
`setManualShutter`), Blackmagic-style auto↔manual chip-tap pattern, and
the M13-M-4 drawer-deletion addendum all landed on iPhone 17 Pro #7
without behavior regression. M13 itself closes here — the cockpit
(parameter chip row + ruler scrubber + Look sheet + lens chip row +
per-control Liquid Glass + angular RoundedRectangle vocabulary) is the
authored capture surface that M13 was scoping for.

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **installed on iPhone 17 Pro #7, ready for owner walk** — autonomous execution complete 2026-05-09 01:12 JST

## Why this active exists

M13-M-2 landed the cockpit shell + Liquid Glass material vocabulary on
iPhone 17 Pro #7 with owner acceptance. The top parameter chip row
already toggles an `activeChip`, but the ruler region beneath the row
is still a placeholder text stub. M13-M-3 ships the real
`RulerScrubber` SwiftUI primitive, wires it to
`session.setExposureBias` / `setManualISO` / `setManualShutter`, and
implements the **Blackmagic-style one-tap mode entry**: tapping the
ISO or Shutter chip while the session is in `.auto` enters manual
exposure and opens the scrubber; tapping the same chip again exits
back to auto.

Bundling the scrubber primitive with its wiring instead of shipping a
"primitive only with SwiftUI Preview" intermediate keeps the cycle
honest — a primitive that does not move a real value is not
production-shaped, and the owner cannot judge "プロ機の顔をした撮影
アプリ" from a stub.

## Decision: one-tap mode entry (Blackmagic pattern)

Without auto-switching, an ISO or Shutter chip tap in `.auto` mode
opens a scrubber whose drag is a no-op (`setManualISO` / `setManualShutter`
are both gated on `exposureMode == .manual`). That is broken UX — the
ruler appears, the user drags, nothing changes.

Resolution adopted (Blackmagic Camera, ARRI VIEWFINDER, Halide):

| Chip | Auto mode | Manual mode |
|---|---|---|
| ISO | tap → enter manual + open ISO scrubber | tap (when active) → exit manual + close, tap (when inactive) → switch active scrubber to ISO |
| Shutter | tap → enter manual + open shutter scrubber | tap (when active) → exit manual + close, tap (when inactive) → switch active scrubber to Shutter |
| EV | tap → open EV scrubber | **disabled** (EV bias has no effect on `setExposureModeCustom`) |
| WB | tap → toggle auto / locked (no scrubber) | (same) |
| Look | tap → present Look sheet | (same) |

EV chip is hidden / disabled in manual mode (matches existing
`FilmtoneCaptureSession.setExposureBias`'s manual-mode no-op gate).

This decision pulls a small slice of the M13-M-4 "mode toggle
integration" scope into M13-M-3 because the scrubber cannot ship
useful without it. M13-M-4 is now narrowed to: WB lock chrome already
works (M12), drawer file deletion + `applyExposureMode` removal +
clean-up.

## Scope

### A. New file — `FilmtoneCaptureRulerScrubber.swift`

Generic horizontal ruler scrubber primitive. Inputs:

```swift
struct FilmtoneCaptureRulerScrubber: View {
    let value: Double            // current value (display + start position)
    let range: ClosedRange<Double>
    let majorStep: Double         // tick spacing for big ticks
    let minorStep: Double         // tick spacing for small ticks
    let valueLabel: (Double) -> String  // formatter for center readout
    let onChange: (Double) -> Void      // emitted continuously during drag
    let onCommit: ((Double) -> Void)?    // emitted on drag end (optional)
}
```

Render:
- `Canvas { context, size in ... }` draws major + minor tick marks on a
  horizontal axis. Center indicator is a 2pt yellow vertical line.
- Current value scrolls horizontally under the indicator; tick density
  is fixed per-pt so the visible window represents a constant slice of
  the range.
- Above the indicator: monospaced digit readout from `valueLabel(value)`.
- Below the indicator: range bookends ("min → max" labels, faded).
- `DragGesture` translates horizontal pan into value delta inside the
  range. Each crossed tick → `UISelectionFeedbackGenerator().selectionChanged()`.
- Glass primitive: `captureGlassRail(in: rulerShape())`, height 56pt.

The primitive is value-typed and pure — no session knowledge. The
cockpit top bar selects the right `range / step / formatter / onChange`
tuple per active chip.

### B. Cockpit wiring — `FilmtoneCaptureCockpitTopBar.swift`

Replace the stub Text("...scrubber — M13-M-3") in `rulerRegion` with:

```swift
switch chip {
case .iso:
    FilmtoneCaptureRulerScrubber(
        value: Double(manualISO),
        range: Double(isoRange.lowerBound)...Double(isoRange.upperBound),
        majorStep: 100, minorStep: 25,
        valueLabel: { "\(Int($0.rounded()))" },
        onChange: { onScrubISO(Float($0)) },
        onCommit: nil
    )
case .shutter:
    FilmtoneCaptureRulerScrubber(
        value: manualShutterSeconds,
        range: shutterDurationRange.lowerBound...shutterDurationRange.upperBound,
        majorStep: ..., minorStep: ...,
        valueLabel: { fmtShutter($0) },
        onChange: { onScrubShutter($0) }
    )
case .ev:
    FilmtoneCaptureRulerScrubber(
        value: Double(exposureBiasEV),
        range: Double(exposureBiasRange.lowerBound)...Double(exposureBiasRange.upperBound),
        majorStep: 0.5, minorStep: 0.1,
        valueLabel: { String(format: "%+.1f", $0) },
        onChange: { onScrubEV(Float($0)) }
    )
}
```

New CockpitTopBar inputs:
- `isoRange: ClosedRange<Float>` / `shutterDurationRange: ClosedRange<Double>`
- `onScrubEV(Float)`, `onScrubISO(Float)`, `onScrubShutter(Double)` callbacks.

For EV chip in `.manual` mode: hide the chip from `CaptureParameterChip.allCases`
in the row, so it does not appear at all (cleaner than disabled grey).

### C. Orchestrator wiring — `FilmtoneCaptureView.swift`

Pass through to session:
- `onScrubEV` → `session.setExposureBias`
- `onScrubISO` → `session.setManualISO`
- `onScrubShutter` → `session.setManualShutter`

`handleParameterChipTap` (currently in cockpit; now needs to involve
session mode) needs to live in the orchestrator so the session is
reachable. Refactor: cockpit emits `onChipTap(CaptureParameterChip)` →
orchestrator runs the auto↔manual logic.

Auto↔manual logic:

```swift
private func handleParameterChipTap(_ chip: CaptureParameterChip) {
    switch chip {
    case .iso, .shutter:
        if activeParameterChip == chip {
            // Tap while active = exit. If we entered manual via this
            // tap, also exit manual. If we were already in manual
            // pre-tap (e.g. a future drawer-era setting), keep manual.
            if isExposureSessionAtoMSwitched {
                session.exitManualExposure()
                isExposureSessionAtoMSwitched = false
            }
            withAnimation(.spring(...)) {
                activeParameterChip = nil
            }
        } else {
            if session.exposureMode == .auto {
                session.enterManualExposure()
                isExposureSessionAtoMSwitched = true
            }
            withAnimation(.spring(...)) {
                activeParameterChip = chip
            }
        }
    case .ev:
        // Only meaningful in auto. Mirror the iso/shutter open/close
        // semantics minus mode entry.
        withAnimation(.spring(...)) {
            activeParameterChip = (activeParameterChip == chip) ? nil : chip
        }
    case .wb: toggleWhiteBalanceMode()
    case .look: showLookPicker = true
    }
}
```

`isExposureSessionAtoMSwitched: Bool` is a new orchestrator `@State`
tracking whether the active manual mode was caused by a chip tap (vs.
a hypothetical drawer setting that we have since removed). M13-M-4
will simplify by removing the legacy drawer entry path entirely.

### D. EV chip visibility in manual mode

`CaptureParameterChip.allCases` includes `.ev` unconditionally today.
Filter it out at the cockpit layer when `exposureMode == .manual`:

```swift
private var visibleChips: [CaptureParameterChip] {
    CaptureParameterChip.allCases.filter { chip in
        chip != .ev || exposureMode == .auto
    }
}
```

### Edit Targets

- NEW `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureRulerScrubber.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureCockpitTopBar.swift`
  — receive ranges + callbacks; replace ruler stub with primitive;
  filter `.ev` in manual; emit `onChipTap` instead of running the tap
  routing locally.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift`
  — own auto↔manual mode logic; pass session callbacks down to cockpit.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  — 4-section registration for the scrubber file.

Do NOT edit:
- `FilmtoneCaptureSession.swift` (existing API surface is sufficient).
- writer / movie output / package / proxy / export pipeline.
- `FilmtoneCaptureAdvancedDrawer.swift` (M13-M-4 deletion).
- React / Capacitor surfaces.

## Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/feature+ios-m9-recording-export-completion
git diff --check

# pbxproj 4-section grep gate
grep -c FilmtoneCaptureRulerScrubber.swift apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
# expect 4

# Simulator + device build
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug -derivedDataPath /tmp/filmtone-m13m3-dd build

# Install + launch
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-m13m3-dd/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

## Owner walk (acceptance gate)

Each must be clearly true before M13-M-3 archives:

1. **EV scrubbing works in auto** — chip tap → ruler appears → drag
   moves the live value with per-tick haptics. EV value updates the
   exposure target bias on the device (live preview brightens /
   darkens). Tap chip again → ruler closes.
2. **ISO scrubbing flips into manual** — chip tap on ISO in auto →
   session enters `.manual`, ruler appears with live `manualISO`
   value, drag moves device ISO. Tap chip again → exit to `.auto`,
   ruler closes, EV chip reappears.
3. **Shutter scrubbing flips into manual** — same pattern for the
   Shutter chip. The 1/24s slow cap is honored; haptics track ticks
   smoothly across the range.
4. **No regressions** — corner radii / Liquid Glass quality from
   M13-M-2 unchanged. Selected pill non-overflow unchanged. WB / Look
   chips unaffected.

If any FAIL: iterate before commit.

## Stop Conditions

- Any edit to session / writer / package / proxy / export / Capacitor.
- Any new capture feature (no scrubber-driven white balance / focus,
  no zoom / aperture wiring).
- Two simulator build failures from the same root cause.
- pbxproj 4-section grep returns < 4 for `FilmtoneCaptureRulerScrubber.swift`.
- Owner says scrubber drag is jittery / haptics overrun the value
  apply rate / mode auto-entry surprises them.

## In-Scope addendum (M13-M-4 absorbed into this active 2026-05-09)

The originally-planned M13-M-4 drawer cleanup is pulled into this
active because the drawer body is already `EmptyView()` and removing
its dormant code carries zero owner-visible behavior change. Bundling
it keeps `FilmtoneCaptureBottomDeck` signature honest (no
`isAdvancedExpanded` / `AdvancedContent` generic that nobody consumes)
and makes it clear that **the chip cockpit is the only path to manual
exposure entry** going forward.

Scope additions:
- Delete `FilmtoneCaptureAdvancedDrawer.swift`.
- Deregister the 4 pbxproj entries for that file.
- Drop `isAdvancedExpanded: Bool` and `advancedContent: () ->
  AdvancedContent` from `FilmtoneCaptureBottomDeck`. The struct is no
  longer generic over `AdvancedContent`. The hardcoded
  `.padding(.top, isAdvancedExpanded ? 2 : 4)` becomes a flat 4pt.
- Drop the `bottomDeck` builder's literal `isAdvancedExpanded: false`
  + trailing `EmptyView()` at the call site in `FilmtoneCaptureView`.

## Out of Scope (deferred to later M13-M-N)

- **M13-M-5** — owner walk / archive after multi-clip use, M13 close.
- Continuous lens zoom, tint setter, histogram / audio meter overlay,
  other capture-controls extensions.

## Execution log (autonomous run 2026-05-09)

- 01:02-01:15 JST: Step 1-6 + M13-M-4 addendum executed continuously
  per active scope.
- New file `FilmtoneCaptureRulerScrubber.swift` (~250 lines): pure
  value-typed Canvas-rendered horizontal ruler primitive with
  center-pinned amber indicator, major/minor tick marks, monospaced
  value readout, range bookends, per-tick `selectionChanged` haptics,
  drag-to-scrub gesture clamped to range.
- `FilmtoneCaptureCockpitTopBar.swift` rewired: emits `onChipTap`
  back to orchestrator, receives `isoRange` / `shutterDurationRange`
  / `exposureBiasRange` + `onScrubISO` / `onScrubShutter` / `onScrubEV`,
  filters `.ev` chip out in `.manual` mode, replaced ruler stub with
  the new primitive (ISO: step 25/100, Shutter: step 1ms/5ms, EV:
  step 0.1/1.0).
- `FilmtoneCaptureView.swift` orchestrator: added
  `manualEntryViaChipTap` `@State`, new `handleParameterChipTap` /
  `handleManualModeChipTap` routing, hooked session calls
  (`enterManualExposure` / `exitManualExposure` / `setExposureBias`
  / `setManualISO` / `setManualShutter`).
- pbxproj 4-section gate: PASS — `FilmtoneCaptureRulerScrubber.swift`
  appears 4 times.
- Simulator build: PASS.
- Device build: PASS (signed).
- Install + launch: PASS — running on iPhone 17 Pro #7 via
  `xcrun devicectl device install app` + `process launch`.
- M13-M-4 addendum: deleted `FilmtoneCaptureAdvancedDrawer.swift`
  (4 pbxproj entries deregistered — `grep -c FilmtoneCaptureAdvancedDrawer
  project.pbxproj` returns 0). `FilmtoneCaptureBottomDeck` no longer
  generic over `AdvancedContent`; dropped `isAdvancedExpanded`,
  `advancedContent` parameters, and the literal `EmptyView()` /
  `false` that the orchestrator was passing through. Re-built sim +
  device, reinstalled + relaunched on iPhone 17 Pro #7. No
  owner-visible behavior change because the drawer body was already
  `EmptyView()`.

## Owner walk pending — four reads

(See "Owner walk (acceptance gate)" above.)

If all 4 PASS: archive this active.md →
`2026-05-09-m13-m-3-ruler-scrubber.md`, append 1-3 line strategy.md
Completion Log entry, open M13-M-4 active.md (drawer file deletion +
clean-up).

If any FAIL: iterate the specific axis identified by owner before
commit.

## Outcome

(Filled at archive time after owner walk acceptance.)
