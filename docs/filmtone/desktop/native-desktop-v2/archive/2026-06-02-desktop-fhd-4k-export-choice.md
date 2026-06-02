# Desktop Export Resolution Choice

Date opened: 2026-06-02 JST
Milestone: M5 Native Editing UI

## Goal

Make Native Desktop video export default to FHD while allowing 4K-capable
sources to opt into 4K output. The 4K option must make the extra export time
visible in the product UI.

## Diagnosis

- Current normal Desktop export leaves `outputLongEdgeLimit` nil, so a
  3840x2160 source exports as 3840x2160 by default.
- The intended baseline product behavior is FHD output. 4K should be an
  explicit user choice when the source supports it, not an accidental default.
- Previous real-source profiling showed 4K heavy Film Damage output can take
  substantially longer than FHD, so the selection control needs a visible time
  warning.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ExportInspectorPanel.swift`
- `apps/filmtone-desktop-macos/Verify/CoreOpticalFilterTests.swift` or nearest
  Desktop verification surface if export sizing is already covered elsewhere.
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Read-Only References

- `/Users/chibatakumi/Movies/DJI_20260531161741_0017_D-stone.filmtone.json`
- `docs/filmtone/filmtone-copy-quality-harness.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-02-desktop-scratch-export-integration-60fps-speed.md`

## Checklist

- [x] Inspect current export UI/coordinator request construction.
- [x] Add a product-facing resolution choice with FHD default.
- [x] Show 4K only when the source display size is 4K-capable.
- [x] Pass FHD/4K caps into `FilmtoneVideoExportRequest`.
- [x] Add or update focused verification.
- [x] Verify Desktop build/checks.
- [x] Record results and archive this task.

## UI Copy Brief

- Primary reader: a Mac user exporting a graded 4K source after preview review.
- Moment: before pressing Export, while checking output settings.
- Unresolved feeling: wants the normal export to be quick enough, but may want
  full 4K detail for selected jobs.
- Next action: leave FHD selected by default, or intentionally choose 4K.
- Not for: public marketing, App Store claims, codec-positioning copy.
- Claim class: Internal product UI.
- Source evidence: current exporter sizing behavior and measured 4K timing in
  the 2026-06-02 archive.
- Reversibility buffer: phrase 4K as taking longer, not as a guaranteed exact
  duration.

## Verification

- `apps/filmtone-desktop-macos/Verify/run.sh` passed: `163/163`.
- `bun run verify:desktop` passed.
- `bun run check:filmtone-copy` passed.
- `bun run check:filmtone-context` passed.
- `git diff --check` passed.

## Done Conditions

- A 4K source defaults to FHD output in normal Desktop export.
- A 4K source exposes a 4K option with a visible time-cost warning.
- Non-4K sources do not show a misleading 4K option.
- Existing automation/headless output caps are not accidentally changed.

## Stop Conditions

- Done conditions are met and verification is recorded.
- The same verification class fails 3 consecutive times.
- Current UI state cannot identify source display size without a broader
  architecture change.

## Out Of Scope

- HDR/10-bit/ProRes export.
- Release, notarization, portfolio, or public copy updates.
- iOS/iPad export-resolution UI changes.

## Unexpected

- None yet.

## Copy / History Impact

No public copy/history impact expected: this is Desktop in-app export settings
copy and behavior.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note.
