# Phase 1 — Foundation + Simple shaders (Day 1)

**Budget**: 10h
**目的**: WebGPU backend の基盤を作り、Simple shader 9 本を end-to-end で通す。primary grade は identity placeholder のまま、bloom/halation チェーンだけ visually 正しく合成されることを確認。

---

## Entry criteria(Phase 0 完了で達成済み — verified 2026-04-18)

- [x] `navigator.gpu.requestAdapter()` が Electron で non-null — **Case A** 確定、flag 不要(`test/golden/adapter-info.json`: vendor=apple, architecture=metal-3, deviceOk=true, features=15, limits=32 keys)
- [x] `test/golden/baseline-A/` に 80 枚 — **JPEG Q=95** で保存(PNG 131MB → JPEG 19MB、plan §4 size gate の 50-200MB 帯 hit)。Phase 1 Baseline B は **PNG** で生成すること(PSNR reference)
- [x] `test/golden.harness.ts` + `test/golden-psnr.ts` + `test/golden.spec.ts` + `test/playwright.config.ts` 動作確認済み(53.7s / 1 pass)
- [x] `package.json` に `"test:golden"` + `"test:golden:baseline-a"` script
- [x] Test-mode hook `window.__filmtoneTest` in `src/renderer/App.tsx` (query `?__test=1`, prod-gated with `__test_prod_override=1`)
- [ ] `DIRECTION.md` §9 Escalation / §10 Decision Defaults を読んだ

## Phase 0 で得た Known gotchas(Phase 1 で参照)

- **Harness loadImage**: `FilmLabCanvasRef.replaceSourceFromPngBase64Body(base64)` を経由 — drag-drop handler を touch せず既存 API を流用、T2 実装が軽量化
- **ESM scope**: harness TS は ESM、`__dirname` 未定義 → `fileURLToPath(import.meta.url)` + `path.dirname` で patch 済み
- **CDP approach for T1**: DevTools self-XSS warning 回避のため、Electron を `--remote-debugging-port=9222` 付きで起動し、Bun WebSocket から `Runtime.evaluate` で adapter 情報取得 → adapter-info.json。Phase 1 以降でも同様の短経路が使える
- **Baseline A encoding**: JPEG Q=95(smoke 用)。Baseline B は PNG 必須(PSNR 比較の reference、lossy 入れない)
- **DPR override**: `__filmtoneTest.setCanvasSize(1280,720)` で canvas width/height/style を明示固定 + Viewport の `setResolution` 呼び出し(Viewport.ts:1768)。Retina backing store 2× を打ち消し
- **Gamma sanity check は Phase 1 に先送り**: Phase 0 では Baseline A が JPEG なので意味薄 → Phase 1 Baseline B(PNG)生成時に `toDataURL` vs `gl.readPixels` 1 枚比較を実施(plan §4 F4 fallback)
- **Prod leak check は Phase 1 完了時**: `bun run build` + `grep '__filmtoneTest' dist/` で 0 match 確認(まだ実施していない — dev only で検証済み)
- **Image 02 & 08 が極小(6KB/5KB)**: flat content のため PNG 圧縮率極端。capture の JPEG 出力は preset 適用で正常サイズに

---

## Tasks

### T1-1. Viewport 単一クラス refactor + WebGL 退避 (1h) [commit 1]

**目的**: 既存 Three.js 実装を `src/webgl/` に退避、`Backend` interface 抽出、`Viewport` を single-class + backend delegation 化。

手順:
```bash
cd packages/film-lab-renderer
git mv src/Viewport.ts src/webgl/WebGLBackend.ts
git mv src/shaders src/webgl/shaders
```

次に:
- `src/Viewport.ts` を**新規作成**:
  ```ts
  import type { RenderBackend } from './webgpu/Backend';
  import { WebGLBackend } from './webgl/WebGLBackend';

  export interface ViewportOptions {
    prefer?: 'webgpu' | 'webgl';
  }

  export class Viewport {
    private constructor(private backend: RenderBackend) {}

    static async create(canvas: HTMLCanvasElement, opts: ViewportOptions = {}): Promise<Viewport> {
      const prefer = opts.prefer ?? 'webgpu';
      if (prefer === 'webgpu' && (await isWebGPUSupported())) {
        const { WebGPUBackend } = await import('./webgpu/WebGPUBackend');
        return new Viewport(await WebGPUBackend.create(canvas));
      }
      return new Viewport(new WebGLBackend(canvas));
    }

    // 60 setters → delegate
    setExposure(v: number) { this.backend.setExposure(v); }
    // ... 以下同様
  }
  ```
