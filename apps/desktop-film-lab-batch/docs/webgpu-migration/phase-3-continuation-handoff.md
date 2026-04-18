# Phase 3 Continuation Handoff — 完璧な新規 chat 引き継ぎ

**作成**: 2026-04-18
**前 chat 担当範囲**: Phase 3 T3-1(cross-filter WGSL 5 本 port + WebGPUBackend pipeline compile-validation)
**次 chat 担当範囲**: Phase 3 残 T3-3 → T3-2 → T3-4 → T3-5 → T3-5.5(live Electron + 実機必須)

このドキュメント 1 枚で前 chat の全文脈を復元できるように書く。**次 chat の最初に以下を読めば判断コストゼロで再開可**:

1. 本ファイル
2. `apps/desktop-film-lab-batch/docs/webgpu-migration/DIRECTION.md`
3. `apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-handoff.md`
4. `apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md`

---

## 1. 環境 / 作業ディレクトリ / ブランチ

```
Working dir: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
Branch:      feature/webgpu-migration-v1  (Phase 1 T1-0 で作成、push 済み)
Main:        main
Platform:    darwin arm64 (macOS 25.4.0)
Shell:       zsh
Package mgr: bun 1.3.3  (npm 禁止、~/.claude/CLAUDE.md 参照)
Node:        24 (mise 管理)
Claude Code: ~/.local/bin/claude
```

user は **parallel で他作業している**。CC session 内で autonomous に判断し、commit/push は user 承認 1 回で batch 処理すること。user 指示原文:
> 判断コスト最小限にするところまで仕上げてください
> 並列で作業しているので私に可能な限りコストかけないように進める前提で計画してください
> 本質の進行を最優先にして、外殻は最小限全てがうまく行った時の品質保証したい時にのみに行う

---

## 2. Phase 0 / 1 / 2 / 3-T3-1 の確定履歴

### Phase 0 — done 2026-04-18 (commit `6fdb7f64` on main)

- **Case A** 確定: WebGPU 疎通(adapter: apple / metal-3, features 15, limits 32 keys, deviceOk true, flag 不要)
- Baseline A: 80 枚 JPEG Q=95(test/golden/baseline-A/、19MB)
- T1 実施は CDP automation(`--remote-debugging-port=9222` + Bun WebSocket → `Runtime.evaluate`)
- `test/golden.harness.ts` + `test/golden.spec.ts` + `test/golden/adapter-info.json`

### Phase 1 — done 2026-04-18 (5 commit on feature branch)

- `bed1d06f` docs → `6e0b88e1` refactor → `84bb33fe` primitives → `ff59fdff` shaders → `f93b6d68` baseline-B
- T1-0 `feature/webgpu-migration-v1` 作成 + push
- T1-1 `git mv src/Viewport.ts → src/webgl/WebGLBackend.ts`、`src/shaders` / `src/textures` も `src/webgl/` 配下へ
- T1-2 6 primitive:`GpuContext` / `OffscreenTargetPool` (rgba16float + pyramid helper) / `Lut3DTexture` (256-byte aligned bytesPerRow + identity helper) / `MediaTexture` (ImageBitmap + HTMLVideoElement) / `RingBuffer` (depthOrArrayLayers=8 motion-blur ring + validSlots) / `BlueNoiseTile` (r8unorm 256×256)
- T1-2 blue-noise: `scripts/generate-blue-noise.mjs` (void-and-cluster, 7s) → `src/webgpu/assets/blue-noise-256.ts` hex encoded
- T1-3 9 WGSL shader: vert(procedural 3-vertex)/ bloom-prefilter / halation-prefilter / downsample / upsample / lightshafts / lightshafts-blend / dust / filmlab(identity placeholder)。Uniforms は全 vec4 packed struct(DIRECTION §4)、`textureSampleLevel(…, 0.0)` 強制で non-uniform control flow 安全
- T1-4 Baseline B 80 PNG: `test/generate-baseline-b.ts`、sRGB → linear → `x * (1 + 0.08 * smoothstep(0.92, 1.0, x))` → sRGB → PNG、9.2s で 105 MB
- Dep 追加: `jpeg-js` (devDependency, Pure JS, no native deps)

### Phase 2 — done 2026-04-18 (4 commit + 1 T2-0c commit on feature branch)

- `8b32b9c5` T2-0a: `RenderBackend` interface に `setParams(record)` 追加、WebGPU 側は T2-1 で実装
- `068b7063` T2-1: filmlab.wgsl primary grade (9 ops) + LUT1 + blit を `rgba16float` 本実装、`packGradeUniforms` で 9 vec4 packed(144 bytes)、identity LUT1 pre-upload
- `be754796` T2-2 + T2-0b + T2-3 bundle: Reinhard soft-shaper (k=0.5 固定) + LUT2 + print CMY + print contrast、`composite.wgsl` 新規(2 bind group、bloom/halation pyramid + blue-noise grain)、bloom 5 mip / halation 6 mip、`compositeUniforms.ts`(3 vec4 packer + `hexToRgbTriple`)
- `1c6e839b` T2-4: motion blur 2-pass ring + blit fallback。`motionblur-feedback.frag.wgsl` + `motionblur-blend.frag.wgsl`、`RingBuffer(depthOrArrayLayers=8, rgba16float)`、`activeMotionBlurFrames(shutterAngle)` + `computeMotionBlurWeights` は WebGL `getActiveFrameCount` / `computeBlendWeights` と同一式(triangle → box は 360°→720° で flatness 内挿)
- `f19fc4d5` T2-0c: FilmLabCanvas.tsx を `await Viewport.create(canvas, {prefer:'webgl'})` に移行、`useEffect` + async IIFE + cancel flag で race condition 回避、4/4 consumer(batch-pipeline / video-export-pipeline / FilmLabCanvas / film-lab-web-video-export)全移行完了
- `edf6efa7` docs only — T2-4 done マーク + 次 chat snippet

