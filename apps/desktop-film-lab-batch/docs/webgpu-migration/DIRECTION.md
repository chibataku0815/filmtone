# Direction Principles — Filmtone WebGPU 移行

**全 phase chat が最初に読む。**
**Master plan**: `~/.claude/plans/sequential-thinking-gemini-web-swirling-prism.md`
**Direction chat**: 別 chat で orchestration のみ担当。実装判断はこの DIRECTION + master plan + 該当 phase handoff が正本。

---

## 1. Non-negotiable 決定事項 (D1-D5)

| # | 決定 |
|---|---|
| D1 | Three.js は完全に切る。WebGPURenderer hybrid 不採用、Pure WebGPU |
| D2 | `gpu-film-post` は **template 参照のみ**、Filmtone の依存にはしない(21 uniforms 中 4 つしか cover していないため)。brand unification は v1.2 で別パッケージ化 |
| D3 | **`Viewport` 単一クラス + `Backend` interface** で内部切替(dual class 却下)。web は build flag で WebGL-only bundle を tree-shake |
| D4 | **Linear Rec.709 + rgba16float** が working space。`clamp(0,1)` を primary grade から除去 |
| D5 | **Hard Mode cross-filter temporal は v1.1 に先送り**。v1.0 では UI グレーアウト、RELEASE_NOTES に明記。partial GL fallback は帯域コストで却下済み |

---

## 2. 色空間ルール(v1.0)

| stage | format | 備考 |
|---|---|---|
| Media texture | `rgba8unorm-srgb` | hw EOTF on sample → linear |
| 全 offscreen RT | `rgba16float` | clamp なし、HDR 値 (>1.0) 可 |
| LUT1 (Log→Linear) | 3D `rgba16float` | 入力は Log encoded (bounded)、**soft-shaper 不要** |
| LUT2 (Creative) | 3D `rgba16float` | 入力直前に **Reinhard soft-shaper 挿入**(1.0 超を [0..1] に滑らか写像) |
| Grain | `rgba8unorm` | 256×256 pre-baked **blue-noise tile**(hash 不使用) |
| Swapchain | `rgba8unorm-srgb` | hw OETF で linear → sRGB |
| Canvas context | `colorSpace: 'srgb'`, `alphaMode: 'opaque'` | P3/HDR は v1.x |

---

## 3. パイプライン順序(filmlab.wgsl、変更禁止)

```
media(sRGB→linear) → optional radial RGB shift → LUT1(Log→Linear Rec.709)
  → Exposure → Contrast → Saturation → Temperature → Tint
  → Split toning → Fade → Highlights / Shadows → Film Compression
  → [HDR 値が可能な境界]
  → Reinhard soft-shaper (LUT2 直前のみ)
  → LUT2 (Creative)
  → Print CMY cast → Print Contrast
  → (final swap blit で hw sRGB OETF)
```

`max(x, 0.0)` ガードを `pow` / `log` 前に入れる(no-clamp で負値が漏れる可能性)。

---

## 4. WGSL 移植ルール

- 全 uniform は **vec4 ベース struct** で設計(`.xyz` アクセス)。`vec3` 直指定は WGSL 16-byte alignment で silent bug
- `sampler3D` → `texture_3d<f32>` + 別 binding の `sampler`
- 非一様制御フロー内の texture sample は `textureSampleLevel(tex, samp, uv, 0.0)` 使用
- bind group は **2 group 構成**(per-frame uniforms / per-pass textures)で entry 数を抑える
- LUT / 3D texture upload は `writeTexture` の `bytesPerRow` 256-byte align + `rowsPerImage=size` を忘れない
- motion blur 8-slot ring は **単一 GPUTexture (`depthOrArrayLayers=8`)**。8 個別 texture にしない
- resize 時は ring texture 再生成 + `validSlots` uniform で未初期化スロット除外
- pipeline pre-warm を `requestIdleCallback` で行う(初回 stutter 回避)
- dev 中は `pushErrorScope('validation')` を pipeline 作成周辺に入れる

