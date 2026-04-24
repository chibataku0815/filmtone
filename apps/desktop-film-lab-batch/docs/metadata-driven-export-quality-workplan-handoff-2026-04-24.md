# Filmtone Metadata-Driven Export Quality Workplan Handoff

Last updated: 2026-04-24
Authoring context: Codex desktop session
Primary repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
Base branch during work: `main`

## 1. Purpose

This document captures the current implementation state and next work plan for using input-video metadata to improve Filmtone export quality.

The strategic plan is in:

- `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-plan-2026-04-24.md`

This handoff is the execution snapshot for the next chat.

## 2. Current Git State

Metadata-related commits added on top of the earlier `main` work:

- `62788286 Add metadata-driven export quality plan`
- `f5690cf2 Classify source video color metadata`
- `1c1b435e Store source video metadata in export sidecars`
- `7e8ab59a Record source frame timing diagnostics`

The branch was `main...origin/main [ahead 6]` at handoff time.

Unrelated dirty files existed before/alongside this work and must not be reverted or mixed into metadata commits:

- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/bloom-depth-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/diffusion-depth-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/halation-depth-prefilter.frag.wgsl.ts`

## 3. Completed Work

### P0-A: Display Geometry / Rotation

Implemented:

- Added source metadata helper:
  - `apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts`
- Normalizes:
  - `rawWidth`
  - `rawHeight`
  - `displayWidth`
  - `displayHeight`
  - `rotationDeg`
  - source provenance: `ffprobe-side-data`, `ffprobe-tags`, `raw`
- Uses Display Matrix first, rotate tags second, raw dimensions last.
- Desktop probe now returns display dimensions as public `width` / `height`.
- Export pipeline uses display dimensions for export sizing and source aspect.
- Non-zero display rotation bypasses WebCodecs and uses the HTMLVideoElement path.
- `cameraOptics` now shares the same display geometry helper.

Tests:

- `electron/video-export-source-metadata.test.ts`
- Existing camera optics tests still pass.

### P0-B: Source Color / HDR Classification

Implemented:

- Extracts normalized ffprobe color fields:
  - `color_range`
  - `color_space`
  - `color_transfer`
  - `color_primaries`
- Detects HDR side-data presence:
  - `Mastering display metadata`
  - `Content light level metadata`
- Classifies source as:
  - `sdr-bt709`
  - `hdr-pq`
  - `hdr-hlg`
  - `wide-gamut-unknown`
  - `unknown`
- Adds `sourceVideoMetadata.color` and `sourceVideoMetadata.colorClass`.
- Logs color metadata during export.
- Does not change pixels or FFmpeg tone mapping yet.

Tests:

- BT.709 SDR
- PQ / `smpte2084`
- HLG / `arib-std-b67`
- BT.2020 without explicit transfer
- HDR side data without explicit transfer
- missing / unspecified metadata

### P1-A: Source Metadata In Sidecar

Implemented:

- Sidecar schema now accepts optional `input.sourceVideoMetadata`.
- Video export sidecar writes:
  - display geometry
  - color metadata
  - color class
  - timing metadata after P1-B
- Old sidecars remain parseable.

Tests:

- `src/renderer/export-metadata-session.test.ts`
- `src/renderer/metadata-json-runtime.test.ts`

### P1-B: Frame Timing Diagnostics

Implemented:

- `deriveSourceFrameRateTrust` now returns structured diagnostics:
  - raw `avgFrameRate`
  - raw `rFrameRate`
  - parsed numeric values
  - trusted source fps
  - trust boolean
  - trust reason
- Trust reasons:
  - `missing-or-invalid-rate`
  - `rates-diverged`
  - `within-absolute-tolerance`
  - `within-relative-tolerance`
- Existing `sourceFrameRate` / `sourceFrameRateTrusted` behavior is preserved.
- Adds `sourceVideoMetadata.timing`.
- Sidecar schema accepts optional timing metadata.
- Export log explains the frame-rate decision.

Tests:

- `electron/video-export-probe-framerate.test.ts`
- Sidecar roundtrip includes timing metadata.

## 4. Verification Run

Last verified commands:

```bash
bun run --cwd apps/desktop-film-lab-batch test
bun run --cwd apps/desktop-film-lab-batch build:electron
bun run --cwd apps/desktop-film-lab-batch build:renderer
```

Results at handoff:

- Vitest: 30 files / 173 tests passed
- Electron build: passed
- Renderer build: passed

Known non-blocking note:

- `bunx tsc -p apps/desktop-film-lab-batch/tsconfig.json --noEmit` is not the verification path currently used because it stops on the existing CSS side-effect import typing issue in `src/renderer/main.tsx`.

## 5. Remaining Work

### Next Recommended Phase: P0-C HDR-to-SDR Preparation Policy

Start with policy and fixture inventory. Do not immediately wire pixel-changing FFmpeg filters.

Suggested first implementation:

- Add pure helper:
  - `deriveDesktopHdrPreparationPolicy(sourceVideoMetadata): HdrPreparationPolicy`
- Inputs:
  - `sourceVideoMetadata.color`
  - `sourceVideoMetadata.colorClass`
- Outputs should be descriptive first:
  - `strategy: "none" | "prepare-sdr-mezzanine" | "defer-unknown"`
  - `reason`
  - `requiresFixtureValidation`
  - optional future FFmpeg filter hints
- Unit tests:
  - SDR BT.709 -> no preparation
  - HDR PQ -> prepare SDR mezzanine, fixture validation required
  - HDR HLG -> prepare SDR mezzanine, fixture validation required
  - wide gamut unknown -> defer / warn, no automatic tone map
  - unknown -> no preparation, existing behavior

Only after real fixtures are available:

- wire one HDR branch at a time
- verify local FFmpeg supports required filters
- compare exported SDR output visually against source expectation
- confirm SDR sources never enter the HDR preparation path

### Later Phases

P2-A: FOV / focal-length-aware optical recommendations

- Must be opt-in or recommendation-only.
- Do not change input LUT.
- Do not claim physical lens correction.
- Use only reliable `cameraOptics.source === "metadata" | "manual"`.

P2-B: Camera / lens profile research

- Requires real fixture sets per family.
- Do not implement distortion correction from make/model alone.

P3: Gyro / IMU / rolling shutter inventory

- Inventory only unless Filmtone intentionally expands into motion metadata processing.
- Do not copy timed telemetry tracks into rendered exports.

## 6. Guardrails For Next Chat

- Do not touch or revert unrelated WebGPU dirty files unless explicitly asked.
- Do not change export FPS behavior while working on metadata diagnostics.
- Do not auto-select camera profile / input LUT from make/model.
- Do not add pixel-changing HDR tone mapping without real PQ/HLG fixtures.
- Keep new work pure-helper-first with focused unit tests.
- Keep sidecar schema backward-compatible.
- Use `rg` for search and `apply_patch` for edits.

## 7. Handoff Prompt

Use this prompt to continue in a new chat:

```text
Filmtone の metadata-driven export quality 改善を続けてください。

