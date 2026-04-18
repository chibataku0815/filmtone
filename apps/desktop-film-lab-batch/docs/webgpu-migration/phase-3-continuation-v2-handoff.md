# Phase 3 Continuation v2 Handoff — live-Electron ship chat

**作成**: 2026-04-18
**前 chat 担当範囲**: T3-1(cross-filter WGSL 5 本)+ T3-3(Viewport composition refactor)+ Electron `enable-unsafe-webgpu` flag
**本 chat 担当範囲**: live-Electron で FilmLabCanvas/App.tsx を WebGPU 切替 → T3-4 Golden 80 matrix → T3-5 DMG v1.0.0 → T3-5.5 SHIP-READINESS
**Non-goal (v1.1 送り)**: T3-2 headless GpuRenderer 抽出、cross-filter render-time integration、Hard Mode temporal

この 1 枚 + `DIRECTION.md` + `STATUS.md` + (参考) `phase-3-continuation-handoff.md`(v1、前々 chat)+ `phase-3-handoff.md` で再開可。

---

## 1. 前 chat の確定事項(commit 前、feature branch working tree)

### コード変更

| File | 変更 | 目的 |
|---|---|---|
| `packages/film-lab-renderer/src/Viewport.ts` | **全面書き換え**(extends WebGLBackend → 明示的 composition) | D3 遵守、WebGPU 分岐を内部に閉じ込める |
| `packages/film-lab-renderer/src/webgpu/shaders/cross-filter-*.frag.wgsl.ts` | 新規 5 本 | T3-1 WGSL 移植(前々 chat) |
| `packages/film-lab-renderer/src/webgpu/shaders/index.ts` | 5 export 追記 | T3-1(前々 chat) |
| `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts` | cross-filter 5 shader を `create()` で compile-validate | T3-1(前々 chat) |
| `apps/desktop-film-lab-batch/electron/main.ts` | `app.commandLine.appendSwitch("enable-unsafe-webgpu")` 追加(`app.whenReady()` 前) | T3-3 safety-net |
| `packages/film-lab-ui/src/FilmLabCanvas.tsx` | L794 `scene.add(viewport.mesh)` を `if (backendKind === 'webgl' && mesh) scene.add(mesh)` に | Viewport の `mesh` 型 narrow 対応 |
| `apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts` | L400 同上 | 同上 |
| `apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts` | L1036 同上 | 同上 |
| `apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md` | Phase 3 構造着地記録 + 次 chat kickoff snippet 更新 | 状態保全 |
| `apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-continuation-v2-handoff.md` | **新規(本ファイル)** | 次 chat 資料 |

### Viewport composition の API 変更点

**維持されたもの**(consumer code 破壊なし):
- `Viewport.create(canvas, { prefer, width, height })` — factory 形
- `render / setResolution / setTexture / setImageResolution / setFitMode / setTime / setParams / getParams`
- `setLUT1 (+Intensity, +clear) / setLUT2 (+Intensity, +clear)`
- `setLUT / setLUTIntensity / clearLUT`(deprecated aliases、apps/webgl-study の debug-gui 向け)
- `setSplitPosition / getSplitPosition`
- `setExportFlipY`
- `resetMotionBlurHistory`
- `bindThree / setComparePair / getHistogramPixels`(WebGL-only、webgpu 分岐では no-op)
- `dispose / destroy`

**新規**:
- `readonly backendKind: 'webgl' | 'webgpu'`
- `readonly mesh?: THREE.Mesh`(WebGL 分岐のみ存在、WebGPU では undefined)
- `setMediaFromBitmap(bitmap)` — WebGPU-native input
- `async prewarm(): Promise<void>` — WebGPU pipeline JIT 予熱、WebGL は no-op

**破壊的変更**(granular setter の消失):
- `viewport.setExposure / setContrast / setSaturation / setRGBShift / ... / setCrossFilterXxx` の **public 型から消失**
- 影響: film-lab-renderer 消費者は全て `setParams(record)` 経由で駆動しており破壊なし(`grep viewport\.set…` で検証済)
- 例外: `apps/webgl-study/05-tao-tajima/` は独立の Viewport を使っており film-lab-renderer を import していない(確認済)

### 検証結果

