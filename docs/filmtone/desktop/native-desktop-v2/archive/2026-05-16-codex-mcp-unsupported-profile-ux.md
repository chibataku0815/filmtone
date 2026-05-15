# Codex MCP Unsupported Export Profile UX

Opened 2026-05-16 JST as a short Codex MVP follow-up.

## Goal

Replace raw Swift decode failures for unsupported batch export profiles with a
clear Codex-facing message that says the requested profile is not supported in
v1 and names the supported profiles.

## Edit Targets

- `packages/film-lab-codex-mcp/`
- `apps/filmtone-desktop-macos/AutomationCLI/`
- Native Desktop v2 lane docs under
  `docs/filmtone/desktop/native-desktop-v2/`

## Checklist

- [x] Add MCP/client-side runtime validation for unsupported profiles.
- [x] Map direct automation CLI decode failures to a user-facing profile error.
- [x] Add MCP package regression coverage.
- [x] Verify user-facing MCP and direct CLI behavior.
- [x] Run focused verification and whitespace checks.

## Verification

- `bun run verify:filmtone-mcp`
- Direct CLI unsupported profile smoke
- MCP STDIO unsupported profile smoke
- `git diff --check`

## Done Conditions

- Codex receives a human-readable unsupported-profile error instead of a Swift
  `DecodingError`.
- Supported `social1080` / `archiveH264` flows remain unchanged.

## Verification Results

- `bun run verify:filmtone-mcp` passed (`5/5` package tests).
- `bun run build:filmtone-automation` passed.
- Direct CLI unsupported profile smoke returned
  `unsupported_export_profile`.
- MCP STDIO unsupported profile smoke returned a user-facing v1 unsupported
  profile message.
- MCP STDIO supported profile preview still returned 4 planned video exports
  and skipped the still image with an explicit warning.
- `git diff --check` passed.

## Copy / History Impact

No copy/history impact: this only changes Codex/MCP error wording and runtime
validation. Public release copy, App Store copy, and implementation-history
claims are unchanged.

Article Opportunity: No story.

Change-History Opportunity: Developer note.

## Stop Conditions

- Verification fails 3 consecutive times for the same reason.
- The fix requires broad batch profile model changes beyond error handling.

## Out Of Scope

- Adding ProRes, HEVC, cloud upload, or additional export profiles.
- Changing the Filmtone Desktop UI.
- Release publication, App Store copy, and portfolio updates.
