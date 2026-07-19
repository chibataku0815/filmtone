# MON-6 Owner Runbook — Vercel 環境変数 + Polar 販売設定

Status: Owner 手動実行用（Claude は実行しない）
Date: 2026-07-19 JST
対象: `Filmtone for DaVinci Resolve`（買い切り OFX プラグイン）のローンチ準備
関連: [progress.md](progress.md) 改訂 26 / [implementation-plan.md](implementation-plan.md) §5・§7 /
[refund-policy.md](refund-policy.md) / [license-delivery-support.md](license-delivery-support.md)

---

## 0. このドキュメントの位置づけ

progress.md 改訂 26 で列挙した「残る owner 手順」のうち、**owner 自身の Vercel /
Polar アカウントでしか実行できない操作**を、コピペ実行できる粒度に落とした手順書。
コード・ドキュメントの変更は伴わない（すべてダッシュボード操作と値の設定）。

このリポには Polar 連携コードは存在しない（既存決済導線は Stripe donation のみ）。
購入確認ページ・受領メールは **Polar ダッシュボード側の設定**で、この codebase の外。

### 実行順序の依存関係

1. **§2.1 で Polar checkout URL を確定** → その値を **§1 の Vercel env** に入れる
   （§1 と §2.1 は値が繋がっている。先に §2.1 を済ませると §1 が 1 回で終わる）。
2. **§1 の env 設定後は必ず再デプロイ**（§1.4）。設定だけでは反映されない（SSG）。
3. §2.2〜§2.4 の Polar 設定は §1 と独立に進めてよい。

### 前提（already done / 参照）

- Polar に製品「Filmtone for DaVinci Resolve」($49 買い切り) と **$10 固定額クーポン**
  は 2026-07-18 に登録済み（progress.md §MON-4）。**新規作成ではなく既存を使う。**
- 署名・notarize・staple 済み pkg `Filmtone-0.1.0.pkg` は作成済み（progress.md 改訂 25）。
- Cloudflare Turnstile 本番 widget（許可 domain `chibatakumi.studio` /
  `www.chibatakumi.studio`、action `filmtone_trial`）と Worker の `ALLOWED_ORIGIN`
  は設定済み。新ページは同一ホスト配下（`/filmtone/resolve`）なので **Worker 側の
  変更は不要**。
- portfolio 側の製品ページコード（`/filmtone/resolve` と法務サブページ）は
  改訂 26 時点で **未 commit の working tree 差分**。§1.4 の再デプロイで実際に公開
  するには、この変更が「デプロイされる中身」に含まれている必要がある（GitHub
  Actions 経路なら **先に main へ commit/push**、手動 CLI 経路なら working tree が
  そのまま上がる）。

---

## 1. Vercel: 環境変数の設定と再デプロイ

### 1.1 対象プロジェクトと設定場所

| 項目 | 値 |
|---|---|
| Vercel プロジェクト名 | `chibatakumi-portfolio-web` |
| Root Directory | `apps/web` |
| 設定場所 | Vercel ダッシュボード → プロジェクト `chibatakumi-portfolio-web` → **Settings → Environment Variables** |
| **対象環境** | **Production**（必ず Production にチェック。理由は §1.3） |

> **重要:** デプロイは `vercel pull --environment=production` → `vercel build --prod`
> の順で **Production スコープの env だけ**を焼き込む。Preview / Development だけに
> 設定しても本番には反映されない。4 変数すべて **Production** に入れること。

### 1.2 設定する環境変数（4 件）

変数名は portfolio の `apps/web/.env.example`（89〜119 行）および
`apps/web/src/features/interactive/film-lab/resolve-plugin-info.ts` と一致している。

| 変数名 | 必須 | 値の入手先 |
|---|---|---|
| `NEXT_PUBLIC_FILMTONE_RESOLVE_TURNSTILE_SITE_KEY` | **必須** | 1Password（§1.2.1） |
| `NEXT_PUBLIC_FILMTONE_RESOLVE_POLAR_CHECKOUT_URL` | **必須** | Polar Checkout Link（§2.1 で取得） |
| `NEXT_PUBLIC_FILMTONE_RESOLVE_TRIAL_ENDPOINT` | 任意 | 空のままでよい（§1.2.2） |
| `NEXT_PUBLIC_FILMTONE_RESOLVE_PKG_DOWNLOAD_URL` | 任意（※trial 経路には実質必須） | §1.2.3 / §4 |

