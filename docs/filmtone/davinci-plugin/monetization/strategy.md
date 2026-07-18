# Filmtone 課金戦略 計画書 (Monetization Strategy)

Date opened: 2026-07-18 JST
Status: 価格($49 / ローンチ $39)・14 日体験は 2026-07-18 にオーナー承認済み。
実装進行中(progress.md 参照)。公開クレームは MON-6 の release truth ゲート
通過後のみ。

この文書は DaVinci Resolve OpenFX プラグイン **Filmtone** の課金・販売の
長期正本である。進行状態は同ディレクトリの `progress.md` に置く。実装レーンの
正本は `docs/filmtone/davinci-plugin/strategy.md`であり、本文書は製品挙動の
正本ではない。2026-07-18時点の最新統合sourceはローカル`main` `cb9b465`に
あるが、`origin/main`への耐久化は未完了である。

## 0. 前提となる開発状態 (2026-07-18 時点)

- ソース実装: CONTRACT / HOST / ADAPTER / BREATH / WEAVE / DAMAGE / INTEGRATION
  すべてaccepted。monetization sourceと統合baseはsource commit `f8c4611`を含む
  remote branchから再取得可能。
- QUALITY: arm64 bundleビルド、Resolve 21.0.2.4 discovery、Color-page実描画、
  default identity、各module、combined、same-frame determinismまでpass。オーナー
  判定はFilm Damageのみpass、Film Breath / Gate Weaveはbelow passで、現行
  QUALITY taskはpartial acceptanceのままclosed。公開製品受入は未成立。
- monetization: MON-1 Accepted、MON-3 Review、MON-4 Running。販売外部基盤と
  context-binding版trial Workerの本番deployは完了したが、実送達・公開導線・
  法務・runtime gateは未完了。
  packaging / releaseは未着手。

課金作業は品質回復を妨げない。プラグイン本体に触る作業(MON-2)は、Film Breath
とGate Weaveの独立品質iterationがそれぞれowner passを得て、combined/public
product acceptanceが明示された後にのみdispatchする。それまでは`Blocked`とする。

## 1. 製品定義(課金対象)

| 項目 | 内容 |
|---|---|
| 製品名 | Filmtone for DaVinci Resolve |
| 内容 | Film Breath / Gate Weave / Film Damage の 3 モジュールを持つ 1 つの OFX Filter |
| 対応環境 (v1候補) | DaVinci Resolve 21.x / macOS 14.0+ / Apple Silicon / Metal。Phase Dの実機互換性確認前は公開クレームにしない |
| 識別子 | `com.chibatakumi.filmtone.resolve` |
| 非対象 | フィルムエマルション・グレイン・ハレーション・入力色管理(strategy.md の Product Boundary に従う) |

## 2. 競合価格の実測 (2026-07-18 検証済み、記憶ベースではない)

| 製品 | 形態 | 価格 (USD) | 出典 |
|---|---|---|---|
| **Dehancer Breath and Damage** (Film Breath + Gate Weave + Film Damage の 3 点 = 機能的に完全な直接競合) | **サブスクのみ**(買い切りなし。Lifetime 選択肢に非存在をサイト上で確認) | 個人 Photo & Video プラン $29/月(年払い $348) に含まれる | dehancer.com/shop/davinci_resolve/breath, dehancer.com/pricing (ブラウザ実測) |
| Dehancer Pro for DaVinci Resolve | Lifetime | **$999**(2 席) ※レビュー記事の $449 は旧価格 | dehancer.com/pricing Lifetime タブ実測 |
| FilmConvert Nitrate (OFX) | 買い切り | $119(RRP $149)+ Halation 別売 $59 | filmconvert.com/purchase |
| Filmbox Looks | 買い切り / サブスク | $199 買い切り / $69 年 | videovillage.com/filmbox/buy |
| Filmbox Pro | 買い切り / サブスク | $999 買い切り / $349 年 | 同上 |
| CinePrint35 (PowerGrades) | 買い切り | $68.99(gate weave ノード含む) | tombolles.net/cineprint35 |
| CinePrint16 | 買い切り | $47 | tombolles.net |
| DaVinci Resolve Studio 内蔵 (Film Look Creator は Studio 専用、内蔵 Film Damage FX は機能限定) | Studio 本体に同梱 | $295(本体) | blackmagicdesign.com ほか |

読み取れる市場構造:

1. **完全一致競合(Dehancer Breath and Damage)は買い切りを売っていない。**
   この 3 点セットを買い切りで欲しい人に、市場は選択肢を提供していない。
