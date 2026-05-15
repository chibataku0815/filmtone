# MCP Security Hardening

Date opened: 2026-05-16 JST
Milestone: AI-native / Codex MCP publication hardening

## Goal

Make the existing Filmtone Codex MCP package safe enough to continue toward
public plugin packaging by addressing the P1/P2 security review findings in the
private implementation source.

## Edit Targets

- `packages/film-lab-codex-mcp/`
- `apps/filmtone-desktop-macos/AutomationCLI/`
- `apps/filmtone-desktop-macos/Verify/AutomationRuntimeTests.swift`
- root package dependency policy if needed

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/2026-05-16-codex-mcp-plugin-publication-handoff.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-15-codex-headless-batch-qa-mvp.md`

## Checklist

- [x] Disable public-runtime auto-build by default and keep explicit dev opt-in.
- [x] Add MCP runtime argument validation with bounded strings, arrays, and job IDs.
- [x] Add source/output path policy with allow roots and sensitive path rejection.
- [x] Pass only allowlisted environment variables to helper child processes.
- [x] Add preview/job/event/stderr/concurrency caps.
- [x] Require signed preview plans for `runBatch`.
- [x] Add Swift-side path policy, scan limits, and direct CLI runBatch validation.
- [x] Add/update tests for security boundaries.
- [ ] Run targeted verification.

## Verification

- `bun run verify:filmtone-mcp` passed (`10/10` MCP package tests).
- `bun run build:filmtone-automation` passed.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed (`146/146`).
- `bun audit --production` still fails repo-wide because of existing non-MCP
  workspace advisories, mostly legacy Electron and shared build dependencies.
  The MCP-direct vulnerable transitive packages identified in review were
  pinned to patched versions: `fast-uri@3.1.2` and `ip-address@10.2.0`.
- `git diff --check` passed.

## Done Conditions

- Public MCP runner no longer executes repo-local build scripts unless explicitly
  opted in for local development.
- MCP tools reject unsafe path, invalid argument, and excessive request shapes
  before invoking the Swift helper.
- Swift helper independently rejects unsafe path / unsigned `runBatch` payloads.
- Long-running jobs cannot grow memory/log state without bounds.
- Verification results are recorded here, then this file is archived.

## Stop Conditions

- 3 consecutive failures in the same verification command.
- Any fix requires changing Filmtone app signing/notarization or public release
  packaging.
- Helper distribution needs app bundle changes beyond this security lane.

## Out Of Scope

- Creating the public Codex marketplace repository.
- Xcode helper target / app-bundled helper distribution.
- GitHub Releases binary distribution.
- Visual frame analysis, mask/skin detection, or in-app chat.

## Unexpected

- `bun install` refreshed generated shared package output; the unrelated
  `packages/film-lab-smart-look/dist/index.d.ts` change was not kept in this
  lane.

## Copy / History Impact

No public copy impact: this is internal security hardening for the Codex MCP
implementation and does not publish or market the plugin.

Article Opportunity: Developer note only, after the public plugin lane exists.

Change-History Opportunity: Developer note. This records the security boundary
shift from dev-only MCP helper execution toward a public plugin-safe runner.

## Known Remaining Product Risks

- Public marketplace packaging is still separate work.
- Third-party end-to-end export still needs a signed/notarized Filmtone app
  helper distribution lane.
- Public setup copy should explain allowed source/output roots and
  `FILMTONE_MCP_ALLOWED_SOURCE_ROOTS` / `FILMTONE_MCP_ALLOWED_OUTPUT_ROOTS`.
