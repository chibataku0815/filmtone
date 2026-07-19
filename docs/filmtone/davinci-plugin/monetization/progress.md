# Filmtone 課金 進行書 (Monetization Progress)

Date: 2026-07-19 JST
Coordinator-owned: yes
計画正本: [strategy.md](strategy.md)(戦略)+
[implementation-plan.md](implementation-plan.md)(対応計画 = 実行仕様)/
実装レーン正本: `docs/filmtone/davinci-plugin/strategy.md`

状態モデルは実装レーンと同じ:
`Queued -> Ready -> Dispatched -> Running -> Review -> Accepted`、
側状態 `Paused / Blocked`。

## 現在地 (2026-07-19)

- **MON-1 承認済み**、**対応計画書作成済み**、**MON-3 実装完了・MON-4 の
  Worker 実装完了**(依存パッケージゼロ)。**Codex 外部レビュー 2 巡の反映まで
  完了**(改訂 5-6)— envelope 再設計 + Worker 強化後、adversarial 7 ケース +
  Worker 操作確認 11 ケース 全 PASS。MON-4 の発売ゲート(実送達・添付検証等)は
  未通過のまま Running。追加レビューの Resend 409 種別判定を
  反映し、`invalid_idempotent_request` だけを既受理扱い、concurrent / unknown
  409 は KV 未記録で再試行可能にした。
- 本番鍵ペア生成済み(`~/.filmtone/secrets/`)。full / trial key JSONは
  1Password Private vaultへdocumentとして保存済み(秘密鍵内容は非表示)。
- Phase C外部基盤: Polar製品($49 / ¥8,000)と固定額クーポン($10 / ¥1,600)、
  Resend domain検証とdomain限定送信key、Cloudflare KV / Turnstile本番widget /
  initial Worker deploy / secret 4件まで完了。規約・SLA文面も候補を作成済み。
  product identity同期済みsourceも2026-07-19に本番deploy済み。Version IDは
  `31e8956b-0ee6-4b67-8a79-5b4cf13618b0`。
- 残るMON-4発売ゲート: testing authorization後の実trial請求・メール送達・
  添付license検証、正しい本番Turnstile tokenのhostname/action成功、MON-6での
  trialフォームと購入メール文面配置、法務文面のオーナー最終確認。
- latest mainのQUALITYはResolve 21.0.2.4ホスト実描画までpassしたが、owner verdictは
  Damage pass / Breath・Weave below passでpartial acceptanceのままclosed。
  combined/public acceptanceは未成立。
- **MON-2 Core Accepted / MON-5 Accepted(2026-07-19・改訂 22 / 25)**:
  MON-2 は canonical parity 17/17 と Resolve 実機 enforcement 両方向確認済み。
  MON-5 は owner の Developer ID 署名・notarization・staple・インストール・
  Resolve 21.0.2 スモークまで完了。
- **Source durability Completed (2026-07-19)**: 統合baseとmonetization sourceを
  commit `f8c4611`として
  `origin/claude/davinci-plugin-pricing-plan-4cb87b`へpush済み。別checkoutから
  review済みsourceを再取得できる。名称同期差分も同日
  `refactor(ofx): align Filmtone product identity`として同ブランチへ
  commit/push済みで、名称同期版のsource durability gateは通過済み(改訂 14)。
- **Naming decision (2026-07-19)**: 公開名は `Filmtone`。DaVinci Resolve
  向けと明示する場合は説明句 `Filmtone for DaVinci Resolve`を使う。
  配布物は `Filmtone.ofx.bundle` / `Filmtone-<version>.pkg`、OFX 識別子は
  `com.chibatakumi.filmtone.resolve`に統一。旧生成契約の内部識別子は互換性資料
  として隔離し、公開コピー・配布名・新規実装には使用しない。
- **ローンチ実行の現在地 (2026-07-19)**: identity 移行は landed
  (`6104168` + push tip `1f0959a`、origin へ push 済み)。独立検証で build 成果物
  identity 一致・static consistency PASS・`git diff --check` clean・frozen 契約
  境界保全を確認。以降の critical path と担当ゲートは次節。2026-07-19 に owner が
  品質ゲートを **waived**(改訂 17): Breath/Weave の owner pass を待たず MON-2 へ進む。
- **MON-6 前提の owner 決定(2026-07-19・改訂 26)**: 公開 module scope を
  **Film-Damage-first** に確定(Breath/Weave は独立品質回復後の後続リリースへ、
  公開コピーでは一切非言及)。公開バージョンは既存の署名済み `Filmtone-0.1.0.pkg`
  を**再ビルドなしでそのまま使用**。対応環境表記は実測範囲(macOS 26.5.1 /
  Resolve Studio 21.0.2)のみに確定、広い互換範囲の追加検証はしない。ローンチ日は
  未確定のまま進行。**MON-4 row W(Worker deploy reconcile)を解消**: 本番稼働中の
  Version ID が `31e8956b-0ee6-4b67-8a79-5b4cf13618b0`(source `6104168`)である
  ことを確認。install guide 作成、portfolio 製品ページ scaffold(未 commit)。
  詳細は改訂 26 ログ。
- **MON-6 準備 3 stream 並列完了(2026-07-19・改訂 27)**: 発売記事(標準 5 媒体
  JP/EN draft)、owner runbook(Vercel/Polar 設定手順)、MON-4 検証手順書(実行なし)
  が出揃った。**新規判明**: Vercel は git auto-deploy 無効で GitHub Actions か
  CLI 経由の再デプロイが必要、Polar 購入メール文面は Custom Benefit の
  Private note が唯一の差し込み口、Gate 3(テスト購入)は Polar Sandbox で実金銭
  不要、**trial 利用者向け pkg 公開ホスト先が未決定の新規ギャップ**。詳細は
  改訂 27 ログ。

## ローンチ実行順序と担当ゲート(2026-07-19 現在地起点)

計画正本は [implementation-plan.md](implementation-plan.md)(= 課金 対応計画書)、
本書が進行書。ここでは現在地から発売までの critical path を担当ゲート付きで
一覧化する(新規の重複 plan は作らない)。

担当区分: **C**=Claude 自律可 / **C+auth**=owner の testing/実行 authorization
後に Claude / **O**=owner のみ(署名 material・本番 endpoint・公開承認・Git 操作)。

| # | ステップ | 担当 | ゲート / 前提 |
|---|---|---|---|
| G0a | Film Breath 独立品質 iteration | — | **2026-07-19 owner 判断で waived(改訂 17)**。MON-2 前提から除外し、将来の独立 iteration へ送る |
| G0b | Gate Weave 独立品質 iteration | — | 同上 — **waived(改訂 17)**。将来の独立 iteration へ送る |
| G0c | 公開 module scope 確定(all-three-as-is / Film-Damage-first) | O | **完了(改訂 26)**: Film-Damage-first に確定。既存 pkg は再ビルドしないため binary は 3 モジュールのまま(Resolve 上で Breath/Weave パラメータは操作可能)だが、公開コピー(製品ページ・記事・ガイド)では Film Damage のみを説明し Breath/Weave は一切非言及とする運用で対応 |
| H | renamed `Filmtone.ofx.bundle` の Resolve 内再検証(discovery / identity / determinism) | O | **完了(改訂 22 / 25)**: Resolve 21.0.2 で `.resolve` discovery・instance identity・license status 遷移を実測。GPU determinism は改訂 22 記載の狭い残存 |
| M2 | MON-2 LICENSE 実装(watermark + ed25519 + expires + status) | C+auth | **Core Accepted(改訂 22)**: canonical parity 17/17、Resolve実機 enforcement両方向確認済み。GPU determinism / placeholder watermark視覚だけを残存として記録 |
| M4 | MON-4 発売ゲート残(Resend 実送達 / Turnstile 実 token 成功 / 購入者 bridge 例外文面) | C+auth / O | 本番 endpoint 呼出しは owner authorization |
| M5 | MON-5 .pkg 署名 + notarization | O | **完了(改訂 25)**: owner 承認下で Developer ID Application / Installer 署名、notary Accepted、staple、実機 install / Resolve smoke 済み |
| M6 | MON-6 launch(製品ページ / 記事 / 価格公開) | C(記事 draft)/ O(portfolio・価格公開承認) | release truth gate + owner 承認 |
| W | Worker deploy 状態の reconcile | O | **完了(改訂 26)**: `npx wrangler@latest deployments list`(読み取り専用、Worker endpoint は未呼び出し)で本番稼働中が Version ID `31e8956b-0ee6-4b67-8a79-5b4cf13618b0`(2026-07-18T16:38:43Z UTC 作成、source `6104168`)であることを確認、改訂 15 の記録と一致。`f8c4611` は 1 つ前の deploy で現行ではない。**担当区分の訂正**: `bunx wrangler` はローカル cache 破損で失敗したが `npx wrangler` は owner の既存 OAuth セッションでそのまま認証済みだった — 本件は当初想定と異なり読み取り専用操作は C(Claude 自律)で完結可能 |

