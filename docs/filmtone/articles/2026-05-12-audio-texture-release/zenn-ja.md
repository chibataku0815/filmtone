# Filmtone 通常動画書き出しの音声保持と Texture Softness 追加 ── 実装メモ

Status: candidate technical draft. Public release wording is gated until
Desktop public `1.7` and iOS public `1.9` are both true.

Publication switch:

- Before public truth: keep `次の更新に入れている`, `候補`, `今回の方針` framing.
- After public truth: change the opening to
  `Filmtone Desktop 1.7 / iOS 1.9 の実装メモです。` and remove the
  `まだ公開前の候補稿なので` sentence.

## この記事の位置づけ

Filmtone の次の Desktop / iOS 更新に入れている、通常動画書き出しの音声保持と `Texture Softness` の実装メモです。まだ公開前の候補稿なので、公開状態の表現は控えています。

この記事では、主に次の 3 点を扱います。

- 音声付き素材を通常動画として書き出すとき、出力 MP4 にも音声を残す。
- 書き出し成功の判定を、処理途中ではなく完成ファイル側で確認する。
- `Texture Softness` を、単純な blur ではなく、細かい輪郭や局所コントラストを動かす処理として設計する。

## 1. audio input を作るだけでは足りなかった

通常の動画書き出しで必要な条件は単純です。

- source に音声トラックがある
- 出力 MP4 にも音声トラックがある
- 書き出し成功と表示する前に、完成ファイル側でそれを確認する

実装中は、`AVAssetWriterInput` に audio input を追加した時点で安心しがちです。ただ、Filmtone ではそこを成功条件にしないようにしました。

理由は、ユーザーが使うのは writer の途中状態ではなく、完成したファイルだからです。

プレビューで音が聞こえること、writer に audio input があること、完成した MP4 に音声トラックが残っていること。この 3 つは似ていますが同じではありません。動画アプリでは、最後の 1 つだけが本番です。

今回の方針はこうです。

- source audio track を読む
- 通常の動画書き出しでは AAC audio として output に書く
- completed output file を再度開き、audio track の有無を確認する
- audio-bearing source なのに output に音声がなければ成功扱いにしない

iOS では、アプリ内録画クリップにマイク音声を含める方向も足しています。Desktop と iOS で細部の実装は違いますが、完成ファイル側で見るという考え方は揃えています。

ハイライト書き出しは、今回の範囲では source-audio disabled のままです。selected timeline segments から再構成する別の出口なので、通常動画書き出しと同じ claim にはしていません。

## 2. Texture Softness は blur ではない

もうひとつの変更は `Texture Softness` です。

目的は、画面全体をぼかすことではなく、細かい輪郭の成分 (detail layer) と局所コントラストを少しだけ弱めることです。

最近の iPhone やアクションカメラ系の素材は、撮って出しの時点で細かい輪郭がかなり立っていることがあります。そのままでも見やすいのですが、Filmtone 側で Preset / LUT / glow / grain / print 処理を重ねると、細い輪郭だけが強く残ることがあります。

普通の blur で解決しようとすると、別の問題になります。

- 文字が読みにくくなる
- 髪や布のエッジが溶ける
- 葉や建物の線が均されすぎる
- grain まで一緒に眠くなる

やりたいのはそこではありません。強い輪郭はなるべく残し、局所的に浮いた細かい acutance を少し落とすことです。

## 3. amplitude-gated bilateral detail layer

実装は、単純な平均化ではなく、近い明るさの周辺ピクセルから局所参照を作り、そこから浮いた detail layer を扱う形にしています。

大まかにはこういう考え方です。

```text
source frame
  -> local edge-preserving reference
  -> detail layer = source - reference
  -> gate detail by local amplitude / threshold
  -> subtract controlled detail amount
  -> continue into optics, glow, grain, LUT, print stages
```

ポイントは、Texture Softness を後段の blur として置かないことです。Desktop release notes では、edge optics、glow、grain、creative LUT、print processing の前に置いています。過剰に立った edge を glow に渡しすぎないこと、生成した grain を後から潰さないことが狙いです。

## 4. source detail bias は runtime-only にする

もうひとつ、素材情報が使える場合は conservative な `source detail bias` を足しています。

ただし、これは saved Look には保存しません。

ここは重要です。iPhone 由来の素材に少し効かせたい補正を Look の中に焼き込むと、その Look を別のカメラ素材に当てたときにも補正が付いてきます。それは Look の持ち運びやすさを壊します。

なので、考え方を分けています。

- Look / Preset: 持ち運ぶ色の意図
- Source Profile / source metadata: その素材を読むための手がかり
- source detail bias: runtime でだけ効く、控えめな補助

この分離は見た目のためだけではなく、記事や release note の claim を安全にするためにも効きます。`このカメラを完全に補正します` とは言わず、`使える素材情報がある場合に、控えめな runtime-only bias を使います` と説明できます。

## 5. native runtime と shared color truth

Filmtone は iOS / Desktop とも native runtime に寄っています。ただし、これは `Web を捨てた` という話ではありません。

初期の Filmtone は WebGPU / WebGL renderer と shared TypeScript の色ロジックから始まりました。React + Capacitor の iOS 版も、その renderer path を iPhone に持ち込むための合理的な選択でした。

その後、iOS の撮影、Live Look、AVFoundation export、Desktop の native macOS export では、その場の処理の質 (runtime quality) を native 側で持つ必要が出てきました。だから SwiftUI / AVFoundation / AppKit 側に降りています。

一方で、色の source of truth は shared core に置く。生成 Swift payload や検証を通して、native app が勝手に別の色思想へ分岐しないようにする。ここは Filmtone の実装方針としてかなり大事です。

## 6. 検証の粒度

今回の候補では、少なくとも以下を gate にしています。

- core / renderer / smart-look build
- iOS verification
- macOS verification
- Swift package tests
- targeted detail / schema tests
- copy / context checks
- `git diff --check`

ただし、Texture Softness の見た目は素材依存です。テストで壊れていないことは見られますが、すべての素材で最適とは言いません。広域の visual QA は、今後も素材を足しながら見る領域です。

## まとめ

今回やったことは、出口の信頼性と、細かい輪郭や局所コントラストを扱うための土台です。

音声は、完成ファイル側で見る。Texture Softness は、blur ではなく detail layer として扱う。source 由来の補正は runtime-only にして、Look の中に混ぜない。

動画アプリでは、プレビューではなく完成ファイルが最後の成果物です。そこを基準にして、音声と細部の処理を少しずつ詰めています。

---

公開前メモ:

- Desktop public `1.7` / iOS public `1.9` が揃うまで release wording にしない。
- Public article にする時は、冒頭を `Filmtone Desktop 1.7 / iOS 1.9 の実装メモです` に変える。