- `cd packages/film-lab-renderer && bunx tsc --noEmit` → exit 0
- `cd packages/film-lab-renderer && bun run build` → clean
- `dist/index.js` 150 KB、WebGPUBackend の 2 match は **L3465-3466 の dynamic `import()` 呼び出し位置のみ**、クラス本体は `dist/chunk-Z3VCXL6F.js` 219 KB に分離
- `dist/webgpu.js` 1.4 KB(sub-path re-export stub)
- web bundle は `prefer: 'webgl'` で dynamic import を trigger せず、該当 chunk を一切 fetch しない
- `cd apps/desktop-film-lab-batch && bunx tsc --noEmit` → 17 errors = Phase 2 baseline、**regression delta 0**

### 前 chat の commit 構成案(user 承認 → batch 実行)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

# Commit 1 — T3-1 WGSL 5 本 + pipeline compile-validate(前々 chat の未 commit 分)
git add \
  packages/film-lab-renderer/src/webgpu/shaders/cross-filter-blend.frag.wgsl.ts \
  packages/film-lab-renderer/src/webgpu/shaders/cross-filter-peak-spacing-max.frag.wgsl.ts \
  packages/film-lab-renderer/src/webgpu/shaders/cross-filter-peak-spacing.frag.wgsl.ts \
  packages/film-lab-renderer/src/webgpu/shaders/cross-filter-peak.frag.wgsl.ts \
  packages/film-lab-renderer/src/webgpu/shaders/cross-filter-streak.frag.wgsl.ts \
  packages/film-lab-renderer/src/webgpu/shaders/index.ts \
  packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts

git commit -m "$(cat <<'EOF'
Phase 3 T3-1: port 5 cross-filter shaders to WGSL; compile-validate

Add peak / peak-spacing-max / peak-spacing / streak / blend ports from
src/webgl/shaders/cross-filter-*.frag.ts. Each WGSL is wired into
WebGPUBackend.create so GPU-side WGSL correctness is validated at backend
init via pushErrorScope('validation'). Runtime render integration is
deferred to v1.1 alongside Hard Mode (D5): all 8 v1.0 presets ship with
crossFilterStrength: 0, so the Golden 80-matrix PSNR gate (>=40dB 75/80)
is unaffected by the deferral.

Tree-shake retained via dynamic import in the Viewport composition layer
(next commit). film-lab-renderer tsc clean; desktop tsc 17 errors
(Phase 2 regression delta 0).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

# Commit 2 — T3-3 Viewport composition + Electron flag + consumer mesh-guard
git add \
  packages/film-lab-renderer/src/Viewport.ts \
  apps/desktop-film-lab-batch/electron/main.ts \
  packages/film-lab-ui/src/FilmLabCanvas.tsx \
  apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts \
  apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts

git commit -m "$(cat <<'EOF'
Phase 3 T3-3: Viewport composition + Electron unsafe-webgpu flag

- Viewport: drop `extends WebGLBackend`, compose WebGLBackend | WebGPUBackend
  with an explicit 20-method delegation surface. `prefer: 'webgpu'` now
  dynamically imports WebGPUBackend, falls back to WebGL on bootstrap error.
  `mesh` is now `THREE.Mesh | undefined` (WebGL-only); `backendKind` added.
  Granular setters (setExposure etc.) removed from public type — all
  consumers already drive via setParams(record).
- Tree-shake: WebGPUBackend moved to a lazy chunk via dynamic import.
  dist/index.js: WebGPUBackend appears only at the import() call site;
  class body lives in dist/chunk-*.js (219 KB), never fetched in web builds.
- Electron main.ts: add `--enable-unsafe-webgpu` as a safety-net switch
  (harmless when WebGPU is already enabled per Phase 0 Case A).
- Guard 3 consumer call sites (FilmLabCanvas:794 / batch-pipeline:400 /
  video-export-pipeline:1036) with `backendKind === 'webgl' && mesh`
  before `scene.add(mesh)` to absorb the type narrowing.

film-lab-renderer tsc clean, tsup build clean, tree-shake verified.
desktop tsc 17 errors = Phase 2 baseline (regression delta 0).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

# Commit 3 — docs only
git add \
  apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md \
  apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-continuation-handoff.md \
  apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-continuation-v2-handoff.md

git commit -m "$(cat <<'EOF'
docs(webgpu-migration): Phase 3 structural handoff + v2 continuation

STATUS: record T3-1 / T3-3 / Electron flag landed with verification
metrics; update next-chat kickoff snippet. Decisions log entry for
T3-2 GpuRenderer deferral to v1.1 (rationale: video-export / batch can
ship v1.0 on WebGL, reducing live-Electron flip regression surface).

