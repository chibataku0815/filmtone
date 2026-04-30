# Filmtone iOS — Look Tonal Identity V2 Handoff (2026-04-30 JST)

**作成日**: 2026-04-30 JST  
**作成チャット**: Claude Code (Opus 4.7 1M)  
**次チャット**: 新規セッション(reference 写真を CD = ユーザーが共有して再設計)  
**状態**: 作業中・**未 commit**・v2 実装は **品質不十分** につき再設計が必要

---

## 0. このドキュメントを読む人へ (TL;DR)

- v1.4 lane で **Built-in 4 Look (Filmtone Signature / Soft Blue / Amber Glow / Night Soft) の階調 identity 強化** を狙った
- presetVersion v1→v2 の dual-kernel dispatch **scaffold は完成**(キープ)
- しかし投入した kernel math と preset 値は **「Filmtone らしさ」を表現できていない**(美的失敗)
- **新規チャットで CD が reference 写真 4 枚を提示**し、それに近づけるよう v2 を再設計する
- このドキュメントは scaffold 構造・前提・失敗の根本原因・次手の候補を完全に引き継ぐためのもの

---

## 1. 経緯と Context

### 1.1 v1.4 lane の発端

元々は `docs/guides/2026-04-30-filmtone-ios-creative-lut-export-feasibility-handoff.md` の **Look→.cube export feasibility** が v1.4 候補だった。これを essence-only で plan 化した直後、CD (= ユーザー) からの方向転換 feedback:

> プリセットの階調パラメーターが保守的すぎる、階調を使ったルックは Filmtone 独特風合いを出せるためその機能強調する  
> 一方で強めにかけても破綻しにくいようなフィルムでいう圧縮効果を考える  
> 一方でレンズフィルター効果による意図した光の広がり表現の白飛びは許容する

→ **「LUT 化する前に、転写元の Look 自体を Filmtone らしく強化する」** が v1.4 の本質。LUT export は v1.4.x or v1.5 に defer 確定。

### 1.2 user 確認済みの scope decision

AskUserQuestion 4 件の回答 (この chat 中):

| 項目 | 決定 |
|------|------|
| 対象 Look | **Built-in 4: Filmtone Signature / Soft Blue / Amber Glow / Night Soft** (Clean Base = 触らない) |
| 「破綻しない」の意味 | **4 つ全部** — Highlight roll-off / Shadow lift cleanliness / Saturation soft clip / Mid-tone S-curve compression / フィルム調かつ個性 |
| v1.4 順序 | **Look tuning を v1.4、LUT export は v1.4.x or v1.5** |

### 1.3 設計方針 (確定済 — 次チャットも維持)

- presetVersion **v1 → v2** に bump (iOS-only `IOS_PRESET_VERSION` を導入、shared `PRESET_VERSION` は v1 のまま)
- v1 / v2 dual kernel dispatch (`applyBaseGradeStage` / `applyToneCompressionStage`)
- v1 user-saved Look は v1 kernel で render → backward compat 維持
- v1 kernel は verbatim 保存(削除しない)
- Built-in catalog の canonical UUID `FB1A...` namespace は維持(中身だけ更新)

---

## 2. このチャットでやったこと

### 2.1 Phase A — kernel additions (additive only)

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift:2890-2954` に追加:

- `OpticalKernels.baseGradeV2` (新規 CIColorKernel)
  - Linear contrast → **Reinhard 形 soft S-curve** (`y = 0.5 + d * (1+s) / (1 + s|d|*2)`)
  - Saturation → **両側 Reinhard soft-clip** (output ∈ [0, 1] strict bound)
  - Fade → **shadow-weighted mask** (`smoothstep(0, 0.55)` で highlight を半分にする)
- `OpticalKernels.filmCompressionV2` (新規 CIColorKernel)
  - smoothstep knee 0.82 → **0.65** (wider)
  - Per-channel quadratic highlight rolloff (`luma > 0.7` で発動)

### 2.2 Phase A — numeric clipping probe

`apps/capacitor-film-lab-ios/scripts/swift/test-baseGrade-v2-clipping.swift` (新規):
- 7 probes (grayscale ramp / saturation stress / fade chromatic / contrast monotonicity / filmComp range / identity / amount=0 passthrough)
- `bun run verify:baseGrade-v2` (package.json:11 に追加)
- **全 7 probes green**

### 2.3 Phase B — dispatch wiring

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`:
- `applyGrade` (line ~1197): `request.grade.presetVersion` を `applyBaseGradeStage` / `applyToneCompressionStage` に渡す
- `applyBaseGradeStage` (line 1251): `presetVersion` で `baseGradeV2` / `baseGrade` を switch
- `applyToneCompressionStage` (line 1289): 同形 switch (`filmCompressionV2` / `filmCompression`)
- 未知 version は `assertionFailure` (DEBUG fail / RELEASE fall-through to most-recent)

