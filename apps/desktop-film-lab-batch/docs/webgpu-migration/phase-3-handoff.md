# Phase 3 — Cross-filter + Export + Ship (Day 3)

**Budget**: 10h
**目的**: 残 cross-filter 5 shader を移植、video-export 経路を WebGPU 化、Electron 統合仕上げ、Golden 80 ケース + smoke + DMG ビルドまで到達。v1.0.0 出荷候補の完成。

---

## Entry criteria(Phase 2 完了で達成済み — verified 2026-04-18)

- [x] filmlab.wgsl 完全実装(primary grade + Reinhard soft-shaper k=0.5 + LUT2 + print CMY + print contrast、commit `068b7063` / `be754796`)
- [x] composite.wgsl 実装(2 bind group、bloom/halation pyramid 結線、blue-noise grain、commit `be754796`)
- [x] motion blur 2 shader + RingBuffer(`depthOrArrayLayers=8`)+ blit fallback(commit `1c6e839b`)
- [x] `RenderBackend` interface + `Viewport` 単一クラス + `Viewport.create(canvas, {prefer})` async factory + 4 consumer 移行(batch-pipeline / video-export-pipeline / FilmLabCanvas / film-lab-web-video-export)
- [x] film-lab-renderer sub-path export(`./webgpu`)で tree-shake、`dist/index.js` に `WebGPUBackend` 0 match(web バンドルに WebGPU コードが入らないことを構造で保証)
- [x] `film-lab-renderer` typecheck clean、desktop tsc 17 errors(main 同数、regression delta 0)、film-lab-ui 1 pre-existing error(FilmLabCanvasPackageEntry.tsx:51 TS4023、本 phase 起因なし)
- [ ] DIRECTION §9-11 読了

### Phase 2 から繰越(必読)

- **Golden PSNR gate(50 ケース、≥40dB 45/50)+ 視覚証明(highlight グラデーション改善)は Phase 3 T3-3 以降に実施**。Phase 2 段階では `Viewport extends WebGLBackend` の継承構造が固定化されていて、`App.tsx` / `FilmLabCanvas.tsx` が `scene.add(viewport.mesh)` を前提にしている。WebGPU 出力を Viewport 経路で取り出すには、T3-3 で Viewport を composition 化(backend を内部に保持、setter を委譲)する refactor が前提。そこが通るまで Golden harness に WebGPU 出力が渡らない。
- Phase 3 T3-3 で `Viewport` を composition に切替 → `App.tsx` / `FilmLabCanvas.tsx` が backend-agnostic になった直後に、T3-4 の Golden 80 matrix と同時に Phase 2 由来の 50 ケース(代表 5 preset × 10 image)も測る(80 matrix は preset 8 × image 10 なので、5×10 は subset で回収可)。
- 視覚証明 screenshot(`docs/webgpu-migration/assets/highlight-proof/`)は T3-3 後・T3-5 SHIP-READINESS 前に、`sunset.jpg` / `backlit-portrait.jpg` / `white-dress.jpg` + 代表 preset の WebGL vs WebGPU 並び 3 枚を出す。

---

## Tasks

### T3-1. Cross-filter 5 shader + UI guard (3h) [commit 1]

**順序**(DIRECTION §10 Phase 3): peak → peak-spacing → peak-spacing-max → streak → blend

**SKIP 明示**:
- `cross-filter-streak-density.frag` は SKIP(exploration で未使用確認済)
- `cross-filter-temporal.frag` + central-bloom は**v1.1 先送り**(DIRECTION §1 D5)

**UI guard**:
- 設定画面で `crossFilterHardMode` UI 要素を disabled + "v1.1" バッジ表示
- tooltip: "Hard Mode temporal 効果は v1.1 で有効化予定"
- 既存 preset で `hardMode: true` が保存されていた場合、読み込み時に false に落として warning console 出力(backward compat 崩さない)

**各 shader 実装**:
- Naga CLI で初期変換 → hand-fix(DIRECTION §4 準拠)
- peak / peak-spacing chain は temporal 無しなら stateless、そのまま pipeline に組み込める
- streak は多 tap(MAX_STREAK_PX=64)なので perf 注意、半解像度 RT で実行
- blend は additive + Soft Reinhard(既存 GLSL と同じロジック)

