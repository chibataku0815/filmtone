# Filmtone Web Support / Privacy Deploy Handoff

Last updated: 2026-04-20 03:00 JST

This is a fresh, stand-alone handoff for deploying the Filmtone iOS app's **Support** and **Privacy** public web pages to `chibatakumi.studio`. The new chat will operate on the `chibatakumi-portfolio` repository (Next.js / Vercel) and must work **independently** of the Filmtone iOS fastlane release chat that spawned this handoff.

Read this document end-to-end before taking any action.

Related documents:
- **iOS fastlane release handoff (parent work)**: `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md`
- **iOS release plan file (life repo)**: `/Volumes/SamsungPortableSSDX5001/documents/life/.claude/plans/3-twinkling-hammock.md`

---

## 1. Why This Matters (Executive Status)

Filmtone iOS v1.0 の App Store 公開パイプライン（別 chat 進行中）が以下 2 URL 404 で **submit-for-review 前に停止** している:

| URL | 現状 |
|---|---|
| `https://www.chibatakumi.studio/film-lab/support` | **404** |
| `https://www.chibatakumi.studio/en/film-lab/support` | **404** |
| `https://www.chibatakumi.studio/film-lab/privacy` | **404** |
| `https://www.chibatakumi.studio/en/film-lab/privacy` | **404** |
| `https://www.chibatakumi.studio/film-lab` | ✅ 200 (既存、参考) |
| `https://www.chibatakumi.studio/en/film-lab` | ✅ 200 (既存、参考) |

Apple App Review のガイドライン上、Support URL と Privacy Policy URL は **reachable (200)** 必須。現状 fastlane `upload_to_app_store` の precheck が empty url として warning を出す（upload-only は完走するが、`SUBMIT_FOR_REVIEW=1` で提出不可）。

**根本原因**: Support / Privacy の Next.js page.tsx は既に **実装済み・ローカル存在**。ただし **git untracked** のため commit / push / deploy が未実行。

**このチャットの責務**: 未 commit の web app ファイル群を確認 → 必要に応じて内容レビュー → main 経由で deploy → URL 4 本が 200 を返すことを検証 → 親チャット（iOS fastlane）に完了通知。

**このチャットの非責務**:
- iOS アプリ本体 / fastlane / ASC / Xcode は一切触らない
- `feature/filmtone-ios-phase0` worktree の iOS 関連ファイルに触らない
- ASC submit-for-review を走らせない
- ASC 資格情報 (`.p8` / API Key) を扱わない

---

## 2. Objective

3 つを同一 deploy で達成:

1. `chibatakumi.studio/{film-lab,en/film-lab}/{support,privacy}` が 4 本とも HTTP 200 を返す
2. 内容が Filmtone iOS v1.0 の非交渉制約（§3）と齟齬なし
3. `apps/web/messages/{ja,en}.json` に必要な i18n key（`film-lab.supportPage.*` / `film-lab.privacyPage.*`）が正しく注入されデプロイされる

---

## 3. 非交渉制約（content review 必須確認）

Support / Privacy ページの文言は **以下に 100% 整合していなければならない**。逸脱があれば修正 → 再 deploy → 再検証。

### 3.1 Product facts

- **プラットフォーム**: iPhone のみ / iOS 17 以上（iPad / macOS / tvOS / visionOS 不対応）
- **Locale**: 日本語 (`ja`) / 英語 (`en-US`) のみ
- **認証 / 課金**: login なし / account なし / IAP なし / subscription なし
- **対応入力 codec**: `H.264 (AVC)` / `HEVC (H.265)` / `Apple ProRes`
- **明示非対応**: `Avid DNxHR` / `Avid DNxHD` — 「対応」と記載禁止
- **出力**: MP4 / H.264 / 長辺 1920px / 30 fps / 音声パススルー
- **ソース制約**: 5 分 (300s) / 長辺 3840px / 8 GiB
- **ポジショニング**: `local-first`。AI 生成 / cloud sync / subscription / アカウント同期の主張禁止

### 3.2 連絡先

