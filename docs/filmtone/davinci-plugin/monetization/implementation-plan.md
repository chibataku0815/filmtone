# Filmtone 課金 対応計画書 (Implementation Plan)

Date: 2026-07-18 JST
戦略正本: [strategy.md](strategy.md) / 進行管理: [progress.md](progress.md)
実装レーン正本: `docs/filmtone/davinci-plugin/strategy.md`

この文書は課金対応(MON-2〜MON-6)の**実行レベルの仕様**である。戦略の再説明は
しない。各ワークストリームは本書の該当節をそのまま assignment として使える
粒度で書く。実装レーンの delegation.md の禁止事項(共有ファイル編集制限・
coordinator 所有物・Git 操作はオーナー)は課金作業にも適用する。

明示例外: root `package.json` への `license:keygen/issue/verify` 3 スクリプト
追加は monetization coordinator の変更として行った(OFX feature worker の
`package.json` 編集禁止はそのまま有効。この例外は本 3 行に限る)。

## 0. 承認状態と前提

- 価格(通常 $49 / ローンチ 30 日 $39 / 買い切り)と 14 日無料体験の追加は
  2026-07-18 のチャットでオーナー了承済み。席数(1 ユーザー 2 台)・商用可・
  v1.x 無償更新は異議がなかったため確定扱い(変更したくなったら strategy.md
  改訂で戻す)。
- 最新mainのQUALITYはpartial acceptanceでclosedした。Film Damageはpass、
  Film Breath / Gate Weaveはbelow passで、combined/public product acceptanceは
  未成立。残る視覚判断はwatermarkだけではない。
- MON-2(プラグイン本体)は、Film Breath / Gate Weaveの独立品質iterationが
  owner passを得てcombined/public acceptanceが明示された後にdispatchする。
  それまでは`Blocked`。MON-3 / MON-4は品質回復と並行できる。
- 2026-07-19に`origin/main`を再取得し、現作業ブランチが最新
  `origin/main`をすでに含むことを確認済み。追加mergeは不要。名称同期の
  作業ツリー差分は、追加deployまたはMON-2 dispatch前にscopeを確認し、
  commit/push後の取得可能なsourceを正とする。

## 1. 全体像

```text
[今すぐ並行可]
  MON-3 鍵・発行ツール(scripts/license/)
  MON-4 販売基盤(Polar 登録 + trial Worker + 規約)
[Film Breath / Gate Weave品質回復 + combined/public acceptance後]
  MON-2 LICENSE(watermark + 検証 + expires + 表示)
  MON-5 配布物(.pkg 署名 + notarization)
[最後]
  MON-6 ローンチ(製品ページ + 記事 + 価格公開)
```

粗い規模感(コミットではない): 品質回復は各独立iterationで再見積り / MON-3
残件はMON-2内 / MON-4残件 0.5-1日 / MON-2 1-2日 / MON-5 0.5-1日 /
MON-6 1日。

### Source durability gate

追加deploy、MON-2 dispatch、署名済み配布物作成のいずれより前にも次を満たす:

- 選択したbase commitが`origin/main`から取得できる。
- `package.json`、`scripts/license/`、`infra/license-worker/`、monetization正本が
  同じreview済みcommit系列にある。
- Worker deploy sourceとrepository sourceのcommitをprogressへ記録する。
- このgateのstage / commit / pushはオーナー明示指示後だけ行う。

### Product-quality recovery gate

MON-2の前に、現行QUALITY taskを再開せず次の独立workstreamを順に閉じる:

1. Film Breath: オーナーが最も目立つ実写上の失敗を具体化してからimmutable planを
   作り、原因を仮定せず修正し、owner passを得る。
2. Gate Weave: 同様に実写上の失敗を具体化し、独立plan・修正・owner passを閉じる。
3. 同じ統合baseでdefault identity、各module、combined、固定pass order、
   random access / fps / cache rebuild / project reopen / export、format / alpha / bounds、
   CinePrint35 coexistenceを実装戦略のMeasurable Done Conditionsに従い確認する。
