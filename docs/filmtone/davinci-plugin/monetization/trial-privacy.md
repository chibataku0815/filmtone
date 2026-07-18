# Filmtone Finish Trial Privacy Notice / Trialプライバシー通知

Status: Publication candidate — production service configuration must be verified  
Effective date: To be set at launch  
Controller / 運営者: Takumi Chiba / forestone  
Contact: chiba@fores-tone.co.jp

## 日本語

この通知は、`Filmtone Finish for DaVinci Resolve`のtrialライセンスを請求するときの
データ処理を説明します。

### 取得・処理する情報

- 入力されたメールアドレス。
- bot対策と短時間のrate limitに必要なTurnstile token、IPアドレスなどの技術情報。
- trialの発行日時、有効期限、送信結果に必要な最小限の運用情報。

### 利用目的

メールアドレスは、trialライセンスの発行・送付、同一アドレスへの重複発行防止、
不正利用防止、問い合わせ対応のために利用します。広告配信やメーリングリスト登録には
利用しません。

### 保存方法と期間

- Cloudflare KVには、メールアドレスそのものではなくHMAC-SHA256による識別子と
  発行日時・有効期限を約400日保存します。
- IPアドレスそのものはKVへ保存せず、HMAC識別子をrate limitのため約1時間保存します。
- Workerのアプリケーションログにはメールアドレス、Resendのエラー本文、
  ライセンス内容を出力しません。
- Resendは、宛先メールアドレス、件名、本文、添付ライセンスなど、メール配信に必要な
  情報を処理します。Resend側の保持は同社の契約・プライバシー条件に従います。

### 委託先

- Cloudflare Workers / KV: trial発行処理、重複防止、rate limit。
- Cloudflare Turnstile: bot判定。ブラウザ・端末に関する技術的signalを処理します。
- Resend: trialメールと添付ライセンスの送信。

これらの事業者は日本国外でデータを処理する場合があります。各事業者の条件は下記の
公式リンクから確認できます。

### 開示・削除などの依頼

trialデータに関する質問、開示、訂正、削除の依頼は、請求に使用したメールアドレスから
`chiba@fores-tone.co.jp`へ連絡してください。法令、セキュリティ、不正利用防止のため
保持が必要な情報を除き、確認可能な範囲で対応します。

## English

This notice explains data processing when you request a trial license for
`Filmtone Finish for DaVinci Resolve`.

### Information processed

- The email address you submit.
- Technical information needed for bot protection and short-term rate limiting,
  including a Turnstile token and IP address.
- Minimal operational data needed to issue the trial, record its issue and
  expiry times, and determine delivery status.

### Purposes

The email address is used to issue and deliver the trial license, prevent
duplicate trials for the same address, prevent abuse, and respond to support
requests. It is not used for advertising or mailing-list enrollment.

### Storage and retention

- Cloudflare KV stores an HMAC-SHA256 identifier instead of the plaintext email,
  together with issue and expiry times, for approximately 400 days.
- The plaintext IP address is not stored in KV. An HMAC identifier is retained
  for approximately one hour for rate limiting.
- Application logs do not contain email addresses, Resend error bodies, or
  license contents.
- Resend processes the recipient address, subject, message, and attached license
  as required to deliver the email. Resend retention follows its contractual
  and privacy terms.

### Service providers

- Cloudflare Workers / KV: trial processing, duplicate prevention, and rate
  limiting.
- Cloudflare Turnstile: bot detection using technical browser and device signals.
- Resend: delivery of the trial email and attached license.

These providers may process data outside Japan.

### Requests

For questions or requests for access, correction, or deletion, email
`chiba@fores-tone.co.jp` from the address used for the trial request. We will
respond where the record can be identified, except where retention is required
by law, security needs, or abuse prevention.

Official provider references:

- <https://developers.cloudflare.com/turnstile/>
- <https://www.cloudflare.com/policies/privacy/>
- <https://resend.com/legal/privacy-policy>
- <https://resend.com/legal/dpa>

