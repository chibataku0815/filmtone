# M5-C.4 Mac-native Export Inspector

Date opened: 2026-05-04 JST (auto-mode go-ahead from user — implementation
proceeding immediately; M5-C.3b deferred to a later slice)

## Milestone

M5 Native Editing UI. M5-C.4 closes the Export-side gap in
`archive/2026-05-04-m5-c-ios-feature-parity-audit.md`: "Export inspector
parity — the Mac shell currently fires NSSavePanel and surfaces a
single-line summary; iOS canonical surfaces a stateful inspector with
metrics, reveal/share, and source-cap reason cards."

## Goal

Bring Desktop Export UX up to iOS canonical parity using Mac-native
idioms (Reveal-in-Finder + NSSharingServicePicker instead of
Save-to-Photos + iOS share-sheet). Specifically:

- A persistent right-rail Export Inspector panel with **ready /
  progress / finished / blocked** states (mirrors iOS
  `FilmtoneExportPanel` `statePanel` switch).
- Pre-export controls: **format picker** (PNG / JPEG) + **JPEG quality**
  slider — currently format is implicitly derived from the NSSavePanel
  filename extension and JPEG quality is hardcoded `0.95`.
- Result state: elapsed time hero + metric grid (output dims, file
  size, sidecar path) that **persists** until the next export starts —
  currently `lastExportSummary` is one ephemeral string.
- Result actions: **Reveal in Finder** + **Share** (NSSharingService) —
  currently no post-export navigation; the user has to manually find
  the file.
- Source-cap blocking surfaces as **amber reason cards** in the panel
  rather than silent toolbar-button disablement.

## Why this slice (本質)

- iOS canonical exposes elapsed time, output dims, file size and
  share/save actions inline; Desktop today writes the file, prints a
  one-line summary into the rail, and forgets. Users have to dig into
  Finder manually to confirm the file landed where they expect.
- Format / quality are first-class export decisions on Mac (where users
  routinely move between PNG screenshots and JPEG share assets). The
  current flow forces the user to type the right extension into
  NSSavePanel and accept whatever quality the codepath hardcodes —
  that's hidden state, not a control.
- Source-cap blocking is currently a tooltip on a disabled toolbar
  button. The user only learns *why* by hovering; in iOS the reason is
  always visible in the panel's amber blocked state.
- This is purely additive UI + a few EditorState fields + a new
  `FilmtoneStillExportRequest.jpegQuality` parameter — no math, no
  pipeline, no protocol changes. The export math / sidecar format /
  source-cap logic is already correct.

## Scope

### In

1. **`State/EditorState.swift`** — extensions
   - `var exportFormat: StillExportFormat = .png` (still-only knob;
     video stays h264/.mp4 — codec picker deferred to M5-C.4b if ever)
   - `var jpegQuality: Double = 0.95` (UX-clamped 0.5...1.0)
   - `var lastExportResult: ExportResultSnapshot?` (struct: outputURL,
     sidecarURL, pixelWidth, pixelHeight, processedFrames?, fileSizeBytes,
     elapsedSeconds, sourceKind)
   - `var lastExportError: String?` (replaces error-via-summary string)
   - `var exportStartedAt: Date?` (for elapsed measurement)
   - `var sourceCapViolations: [String]` computed property (mirrors
     iOS `store.sourceViolations` — pulls from
     `FilmtoneSourceInputTransform.sourceCapReason`)
   - helpers: `resetExportResult()`, `formattedFileSize(_:)`,
     `formattedElapsed(_:)` (pure formatters — Verify-harness covered)

2. **`UI/ExportInspectorPanel.swift`** (new) — right-rail panel
   - States via @ViewBuilder switch:
     - **blocked**: amber reason cards from `sourceCapViolations`
     - **progress**: large %, stage label badge, ProgressView, frame
       counter, Cancel button (replaces current `ExportProgressBar`)
     - **finished**: elapsed hero ("12.4s"), MetricRow grid (Output
       dims, File size, Sidecar filename), "Reveal in Finder" + "Share"
       buttons, "Export Again" secondary action that clears the result
       so the panel returns to ready state
     - **ready**: MetricRow grid (Source dims if known, Format picker,
       JPEG quality slider when format == .jpeg), "Export…" primary
       button (triggers NSSavePanel via callback)
   - Same Pass 4 dark-tinted `.clear` Liquid Glass posture as siblings
   - Width-locked at 240pt to match the rail

