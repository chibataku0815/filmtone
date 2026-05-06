# Filmtone iOS Creative LUT Pack 01 — ペルソナ整理 と 命名探索 (中間)

Date: 2026-05-01 JST
Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
Branch: `main` (`origin/main` ahead 1 — `95b6321 Add Stone and Urban creative LUTs`)
Status: **命名は確定していない**。CD 発言「Air / Dusk はよくはなってきている」に対応する **方向確認段階** のスナップショット。

## 0. この doc の目的

Pack 01 (`Stone` / `Urban` 仮置き) の **正式名称議論** を進めるための前提整理を凍結する
ためのもの。次 chat が persona 議論を再走しないで済むように、

- 想定ユーザーの 3 層構造 (一次／二次／signoff)
- 各層が Look 名に何を求めるか
- これまでの命名失敗パターン 3 件と教訓
- 現在の候補ペア `Air / Dusk` と CD 評価 (「よくはなってきている」= 方向 OK、最終 NG なし)
- 確定していない事項

を ssot で記す。Pack 01 の **実装状態** (cube / 光学パッチ / sidecar / pbxproj) は別 doc
`creative-lut-pack-01-stone-urban-refinement-handoff-2026-05-01-jst.md` に既出のため
本 doc では繰り返さない。両 doc は補完関係。

## 1. ペルソナ (3 層)

ソース:
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md` §5.2
- `docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-marketing-ia-aso-lp-brief-2026-04-30-jst.md` §Positioning Spine
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-quality-iteration-handoff-2026-05-01-jst.md` §1

### 1.1 Layer A — iPhone snapshot ritual user (一次 / hero)

- 行動: 撮ったあと **30 秒以内** に SNS (Reels / TikTok / IG Story) または Photos へ
- 競合空間: VSCO / Dazz / Filmm
- App Store subtitle (現候補): JA「iPhoneでフィルム調に仕上げる」/ EN "Film looks, local export"
- 関心: 即時性、tribe identity、tap 前に意味が立つラベル
- 知識前提: LUT / Reference / Density / Log といった pro 語彙は **読まない**
- Look chip を選ぶ瞬間の語彙: 「いつものやつ」「街っぽい」「夕方っぽい」「人物に合うやつ」

### 1.2 Layer B — Pro tool bridge user (二次 / 競合不在カテゴリ)

- 行動: iPhone で pre-grade → sidecar JSON / `.cube` export → DaVinci / Premiere / FCP で finish
- App Store subtitle 候補 (新規ライン): JA「iPhoneで下地を、DaVinciで仕上げを」/ EN "Pre-grade on iPhone. Finish in DaVinci."
- 関心: 色再現性、sidecar スキーマ、`.cube` export、Apple Log pass-through、ProRes 422 出力
- Look 名前への関心は **薄い** — 機能 / `bundledSlug` / sidecar が機械可読なら命名は何でもよい
- 一次 ASO カテゴリでは **ない**、ただし v1.3 以降 description 構成案 (§7.3) で軸 B として明示される

### 1.3 Layer C — CD = chibatakumi (signoff)

