# Codex MCP Plugin Publication Handoff

Date: 2026-05-16 JST

This handoff exists because the previous "published" wording was corrected.
The Filmtone Codex MCP is committed and pushed to the private Filmtone repo,
but it is not publicly released. Treat the task as incomplete until the MCP is
packaged as a Codex plugin and made installable through a Codex plugin
marketplace that third parties can access.

## Hard Truth

- Current public status: not public.
- Current code status: private repo `main` contains the MCP implementation.
- Current repo: `chibataku0815/filmtone`, private.
- Current pushed commit: `829fbbf7 feat(filmtone): add Codex MCP batch automation`.
- "GitHub repo internal package" is not publication because the repo is private.
- "Publication complete" means Codex can install it as a plugin from a
  marketplace source, not merely that the package exists in this monorepo.

## User Direction

The user rejected treating documentation/manual work as the main Codex value.
The right product value is:

- video batch operations,
- abstract Q&A about state/export workflow,
- dry-run before export,
- long export job execution and tracking,
- actionable errors and machine-readable tool descriptions instead of a manual.

The user also explicitly removed DaVinci Bridge context from this thread.
Do not route this work through DaVinci Bridge, DRX import strategy, or external
grade import positioning unless the user explicitly reintroduces that scope.

## Product Boundary

v1 is Codex-only, headless, batch/Q&A integration.

Included:

- native automation CLI,
- MCP STDIO server,
- source inspection,
- abstract answer context,
- batch preview,
- batch start/status/cancel/summary,
- video-only export,
- state/export advice with explicit analysis limits.

Excluded:

- in-app chat,
- live control of an already-running Filmtone Desktop window,
- Claude Code integration,
- visual frame analysis,
- clipping/skin/mask detection,
- still export,
- ProRes/HEVC/cloud upload,
- public product copy/release marketing.

## Implemented Code

Main implementation commit:

```text
829fbbf7 feat(filmtone): add Codex MCP batch automation
```

Important files added or changed by the Codex MCP work:

```text
apps/filmtone-desktop-macos/AutomationCLI/FilmtoneAutomationCLI.swift
apps/filmtone-desktop-macos/AutomationCLI/FilmtoneAutomationCore.swift
apps/filmtone-desktop-macos/Verify/AutomationRuntimeTests.swift
apps/filmtone-desktop-macos/Verify/main.swift
apps/filmtone-desktop-macos/Verify/run.sh
apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCreativeLutLoader.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift
packages/film-lab-codex-mcp/package.json
packages/film-lab-codex-mcp/tsconfig.json
packages/film-lab-codex-mcp/src/automation-client.ts
packages/film-lab-codex-mcp/src/index.ts
packages/film-lab-codex-mcp/test/automation-client.test.ts
scripts/build-filmtone-automation.sh
package.json
bun.lock
```

Lane archives created by the work:

```text
docs/filmtone/desktop/native-desktop-v2/archive/2026-05-15-codex-headless-batch-qa-mvp.md
docs/filmtone/desktop/native-desktop-v2/archive/2026-05-16-codex-mcp-unsupported-profile-ux.md
docs/filmtone/desktop/native-desktop-v2/archive/2026-05-16-retired-built-in-look-removal.md
```

The `retired-built-in-look-removal` archive is adjacent cleanup that landed in
the same final commit set. Do not reintroduce Twilight or its preset-only
built-in Look surface as part of Codex publication.

## Root Scripts Added

```json
{
  "build:filmtone-automation": "bash ./scripts/build-filmtone-automation.sh",
  "verify:filmtone-mcp": "bun run --cwd packages/film-lab-codex-mcp test",
  "filmtone:mcp": "bun run --cwd packages/film-lab-codex-mcp start"
}
```

## Native Automation CLI

Binary path after build:

```text
apps/filmtone-desktop-macos/build/automation/FilmtoneAutomationCLI
```

Build command:

```bash
bun run build:filmtone-automation
```

The CLI reads a JSON envelope from stdin and writes JSON or JSONL to stdout.

Commands:

```text
inspectSources
answerContext
previewBatch
runBatch
```

`runBatch` emits JSONL progress events such as:

```text
jobStarted
itemStarted
itemProgress
itemFinished
itemFailed
jobFinished
```

Creative LUT lookup was extended so the automation CLI can resolve bundled LUT
resources through `FILMTONE_CREATIVE_LUT_ROOT` when Bundle resource lookup is
not available.

Video export now supports an optional `outputLongEdgeLimit`; this is used by
the automation `social1080` profile and should preserve app behavior when nil.

## MCP Package

Package path:

```text
packages/film-lab-codex-mcp/
```

Runtime:

```text
Bun / TypeScript / @modelcontextprotocol/sdk
```

MCP server entry:

```text
packages/film-lab-codex-mcp/src/index.ts
```

Automation bridge:

```text
packages/film-lab-codex-mcp/src/automation-client.ts
```

MCP tools exposed:

```text
inspect_sources(paths, recursive?)
prepare_filmtone_answer_context(question, paths?, recursive?)
preview_batch_job(planRequest)
start_batch_job(previewId, overwrite?)
get_batch_job_status(jobId)
cancel_batch_job(jobId)
summarize_batch_job(jobId)
```

Low-level `set_control` style tools are intentionally not exposed in v1.

## Behavior Details

`prepare_filmtone_answer_context` returns facts and limits only. Codex answers
the natural-language question; Filmtone MCP does not call an LLM.

Every abstract answer context must include:

```json
{
  "visualFrameAnalysis": false,
  "maskOrSkinDetection": false,
  "clippingDetection": false,
  "answerMode": "state-export-advice"
}
```

Implication: Codex must not claim visual facts such as "this is clipped",
"skin is warm", or "composition is too dark" because v1 does not inspect frames.
It can advise based on metadata, Look, strength, profile, sidecars, and known
workflow constraints.

Batch export must go through `preview_batch_job` first. `start_batch_job`
requires a `previewId`.

Defaults:

```text
overwrite: false
continueOnError: true
```

v1 export profiles:

```text
social1080
  H.264 MP4
  audio preserved
  long edge capped at 1920px
  suffix: -social

archiveH264
  H.264 MP4
  audio preserved
  source display size preserved
  suffix: -archive
```

Unsupported profiles:

```text
ProRes
HEVC
cloud upload
```

Unsupported profile UX was fixed. A request like `proRes422` now returns a
human-readable v1 unsupported message rather than a raw Swift `DecodingError`.

Expected MCP-facing error:

```json
{
  "error": "Unsupported export profile: proRes422. v1 supports social1080 and archiveH264 only. ProRes, HEVC, and cloud upload are not supported yet."
}
```

Direct CLI returns:

```json
{
  "ok": false,
  "error": {
    "code": "unsupported_export_profile",
    "message": "Unsupported export profile 'proRes422'. v1 supports social1080 and archiveH264 only. ProRes, HEVC, and cloud upload are not supported yet."
  }
}
```

## Verification Already Run

The following passed before the final commit and push:

```bash
bun run build:filmtone-automation
bun run verify:filmtone-mcp
bash apps/filmtone-desktop-macos/Verify/run.sh
bun run verify:desktop
git diff --check
```

Observed results:

```text
MCP package tests: 5/5 passed after unsupported profile UX fix
Native verify harness: 150/150 passed during Codex MVP verification
Desktop xcodebuild: BUILD SUCCEEDED during Codex MVP verification
```

User-perspective smoke test:

- Created a temporary folder with a wide video, vertical video, and still image.
- Asked the Codex/MCP flow to prepare Stone exports for social and archive use.
- `prepare_filmtone_answer_context` returned analysis limits and did not claim
  clipping/visual facts.
- `preview_batch_job` returned 4 video export items and skipped the still with a
  warning.