2026-07-19 owner 判断(改訂 17)で G0 品質ゲートを waived。MON-2 は改訂 22で
**Core Accepted**、MON-5 は改訂 25で**Accepted**。残る発売ゲートはMON-4の
実送達 / 本番token確認と、公開 module scope(MON-6 前に確定) / 価格公開。

## ワークストリーム一覧

実行仕様はすべて [implementation-plan.md](implementation-plan.md) の該当節を正とする。

| ID | 内容 | 仕様 | 依存 | プラグイン本体に触るか | State |
|---|---|---|---|---|---|
| MON-1 | 価格・ライセンス条件の確定 | strategy §3 | なし | 否 | **Accepted(2026-07-18 チャット承認)** |
| MON-2 | LICENSE 実装(watermark + ed25519 + expires + 状態表示) | 対応計画 §3 | 品質ゲート waived(2026-07-19 owner・改訂 17) | **是** | **Core Accepted(2026-07-19)**: build PASS・canonical parity 17/17・**Resolve 実機で enforcement 両方向 live 確認(改訂 22)**。残: GPU determinism(未実施=狭い残存)+ watermark 視覚 |
| MON-3 | 鍵・発行ツール(keygen / issue / verify) | 対応計画 §4 | なし | 否 | **Review — 実装・鍵生成・1Password保管済み。MON-2のCクロス検証待ち** |
| MON-4 | 販売基盤(Polar 登録・trial Worker・規約) | 対応計画 §5 | runtime gate・公開導線・法務確認 | 否 | **Running — product identity同期版deploy・安全な失敗系・外部表示名sync完了。実送達・公開導線・法務最終確認待ち** |
| MON-5 | 配布物(署名 + notarized .pkg) | 対応計画 §6 | MON-2 | 否 | **Accepted(2026-07-19)** — local `main` `0b5669a` から `Filmtone-0.1.0.pkg` を Developer ID 署名 + notarize + staple。macOS 26.5.1 / Resolve Studio 21.0.2 で install・discovery・license status 遷移を実測(改訂 25) |
| MON-6 | ローンチ(製品ページ・記事・価格公開) | 対応計画 §7 | MON-2〜5 + release truth | 否 | **Running(改訂 26)**: module scope / version / 対応環境の owner 決定完了、install guide 作成、portfolio 製品ページ scaffold 済み(別 repo・未 commit・env 未設定)。残: release article、Polar checkout URL、legal review、Vercel env 設定+redeploy、MON-4 残ゲート |
| MON-7 | 外殻(実売後のみ): 購入側自動発行(Phase L2)、marketplace 展開、edu/bundle 価格、Windows 版検討 | 対応計画 §5 L2 注記 | MON-6 後の実売データ | 一部 | Queued(着手条件未成立) |

## 実行順序

```text
MON-3 Review ───────────────────────────────────────────────┐
MON-4 Running ──────────────────────────────────────────────┼─ MON-6 launch
Breath / Weave品質回復 + combined/public受入 ──── MON-2 ─ MON-5 pkg ─┘

MON-7は発売後の実売で判断
```

MON-3 / MON-4の未deploy作業はMON-2と並行可能(プラグインに触らない)。
クリティカルパスは MON-2 -> MON-5 -> MON-6(2026-07-19 に品質ゲートを waived・
改訂 17。品質回復は発売前提から外れ、将来の独立 iteration へ)。

## 各ワークストリームの Done 条件

### MON-1 価格・ライセンス条件の確定 — Accepted

- [x] 買い切り / 通常 $49 / ローンチ $39(30 日)の承認(2026-07-18 チャット
  「金額は良いと思ってます」)
- [x] 14 日無料体験の追加(2026-07-18 オーナー要望により採用)
- [x] 1 ユーザー 2 台・商用可・v1.x 無償更新(異議なしのため確定扱い。変更は
  strategy.md 改訂で)

公開名は `Filmtone`に固定する。DaVinci Resolve 向けの説明句は
`Filmtone for DaVinci Resolve`を使う。

### MON-2 LICENSE 実装(プラグイン本体)

- [~] **2026-07-19 owner 判断で waived(改訂 17)**: Film Breath / Gate Weave の
  owner pass と combined/public acceptance は MON-2 の前提から外す。公開 module
  scope(all-three-as-is / Film-Damage-first)は MON-6 前に確定する
- [x] source durability gate(remoteからbaseとmonetization sourceを再取得可能)
- [ ] 未ライセンス時のみ deterministic watermark を最終パスで合成
- [ ] ライセンスファイル(ed25519)のオフライン検証。ネットワークコード 0 行
- [ ] `expiresAt` 対応(購入版 = 明示 null・永続 / trial = +14 日必須 + 未来日
  発行拒否。超過時は watermark 状態へ戻る)
- [ ] wire format の C 側実装は対応計画書 §2(envelope・厳密 decode・キー順序
  固定)に従い、TS fixture + adversarial vectors で同一判定を確認
- [ ] License グループに読み取り専用の状態表示(Licensed to ... / Trial expires
  YYYY-MM-DD / Trial mode)
- [ ] 検証はインスタンス生成時 + mtime 変化時のみ(レンダー毎 I/O なし)
- [ ] identity 不変条件の維持: ライセンス済み + 全モジュール off = bit-exact
  identity(実装レーンの Done 条件を破らない)
- [ ] watermark の見た目はオーナー視覚判断で確定
- [ ] 実装レーンの delegation.md に従い、immutable workstream plan
  (`workstreams/license.md`)を起票してから dispatch する

### MON-3 発行ツール — Review(2026-07-18 実装完了)

- [x] `scripts/license/{core,keygen,issue,verify}.ts` 実装(依存パッケージゼロ、
  Bun 内蔵 WebCrypto Ed25519)。package.json に `license:keygen/issue/verify` 追加
- [x] **Codex レビュー反映で envelope 形式へ再設計**(署名対象 = payload バイト
  列そのもの / 厳密 decode / kind 内部鍵選択 / trial 未来日拒否。対応計画書 §2
  改訂 1 参照)
- [x] 動作確認一巡(2026-07-18、デモ鍵): full/trial 発行 -> verify pass /
  改竄 -> signature mismatch / 期限 +20 日 -> expired、に加えて adversarial
  7 ケース全 PASS(trial 鍵での full 偽造 / 未来日 issuedAt / 非 canonical
  payload / 未知フィールド / date-only 日時 / 期限切れ / 鍵欠落)
- [x] 本番鍵ペア生成済み: **`~/.filmtone/secrets/`**(repo 外・非 iCloud 領域、
  dir 0700 / file 0600。`~/Documents` から移動済み)。
  公開鍵(埋め込み用・公開情報): full `4b887963416f325a290203b086caf40d811dd7724252f780f3c15fbfe7fdd376`
  / trial `39af05f555ecdf06702470a09b2c0384e0ff34457b25f148fa98ee0e232fa4e0`。
  `PublicKeys.h.snippet` 同所に出力済み(MON-2 で転記)
- [x] 鍵ローテーション + full 鍵漏洩インシデント手順を `scripts/license/README.md`
  に記録
- [x] `filmtone-{full,trial}.key.json` を 1Password Private vaultへdocument保存
  (2026-07-18、item metadataのみ確認。秘密鍵内容は非表示)
- [ ] C 実装(MON-2)とのクロス検証(TS 発行 fixture + adversarial vectors、
  MON-2 時に owner の testing authorization を記録して実施)

### MON-4 販売基盤

- [x] **既存 Polar アカウント**に製品登録($49 / ¥8,000、ローンチは
  **$10 / ¥1,600固定額クーポン** = $39)。新規サービス開設はしない
- [x] Polar org の作成日を確認(2026-06-19)し、適用手数料を
  5% + $0.50に確定
- [ ] .pkg を Polar のファイル配信 benefit に載せる(配信インフラ不要)
- [x] EULA / 返金14日 / trial privacy / full発行SLA・サポート導線の候補文書
  (`eula.md` / `refund-policy.md` / `trial-privacy.md` /
  `license-delivery-support.md`)を作成。公開前の法務最終確認は残る
- [x] trial Worker 実装(`infra/license-worker/`): `POST /trial` -> trial 鍵署名
  (+14 日)-> Resend 添付送付。**レビュー 2 巡反映済み**: streaming byte 上限
  4096(全量読込後の文字数判定ではない)/ 文字列型必須 / **Turnstile 必須・
  fail-closed(secret 未設定 = 500) + `action == filmtone_trial` + hostname allowlist** /
  IP 5 req/時 throttle / 既発行は generic
  `{"ok":true}` / KV は HMAC 識別子 + TTL 約 13 ヶ月 / **決定的 payload +
  Resend Idempotency-Key** / Resend `409` は `name` だけを判定し、
  `invalid_idempotent_request` のみ既送達扱い、concurrent は KV 未記録の
  `503` + `Retry-After: 2`、unknown / JSON 不正は KV 未記録の `502` /
  PII をログに出さない。従前のスタブ KV/fetch 操作確認 11 ケース全 PASS +
  `bun build` バンドル解決確認済み。今回の修正では testing authorization が
  ないためテスト・test-like verification は未実行
