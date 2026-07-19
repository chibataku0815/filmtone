# DaVinci Resolve 用フィルムダメージ OFX を「決定的に」作る ── Filmtone for DaVinci Resolve 実装メモ

Status: candidate draft（発売前）。公開状態・公開価格・発売日・対応環境の
公言は monetization progress.md（coordinator 所有の truth）で owner 承認が
確認できてからのみ。この製品に iOS / Desktop 用 truth script は適用されない。

Publication switch:

- Before launch: `候補`, `発売時`, `予定` の framing を保つ。`公開しました`
  `now available` は使わない。
- After launch（owner 承認後）: 冒頭を実装メモとして確定させ、価格・発売日・
  購入リンクを確定値へ置換する。

TOC policy: Zenn は右サイドバーで H2 / H3 から目次を自動生成する。本文に手動の
「## 目次」は書かない。H2 は単独で読んで意味が通るようにする。

---

Filmtone for DaVinci Resolve は、DaVinci Resolve のグレーディングにフィルムの「傷み」を足す OpenFX（OFX）プラグインです。埃・繊維（ゲートに挟まった毛）・傷・シミ・ゲート際の汚れ ── 実際にフィルムを映写・保管・搬送したときに付く痕跡を、クリップや Color ノードに合成します。色そのものは変えません。

実装は native の OFX Filter プラグインで、傷みの描画は Metal の single-pass。スキャン素材のライブラリは持たず、すべて手続き的（procedural）に生成します。ライセンス検証は ed25519 署名ファイルのローカル照合で、ネットワークコードは 0 行。配布は署名・notarization・staple 済みの `.pkg` です。OFX 識別子は `com.chibatakumi.filmtone.resolve`。この記事は、その 3 つ ── 決定的な傷み、render scale から独立した配置、オフラインのライセンス ── の設計メモです。

## 何を作ったか ── DaVinci Resolve 用の手続き的フィルムダメージ

描くのは 5 系統の傷みで、それぞれ独立した amount を持ちます。全系統 amount = 0 のとき、出力は入力に対して bit-exact な identity（完全な no-op）になります。傷みが乗るのは、どれかの amount を上げたときだけです。

- **Dust**: 不定形で小さい粒が大半、まれに大きな塊。サイズ分布を歪ませ（skew）、均一な丸ドットにしない。フィルムの汚れは roll 上で不均一に集まるので、birth-frame でサンプルする slow なクラスタ変調を掛け、束になって濃くなる山を作る。
- **Fibers/Hairs**: フレーム端に anchor した曲がった線。根元が太く先が細る taper、先端だけ震える tremble。free-floating な縦線は出さない（"hair in the gate"）。
- **Scratches**: 長寿命の tramline と短命の cinch の 2 population が contract range を共有。break-up / gap / taper と、core + scuff の cross-profile。暗い傷が主で、まれな明るい傷は真っ白ではなく淡い緑〜シアン（乳剤側の染料抜け）。
- **Stains**: 乾いた水滴痕。density を rim（縁）に寄せ、内側は faint な veil。塗りつぶした半透明楕円ではなく、境界に沈着が寄った温かめの滲み。
- **Gate Wear**: 左右フレーム端のレール摩耗。左右非対称（片側が強い）。周辺を均一に落とす vignette とは別物で、端に沿った streaky な擦れとして描く。

暗い痕跡が主役、白い sparkle は従属。additive white が画面全体に乗る「オーバーレイ読み」を避けるため、まれな明るい傷以外は暗く落とす polarity で組んでいます。

## 傷みを「乱数で毎フレーム」ではなく「決定的」に描く

フィルムダメージの実装でありがちな 2 つの失敗が、(1) フレームごとに乱数で位置を振り直して popping させる、(2) スキャン素材を貼って tiling を見せる、です。前者は毎フレーム別物になって再現できず、後者は UHD で繰り返しが目立つ。

Filmtone の各アーティファクトは、canonical 座標上の cell / lane / slot と、cycle・per-event stream・frame index / host time の hash から決まる純関数です。同じ time / fps / params なら、何度レンダーしても同じ結果になります。

止まっている、という意味ではありません。lifetime と fade を持ち、held-visibility の floor で「出現 → しばらく居座る → 消える」を作り、per-frame の white-noise popping ではなく数フレーム刻みの stepped micro-instability（tick jump）で「生きている」動きを出す。傷は震え、埃はクラスタで増減し、毛は先端が揺れる ── それが乱数の暴れではなく、時間に沿って決まる liveliness になっています。tiling は per-event stream draw なので、繰り返しの stamp は構造的に出ません。