phase-3-continuation-v2-handoff.md: new document covering remaining
Phase 3 scope for the next live-Electron chat — FilmLabCanvas/App.tsx
flip, T3-4 Golden 80 matrix, T3-5 DMG v1.0.0, T3-5.5 SHIP-READINESS.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

# Push: ユーザー判断
git push origin feature/webgpu-migration-v1
```

---

## 2. 本 chat で実行する残タスク(順序付き)

### Critical path

```
T3-3 残 (2h)  FilmLabCanvas WebGPU 分岐 + App.tsx prewarm 配線
    ↓
T3-4 (1h)     bun run desktop で live 確認 + test:golden 80 matrix
    ↓
T3-5 (30min)  version 1.0.0 bump + RELEASE_NOTES + dist:mac:unsigned
    ↓
T3-5.5 (15min) SHIP-READINESS.md 生成 → user 1 択判断
```

---

### T3-3 残: FilmLabCanvas WebGPU 分岐(最重要、~90min)

**問題**: 現状 FilmLabCanvas.tsx は `renderer.domElement` を canvas として使うが、この canvas は既に WebGL2 context を持っているので `canvas.getContext('webgpu')` は null を返す。WebGPU 化には fresh canvas が必要。

**実装方針**: FilmLabCanvas の useEffect 内で backend を決定 → backend に応じて異なる canvas 生成 + rendering loop を持つ。

**推奨 diff パターン**(`packages/film-lab-ui/src/FilmLabCanvas.tsx` L718-873 周辺):

```tsx
useEffect(() => {
  const container = containerRef.current;
  if (!container) return;

  const BACKEND_PREF: ViewportBackendPreference =
    typeof import.meta.env?.FILMTONE_BACKEND === "string"
      ? (import.meta.env.FILMTONE_BACKEND as ViewportBackendPreference)
      : "webgpu";  // desktop default

  if (BACKEND_PREF === "webgl" && !isWebGL2Supported()) {
    setSupported(false);
    return;
  }
  // WebGPU support is probed inside Viewport.create; fallback is automatic.

  let width = Math.max(1, container.clientWidth);
  let height = Math.max(1, container.clientHeight);

  // canvas はシングル要素として確保。WebGL 分岐は THREE.WebGLRenderer が
  // この canvas に WebGL2 context を張る。WebGPU 分岐は Viewport.create 内で
  // canvas.getContext('webgpu') を張る。
  const canvas = document.createElement("canvas");
  canvas.style.display = "block";
  canvas.style.width = "100%";
  canvas.style.height = "100%";
  container.appendChild(canvas);

  let renderer: THREE.WebGLRenderer | null = null;
  let scene: THREE.Scene | null = null;
  let camera: THREE.OrthographicCamera | null = null;
  let viewport: Viewport | null = null;
  let animationId = 0;
  let resizeObserver: ResizeObserver | null = null;
  let resizeRafId = 0;
  let cancelled = false;

  const syncViewportSize = () => {
    if (!viewport) return;
    const nextWidth = Math.max(1, container.clientWidth);
    const nextHeight = Math.max(1, container.clientHeight);
    if (nextWidth === width && nextHeight === height) return;
    width = nextWidth;
    height = nextHeight;
    if (renderer) {
      renderer.setSize(width, height);
    } else {
      canvas.width = width;
      canvas.height = height;
    }
    viewport.setResolution(width, height);
  };
  window.addEventListener("resize", syncViewportSize);

  void (async () => {
    const vp = await Viewport.create(canvas, {
      prefer: BACKEND_PREF,
      width,
      height,
    });
    if (cancelled) {
      vp.dispose();
      return;
    }
    viewport = vp;

    if (vp.backendKind === "webgl") {
      // WebGL path: 既存の THREE.WebGLRenderer を canvas に張る
      renderer = new THREE.WebGLRenderer({
        canvas,  // 既存 canvas を使う(createElement で作成済み)
        antialias: false,
        alpha: false,
        preserveDrawingBuffer: true,
      });
      renderer.setSize(width, height);
      renderer.setPixelRatio(getOptimalPixelRatio(1.5));
      renderer.outputColorSpace = THREE.SRGBColorSpace;
      rendererRef.current = renderer;

      scene = new THREE.Scene();
      scene.background = new THREE.Color(0x0a0a0a);
      camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
      camera.position.z = 1;
      sceneRef.current = scene;
      cameraRef.current = camera;

      if (vp.mesh) scene.add(vp.mesh);
    } else {
      // WebGPU path: canvas.getContext('webgpu') は Viewport.create 内で既に張られた
      rendererRef.current = null;
      sceneRef.current = null;
      cameraRef.current = null;
      // pre-warm: 150ms 未満 silent / 300ms 以上 overlay(UX は App.tsx 側で計測)
      await vp.prewarm();
    }

    viewportRef.current = viewport;
    onViewportReadyRef.current?.(viewport);
    viewport.setParams(buildViewportParams(initialResolvedGradeRef.current));
    void restoreCurrentSource();

    syncViewportSize();
    resizeObserver =
      typeof ResizeObserver !== "undefined"
        ? new ResizeObserver(() => syncViewportSize())
        : null;
    resizeObserver?.observe(container);
    resizeRafId = window.requestAnimationFrame(() => syncViewportSize());

    const clock = new THREE.Clock();
    const animate = () => {
      animationId = requestAnimationFrame(animate);
      if (
        !viewport ||
        previewContextLostRef.current ||
        (renderer && isRendererContextLost(renderer)) ||
        pauseVideoPreviewRef.current ||
        previewRenderingHoldRef.current
      ) {
        return;
      }
      viewport.setTime(clock.getElapsedTime());
      if (renderer && scene && camera) {
        viewport.render(renderer, scene, camera);
      } else {
        viewport.render();  // WebGPU: canvas 直描画
      }
    };
    animate();
  })();

  return () => {
    cancelled = true;
    if (animationId) cancelAnimationFrame(animationId);
    if (resizeRafId) window.cancelAnimationFrame(resizeRafId);
    resizeObserver?.disconnect();
    window.removeEventListener("resize", syncViewportSize);
    if (renderer) {
      try { renderer.forceContextLoss(); } catch { /* ignore */ }
      renderer.dispose();
    }
    activeTextureRef.current?.dispose();
    activeTextureRef.current = null;
    disposePreviewVideoElement(previewVideoElementRef.current);
    viewport?.dispose();
    previewVideoElementRef.current = null;
    previewVideoShouldResumeRef.current = false;
    previewVideoPausedByBusyRef.current = false;
    if (container.contains(canvas)) container.removeChild(canvas);
    viewportRef.current = null;
    mediaLoaderRef.current = null;
    rendererRef.current = null;
    sceneRef.current = null;
    cameraRef.current = null;
    onViewportReadyRef.current?.(null);
  };
}, [
  applyLoadedTextureResult,
  disposePreviewVideoElement,
  restoreCurrentSource,
  canvasRuntimeNonce,
]);
```

**注意点**:
1. `webglcontextlost` listener は WebGL 分岐のみ必要。WebGPU は `device.lost` を `GpuContext.create` 内で監視している。追加したい場合は `viewport.backendKind === 'webgpu'` 時のみ分岐を書く。
2. L220-221 の `import.meta.env.BASE_URL` 既存エラーは無関係(baseline に含まれる)。触らない。
3. L893-903 の A/B 比較(`splitBefore`/`splitBefore`)は WebGL 限定の機能。WebGPU 分岐では `viewport.render()` 単独呼び出しに書き換え、`setSplitPosition(-1)` は維持(WebGPU backend にも setter あり)。ただし A/B 比較自体は WebGL のみなので if ガードで無効化して良い。
4. `Histogram.tsx` の `getHistogramPixels()` は WebGL 分岐のみ機能。WebGPU 時は null を返す(UI 側は null でグレーアウト等の扱いを既に持っているか確認、なければ最小パッチ)。

**Exit criteria**(`bun run desktop` で確認):
1. 起動 → DevTools Console に `[GpuContext] … adapter … metal-3` ログ
2. 画像 load(drag-drop)→ 色が出る(identity preset)
3. Preset 切替 3 種(cinematic / portra / bw)→ 視覚的に変化
4. Resize → canvas 追従
5. Close → GPU リソース解放(console に leak warning 無し)

### T3-3 残: App.tsx prewarm overlay(~15min、任意)

- `viewport.prewarm()` 呼出自体は FilmLabCanvas 内で完結(上記 diff に含む)
- App.tsx 側に "Preparing renderer…" overlay を出したい場合のみ:
  - `useViewport(onViewportReady)` 経由で viewport が ready になった時刻を計測
  - init から viewport ready まで > 150ms → overlay fade in
  - viewport ready → overlay fade out(> 300ms 経過していたら animated fade、未満なら instant hide)
- DIRECTION §10 Phase 3 の「150ms 未満 silent / 300ms 以上 fade」規定に合わせる
- Phase 0 Case A 疎通実績から Electron 実機では prewarm 自体が 50-80ms 程度の見込み(overlay 不要になる可能性高い)

### T3-4 Golden 80 matrix(~1h、live Electron)

```bash
cd apps/desktop-film-lab-batch
bun run typecheck          # regression delta 0 維持
bun run test               # vitest + 既存 unit
bun run test:smart-look-pending
bun run smoke:smart-look-pending
bun run build              # electron bundle
bun run test:golden -- --baseline B --full
```

- 合格基準: PSNR ≥ 40dB が **75/80 以上**(単一 regression accept、5+ は direction chat escalate)
- 結果 CSV → `docs/webgpu-migration/phase-3-golden-report.csv`
- 低 PSNR top 5 を目視 → 許容差分判定
- Phase 2 繰越 5 preset × 10 image gate は 80 matrix の subset として自動回収
- 視覚証明 screenshot 3 枚 → `docs/webgpu-migration/assets/highlight-proof/`

**注意**: video-export / batch-pipeline は引き続き WebGL を `prefer: 'webgl'` で使っている(既存コード維持)。Golden 80 matrix は FilmLabCanvas の live preview path を検証するもので、export paths は対象外。export path の WebGPU 化は v1.1 scope。

### T3-5 DMG + RELEASE_NOTES(~30min)

1. `apps/desktop-film-lab-batch/package.json` version 0.6.2 → 1.0.0
2. `apps/desktop-film-lab-batch/RELEASE_NOTES-v1.0.0.md` 起案(既存 `RELEASE_NOTES-v0.*.md` 書式踏襲):

```md
# v1.0.0 — WebGPU migration