- `src/webgpu/Backend.ts`: interface のみ定義(全 setter + `render` / `readPixels` / `resize` / `destroy`)
- `src/webgl/WebGLBackend.ts`: 既存 Viewport 実装を `implements RenderBackend` に rename
- `src/support.ts` に `isWebGPUSupported()` 追加(`DIRECTION §10 Phase 1 専用` の API 形式)
- `src/index.ts` から `Viewport`, `ViewportOptions`, `isWebGPUSupported`, `isWebGL2Supported` を export

**Build flag 設定**:
- `apps/web/vite.config.ts` に `define: { 'import.meta.env.FILMTONE_BACKEND': '"webgl"' }` を追加(既存なら更新)
- `apps/desktop-film-lab-batch/vite.config.ts` にも `'"webgpu"'` で同様追加
- `Viewport.create` の内部で `import.meta.env.FILMTONE_BACKEND === 'webgl'` なら WebGPU 分岐を skip(dynamic import しない = tree-shake される)

**Exit**: `bun run typecheck` pass、既存 desktop app が起動して WebGL 経路で画像表示(regression なし)

**Commit 案**: `Refactor Viewport as single class with pluggable Backend; relocate WebGL impl to src/webgl/`

---

### T1-2. GPU primitives 実装 (3h)

新規ファイル(全て `packages/film-lab-renderer/src/webgpu/` 配下):

#### `GpuContext.ts` (30min)
- `static async create(canvas): Promise<GpuContext>` で adapter / device / canvas context 初期化
- `context.configure({ device, format: 'rgba8unorm-srgb', alphaMode: 'opaque', colorSpace: 'srgb' })` (DIRECTION §2)
- `device.pushErrorScope('validation')` を dev 中入れる

#### `OffscreenTargetPool.ts` (45min)
- Lazy allocation、rgba16float full-res / half-res / quarter-res を labeled で管理
- `get(label, { width, height, format, mipLevels? })` で取得、同 label なら reuse
- resize 時に destroy + re-create
- bloom mip pyramid 5 枚、halation 6 枚用の pyramid helper を実装

#### `Lut3DTexture.ts` (30min)
- `upload(device, data: Float32Array, size: number): GPUTexture`
- `writeTexture` で `bytesPerRow = Math.max(256, size * 16)`(rgba16float は 8bytes/pixel、256 align)、`rowsPerImage = size` 必須
- 最初は identity LUT(33³ linear ramp)を生成する helper も用意(pipeline 通す用)

#### `MediaTexture.ts` (30min)
- `fromImageBitmap(device, bitmap): GPUTexture`
- `fromVideoElement(device, video): GPUTexture`(毎フレーム `copyExternalImageToTexture`)
- format = `rgba8unorm-srgb`(hw EOTF、linear RGB として読める)

#### `RingBuffer.ts` (30min)
- motion blur 用 8-slot texture array
- `GPUTexture({ size: [W, H, 8], dimension: '2d', usage: RENDER_ATTACHMENT | COPY_SRC | TEXTURE_BINDING, format: 'rgba16float' })`
- `validSlots: number` を管理、resize で再生成 + validSlots リセット
- `nextSlot(): number` で write 先 layer index を返す

#### `BlueNoiseTile.ts` + asset (15min)
- void-and-cluster で生成した 256×256 R8 PNG を `src/webgpu/assets/blue-noise-256.png` に check-in(既成なら再利用、無ければ `node scripts/generate-blue-noise.mjs` で生成して commit)
- `load(device): Promise<GPUTexture>` ヘルパー

**Exit**: 全 primitive が単体で instantiate できる(integration は T1-3 で確認)

**Commit 案**: `Add WebGPU primitives: GpuContext, OffscreenTargetPool, Lut3DTexture, MediaTexture, RingBuffer, blue-noise tile`

---

### T1-3. 9 Simple shaders 移植 + end-to-end 疎通 (4h) [commit 3]

**順序**(DIRECTION §10 Phase 1 Default): vert → bloom-prefilter → halation-prefilter → downsample → upsample → lightshafts → lightshafts-blend → dust + identity filmlab.wgsl placeholder

各 shader:
1. Naga CLI で初期変換: `bunx naga src/webgl/shaders/bloom-prefilter.frag -o src/webgpu/shaders/bloom-prefilter.wgsl`(naga が未 install なら `cargo install naga-cli` または npm で相当)
2. DIRECTION §4 に従い hand-fix:
   - vec4 alignment 修正
   - sampler 分離
   - `textureSampleLevel` 使用(非一様フロー内)
   - `max(x, 0.0)` ガード
3. `WebGPUBackend.ts` から pipeline 作成 + render pass 組み込み
4. Golden harness で identity filmlab を通して描画確認

**identity filmlab.wgsl**(placeholder、T2-1 で本実装に差し替え):
```wgsl
@fragment
fn fs(@builtin(position) pos: vec4f, @location(0) uv: vec2f) -> @location(0) vec4f {
  return textureSampleLevel(mediaTex, mediaSamp, uv, 0.0);
}
```
primary grade は no-op、下流の bloom/halation を visually 確認するための pass through。