## プロキシと書き出しで配置がズレない ── render scale の分離

grade はプロキシ、納品はフルサイズ ── この 2 つで傷みの位置が変わると、最終確認をやり直すことになります。OFX の座標系では、spatial なロジックを canonical 座標で持ち、render scale は buffer I/O のときだけ変換するのが筋です（`ofxCoordSystem`）。

なので event の geometry（cell grid、radii、noise lattice、lane / slot、pattern phase）はすべて canonical に閉じていて、pixel 由来の量である `antialiasWidth` を配置計算に混ぜません。`antialiasWidth` が触るのは smoothstep の遷移幅と sub-pixel の可視 floor だけ。結果として、proxy と full-resolution が同じ event grid を解決し、プレビューと書き出しで埃・傷が同じ場所に出ます。

再現性の一番痛いところ ── preview と export でズレる ── を、座標系の設計で潰しています。

## ネットワークコード 0 行のライセンス検証（ed25519・オフライン）

設計原則は「プラグインにネットワークコードを一切入れない」。認証サーバーもオンラインアクティベーションもありません。ポストプロダクションのオフライン環境でそのまま動き、サーバー障害で顧客のレンダーが止まる事故が構造的に起きず、プライバシー説明も要らない ── プラグイン自体は何も送信しないからです。

- 形式: envelope（署名対象は payload のバイト列そのもの）。公開鍵はプラグインに埋め込み、署名済みの kind が検証鍵を内部選択。strict な canonical decode で、非正規・reorder・unknown field・tamper は invalid。
- 配置: `~/Library/Application Support/Filmtone/Filmtone.license`。購入版・trial 版で同じファイル名・同じ場所。
- 検証タイミング: インスタンス生成時と、ライセンスファイルの mtime 変化時のみ再読込。**レンダーごとの I/O はしない。**
- 期限: 購入版は `expiresAt` を明示 null（永続）、trial は発行 +14 日。expiry はレンダー要求時刻と比較する。
- 未ライセンス / 期限切れ / ファイル不正: 全機能そのまま動作し、最終パスでウォーターマークを合成（描画順は Dust → … → Watermark）。**ライセンス済み + 全 amount = 0 のときは bit-exact identity を維持**する。

TS 側は WebCrypto、C 側は ed25519 verify を vendored（zlib）で持ち、TS が署名した fixture と adversarial vector を C 側が同一判定することを cross-check しています。「正当な full license を誤って invalid 判定して、課金済みの顧客にウォーターマークを出す」という最悪ケースを、fixture parity で潰すのが狙いです。

## 配布と対応環境 ── 署名 / notarization / staple 済み .pkg

手動 zip コピーはインストール失敗 → サポート / 返金コストに直結するため、配布は `.pkg` インストーラにしています。Developer ID Application で bundle を、Developer ID Installer で pkg を署名し、notarization → staple 済み。`/Library/OFX/Plugins/Filmtone.ofx.bundle` に配置され、Resolve 起動時に load されます。

動作確認は macOS 26.5.1 と DaVinci Resolve Studio 21.0.2 の組み合わせで行った実測です。ほかのバージョンでの動作は別途確認が必要で、下限を保証するものではありません。内部評価バージョンは 0.1.0 / build 1。

素材や設定によって効き方は変わります。すべての映像に同じ amount が最適なわけではなく、カットの明るさや被写体に合わせて控えめから上げていく前提の道具です。

---

購入・トライアルの導線: 〔製品ページ / 購入リンク（Polar）は発売時に確定・ここに掲載〕

編集メモ:

- この製品に iOS / Desktop 用 truth script は適用されない。公開 claim のゲートは
  monetization progress.md（coordinator 所有）での owner 承認と、製品ページ /
  Polar checkout / pkg ダウンロードリンクの確定。
- 発売日は未定。`〔発売日 TBD〕` を確定後に実日付へ置換。
- 対応環境は macOS 26.5.1 / Resolve Studio 21.0.2 の実測のみ。`macOS 14.0+`
  `Resolve 21.x` のような下限保証は書かない。
- Zenn frontmatter（title / emoji / type: tech / topics / published）は投稿時に付与。
  本文に手動 TOC は書かない（右サイドバー auto）。
- 生成された recipe / adapter / contract 等の凍結された内部機構には踏み込まない
  （load-bearing でなく、誤記は verify-before-documenting 違反）。
