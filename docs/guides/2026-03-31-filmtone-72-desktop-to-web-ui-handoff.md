# Filmtone #72 Desktop -> Web UI Handoff

> **Update 2026-04-01:** `pauseVideoPreview`（`FilmLabCanvas` + Desktop `App.tsx` の `pauseVideoPreview={running}`）は main にマージ済み。本文中の「未コミットの pauseVideoPreview を web 移植に混ぜない」という注意は **旧前提**。

## Purpose

This document is the handoff for porting the **desktop-side UI redesign from issue `life#72`** into the **web Film Lab UI** in a separate chat.

This is intended to be complete enough that a new chat can continue without re-discovering context.

## Important Note

- The originally referenced handoff file `docs/guides/2026-03-31-filmtone-72-glass-panel-handoff.md` was **not present** in this workspace during the desktop continuation work.
- Because of that, the desktop continuation was reconstructed from:
  - the current source tree
  - the user’s problem statements and screenshots
  - commit history
  - direct visual validation in the Electron app
- Treat **this file** as the current source of truth for the desktop-to-web transfer.

## Repo Context

- Repo root: `forestone/chibatakumi-portfolio`
- Desktop app: `apps/desktop-film-lab-batch`
- Web app: `apps/web`
- Shared UI package: `packages/film-lab-ui`
- Shared renderer/core: `packages/film-lab-renderer`, `packages/film-lab-core`

## Ground Truth Commits

These are the relevant desktop continuation commits, in order:

1. `2f5bc4d` `fix(desktop): add end gutter to edit control rows (life#72)`
2. `fbce32f` `feat(desktop): flatten edit chrome and merge canvas actions (life#72)`
3. `d58d2ab` `fix(desktop): soften titlebar chrome in edit mode (life#72)`
4. `23779cb` `fix(desktop): replace panel reveal rail with disclosure chip (life#72)`

The user also stated that the pre-handoff desktop baseline was around commit `3baf274` and that the inline export panel + glass UI were already mostly complete at that point.

## Final Desktop Outcome

### What changed visually

The desktop edit view was pushed toward a flatter, more integrated composition:

- The preview area was made more full-bleed.
- The old stacked preview framing was reduced.
- Histogram moved into a small overlay on the preview instead of living as a separate block.
- The right controls pane became visually lighter and less nested.
- Open / save actions moved into the edit pane toolbar.
- The large outer black matte around the window was reduced and turned into lighter chrome.
- The old vertical slab-like reveal rail was replaced with a smaller disclosure chip.

### What changed structurally

- Desktop now uses the shared `FilmLabCanvas` with `stackedToolbarVisible={false}` in edit mode.
- Desktop uses `FilmLabControlPanelCore` with `surface="bare"` to remove an inner card layer.
- Desktop injects a custom “initial look” select into the preset section using a `beforePresets` slot.
- Shared `FilmLabCanvasRef` now exposes:
  - `openMediaPicker()`
  - `saveCurrentPng()`

## Exact Desktop Files Changed

### Shared package changes that matter for Web

#### `packages/film-lab-ui/src/ui/ControlSlider.tsx`

Desktop needed more right-end breathing room for slider rows. The shared slider now accepts `className`.

Why this matters for web:

- Web imports `ControlSlider` via the bridge file:
  - `apps/web/src/features/interactive/film-lab/components/ui/ControlSlider.tsx`
- So web can now pass layout-specific gutter classes without forking the slider component.

#### `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx`

Desktop added:

- `surface?: "card" | "bare"`
- `slots.beforePresets?: ReactNode`

Why this matters for web:

- Desktop uses the shared core directly.
- Web **does not**. Web still has its own local `ControlPanel.tsx`.
- So these additions are useful reference patterns, but web will not automatically inherit them unless it migrates closer to `FilmLabControlPanelCore` or reproduces the same layout ideas locally.

#### `packages/film-lab-ui/src/FilmLabCanvas.tsx`

Committed desktop-related shared changes at `fbce32f`:

- `stackedToolbarVisible?: boolean`
- `FilmLabCanvasRef.openMediaPicker()`
- `FilmLabCanvasRef.saveCurrentPng()`
- refined toolbar button styling

Why this matters for web:

- Web’s `FilmLabCanvas` component is only a bridge to the shared package:
  - `apps/web/src/features/interactive/film-lab/components/FilmLabCanvas.tsx`
- That means web already inherits the shared canvas button styling changes automatically.
- But web does **not** currently use the desktop composition pattern (`stackedToolbarVisible={false}` + bare preview shell + histogram overlay) by default.

### Desktop-only app shell files

#### `apps/desktop-film-lab-batch/src/renderer/App.tsx`

This is where the desktop composition changed most.

Key changes:

- edit-mode root gets `film-lab-desktop-root--edit`
- edit-mode main area gets `fl-main--edge`
- preview section became bare and full-height
- `FilmLabCanvas` is rendered with:
  - `chromeLayout="stacked"`
  - `stackedToolbarVisible={false}`
  - `fullScreen`
- histogram is rendered as an overlay
- edit pane uses `FilmLabControlPanelCore surface="bare"`
- initial look select is injected via `beforePresets`
- open/save actions moved into the right pane toolbar
- collapsed panel trigger changed from the old rail to the new disclosure chip

#### `apps/desktop-film-lab-batch/src/renderer/globals.css`

This file contains the desktop-specific shell polish:

- outer edit-mode chrome treatment
- `fl-main--edge`
- edit preset select styles
- drag zone refinements
- right pane shadow tuning
- final disclosure chip styling (`.fl-edit-pane-toggle-chip`)

#### `apps/desktop-film-lab-batch/messages/ja.json`
#### `apps/desktop-film-lab-batch/messages/en.json`

Added:

- `presetWhenOpenCompactLabel`

Desktop uses this for the compact “initial look” label inside the controls pane.

## Desktop Design Decisions and Why They Were Chosen

### 1. Slider end gutter fix

Problem:

- Right-side slider values were visually cramped against the card edge.
- Outer container padding did not solve it.

Root cause:

- The slider row itself consumed the full width.
- Parent padding changes were not enough because the meaningful layout edge was inside the shared row structure.

Chosen fix:

- Add `className` to shared `ControlSlider`.
- In `FilmLabControlPanelCore`, wrap shared slider rows with `lg:pr-4`.
- Also add matching right inset to hue slider variants.

Why this is important for web:

- If the web panel still feels cramped, adjust row-level spacing, not only outer card padding.

### 2. Remove excessive panel layering

Problem:

- Too many nested frames made the edit pane feel heavy and unsophisticated.

Chosen fix:

- Desktop edit pane switched `FilmLabControlPanelCore` to `surface="bare"`.
- Preview lost its unnecessary card shell.
- Histogram became an overlay instead of a separate block.

Why this matters for web:

- The biggest gain came from removing redundant containers, not from decorative glass alone.
- When porting to web, prefer fewer layers over adding more blurred wrappers.

### 3. Merge actions into the edit context

Problem:

- “Open media” and “Save PNG” felt disconnected from the actual editing workflow.

Chosen fix:

- Move these actions into the edit pane toolbar.
- Iconify them to match the toolbar language.

Why this matters for web:

- If web keeps file/open/save controls far from the control panel, it will still feel split into multiple control systems.

### 4. Reduce the outer black matte

Problem:

- The large outer black area around the desktop composition felt like wasted dead space.

Chosen fix:

- Remove edge padding in edit mode via `fl-main--edge`.
- Reduce the titlebar chrome to a lighter overlay treatment.

Important failure mode discovered:

- A root-level full-window blur/backdrop treatment caused bad visual blur and even renderer instability during HMR iterations.
- Do **not** reintroduce a full-screen `backdrop-filter` layer over the entire app/page as a shortcut for “glass”.

### 5. Replace the reveal rail with a disclosure chip

Problem:

- The old reveal control was a tall slab cut into the right edge.
- It looked like an old web drawer handle, not part of the current glass/toolbar language.

Chosen fix:

- Replace it with a compact disclosure chip near the upper-right area.
- Use a sidebar/disclosure-style icon instead of a lone large chevron.
- Match the material language of the toolbar buttons instead of inventing a second control family.

This commit is:

- `23779cb`

## Desktop Validation That Was Performed

The desktop work was visually validated by repeatedly launching Electron and capturing window screenshots.

Desktop launch command used:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch
pkill -f "electron" 2>/dev/null; sleep 1
bun run build:electron && bun run build:renderer && bun run dev
```

Also used during iterative debugging:

```bash
bun run dev
```

Build validation that passed during the desktop work:

- `apps/desktop-film-lab-batch`: `bun run build:renderer`
- `apps/desktop-film-lab-batch`: `bun run build:electron`
- `apps/web`: `bun run build`

Important caveat observed:

- During HMR-heavy iteration, Electron sometimes ended up in a blank / dark state because the renderer process crashed.
- The symptom was a dark blurred shell with missing content.
- A clean Electron restart fixed that.
- Do not misdiagnose that blank state as a CSS-only issue.

## Current Desktop State at `HEAD`

Current `HEAD` at the time of writing:

- `23779cb` `fix(desktop): replace panel reveal rail with disclosure chip (life#72)`

Desktop commits are complete enough to use as the visual reference for porting to web.

## Important Current Worktree Caveat

At the time this document was written, the repo still had unrelated or experimental uncommitted changes:

- `packages/film-lab-ui/src/FilmLabCanvas.tsx`
- `packages/film-lab-core/dist/index.d.ts`
- `packages/film-lab-core/dist/index.js`
- `.playwright-cli/`
- `packages/film-lab-renderer/dist/`
- `packages/film-lab-renderer/node_modules/`

These are **not** part of the finished desktop UI commit chain for the web handoff.

In particular:

- there is an experimental `pauseVideoPreview` change in the working tree of `packages/film-lab-ui/src/FilmLabCanvas.tsx`
- that change is **not committed**
- do **not** treat it as part of the approved desktop UI baseline unless explicitly asked

For desktop-to-web comparison, prefer:

- the committed history up to `23779cb`
- not the current uncommitted working tree

## Web Architecture Differences That Matter

This is the single most important structural difference:

- **Desktop** edit pane uses `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx`
- **Web** still uses its own:
  - `apps/web/src/features/interactive/film-lab/components/ControlPanel.tsx`

Also:

- Web’s `FilmLabCanvas` is just a bridge to the shared package:
  - `apps/web/src/features/interactive/film-lab/components/FilmLabCanvas.tsx`
- Web’s `Histogram` is also a bridge:
  - `apps/web/src/features/interactive/film-lab/components/ui/Histogram.tsx`
- Web’s `ControlSlider` bridge points to the shared slider:
  - `apps/web/src/features/interactive/film-lab/components/ui/ControlSlider.tsx`

What this means:

- shared canvas-level changes can affect web directly
- desktop pane-shell changes do **not** automatically affect web
- web layout work must happen mainly in:
  - `apps/web/src/features/interactive/film-lab/components/FilmLabFullPage.tsx`
  - `apps/web/src/features/interactive/film-lab/components/ControlPanel.tsx`

## Where the Web Port Should Happen

### Primary web entry point

- `apps/web/src/features/interactive/film-lab/components/FilmLabFullPage.tsx`

Current structure:

- canvas inside a `film-lab-liquid-glass` wrapper
- histogram rendered under the canvas, not as the same kind of desktop overlay treatment
- control panel rendered below the canvas

### Primary web control implementation

- `apps/web/src/features/interactive/film-lab/components/ControlPanel.tsx`

This file remains the local source of truth for:

- presets
- quick/pro mode
- LUT sections
- histogram toggle
- share / browser save / smart look sections
- LP try-first layout behavior

### Shared slider

- `apps/web/src/features/interactive/film-lab/components/ui/ControlSlider.tsx`
  re-exports the shared `film-lab-ui` slider

This matters because:

- web can reuse the same className-based gutter strategy as desktop if needed

## What Should Be Ported to Web

These are the desktop changes that are worth porting conceptually:

### Strongly recommended to port

1. **Flatten the composition**
   - reduce redundant nested glass/card wrappers
   - let the preview feel larger and less boxed-in

2. **Make histogram feel integrated**
   - prefer overlay or more direct attachment to the preview
   - reduce the sense that it is a separate stacked section

3. **Move key actions closer to editing**
   - web equivalent of media open / save actions should feel part of the editing surface, not a separate utility row

4. **Reduce frame-within-frame look**
   - fewer borders, fewer heavy shells, fewer unrelated shadows

5. **Use the compact control language**
   - smaller icon-led controls
   - avoid large slab-like affordances

### Potentially portable, but only if web layout is changed more aggressively

1. **Collapsible right pane behavior**
   - desktop now has a hidden/collapsible edit pane with a disclosure chip
   - web currently does not have that same desktop-shell pattern
   - only port this if you intentionally redesign web desktop layout into a preview + side inspector composition

2. **Disclosure chip**
   - portable only if web gains a true collapsible inspector
   - otherwise do not force this pattern into web unnecessarily

### Desktop-only and should not be copied literally

1. `fl-drag-zone`
2. titlebar chrome logic
3. macOS traffic-light-related spacing
4. Electron window-edge glass framing

## Recommended Web Port Strategy

### Strategy

Do **not** blindly copy desktop JSX.

Instead:

1. Recreate the **visual principles** in web.
2. Port only the shared component changes that help.
3. Rebuild the page composition in `FilmLabFullPage.tsx` and `ControlPanel.tsx` using web-native layout logic.

### Suggested order

1. Inspect current web Film Lab layout in:
   - `apps/web/src/features/interactive/film-lab/components/FilmLabFullPage.tsx`
   - `apps/web/src/features/interactive/film-lab/components/ControlPanel.tsx`

2. Apply the desktop composition principles:
   - bigger preview presence
   - fewer wrappers
   - less stacked-card feeling
   - more integrated histogram

3. Reconcile action placement:
   - decide whether upload/save/share actions should move closer to the top of the control system

4. If the web desktop breakpoint is redesigned into a side inspector:
   - only then consider porting the disclosure-chip idea

5. Verify that LP-specific behavior still works:
   - `tryFirstLayout`
   - donation / smart look / browser save sections

## Recommended File-Level Web Plan

### `apps/web/src/features/interactive/film-lab/components/FilmLabFullPage.tsx`

Likely tasks:

- simplify the outer glass wrapper hierarchy
- make the preview area feel less like a demo block and more like the primary surface
- evaluate whether histogram should become an overlay or a smaller attached element
- decide whether the control panel should remain below the preview or become a side inspector on larger screens

### `apps/web/src/features/interactive/film-lab/components/ControlPanel.tsx`

Likely tasks:

- visually flatten nested sections
- reduce border density
- integrate presets and quick/pro controls more cleanly
- if slider rows feel cramped, apply row-level gutter via shared `ControlSlider className`
- potentially create a compact “initial look” area if that concept is kept for web

### `apps/web/messages/ja.json`
### `apps/web/messages/en.json`

Only if needed:

- add text equivalents for any new compact labels introduced from the desktop concept

Important note:

- web currently already has `film-lab.desktop.app.*` keys in messages, including:
  - `openParamsPanelAria`
  - `paramsPanelAria`
  - `closeParamsPanelAria`
- but web does **not** currently have `presetWhenOpenCompactLabel`

Do not add desktop-specific message keys to web unless the web UI actually needs them.

## Specific Desktop Ideas Worth Reusing in Web Code

### Reuse directly or almost directly

- compact toolbar-style icon buttons
- reduced border count
- overlay histogram concept
- className-capable shared slider rows

### Reuse as inspiration, not literally

- `surface="bare"` concept from desktop `FilmLabControlPanelCore`
- compact “initial look” control placement before presets
- disclosure chip visual language

## Things to Avoid

1. Do not add a full-page `backdrop-filter` layer to fake glass.
2. Do not solve cramped sliders only with outer padding.
3. Do not reintroduce multiple nested rounded cards just because the desktop version uses glass.
4. Do not assume web uses `FilmLabControlPanelCore`; it does not.
5. Web 移植の PR に、Desktop の export バス制御専用の変更を無関係に混ぜない（`pauseVideoPreview` 自体は main に既にある）。

## Validation Checklist for the Web Port

After porting, validate at minimum:

- `apps/web`: `bun run build`
- desktop viewport width on the web page
- mobile layout still works
- histogram toggle still works
- compare / before-after still works
- LUT / share / browser save / smart look sections still behave
- no new hydration issues
- no new over-blur / washed-out glass layers

If a side inspector is introduced:

- hidden / shown state
- keyboard focus visibility
- no overlap with canvas interactions
- no accidental clipping of slider value labels

## Suggested Success Criteria for the Web Port

The web result should feel like the same design language as the desktop edit pane, not a pixel copy.

That means:

- fewer redundant layers
- more confident preview dominance
- controls that feel attached to the editing workflow
- compact utility actions
- cleaner inspector hierarchy
- less “demo widget inside a landing page card” feeling

## High-Precision Transfer Prompt

Use the following prompt in the next chat:

```text
Filmtone Web UI に、desktop issue #72 で確定した編集UIの方向性を移植してください。

必ず最初に以下の handoff doc を読んでください:
docs/guides/2026-03-31-filmtone-72-desktop-to-web-ui-handoff.md

目的:
- desktop で行った UI 改善の意図・構成・判断理由を踏まえて、web 版 Film Lab UI を同じデザイン言語へ寄せる
- 単なる見た目の模倣ではなく、web 側の構造に合わせて最適化する

前提:
- desktop の確定コミット列は以下
  - 2f5bc4d fix(desktop): add end gutter to edit control rows (life#72)
  - fbce32f feat(desktop): flatten edit chrome and merge canvas actions (life#72)
  - d58d2ab fix(desktop): soften titlebar chrome in edit mode (life#72)
  - 23779cb fix(desktop): replace panel reveal rail with disclosure chip (life#72)
- ただし web は desktop と違って FilmLabControlPanelCore を使っていない
- web の ControlPanel は独自実装:
  apps/web/src/features/interactive/film-lab/components/ControlPanel.tsx
- web の page composition の中心は:
  apps/web/src/features/interactive/film-lab/components/FilmLabFullPage.tsx
- web の FilmLabCanvas と Histogram は shared package bridge

やること:
1. docs/guides/2026-03-31-filmtone-72-desktop-to-web-ui-handoff.md を読み、desktop 側の最終意図を把握する
2. apps/web/src/features/interactive/film-lab/components/FilmLabFullPage.tsx を読んで、現在の preview / histogram / control panel の構成を把握する
3. apps/web/src/features/interactive/film-lab/components/ControlPanel.tsx を読んで、現在の panel 階層・preset・quick/pro・LUT・share・smart look の構成を把握する
4. desktop の「余分な層を減らす」「preview を主役にする」「操作を editing context に寄せる」「重い slab UI を避ける」という方針を web に適用する
5. 必要なら shared ControlSlider の className 対応を利用して web の slider row 余白も見直す
6. ただし desktop の drag zone / titlebar chrome / macOS 固有 UI は web に持ち込まない
7. full-page backdrop-filter で雑に glass 化しない
8. 変更後は apps/web で bun run build を通す

期待する成果:
- web の Film Lab UI が desktop の新しい edit UI と同じ design language になる
- frame-within-frame 感が減る
- preview が大きく、自然で、洗練される
- control panel が整理され、余白と階層が改善される
- 必要なら actions の配置も desktop の考え方に合わせて整理される

注意:
- desktop / shared の baseline は **main の最新**を正とする（旧メモの 23779cb 固定は参照用）

進め方:
- まず現状コードを読んで、web 側でどういう構成変更にするかを短く整理
- その後すぐ実装
- 最後に build 結果と、desktop から何を port して何を port しなかったかを簡潔に報告
```
