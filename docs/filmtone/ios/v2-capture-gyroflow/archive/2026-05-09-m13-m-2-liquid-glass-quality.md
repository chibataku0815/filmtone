# Archived: M13-M-2 — Liquid Glass Quality + Cockpit Refactor

Status: **PASS** — owner accepted 2026-05-09 ("OK"). Corner radii read
as pro-camera angular (chip 9pt / lens 8pt / HUD 10pt / peripheral 11pt
RoundedRectangle, Capsule retained only on status timecode). Bottom
shelf glass slab dropped — each control owns its own Liquid Glass
primitive, refraction reads at the rim. Selected state moved to
`tint(white 0.10) + 0.6pt rim 0.22 + bold` per Apple HIG. Component
extraction split `FilmtoneCaptureView.swift` 1170 → 847 lines into
`Cockpit / Lens / Look` siblings without behavior regression.

Acceptance authorized M13-M-3 (RulerScrubber primitive + session
wiring + auto↔manual mode tap pattern) as next step.

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **installed on iPhone 17 Pro #7, ready for owner walk** — autonomous execution complete 2026-05-09 01:02 JST

## Why this active exists

M13-M-1 cockpit shell landed (chip rows, no side rails, preview owns
the screen, selected pills no longer overflow), but owner walk found
two material gaps:

1. **角丸が丸すぎる** — `Capsule()` everywhere on chips + bottom shelf
   `cornerRadius: 26` produced pill / soft-slab silhouettes. Reads as a
   consumer pill UI, not a pro camera surface.
2. **Apple Liquid Glass ではなく磨りガラス** — the bottom shelf rail
   creates a glass-on-glass stack with the chips and shutter cluster
   sitting on top. The per-edge specular / refraction signature that
   distinguishes Apple Liquid Glass from frosted blur collapses into
   one flat haze. Selected-tint at `white.opacity(0.18)` further drowns
   refraction on active chips.

M13-M-2 keeps the cockpit composition (top chip row, bottom lens chip
row, compact shutter, no side rails, preview-dominant) but rebuilds the
material layer to read as Apple Liquid Glass and refines per-component
shape vocabulary to angular pro-camera radii. It also separates the
1170-line `FilmtoneCaptureView.swift` into role-specific components.

## Owner-locked decisions carried forward (from M13-M-1)

1. Look picker stays as a `.sheet(isPresented:)` — scales to future
   saved Looks + loaded LUT entries.
2. Ruler scrubber expands directly below the active parameter chip
   (real ruler primitive lands in M13-M-3, not this step).
3. Continuous lens zoom (`videoZoomFactor`) deferred to a later
   capture-controls lane.
4. Cockpit composition (top parameter chips, bottom lens chips, no
   vertical side rails) is owner-confirmed and is **not** redesigned in
   M13-M-2. Only the material + shape language changes.

## M13-M-2 Scope

### A. Material refinement — `FilmtoneCaptureChrome.swift`

- Reduce `selectedGlassTint` opacity `0.18 → 0.10` so the refraction
  passes through on active chips. Add `selectedStroke` 0.6pt edge at
  `white.opacity(0.22)` only on the selected variant — the visual
  weight comes from rim + tint + bold weight, not opacity.
- Add new shape tokens (single source of truth for radii):
  - `chipShape = RoundedRectangle(cornerRadius: 9, style: .continuous)`
  - `lensChipShape = RoundedRectangle(cornerRadius: 8, style: .continuous)`
  - `hudShape = RoundedRectangle(cornerRadius: 10, style: .continuous)`
  - `peripheralShape = RoundedRectangle(cornerRadius: 11, style: .continuous)`
  - `rulerShape = RoundedRectangle(cornerRadius: 11, style: .continuous)`
- Add `View.captureGlassChip(active:in:)` helper that branches between
  `captureGlassControl` (idle) and `captureGlassSelected` (active) on
  the same shape. Replaces the per-callsite `filmtoneChipGlass`
  fileprivate extension that lived inside `FilmtoneCaptureView.swift`.
- Drop the unused `selectedFill` cream pill token. Drop legacy
  `panelCornerRadius` if any caller no longer references it.
- Reduce `shelfCornerRadius` token to a no-op (tracked for future
  callers if the shelf rail comes back). The current shelf rail is
  removed in scope D.

### B. Top cockpit extraction — new file `FilmtoneCaptureCockpitTopBar.swift`

