# Vision3 500T Blue Hour Preset Handoff - 2026-05-12

## Product Change

- Added shared Web/Desktop film-stock preset `vision3500t` in `packages/film-lab-core`.
- Target expression: blue-hour material that should stay deep cobalt instead of being warmed back to neutral, with 16mm-scale grain, dense silhouettes, restrained Kodak negative halation, and mild film latitude/print density.
- Source evidence: Kodak lists VISION3 500T 5219/7219 as tungsten 3200K / daylight 320 with 85 filter, low-light capable, and extended highlight-latitude stock. The supplied reference screenshot measured around median hue 224.5 with a low median luma, supporting a dense blue-hour recipe rather than a generic tungsten-glow preset.

## Copy / History Impact

- Public copy update required: release notes may mention the new `Vision3 500T` / `Blue Hour` preset when this ships; no version, App Store, download, or platform claim was made here.
- Implementation history update required: none. This expands the preset catalog and does not change the WebGPU / WebGL, Capacitor, SwiftUI, AVFoundation, or package-source story.
- Release/App Store claim: run the release truth scripts before writing release copy.
- Article Opportunity: Release-note only - user-visible output preset, narrow scope, no release proof package yet.
- Change-History Opportunity: No history story - preset catalog expansion only.

## Verification

- `bun test packages/film-lab-core/src/filmtone-defaults.test.ts packages/film-lab-core/src/schema.test.ts`
- `bun run build:core`
- `bun test packages/film-lab-core/src`
- `bun run generate:ios-swift --check`
- `bun run check:filmtone-copy`
- `bun run check:filmtone-context`
- `git diff --check`