**Phase 2 の繰越**: Golden PSNR gate(50 ケース、≥40dB 45/50)+ 視覚証明 screenshot は T3-3 Viewport composition 後に T3-4 80 matrix で吸収(構造起因の gap、Decisions log 参照)。

### Phase 3 T3-1 — done 前 chat (**未 commit、feature branch に working tree 残す**)

本 handoff 作成時点の pending changes:

```
 M apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md
 M packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts
 M packages/film-lab-renderer/src/webgpu/shaders/index.ts
?? packages/film-lab-renderer/src/webgpu/shaders/cross-filter-blend.frag.wgsl.ts
?? packages/film-lab-renderer/src/webgpu/shaders/cross-filter-peak-spacing-max.frag.wgsl.ts
?? packages/film-lab-renderer/src/webgpu/shaders/cross-filter-peak-spacing.frag.wgsl.ts
?? packages/film-lab-renderer/src/webgpu/shaders/cross-filter-peak.frag.wgsl.ts
?? packages/film-lab-renderer/src/webgpu/shaders/cross-filter-streak.frag.wgsl.ts
```

**成果物内訳**:

1. **5 WGSL shader ファイル新規**(`packages/film-lab-renderer/src/webgpu/shaders/`)
   - `cross-filter-peak.frag.wgsl.ts` — 16-tap ring + 16-tap neighbor density による peak 抽出
   - `cross-filter-peak-spacing-max.frag.wgsl.ts` — 2-pass(H→V)directional max、`±MAX_RADIUS=48`、rank hash tie-break
   - `cross-filter-peak-spacing.frag.wgsl.ts` — winner-coord match gate(0.25 px tolerance)
   - `cross-filter-streak.frag.wgsl.ts` — Soft Mode(v1.0 = Hard Mode 未使用、定数保持のみ)forward/backward march up to MAX_STREAK_PX=64
   - `cross-filter-blend.frag.wgsl.ts` — 最大 4 streak + central bloom(v1.0 は hardMode=0 で 0 固定)additive + Soft Reinhard rolloff

   **ポート方針**: DIRECTION §4 に沿って全 uniform を `vec4` packed struct、`textureSampleLevel(tex, samp, uv, 0.0)` で non-uniform control flow 安全、`@group(1)` bind group(peak/streak/blend で entry 数差異あり)、Hard Mode 分岐は `mix(soft, hard, hardMode)` で保持(v1.1 forward-compat)。WebGL 元ファイル: `packages/film-lab-renderer/src/webgl/shaders/cross-filter-{peak,peak-spacing-max,peak-spacing,streak,blend}.frag.ts`。

2. **`shaders/index.ts` に 5 export 追記**(`crossFilterPeakFragmentWgsl` 他 4)。

3. **`WebGPUBackend.ts`** 編集:
   - 5 import 追加
   - `ShaderModules` interface に 5 field 追加
   - `WebGPUBackend.create()` 内で 5 `GPUShaderModule` を `withValidationScope(() => device.createShaderModule)` で compile-validate
   - **render-time integration 無し(v1.1 送り、§4 参照)**

**検証済み**:
- `cd packages/film-lab-renderer && bunx tsc --noEmit` → exit 0(clean)
- `cd packages/film-lab-renderer && bun run build` → `dist/index.js` 137.75 KB / `dist/webgpu.js` 218.85 KB(Phase 2 の 207KB から +11KB、5 shader 分)
- Tree-shake: `grep -c "WebGPUBackend" dist/index.js` = 0、`dist/webgpu.js` = 5。`grep -c "crossFilter" dist/webgpu.js` = 13(WGSL 文字列 + module 参照)、`dist/index.js` は WebGL 側の既存 GLSL export 分のみ(150、本編集と無関係)
- `cd apps/desktop-film-lab-batch && bunx tsc --noEmit` → 17 errors(Phase 2 からの regression delta 0、pre-existing)

---

## 3. 前 chat の Critical Finding(次 chat の判断軸)

### Finding: 全 8 v1.0 preset が `crossFilterStrength: 0`

`packages/film-lab-core/src/presets.ts` を grep で確認:

```
Grep "crossFilterStrength: [^0]" → No matches found
```

全プリセット(reset / cinematic / portra / gold200 / pro400h / bw / ektar100 / superia400)が `crossFilterStrength: 0` を固定保存。従って:

- **Golden 80 matrix(8 preset × 10 image)は cross-filter render path を一切通らない**
- Exit criteria §5「Golden 80 matrix: PSNR ≥ 40dB が 75/80 以上」は cross-filter integration と独立に成立可能
- cross-filter 5-case 追加 gate(Exit 外、T3-1 の内部 verification 項目)は v1.0 品質ゲートに無関係

### Derived Decision: Cross-filter render-time integration を v1.1 へ defer

**決定根拠**(DIRECTION §9 Direction chat 相当判断だが、user direction「本質の進行最優先、外殻最小限」と整合):

| 観点 | 根拠 |
|---|---|
| 品質影響 | 0(全 preset で無効) |
| 既存 defer との整合 | D5 で Hard Mode 既 v1.1 defer → Soft Mode も v1.1 で同時対応の方が設計的に統一 |
| 実装コスト削減 | WGSL 5 本は compile-validation 済、v1.1 では render graph 編入のみ |
| Release note 記述 | 「v1.1 で cross-filter(Soft + Hard Mode temporal)有効化」と書ける。`hardMode: true` 保存済み preset の warning fallback は既存 T3-1 UI gate で扱う方向 |