4. coordinatorがcombined/public product acceptanceを明示する。

テスト、ハーネス、Resolve操作は、その品質iterationでオーナーが明示的にtesting
authorizationを与えた場合だけ行う。具体的なowner-observed failureがない状態で
Breath / Weaveを推測調整しない。

## 2. 鍵設計(全ワークストリーム共通の土台)

**2 鍵構成**にする。目的: 自動発行(Worker)に秘密鍵を置いても、漏洩時の
被害を「14 日 trial の偽造」に限定し、購入ライセンスの偽造を構造的に不可能に
保つ。

| 鍵 | 置き場所 | 署名できるもの |
|---|---|---|
| full 鍵 | オーナーのローカル + 1Password のみ。repo・クラウドに置かない | `kind: "full"`(永続ライセンス) |
| trial 鍵 | Cloudflare Worker の secret | `kind: "trial"`(expires 必須) |

プラグインは kind ごとの公開鍵(**リスト**、ローテーション併載用)を埋め込み、
次を強制する(検証鍵は署名済み `kind` が内部選択し、呼び出し側は選べない):

- `kind == "full"` は full 公開鍵で検証できた時のみ有効。
- `kind == "trial"` は trial 公開鍵で検証でき、`expiresAt` が存在し
  `expiresAt <= issuedAt + 31 日`、**かつ `issuedAt <= 現在時刻 + 3 日
  (ISSUED_AT_CLOCK_SKEW)`** の時のみ有効。正確な効果: **正しい時計の下で、
  1 通の trial license が有効であり得る期間を最長 34 日に制限する**。漏洩した
  trial 鍵は(旧公開鍵を受理し続ける限り)新しい trial を発行し続けられる —
  鍵自体の失効はローテーション + 旧公開鍵の削除で行う(scripts/license/README)。

### ライセンスファイル wire format (`filmtone-license/1`、envelope 形式)

配置: `~/Library/Application Support/Filmtone/Filmtone.license`

```json
{
  "schema": "filmtone-license/1",
  "payload": "base64(payloadBytes)",
  "sig": "base64(ed25519(payloadBytes))"
}
```

- **署名対象は `payload` のバイト列そのもの**。検証側(TS/C とも)は署名検証の
  前に再 canonicalize しない。これにより言語間の canonical 化差異が署名検証に
  影響する余地を構造的に消す(Codex レビュー Blocker 2 対応)。
- `payloadBytes` は次の 9 フィールドのみを、キー昇順・空白なしの canonical
  JSON で並べたもの。**C パーサはこの順序が固定で現れることに依存してよい**:
  `edition, email, expiresAt, issuedAt, kind, name, orderRef, product, schema`
- 検証手順(TS 実装 `scripts/license/core.ts` が参照実装、C は同一挙動):
  1. envelope の余剰フィールド拒否、`sig` は 64 byte、payload ≤ 4096 byte
     (ファイル全体 ≤ 16 KB)。
  2. payload を decode -> JSON parse -> **キー集合が上記 9 個と完全一致**
     -> **canonicalize(parse 結果) == payload バイト列**(重複キー・順序替え・
     空白挿入・未知フィールドを全て拒否)。
  3. 厳密検証: `schema`/`product` 固定値、`edition == "v1"` 固定、日時は
     `YYYY-MM-DDThh:mm:ssZ` の厳密 UTC のみ(緩い `Date.parse` 形式は拒否)、
     `name ≤ 120` / `email ≤ 254` / `orderRef ≤ 120` 文字。
  4. kind 別の鍵選択 -> 署名検証 -> trial は未来日拒否と期限判定。
- full は `expiresAt: null` を**明示フィールドとして必須**(省略ではない)。
- v2 発売時は `edition` で区別する(v1 ライセンスは v1.x 系を永続に開ける)。
- クロス検証: TS で発行した実 envelope 1 式を fixture として C 実装(MON-2)で
  検証し、加えて §3 の adversarial vectors を C 側でも通す。