---

## 5. Tooling

- **Naga CLI** で GLSL→WGSL 初期変換(Simple/Medium shader で 60% 工数削減)
- Naga 出力は非 idiomatic、必ず hand-fix
- Simple/Medium shader を先に通してから Complex に進む
- 手変換で詰まったら `naga in.glsl out.wgsl` を先に当てて diff 比較

---

## 6. Working style (feedback memory より)

- **Terse 応答**、冗長提案は嫌われる(過去に「話にならない」と却下実績あり)
- **参照なし推測実装禁止**。既存コード・画像で裏付けしてから提案
- **装飾の積み上げ禁止**。追加には明確な改善理由が必要
- **クラフト水準**(深澤 / ラムス)を技術と同時に追う
- **Film モード ON 既定**(motion / filmtone 両方の基本層、opt-in にしない)
- 視覚的フィジビリティ限界まで押す(保守的 +1/+2 刻み NG、第一案に最大値を出す傾向)

Reference: `/Users/chibatakumi/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/`

---

## 7. Phase 運用ルール

### Phase 境界
- 各 Exit criteria 未達で次 phase に進まない
- Exit 未達時は **direction chat に戻って再計画**、ad-hoc に進めない
- Day 0 疎通失敗時は計画全体を見直す(WebGPU 路線自体の再検討)

### Git
- **自動 commit 禁止**。ユーザーが最終確認して commit/push
- Phase 論理完了時にステージング提案 → 確認取って commit 文面作成
- Co-Authored-By 必須

### Handoff 引き継ぎ
各 phase 終了時、**次 phase の `phase-N-handoff.md` を書く**:
- Entry criteria (既完了項目)
- Exit criteria (必達条件)
- Tasks (順序付き、具体的 file path つき)
- Known gotchas (今 phase 学び)
- First command in next chat

### STATUS.md 更新
- 各 phase 開始時: "in progress" 記録
- 各 phase 終了時: Exit check + 完了記録 + 次 phase ready
- direction chat がフェーズ間調整で更新することもある

---

## 8. 参考リンク

