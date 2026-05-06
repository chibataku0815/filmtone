# Filmtone iOS — Information Design 仕様書

> ⚠️ **PARTIAL CORRECTION — 2026-05-04 (domain vocabulary)**
>
> 本 doc は `2026-04-07-filmtone-tool-vocabulary-ia-spec.md` の `Base Looks / Finish Tools / Trim` 3 層 taxonomy を iOS surface に投影しているが、その vocab spec は 2026-05-04 に **撤回**。**Look = Stone / Urban (Creative LUT Pack 01)** が canonical であり、本 doc 内の「Look (= Base Look) / world を決める層」表記は **誤前提**。
>
> 読み替え:
> - 本 doc の「**Look**」「**Base Look**」「**Look carousel**」「**Look Browser**」等は、現 canonical では **Preset** (curve/grade 土台) のこと
> - 現 canonical の「Look」(= Stone / Urban) は本 doc の「Look」とは別概念
> - `Air` / `Dusk` 等の架空 Look 名 (line 680 等) は実装されていない、参考とせず
>
> iOS app の実装 (`FilmtoneStrings.swift` "Preset Strength"、`messages.ts` `presetRowAriaLabel`) は **canonical のまま**であり、本 doc の rename 提案は scope 外。
>
> 詳細: `~/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/feedback_filmtone_preset_vs_look_domain.md`
>
> ---

- **Date**: 2026-05-02 (JST)
- **Status**: v1.0 — CD signoff 取得済 (本 chat にて 3 tension 裁定 + 出力先合意)
- **Author**: CD (chibatakumi)
- **対象 surface**: iOS app v1.4 mezzanine in-flight 以降の全 surface
- **Repo**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
- **Position**: iOS-specific specialization。Web/Desktop 横断の上流 canonical (persona-canonical / IA spec / marketing IA brief / PeekLut pivot / Pack 01 naming) を iOS の persona / journey / surface / microcopy / feedback design に貫通させる単一 doc

## この doc の役割

iOS app には canonical 上流の設計資産 (persona / vocabulary / positioning) が **個別に** 存在する一方、それらが **iOS の全 surface に統合された情報設計** として 1 文書化されていない。実装 (FilmtoneStrings / SwiftUI views / fastlane metadata / Onboarding / Help) は canonical と乖離している。

本 doc は:
1. 上流 canonical doc の iOS specialization を 16 section + 3 appendix で固定
2. 下流実装 chat (FilmtoneStrings rewrite / SwiftUI 再構成 / fastlane metadata rewrite) の **single source of truth** として機能
3. 実装 chat は本 doc を input とし、追加判断なしに rewrite 作業を進められる

矛盾時の優先順:
1. 本 doc (iOS specialization)
2. `/Volumes/SamsungPortableSSDX5001/documents/life/.claude/knowledge/patterns/2026-04-02-filmtone-product-intent-canonical.md` (product intent)
3. `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md` (canonical IA)
4. `docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-marketing-ia-aso-lp-brief-2026-04-30-jst.md`
5. `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/filmtone-persona-canonical.md` (Web/Desktop 期表現を含む — T2 で iOS context での override を明記)

## 上書き / 補完対象

| upstream doc | 関係 |
|---|---|
| `filmtone-persona-canonical.md` § ポジショニングステートメント | **iOS context で override** (T2 解消、§ 0 参照) |
| `2026-04-07-filmtone-tool-vocabulary-ia-spec.md` | **iOS specialization** (§ 7 で 3 層を iOS surface に配置) |
| `filmtone-marketing-ia-aso-lp-brief-2026-04-30-jst.md` | **継承** (surface roles, vocabulary lock, claim matrix) |
| `filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md` | **継承** (Axis A/B/C, Pro Tool bridge thesis) |
| `creative-lut-pack-01-naming-persona-handoff-2026-05-01-jst.md` | **確定** (Air/Dusk を § 8 で final lock、T3 解消) |

---

## § 0 Tension Resolution Log

本 doc を書くために CD が 3 件の上流間 tension を裁定した。実装 chat / 後続 chat はこの裁定を前提として動く。

### T1: DaVinci 言及の forbidden 範囲

- **upstream tension**:
  - `filmtone-marketing-ia-aso-lp-brief-2026-04-30-jst.md` § Forbidden until shipped: "DaVinci public workflow or 'DaVinci replacement' positioning"
  - `filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md` § 7.3: v1.3 description で `Pre-grade for DaVinci, Adobe, Final Cut` を hero に出す、軸 B `Pre-grade on iPhone. Finish in DaVinci.` を tagline 化
  - `filmtone-persona-canonical.md` § Don't: `Resolve replacement`
  - `scripts/check-filmtone-copy-quality.mjs`: `DaVinci` を含む forbidden-claim pattern
- **CD resolution**: v1.4 期は **handoff destination としての DaVinci 言及を許容**。`.cube` LUT export + Sidecar JSON は `FilmtoneExportSidecarBuilder.swift` で shipped 済 = "forbidden until shipped" 条件解除。
- **実装 chat への注意**: 実装時に `scripts/check-filmtone-copy-quality.mjs` の lint pattern を直接確認。文字列 "DaVinci" が完全 forbidden なら "your color editor" / "your NLE" / "desktop NLE" 等で迂回。"DaVinci replacement" は永続的に Don't。

### T2: iPhone surface の権威

- **upstream tension**:
  - `filmtone-persona-canonical.md` § ポジショニングステートメント: `Desktop-first look finisher` / `Web is where you try the look. Desktop is where you finish the work.` (Desktop-first / iPhone 不在)
  - `filmtone-marketing-ia-aso-lp-brief-2026-04-30-jst.md` § Surface roles: `Web=Try first / iPhone=Finish locally / Mac=Deeper finish/export` (3 surface 並列)
  - `filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md` § 5.2: iPhone を独立カテゴリ `iPhone snapshot ritual + Pro Tool bridge` として打ち出す
