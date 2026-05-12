---
name: filmtone-release-articles
description: Filmtone Desktop / iOS リリース記事を 5 媒体 × JP/EN マトリクスで生成・改稿するためのスキル。認知ゼロ前提・truth gate 連動・媒体別 TOC ポリシー・禁忌語チェックを内包。
trigger: Filmtone のリリース記事を作成・改稿・proofread する時、または「リリース記事を 7 本書く / 媒体別に展開する」と user が指示した時。
---

# Filmtone Release Articles Skill

Filmtone (iPhone / Mac の動画色アプリ) のリリース記事を、複数媒体 × JP/EN で書くための運用スキル。

---

## 0. 大前提 (毎回上書きされる思考の出発点)

**Filmtone の認知はほぼゼロ**。既存ユーザー向けの release 告知として書かない。「Filmtone を初めて目にする読者に、product 自体を discover してもらいながら、たまたま今 release があるから具体例として更新内容を読んでもらう」スタンス。

**candidate / public の二相性**。記事は基本 candidate として書く。公開状態は必ず life の truth scripts で確認してからしか主張しない:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

doc と script が食い違ったら script を信頼 (`feedback_verify_before_documenting`)。

**本質優先・外殻最小**。記事品質は本質。formal QA workflow / 過剰 i18n / 飾り banner は外殻、user が QA 希望と明示しない限り入れない。保守的ヘッジ (「念のため fallback」「v1.x 後回し」) は採用しない。

---

## 1. 媒体マトリクス

| ID | 媒体 | 言語 | 性格 | TOC | ファイル名規約 |
|----|------|------|------|------|----------------|
| `note` | note.com | JP | 統合・narrative | エディタの「目次」block (H2/H3 拾う、自動採番なし → H2 に手動 `1.` `2.` 付与) | `note-ja.md` |
| `zenn` | Zenn | JP | 技術メモ | 右サイドバー自動 (H2/H3) → 手動 TOC 書かない | `zenn-ja.md` |
| `medium` | Medium | EN | product / design narrative | TOC なし → H2 を self-contained に | `medium-en.md` |
| `hashnode` | Hashnode | EN | 技術 implementation note | Article Settings で auto TOC ON → 手動 TOC 書かない | `hashnode-en.md` |
| `behance` | Behance | EN | visual case study | TOC widget なし、scroll-based。H2 は production checkpoint (Cover / Project Summary / Problem / Design Direction / Visual System Notes / Case Study Copy / Asset Checklist / Publish Guard)。**rename / 採番禁止** | `behance-case.md` |
| `x-long` | X (Twitter) Article | JP/EN | long-form, follow 層向け | TOC なし。本文に「## 目次」を書かない | `{platform}-{version}-x-article-{ja\|en}.md` |
| `desktop-note` / `ios-note` | プラットフォーム単独の note 記事 | JP | 1 platform 集中 | `note` と同じ | `desktop-v{X.Y}-article-jp.md` / `ios-{X.Y}-x-article-jp.md` |

**書く時の標準セット**: 1 release につき note-ja / zenn-ja / medium-en / hashnode-en / behance-case が basic。X long-form と platform 単独記事は追加。

---

## 2. 媒体別ターゲットと読書メリット (記事を書く前に決める)

毎回 release ごとに、各記事の "誰が読む / 何を得る" を Copy Brief として明文化する。テンプレは次の表。**Filmtone 認知ゼロ前提**で書く。

| 媒体 | 対象読者 (認知ゼロ) | 読むと得られるもの |
|------|--------------------|-------------------|
| `note` (統合) | iPhone / Mac で撮った動画の色をどうにかしたい JP creator / 写真出身者 / Adobe Rush / Filmic Pro / VSCO Cinematic に物足りなさを感じている人 / DaVinci を諦めた人 | Filmtone の道具立て (Look pack + Optics + MP4 書き出し)、product premise、release の具体例、公開後の試行手順、shared core + native runtime の架構 |
| `desktop-note` | Final Cut / iMovie / Premiere ユーザーで色だけ別アプリで扱いたい人、DaVinci の color page だけ使いたかった人 | Filmtone Desktop = Mac native の動画色 / MP4 書き出し専用 product。LUT pack 文化への入口。output trust の厳しさ |
| `ios-note` / `x-long` (JP iOS) | creator follow 層 (X 経由) / Filmic Pro / LumaFusion / VN / CapCut に色工程の物足りなさある JP user | Filmtone iOS = iPhone 1 台で撮影 → 色 → 書き出し → 共有完結。中継アプリとしての位置づけ。native quality の signal |
| `zenn` | AVFoundation / Metal / SwiftUI / Capacitor / cross-platform color pipeline 関心 JP エンジニア | shared TS core + native runtime 構成、completed-file validation pattern、amplitude-gated bilateral detail layer の placement、runtime-only bias の architecture |
| `medium` | international product designers / indie tool builders / Linear・Things・Arc Browser のような small-release-strong-opinion 物語が好きな層 | Filmtone の international discovery、design premise ("you do not pick a color from imagination")、portability を design constraint として扱う発想 |
| `hashnode` | international iOS/macOS engineers / cross-platform tool builders / WebGPU / Capacitor / native hybrid 関心 | "validate finished file" pattern、edge-aware detail layer placement、native runtime ≠ forking color truth の責務分割 |
| `behance` | international visual designers / motion designers / art directors / mobile-first creative tool に visual interest ある人 | Filmtone の visual identity discovery、"a release without adding a single new screen" の minimalist 事例、portability の visual case |

決めたら、各記事冒頭の「Copy Brief」セクションに Primary reader / Moment / Unresolved feeling / Next action / Not for / Claim class / Source evidence / Reversibility buffer を書き出す (Desktop 記事に既存例あり)。

---

## 3. 共通構造 (Filmtone discovery → premise → release content)

**毎記事の最初の 2-3 段落**で、認知ゼロ読者に対して順に開示:

1. **Filmtone が何をするアプリか** (動画の色味を整えて MP4 として書き出す / iPhone と Mac 両方で動く)
2. **product premise** (色は撮った素材を見ながら作る、思いつきで当てるのではない)
3. **その上で次の更新を語る**