- **Operator**: `Takumi Chiba`
- **Support email**: `chiba@fores-tone.co.jp`
- **Canonical base URL**: `https://www.chibatakumi.studio`
- **審査連絡電話 (ASC 側、公開しない)**: `+81-80-9983-6923`（E.164）

### 3.3 Privacy positioning

- **No account / No tracking / No analytics / No collection** — Filmtone は完全ローカル処理
- Photo Library permission（import / save）と Files access のみ使用、取得データはデバイス外に出ない

---

## 4. Environment

### 4.1 Absolute paths

| 用途 | パス |
|---|---|
| Repo parent clone (on `feature/webgpu-migration-v1`) | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/` |
| **Main-release worktree (on `main`)** — 本チャット推奨作業場 | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-main-release/` |
| iOS 作業用 worktree (`feature/filmtone-ios-phase0`、page.tsx 群のローカル保持元) — 読み取り専用参照 | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-phase0/` |
| life repo | `/Volumes/SamsungPortableSSDX5001/documents/life/` |

### 4.2 GitHub / Vercel

- **Remote**: `origin = https://github.com/chibataku0815/chibatakumi-portfolio.git`
- **Main branch tip (at handoff time)**: `6487a057` — `Merge remote-tracking branch 'origin/main' into feature/webgpu-migration-v1-release`
- **Deploy 手段**: `vercel.json` / `.vercel/` が repo 内に見当たらないため、**Vercel プロジェクト側で main 自動 deploy 設定されている**と推定。ただし新チャットで **確証取る必要あり**:
  ```sh
  # 確認方法（例）
  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-main-release
  vercel inspect --scope <team> 2>&1 | head
  # or GitHub Actions が存在する可能性を確認
  ls .github/workflows/ 2>&1
  ```

### 4.3 関連 worktree（他チャット進行中、干渉しない）

```
/Volumes/.../chibatakumi-portfolio                                   feature/webgpu-migration-v1   (Filmtone Desktop 作業)
/Volumes/.../chibatakumi-portfolio/.worktrees/filmtone-ios-phase0    feature/filmtone-ios-phase0   (iOS release 作業、親チャット)
/Volumes/.../chibatakumi-portfolio/.worktrees/filmtone-ios-mezzanine feature/filmtone-ios-mezzanine
/Volumes/.../chibatakumi-portfolio-main-release                      main                          ★ 本チャット作業場
```

main 直 push は推奨される作業場 `chibatakumi-portfolio-main-release` から行う。`feature/filmtone-ios-phase0` worktree に依存しない。

### 4.4 Time context

- Handoff 作成日時: `2026-04-20 03:00 JST`
- Timezone: `Asia/Tokyo`
- Apple App Review 審査連絡電話: `+81-80-9983-6923`（本チャットでは使わない、参考）

---

## 5. 対象ファイル（全 7 本）

### 5.1 新規追加（untracked、`feature/filmtone-ios-phase0` worktree のローカル）

| パス | 行数 | 役割 |
|---|---|---|
| `apps/web/src/app/[locale]/film-lab/support/page.tsx` | 305 | Support ページ本体 (App Review 参照先) |
| `apps/web/src/app/[locale]/film-lab/support/thanks/page.tsx` | (未確認、同 dir) | お問い合わせ完了ページ |
| `apps/web/src/app/[locale]/film-lab/support/thanks/FilmLabSupportThanksClient.tsx` | (未確認、同 dir) | Thanks ページ client component |
| `apps/web/src/app/[locale]/film-lab/privacy/page.tsx` | 195 | Privacy Policy ページ本体 |
| `apps/web/src/features/interactive/film-lab/ios-release-info.ts` | 30 | public-facing 定数 SSOT（page.tsx 2 本が import）|

### 5.2 既存編集（origin/main 比 +183 行ずつ）

| パス | origin/main 比 diff | 役割 |
|---|---|---|
| `apps/web/messages/ja.json` | +183 行 | `film-lab.supportPage` / `film-lab.privacyPage` i18n key + 他 Filmtone iOS 関連文字列 |
| `apps/web/messages/en.json` | +183 行 | 同上（英語） |