- [x] 初回Worker デプロイ(wrangler login / KV 作成 / secret 4 つ
  [TRIAL_PRIVATE_KEY / RESEND_API_KEY / TRIAL_HASH_SECRET / **TURNSTILE_SECRET
  (必須)**] / deploy — README 参照)+ Resend domain検証・domain限定key発行・
  Turnstile本番widget設定。Worker URL:
  `https://filmtone-license-worker.chiba-4f9.workers.dev`
- [x] hostname/action bindingとResend 409種別判定を含むsource commit `f8c4611`を
  remoteへ保存して再deploy。Worker Version ID:
  `627b6337-15d3-441c-a695-8accb47f9f9d`
- [x] product identity同期済みcommit `6104168`のWorkerを本番deploy。Worker
  Version ID: `31e8956b-0ee6-4b67-8a79-5b4cf13618b0`。同deploy後にtoken欠落
  `400 invalid_request`、不正token `403 verification_failed`を再確認。どちらも
  Turnstile/throttle/KV/Resendの処理順からメール送信・KV書き込みへ到達しない。
- [x] 外部表示名sync: Cloudflare Turnstile widgetはsitekey・domain・managed
  modeを維持して`Filmtone Trial`、1Password Environment
  `w4plqx7tjh2zmaojldj6r3jfp4`はID・変数を維持して`Filmtone Production`。
- [ ] **発売ゲート(未通過)**: Resend 実送達確認(実メール到達・添付検証)/
  正しいTurnstile hostname/action成功と欠落・不正・mismatch拒否 / trial使用済み
  購入者の優先発行例外を購入メールに明記
- [x] 本番Workerの安全な失敗系: token欠落は`400 invalid_request`、不正tokenは
  `403 verification_failed`。いずれもメール送信なし(2026-07-19)
- [x] 請求フォームの受け口を製品ページのTurnstile付きフォーム -> Worker直叩き
  に決定(Polar $0 checkoutはWorkerへの自動bridgeを持たないため)
- [ ] テスト購入 -> 受領メール -> ライセンス発行(手動 L1)の一巡確認
- [ ] trial 請求 -> 受信 -> 14 日後に watermark へ戻ることの一巡確認(時計を
  進めた検証で可)

### MON-5 配布物

- [x] `Resources/ProductVersion.mk`を内部評価version 0.1.0 / build 1 / macOS
  deployment target 14.0の単一正本として追加(公開versionは未確定)
- [x] OFX bundleをDeveloper ID Application + hardened runtime + timestampで先行署名
- [x] 署名済みbundleを格納する.pkgをDeveloper ID Installerで署名 + notarization +
  staple
- [x] macOS 14.0+ / Resolve 21.x候補の実機互換性を確認し、実測範囲だけを公開
  (今回の実測はmacOS 26.5.1 / Resolve Studio 21.0.2。下限14.0の実機確認ではない)
- [x] クリーン Mac 相当でのインストール -> Resolve 認識 -> watermark 表示 ->
  ライセンス配置 -> watermark 消滅の一巡確認
- [x] アンインストール手順の記載: Resolve終了後に
  `/Library/OFX/Plugins/Filmtone.ofx.bundle`を削除し、必要なら
  `sudo pkgutil --forget com.chibatakumi.filmtone.resolve.pkg`でreceiptを破棄して
  Resolveを再起動。ユーザーの`Filmtone.license`は明示的に削除しない限り保持する

### MON-6 ローンチ

- [ ] portfolio `apps/web` に製品ページ(価格・trial 説明・購入導線)
- [ ] release article(filmtone-release-articles skill、JP/EN)
- [ ] 公開クレームは品質回復、source耐久化、実装レーンDone、署名/notarization、
  version/macOS/Resolve実測を含むrelease truth確認後のみ
- [ ] ローンチ価格の終了日をカレンダー記録(30 日後に $49 へ自動復帰)

### MON-7 外殻(着手条件: 発売後に実売が立ち、品質保証段階に入った時のみ)

- [ ] Polar webhook -> Cloudflare Worker 自動発行(無料枠)+ Resend 送付
- [ ] marketplace(aescripts / Toolfarm)条件調査と出店判断
- [ ] 60 日レビュー: 本数 × 価格で $49 継続 / $59 改定判断(値下げはしない)

## 不変条件(全ワークストリーム共通)

1. **新規固定費を作らない**(strategy.md §4)。月額契約が必要になったら
   Blocked にして計画改訂へ戻す。
2. **プラグインにネットワークコードを入れない。**
3. 実装レーンの禁止事項(共有ファイル編集制限・coordinator 所有物)を課金
   作業でも破らない。MON-2 は license 専用領域のみ編集。
4. 公開価格・発売日・対応環境の公言はオーナー承認ゲートを通ってからのみ。
5. Git 操作(commit/push)はオーナーが行う。

## Verification State

- 競合価格: 2026-07-18 に公式ページ実測で検証済み(strategy.md §2)。
  Dehancer は JS 描画のためブラウザ実測、他は公式ページ fetch。
- Polar の手数料・MoR・license key・ファイル配信機能: 2026-07-18 に公式
  (polar.sh/resources/pricing, docs)+複数レビューで検証済み。適用手数料の
  確定(org 作成日2026-06-19、5% + $0.50)まで完了。
- gemini-search(agy)は OAuth 未認証で実行不可だった -> WebSearch/WebFetch/
  ブラウザ実測にフォールバック(CLAUDE.md の検索順序に準拠)。
- 作成済み: MON-3 ツール一式・本番鍵(`~/.filmtone/secrets/`)・Polar製品/
  クーポン・規約候補・Resend検証済みdomain/API key・Cloudflare KV/Turnstile/
  Worker本番設定。未作成: pkg・公開trialフォーム・MON-2。
- 2026-07-18 に Codex による外部レビューを実施(4 Blocker / 9 Major / 3 Minor)。
  全 Blocker と Major の大半をコード・計画へ反映済み(各文書の改訂ログ参照)。
  不採用: Durable Objects による KV 厳密化(外殻・soft 制限で足りる)。
- テスト実行・テストファイル作成: なし。CLI/Worker の動作確認は成果物自体の
  実行(運用確認)として実施。
- 2026-07-18 Phase A1: Resend `409` を JSON `name` で種別判定する修正を実装。
  `invalid_idempotent_request` だけを既受理扱いにし、
  `concurrent_idempotent_requests` は KV 未記録の `503` + `Retry-After: 2`、
  unknown / JSON 不正の `409` は KV 未記録の `502` とした。オーナーの testing
  authorization がないため、静的確認のみ実施。
- 2026-07-18 Phase A2: full / trial key JSONを1Password Private vaultへ
  documentとして保存し、item metadataのみで存在を確認。秘密鍵内容は開かず、
  表示していない。MON-3はCクロス検証待ちのためReviewを維持。
- 2026-07-18 Phase C基盤: Resend `fores-tone.co.jp` を検証し、送信専用・
  domain限定API keyを1PasswordとWorker secretへ保存。Cloudflare Workerを
  KV・本番Turnstile・secret 4件付きでdeploy。Polar製品/固定額クーポンと
  規約候補も準備済み。testing authorizationがないためendpoint呼出し、実送達、
  添付検証などの発売ゲートは実行していない。
- 2026-07-18 latest main adversarial remediation: QUALITY split verdictへ状態を同期し、
  MON-2をBlocked化。Turnstile hostname/action binding、ProductVersion.mk、明示
  macOS deployment target、内包OFX先行署名target、source durability gateを静的
  実装・仕様化。testing authorizationがないためbuild、test、署名、deploy、endpoint、
  Resolve、notarization等は実行していない。
- 1Password MCPの同名更新が追記動作になったため、旧Environmentを削除せず
  retired名へ変更し、新しい`Filmtone Production`をMCPだけで再作成。
  必要5変数を重複なしで保存し、変数名一覧だけを確認した。
- 2026-07-19 product identity post-deploy gate: Worker Version
  `31e8956b-0ee6-4b67-8a79-5b4cf13618b0`を本番へdeploy。許可originからの
  token欠落は`400 invalid_request`、不正tokenは`403 verification_failed`。
  Turnstile widgetと1Password Environmentの表示名syncも完了。実trial請求、
  Resend実送達、添付`Filmtone.license`検証は実行していない。

## 進行ログ

- 2026-07-18: 開発状態の確認(OFX レーン全 8 ワークストリームの状態把握)、
  競合実測、計画書・進行書の初版起案。MON-1 をオーナー承認待ちに設定。