### 2.4 Phase C — preset version bump + value updates

generator pipeline:
- `packages/film-lab-core/src/look-ids.ts`: 新規 `IOS_PRESET_VERSION = "v2"` (shared `PRESET_VERSION = "v1"` は維持)
- `packages/film-lab-core/src/ios-swift-payload.ts:88`: `IOS_PRESET_VERSION` を使う
- `packages/film-lab-core/src/ios-preset-overrides.ts`: iphone / softBlue / amberGlow の 12 param を更新
- `packages/film-lab-core/src/ios-swift-payload.test.ts`: EXPECTED 3 envelope を更新
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift:94-99`: Night Soft override を更新
- `bun run scripts/generate-filmtone-ios-swift.ts` で `FilmtonePhase0Generated.swift` 再生成 (presetVersion = "v2" へ)

### 2.5 Phase C — fixture / test bumps

- 4 phase0-contract fixtures `"v1"` → `"v2"` (`scripts/fixtures/phase0-contract/*.json`)
- `scripts/swift/test-sidecar-builder.swift:136` 期待値 `"v1"` → `"v2"` 1 箇所だけ

### 2.6 Phase D — visual a/b 検証 (failure)

実写真 3 枚 (img_1 / img_4 / img_8 from `apps/example01/public/`) × 4 Look = **12 a/b** を `/tmp/filmtone-real-render/` に生成。
CD review 結果: **「全てダメです 質が低すぎます」**。

---

## 3. なぜ品質が低かったか — 6 つの根本失敗

### 3.1 数学的解と美的解を混同した

評価軸を **数値が clip しないこと / monotonic / bounded** に置いた。しかし要求は **「Filmtone 独特の風合い」** であり、数値の振る舞いではなく **見た目が film stock らしいかどうか** という美的判断。

`output ≤ 1.0` を strict 担保しても、それは「フィルムらしく見える」を一切担保しない。

### 3.2 「破綻しない」の数値定義での取り違え

| 解釈 | 評価 |
|------|------|
| ❌ 私の解釈 | `output ∈ [0, 1]` (数値の境界条件) |
| ✅ 正しい解釈 | 強い設定でも **見た目が破綻しない** (banding なし / muddy なし / artificial に見えない) |

数値で bound しても見た目の品質は別問題。

### 3.3 Filmtone identity を一度も visualize していない

- 実装前に **「各 Look が target とする film stock は何か」** を一度も問わなかった
- Reference 画像なし、film stock セマンティクスなし、aesthetic anchor なしで kernel を書き始めた
- 結果: ジェネリックな Reinhard tonemapping (HDR 用 / ゲーム業界由来) を Filmtone identity に擬態させた

### 3.4 Reinhard S-curve はフィルム curve ではない

`y = 0.5 + d * (1+s) / (1 + s|d|*2)` は HDR tone mapping 用。実フィルムの濃度曲線は:
- **toe (足) + linear + shoulder (肩)** の 3 段
- stock 別に curve 形が visibly 異なる (Vision3 / Portra / Velvia は別物)
- Density-dependent な 色 crosstalk (highlights warm shift / shadows cool shift など stock 固有)

私の Reinhard は全 Look 共通で、film stock の **個性を一切持たない**。

### 3.5 Shadow lift が white-lift で muddy になっている

私の v2 fade: `rgb + fade * (1 - rgb)` を shadow mask で重み付け。これは **白に向かって持ち上げる** = neutral white に向かって lift。

実フィルムの shadow:
- Vision3: cool cyan-blue 寄りに lift
- Portra: わずかに magenta-rose 寄り
- Cinestill: cyan に強く lift + halation
- 共通点: shadow に **色がある**

私の実装: shadow が neutral white に lift → 単に **濁る (muddy)**。「フィルムらしい霞」と表現したが、実態は「lifted blacks」digital preset。

### 3.6 spatial stage を一切触っていない

ユーザー: 「レンズフィルター効果による白飛びは許容」(つまり halation/bloom を強めたい)  
私: Night Soft だけ halation 0.04→0.08 で他は変えず。Filmtone Signature の halation 0.018 / bloom 0.16 は **そのまま**。

実 film の "signature character" は **空間効果** (halation の warm glow / bloom の soft falloff / diffusion の atmosphere) に強く宿る。tonal stage だけで signature character を作ろうとしたのが誤り。

### 3.7 (補) preset 値変更が arbitrary

`contrast 1.03 → 1.12`, `compressionAmount 0 → 0.35`, `printContrast 0 → 0.10` …
- なぜ 1.12? なぜ 0.35? — **根拠なし**
- 「もっと strong に」と言われたから increase しただけ
- Reference frame と比較して「近づいた」という確認をしていない

---

## 4. 現状のコード変更まとめ (どこまで未 commit)

```
M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift          (Night Soft override 値変更)
M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift          (kernel 追加 + dispatch wiring)
M apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift        (generator output: presetVersion=v2 + new values)
M apps/capacitor-film-lab-ios/package.json                                     (verify:baseGrade-v2 npm script)
M apps/capacitor-film-lab-ios/scripts/fixtures/phase0-contract/*.json (×4)    (presetVersion v1→v2)
M apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift        (期待値 v1→v2 1 箇所)
M packages/film-lab-core/src/ios-preset-overrides.ts                          (iphone/softBlue/amberGlow 値更新)
M packages/film-lab-core/src/ios-swift-payload.test.ts                        (EXPECTED 3 envelope 更新)
M packages/film-lab-core/src/ios-swift-payload.ts                             (PRESET_VERSION → IOS_PRESET_VERSION)
M packages/film-lab-core/src/look-ids.ts                                      (IOS_PRESET_VERSION 追加)
?? apps/capacitor-film-lab-ios/scripts/swift/test-baseGrade-v2-clipping.swift (新規 numeric probe)
```

すべて未 commit。`git status` で確認可。

---

## 5. 何を残し、何を捨てるか — Scaffold 残/Math 捨て

### 5.1 残す (scaffold — 構造として正しい)

| 項目 | 場所 | 理由 |
|------|------|------|
| `IOS_PRESET_VERSION = "v2"` 変数 | `packages/film-lab-core/src/look-ids.ts` | 共有 PRESET_VERSION との decoupling は正解(desktop/web Look ID を破壊しない) |
| `presetVersion` based dual-kernel dispatch | `FilmtoneExportSession.swift:1251 / 1289` | v1 user-saved Look の backward compat ガードは外せない |
| `applyGrade` で `request.grade.presetVersion` を渡す経路 | `FilmtoneExportSession.swift:1197` | v2 への param 受け渡しのため必要 |
| `OpticalKernels.baseGradeV2` / `filmCompressionV2` の **shell** | `FilmtoneExportSession.swift:2890-2954` | kernel 本体の math は再設計だが、shell は使う |
| `verify:baseGrade-v2` npm script + clipping probe harness | `package.json:11` + `scripts/swift/test-baseGrade-v2-clipping.swift` | 数値の境界条件 gate としては有効(美的解とは別だが、numerical regression 防御として残す) |
| Phase 0 contract fixtures `presetVersion: "v2"` | `scripts/fixtures/phase0-contract/*.json` | runtime 定数と一致させる必要 |
| `test-sidecar-builder.swift:136` の `"v2"` 期待値 | 同上 | runtime と整合 |
| Generator pipeline (`scripts/generate-filmtone-ios-swift.ts`) の動作 | `scripts/generate-filmtone-ios-swift.ts` | iOS 用 swift payload 生成は正常に動いている |

### 5.2 捨てる (再設計が必要)

| 項目 | 現状の問題 | 再設計の方針 |
|------|-----------|-------------|
| `baseGradeV2` の math 本体 | Reinhard ジェネリック、film stock 個性なし | Reference 写真の film stock を特定 → toe+linear+shoulder + density-dependent crosstalk を実装 |
| `filmCompressionV2` の math 本体 | luma sigmoid + quadratic shoulder = digital tonemapping | Stock 別の film density curve を実装 |
| 4 Look の preset 値 (iphone / softBlue / amberGlow + Night Soft override) | Arbitrary な値変更、reference 比較なし | Reference 写真に近づくまで CD review で iterate |
| Spatial stage (halation / bloom / diffusion) パラメータ | Filmtone Signature は触っていない | Look ごとに film stock 由来の glow 表現を追加 (光の広がり = lens-filter blow-out OK の実装) |

---

## 6. 次チャット用 — 推奨アプローチ

### 6.1 入力 (CD = ユーザーが提供)

- **4 reference 写真**: 各 Look (Filmtone Signature / Soft Blue / Amber Glow / Night Soft) の **理想形**
- 「これに近づけて」が次チャットの北極星

### 6.2 推奨ワークフロー

```
[step 1] CD から reference 写真 4 枚を受領、ファイル path を確定
[step 2] 各 reference を Read で view → film stock を推定 (Portra / Vision3 / Cinestill / Gold200 / Cinematic 等)
[step 3] reference の特徴を言語化:
        - Highlight rolloff の硬軟
        - Shadow の color (cyan / magenta / neutral)
        - Saturation の傾向 (highlight vs shadow で異なる?)
        - Mid-tone の contrast 形 (S-curve / linear / log)
        - Halation / bloom の有無と warmth
        - Grain texture
[step 4] desktop/Remotion の `packages/film-lab-core/src/presets.ts` の同名/類似 stock の値を reference として参照
        - portra (line 190+), gold200 (246+), cinestill800t (526+), cinematic (134+) etc.
        - 既に density-dependent な値が組まれている可能性大
[step 5] 各 Look ごとに kernel 設計判断:
        - Option X: 単一 baseGradeV2 を parametric にする (curve shape param 追加)
        - Option Y: 各 Look 別 kernel (`baseGradeFilmtoneSignatureV2` / `baseGradeSoftBlueV2` ...) — 純度高だが file 増
        - Option Z: 単一 kernel + preset 値だけで差別化(現状) — limiting だが simple
[step 6] kernel 再実装 → preset 値再決定 → 同じ reference 写真で v2 render
[step 7] CD review iterate (visual a/b、reference に近づいたか)
[step 8] 全 4 Look で reference に近づいた確認後 commit
```

### 6.3 reference として読むべき既存資産

| 場所 | 内容 |
|------|------|
| `packages/film-lab-core/src/presets.ts` | 10 種の film stock preset (cinematic / portra / gold200 / pro400h / bw / ektar100 / superia400 / cinestill800t / velvia50 / reset)。 各 stock 用の compressionAmount / printContrast / cyan/magenta/yellow / fade / shadow & highlight tone & hue 等が既に値を持つ |
| `packages/film-lab-core/src/phase0-schema.ts` | Phase0Params の正本 schema |
| `apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/` | V-Log/S-Log3 fixture 構造 (color science の template) |
| `apps/remotion-film-lab/` | Desktop/Remotion 側の film lab 実装 — kernel は別だが logic は参考になる |
| `apps/edit-movie/footage/` (`/Volumes/SamsungPortableSSDX5001/documents/edit-movie/`) | 実footage、CD のリアル写真素材 |

### 6.4 Filmtone iOS は desktop と何が違うか

iOS は **subset preset** (iphone / softBlue / amberGlow / reset) で desktop の 10 stock とは別ライン。  
ただし **base preset の Phase0Params shape は同じ** (`mergePhase0Params` で desktop CONTRACT_DEFAULTS を踏襲)。  
→ desktop の portra/gold200/cinestill800t の値を **iOS の Filmtone Signature / Amber Glow / Night Soft の reference として転用可能**。

### 6.5 失敗回避チェックリスト (必読)

- [ ] **Reference 画像なしで kernel 書かない** — まず CD reference を view すること
- [ ] **Reinhard / 単純 sigmoid を「film curve」と呼ばない** — film は stock-specific
- [ ] **Shadow lift で white に向けない** — 必ず color (cyan / magenta / 等) を持たせる
- [ ] **「output ∈ [0,1]」を「破綻しない」と読み替えない** — それは数値境界の話、見た目の話ではない
- [ ] **Halation / bloom / diffusion を最初から設計対象に含める** — Filmtone signature は spatial に宿る
- [ ] **preset 値を bump 前に reference render → CD review → 値決定の順で進める** — arbitrary な値 increment 禁止
- [ ] **作業前に「この Look の film stock target は何?」を必ず CD に確認**

---

## 7. Codebase ground truth (validated, 不変)

| 項目 | 値 / 場所 |
|------|----------|
| `applyGrade` 9-stage 順序 | `FilmtoneExportSession.swift:1197-1212` (input LUT / baseGrade / filmCompression / edge / glow / vignette / grain / creative LUT / printStage) |
| `OpticalKernels.baseGrade` (v1) | `FilmtoneExportSession.swift:2873-2888` (verbatim 残す) |
| `OpticalKernels.filmCompression` (v1) | 2890-2907 (verbatim 残す) |
| `OpticalKernels.printStage` (v1) | 2929-2948 (v2 不要) |
| `OpticalKernels.baseGradeV2` (v2 — 再設計対象) | 2890-2916 |
| `OpticalKernels.filmCompressionV2` (v2 — 再設計対象) | 2934-2954 |
| dispatch site (baseGrade) | `FilmtoneExportSession.swift:1251` |
| dispatch site (filmCompression) | 1289 |
| `applyGrade` で presetVersion を渡す site | 1198, 1203, 1204 |
| `Phase0GradeDTO.presetVersion: String` | `FilmtoneMediaTypes.swift:321-326` (DTO 経路で運ばれる) |
| `Phase0ParamsDTO` (presetVersion なし) | `FilmtoneMediaTypes.swift:274-306` |
| `SavedLookEntry.presetVersion: String` | `FilmtoneLibrarySchema.swift:128-160` (saved Look の version stamp) |
| `FilmtonePhase0Generated.presetVersion` | 現在 `"v2"` (再生成済) |
| `IOS_PRESET_VERSION` | `packages/film-lab-core/src/look-ids.ts` 新規追加 = `"v2"` |
| `PRESET_VERSION` (shared) | 同上、`"v1"` 維持(desktop Look ID は無傷) |
| iOS preset 値の source-of-truth | `packages/film-lab-core/src/ios-preset-overrides.ts` |
| Generator | `scripts/generate-filmtone-ios-swift.ts` (`bun run scripts/generate-filmtone-ios-swift.ts`) |
| Built-in Look catalog (UUID FB1A...) | `FilmtoneBuiltInCatalog.swift:42-102` (UUID 不変) |
| Sidecar V1 schemaVersion | `FilmtoneExportSidecarBuilder.swift:226` 不変 |
| Sidecar 8 KB cap | `scripts/swift/test-sidecar-builder.swift:79-82` |
| Phase 0 contract gate | `bun run verify:swift-contract` (`./scripts/verify-phase0-contract.sh`) |
| V-Log/S-Log3 accuracy | `Tests/Fixtures/source-profile/` `max = 0.000` 維持 |
| Snapshot 端末 | iPhone 17 Pro Max iOS 26.2 UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192` |

---

## 8. Verification gates (絶対 green を維持)

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios

# Phase 0 contract gate (V-Log/S-Log3 max=0.000、sidecar、cube parser、cache、ray-angle 全て)
bun run verify:swift-contract

# v2 numeric clipping probe (kernel が数値的に bounded か)
bun run verify:baseGrade-v2

# iOS 用 generated payload sync (test ファイル)
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
bun test packages/film-lab-core/src/ios-swift-payload.test.ts

# iOS web-side phase0 contract test
bun test apps/capacitor-film-lab-ios/src/lib/phase0-state.test.ts

# Build (Debug, generic simulator)
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

5 件全 green であることが next chat 着手の前提。

---

## 9. 不変条件 reminder (CLAUDE.md §5 / §13 由来)

- `Profile.version = 4` 触らない (schema 変更しない)
- Sidecar V1 `schemaVersion = 1` 触らない
- `OpticalKernels.baseGrade` (v1) verbatim 維持
- `OpticalKernels.filmCompression` (v1) verbatim 維持
- Built-in Look canonical UUID `FB1A...` namespace 維持(中身更新のみ)
- preset names locked (`["reset", "iphone", "softBlue", "amberGlow"]`)
- `FilmtonePhase0Generated.swift` 手動編集禁止 (generator 経由のみ)
- silent fallback 禁止 (CLAUDE.md §11 `feedback_no_fallback_bug_hotbed`)
- Vocabulary gate: JP `短尺動画` 禁止 / EN `short-form video` 禁止
- 既存 untracked 4 docs (`docs/filmtone/ios/filmtone-connect-davinci-*` 3 件 + `docs/guides/2026-04-30-filmtone-ios-v1.3-release-rail-resume-handoff.md`) は触らない
- DaVinci spike worktree (`feature/filmtone-davinci-connect-package`) のコードに依存しない

---

## 10. (重要) 次チャットへの最高精度引き継ぎプロンプト

新規チャットの最初に **そのまま貼る**:

````markdown
## Filmtone iOS v1.4 Look Tonal Identity V2 — 引き継ぎ

**前チャット handoff doc**: `docs/guides/2026-04-30-filmtone-ios-look-tonal-identity-v2-handoff.md`

このタスクは Filmtone iOS の Built-in 4 Look (Filmtone Signature / Soft Blue / Amber Glow / Night Soft) の階調 identity を強化する作業の **再設計** フェーズです。

### 前提 (handoff doc §0-1 を参照)
- v1.4 lane = Look tuning (LUT export は v1.4.x or v1.5 へ defer)
- 対象 Look: Built-in 4 (Clean Base = 触らない)
- presetVersion v1→v2 dual-kernel dispatch の **scaffold は完成済**
- 私 (前チャット) が投入した v2 kernel math と preset 値は **「Filmtone らしさ」を表現できておらず再設計が必要**

### 前チャットの失敗 (handoff doc §3 を参照、繰り返さないこと)
1. 数値解と美的解を混同 (output ≤ 1.0 を「破綻しない」と取り違えた)
2. Reference 画像なしで kernel を書き始めた (aesthetic anchor なし)
3. ジェネリック Reinhard を「film curve」と呼んだ (実 film は stock-specific)
4. Shadow lift で neutral white に向けた (実 film shadow は **色** がある)
5. Spatial stage (halation/bloom/diffusion) を一切触らなかった
6. preset 値を arbitrary に bump した (reference 比較なし)

### あなた (新チャット) のタスク

CD = ユーザー が **4 Look それぞれの reference (理想) 写真** を共有するので、それに近づくよう v2 を再設計する。

#### Step-by-step

1. CD reference 写真 4 枚を受領 (path 確定)
2. 各 reference を `Read` で view → film stock 推定 (Portra / Vision3 / Cinestill / Gold200 / Cinematic 等)
3. 各 Look の特徴を言語化 (highlight rolloff / shadow color / saturation 傾向 / mid-tone curve / halation / grain)
4. `packages/film-lab-core/src/presets.ts` の対応する film stock 値を参照 (cinematic / portra / gold200 / cinestill800t etc. 既に density-dependent な値あり)
5. 各 Look ごとに kernel 設計判断 (handoff doc §6.2 の Option X/Y/Z を CD と相談):
   - X: 単一 baseGradeV2 を parametric 化(curve shape param 追加)
   - Y: 各 Look 別 kernel (例: `baseGradeFilmtoneSignatureV2`)
   - Z: 単一 kernel + preset 値だけで差別化(現状の構造)
6. kernel 再実装 + preset 値再決定 + spatial stage パラメータ調整 (Filmtone signature の halation/bloom も対象)
7. 同じ reference 写真で v2 render → CD review → 値・math iterate
8. 全 4 Look で reference に近づいた合意 → commit

#### 強い制約 (絶対遵守)

- ❌ Reference 画像 view 前に kernel に手を入れない
- ❌ 「output ∈ [0,1]」を「破綻しない」と読み替えない (それは数値境界、見た目の話ではない)
- ❌ Reinhard / 単純 sigmoid を「film curve」と呼んで使わない
- ❌ Shadow lift で neutral white に向けない (cyan / magenta / 等で **色** を持たせる)
- ❌ Halation / bloom / diffusion を「tonal が違うから別」と切り捨てない (Filmtone signature は spatial に宿る)
- ❌ preset 値を arbitrary に increment しない (必ず reference 比較で根拠付け)
- ❌ `OpticalKernels.baseGrade` (v1) / `filmCompression` (v1) verbatim 維持 — 削除禁止
- ❌ Built-in Look canonical UUID `FB1A...` 維持
- ❌ `FilmtonePhase0Generated.swift` 手動編集禁止 (generator 経由)
- ❌ 共有 `PRESET_VERSION` 触らない (`IOS_PRESET_VERSION` で iOS 専用)
- ❌ silent fallback 入れない (CLAUDE.md §11)
- ❌ user 承認なしに commit しない

#### 強い指針 (積極遵守)

- ✅ CD reference 写真を最初に Read で view
- ✅ 各 Look の film stock target を CD と最初に確認
- ✅ desktop の `packages/film-lab-core/src/presets.ts` を reference として深く読む
- ✅ kernel 再実装は film stock semantics (toe+linear+shoulder + density-dependent crosstalk) を反映
- ✅ Halation / bloom 値も Filmtone Signature を含めて見直す
- ✅ 各 iteration で render → CD review → 数値 nudge → 再 render の **目視 close-the-loop**
- ✅ Verification gates 全 5 件 green を必ず維持 (handoff doc §8)

#### 既存ツール

- v2 a/b render harness: `/tmp/render-v2-real.swift` (前チャットが書いた、再利用可)
- numeric clipping probe: `bun run verify:baseGrade-v2` (再利用、必要に応じて拡張)

#### 完了基準

- 4 Look 全部で CD review 合意「reference に近づいた」
- Verification gates 5 件 green
- v1 user-saved Look が v1 kernel で render され続ける (backward compat 維持)
- commit + push 段取りは CD 承認後

handoff doc を最初に通読してから着手してください (§5 で何を残し何を捨てるかを必ず確認)。
````

---

## 11. 関連 doc references

- `docs/guides/2026-04-30-filmtone-ios-creative-lut-export-feasibility-handoff.md` — original feasibility (LUT export は v1.4.x/v1.5 で再開)
- `docs/filmtone/ios/filmtone-connect-davinci-overall-plan-2026-04-30-jst.md` — v1.5+ 全体計画
- `apps/capacitor-film-lab-ios/CLAUDE.md` §1 運用原則 / §5 不変条件 / §13 Built-in Catalog
- `packages/film-lab-core/src/presets.ts` — 10 film stock の Phase0 params (新チャットの reference)
- `packages/film-lab-core/src/look-ids.ts` — `IOS_PRESET_VERSION` 追加済み
- `apps/capacitor-film-lab-ios/RELEASE.md` — release rail

---

## 12. 履歴

- 2026-04-30 JST: 前チャットで scaffold 完成、kernel/値投入 → CD レビューで quality 不十分判定 → handoff 作成
- next: 新チャットで CD reference 写真 4 枚を受領 → kernel/値再設計 → CD review iterate

---

## 13. 一行サマリー

> **「Filmtone らしさ」は数値で出ない、reference 写真と film stock 知識を起点に kernel を再設計する。**
