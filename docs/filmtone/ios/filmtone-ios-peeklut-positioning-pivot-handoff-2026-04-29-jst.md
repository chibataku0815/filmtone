# Filmtone iOS — PeekLut 競合分析と "Pro Tool 連携" へのポジショニング転換

- **作成日**: 2026-04-29 (JST)
- **対象**: Filmtone iOS v1.2 → v1.3 以降の戦略方針
- **CD 判断**: 機能パリティを追わない。DaVinci / Adobe との連携を磨く方向に転換
- **関連 doc**:
  - `filmtone-ios-v12-release-to-aso-handoff-2026-04-29-jst.md`（v1.2 出荷）
  - `filmtone-ios-parity-gap-vs-desktop-v1.0.3-2026-04-24-jst.md`（Desktop 比）
  - `apps/capacitor-film-lab-ios/CLAUDE.md`（運用原則）

---

## 1. 背景

PeekLut（Lauper Labs）が App Store 上で iPhone / iPad の「DaVinci Resolve 代替」を取りに来ている。Filmtone iOS は副業 6 週で v1.2 を ASC に提出済。両者を機能数で比較すると **73〜83% 機能負け**。本書では機能負けの定量化と、それを **追わない方向に振る** 戦略判断を記録する。

### 1.1 開発工数の前提

| 項目 | 値 |
|------|-----|
| Filmtone iOS 単体 | 副業レベル **約 2 週間** |
| Filmtone iOS + Desktop | 副業レベル **約 6 週間** |
| PeekLut | フルタイム想定で **12 ヶ月（24 リリース）** |
| 工数比 | 概算 **30〜100 倍**（人月換算） |

---

## 2. PeekLut の輪郭

| 項目 | 値 |
|------|-----|
| 開発元 | Lauper Labs |
| 価格 | Free + IAP（¥200/週 〜 ¥3,000/年 〜 PeekPro Long ¥15,000） |
| 評価 | 4.7★ / 294 レビュー |
| 現行 | v2.18.0（2026-04-29 時点で 12 時間前更新） |
| リリース速度 | 直近 12 ヶ月で **24 リリース・平均 14.5 日サイクル** |
| ターゲット | Reels / TikTok / YouTube クリエイター、出先のカラリスト、"DaVinci のモバイル版" を求めるユーザー |
| 訴求軸 | 「プロ品質、学習曲線ゼロ」「DaVinci Resolve に匹敵」 |

### 2.1 機能ロードマップ要約

| 期間 | 入れた機能 | 戦略意図 |
|------|----------|---------|
| 25/07–08 (v2.0–2.3) | 新 rendering engine, **画像マスク, トーンカーブ, JPEG/PNG/HEIC/TIFF, B/A スライダー** | プロ寄り基本セット完成 |
| 25/09 (v2.4–2.5) | 肌・空 rendering 改善, Liquid Glass | iOS 26 適合 |
| 25/11–12 (v2.6–2.9) | **バッチ編集, HDR, ProRes 422/4444, ハレーション color picker** | プロワークフロー |
| 26/01 (v2.10–2.11) | Technicolor 3-strip, チャンネル別 saturation, LUT layering | ビンテージ層 |
| 26/02 (v2.12–2.13) | **Crop tools, Auto Crop, LUT folder sync, ヒストグラム** | パワーユーザー化 |
| 26/03 (v2.14–2.15) | **メタデータ保持, Apple Log, 色収差, レンズ歪み, Film Filter Tab** | iPhone 17 Pro 動画層 |
| 26/04 (v2.16–2.18) | iPad 左右配置, **タイムスタンプ保持, 輝度範囲マスク, 14 split-tone preset** | 完成局面・プロ層仕上げ |

### 2.2 戦略パターン

- **2 週間サイクルで Re-publish ASO トリック**: 同じ release notes を 1〜2 週後に v.X.1 として再公開（5 回検出）。What's New 枠で再露出
- **段階深堀り**: トーンカーブ (v2.3) → ヒストグラム (v2.13) → 曲線ヒストグラム解決 (v2.17) と 3 段。マスクも image (v2.2) → luma (v2.17) と 2 段
- **直近 1 ヶ月は完成局面**: 新機能投入から既存機能の使い倒し体験を磨くフェーズへ移行