## 3. MON-2 LICENSE(プラグイン本体)

Dispatch 条件: Film Breath / Gate Weaveの独立品質iterationがowner pass、
combined/public product acceptance明示、本書レビュー、Source durability gate完了。
Worker base: その時点で`origin/main`から取得できる最新review済み統合ref。
ローカルのみの`main`や古いplan branchから切らない。

### 編集領域(排他)

- 新規: `apps/filmtone-resolve-ofx/Sources/License/`
  - `LicenseStore.h/.mm` — envelope 読込・厳密 decode(§2)・ed25519 検証・状態キャッシュ
  - `WatermarkPass.h/.mm` — watermark の Metal パス(埋め込み MSL)
  - `vendor/ed25519/` — orlp/ed25519 を vendored。**注意(Codex レビュー Major 7):
    zlib license・複数ファイル構成**(public domain・単一ファイルではない)。
    `src/` の verify 経路一式(`fe/ge/sc/sha512/verify` と headers)+ LICENSE
    ファイルを同梱し、pin した commit hash を進行記録に残す。seed/keypair/sign
    系は不要なら除外してよいが、除外した場合はビルド完結性を確認する
  - `PublicKeys.h` — full / trial 公開鍵**リスト**(MON-3 の keygen 出力を転記。
    ローテーション時は追記式)
- 統合点(最小 diff、他モジュールの処理は変更しない):
  - render graph 最終段: 状態が licensed 以外なら watermark パスを追加
    (順序: Breath -> Weave -> Damage -> Watermark)
  - パラメータ面: `License` グループに読み取り専用 status 文字列 1 個
    (`Licensed to <name>` / `Trial — expires YYYY-MM-DD` / `Trial mode
    (watermarked)`)

### 挙動仕様

- 状態管理: 検証済みライセンス状態は **immutable snapshot** とし、atomic に
  差し替える(複数 render thread から安全に読める)。
- キャッシュと再読込: render 要求時に `stat()`(mtime + size)を確認し、変化
  時のみ全再読込 + 署名再検証。`stat` 確認は最大 1 回/5 秒に間引く(playback
  中の per-frame I/O を避ける)。ファイル削除は即 unlicensed(watermark)。
  同 mtime・同 size の内容差し替えは検知しない(病的ケースとして許容し、ここに
  記録する)。
- 期限評価: **render 要求ごと**に snapshot の expiresAt と実時刻を比較する。
  長時間 export が期限を跨いだ場合、跨いだフレーム以降に watermark が入る
  (trial の仕様として文書化。status 表示とメールに正確な期限時刻を出すことで
  予見可能にする)。
- 時計操作: **オフライン検証の既知の限界として許容する**。`issuedAt - 3 日`
  より前へ戻すと trial は無効になるが、時計を有効期間内に固定し続ければ実時間
  上の利用は延長できる。watermark 床がある indie 規模の trial 抑止としては
  受容し、オンライン時刻取得などの対策は導入しない(ネットワーク 0 行が優先)。
- UI status: OFX の read-only 文字列は render thread から更新しない。インス
  タンス生成時と instanceChanged 時に更新し、Resolve の表示反映がパネル再表示
  依存になる制約を受入条件で確認する。
- **ネットワークコード 0 行**(接続・DNS・telemetry 一切なし)。
- identity 不変条件: 有効ライセンス + 全モジュール off = bit-exact identity を
  維持(実装レーンの Done 条件を破らない)。