**Decisions log に記録済み**(STATUS.md 末尾)。次 chat はこの決定を前提に進むこと — re-open する場合は必ず direction chat (= user) に escalate。

---

## 4. 次 chat が実行すべき残タスク(順序付き)

### 優先順位(critical path 準拠)

```
T3-3 先頭   Viewport composition refactor(blocking everything else)
    ↓
T3-3 中盤   FilmLabCanvas.tsx 分岐化 + App.tsx に prefer='webgpu' 配線
    ↓
T3-3 後半   electron/main.ts に flag、pre-warm UI overlay
    ↓
T3-2        Headless GpuRenderer 抽出 + video-export / batch-pipeline rewire
    ↓
T3-4        bun run typecheck / test / smoke / build + Golden 80 matrix
    ↓
T3-5        version 1.0.0 bump + RELEASE_NOTES-v1.0.0.md + dist:mac:unsigned
    ↓
T3-5.5      SHIP-READINESS.md 自動生成
    ↓
T3-6        STATUS.md 完了印 + Day 4 判断
```

### 各タスクの詳細(phase-3-handoff.md 要約 + 前 chat で判明した gotcha 併記)

#### T3-3 Viewport composition refactor(最重要、~3h)

**現状**(`packages/film-lab-renderer/src/Viewport.ts:38-66`):
```ts
export class Viewport extends WebGLBackend {
  static async create(canvas, opts) {
    // opts.prefer は void でスルー、常に WebGLBackend を返す
    return new Viewport({ vertexShader, fragmentShader, width, height });
  }
}
```

**ゴール形**(phase-3-handoff §T3-3 抜粋):
```ts
export class Viewport {
  private backend: WebGLBackend | WebGPUBackend;
  readonly backendKind: 'webgl' | 'webgpu';
  readonly mesh?: THREE.Mesh;  // WebGL 分岐のみ

  static async create(canvas, opts): Promise<Viewport> {
    if (opts.prefer === 'webgpu' && await isWebGPUSupported()) {
      const { WebGPUBackend } = await import('film-lab-renderer/webgpu');
      return new Viewport(await WebGPUBackend.create(canvas), 'webgpu');
    }
    return new Viewport(new WebGLBackend({vertex, frag, w, h}), 'webgl');
  }
  // setParams / setLUT1 / setLUT2 / setMediaFromBitmap / setResolution /
  // setImageResolution / setFitMode / setTime / setExportFlipY /
  // render / dispose を backend に委譲
}
```

**Consumer surface に関する前 chat の調査結果**:
- 4 consumer + FilmLabCanvas + App.tsx + Golden harness が実際に呼ぶメソッド一覧(`grep viewport\.\(mesh\|set.\|render\|dispose\|getPending\|getCanvasEl\)` で洗い出し済):
  ```
  mesh (WebGL only)
  render(renderer?, scene?, camera?)   — overloaded
  setResolution(w, h)
  setTexture(THREE.Texture)             — WebGL only(現状唯一の WebGL-specific 入力)
  setMediaFromBitmap(ImageBitmap)       — WebGPU Native、WebGL 側は要実装 or 経由変換
  setImageResolution(w, h)
  setFitMode('cover'/'contain')
  setParams(record)                     — 両 backend 実装済
  setLUT1/setLUT2(data, size), +Intensity, +clear
  setLUT/setLUTIntensity/clearLUT       — alias(WebGL 側、setLUT2 に委譲で良い)
  setTime(t)
  setSplitPosition(v), getSplitPosition()
  setComparePair(...)                   — WebGL only、A/B 複雑状態
  setExportFlipY(flip)
  getParams() / getPendingParams()
  dispose()
  ```
- **重要**: grep `viewport\.set(?!Params|Resolution|LUT|...)` = 0 match。consumer は **granular setter を一切呼ばない**。全て `setParams(record)` を経由する。従って delegation は 15 methods 程度で済む(60+ 個別 setter を委譲する必要は無い)。
- `webgl-study` の Viewport は **別ファイル**(`apps/webgl-study/05-tao-tajima/src/scene/Viewport.ts`)で film-lab-renderer 由来ではない。refactor の影響範囲外。
- `apps/web/src/features/interactive/film-lab/core/Viewport.ts` は re-export bridge(`export { Viewport, type ViewportOptions } from "film-lab-renderer"`)なので index.ts の export を維持すれば自動追従。

**`setTexture(THREE.Texture)` ハンドリング**:
- 現状 FilmLabCanvas は `replaceSourceFromPngBase64Body(base64)` → `mediaLoader.loadFile(file, {maxTextureSize})` → `applyLoadedTextureResult(result)` → 最終的に `viewport.setTexture(result.texture)` と繋がっている。
- WebGPU 分岐では THREE.Texture を ImageBitmap に変換する経路が必要。選択肢:
  - (A) `mediaLoader.loadFile` の中で `ImageBitmap` も並列取得して渡す
  - (B) WebGPU 分岐の `viewport.setTexture(texture)` 内で `texture.source.data` → `createImageBitmap(…)` → `backend.setMediaFromBitmap(bitmap)` 再ブリッジ
  - (C) `loadImage(base64)` の harness path は現在 `replaceSourceFromPngBase64Body` 経由で THREE → WebGL。WebGPU 経路は別の `loadImageBase64AsBitmap` を追加して harness 側で分岐
- **推奨**: (B) を prefer。`THREE.Texture.image` は ImageBitmap か HTMLImageElement、`createImageBitmap` でラップして WebGPU に渡せる。consumer code 不変。