---

## 3. 機能カバレッジ計測

PeekLut の release notes と App Store description から **69 個** の機能項目を抽出して 1 個ずつ突合。

### 3.1 単純カウント

| 状態 | 件数 | 割合 |
|------|------|------|
| ✅ Filmtone 完全実装 | 12 | **17.4%** |
| ⚠️ 部分 / 概念違いで実装 | 6 | 8.7% |
| ❌ Filmtone 未実装 | 51 | 73.9% |

### 3.2 重み付きスコア（重要度 1-5）

| カテゴリ | 重要度 | PeekLut | Filmtone | 状態 |
|---------|--------|---------|----------|------|
| LUT import / apply | 5 | 5 | 5 | ✅ |
| Tone Curve | 5 | 5 | 0 | ❌ |
| クロップ | 5 | 5 | 0 | ❌ |
| マスク（線形/放射状/輝度範囲） | 4 | 4 | 0 | ❌ |
| バッチ編集 | 4 | 4 | 0 | ❌ |
| プリセット数 | 4 | 4 | 1.1 (4/14) | ❌ |
| Halation/Bloom/Grain/色収差/歪み/Tech3 | 4 | 4 | 2.7 (4/6) | ⚠️ |
| ProRes / カスタムビットレート | 3 | 3 | 0 | ❌ |
| 出力形式（JPG/PNG/HEIC/TIFF） | 3 | 3 | 1.5 (2/4) | ⚠️ |
| Histogram | 3 | 3 | 0 | ❌ |
| チャンネル別 saturation / luminance | 3 | 3 | 0 | ❌ |
| メタデータ / タイムスタンプ保持 | 3 | 3 | 0 | ❌ |
| Before/After スライダー | 2 | 2 | 1 | ⚠️ |
| Compare（瞬時切替） | 2 | 2 | 2 | ✅ |
| **合計** | — | **50** | **13.3** | **27%** |

→ **機能負け 73%（重み付き）**

### 3.3 工数比で正規化

- 機能カバレッジ 17〜27% を工数比 30〜100 倍で割ると **Filmtone のほうが効率 5〜25 倍**
- 副業 6 週で PeekLut の 17〜27% に到達 = 機能数で勝つのは設計上不可能だが、効率は遥かに高い

---

## 4. Filmtone 独自実装（PeekLut にない 13 項目）

### 4.1 物理光学・色科学（コア IP）

1. **Depth-aware grading**（静止画 + 動画）
   - `DepthSourceService` / `VideoDepthSourceService` / `FilmtoneDepthMap` / `FilmtoneDepthPrefilter`
   - iOS の depth map を grading に使う。PeekLut は 2D のみ
2. **180° shutter physics motion blur**
   - `FilmtoneMotionBlurMath`
   - 物理的に正しいシャッター角ベースのモーションブラー
3. **Ray Angle Optics**（光学物理シミュレーション）
   - `FilmtoneRayAngleOptics`
   - PeekLut の chromatic aberration / lens distortion より深い物理層
4. **Phase 0 数学モデル**
   - `FilmtonePhase0Math` で param→shader を決定論的に展開
   - クロスプラットフォーム再現性

### 4.2 入力色域の自動処理

5. **Source Color Metadata Normalizer**
   - 入力色域（Rec.709 / P3 / HDR / Log）を自動正規化
   - PeekLut は手動でカラースペース変換選択
6. **Mezzanine Color Probe**
   - 撮影メタデータから素材性質を自動推定
7. **HDR Policy Notice**
   - HDR 素材を SDR で出すと劣化が出ることを明示する UI

### 4.3 iOS プラットフォーム深掘り

8. **Live Activity 書き出し進捗**
   - Dynamic Island / Lock Screen で書き出しを実況
9. **Lock Screen Cancel Intent**
   - App Intent で Lock Screen から書き出し中断
10. **Live Activity Attributes 設計**
    - `FilmtoneExportAttributes` で進捗データ構造を設計済

### 4.4 アーキテクチャ哲学