- watermark 仕様:
  - deterministic(時間アニメーションなし・乱数はシード固定)。トライアル
    レンダーも再現可能であること。
  - 座標系: **output bounds 基準のグローバル座標**で描く。render window /
    tile 単位で繰り返さない(タイルごとに文字が複製される実装を禁止)。
    renderScale / proxy に追従してパターンを拡縮し、proxy と full-res で見た目
    が一致すること。縦横比・portrait でも破綻しないこと。
  - 画素規律: **alpha は不変**(RGB のみに合成)。watermark 領域外の画素は
    bit-exact 不変。負値・1 超の extended-range RGB を clamp しない(watermark
    合成は float のまま行い、NaN を生まない)。
  - 内容: 四隅の 1 箇所に小さな `FILMTONE — TRIAL` バッジ + 低透過の
    対角テキストタイル(除去を面倒に、評価を邪魔しない濃度)。
  - テキストはフォント描画に依存せず、事前ラスタライズしたビットマップを
    ヘッダ埋め込み(OFX レンダーコンテキストにフォント環境を仮定しない)。
  - 最終的な文言・位置・濃度はオーナー視覚判断で確定(2-3 候補を並べる)。

### 受入条件

- 未ライセンス: 全モジュール off でも watermark のみ合成される(trial 表示)。
- 有効 full ライセンス配置 -> 再レンダーで watermark 消滅、status 表示更新。
- 有効 trial: clean。`expiresAt` 超過(検証はシステム時計を進めて実施)で
  watermark 復帰。
- 改竄ファイル(1 バイト変更・鍵不一致・trial なのに expires 無し)は全て
  無効 = watermark。
- **adversarial vectors(C 側でも全拒否を確認する)**: trial 鍵で署名した
  `kind:"full"` / 未来日 `issuedAt`(+3 日超) / 非 canonical payload(空白・
  キー順) / 未知・欠落・重複フィールド / 型違い / date-only・offset 付き日時 /
  31 日境界超過 / 不正 base64 / 64 byte でない sig / サイズ超過。TS 参照実装
  (`scripts/license/core.ts`)で 2026-07-18 に全ケース PASS 済み — C 実装は
  TS 発行の fixture 1 式 + 本リストで同一判定になること。
- 既存 QUALITY ハーネスの direct-Metal ケースに、状態別(unlicensed / full /
  trial / expired)のハッシュ比較を追加できる形で実装する。**ハーネス実行・
  test file 作成・上記 vectors の実行検証は、オーナーの明示的な testing
  authorization を dispatch 文面に記録した上で行う**(グローバルルール準拠)。

## 4. MON-3 鍵・発行ツール(今日から着手可)

配置: `scripts/license/`(bun / TypeScript、既存 repo 慣習に従う)。
**依存パッケージゼロ** — Bun / Cloudflare Workers ともに内蔵 WebCrypto の
Ed25519 を実測確認して使用(署名ツールに外部 npm 依存を持ち込まない)。
実装・検証済み(2026-07-18、progress.md 参照)。

| コマンド | 仕様 |
|---|---|
| `bun run license:keygen [-- --out-dir <dir>]` | full / trial の 2 鍵ペアを生成。秘密鍵は repo 外(既定: `~/.filmtone/secrets/`、0700 / 0600、`wx` で上書き拒否。**iCloud 同期対象の `~/Documents` は使わない**)。公開鍵 hex と `PublicKeys.h.snippet` を出力 |
| `bun run license:issue -- --key <key.json> --kind full\|trial --name --email --order [--days 14] [--out <path>]` | §2 envelope を発行(0600、上書き拒否)。key の `role` と `--kind` の不一致は拒否。発行直後に自己検証 |
| `bun run license:verify -- --file <path> [--full-key\|--trial-key <key.json>] [--full-pub\|--trial-pub <hex>]` | §2 の厳密検証。**署名済み kind が検証鍵を内部選択**する(単一鍵で任意 kind を「有効」と報告しない)。exit 0 = 有効 / 2 = 期限切れ / 1 = 無効 |

- クロス検証: `issue.ts` の出力 envelope を fixture として C 実装(MON-2 の
  `LicenseStore`)で検証し、§3 の adversarial vectors も C 側で同一判定になる
  ことを確認する(実行はオーナーの testing authorization 記録後)。
- 鍵運用・ローテーション・full 鍵漏洩時のインシデント手順は
  `scripts/license/README.md` が正本(trial は新旧公開鍵を 31 日以上併載、
  full 漏洩時は旧鍵削除 + 全購入者再発行)。

## 5. MON-4 販売基盤(今日から着手可)