これを破ると "release announcement to existing users" になり致命的に miscalibrated。

### 3.0 固有名詞の導入ルール (最重要)

**Filmtone definition (冒頭 2-3 段落) では、社内固有名詞を未知のまま並べない**。これは認知ゼロ前提の必須帰結。

- **冒頭で出さない固有名詞**: `Stone`, `Urban Creative`, `Look pack`, `Optics`, `curve`, `grade`, `LUT pack`, `Lens Softness`, `Texture Softness`, `source detail bias`
- **user-facing で一切使わない (本文どこでも禁止)**: `Preset` / `プリセット`。Filmtone の UI から Preset 概念は消えた。curve / grade 土台にあたるものも bundled Look として `Look` の中に並ぶので、記事側も常に `Look` に統一する。`Preset (色の土台になる curve / grade のセット)` 風の説明的導入もしない (概念を再導入することになる)
- **冒頭で出していい一般語**: 動画 / 色味 / 雰囲気 / フィルム調 / 街っぽい雰囲気 / シャープさ / 肌のトーン / 暗部 / MP4 / 書き出し / iPhone / Mac
- **本文での導入**: 固有名詞は本文の初出時に「これは XX のこと」と一文で説明してから使う。例:
  - 「`Stone` という名前で用意されているフィルム系の `Look`」
  - 「`Optics` (画の細部を扱うパネル)」
  - 「`Texture Softness` (画面全体ではなく細かい輪郭だけを少し弱める調整)」

例外: 技術媒体 (zenn / hashnode) では、`WebGPU` / `WebGL` / `AVFoundation` / `SwiftUI` / `TypeScript` / `native macOS app` のような業界一般語は冒頭で使ってよい (技術読者の前提知識)。社内固有名詞だけ §3.0 ルールに従う。

### 3.1 Filmtone definition テンプレ (2 文 short version + tail placeholder)

**設計**: 冒頭は 2 文だけで「何をするアプリか」を言い切る。premise や workflow の説明は冒頭に詰め込まない (本文で例とともに示す)。後半の `{release-specific tail}` は release ごとに書き換え、その release で重視する側面と本文を意味的にシンクさせる。

**tail の書き方**: その release のテーマを 1 フレーズで集約。冒頭で固有名詞を出さないので、tail も一般語で書く (今回 release は Texture Softness + 音声 → `質感のある動画として` / `texture and audio intact`)。次 release では別フレーズ (例: `肌のトーンが沈まない動画として` / `with skin tones that hold up`) に差し替える。

**JP base (note / X long-form / 統合)**:

```
Filmtone は、iPhone と Mac で動画の色味を整えるためのアプリです。スマホやカメラで撮った動画を読み込んで、{release-specific tail} 書き出します。
```

**JP Desktop 専用**:

```
Filmtone は、iPhone と Mac で動画の色味を整えるためのアプリです。Mac 側 (Filmtone Desktop) は、撮った動画を Mac に取り込んで、{release-specific tail} 書き出します。
```

**JP iOS 専用**:

```
Filmtone は、iPhone と Mac で動画の色味を整えるためのアプリです。iPhone 側 (Filmtone iOS) は、撮影、色の調整、{release-specific tail} 書き出しまでを、1 台の iPhone の中で進められます。
```

**JP 技術 (zenn)**:

冒頭 2 文は base と同じ。直後に技術段落 (native Swift runtime + shared TS color core) を 1 段落だけ足す。

```
Filmtone は、iPhone (iOS) と Mac (macOS) で動画の色味を整えるアプリです。撮った動画を読み込んで、{release-specific tail} 書き出します。

shipping 構成は iOS / macOS とも native Swift で、AVFoundation (decode / encode) と Core Image (CIKernel) でグレーディングの GPU 処理を回し、UI は SwiftUI / AppKit という形です。色の判定 (Look 構成、kernel 定数、curve / compression / shadow / detail-softness / optics の resolve 順) は TypeScript で書いた一つの core (`packages/film-lab-core`) を正本とし、そこから Swift コードを生成して `packages/film-lab-swift-core` (`FilmLabSwiftCore` Swift Package) に置き、両 native app から `import FilmLabSwiftCore` で参照する作りです。WebGPU / WebGL renderer (`packages/film-lab-renderer`) も維持していますが、これは portfolio 側 web の landing demo 専用で、iOS / Mac アプリの runtime path には乗っていません。
```

**EN product / design (medium)**:

```
Filmtone is a small app for adjusting the color of video on iPhone and Mac. You load a clip you have already shot, and it writes out a finished video with {release-specific tail}.
```

**EN tech (hashnode)**:

```
Filmtone is a small app for color-grading video on iPhone and macOS. You load a clip and it writes out an MP4 with {release-specific tail}.

Under the surface, both the shipping iOS and macOS apps are native Swift: AVFoundation for decode / encode, Core Image (CIKernel) for the GPU-side grading work, SwiftUI / AppKit for UI. The color *logic* — Look composition, kernel constants, curve / compression / shadow / detail-softness / optics resolution — lives in a single TypeScript core (`packages/film-lab-core`), regenerated into a Swift Package (`packages/film-lab-swift-core`, `FilmLabSwiftCore`) that both native apps import. The WebGPU / WebGL renderer (`packages/film-lab-renderer`) is also maintained, but it powers the web landing surface — not the iOS or macOS app runtime.
```

**EN visual (behance subtitle)**:

```
Filmtone is a small app for adjusting the color of video on iPhone and Mac. This case study covers a release that {release-specific summary in 1 sentence, written in everyday words}.
```

### 3.2 今回 release (2026-05-12 texture + audio fix) の tail 確定値

**この release の主題は Texture Softness (新規調整) のみ**。音声出力は不具合修正なので、tail にも lead の並列構造にも入れない。本文では「あわせて、通常動画書き出しで音声が出力されない不具合を直しました」と短く触れる程度に格下げ。