**Golden gate**: cross-filter ON preset × 5 image = 5 ケース、Baseline B 比 PSNR ≥ 38dB(多 tap 系は精度差出やすいため緩め)が 4/5 以上。

**Commit 案**: `Migrate 5 cross-filter shaders; gate Hard Mode for v1.1`

---

### T3-2. Headless GpuRenderer + video-export (2h) [commit 2]

**目的**: Viewport(canvas 接続)と video-export(offscreen)で共通使える**headless レンダラ**を抽出。

新規: `packages/film-lab-renderer/src/webgpu/GpuRenderer.ts`
- WebGPUBackend の pipeline graph 部分だけを切り出し
- `async render(input: GPUTexture, output: GPUTexture): void`
- canvas 非依存(canvas context は Viewport の外側で管理)

**video-export-pipeline.ts 改修**:
- 既存 `videoExportRender(frame, params)` を `GpuRenderer` 使用に差し替え
- 出力先 = `GPUTexture({ format: 'rgba16float' })`
- `copyTextureToBuffer` で mapped staging buffer に吸い出し
- CPU 側で tone-mapping(filmlab.wgsl と同じ式をシェーダー経由で適用、rgba8unorm output)
- nv12 変換(ffmpeg filter `format=nv12` に渡す形式)で ffmpeg stdin 投入

**batch-pipeline.ts 改修**:
- 既存 `batchRender(image, params)` も `GpuRenderer` 経由に差し替え
- 出力 PNG は tone-mapped rgba8unorm → PNG encode

**Exit**: `bun run smoke:smart-look-pending` が WebGPU path で完走(IPC 経路破綻なし)

**Commit 案**: `Extract headless GpuRenderer; rewire video/batch export to WebGPU`

---

### T3-3. Viewport composition refactor + Electron 統合仕上げ (2h) [commit 3]

**T3-3 先頭で Viewport を composition に切替**(Phase 2 T2-0c から繰越の構造 refactor):

現状 `Viewport extends WebGLBackend` のため、`Viewport.create(canvas, {prefer:'webgpu'})` は `void opts.prefer` でスルーされて WebGL-backed Viewport を返す(`packages/film-lab-renderer/src/Viewport.ts:57`)。T3-3 の最初で以下に組み替える:

```ts
// Viewport.ts (after T3-3)
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
  // setParams / setLUT1 / setLUT2 / setMediaFromBitmap / setResolution / render / dispose を backend に委譲
}
```

**consumer 側の吸収**:
- `App.tsx` / `FilmLabCanvas.tsx` の `scene.add(viewport.mesh)` は `if (viewport.backendKind === 'webgl') scene.add(viewport.mesh!)` に
- `viewport.render(renderer, scene, camera)` は WebGL 専用 → WebGPU 分岐では `viewport.render()`(引数無し、canvas に直描画)で三分岐
- batch-pipeline / video-export-pipeline / film-lab-web-video-export は既に `Viewport.create` 経由なので `prefer` を渡すだけで動く

**Tree-shake の維持**: `import('film-lab-renderer/webgpu')` を dynamic import にして、Vite/Next の build flag (`import.meta.env.FILMTONE_BACKEND === 'webgl'`) 分岐で chunk を除外(Phase 1 で準備済み)。

---

**電源投入順整理**:

**電源投入順整理**:
- `electron/main.ts`: Phase 0 で追加した flag(Case B の場合)を v1.0 リリース時も保持(旧 macOS 互換の安全網)
- `app.whenReady()` 前の flag 追加を confirm:
  ```ts
  app.commandLine.appendSwitch('enable-unsafe-webgpu');
  // Case B 要件なら以下も
  // app.commandLine.appendSwitch('enable-features', 'Vulkan');
  ```

**`App.tsx` 改修**:
- `const viewport = await Viewport.create(canvas, { prefer: 'webgpu' });`
- 失敗時(`isWebGPUSupported() === false`)は自動で WebGL にフォールバック(Viewport.create 内で処理済み)
- renderer 初期化直後、pipeline pre-warm を `requestIdleCallback` 内で実行

**Pre-warm UI**:
- `viewport.prewarm()` を呼ぶ → 全 pipeline の最初の 1 frame を空 uniform で通す
- 150ms 超えた場合、"Preparing renderer…" overlay をフェードイン/アウト(DIRECTION §10 Phase 3)