- Master plan: `~/.claude/plans/sequential-thinking-gemini-web-swirling-prism.md`
- gpu-film-post architecture reference: `/Volumes/SamsungPortableSSDX5001/documents/life/output/gpu-film-post/`
- Naga: https://github.com/gfx-rs/naga
- WebGPU implementation status: https://github.com/gpuweb/gpuweb/wiki/Implementation-Status
- 既存 film-lab-renderer: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/packages/film-lab-renderer/`

---

## 9. Escalation Matrix(判断の委譲階層)

ユーザー判断コスト最小化のため、phase chat の判断は 3 階層。**下から上に escalate**(可能な限り autonomous、strategic のみユーザーへ)。

### Autonomous(phase chat 自身が決定、escalate 不要)
- Tool バージョン選択、互換 dep 追加
- File 命名(既存パターン踏襲)
- Comment / log verbosity
- Test harness 内部実装、エラーハンドリング
- Clarity のための minor refactor
- Micro performance tuning
- WGSL idiom choice(GLSL と意味論的等価なら)
- 変数名、local refactor
- Phase scope 内の bug fix
- §10 Decision Defaults にある全項目

### Direction chat(ユーザー経由でこの chat に来る)
- Commit granularity の ambiguity
- Feature deferral 判断(shader を port するか cut するか)
- PSNR gate の near-miss(38-40dB 範囲)
- bind group layout が 2-group rule から逸脱必要
- Test fixtures が見つからない時の代替(Default で解決しない場合)
- Performance regression > 30% vs WebGL
- Handoff / DIRECTION 記載外の dep 追加
- Phase 工数 20-40% overrun
- §10 Decision Defaults で未 cover の tactical 論点

### User(strategic、稀)
- D1-D5 の変更(§1 の非妥協事項)
- Day レベルの scope 変更(Day 追加/削除)
- Release version number / ship 判断
- 色空間パラダイム変更
- 既存 preset 後方互換破壊
- Phase 工数 > 40% overrun
- Case C(WebGPU 完全非対応環境)

### Phase chat が direction chat に上げる時の書式
```
【Direction 判断要請】
- Phase: N
- 状況: (2 行)
- 選択肢: A / B / C(各 1 行)
- 現場推奨: X(1 行)
- Block 度: low / mid / high
```
ユーザーはそのまま direction chat に貼り付け → direction が即答 → user が answer を phase chat に貼り戻す。User 認知コストは「貼って貼り返す」の 2 アクション。

---

## 10. Decision Defaults(pre-decided 回答集)

phase chat が迷いやすい論点の**事前確定回答**。escalate せず即適用。

### 共通 Default
| 論点 | Default | 理由 |
|---|---|---|
| Typecheck 失敗 | Exit 前に必ず clean。`bun run typecheck` 通らないまま次 phase NG | 品質担保 |
| Lint 違反 | 既存設定に従う、新規 warning 増やさない | |
| Playwright 不具合 | `playwright-electron` 詰まったら `child_process.spawn` + CDP 接続に切替 | Phase 0 gotcha |
| Golden PNG 総計 ≥ 50MB | JPEG Q=95 に変換、200MB 超なら direction chat | repo bloat |
| Naga 出力バグ | 該当 shader だけ hand-translate、`// naga-workaround: ...` コメント | |
| Dep 追加(handoff 外) | 実装必要かつ reasonable なら autonomous、メジャー追加は direction chat | |
| 単一 visual regression(80 中 1 件) | accept、note に理由記録、proceed | |
| 2+ regression | direction chat へ | |
| Shader perf WGSL < GLSL | accept for v1.0、`// TODO(v1.1): profile` タグ | 品質優先 |
| DPR | canvas は device DPR のまま、test harness は 1.0 固定 | PSNR 再現性 |
| VideoFrame API 未サポート | HTMLVideoElement + `copyExternalImageToTexture` フォールバック | |
| Task 工数 20% overrun | STATUS.md に記録して継続 | proactive signal |
| Task 工数 40% overrun | direction chat へ | blocking signal |

### Phase 0 専用
| 論点 | Default |
|---|---|
| T1 実施方法 | 手動 DevTools、adapter-info.json 手書き(Option 3 ハイブリッド) |
| T2 Playwright 失敗 | spawn + CDP 方式に切替 |
| Preset 選定 | film-lab-core 内 preset の**先頭 8 種**を default |
| テスト画像 | 手元 sample / film-lab-core fixtures。無ければ 10 色 gradient + 2 synthetic HDR パッチで代替(20 分以内で確定) |
| Commit 単位 | Case A → 1 commit、Case B → 2 commit(main.ts flag と infra 分離) |

### Phase 1 専用
| 論点 | Default |
|---|---|
| Simple shader migration order | vert → bloom-prefilter → halation-prefilter → downsample → upsample → lightshafts → lightshafts-blend → dust(8 本、vert 含め 9) |
| WebGL backend 退避 | `git mv` で `src/Viewport.ts` / `src/shaders/` → `src/webgl/` 配下、別 commit |
| `isWebGPUSupported()` API | `async function isWebGPUSupported(): Promise<boolean>`、初回 adapter 取得結果をメモ化 |
| Backend interface export | `index.ts` に types export、public API として扱う |
| Web tree-shake | Vite の `import.meta.env.FILMTONE_BACKEND` build flag、`WebGPUBackend` は dynamic import |
| LUT3D 初期テスト | identity LUT(33³ linear)で pipeline 通してから実 .cube データ |
| Baseline B 生成式 | `x' = x * (1 + 0.08 * smoothstep(0.92, 1.0, x))` で highlight だけ緩い un-clamp |
| Golden harness runner | 既存 vitest の custom integration として追加(`describe('golden', ...)`) |
| Blue-noise tile 生成 | void-and-cluster 既成ライブラリ or 生成 script + checked-in PNG。毎回生成しない |

