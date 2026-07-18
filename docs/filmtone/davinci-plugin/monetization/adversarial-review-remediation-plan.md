# Filmtone Finish Monetization 全体対応計画書

Date: 2026-07-18 JST  
Status: Active  
Scope: Codex adversarial review 全件 + MON-2〜MON-6 発売完了まで  
Strategy source: [strategy.md](strategy.md)  
Execution specification: [implementation-plan.md](implementation-plan.md)  
Progress source: [progress.md](progress.md)

## 0. 文書の役割

本書は、Codex adversarial review の全指摘を起点として、現在のライセンス
ツール・trial Worker・課金文書を、プラグイン実装、販売基盤、配布、発売まで
完了させるための**横断実行計画**である。

- `strategy.md`: 価格、販売形態、コスト構造、長期判断の正本。
- `implementation-plan.md`: wire format、Worker、MON-2〜6の実装仕様正本。
- `progress.md`: 各MONの現在状態と完了記録。
- **本書**: 指摘の判定台帳、残作業の優先順位、依存順、責任、ゲート、全体Done。

単発のレビュー指摘ごとに別計画を増やさず、残作業は本書の該当フェーズに統合する。

## 1. Goal / 全体Done

購入者またはtrial利用者が、次の導線を実環境で一巡できる状態を作る。

1. 未ライセンス版をインストールし、全機能をwatermark付きで評価できる。
2. trialを請求し、メールで受領した署名ライセンスによりclean出力へ移行できる。
3. trial期限後はwatermark状態へ戻る。
4. Polarで購入し、fullライセンスを受領して永続的にclean出力できる。
5. `.pkg`が署名・notarizeされ、公開ページの価格・機能・対応環境が実装と一致する。

全体Doneは、コード完成だけではなく、MON-2〜MON-6の受入条件と発売ゲートを
すべて満たした時点とする。

## 2. 現在地

| 領域 | 状態 | 現在の判断 |
|---|---|---|
| MON-1 価格・条件 | Accepted | $49 / ローンチ$39 / 買い切り / 14日trial |
| MON-3 発行ツール | Review | TS実装・鍵生成・1Password保存済み。MON-2のCクロス検証待ち |
| MON-4 Worker | Running | 外部本番設定済み。Turnstile context bindingはcode反映済みでcurrent source再deploy待ち。実送達、公開導線、法務ゲートも残る |
| MON-2 プラグイン | Blocked | Breath / Weave品質回復、combined/public受入、source耐久化後にdispatch |
| MON-5 `.pkg` | Queued | MON-2統合後 |
| MON-6 発売 | Queued | MON-2〜5とrelease truth完了後 |

## 3. Adversarial Review 判定台帳