- **CD resolution**: iOS app = **独立した完結 surface (Layer A snapshot ritual) + Pro Tool bridge (Layer B)** を主軸。`persona-canonical.md` の Desktop-first 表現は **2026-04-07 期 v0.6 期表現** として override。
- **新 canonical**: `marketing-ia-aso-lp-brief` (2026-04-30) + `peeklut-positioning-pivot` (2026-04-29) の組み合わせ。`persona-canonical.md` の persona table (Alex / ユウキ / Anti-persona / Brand Voice / Do-Don't) は **iOS context でも有効**、ポジショニングステートメントのみ override。

### T3: Pack 01 final naming

- **upstream tension**: `creative-lut-pack-01-naming-persona-handoff-2026-05-01-jst.md` で CD 発言「Air / Dusk はよくはなってきている」= 方向 OK / 最終確定なし。Stone / Urban は forbidden naming (placeholder material / generic geographic) と CD 自身が規定。
- **CD resolution**: **Air / Dusk で確定**。
  - JA カタカナ「エア」「ダスク」採用 (chip 表示の即時性 / Layer A 優先 / 漢字「大気/黄昏」は意味重すぎ chip 表示で重い)
  - EN は "Air" / "Dusk" 英字
  - bundleSlug `filmtone-creative-pack-01-stone/urban` / UUID `FB1A...000006/000007` / `.cube` SHA-256 / Phase0Generated 内部識別子は **据え置き** (永久 leak、 Pack 01 naming doc § 7 の触らないリスト)
  - display name のみ変更 (FilmtoneStrings の `builtInLookCreativePack01Stone/Urban` の value)
- **defer**: Pack 02 以降の命名軸 family 整合は別 chat / 別 plan

---

## § 1 Target Persona

### § 1.1 Layer A — hero (App Store 訪問者の 8 割 / SNS-led video creator)

| 項目 | 内容 |
|---|---|
| 名前 | Alex (仮) |
| 年齢 | 23–40 |
| 職業 | video creator / hybrid shooter / small brand video operator / 旅 vlogger |
| 撮影機材 | iPhone 15/16/17 Pro 系 + 小型ジンバル ± Sony α7C / FX30 / DJI Osmo / GoPro |
| 編集環境 | iPhone 完結 OR Mac で Premiere/FCP/CapCut。DaVinci は重く感じる |
| Pain (現状の苦痛) | (1) 撮ったあと SNS 公開まで時間がない / (2) 仕上がりの finished feel が欲しいが LUT 一発では物足りない / (3) 光学的 character (halation/grain) を簡単に足したい / (4) 動画を再生しながら判断したい (止め絵では mood が見えない) |
| Goal (達成したい状態) | 撮ったあと **30 秒以内** に Reels / TikTok / IG Story / YouTube Shorts に出す |
| 知識前提 | LUT / Log / Reference / Density 等の pro 語彙は **読まない**。タップ前に意味が立つ言葉のみ理解 |
| Look 名への期待 | 1 単語で mood が立つ / SNS で「○○ で撮った」と引用しやすい / 専門 / 古語 / 機能名 (Reference, Density) は NG |
| 主要文脈 | 旅 / イベント / mood clip / brand short / product teaser / 日常記録 |
| 使う surface | App Store discovery → DL → Onboarding → Empty → Editor → Look 選択 → Adjust (簡易) → Export → Save/Share |
| 期待しない surface | Settings (現状なし) / About / 詳細な help |

### § 1.2 Layer B — secondary (Pro Tool bridge user / 競合不在カテゴリ)

| 項目 | 内容 |
|---|---|
| 名前 | ユウキ (仮) |
| 年齢 | 27–45 |
| 職業 | フォトグラファー / 副業の映像制作者 / video colorist の出先版 / small creative team |
| 撮影機材 | iPhone Pro (Apple Log) ± Sony α / Canon C-Log / DJI D-Log / Rec.709 |
| 編集環境 | macOS Premiere / FCP / DaVinci で finish。iPhone は **pre-grade に使う** |
| Pain | (1) 撮影現場で素地を作って Mac に渡したい / (2) DaVinci で 0 から grade するのは時間がかかる / (3) 写真と動画の世界観を揃えたい / (4) iPad / iPhone でも grading 状態を持ち運びたい |
| Goal | iPhone で pre-grade → `.cube` + Sidecar JSON export → DaVinci/Premiere/FCP で finish |
| 知識前提 | LUT / Log / sidecar / `.cube` / Apple Log / S-Log3 等の pro 語彙に慣れている |
| Look 名への期待 | 雰囲気名でも実害なし。`bundledSlug` が機械可読なら命名は何でもよい |
| 主要文脈 | client gallery + recap clip / brand short の現場対応 / 旅先での pre-grade |
| 使う surface | App Store description (Pro workflow section) → DL → Source Profile sheet (Apple Log 詳細) → Adjust sheet (Trim 詳細) → Export → `.cube` LUT export → Files.app / iCloud Drive → Mac NLE |
| 期待しない surface | Onboarding (skip 多い) / Help (基本概念は既知) |

### § 1.3 Anti-Persona

`persona-canonical.md` § Anti-Persona から **iOS context でも継承**:

| タイプ | 理由 |
|---|---|
| プロカラリスト (DaVinci フル node graph 主軸) | Filmtone iOS の narrow path とは噛み合わない |
| NLE 代替を求める人 | Filmtone は timeline editor でも総合 post suite でもない (PeekLut 領域) |
| film process の厳密再現を主目的とする人 | Dehancer 領域 |
| Smart Look AI を主目的とする人 | 計画中 / 未出荷 |
| Windows-only ワークフロー | Desktop は macOS のみ |
| カジュアル smartphone filter で十分な人 | Filmtone を開く動機が弱い (VSCO で十分) |

### § 1.4 CD signoff layer (= chibatakumi)

`creative-lut-pack-01-naming-persona-handoff-2026-05-01-jst.md` § 1.3 から継承:
- Palermo Powergrade 所有者、film vocabulary に深く慣れている
- 多分野プロ (`life/CLAUDE.md` § 1 の 5 つの顔)
- 凡庸禁止 / descriptive stack 禁止 / placeholder 名定着禁止 を発令する人

優先順位 (Layer 競合時):
> **A 一次 → C 不可侵 → B 許容**

A に届かない名前 / 表現は採用しない。C を侮辱する命名 (placeholder / 凡庸 / descriptive stack) も採用しない。B は実害 free 帯。

---

## § 2 Jobs-To-Be-Done (JTBD)

### Layer A の job
> 「**撮ったクリップを、開いた数分後には作品として SNS に出せる状態**にする仕事を雇う」

### Layer B の job
> 「**撮影現場や移動中に iPhone で色の方向を決めて、Mac の NLE に持ち込む時にすぐ仕上げに入れる**ように準備する仕事を雇う」

### 両 layer 共通 job
> 「**重いカラー工程を開かずに、finished feel を作る**仕事を雇う」

### iOS specialization での意味
- iPhone で完結する Layer A / Mac へ持ち出す Layer B が **同一アプリで両立** する surface design が必要
- 同一 user (Alex がイベント撮影で Layer A、ユウキが client 案件で Layer B、または **同一人物が文脈で切替**) を排他的に分離しない
- onboarding / first launch は Layer A 寄りで誘導 (8 割の trip)、Pro workflow は description / Adjust sheet 詳細部 / Export 出力部で **discoverable に提示** (Layer B が必要時に発見できる)

---

## § 3 Value Proposition

iOS-specific value:

| 価値 | Layer | 競合との差分 |
|---|---|---|
| **iPhone だけで完結する finish path** | A | VSCO / Dazz / Filmm: 単純 filter のみ。Filmtone は optical character (halation, grain physics, depth-aware) を持つ |
| **Pro Tool への seamless bridge** | B | PeekLut: "DaVinci 代替" → Filmtone: "DaVinci の前段"。`.cube` LUT export + Sidecar JSON で grading state を NLE に persist。**競合不在カテゴリ** |
| **物理整合の独自 IP** | 両 (trust 軸) | 180° shutter / Ray Angle Optics / Source Color Metadata Normalizer / depth-aware grading。PeekLut の chromatic aberration や lens distortion より深い物理層 |
| **完全ローカル / アカウント不要 / IAP なし** | 両 (trust 軸) | PeekLut: IAP (¥200/週〜¥15,000)。VSCO: subscription。Filmtone: friction zero |

凝縮:
> **`high immediate feel × low workflow overhead × Pro Tool handoff × physical authenticity`**

(`persona-canonical.md` § Filmtone の隙間 を iOS 文脈で拡張: 元は `high immediate feel × low workflow overhead × same-world extension`、 iOS では `same-world extension` を `Pro Tool handoff` に置き換え + `physical authenticity` を追加)

---

## § 4 Positioning

iOS-specific positioning は 3 軸構造:

### Axis A — iPhone snapshot ritual (hero / 一次層)

- **Position**: VSCO / Dazz / Filmm の上を行く **optical finish** を持つ iPhone film look tool
- **競合空間**: VSCO (subscription mood filter) / Dazz (フィルム風スマホ filter) / Filmm (動画 filter)
- **JA tagline**: 「撮ったあとを、フィルムへ」
- **EN tagline**: "After capture, before sharing."
- **触れるべき要素**: 30 秒 ritual / Look chip / Strength + Look Intensity / Photos export
- **避けるべき**: pro 語彙 (LUT / Log / Reference) を hero に出さない

### Axis B — Pro Tool bridge (差別化 / 二次層)

- **Position**: PeekLut が "DaVinci 代替" を取る空間に対して **"DaVinci の前段"** を取る
- **競合空間**: 不在 (PeekLut は明示的に DaVinci 代替を志向)
- **JA tagline**: 「iPhone で下地を、デスクトップで仕上げを」
- **EN tagline**: "Pre-grade on iPhone. Finish on desktop." (DaVinci 単独名は実装 chat の lint 通過確認次第で "Pre-grade on iPhone. Finish in DaVinci/Premiere/FCP." も可)
- **触れるべき要素**: `.cube` LUT export / Sidecar JSON / Apple Log pass-through / ProRes 422 (将来) / metadata 保持 (将来)
- **避けるべき**: "DaVinci replacement" / "Resolve replacement" / "exact film process"

### Axis C — 物理整合 IP (trust / 三次層)

- **Position**: PeekLut にない **物理光学 IP** を背景に持つ
- **競合空間**: Dehancer の film process fidelity と異なるアプローチ (Filmtone は authenticity 競争に乗らず、speed × physical signature を取る)
- **JA tagline**: 「フィルムの物理を、iPhone の素材に」
- **EN tagline**: "Physically grounded film, in your pocket."
- **触れるべき要素**: 180° shutter / Ray Angle Optics / depth-aware grading / Source Color Metadata Normalizer / dual-LUT pipeline
- **配置**: description tertiary section のみ。hero / subtitle には出さない (Layer A 読み速度を阻害)

### Axis 前出し順

> **A > B > (C は description tertiary)**

App Store listing 構成:
- name / subtitle: **Axis A only**
- promotional text: **Axis A 主 + Axis B 補**
- description: **Axis A hook → use case → Axis B Pro workflow → Axis C trust → privacy** (5 section)

---

## § 5 Promise (5 文 grammar)

`2026-04-07-filmtone-tool-vocabulary-ia-spec.md` § 7.1 の LP grammar 5 文を **iOS 適用版** に specialise:

| # | iOS Promise | 適用 surface |
|---|---|---|
| 1 | `Make iPhone clips feel finished fast` (Layer A 主) | App Store name candidate / Onboarding step 1 hero |
| 2 | `Choose a Look. Add finish. Export local.` (3 step を 1 文) | App Store description hook / Onboarding journey grammar |
| 3 | `Pre-grade on iPhone. Finish on desktop.` (Layer B) | App Store description Pro section |
| 4 | `Physical film character — bloom, halation, grain.` (Axis C trust) | App Store description tertiary / Help body |
| 5 | `No account. No cloud. No IAP.` (privacy) | App Store description footer / Empty state subtitle |

これら 5 文以外の promise は使わない (= 用例の inflation を防ぐ)。

---

## § 6 Brand Voice

### § 6.1 Surface 別 voice / tone

`persona-canonical.md` § Brand Voice Guidelines を iOS surface 別に展開:

| Surface | 声 | トーン | 例 |
|---|---|---|---|
| App Store hero (name/subtitle) | User | 結果志向・短い | "Finish iPhone clips with film character." |
| App Store description | User → Maker (Pro section のみ) | 明快・段階的 | "Choose a Look. / Tune Strength and Finish Tools. / Export to Photos or `.cube` LUT for desktop NLE." |
| In-app onboarding (4 step) | User | 結果志向 + 安心 | "Pick a photo or video to begin." |
| In-app primary action (button) | User | 動詞短文 | "Export" / "Save Look" / "Share" |
| In-app help / explainer | Neutral | 明快・simple | "A Look chooses the world. Finish Tools add the signature." |
| In-app error message | Neutral | 状態 → recovery 順、1 sentence | "Export couldn't be completed. Try again or pick another source." |
| In-app HDR notice | Neutral | edge case acknowledge + outcome | "HDR video loaded. Export will be SDR." |
| In-app toast | Neutral | 状態のみ、icon 補強 | "Saved to Photos" / "Export complete" / "Share failed — try again" |
| Maker comment (PH 等 / app 外) | Maker | 技術 + 視点 | "I wanted iPhone clips to feel finished without opening DaVinci." |

### § 6.2 Do / Don't 語彙

`persona-canonical.md` § コピーの Do / Don't を iOS context に specialise:

**Do**:
- `video` / `clip` / `footage`
- `finished feel`
- `Look` / `Finish Tool` / `Trim` (canonical 3 層)
- `Pre-grade`
- `Local export`
- `.cube`
- `sidecar`
- `signature`
- `play while you judge`
- `Save Look` (action 動詞)
- `Save to Photos` (file I/O 動詞)

**Don't**:
- `短尺動画` / `short-form video` (vocabulary lock 違反、CLAUDE.md § 6)
- `atmosphere` / `cinematic` / `mood-only` 表現
- `世界観` / `雰囲気` (action と組み合わせない単独使用)
- `device you shot with` / `capture device` / `撮った後` (obvious-premise lint pattern)
- `DaVinci replacement` / `Resolve replacement` (false equivalence)
- `exact film process` / `film-stock fidelity` (Dehancer 領域に侵入)
- `AI auto-grade` (未出荷)
- `preset count` (feature inventory)
- `Black Mist` / `White Mist` (shipped feature 名ではない、internal candidate のみ)
- `LUT` を hero / subtitle / description headline の主語にする (UI / 詳細説明 OK、hero NG)

### § 6.3 ja↔en intent parity 原則

`persona-canonical.md` § Brand Voice Guidelines は ja/en 翻訳 fidelity を求める。iOS 実装 chat への注意:
- 翻訳の正確性 ≥ 同 mental model の伝達
- 例 (現状の divergence 例): `quickFilmCharacterHelpCopy` の effect 説明で JA は emotional/mood 語彙、EN は technical 語彙 → 同 mental model に整合させる必要
- ja で詳細説明 / en で簡潔、のような bias は禁止

---

## § 7 Concept Hierarchy

`2026-04-07-filmtone-tool-vocabulary-ia-spec.md` § 3 の canonical 3 層 (`Base Looks / Finish Tools / Trim`) を **iOS surface に物理配置**。

### § 7.1 3 層 + iOS 配置

```
[ Look ] (= Base Looks / world を決める)
  ├── Built-in Looks (Pack 01): Air, Dusk
  ├── Saved Looks (user-created snapshot)
  ├── Imported Look LUTs (.cube)
  └── Look Intensity (0–100% / Look LUT のブレンド)

[ Finish Tools ] (= signature を足す層)
  ├── Glow         (bloom + halation params)
  ├── Texture      (grain + vignette + radial mix)
  ├── Lens         (rgb shift + lens softness)
  ├── Motion       (shutter angle + trail)
  ├── Mist         (diffusion) ※ 内部 param あり、UI family 化は v1.5+ defer
  └── Cross        (cross filter) ※ 内部 param あり、UI family 化は v1.5+ defer

[ Trim ] (= source correction)
  ├── Source Profile (Camera Log → Working Space; Apple Log / Apple Log 2 / S-Log3 / V-Log / D-Log / D-Log M / C-Log / C-Log 3 / Rec.709 / Custom .cube / Auto)
  ├── Source LUT Intensity (0–100% / imported source LUT のブレンド)
  ├── Quick: Exposure / Contrast / Saturation
  └── Detail: Temperature / Tint / Highlights / Shadows / Fade
```

### § 7.2 surface 配置原則

- **iOS で `Look` を hero**: top-level surface = Editor の Look carousel + fullscreen Look Browser
- **`Finish Tools` を Adjust sheet 内の 1 つ目 section**: 6 family は disclosure section
- **`Trim` を Adjust sheet 内の 2 つ目 section + Source Profile sheet (Trim sub-layer)**
- **Source Profile (Camera Log) は Trim sub-layer**: 独立した hero ではない。Editor の side action button から起動
- **Library section 分離** (現行 C2 修正):
  - Saved Looks + Imported Look LUTs = Look browser 内 (Look 配下 / source-independent)
  - Imported Source LUTs = Source Profile sheet 内のみ (Trim 配下 / source-dependent retention)

### § 7.3 重要原則 (renderer ≠ user mental model)

`2026-04-07-filmtone-tool-vocabulary-ia-spec.md` § 4 から継承:
> このマッピングは user-facing IA の正本であり、renderer grouping の説明ではない。

- Profile schema の内部 key (`bloom_strength` / `halation_intensity` / `grain_size` 等) は **据え置き** (Profile.version 5 immutable / Sidecar V1 schema field 不変)
- UI label / FilmtoneStrings の display 値のみ canonical 用語に整合
- 実装 chat は **二層運用** (display = canonical / internal = 既存据え置き) で動く

---

## § 8 Vocabulary Lock (canonical glossary table)

iOS 全 surface で使う **canonical 用語表**。実装 chat はこの表に従って FilmtoneStrings の display value を全置換する。

### § 8.1 Top-level layer 名

| 概念 | UI EN | UI JA | 内部 key (FilmtoneStrings) | forbidden alias |
|---|---|---|---|---|
| Look layer (top-level) | Look | Look (英字統一、ルック→Look) | `lookLabel` | ルック (UI で出さない) |
| Finish Tools section | Finish Tools | Finish Tools | (新 key: `finishToolsLabel`) | Advanced (top-level), Artifacts |
| Trim section | Trim | Trim | (新 key: `trimLabel`) | Source Trim, Basic |

### § 8.2 Look 関連

| 概念 | UI EN | UI JA | 内部 key | forbidden alias |
|---|---|---|---|---|
| Built-in Pack 01 — 1 | Air | エア (カタカナ) | `builtInLookCreativePack01Stone` (key 据え置き、value 切替) | Stone |
| Built-in Pack 01 — 2 | Dusk | ダスク (カタカナ) | `builtInLookCreativePack01Urban` (key 据え置き、value 切替) | Urban |
| Saved Look | Saved Look | 保存した Look | `savedLook*`, `librarySavedLooksTitle`, `lookSavedToastFormat`, `lookAppliedToastFormat` | 保存したルック |
| Imported Look LUT | Imported Look | 読み込んだ Look | `lookImport`, `library*` | Imported LUT (Look 文脈で曖昧) |
| Look Intensity | Look Intensity | Look 強度 | `lookLutAmountLabel`, `fullscreenLookIntensityLabel` (両 surface 同一名) | Look LUT Amount, ルックLUTの量, Look ミックス |
| Look Browser surface | Look Browser | Look ブラウザ | `fullscreenTitle` | LUT Browser, LUT ブラウザ |
| Save Look (action) | Save Look | Look を保存 | `lookSaveCurrentMenu`, `savedLookSheetSave` | (現状一致) |

### § 8.3 Finish Tools family 名

| 概念 | UI EN | UI JA | 内部 key | forbidden alias |
|---|---|---|---|---|
| Glow family | Glow | Glow | `advancedGlowLabel` (rename to `finishToolGlowLabel` 推奨) | Halation 単独 family 化しない |
| Texture family | Texture | Texture | (新 key: `finishToolTextureLabel`) | Grain top-level family 化しない |
| Lens family | Lens | Lens | (新 key: `finishToolLensLabel`) | Optics (canonical では Lens) |
| Motion family | Motion | Motion | `advancedMotionLabel` (rename to `finishToolMotionLabel` 推奨) | (現状一致) |
| Mist family (defer) | Mist | Mist | (defer / v1.5+) | Black Mist / White Mist |
| Cross family (defer) | Cross | Cross | (defer / v1.5+) | Cross Filter (release notes 名は OK) |

### § 8.4 Trim 関連

| 概念 | UI EN | UI JA | 内部 key | forbidden alias |
|---|---|---|---|---|
| Source Profile (Camera Log) | Source Profile | ソースプロファイル | `cameraLabel` (label 変更) | Camera, Camera LUT, カメラ |
| Source LUT Intensity | Source LUT Intensity | ソース LUT 強度 | `inputLutAmountLabel` | Camera LUT Amount, カメラLUTの量 |
| Imported Source LUT | Imported Source LUT | 読み込んだソース LUT | `cameraImport` | Imported LUT (Source 文脈で曖昧), カメラ LUT |
| Source Profile sheet | Source | ソース | (sheet header) | Camera (Source Profile に統一) |

### § 8.5 Trim Quick / Detail

| 概念 | UI EN | UI JA | 内部 key | forbidden alias |
|---|---|---|---|---|
| Quick section | Quick | Quick | (new section header) | (内部 key `quickFilmCharacter`/`quickEra`/`quickDynamics` の display は標準語に統一) |
| Quick Exposure | Exposure | 露出 | `quickFilmCharacter` (key 据え置き、value 切替) | Film Character (display で使わない) |
| Quick Contrast | Contrast | コントラスト | `quickEra` (key 据え置き、value 切替) | Era (display で使わない) |
| Quick Saturation | Saturation | 彩度 | `quickDynamics` (key 据え置き、value 切替) | Dynamics (display で使わない) |
| Detail Temperature | Temperature | 色温度 | `paramLabels["temperature"]` | (現状一致) |
| Detail Tint | Tint | 色かぶり | `paramLabels["tint"]` | (現状一致) |
| Detail Highlights | Highlights | ハイライト | `paramLabels["highlights"]` | (現状一致) |
| Detail Shadows | Shadows | シャドウ | `paramLabels["shadows"]` | (現状一致) |
| Detail Fade | Fade | フェード | `paramLabels["fade"]` | (現状一致) |

### § 8.6 Recipe (Look-side preset) 関連

`2026-04-07-filmtone-tool-vocabulary-ia-spec.md` § 4.2 で `Presets` は `Base Looks` (= Look 配下) に位置付けされる。Recipe = Look 内の preset variant として明確化。

| 概念 | UI EN | UI JA | 内部 key | forbidden alias |
|---|---|---|---|---|
| Recipe (term) | Recipe | レシピ | `advancedPreset*Label` (rename to `recipe*Label` 推奨 / 内部 key 変更可、Capacitor bridge 跨がない) | Preset (top-level 衝突回避、recipe = Look 配下の variant 限定) |
| Recipe variant — None | None | なし | `advancedPresetNoneLabel` | (現状一致) |
| Recipe variant — Default | Default | 標準 | `advancedPresetDefaultLabel` | (現状一致) |
| Recipe variant — Strong | Strong | 強め | `advancedPresetStrongLabel` | (現状一致) |
| Recipe variant — Print Reference | Print Reference | プリント基準 | `advancedPresetPrintLabel` | "階調" (`advancedToneLabel` ja / `advancedProcessLabel` ja と 3 重衝突) |
| Recipe variant — Push | Push | プッシュ | `advancedPresetPushLabel` | (現状一致) |
| Recipe variant — Vivid | Vivid | ヴィヴィッド | `advancedPresetVividLabel` | (現状一致) |
| Recipe variant — Punch | Punch | パンチ | `advancedPresetPunchLabel` | (現状一致) |
| Recipe variant — Custom | Custom | カスタム | `advancedPresetCustomLabel` | (現状一致) |

### § 8.7 Tone / Process group

| 概念 | UI EN | UI JA | 内部 key | forbidden alias |
|---|---|---|---|---|
| Tone family | Tone | 色トーン (Process との衝突回避) | `advancedToneLabel` | "階調" 単独 |
| Tone variant — Standard | Standard | 標準 | `advancedToneStandardLabel` | (現状一致) |
| Tone variant — Airy | Airy | 爽やか | `advancedToneAiryLabel` | (現状一致) |
| Tone variant — Sunset | Sunset | 夕景 | `advancedToneSunsetLabel` | (現状一致) |
| Tone variant — Depth | Depth | 深み | `advancedToneDepthLabel` | (現状一致) |
| Process family | Process | 階調処理 (Tone との衝突回避) | `advancedProcessLabel` | "階調" 単独 (曖昧) |

### § 8.8 Strength 統合 (現行 4 重命名 → 3 種類整理)

| 概念 | UI EN | UI JA | 内部 key | forbidden alias |
|---|---|---|---|---|
| Recipe Strength (Look 全体の preset 適用度) | Strength | 強度 | `strengthLabel`, `fullscreenStrengthLabel` (両 surface 同一名) | Preset Strength (廃止), プリセット強度 (廃止) |
| Look Intensity | Look Intensity | Look 強度 | `lookLutAmountLabel`, `fullscreenLookIntensityLabel` (両 surface 同一名) | Look LUT Amount, ルックLUTの量, Look ミックス |
| Source LUT Intensity | Source LUT Intensity | ソース LUT 強度 | `inputLutAmountLabel` | Camera LUT Amount, カメラLUTの量 |

**整合原則**: 3 つの異なる control が 3 つの異なる名前で呼ばれる、を担保。main editor / fullscreen / Adjust sheet で同 control は同一名。

### § 8.9 Library / Action / Surface

| 概念 | UI EN | UI JA | 内部 key | forbidden alias |
|---|---|---|---|---|
| Library section header | Library | ライブラリ | (新 section header) | Saved (動詞文脈に限定) |
| Save to Photos | Save to Photos | 写真に保存 | `saveToPhotos`, `exportAndSave` | (現状一致) |
| Export | Export | 書き出す | `exportStart`, `exportSectionTitle` | (現状一致) |
| Import .cube | Import .cube | .cube を読み込む | `cameraImport`, `lookImport` | (現状一致) |
| Pick (source acquisition) | Pick a photo or video | 写真や動画を選ぶ | `sourceEmpty`, `pickSource` | Choose (Onboarding step 1 でも Pick 統一) |

### § 8.10 forbidden vocabulary 包括リスト

実装 chat の lint 通過確認に使う:

| 領域 | forbidden | reason |
|---|---|---|
| Layer A 抽象 | atmosphere, cinematic, mood (単独), 世界観, 雰囲気, 空気感 | abstract-filler / 行動と紐付かない |
| Surface naming | 短尺動画, short-form video, short clips | vocabulary-lock 違反 (CLAUDE.md § 6) |
| Premise | 撮った後, 撮影後, after you shoot, device you shot with, capture device | obvious-premise lint pattern |
| Competitor | DaVinci replacement, Resolve replacement, exact film process, film-stock fidelity | false equivalence |
| Unshipped | AI auto-grade, Smart Look, Black Mist, White Mist | 未出荷 (roadmap gated) |
| Feature inventory | preset count | outcome ではない |
| Surface confusion | Web (役割明示なし), iPhone (役割明示なし) | surface-without-role lint pattern |

### § 8.11 ja カタカナ vs 英字使用ルール

- **英字 Look / Finish Tools / Trim / Recipe**: 製品 IA の核となる用語。意味の重さを保つため英字採用、JA UI でも英字維持
- **カタカナ Air / Dusk / Glow / Texture / Lens / Motion**: chip / family chip 表示に使う名詞。読み速度優先で英字でも OK だが Pack 01 (Air/Dusk) は CD 判定で **JA カタカナ「エア」「ダスク」採用**
- **漢字 露出 / 彩度 / 色温度 / 色トーン / 階調処理**: parameter 名 / 群名は意味の重さがあり漢字表記が伝わりやすい → 漢字採用
- **Quick (英字)**: section name は短さ + 即時性で英字 (漢字「クイック」は冗長)

---

## § 9 User Journey

iOS app の 8 step canonical journey。実装 chat の Onboarding / Empty / Editor / Help の copy はこの journey を反映する。

### § 9.1 Journey diagram

```
[J1] App Store discovery
     │  - subtitle で Layer A の hook (30 秒 ritual)
     │  - description で Layer A → Layer B → Privacy の段階構成
     │  - Pro workflow を読みたい Layer B に reach
     ▼
[J2] App Store DL → first launch
     │  - icon tap → launch screen (brand recognition)
     ▼
[J3] Onboarding (4 step canonical journey)
     │  Step 1: Pick    — 写真や動画を選ぶ
     │  Step 2: Look    — Look を選んで世界観を決める
     │  Step 3: Finish  — Finish Tools で character を足す
     │  Step 4: Export  — Photos へ書き出すか NLE へ持ち出す
     │  - Layer B reach: Step 4 で `.cube` LUT export を mention
     ▼
[J4] Empty state
     │  - "Pick from Photo Library" / "Pick from Files" CTA
     │  - Saved Looks teaser (1 件以上あれば表示)
     │  - 言葉: "Pick a photo or video to begin." / "写真や動画を選んで始める"
     ▼
[J5] Source loaded → Editor
     │  - Source profile auto-detect banner (Apple Log 等検出時)
     │  - Look carousel が hero (Built-in Air/Dusk + Saved Looks)
     │  - Strength + Look Intensity slider
     │  - Adjust / Source / Export action button
     ▼
[J6] Look judgment
     │  - Look carousel browse (再生しながら判断)
     │  - Look Browser fullscreen (詳細比較)
     │  - Strength + Look Intensity 調整
     │  ┌─────────────────────────────────────────┐
     │  │ Layer A path: 直で Export → Photos      │
     │  │ Layer B path: Adjust sheet で Trim +    │
     │  │              Finish Tools 微調整 →      │
     │  │              Export → Files (.cube +    │
     │  │              Sidecar JSON)              │
     │  └─────────────────────────────────────────┘
     ▼
[J7] Export → Result
     │  - Save to Photos (Layer A 主)
     │  - Share (system sheet)
     │  - (Layer B) `.cube` LUT export → Files.app
     │    → AirDrop / iCloud Drive → Mac NLE
     │  - Toast: "Saved to Photos" / "Export complete"
     ▼
[J8] Reuse path
        - Saved Looks 再呼出 (Look carousel + Library)
        - Imported Looks 再適用 (Look browser)
        - Imported Source LUTs 再適用 (Source Profile sheet)
        - 同一 source / 別 source への適用 toggle
```

### § 9.2 感情変化 (各 step での user 内面)

| Step | Layer A の感情 | Layer B の感情 |
|---|---|---|
| J1 Discovery | "iPhone でフィルム調できそう" | "Pre-grade tool として使えるかも" |
| J2 First launch | "シンプル、迷わない" | "シンプル、迷わない" |
| J3 Onboarding | "わかった、写真選んで Look 選ぶだけ" | (skip 多い) |
| J4 Empty | "撮った clip 選ぶ" | "現場の素材を pre-grade する" |
| J5 Editor | "Look が並んでる、選びたい" | "Source profile auto-detect 効いた、安心" |
| J6 Judgment | "再生しながら mood 判断、Air がいい" | "Trim を細かく追い込みたい、Adjust 開く" |
| J7 Export | "Photos に保存できた、Reels に上げよう" | ".cube + Sidecar が Files に出た、Mac へ" |
| J8 Reuse | "前と同じ Look 使い回せる、便利" | "Saved Look library で grade 継承" |

### § 9.3 surface ごとの journey との対応

| surface | 主要 step | 同居 step |
|---|---|---|
| App Store listing | J1 | — |
| App Icon / Launch | J2 | — |
| Onboarding | J3 | — |
| Empty state | J4 | J8 (Saved Looks teaser) |
| Editor | J5, J6 | J8 (Look carousel に Saved 同居) |
| Look Browser | J6 | J8 |
| Adjust sheet | J6 (Layer B path) | — |
| Source Profile sheet | J6 (Layer B path) | J8 (Imported Source LUTs strip) |
| Library (内蔵) | J8 | — |
| Export panel | J7 | — |
| Result + Share | J7 | — |
| Help | (任意 step、学習補助) | — |
| HDR notice | J5 (素材種別による edge case) | — |
| Toast | J5–J8 (操作 feedback transient) | — |

---

## § 10 Surface Map

iOS app の全 surface inventory。各 surface の役割 / information role / canonical layer / 状態 を固定。

### § 10.1 Surface 一覧

| # | Surface | View file | 役割 | Information role | canonical layer | 状態 |
|---|---|---|---|---|---|---|
| S1 | App Store listing | (fastlane metadata) | 第一印象 / DL 動機 | Layer A hook + Layer B differentiator + privacy trust | (上流) | live |
| S2 | App Icon | (Asset Catalog) | アプリ aware の identifier | brand anchor | (上流) | live |
| S3 | Launch screen | (LaunchScreen.storyboard) | 起動 cue | 待ち時間 / brand recognition | (上流) | live |
| S4 | Onboarding | `FilmtoneOnboardingView` | mental model installation | canonical journey 4 step を最初に教える | journey foundation | live (要 rewrite) |
| S5 | Empty state | `FilmtoneEmptyView` | DL 後の first surface | 操作 entry-point + Saved Looks teaser | journey entry | live |
| S6 | Editor (fullscreen) | `FilmtoneFullscreenLutEditor` | 主要 grading surface | Look (hero) + Source (側) + Strength + Look Intensity + Preview + Export trigger | Look (hero) + Source meta | live (要 rewrite for hero/side 区別) |
| S7 | Look Browser (fullscreen modal) | `FilmtoneFullscreenLutEditor` 内 | Look 比較画面 | Built-in / Saved / Imported を section 分離して一覧 | Base Looks | live (要 rewrite for section 分離) |
| S8 | Adjust sheet | `FilmtoneStrengthSheet` | 微調整 | Trim section (Quick + Detail) + Finish Tools section + Recipe selector | Trim + Finish Tools | live (最大改修対象) |
| S9 | Source Profile sheet | `FilmtoneSourceProfileSheet` | source 正規化 | Source profile picker + Source LUT Intensity + Imported Source LUTs library | Trim sub-layer | live (要 rewrite for Trim 表現) |
| S10 | Library (in Look browser) | (S7 内に integrated) | Saved Looks + Imported Look LUTs 再利用 | source-independent retention | Look 配下 | live (要 section 分離) |
| S11 | Library (in Source Profile sheet) | (S9 内に integrated) | Imported Source LUTs 再利用 | source-dependent retention | Trim 配下 | live |
| S12 | Save Look sheet | `FilmtoneSavedLookSheet` | snapshot 命名 | テキスト入力のみ、context は parent から | (action sheet) | live |
| S13 | Export panel | `FilmtoneExportPanel` | 出力フロー | Ready / Running / Result + metric cards (Strength / Source / Optics) | journey exit | live |
| S14 | Result + Share | `FilmtoneExportPanel` (result state) + system share | 完了 + 拡散 | Save to Photos / Share / `.cube` export (Layer B) | journey exit | live |
| S15 | Help / Adjustment Help | `FilmtoneAdjustmentHelpSheet` | 学習補助 | popover or sheet-within-sheet で context preservation | learning | live (C1 修正対象 — UX bug) |
| S16 | HDR notice | `FilmtoneHdrPolicyNotice` | edge case | HDR PQ/HLG/wide-gamut の処理通知 + outcome | edge case | live |
| S17 | Toast | `FilmtoneRootChrome.FilmtoneToastView` | 操作 feedback | success / error / info の transient | feedback | live |
| S18 | Confirmation dialog | `.confirmationDialog` (system) | 破壊的 action 確認 | Delete LUT / Delete Saved Look | safety | live |
| S19 | Unsaved Export Prompt | `FilmtoneRootChrome.UnsavedExportPrompt` | edge case 救出 | 書き出し済 unsaved を保護 | safety | live |
| S20 | Settings | (現状なし) | 状態開示 | (deferred — 必要なら future plan) | optional | absent |
| S21 | About / Credits | (現状なし) | identity | (deferred) | optional | absent |

### § 10.2 surface presentation 階層

```
Root (FilmtoneRootView ZStack router)
├─ fullScreenCover(onboardingPresented)
│  └─ S4 FilmtoneOnboardingView
│
├─ Conditional: S5 FilmtoneEmptyView (source == nil)
│
├─ Conditional: S6 FilmtoneFullscreenLutEditor (source != nil)
│  ├─ ZStack overlay: S16 HDR notice (top)
│  ├─ ZStack overlay: chrome (bottom)
│  ├─ ZStack overlay: S17 Toast
│  └─ Embedded: S7 Look Browser (fullscreen modal alternative)
│
├─ sheet(sourceSheetPresented)
│  └─ S9 FilmtoneSourceProfileSheet
│     └─ Contains: S11 Imported Source LUTs strip
│
├─ sheet(advancedSheetPresented)
│  └─ S8 FilmtoneStrengthSheet
│     ├─ Section A: Trim (Quick + Detail + Recipe)
│     └─ Section B: Finish Tools (Glow / Texture / Lens / Motion)
│
├─ sheet(exportSheetPresented)
│  └─ S13 FilmtoneExportPanel → S14 Result+Share
│
├─ sheet(item: savedLookSheet)
│  └─ S12 FilmtoneSavedLookSheet
│
├─ S18 confirmationDialog (lutDelete / lookDelete)
│
└─ ZStack overlay (root level)
   ├─ S15 Adjustment Help popover (C1 修正後 popover or sheet-within-sheet)
   ├─ S17 Toast (viewport-level transient)
   └─ S19 Unsaved Export Prompt
```

---

## § 11 Per-Surface Information Design Rules

各 surface ごとの「**何を / いつ / どの密度で / どの形式で**」rule。実装 chat は本 section を直接 input として SwiftUI / FilmtoneStrings / fastlane metadata の修正を進める。

### § 11.1 S1 App Store listing

| 要素 | 文字数 cap | rule | content guideline |
|---|---|---|---|
| Name | 30 字 | canonical 用語 + Layer A hero noun | JA「Filmtone — Look を選んで書き出し」/ EN「Filmtone: iPhone Film Looks」 (marketing IA brief 既出案を base に refine) |
| Subtitle | 30 字 | Layer A action verb で完結 | JA「iPhoneでフィルム調に仕上げる」/ EN「Film Looks, local export」 |
| Promotional text | 170 字 | v1.4 highlights = Air/Dusk + .cube export + Pro Tool handoff の 3 文圧縮 | JA: Air/Dusk Pack 01 / Strength + Look Intensity / `.cube` + Sidecar export の 3 軸言及 |
| Description | 4000 字 | 5 section 構成 (下記 § 11.1.1) | — |
| Keywords | 100 byte | Layer A + Layer B + Pro term | Layer A: 写真加工, フィルター, Look / Layer B: Apple Log, pre-grade, DaVinci 連携 (lint 確認後) / Pro term: cube, sidecar, ProRes |
| Release notes | 4000 字 | v1.4 highlights = Air/Dusk + Camera Profile 拡張 (D-Log M / C-Log 3) + (.cube export 公開時に追記) | — |

#### § 11.1.1 Description 5 section 構成

```
[Section 1] Hook (Layer A 30 秒 ritual)
  - "撮ったあと数分で SNS に出せる仕上がり"
  - "Look を選び、Strength と Look Intensity を調整、書き出し"

[Section 2] Use case 列挙
  - 旅 / イベント / brand short / mood clip / product teaser
  - 写真と動画両方に対応

[Section 3] Pro workflow (Layer B / 軸 B)
  - Pre-grade for desktop NLE
  - `.cube` LUT export (dual-lane: Source Profile / Look / Combined)
  - Sidecar JSON for grading state reproduction
  - Apple Log / S-Log3 / V-Log / D-Log / C-Log Source Profile auto-detect
  - (DaVinci 単独名は lint 通過確認次第)

[Section 4] Physical IP (軸 C / tertiary trust)
  - 180° shutter physics motion blur
  - Halation / Bloom physics
  - Depth-aware grading
  - Source Color Metadata Normalizer

[Section 5] Privacy / 完全ローカル
  - No account, no cloud, no IAP
  - All processing on device
```

### § 11.2 S2 App Icon / S3 Launch screen

- 現状維持 (CD-provided symbol image / 現行 Liquid Glass design)
- 情報設計対象外 (visual design は § 13 guidance only)

### § 11.3 S4 Onboarding (4 step canonical journey)

| Step | canonical layer | Title (EN / JA) | Body (EN / JA) | image guidance |
|---|---|---|---|---|
| 1 | journey: Pick | "Pick a photo or video" / 「写真や動画を選ぶ」 | "Load your own media and Filmtone starts a film-look preview right away." / 「自分の素材を読み込むと、Look のプレビューがすぐ始まります。」 | iPhone + sample clip thumbnail |
| 2 | Look (= Base Look) | "Choose a Look" / 「Look を選んで世界観を決める」 | "Tap a built-in Look like Air or Dusk, or apply a Saved Look to start the world." / 「Air や Dusk のような Look をタップ、または保存した Look で世界観を決めます。」 | Look carousel UI snapshot |
| 3 | Finish Tools | "Add finish" / 「Finish Tools で signature を足す」 | "Tune Glow, Texture, Lens, and Motion to add the optical signature." / 「Glow、Texture、Lens、Motion で光学的な signature を足します。」 | Adjust sheet UI snapshot |
| 4 | Export (Layer A + Layer B) | "Save and share" / 「書き出して、共有する」 | "Export to Photos for sharing, or output `.cube` LUT and Sidecar JSON for desktop NLE." / 「Photos に書き出して共有、または `.cube` LUT を NLE に持ち出します。」 | Export panel + Files.app icon |

structure: 1 sentence body + 1 image。各 step の "Next" ボタン / 最終 step の "Pick media" CTA は現状維持。

### § 11.4 S5 Empty state

- **Hero**: app icon symbol (現状維持)
- **CTA primary**: "Pick from Photo Library" / 「写真ライブラリから選ぶ」
- **CTA secondary**: "Pick from Files" / 「ファイルから選ぶ」
- **Saved Looks teaser**: 1 件以上あれば下に horizontal strip (max 6 件、最近順)
- **subtitle (画面下小さく)**: "No account. No cloud. No IAP." / 「アカウント不要・クラウド不使用・課金なし」 (privacy 軸の常時可視化)

### § 11.5 S6 Editor (fullscreen)

- **Top chrome**: Source name (file name truncated) + Close button + (S16 HDR notice if applicable)
- **Center**: Preview (graded / original toggle / expand to fullscreen)
- **Bottom**: **Look carousel (hero)**
  - Section 1: Built-in (Air, Dusk)
  - Section 2: Saved Looks
  - Section 3: Imported Looks (.cube)
  - 横 scroll
- **Right side action button** (上から):
  - Adjust (= Trim + Finish Tools sheet を開く)
  - Source (= Source Profile sheet を開く)
  - Export (= Export panel を開く)
- **Slider** (Look carousel の上):
  - Strength (Look layer 全体の Recipe Strength)
  - Look Intensity (creative LUT のブレンド)
- **重要原則**: Look が **hero**、Source profile は side action button (Trim sub-layer 扱い)

### § 11.6 S7 Look Browser (fullscreen modal alternative)

- **Title**: "Look Browser" / 「Look ブラウザ」
- **Section 1**: Built-in (Air / Dusk) — 大きい thumbnail 2 件
- **Section 2**: Saved Looks — grid 表示、長押しで context menu (Apply / Rename / Delete / Favorite / Unfavorite)
- **Section 3**: Imported Looks (.cube) — 同様の grid + context menu (Apply / Rename / Delete)
- **Strength + Look Intensity slider**: 画面下、両 slider 同時表示 (現行 fullscreen と整合)
- **Apply 動作**: Look chip tap で即時適用 + toast "Look を適用しました：%@"
- **Save 動作**: 現行 grade を保存 (Save Look sheet 起動 → S12)

### § 11.7 S8 Adjust sheet (最大改修対象)

```
[Top] Header
  - Title: 現行 Look 名 / Recipe variant 名
  - Done / Default ボタン

[Top sliders]
  - Strength (Recipe 適用度 / 0–100%)
  - Look Intensity (Look LUT ブレンド / 0–100%)

[Section A: Trim]
  - Title: "Trim"
  - subtitle (small): "source correction"
  - [Quick group / 常時展開]
    - Exposure / Contrast / Saturation slider
  - [Detail group / disclosure]
    - Temperature / Tint / Highlights / Shadows / Fade slider
  - [Recipe group / chip selector]
    - Recipe variant chips: None / Default / Strong / Print Reference / Push / Vivid / Punch / Custom

[Section B: Finish Tools]
  - Title: "Finish Tools"
  - subtitle (small): "optical signature"
  - [Glow disclosure]
    - bloom_strength / bloom_threshold / bloom_radius / bloom_soft_knee
    - halation_intensity / halation_spread / halation_hue / halation_threshold / halation_radius / halation_soft_knee
  - [Texture disclosure]
    - grain_intensity / grain_size / grain_radial_mix
    - vignette
  - [Lens disclosure]
    - rgb_shift / lens_softness
  - [Motion disclosure]
    - shutter_angle / trail_intensity
  - (Mist / Cross は内部 param 状態で UI family 化を v1.5+ defer)

[Bottom] Help icon (各 group 横)
  - tap で S15 Adjustment Help popover (C1 修正版)
```

**削除 / 統合**:
- 旧 "Advanced > Basic / Process / Optics" の 3 group 名は **使わない** (canonical では Trim / Finish Tools の 2 section)
- 旧 `advancedParamsLabel` "Advanced Params" は **section name として使わない**
- Tone group の 3 重衝突 (`advancedPresetPrintLabel ja "階調"` / `advancedToneLabel ja "階調"` / `advancedProcessLabel ja "階調"`) は § 8 vocabulary lock 表で解消

### § 11.8 S9 Source Profile sheet

- **Title**: "Source" / 「ソース」
- **subtitle (small)**: "source normalization (Trim sub-layer)" / 「素材の正規化 (Trim sub-layer)」
- **Auto-detect badge**: Apple Log 等検出時に上部に表示 (現状維持)
- **Source profile picker**:
  - Auto / Apple Log / Apple Log 2 / S-Log3 / V-Log / D-Log / D-Log M / C-Log / C-Log 3 (Cinema Gamut) / Rec.709 / Custom (Import .cube)
- **Source LUT Intensity slider**: Imported source LUT 適用時のみ表示 (0–100%)
- **Imported Source LUTs strip** (S11): recent 6 件、長押しで context menu (Apply / Rename / Delete)
- **重要原則**: ここは **Trim sub-layer** であり、独立した hero 主張をしない (ヘッダ表現で位置付けを明示)

### § 11.9 S10 Library (in Look Browser)

- S7 Look Browser 内に integrated (現状維持)
- Saved Looks section + Imported Look LUTs section の 2 種を **明示分離**
- 各 section に header + count badge ("Saved Looks (12)" / "Imported (3)")
- 各 entry: thumbnail + name + favorite badge

### § 11.10 S11 Library (in Source Profile sheet)

- S9 Source Profile sheet 内に integrated (現状維持)
- Imported Source LUTs section のみ (Saved Looks / Imported Look LUTs は混入させない)
- 各 entry: name + camera profile target + source-dependent retention 表示
- 長押しで context menu (Apply / Rename / Delete)

### § 11.11 S12 Save Look sheet

- 現状維持 (NavigationStack with toolbar)
- Title: "Save Look" / 「Look を保存」 (mode: create) or "Rename Look" / 「Look の名前を変更」 (mode: rename)
- Body: テキスト入力のみ、placeholder "Look 名"
- Save / Cancel button

### § 11.12 S13 Export panel

- **Title**: "Export" / 「書き出し」
- **State machine**: Ready → Running → Result
  - Ready 状態: metric cards (Strength / Source Profile / Optics) + Export ボタン
  - Running 状態: progress bar + stage label (Preparing / Reading / Rendering / Writing / Completed)
  - Result 状態: file size / elapsed / Save to Photos ボタン / Share ボタン / (Layer B) `.cube` Export ボタン
- **重要**: Layer B 用の `.cube` LUT export ボタンは Result 状態でのみ visible (実装 chat で `.cube` export shipped 確認後)

### § 11.13 S14 Result + Share

- S13 Export panel の Result 状態に integrated
- system share sheet 経由で Photos / Files / AirDrop / iCloud Drive / Mail / Messages 等
- Layer B path: Files.app 経由で Mac NLE へ

### § 11.14 S15 Help / Adjustment Help (C1 修正対象)

- **C1 issue**: 現行は親 sheet を dismiss してから root overlay として popover 表示、戻る時に sheet を再表示する非標準 UX
- **修正方針** (実装 chat で適用):
  - **Option A**: `.popover(isPresented:)` で親 sheet を dismiss しない popover 表示 (推奨)
  - **Option B**: sheet-within-sheet で親 sheet の上に新 sheet をスタック
- **Content structure**:
  - "What changes" — この parameter / family が画像にもたらす変化を 1 sentence
  - "When to use" — どんな素材 / 場面で使うか 1 sentence
  - Before / After image (現状維持)

### § 11.15 S16 HDR notice

- **Title**: "HDR video loaded" / 「HDR 動画を読み込みました」
- **Body**: 1 sentence per case (PQ / HLG / wide-gamut unknown)
  - PQ: "Export will be SDR. Highlights may compress." / 「SDR で書き出します。ハイライトが圧縮される場合があります。」
  - HLG: "Export will be SDR. The HLG curve is preserved on input." / 「SDR で書き出します。HLG curve は入力時に保持されます。」
  - Wide-gamut unknown: "Wide gamut detected. Color may shift in export." / 「広色域を検出しました。書き出し時に色が変化することがあります。」
- 常駐 (現状維持)、recovery 不要なため info-only

### § 11.16 S17 Toast

- **success** (amber, 2.5s): "Saved to Photos" / 「写真に保存しました」 / "Export complete" / 「書き出し完了」 / "Look を適用しました：%@" / "Look を保存しました：%@"
- **error** (red, 4s): "Share failed — try again" / 「共有に失敗しました」 / "Look couldn't be saved." / 「Look を保存できませんでした」
- **info** (sky blue, 2s): (Source Profile auto-detected 等の transient 通知 — 現状未使用、将来使う場合のみ)

### § 11.17 S18 Confirmation dialog

- 破壊的 action のみ (Delete LUT / Delete Saved Look)
- system `.confirmationDialog` 利用 (現状維持)
- Title: "Delete LUT?" / "Delete Saved Look?"
- Body: action の **取り消し不可** を明示

### § 11.18 S19 Unsaved Export Prompt

- 書き出し済 / Photos 未保存状態で close 試行時に出現
- 現状維持

### § 11.19 S20 Settings / S21 About (deferred)

- 現状未実装。本 spec の scope 外
- 将来追加する場合は別 plan で本 spec を update

---

## § 12 Microcopy Derivation Rules

実装 chat 用の microcopy 生成 rule。具体的 string draft は実装 chat で展開。

### § 12.1 全 user-facing string で守る rule

1. **§ 8 vocabulary lock 整合** — display value は § 8 glossary table 通り
2. **ja/en intent parity** — 翻訳の正確性 ≥ 同 mental model 伝達。emotional/technical の bias を ja/en で揃える
3. **forbidden vocabulary 排除** — § 8.10 の包括リスト不使用
4. **canonical 5 promise の grammar** — § 5 の 5 文以外の promise を作らない
5. **brand voice surface rule** — § 6.1 surface 別 voice/tone に従う
6. **Apple App Store 文字数 cap** — name 30 / subtitle 30 / promo 170 / desc 4000 / keywords 100B / release_notes 4000

### § 12.2 fastlane metadata 専用 rule

7. **`scripts/check-filmtone-copy-quality.mjs` lint pass** — forbidden-claim / abstract-filler / obvious-premise / category-as-value / feature-list-copy / surface-without-role / app-store-limit すべて violation 0
8. **description 5 section 構成** — § 11.1.1 通り
9. **DaVinci 言及** — lint pattern 直接確認、NG なら "your color editor" / "your NLE" / "desktop NLE" 等で迂回 (T1 resolution)
10. **release_notes** — v1.4 highlight = Air/Dusk + Camera Profile 拡張 + (`.cube` export 公開時に追記)

### § 12.3 FilmtoneStrings 専用 rule

11. **key 据え置き / value 切替** — § 8 glossary の "内部 key" 列に従う。Profile schema / Capacitor bridge を跨ぐ key は据え置き
12. **新 key 追加** — § 7.1 の 3 層 hero label (`finishToolsLabel`, `trimLabel`, `finishToolGlowLabel`, `finishToolTextureLabel`, `finishToolLensLabel`, `finishToolMotionLabel` 等)
13. **Help copy 全面書き直し** — `helpLut*` を canonical mental model (`A Look chooses the world. Finish Tools add the signature.`) に整合
14. **Onboarding copy** — § 11.3 の 4 step table 通り

### § 12.4 SwiftUI view 専用 rule (実装 chat への補足)

15. **section name** は § 8 vocabulary lock の "Top-level layer 名" を採用
16. **internal enum / Swift type 名** rename は Capacitor bridge 跨がない範囲で許容 (例: `enum AdvancedSection` → `enum AdjustSection { trim, finishTools }` / `enum FinishToolFamily { glow, texture, lens, motion }` / `enum TrimGroup { quick, detail }`)

---

## § 13 Visual / Motion Design (guidance only)

本 spec の scope は **情報設計**。visual design / motion design は **現状維持** = `liquid-glass-ui-design-handoff-2026-05-01-jst.md` の Liquid Glass UI base 継承。

### § 13.1 Information hierarchy 原則

情報配置 (information hierarchy in layout) のみ canonical 整合:

| 要素 | 視覚 weight | 配置 |
|---|---|---|
| Look (carousel + thumbnail) | hero (大きい / 中央 / colorful preview) | Editor 下部 / Look Browser 全画面 |
| Strength + Look Intensity slider | primary slider (大きい) | Editor preview 下 / Adjust sheet 上部 |
| Adjust / Source / Export action button | secondary action (中サイズ) | Editor right side |
| Library entry (chip / strip) | tertiary entry (小さい) | Look Browser / Source Profile sheet 内 |
| Toast / HDR notice | transient information (overlay) | Root level |

### § 13.2 Motion / animation guidance

- Look chip tap → preview update: 即時 (< 100ms)
- Adjust sheet 開閉: 300ms ease-out
- Toast 表示 / 消失: 250ms fade
- Adjustment Help (C1 修正後): popover 200ms scale + fade

(具体的な animation tuning は visual design 担当の別 chat で。本 spec scope 外)

---

## § 14 Feedback & Recovery Information Design

### § 14.1 Toast policy

| 種別 | 色 | 持続時間 | content rule |
|---|---|---|---|
| success | amber | 2.5s auto-dismiss | 状態のみ 1 sentence |
| error | red | 4s auto-dismiss | state → recovery hint 1 sentence |
| info | sky blue | 2s auto-dismiss | 状態通知のみ |

### § 14.2 Error message 構造

**format**: `state → recovery in 1 sentence`

例:
- "Export couldn't be completed. Try again or pick another source." / 「書き出しに失敗しました。再試行するか別の素材を選んでください。」
- "Camera Profile import failed. The .cube file may be unsupported." / 「カメラプロファイルの読み込みに失敗しました。`.cube` ファイルが非対応の可能性があります。」
- "The LUT linked to this Look is no longer in the library. Re-import it to restore the look." / 「この Look に紐づく LUT がライブラリから削除されています。Look を復元するには再読み込みしてください。」

### § 14.3 HDR notice

- 常駐 (現状維持)
- recovery 不要 = **info-only**
- outcome 明示 ("Export will be SDR" 等)
- 詳細は § 11.15

### § 14.4 Unsaved Export Prompt

- 書き出し済 / Photos 未保存状態で Editor close 試行時に出現
- 現状維持
- Body: "Export complete. It has not been saved to Photos yet." / 「書き出しは完了しましたが、まだ写真に保存されていません。」
- Action: Save to Photos / Share / Discard

### § 14.5 Confirmation dialog

- 破壊的 action のみ (Delete LUT / Delete Saved Look)
- system `.confirmationDialog`
- 取り消し不可を明示

---

## § 15 Continuity (cross-surface state preservation)

### § 15.1 Look + Strength + Look Intensity の全 surface 表示

- **Editor**: Look chip 強調 / Strength + Look Intensity slider 常時可視
- **Adjust sheet**: 上部に Strength + Look Intensity slider (Editor と同一 control / 同一 label)
- **Look Browser**: Strength + Look Intensity slider 画面下に常駐
- **Export panel**: metric card に Look 名 / Strength % / Source Profile 名を表示
- **Continuity 原則**: 同 control が surface を跨いで同一 label / 同一 value で見える

### § 15.2 Source profile auto-detect

- **Editor 起動時 (J5)**: top に banner で 1 度通知 ("Apple Log detected" / 「Apple Log を検出しました」)
- **Adjust sheet 内**: metric card で permanent 表示 (Source Profile 名)
- **Export panel**: metric card で permanent 表示
- **Continuity 原則**: auto-detect の事実が **silently 失われない** (banner → metric card 移行で永続化)

### § 15.3 Saved Look apply

- toast で「Look を適用しました：%@」(`lookAppliedToastFormat` 既出)
- Editor の Look chip が highlight
- Strength + Look Intensity が Saved Look の保存値に reset

### § 15.4 Adjustment Help context 連続化 (C1 修正対象)

- 現行: 親 sheet を dismiss してから root overlay 表示、戻る時に sheet を再表示
- 修正後: popover or sheet-within-sheet で親 sheet を保持
- **Continuity 原則**: 学習動作が **作業中の context を破壊しない**

### § 15.5 Session 間の continuity (defer)

- 同一 session 内: 上記 § 15.1〜15.4
- session 跨ぎ (アプリ再起動後): 現行は Saved Looks / Imported LUTs / Profile 状態が persist (CoreData / FileManager 経由)
- どこまで persist させるかの設計は本 spec scope 外、現状維持

---

## § 16 Measurement (情報設計が機能しているかの計測経路)

### § 16.1 short-term proxy (App Store 側)

- **App Store conversion** (impression → install) の v1.3 vs v1.4 比較
- **App Store rating** の v1.3 vs v1.4 比較 (4.5 ↔ 4.7 等)
- **App Store keyword 流入**: "iPhone DaVinci 連携" / "Apple Log iPhone 編集" / "LUT export iPhone" / "pre-grade mobile" の流入計測

### § 16.2 in-app proxy (実装 chat / instrumentation 別 plan)

- **Onboarding 完走率**: 4 step 全部見たか / どこで skip
- **Empty state からの first source pick までの時間**: 30 秒 ritual の実態計測
- **First export 到達率**: J7 まで到達した user 割合
- **Saved Look 作成率**: J8 reach signal (Layer B 寄り)
- **`.cube` export 利用率**: Layer B reach signal (実装 chat で `.cube` export shipped 後)
- **Adjust sheet 開封率 vs Layer A 直 export 率**: Layer A vs Layer B 比率

### § 16.3 qualitative

- TestFlight β 経由の user feedback (CD レビュー)
- App Store review 内容分析 (語彙 / mental model / 期待 vs 実際の gap)
- SNS posts における Filmtone hashtag 使用例 (Layer A 用法)

### § 16.4 measurement instrumentation

具体的な instrumentation 実装 (Firebase / TelemetryDeck / 自前 logging) は **本 spec scope 外**。実装 chat でも別 plan として扱う。

---

## § Appendix A: Existing Implementation Audit

本 spec の元になった現行実装の IA 不整合一覧。実装 chat はこの appendix を直接 backlog として展開し、それぞれを spec 対応箇所に整合させる。

| # | Issue | Severity | 対応 spec section | 対応 file (実装 chat) |
|---|---|---|---|---|
| A1 | Canonical taxonomy 不適用 — top-level surface に `Base Looks / Finish Tools / Trim` の 3 層が出ていない。Camera Profile が hero として top-level に出ている。Mist / Cross / Texture が UI family 名として出ていない | 🚨 Critical | § 7, § 10, § 11.5, § 11.7, § 11.8 | `FilmtoneFullscreenLutEditor.swift`, `FilmtoneStrengthSheet.swift`, `FilmtoneSourceProfileSheet.swift` |
| A2 | Strength 4 重命名 — `strengthLabel` / `fullscreenStrengthLabel` / `lookLutAmountLabel` / `inputLutAmountLabel` が同種スライダーに 4 つ違うラベル | 🚨 Critical | § 8.8 | `FilmtoneStrings.swift` |
| A3 | Look ↔ LUT 用語崩壊 — `lookLabel` / `lookFilmtone` / `lookCustom` / `lookImport` / `builtInLook*` / `librarySavedLooks*` / `fullscreenTitle = LUT ブラウザ` で 1 概念が 5 名前 | 🔴 High | § 8.2, § 11.6 | `FilmtoneStrings.swift` |
| A4 | Save 動詞過負荷 — `exportAndSave` / `lookSaveCurrentMenu` / `saveToPhotos` / `cameraImport` (LUT を library に save) が全部「保存/Save」に見える | 🔴 High | § 8.9 | `FilmtoneStrings.swift` |
| A5 | Preset 二重定義 — Advanced 配下に "Preset" (Default/Strong/Print/Push/Vivid/Punch) と "Tone Preset" (Standard/Airy/Sunset/Depth) が並列。`advancedPresetPrintLabel` ja "階調" は `advancedToneLabel` ja "階調" と完全衝突 | 🔴 High | § 8.6, § 8.7 | `FilmtoneStrings.swift` |
| A6 | Quick ↔ Advanced 同一パラメータ二重命名 — Quick (`quickFilmCharacter`/`quickEra`/`quickDynamics`、UI: Exposure/Contrast/Saturation) は Advanced Basic と同 parameter | 🔴 High | § 8.5 | `FilmtoneStrings.swift` |
| A7 | Stone/Urban naming forbidden — Doc 1 で forbidden、CD direction Air/Dusk 確定 (T3) | 🟡 Medium | § 0 T3, § 8.2 | `FilmtoneStrings.swift` (display value のみ) |
| A8 | Adjustment Help UX — 親 sheet を dismiss してから root overlay として出る non-standard pattern | 🟡 Medium | § 11.14, § 15.4 | `FilmtoneAdjustmentHelpSheet.swift`, `FilmtoneRootView.swift` |
| A9 | Library 種別混合 — Input LUT (camera-dependent) と Saved Look (creative, source-independent) が同じ strip / 同じ action menu を共有 | 🟡 Medium | § 7.2, § 11.9, § 11.10 | `FilmtoneSourceProfileSheet.swift`, `FilmtoneFullscreenLutEditor.swift` |
| A10 | App Store metadata の positioning gap — Axis B (Pro Tool bridge) 未導入、Stone/Urban を Pack 01 hero として promo に出している、canonical 用語 unused | 🟡 Medium | § 4, § 11.1, § 11.1.1 | `fastlane/metadata/{ja,en-US}/*.txt` |

---

## § Appendix B: 不変条件 (尊重必須)

`apps/capacitor-film-lab-ios/CLAUDE.md` から継承。実装 chat はこれらを **絶対に触らない**:

| 項目 | 値 | 理由 |
|---|---|---|
| Profile.version | 5 (immutable) | schema 不変、変更時は CD + sidecar reader 同時調整必須 |
| Sidecar V1 schema | field 追加 OK / type 変更 = V2 (未着手) | 既存 field rename 不可 |
| hiddenDefaults | 19 keys 固定 | parameter 追加 / 削除しない |
| Built-in catalog UUID | Pack 01 Stone (`FB1A...000006`) / Urban (`FB1A...000007`) | UUID 据え置き、display name のみ Air/Dusk |
| bundleSlug | `filmtone-creative-pack-01-stone/urban` | 据え置き (永久 leak、 Pack 01 naming doc § 7) |
| Capacitor bridge | 8 method 名固定 (pickSource / pickLutFile / probeSource / renderPreviewFrame / runExport / saveToPhotos / shareOutput / cancelExport / handleMemoryWarning) | 内部 API 名変更不可 |
| Profile JSON keys | bloom_strength 等の internal key | UI label のみ canonical 用語、内部 key 不変 |
| .cube file 名 | 据え置き | bundle 内 asset、識別子 leak |
| Snapshot device | iPhone 17 Pro Max iOS 26.2 | fastlane hardcoded |
| Info.plist NSPhotoLibrary* / NSSupportsLiveActivities / ITSAppUsesNonExemptEncryption | 据え置き | ASC audit 直接対象 |

→ **「display = canonical / internal = 据え置き」の 2 層運用** を全 phase で死守

---

## § Appendix C: 参照 doc map

### 上流 canonical (本 spec が引用 / specialise する)

| # | path | 役割 | この spec との関係 |
|---|---|---|---|
| C1 | `/Volumes/SamsungPortableSSDX5001/documents/life/.claude/knowledge/patterns/2026-04-02-filmtone-product-intent-canonical.md` | product intent canonical | 矛盾時の優先順 #2 |
| C2 | `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/filmtone-persona-canonical.md` | persona base | § 1 / § 6 で継承 / ポジショニングステートメントは T2 で iOS context override |
| C3 | `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md` | canonical 3 層 IA + LP grammar | § 5 / § 7 / § 8 で iOS specialise |
| C4 | `docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-marketing-ia-aso-lp-brief-2026-04-30-jst.md` | surface roles, vocabulary lock, claim matrix | § 4 / § 6.2 / § 11.1 で継承 |
| C5 | `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md` | Axis A/B/C / Pro Tool bridge thesis | § 4 で継承 / T1 で resolution |
| C6 | `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-naming-persona-handoff-2026-05-01-jst.md` | Pack 01 命名 persona 3 層 | § 1 / T3 で Air/Dusk final lock |
| C7 | `apps/capacitor-film-lab-ios/CLAUDE.md` | iOS 不変条件 | Appendix B で継承 |
| C8 | `packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md` | Finish Tools family 名 SSoT | § 7.1 / § 8.3 で継承 |

### 関連 implementation handoff (本 spec から見ると参考 / 補完)

| # | path | 役割 |
|---|---|---|
| D1 | `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/liquid-glass-ui-design-handoff-2026-05-01-jst.md` | Liquid Glass UI base / 視覚 design SSoT |
| D2 | `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/empty-view-redesign-final-handoff-2026-05-01-jst.md` | Empty state surface 状態 |
| D3 | `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-v1.1-release-handoff-2026-04-25-jst.md` | v1.1 surface 変更履歴 |
| D4 | `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-stone-urban-refinement-handoff-2026-05-01-jst.md` | Pack 01 実装状態 (cube / 光学パッチ / sidecar / pbxproj) |
| D5 | `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/2026-05-02-ios-source-profile-dlog-clog-handoff-jst.md` | D-Log / C-Log / D-Log M / C-Log 3 source profile 拡張 |
| D6 | `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/quality-mezzanine-cache-handoff-2026-05-02-jst.md` | Mezzanine 出力品質 |
| D7 | `docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-effect-terminology-alignment-handoff-2026-04-26-jst.md` | Effect terminology alignment |
| D8 | `docs/filmtone/filmtone-copy-quality-harness.md` | check:filmtone-copy lint 仕様 |

### iOS truth gate

- `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh` — release truth 整合確認
- `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh` — release 整合確認

---

## 次 chat (実装 chat) への handoff

本 spec を input として、以下を順に実施する別 chat を開く:

### 実装 phase 1: 上流 canonical への pointer 追加 (軽量)

以下の 5 doc 末尾に「iOS 適用は本 spec doc 参照」の 1 行 pointer を追加:

- `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/filmtone-persona-canonical.md`
- `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`
- `docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-marketing-ia-aso-lp-brief-2026-04-30-jst.md`
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md`
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-naming-persona-handoff-2026-05-01-jst.md`

### 実装 phase 2: FilmtoneStrings.swift 全面再編

- 本 spec § 8 vocabulary lock table に従って display value を全置換
- key 据え置き (Capacitor bridge / Profile schema を跨ぐ key)
- Stone → Air / Urban → Dusk display 切替
- Tone group 3 重衝突解消 (`階調` → `プリント基準` / `色トーン` / `階調処理`)
- 新 key 追加 (`finishToolsLabel`, `trimLabel`, `finishToolGlowLabel` 等)
- `bun run generate:ios-swift --check` で contract drift 確認

### 実装 phase 3: SwiftUI surface 再構成

- 本 spec § 11 per-surface rule に従って各 view を rewrite
- `FilmtoneStrengthSheet` を Trim section + Finish Tools section に再構成 (最大改修)
- `FilmtoneSourceProfileSheet` を Trim sub-layer 表現に整合
- `FilmtoneFullscreenLutEditor` を Look hero + Source side button に整合
- `FilmtoneAdjustmentHelpSheet` を popover or sheet-within-sheet 化 (C1 修正)
- `FilmtoneOnboardingView` を 4 step canonical journey に整合
- 内部 enum / Swift type 名 rename (Capacitor bridge 跨がない範囲)

### 実装 phase 4: fastlane metadata 全面 rewrite

- 本 spec § 11.1 / § 11.1.1 に従って 5 section description rewrite
- canonical 用語 + Axis A+B 構造
- forbidden vocabulary 排除
- DaVinci 言及は lint pattern 直接確認、迂回必要なら "your color editor" 等
- Stone/Urban → Air/Dusk
- 文字数 cap 守る

### 実装 phase 5: verify

```bash
bun run check:filmtone-copy
bun run verify:ios
bun run generate:ios-swift --check
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

実機 / Simulator UI walkthrough で全 surface canonical layer 整合確認

### 実装 phase 6: worktree finalize + CD signoff

- `.claude/worktrees/ia-canonical-2026-05-02` で完結
- v1.4 metadata release rail との整合 (recent commit `7a2e1d1` 参照)
- merge は user 判断 (Git 操作は user)