### オーナー操作(手順書を作って渡す)

1. [完了 2026-07-18] `~/.filmtone/secrets/` の
   `filmtone-{full,trial}.key.json` を 1Password Private vaultへdocumentとして
   保存済み(秘密鍵内容は非表示でitem metadataのみ確認。`~/Documents` には置かない)。
2. [完了 2026-07-18] Polar org は 2026-06-19 作成。適用手数料は
   5% + $0.50。
3. [製品・クーポン完了 2026-07-18 / benefit は MON-5 後]
   Polar に製品登録: `Filmtone for DaVinci Resolve` $49、ローンチ用
   **固定額 $10 オフ クーポン(= $39 ちょうど。20% だと $39.20 になり LP 表記と
   ずれるため率ではなく固定額)**、購入者向けファイル配信 benefit に .pkg
   (MON-5 成果物)。
4. [完了 2026-07-18] Resend で送信 domain `fores-tone.co.jp` を検証し、
   Sending access + domain限定 API keyを発行。現契約は月50,000通・日次上限
   なしで、現行 UI / API に送信量アラート設定はないため、超過課金オフと
   Usage監視を安全弁にする。
5. [完了 2026-07-19] CloudflareでWorker +
   KVを作成し、`wrangler secret`を4つ登録
   (TRIAL_PRIVATE_KEY / RESEND_API_KEY / TRIAL_HASH_SECRET / TURNSTILE_SECRET)。
   **Turnstile は発売ゲート(必須)**: Worker は secret 未設定だと 500 を返す
   fail-closed 実装(bot がメール枠を焼くと正規 trial が止まるため)。本番
   Turnstile widgetも作成し、`chibatakumi.studio` と
   `www.chibatakumi.studio` に限定済み。Worker URLは
   `https://filmtone-license-worker.chiba-4f9.workers.dev`。
   hostname/action bindingとResend 409種別判定を含むsource commit `f8c4611`を
   remoteへ保存して再deploy済み。Version IDとdeploy記録はprogressを正とする。
6. [方針決定 2026-07-18] Polar $0 checkoutはWorkerへの自動bridgeを持たないため、
   trial受付は製品ページのTurnstile付きフォームからWorkerを直接呼ぶ。
7. [文面作成済み / 公開配置はMON-6] 購入確認ページ / 受領メールに 2 行を載せる:
   「full ライセンスは 24 時間以内
   (通常は数時間)にメールでお届け」+「待ち時間なしで使い始めるには 14 日
   trial ライセンスを即時取得できます」。**購入者が発行待ちでブロックされない
   ようにする**(trial は即時自動・full 手動発行の SLA を明示する)。
   **例外(trial 使用済み購入者)**: 過去に trial を取得済みの購入者はブリッジ
   不可のため、購入メールに「お急ぎの場合はこのメールに返信で優先発行」を
   明記する(L2 自動化までの運用)。

### trial Worker(実装済み 2026-07-18、repo 内 `infra/license-worker/`)