| ID | 判定 | 本計画での扱い |
|---|---|---|
| B1 未来日`issuedAt` | 対応済み | 正しい時計の下で1通の有効期間を最大34日に制限。鍵失効はローテーション |
| B2 TS/C wire format | 設計対応済み / 実装ゲート | envelope + exact payload bytes。MON-2でC fixtureクロス検証 |
| B3 kind非拘束verify | 対応済み | signed `kind`による内部鍵選択を維持 |
| B4 公開メール送信器 | コード対応済み / 実機ゲート | streaming 4KB、型検証、Turnstile必須、hostname/action binding、IP throttle。deploy済みsourceの更新とruntime確認はMON-4 |
| M5 KV非atomic / 冪等性 | 対応済み / accepted risk | Resend 409をerror `name`で判別。厳密atomic化は採らずsoft制限を維持 |
| M6 MON-2仕様不足 | 仕様対応済み / 実装待ち | snapshot、時刻、cache、thread、watermark画素規律をMON-2で実装 |
| M7 orlp license | 仕様対応済み / vendor待ち | zlib LICENSE、commit pin、verify経路一式をMON-2で同梱 |
| M8 鍵運用 | 対応済み / rotation gate | `~/.filmtone/secrets/`移動・権限・1Password Private vault保管済み。公開鍵rotationは運用手順を維持 |
| M9 赤字表現 | 対応済み | 新規固定費ゼロと取引単位の下振れを分離して維持 |
| M10 full手動発行待ち | 仕様対応済み / 運用ゲート | 24h SLA、trial bridge、trial使用済み購入者の優先発行文面を発売前に実装 |
| M11 trial PII | コード対応済み / 規約待ち | HMAC識別子、TTL、generic応答、PII非ログ。プライバシー表記はMON-4 |
| M12 ポジショニング | 計画対応済み / 公開前truth gate | 「3点だけの買い切り選択肢」に限定し、quality parityを主張しない |
| M13 文書矛盾 | 再発防止反映済み | latest mainのsplit quality verdictへ同期。各phaseで変更した正本だけ更新する |
| M17 QUALITY依存誤認 | 対応済み / owner evidence待ち | MON-2をQueuedからBlockedへ変更。Breath / Weave独立品質iterationとcombined/public受入を明示dependency化 |
| M18 release署名 | 仕様対応済み / owner gate | 内包OFXをDeveloper ID Application + hardened runtime + timestampで先に署名し、外側pkgをDeveloper ID Installerで署名 |
| M19 source耐久性 | 計画対応済み / owner Git gate | local-only mainと未追跡monetization sourceのまま追加deploy/MON-2/releaseへ進まない |
| M20 compatibility truth | 仕様対応済み / 実機ゲート | ProductVersion.mkを正本化し、macOS 14.0+ / Resolve 21.x候補を実測範囲に限定して公開 |
| m14 クーポン計算 | 対応済み | $10固定額クーポンを維持 |
| m15 `TRIAL_DAYS` | 対応済み | 検証済み`days`を期限・件名・本文で共有 |
| m16 index loop | 対応済み | 現行宣言的記法を維持 |

## 4. 実行フェーズ

### Phase A — レビュー残件を閉じる(MON-3 / MON-4現在地)

#### A1. Resend 409を種別判定する

Status: Completed (2026-07-18、testing authorization なしのため静的確認のみ)

対象:

- `infra/license-worker/src/index.ts`
- `infra/license-worker/README.md`
- `implementation-plan.md` §5
- `progress.md`

必要挙動:

| Resend response | Worker response | KV |
|---|---:|---|
| `2xx` | generic 200 | 記録する |
| `409 invalid_idempotent_request` | generic 200 | 記録する |
| `409 concurrent_idempotent_requests` | 503 + `Retry-After: 2` | **記録しない** |
| 不明・JSON不正の409 | 502 | **記録しない** |
| その他の非2xx | 502 | **記録しない** |

実装条件:

- Resend JSONの`name`だけを判定し、`message`や本文をログに出さない。
- 既存のhourly payload、Idempotency-Key、KV key、TTLは変更しない。
- Durable Objects、queue、DB、新規依存は追加しない。
- MON-4は`Running`のまま維持する。

Done:

- concurrent / unknown 409でKVを書く経路がない。
- Worker README、対応計画、進行書が同じresponse matrixを示す。

#### A2. 鍵保管を完了する(オーナー操作)

Status: Completed (2026-07-18、1Password Private vaultへのdocument保存を
item metadataのみで確認。秘密鍵内容は非表示)

- `filmtone-full.key.json`と`filmtone-trial.key.json`を1Passwordへ保存する。
- repo、iCloud Documents、Workerログへ秘密鍵を持ち込まない。
- trial private keyだけをCloudflare secretへ登録する。
- 完了後もMON-3は、Cクロス検証が終わるまで`Review`を維持する。

### Phase Q — Product-quality recovery(MON-2前提)

Status: Blocked on owner-observed defects and future testing authorization

最新mainのQUALITYは「受入待ち」ではなくpartial acceptanceでclosedした。Film
Damageはpass、Film Breath / Gate Weaveはbelow passで、combined/public product
acceptanceは明示的に未成立。MON-2を開始する前に次を閉じる:

1. Film Breathの次iterationは、オーナーが最も目立つ実写failureを具体化してから
   immutable workstream planを作る。原因を仮定した先回り調整は禁止。