- JP tail: `質感のある動画として`
- EN tail: `clean fine texture`
- Behance subtitle summary: `adds a new control for softening fine, over-sharpened texture in the image, and keeps source-specific corrections out of saved color presets. The release also fixes a bug where normal video exports could lose their original audio.`

次の release では §3.1 の placeholder をその release の **新規調整** 1 軸でフレーズ化する (bug fix は tail に入れない)。

### 3.3 iOS App Store link は linkable 媒体に必ず置く

**Filmtone iOS の App Store URL** (canonical):

```
https://apps.apple.com/jp/app/filmtone-%E3%83%95%E3%82%A3%E3%83%AB%E3%83%A0%E8%AA%BF%E3%82%AB%E3%83%A9%E3%82%B0%E3%83%AClut/id6762564806
```

inline link を貼れる全媒体 (note / zenn / medium / hashnode / behance / X long-form / Desktop note / iOS note) では、本文末尾 (まとめ / Publish Notes の手前 / Asset Checklist の手前) に **App Store link を 1 行で必ず置く**。Desktop 単独記事でも、iOS 版が存在する事実を消さないために置く。

書き方の標準:

- JP: `Filmtone iOS は App Store で配布しています: <URL>`
- EN: `Filmtone iOS is available on the App Store: <URL>`
- Behance: Project external links / description セクションに `<URL>` を貼る (本文中の bare link も可)

`Preset` と同じく、欠けたら §8 改稿チェックリストで検出する。iOS public truth が公開前でも App Store ページ自体は存在しているので link は常時有効。

### 3.4 release 内容の分類ルール (新規 vs bug fix)

各 release の change set を冒頭で分類する:

| 分類 | lead での扱い | 本文での扱い |
|------|--------------|-------------|
| 新規調整 / 機能 | tail のテーマ軸に直結。lead 後段で具体に触れる | 独立 H2 セクションで詳しく |
| 仕様変更 / 振る舞いの再設計 | tail に含めるか別 H2 で扱うか release ごと判断 | 独立 H2 セクション |
| 不具合修正 (bug fix) | tail に含めない。lead では「あわせて、○○ もできるようになります」のように **outcome として** 触れる (「不具合を直しました」と書かない) | 独立 H2 ではなく、関連 H2 内に 1 段落、または小見出し `### 〜が動くようになりました` で短く |
| 内部実装 refactor | lead には書かない | 技術記事 (zenn / hashnode) のみ末尾の補足で触れる |

判断基準: 「ユーザーがこの release で新しく試せることは何か」を 1 行で書けるなら新規調整。「以前あった想定外の挙動が直った」なら bug fix。区別が曖昧なときは Copy Brief の `Next action` から逆算する。

**bug fix を outcome 文に reframe する** (Refactoring English release announcement chapter):

| 原型 (NG) | reframe 後 (OK) |
|----------|------------------|
| 通常動画書き出しで音声が出力されない不具合を直しました | 通常動画書き出しが、元の音声を含めた完成 MP4 として書き出されるようになります |
| iOS 録画クリップに mic audio が含まれない不具合を直しました | iOS の録画クリップに、撮影時の mic 音声がそのまま入るようになります |
| クラッシュを直しました | 〜が動くようになりました / 〜が落ちずに通るようになりました |
| The export pipeline was fixed to retain audio | Normal video exports now keep their original audio in the completed file |
| Fixed a thread deadlock that froze the UI for 2 seconds | New file creation now lands in under 20 ms (≈100× faster) |

理由: bug-framing は読者を「壊れていた事実」に向ける。outcome-framing は「これからできること」に向ける。読者が知りたいのは後者。`feedback_no_bug_first_framing` 既発火。

---

## 3.5 Craft 原則 (面白く / 認知ゼロでも読める文章を書く)

機械的な禁忌チェックを全部通っても、文章が抽象名詞の羅列で「読んで面白い」「初見でも情景が浮かぶ」状態にはならない。ここは Refactoring English (release announcement chapter) / Linear changelog / SmartHR Design System (リリースノート原則) / VSCO アップデート / note 公式「カイゼン」/ Paul Graham / Arc Browser blog の craft 知見を Filmtone 文脈に翻訳したセクション。**毎稿、§8 改稿チェックリストの 9〜15 と組で走らせる**。

### 3.5.1 Lead パターン: 読者の既存体験への呼びかけ + 違和感の名指し

Lead (冒頭 1-2 段落) は、読者が **すでに体験している現象** から入る。Filmtone を知らない人にも「あ、それ知ってる」と言わせるのが目的。Linear / SmartHR Design System の "コードが何をするかではなく、ユーザーが何から解放されるか" 原則と同じ。

**推奨 lead テンプレ (`X is decided. But Y...` pattern)**:

```
{良い状況の確認}。でも {素材 / 環境} によっては、{なぜか残る違和感}。

{具体観察 1}。{具体観察 2}。{具体観察 3}。── {その違和感の正体を 1 文で名指し}。
```

実例 (今回 release):

> 色は決まる。でも素材によっては、なぜかフィルム寄りに振りきらない瞬間があります。
>
> 髪の一本一本が立つ。布の繊維が見えすぎる。夜のシーンで、ノイズが粒として残る。── 撮影時にカメラ側で焼き込まれたシャープネスが、グレーディングをかけたあとに、改めて主張しはじめる現象です。

これで読者は「あ、それ知ってる」を起動できる。Filmtone を知らない読者でも入れる。Filmtone を知っている読者は「あれを言語化してくれた」で読める。

そのあとに sentence 3-4 で Filmtone とは何か (`Filmtone は、iPhone と Mac で動画の色味を整えるアプリです。`) → 次の更新の説明、と接続する。

**従来パターン (即 NG)**: `Filmtone は X するアプリです。次の更新では Y を入れます。` ── 読者がページを閉じる典型構造。冒頭で product definition を出すと、Filmtone 未知の読者には「何の話?」、既知の読者には「知ってる」で両方刺さらない。

**具体シーンとして数えるもの**:

- 特定の撮影状況 (`iPhone で夜に渋谷を撮ると`, `アクションカメラで逆光の海を撮ると`, `蛍光灯の室内で人物を撮ると`)
- 特定の被写体 (`髪の毛のキワ`, `街灯のフチ`, `葉脈`, `肌の砂目`, `タイトル文字のエッジ`)
- 特定の鑑賞瞬間 (`書き出した動画を Instagram に上げて見返したとき`)
- 特定の主観感覚 (`紙細工みたいに立つ`, `砂目が浮く`, `輪郭が一本一本立つ`)

**シーンとして数えない (抽象名詞)**:

- ❌ `デジタル感の強い部分`
- ❌ `細かい輪郭`
- ❌ `局所コントラスト`
- ❌ `フィルム調の質感`
- ❌ `素材によって効き方が変わる`

**判定基準**: Lead を読み終えた読者が、頭の中で 1 枚の絵を再生できるか。再生できないなら抽象。

### 3.5.2 Title は「特定の image」か「特定の outcome」を含む

Title は記事の lead 装置。記述的な羅列はやめる。

| NG (現状の傾向) | OK |
|----------------|-----|
| Filmtone の次の更新では、デジタル感の強い部分の見え方を整えるための調整を入れています | iPhone の夜景がバキバキ見える、を一段ほぐせるようになります |
| Filmtone Is Updating Audio Export and Texture Softness | Softening the In-Camera Sharpening Without Blurring the Whole Image |
| Filmtone iOS 1.9候補では、音声と細かい輪郭の見え方を見直しています | iPhone で撮った夜景の輪郭を、画面ごとぼかさずに少しだけ削れるようにします |

Refactoring English のパターン (Gleam: `Gleam JavaScript gets 30% faster`) と同じ: **title に外せない 1 行 (what changes for you) を入れる**。Filmtone は perf 数値訴求の product ではないので、`{特定の状況}` × `{特定の変化}` の組で書く。

### 3.5.3 抽象名詞 → 具体名詞・名指し素材への置換

draft 完成後に **抽象名詞 1 個ずつ** 具体に置換するパスを走らせる。

| 抽象 (lazy default) | 具体 (置換候補) |
|---------------------|----------------|
| 素材 | iPhone で夜に撮った街並み / アクションカメラの逆光の海 / 蛍光灯の室内人物 / 古い動画 |
| 細かい輪郭 | 髪の毛のキワ / 葉脈 / 街灯のフチ / 肌の砂目 / 文字のエッジ |
| デジタル感 | 撮って出しの硬さ / iPhone 特有の解像感 / 紙細工っぽい縁 |
| 整える / 見直す | ほぐす / 削る / 一段下げる / 紙細工感を抜く |
| 効き方は素材によって変わる | 人物の肌は 20% でも違いが出る。海や空はほぼ変わらない / 夜景に効きやすく、晴天の風景にはほぼ無効 |
| 局所コントラスト | 髪と髪の隙間の白さ / 葉の縁取りの黒さ |

書き方: **draft に「素材」「輪郭」「効き方」が出るたびに 1 箇所ずつ specific に置換できないか考える**。文中に 1 つも具体名詞がない段落は赤信号。

### 3.5.4 Second person + 読者が次に取る行動

機能説明は「ノブの位置とアルゴリズムの説明」ではなく、「読者が **今度試したらどうなるか**」で書く (Refactoring English: "What can users do now that they couldn't before?")。

| NG (third person describe) | OK (second person action) |
|---------------------------|--------------------------|
| Texture Softness は、細かい輪郭の成分 (detail layer) を取り出して、強い輪郭を残しながら細部の出すぎを抑える調整です | いつもの Look を当てた後、Texture Softness を 30% まで上げてみてください。髪と葉の輪郭だけが一段ほぐれて、瞳と文字のディテールはそのまま残ります |
| 通常の動画書き出しが、元の音声を含めた完成 MP4 として書き出されるようになります | 音声付きの動画を Filmtone に入れて normal export を押すと、書き出した MP4 がそのまま音付きで保存されます。Instagram にも、撮ったときに残した街の音や声がそのまま乗ります |
| The control sits in Advanced Optics | Open Advanced Optics. The new control is labeled `Texture Softness`. Pull it to about a third and watch the hair and leaves first |

「機能の構造」は本文 1 段落だけで充分。残りは「読者が触ったらどう感じるか」を書く。

### 3.5.5 段落リズム ── 抽象 → 具体 → 抽象、2-4 行で 1 段落、体言止め短文の挟み込み

説明段落だけが 3 連続したら、必ず 1 段落 specific scene を挟む。Linear changelog の scannability と同じ。

- **段落の長さ**: 2-4 行。それ以上は割る。
- **段落の中身**: 1 段落 1 アイデア。「Texture Softness とは何か」「なぜ普通の blur ではダメか」「内部でどう実装したか」を 1 段に混ぜない。
- **段落間のリズム**: `[一般・抽象 1 段] → [具体・シーン 1 段] → [一般・抽象 1 段] → [次の H2]` のような往復構造。
- **長い説明段落の指標**: 4 行を超えたら、`しかし`, `そのため`, `ただし`, `ところで` のような turn 接続詞を見て自然な切れ目で割る。

**体言止め短文 + 断定の rhythm (要所に挟む)**:

長い説明段落の合間に、**短い断定文 / 体言止め** を挟むと記事が引き締まる。詩的なくらい短い文を、製品哲学の中心や section pivot で 1-2 回置く。

| パターン | 例 |
|---------|----|
| 体言止め 3 連 observation | `髪の一本一本が立つ。布の繊維が見えすぎる。夜のシーンで、ノイズが粒として残る。` |
| 体言止め分け方宣言 | `Look は素材を超えて持ち運べるもの、素材ごとの補正は実行時 (runtime) に任せるもの ── ここを明確に分けています。` |
| 短文 + 短文 + 補足 | `色は一箇所にまとめる。処理の質感は各 OS に任せる。── 作品としての一貫性と、ネイティブの速さ。両方を捨てないための作りです。` |
| 体言止め問題提起 | `問題は、これがファイルに焼き付いていること。` |
| 短文断定 + ピボット | `万能ではありません。すべての素材を自動で良くする機能ではなく、{具体}。` |