**Exit**: `bun run desktop` で起動、WebGPU path で画像 load + preset 適用、regression なし

**Commit 案**: `Wire WebGPU backend into Electron app with pre-warm and flag safety-net`

---

### T3-4. Full smoke + Golden 80 matrix (2h)

**smoke tests**:
```bash
bun run typecheck
bun run test
bun run test:smart-look-pending
bun run smoke:smart-look-pending
bun run build
```
全て pass 必須。失敗あれば T3-1〜T3-3 内で修正。

**Golden 80 matrix**:
- `bun run test:golden -- --baseline B --full`
- 8 preset × 10 image = 80 ケース実行
- 結果 CSV を `docs/webgpu-migration/phase-3-golden-report.csv` に保存
- **合格基準**: PSNR ≥ 40dB が **75/80 以上**(単一 regression は accept、5 件以上なら direction chat)。**この 80 matrix は Phase 2 で punt された 50 ケース(代表 5 preset × 10 image)を subset で包含するので、Phase 2 Exit の PSNR gate も T3-4 で同時に回収**。

**視覚回帰 check**:
- 低 PSNR 順に top 5 ケースを目視 → 許容可能な差分か判定
- 許容不可なら shader 側の bug として fix

**Commit 案**: Exit criteria 達成で T3-1 〜 T3-4 をまとめて単一 commit も可、分けても可(ユーザー確認)。

---

### T3-5. dist:mac:unsigned + RELEASE_NOTES (1h) [commit 4]

**DMG build**:
```bash
cd apps/desktop-film-lab-batch
bun run dist:mac:unsigned
```
成果物: `release/Filmtone-1.0.0-arm64.dmg`(`package.json` の version を 0.6.2 → 1.0.0 に bump 必要)

**実機 QA**(自分で):
- DMG を mount → Filmtone.app を `/Applications/` に drag
- 起動 → 画像 1 枚 load → preset 3 種切替 → video 1 本書き出し → smart-look 1 回 → クラッシュなし
- highlight 豊富な画像で LUT2 出力の gradient を確認(v1.0 promise 証明)

**RELEASE_NOTES-v1.0.0.md 起案**:
既存 `RELEASE_NOTES-v0.*.md` 書式踏襲、以下 headline:
```md
# v1.0.0 — WebGPU migration

## Headline
- Linear Rec.709 + rgba16float working space(clamp 除去、LUT 前で広いレンジ保持)
- WebGPU backend(macOS arm64)、WebGL backend は web 向けに温存
- Hardware sRGB OETF で最終 display transform

## What's new
- ...

## Known limits
- Cross-filter Hard Mode temporal は v1.1 で対応予定
- apps/web 側は引き続き WebGL(v1.3 で WebGPU 化予定)
- HDR / P3 出力は未対応(v2.0 ロードマップ)

## Migration
- 既存 preset は 83 fields 全て完全互換、user action 不要
- hardMode: true で保存済みの preset は自動で false に落とされ、warning を console に出力

## Tech
- Three.js 依存削除、Pure WebGPU
- 11-pass render graph を rgba16float で再実装
- Blue-noise grain で GPU vendor 決定論を担保
```

**Commit 案**: `Release v1.0.0: bump version, add RELEASE_NOTES, dist:mac:unsigned build`

---

### T3-5.5. SHIP-READINESS.md 自動生成 (15min) [commit 5]

**目的**: v1.0 ship 判断のために、user が**この 1 ファイルだけ読めば決められる**状態にする。

生成先: `apps/desktop-film-lab-batch/docs/webgpu-migration/SHIP-READINESS.md`

Phase 3 chat が以下フォーマットで自動生成(値は実測値に差し替え):