11. **Capacitor + Swift hybrid + film-lab-core 共有**
    - Web / iOS / Desktop で同じ color pipeline。PeekLut は iOS only
12. **Dual-LUT パイプライン**（Source Profile + Film Look）
    - PeekLut の LUT layering と概念違い。色管理の文法として明示的
13. **完全ローカル / no account / no cloud / no IAP**
    - PeekLut は IAP（¥200/週〜¥15,000）

### 4.5 既に実装済の "Pro Tool 連携基盤"（重要）

**`FilmtoneExportSidecarBuilder.swift`** が既に存在し、書き出しごとに以下を含む sidecar JSON を生成している：

```
<出力ファイル名>.filmtone-ios-export-session-v1.json
```

- Schema: `filmtone-ios-export-session-v1`（拡張可能、v1.1 / v1.2 で additive optional fields）
- 含む情報: device identity / preset + params / LUT 参照（size + intensity） / output 情報 / mezzanine 情報
- Files.app / Finder で **メディア + sidecar が並んでソート可能** な命名

これが **Pro Tool 連携ポジションの既存の技術的土台**。PeekLut にはない。

---

## 5. 戦略判断（CD 決定 = 2026-04-29）

### 5.1 機能パリティは追わない

> **Pro 向けの色管理は DaVinci / Adobe で行うのが正しい。Filmtone がそこに突っ込むのは筋が悪い。**

理由:
- PeekLut の 24 リリース・2 週間サイクルに副業 6 週の Filmtone は構造的に追従不能
- トーンカーブ・マスク・チャンネル別 luminance などは **DaVinci に既に高品質で存在する**。モバイルで再実装する価値が薄い
- Filmtone のコア IP（Depth / Ray Angle Optics / 180° shutter / Sidecar pipeline）は PeekLut の延長線にない

### 5.2 取るべきポジション

> **「iPhone snapshot ritual」 ＋ 「Pro Tool への handoff bridge」**

二段構えの位置取り：

| 層 | 価値 | 競合 |
|----|------|------|
| (a) iPhone 完結 ritual | 撮ったあと 30 秒で SNS / Photos へ | VSCO / Dazz / Filmm |
| (b) Pro Tool への bridge | iPhone で素地を作って DaVinci / Adobe で仕上げる | **競合不在**（PeekLut は "DaVinci 代替"、Filmtone は "DaVinci の前段"） |

(b) は **PeekLut が定義していないカテゴリ**。ここに旗を立てる。

---

## 6. "Pro Tool 連携" の具体仕様

### 6.1 既存資産（v1.2 時点で動いている）

| 機能 | 実装 | 連携相手 |
|------|------|---------|
| Sidecar JSON 出力 | `FilmtoneExportSidecarBuilder` | 任意（schema 公開可能） |
| Dual-LUT pipeline | `FilmtoneColorPipeline` + `FilmtoneCubeParser` | DaVinci / Premiere / FCP |
| Source Color Metadata Normalizer | `SourceColorMetadataNormalizer` | カメラ素材直接 |
| Mezzanine Color Probe | `MezzanineColorProbe` | DaVinci の input transform |
| HDR Policy Notice | `FilmtoneHdrPolicyNotice` | HDR 素材保持判定 |
| Live Activity 進捗 | `FilmtoneExportLiveActivity` | iOS only |

### 6.2 v1.3 で追加する連携機能（提案）

優先度高い順:

#### P0: LUT (.cube) 書き出し

- 現在の Filmtone grade（preset + params + LUT スタック）を **1 個の .cube ファイル**に焼き込み
- DaVinci / Premiere / FCP / Resolve / Affinity Photo / Capture One すべてが読める標準形式
- 書き出し先: Files.app（iCloud Drive 経由でデスクトップ NLE に直接渡る）
- 実装: Phase 0 params → 33×33×33 の 3D LUT サンプリング → .cube シリアライズ
- **PeekLut も持っている機能だが、Filmtone の dual-LUT 思想で書き出すと差別化される**：
  - "Source Profile lane" だけ書き出し → カメラ正規化用の LUT
  - "Film Look lane" だけ書き出し → クリエイティブ grade 用の LUT
  - "Combined" 書き出し → 一発適用用