### Phase 2 専用
| 論点 | Default |
|---|---|
| filmlab.wgsl 分割 commit | primary grade(9 ops)を先に commit → soft-shaper + LUT2 + print を次 commit |
| 31 uniforms struct | all vec4 packed、TS types は codegen 無しなら手書き + runtime 検証 |
| LUT sampler | `addressMode: 'clamp-to-edge'`, `magFilter: 'linear'`, `minFilter: 'linear'`, `mipmapFilter: 'nearest'` |
| Soft-shaper 係数 | Reinhard `x/(x+k)` で `k=0.5` 固定(v1.0 では UI knob 追加しない) |
| Composite bind group | group0=uniforms, group1=textures×4 + sampler×1 |
| Motion blur ring usage | `RENDER_ATTACHMENT | COPY_SRC | TEXTURE_BINDING` |
| Motion blur 初期 frame | `validSlots` uniform を 1 から開始、frame 毎に `min(slots+1, 8)` |
| PSNR near-miss (38-40dB) | 一度 investigate: linear pipeline 起因なら accept + note、計算ミスなら修正 |
| `max(x, 0.0)` ガード | `pow(x, n)` / `log(x)` / `sqrt(x)` の直前に必ず入れる |

### Phase 3 専用
| 論点 | Default |
|---|---|
| Cross-filter 5 shader 順 | peak → peak-spacing → peak-spacing-max → streak → blend。**streak-density は SKIP**(exploration で unused 確認済) |
| Hard Mode UI | 設定画面でグレーアウト + "v1.1" バッジ、直接操作不可 |
| Video export 色変換 | rgba16float → tone-mapped rgba8unorm buffer → nv12(ffmpeg filter `format=nv12`)、shader は filmlab.wgsl と同一経路 |
| ffmpeg codec | 既存 batch-pipeline のまま変更しない |
| DMG signing | `dist:mac:unsigned` を Day 3 QA 用、signed は public release 時(別作業) |
| RELEASE_NOTES | 既存 `RELEASE_NOTES-v0.*.md` 書式踏襲、v1.0 headline = "WebGPU migration" |
| Pipeline pre-warm UX | 150ms 未満は silent、以上は "Preparing renderer…" overlay、300ms 以上でフェードアウト |
| Web bundle | build flag で WebGPUBackend を dynamic import、tree-shake 成功を vite build log で確認 |
| isWebGPUSupported in apps/web | build flag で常に false(web は WebGL 固定) |

---

## 11. User Interaction Budget

**Target**: ≤ **8 user messages** through the 38h sprint。

### 必須 interaction(6 回想定)
1. Phase 0 start 合図(1 msg)
2. Phase 0 完了 → commit 確認 + Phase 1 GO(1 msg)
3. Phase 1 完了 → commit 確認 + Phase 2 GO(1 msg)
4. Phase 2 完了 → commit 確認 + Phase 3 GO(1 msg)
5. Phase 3 完了 → commit 確認 + 最終 QA(1 msg)
6. v1.0 ship 判断(signed DMG / release notes 確認)(1 msg)

### 予備(2 回バッファ)
Strategic escalation のため温存。

### Phase 完了報告書式(phase chat → user)
各 phase 終了時、以下の 1 パラグラフだけユーザーに出す:
```
Phase N 完了。{主要 deliverable 1-2 行}。Exit criteria {n/n}達成。
Regression {あり/なし、あれば概要}。
commit 案: "{commit msg 1 行}"
OK なら次 phase(N+1)に移ります。
```

### Proactive risk signaling
Phase chat は以下を常に STATUS.md に append:
- Task 工数 20%+ overrun → Progress Notes に記録して継続
- 視覚 regression 発生 → Regressions ログに追加
- Dep 追加 → Decisions log に追加
- §10 Default 適用結果の違和感 → Notes に記録

User はこれを能動的に読みに行かなくてよい。Phase 完了時に phase chat が集約報告する。