- `start_batch_job` completed with `succeeded: 4, failed: 0, skipped: 0`.
- `campaign-wide-social.mp4` resized from `2560x1440` to `1920x1080`.
- `campaign-wide-archive.mp4` preserved `2560x1440`.
- vertical `720x1280` outputs preserved size.
- audio was preserved in all four outputs.
- sidecar `.filmtone.json` files were written with Stone `lookId`,
  `batchLookChoice`, and Creative LUT details.
- Existing outputs with `overwrite: false` were blocked during a follow-up
  preview.
- Invalid `previewId` start was rejected.

## Current Repo State Warning

At the time this handoff was written, `origin/main` points to `829fbbf7`, but
local `main` has two additional unpushed commits:

```text
c4f30b55 merge: integrate 24fps Slow Mode (iOS + macOS) into main
45f1562b feat(filmtone): add explicit 24fps Slow Mode for iOS + macOS native exports
829fbbf7 origin/main feat(filmtone): add Codex MCP batch automation
```

The working tree itself is clean except for untracked docs:

```text
docs/filmtone/davinci-bridge/2026-05-14-protective-soft-masks-integration-plan.md
docs/filmtone/desktop/native-desktop-v2/2026-05-16-codex-mcp-plugin-publication-handoff.md
```

For Codex plugin publication, do not depend on the unpushed 24fps commits unless
the user explicitly wants that local main state included. The safest base is a
new clean worktree from `origin/main` at or after `829fbbf7`, because the Codex
MCP implementation is already present there.

Suggested clean start:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git fetch origin
git worktree add /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-codex-plugin-publication -b feature/codex-plugin-publication origin/main
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-codex-plugin-publication
```

Do not delete dirty worktrees unless the user explicitly confirms that their
uncommitted changes are disposable.

## Official Codex Plugin Premises

The next chat must use official OpenAI Codex docs as source of truth.

Useful docs:

- `https://developers.openai.com/codex/plugins/build#plugin-structure`
- `https://developers.openai.com/codex/plugins/build#bundled-mcp-servers-and-lifecycle-hooks`
- `https://developers.openai.com/codex/plugins/build#path-rules`
- `https://developers.openai.com/codex/plugins/build#marketplace-metadata`
- `https://developers.openai.com/codex/cli/reference#codex-plugin-marketplace`

Observed requirements from official docs:

- A Codex plugin has `.codex-plugin/plugin.json`.
- `plugin.json` belongs inside `.codex-plugin/`.
- `skills/`, `hooks/`, `assets/`, `.mcp.json`, and `.app.json` live at plugin
  root, not inside `.codex-plugin/`.
- Manifest paths are relative to plugin root, start with `./`, and must stay
  inside plugin root.
- MCP servers can be configured through `.mcp.json`.
- A marketplace is defined by `.agents/plugins/marketplace.json`.
- Marketplace entries require install policy, auth policy, category, and a
  source pointing at the plugin.
- Codex CLI can add plugin marketplace sources from GitHub shorthand, Git URL,
  SSH URL, or local marketplace root.
- Git-backed marketplace entries can point to a plugin at repo root or a
  subdirectory.

## Publication Definition

Publication is not:

- private repo push,
- local MCP config,
- manual `codex mcp add` against a private checkout,
- a package that only the owner can access.

Publication is:

- a Codex plugin package with `.codex-plugin/plugin.json`,
- bundled `.mcp.json`,
- a marketplace entry that Codex can browse/install,
- hosted in a public or otherwise third-party-accessible marketplace source,
- verified through Codex plugin marketplace install flow.

## Recommended Publication Architecture

Do not make the private Filmtone monorepo public just to publish the plugin.

Recommended route:

1. Keep `chibataku0815/filmtone` private.
2. Create a new public repo for the Codex plugin/marketplace, for example:

```text
chibataku0815/filmtone-codex-plugin
```

or:

```text
chibataku0815/filmtone-codex-marketplace
```

3. Publish only the Codex plugin wrapper, install metadata, and MCP runner.
4. Do not expose proprietary Filmtone app source or LUT assets unless the owner
   intentionally chooses to do so.
5. The public plugin should call an installed/signed Filmtone Desktop helper
   rather than containing all private implementation source.

## Critical Packaging Decision