## Headline
- Linear Rec.709 + rgba16float working space(clamp 除去、LUT 前で広いレンジ保持)
- WebGPU backend(macOS arm64、preview path)、WebGL backend は web 向け + video/batch export で温存
- Hardware sRGB OETF で最終 display transform

## Known limits
- Cross-filter(Soft + Hard Mode)は v1.1 で render integration 予定。保存 preset の
  `hardMode: true` / `crossFilterStrength > 0` は読込時に 0 へ落として console warning 出力
- Video export / Batch export は引き続き WebGL 経路(v1.1 で headless GpuRenderer 経由に移行予定)
- apps/web 側は引き続き WebGL(v1.3 で WebGPU 化予定)
- HDR / P3 出力は未対応(v2.0 ロードマップ)

## Compatibility
- macOS 13+ arm64 / Intel、Electron 32 系
- Preview が WebGPU 起動に失敗した場合は自動的に WebGL にフォールバック(Viewport.create の fallback path)
```

3. `cd apps/desktop-film-lab-batch && bun run dist:mac:unsigned` → `release/Filmtone-1.0.0-arm64.dmg`
4. 実機 QA(DMG mount → /Applications drag → 起動 → 画像 load → preset 3 種 → video 1 本 → smart-look 1 回 → 10 min ストレス)
5. Highlight 豊富な画像で LUT2 highlight gradient 確認

### T3-5.5 SHIP-READINESS.md(~15min)

生成先: `apps/desktop-film-lab-batch/docs/webgpu-migration/SHIP-READINESS.md`

User が 5-10 分で読んで **merge or hold の 1 択** に圧縮するのが目的。既定項目:

```md
# v1.0 SHIP READINESS(2026-MM-DD)

