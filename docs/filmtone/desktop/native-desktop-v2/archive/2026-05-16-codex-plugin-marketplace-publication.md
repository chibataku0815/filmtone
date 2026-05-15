# Codex Plugin Marketplace Publication

Date opened: 2026-05-16 JST
Milestone: Codex Plugin Marketplace Publication (Phase A)

## Goal

Publish the Filmtone Codex MCP as a Codex plugin marketplace package that a
third party can discover and install from `chibataku0815/filmtone-codex-marketplace`.
Phase A is helper-detection only: the plugin must list tools and return a clear
setup error when `FilmtoneAutomationCLI` is not installed. Bundling/signing the
native helper is a follow-up lane.

## Edit Targets

- `docs/filmtone/desktop/native-desktop-v2/active.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- Public repo:
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-codex-marketplace`

## Read-Only References

- `packages/film-lab-codex-mcp/src/index.ts`
- `packages/film-lab-codex-mcp/src/automation-client.ts`
- `packages/film-lab-codex-mcp/src/security.ts`
- `packages/film-lab-codex-mcp/test/automation-client.test.ts`
- `apps/filmtone-desktop-macos/AutomationCLI/FilmtoneAutomationCLI.swift`
- `docs/filmtone/desktop/native-desktop-v2/2026-05-16-codex-mcp-plugin-publication-handoff.md`
- OpenAI Codex plugin docs.

## Checklist

- [x] Create public marketplace repository.
- [x] Scaffold marketplace-shaped plugin root.
- [x] Port hardened MCP wrapper without Swift source, LUTs, signing material, or private repo scripts.
- [x] Use a committed Node runnable bundle, not runtime `tsx`.
- [x] Add helper detection and actionable setup error.
- [x] Add tests for tool listing, helper detection, validation, job progress, and event caps.
- [x] Verify plugin package locally.
- [x] Verify Codex marketplace add/install path as far as current CLI/app-server supports.
- [x] Push public repo.
- [x] Archive this active log and add a short strategy note.

## Verification

- Public plugin package install/build/test command.
- Public repo secret/proprietary source scan.
- Codex plugin marketplace add from a clean config root.
- Plugin visible/installable through available Codex plugin surface.
- MCP helper-missing setup error returns instead of raw spawn/build/decode error.
- Optional helper override smoke if current CLI can launch installed MCP tools.

Completed 2026-05-16 JST:

- Public repo created and pushed:
  `https://github.com/chibataku0815/filmtone-codex-marketplace`.
- Public commits:
  - `88ed87c feat: publish Filmtone Codex plugin marketplace`
  - `209e6ba fix: use direct MCP server map for Codex plugin`
- `npm test` in
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-codex-marketplace/plugins/filmtone-codex`
  passed: bundle build, typecheck, and 10/10 Node tests.
- `npm audit --omit=dev` passed with 0 vulnerabilities.
- `git diff --check` passed in the public repo.
- Proprietary source/material scan found no `.cube`, `.swift`, `.env`,
  provisioning, certificate, or key files outside ignored `node_modules`.
- Direct MCP smoke passed without `node_modules`: runner initialized from the
  committed `dist/` bundle.
- Direct MCP client smoke listed all 7 tools and returned the actionable
  helper-missing setup error for `inspect_sources`.
- Clean Codex config root verification passed:
  `codex plugin marketplace add chibataku0815/filmtone-codex-marketplace`.
- Codex app-server verification passed in clean root:
  `plugin/list` saw `filmtone-codex@filmtone`, `plugin/install` enabled it,
  and `mcpServerStatus/list` exposed the `filmtone` MCP server with all 7 tools.

## Done Conditions

- Public marketplace repo exists and is pushed.
- The repo contains `.agents/plugins/marketplace.json`,
  `plugins/filmtone-codex/.codex-plugin/plugin.json`, and bundled `.mcp.json`.
- The plugin runner does not auto-build or auto-download native code.
- Private lane state is recorded and archived.

## Stop Conditions

- GitHub repo creation requires manual owner action.
- Current Codex CLI/app-server cannot expose install/enable surfaces needed to
  verify publication semantics.
- Official plugin schema contradicts the marketplace shape.
- Helper distribution requires app signing/notarization work.

## Out Of Scope

- Filmtone Desktop helper target.
- Code signing, notarization, DMG/pkg distribution.
- GitHub Releases helper binary distribution.
- Publishing LUT `.cube` files or Swift native source in the public plugin repo.
- In-app chat, Claude Code integration, live Desktop window control, visual frame analysis.

## Unexpected

- Current `codex-cli 0.131.0-alpha.9` exposes marketplace add through CLI, but
  plugin list/install through app-server protocol rather than CLI subcommands.
- The plugin loader treated wrapped `.mcp.json` (`mcp_servers`) as an invalid
  server entry. The public package was corrected to the direct top-level MCP
  server map used by this Codex app-server build.

## Copy / History Impact

No Filmtone product copy/history impact: this lane published developer-facing
Codex plugin metadata and setup docs only, with no App Store, release, portfolio,
or product-positioning claim change.

Article Opportunity: Developer note only. The marketplace wrapper is public, but
general-user export use still depends on a signed Filmtone Desktop helper lane.

Change-History Opportunity: Developer note. Record that Codex integration
started as a helper-detection marketplace wrapper before native helper
distribution/signing.