未設定時のフォールバック（デッドリンクにはならない）:
- Turnstile site key が空 → trial フォームは「一時的に利用不可」表示。
- Polar checkout URL が空 → 購入 CTA は「近日公開」の無効表示。
- pkg URL が空 → install 手順が pkg 名パターンのみ表示（DL リンクなし）。

#### 1.2.1 `NEXT_PUBLIC_FILMTONE_RESOLVE_TURNSTILE_SITE_KEY` の値

- **1Password** を開く → Environment（アイテム）**「Filmtone Production」**
  （item id `w4plqx7tjh2zmaojldj6r3jfp4`）。
- その中の **`TURNSTILE_SITE_KEY`** フィールドの値を使う。
- これは **公開値（非秘密）**。同じ Environment に Worker 用の **秘密**
  `TURNSTILE_SECRET` も同居しているが、**site key の方**（widget 埋め込み用の公開
  キー）を使うこと。両者を取り違えないよう、フィールド名 `TURNSTILE_SITE_KEY` で
  確認する。
- widget の `action` はコード側で `filmtone_trial` に固定済み。site key を差し替える
  だけでよい（Worker 側の設定変更は不要）。

#### 1.2.2 `NEXT_PUBLIC_FILMTONE_RESOLVE_TRIAL_ENDPOINT`（任意）

- **空のままでよい。** 未設定時は本番 Worker の既定 URL
  `https://filmtone-license-worker.chiba-4f9.workers.dev/trial` を使う
  （`resolve-plugin-info.ts` の `FILMTONE_RESOLVE_TRIAL_ENDPOINT_DEFAULT`）。
- 別 endpoint を使う必要が生じたときだけ設定する。

#### 1.2.3 `NEXT_PUBLIC_FILMTONE_RESOLVE_PKG_DOWNLOAD_URL`（任意・要判断）

- 署名済み pkg の **公開 HTTPS 直リンク**。設定すると install 手順に DL リンクが出る。
- **注意（§4 参照）:** コード上は optional だが、**trial 利用者にはこの公開 URL が
  実質必須**。trial 利用者は Worker から `.license` しか受け取らず、pkg 本体の入手
  経路が他にない（Polar のファイル配信は購入者限定の個別署名 URL で trial には
  使えない）。公開ホスト（例: Cloudflare R2 / Vercel Blob 等）に pkg を置いて直
  リンクを設定するか、trial 導線の pkg 配布方法を別途決める **owner 判断**が要る。
- 実バージョン・配布先が未確定の間は空でよいが、その場合 trial 導線が完結しない
  点は認識しておく。

### 1.3 重要: SSG のため「設定しただけ」では反映されない

`/filmtone/resolve` は **静的生成（SSG）**される。`NEXT_PUBLIC_*` は **ビルド時に
コードへ焼き込まれる**ため、Vercel ダッシュボードで値を保存しただけでは**反映され
ない**（購入 CTA は「近日公開」・trial は「利用不可」のまま）。

**値を設定したら、必ず新しいビルドを走らせて（=再デプロイして）焼き込む。** これは
save-and-forget では終わらない。

### 1.4 再デプロイの手順

このプロジェクトは **Git auto-deploy が無効**（`apps/web/vercel.json` の
`deploymentEnabled: false`）。理由は、Vercel 側 build が private submodule
`vendor/filmtone` を取得できないため。本番デプロイは **GitHub Actions の prebuilt
経路**または**手動 CLI** で行う。

#### 経路 A（推奨・正本）: GitHub Actions ワークフロー

1. （GitHub Actions 経路の場合）portfolio の `/filmtone/resolve` ページ変更を
   **先に `main` へ commit/push**（改訂 26 の未 commit 差分。これがないと再デプロイ
   しても新ページは公開されない）。