ルール: 1 セクションに 1-2 回。やりすぎると詩集になる。長い説明段落の **直後** か、section の **最後の総括** で使うと効きやすい。

### 3.5.6 音読テスト (Paul Graham)

投稿前に **黙読ではなく音読** する。次のパターンが連続している箇所は推敲対象:

- `〜という〜` / `〜ための〜` / `〜に対する〜` / `〜における〜` (付帯語ネスト)
  - 例 ❌「細かい輪郭の見え方を整えるための新しい調整」
  - 例 ◯「細かい輪郭をほぐすノブ」「文字や髪の縁を一段下げる調整」
- `〜については〜` / `〜にあたっては〜` (官僚語)
- `〜という位置づけです` / `〜という形になっています` (meta-tag に逃げる)
- 二重否定 (`〜なくはない`, `〜ないわけではない`)
- 主語が「Filmtone は」「本リリースは」連続 (主語を **読者の動作** に振る: 「いつもの Look を当てた後、ノブを 30% まで上げてみてください」)

Paul Graham: "write like you speak → ahead of 95% of writers"。一度全文を「同僚に口頭で説明するなら何と言うか」で口に出してみる。

### 3.5.7 一人称の試行語り (限定的に許可)

Arc Browser blog の `I had abandoned Firefox within 2 days` のような **一人称の手触り語り** は、Filmtone 記事でも限定的に解禁する。

許可される条件:

- 検証可能な素材で書かれている (`iPhone 17 Pro で夜の渋谷を撮った素材で試したら`)
- 個人の体感を sweeping claim に拡張していない (`どの機種でもこうなる` のような断定はしない)
- 媒体ごとの分布: note / X / Behance ◯、Medium 部分的 ◯、Zenn / Hashnode は控えめ (技術媒体は I より the editor / Filmtone の `we` のほうが自然)

例:

- ◯ 「iPhone 17 Pro で渋谷の夜を撮った素材を Filmtone に流し込むと、Stone を当てたあとでも街灯のフチが少し紙細工っぽく見えていました。Texture Softness を 30% 上げると、その紙細工感だけが落ちます。」
- ❌ 「私の経験では、全ての iPhone 素材でこの調整が必要です。」(sweeping claim)

### 3.5.8 H2 は self-contained で「単独で読まれても意味が通る」 + 疑問形 + stakes subtitle

note / Zenn / Hashnode の TOC は H2 を抜き出すだけ。読者は TOC から本文を読まずに H2 だけスキャンする。なので H2 は **1 行で何が書いてあるかわかる** ようにする。

**3 つの推奨パターン**:

| パターン | 例 |
|---------|----|
| 名詞 + ── + 動作 / 結果 | `Texture Softness ── 焼き込まれたシャープネスを、後段で外す` |
| 疑問形 + ── + stakes subtitle | `なぜ iOS と Mac で「色」がズレないのか ── 作っている側の話` |
| 体言止め outcome | `撮ったときの音が、書き出した動画にそのまま入ります` |

**NG (合成名詞・冗長・read motive がない)**:

| NG | OK |
|----|-----|
| 1. Texture Softness でデジタル感の強い部分の強さを調整する | Texture Softness ── 焼き込まれたシャープネスを、後段で外す |
| 2. 通常の動画書き出しと録画クリップの音声を直しました | 撮ったときの音が、書き出した動画にそのまま入ります |
| 4. 作っている側で考えていること | なぜ iOS と Mac で「色」がズレないのか ── 作っている側の話 |

**「作っている側で考えていること」のような meta タイトル禁止**: 読者が読みたくなる理由を 1 行も提供していない。中身が「TypeScript core から Swift を自動生成して iOS と Mac で色をズラさない」のような **製品哲学に直結する craft の話** なら、それは「裏側」ではなく **表に出すべき選択理由** であり、stakes subtitle 付きの疑問形に書き換える。

H2 は「次に何の話か」だけでなく「読者にとっての意味 (stakes)」を含めると一段刺さる。

### 3.5.9 太字の使い方 ── thesis 1 箇所 + inline 短句 emphasis

太字は **どこに置くか** で記事の重心が決まる。乱用すると全部太字 = どこも太字でなくなる。

| 種類 | ルール | 例 |
|------|-------|----|
| **thesis bold** (製品哲学・中心 claim を 1 文まるごと太字) | 一篇に **1 箇所のみ** | `**iOS と Mac で、色そのものの決め方は絶対に別物にしない。**` |
| **inline emphasis bold** (短句 1-3 文字を contrast / 重要語として強調) | 1 セクションに 1-2 ペア程度。多くても 1 篇 4 箇所まで | `Lens Softness は「ふんわり」を **足す** 方向。Texture Softness は「くっきり」の主張を **落とす** 方向。` / `Swift コードを **自動生成** しています` |
| ❌ NG | section 内多用 / heading 横並びの bold / 連続段落での bold | (Markdown が太字だらけ = どこも強調されない状態) |

**配置の方針**:

- thesis bold は記事の最後 1/3 (作っている側の話 / 製品哲学のセクション) に置く。lead では使わない (lead はそれ自体で重い)
- inline emphasis bold は contrast を明示するためだけに使う (`A は X 方向 / B は逆の Y 方向`)
- thesis bold を打つ場所が決まらない記事 ← **記事の中心 claim が定まっていない signal**。先に中心 claim を 1 行で言語化する

---

## 4. 用語ロック (毎回チェック、ブレ禁止)