- 2026-07-18 (改訂 1): オーナー指摘を反映。販路を LS 新規開設案から**既存
  Polar** に変更(新規サービスを増やさない)。名称確定を承認事項から削除
  (当時の判断は「名称変更は不要、`Filmtone Finish` のまま」— 改訂 13 の
  naming 決定で撤回)。
- 2026-07-18 (改訂 2): オーナー要望で 14 日無料体験を追加(strategy.md §3.3)。
  MON-2 に `expires` 対応と状態表示、MON-4 に trial 自動発行(Worker、発売時
  必須)を追加。価格($49/$39)はオーナー了承の方向(正式承認は MON-1)。
- 2026-07-18 (改訂 3): **MON-1 を Accepted に更新**(価格・体験期間のチャット
  承認を記録)。**対応計画書 implementation-plan.md を作成** — MON-2〜MON-6 の
  実行仕様(編集領域・スキーマ・受入条件)、2 鍵構成(full = ローカルのみ /
  trial = Worker)、full 鍵をクラウドに置かない L2 方針を確定。MON-3 / MON-4 を
  Ready(着手可)へ。
- 2026-07-18 (改訂 4): **MON-3 実装完了**(`scripts/license/` 4 ファイル +
  package.json スクリプト 3 本。正常系・改竄・役割不一致・31 日上限・鍵違い・
  期限切れの 7 ケース動作確認 pass)。**MON-4 の trial Worker 実装完了**
  (`infra/license-worker/`、バンドル解決確認済み・未デプロイ)。本番鍵生成済み
  (公開鍵 hex は MON-3 節に記録)。Bun/Workers の WebCrypto Ed25519 ネイティブ
  対応を実測確認したため外部依存ゼロで実装(supply-chain 面で署名ツールに最適)。
- 2026-07-18 (改訂 5): **Codex 外部レビュー(4B/9M/3m)を反映。** ライセンスを
  envelope 形式へ再設計(Blocker 1-3: 未来日拒否 / 署名対象=バイト列 / kind
  内部鍵選択)し、adversarial 7 ケース + 正常系 + Worker バンドルを再検証 —
  全 PASS。Worker を乱用対策込みに強化(Blocker 4 / Major 5, 11)。鍵を
  `~/.filmtone/secrets/` へ移動(Major 8)。文書は「絶対赤字」表現の是正
  (Major 9)、ポジショニング精密化(Major 12)、orlp zlib 訂正(Major 7)、
  $10 固定クーポン(Minor 14)、SLA + 購入者 trial ブリッジ(Major 10)、
  MON-2 仕様増強(Major 6)、`for(let i` 排除(Minor 16)を反映。公開鍵は
  鍵不変のため改訂 4 の記録から変更なし。
- 2026-07-18 (改訂 6): **Codex 再精査(2 巡目)を反映。** B4 を実効化(streaming
  byte 打ち切り・型必須・Turnstile fail-closed 必須化)、Resend 冪等性を決定的
  payload で成立させ 409 を既送達扱いに、時計操作と「≤34 日」記述の過大表現を
  是正、残存矛盾(旧テーゼ / クーポン表記 / Status 行 / §4 見出し)を除去。
  Worker はスタブ KV/fetch で 11 ケース操作確認 全 PASS。**MON-4 は Running
  のまま**(発売ゲート: Resend 実送達 / Turnstile 本番キー / 購入者 bridge
  例外運用が未了)。
- 2026-07-18 (改訂 7 / Phase A1): Resend `409` の一律成功扱いを廃止し、JSON
  `name` による response matrix を Worker / README / 対応計画へ同期。
  `invalid_idempotent_request` だけが KV 記録へ進み、concurrent は `503` +
  `Retry-After: 2`、unknown / JSON 不正は `502` で KV を記録しない。
- 2026-07-18 (改訂 8 / Phase A2): full / trial key JSONを1Password Private
  vaultへdocument保存。秘密値を表示せずitem metadataだけで2 itemを確認。
- 2026-07-18 (改訂 9 / Phase C基盤): Polar、Resend、Cloudflare KV、Turnstile、
  Worker deploy、secret 4件、規約候補を実環境状態へ同期。Resend現契約には
  日次上限・送信量alert設定がないため、超過課金オフとUsage監視へ置換。
- 2026-07-18 (改訂 10 / latest main adversarial remediation): QUALITYをpending
  ではなくpartial acceptance closedへ同期し、MON-2をBlocked化。Breath / Weave
  独立品質回復、combined/public acceptance、source durabilityを前提に追加。
  WorkerへTurnstile hostname/action binding、OFX buildへProductVersion.mkと
  macOS 14.0 deployment target、Developer ID Application先行署名targetを追加。
  build/test/deploy/sign/notarizationは未実行。
- 2026-07-19 (改訂 11 / source durability + Worker再deploy): review済み統合baseと
  monetization sourceをcommit `f8c4611`としてremote branchへpush。Turnstile
  hostname/action bindingとResend 409種別判定を含むWorkerを本番へ再deployし、
  Version ID `627b6337-15d3-441c-a695-8accb47f9f9d`を記録。実trial請求・実送達・
  添付検証は発売ゲートとして未実施。
- 2026-07-19 (改訂 12 / Worker本番失敗系): 許可originからのtoken欠落を
  `400 invalid_request`、不正tokenを`403 verification_failed`として拒否することを
  本番endpointで確認。メール送信は発生していない。有効token、action/hostname
  mismatch、実送達、添付license検証は未完了。
- 2026-07-19 (改訂 13 / naming): 公開名を `Filmtone`に固定し、
  配布物名・OFX識別子・ライセンス名・Worker送信文面・関連文書を同期。
  `origin/main`は現作業ブランチにすでに含まれ、追加mergeは不要だった。
  名称同期版のWorkerは未deployで、commit/pushとともに次回の発売ゲートとする。
  Copy / History Impact: 公開名の確定のみで機能・履歴主張の変更はない。
  Article Opportunity: Release-note only。Change-History Opportunity: No。
- 2026-07-19 (改訂 14 / naming同期の検証・commit): オーナー指示のautonomous
  taskとして名称同期差分を全件レビューし、rename 5ファイルとMakefile/include
  参照の完全性を確認。`make -C apps/filmtone-resolve-ofx` PASS —
  `Filmtone.ofx.bundle` / `Filmtone.ofx` / `com.chibatakumi.filmtone.resolve`
  (0.1.0 / build 1 / macOS 14.0)を生成し、binary文字列監査で
  chibatakumiドメイン識別子は全て`.resolve`系、`git diff --check` clean。
  **frozen契約境界(残置)**: `Sources/Generated/Contracts/`の生成artifact、
  外部manifest key、生成17-entry base parameter ID
  (`com.forestone.filmtone.finish.*`)、adapter/mapping型・関数名は外部
  visual-effect-core所有の凍結handoffのため旧識別子を互換性資料として維持
  (UIには非表示。改名にはCONTRACT改訂が必要)。文書側は、日付入り実測証跡
  (master progress のResolve host記録・workstream record・改訂1ログ)を
  実測時の旧識別子へ復元し、rename後bundleのResolve内再検証が未実施である
  ことを明記。Turnstile widget・1Password Environmentの実ダッシュボード
  表示名は本タスクで未確認(文書上の名称のみ同期)。名称同期版Workerの
  deploy・実trial送達・添付license検証は発売ゲートとして未実施のまま。
- 2026-07-19 (改訂 15 / product identity post-deploy gate): commit `6104168`の
  Workerを本番へdeployし、Version ID
  `31e8956b-0ee6-4b67-8a79-5b4cf13618b0`を記録。deploy後のtoken欠落は
  `400 invalid_request`、不正tokenは`403 verification_failed`で、sourceの
  処理順から両方ともthrottle/KV/Resendへ到達しない。Cloudflare Turnstile
  widgetを`Filmtone Trial`、指定1Password Environmentを
  `Filmtone Production`へ名称同期し、sitekey/domain/modeとEnvironment IDを
  維持した。MON-6のTurnstile付きtrialフォームが未設置のため、有効tokenを
  使う実trial請求、Resend実送達、添付`Filmtone.license`検証は未実施。
  rename後bundleのResolve内discovery / identity / determinism再検証も未実施。
  Copy / History Impact: 外部管理画面とWorker deployを確定済みproduct identityへ
  同期しただけで、公開release claimは追加していない。Article Opportunity:
  No story。Change-History Opportunity: No。
