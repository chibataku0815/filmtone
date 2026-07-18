# filmtone-license-worker

Filmtone Finish の 14 日 trial ライセンスを自動発行する Cloudflare Worker。
仕様正本: `docs/filmtone/davinci-plugin/monetization/implementation-plan.md` §5。

- `POST /trial` `{ "email": "...", "turnstileToken": "..." }`(両方とも文字列
  必須)-> trial 鍵で署名した `FilmtoneFinish.license`(envelope 形式)を
  Resend でメール添付送付。
- 乱用対策: **Turnstile 必須・fail-closed**(secret 未設定は 500、Siteverifyの
  `success`に加えて`action == filmtone_trial`と`hostname`が`ALLOWED_ORIGIN`の
  hostに一致することを必須化)/ streaming
  4 KB byte 上限(超過時点で打ち切り)/ `Content-Type: application/json` 必須 /
  IP ごと 5 req/時の soft throttle。
- 再試行安全性: payload は (email, 時間枠) ごとに決定的(issuedAt 時間切り
  捨て + HMAC 由来 orderRef)で、Resend `Idempotency-Key` の「同一 key = 同一
  payload」契約を満たす。Resend の `409` は JSON の `name` だけで判定し、
  `invalid_idempotent_request` は既送達として成功扱い(保存期間 24 時間)、
  `concurrent_idempotent_requests` は KV 未記録のまま `503` と
  `Retry-After: 2`、不明または JSON 不正の `409` は KV 未記録のまま `502`。
  その他の非 2xx も KV 未記録のまま `502`。エラーログは status のみ
  (message・本文・PII は非出力)。
- プライバシー: KV に保存するのは HMAC-SHA256(識別子)と発行日時のみ。メール
  平文は保存しない。保持は約 13 ヶ月(TTL)で自動削除。既発行メールへの応答も
  generic な `{"ok":true}`(trial 請求歴を列挙できない)。
- full 鍵はこの Worker に**存在しない**。漏洩時に偽造できるのは最長 31 日の
  trial だけ(プラグイン側の kind 別鍵選択 + 未来日 `issuedAt` 拒否)。
- 管理画面・DB・購読機能は持たない。Workers / KV は無料枠、メール送信は
  既存 Resend 契約を使うため、この Worker 導入による新規固定費は 0 円。

## 発売前の本番設定(2026-07-19)

- Worker: `https://filmtone-license-worker.chiba-4f9.workers.dev`
- hostname/action bindingとResend 409種別判定を含むsource commit `f8c4611`を
  remote branch `origin/claude/davinci-plugin-pricing-plan-4cb87b`へ保存し、
  2026-07-19に再deploy済み。Cloudflare Worker Version ID:
  `627b6337-15d3-441c-a695-8accb47f9f9d`。
- KV binding: `TRIAL_KV` (`7e939ca054614c57b31ed9503613c87a`)
- Resend: `fores-tone.co.jp` 検証済み。API key は Sending access かつ同 domain
  限定で、1Password と Worker secret に保存済み。
- Turnstile: `Filmtone Finish Trial` 本番 widget を作成済み。許可 domain は
  `chibatakumi.studio` / `www.chibatakumi.studio`。secret は1Passwordと
  Worker secretに保存済み。MON-6のフォームはwidgetへ
  `data-action="filmtone_trial"`を設定し、別action/別hostnameのtokenをWorkerが
  拒否する構成にする。
- Worker secret 4 件(`TRIAL_PRIVATE_KEY` / `RESEND_API_KEY` /
  `TRIAL_HASH_SECRET` / `TURNSTILE_SECRET`)は登録済み。秘密値は本書へ記載しない。
- 1Password Environment: `Filmtone Finish Production`
  (`w4plqx7tjh2zmaojldj6r3jfp4`)。上記4 secretと公開
  `TURNSTILE_SITE_KEY`を重複なしで保管。旧Environmentは削除せず
  `Filmtone Finish Production (retired 2026-07-18)`として保持する。
- 現 Resend 契約は月 50,000 通・日次上限なし。送信量アラートの設定項目は
  現行 UI / API にない。超過課金はオフを維持し、Resend Usage と Worker の
  Turnstile・IP throttle・email単位制限で管理する。
- current sourceの再deployまでは完了。公開endpointへの実trial請求、実メール
  送達、添付license検証は別の発売ゲートとして未実施。2026-07-19に本番endpointで
  token欠落=`400 invalid_request`、不正token=`403 verification_failed`を確認済み
  (メール送信なし)。

## デプロイ(オーナー操作、初回のみ)

```bash
cd infra/license-worker
bunx wrangler login
bunx wrangler kv namespace create TRIAL_KV   # 出力された id を wrangler.toml へ
# ALLOWED_ORIGIN / PRODUCT_URL は現在の公開 Filmtone page を設定済み。
# Finish 専用ページ公開時は同 origin の PRODUCT_URL だけを差し替える
bunx wrangler secret put TRIAL_PRIVATE_KEY   # ~/.filmtone/secrets/filmtone-trial.key.json の privateKeyPkcs8Hex
bunx wrangler secret put RESEND_API_KEY      # Resend(fores-tone.co.jp ドメイン検証済み)の API key
bunx wrangler secret put TRIAL_HASH_SECRET   # openssl rand -hex 32 の出力
bunx wrangler secret put TURNSTILE_SECRET    # 必須(fail-closed)。Turnstile site 作成後
bunx wrangler deploy
```

発売前チェック(発売ゲート): Resend Usage と超過課金オフを確認し、Turnstile
の**本番キー**を設定する(bot がメール枠を焼き切ると正規 trial が止まるため。
Worker は secret 未設定だと 500 を返す)。製品フォームのTurnstile widgetには
`data-action="filmtone_trial"`を設定する。正しい本番tokenの成功だけでなく、
action不一致・hostname不一致が`403 verification_failed`になることを発売前に
確認する。

## 動作確認

デプロイ直後の確認には Cloudflare 公式の **Turnstile テストキー**(常時 pass、
secret `1x0000000000000000000000000000000AA`)を使うと、フォームなしで curl
確認できる。本番キーに切り替えた後は正しい token が必要になる。

```bash
curl -sX POST https://<worker>/trial -H 'Content-Type: application/json' \
  -d '{"email":"you@example.com","turnstileToken":"test"}'
# 成功: {"ok":true} + メール着信(既発行メールでも同じ {"ok":true} が返る仕様)
# 添付の検証:
#   bun run license:verify -- --file FilmtoneFinish.license \
#     --trial-key ~/.filmtone/secrets/filmtone-trial.key.json
```