```md
# Filmtone v1.0.0 — Ship Readiness Report

**Generated**: {ISO timestamp}
**Branch**: `feature/webgpu-migration-v1`
**Commits in branch**: {n}
**DMG**: `apps/desktop-film-lab-batch/release/Filmtone-1.0.0-arm64.dmg` ({size} MB)

## Auto checks
- [{✓/✗}] `bun run typecheck` pass
- [{✓/✗}] `bun run test` pass ({n} tests)
- [{✓/✗}] `bun run smoke:smart-look-pending` pass
- [{✓/✗}] `bun run build` pass
- [{✓/✗}] `bun run dist:mac:unsigned` produced DMG

## Golden 80 matrix (vs Baseline B)
- Pass ≥ 40dB: **{n}/80**
- Fail (< 40dB): {n}/80
- 失敗ケース一覧:
  - {preset}/{image}: PSNR={dB}(理由: {linear pipeline 期待差 / 要調査})
- Screenshots: `docs/webgpu-migration/assets/highlight-proof/` に {n} 枚

## 視覚証明(v1.0 promise)
- 高 DR サンプル 3 枚で LUT2 出力の highlight gradient 改善を確認:
  - `sunset.jpg` + preset A: before / after 画像 {link}
  - `backlit-portrait.jpg` + preset B: {link}
  - `white-dress.jpg` + preset C: {link}

## Manual QA(Phase 3 chat 実施済み)
- [{✓/✗}] DMG install + 起動 + 画像 load + preset 切替(3 種)
- [{✓/✗}] Video export 1 本 完走
- [{✓/✗}] smart-look 1 回 正常
- [{✓/✗}] クラッシュ無し(10 min 操作)

## Known issues deferred to v1.1+
- Cross-filter Hard Mode temporal(v1.1 予定、UI はグレーアウト)
- apps/web の WebGPU 化(v1.3 予定、現状は WebGL 継続)
- HDR / P3 出力(v2.0 ロードマップ)

## Regressions accepted
- {list, each with rationale; empty if none}

## Recommendation

**Phase 3 chat 判定**: **{ship-ready / hold / needs-review}**

理由: {1-2 行}

## User action

### Ship 承認の場合
```bash
git checkout main
git pull
git merge --no-ff feature/webgpu-migration-v1 -m "Release v1.0.0: WebGPU migration"
git push origin main
# その後 signed DMG build:
cd apps/desktop-film-lab-batch
bun run dist:mac:release  # notarize 含む、10-20 min
bun run release:staple
bun run release:checksums
bun run release:upload-blob
bun run release:upload-update-meta
```

### Hold の場合
direction chat に以下貼り付け:
> SHIP-READINESS レビュー結果: hold。{理由 1-2 行}。Day 4 発動して {対処内容}。
```

**User の判断コスト**: この単一ファイルを 5-10 分で読む → "merge" or "hold" の 1 択。

**Commit 案**: `Generate SHIP-READINESS report for v1.0.0 go/no-go`

---

### T3-6. buffer + Day 4 判断 (1h)

- STATUS.md に Phase 3 → done、Day 4 判断(実施 / skip)
- Day 4 実施判断の基準:
  - Golden で 5-10 件 regression ありで fix したい
  - Hard Mode temporal を WebGPU で通す余力ある
  - v1.0 出荷前にシグネチャ付き DMG まで作りたい
- 不実施なら Day 4 セクションを STATUS.md で "skipped" 記録
- User に最終報告

---

## Exit criteria(9 項目、全達必須)

- [ ] Cross-filter 5 shader WGSL 移植、Hard Mode UI グレーアウト
- [ ] headless `GpuRenderer` 抽出、video-export + batch-pipeline が WebGPU で完走
- [ ] Electron `bun run desktop` 起動 → WebGPU path で regression なし
- [ ] `bun run typecheck` / `bun run test` / `bun run smoke:smart-look-pending` / `bun run build` 全 pass
- [ ] **Golden 80 matrix**: PSNR ≥ 40dB が 75/80 以上
- [ ] `dist:mac:unsigned` DMG 生成、実機 install + smoke QA pass
- [ ] `package.json` version 1.0.0、`RELEASE_NOTES-v1.0.0.md` 起案
- [ ] STATUS.md Phase 3 → done、Day 4 判断記録
- [ ] v1.0 promise(広い range)の視覚証明スクショを RELEASE_NOTES から参照可能な場所に配置

---

## Phase 3 固有の Decision Defaults(DIRECTION §10 再掲)