2. GitHub → `chibatakumi-portfolio` → **Actions** → **「Vercel Production Deploy」**
   → **Run workflow**（このワークフローは `workflow_dispatch` 対応）。
   - CLI 派なら repo root で `gh workflow run vercel-production-deploy.yml`。
   - `main` への push でも自動起動する（`on.push: main`）。
3. ワークフローは
   `vercel pull --environment=production`（Production の env を取得）→
   `vercel build --prod`（**ここで NEXT_PUBLIC を焼き込み**）→
   `vercel deploy --prebuilt --prod` を実行する。
   ワークフロー定義: `chibatakumi-portfolio/.github/workflows/vercel-production-deploy.yml`。

#### 経路 B（fallback）: 手動 CLI

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio   # 必ずリポジトリ root
bunx vercel deploy --prod --yes
```

- **必ず repo root で実行**（`apps/web` から叩くと内部で `apps/web/apps/web` の
  誤パスになる — portfolio README「Vercel」節）。
- ローカル working tree（submodule 展開済み）をアップロードして Vercel 側で build
  するため、未 commit の scaffold もそのまま公開される。

#### やってはいけないこと

- **Vercel ダッシュボードの「Redeploy」ボタンだけに頼らない。**
  - 既存 prebuilt 出力の再配信では**新しい `NEXT_PUBLIC_*` 値が焼き込まれない**。
  - Vercel 側で再ビルドさせる形になると、private submodule `vendor/filmtone` を
    取得できずに失敗する（git deploy を無効化しているのと同じ理由）。
  - 必ず経路 A か B で **新規ビルド**を走らせる。

#### 反映確認

デプロイ完了後、`https://www.chibatakumi.studio/filmtone/resolve` を開く:

- 購入 CTA が「近日公開」ではなく **有効なリンク**になっている。
- trial フォームに **Turnstile widget が表示**される（「一時的に利用不可」でない）。

---

## 2. Polar: 製品・配信・購入メール・返金

> UI 表記の注記: 以下は Polar 公式 docs（`polar.sh/docs/...`）に基づくが、ダッシュ
> ボードのメニュー階層・ボタン文言は変わりうる。**機能名**で書き、正確なクリック
> パスが docs で確認できない箇所は「（現行 UI で位置を確認）」と明示する。断定的な
> クリックパスを推測で書かない。

### 2.1 既存製品の checkout URL を取得する

Polar では「製品ごとの share link」ではなく、**Checkout Link** オブジェクトで購入
URL を作る（docs: `polar.sh/docs/features/checkout/links`）。製品の右クリックメニュー
には Archive / Duplicate しかなく、share は無い。

1. Polar ダッシュボード → **Products → Checkout Links**（正確な位置は現行 UI で確認。
   docs のリンク先は `/dashboard/{org}/products/checkout-links`）。
   - **まず既存 link を探す:** 製品登録時（2026-07-18）にこの製品の Checkout Link が
     既に作られていれば、**それをコピーして流用**する（新規作成不要）。無ければ次へ。
2. **New Link** を押す → 製品 **「Filmtone for DaVinci Resolve」** を選択。
3. **ローンチ価格 $39 の実現:** 手順 2 と同じフォームで、**登録済みの $10 固定額
   discount を link に preset（自動適用）**する（新規クーポン作成ではなく既存を
   選択）。preset すると顧客はコード入力なしで $39 が表示される。
4. 保存後、生成された **Checkout Link の URL をコピー**（「コピー」操作の正確な位置
   は現行 UI で確認）。
   - 期待されるホストは `buy.polar.sh/polar_cl_…` 形式。**手構築せず、ダッシュボード
     が表示する URL をそのままコピー**する（この形式は検索インデックス由来で、
     ダッシュボード表示が正）。
   - **session URL（短命）ではなく Checkout Link URL（長命）**を使う。docs が明示的に
     警告している。
5. この URL を **§1.2 の `NEXT_PUBLIC_FILMTONE_RESOLVE_POLAR_CHECKOUT_URL`** に設定し、
   **§1.4 で再デプロイ**。

#### ローンチ終了（30 日後）の扱い

- **同じ Checkout Link の discount preset を外すだけ**でよい（$49 に戻る）。
- **URL は変わらない**ので、**env の変更も再デプロイも不要**（link 編集で URL が
  保持されることを現行 UI で確認）。