**⚠️ 重要**: `messages/{ja,en}.json` の +183 行には **Filmtone iOS ネイティブアプリ用の文字列（iOS 画面コピー）も混在** している可能性大。本チャットで必要なのは `film-lab.supportPage.*` / `film-lab.privacyPage.*` の key 階層のみ。iOS アプリ側で使われる key を誤って含めても web 側 build は通るが、責任範囲明確化のため diff を精査してから commit 範囲を決めること。

**確認方法**:
```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-phase0
git diff origin/main -- apps/web/messages/ja.json | head -300
```

### 5.3 既存 SSOT（page.tsx 2 本が import する）の値（2026-04-20 時点）

`ios-release-info.ts` から（参考、編集するなら §3 非交渉制約と整合）:

```ts
filmLabCanonicalBaseUrl          = "https://www.chibatakumi.studio"
filmLabIosSupportEmail           = "chiba@fores-tone.co.jp"
filmLabIosOperatorName           = "Takumi Chiba"
filmLabIosMinimumVersion         = "17.0"
filmLabIosSupportedDeviceFamily  = "iPhone"
filmLabIosSourceDurationCapSeconds = 300
filmLabIosSourceLongEdgeCapPx      = 3840
filmLabIosSourceFileSizeCapGiB     = 8
filmLabIosOutputLongEdgePx         = 1920
filmLabIosOutputFrameRate          = 30
filmLabIosOutputCodec              = "H.264"
filmLabIosOutputContainer          = "MP4"
filmLabIosPreservesSourceAudio     = true
filmLabIosSupportedInputCodecs     = ["H.264 / AVC", "HEVC / H.265", "Apple ProRes"]
filmLabIosUnsupportedVideoCodecs   = ["Avid DNxHR / DNxHD"]
```

---

## 6. 推奨手順（逐次、verify 込み）

### 6.1 Step 1 — 作業場セットアップ

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-main-release

# main が origin/main と同期しているか確認
git status
git fetch origin main
git log --oneline HEAD..origin/main | head -5   # 差分なければ空
git log --oneline origin/main..HEAD | head -5   # 先行なければ空

# 想定: 完全同期 (`6487a057` HEAD)
```

同期してなければ `git pull origin main` で追従（本チャット着手前の main に戻す）。

### 6.2 Step 2 — 未 commit ファイルを main-release に取り込む

`feature/filmtone-ios-phase0` worktree にある untracked ファイルを、`main-release` worktree にコピーする（**同じリポジトリなので cp 可**）:

```sh
SRC=/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-phase0
DST=/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-main-release

# 新規ファイル
mkdir -p "$DST/apps/web/src/app/[locale]/film-lab/support/thanks"
mkdir -p "$DST/apps/web/src/app/[locale]/film-lab/privacy"
mkdir -p "$DST/apps/web/src/features/interactive/film-lab"

cp "$SRC/apps/web/src/app/[locale]/film-lab/support/page.tsx"                                   "$DST/apps/web/src/app/[locale]/film-lab/support/page.tsx"
cp "$SRC/apps/web/src/app/[locale]/film-lab/support/thanks/page.tsx"                            "$DST/apps/web/src/app/[locale]/film-lab/support/thanks/page.tsx"
cp "$SRC/apps/web/src/app/[locale]/film-lab/support/thanks/FilmLabSupportThanksClient.tsx"      "$DST/apps/web/src/app/[locale]/film-lab/support/thanks/FilmLabSupportThanksClient.tsx"
cp "$SRC/apps/web/src/app/[locale]/film-lab/privacy/page.tsx"                                   "$DST/apps/web/src/app/[locale]/film-lab/privacy/page.tsx"
cp "$SRC/apps/web/src/features/interactive/film-lab/ios-release-info.ts"                        "$DST/apps/web/src/features/interactive/film-lab/ios-release-info.ts"
```

### 6.3 Step 3 — i18n message JSON の必要 key 抽出

`messages/{ja,en}.json` は iOS アプリ文字列も含む 183 行 diff。本チャットで必要なのは `film-lab.supportPage.*` と `film-lab.privacyPage.*` のみ。以下 2 択で進める:

**Option A（推奨・保守的）**: source worktree の JSON から該当 key 階層だけを抽出して main-release JSON にマージ。

```sh
# jq を使って該当 key 階層だけ抽出
cd $SRC/apps/web/messages
jq '.["film-lab"].supportPage, .["film-lab"].privacyPage' ja.json > /tmp/ja-filmlab-legal.json
jq '.["film-lab"].supportPage, .["film-lab"].privacyPage' en.json > /tmp/en-filmlab-legal.json
```
抽出後、main-release の messages JSON に手動マージ（jq の `*` merge 演算子で可）。

**Option B（速い・リスクあり）**: source worktree の messages/{ja,en}.json を main-release にそのまま cp。副作用として iOS 向け文字列も commit される。**iOS アプリ文字列が web app の i18n 動作に支障を与えない**ことを確認できる場合のみ採用。

いずれの Option を選んでも、commit メッセージで scope を明示（例: `feat(web): add film-lab support and privacy pages`）。

### 6.4 Step 4 — ローカル build / dev 動作確認

```sh
cd $DST/apps/web
bun install
bun run build 2>&1 | tail -30

