# Active — Codex headless batch/Q&A MVP

Inserted 2026-05-15 as an owner-directed AI-native interrupt against Native
Desktop v2.

## Milestone

Interrupt — AI-native Codex integration MVP.

## Goal

Add a Codex-only headless integration that lets Codex inspect media sources,
prepare state/export advice context, preview video batch export plans, run
validated batch jobs, and report job status through an MCP STDIO server. Do not
add in-app chat, live Desktop app control, Claude Code-specific integration, or
visual frame-content analysis in this slice.

## Edit Targets

- Native automation CLI under `apps/filmtone-desktop-macos/`.
- Existing Native Desktop non-UI export/color/media code needed by the CLI.
- New MCP package under `packages/film-lab-codex-mcp/`.
- Root build/verify scripts.
- Native verification harness coverage.

## Read-only References

- `apps/filmtone-desktop-macos/README.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Add a native JSON stdin/stdout automation CLI for inspect / previewBatch
  / runBatch.
- [x] Reuse Native Desktop export/color/media code without routing through
  SwiftUI/AppKit UI state.
- [x] Support video-only batch export with `social1080` and `archiveH264`
  profiles, audio preservation, sidecars, output naming, conflict checks, and
  JSONL progress.
- [x] Add a Codex MCP STDIO package with high-level workflow tools only.
- [x] Add MCP job lifecycle: preview id, start, status, cancel, summarize.
- [x] Add Swift and MCP tests for request validation, preview behavior, profile
  sizing, skip/warning behavior, and job status parsing.
- [x] Run required verification and record results here.

## Verification

- `bun run build:filmtone-automation`
- `bun run verify:filmtone-mcp`
- `bash apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run verify:desktop`
- `git diff --check`

## Done Conditions

- Codex can be configured against `bun run filmtone:mcp`.
- MCP tools expose only batch/Q&A workflow operations, not low-level slider
  controls.
- `prepare_filmtone_answer_context` always returns `analysisLimits` and avoids
  visual-content claims.
- Batch export requires a preview id before execution, defaults to
  `overwrite: false` and `continueOnError: true`, and returns clear per-file
  summaries.
- Verification commands above pass or any remaining failures are documented as
  unrelated baseline issues.

## Stop Conditions

- 3 consecutive failures on the same verification command.
- Export output diverges from the Native Desktop video export path instead of
  reusing it.
- MCP server requires a manual operation guide to be useful.
- The implementation starts live-app control or visual frame analysis work.

## Out of Scope

- In-app AI assistant UI.
- Live control of an already-running Filmtone Desktop window.
- Claude Code integration.
- Visual frame analysis, mask/skin detection, clipping detection, or AI image
  generation.
- ProRes, HEVC, cloud upload, release metadata, public copy, or portfolio
  submodule updates.

## Unexpected / Follow-up

- `bun install` regenerated the intentionally tracked
  `packages/film-lab-smart-look/dist/index.d.ts` declaration for existing
  package source state. Left in place so tracked dist matches source.

## Completion Log — 2026-05-15 JST

Changed:

- Added `FilmtoneAutomationCLI`, a Swift JSON stdin/stdout headless automation
  binary for source inspection, answer-context preparation, batch preview, and
  JSONL batch execution.
- Added a Codex MCP STDIO workspace package exposing only high-level workflow
  tools: inspect, answer context, preview/start/status/cancel/summarize batch
  jobs.
- Extended native video export requests with an optional long-edge output cap
  so `social1080` reuses the same native export path while downscaling to a
  1920px long edge.

Verification:

- `bun run build:filmtone-automation` passed.
- `bun run verify:filmtone-mcp` passed.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed (`150/150`).
- `bun run verify:desktop` passed.
- `git diff --check` passed.

No copy/history impact: this is an internal Codex-only MCP / headless
automation surface, with no public copy, release metadata, App Store wording,
or implementation-history copy changed.

Article Opportunity: Developer note.

Change-History Opportunity: Developer note — this records the first
AI-native operation boundary as headless batch/Q&A, not in-app chat or
low-level slider control.