The current MCP package depends on:

- the native automation CLI build output,
- Filmtone Desktop native source compiled by `scripts/build-filmtone-automation.sh`,
- Creative LUT resources.

This is fine inside the private monorepo. It is not yet a clean public plugin.

Before public Codex plugin release, choose one of these:

### Option A: Installed App Helper (Recommended)

Ship `FilmtoneAutomationCLI` inside the signed/notarized Filmtone Desktop app
bundle or a signed helper install location. The public Codex plugin detects and
calls that helper.

Benefits:

- public plugin does not expose app source,
- versioning follows app installation,
- user installs Filmtone normally, then installs Codex plugin,
- plugin can produce actionable "Filmtone Desktop not found" errors.

Costs:

- requires Desktop packaging/signing changes,
- requires stable helper path/version contract,
- requires a public compatibility statement.

Example helper lookup candidates to evaluate, not yet implemented:

```text
/Applications/Filmtone.app/Contents/MacOS/FilmtoneAutomationCLI
/Applications/Filmtone.app/Contents/Helpers/FilmtoneAutomationCLI
~/Applications/Filmtone.app/Contents/MacOS/FilmtoneAutomationCLI
FILMTONE_AUTOMATION_CLI override
```

### Option B: Public Plugin Bundles Binary

Bundle a prebuilt automation CLI and LUT resources inside the public plugin.

Benefits:

- simple Codex install,
- no installed app dependency.

Costs:

- exposes more proprietary behavior/assets,
- macOS binary signing/notarization questions,
- platform-specific artifact management,
- update/version drift from Desktop app.

### Option C: Public npm/Bun Package

Publish `@filmtone/codex-mcp` and let the Codex plugin run it.

Benefits:

- familiar JS package distribution.

Costs:

- still needs a native helper strategy,
- still not "plugin marketplace complete" unless wrapped in a plugin and
  marketplace entry.

Recommended next step: implement Option A.

## Expected Public Plugin Repo Shape

One possible shape:

```text
filmtone-codex-plugin/
├── .agents/
│   └── plugins/
│       └── marketplace.json
├── plugins/
│   └── filmtone-codex/
│       ├── .codex-plugin/
│       │   └── plugin.json
│       ├── .mcp.json
│       ├── README.md
│       ├── assets/
│       ├── bin/
│       │   └── filmtone-mcp-runner.mjs
│       ├── package.json
│       ├── src/
│       │   ├── index.ts
│       │   └── automation-client.ts
│       └── test/
│           └── automation-client.test.ts
└── README.md
```

The runner should:

- find the installed Filmtone helper or respect `FILMTONE_AUTOMATION_CLI`,
- return a clear setup error if Filmtone Desktop/helper is missing,
- start the MCP STDIO server,
- never require access to the private Filmtone monorepo.

## Minimum Plugin Metadata

The plugin manifest must identify the plugin, point to `.mcp.json`, and contain
install-surface metadata ready for other developers to see.

Sketch only; verify against current official docs before implementation:

```json
{
  "id": "filmtone-codex",
  "name": "Filmtone Codex",
  "version": "0.1.0",
  "description": "Inspect Filmtone video folders, prepare batch export plans, and run tracked Filmtone exports from Codex.",
  "mcpServers": "./.mcp.json",
  "publisher": {
    "name": "Filmtone"
  }
}
```

Do not assume this schema is final. Fetch the official docs again when
implementing.

## Minimum Marketplace Metadata

Sketch only; verify against current official docs before implementation:

```json
{
  "name": "filmtone",
  "interface": {
    "displayName": "Filmtone"
  },
  "plugins": [
    {
      "name": "filmtone-codex",
      "source": {
        "type": "local",
        "path": "./plugins/filmtone-codex"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "NONE"
      },
      "category": "media"
    }
  ]
}
```

For Git-backed public installation, adapt the source form according to official
docs and test with:

```bash
codex plugin marketplace add <owner>/<repo>
codex plugin list
codex plugin install <marketplace>/<plugin>
```

Exact CLI syntax may vary. Confirm with:

```bash
codex plugin marketplace --help
codex plugin --help
```

## Required Verification For True Publication

A future chat should not call the task complete until all of this is true:

1. Public plugin/marketplace repository exists and is accessible without private
   Filmtone repo access.
2. `codex plugin marketplace add ...` succeeds from a clean Codex install.
3. `codex plugin list` or equivalent shows the Filmtone plugin.
4. `codex plugin install ...` succeeds.
5. A fresh Codex session sees the Filmtone MCP tools.
6. `inspect_sources` works against a real local folder.
7. `prepare_filmtone_answer_context` returns `analysisLimits`.
8. `preview_batch_job` returns a dry-run plan.
9. `start_batch_job` either runs successfully or returns a clear setup/export
   error.
10. Missing Filmtone Desktop/helper returns a human-readable setup error.
11. Unsupported profiles return the v1 unsupported message.
12. No private source, signing secrets, provisioning material, or local `.env`
    files are published.

## Suggested Next Active Lane

Create a new lane only in a clean worktree:

```text
Active — Codex Plugin Marketplace Publication
```

Goal:

```text
Make Filmtone Codex integration installable as a Codex plugin from a
third-party-accessible Codex plugin marketplace source.
```

Checklist:

```text
- [ ] Re-check official Codex plugin docs.
- [ ] Create public plugin/marketplace repo or repo-local publication package.
- [ ] Decide helper distribution strategy, preferably installed Filmtone app helper.
- [ ] Add plugin manifest and .mcp.json.
- [ ] Add public MCP runner with helper detection.
- [ ] Port or package the MCP TypeScript server without private monorepo build dependency.
- [ ] Add setup/actionable errors for missing helper/app.
- [ ] Add plugin install verification docs.
- [ ] Test marketplace add/install from a clean environment.
- [ ] Test MCP tools after plugin install.
- [ ] Commit/push public plugin repo.
- [ ] Record final public URL and install command.
```

Stop conditions:

```text
- Official plugin schema cannot be verified.
- Public repo creation or repository visibility change requires owner action.
- Helper CLI distribution needs app signing/notarization changes beyond this lane.
- Any publication path would expose proprietary LUT/source unintentionally.
```

## High-Precision English Handoff Prompt