2. 買い切り帯の相場: PowerGrade/DCTL 帯 $47-69、単機能 OFX 帯 $119-199。
3. Resolve 内蔵は「無料の下限」として存在するが、決定性(シード再現)・
   モジュール独立性・質感で差別化余地が明確(内蔵 Film Damage は機能限定)。

## 3. 価格決定(推奨案)

### 3.1 本体価格

| 項目 | 決定 |
|---|---|
| ライセンス形態 | **買い切り(perpetual)** |
| 通常価格 | **$49**(参考 ¥7,400 前後、決済プラットフォームの為替に従う) |
| ローンチ価格 | **$39**(発売から 30 日間。**固定額 $10 オフのクーポン**で実現 — 率 20% だと $39.20 になり表記と食い違うため) |
| 席数 | 1 ユーザー / 2 マシン(Dehancer Lifetime の 2 席、FilmConvert の 3 席と同水準) |
| 商用利用 | 可(予算制限なし。Filmbox の budget-tier 制は採らない) |
| アップデート | v1.x 無償。v2 メジャーは既存ユーザー 50% off |
| サブスク | **やらない**(決済・解約・比例配分の運用負担=個人開発の外殻。買い切りが差別化そのもの) |

ポジショニング 1 行: 「Film Breath / Gate Weave / Film Damage を、**単体の
買い切り OFX** として提供する。CinePrint35 の後段に置く processing layer」。

公開コピーの精密化(Codex レビュー Major 12): 「サブスク専売の市場に〜」の
ような広い主張はしない。正確な事実は「この 3 点**だけ**を買い切りで買う選択肢
が現在ない」(Dehancer の同 3 点は subscription プラン内のみ。Dehancer Pro
Lifetime $999 はフルスイートとして存在する)。また「Dehancer 相当」等の品質
parity を示唆する表現は使わない — 同**カテゴリ**の 3 モジュール構成、とだけ
言う。

### 3.2 価格の根拠

- **vs Dehancer**: 同機能 3 点はサブスク専売($29/月)。買い切り $49 =
  約 2 ヶ月分以下で永続。「サブスク疲れ」層への明確な代替。
- **vs CinePrint35 ($68.99)**: 推奨ノード順(strategy.md)で公式に companion と
  位置付けている製品より安い付属価格帯 → 同時購入の心理障壁が低い。
- **vs FilmConvert $119 / Filmbox Looks $199**: 半額未満で「個人開発なので安価」
  要件を満たす。
- **下限を $49 に置く理由(安売りしない理由)**: $19-29 は LUT パック帯の
  価格シグナルになり、決定性保証を持つ native Metal OFX の品質訴求と矛盾する。
  変動費 ~7% 構造では価格を半分にしても売上本数が 2 倍になる根拠がなく、
  ブランド毀損だけが残る。安価要件は「競合比」で満たす($999 の 1/20、
  $119 の 1/2.4)。

### 3.3 試用(トライアル)— 2 段構え

| 段 | 内容 | 入手 |
|---|---|---|
| 常設 | **未ライセンス状態 = 全機能 + ウォーターマーク**。時間制限なし | ダウンロードのみ。登録不要・即評価可 |
| 体験期間 | **14 日間ウォーターマークなし**(全機能クリーン出力)。期限後は常設 watermark 状態へ自動で戻る | メールアドレスで trial license を請求(1 メール 1 回) |

- 常設 watermark(Dehancer 型)が「登録なしで即試せる床」、14 日 clean trial
  (Filmbox 型)が「実案件で 1 本納品してみる」評価を可能にする。この製品の
  価値は微細な時間的挙動なので、実納品での評価が購入判断に直結する。
- 実装は §5 のライセンスファイルに `expires` フィールドを足すだけ。**トライアル
  のためのサーバー・オンライン認証は増えない**(期限は署名済みファイル内の値と
  システム時計の比較。購入版ライセンスは `expires` なし=永続)。
- 期限の UX: プラグインの License グループに読み取り専用で「Trial expires
  YYYY-MM-DD」を表示し、納品中に突然 watermark が出る事故を防ぐ。
- trial 配送は即時性が必須のため、発売時から自動化する(§5 Phase L2 の trial
  部分を前倒し。無料枠内で固定費 0 のまま)。
- **購入直後のブリッジにも使う**: full ライセンスは手動発行(SLA 24 時間以内・
  通常数時間)のため、購入確認ページで「待ち時間なしで使うには trial を即時
  取得」と案内し、購入者が発行待ちでブロックされない構造にする。trial 使用済み
  の購入者はブリッジ不可のため、購入メールの返信で優先発行する例外運用を明記
  (対応計画 §5)。