**疎通確認**: canvas に画像を load → bloom intensity 0.8 / halation 0.5 等に設定 → **WebGL 版と近似した bloom/halation が出ていること**を目視(PSNR は Baseline B ができてからなので、ここは目視 OK で可)。

**Exit**: 9 WGSL ファイル存在、Golden harness が WebGPU backend で 1 枚でも capture できる

**Commit 案**: `Migrate 9 simple shaders to WGSL; wire bloom/halation pyramid end-to-end via WebGPU`

---

### T1-4. Baseline B capture (1h) [commit 4 に含める]

**目的**: 現行 WebGL 出力に post-hoc un-clamp を適用した PNG を 80 ケース生成。Phase 2-3 の PSNR gate の基準。

手順:
- `test/golden-baseline-b.ts`(新規)で以下を実行:
  ```ts
  // baseline-A の PNG を読み込む
  // 各 pixel に DIRECTION §10 Phase 1 の式を適用:
  // x' = x * (1 + 0.08 * smoothstep(0.92, 1.0, x))
  // R, G, B それぞれに linear 空間で適用(A は touch しない)
  // PNG として `test/golden/baseline-B/{preset}/{image}.png` に保存
  ```
- `bun run test:golden -- --baseline B` でバッチ実行

**Exit**: `test/golden/baseline-B/` に 80 PNG、`test/golden.harness.ts` に `compareAgainstBaselineB(webgpuOutputPath, presetId, imageId): number` PSNR 関数追加

**Commit 案**: T1-3 の commit に含めるか、別で `Add Baseline B (post-hoc linearized) for WebGPU PSNR gate`

---

### T1-5. buffer + STATUS 更新 + Phase 2 handoff 補完 (1h)

- STATUS.md を更新(Day 1 → done、Regressions ログ、Progress notes)
- `phase-2-handoff.md` の「Entry criteria」欄を Phase 1 実際の成果物状態に合わせて微調整(このファイルは direction が pre-write 済みだが、Known gotchas や成果 URL 等を埋める)
- Known gotchas セクションに Phase 1 学びを追記

---

## Exit criteria(8 項目、全達必須)

- [ ] `Viewport` single-class + Backend interface 完成、WebGL backend 退避済み、web build が WebGL で通る
- [ ] 6 primitive(GpuContext / OffscreenTargetPool / Lut3DTexture / MediaTexture / RingBuffer / BlueNoiseTile)実装
- [ ] 9 Simple shaders WGSL 移植、end-to-end で bloom/halation 描画確認(目視)
- [ ] `test/golden/baseline-B/` に 80 PNG
- [ ] `bun run typecheck` pass
- [ ] 既存 web / desktop app が WebGL path で regression なし
- [ ] STATUS.md Day 1 → done、Regressions / Notes 更新
- [ ] `phase-2-handoff.md` の Known gotchas / Entry 反映

---

## Phase 1 固有の Decision Defaults(DIRECTION §10 参照)

再掲:
- WebGL 退避は `git mv`、別 commit
- isWebGPUSupported → async Promise<boolean>、メモ化
- identity LUT を最初に通してから実 .cube
- Baseline B 生成式は `x * (1 + 0.08 * smoothstep(0.92, 1.0, x))`

---

## Known gotchas(Phase 1 で学んだら追記)

(Phase 1 実行中に判明した落とし穴をここに追記)

---

## Fail-stop / Escalate 条件

- Simple shader が 3 本以上 perf 30% 超劣化 → direction chat
- Blue-noise tile 生成に 1h 以上かかる → 既成 public domain tile を DL して使用(autonomous)
- bun typecheck で既存 web build が壊れる → 即 direction chat(regression 許容不可)
- Playwright harness が WebGPU backend 切替後に動かない → direction chat(Phase 0 成果物への回帰)

---

## 完了報告 template(user へ)

```
Phase 1 完了。Viewport backend 切替 + GPU primitives 6 本 + Simple shader 9 本 WGSL 化 + Baseline B 80 PNG。
Exit criteria 8/8 達成。Regression なし(WebGL path 既存動作維持)。
commit 案: 3 commit(refactor / primitives / shaders+baseline-B)
OK なら Phase 2 に移ります。
```

---

## First command in Phase 2 chat

新規チャット開始時に貼り付け:
```
作業ディレクトリ: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

@apps/desktop-film-lab-batch/docs/webgpu-migration/DIRECTION.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/phase-2-handoff.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md を読んで Phase 2 を実行してください。
Master plan ~/.claude/plans/sequential-thinking-gemini-web-swirling-prism.md の Day 2 節も確認。
```