- Cross-filter order: peak → peak-spacing → peak-spacing-max → streak → blend
- streak-density は SKIP、Hard Mode は v1.1
- Video export: rgba16float → rgba8unorm (tone-mapped) → nv12 → ffmpeg
- ffmpeg codec: 既存のまま
- DMG: unsigned for Day 3、signed は別作業
- RELEASE_NOTES: 既存書式踏襲、headline "WebGPU migration"
- Pipeline pre-warm UX: 150ms 未満 silent、以上 overlay
- Web bundle: build flag で WebGPU dynamic import、tree-shake 確認

---

## Known gotchas(Phase 3 で追記)

### Phase 2 引継ぎ(Viewport 構造起因)

- **Viewport は現在 `extends WebGLBackend`**: `packages/film-lab-renderer/src/Viewport.ts` は `WebGLBackend` を継承しているので、`viewport.mesh` / `viewport.setParams(...)` / `viewport.render(renderer, scene, camera)` が全て Three.js API のまま露出している。WebGPU 経路では `viewport.mesh` は存在しないため、`App.tsx:scene.add(viewport.mesh)` / `FilmLabCanvas.tsx` の Three.js 連携は T3-3 で composition に切替えない限り WebGPU 分岐を呼べない。
- **T3-3 で期待される refactor 形**: `Viewport.create(canvas, {prefer})` が内部で `WebGPUBackend.create(canvas)` or `new WebGLBackend({vertex, frag, w, h})` を分岐保持し、`setParams / setLUT1 / setLUT2 / setMediaFromBitmap / setResolution / render / dispose` を backend インスタンスへ委譲。`viewport.mesh` は WebGL 分岐のみ(WebGPU は canvas 直描画なので不要)。App.tsx / FilmLabCanvas.tsx 側の `scene.add(viewport.mesh)` は WebGL 分岐専用のコードに変わる(`if (viewport.backendKind === 'webgl') scene.add(viewport.mesh)`)。
- **Viewport.create の `prefer` は現在 `void opts.prefer`**(Viewport.ts:57): T2-0c 時点ではインタフェースのみ、実ルーティング未接続。T3-3 で本格接続。
- **4 consumer 全移行済**: batch-pipeline / video-export-pipeline / FilmLabCanvas / film-lab-web-video-export 全て `await Viewport.create(canvas, {...})` 経由(Phase 2 T2-0c)。T3-3 で Viewport 内部を composition に切替える際、consumer 側は再修正不要(prefer を渡すだけで分岐する)。
- **Golden harness 入口は `window.ln`**(`apps/desktop-film-lab-batch/src/renderer/App.tsx` が `?__test=1` 時のみ expose)。T3-3 後は `window.ln.getViewport()` が backend-agnostic な委譲 wrapper を返す形になるので、既存 golden.harness.ts の `h.setParams(preset)` / `h.loadImage(base64)` / `h.setCanvasSize(w,h)` がそのまま動く想定。

(Phase 3 実行中判明したらここに追記)

---

## Fail-stop / Escalate 条件

- Golden 80 matrix で 5+ regression → direction chat(scope / 精度再検討)
- Cross-filter shader が GPU validation error 多発 → direction chat
- DMG が実機で crash → direction chat(原因特定 + Day 4 強制発動)
- `bun run dist:mac:unsigned` 失敗(既存 esbuild / electron-builder chain の破綻) → direction chat

---

## 完了報告 template

```
Phase 3 完了。Cross-filter 5 / GpuRenderer / Electron 統合 / Golden 80 matrix / DMG ビルド。
Golden PSNR ≥ 40dB = {n}/80。DMG 実機 QA {OK / 課題有(詳細)}。
Regression {あり / なし}。Day 4 判断: {実施 / skip}(理由)
commit 案: 4-5 commit(詳細は下記)
v1.0 ship 可否を教えてください。
```

---

## First command in Day 4 chat(実施する場合)

```
作業ディレクトリ: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

@apps/desktop-film-lab-batch/docs/webgpu-migration/DIRECTION.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md を読んで Day 4 半日バッファを実行してください。
作業項目は STATUS.md の Day 4 セクションで direction chat が指定した 1-3 項目に絞ります。
```

---

## v1.0 ship 後(参考)

- signed DMG build は別セッション(release:staple / notarize / checksum 各 script 実行)
- web 側 WebGPU 化は v1.3 で別計画
- Hard Mode temporal は v1.1 の issue として即 gh create
