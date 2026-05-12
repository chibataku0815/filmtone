# Filmtone Desktop v1.7 release article draft

Status: candidate draft. Do not publish until the Desktop truth script reports
public `latestVersion: "1.7"` and the fixed download rail points to
`Filmtone-1.7.dmg`.

## Copy Brief

- Primary reader: Mac で自分の素材を見比べながら仕上げ、音のある動画として書き出したい Filmtone Desktop 利用者。
- Moment: v1.6 から更新するか判断する時、または動画を書き出したあとに音声や、細かい輪郭の強さが気になる時。
- Unresolved feeling: Mac で仕上げるなら、色だけでなく音声付きの完成ファイルとして信頼したい。最近の素材の、細かい輪郭が強く出すぎる部分も少し整えたい。
- Next action: v1.7 公開後にダウンロードし、音声付き素材の通常書き出しと `Texture Softness` を自分の素材で試す。
- Not for: iOS 1.9 の App Store 公開告知、Mac App Store 申請、メーカー別の認定変換主張。
- Claim class: Candidate until public update metadata reports v1.7.
- Source evidence: release truth script on 2026-05-12 reports public Desktop v1.6; local candidate is v1.7 build 4 after this prep. Audio proof is recorded in `docs/filmtone/export-audio/archive/2026-05-12-export-audio-restoration-a.md`. Detail Softness proof is recorded in `docs/filmtone/detail-softness/strategy.md` and Phase 5 archive.
- Reversibility buffer: say `今回の更新では` and `素材によって効き方は変わります`; do not claim every camera/source is perfectly handled.

## Draft

Filmtone は、iPhone と Mac で動画の色味を整えるためのアプリです。Mac 側 (Filmtone Desktop) は、撮った動画を Mac に取り込んで、質感のある動画として書き出します。

次の更新 v1.7 では、Advanced の Optics に `Texture Softness` という、細かい輪郭の見え方を整えるための新しい調整を入れています。あわせて、通常の動画書き出しで音声が出力されない不具合を直しました。

<!-- noteエディタで「目次」ブロックを挿入する位置。下のリストは挿入後に表示される構成のプレビューで、投稿時には削除する。 -->

**目次**

1. Texture Softness で細かい輪郭の強さを動かす
2. 通常の動画書き出しで音声が出力されない不具合を直しました
3. 公開後に試してほしいところ

## 1. Texture Softness で細かい輪郭の強さを動かす

`Texture Softness` は、細かい輪郭が強く出すぎる部分を、少しだけ弱めるための調整です。

似た名前の `Lens Softness` とは役割が違います。`Lens Softness` はこれまでどおり、レンズの周辺やフォーカスの落ち方に近い柔らかさを足す調整です。`Texture Softness` はそれとは別で、画面の中心も含めた細かいディテールや、センサーや圧縮で生まれやすい局所コントラストを少し抑えるために入れています。

単純なぼかしにはしていません。大きな輪郭や文字の読みやすさは残しつつ、細い輪郭の主張だけを引く方向にしています。内部では、近い明るさの周辺ピクセルから局所的な参照を作り、そこから浮いた細かいディテール (detail layer) を弱めています。強い輪郭まで一緒に均してしまうとただのぼかしになるので、そこは避けています。

さらに、ソースによって少しだけ効き方を変えています。iPhone やアクションカメラ系の素材は、撮って出しの時点で細かい輪郭がかなり立っていることがあります。一方で、Log のカメラ素材や、すでに柔らかいレンズで撮られた素材まで同じように弱めるとやりすぎになります。

なので今回の Desktop では、使えるメタデータがある場合だけ、控えめな初期値 (source detail bias) を足しています。これは保存した Look には焼き込みません。同じ Look を別の素材に当てたときに、iPhone 用の補正まで一緒に持ち運ばれてしまうと困るからです。

## 2. 通常の動画書き出しで音声が出力されない不具合を直しました

Desktop の通常の動画書き出しで、元の素材に音声があっても、書き出した MP4 に音声が残らない場合がありました。今回はそこを直しています。

内部では、元の音声トラックを AAC として出力に書き、書き出しが終わったあとに完成 MP4 をもう一度開いて、音声トラックが残っているかを確認するようにしています。書き出し中の状態だけでは「音声が無事に書けたか」が判定できないことがあったので、完成ファイル自体を直接見るようにしました。

ハイライト書き出しは、いまの設計では音声なしのままです。今回の修正は、通常の動画書き出しの範囲です。

## 3. 公開後に試してほしいところ

まずはいつもの Look (`Stone` のようなフィルム系、`Urban Creative` のような街並み系、あるいは自分で保存した仕上がり) を選んでから、Advanced の Optics にある `Texture Softness` を少しだけ上げてみてください。効き方は素材によって変わります。髪、布、葉、細かい文字、夜のノイズが乗った素材ほど、上げすぎかどうかを見つけやすいです。

今回の更新は、Filmtone Desktop を「Mac で色を作って、音声付きの完成ファイルとして書き出す」方向にもう一段寄せるための更新です。書き出した後にそのまま使えること、そして細かい輪郭の見え方を少し整えられることに重心を置いています。

v1.7 が公開されたら、いつものダウンロードページから置き換えられます。iPhone 側の Filmtone iOS は App Store で配布しています: https://apps.apple.com/jp/app/filmtone-%E3%83%95%E3%82%A3%E3%83%AB%E3%83%A0%E8%AA%BF%E3%82%AB%E3%83%A9%E3%82%B0%E3%83%AClut/id6762564806

## Publish Notes

- Replace the final line only after public update metadata reports v1.7.
- If the article links release notes, use the v1.7 notes after checksum is filled.
- Do not mention iOS 1.9 public availability from this draft.
- 目次は note エディタの「目次」ブロックで自動生成する。Draft 内の `**目次**` プレビューリストと HTML コメントは投稿時に削除し、同じ位置に目次ブロックを挿入する。note 仕様上 H2 / H3 のみ拾われ、自動採番はないため、Draft の H2 は手動で `1.` 〜 `3.` を付与済み。
