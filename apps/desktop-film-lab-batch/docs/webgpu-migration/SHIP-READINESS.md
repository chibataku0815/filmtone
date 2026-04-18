# v1.0 SHIP READINESS (2026-04-18)

**Branch**: `feature/webgpu-migration-v1`
**Target tag**: `desktop-v1.0.0`
**Decision scope**: merge into `main` + tag + DMG release, or hold with a named issue.

This document is the one-decision gate for v1.0. Everything below is the
evidence the phase chat collected. Read the ✅ section, the ⚠️ section, and
the Decision section — that is the minimum. The full commit / code evidence
lives in `STATUS.md` and `phase-3-continuation-v2-handoff.md`.

---

## ✅ Passed (phase chat, Claude-side)

| Gate | Result |
|---|---|
| `film-lab-renderer` `bunx tsc --noEmit` | exit 0 (clean) |
| `film-lab-renderer` `bun run build` | main `dist/index.js` 144 KB, WebGPUBackend is a lazy chunk (`chunk-Z3VCXL6F.js` 219 KB + 83-byte re-export stub). Tree-shake verified: web bundles set `FILMTONE_BACKEND=webgl` and the dynamic `import()` is never executed, so the chunk is not fetched. |
| `film-lab-ui` `bunx tsc --noEmit` | 1 pre-existing error (`FilmLabCanvasPackageEntry.tsx:51` TS4023 — `FilmLabCanvasProps` naming, predates this branch). **Regression delta 0.** |
| `desktop-film-lab-batch` `bunx tsc --noEmit` | 17 errors = Phase 2 baseline exactly (11 in electron/main.ts / batch-pipeline / video-export / BatchTabPanel that predate Phase 3, 4 in smart-look tests / viewport-to-params, 2 in FilmLabCanvas for the pre-existing `BASE_URL` vitest type gap). **Regression delta 0.** |
| `apps/web` `bunx tsc --noEmit` | clean (0 errors) — WebGPU path is dynamically imported, web-bundle type check unaffected. |
| Viewport composition API contract | 20-method delegation surface preserved (render / setResolution / setTexture / setParams / setLUT1+setLUT2 / split / motion blur / bindThree / histogram / dispose / prewarm). `backendKind` + `mesh?` narrowed type is gated at the 3 known `scene.add(mesh)` call sites. |
| Electron `--enable-unsafe-webgpu` switch | Added to `electron/main.ts` before `app.whenReady()`. Harmless when WebGPU is already enabled (Phase 0 Case A). |
| FilmLabCanvas WebGPU branching | `useEffect` now creates a fresh canvas, probes `isWebGPUSupported()` inside the async IIFE, and commits to one backend. WebGL path constructs `THREE.WebGLRenderer({ canvas, … })` so the same element works for either backend. WebGPU path skips the THREE renderer entirely and drives the swapchain through `viewport.render()`. `handleDownload` / `getJpegBase64ForAi` / `getWebGlCanvas` now read from the backend-agnostic `canvasRef`. |
| Prewarm wiring | `await viewport.prewarm()` is called on the WebGPU path inside the bootstrap IIFE so the first animation frame does not stutter on pipeline compile. Phase 0 Case A measured bootstrap < 100 ms — the 150 ms silent UX budget is covered without an explicit overlay. |

## ✅ Also passed in this chat (headless)

After the initial hand-off split, these items ran cleanly from the phase chat
without needing your machine:

| Gate | Command | Result |
|---|---|---|
| Desktop vitest suite | `bun run test` | **52 / 52 passed**, 1.48 s (re-run post GpuContext fix). |
| Desktop `bun run build` | — | clean; main renderer bundle `index-DUzs1Rez.js` 1388 KB (gzip 372 KB), **WebGPU split into its own chunk** `WebGPUBackend-WMAUKCOP-DRIzOF_O.js` 195 KB (gzip 88 KB) — lazy load verified. |
| Desktop DMG | `bun run dist:mac:unsigned` | **`release/filmtone-1.0.0-arm64.dmg` rebuilt (194 MB)**. Ad-hoc codesigned, notarization intentionally skipped. New SHA-256 recorded in `RELEASE_NOTES-v1.0.0.md` — supersedes the pre-fix 2026-04-18 DMG (`8cfd1734…`). |
| WebGPU QA blocker fix | code+docs | **Applied** — see `v1.0-qa-blocker-handoff.md` §8. GpuContext canvas configure is now WebGPU-spec compliant (rgba8unorm + sRGB viewFormats), Viewport silent fallback is removed, FilmLabCanvas shows explicit `canvas.webgpuRequired` / `canvas.webgpuInitFailed` error UI when WebGPU is unavailable. |

## ⚠️ Requires user machine (irreducible)

| Gate | Runbook | Why only you |
|---|---|---|
| **10〜15 分の実機 QA(動画重視)** | 専用 runbook: [`v1.0-qa-runbook.md`](./v1.0-qa-runbook.md)。Pre-flight → Step 1 静止画 → **Step 2 動画プレビュー** → **Step 3 preview vs export 色マッチ**(最重要)→ Step 4 LUT → Step 5 ストレス → Step 6 終了。Smart Look は触らない(Desktop で frozen)。 | Subjective visual accept。色マッチ確認は圧縮後動画フレームをプレビュー出力と並べて目視する作業なので自動化できない。 |
| **Decision checkbox** | — | Ship / hold judgment。 |