- 2026-07-19 (改訂 16 / launch 実行ゲート整理): identity 移行の landed を独立検証
  (build 成果物 identity 一致・static consistency PASS・`git diff --check` clean・
  frozen 契約境界 `Sources/Generated/Contracts/` / param ID
  `com.forestone.filmtone.finish.*` 保全)。発売までの critical path を担当ゲート
  付きで整理(新規の重複 plan は作らず本進行書へ集約)。先頭 G0(Breath / Weave
  品質)が owner-observed defect 待ちで、MON-2 は Blocked のまま。よってこのターンで
  着手できる非ゲート実装作業は無く、次の一手は owner の Breath/Weave verdict。
  Worker deploy 状態は改訂 15(`6104168` deploy 済み記録)と本タスク brief
  (`f8c4611` 現行)が矛盾するため owner reconcile 事項として surface
  (改訂 15 は日付・Version ID 付き coordinator 記録のため削除せず保持)。
  Copy / History Impact: 進行状態の記録のみで公開 claim なし。Git commit/push は
  未実施(owner 承認待ち)。
- 2026-07-19 (改訂 17 / 品質ゲート waiver・MON-2 Ready 化): owner が
  「品質バー変更 / スコープ縮小で MON-2 へ」を選択(AskUserQuestion)。これにより
  MON-2 dispatch の前提だった「Film Breath / Gate Weave の owner pass +
  combined/public acceptance」を **waived** し、MON-2 を Blocked -> Ready に更新。
  immutable workstream plan [license.md](workstreams/license.md) を起票
  (実行仕様は implementation-plan §2/§3)。**トレードオフ(明示)**: Breath/Weave は
  以前 owner bar 未達で、これを発売前提から外すのは品質基準の引き下げ。最終的な
  公開 module scope(all-three-as-is か Film-Damage-first か)は MON-6 前に確定し、
  それまで公開 quality/parity claim はしない。MON-2 内には残る owner ゲート
  (テスト実行・adversarial vector 検証の testing authorization / ウォーターマーク
  視覚確定 / ed25519 vendoring 承認)。Git: owner 承認により本改訂と 改訂 16、
  license.md を `docs(ofx): record launch gates and MON-2 license plan`
  として commit/push。Copy / History Impact: 進行・計画記録のみで公開 claim なし。
  Article Opportunity: No story。Change-History Opportunity: No。
- 2026-07-19 (改訂 18 / MON-2 crypto core 着手・checkpoint): owner 承認で inline
  実装開始。ed25519(orlp/ed25519 verify path、pin `b1f19fab`)を vendor 化し、
  `Sources/License/{PublicKeys.h, LicenseStore.h/.mm}` を実装。envelope decode /
  strict canonical 検証 / kind-bound Ed25519 検証 / trial skew+expiry を
  `scripts/license/core.ts` と一致するよう移植。`make` PASS(compile+link、
  LicenseStore symbol・identity 文字列確認、挙動は不変=verifier 未配線)。残: Metal
  WatermarkPass、render-graph 最終段統合、License param status、TS↔C クロス検証
  (testing authorization gate)。詳細は [workstreams/progress/license.md]
  (workstreams/progress/license.md)。Git: 本 checkpoint を owner 承認で commit/push。
- 2026-07-19 (改訂 19 / MON-2 watermark enforcement): `WatermarkPass.h/.mm`
  (決定的 trial ウォーターマーク、in-place・alpha 不変・extended-range 安全・
  output-bounds グローバル座標・埋め込み 5x7 font "FILMTONE TRIAL" 対角タイル)を
  実装し、`FilmtoneRenderGraph.mm` の最終段で非ライセンス時のみ合成、
  `FilmtonePlugin.cpp` の `isIdentity` を watermarked 時に false 化(host が必ず
  render)。**licensed 時は挙動不変で bit-exact identity 維持**。`make` PASS
  (symbol・埋め込み MSL 確認)。残る MON-2 コードは License param status 表示のみ。
  owner ゲート: ウォーターマーク視覚確定(既定は placeholder・2-3 候補提示予定)、
  TS↔C クロス検証の testing authorization、Resolve 実機確認。詳細は
  [workstreams/progress/license.md](workstreams/progress/license.md)。Git: owner 承認で commit/push。
- 2026-07-19 (改訂 20 / MON-2 status param・コード完了): 読み取り専用 License
  グループ status ラベル(eStringTypeLabel、非永続)を `FilmtoneParameters.h/.cpp`
  に追加し、`statusLine()`(Licensed to … / Trial — expires … / Trial mode
  (watermarked))を instance 生成時と changedParam 時に更新(パネル再表示依存の
  制約を明記)。**これで MON-2 の実装スコープは code-complete**、状態は
  delegation.md の **Review — verification blocked**(build PASS だが証明に owner
  authorization 必要)。残る owner ゲート: watermark 視覚確定、testing
  authorization(TS↔C クロス検証 + adversarial vectors)、Resolve 実機
  (unlicensed→watermark / full→clean / trial→clean→expired→watermark / tamper→
  watermark)。Copy / History Impact: プラグイン内部 UI ラベルのみで公開 claim
  なし。Article Opportunity: No story。Change-History Opportunity: No。Git: owner
  承認で commit/push。
- 2026-07-19 (改訂 21 / MON-2 canonical parity 検証 PASS): owner の testing
  authorization を受け cross-verification harness を作成
  (`scripts/license/parity/{gen_vectors.ts, harness.mm, run.sh}`)。TS core.ts が
  実鍵(`~/.filmtone/secrets`、embedded PublicKeys.h と一致)で 14 envelope を署名
  し各 verdict を記録、C++ `LicenseStore::evaluateBytes()` が全再現。**17 PASS /
  0 FAIL**(非 ASCII・JSON-escape・emoji surrogate の名前 3 件を含む — C++
  escapeJsonString が TS JSON.stringify と byte 一致)。crown-jewel リスク(正当
  full license の Invalid 誤判定→課金顧客
  watermark)を解消: full→licensed / trial→trial / expired→expired、非
  canonical・reorder・unknown・tamper・kind 越え・+3d skew・>31d・name>120・bad
  base64・sig 長・envelope 余剰 field は全て invalid で TS 一致。残(要 Resolve):
  GPU cross-command-buffer watermark ordering、Resolve 状態マトリクス、watermark
  視覚。Copy / History Impact: 内部検証のみで公開 claim なし。Git: harness + 記録を
  owner 承認で commit/push。
- 2026-07-19 (改訂 22 / MON-2 Resolve 実機 live 確認・core Accepted): 統合 bundle
  (`com.chibatakumi.filmtone.resolve`)を `/Library/OFX/Plugins` へ install し
  DaVinci Resolve で実クリップに適用。owner が live 確認: プラグイン load・
  param panel(spatial + film + Node Role + License 全 group)・**無ライセンス→
  trial watermark 描画**・**full.license→クリーン + `Licensed to Owner
  Verification`**。enforcement の両方向が実機で実証され MON-2 の核は Accepted。
  残 verdict 行(trial/expired/tampered)は harness 17/17 でカバー、licensed
  identity 不変は構造的に保証。**残存(owner 判断で未実施)**: GPU determinism
  (同フレーム二重 export の md5 比較)— watermark 帯 flicker の狭いリスクとして
  記録、remedy(source→output tracked intermediate)は用意済み。watermark 視覚は
  placeholder。次は MON-5(署名/notarization)。Copy / History Impact: 内部検証の
  みで公開 claim なし。Git: 記録を owner 承認で commit/push。
- 2026-07-19 (改訂 23 / identity 統一 + MON-5 足場 + 統合計画): owner が track 1
  (MON-5)+ 3(integration→main + identity 統一)を選択。**identity 統一**: 統合
  ブランチの plugin 登録 id を生成 compat id `.finish` から `com.chibatakumi.
  filmtone.resolve` へ(wrapper override、凍結契約は不変・表示名は Filmtone のまま。
  spatial group id `.finish.group.*` は cosmetic 残置=契約再生成が要る)。**MON-5
  足場**: `ProductVersion.mk`(0.1.0/build 1/macOS 14.0)+ 版数・deployment target を
  build/Info.plist へ配線 + sign-bundle target + `Scripts/package.sh`(sign→pkg→
  notarize→staple、署名 identity は owner keychain のみ・私は非接触)。build PASS・
  binary minos 14.0・登録 id `.resolve` 確認。integration `0b5669a` push 済み・main に
  ff 可能。計画は [launch-consolidation-plan.md](launch-consolidation-plan.md)。
  **残 owner ゲート**: main への ff(dirty primary worktree のため owner)/ 署名+
  notarize(Developer ID)/ monetization docs+harness の main への持ち込み。
  Copy / History Impact: 内部・配布準備のみで公開 claim なし。Article Opportunity:
  No story。Change-History Opportunity: No。Git: 記録を owner 承認で commit/push。