- `POST /trial` `{ email, turnstileToken }`(両方とも文字列必須・型強制なし)の
  処理順:
  1. **Turnstile fail-closed**: `TURNSTILE_SECRET` 未設定は 500
     `server_misconfigured`(発売環境で bot 検証が黙って外れる事故を構成不能に)
  2. `Content-Type: application/json` 必須 + **streaming byte 上限 4096**
     (`Content-Length` は早期拒否の補助、実体は stream を 4096 byte 超過時点で
     打ち切り — 全量読込後の文字数判定はしない)
  3. メール形式検証 -> Turnstile検証(403)。Siteverifyの`success`だけでなく、
     `action == "filmtone_trial"`、`hostname`が`ALLOWED_ORIGIN`から導出したhost
     allowlistに含まれることを必須にする。MON-6のwidgetは
     `data-action="filmtone_trial"`を設定する
  4. IP ごと 5 req/時の soft throttle(429。KV 非 atomic の best-effort)
  5. KV `trial:<HMAC-SHA256(email)>` 既存なら **generic `{"ok":true}`**
     (trial 請求歴を列挙させない。409 は返さない)
  6. **決定的 payload** を trial 鍵で署名: `issuedAt` は時間単位に切り捨て、
     `orderRef` はメール HMAC 由来 -> 同一 (email, 時間枠) の再試行は byte
     一致の envelope を再生成する(Ed25519 は決定的署名)。`TRIAL_DAYS` は
     1..30 の整数のみ受理、それ以外は 14 に矯正し、件名・本文の日数表記にも
     同じ値を使う
  7. Resend 送信(`Idempotency-Key: trial-<HMAC(email)>` + `User-Agent` 明示)。
     **Resend の冪等性契約(同一 key は同一 payload、保存 24 時間)を 6 の
     決定的 payload が満たす**。`409` は Resend JSON の `name` だけで判定する。
     `invalid_idempotent_request` は「この key で既に受理済み」を意味するため
     **既送達として成功扱い**(時間枠跨ぎの再試行で発生し得る)。
     `concurrent_idempotent_requests` は KV 未記録のまま `503` +
     `Retry-After: 2`、不明または JSON 不正の `409` は KV 未記録のまま `502`、
     その他の非 2xx も KV 未記録のまま `502`(ユーザー再試行可能)。エラーログは
     status のみ(Resend の `message` や本文は宛先アドレスを含み得るため出力しない)
  8. 成功後に KV 記録(HMAC キー + 発行/期限日時のみ、**TTL 約 13 ヶ月**。
     メール平文・IP 平文は保存しない)
- 併走リクエストの二重発行は KV 非 atomic のため理論上残る(Idempotency-Key
  で同一メールの二重送信は抑止)。soft 制限の設計判断としてここに記録する。
  Durable Objects による厳密化は採らない(外殻・複雑性)。
- 管理画面・DB・ダッシュボードは作らない(外殻)。
- 購入側 webhook(Polar -> full 発行の自動化)は **Phase L2**。発売時は
  full 発行を `issue.ts` 手動運用で始め(SLA はオーナー操作 7 で顧客に明示)、
  自動化は「オーナー Mac 上の launchd + Polar API ポーリング」を第一案とする。
  **full 鍵をクラウドに置く案は採らない。**

### 規約類(各 1 ページ、日英)

- EULA: 1 ユーザー 2 台 / 商用可 / 再配布・再販禁止 / 無保証・責任制限。
- 返金: 14 日(watermark trial + 14 日 clean trial があるため「試せなかった」
  返金理由は構造的に発生しにくい)。
- **trial プライバシー表記**(請求フォームに併記): 取得するのはメールアドレス
  のみ / 目的はライセンス送付 / 処理は Cloudflare(署名)と Resend(送信)/
  保存はハッシュ化識別子と発行日時を約 13 ヶ月 / 削除依頼はサポート窓口へ。
- サポート窓口: メール 1 本(応答目安 2 営業日)。
- 販売者表記は MoR の Polar 側。portfolio には問い合わせ先のみ。
- 法的適合(消費者法・特商法関連の文言)は発売前にオーナーが最終確認する。

### 受入条件

- テスト purchase(Polar sandbox か $1 テスト価格)-> 受領メール ->
  `issue.ts` で full 発行 -> 検証 pass。
- trial 請求 -> 1 分以内にメール到着 -> ファイル配置手順で有効化 -> 同一
  メール再請求は generic `{"ok":true}` でメールが再送されないこと -> IP 連投で
  429 になること。
- Turnstile本番tokenは正しいhostname/actionだけ成功し、欠落・不正tokenに加えて
  action不一致・hostname不一致を403で拒否すること。

## 6. MON-5 配布物(MON-2 統合後)

