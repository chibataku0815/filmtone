# Active - Codex Grade Repair Phase 0: Decode + Metrics Verification

Worktree: `feature/codex-grade-repair-metrics-proof`
Parent strategy: `docs/filmtone/desktop/native-desktop-v2/strategy.md`
Parent design memo (main worktree, untracked): `docs/filmtone/desktop/native-desktop-v2/2026-05-16-codex-grade-repair-soft-masks-plan.md`

## Goal

Filmtone がローカル素材を deterministic に読み、破綻検出に使える基礎
metrics を安定して出せるかだけを検証する。Codex / MCP / CLI surface まで
いかない。analyze_grade_issues は次 Phase 1 で組む。

## Scope

In:

- Add `FilmtoneFrameMetricsHarness.swift` to `apps/filmtone-desktop-macos/AutomationCLI/`.
- Decode path: still PNG via ImageIO, render to bitmap with 320px long-edge cap, walk raw pixels.
- Metrics: luma summary (min / max / mean / high-luma ratio / low-luma ratio), R/G/B channel ceiling ratio, chroma stress (channel spread mean + high percentile), black floor (very-low-luma ratio), sample warnings (empty / unreadable / unsupported pixel format).
- Verify-side fixtures: neutral gray PNG, white clipped PNG, saturated red PNG, near-black PNG, invalid/empty image, determinism check.
- Build wiring: append the new source to `scripts/build-filmtone-automation.sh` and `apps/filmtone-desktop-macos/Verify/run.sh` SOURCES.
- Tests extend `AutomationRuntimeTests.swift`; split into a new file only if it bloats.

Out:

- `analyze_grade_issues` MCP / CLI command.
- JSON contracts (`AnalysisManifest`, `GradeIssue`).
- MCP package edits.
- Video decode via `AVAssetImageGenerator` (Phase 1).
- Repair / proof / sidecar / export runtime.
- Skin candidate detection.

## Edit targets

- `apps/filmtone-desktop-macos/AutomationCLI/FilmtoneFrameMetricsHarness.swift` (new)
- `apps/filmtone-desktop-macos/Verify/AutomationRuntimeTests.swift` (extend) — or split to `FrameMetricsHarnessTests.swift` if it bloats
- `scripts/build-filmtone-automation.sh` (SOURCES append)
- `apps/filmtone-desktop-macos/Verify/run.sh` (SOURCES append)

Read-only references:

- `apps/filmtone-desktop-macos/AutomationCLI/FilmtoneAutomationCore.swift`
- `apps/filmtone-desktop-macos/Verify/TestSupport.swift`
- `docs/filmtone/desktop/native-desktop-v2/2026-05-16-codex-grade-repair-soft-masks-plan.md` (main worktree, untracked)

## Checklist

- [x] Create `FilmtoneFrameMetricsHarness.swift` with internal Swift API only (no CLI surface, no JSON).
- [x] Implement deterministic ImageIO decode + 320px long-edge bitmap render.
- [x] Implement luma / channel ceiling / chroma stress / black floor / sample-warning metrics.
- [x] Add Verify tests for the five fixture cases plus determinism (split into `FrameMetricsHarnessTests.swift`).
- [x] Append new source to the two build scripts.
- [x] Pass `bash apps/filmtone-desktop-macos/Verify/run.sh` (153/153).
- [x] Pass `bun run build:filmtone-automation` (binary emitted; pre-existing CIKernel deprecation warnings only).
- [x] Pass `git diff --check`.

## Done conditions

- The harness compiles into both AutomationCLI and the Verify harness binary.
- All six Verify metrics tests pass.
- Same input image yields byte-identical metric structs on repeated runs.
- `git diff --check` clean.

## Stop conditions

- Done conditions met.
- Verify build refuses ImageIO / CoreGraphics linkage and a non-trivial fallback would be required.
- 3 consecutive failures on the same verification command.

## Out of scope

- Codex MCP wiring.
- analyze_grade_issues command surface.
- Video frame sampling.
- Any output / export / sidecar change.
- Repair plans, proofs, masks.

## Copy / History Impact

- Public copy update required: none. Internal harness only.
- Implementation history update required: minor — a 1-line entry in the
  parent strategy Completion / Interrupt log only after Phase 0 lands and
  passes verification.
- Article Opportunity: defer until Phase 1 produces a Codex-facing surface.
- Change-History Opportunity: defer until Phase 1.