# dev で URL 確認
bun run dev &
DEV_PID=$!
sleep 8
for u in \
  "http://localhost:3000/film-lab/support" \
  "http://localhost:3000/en/film-lab/support" \
  "http://localhost:3000/film-lab/privacy" \
  "http://localhost:3000/en/film-lab/privacy" ; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 10 "$u")
  echo "$code  $u"
done
kill $DEV_PID 2>/dev/null
```

期待: 4 本全て `200`。失敗時は Next.js build error / i18n key missing が典型。

### 6.5 Step 5 — 内容レビュー（§3 非交渉制約準拠）

build が通ったら、dev server で 4 URL を **ブラウザで目視確認** し、以下をチェック:

- [ ] 「AI 機能」「cloud sync」「account」「subscription」の記述が無い
- [ ] 「DNxHR」「DNxHD」が「非対応」として明示され、対応欄には入っていない
- [ ] 対応 codec が `H.264 / HEVC / ProRes` のみ
- [ ] iPhone only / iOS 17+ が明記（iPad / macOS 対応を示唆しない）
- [ ] 連絡先が `chiba@fores-tone.co.jp` / `Takumi Chiba`
- [ ] 日本語と英語で内容が一致（locale 切替で同じ事実が読める）
- [ ] canonical URL が `https://www.chibatakumi.studio/{film-lab, en/film-lab}/{support, privacy}`

文言に齟齬があれば先に修正、page.tsx / messages JSON を編集してから Step 6 へ。

### 6.6 Step 6 — Commit + Push + Deploy

ユーザー作業（本チャットの agent は commit / push を代行しない慣例、filmtone-ios-public-release-handoff §3.3 に準ずる）:

```sh
cd $DST
git add apps/web/src/app/\[locale\]/film-lab/support/page.tsx
git add apps/web/src/app/\[locale\]/film-lab/support/thanks/page.tsx
git add apps/web/src/app/\[locale\]/film-lab/support/thanks/FilmLabSupportThanksClient.tsx
git add apps/web/src/app/\[locale\]/film-lab/privacy/page.tsx
git add apps/web/src/features/interactive/film-lab/ios-release-info.ts
git add apps/web/messages/ja.json
git add apps/web/messages/en.json

git commit -m "feat(web): add film-lab support and privacy pages for iOS v1.0 App Review"
git push origin main
```

Vercel が main auto-deploy している場合、push から 2〜5 分で本番反映。deploy 通知は Vercel dashboard or メールで確認。

### 6.7 Step 7 — 本番 URL 検証

```sh
for u in \
  "https://www.chibatakumi.studio/film-lab/support" \
  "https://www.chibatakumi.studio/en/film-lab/support" \
  "https://www.chibatakumi.studio/film-lab/privacy" \
  "https://www.chibatakumi.studio/en/film-lab/privacy" ; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 15 "$u")
  echo "$code  $u"
done
```

期待: 4 本全て `200`。404 / 500 / タイムアウトなら Vercel deploy log を確認、必要に応じて再 push / 設定修正。

