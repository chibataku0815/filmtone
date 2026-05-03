# Filmtone Agent Start Rules

This repository is the standalone implementation source of truth for Filmtone
Desktop, Filmtone iOS, and the shared `film-lab-*` packages.

Do not begin with broad file discovery. Route first, open the current target,
then work on the product surface.

## First 60 Seconds

1. Read this file.
2. Run `git status --short --branch`.
3. Open only the current target entry:
   - repo-wide context: `README.md`, then `CLAUDE.md` if policy details matter
   - Desktop: `apps/desktop-film-lab-batch/` and `docs/filmtone/desktop/`
   - Native Desktop v2: `docs/filmtone/desktop/native-desktop-v2/strategy.md`,
     then `active.md` if present
   - iOS: `apps/capacitor-film-lab-ios/CLAUDE.md`, then the exact Swift/TS
     surface
   - shared packages: the specific package under `packages/`
   - release/version claims: `docs/filmtone/filmtone-release-version-sources.md`
4. Start the requested product work. Do not turn orientation into a separate
   task.

If the request names a concrete file, app, package, branch, or handoff, go
there directly after this file.

## Routing

| Request mentions | Start here | Primary check |
|---|---|---|
| Desktop, macOS, release, update metadata | `apps/desktop-film-lab-batch/` and `docs/filmtone/desktop/` | `bun run verify:desktop` |
| Native Desktop v2, SwiftUI Desktop, macOS native app | `docs/filmtone/desktop/native-desktop-v2/strategy.md` and `active.md` | `bun run verify:macos` |
| iOS, App Store, Xcode, TestFlight, Swift, Capacitor | `apps/capacitor-film-lab-ios/CLAUDE.md` | `bun run verify:ios` |
| color math, presets, LUT, schema, Swift payload | `packages/film-lab-core/` | `bun run build:core` and relevant package tests |
| renderer, WebGL, WebGPU, shader parity | `packages/film-lab-renderer/` | `bun run build:renderer` |
| shared UI controls | `packages/film-lab-ui/` | package build/typecheck plus the affected app smoke |
| Smart Look package | `packages/film-lab-smart-look/` | `bun run build:smart-look` |
| public LP, support, privacy, release notes web pages | portfolio repo, not this repo | update `vendor/filmtone` only after this repo is pushed |