- Owns `CaptureParameterChip` enum (currently inside
  `FilmtoneCaptureView`).
- Renders the existing `FilmtoneCaptureTopStatusBar` (close + storage
  HUD) and the parameter chip row (ISO / Shutter / EV / WB / Look) and
  the conditional ruler region.
- Inputs: session state slices (exposureMode, manualISO,
  manualShutterSeconds, exposureBiasEV, whiteBalanceMode,
  captureLookSelection, isRecordingOrStopping, storage info, quality
  contract text), bindings for `activeChip` and
  `showLookPicker`, callbacks for tap and WB toggle.
- Selection state: `chipShape` + `captureGlassChip(active:in:)`. The
  parameter chip row sits inside the parent's `GlassEffectContainer`.
- Ruler region: `rulerShape` (cornerRadius 11) wrapping a stub label;
  real ruler is M13-M-3.

### C. Bottom lens chip row — new file `FilmtoneCaptureLensChipRow.swift`

- Inputs: `lenses` array + `selectedLens` + `isRecordingOrStopping` +
  `lensSwitchInFlight` + `onSelect(FilmtoneCaptureLens)` closure.
- Shape: `lensChipShape` (cornerRadius 8). Active = tint via
  `captureGlassSelected`. Hidden when `lenses.count <= 1`.

### D. Bottom deck refactor — `FilmtoneCaptureBottomDeck.swift`

- **Drop the shelf glass rail** that wraps `shelfBody`. The shelf is no
  longer a single Liquid Glass surface; instead each control owns its
  own glass primitive on its own shape:
  - Folder pick / clear: `peripheralShape` (cornerRadius 11) ×
    `captureGlassControl`.
  - Record button: `Circle()` × `captureGlassControl` (kept; shutter
    convention).
  - Status text (when recording): floats above the cluster as a small
    `captureGlassHUD` capsule (Capsule is OK here — pro camera HUD
    timecodes are the one place a pill silhouette reads as authored).