#### P0: Sidecar JSON のスキーマ公開

- `filmtone-ios-export-session-v1.json` のスキーマを **公開ドキュメント化**
- 公開先候補: `chibatakumi.studio/filmtone/sidecar-schema` or GitHub
- DaVinci の Lua スクリプト / Premiere の ExtendScript で sidecar を読み取って grading state を再現するサンプルを提供
- これが **競合が真似しづらい "プラットフォーム化" の一歩目**

#### P1: ProRes 422 書き出し（出力側）

- 入力 ProRes は既に対応。**出力**にも対応
- DaVinci に渡すなら ProRes 422 が de facto standard
- ProRes 4444 / RAW までは追わない（オーバースペック・実装コスト大）
- 現在の `FilmtoneExportSession` の `MezzanineService` を流用可能

#### P1: メタデータ保持書き出し

- EXIF（撮影日時 / GPS / カメラ機種）を出力にコピー
- 写真愛好家層の常識的要件
- iCloud 写真 → Lightroom 連携のときに必須
- 実装は CGImageDestination の copyMetadata で 1 メソッド

#### P1: Apple Log pass-through 出力

- 現在は Log → Rec.709 input transform。**Pass-through モード**を追加
- Filmtone の grade を sidecar / LUT として出して、**素材は Log のまま** 出力
- DaVinci 側で Filmtone の LUT を当てて grading 続行できる
- iPhone 17 Pro の Apple Log ユーザー層にダイレクトに刺さる

#### P2: DaVinci .drx / Premiere .lrtemplate 出力

- DaVinci の Color Trace 用 .drx export
- Premiere / Lightroom の Look 形式 .lrtemplate
- **これは "やる" を決めてから工数見積もる**。サンプル実装の調査が先

#### P2: Files.app 共有エクスポートの一括化

- 出力 + sidecar + LUT + reference still を **1 zip** に固める "Send to NLE" ボタン
- AirDrop で macOS にぶん投げる UX
- これは UI 寄りの仕事

### 6.3 やらない機能（明示）

| 機能 | 理由 |
|------|------|
| トーンカーブ | DaVinci で十分。Filmtone は「ざっくり仕上げ → DaVinci で精密化」 |
| マスク（線形/放射状/輝度範囲） | DaVinci の Power Window が圧倒的 |
| チャンネル別 saturation / HSL luminance | DaVinci の Color Warper / Hue vs Sat |
| 14+ split-tone preset の数勝負 | 既存 4 preset を **名前と物理整合性で磨く** 方が深い |
| Technicolor 3-strip / Tetra Color Mix | プリセット 1 枚で代替可能 |
| ProResRAW 出力 | デスクトップ仕事 |
| LUT folder sync | プロカラリスト向け、Filmtone 層に不要 |
| バッチ編集（複雑な） | "同じ preset を複数枚に当てる" だけの軽量版に絞る |

---

## 7. マーケティング再ライティング

### 7.1 旧コピー（v1.2 時点）

- subtitle ja: 「映画の色から使い捨てカメラまで」
- subtitle en: "Movie color, film snapshots"
- description: "標準の写真編集では少し物足りない。大きな動画編集アプリを開くほどでもない"

→ 方向は正しいが「日常 / 雰囲気」で他アプリと埋もれる。**Pro Tool 連携軸を立てる必要がある**。

### 7.2 新コピー（v1.3 提案・3 軸）

#### 軸 A：iPhone snapshot ritual（既存層維持）

- ja: 「撮ったあとを、フィルムへ」
- en: "After capture, before sharing."

#### 軸 B：Pro Tool への bridge（新規層）

- ja: 「iPhone で下地を、DaVinci で仕上げを」
- en: "Pre-grade on iPhone. Finish in DaVinci."

#### 軸 C：物理整合（独自 IP）

- ja: 「180° の真実、レンズの距離。フィルムの物理を iPhone の写真に戻す」
- en: "Physically grounded film: 180° shutter, ray angle optics, depth-aware grading."

### 7.3 description 構成案（v1.3 ASO）