3. **`UI/MetricRow.swift`** (new, small) — shared label+value tile
   reused inside ExportInspectorPanel and (later) elsewhere if needed.
   Two-line layout: caption-weight label + body value, white text on
   dark glass.

4. **`UI/RootWindowView.swift`** — wiring
   - Replace `if state.isExporting { ExportProgressBar(...) }` block
     with always-visible `ExportInspectorPanel(state:, onExportTap:)`
     (gated on `state.sourceURL != nil` to keep the rail clean before
     a source loads)
   - Toolbar Export button keyboard shortcut (Cmd-E) now calls
     `panel.requestExport()` (forwarded into the inspector's primary
     action) — keeps the existing toolbar verb live but routes through
     the new inspector logic
   - `presentStillExportPanel` reads `state.exportFormat` /
     `state.jpegQuality` instead of inferring from extension; passes
     into `FilmtoneStillExportRequest`
   - On export completion: stamps `state.lastExportResult` with file
     size (read via `FileManager.attributesOfItem`), elapsed seconds
     (`Date().timeIntervalSince(startedAt)`), output dims (already
     returned), sidecar URL (already returned)

5. **`Export/FilmtoneStillExporter.swift`** — extend
   `FilmtoneStillExportRequest` with `jpegQuality: Double = 0.95`;
   thread it into the JPEG branch of `render(...)` so the hardcoded
   0.95 becomes request-driven. Default keeps current behavior bytewise
   for callers that don't pass the new field.

6. **`apps/filmtone-desktop-macos/Verify/main.swift`** — extend harness
   - `formattedFileSize` boundary cases (0 B / 999 B / 1.0 KB / 1.5 MB
     / 2.7 GB)
   - `formattedElapsed` boundary cases (0.5s / 12.4s / 90s / 3661s)
   - JPEG quality clamps to 0.5...1.0 range when assigned via
     EditorState helper (if helper exists; otherwise direct property
     test)

### Out (deferred — purely UX polish)

- Drag-to-reorder MetricRow grid (fixed order is fine)
- Custom JPEG quality numeric text-field (slider only)
- ProRes / HEVC codec picker for video (h264 only — current behavior
  preserved)
- Per-export sidecar diff vs. previous export (audit-trail polish)
- "Reveal sidecar" as a separate button (the sidecar URL is in the
  metric row; current Reveal targets the output file, which is what
  users actually want to drag into other tools)
- Panel collapse/expand chevron (always-on while source loaded)

## Approach

EditorState gains the controls and the result-snapshot struct. The
current `ExportProgressBar` private View is retired in favor of
`ExportInspectorPanel`, which inlines progress as one of its four
states. RootWindowView's `presentStill/VideoExportPanel` methods stamp
the result snapshot in the `MainActor.run` completion block instead of
just setting `lastExportSummary`. The panel reads
`state.lastExportResult` directly to render the finished state.

`Reveal in Finder` is `NSWorkspace.shared.activateFileViewerSelecting
([url])`. `Share` is `NSSharingServicePicker(items: [url])`
`.show(relativeTo: rect, of: view, preferredEdge: .minY)` — anchored
to the share button's frame via a NSViewRepresentable bridge or simpler
`NSApp.keyWindow.contentView` fallback.

JPEG quality slider in EditorState clamps via `didSet`:

```swift
var jpegQuality: Double = 0.95 {
    didSet { jpegQuality = min(1.0, max(0.5, jpegQuality)) }
}
```

File size is read post-export from disk via
`FileManager.attributesOfItem(atPath:)[.size] as? Int ?? 0`. Elapsed
seconds use `Date().timeIntervalSince(state.exportStartedAt!)` stamped
in the completion block.

## Done conditions

- `xcodebuild -scheme FilmtoneDesktop -configuration Debug
  -destination 'platform=macOS' build` passes clean (Swift 6 strict
  concurrency)
- Right rail shows Export Inspector below Grade once a source is
  loaded; ready state shows source dims + format picker
- Toggling format to JPEG reveals the quality slider; PNG hides it
- Tapping "Export…" runs NSSavePanel using `state.exportFormat`'s
  extension as default; JPEG export honors the chosen quality
- Progress state shows live percentage + Cancel; Cancel returns the
  panel to ready state
- Finished state shows elapsed seconds, output dims, file size in
  human-readable units (B/KB/MB/GB), sidecar filename