- VStack remains transparent. Spacing between cluster and lens chip
  row is owned by the parent (`FilmtoneCaptureView`'s `bottomZone`).

### E. Look picker extraction — new file `FilmtoneCaptureLookSheet.swift`

- Inputs: `selection: Binding<FilmtoneCaptureLook>` + `onDismiss`.
- Body: NavigationStack + List of `FilmtoneCaptureLook.allCases` with
  checkmark + Done toolbar + `.presentationDetents([.medium, .large])`
  + `.presentationDragIndicator(.visible)`.
- Forward-compat: list is structured so a future "Saved Looks" /
  "Loaded LUTs" section can append without rewriting the picker.

### F. Orchestrator slim — `FilmtoneCaptureView.swift`

- Remove all chip / ruler / lens / look-picker view code.
- Body composes:
  - `Color.black.ignoresSafeArea()`
  - `previewLayer`
  - `FilmtoneCaptureInteractionOverlay`
  - `GlassEffectContainer(spacing: 8) { VStack { topBar component, Spacer, bottomZone component } }`
  - `failureOverlay`, `diagnosticOverlay`
- Body should be < 120 lines after the extraction; total file under
  900 lines after the cockpit move.

### Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureChrome.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureBottomDeck.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift`
- NEW `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureCockpitTopBar.swift`
- NEW `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureLensChipRow.swift`
- NEW `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureLookSheet.swift`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  (4-section registration for the 3 new files)

Do NOT edit:
- `FilmtoneCaptureSession.swift`
- writer / movie output / package / proxy / export pipeline
- React / Capacitor surfaces (dead code per memory)
- master truth scripts

## Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/feature+ios-m9-recording-export-completion
git diff --check

# pbxproj 4-section grep gate (>=4 each)
for f in FilmtoneCaptureCockpitTopBar.swift FilmtoneCaptureLensChipRow.swift FilmtoneCaptureLookSheet.swift; do
  echo "$f $(grep -c "$f" apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj)"
done

# Simulator build (CLAUDE.md §3 commit gate)
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO

# Device build + install + launch
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug -archivePath /tmp/filmtone-m13m2.xcarchive archive
# (or build-for-testing with signing — whichever lands a signed .app)
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /path/to/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

## Owner walk (acceptance gate)

Each must be clearly true before M13-M-2 archives:

1. **角丸が pro-camera 寄り** — parameter chips / lens chips / HUD pill /
   peripheral buttons は angular RoundedRectangle (radii 8-11pt) で、
   Capsule の pill silhouette は shutter 横の status timecode と record
   button 円形だけ。
2. **Apple Liquid Glass が efektive** — chip / control の rim に
   specular highlight が見え、preview の色が edge で refraction される。
   selected chip は tint が hint レベルで、background の preview が
   chip 越しにわずかに透ける。bottom shelf の slab はもう存在しない。
3. **Cockpit composition は不変** — top に parameter chip 行、bottom に
   lens chip 行 + 静かな shutter cluster、preview が画面 100% を占める
   M13-M-1 の良い部分は壊れていない。selected pill overflow も
   再発していない。

## Stop Conditions

- Any edit to session / writer / package / proxy / export / Capacitor.
- Any new capture feature.
- Two simulator build failures from the same root cause.
- pbxproj 4-section grep returns < 4 for any new file (single-section
  registration produces a stale archive that compiles only because of
  PBXSourcesBuildPhase + PBXFileReference being separately consistent;
  this trap was named in `apps/capacitor-film-lab-ios/CLAUDE.md` §3).
- Owner says cornering / glass quality still reads as M13-M-1 after
  install.

## Out of Scope (deferred to later M13-M-N)

- **M13-M-3** — `RulerScrubber` SwiftUI primitive (Canvas tick marks +
  `DragGesture` translation → value mapping + center-pinned indicator
  + `UISelectionFeedbackGenerator` per tick). No session wiring yet;
  primitive ships with a SwiftUI Preview only.
- **M13-M-4** — wire `RulerScrubber` to `session.exposureBiasEV` (auto
  mode), `session.manualISO` (manual), `session.manualShutterSeconds`
  (manual). Active chip in the top parameter row → scrubber slides in
  below the row.
- **M13-M-5** — Auto / Manual exposure mode toggle integration into
  the cockpit (currently in advanced drawer's `exposureModeSegment`).
  WB auto / locked toggle integration. Drawer goes away.
- **M13-M-6** — owner walk on iPhone 17 Pro / iOS 26.4 with parameter
  scrubbing across ISO / shutter / EV / lens. M13 archive if the read
  is "プロ機の顔をした撮影アプリ".
- Continuous lens zoom (`videoZoomFactor`).
- Tint / chromaticity manual setter.
- Histogram / audio meter overlay.

## Execution log (autonomous run 2026-05-09)

- 00:46-01:02 JST: Step 1-9 executed continuously per active scope.
- Simulator build: PASS (`** BUILD SUCCEEDED **` against
  `iPhoneSimulator26.4.sdk`, derived data
  `~/Library/Developer/Xcode/DerivedData/App-ekvlyqtadlqbjmhkryhdrhpdrfyp`).
- Device build: PASS (`** BUILD SUCCEEDED **`, signed with
  `Apple Development: takumi chiba (262F3A4568)`, derived data
  `/tmp/filmtone-m13m2-dd`).
- pbxproj 4-section gate: PASS — each new file appears 4 times
  (`PBXBuildFile` / `PBXFileReference` / `PBXSourcesBuildPhase` / `PBXGroup`).
- Install + launch: PASS — `xcrun devicectl device install app` →
  `App installed: com.chibatakumi.film.lab.ios`; `process launch` →
  `Launched application with com.chibatakumi.film.lab.ios bundle
  identifier.` on iPhone 17 Pro #7
  (UDID `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`).
- `FilmtoneCaptureView.swift`: 1170 → 847 lines (cockpit / lens /
  look-sheet rendering moved to siblings). Three new files added,
  `FilmtoneCaptureChrome.swift`, `FilmtoneCaptureBottomDeck.swift`,
  `FilmtoneCaptureTopStatusBar.swift` updated for angular shape
  vocabulary + tint-as-hint selected state.

## Owner walk pending — three reads

(See "Owner walk (acceptance gate)" above.)

If all 3 PASS: archive this active.md → 2026-05-09-m13-m-2-liquid-glass-quality.md,
add 1-3 line strategy.md Completion Log entry, open M13-M-3 active.md
(real `RulerScrubber` Canvas primitive).

If any FAIL: iterate the specific shape token / glass primitive
identified by the owner before commit.

## Outcome

(Filled at archive time after owner acceptance of M13-M-6.)