| 守る | 禁忌 | 理由 |
|------|------|------|
| 動画 / video | 短尺動画 / short-form video | life `5ce6d55` で lock 済 |
| Look (curve / grade 土台も bundled Look として並ぶ。すべての保存済み色設定の総称) | `Preset` / `プリセット` を user-facing で使う | UI から Preset 概念は撤去済み。記事は user 視点で書くので、土台にあたる項目もすべて Look として書く |
| Texture Softness (amplitude-gated bilateral detail layer) | plain blur / 一般的なぼかし | 実装と異なる説明禁止 |
| Texture Softness の対象 = 機種側 sensor / ISP / encoder で撮影時点に焼き込まれた sharpening | `グレーディング後に細い輪郭が強く残る` / `Look を当てると輪郭が立つ` / `グレードが輪郭を強める` | grade は輪郭強調をしない。原因は source 側のデジタル sharpening (iPhone / アクションカメラ等の ISP) で、撮って出しの時点で焼き込まれている。記事では「機種の sharpening / ISP / encoder で in-camera に焼き込まれた」と書く |
| Lens Softness (lens/periphery character) | Texture Softness と混同 | 別軸 |
| source detail bias (runtime-only) | Look に焼き込む / baked into Look | portability 破壊 |
| transform LUT (Log→Rec.709 + creative の hybrid) | technical-only 変換 / direction を逆に書く | `feedback_transform_lut_is_hybrid_in_production` |
| `BaseLookName` / `BASE_LOOKS` / `lookPresetId` / `currentExportLookPreset` | 新規参照 (alias artifact) | purge lane 扱い |
| FINISHED ON iPhone | SHOT ON iPhone (Filmtone 軸として) | camera-agnostic 訴求軸 (`feedback_filmtone_source_camera_agnostic`) |
| Apple Liquid Glass (フル名で書く) | Liquid Glass 単独 | canonical name |
| 通常動画書き出しは音声を残す | Highlight-reel も同じと書く | Highlight-reel は source-audio disabled のまま |
| bun / `bun install` / `bun.lock` | npm / `npm install` / `package-lock.json` | life CLAUDE.md §パッケージマネージャ |

---

## 5. 禁忌語 / 禁忌フレーズ

**現在 architecture (絶対に間違えない)**:

shipping app の runtime は **iOS / Mac とも native Swift**。AVFoundation (capture / encode / decode) + Core Image (CIKernel で grade GPU 処理) + SwiftUI / AppKit (UI)。色ロジックの正本は TypeScript core (`packages/film-lab-core`) → 生成 Swift Package (`packages/film-lab-swift-core`, `FilmLabSwiftCore`) → 両 native app が import。**WebGPU / WebGL renderer (`packages/film-lab-renderer`) は portfolio 側 web (`vendor/filmtone` submodule 経由) でだけ runtime に乗っている**。iOS は 1.8 で WebGPU-bridge (React+Capacitor) → native Swift 移行済 (`project_filmtone_react_capacitor_was_webgpu_bridge`)。Desktop は Native v2 で Electron + WebGPU → native macOS 移行済 (`project_native_v2_replaces_electron`)。

絶対に書かない:

- 「shipping app の runtime は WebGPU/WebGL renderer + その上に native runtime」 (誤り、現在の runtime は native Swift のみ)
- 「いまも WebGPU / WebGL が iOS / Mac の runtime」 (誤り、portfolio web 側のみ)
- 「shared package (`film-lab-renderer`) を iOS と Desktop が参照」 (`film-lab-renderer` は web 専用、native は `film-lab-swift-core` を参照)

書き分け:

- 現在形: native Swift + Core Image + AVFoundation + SwiftUI / AppKit。色ロジック正本は `film-lab-core` (TS) → 生成 Swift → `FilmLabSwiftCore`
- 歴史 (任意): 初期は WebGPU/WebGL renderer。iOS は React+Capacitor 経由でその renderer を持ち込んでいた。1.8 で native Swift 移行。WebGPU renderer は今も Web 公開窓で維持中

**Texture Softness の premise (絶対に間違えない)**:

対象は **source 素材が in-camera で焼き込んでくる digital sharpening**。iPhone / アクションカメラなどの sensor + ISP + encoder の sharpening が撮影時点で acutance を強く乗せていて、その性質は撮って出しの段階で焼き込まれている。Filmtone 側の curve / Look / LUT / glow / grain / print processing は輪郭を「足す」処理ではない (むしろ contrast や print が整うと、もともと立っていた細い輪郭が相対的に目立ちやすくなる)。Texture Softness はその source-side の焼き込まれた sharpening を、強い edge は残したまま局所的に弱める。

書き方:

- ◯ 「最近の iPhone / アクションカメラ系の素材は、撮影時点で sensor / ISP / encoder 側の sharpening によって細かい輪郭の acutance が強く焼き込まれている」
- ◯ 「Filmtone でグレーディングを当てたあとも、その in-camera で焼き込まれた sharpness は減らない」
- ◯ 「contrast や print stage が整うと、もともと source 側に乗っていた強めの細部が相対的に目立ちやすくなる」
- ✕ 「グレーディング後に細い輪郭だけが強く残る」(grade が原因に読める)
- ✕ 「Look や LUT を当てると輪郭が立つ」(grade が輪郭強調するように読める)
- ✕ 「Filmtone 側で curve / LUT / grain を重ねると細い輪郭が強くなる」(grade-induced と読める)

**入れない**:

- 細部の硬さ (「細かいディテール」「細かい輪郭」に置換)
- 世界観 (description が抽象すぎる、何を指すか書く)
- 魔法 (`magical`, `magic-like` 含む)
- プロ級 / pro-grade (claim を裏付けないクラスは使わない)
- 必ず / 完璧 / すべての素材で / always / perfectly / every source
- Web を捨てた / instead of web / 「Web 製の iPhone 移植」
- React + Capacitor は間違い / mistake / 失敗だった
- 公開しました / released / shipped / now available (public truth script が PASS した後だけ)
- 「念のため fallback」「安全側でスキップ」「v1.x で後回し」(保守的ヘッジ)
- 旧 iOS lowercase compatibility ID を現在 truth として使う
- **`Preset` / `プリセット`** (user-facing で一切使わない。UI 上はすべて `Look`。`Preset (curve や grade の土台)` 風の説明的注釈もしない、概念再導入になる)
- **「本来そうであるべき挙動に戻した、という位置づけです」「あるべき挙動に戻しました」「本来の挙動を取り戻した」** (受動的・bureaucratic・「位置づけ」でメタに逃げる悪文。bug fix は「もともと残るはずだったところで残っていなかったので、直しました」「動画書き出しで音声が出なかった不具合を直しました」のように能動・具体に書く)
- 「〜という位置づけです」 / 「〜の位置づけ」 (meta-tag に逃げる。本文内で位置づけを宣言せず、書き方そのものでポジションを示す)
- **positioning downplay (release 矮小化フレーズ全廃)**:
  - 「新しい画面を大きく足す更新ではありません」「大きな新画面を足す更新ではありません」「派手な新画面より」「派手ではありません」
  - 「地味な更新です」「地味だと思います」「小さな更新です」「ささやかな更新」
  - `The release is small in feature count` / `This update is small in feature count` / `quiet by design` / `release without adding a single new screen` / `small feature count`
  - 理由: 読者は更新の大小を聞いていない。否定形でメタに自己評価するのは positioning anxiety の signal。本文で何が変わるかだけを能動的に書けばよい。「派手な新画面より X を優先しました」のような **想像上の alternative との比較** も削除する