- 2026-07-19 (改訂 24 / main ff 実行 + MON-5 署名前提の実測): **track A2 完了** —
  primary worktree がクリーンだったため(改訂 23 の「dirty のため owner」は解消)
  `main` を `claude/davinci-ofx-integration`(`0b5669a`)へ ff。統合プラグイン
  (spatial + film + MON-2)が local `main` に前進。`origin/main` push は
  davinci+spatial+iOS レーン全体の初公開になるため owner 判断(未実施)。**MON-5
  署名は環境実測でブロック**: Developer ID **Application** 証明書はあるが
  **Installer 証明書が無い**(Apple Developer で作成要)+ **notary 資格情報未設定**
  (`notarytool store-credentials` 要、team C3G77H8NM6)。どちらも owner の Apple
  アカウントでのみ作成可 — 揃えば `Scripts/package.sh` が end-to-end で通る。Git:
  記録を owner 承認で commit/push。
- 2026-07-19 (改訂 25 / MON-5 signed package Accepted): owner 承認下で
  Developer ID Installer証明書をkeychainへ追加し、notary用keychain profile
  `filmtone`を作成(資格情報・Apple ID・passwordはfile / repo / logへ記録せず)。
  local `main` `0b5669a`の`apps/filmtone-resolve-ofx`で`make`後、
  `Scripts/package.sh`をDeveloper ID Application
  `takumi chiba (C3G77H8NM6)` / Developer ID Installer
  `takumi chiba (C3G77H8NM6)` / notary profile `filmtone`で完走。
  `build/Filmtone-0.1.0.pkg`(231,353 bytes、SHA-256
  `529e822d12eec97d06d352845108fd87ba9ad00cd06c2b6ccfd6a733ca062bc2`)を生成。
  bundle `codesign --verify --deep --strict`、pkg署名、notary submission
  `b9921ba8-ad05-4384-b546-d67ac028b646` = **Accepted**、staple / validate、
  `spctl -a -vv -t install` = accepted(`Notarized Developer ID`)を確認。
  pkgをsystem installし、receipt
  `com.chibatakumi.filmtone.resolve.pkg` version 0.1.0と
  `/Library/OFX/Plugins/Filmtone.ofx.bundle`の署名・package内binary一致を確認。
  macOS 26.5.1 / DaVinci Resolve Studio 21.0.2のowner単一accountを
  clean-equivalentとして既存licenseを一時退避し、Resolve logの
  `OFX: loading com.chibatakumi.filmtone.resolve`、Fusion Add Toolの`Filmtone`、
  instance id `ofx.com.chibatakumi.filmtone.resolve`、Status
  `Trial mode (watermarked)` -> test full license配置後
  `Licensed to Owner Verification`を実測。MON-2改訂22で確認済みの
  watermark -> clean enforcementを配布pkg由来instanceでも維持した。
  テストlicenseは`bun run scripts/license/parity/gen_license_files.ts /tmp/fl`で生成。
  終了時に元のlicenseをhash一致で復元し、追加したColor / Fusion test nodeを削除して
  projectを保存。別のclean user / macOS 14.0下限実機は未使用なので公開互換claimは
  今回実測のmacOS 26.5.1 / Resolve 21.0.2に限定する。artifactはlocal `main`の
  untracked `build/`に保持し、**origin/mainはpushしない**。
  Copy / History Impact: 署名・notarization・stapleと実測互換性はMON-6 release truthに
  使用可能だが、公開version / 対応範囲はowner承認まで公言しない。
  Article Opportunity: Release-note only。Change-History Opportunity: No。
- 2026-07-19 (改訂 26 / MON-6 owner 決定 + 準備着手): owner が AskUserQuestion で
  5 点を決定。**module scope = Film-Damage-first**(Breath/Weave は独立品質回復後の
  後続リリースへ、公開コピーで一切非言及)。**version = 0.1.0/build 1 をそのまま
  公開**(再ビルド・再署名・再notarize なし)。この 2 択の組み合わせにより、公開
  pkg の binary は 3 モジュールを含んだままで、Resolve 上では Breath/Weave の
  パラメータが引き続き操作可能な状態での発売になる — この tension を owner に
  提示し、フォローアップ確認で「Film Damage のみをマーケティング、Breath/Weave
  は完全非言及(binary からは削除しない)」を確定。**対応環境表記 = 狭い実測範囲
  のみ**(macOS 26.5.1 / Resolve Studio 21.0.2)、追加検証はしない。**ローンチ日 =
  未確定のまま進行**。
  - **MON-4 row W 解消**: `infra/license-worker/` で `bunx wrangler whoami` が
    ローカル cache 破損(`Cannot find module 'esbuild'`)で失敗したため
    `npx wrangler@latest` に切替。owner の既存 OAuth セッション
    (chiba@fores-tone.co.jp)でそのまま認証済みだった。読み取り専用の
    `wrangler deployments list` を実行(Worker endpoint は未呼び出し)し、本番
    稼働中が Version ID `31e8956b-0ee6-4b67-8a79-5b4cf13618b0`
    (2026-07-18T16:38:43Z UTC 作成 = 2026-07-19 JST 未明、source `6104168`)で
    あることを確認 — 改訂 15 の記録と一致し、タスクブリーフが挙げていた
    `f8c4611` は 1 つ前の deploy で現行ではないと確定した。Worker への新規
    deploy・endpoint 呼び出しは行っていない。
  - **install guide 作成**: `apps/filmtone-resolve-ofx/docs/installation-guide.md`
    (JP/EN)を新規作成。progress.md 改訂 25 と implementation-plan.md §6 に厳密
    grounding。作成後に scope 決定と時系列が前後した(dispatch 時点では
    Film-Damage-first が未確定だったため初稿が 3 モジュール表記)ことが判明し、
    Film Damage 単独表記へ訂正済み。残: Color ページ `Effects Library` の正確な
    ナビゲーション、Fusion `Add Tool` ウォークスルー、ウォーターマーク文言
    (`FILMTONE — TRIAL` はプレースホルダ)の 3 点は実機/スクリーンショット検証
    未実施(ブロッカーではない)。
  - **portfolio 製品ページ scaffold**(`chibatakumi-portfolio` repo、**未 commit**
    の working tree 差分): 新ルート `/filmtone/resolve`(既存 `/filmtone` 起点
    配下、Worker の `PRODUCT_URL`/`ALLOWED_ORIGIN` を変更せず満たす)。新規
    `resolve-plugin-info.ts`(価格・動作確認済み構成・技術識別子の集約)、
    `resolve/page.tsx`(LP 本体)、`FilmtoneResolveTrialForm.tsx`(Turnstile
    explicit render → Worker `POST /trial`)、`resolve-legal-ui.tsx` +
    `eula`/`refund`/`trial-privacy` の 3 サブページ(既存共有 `/filmtone/privacy`
    は「no-collection/no-account」を主張しており trial のメール収集と矛盾する
    ため統合せず独立ページ化。文面は
    `docs/filmtone/davinci-plugin/monetization/{eula,refund-policy,trial-privacy}.md`
    から忠実翻訳、**owner の法務レビュー未了の候補版**)。`messages/{ja,en}.json`
    に `filmtone-resolve` namespace 追加(既存 `filmtone-signature` 踏襲、JA/EN
    キー木一致検証済み)、`.env.example` に新規 env 4 件追記、`sitemap.ts` に
    新規 4 ルート追加。`tsc --noEmit`・`eslint`・`next build` すべてエラー 0
    (4 ルート ja/en 両 locale で SSG prerender 成功)。Git write なし
    (`AGENTS.md` の既存 owner 編集・`vendor/filmtone` submodule pointer とも
    未接触)。
  - **導入した env var(owner がVercel側で値設定 → 設定後は SSG のため
    再デプロイ必須)**: `NEXT_PUBLIC_FILMTONE_RESOLVE_TURNSTILE_SITE_KEY`
    (必須、未設定時はフォーム側で「一時的に利用不可」表示にフォールバック)、
    `NEXT_PUBLIC_FILMTONE_RESOLVE_POLAR_CHECKOUT_URL`(必須、未設定時は購入 CTA
    を「近日公開」無効表示)、`NEXT_PUBLIC_FILMTONE_RESOLVE_TRIAL_ENDPOINT`
    (任意、既定は本番 Worker URL)、`NEXT_PUBLIC_FILMTONE_RESOLVE_PKG_DOWNLOAD_URL`
    (任意、配布 pkg 直リンク・version/配布先とも TBD)。
  - **Polar 連携**: repo 内に既存の Polar 連携なし(既存決済導線は Stripe
    donation のみ)。購入確認ページ/受領メールも Polar ダッシュボード側設定
    でこの codebase 外のため、実装はしていない。**購入メール向けの trial
    ブリッジ+優先再発行文面(JA/EN)は draft 済み**(MON-4 owner-operation 7 の
    既存文面を踏襲)— owner が Polar 側に貼り付ける前提で本ログに記録:
    JA「full ライセンスは購入確認後 24 時間以内(通常は数時間以内)にメールで
    お届けします。待ち時間なしで使い始める場合は、14 日 trial をご利用くださ
    い。trial 使用済みの場合は、この購入メールへ返信いただければ優先して発行
    します。」/ EN “Your full license will be emailed within 24 hours of
    purchase confirmation (normally within a few hours). To start
    immediately, use the 14-day trial. If you have already used the trial,
    reply to this purchase email for priority full-license issue.”
  - **残る owner 手順**(MON-6 続行の前提): ① Vercel に Turnstile site key と
    Polar checkout URL を設定し再デプロイ ② DaVinci Resolve 版の実 Polar
    checkout URL の確定 ③ EULA/返金/trial-privacy 3 文書の法務レビュー
    ④ Polar ダッシュボードでの返金ポリシー同期+上記購入メール文面の設定
    ⑤ install guide 公開後、製品ページの `fullGuideNote` プレースホルダを実
    リンクへ差し替え ⑥ portfolio 側変更のレビュー・commit(現状 working tree
    のまま、owner 承認まで commit しない)。
  Copy / History Impact: 製品ページ・法務ページ・install guide の draft 一式が
  発生したが、いずれも未公開(portfolio 側は未 commit、filmtone 側の
  install guide は本ブランチへ commit されて初めて配布可能になる)。公開クレーム
  は追加していない。Article Opportunity: Release-note only(本改訂は準備進捗の
  記録であり、実発売時の Full article 判断は strategy.md §10 のまま)。
  Change-History Opportunity: No。Git: 本タスクブリーフの pre-authorization に
  より本改訂を `claude/davinci-plugin-pricing-plan-4cb87b` へ commit/push
  (dc1451b の merge lineage を経由しない独立コミットとして作成)。portfolio 側の
  変更は別 repo・別ゲートのため今回 commit しない。
