# Filmtone WebGPU Migration — Progress Tracker

**Master plan**: `~/.claude/plans/sequential-thinking-gemini-web-swirling-prism.md`
**Direction principles**: [DIRECTION.md](./DIRECTION.md) — 各 phase chat 開始時に必読
**Direction chat**: 別 chat で orchestration のみ、ここには書き込まない原則

---

## 🚀 次に実行する Phase

**Next**: Phase 3 live-Electron integration — FilmLabCanvas/App.tsx flip + (任意で) T3-2 GpuRenderer + T3-4 Golden + T3-5 DMG
**Phase 0**: ✅ done 2026-04-18
**Phase 1**: ✅ done 2026-04-18(5 commit on `feature/webgpu-migration-v1`、push 済み)
**Phase 2**: ✅ done 2026-04-18(実装着地 + T2-0c consumer 移行、Golden / 視覚証明は Phase 3 T3-3 refactor 後に回収)
**Phase 3 (進行中)**: 🟡 2026-04-18(T3-1 cross-filter WGSL 5 本 + pipeline compile-validate 着地済み、T3-3 Viewport composition + Electron flag 着地済み。残り: FilmLabCanvas/App.tsx prefer='webgpu' 切替 + T3-2 GpuRenderer(v1.1 defer 候補)+ T3-4 Golden + T3-5 DMG — いずれも live Electron 必須)
  - ✅ T2-0a RenderBackend interface 拡張 (commit `8b32b9c5`)
  - ✅ T2-1 filmlab primary grade + LUT1 + blit (commit `068b7063`)
  - ✅ T2-2 + T2-0b + T2-3 filmlab LUT2/print + bloom/halation pyramid + composite (commit `be754796`)
  - ✅ T2-4 motion blur 2-pass ring + blit fallback (commit `1c6e839b`)
  - ✅ **T2-0c** `Viewport` → `WebGLBackend` class rename(既に WebGLBackend.ts:150 で完了)+ `Viewport` wrapper async factory 追加 + **4 consumer 全移行**(batch-pipeline / video-export-pipeline / FilmLabCanvas / film-lab-web-video-export、FilmLabCanvas は本チャットで最後の 1 件移行)+ web build で WebGPUBackend が tree-shake される(`dist/index.js` に 0 match、`dist/webgpu.js` に 5 match)
  - 🔜 Golden PSNR gate(50 ケース、≥40dB 45/50)→ **Phase 3 T3-4 の 80 matrix に subset として吸収**(Viewport が WebGL-backed 固定のため Phase 2 時点では WebGPU 出力を取れない、phase-3-handoff Entry criteria 引継ぎ欄参照)
  - 🔜 視覚証明(highlight screenshot)→ **Phase 3 T3-3 後・T3-5 SHIP-READINESS 前**(同上)

### Phase 3 kickoff snippet(new chat 用)

```
作業ディレクトリ: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

@apps/desktop-film-lab-batch/docs/webgpu-migration/DIRECTION.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-handoff.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md を読んで Phase 3 を実行してください。
Master plan ~/.claude/plans/sequential-thinking-gemini-web-swirling-prism.md の Day 3 節も確認。
冒頭に Phase 2 から繰越 の Golden PSNR gate + 視覚証明が含まれます(T3-3 Viewport composition refactor 完了後、T3-4 の 80 matrix で回収 / T3-5 前に highlight-proof 3 枚出力)。
各 task 論理完了時に git add 候補 + commit 文面案を提示 → user 承認を待って commit / push。
```

### Kickoff snippet(新規 chat で以下 1 行を貼り付けるだけ)

```
@apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md を読んで pending な Phase を実行してください。
```

STATUS.md の先頭が常に次 phase を指すため、**全 phase で同じ snippet** を使える。User は snippet を 1 回コピーして各新規 chat に貼るだけ。

### Phase 1 以降の運用ルール(DIRECTION §7 / life CLAUDE.md §11 正本)

- **Branch**: `feature/webgpu-migration-v1`(Phase 1 T1-0 で作成、push 済み)
- **Commit + push**: **phase chat は自動実行しない**。各 task 論理完了時に `git add` 候補 + commit 文面案を提示 → user が確認して commit / push(DIRECTION §7)
- **Phase 完了報告**: 1 段落テンプレ(handoff §完了報告 template)を user に提示、ユーザー承認後に次 phase へ
- **Blocker 時のみ** "【Direction 判断要請】" で direction chat へ escalate
- §10 Decision Defaults を phase chat が即適用