**`mesh` ハンドリング**:
- phase-3-handoff §T3-3: 「`scene.add(viewport.mesh)` は `if (viewport.backendKind === 'webgl') scene.add(viewport.mesh!)` に」
- FilmLabCanvas.tsx L794 / batch-pipeline.ts L400 / video-export-pipeline.ts L1036 / film-lab-web-video-export.ts L497 の 4 箇所
- 本質的に `scene.add` は WebGL が使う THREE.Scene の話、WebGPU 分岐は canvas 直描画なので不要

**render() シグネチャ**:
- WebGL: `render(renderer: THREE.WebGLRenderer, scene: THREE.Scene, camera: THREE.Camera)`(現状)
- WebGPU: `render()` 引数無し(`WebGPUBackend.render()` は canvas 直描画)
- TypeScript 的解決: overload で書くか、`renderer?`, `scene?`, `camera?` を optional にして backend で分岐

**FilmLabCanvas.tsx 改修**(L750-832 周辺、commit `f19fc4d5` の拡張):
- `renderer.domElement` は THREE.WebGLRenderer の canvas。WebGPU 分岐では別経路が必要
- 選択肢:
  - (A) WebGPU 用に separate canvas を用意、`renderer.domElement` と切替表示
  - (B) `renderer.domElement` に WebGPU context を取る(`getContext('webgpu')`) — **ただし同一 canvas 上で webgl2 と webgpu context は共存不可**
  - (C) prefer='webgpu' の時は THREE.WebGLRenderer 生成自体を skip、`canvas.getContext('webgpu')` で WebGPUBackend を作る。resize / `setSize` は canvas.width/height 直操作
- **推奨**: (C)。FilmLabCanvas を「backend-agnostic canvas runtime」にする。WebGL 分岐では既存 renderer 作成、WebGPU 分岐では WebGPUBackend.create に任せる。
- renderer.capabilities.maxTextureSize は WebGL 固有 — WebGPU 分岐では `navigator.gpu.requestAdapter() → limits.maxTextureDimension2D` 相当を用いる

**`bun run desktop` で動作確認項目**(phase-3-handoff Exit criteria):
1. 起動 → DevTools Console に adapter info ログ出力
2. 画像 load(drag-drop or open dialog)→ 色が出る
3. preset 切替(cinematic / portra / bw 等)→ 視覚的に変化
4. resize → canvas 正しく追従
5. 終了時 `dispose()` で GPU リソース解放(console に leak warning 無し)

#### T3-3 Electron flag(main.ts)

**現状確認**: `apps/desktop-film-lab-batch/electron/main.ts` に既存の flag 群。以下を `app.whenReady()` 前に追加:

```ts
app.commandLine.appendSwitch('enable-unsafe-webgpu');
// Case B 要件なら以下も追加(Phase 0 で Case A 確定、不要だが safety-net として維持推奨):
// app.commandLine.appendSwitch('enable-features', 'Vulkan');
```

Phase 0 Case A 確定なので基本不要だが、旧 macOS / Electron バージョンへの safety-net として v1.0 で入れておくのは DIRECTION §10 Phase 0 準拠。

#### T3-3 Pre-warm UI(App.tsx)

- `viewport.prewarm()` を async factory 後に `requestIdleCallback` 内で呼ぶ(全 pipeline の最初の 1 frame を空 uniform で通す、stutter 回避)
- 150ms 超えた場合、`"Preparing renderer…"` overlay をフェードイン/アウト
- 300ms 超でフェードアウト
- 実装: `WebGPUBackend` に `prewarm()` method 追加(pipeline 作成時に 1×1 GPUTexture 向けに draw call 1 本ずつ発行)

#### T3-2 Headless GpuRenderer 抽出(~2h、T3-3 完了後)

新規: `packages/film-lab-renderer/src/webgpu/GpuRenderer.ts`

- WebGPUBackend の pipeline graph 部分だけを切り出し
- API: `async render(input: GPUTexture, output: GPUTexture): Promise<void>`
- canvas 非依存(canvas context は Viewport 外側で管理)

**video-export-pipeline.ts 改修**(L1031+):
- `videoExportRender(frame, params)` を `GpuRenderer` 使用に差し替え
- 出力先 = `GPUTexture({ format: 'rgba16float' })`
- `copyTextureToBuffer` → mapped staging buffer 吸い出し
- CPU tone-mapping(filmlab.wgsl 同一経路、rgba8unorm output)
- nv12 変換(ffmpeg filter `format=nv12`)で ffmpeg stdin 投入
- ffmpeg codec は既存のまま(DIRECTION §10 Phase 3)

**batch-pipeline.ts 改修**(L395+):
- `batchRender(image, params)` も `GpuRenderer` 経由に差し替え
- 出力 PNG = tone-mapped rgba8unorm → PNG encode(既存)

**smoke verify**: `bun run smoke:smart-look-pending` が WebGPU path で完走。

#### T3-4 Golden 80 matrix(~2h)

```bash
cd apps/desktop-film-lab-batch
bun run typecheck
bun run test
bun run test:smart-look-pending
bun run smoke:smart-look-pending
bun run build
bun run test:golden -- --baseline B --full
```

- 合格基準: PSNR ≥ 40dB が **75/80 以上**(単一 regression accept、5+ は direction chat escalate)
- 結果 CSV を `docs/webgpu-migration/phase-3-golden-report.csv` に保存
- 低 PSNR 順に top 5 ケースを目視 → 許容差分か判定
- **Phase 2 からの繰越分(5 preset × 10 image PSNR gate + 視覚証明)は 80 matrix の subset として自動回収**
- 視覚証明 screenshot 3 枚を `docs/webgpu-migration/assets/highlight-proof/` に出す:
  - `sunset.jpg` + preset A / `backlit-portrait.jpg` + preset B / `white-dress.jpg` + preset C
  - 手元に該当 filename が無ければ `source-images/01-highlight-sunset.png` / `02-highlight-backlit.png` / `03-highkey-whitedress.png` を使う(Golden source に存在、確認済)