Portfolio lives at:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
```

Portfolio is the public web window. It consumes this repo through
`vendor/filmtone`. Do not edit Filmtone implementation in portfolio.

## Long-Running Task Model

Use the 2-layer model for long-running product lanes. For each project, propose
the placement first. For Filmtone Native Desktop v2, the canonical placement is:

```text
docs/filmtone/desktop/native-desktop-v2/
```

Documents:

- `strategy.md` is the long-term source of truth: goal, measurable Done
  conditions, milestones, dependencies, constraints, open questions, and short
  completion logs only.
- `active.md` is the only current subtask. It must name the milestone, goal,
  edit targets, read-only references, checklist, verification, Done conditions,
  out-of-scope items, and unexpected blockers.
- `archive/YYYY-MM-DD-{slug}.md` stores completed `active.md` logs.
- `paused/YYYY-MM-DD-{slug}.md` stores interrupted, incomplete active tasks.

Rules:

- Start Native Desktop v2 sessions by reading `strategy.md`, then `active.md` if
  present. If `active.md` is missing, propose the next subtask and wait.
- Do not implement without an `active.md`, and do not mix multiple subtasks into
  one `active.md`.
- For half-day-or-larger interrupts, append a `Paused` section to the current
  `active.md`, move it to `paused/`, and create a new interrupt-only
  `active.md`. Restore the paused file after the interrupt is archived.
- Work only inside the current `active.md` scope. If scope needs to change, stop
  and record the issue before proposing the next step.
- While implementing, update completed checklist items as they finish.
- On completion, record verification in `active.md`, move it to `archive/`, and
  append only a 1-3 line milestone note to `strategy.md`.
- Existing handoffs and old plan docs are read-only evidence. Do not treat them
  as current truth.

## Execution Bias

- Product quality is the priority. Prefer the path that reaches the best product
  state over conservative general advice.
- Core progress comes first: behavior, color, export quality, native pipeline,
  release correctness, visual fidelity, and product copy.
- Keep outer-shell work minimal until the core result is good. Broad audits,
  issue hygiene, archive cleanup, and long handoffs come after the product
  surface is working, or when the user explicitly asks for QA/documentation.
- Do not silently lower quality for speed. If a shortcut changes product
  quality, state the tradeoff before taking it.

## Thinking, Research, And Questions

- Use `sequential-thinking` for real design branches, architecture choices,
  release-lane decisions, product-quality tradeoffs, or ambiguous plans.
- Do not create visible thinking work for trivial routing or obvious edits.
- If local source files and the current handoff do not answer a material
  question, search with Gemini if available or web search. Ask the user only
  when the answer changes implementation and cannot be discovered.
- When multiple reads or checks are independent, run them in parallel.

## Truth Gates

Before stating the latest Desktop version, next Desktop version, iOS public
version, iOS local candidate, release scope, or App Store state, run the life
truth scripts:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

Use `FILMTONE_REPO_ROOT` or pass this repo root as an argument if needed.

Rules:

- Trust the truth scripts over old handoffs.
- Do not collapse public iOS state and local Xcode candidate state into one
  value.
- Do not infer current release state from old `life` or portfolio-era docs.

## Verification

Use the smallest verification that proves the changed surface.

Common commands:

```bash
bun install
bun run build:core
bun run build:renderer
bun run build:smart-look
bun run verify:desktop
bun run verify:macos
bun run verify:ios
bun run check:filmtone-copy
git diff --check
```

Guidance:

- Desktop behavior/export changes: `bun run verify:desktop`.
- Native Desktop v2 behavior/export changes: `bun run verify:macos`.
- iOS native/bridge/export changes: `bun run verify:ios`; if Swift build risk is
  material, run the `xcodebuild` command documented in
  `apps/capacitor-film-lab-ios/CLAUDE.md`.
- Shared package contract changes: build the package, then verify every affected
  app surface.
- Copy changes: run `bun run check:filmtone-copy`.
- Broader QA is appropriate only after the primary product result is already
  good.

## Non-Negotiables

- Use `bun`. Do not introduce npm/yarn/pnpm lockfile churn.
- Do not reintroduce npm publishing as the initial dependency mode. The current
  portfolio dependency mode is Git submodule.
- Do not treat `chibatakumi-portfolio/apps/desktop-film-lab-batch` or
  `chibatakumi-portfolio/apps/capacitor-film-lab-ios` as implementation truth.
- Do not remove `packages/film-lab-renderer/dist/` or
  `packages/film-lab-smart-look/dist/` as generated noise. They are intentionally
  tracked so a fresh portfolio submodule checkout can import package exports.
- Do not hand-edit generated Swift such as
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift`.
  Regenerate via `bun run generate:ios-swift`.
- Do not commit secrets, signing material, ASC keys, provisioning files, or
  local `.env` files.
- Copy vocabulary: use `動画`, not `短尺動画`; use `video`, `videos`, or
  `footage`, not active positioning such as `short-form video`.
- Preset/Look vocabulary: `Preset` is the curve/grade foundation. `Look` is
  reserved for the Stone/Urban Creative LUT Pack context. The old
  Preset/Look rename premise from `feature/desktop-look-unification` is
  withdrawn; do not add new references to alias artifacts such as
  `BaseLookName`, `BASE_LOOKS`, `lookPresetId`, or `currentExportLookPreset`
  unless the task explicitly removes or quarantines that legacy layer.

## Dirty Worktree Policy

This repo may already contain user changes. Do not revert changes you did not
make. If existing edits overlap the requested surface, inspect them and work
with them. If they are unrelated, leave them alone.

Do not stage, commit, push, or bump the portfolio submodule unless the user
explicitly asks.

## Handoffs

Keep handoffs short and only write them when they preserve product state that a
future chat needs.

Preferred locations:

- Desktop: `docs/filmtone/desktop/`
- Native Desktop v2: `docs/filmtone/desktop/native-desktop-v2/`
- iOS: `docs/filmtone/ios/`
- Cross-cutting Filmtone docs: `docs/filmtone/`
- life-level strategy or route docs:
  `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/`

When finishing substantial work, record only:

- what changed
- current product/release truth if relevant
- verification run
- known remaining product risks