Release identityの正本は
`apps/filmtone-resolve-ofx/Resources/ProductVersion.mk`とする。初期値は内部評価用
`0.1.0` / build `1` / macOS deployment target `14.0`。公開版作成前にオーナーが
marketing/build versionを確定し、Makefileが生成するbundle Info.plist、pkg version、
ファイル名、公開コピーへ同じ値を使う。公開対象はResolve 21.x / macOS 14.0+
/ Apple Silicon / Metal候補とし、下限OSと対応Resolveで実機確認するまで公開
クレームにしない。

```bash
cd apps/filmtone-resolve-ofx
make sign-bundle \
  SIGN_IDENTITY="Developer ID Application: <existing>"
codesign --verify --deep --strict --verbose=2 \
  build/Filmtone.ofx.bundle
pkgbuild --component build/Filmtone.ofx.bundle \
  --install-location "/Library/OFX/Plugins" \
  --identifier com.chibatakumi.filmtone.resolve.pkg \
  --version <ProductVersion.mk marketing version> raw.pkg
productbuild --package raw.pkg --sign "Developer ID Installer: <existing>" \
  Filmtone-<version>.pkg
pkgutil --check-signature Filmtone-<version>.pkg
xcrun notarytool submit Filmtone-<version>.pkg \
  --keychain-profile <existing> --wait
xcrun stapler staple Filmtone-<version>.pkg
xcrun stapler validate Filmtone-<version>.pkg
```

- **署名順序は固定**: OFX bundleをDeveloper ID Application + hardened runtime +
  secure timestampで先に署名し、その署名済みbundleを格納したpkgをDeveloper ID
  Installerで署名する。外側pkgだけを署名した配布物は禁止。
- README(同梱 + 製品ページ): インストール -> Resolve 再起動 -> Effects に
  `Filmtone` -> ライセンス配置(Finder へ 1 ドラッグ)-> watermark 消滅
  確認、の 5 手順。アンインストール(`/Library/OFX/Plugins` から bundle を
  削除)も明記。
- 受入: 内包OFXとpkgの署名、notary ticket、stapleを確認し、macOS 14.0+の
  クリーン環境相当(評価用ユーザーアカウント可)でpkgインストール -> Resolve
  21.x認識 -> trial表示 -> ライセンス有効化の一巡。少なくとも発売時の最新
  Resolve 21 patchと品質受入に使った21.0.2.4の差を確認し、実測範囲だけを
  公開対応範囲にする。
- 成果物は Polar のファイル配信 benefit へ(自前配信インフラなし)。

## 7. MON-6 ローンチ(全 Done 後)

1. release truth確認(Product-quality recovery、Source durability、MON-2〜5、
   実装レーンのMeasurable Done Conditions、署名/notarization、対応OS/Resolve
   実測範囲を含む。公開クレームはここを通過してからのみ)。
2. portfolio `apps/web` に製品ページ: 価格・2 段 trial の説明・購入 CTA
   (Polar checkout)・trial請求導線・インストールガイド・EULA/返金リンク。
   trial widgetには`data-action="filmtone_trial"`を設定する。
   ※ portfolio 側の実装は repo 境界に従い bump 手順で(このリポでは書かない)。
3. release article JP/EN(`filmtone-release-articles` skill)。テーゼは
   strategy.md §3.1 の精密化に従う: 「この 3 点だけを買い切りで買う選択肢を
   作った」(市場全体をサブスク専売と呼ばない・品質 parity を示唆しない)。
4. ローンチ価格の終了日(発売 +30 日)をカレンダー登録し、$49 へ戻す。

## 8. 全体 Done / Stop 条件

Done:

- 購入 -> 支払い -> ライセンス受領 -> 有効化 -> クリーン出力、が実ユーザー
  導線で一巡する。
- trial 請求 -> 14 日 clean -> watermark 復帰、が一巡する。
- 新規固定費 0 円のまま(strategy.md §4 の表に反する契約が 1 つもない)。
- 公開ページの価格・体験・対応環境の記述が実装と一致する。
- repositoryからrelease sourceとWorker deploy sourceを再取得でき、公開した
  version / macOS / Resolve範囲が`ProductVersion.mk`と実測evidenceに一致する。

Stop(発生時は progress.md に記録して停止):