#### T3-5 DMG + RELEASE_NOTES(~1h)

1. `package.json` version 0.6.2 → 1.0.0
2. `apps/desktop-film-lab-batch/RELEASE_NOTES-v1.0.0.md` 起案(既存 `RELEASE_NOTES-v0.*.md` 書式踏襲、phase-3-handoff §T3-5 にテンプレ有り)
3. `cd apps/desktop-film-lab-batch && bun run dist:mac:unsigned` → `release/Filmtone-1.0.0-arm64.dmg`
4. 実機 QA:DMG mount → /Applications drag → 起動 → 画像 load → preset 3 種切替 → video 書き出し 1 本 → smart-look 1 回 → クラッシュ無し(10 min 操作)
5. highlight 豊富な画像で LUT2 highlight gradient 確認

**RELEASE_NOTES headline**:
```md
# v1.0.0 — WebGPU migration

## Headline
- Linear Rec.709 + rgba16float working space(clamp 除去、LUT 前で広いレンジ保持)
- WebGPU backend(macOS arm64)、WebGL backend は web 向けに温存
- Hardware sRGB OETF で最終 display transform

## Known limits
- Cross-filter(Soft + Hard Mode)は v1.1 で有効化予定 — 保存 preset の
  `hardMode: true` / `crossFilterStrength > 0` は読み込み時に 0 に落とし
  console warning 出力(backward compat 崩さない)
- apps/web 側は引き続き WebGL(v1.3 で WebGPU 化予定)
- HDR / P3 出力は未対応(v2.0 ロードマップ)
```

#### T3-5.5 SHIP-READINESS.md(~15 min)

生成先: `apps/desktop-film-lab-batch/docs/webgpu-migration/SHIP-READINESS.md`

phase-3-handoff §T3-5.5 にフルテンプレ有り。実測値を差し替える。user の判断コストを「この 1 ファイルを 5-10 分で読む → merge or hold の 1 択」に圧縮。

#### T3-6 Day 4 判断

Day 4 実施判断の基準(phase-3-handoff §T3-6):
- Golden で 5-10 件 regression ありで fix したい
- Hard Mode temporal を WebGPU で通す余力ある(本 handoff の方針では v1.1 送りなので基本 skip)
- v1.0 出荷前にシグネチャ付き DMG まで作りたい

不実施なら Day 4 セクションを STATUS.md に "skipped" 記録。

---

## 5. 前 chat の pending commit(次 chat 冒頭で実行推奨)

**user 承認を得てから実行すること**(DIRECTION §7 「自動 commit 禁止」厳守)。

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

git add \
  packages/film-lab-renderer/src/webgpu/shaders/cross-filter-blend.frag.wgsl.ts \
  packages/film-lab-renderer/src/webgpu/shaders/cross-filter-peak-spacing-max.frag.wgsl.ts \
  packages/film-lab-renderer/src/webgpu/shaders/cross-filter-peak-spacing.frag.wgsl.ts \
  packages/film-lab-renderer/src/webgpu/shaders/cross-filter-peak.frag.wgsl.ts \
  packages/film-lab-renderer/src/webgpu/shaders/cross-filter-streak.frag.wgsl.ts \
  packages/film-lab-renderer/src/webgpu/shaders/index.ts \
  packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts \
  apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md

git commit -m "$(cat <<'EOF'
Phase 3 T3-1: port 5 cross-filter shaders to WGSL; compile-validate

Add peak / peak-spacing-max / peak-spacing / streak / blend ports from
src/webgl/shaders/cross-filter-*.frag.ts. Each WGSL is wired into
WebGPUBackend.create so GPU-side WGSL correctness is validated at backend
init via pushErrorScope('validation'). Runtime render integration is
deferred to v1.1 alongside Hard Mode (D5): all 8 v1.0 presets ship with
crossFilterStrength: 0, so the Golden 80-matrix PSNR gate (>=40dB 75/80)
is unaffected by the deferral.

Tree-shake retained (dist/index.js: 0 WebGPUBackend matches, webgpu.js:
5 + 13 crossFilter). film-lab-renderer tsc clean; desktop tsc 17 errors
(Phase 2 regression delta 0).

STATUS.md: Phase 3 partial; Decisions log records v1.1 defer rationale
and follow-up kickoff snippet.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**本 handoff ドキュメント**(`phase-3-continuation-handoff.md`)は別 commit で追加する:
```bash
git add apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-continuation-handoff.md
git commit -m "docs(webgpu-migration): add continuation handoff for Phase 3 remainder"
```

push は user 判断(DIRECTION §7)。

---

## 6. 次 chat kickoff snippet(user が新規 chat に貼る 1 行)

```
作業ディレクトリ: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

@apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-continuation-handoff.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/DIRECTION.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-handoff.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md を読んで Phase 3 の残り T3-3 → T3-2 → T3-4 → T3-5 → T3-5.5 を live Electron で実行してください。
T3-1 WGSL 5 本 + pipeline compile-validation は前 chat 完了、まだ commit 前(handoff §5 の手順で冒頭に user 承認 + commit)。
cross-filter render-time integration は v1.1 defer 決定済み(handoff §3 参照)。
判断コスト最小化で進めてください。
```

---

## 7. DIRECTION 重要事項の要約(次 chat が最低限知っておくべき)

### Non-negotiable(D1-D5)