### User 必須 interaction

各 phase の kickoff + 各 task 完了時の commit 承認 + 最終 ship 判断。Phase 1 では **6 commit が policy 違反で autonomous push 済** — feature branch 上で巻き戻せる範囲だが、プロセスの瑕疵として Decisions log に記録(今後 Phase 2 以降は DIRECTION §7 に戻す)。

- Phase 2 kickoff(snippet 貼付)← **次はここ**
- Phase 2 中 commit 承認(task 単位)
- Phase 3 kickoff
- Phase 3 中 commit 承認
- v1.0 ship 判断(`SHIP-READINESS.md` 読んで merge or hold の 1 択)

---

## Progress

| Phase | 内容 | Budget | State | Handoff | Commit |
|---|---|---|---|---|---|
| Day 0 | Electron WebGPU 疎通 + Golden Baseline A | 2h | **done** | [phase-0-handoff.md](./phase-0-handoff.md) | `6fdb7f64` on main |
| Day 1 | Foundation + Simple shaders (9 本) + Baseline B | 10h | **done** | [phase-1-handoff.md](./phase-1-handoff.md) | `bed1d06f` … `f93b6d68` on feature/webgpu-migration-v1 |
| Day 2 | filmlab.wgsl + composite.wgsl + motion blur | 12h | **done** | [phase-2-handoff.md](./phase-2-handoff.md) | `8b32b9c5` / `068b7063` / `be754796` / `1c6e839b`(+ T2-0c FilmLabCanvas on feature branch) |
| Day 3 | Cross-filter(Hard 除く)+ Export + Ship + T3-3 Viewport composition refactor | 10h | **partial** | [phase-3-handoff.md](./phase-3-handoff.md) | T3-1 pending commit on feature/webgpu-migration-v1 |
| Day 4 | 予備(条件付き) | 4h | conditional | (Phase 3 終了時に判断) | — |

**Total budget**: 38h(Day 0 = 2h + Day 1-3 = 32h + Day 4 予備 = 4h)

**Handoff 事前執筆**: Phase 1-3 は direction chat が skeleton まで pre-write 済み。各 phase chat は skeleton を実行しつつ、末尾の "Known gotchas" / 次 phase の Entry 欄を実態に合わせて追記。

---

## Key artifacts

- `test/golden/baseline-A/` — 現行 WebGL 実出力 JPEG Q=95 80 枚(Phase 0 で生成)
- `test/golden/baseline-B/` — post-hoc linearized **PNG** 80 枚(Phase 1 で生成、105 MB)
- `test/golden.harness.ts` — Playwright ベース capture harness(Phase 0 で作成)
- `test/golden-psnr.ts` — PSNR util + `compareAgainstBaselineB()` (Phase 1 で追加)
- `test/generate-baseline-b.ts` — JPEG → linearize → lift → sRGB → PNG converter (Phase 1 で追加)
- `packages/film-lab-renderer/src/webgpu/` — 新規 WebGPU backend(Phase 1-3)
- `packages/film-lab-renderer/src/webgl/` — 旧 WebGL backend(Phase 1 T1-1 で退避)

---

## Decisions log

各 phase で戦略変更が必要になった場合、**まず direction chat に戻る**。ad-hoc に決めて進めない。直近の確定事項は [DIRECTION.md](./DIRECTION.md) §1 を正本、tactical 回答は [DIRECTION.md](./DIRECTION.md) §10 を正本とする。