```
1. Hook（軸 A）— 撮ったあと 30 秒で完了
2. Use case 列挙（SNS / 旅 / カバー）
3. Pro 連携セクション（軸 B）— Pre-grade for DaVinci, Adobe, Final Cut
   - .cube LUT export
   - Sidecar JSON for grading state reproduction
   - ProRes 422 / Apple Log pass-through
   - Metadata preservation
4. 物理整合（軸 C）— 180° shutter, depth-aware, Halation/Bloom physics
5. プライバシー — 完全ローカル、課金なし、アカウント不要
```

これで **PeekLut が "DaVinci 代替"、Filmtone が "DaVinci 前段"** という棲み分けが ASO 上で明確になる。

---

## 8. ロードマップ再設計

### 8.1 v1.2.1（〜2 週後・実装ゼロ）

- Re-publish ASO（PeekLut の手口）
- 軽微 fix を口実に v1.2 と同じ binary で release notes 再露出
- subtitle / description は v1.2 のまま（v1.3 まで温存）

### 8.2 v1.3（〜2 ヶ月後・Pro 連携 P0）

- **LUT (.cube) 書き出し**（dual-lane: Source / Film Look / Combined）
- **Sidecar スキーマ公開ページ** + DaVinci Lua サンプル
- **subtitle / description 再ライティング**（軸 A + B + C）
- 既存 4 preset の **名前再定義**（"京都プリント" "稲妻" "夕暮れポラ" 等の固有名詞）

### 8.3 v1.4（〜4 ヶ月後・Pro 連携 P1）

- **ProRes 422 出力**
- **メタデータ保持書き出し**
- **Apple Log pass-through 出力**
- "Send to NLE" ボタン（出力 + sidecar + LUT + reference still を 1 zip）

### 8.4 v1.5 以降（Pro 連携深堀り or 独自 IP 強化）

判断 gate：v1.3 / v1.4 のリテンションを見て決める
- Pro 連携が刺さる → DaVinci .drx / Premiere .lrtemplate
- ritual 層が刺さる → 独自 13 項目の太らせ（Depth UI 露出 / Live Activity 拡張）

---

## 9. 期待効果

### 9.1 機能負け率の解釈変化

| 軸 | 旧解釈 | 新解釈 |
|----|--------|--------|
| 機能カウント | 73〜83% 負け | 同じ。**気にしない** |
| 比較対象 | PeekLut（DaVinci 代替） | DaVinci 自身（Filmtone は前段） |
| 競合カテゴリ | "iPhone 用カラリストツール" | "iPhone 用 pre-grade ＋ Pro Tool bridge" |
| ベンチマーク | PeekLut の機能数 | DaVinci ワークフローへの cleanness |

### 9.2 ASO 上の差分

- PeekLut の検索流入：「iPhone カラーグレーディング」「DaVinci モバイル」
- Filmtone の検索流入を狙う：「iPhone DaVinci 連携」「Apple Log iPhone 編集」「LUT export iPhone」「Pre-grade mobile」
- **競合がいないキーワード空間**を取りに行く

### 9.3 商用展開可能性

- Sidecar スキーマ公開 → **DaVinci Studio / Premiere プラグイン** を別 SKU として作る余地
- "Filmtone Connect for DaVinci" のような有料プラグイン（モバイル本体は無料維持）
- これは **Filmtone を単独アプリから "ワークフロー" に昇格** させる動き

---

## 10. 次のアクション

| アクション | 担当 | 期日 | 状態 |
|----------|------|------|------|
| 本ドキュメント承認 | CD（ユーザー） | 2026-04-29 | 提出中 |
| v1.2.1 Re-publish 計画書 | Claude | 承認後 | — |
| v1.3 LUT 書き出し技術設計 handoff | Claude | 承認後 | — |
| Sidecar スキーマ公開ページ案 | Claude | 承認後 | — |
| subtitle / description 再ライティング 3 案 | Claude | 承認後 | — |
| DaVinci Lua sidecar reader サンプル | 別チャット推奨 | v1.3 中 | — |

---

## 11. 参考データ

### 11.1 PeekLut バージョン履歴（要約）