- 機能制限版・クレジットカード必須トライアルはやらない。

## 4. コスト構造 — 新規固定費ゼロ(本計画の不変条件)

**方針: 新規固定費を 1 円も作らない。すべてのコストを売上連動の変動費にする。**

| コスト項目 | 額 | 根拠 |
|---|---|---|
| ライセンスサーバー | **¥0** | 持たない(§5: 完全オフライン検証) |
| 決済プラットフォーム月額 | **¥0** | Polar Starter は月額なし・成果報酬のみ(既存アカウント、新規開設もなし) |
| 販売ページ | ¥0 追加 | 既存 portfolio (`apps/web`, Vercel) に追加 |
| Apple Developer Program | ¥0 追加 | iOS/macOS レーンで契約済み(サンク) |
| 署名・notarization | ¥0 追加 | 既存 Developer ID |
| 自動発行(trial + Phase L2) | ¥0 追加 | Cloudflare Workers + KV の無料枠と既存 Resend 契約(月50,000通、超過課金オフ)を使用 |
| 変動費(売上時のみ) | 約 7-8% + $0.50/本 | Polar org は2026-06-19作成のため5% + $0.50。国際カード1.5%とpayout手数料($2/出金月 + 0.25% + $0.25 + 越境 ~1%)も売上がある月にしか発生しない |

- **保証できるのは「新規固定費ゼロ」= 売上 0 本のとき継続支出 0 円**。月次で
  固定赤字が積み上がる構造は存在しない。
- 取引単位の下振れは存在する(正直に見積る、Codex レビュー Major 9):
  chargeback は Polar 規定で **$15/件** + 手数料非返還 -> 最悪 **約 -$18/件**。
  返金も決済手数料分(約 $2-3)は戻らない。いずれも通常販売 1 本の手取り
  (約 $44)で吸収できる規模であり、trial で試してから買える構造のため発生率は
  低い想定。ゼロにはならないことを前提に置く。
- $49 の 1 本あたり手取り: 約 $44-46。$39 なら約 $35-36。
- 唯一の非金銭コスト = 開発・サポート時間。これは赤字定義(金銭)外だが、
  サポート最小化設計(§5 のオフライン検証・§6 の pkg インストーラ)で抑える。

**禁止事項(この構造を壊すもの)**: 月額課金のインフラ契約、席数管理サーバー、
オンラインアクティベーション必須化、広告出稿の先行投資。導入する場合は
本計画書の改訂とオーナー承認を必須とする。

## 5. ライセンス機構(本質実装、最小)

設計原則: **プラグインにネットワークコードを一切入れない。**
(ポストハウスのオフライン運用に一発で通る・プライバシー説明が不要・
サーバー障害で顧客のレンダーが止まる事故が構造的に起きない)

| 要素 | 決定 |
|---|---|
| 検証方式 | ed25519 署名付きライセンスファイル(envelope 形式 — 署名対象は payload バイト列そのもの)のローカル検証。公開鍵はプラグインに埋め込み、署名済み kind が検証鍵を内部選択 |
| 実装 | TS 側は WebCrypto(依存ゼロ、実装済み)。C 側は orlp/ed25519 を vendored(**zlib license・複数ファイル**。LICENSE 同梱 + commit pin — 対応計画 §3) |
| 配置 | `~/Library/Application Support/Filmtone/Filmtone.license` |
| 内容 | 署名済み payload: 氏名 / メール / 製品 ID / エディション(v1 固定)/ kind / 発行日 / 注文参照 / **expiresAt(購入版は明示 `null` = 永続、trial は発行 +14 日必須)**。trial は未来日発行を拒否(1 通の有効期間を最長 34 日に制限。鍵漏洩時の失効はローテーションで) |
| 未ライセンス時 | 全機能動作 + deterministic watermark(最終パスで合成。Breath -> Weave -> Damage -> Watermark)。**expires 超過時も同じ状態に戻る** |
| 検証タイミング | インスタンス生成時 + ファイル mtime 変化時のみ再読込(レンダーごとの I/O はしない)。expires はレンダー要求時刻と比較 |
| 席数 enforcement | しない(規約 2 台 + 氏名入りファイルの社会的抑止のみ。アクティベーションは外殻) |
| 秘密鍵 | `~/.filmtone/secrets/`(非 iCloud 領域・0700)+ 1Password 保管。repo に置かない。full 鍵はクラウドに置かない。ローテーション/漏洩時手順は `scripts/license/README.md` |

発行フロー:

- **購入ライセンス / Phase L1(発売時)**: `scripts/license/issue.ts`(bun CLI)で
  オーナーが署名発行 → 購入メールへ返信添付。低ボリューム時は数分/日の運用。
- **trial ライセンス(発売時から自動)**: 製品ページのTurnstile付き請求フォーム→
  Cloudflare
  Worker(無料枠)が `expires = +14 日` で署名 → Resend で即時メール送付。
  1 メール 1 回の soft 制限は Workers KV(無料枠)で行う。trial は請求数が
  購入数より桁で多くなるため、手動運用にしない。
- **Phase L2(自動化、発売後早期)**: 購入側も Polar webhook → 同じ Worker に
  接続。手動 CLI は永続フォールバック。
- trial 乱用(別メールでの再請求)は許容する。常設 watermark 状態が下限として
  存在するため、乱用者は「watermark なし常用」ではなく「手間のかかる試用」を
  しているだけで、失うものは元々ない売上ではない。

## 6. 販売チャネル

**新規サービスは開設しない。オーナーが既に使える Polar(+その土台の Stripe)で
完結させる。**

| 優先 | チャネル | 判断 |
|---|---|---|
| 主 | **Polar**(既存アカウント、Merchant of Record) | 月額 0(Starter)。手数料は org 作成日で決まる: 2026-05-27 以前作成なら 4% + $0.40(Early Member、恒久)、以降なら 5% + $0.50。+国際カード 1.5%。MoR が VAT・消費税等を売主として処理 → 個人の税務境界リスクを構造的に除去。license key・ファイル配布(.pkg 配信に使える)・webhook 内蔵。Polar 自体が Stripe 上で動くため実質 Stripe 決済 |
| 使わない(直販として) | Stripe 直販 | MoR ではないため、海外販売の EU VAT 等の登録・納税義務が売主(個人)に残る。国内限定販売なら選択肢だが、この市場は海外が主戦場 |
| 不採用 | Lemon Squeezy / Paddle / Gumroad | 新規開設が必要でメリットなし(手数料は Polar と同等以下にならない。Gumroad は実質 ~13% + EU VAT 売主責任化) |
| 後日(外殻) | aescripts / Toolfarm 等のマーケットプレイス | 手数料 ~30-50%。露出目的で軌道に乗った後に判断 |
| 販売ページ | portfolio `apps/web` に製品ページ + Polar checkout | SNS 告知は外部プラットフォームで(portfolio スコープ外) |

規約類(発売前の最小セット、各 1 ページ): EULA(1 ユーザー 2 台・再配布禁止・
無保証)/ 返金 14 日(watermark trial があるため返金率は低い想定)/
販売者表記は Polar が MoR のため Polar 側。portfolio 側には問い合わせ先のみ。

## 7. 配布物(発売の最小完成形)

- 署名 + notarized **.pkg インストーラ**(`/Library/OFX/Plugins` へ配置。
  手動 zip コピーはインストール失敗 → サポート/返金コストに直結するため
  pkg は外殻ではなく必須)
- インストール後の確認手順 1 ページ(Resolve 再起動 → Effects に表示)
- ライセンスファイル配置手順(Finder で 1 ドラッグ)
- アンインストール手順(信頼の担保)
- 配布経路: Polar の購入者向けファイル配信(自前の配信インフラは持たない)

## 8. 売上の参考シナリオ(コミットではない)

固定費ゼロのため回収すべき先行投資はない(chargeback/返金による取引単位の
下振れは §4 のとおり存在する)。以下はモチベーション管理用の参考値。

| シナリオ | 本数 | 手取り概算 |
|---|---|---|
| ローンチ月(記事 + X 告知のみ) | 30 本 × $39 | 約 $1,050 |
| 巡航(月) | 10 本 × $49 | 約 $440/月 |
| 1 年累計(上記巡航) | 150 本 | 約 $6,300 |

価格連動の検証: 発売 60 日後に本数 × 価格を見て、$49 継続 / $59 へ改定
(値上げは既購入者に影響なし)を判断する。値下げは原則しない。

## 9. 決定が必要な事項(オーナー承認ゲート)

1. ~~通常 $49 / ローンチ $39 / 買い切りの承認~~ — **承認済み(2026-07-18
   チャット)**。14 日無料体験の追加も同日承認。
2. Film Breath / Gate Weaveの具体的failureと改善後owner pass、combined/public
   acceptanceは品質回復iterationで判断
3. watermarkの見た目(文言・位置・濃度)はMON-2実装時にオーナー視覚判断

実行仕様は [implementation-plan.md](implementation-plan.md)(対応計画書)が正。