2. Gate Weaveも同じ手順で独立iterationを行う。
3. 両moduleがowner passを得た同一baseで、default / isolated / combined、固定
   pass order、temporal / random access / fps / cache / reopen / export、format /
   alpha / bounds、CinePrint35 coexistenceを実装戦略のMeasurable Done Conditionsに
   従い確認する。
4. coordinatorがcombined/public product acceptanceを明示する。

テスト、ハーネス、Resolve操作は、そのfuture taskでオーナーが明示的にtesting
authorizationを与えた場合だけ行う。現タスクでは品質sourceを推測変更しない。

### Phase S — Source durability gate(オーナーGit操作)

Status: Blocked on owner authorization

2026-07-18 review時点でローカル`main` `cb9b465`は`origin/main`より18 commits
先行し、`package.json`、monetization docs、`infra/`、`scripts/license/`には未commit
変更がある。追加deploy、MON-2 dispatch、署名済み配布物作成より前に:

- 選択したbaseとmonetization sourceを同じreview済みcommit系列へ置く。
- `origin/main`または明示されたremote branchから別checkoutで取得可能にする。
- Worker deploy sourceのcommitを`progress.md`へ記録する。
- stage / commit / pushはオーナーの明示指示後だけ行う。

### Phase B — MON-2 プラグインライセンス実装

開始条件:

- Phase QのBreath / Weave owner passとcombined/public acceptanceが完了している。
- Phase Sを通過し、remoteから取得できる最新review済み統合refをbaseにする。
- 実装レーンのimmutable workstream planを作成している。
- テストまたはハーネス実行を行う場合、オーナーのtesting authorizationを
  dispatch文面へ明記している。

実装対象:

- `LicenseStore.h/.mm`: envelope decode、kind別公開鍵、期限、snapshot、cache。
- `WatermarkPass.h/.mm`: 最終pass、global座標、alpha不変、extended range保持。
- `vendor/ed25519/`: orlp verify経路、zlib LICENSE、commit pin。
- `PublicKeys.h`: full / trial公開鍵リスト。
- OFX統合点: render graph最終段とread-only License status。

wire / C-parity条件:

- payload bytesはUTF-8として扱う。
- TS fixtureの署名対象bytesをC側でそのまま検証する。
- 固定key順、未知・欠落・重複field拒否、厳密UTC、サイズ上限を一致させる。
- name/email/orderRefの長さ単位はC実装前に明文化し、TSと同じ判定にする。
- trial鍵でfull、未来日、非canonical、型違い、不正base64を拒否する。

受入:

- 未ライセンス/期限切れはwatermark、valid full/trialはclean。
- valid license + 全module offでbit-exact identity。
- renderScale、tile、portrait、extended-range、alphaの規律を満たす。
- Cクロス検証完了後、MON-3を`Accepted`へ進める。
- MON-2受入後にMON-5をReadyにする。

Accepted risks:

- オフライン時計を有効期間内に固定するtrial延長は許容する。
- KVの完全atomic化とオンラインactivationは採らない。
- 同mtime・同sizeの病的なlicense差し替えは既知制約として扱う。

### Phase C — MON-4 販売基盤と外部サービス

オーナー操作:

1. Polar org作成日を確認して手数料tierを確定する。
2. `Filmtone Finish for DaVinci Resolve`を$49で登録する。
3. ローンチ用の$10固定額クーポンを作成する。
4. [完了 2026-07-18] Resendで送信domainを検証し、送信専用・domain限定keyを
   発行する。現契約に送信量alert設定はないため、超過課金オフとUsage監視を維持する。
5. [初回完了 2026-07-18 / current source再deploy待ち] Worker + KVを作成し、
   4 secretsを登録する。hostname/action binding版はPhase S後にdeploy commitを
   記録して再deployする。
6. [完了 2026-07-18] Turnstile本番site/keyを設定する。
7. [完了 2026-07-18] trial intakeはPolar $0 checkoutではなく、製品ページの
   Turnstile付きフォームからWorkerを直接呼ぶ方針にする。

規約・顧客導線:

- EULA: 1 user / 2 machines、商用可、再配布禁止、責任制限。
- 返金: 14日。
- trial privacy: email利用目的、Cloudflare/Resend、HMAC記録、約13ヶ月TTL。
- full発行: 24時間以内SLA。
- trial使用済み購入者: 購入メール返信による優先発行を明記。

発売ゲート:

- Resend実メールが到達し、添付licenseが検証できる。
- Turnstile本番tokenは`action == filmtone_trial`かつhostname allowlist一致だけ成功し、
  欠落・不正・action不一致・hostname不一致tokenは拒否される。MON-6のwidgetは
  `data-action="filmtone_trial"`を設定する。
- 同一email再請求、IP throttle、Resend失敗時の再試行が意図どおり動く。
- Polar sandboxまたは許容された実取引で購入→full発行が一巡する。
- 上記完了まではMON-4を`Running`に置く。

### Phase D — MON-5 配布物

開始条件: MON-2 Accepted、Phase S完了、公開version候補確定。

- `apps/filmtone-resolve-ofx/Resources/ProductVersion.mk`をmarketing/build versionと
  macOS deployment targetの単一正本にする。現内部評価値は0.1.0 / 1 / macOS 14.0。
- OFX bundleをDeveloper ID Application + hardened runtime + secure timestampで
  **先に署名**する。外側pkgだけの署名は禁止。
- 署名済みOFX bundleを`/Library/OFX/Plugins`へ配置する`.pkg`を生成し、Developer
  ID Installerで署名する。
- notarizationを通し、ticketをstapleする。
- install、Resolve再起動、plugin discovery、license配置、uninstallを文書化する。
- clean Mac相当でwatermark→license→cleanの導線を一巡する。
- macOS 14.0+ / Resolve 21.x候補は実機で確認した範囲だけを公開対応範囲にする。
- 完成した`.pkg`をPolarの購入者向けfile benefitへ登録する。

### Phase E — MON-6 公開・発売

開始条件: Phase Q/S、MON-2〜5のDoneとrelease truth確認。

- portfolioに製品ページ、価格、trial、購入CTA、導入手順、規約リンクを追加する。
- 公開コピーは「Film Breath / Gate Weave / Film Damageの3点を買い切りで
  提供する」に限定し、Dehancerとのquality parityを示唆しない。
- JP/EN release articleを作成する。
- ローンチ価格終了日を発売+30日で登録し、通常$49へ戻す。
- 公開ページと実装の対応OS、Resolve version、license挙動を最終照合する。

## 5. 依存順

```text
Phase A completed ───────────────────────────────┐
                                                ├─ Phase C MON-4 runtime gates ────────────────┐
Breath recovery ─┐                              │                                               │
Weave recovery ──┼─ Phase Q combined/public acceptance ─┐                                      │
quality matrices ┘                                         ├─ Phase B MON-2 ─ Phase D MON-5 ───┼─ Phase E MON-6
owner Git authorization ─ Phase S source durability ──────┘                                      │
                                                                                                  ┘
```

Phase A/CとPhase Qの準備は並行可能。Phase Qは具体的なowner-observed failureと
testing authorizationが得られるまで実装しない。Phase BはQ/S完了前に開始しない。
Phase EはQ/SまたはMON-2〜5のどれかが未完なら開始しない。

## 6. Verification policy

- 現在の計画作成ではテスト、ハーネス、test file作成を行わない。
- 実装時も、オーナーがそのタスクで明示的にtesting authorizationを与えない限り、
  テスト・test-like verification・test file作成を行わない。
- 許可された場合も、変更surfaceを証明する最小ケースだけを実行する。
- 外部実機確認(Resend、Turnstile、Polar、notarization)は各発売ゲートで記録する。
- 実行結果は`progress.md`へ、戦略変更だけを`strategy.md`へ短く記録する。

## 7. Global constraints / Non-goals