- **bug-fix の二重宣言禁止**: 見出しが既に「○○の不具合を直しました」なら、本文冒頭で「これは新規機能ではなく、不具合修正です」と再宣言しない (見出しで明示済み)。本文は具体内容から書き始める

**入れない positioning anxiety**:

- 「## 目次」を本文に手打ち (note エディタ block / Zenn / Hashnode の auto TOC と二重表示)
- 「## 誰に向けた更新か」セクション (audience uncertainty を broadcast する。Copy Brief で済ませる)
- 「## 作っている側の補足」のような meta セクション (本文に統合 or §4 「作っている側で考えていること」として消化)

**入れない (固有名詞並列・jargon-wall) — §3.0 の帰結**:

- 冒頭 2-3 段落で `Stone` / `Urban Creative` / `Look pack` / `Optics` / `curve` / `grade` / `LUT pack` を説明なく並べる
- 「いつもの `Preset` や `Look` を選び」のような並列表記 (Preset 概念は廃止済み)
- 冒頭で「Look (Stone / Urban Creative LUT Pack や保存済みの仕上がり) を選び」のように、説明的に見えても固有名詞 3 つを 1 文に詰め込む
- 「Lens Softness とは別の Texture Softness」のような対比を、両方未紹介の段階で出す
- judge 基準: 冒頭段落を読んだ Filmtone 未知の人が「何個も知らない言葉が並んでいて読むのを諦めるか」想像。1 つでも「これ何?」が連続するなら一般語に直す

---

## 6. 媒体別 TOC ポリシー (Publish Notes に毎回書く)

| 媒体 | ポリシー | 投稿時アクション |
|------|---------|-----------------|
| note | エディタ「目次」block で自動生成。H2/H3 拾う、自動採番なし | Draft の `**目次**` プレビューリストと HTML comment は投稿時に削除し、同位置に block 挿入。H2 に手動 `1.` `2.` 採番済の状態で投稿 |
| Zenn | 右サイドバー auto (H2/H3) | 本文に手動 TOC 書かない。H2 を独立読み可能にする |
| Medium | TOC なし、anchor ID 露出なし | H2 を short / self-contained に。手動 TOC 不可 |
| Hashnode | Article Settings で auto TOC ON | 本文に手動 TOC 書かない |
| Behance | 無し | H2 を production checkpoint として使い rename / 採番しない |
| X Article | 無し | 「## 目次」セクション禁止 |

---

## 7. 公開ゲート (Publish Guard)

候補稿は必ず次の Publication switch セクションを末尾に持つ:

```
Publication switch:

- Before public truth: keep `候補`, `次の更新に入れている`, `upcoming`, `release candidate` framing.
- After public truth: change opening to `Filmtone Desktop {X.Y} / iOS {X.Y} の実装メモです.` etc., and update Release Guard to reflect post-release truth.
```

公開直前チェック:

1. `check-filmtone-release-truth.sh` PASS → Desktop public 確定
2. `check-filmtone-ios-truth.sh` PASS → iOS public 確定
3. 本文の `候補` / `candidate` / `upcoming` 表現を release wording に置換
4. ダウンロードリンク / App Store link を埋める
5. Behance のみ: visual asset を入れ、`[ ]` の placeholder を消す
6. 共通: 公開した瞬間に、portfolio 側 (`vendor/filmtone` submodule) を bump 対象に上げる (手順は CLAUDE.md §7)

---

## 8. 改稿時のチェックリスト

既存 candidate を改稿する時、毎回次の順に走らせる:

1. **認知ゼロ前提を満たしているか**: 冒頭 2-3 段落に Filmtone definition があるか / "existing user 向け" になっていないか
2. **媒体別 TOC**: §6 と整合しているか / 重複 TOC や禁忌な「## 目次」「## 誰に向けた更新か」が残っていないか
3. **用語ロック**: §4 全項目を grep で確認 (特に `Preset` / `プリセット` の残存)
4. **禁忌語**: §5 を grep で確認 (`細部の硬さ`, `世界観`, `魔法`, `プロ級`, `公開しました`, `Web を捨てた`, `Preset`, `プリセット` 等)
4.5. **iOS App Store link**: §3.3 のとおり末尾に貼られているか確認
5. **structural セクション**: §1 audio / §2 Texture Softness / §3 公開後に試してほしいところ / §4 作っている側で考えていること (note / X long-form / Desktop / iOS note 系)
6. **truth gate**: candidate state を保っているか / public 主張を含めていないか
7. **defensive framing 除去**: 「Web を捨てた話ではない」「easy to misdescribe」のような言い訳的 lead を消す
8. **lead の鋭さ**: 1 段落目で release が何を変えるか具体に書けているか
9. **§3.5.1 Lead に具体シーンが 1 つ以上**: 冒頭 1-2 段落に「読者が頭の中で 1 枚絵を再生できる」描写があるか。`デジタル感` `細かい輪郭` `局所コントラスト` だけで lead が終わっていたら不合格。`iPhone で夜に撮ると` `髪の毛のキワ` `街灯のフチ` のような specific scene を 1 つ以上挿す
10. **§3.5.2 Title に特定 image / outcome**: title が記述的羅列 (`〜の見え方を整えるための調整を入れています`) になっていないか。`特定状況 × 特定変化` の組で書き直せないか確認
11. **§3.5.3 抽象名詞置換**: 本文を grep し、`素材` `輪郭` `効き方` `整える` `見直す` `局所コントラスト` `デジタル感` を 1 個ずつ具体に置換できないか検討。1 段落に 1 個も具体名詞がないなら赤信号
12. **§3.5.4 second person の有無**: 「読者が試したら何が起きるか」が書かれているか。`Filmtone は X です` `本リリースは Y です` だけが連続していたら、「いつもの Look を当てたあと、ノブを 30% まで上げてみてください」型に書き換え
13. **§3.5.5 段落リズム**: 4 行超の段落がないか / 抽象 → 具体 → 抽象の往復になっているか / 説明段落が 3 連続していないか
14. **§3.5.6 音読**: 全文を **声に出して** 読む。`〜という〜` `〜ための〜` `〜に対する〜` `〜という位置づけです` `〜という形になっています` の連続を grep で確認し、口語に書き換え
15. **§3.4 bug fix → outcome reframe**: `〜不具合を直しました` `Fixed 〜` を grep し、`〜できるようになります` `Normal video exports now keep 〜` 型に reframe (見出しも本文も両方)
16. **§3.5.1 Lead = 既存体験 + 違和感**: 冒頭が `Filmtone は X するアプリです。次の更新では Y を入れます。` 構造になっていないか。`{良い状況の確認}。でも {素材} によっては {残る違和感}。` パターンか、それと同等の「読者の既存体験への呼びかけ」になっているか
17. **§3.5.5 体言止め短文の挟み込み**: 説明段落が続く section に、`色は一箇所にまとめる。処理の質感は各 OS に任せる。` のような短文断定が 1-2 箇所入っているか。詩集化していないか (1 篇に 10 個以上の体言止めは赤信号)
18. **§3.5.8 H2 read motive**: meta タイトル (`作っている側で考えていること`) になっていないか。各 H2 が読者に「読みたい」と思わせる stakes / 疑問形 / outcome を含むか
19. **§3.5.9 thesis bold 1 箇所**: 製品哲学・中心 claim を 1 文太字で打ち抜いているか。打てない場合は中心 claim が言語化されていない signal。lead 直後ではなく後半 1/3 に置けているか

---

## 9. ファイル配置規約

```
docs/filmtone/articles/{YYYY-MM-DD}-{topic}-release/
  note-ja.md
  zenn-ja.md
  medium-en.md
  hashnode-en.md
  behance-case.md

docs/filmtone/desktop/native-desktop-v2/
  {YYYY-MM-DD}-filmtone-desktop-v{X.Y}-article-jp.md

docs/filmtone/ios/
  {YYYY-MM-DD}-filmtone-ios-{X.Y}-x-article-jp.md
```

X long-form は platform 単独 doc 側 (`desktop/` or `ios/`) に置く。`articles/` には 5 媒体共通の release セットを置く。

---

## 10. 1 release を新規で書き起こす時の手順

1. **release scope を確定**: 何が変わるか、なぜ変えたか、どの platform に効くかを箇条書きで先に書き出す
2. **truth script を走らせる**: Desktop / iOS の public / candidate 状態を取得
3. **Copy Brief を各記事分書く** (§2 の表をベースに 8 項目埋め)
4. **Filmtone definition を §3.1 から選ぶ** (release-specific summary 1 文だけ毎回書き換え)
5. **構造を §3 に従って組む** (媒体ごとに H2 を §3.1 → release content → § 試行 → § 内部設計 の 4 ブロック程度)
6. **§4 用語ロック / §5 禁忌語を draft 完成後に grep**
7. **§6 TOC ポリシー** を Publish Notes に書く
8. **§7 公開ゲート** Publication switch セクションを末尾に
9. **§8 改稿チェックリスト** を最後に通す

---

## 11. アンチパターン (このスキル使用時に踏まない)

- **「全媒体同じ lead で書く」**: 各媒体の対象読者と読書メリットは異なるので lead も別 (§2)
- **「## 目次」「## 誰に向けた更新か」を本文に書く**: positioning anxiety の signal。Copy Brief で済ませ本文には書かない
- **「Filmtone は X 社の Y を超える」比較訴求**: メーカー名を出す claim は §5 reversibility buffer を破る。具体 product と並べる時は「中継アプリ」「Premiere/FCP の色を別アプリで扱う」のように function level に留める
- **「## 目次」を手打ち** (Zenn / Hashnode auto TOC と二重表示)
- **iOS / Desktop の Look ID を旧 lowercase compatibility ID で書く** (§4 用語ロック / CLAUDE.md §6 #4)
- **`apps/desktop-film-lab-batch` を Desktop 正本として書く** (正式 Desktop は `apps/filmtone-desktop-macos`、CLAUDE.md §3 / §6 #3)
- **`Preset` / `プリセット` を user-facing 本文で使う** (§3.0 / §5、UI から撤去済み概念)
- **iOS App Store link を本文末尾に置き忘れる** (§3.3、linkable 媒体すべて必須)

---

## 12. 参照

- Filmtone CLAUDE.md §3 (運用原則) / §6 (アンチパターン)
- life `docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md` (用語 spec)
- life `docs/guides/film-lab-current-index.md` (live entry)
- 既存 reference 記事 (2026-05-12 release set):
  - `docs/filmtone/articles/2026-05-12-audio-texture-release/note-ja.md`
  - `docs/filmtone/articles/2026-05-12-audio-texture-release/zenn-ja.md`
  - `docs/filmtone/articles/2026-05-12-audio-texture-release/medium-en.md`
  - `docs/filmtone/articles/2026-05-12-audio-texture-release/hashnode-en.md`
  - `docs/filmtone/articles/2026-05-12-audio-texture-release/behance-case.md`
  - `docs/filmtone/desktop/native-desktop-v2/2026-05-12-filmtone-desktop-v1-7-article-jp.md`
  - `docs/filmtone/ios/2026-05-12-filmtone-ios-1.9-x-article-jp.md`