## ✅ Passed
- [ ] film-lab-renderer tsc exit 0
- [ ] desktop tsc regression delta 0(17 errors = baseline)
- [ ] bun run build clean(main 150 KB + lazy chunk 219 KB、tree-shake 維持)
- [ ] bun run test — vitest pass
- [ ] bun run test:golden -- --baseline B --full — PSNR ≥ 40dB: N/80(≥ 75 target)
- [ ] 視覚証明 3 枚取得(sunset / backlit / white dress)
- [ ] DMG v1.0.0-arm64 unsigned generated + 10 min 実機 QA pass

## ⚠️ Known limits(RELEASE_NOTES 記載済)
- Cross-filter render integration → v1.1
- Video/Batch export は WebGL 継続 → v1.1
- HDR / P3 出力 → v2.0

## ⚠️ Risks
- Electron 実機で WebGPU bootstrap 失敗 → WebGL 自動 fallback(Viewport.create catch 済)
- Preset round-trip(getParams → setParams)で WebGPU 時に WebGL の getParams 完全互換ではない(`getPendingParams` 経由、最低限の key しか返らない可能性)
  - 対策: App.tsx:847 の round-trip で失敗した場合は Log + default fallback

## Decision
- [ ] Ship v1.0.0(main に merge + tag + release)
- [ ] Hold(具体的 issue を直下に書く)
```

---

## 3. Escalation への備え

### 「WebGPU bootstrap がどうしても通らない」

- Fallback は既に Viewport.create で実装済み — WebGL 経路に自動で戻る
- この状態で ship しても「WebGPU は internal にあるが実効は WebGL」の v1.0 と位置づけ可能(RELEASE_NOTES の headline を書き換え)
- Direction chat へ escalate(Case C 発動の可能性)

### 「Golden PSNR が 2+ 件 < 40dB」

- DIRECTION §10 Phase 3 Default: 「2+ regression → direction chat」
- investigate 方針: PSNR 低下が linear pipeline 起因(Phase 2 D4)なら accept、数値ミスなら filmlab.wgsl / composite.wgsl で修正

### 「DMG 生成が通らない」

- electron-builder の Mac 設定エラーなら既存 `RELEASE_NOTES-v0.*.md` の recovery 手順を参照
- `bun run dist:mac:unsigned` 自体の script 内部は本 handoff 対象外

---

## 4. v1.1 送り項目(明示的 defer)

以下は **v1.0 ship 直後に issue 起票**、v1.1 milestone で実装:

| 項目 | 起票タイトル案 | Scope |
|---|---|---|
| Cross-filter render-time integration | `v1.1: activate WebGPU cross-filter render integration (Soft + Hard Mode)` | 5 WGSL は compile-validate 済、render graph 編入 + `hardMode` / `crossFilterStrength > 0` 保存 preset の 5-case PSNR gate |
| Video export WebGPU 化 | `v1.1: migrate video-export-pipeline to WebGPU headless GpuRenderer` | T3-2 scope、rgba16float → tone-mapped rgba8unorm → nv12 → ffmpeg |
| Batch export WebGPU 化 | `v1.1: migrate batch-pipeline to WebGPU headless GpuRenderer` | T3-2 scope、PNG encode 経路維持 |
| apps/web WebGPU 化 | `v1.3: migrate apps/web film-lab canvas to WebGPU` | 独立 scope、Chrome/Safari 主要ブラウザで WebGPU 安定後 |

起票コマンド(v1.0 ship 後):

```bash
gh issue create -R chibataku0815/chibatakumi-portfolio \
  -t "v1.1: activate WebGPU cross-filter render integration (Soft + Hard Mode)" \
  -b "WGSL 5 shader は feature/webgpu-migration-v1 で compile-validate 済。render graph への編入と \`hardMode: true\` / \`crossFilterStrength > 0\` 保存 preset のための 5-case PSNR gate を実装する。"

