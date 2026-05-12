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

Filmtone Desktop の次の更新では、Mac で仕上げて書き出すところを少し太くします。

大きい変更はふたつです。ひとつは、音声のある動画を書き出したときに、完成した MP4 に音声トラックが残っていることを最後に確認するようにしたこと。もうひとつは、`Texture Softness` という新しい調整を入れたことです。

これまでの Native Desktop は、動画の画をフレームごとに処理して MP4 に戻すところを先に作っていました。そのため、通常の動画書き出しでも音声が落ちる状態が残っていました。今回の更新では、元の音声トラックを読み、出力側に AAC として書き込み、最後に完成ファイルを開いて音声トラックが残っているかを確認します。

ここは見た目の派手さはありません。ただ、Mac で最後まで仕上げるアプリとしては大事なところです。プレビューで音が聞こえることと、書き出したファイルに音が残っていることは別の話なので、今回は後者を完成ファイル側で見るようにしました。

もうひとつの `Texture Softness` は、細かい輪郭が強く出すぎる部分を、少しだけ弱めるための調整です。

似た名前の `Lens Softness` とは役割が違います。`Lens Softness` はこれまでどおり、レンズの周辺やフォーカスの落ち方に近い柔らかさを足す調整です。`Texture Softness` はそれとは別で、画面の中心も含めた細かいディテールや、センサーや圧縮で生まれやすい局所コントラストを少し抑えるために入れています。

単純なぼかしにはしていません。大きな輪郭や文字の読みやすさは残しつつ、細い輪郭の主張だけを引く方向にしています。内部では、近い明るさの周辺ピクセルから局所的な参照を作り、そこから浮いた細かいディテール (detail layer) を弱めています。強い輪郭まで一緒に均してしまうとただのぼかしになるので、そこは避けています。

さらに、ソースによって少しだけ効き方を変えています。iPhone やアクションカメラ系の素材は、撮って出しの時点で細かい輪郭がかなり立っていることがあります。一方で、Log のカメラ素材や、すでに柔らかいレンズで撮られた素材まで同じように弱めるとやりすぎになります。

なので今回の Desktop では、使えるメタデータがある場合だけ、控えめな初期値 (source detail bias) を足しています。これは保存した Look には焼き込みません。同じ Look を別の素材に当てたときに、iPhone 用の補正まで一緒に持ち運ばれてしまうと困るからです。

公開後に試すなら、まずはいつもの Preset (curve / grade の土台) や Look (Stone / Urban Creative LUT Pack や、保存済みの仕上がり) を選んでから、Advanced の Optics にある `Texture Softness` を少しだけ上げてみてください。効き方は素材によって変わります。髪、布、葉、細かい文字、夜のノイズが乗った素材ほど、上げすぎかどうかを見つけやすいです。

今回の更新は、Filmtone Desktop を「Mac で色を作って、音声付きの完成ファイルとして書き出す」方向にもう一段寄せるためのものです。派手な新画面より、書き出した後にそのまま使えることと、細かい輪郭の見え方を少し整えられることを優先しました。

v1.7 が公開されたら、いつものダウンロードページから置き換えられます。

## Publish Notes

- Replace the final line only after public update metadata reports v1.7.
- If the article links release notes, use the v1.7 notes after checksum is filled.
- Do not mention iOS 1.9 public availability from this draft.