対象 repo:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

現在地:
- main は origin/main より ahead。
- metadata 関連の最新コミットは `7e8ab59a Record source frame timing diagnostics`。
- 完了済み:
  - P0-A display geometry / rotation 正規化
  - P0-B source color / HDR classification
  - P1-A normalized source metadata sidecar 保存
  - P1-B frame timing diagnostics
- 全体計画:
  - apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-plan-2026-04-24.md
- 現在地・引き継ぎ:
  - apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-workplan-handoff-2026-04-24.md

注意:
- unrelated dirty files として `packages/film-lab-renderer/src/webgpu/...` が残っている可能性があります。metadata 作業では触らず、stage/commit しないでください。
- camera profile / input LUT と optical/capture metadata を混同しないでください。
- export FPS の挙動は変えないでください。
- HDR tone mapping は pixel-changing なので、real PQ/HLG fixtures が揃うまでは直接 wire しないでください。

次の推奨作業:
P0-C の最初として、pixel は変えずに HDR-to-SDR preparation policy の pure helper と unit test を作ってください。

推奨 helper:
`deriveDesktopHdrPreparationPolicy(sourceVideoMetadata): HdrPreparationPolicy`

期待する分類:
- `sdr-bt709` -> no preparation
- `hdr-pq` -> prepare SDR mezzanine, fixture validation required
- `hdr-hlg` -> prepare SDR mezzanine, fixture validation required
- `wide-gamut-unknown` -> defer / warn
- `unknown` -> no automatic change

検証は最低限:
`bun run --cwd apps/desktop-film-lab-batch test`
`bun run --cwd apps/desktop-film-lab-batch build:electron`
`bun run --cwd apps/desktop-film-lab-batch build:renderer`
```