- 月額課金インフラが必要になる設計変更(戦略改訂へ差し戻し)。
- プラグインへのネットワークコード追加が必要になる要求。
- 同一検証コマンド 3 連続失敗、または実装レーンとの所有権衝突。

## 9. 変更履歴

- 2026-07-18: 初版。価格・trial 承認(§0)を受けて MON-2〜MON-6 を実行仕様化。
  2 鍵構成(full ローカル / trial Worker)と kind 別検証規則を確定。
- 2026-07-18 (改訂 1、Codex レビュー反映): wire format を envelope(署名対象 =
  payload バイト列そのもの)へ再設計し、厳密 decode 規則・キー順序定数・厳密
  UTC 日時・サイズ/文字数上限を確定(Blocker 2)。trial の未来日 `issuedAt`
  拒否 + 3 日 skew で 1 通の有効期間を最長 34 日に制限(Blocker 1)。検証鍵の
  kind 内部選択(Blocker 3)。Worker に body 上限・Turnstile・IP throttle・
  generic 応答・HMAC 識別子・TTL 保持・Idempotency-Key を追加(Blocker 4 /
  Major 5, 11)。鍵既定を `~/.filmtone/secrets/` へ変更し 0700/`wx` 化、
  ローテーション/インシデント手順を README に確定(Major 8)。orlp/ed25519 の
  zlib license・複数ファイル構成を明記(Major 7)。MON-2 の時間 snapshot・
  時計巻き戻し・stat cache・thread safety・watermark 画素規律・adversarial
  vectors を仕様化(Major 6)。$10 固定額クーポン(Minor 14)。full 手動発行の
  SLA 明示 + 購入者は trial 即時取得で待ちゼロ(Major 10)。
- 2026-07-18 (改訂 2、Codex 再精査反映): Worker の body 上限を **streaming
  byte 打ち切り**に実効化し `email`/`turnstileToken` を文字列型必須に(B4)。
  **Turnstile を発売ゲート・fail-closed** に変更(secret 未設定 = 500)。Resend
  冪等性を成立させるため **決定的 payload**(issuedAt 時間切り捨て + HMAC 由来
  orderRef)へ変更し、409 は既送達として成功扱い、`User-Agent` 明示、エラー
  ログは status のみ(PII 排除)。時計操作の記述を「既知の限界として許容」へ
  是正(「巻き戻しで伸びない」主張を削除)。B1 の効果記述を「1 通の有効期間
  ≤34 日」へ精密化(漏洩鍵の失効はローテーションで行うことを明記)。trial
  使用済み購入者向けの優先発行例外を §5 に追加。Worker はスタブ KV/fetch の
  操作確認 11 ケース(byte 上限 / 型 / fail-closed / throttle / generic 重複 /
  決定的再試行 payload 一致 / 409 成功扱い / 失敗時 KV 未記録)全 PASS。
- 2026-07-18 (改訂 3 / Phase A1): Resend `409` の一律成功扱いを廃止。
  JSON `name` が `invalid_idempotent_request` の場合だけ既受理として KV を記録し、
  `concurrent_idempotent_requests` は KV 未記録の `503` + `Retry-After: 2`、
  unknown / JSON 不正は KV 未記録の `502` とした。testing authorization が
  ないため、テスト・test-like verification は実行していない。
- 2026-07-18 (改訂 4 / Phase A2): full / trial key JSONを1Password Private
  vaultへdocumentとして保存。item metadataのみで存在を確認し、秘密鍵内容は
  開かず、表示していない。MON-3はCクロス検証待ちのためReviewを維持。
- 2026-07-18 (改訂 5 / latest main adversarial remediation): QUALITYの状態を
  pendingからpartial acceptance closedへ訂正し、Breath / Weave独立品質回復と
  combined/public acceptanceをMON-2前提に追加。local-only / untracked sourceの
  durability gate、Turnstile hostname/action binding、ProductVersion.mkによる
  macOS/version正本、内包OFXのDeveloper ID Application先行署名を発売条件化。