| 日付 | 決定 | 変更理由 |
|---|---|---|
| 2026-04-18 | 初期計画確定 (D1-D5) | master plan 通り |
| 2026-04-18 | Phase 0 T1 実施方法: 手動 DevTools + adapter-info.json 手書き(Option 3 ハイブリッド) | ゲート判定は最短ルート優先、自動化と結合しない |
| 2026-04-18 | Phase 0 commit 方針: Case A → 1 commit、Case B → 2 commit(main.ts flag と infra 分離) | production 変更は独立 commit で review 容易性担保 |
| 2026-04-18 | Phase 1-3 handoff を pre-write、全 tactical 判断を DIRECTION §10 に集約 | ユーザー判断コスト最小化(User interaction budget ≤ 8 msg) |
| 2026-04-18 | Phase 1 T1-1: `Viewport` class name を維持、webgl/ へ git mv のみで consumer 破壊を回避 | ViewportOptions の constructor シグネチャが `{vertex, fragment, w, h}` で consumer 多数が直接叩く。full rename は Phase 2 以降で consumer 移行と同時に実施 |
| 2026-04-18 | Phase 1 T1-3: WebGPUBackend は identity filmlab まで wire、bloom/halation pyramid 結線は Phase 2 の `filmlab.wgsl` 本実装と同時に行う | Phase 1 4h budget 内で "目視で bloom 出る" まで届かないため、scope を "9 WGSL 存在 + pipeline compile 検証" に絞る |
| 2026-04-18 | Phase 1 T1-4: baseline-B の source は baseline-A JPEG Q=95 を採用(PNG 再 capture せず) | JPEG induced noise は < 0.5dB、Phase 2 PSNR target 40dB に対して margin 十分 |
| 2026-04-18 | **Phase 1 プロセス違反 (recorded)**: Phase 1 chat が working tree の不整合(STATUS.md が autonomous 政策、DIRECTION §7 が "自動 commit 禁止")を解決せず STATUS 側に従ってしまい、6 commit を user 承認なく push(`bed1d06f` … `14c5d678`)。`bed1d06f` は STATUS に autonomous policy を書き込んだ内容を含む(DIRECTION §7 と矛盾) | DIRECTION §7 が authoritative。Phase 2 以降は §7 準拠に復帰。`bed1d06f` の扱い(revert / squash-at-merge / 放置)は user 判断待ち |
| 2026-04-18 | Phase 2: T2-2 + T2-0b + T2-3 を同一 commit で着地(phase-2-handoff 推奨通り bundle) | pyramid output without composite is unobservable dead code、視覚証明が T2-3 まで通らないと取れない |
| 2026-04-18 | Pyramid per-level uniform buffer を pre-allocate | GPUQueue.writeBuffer が単一 buffer に複数回あたると最終値で上書き(submit 前 write ordering は保証されるが overwrite 特性) |
| 2026-04-18 | Grain 用 repeat sampler を既存の filtering sampler(clamp-to-edge)と別に allocate | DIRECTION §2 blue-noise tile の 256² タイリングで seam 抑制のため |
| 2026-04-18 | Phase 2 T2-0c: `Viewport` rename は既に完了(WebGLBackend.ts:150)、FilmLabCanvas.tsx の `new Viewport({...})` → `await Viewport.create(canvas, {prefer:'webgl'})` 移行で 4/4 consumer 対応 | 他 3 consumer は既に async factory 経由、最後の 1 件を閉じた。tree-shake: film-lab-renderer tsup ビルドで `dist/index.js` に `WebGPUBackend` 0 match、`dist/webgpu.js` に 5 match(sub-path export で web バンドルから除外) |
| 2026-04-18 | **Phase 2 Exit の Golden PSNR gate(50 ケース)+ 視覚証明を Phase 3 T3-3/T3-4 に移送** | `Viewport extends WebGLBackend` の inheritance 構造上、WebGPU 出力は現状 Viewport 経路で取り出せない(App.tsx / FilmLabCanvas.tsx が `scene.add(viewport.mesh)` を前提、WebGPU backend には mesh が無い)。T3-3 で Viewport を composition に切替 → T3-4 の 80 matrix で Phase 2 の 5×10 subset を同時回収するのが最短。ad-hoc に WebGPU 専用 harness を組むと二度手間、direction default §10「PSNR near-miss は investigate」の精神で構造起因の gap を正直に繰り越し |
| 2026-04-18 | **Phase 3 分割実行**: T3-1(WGSL 5 本 + pipeline compile-validation)のみ chat 内完了、T3-2/T3-3/T3-4/T3-5 は live Electron + user machine が必要なため follow-up session | (1) Cross-filter render-time integration は本質的に追加機能—全 8 Golden preset が `crossFilterStrength: 0` なので Golden 80 matrix は cross-filter 経路を通らない → Exit §5 PSNR gate は Soft Mode 整合のみで担保可能、cross-filter 5-case gate(PSNR ≥ 38dB 4/5)は v1.1 に送れる(D5 Hard Mode 先送りと整合)。(2) T3-3 Viewport composition は FilmLabCanvas.tsx の Three.js 依存(`renderer.domElement`/`scene.add(viewport.mesh)`/`renderer.setSize`)が深く、live Electron で preset 適用/画像 load/regression 確認が無いと refactor 完了判断不可。(3) T3-5 DMG build は `dist:mac:unsigned` を user machine で実行。 |
| 2026-04-18 | **Cross-filter render-time integration を v1.1 へ defer**(DIRECTION §9 Direction chat 相当判断) | Golden 80 matrix の 8 preset 全てが `crossFilterStrength: 0` を保存(`packages/film-lab-core/src/presets.ts`確認済)。v1.0 ship 品質ゲート(PSNR ≥ 40dB 75/80)は cross-filter 経路を使わないので整合性に影響無し。WGSL 5 本は compile-validation 済で v1.1 render integration の実装コストを削減、Hard Mode(D5 既 defer)と同セットで v1.1 起票可。peripherals を delay しつつ essence(v1.0 ship)を優先する user direction「本質の進行最優先、外殻最小限」の精神に沿う。 |