- 新規固定費を作らない。
- プラグインへnetwork codeを入れない。
- full private keyをcloudへ置かない。
- subscription、seat server、online activationを追加しない。
- Durable Objectsや購入full licenseのcloud署名を初期発売へ持ち込まない。
- legacy Electron Desktop、iOS、shared packagesを変更しない。
- portfolio実装はこのrepoで直接行わず、正規のvendor/submodule手順に従う。
- 無関係な文書清掃、archive整理、広域refactorを各Phaseへ混ぜない。
- stage、commit、push、portfolio submodule bumpはオーナー指示なしに行わない。

## 8. Stop conditions

- 月額契約または新規固定費が必要になった。
- full keyをcloudへ置かないと成立しない要求が出た。
- MON-2がPhase Q/S完了前に必要になった。
- owner-observed failureなしでBreath / Weaveの原因や調整値を推測する必要が出た。
- local-only / untracked sourceのまま追加deploy、署名、releaseが必要になった。
- signed payloadまたはC parityの仕様変更が必要になった。
- 同じ検証失敗が3回連続した。
- 作業対象が本書のPhase境界を越える必要が出た。

発生時は実装を止め、`progress.md`へblockerを記録し、戦略または対応計画の
レビューへ戻す。

## 9. Overall Done checklist

- [x] Phase A: Resend 409分岐修正
- [x] Phase A: full/trial keyの1Password保存
- [ ] Phase Q: Film Breath / Gate Weave独立iterationのowner pass
- [ ] Phase Q: quality matrixとcombined/public product acceptance
- [ ] Phase S: review済みbaseとmonetization sourceのremote耐久化
- [ ] Phase B: MON-2 license + watermark実装と受入
- [ ] Phase B: TS/C fixture・adversarial parity完了、MON-3 Accepted
- [ ] Phase C: Polar / Resend / Turnstile(hostname/action含む) / Worker実環境ゲート完了
- [ ] Phase C: EULA / refund / privacy / SLA導線完了、MON-4 Accepted
- [ ] Phase D: 内包OFX + `.pkg`署名、notarization、version/compatibility、clean環境導線完了、MON-5 Accepted
- [ ] Phase E: release truth、製品ページ、記事、価格終了日、MON-6 Accepted
- [ ] 購入→full license→clean出力が実導線で一巡
- [ ] trial請求→clean→期限後watermarkが実導線で一巡
- [ ] 公開コピー、実装、価格、規約、進行書に矛盾がない

## 10. Agent Execution Brief (English)

Goal:
Complete the Filmtone Finish monetization lane from the current reviewed state to
a launch-ready product, including the remaining Worker correction, native OFX
license enforcement, sales operations, packaging, and release gates.

Context:
The TypeScript license tools and trial Worker exist. MON-3 is in Review and
MON-4 is Running. The latest QUALITY task is closed with partial acceptance:
Damage passed, Breath and Weave did not, and combined/public product acceptance
was not granted. MON-2 is therefore Blocked, not Queued. The local source is also
not durable yet: local main is ahead of origin/main and the monetization lane is
uncommitted.

Constraints:
- Execute Phase A/C safely, then Q/S, B, D, and E in the dependency order defined
  in this document.
- Complete the product-quality recovery and source-durability gates before MON-2.
- Preserve the two-key offline license architecture and zero-network OFX plugin.
- Keep the full private key local and in 1Password only.
- Do not add fixed-cost infrastructure, subscriptions, online activation, queues,
  databases, or unrelated refactors.
- Do not run tests or create test files without explicit owner authorization in
  the implementation task.
- Keep progress, implementation specification, and strategy truth separated.
- Sign the inner OFX bundle with Developer ID Application before signing the
  outer package with Developer ID Installer, and publish only compatibility
  ranges proved by release evidence.

Expected output:
- Close the review ledger without reopening resolved findings as speculative work.
- Close the quality-recovery and source-durability gates, implement and accept
  MON-2, complete MON-4 runtime gates, MON-5 packaging, and MON-6 release.
- Record evidence for each gate in `progress.md`.
- Finish with both purchase and trial user journeys working end to end.

Non-goals:
- Do not redesign the licensing business model.
- Do not move full-license signing to the cloud.
- Do not expand into other Filmtone apps or legacy Desktop work.
- Do not treat documentation cleanup as a separate project.