- Reveal-in-Finder opens Finder with the output file selected
- Share button presents the system share sheet anchored near the
  button
- "Export Again" clears the snapshot and returns to ready state
- Loading an HDR video that exceeds source-cap shows the amber
  blocked state with the same reason string the toolbar tooltip
  currently surfaces
- `Verify/run.sh` extended formatter + clamp tests all PASS

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift` (extend)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ExportInspectorPanel.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/MetricRow.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift` (extend)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneStillExporter.swift` (extend request)
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj` (register new files)
- `apps/filmtone-desktop-macos/Verify/main.swift` (extend harness)

## Read-Only References

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift`
  (canonical state-switch + metric grid + share button — Mac-native
  idiom replacements: `Save to Photos` → `Reveal in Finder`,
  iOS `UIActivityViewController` → `NSSharingServicePicker`)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSourceInputTransform.swift`
  (sourceCapReason for blocked state copy)
- M5-C.3a archive: ExportInspectorPanel reuses the same
  Pass-4 dark-tinted `.clear` glass posture established for
  QuickAdjustControls / GradeControls

## Out Of Scope

- Math changes (none — export pipeline is correct)
- Sidecar payload changes (none — already includes everything)
- Video codec picker (h264 only — defer)
- Multi-export queue (single-shot only — defer)
- Drag-and-drop into Inspector (toolbar Open is sufficient — defer)

## Estimated size

Multi-hour slice (~6 files / ~600 LOC). Single commit at landing.
Format-picker change is back-compat (default StillExportFormat = .png
matches current implicit default).

## Operating mode

Auto-mode: implementation proceeding immediately per user's
"M5-C.4 Export panel に進んでいきましょう" directive on
2026-05-04 JST. Commits will be made by the agent. Compact at
implementation/build/launch boundaries.

## Resume

Resumed: 2026-05-04 JST after M4-B Shared Phase0 Core Package closure
(`archive/2026-05-04-m4-b-shared-phase0-core-package.md`, commits
`5efb7072` + `7663bd1f`).

Already committed on the current branch:

- Implementation files: `EditorState.swift`, `ExportInspectorPanel.swift`,
  `MetricRow.swift`, `FilmtoneExportSnapshot.swift`, `RootWindowView.swift`,
  `FilmtoneStillExporter.swift`, project file registration, and Verify
  harness formatter / JPEG clamp tests landed in commit `5cea00c6`
  (`feat(macos): M5-C.4 Mac-native Export Inspector`).
- `bun run verify:macos` ✅ BUILD SUCCEEDED at pause time.
- `apps/filmtone-desktop-macos/Verify/run.sh` ✅ 36/36 PASS at pause time.
- Code path is unchanged through the M4-B SPM extraction (Desktop now
  imports `FilmLabSwiftCore` for the Phase0 types but Export Inspector
  logic itself was not touched).

Remaining before this slice can archive:

1. ~~Re-run `bun run verify:macos` and `Verify/run.sh` on the current
   post-M4-B branch to confirm no regression from the SPM cutover.~~
   **Done 2026-05-04** after M4-B follow-up commit `d4d46cf3`:
   `xcodebuild -scheme FilmtoneDesktop -configuration Debug build` ✅
   BUILD SUCCEEDED, `Verify/run.sh` ✅ 36/36 PASS, iOS
   `xcodebuild -scheme App -destination 'generic/platform=iOS' build` ✅
   BUILD SUCCEEDED, `swift test` 27/27 ✅, generator `--check` EXIT 0,
   `git diff --check` EXIT 0.
2. Manual visual smoke for **ready / progress / finished / blocked**
   states on a real source file (still + video). *(user-driven)*
3. Finder reveal tap-through (output file selected in Finder).
   *(user-driven)*
4. NSSharingServicePicker tap-through (share sheet anchors near the
   share button, not the window center). *(user-driven)*
5. Format picker (PNG ↔ JPEG) + JPEG quality slider exercised at least
   once. *(user-driven)*
6. Source-cap blocked state confirmed on an HDR / oversized source.
   *(user-driven)*
7. Archive this active.md → `archive/2026-05-04-m5-c4-export-inspector.md`
   and append a 1-3 line Completion Log entry to `strategy.md`.
   *(after #2-#6 land)*

There is no further code work expected for the happy path; the slice
is in user-driven validation phase. If smoke surfaces a regression,
narrow fix here in this active.md before archiving.