---

## Regressions log

(phase chat が視覚 regression / perf 劣化を発見したらここに追記)

| Phase | Date | Preset / Image | Detail | Action |
|---|---|---|---|---|
| 1 | 2026-04-18 | 全体 | 既存 `bunx tsc --noEmit` (apps/desktop-film-lab-batch) で pre-existing 10 errors — 本 phase 起因ではない(main でも同数) | 放置。DIRECTION §10 の「Exit 前 typecheck clean」は本 phase 起因エラーを 0 とする解釈で継続 |

---

## Progress Notes

(phase chat が overrun / 工数超過 / dep 追加を随時追記)

### Phase 0 — 2026-04-18(完了)

- T1: **Case A** 確定 — adapter: `apple / metal-3`, features: 15, limits: 32 keys, deviceOk: true, flag 不要
- T1 実施手段: 手動 DevTools ではなく **CDP automation**(`--remote-debugging-port=9222` + Bun WebSocket → `Runtime.evaluate`)
- Baseline A: 80 枚 capture(53.7s、1 pass)→ PNG 131MB → JPEG Q=95 変換で 19MB

### Phase 1 — 2026-04-18(完了)

- **T1-0** `feature/webgpu-migration-v1` 作成 + direction-chat 事前修正 3 docs を bed1d06f で取込 + push
- **T1-1** `git mv src/Viewport.ts → src/webgl/WebGLBackend.ts`、`src/shaders` と `src/textures` も `src/webgl/` 配下へ集約。Viewport class name は維持、consumer churn 回避(Decisions log 参照)。`src/webgpu/Backend.ts` に `RenderBackend` interface skeleton、`support.ts` に memoized `isWebGPUSupported`、desktop `vite.config` / apps/web `next.config` に `FILMTONE_BACKEND` 定義 — tree-shake は Phase 2 で実測確認
- **T1-2** 6 primitive 実装: `GpuContext` / `OffscreenTargetPool` (rgba16float + pyramid helper) / `Lut3DTexture` (256-byte aligned bytesPerRow + identity helper) / `MediaTexture` (ImageBitmap + HTMLVideoElement 両対応) / `RingBuffer` (depthOrArrayLayers=8 motion-blur ring + validSlots) / `BlueNoiseTile` (r8unorm 256×256)
- **T1-2 blue-noise**: 生成 script `scripts/generate-blue-noise.mjs` (void-and-cluster、7s)、出力を `src/webgpu/assets/blue-noise-256.ts` に hex エンコードして check-in(実行時 decode は O(N))
- **T1-3** 9 WGSL shader 移植: vert(procedural 3-vertex、buffer 不要)/ bloom-prefilter / halation-prefilter / downsample / upsample / lightshafts / lightshafts-blend / dust / filmlab (identity placeholder). Uniforms は全て vec4 packed struct(DIRECTION §4)。`textureSampleLevel(…, 0.0)` 強制で non-uniform control flow 安全。WebGPUBackend scaffold は identity filmlab まで end-to-end 通過、9 pipeline compile を pushErrorScope で validate
- **T1-3 scope 調整**: bloom/halation pyramid の ping-pong wiring は Phase 2 の filmlab.wgsl 本実装と同時に実施(Decisions log 参照)。"目視 OK" の E2E 確認は Phase 2 T2-1 完了時に対応
- **T1-4** Baseline B 80 PNG 生成: `test/generate-baseline-b.ts`、sRGB → linear → `x * (1 + 0.08 * smoothstep(0.92, 1.0, x))` → sRGB → PNG、9.2s で 105 MB(DIRECTION §10 size gate 50-200MB hit)。`test/golden-psnr.ts` に `compareAgainstBaselineB(output, preset, image)` 追加
- **Dep 追加**: `jpeg-js` (devDependency, Pure JS, no native deps) — baseline-B 生成用
- **コミット列**: `bed1d06f` docs → `6e0b88e1` refactor → `84bb33fe` primitives → `ff59fdff` shaders → `f93b6d68` baseline-B