```text
You are continuing the Filmtone Codex MCP publication work.

Repository context:
- Filmtone implementation source of truth is the private repo at /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone.
- Native Desktop means apps/filmtone-desktop-macos. Do not touch apps/desktop-film-lab-batch unless explicitly asked.
- Current pushed private main contains commit 829fbbf7: "feat(filmtone): add Codex MCP batch automation".
- That commit implemented a native automation CLI plus packages/film-lab-codex-mcp, but it is NOT publicly released because the repo is private.
- The user explicitly corrected the publication definition: this task is only complete when the MCP is packaged as a Codex plugin and installable through a Codex plugin marketplace that third parties can access.
- DaVinci Bridge context is irrelevant for this task. Focus only on AI-native Codex integration: video batch operations and abstract state/export Q&A.

Critical current-state warning:
- At handoff time, origin/main points to 829fbbf7, while local main is two commits ahead with 24fps Slow Mode commits (c4f30b55 and 45f1562b). The Codex MCP implementation is already in origin/main at 829fbbf7.
- Start from a clean worktree based on origin/main at or after 829fbbf7 unless the user explicitly wants the unpushed local 24fps commits included.
- Do not delete dirty worktrees or branches unless the user explicitly confirms their uncommitted changes are disposable.

Existing private implementation:
- Native automation CLI files:
  - apps/filmtone-desktop-macos/AutomationCLI/FilmtoneAutomationCLI.swift
  - apps/filmtone-desktop-macos/AutomationCLI/FilmtoneAutomationCore.swift
- MCP package:
  - packages/film-lab-codex-mcp/src/index.ts
  - packages/film-lab-codex-mcp/src/automation-client.ts
  - packages/film-lab-codex-mcp/test/automation-client.test.ts
- Build/test scripts:
  - bun run build:filmtone-automation
  - bun run verify:filmtone-mcp
  - bun run filmtone:mcp
- Existing MCP tools:
  - inspect_sources
  - prepare_filmtone_answer_context
  - preview_batch_job
  - start_batch_job
  - get_batch_job_status
  - cancel_batch_job
  - summarize_batch_job

Implemented behavior:
- v1 is Codex-only, headless batch/Q&A.
- No in-app chat, no live Desktop window control, no Claude Code integration, no visual frame analysis.
- prepare_filmtone_answer_context returns analysisLimits and must not claim clipping, skin warmth, masks, or visual facts.
- Batch export must go through preview_batch_job before start_batch_job.
- Default overwrite is false. Default continueOnError is true.
- v1 profiles are social1080 and archiveH264 only.
- social1080 is H.264 MP4, audio preserved, long edge capped at 1920px, suffix -social.
- archiveH264 is H.264 MP4, audio preserved, source display size preserved, suffix -archive.
- Still images can be inspected but are skipped for batch export with a warning.
- Unsupported ProRes/HEVC/cloud upload requests must return a human-readable v1 unsupported message, not a raw Swift DecodingError.

Verification already performed before commit 829fbbf7:
- bun run build:filmtone-automation passed.
- bun run verify:filmtone-mcp passed.
- Native verify harness passed 150/150.
- bun run verify:desktop passed.
- User-flow smoke exported wide and vertical videos through MCP, preserved audio, wrote sidecars, blocked existing outputs with overwrite=false, and rejected invalid previewId.

Official Codex docs to re-check before implementing:
- https://developers.openai.com/codex/plugins/build#plugin-structure
- https://developers.openai.com/codex/plugins/build#bundled-mcp-servers-and-lifecycle-hooks
- https://developers.openai.com/codex/plugins/build#path-rules
- https://developers.openai.com/codex/plugins/build#marketplace-metadata
- https://developers.openai.com/codex/cli/reference#codex-plugin-marketplace

Your task:
1. Create a clean active lane for "Codex Plugin Marketplace Publication".
2. Package the existing Filmtone MCP as a Codex plugin with .codex-plugin/plugin.json and .mcp.json.
3. Provide a Codex plugin marketplace entry in .agents/plugins/marketplace.json.
4. Make it third-party installable from a public or otherwise accessible marketplace source. A private repo path does not count as publication.
5. Do not expose the private Filmtone monorepo, proprietary LUT assets, signing secrets, provisioning files, or local .env files.
6. Prefer a public plugin/marketplace repo that runs a small MCP wrapper and calls an installed/signed Filmtone Desktop automation helper. If the helper is missing, return a clear setup error.
7. Verify installation using the Codex plugin marketplace flow, not only local bun scripts.
8. Confirm that after plugin install, a fresh Codex session can see and call Filmtone MCP tools.
9. Only declare the task complete after the public marketplace URL/install command and successful install/tool-call verification are recorded.

Recommended architecture:
- Keep the private Filmtone monorepo private.
- Create or use a public repo such as chibataku0815/filmtone-codex-plugin or chibataku0815/filmtone-codex-marketplace.
- Public plugin repo layout should include:
  - .agents/plugins/marketplace.json
  - plugins/filmtone-codex/.codex-plugin/plugin.json
  - plugins/filmtone-codex/.mcp.json
  - plugins/filmtone-codex/bin/filmtone-mcp-runner.mjs
  - plugin README/assets/tests as needed
- The runner should locate /Applications/Filmtone.app or respect FILMTONE_AUTOMATION_CLI, then start the MCP STDIO server.

Completion criteria:
- codex plugin marketplace add <public-source> succeeds from a clean environment.
- Codex can list and install the Filmtone plugin.
- Filmtone MCP tools appear after install.
- inspect_sources and prepare_filmtone_answer_context work.
- preview_batch_job returns a dry-run plan.
- start_batch_job works when Filmtone helper is installed, or returns a clear setup/export error otherwise.
- The final answer includes the public marketplace source, install command, commit(s), verification run, and any remaining release risks.
```