gh issue create -R chibataku0815/chibatakumi-portfolio \
  -t "v1.1: migrate video-export-pipeline to WebGPU headless GpuRenderer" \
  -b "T3-2 scope defer。rgba16float → tone-mapped rgba8unorm → nv12 → ffmpeg の直結経路を GpuRenderer(canvas 非依存 WebGPUBackend wrapper)で実装。既存 WebGL path は fallback として温存。"

gh issue create -R chibataku0815/chibatakumi-portfolio \
  -t "v1.1: migrate batch-pipeline to WebGPU headless GpuRenderer" \
  -b "T3-2 scope defer。tone-mapped rgba8unorm → PNG encode 経路を GpuRenderer 経由に。"
```

---

## 5. 参考: 前々 chat / 前 chat の完全履歴

### 前々 chat(T3-1)
- `phase-3-continuation-handoff.md` に全文保存
- 成果: 5 WGSL shader + WebGPUBackend compile-validate wiring、未 commit 状態で終了

### 前 chat(T3-3 構造 + Electron flag)
- 本ドキュメント §1 に全差分を記載
- film-lab-renderer tsc / tsup build clean、desktop tsc regression delta 0
- User 承認後に 3 commit + push(§1 末尾の snippet)

### 本 chat(残タスク)
- FilmLabCanvas WebGPU 分岐 + App.tsx prewarm(本文 §2 T3-3 残)
- Golden 80 matrix + DMG + SHIP-READINESS
- User との最終 interaction は SHIP-READINESS レビュー(merge or hold 1 択)

---

**EOF** — この 1 枚で完全な継続が可能。疑問は DIRECTION §9 Escalation Matrix に従う。