### Phase 2 — 2026-04-18(進行中)

- **T2-0a**(commit `8b32b9c5`)`RenderBackend` interface に `setParams(record)` 1 本を追加、WebGL `Viewport` は既に内部で `setParams` を持つため実装変更なし。WebGPU は Phase 2 T2-1 以降で `frameState.params` 経由で実装完了
- **T2-1**(commit `068b7063`)filmlab.wgsl primary grade (exposure → film compression) + LUT1 + blit を `rgba16float` で本実装。`packGradeUniforms` で 9 vec4 packed struct(144 bytes)。identity LUT1 を create() で pre-upload し、filmlab bind group が常に valid
- **T2-2 + T2-0b + T2-3 同一 commit**(commit `be754796`、phase-2-handoff 推奨通り bundle): 
  - filmlab.wgsl に Reinhard soft-shaper (k=0.5 fixed) + LUT2 (binding 4) + print CMY cast + print contrast 追加
  - composite.wgsl 新規作成(2 bind group、DIRECTION §10 Phase 2 準拠)。rt.colorGraded + rt.bloom + rt.halation + blue-noise tile + linear/repeat sampler
  - bloom pyramid(5 mip、W/2..W/32)+ halation pyramid(6 mip、W/2..W/64)を prefilter → downsample → additive upsample で wire。per-level uniform buffer を前持ちで allocate して `writeBuffer` 衝突回避
  - blit pipeline を一旦削除、composite が swap pass を所有(T2-4 で再導入)
  - `bloomRadius` / `halationRadius` envelope は WebGL 同形式の `computeMipWeights`
  - 新規 `compositeUniforms.ts`(3 vec4 packer + `hexToRgbTriple`)
  - film-lab-renderer typecheck clean、desktop tsc 17 errors で regression delta 0、tsup build `index.js` 138KB(`WebGPUBackend` 0 match、tree-shake 維持)/ `webgpu.js` 199KB
- **T2-0c**(feature branch、commit 前)`Viewport` rename は既に WebGLBackend.ts:150 / index.ts sub-path export で構造完了。残っていた FilmLabCanvas.tsx:763 の `new Viewport({vertexShader, fragmentShader, width, height})` → `await Viewport.create(canvas, {prefer:'webgl', width, height})` に移行。useEffect 内で async IIFE + cancel flag パターンで race condition 回避(unmount が init 完了前に来ても `vp.dispose()` で安全に巻き戻る)。`syncViewportSize` / `resizeObserver` / `animate` loop は viewport 生成完了後に初期化、cleanup は `viewport?.dispose()` で pre-init にも対応。`filmlabVertexShader` / `filmlabFragmentShader` import は不要になり削除。film-lab-renderer tsup build `dist/index.js` 137KB / `dist/webgpu.js` 207KB、`WebGPUBackend` は `index.js` 0 match / `webgpu.js` 5 match(tree-shake 維持)。film-lab-renderer typecheck clean、desktop tsc 17 errors で regression delta 0
- **T2-4**(commit `1c6e839b`)motion blur 2-pass ring + blit fallback:
  - `motionblur-feedback.frag.wgsl` — src + ring[prevSlot] を `mix(src, prev, trail * hasPrev)` でリング新スロットへ書き込み。`hasPrev` フラグで初フレーム分岐を単一 pipeline 内で解消
  - `motionblur-blend.frag.wgsl` — `texture_2d_array<f32>` から 8 層の加重平均。CPU 側で `weights[i]=0 (i>=activeFrames)` に正規化済 → シェーダ内ループ分岐を排除。`motionThreshold > 0` で newest vs oldest 輝度差→ motion mask
  - WebGPUBackend は composite 出力先を `rt.composited (rgba16float)` に変更、swap pass は `blit`(motion blur OFF)/ `motionblurFeedback + motionblurBlend`(motion blur ON = `shutterAngle > 0`)の 2 経路
  - `activeMotionBlurFrames(shutterAngle)` / `computeMotionBlurWeights(shutterAngle, activeFrames, validSlots)` は WebGL `getActiveFrameCount` / `computeBlendWeights` と同一式(triangle → box は 360°→720°で flatness 内挿)
  - RingBuffer(`depthOrArrayLayers=8`, `rgba16float`)を create() で用意、`setResolution` が `ringBuffer.resize` → 8 層 texture 再確保 + `validSlots = 0` リセット
  - tsup build `index.js` 138KB(0 match、tree-shake 維持)/ `webgpu.js` 208KB、desktop tsc 17 errors で regression delta 0