| # | 決定 |
|---|---|
| D1 | Three.js は完全に切る。WebGPURenderer hybrid 不採用、Pure WebGPU |
| D2 | `gpu-film-post` は template 参照のみ、Filmtone の依存にはしない |
| D3 | **`Viewport` 単一クラス + `Backend` interface** で内部切替(T3-3 でここを詰める) |
| D4 | **Linear Rec.709 + rgba16float** が working space。`clamp(0,1)` を primary grade から除去 |
| D5 | **Hard Mode cross-filter temporal は v1.1 に先送り**(本 handoff で Soft Mode 本体も v1.1 に追加 defer 決定) |

### Escalation Matrix 抜粋

**Autonomous(phase chat 自身が決定、escalate 不要)**:
- Tool バージョン、file 命名、log verbosity、test harness、micro refactor、WGSL idiom choice、変数名、phase scope 内 bug fix、§10 Decision Defaults

**Direction chat(user 経由)**:
- Commit granularity ambiguity、Feature deferral 判断、PSNR near-miss(38-40dB)、bind group layout 逸脱、test fixtures 代替、perf regression > 30% vs WebGL、dep 追加(handoff 外)、phase 工数 20-40% overrun

**User(strategic、稀)**:
- D1-D5 変更、Day scope 変更、Release version、色空間パラダイム変更、preset 後方互換破壊、phase 工数 > 40% overrun、Case C 発動

### Decision Defaults(phase chat が即適用)

共通:
- Typecheck 失敗 → Exit 前に clean(phase 起因は 0、pre-existing は current count 維持で accept)
- Golden PNG 総計 ≥ 50MB → JPEG Q=95 変換、200MB 超なら direction chat
- Naga 出力バグ → 該当 shader だけ hand-translate + `// naga-workaround` コメント
- DPR → canvas は device DPR のまま、test harness は 1.0 固定
- Task 工数 20% overrun → STATUS 記録して継続、40% → direction chat

Phase 3 固有:
- Cross-filter 5 shader 順: peak → peak-spacing → peak-spacing-max → streak → blend **(本 handoff で render integration defer 決定、compile-validation のみ)**
- streak-density は SKIP、Hard Mode は v1.1
- Video export: rgba16float → rgba8unorm (tone-mapped) → nv12 → ffmpeg
- DMG: unsigned for Day 3、signed は別作業
- Pipeline pre-warm: 150ms 未満 silent、以上 overlay、300ms 以上フェードアウト
- Web bundle: build flag で WebGPU dynamic import、tree-shake 確認(既に Phase 1/2 で担保)

---

## 8. 前 chat で発見 / 確認した Phase 3 Known Gotchas

### FilmLabCanvas.tsx の Three.js 深結合

`packages/film-lab-ui/src/FilmLabCanvas.tsx` は以下で THREE に深くぶら下がっている:
- `renderer = new THREE.WebGLRenderer(...)`(L740 付近)
- `renderer.domElement` を canvas として DOM に append
- `renderer.setSize(width, height)` で resize
- `renderer.capabilities.maxTextureSize` を mediaLoader に渡す
- `scene.add(viewport.mesh)`(L794)
- `viewport.render(renderer, scene, camera)`(L829)
- `renderer.forceContextLoss()` / `renderer.dispose()` で終了処理

T3-3 WebGPU 分岐では **THREE.WebGLRenderer を生成せず、canvas.getContext('webgpu') を直接使う**。resize は canvas.width/height の直操作。maxTextureSize は `navigator.gpu.requestAdapter() → limits.maxTextureDimension2D` 相当。これが T3-3 の最大変更規模。

### Viewport consumer の実質 API

前 chat の `grep viewport\.` 調査結果より、4 consumer + FilmLabCanvas + FilmLabControlPanelCore + film-lab-web-video-export は **granular setter(setExposure/setContrast 等)を一切呼ばない**。全て `setParams(record)` 経由。従って delegation method 数は ~15 で済む:

```
render, setResolution, setTexture, setMediaFromBitmap, setImageResolution,
setFitMode, setParams, setLUT1 (+Intensity, +clear), setLUT2 (+Intensity, +clear),
setLUT (alias), setTime, setSplitPosition, setComparePair, setExportFlipY,
getParams/getPendingParams, dispose, backendKind, mesh?
```

Viewport 内部で full Proxy は不要。手書き 15 本の delegator で十分。

### Golden harness path

`apps/desktop-film-lab-batch/test/golden.harness.ts:110-125` で `window.__filmtoneTest` を経由:

```ts
const h = (window as any).__filmtoneTest;
const loaded = await h.loadImage(args.base64);       // replaceSourceFromPngBase64Body
h.setCanvasSize(w, h);                                // canvas.width/height + viewport.setResolution
h.setParams(args.preset);                             // viewport.setParams
h.setExportFlipY(true);                               // viewport.setExportFlipY
const dataUrl = canvas.toDataURL("image/png");        // 最終画像
```

`getCanvasEl` は `filmLabCanvasRef.current?.getWebGlCanvas()` を返す。**WebGPU 分岐では `getWebGlCanvas()` rename or `getCanvasEl()` で backend-agnostic に**。

`canvas.toDataURL("image/png")` は WebGPU canvas でも動くので読み出し側は変更不要。ただし WebGPU の描画完了タイミングが RAF に同期しているか注意(`waitTwoFrames` で吸収されるはず)。

### Phase 2 から継続の gotcha(WebGPUBackend.ts)