- 2026-07-19 (改訂 27 / MON-6 準備を並列 3 stream で実行・director 統合): owner の
  指示で並列作業計画書 [launch-parallel-work-plan.md](launch-parallel-work-plan.md)
  と lock board `.claude/tasks/ACTIVE-PARALLEL-TASK.md` を作成し、`.ai/parallel-work.md`
  協調プロトコルに従い 3 stream を本チャット内で background 並列実行(ディレクター
  = 本チャット)。全 stream ともファイル非重複・production 操作なし・commit なし。
  各成果物はディレクターが通読・grounding 検証してから採用。
  - **S1(記事 JP/EN)**: `docs/filmtone/articles/2026-07-19-davinci-resolve-film-damage-release/`
    に note-ja / zenn-ja / medium-en / hashnode-en / behance-case の標準 5 媒体を
    draft(Behance のみ visual asset が実レンダー待ち placeholder)。`filmtone-release-articles`
    skill 本体(`.claude/skills/filmtone-release-articles/SKILL.md`)を直接読んで
    house style に従った(agent 側に Skill tool が無かったため)。Breath/Weave =
    0 件・絶対語 = 0 件・競合名 = 0 件・grain/vignette を feature として言及 = 0 件を
    grep で機構化確認。発売日は全記事で `〔発売日 TBD〕` placeholder。iOS/Desktop 用
    truth script は本製品に適用対象外と判断(理由: 消費者アプリ専用のスクリプトで
    DaVinci プラグインには不整合)、本製品の truth は本 progress.md に依拠。
  - **S2(owner runbook)**: `mon6-owner-runbook.md` を新規作成。**新規判明事項**:
    (1) portfolio の Vercel deploy は **git auto-deploy 無効**(`vercel.json` の
    `deploymentEnabled: false`、private submodule `vendor/filmtone` を Vercel 側
    build が取得不可のため)。env 設定後の反映には GitHub Actions
    `vercel-production-deploy.yml`(`workflow_dispatch` 対応)か、repo root での
    `bunx vercel deploy --prod --yes` が必要 — **ダッシュボードの「Redeploy」単独
    では新しい `NEXT_PUBLIC_*` が焼き込まれない**。
    (2) Polar の確認メール本文は編集不可(docs 確認済み)。購入メール文面
    (trial ブリッジ+優先再発行 note)の唯一の差し込み口は **Custom Benefit の
    Private note**(checkout success page + 確認メール + Customer Portal の 3 箇所に
    レンダリング)。返金ポリシーも Polar に設定項目は無く、製品 Description への
    明記+手動返金が実務。
    (3) Checkout Link に $10 固定 discount を preset すれば $39 が自動適用され、
    ローンチ終了時は preset を外すだけで URL 不変・再デプロイ不要。
    (4) **新規ギャップ(未解決の owner 判断事項)**: trial 利用者が pkg 本体を入手する
    公開経路が現状ない。Worker は trial に `.license` のみ送付し、Polar の
    File Downloads benefit は購入者限定の個別署名 URL のため trial には使えない。
    `NEXT_PUBLIC_FILMTONE_RESOLVE_PKG_DOWNLOAD_URL` に公開 HTTPS 直リンク
    (例: Cloudflare R2 / Vercel Blob)を設定するか、trial 導線の pkg 配布方法を
    別途決める owner 判断が必要。
  - **S3(MON-4 検証手順書、実行なし)**: `mon4-verification-runbook.md` を新規作成。
    **Gate 1**: garbage token は Siteverify の `success` 判定で短絡するため
    action/hostname mismatch 分岐を検証できない — 実 widget solve が必須と明記
    (curl のみでは既確認の invalid-token ケースの再現に留まる)。**Gate 2**: 実行には
    portfolio 側 scaffold の commit + Vercel env 設定 + redeploy が前提のため
    現状 blocked。**Gate 3**: **Polar Sandbox**(`sandbox.polar.sh`、Stripe test card
    `4242 4242 4242 4242`)を primary path として発見 — 実金銭不要でテスト購入から
    manual issuance までの一巡を検証可能(本番実購入+返金は fallback)。**Gate 4**:
    `LicenseStore::evaluate()` が render 毎に `::time(nullptr)` から Trial/Expired を
    再導出することを source(`LicenseStore.h:40-43,66-67` / `.mm:286-287,343-344,401-402`)
    で確認し、clock-forward 手順を具体化(1 日 trial での低擾乱 variant も用意)。
    macOS `date` set-operand の年-先頭フォーマット bug を自己検出・修正済み
    (誤ると年が大きくずれる高リスク行だった)。owner 確認前の実行はしていない。
  - **並列化しなかった項目**(引き続き owner 専任、次節参照): Vercel env 実設定、
    Polar checkout URL 確定・pkg アップロード、法務レビュー、MON-4 実実行、
    trial pkg 公開ホスト先の決定、portfolio 側 commit。
  Copy / History Impact: 記事 draft 一式が発生したが、いずれも
  candidate/pre-launch framing で未公開(publish switch 手順を各記事末尾に記載)。
  Article Opportunity: 本改訂で Full article(標準 5 媒体)の draft 化が完了 —
  公開判断は owner 承認待ち。Change-History Opportunity: No。Git: 本タスクブリーフの
  pre-authorization により `claude/davinci-plugin-pricing-plan-4cb87b` へ
  commit/push(dc1451b の merge lineage を経由しない独立コミット)。
