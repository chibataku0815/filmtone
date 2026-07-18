# Filmtone Finish 課金 進行書 (Monetization Progress)

Date: 2026-07-18 JST
Coordinator-owned: yes
計画正本: [strategy.md](strategy.md)(戦略)+
[implementation-plan.md](implementation-plan.md)(対応計画 = 実行仕様)/
実装レーン正本: `docs/filmtone/davinci-plugin/strategy.md`

状態モデルは実装レーンと同じ:
`Queued -> Ready -> Dispatched -> Running -> Review -> Accepted`、
側状態 `Paused / Blocked`。

## 現在地 (2026-07-18)

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
  hostname/action bindingを含むcurrent sourceの再deployはsource耐久化後。
- 残るMON-4発売ゲート: testing authorization後の実trial請求・メール送達・
  添付license検証・失敗系確認、MON-6でのtrialフォームと購入メール文面配置、
  法務文面のオーナー最終確認。
- latest mainのQUALITYはResolve 21.0.2.4ホスト実描画までpassしたが、owner verdictは
  Damage pass / Breath・Weave below passでpartial acceptanceのままclosed。
  combined/public acceptanceは未成立。
- **MON-2 Blocked**: Breath / Weave独立品質iterationのowner pass、quality matrix、
  combined/public acceptance、source durability gate完了後にのみdispatch。MON-5は
  MON-2後。
- **Source durability Blocked**: ローカル`main` `cb9b465`は`origin/main`より18
  commits先行し、monetization docs / `infra/` / `scripts/license/` / `package.json`
  は未commit。追加deploy/MON-2/署名より前にオーナーGit操作でremoteから再取得
  可能にする。現タスクではstage / commit / pushしない。

## ワークストリーム一覧

実行仕様はすべて [implementation-plan.md](implementation-plan.md) の該当節を正とする。

| ID | 内容 | 仕様 | 依存 | プラグイン本体に触るか | State |
|---|---|---|---|---|---|
| MON-1 | 価格・ライセンス条件の確定 | strategy §3 | なし | 否 | **Accepted(2026-07-18 チャット承認)** |
| MON-2 | LICENSE 実装(watermark + ed25519 + expires + 状態表示) | 対応計画 §3 | 品質回復 + combined/public受入 + source耐久化 | **是** | **Blocked** |
| MON-3 | 鍵・発行ツール(keygen / issue / verify) | 対応計画 §4 | なし | 否 | **Review — 実装・鍵生成・1Password保管済み。MON-2のCクロス検証待ち** |
| MON-4 | 販売基盤(Polar 登録・trial Worker・規約) | 対応計画 §5 | 登録/deployはオーナー操作、追加deploy前にsource耐久化 | 否 | **Running — hostname/action bindingはcode反映済み。deploy更新・実送達・公開導線・法務最終確認待ち** |
| MON-5 | 配布物(署名 + notarized .pkg) | 対応計画 §6 | MON-2 | 否 | Queued |
| MON-6 | ローンチ(製品ページ・記事・価格公開) | 対応計画 §7 | MON-2〜5 + release truth | 否 | Queued |
| MON-7 | 外殻(実売後のみ): 購入側自動発行(Phase L2)、marketplace 展開、edu/bundle 価格、Windows 版検討 | 対応計画 §5 L2 注記 | MON-6 後の実売データ | 一部 | Queued(着手条件未成立) |

## 実行順序

```text
MON-3 Review ───────────────────────────────────────────────┐
MON-4 Running ──────────────────────────────────────────────┼─ MON-6 launch
Breath / Weave品質回復 + combined/public受入 ─┐             │
source耐久化 ──────────────────────────────────┴─ MON-2 ─ MON-5 pkg ─┘

MON-7は発売後の実売で判断
```

MON-3 / MON-4の未deploy作業は品質回復と並行可能(プラグインに触らない)。
クリティカルパスは品質回復 + source耐久化 -> MON-2 -> MON-5 -> MON-6。

## 各ワークストリームの Done 条件

### MON-1 価格・ライセンス条件の確定 — Accepted

- [x] 買い切り / 通常 $49 / ローンチ $39(30 日)の承認(2026-07-18 チャット
  「金額は良いと思ってます」)
- [x] 14 日無料体験の追加(2026-07-18 オーナー要望により採用)
- [x] 1 ユーザー 2 台・商用可・v1.x 無償更新(異議なしのため確定扱い。変更は
  strategy.md 改訂で)

名称変更は不要(strategy.md §9)。`Filmtone Finish` をそのまま公開名として扱う。

### MON-2 LICENSE 実装(プラグイン本体)

- [ ] Film Breath / Gate Weaveの独立品質iterationで具体的owner failureを修正し、
  両方owner pass
- [ ] quality matrixとcombined/public product acceptance
- [ ] source durability gate(remoteからbaseとmonetization sourceを再取得可能)
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
- [ ] source durability完了後、hostname/action bindingを含む現在codeを再deployし、
  deploy commitを記録
- [ ] **発売ゲート(未通過)**: Resend 実送達確認(実メール到達・添付検証)/
  正しいTurnstile hostname/action成功と欠落・不正・mismatch拒否 / trial使用済み
  購入者の優先発行例外を購入メールに明記
- [x] 請求フォームの受け口を製品ページのTurnstile付きフォーム -> Worker直叩き
  に決定(Polar $0 checkoutはWorkerへの自動bridgeを持たないため)
- [ ] テスト購入 -> 受領メール -> ライセンス発行(手動 L1)の一巡確認
- [ ] trial 請求 -> 受信 -> 14 日後に watermark へ戻ることの一巡確認(時計を
  進めた検証で可)

### MON-5 配布物

- [x] `Resources/ProductVersion.mk`を内部評価version 0.1.0 / build 1 / macOS
  deployment target 14.0の単一正本として追加(公開versionは未確定)
- [ ] OFX bundleをDeveloper ID Application + hardened runtime + timestampで先行署名
- [ ] 署名済みbundleを格納する.pkgをDeveloper ID Installerで署名 + notarization
- [ ] macOS 14.0+ / Resolve 21.x候補の実機互換性を確認し、実測範囲だけを公開
- [ ] クリーン Mac 相当でのインストール -> Resolve 認識 -> watermark 表示 ->
  ライセンス配置 -> watermark 消滅の一巡確認
- [ ] アンインストール手順の記載

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
  retired名へ変更し、新しい`Filmtone Finish Production`をMCPだけで再作成。
  必要5変数を重複なしで保存し、変数名一覧だけを確認した。

## 進行ログ

- 2026-07-18: 開発状態の確認(OFX レーン全 8 ワークストリームの状態把握)、
  競合実測、計画書・進行書の初版起案。MON-1 をオーナー承認待ちに設定。
- 2026-07-18 (改訂 1): オーナー指摘を反映。販路を LS 新規開設案から**既存
  Polar** に変更(新規サービスを増やさない)。名称確定を承認事項から削除
  (名称変更は不要、`Filmtone Finish` のまま)。
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