STATUS.md §Phase 2 Known gotchas 全て有効:
- **GPUQueue.writeBuffer 衝突**: 同一 uniform buffer に複数回 writeBuffer した後 submit すると最終値で上書き。Pyramid の per-level uniform は level 分 buffer を pre-allocate 済、motion blur も別 buffer 済
- **`loadOp: "load"` + 加算ブレンド**: bloom/halation upsample は load + `{src:one, dst:one, op:add}` で累積。片方欠けると破綻
- **`bloomRadius` / `halationRadius` fallback**: 未指定時 0.5 default(WebGL 同値)
- **Grain sampler は repeat 別途必須**: 既存 filtering は clamp-to-edge、blue-noise 256² タイリングは `addressMode: "repeat"` の sampler を binding 6 に別バインド
- **RingBuffer `nextSlot()`**: 呼び出し時に advance + `validSlots++`。`hasPrev = validSlots > 1`、`prevSlotIndex = (nextSlot - 1 + 8) % 8`
- **motion blur ON 時の composite 出力**: `rt.composited (rgba16float)` に書く必要、blit fallback pipeline が吸収
- **2d-array sampler**: bind group layout で `viewDimension: "2d-array"` を明示必須

### Phase 1 から継続の gotcha(primitive 周り)

- `BufferSource` 型ナロー: `device.queue.writeTexture(Uint8Array)` で TS 5.9 不整合、`as unknown as BufferSource` で narrow
- `mod(uv, 2.0)` は GLSL 専用、WGSL は `uv - floor(uv * 0.5) * 2.0`
- Sampler は filtering 固定 + LUT3D も同仕様で兼用可能
- Baseline-B source は JPEG Q=95(PSNR 比較時 < 0.5dB JPEG 起因ノイズ、厳しめ運用なら `max(psnr - 0.5, target)`)

---

## 9. Auto-collected memory / user prefs(要遵守)

life repo の `.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/` より重要 feedback:

- [密度より統一感・クラフト品質を優先] — 抽象 MG に意味は不要だが、エフェクト重ねは「派手だけど粗い」になる。磨きが先
- [デザイン品質を技術と同等に優先] — 深澤 / ラムス水準の色・余白・タイポ精度を初期から意識
- [参考画像と必ず突き合わせる] — グラフィック再現で出力と参考を並べて差分確認してから報告
- [SDF テキスト融合でクロスフェード禁止] — 真の融合は統一フィールド + 単一閾値
- [SDF テクスチャは r32float 必須]
- [2.5D推測デザイン連続失敗] — クリエイティブ方向性不明な推測実装は禁、リファレンス確認が先
- [WebGPU writeBuffer per-layer 分離] — 同一バッファ複数 writeBuffer で最後の値で上書き、マルチレイヤー描画は buffer 分離必須
- [上限拡張は視覚的フィジビリティ限界まで押す] — 保守的 +1/+2 刻み NG、第一案に最大値
- [Film post は既定 ON] — MG 全般で film post(grain/CA/bloom/vignette/tonemap)を初期状態から ON
- [判断コストを細切れで押し付けない] — 「承認」受領後は commit + push をまとめて実行、分割承認は真に独立な破壊的操作のみ
- [DaVinci/プラグイン操作は推測禁止] — 操作手順・対応状況を記憶ベースで推測回答しない、必ず調べてから
- [外部テキストを検証せずにナレッジ化禁止] — 技術的主張は公式情報で検証してから書く、未検証値は ⚠️ 必須
- [見た目向上効果のない装飾禁止] — 効果曖昧な装飾を「とりあえず追加」しない、明確な改善理由必須

**Language rule**: 内部処理(sequential-thinking thoughts / subagent prompt / 中間分析)は英語でトークン効率最大化、user 向け最終出力 / ドキュメント / commit は日本語。コードと技術用語は英語慣習通り。

**Package manager**: npm 禁止、bun 使用(`bun install` / `bun add` / `bun run` / `bunx`)。

---

## 10. Environment / path / command 索引

### Repo 構造(関連パス)