### 6.8 Step 8 — 親チャット（iOS fastlane）への完了通知

完了したら以下を親チャットに報告する:

- deploy 完了時刻（UTC / JST）
- 4 URL 全て 200 確認済み
- main branch の最終 commit hash
- Vercel deploy URL（preview / production 両方わかれば）

親チャットはこの通知を受けて `fastlane ios release` を走らせ、precheck 警告が解消されることを確認後、`SUBMIT_FOR_REVIEW=1` 判断に進む。

---

## 7. Critical files（本チャットで読む必須）

| 用途 | パス |
|---|---|
| 本ドキュメント | `docs/filmtone/web/archive/filmtone-web-support-privacy-deploy-handoff-2026-04-20-0300-jst.md` |
| 親チャット handoff（参照のみ） | `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md` |
| Support page 本体 | `apps/web/src/app/[locale]/film-lab/support/page.tsx` |
| Privacy page 本体 | `apps/web/src/app/[locale]/film-lab/privacy/page.tsx` |
| SSOT 定数（2 page.tsx の import 元）| `apps/web/src/features/interactive/film-lab/ios-release-info.ts` |
| i18n JA | `apps/web/messages/ja.json` |
| i18n EN | `apps/web/messages/en.json` |
| 既存 `/film-lab` LP（構造参考）| `apps/web/src/app/[locale]/film-lab/page.tsx` |

---

## 8. Risks / Gotchas

1. **messages JSON の scope 漏洩**: `messages/{ja,en}.json` の +183 行は iOS アプリ用文字列を含む可能性。Option A（§6.3）で key 抽出して commit 範囲を絞ると安全。Option B（全 diff commit）は速いが副作用リスクあり。どちらを採るかは diff を見て判断。
2. **Vercel deploy トリガー未確認**: repo 内に `vercel.json` / `.vercel/` が無いため、Vercel プロジェクト側設定で main 自動 deploy されていると**推定**。本チャット冒頭で `vercel inspect` / GitHub Actions / Vercel Dashboard で確証を取ること。
3. **Next.js i18n キー欠落**: page.tsx が参照する i18n key（`film-lab.supportPage.metadata.title` など）が messages JSON に無いと build error。Step 4 の build 検証で早期発見可。
4. **Locale 切替動作**: `next-intl` の `getTranslations` + `setRequestLocale` 使用。`[locale]` dynamic segment でルーティング。`/film-lab/support` → ja、`/en/film-lab/support` → en-US にマッピング。404 が再現したら middleware / i18n routing 設定を確認。
5. **iOS アプリ側の ios-release-info.ts との一致**: 本ファイルは web のみ。iOS アプリ側の `apps/capacitor-film-lab-ios/` にも同様の定数があるが、**web と iOS が同じ値を参照することが SSOT 原則** — 将来変更時は両側同期必要（本チャットでは web のみ触る）。
6. **Canonical URL hard-coding**: `filmLabCanonicalBaseUrl = "https://www.chibatakumi.studio"` で固定。preview / stg 環境では上書きが必要になる可能性あるが、本リリースでは production 一点張りなので変更不要。
7. **Privacy ページの法的妥当性**: 「no data collection / no analytics / no tracking」の記述が**実装と完全一致**していることを確認。iOS アプリ側で将来 analytics / Sentry / Firebase などを入れる場合、このページの記述を同時に更新しないと App Review で refuse される。
8. **Apple App Review の要件**:
   - Support URL: ユーザーが開発者に連絡できる手段が明示されていること (email / form)
   - Privacy Policy URL: データ取り扱いの方針が明示されていること
   - 404 / redirect loop / timeout 不可
   - Login 必須にしない（login wall の裏に隠さない）

---

## 9. Non-Negotiable Process Rules

`docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md` §3.3 と整合:

- 推論ではなく検証ベースで進める
- Fallback 設計禁止（auto backend switching、silent retry などを page.tsx に埋め込まない）
- 広域 cleanup 禁止（main-release worktree の無関係な dirty があれば触らない）
- `git commit` / `git push` はユーザーが行う。agent は提案まで
- sequential-thinking を非自明な判断の前に使う
- 不明は質問（ユーザー判断が必要な scope 拡張は必ず確認）

