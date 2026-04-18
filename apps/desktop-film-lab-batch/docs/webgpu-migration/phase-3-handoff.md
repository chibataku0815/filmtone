# Phase 3 — Cross-filter + Export + Ship (Day 3)

**Budget**: 10h
**目的**: 残 cross-filter 5 shader を移植、video-export 経路を WebGPU 化、Electron 統合仕上げ、Golden 80 ケース + smoke + DMG ビルドまで到達。v1.0.0 出荷候補の完成。

---

## Entry criteria(Phase 2 完了で達成済み想定)

- [ ] filmlab.wgsl 完全実装(soft-shaper + LUT2 + print 含む)
- [ ] composite.wgsl 実装
- [ ] motion blur 2 shader + RingBuffer 接続
- [ ] Golden 50 ケース ≥ 40dB(代表 5 preset × 10 image)
- [ ] 視覚証明(highlight グラデーション改善)スクショ保存
- [ ] `bun run typecheck` clean
- [ ] DIRECTION §9-11 読了

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

### T3-3. Electron 統合仕上げ (1h) [commit 3]

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
- **合格基準**: PSNR ≥ 40dB が **75/80 以上**(単一 regression は accept、5 件以上なら direction chat)

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

(実行中判明したらここに追記)

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