名称について: **公開名は `Filmtone`。** DaVinci Resolve 向けと明示する
場合は説明句 `Filmtone for DaVinci Resolve`を使う。配布物名・ライセンス・
プラグイン表示・販売文面はすべてこの決定に従う。

## 10. Copy / History Impact

- 本計画書自体は公開物ではない。公開価格・発売日・対応環境の公言は品質回復、
  source耐久化、署名/notarization、互換性実測を含むrelease truth確認後のみ。
- Article Opportunity: **Full article**(発売時。ただしBreath / Weaveと
  combined/public acceptanceまではdraft/publishしない。filmtone-release-articles skill を
  使用。テーゼは §3.1 の精密化に従う: 「この 3 点だけを買い切りで買う選択肢を
  作った」— 市場全体をサブスク専売と呼ばない・品質 parity を示唆しない)。
- Change-History Opportunity: **Yes** — Filmtone が初の直接課金プロダクトを
  持つ転換点。

## Interrupt / Decision Log

- 2026-07-18: 初版作成。競合実測(Dehancer Breath and Damage = サブスク専売、
  Pro Lifetime $999 へ値上げ、CinePrint35 $68.99、FilmConvert $119、
  Filmbox Looks $199)に基づき、買い切り $49(ローンチ $39)・完全オフライン
  ライセンス・MoR 販売・新規固定費ゼロ構造を推奨として起案。
- 2026-07-18: latest mainのQUALITY split verdictを反映。MON-2をBlockedへ変更し、
  品質回復・source耐久化・内包OFX署名・version/compatibility truthを発売前提に追加。
- 2026-07-18 (改訂 1): オーナー指摘により販路を Lemon Squeezy 新規開設案から
  **既存の Polar** へ変更(新規サービスを増やさない)。Polar の MoR・license
  key・手数料(Early Member 4% + $0.40 / 新規 org 5% + $0.50)は公式・複数
  ソースで検証済み。「名称確定」を承認事項から削除 — 当時の判断は「名称変更は
  不要で、`Filmtone Finish` をそのまま公開名として扱う」(2026-07-19 の naming
  決定で撤回 — §9 と progress.md 改訂 13 を参照)。
- 2026-07-18 (改訂 2): オーナー要望により **14 日間の無料体験期間を追加**。
  常設 watermark trial の上に、署名ライセンスの `expires` フィールドで実装する
  clean trial を重ねる 2 段構え(§3.3)。サーバー・オンライン認証は増えない。
  trial 配送のみ発売時から Worker 自動化(無料枠、固定費 0 維持)。
- 2026-07-18 (改訂 3): 価格・体験期間のオーナー承認を記録し、実行仕様を
  **対応計画書 implementation-plan.md** に切り出し(2 鍵構成・スキーマ・
  受入条件・オーナー手順)。本書は戦略正本として据え置き。
- 2026-07-18 (改訂 4、Codex レビュー反映): 「絶対赤字にならない」を「新規固定費
  ゼロ + 取引単位の下振れ(chargeback 約 -$18/件)は存在」へ是正(Major 9)。
  ポジショニングを「3 点だけの買い切りが市場にない」へ精密化し parity 示唆を
  排除(Major 12)。ローンチ価格は $10 固定額クーポン(Minor 14)。ライセンスは
  envelope 形式 + trial 未来日拒否へ再設計(Blocker 1-3、詳細は対応計画書
  改訂 1)。full 手動発行の SLA 明示と購入者向け trial 即時ブリッジを追加
  (Major 10)。鍵保管を `~/.filmtone/secrets/` へ変更(Major 8)。
- 2026-07-18 (改訂 5、Codex 再精査反映): Status 行と §4 見出し(「絶対赤字
  回避」->「新規固定費ゼロ」)を実態に一致させ、trial 未来日拒否の効果記述を
  「1 通の有効期間 ≤34 日」へ精密化。trial 使用済み購入者の優先発行例外を
  §3.3 に追加。Worker 側の残指摘(B4 実効化・Turnstile fail-closed・Resend
  冪等性)は対応計画書 改訂 2 を参照。
- 2026-07-19 (改訂 6、naming 決定): 公開名を `Filmtone` に確定し、改訂 1 の
  「名称変更は不要」判断を撤回。§1 の製品名・識別子と §9 を同期。配布物は
  `Filmtone.ofx.bundle` / `Filmtone-<version>.pkg`、OFX 識別子は
  `com.chibatakumi.filmtone.resolve`。実装同期の記録は progress.md 改訂 13 以降。