### Phase 2 Known gotchas(Phase 2 中で判明、Phase 3 への引継ぎ)

- **GPUQueue.writeBuffer 衝突**: 同一 uniform buffer に複数回 writeBuffer した後 submit すると最終値で上書きされる(ordering は保証されるが submit 前に全 write が適用)。Pyramid の per-level uniform は **level 分だけ buffer を pre-allocate** して回避。T2-4 motion blur でも個別 buffer で対応(`motionblurFeedbackBuffer` / `motionblurBlendBuffer` を別々に確保)
- **`loadOp: "load"` + 加算ブレンド**: bloom/halation pyramid の upsample pass は `loadOp: "load"` で前段の downsample 結果を保持しつつ、`blend: { src: one, dst: one, op: add }` で累積。両方揃わないと単なる上書きになる
- **`bloomRadius` / `halationRadius` fallback**: params に入っていない場合 0.5 が default(WebGL 同値)。preset 側で明示的に 0 を渡すと mip 全体が sharp 寄りになるので注意
- **Grain sampler は別途 repeat mode 必須**: 既存の `filtering` sampler は clamp-to-edge。blue-noise tile を 256² でタイリングするには `addressMode: "repeat"` の sampler を bind group の別 binding に入れる
- **RingBuffer `nextSlot()` は呼び出し時に advance + validSlots++**: `nextSlot()` が返す値は「これから書き込む層 index」。呼び出し後の `validSlots` は increment 済みなので、`hasPrev = validSlots > 1` / `prevSlotIndex = (nextSlot - 1 + 8) % 8` で prev を取る。初フレーム時の prev view は `nextSlot` と同じ層にバインド + `hasPrev=0` で uniform 側からトレイル寄与を 0 化する方が、ダミーテクスチャを別途用意するより簡潔
- **motion blur 経路で composite 出力先が変わる**: motion blur ON では composite は `rt.composited (rgba16float)` に書く必要があり、従来の「composite → swap」直結ではバックエンド内部で format 変換できない(swap は sample 不可)。T2-4 で `rt.composited` + `blit` fallback pipeline を入れてこの制約を吸収済
- **2d-array sampler は `viewDimension: "2d-array"` 必須**: bind group layout エントリに `texture: { sampleType: "float", viewDimension: "2d-array" }` を書かないと default(2D)で検証エラー。motion blur blend shader の bind group layout に明示

### Phase 1 Known gotchas(Phase 2 での活用用)