- 製品ページ側の表示ローンチ価格（コードの `filmtoneResolveLaunchWindowDays = 30`）と
  Polar の discount は**独立管理**。ローンチ終了時は**両方を揃えて**終了させる
  （片方だけ残すと表示と実売価格がずれる）。

### 2.2 署名済み .pkg を File Downloads benefit に載せる

**対象ファイル:** `apps/filmtone-resolve-ofx/build/Filmtone-0.1.0.pkg`
（**231,353 bytes**、SHA-256 `529e822d12eec97d06d352845108fd87ba9ad00cd06c2b6ccfd6a733ca062bc2`）。

> このファイルは progress.md 改訂 25 の通り **local `main` の untracked `build/`
> にのみ存在**（この worktree にはない）。手元に無い場合は owner keychain で
> `apps/filmtone-resolve-ofx/Scripts/package.sh` を再実行して再生成（署名 +
> notarize + staple を含む）。

1. Polar ダッシュボード → **Benefits** → **「+ Add Benefit」**。
2. **Type = 「File Downloads」** を選択。
3. dropzone（"Feed me some bytes" と表示される領域）に pkg をドラッグ、または
   クリックしてファイル選択でアップロード。
4. **アップロード後、per-file メニュー（… / ドット）の「Copy SHA-256 Checksum」**で
   checksum を取得し、
   `529e822d12eec97d06d352845108fd87ba9ad00cd06c2b6ccfd6a733ca062bc2`
   と**一致することを確認**（改竄・アップロード破損の integrity gate）。
5. この benefit を製品 **「Filmtone for DaVinci Resolve」に attach**（製品編集フォーム
   内で有効化、または Benefits 側から接続。正確なコントロールは現行 UI で確認）。

- **上限:** 10GB/file（231KB は余裕）。ファイル種別制限なし（`.pkg` OK）。
- **買い手の受け取り:** 購入 → 確認メール内の **Customer Portal リンク** → 購入時
  メールアドレスで認証（ワンタイムコード）→ portal から**署名付き個別 URL**で DL。
- **バージョン更新:** versioning 機能は無い。新 build 配布時は**同 benefit に新ファイル
  を add**（既存購入者へ retroactive 付与）し、**旧を disable**。過去購入者に残すなら
  **旧を delete しない**（delete すると既存購入者もアクセスを失う）。

### 2.3 購入メール文面の配置（Custom Benefit の Private note）

**重要な事実:** Polar の**自動確認メール（order confirmation）テンプレート自体は
編集不可**。件名・本文・装飾を変える UI は organization / email / per-product の
いずれにも無い（docs: `polar.sh/docs/features/orders`）。Receipt / Invoice PDF にも
自由記述欄は無い。

**サポートされる唯一の差し込み手段:** 製品に **Custom Benefit（Type: Custom）**を
追加し、その **Private note（Markdown）**に文面を書く。Private note は
**「checkout success page + 購入確認メール + Customer Portal」の 3 か所**に
レンダリングされる（docs: `polar.sh/docs/features/benefits/custom`）。これが今回の
「24h 以内発行 / trial 使用済みは優先再発行」note の置き場所。

- **フィールドの使い分け（重要）:** `Description` は**購入前**（product / checkout
  ページ）に露出する顧客向けタイトル。ここには**短い見出しだけ**にし、実文面は
  **Private note**（購入後のみ表示）に入れる。全文を Description に入れると checkout
  ページに露出する。

#### 手順

1. Polar ダッシュボード → **Benefits** → **「+ Add Benefit」** → **Type = Custom**。
2. **Description**（任意・短い見出しのみ。例:「ライセンス配信と再発行について」）。
3. **Private note（Markdown）**に下記 JA / EN を貼り付け。
4. この Custom Benefit を製品「Filmtone for DaVinci Resolve」に **attach**
   （製品は File Downloads + Custom の **2 benefit** を持つ状態になる）。

#### 貼り付ける文面（progress.md 改訂 26 verbatim）

JA:

```text
full ライセンスは購入確認後 24 時間以内(通常は数時間以内)にメールでお届けします。待ち時間なしで使い始める場合は、14 日 trial をご利用ください。trial 使用済みの場合は、この購入メールへ返信いただければ優先して発行します。
```