## ⚠️ Gap found in this chat: golden-matrix PSNR harness not wired

`bun run test:golden` currently only **captures** to `test/golden/baseline-<label>/`
and asserts the count is 80 — there is no PSNR comparison against Baseline B
in code yet. `test/golden-psnr.ts` exposes `compareAgainstBaselineB(...)` but no
spec calls it, and the Playwright config has no `webServer` entry, so
`test:golden` needs vite running at 5173 manually. This means the objective
80-case PSNR gate referenced in the handoff is not currently runnable as-is.

**Impact on v1.0 ship**: deferring this to a v1.0.1 follow-up is reasonable
given every factory preset passes `crossFilterStrength: 0` so the WebGPU path
exercises only the Soft-mode pipeline that Phase 2 already validated by eye.
The hands-on QA is the v1.0 acceptance signal. `v1.0.1: wire the 80-matrix
PSNR gate into vitest / playwright (vite webServer + tmp-dir capture + csv
report)` should be filed after ship.

## ⚠️ Known limits at ship (already covered by RELEASE_NOTES-v1.0.0.md)

- Cross-filter render-time integration → v1.1 (WGSL is compile-validated,
  render-graph editing + preset round-trip is the v1.1 scope). All 8 v1.0
  factory presets have `crossFilterStrength: 0`, so the 80-matrix PSNR gate
  is not exercised by this code path.
- Video export / batch export → WebGL2 for v1.0, WebGPU `GpuRenderer` in v1.1.
- Hard Mode temporal cross-filter → v1.1 (unchanged from v0.6.x decisions).
- HDR / P3 output → v2.0.

## ⚠️ Risks

- **Preview (WebGPU) と Video export (WebGL) の色が highlight で乖離する可能性
  [最重要、v1.0 固有]**。Preview は rgba16float 線形 Rec.709 + no-clamp、Video
  export は既存の WebGL2 パス(rgba8 + clamp)。shader と LUT は同じなので通常
  領域では同じ見えになるが、1.0 超過の highlight を含むシーンでは理論上ズレる。
  QA runbook の Step 3 で **同フレームの preview 静止画 と export 動画の frame
  を並べて目視** することが v1.0 ship 判断の主ゲート。乖離パターン別の判断
  フローは [`v1.0-qa-runbook.md`](./v1.0-qa-runbook.md) §Step 3 の Fail 時フロー。
- **WebGPU bootstrap fails on first boot.** `Viewport.create` catches the
  exception, logs `[Viewport] WebGPU backend bootstrap failed — falling back
  to WebGL` and constructs a WebGL backend. BUT the fresh canvas we passed in
  may already own a half-configured WebGPU context in that case, so the
  subsequent WebGL2 context acquisition inside `THREE.WebGLRenderer` would
  throw. In practice Phase 0 Case A on macOS 15.x / Electron 32 boots
  WebGPU cleanly, so this path is exercised only on machines that fail the
  adapter request outright. If the user hits it, the preview will be black
  and the console will show both the fallback log and a THREE context error
  — escalate to direction chat (DIRECTION §9 Case C).
- **Preset round-trip (WebGPU) loses granular state.** `Viewport.getParams()`
  on the WebGPU path returns `getPendingParams()`, which is the last
  `setParams` blob the backend received. For factory presets that is
  complete; user-modified state flowing through `App.tsx:847` should still
  round-trip correctly because the same keys go in and come out. If a user
  preset saved on v0.6.x contains keys the WebGPU backend doesn't recognize,
  they are preserved as opaque values (the backend only consumes the keys it
  knows about and keeps the rest). The first real-world preset save / load
  on live Electron is the verification step.
- **`toDataURL` on the WebGPU canvas.** Chrome / Electron's WebGPU canvas
  implementation is expected to service `canvas.toDataURL()` by reading back
  the current swapchain texture, but it is slower than WebGL's
  `preserveDrawingBuffer` readback. If the live-Electron download is
  noticeably slow or returns a black frame, escalate — we can switch to an
  explicit `copyTextureToBuffer` readback in v1.0.1.

## Decision

- [ ] **Ship v1.0.0** — merge `feature/webgpu-migration-v1` into `main`, tag
  `desktop-v1.0.0`, run `bun run dist:mac:release` once signed+notarized
  release is planned.
- [ ] **Hold** — open a follow-up issue with the failing gate from the ⚠️
  section and link it back here.

## Commit status

- Live-flip + release artifacts: commit `c1987104` on
  `origin/feature/webgpu-migration-v1` (pushed).
- Headless run artifacts added in a follow-up commit:
  - `RELEASE_NOTES-v1.0.0.md` checksum line (SHA-256 of the DMG).
  - `SHIP-READINESS.md` — reflects what this chat actually ran vs. what still
    needs your machine.

Post-ship, after the 10-min QA passes, there is nothing else to commit — the
only change is flipping the Decision checkbox and creating the release tag
with `bun run dist:mac:release`.

## v1.1 issues to open after ship

From `phase-3-continuation-v2-handoff.md` §4, to be created once v1.0 is
tagged:

- `v1.1: activate WebGPU cross-filter render integration (Soft + Hard Mode)`
- `v1.1: migrate video-export-pipeline to WebGPU headless GpuRenderer`
- `v1.1: migrate batch-pipeline to WebGPU headless GpuRenderer`
- `v1.3: migrate apps/web film-lab canvas to WebGPU`
