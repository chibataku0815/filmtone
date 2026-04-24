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
- `0cb2c778 Derive desktop HDR preparation policy`
- `aa2a21e5 Surface HDR preparation policy metadata`

The branch was `main...origin/main [ahead 9]` before this handoff-doc update.

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

### P0-C: HDR-to-SDR Preparation Policy Foundation

Implemented:

- Added pure helper:
  - `deriveDesktopHdrPreparationPolicy(sourceVideoMetadata): HdrPreparationPolicy`
- Policy output is descriptive only:
  - `strategy: "none" | "prepare-sdr-mezzanine" | "defer-unknown"`
  - `reason`
  - `requiresFixtureValidation`
  - `warning`
- Classification behavior:
  - `sdr-bt709` -> no preparation
  - `hdr-pq` -> prepare SDR mezzanine, fixture validation required
  - `hdr-hlg` -> prepare SDR mezzanine, fixture validation required
  - `wide-gamut-unknown` -> defer / warn, no automatic tone map
  - `unknown` -> no automatic change
- Desktop probe now derives `sourceVideoMetadata.hdrPreparationPolicy`.
- Bridge types and sidecar schema accept optional `hdrPreparationPolicy`.
- Video export logs the policy when present.
- No FFmpeg filters, mezzanine branch changes, export FPS changes, or pixel-changing tone mapping were added.

Tests:

- `electron/video-export-source-metadata.test.ts`
- `src/renderer/export-metadata-session.test.ts`

## 4. Verification Run

Last verified commands:

```bash
bun run --cwd apps/desktop-film-lab-batch test
bun run --cwd apps/desktop-film-lab-batch build:electron
bun run --cwd apps/desktop-film-lab-batch build:renderer
```

Results at handoff:

- Vitest: 30 files / 179 tests passed
- Electron build: passed
- Renderer build: passed

Known non-blocking note:

- `bunx tsc -p apps/desktop-film-lab-batch/tsconfig.json --noEmit` is not the verification path currently used because it stops on the existing CSS side-effect import typing issue in `src/renderer/main.tsx`.

## 5. Remaining Work

### Next Recommended Phase: P0-C Fixture-Backed HDR Preparation

The pure policy and visibility layer are complete. The next step is fixture and capability inventory before any pixel-changing implementation.

Recommended next work:

- Inventory or add real sample fixtures:
  - at least one PQ source
  - at least one HLG source
  - one SDR BT.709 regression source
- Record safe fixture metadata:
  - dimensions / duration
  - color fields
  - HDR side data presence
  - expected visual behavior after SDR preparation
- Check local FFmpeg filter support for future HDR-to-SDR preparation.
- Design fixture-backed validation before wiring any filter chain.

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
- Keep new work fixture-backed with focused tests.
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
- metadata 関連の最新実装コミットは `aa2a21e5 Surface HDR preparation policy metadata`。
- 完了済み:
  - P0-A display geometry / rotation 正規化
  - P0-B source color / HDR classification
  - P1-A normalized source metadata sidecar 保存
  - P1-B frame timing diagnostics
  - P0-C HDR preparation policy pure helper
  - P0-C HDR preparation policy log / sidecar visibility
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
P0-C の次として、pixel は変えずに HDR fixture / FFmpeg capability inventory を作ってください。

期待する作業:
- PQ / HLG / SDR BT.709 fixture の所在・不足を確認する
- fixture 追加ができる場合は privacy-safe な小さいものに限定する
- local FFmpeg が将来必要になる HDR-to-SDR filter を持つか確認する
- まだ FFmpeg tone mapping を export path に wire しない
- export FPS の挙動は変えない

検証は最低限:
`bun run --cwd apps/desktop-film-lab-batch test`
`bun run --cwd apps/desktop-film-lab-batch build:electron`
`bun run --cwd apps/desktop-film-lab-batch build:renderer`
```