EN:

```text
Your full license will be emailed within 24 hours of purchase confirmation (normally within a few hours). To start immediately, use the 14-day trial. If you have already used the trial, reply to this purchase email for priority full-license issue.
```

> 上記は改訂 26 ログの**逐語**（ASCII スペース・半角括弧のまま）。句読点を整えた
> 正規化版が [license-delivery-support.md](license-delivery-support.md) の
> §"Required purchase-email copy" にある。**実送信にはそちらの正規化版を使ってもよい**
> （文意は同一）。

#### 検証ステップ（crux・強く推奨）

「Private note が**確認メール本文**に実際に出る」ことは docs 1 文が根拠で、ライブ未
確認。**1 回テスト購入**して、**確認メール本文・checkout success page・Customer
Portal の 3 か所**に文面が出ることを確認する。仮にメール描画が docs と異なっても、
**success page と Customer Portal には確実に表示される**ため、文面自体は購入者に届く。

> 注意: Polar の **sandbox は本番と別 org** で走るため、本番製品の benefit 設定は
> テストされない。真に本番構成を確認するには、sandbox 側に同じ Custom Benefit を
> 複製するか、**本番で 1 回実購入 → 自己返金**（§2.4 の手動返金）で確かめる。

#### flag: 「この購入メールへ返信」の宛先

文面の「この購入メールへ返信」は、**Polar が送る transactional メールの reply-to が
`chiba@fores-tone.co.jp` に届くとは限らない**。テスト購入時に返信が実際に自分へ
届くか確認し、届かない場合は文面末尾に `chiba@fores-tone.co.jp` を明記する調整を
検討（本 runbook では指示通り逐語版を掲載）。

### 2.4 返金ポリシー（14 日）の扱い

**重要な事実:** Polar に「返金ポリシー / 返金期間」を設定する項目は**存在しない**
（docs: `polar.sh/docs/features/refunds`）。**14 日返金は Polar のトグルではなく、
こちらの約束として告知するもの。** 「Polar で 14 日を設定する」画面を探しても無い。

したがって「返金ポリシー同期」の実務は、**設定を入れることではなく、文面と運用を
齟齬なく揃えること**:

1. **製品 Description（Markdown・checkout ページ）に「購入日から 14 暦日以内は返金
   申請可」を明記**（購入前に見える唯一の owner 制御スロット）。文面は
   [refund-policy.md](refund-policy.md) と portfolio `/filmtone/resolve/refund`
   ページに揃える。
2. 必要なら §2.3 の Custom Benefit note（購入後）にも併記。
3. **返金の実行（手動）:** ダッシュボード → 対象 order → **Refunds** セクション →
   **「Refund order」**（全額が既定、金額を下げれば partial）。**顧客セルフサービス
   返金は無い**ので、`chiba@fores-tone.co.jp` に注文番号付きで申請を受け → 手動で返金。
4. **認識しておくこと:** Polar は MoR として、購入後 **60 日以内**は自社裁量で
   **proactive refund** を行う場合がある（chargeback 防止等。"no refunds" でも適用・
   opt-out 不可）。14 日はこちらの上乗せの約束で、Polar のベースラインとは別枠。
5. **one-time 購入の返金:** `revoke_benefits` が既定 **ON**（File Downloads /
   ライセンスを剥奪）。税は比例返金されるが、**決済処理手数料は返金されない**。

---

## 3. 最終チェックリスト

### Vercel

- [ ] `NEXT_PUBLIC_FILMTONE_RESOLVE_TURNSTILE_SITE_KEY` を **Production** に設定
      （値 = 1Password「Filmtone Production」の `TURNSTILE_SITE_KEY`）
- [ ] `NEXT_PUBLIC_FILMTONE_RESOLVE_POLAR_CHECKOUT_URL` を **Production** に設定
      （値 = §2.1 の Checkout Link URL）
- [ ] `NEXT_PUBLIC_FILMTONE_RESOLVE_PKG_DOWNLOAD_URL` を判断（trial 導線を使うなら
      公開 pkg URL を設定 / 使わないなら空）