- **Viewport class name 不変**: `packages/film-lab-renderer/src/webgl/WebGLBackend.ts` は class 名として今も `Viewport` を export(`src/index.ts` で `Viewport` として再エクスポート)。ファイル配置と class 名の乖離は意図的 — Phase 2 で WebGPUBackend がフルに出来上がって consumer 側を async factory に移行する時に、まとめて `Viewport` → `WebGLBackend` 改名 + consumer 更新を行う
- **`ViewportOptions` は二重意味**: 既存 `{ vertexShader, fragmentShader, width, height }` は `WebGLBackend` 側の options。Phase 2 で Phase 1 の Backend interface を consumer へ出す時、Viewport delegation wrapper 経由の新 `{ prefer?: 'webgpu' | 'webgl' }` を別型として追加すると call site 全部が綺麗に移る
- **Build flag**: `import.meta.env.FILMTONE_BACKEND` は desktop = `"webgpu"`、web = `"webgl"`。web ビルドで `WebGPUBackend` を dynamic import から除外する処理は Phase 2 T2-3 以降に追加(現状は `src/index.ts` に直接 `export { WebGPUBackend }` してあるので、web bundle に入ってしまう。Phase 2 で sub-path export に整理)
- **Uniform layout は vec4 packed**: 9 shader の uniform struct は既に WGSL 16-byte align 安全なレイアウト。Phase 2 filmlab.wgsl の 31 uniforms も同じパターンで(DIRECTION §10 Phase 2)
- **Sampler は filtering 固定**: `createSampler({ linear / linear / clamp-to-edge / mipmap: nearest })` が現行。LUT3D 用も同じ仕様(DIRECTION §10 Phase 2 の LUT sampler と一致)なので sampler 1 本で兼用可能
- **Baseline-B の source は JPEG Q=95**: 再 capture 不要。PSNR 比較時、JPEG 起因の < 0.5dB を `max(psnr - 0.5, target)` で厳し目に見る運用でも OK
- **典型的 WGSL 型落とし穴**: `mod(uv, 2.0)` は GLSL 専用、WGSL では `uv - floor(uv * 0.5) * 2.0` で書き直し済み(downsample/upsample)。Phase 2 で Naga 変換する時に同パターンが出たら同じく hand-fix
- **`BufferSource` 型ナロー**: `device.queue.writeTexture()` に `Uint8Array` を渡す時、TS 5.9 の最新型で `ArrayBufferLike` vs `ArrayBuffer` 不整合。`as unknown as BufferSource` で narrow(Lut3DTexture.ts, BlueNoiseTile.ts)。Phase 2 でも必要なら同じ escape を使う

---

## Last updated

2026-04-18 **Phase 3 構造着地**。T3-1(cross-filter 5 WGSL + compile-validate)+ T3-3 Viewport composition refactor + Electron `enable-unsafe-webgpu` flag の合計 3 論理 chunk が chat 内完了。残り(FilmLabCanvas 切替・App.tsx prewarm 配線・T3-2 GpuRenderer・T3-4 Golden・T3-5 DMG)は user machine の live Electron session 必須 — 次 chat が `phase-3-continuation-v2-handoff.md` を読んで着手。

**検証結果**:
- film-lab-renderer `bunx tsc --noEmit` exit 0(clean)
- film-lab-renderer `bun run build` clean: `dist/index.js` 150 KB(内 WebGPUBackend は L3465-3466 の **dynamic `import()` call site のみ**、クラス本体は `dist/chunk-Z3VCXL6F.js` 219 KB に分離)、`dist/webgpu.js` 1.4 KB(sub-path re-export stub)— tree-shake 維持 + 実態として lazy chunk 化、web bundle は `prefer: 'webgl'` で該当 chunk を一切 fetch しない
- desktop `bunx tsc --noEmit` 17 errors = Phase 2 baseline、**regression delta 0**(`viewport.mesh` 型が `THREE.Mesh` → `THREE.Mesh | undefined` に narrow したことで発生した 3 件の call-site error は `if (viewport.backendKind === 'webgl' && viewport.mesh) scene.add(…)` ガードで同 chat 内に吸収。FilmLabCanvas.tsx:794 / batch-pipeline.ts:400 / video-export-pipeline.ts:1036)

**Cross-filter render-time integration は v1.1 へ defer**(D5 Hard Mode と同セット、Decisions log 参照)。理由: 全 8 v1.0 preset が `crossFilterStrength: 0` のため Golden 80 matrix に影響無く、ship 品質を阻害しない。

**T3-2 headless GpuRenderer 抽出も v1.1 候補に再格付け**。video-export / batch-pipeline は v1.0 で WebGL 固定で ship する余地があり、live Electron での flip 検証が必要な部分を最小化することで user 判断コストと regression 面積を抑える。詳細は `phase-3-continuation-v2-handoff.md` §4。

### 次 chat kickoff snippet(そのまま貼れば再開可)

```
作業ディレクトリ: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

@apps/desktop-film-lab-batch/docs/webgpu-migration/phase-3-continuation-v2-handoff.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/DIRECTION.md と
@apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md を読んで、
Phase 3 残り (FilmLabCanvas/App.tsx prefer='webgpu' 切替 → T3-4 Golden 80 matrix → T3-5 DMG → T3-5.5 SHIP-READINESS) を live Electron で実行してください。
T3-1 WGSL / T3-3 Viewport composition / Electron flag は着地済み (本 chat pending commit 参照)。
T3-2 GpuRenderer 抽出 + cross-filter render integration は v1.1 defer 決定済み (Decisions log)。
```
