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

## ⚠️ Requires user machine (live Electron, not available in chat)

These are the items the handoff explicitly marks as live-Electron-only. Each
one is a single command on your machine; the expected results are in
`phase-3-continuation-v2-handoff.md` §2.

| Gate | Command | Expected |
|---|---|---|
| Live boot sanity | `cd apps/desktop-film-lab-batch && bun run desktop` | DevTools console prints `[GpuContext] … adapter … metal-3`. Drag-drop an image; three presets render different output. Resize follows. Close window: no leak warnings. |
| Unit + smoke | `bun run test && bun run test:smart-look-pending && bun run smoke:smart-look-pending` | all pass. |
| Electron build | `bun run build` | clean. |
| Golden 80 matrix | `bun run test:golden -- --baseline B --full` | PSNR ≥ 40 dB on ≥ 75 / 80 cases. Save the CSV to `docs/webgpu-migration/phase-3-golden-report.csv`. |
| Visual proof | capture three screenshots (sunset / backlit / white-dress highlight) → `docs/webgpu-migration/assets/highlight-proof/` |
| DMG build | `bun run dist:mac:unsigned` → `release/Filmtone-1.0.0-arm64.dmg` | 10-minute hands-on: mount → drag to `/Applications` → load image → 3 presets → 1 video export → 1 smart-look → stress for 10 min. |

The handoff has a top-to-bottom runbook with the matching commands in
`phase-3-continuation-v2-handoff.md` §2 T3-4 / T3-5.

## ⚠️ Known limits at ship (already covered by RELEASE_NOTES-v1.0.0.md)

- Cross-filter render-time integration → v1.1 (WGSL is compile-validated,
  render-graph editing + preset round-trip is the v1.1 scope). All 8 v1.0
  factory presets have `crossFilterStrength: 0`, so the 80-matrix PSNR gate
  is not exercised by this code path.
- Video export / batch export → WebGL2 for v1.0, WebGPU `GpuRenderer` in v1.1.
- Hard Mode temporal cross-filter → v1.1 (unchanged from v0.6.x decisions).
- HDR / P3 output → v2.0.

## ⚠️ Risks

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

## Commit plan (local → push when you're ready)

All Phase-3 structural work is already on `feature/webgpu-migration-v1`
(commits `0d6f53fb`, `e08a6ec1`, `2768e448`). The remaining uncommitted
work from this chat is the single "live flip + release artifacts" set.
Suggested commit:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

git add \
  packages/film-lab-ui/src/FilmLabCanvas.tsx \
  apps/desktop-film-lab-batch/package.json \
  apps/desktop-film-lab-batch/RELEASE_NOTES-v1.0.0.md \
  apps/desktop-film-lab-batch/docs/webgpu-migration/SHIP-READINESS.md \
  apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md

git commit -m "$(cat <<'EOF'
Phase 3 T3-3 live flip + v1.0.0 release artifacts

- FilmLabCanvas: backend-agnostic canvas bootstrap. The effect now creates a
  fresh canvas (no prior WebGL2 context), probes isWebGPUSupported() async,
  and commits to one backend. WebGL path constructs THREE.WebGLRenderer with
  `canvas:` option on the same element; WebGPU path attaches the swapchain
  inside Viewport.create and drives rendering without a THREE renderer.
  handleDownload / getJpegBase64ForAi / getWebGlCanvas / getPreviewHealth now
  read from a shared canvasRef so they work on either backend. WebGL
  context-lost listener is wired only on the WebGL branch. Prewarm is
  awaited inside the WebGPU branch so the first animation frame does not
  stutter on pipeline compile.
- Desktop version 0.6.2 → 1.0.0.
- RELEASE_NOTES-v1.0.0: WebGPU preview + Linear Rec.709 rgba16float working
  space. Cross-filter render-integration and video/batch export WebGPU move
  to v1.1; web stays on WebGL2.
- SHIP-READINESS.md: single-decision checklist (merge / hold). Evidence:
  film-lab-renderer tsc + build clean, film-lab-ui / desktop / apps-web tsc
  regression delta 0, tree-shake verified (main 144 KB + lazy 219 KB chunk).
- STATUS.md: Phase 3 closeout; live-Electron gate items explicitly marked as
  user-machine work (bun run desktop / test:golden / dist:mac:unsigned).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

git push origin feature/webgpu-migration-v1
```

After the live-Electron gates pass, the follow-up commit is mechanical:

```bash
git add \
  apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-golden-report.csv \
  apps/desktop-film-lab-batch/docs/webgpu-migration/assets/highlight-proof \
  apps/desktop-film-lab-batch/RELEASE_NOTES-v1.0.0.md  # checksum line

git commit -m "$(cat <<'EOF'
Phase 3 T3-4 / T3-5: Golden 80 PSNR report + DMG checksum

Live Electron + test:golden -- --baseline B --full pass
(PSNR >= 40 dB on N/80 cases). DMG v1.0.0-arm64 unsigned generated
and 10-min hands-on QA pass. Checksum line filled in RELEASE_NOTES.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

## v1.1 issues to open after ship

From `phase-3-continuation-v2-handoff.md` §4, to be created once v1.0 is
tagged:

- `v1.1: activate WebGPU cross-filter render integration (Soft + Hard Mode)`
- `v1.1: migrate video-export-pipeline to WebGPU headless GpuRenderer`
- `v1.1: migrate batch-pipeline to WebGPU headless GpuRenderer`
- `v1.3: migrate apps/web film-lab canvas to WebGPU`