- [ ] `NEXT_PUBLIC_FILMTONE_RESOLVE_TRIAL_ENDPOINT` は空のまま（既定 = 本番 Worker）
- [ ] （GitHub Actions 経路なら）portfolio の `/filmtone/resolve` 差分を main へ
      commit/push 済み
- [ ] **再デプロイを実行**（経路 A: Actions「Vercel Production Deploy」/ 経路 B:
      root で `bunx vercel deploy --prod --yes`）。ダッシュボード「Redeploy」単独は不可
- [ ] `/filmtone/resolve` で購入 CTA 有効化 + trial フォームの Turnstile 表示を確認

### Polar

- [ ] 既存製品「Filmtone for DaVinci Resolve」の **Checkout Link** を作成し URL を取得
- [ ] ローンチ用に **$10 固定 discount を同 link に preset**（$39 自動適用）
- [ ] File Downloads benefit を作成し `Filmtone-0.1.0.pkg` をアップロード
- [ ] アップロード後 **SHA-256 が `529e822d…062bc2` と一致**することを確認
- [ ] File Downloads benefit を製品に attach
- [ ] **Custom Benefit** を作成し **Private note に §2.3 の購入メール文面**を貼付
- [ ] Custom Benefit を製品に attach（製品が benefit 2 個を持つ状態）
- [ ] 製品 Description に **14 日返金**を明記（refund-policy.md と揃える）
- [ ] （推奨）test / sandbox 購入で **確認メール・success page・portal に文面が出る**
      ことと、**返信が自分に届く**ことを確認
- [ ] ローンチ終了時の段取り（30 日後に discount preset を外す。URL 不変・再デプロイ
      不要）をカレンダー登録

---

## 4. 未確認事項 / ライブ UI で要検証

Polar docs で**確認できた事実**と、**ダッシュボード UI で最終確認が必要な点**を分離
しておく。

| 項目 | 状態 |
|---|---|
| 確認メールのテンプレート編集 | **不可**（docs 確認済み）。差し込みは Custom Benefit の Private note のみ |
| Private note が**確認メール本文**に出るか | docs 1 文が根拠。**test 購入で要確認**（success page / portal には確実に出る） |
| 返金ポリシーの設定項目 | Polar に**存在しない**（docs 確認済み）。告知は製品 Description、返金は手動 |
| `buy.polar.sh/polar_cl_…` の URL 形式 | 検索インデックス由来。**ダッシュボード表示の URL をそのまま使う** |
| Checkout Links のダッシュボード位置・「コピー」操作・link 編集での URL 保持 | **現行 UI で要確認** |
| benefit を製品に attach する正確なコントロール | **現行 UI で要確認**（製品編集フォーム or Benefits から接続、は docs 確認済み） |
| 「この購入メールへ返信」の reply-to | Polar の transactional メールが `chiba@fores-tone.co.jp` に届くか**要確認** |
| `PKG_DOWNLOAD_URL`（trial 経路） | コード上 optional だが **trial には実質必須**。trial 利用者は Worker から `.license` のみ受領し、pkg 入手経路が他にない（Polar のファイルは購入者限定）。公開ホスト設置 or 別配布方法の **owner 判断**が必要 |
| pkg 実体の所在 | local `main` の untracked `build/` のみ。無ければ `Scripts/package.sh` を owner keychain で再実行して再生成 |

### 参照した Polar docs

- `polar.sh/docs/features/checkout/links`（Checkout Link・discount preset）
- `polar.sh/docs/features/benefits/file-downloads`（File Downloads・10GB 上限・checksum）
- `polar.sh/docs/features/benefits/custom`（Custom Benefit の Private note = 確認メール
  + success page + portal）
- `polar.sh/docs/features/benefits/introduction`（benefit を製品へ attach）
- `polar.sh/docs/features/customer-portal/introduction`（買い手のファイル受領導線）
- `polar.sh/docs/features/refunds`（返金設定は無い・手動発行・60 日 proactive）
- `polar.sh/docs/features/orders` / `polar.sh/features/merchant-of-record`

> `polar.sh/docs/guides/automate-post-purchase-link-sharing` は検索に出るが現在
> **404**。Private note の正本は `polar.sh/docs/features/benefits/custom`。
