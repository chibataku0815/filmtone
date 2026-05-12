# Texture Softness を blur ではなく detail layer として実装する ── Filmtone の場合

Status: candidate technical draft. Public release wording is gated until
Desktop public `1.7` and iOS public `1.9` are both true.

Publication switch:

- Before public truth: keep `次の更新に入れている` / `候補` 表現。
- After public truth: 冒頭を `Filmtone Desktop 1.7 / iOS 1.9 で入った Texture Softness の実装メモです。` に差し替える。

TOC policy: Zenn は h2 / h3 から目次を自動生成し、デスクトップでは右サイドバーに常時表示する。本文内に手動 TOC を書かない。見出しは単独で意味が通る形を保つ (目次項目になるため)。

## Filmtone とは

Filmtone は、iPhone (iOS) と Mac (macOS) で動画の色味を整えるアプリです。撮影済みの動画を読み込み、curve / grade / LUT / glow / grain / print processing を組み合わせたカラーグレーディングをかけて、MP4 として書き出します。

shipping app の構成は **iOS / macOS とも native Swift**。`AVFoundation` でデコード / エンコード、`CoreImage` (CIKernel) でカラーグレーディングの GPU 処理を回し、UI は SwiftUI と AppKit という形です。色の判定 (Look の組み立て、kernel 定数、curve / compression / shadow / detail-softness / optics の resolve 順) は TypeScript で書いた一つの core (`packages/film-lab-core`) を正本とし、そこから Swift コードを生成して `packages/film-lab-swift-core` (`FilmLabSwiftCore` Swift Package) に置き、iOS / macOS の両 native app から `import FilmLabSwiftCore` で参照します。

つまり「色の正本は TypeScript」「runtime は native Swift」というのが、いまの shipping 構成です。WebGPU / WebGL の renderer (`packages/film-lab-renderer`) も維持していますが、これは portfolio 側の web 公開窓で landing demo を出すための表側専用で、iOS / macOS アプリの runtime path には乗っていません。

この記事は、次の Desktop / iOS 更新に入れている `Texture Softness` の実装メモです。同じ release で不具合修正 (通常動画書き出しの音声欠落) も入っているので、末尾でその検証 pattern にも触れます。

## 問題: 機種側で焼き込まれた sharpening が強すぎる素材がある

最近の iPhone やアクションカメラ系の素材は、撮影時点で sensor / ISP / encoder の sharpening によって細かい輪郭の acutance がかなり強く乗っています。これは撮って出しの段階で既に焼き込まれた性質で、後段で grade を当てても弱まりません。

curve / Look / LUT / glow / grain / print processing は輪郭を「足す」処理ではありません。ただし contrast や print stage で画全体のコントラストが整うと、もともと source 側に立っていた強めの細部が相対的に目立ちやすくなります。

具体的に見えやすい部位は、髪、布、葉、細かい文字、夜のノイズ、街灯まわりの境界です。

普通の blur で対処すると別の問題が起きます:

- 文字が読みにくくなる
- 髪・布のエッジが溶ける
- 葉や建物の線が均されすぎる
- 自前で乗せた grain まで一緒に眠くなる

つまり、画面全体の解像感を落としたいのではなく、**強い edge は残したまま、source に焼き込まれた局所的に浮いた細かい acutance だけを下げたい**。これが Texture Softness の出発点です。

## 実装: amplitude-gated bilateral detail layer

Texture Softness は、画面全体に対する後段 blur ではなく、frame 単位で組む detail layer 操作として実装しています。

```text
source frame
  → edge-preserving local reference (近い明るさのピクセルから局所平均)
  → detail layer = source - reference
  → local amplitude / threshold で detail を gate
  → controlled amount だけ source から差し引く
  → 後段の optics / glow / grain / LUT / print stages へ
```

ポイントは 2 つです。

**1. 単純平均ではなく edge-preserving reference を作る**。bilateral / joint filter 系の発想で、近い明るさのピクセル群から局所参照を作るので、強い edge (人物の輪郭、文字の縁) は reference 側に保たれ、その上で `detail = source - reference` を取ると、強い edge は detail layer にほとんど乗らず、細かい acutance だけが detail layer に乗ります。

**2. detail layer を amplitude で gate する**。detail layer をそのまま差し引くと、grain や微細テクスチャまで一緒に削れます。amplitude / threshold で「中くらいの強さの細かい acutance」だけを引き対象にすることで、大きい edge と小さい grain をどちらも残せます。