- "色は CD signoff 必須" (quality-iteration handoff §1)
- Palermo Powergrade 所有者、film vocabulary に深く慣れている
- 多分野プロ (`life/CLAUDE.md` §1 の 5 つの顔)
- 凡庸禁止 / descriptive stack 禁止 / placeholder 名 (Stone / Urban) 定着禁止 を発令する人
- Filmtone Reference Density 系冗長名は明示却下済 (refinement handoff §"Pitfalls" #5)

## 2. Look 名前への要求差分

| 層 | 名前への期待 | NG |
|---|---|---|
| A (hero) | 1 単語で mood が立つ。tap 前に意味が読める | 専門/古語 (Plate, Quay) / 機能名 (Reference, Density) |
| B | 雰囲気名でも実害なし、`bundledSlug` 機械可読なら OK | 機能名が UI に出ること自体は許容 |
| C | film 文化整合、pair として筋が通る、placeholder 感ゼロ | 凡庸 / descriptive stack / 説明的 |

優先順位: **A 一次 → C 不可侵 → B 許容**。
A に届かない名前は採用しない。C を侮辱する名前も採用しない。B は実害 free 帯。

## 3. これまでの命名失敗パターン

### 3.1 (a) `Tungsten Bloom / Window Diffusion / Vintage Haze / Golden Halation` (4 Look pack 時代)

- パターン: `[scene/mood] [Filmtone lens-filter signature]` 二語複合
- CD 評価: 「意味不明」(quality-iteration handoff §11 self-critique)
- 失敗診断: scene 部分が広すぎ (Tungsten = 全 tungsten シーン)、 mood lock が解除された。
  Layer A が「自分のシーンに当てはまるか」即時判断できなかった
- 教訓: scene 名は具体度を上げないと機能しない。lens-signature を後ろに付けると 2 単語化して読み速度が落ちる

### 3.2 (b) `Stone / Urban` (現状仮置き)

- CD 評価: 「全然 stone じゃねーわ / 仮置きで Stone でいいです」「Urban でいいです / 名称は別途考えます」
- 失敗診断: 物質名 (Stone) を **対象が物質に見えない** Look に当てた。Urban は説明語すぎ
- 教訓: 物質名は対象が本当にその物質に見える時のみ。地理/環境語は具体度ゼロのとき placeholder 感が抜けない

### 3.3 (c) `Plate / Slate / Mortar / Quay` (本 chat 私の初稿)

- CD 評価: 「ダメですね、想定ユーザーやペルソナを説明してください」
- 失敗診断: Layer C 寄りの film 文化語彙 (写真乾板・港の石岸) で組み立てた。Layer A の 20-30 代
  SNS ユーザーが意味を即取れない。**ペルソナ最上位 (A) を脳内に置いていなかった**
- 教訓: Pack 01 は Look chip strip 最前面 = Layer A の判断ハンドル。CD 寄りの文化語彙は二次

## 4. 命名軸 3 候補

| 軸 | Reference base | Density 派生 | 評価 |
|---|---|---|---|
| **α 大気** ★ | **Air** | **Dusk** | Layer A 即時 mood / Layer C 拒否しない / pair 対称 (朝-夕、軽-重、開-閉) |
| β 写真用語 | Print | Press | Layer C 強、Layer A は学習負荷 / 頭韻 Pr- が child っぽい |
| γ 静謐-厚み | Calm | Dense | 両方とも一般形容詞、固有名感が弱い |

## 5. 現在の候補ペア — `Air` / `Dusk`

CD 発言 (2026-05-01):
> Air / Dusk はよくはなってきていると思います

→ **方向 OK、最終確定なし**。次の精度上げ余地が残っている前提で記録する。

### 5.1 意味の anchor

- **Air**: 透明・開けた・軽い。Palermo Reference の clean な film tone に翻訳される
- **Dusk**: 夕暮れ・密度・わずかに冷たい。Palermo Green Density (緑寄せ + 高彩度密度) の冷たい厚みに乗る
- Pair の対称: 朝-夕、軽-重、開-閉

### 5.2 ペルソナ通過確認

| 層 | Air / Dusk への反応 |
|---|---|
| A | 1 単語で mood 立つ ✓ / SNS で「Dusk で撮った」と引用しやすい ✓ |
| B | 害なし ✓ |
| C | 「よくはなってきている」 ✓ (= 方向 OK) |

### 5.3 既知の弱点 / iteration 余地

- 時間軸命名 (`A1 Dusk` 系) は VSCO / Lightroom プリセット界隈で **食傷気味**。差別化の弱さは残る
- `Dusk` は写真界で多用される語、Filmtone 固有性が薄い
- `Air` は意味が広すぎ、密度の弱い名前
- 上記により **CD は「よくなっている」止まりで「決定」とは言っていない** 可能性が高い

## 6. 確定していない事項

1. ペアそのものを `Air / Dusk` で確定するか、別軸 (場所軸 / 時間軸別取り / film stock 抽象化) を試すか
2. 1 単語のままで行くか、Filmtone 固有性を出すために 2 単語化を許容するか (例 `Open Air` / `Late Dusk`)
3. JA ローカライズを `エア` / `ダスク` カタカナにするか、`大気` / `黄昏` 漢字にするか、英語のまま `Air` / `Dusk` にするか
   - chip 表示は短さが効く。カタカナはミニマム情報量、漢字は意味の重さが乗る
4. Pack 02 以降の命名軸との整合 (Pack 01 が大気軸なら Pack 02 は ?)。命名軸ファミリーは決定先送り可

## 7. 触らないもの (再確認)

- slug `filmtone-creative-pack-01-stone` / `filmtone-creative-pack-01-urban` (識別子は naming と独立、永久 leak される)
- canonical UUID `FB1A...000006` / `FB1A...000007`
- cube SHA-256 (`005972...` / `9620...`)
- Pack 01 を 1 本に畳まない
- `FilmtonePhase0Generated.swift` の手編集禁止
- 仮 `Stone` / `Urban` を最終名と前提する記述

## 8. 次 chat の action 順 (命名確定編)

1. 本 doc + refinement handoff (`creative-lut-pack-01-stone-urban-refinement-handoff-2026-05-01-jst.md`) の 2 件を全文読む
2. CD に確認する 4 点 (§6 の 1〜4)。優先は §6.1 (`Air / Dusk` で確定 vs 別軸再提示)
3. 確定したら 4 ファイルを一括更新:
   - `packages/film-lab-core/src/creative-pack-01.ts` の `englishName`
   - `packages/film-lab-core/src/creative-pack-01.test.ts` の display name expectation
   - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift` の `englishName`
   - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift` のローカライズ (ja/en defaultValue)
4. 検証:
   ```sh
   bun test packages/film-lab-core/src/creative-pack-01.test.ts
   bun run build:core
   bun run verify:ios
   bun run check:filmtone-copy
   git diff --check
   ```
5. ASO/LP メタデータの該当箇所 (`messages/{en,ja}.json` 周辺、portfolio repo の satellite LP) は
   **同 PR では触らない** — 公開前に CD signoff を再度通す
6. handoff は本 doc を更新するか、確定 doc に切り出すかを決める

## 9. 参考 doc 一覧 (本件で読むべき順)

1. `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-stone-urban-refinement-handoff-2026-05-01-jst.md`
   — 実装状態 (cube / 光学パッチ / sidecar / pbxproj)
2. 本 doc — ペルソナ + 命名軸 + 現候補
3. `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md`
   — Pro Tool bridge 戦略への転換、軸 A/B/C コピー
4. `docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-marketing-ia-aso-lp-brief-2026-04-30-jst.md`
   — ASO/LP 言葉遣い規約、避ける語彙
5. `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-quality-iteration-handoff-2026-05-01-jst.md`
   — 過去 4 Look pack 時代の失敗、self-critique