---

## 10. Verification checklist（このチャット完了時）

以下全てが ✅ になったら完了:

- [ ] `main-release` worktree が origin/main と同期している
- [ ] 5 新規ファイル + 2 既存ファイルが正しくステージ済み
- [ ] `bun run build` がエラーなく通る（web app build 成功）
- [ ] `bun run dev` で 4 URL (`/film-lab/{support,privacy}` / `/en/film-lab/{support,privacy}`) が 200
- [ ] 内容レビュー（§6.5）で非交渉制約と齟齬なし
- [ ] ユーザーが commit + push 実行
- [ ] Vercel production deploy 完了（dashboard で確認）
- [ ] 本番 4 URL が 200（§6.7 の curl 確認）
- [ ] 親チャット（iOS fastlane）に完了通知送信済み

---

## 11. Cold-Start Prompt For The Next Chat

新規 chat を開いたら以下を貼り付ける:

```text
あなたは Filmtone iOS v1.0 App Store 公開のための Web 側対応を引き継ぐ担当です。

正本の handoff ドキュメント:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-phase0/docs/filmtone-web-support-privacy-deploy-handoff-2026-04-20-0300-jst.md

このドキュメントを end-to-end で読んでから着手してください。過去 chat 履歴は無いので本ドキュメントを唯一の真実とすること。

作業場: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-main-release (on `main` branch)

目的: Next.js web app の Film Lab Support / Privacy ページを main に commit + push し、
chibatakumi.studio/{film-lab,en/film-lab}/{support,privacy} 4 URL を 200 にする。

非交渉制約（handoff §3 転記）:
- Filmtone は iPhone only / iOS 17+ / ja + en-US / no login / no IAP / no subscription
- 対応 codec: H.264 / HEVC / ProRes。DNxHR/DNxHD は非対応として明示
- Positioning は local-first。AI / cloud sync / subscription の主張は一切禁止
- 連絡先: Takumi Chiba / chiba@fores-tone.co.jp
- git commit / push はユーザー実行。agent は提案まで
- 無関係な main-release worktree の dirty に触らない
- iOS アプリ本体 / fastlane / ASC に一切触らない

現状検証済み:
- Support page.tsx (305 行) + Privacy page.tsx (195 行) + ios-release-info.ts (30 行) + messages/{ja,en}.json (+183 行) が feature/filmtone-ios-phase0 worktree に untracked 状態で存在
- main branch tip は 6487a057
- 4 URL は全て 404
- i18n key film-lab.supportPage / film-lab.privacyPage は messages JSON に存在確認済

直近やること:
1. handoff を熟読
2. main-release worktree で `git status` 確認、origin/main と同期
3. feature/filmtone-ios-phase0 worktree から 5 新規ファイル + 2 既存ファイル (messages JSON) を main-release にコピー — ただし messages JSON は film-lab.{supportPage,privacyPage} key 階層のみ取り込む方を推奨 (§6.3 Option A)
4. `bun install && bun run build` で build 健全性確認
5. `bun run dev` で 4 URL が 200 を返すことを確認
6. 内容レビュー (§3 非交渉制約との照合、§6.5 checklist)
7. 問題なければユーザーに narrow commit set を提案 → ユーザーが commit / push
8. Vercel auto-deploy 完了後、本番 4 URL を curl で 200 確認
9. 親チャットへの完了通知文面を提案

重要な技術指針:
- 計画の前に検証、推測の前に調べる
- 非自明な判断前に sequential-thinking
- scope escalation は事前確認
- Apple App Review の視線で各ページ文面を読む

まず handoff を読み、3 行で計画を提示してください。
```

---

## 12. Change Log

- 2026-04-20 03:00 JST — 本 handoff 作成。親チャット (iOS fastlane release) の Phase 2 (metadata upload) 完了・Phase 3 (release upload-only) 待機状態から分岐。URL 404 が `SUBMIT_FOR_REVIEW=1` 前の最大ブロッカーと判明、Web 側 deploy を別 chat に分離。