### Pipeline 上の位置

これも書く価値があります。Texture Softness を**後段の blur として置かない**ことが重要です。

Filmtone の Desktop pipeline では、Texture Softness は edge optics / glow / grain / creative LUT / print processing の**前**に置いています。理由は 2 つ:

- 過剰に立った edge を glow に渡すと halo が肥大化する。Texture Softness を glow より前に置けば、glow 入力時点で輪郭が落ち着いている
- Texture Softness を後段に置くと、自前で乗せた grain も潰してしまう。先に detail layer を落とし、その後で grain を乗せる順序にする

## source detail bias を Look に保存しない

Texture Softness 自体は user-controllable な軸ですが、それとは別に Filmtone は素材メタデータが使える場合に、控えめな `source detail bias` (初期 detail 抑制量) を runtime で足しています。

ここで設計判断が一つあります。**この bias を `Look` (保存可能な色の意図) には書き込まない**。

理由:

- iPhone 撮って出し向けに少し効かせたい bias を、保存した Look の中に値として持たせてしまうと、別カメラ素材にその Look を当てたときにも bias が付いてくる
- Look の portability (素材をまたいで使える) が壊れる
- 記事 / release notes での claim が安全でなくなる (「このカメラ向けに最適化」と言ってしまうと、Look の portability claim と矛盾する)

なので、3 層に責務を分けています:

```text
Look                    : 持ち運ぶ色の意図 (curve / grade 土台も bundled Look として並ぶ)
Source profile / metadata: その素材を読むための手がかり (runtime で参照する)
Source detail bias       : runtime でだけ効く控えめな補助 (Look には書き込まない)
```

この分離があると、release notes でも `使える素材情報がある場合に、控えめな runtime-only bias を入れています` のように、portability を壊さない説明ができます。

## 不具合修正: 完成ファイル側で出力 audio を検証する

同じ release で、通常動画書き出しの音声欠落も直しました。新機能ではなく bug fix ですが、検証 pattern としては書く価値があります。

書き出しに必要な条件は単純です:

- source に audio track がある
- 出力 MP4 にも audio track がある
- 成功表示の前に、完成ファイル側で確認する

問題は最後です。実装中は `AVAssetWriterInput` に audio input を append できた時点で安心しがちですが、これは「writer 上で audio input を構成できた」ことしか保証しません。完成 MP4 を再度開いて audio track の有無を確認するまで、ユーザーが受け取るファイルの実態は確認できません。

なので、今回は次の判定にしています:

- source の audio track を読む
- 通常動画書き出しでは AAC として output に書く
- writer finish 後、completed output file を `AVAsset` で再オープンして audio track の有無を確認する
- audio を持つ source なのに output に audio track がなければ成功扱いにしない

iOS では、これに加えてアプリ内録画クリップにマイク音声を含める path も入れました。Desktop と iOS で writer 実装は違いますが、**writer state ではなく完成ファイルで判定する**という考え方は揃えています。

なお Highlight 書き出し (selected timeline segments を再構成する別の出力 path) は今回の範囲では source-audio disabled のままです。通常動画書き出しと同じ claim にはしていません。

## まとめ

- Texture Softness は後段 blur ではなく、`amplitude-gated detail layer subtract` として実装している
- detail layer 操作は glow / grain / LUT より**前**に置く
- source detail bias は runtime のみ。Look には書き込まない (portability 維持のため)
- 動画書き出しの成功判定は writer state ではなく完成ファイル側で見る

動画アプリではプレビューではなく完成ファイルが最後の成果物です。Texture Softness の効きも、audio の有無も、最後に書き出された MP4 で判断されます。そこに寄せて設計を詰めています。

---

Filmtone iOS は App Store で配布しています: https://apps.apple.com/jp/app/filmtone-%E3%83%95%E3%82%A3%E3%83%AB%E3%83%A0%E8%AA%BF%E3%82%AB%E3%83%A9%E3%82%B0%E3%83%AClut/id6762564806

---

公開前メモ:

- Desktop public `1.7` / iOS public `1.9` が揃うまで release wording にしない。
- Public 確定後は冒頭を `Filmtone Desktop 1.7 / iOS 1.9 で入った Texture Softness の実装メモです。` に変える。