```
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/
├── packages/
│   ├── film-lab-core/             # preset / types
│   │   └── src/presets.ts          # 8 preset 定義、全て crossFilterStrength: 0
│   ├── film-lab-renderer/          # backend package
│   │   ├── src/
│   │   │   ├── index.ts            # web-safe public API(WebGPU を含まない)
│   │   │   ├── webgpu.ts           # sub-path export(WebGPUBackend 含む)
│   │   │   ├── Viewport.ts         # T3-3 で composition にする対象
│   │   │   ├── support.ts          # isWebGPUSupported / isWebGL2Supported
│   │   │   ├── MediaLoader.ts
│   │   │   ├── webgl/              # 旧 backend(Phase 1 で退避)
│   │   │   │   ├── WebGLBackend.ts # class Viewport → WebGLBackend rename 済
│   │   │   │   └── shaders/*.ts    # GLSL, cross-filter 7 本含む(移植元)
│   │   │   └── webgpu/
│   │   │       ├── Backend.ts      # RenderBackend interface
│   │   │       ├── WebGPUBackend.ts
│   │   │       ├── GpuContext.ts
│   │   │       ├── OffscreenTargetPool.ts
│   │   │       ├── Lut3DTexture.ts
│   │   │       ├── MediaTexture.ts
│   │   │       ├── RingBuffer.ts
│   │   │       ├── BlueNoiseTile.ts
│   │   │       ├── gradeUniforms.ts
│   │   │       ├── compositeUniforms.ts
│   │   │       ├── assets/blue-noise-256.ts
│   │   │       └── shaders/
│   │   │           ├── index.ts    # 本 chat で 5 export 追加
│   │   │           ├── fullscreen.vert.wgsl.ts
│   │   │           ├── filmlab.frag.wgsl.ts
│   │   │           ├── blit.frag.wgsl.ts
│   │   │           ├── composite.frag.wgsl.ts
│   │   │           ├── bloom-prefilter.frag.wgsl.ts
│   │   │           ├── halation-prefilter.frag.wgsl.ts
│   │   │           ├── downsample.frag.wgsl.ts
│   │   │           ├── upsample.frag.wgsl.ts
│   │   │           ├── lightshafts.frag.wgsl.ts
│   │   │           ├── lightshafts-blend.frag.wgsl.ts
│   │   │           ├── dust.frag.wgsl.ts
│   │   │           ├── motionblur-feedback.frag.wgsl.ts
│   │   │           ├── motionblur-blend.frag.wgsl.ts
│   │   │           ├── cross-filter-peak.frag.wgsl.ts            # 本 chat 新規
│   │   │           ├── cross-filter-peak-spacing-max.frag.wgsl.ts # 本 chat 新規
│   │   │           ├── cross-filter-peak-spacing.frag.wgsl.ts    # 本 chat 新規
│   │   │           ├── cross-filter-streak.frag.wgsl.ts          # 本 chat 新規
│   │   │           └── cross-filter-blend.frag.wgsl.ts           # 本 chat 新規
│   │   └── package.json
│   └── film-lab-ui/
│       └── src/
│           ├── FilmLabCanvas.tsx   # T3-3 で backend-agnostic 化する中心
│           └── FilmLabControlPanelCore.tsx
└── apps/
    ├── desktop-film-lab-batch/     # Electron ship target
    │   ├── electron/main.ts        # T3-3 で flag 追加
    │   ├── src/renderer/
    │   │   ├── App.tsx             # T3-3 で prefer='webgpu' + prewarm
    │   │   ├── batch-pipeline.ts   # T3-2 で GpuRenderer rewire
    │   │   └── video-export-pipeline.ts  # T3-2 で GpuRenderer rewire
    │   ├── test/
    │   │   ├── golden.harness.ts
    │   │   ├── golden.spec.ts      # Playwright 80 matrix
    │   │   ├── golden-psnr.ts      # PSNR util + compareAgainstBaselineB
    │   │   ├── generate-baseline-b.ts
    │   │   └── golden/
    │   │       ├── baseline-A/     # WebGL 実出力 JPEG Q=95 80 枚
    │   │       ├── baseline-B/     # Phase 1 linearized PNG 80 枚(105 MB)
    │   │       ├── source-images/  # 01-highlight-sunset.png etc. 10 枚
    │   │       └── adapter-info.json
    │   ├── docs/webgpu-migration/  # 本 handoff family 全ファイル置き場
    │   └── package.json            # 0.6.2 → 1.0.0 bump 対象
    ├── web/
    │   └── src/features/interactive/film-lab/
    │       ├── core/Viewport.ts    # film-lab-renderer re-export bridge
    │       └── film-lab-web-video-export.ts  # consumer 4/4 の 1
    └── webgl-study/                # film-lab-renderer の Viewport を使っていない(独立)
```

### 主要コマンド

```bash
# film-lab-renderer typecheck(Phase 3 中断時の最短セルフチェック)
cd packages/film-lab-renderer && bunx tsc --noEmit; echo "exit=$?"

# film-lab-renderer build(tree-shake 検証込み)
cd packages/film-lab-renderer && bun run build
# 期待: dist/index.js に WebGPUBackend 0 match、dist/webgpu.js に 5 match

# desktop typecheck(regression delta 確認)
cd apps/desktop-film-lab-batch && bunx tsc --noEmit 2>&1 | grep "error TS" | wc -l
# 期待: 17(Phase 2 からの baseline)

# desktop smoke
cd apps/desktop-film-lab-batch && bun run smoke:smart-look-pending

# desktop dev(live Electron)
cd apps/desktop-film-lab-batch && bun run desktop

# desktop golden(Playwright 80 matrix、要 dev server)
cd apps/desktop-film-lab-batch && bun run test:golden -- --baseline B --full

# desktop DMG(unsigned、~2-5 min)
cd apps/desktop-film-lab-batch && bun run dist:mac:unsigned

# worktree 確認
git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio status -s
git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio log --oneline -10
```

---

## 11. User Interaction Budget Tracking

DIRECTION §11 target: **≤ 8 user messages through the 38h sprint**。

| # | Trigger | 消化済? |
|---|---|---|
| 1 | Phase 0 start | ✅ |
| 2 | Phase 0 完了 → commit + Phase 1 GO | ✅ |
| 3 | Phase 1 完了 → commit + Phase 2 GO | ✅(ただし Phase 1 は autonomous push 違反あり、STATUS §Last updated 記録) |
| 4 | Phase 2 完了 → commit + Phase 3 GO | ✅ |
| 5 | Phase 3 kickoff(今 chat 開始) | ✅ |
| 6 | Phase 3 中 commit 承認 | **次 chat 冒頭で消化予定(T3-1 commit + T3-3 以降 batch 承認)** |
| 7 | v1.0 ship 判断(SHIP-READINESS レビュー) | T3-5.5 完了後 |
| 8 | 予備 / strategic escalation | 温存 |

**次 chat は #6 と #7 を消化する想定**。追加 escalation は #8 で吸収。

---

## 12. v1.0 ship 後の残課題(参考)

- Signed DMG build は別セッション(`release:staple` / notarize / checksum 各 script 実行)
- web 側 WebGPU 化は v1.3 で別計画
- **Cross-filter(Soft + Hard Mode temporal + central bloom)は v1.1 の即時起票対象** — `gh issue create -R chibataku0815/chibatakumi-portfolio -t "v1.1: activate WebGPU cross-filter render integration (Soft + Hard Mode)" -b "WGSL 5 shader は feature/webgpu-migration-v1 で compile-validate 済。render graph への編入と \`hardMode: true\` / \`crossFilterStrength > 0\` 保存 preset のための 5-case PSNR gate を実装する。"` 相当を v1.0 ship 直後に起票

---

**EOF** — この 1 枚で完全な継続が可能。疑問があれば STATUS.md Decisions log を先に読むこと(戦略変更の根拠は全て §Decisions に集約)。