| バージョン | 日付 | 主な変更 |
|----------|------|---------|
| 1.3.1 | 2025/05/31 | Bug fixes |
| 2.0 / 2.1 | 2025/07/27–30 | New rendering engine, Color Grading, adjustable Grain, Fade/Clarity/Sharpness/Whites/Blacks |
| 2.2 | 2025/08/08 | **画像マスク（線形/放射状/画像）, 編集→.cube 書き出し** |
| 2.3 / 2.3.1 | 2025/08/20–31 | **トーンカーブ, JPEG/PNG/HEIC/TIFF, B/A スライダー** |
| 2.4 | 2025/09/09 | 肌・空・影 rendering 改善 |
| 2.5 | 2025/09/17 | Liquid Glass 対応 |
| 2.6 | 2025/11/06 | **バッチ編集, グレイン強化** |
| 2.7 | 2025/11/28 | **HDR エクスポート** |
| 2.8 | 2025/12/08 | **ProRes 422/4444, カスタムビットレート** |
| 2.9 | 2025/12/15 | Bloom 強化, ハレーション color picker, ギャラリーレイアウト |
| 2.10 | 2026/01/03 | フィルム濃度, 緑葉, Technicolor 3-strip |
| 2.11 | 2026/01/25 | コンパクト編集レイアウト, **チャンネル別 saturation**, LUT 重ね合わせ |
| 2.12.1 | 2026/02/10 | **新クロップツール, コンパクトレイアウト toggle** |
| 2.13 / 2.13.1 | 2026/02/14–19 | **自動クロップ, テトラカラーミックス, LUT フォルダ同期, コンパクトヒストグラム** |
| 2.14 / 2.14.1 | 2026/03/03–05 | **メタデータ保持画像書き出し, Apple Log/HDR fix** |
| 2.15 / 2.15.1 | 2026/03/19–24 | **Film Filter Tab, 色収差, レンズ歪み, Technicolor 3-strip, Film Saturation** |
| 2.16 | 2026/04/09 | iPad コントロール左右, **タイムスタンプ保持書き出し** |
| 2.17 | 2026/04/21 | **輝度範囲マスク, ライブマスクプレビュー, 曲線ヒストグラム解決** |
| 2.18 | 2026/04/29 | **14 split-tone preset（東京プリント等）, HSL 色輝度** |

### 11.2 既存 Filmtone iOS 関連 doc

- 出荷: `filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md`
- v1.1: `filmtone-ios-v1.1-release-handoff-2026-04-25-jst.md`
- v1.1 parity: `filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`
- v1.2: `filmtone-ios-v12-release-to-aso-handoff-2026-04-29-jst.md`
- Desktop parity: `filmtone-ios-parity-gap-vs-desktop-v1.0.3-2026-04-24-jst.md`
- 用語整合: `filmtone-effect-terminology-alignment-handoff-2026-04-26-jst.md`
- Dual LUT: `filmtone-ios-dual-lut-clear-output-breakage-handoff-2026-04-29-jst.md`
- LUT intensity: `filmtone-ios-lut-intensity-slider-handoff-2026-04-29-jst.md`
- Preview/export parity: `filmtone-ios-preview-export-color-parity-handoff-2026-04-29-jst.md`
- Process tone preset: `filmtone-ios-process-tone-preset-handoff-2026-04-29-jst.md`

---

## 12. 結論

- **機能負けは 73〜83%。事実として認める**
- **追わない。DaVinci / Adobe との連携を磨く方向に転換する**
- 既存の Sidecar JSON 基盤、Dual-LUT pipeline、Source Color Metadata Normalizer は **連携ポジションの強い土台** として既に存在する
- v1.3 で LUT 書き出し + Sidecar スキーマ公開 + ASO 再ライティング を打つ
- "PeekLut が DaVinci の代替を狙う" のに対し、Filmtone は "**DaVinci の前段**" を取る。**競合不在カテゴリ**

---

*本書は CD 承認 gate にかける。承認後に v1.3 LUT 書き出し技術設計 / Sidecar スキーマ公開 / subtitle 再ライティング の各 handoff doc を分割して進める。*