- 2026-07-19 (改訂 28 / MON-6 本番公開実行 — 製品ページ live・Polar publish・
  checkout 開通): owner の段階承認(Polar 4 件一括 / 未レビュー法務文書のまま
  デプロイ / trial pkg は portfolio public/ 直置き / Polar rename+publish+
  Checkout Link 作成 / マーケ文追加 / File Downloads benefit スキップ)を受け、
  ディレクター(本チャット)+ Opus agent 群で実行。
  - **Vercel env(Production)3 件設定**: `NEXT_PUBLIC_FILMTONE_RESOLVE_
    TURNSTILE_SITE_KEY` = `0x4AAAAAAD4iGBpaJO9m-yJG`(公開値。Cloudflare
    dashboard から browser agent が読取り — 許可 hostname 2 件・Managed mode も
    期待通りを確認)、`_POLAR_CHECKOUT_URL`、`_PKG_DOWNLOAD_URL`。owner が
    Chrome で Cloudflare / Polar にログインして unblock(Claude は認証情報に
    非接触。wrangler token 流用の API 読取りは classifier が阻止 — 妥当と判断し
    断念)。
  - **trial pkg 公開配布**: `Filmtone-0.1.0.pkg` を portfolio
    `apps/web/public/filmtone/` へ配置(SHA-256 一致確認)。公開 URL
    `https://www.chibatakumi.studio/filmtone/Filmtone-0.1.0.pkg`(実測 200・
    231,353 bytes 一致)。**設計整合**: watermark モデルではバイナリは無料配布が
    意図で、課金対象は license — 購入者も trial も同一公開 URL を使う。Polar 側
    File Downloads benefit は owner 判断でスキップ(後付け可能)。
  - **Polar 本番確定**(browser agent、Polar API GET で独立検証済み):
    製品名を旧 `Filmtone Finish for DaVinci Resolve` から確定公開名
    `Filmtone for DaVinci Resolve` へ rename(id `3fee7c75-3d96-4b31-8608-
    b043e2b9df4f`)。Description にマーケ 4 段落(JP/EN、価格数値なし=Polar 表示
    に委譲、Film Damage 単独スコープ)+既存返金 2 行(936 字)。draft →
    **public へ publish**。**Checkout Link 作成**:
    `https://buy.polar.sh/polar_cl_YczulsJVo3gsFolUEX1nyfn1L26mQFmQ9q85H48xMuY`
    — FINISH39(-¥1,600)preset・discount code 入力欄無効。実 checkout 画面で
    ¥8,000 → **¥6,400 自動適用**を目視確認。価格(¥8,000/$49)・既存 Custom
    benefit・discount object は不変。
  - **本番デプロイ 2 回**(`vercel deploy --prod`、working tree 直上げ):
    1 回目 dpl_8K6G8Je6uouh5YwGPWcgemtdNrwy で製品ページ・法務 3 ページ公開。
    検証で pkg DL リンク未配線を発見(helper `filmtoneResolveReadPkgDownloadUrl`
    が定義のみで未消費)→ Opus が install セクションに DL CTA を配線
    (page.tsx + messages ja/en、build PASS)→ 2 回目デプロイで解消。
  - **live 検証**: `/filmtone/resolve`(ja=bare)200・`/en/` 200、site key /
    checkout URL / pkg DL CTA とも両 locale で焼き込み確認。法務 3 ページ
    (eula/refund/trial-privacy)200。**Breath/Weave は可視テキスト 0 件**
    (HTML 内 14 hit は既存 Desktop v1.8 release note・lattice-breath 記事の
    i18n payload 由来で本製品コピーではない — script 除去 grep で確認)。
  - **残 blocker(重要)**: ① **Polar org が test mode** — checkout に
    "Payments are currently unavailable" 表示、実決済不可。owner の account
    activation(本番決済有効化)が必要。② discount 表示名
    `Filmtone Finish Launch $10 Off` が旧名のまま買い手に見える(discount
    object 非接触の約束により残置 — 表示名の rename を推奨)。③ **portfolio
    変更は deploy 済みだが未 commit** — 本番は Vercel 上にのみ存在し working
    tree が正本の状態。durability のため owner 承認後の commit/push が必要。
    ④ 法務 3 文書は owner が「未レビューのまま公開」を明示選択(改訂 28 時点で
    公開中。レビュー後の差し替えは再デプロイで可能)。
  - **MON-4 の unblock**: 製品ページが live になったため Gate 1b/1c(実 widget
    solve での action/hostname mismatch)、Gate 2(実 trial 請求 → Resend 送達 →
    添付検証)が実行可能になった。Gate 3 は Polar activation 後(または
    sandbox org 作成後)。実行は各 action 直前の owner 確認を維持。
  Copy / History Impact: 製品ページ・法務ページ・購入導線が**実際に公開**された。
  公開クレームは承認済み事実(Film Damage 単独・実測環境・価格)のみ。
  Article Opportunity: 記事 5 本は draft のまま(公開は発売日確定・owner 承認後)。
  Change-History Opportunity: **Yes** — 初の直接課金プロダクトの購入導線が
  技術的に開通した転換点(実売は Polar activation 待ち)。Git: 本改訂を
  `claude/davinci-plugin-pricing-plan-4cb87b` へ commit/push。
- 2026-07-19 (改訂 29 / **MON-4 Gate 2 PASS** — 実 trial 送達 + 有効 token 成功、
  portfolio commit、Polar activation 前進): owner 承認の下で実行。
  - **Gate 2 完全 PASS(実測)**: ライブフォーム
    (`chibatakumi.studio/filmtone/resolve` #trial)から
    `chiba+fttrial1@fores-tone.co.jp`(plus-alias、runbook 準拠)で 1 回だけ実請求。
    **Turnstile は Managed 自動通過**(インタラクティブ challenge 非表示 = agent
    の bot 検証突破なし)。メールはほぼ即時到達: From
    `Filmtone <filmtone@fores-tone.co.jp>`、件名
    `Filmtone — 14日無料体験ライセンス / 14-day trial license`、
    2026-07-19T13:21:52Z、添付 `Filmtone.license`(547 bytes)。
    `license:verify --trial-pub 39af05f5…` = **exit 0 / status trial / kind
    trial / issued 2026-07-19T13:00:00Z(hour-truncated)/ expires
    2026-08-02T13:00:00Z(正確に +14 日)**。`name` = email はフォームが氏名を
    収集しない Worker 既定で想定内。**この成功により「正しい本番 Turnstile
    token の hostname/action 成功」ゲートも同時に実証**(本番ページ実 solve →
    siteverify 通過 → row 7 送達到達のため)。限界の記録: Worker POST の
    wire-level status code は network 追跡開始タイミングの都合で未取得
    (UI 成功分岐 + 新規署名 license の実到達が 200 経路の実証。1 リクエスト
    厳守のため再送せず)。KV には alias の HMAC が約 13 ヶ月記録された(想定
    どおり)。残る MON-4 検証: action/hostname mismatch の実 solve 拒否
    (Gate 1b/1c)、テスト購入→手動発行(Gate 3、Polar activation 待ち)、
    clock-forward 失効(Gate 4、owner の sudo 必要)。
  - **portfolio commit `0ed86b3a`**(owner 承認): 製品ページ一式 + pkg(12
    ファイル、+1,719 行)を portfolio `main` へ commit。owner の既存編集
    `AGENTS.md` は除外・未接触。**push は未実施** — portfolio `main` には
    owner の未 push commit 5 件(corona 記事系 + docs governance)が先行して
    積まれており、push はそれらも同時公開になるため owner 判断待ち。
  - **Polar activation 前進**: account review の正確な導線を実測特定 —
    ダッシュボードに「test mode」文言は存在せず(checkout ページ専用表現)、
    正本は **Finance → Account(`/dashboard/forestone/finance/account`)**。
    チェックリストの「Add your product website」を Claude が実行
    (`https://www.chibatakumi.studio/filmtone/resolve` 受理・緑チェック)。
    残り必須 2 件は owner 専任: **Verify identity(身分証)/ Connect payout
    account(口座)** — いずれも Claude の禁止事項(政府発行 ID・金融情報の
    入力)のため代行不可。完了後に「Submit for review」→ Polar 手動審査。
    **副作用(owner 判断待ち)**: org website 登録により「Add a support
    email」行がドメイン照合警告(オレンジ/Review — support email が
    fores-tone.co.jp 系で website が chibatakumi.studio のため)へ変化。
  - **ライブページ表示バグ発見・修正**: trial 節見出しが `{trialDays}` の
    まま未展開表示(page.tsx が `t("trial.title")` / `t("trial.body")` を
    values なしで呼んでいた)。両呼び出しへ `{ trialDays }` を渡す修正を適用、
    可視 HTML の未展開 placeholder 総当たり scan では該当 1 箇所のみを確認。
    build 検証 → 再デプロイ → 再 scan(0 件化)は本改訂 commit 時点で進行中/
    完了を次改訂に記録。
  Copy / History Impact: 公開ページの表示バグ修正のみで新規 claim なし。
  trial 導線は実測で end-to-end 動作確認済み — この事実は MON-6 release truth
  に使用可能。Article Opportunity: No story(検証記録)。Change-History
  Opportunity: No。Git: 本改訂を `claude/davinci-plugin-pricing-plan-4cb87b`
  へ commit/push。
- 2026-07-19 (改訂 30 / {trialDays} バグの診断訂正と解消確認): 改訂 29 に
  書いた初回診断(`trial.title` / `trial.body` の values 欠落)は**誤り**だった。
  該当 2 キーは placeholder を含まず、修正 commit `715a7174` は無害だが無効果。
  build cache 無効の `--force` 再デプロイ後も現象が残ったことから再調査し、
  実際の欠落箇所は **`trialRequest.title`**(page.tsx:317 — 兄弟の
  `trialRequest.body` は当初から values 渡し済み)と特定。commit `272ed2d7` で
  修正し本番デプロイ。**ライブ検証 PASS**: ja/en とも可視 HTML の未展開
  placeholder 0 件、見出しは「ウォーターマークなしで 14 日試す」/
  「Try 14 days watermark-free」を実測。調査過程の副次確認: alias は正しく
  最新 production deployment を指しており(`data-dpl-id` で確認)、Vercel の
  deployment 直 URL は SSO 保護ページを返すため content 検証には使えない
  (誤検知の教訓として記録)。portfolio commits: `0ed86b3a`(ページ一式)、
  `715a7174`(無効果 fix)、`272ed2d7`(実 fix)— いずれも push 未実施
  (owner の先行未 push 5 commit と同時公開になるため owner 判断待ち)。
  Copy / History Impact: 表示バグ解消のみ。Git: 本改訂を
  `claude/davinci-plugin-pricing-plan-4cb87b` へ commit/push。
