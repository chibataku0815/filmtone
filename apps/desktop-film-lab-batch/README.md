# Filmtone Desktop

Filmtone Desktop は、Filmtone の **macOS 向けローカル書き出しアプリ**です。写真フォルダの一括処理と、動画 1 本の MP4 書き出しを Desktop 上で行います。

## 公開版の固定事項

- **固定ダウンロード URL:** `https://www.chibatakumi.studio/film-lab/download`
- **対応 OS:** macOS のみ
- **最小 macOS:** `11.0+`
- **対応アーキ:** Apple Silicon (`arm64`) のみ
- **正規配布物:** 署名・公証済み `DMG`
- **更新方針:** バックグラウンドでの自動インストールはありません。**差し替えは常に DMG 手動取得**（ダウンロードページ / release notes）。起動後・24 時間ごとに、公開 JSON へ問い合わせて**新しい版の通知**だけ出すことがあります（`FILM_LAB_DESKTOP_UPDATE_CHECK_URL` がビルドに埋め込まれているときのみ）。
- **窓口（Filmtone Desktop）:** `chiba@fores-tone.co.jp`

> `https://www.chibatakumi.studio/film-lab/download` は固定導線です。公開アセットが接続されているときは現行ビルドへリダイレクトし、未公開時は案内ページを表示します。

## ダウンロード前に伝えること

- **版差分とチェックサムの正本**は、そのビルドの **release notes** です。
- **LUT（3D LUT）** はプレビューからバッチへ **自動コピーしません**。同期するのは数値 `Params` のみです。最終確認は必ず出力ファイルで行ってください。
- **寄付 / 共有** は Desktop 版ではオフです。Web との差分の全体は release notes を正とします。
- **スマートルック AI** は、この Desktop リリースには含めません。
- **動画書き出し**には `ffmpeg` / `ffprobe` が `PATH` 上に必要です。

## リリース用コマンド

- `bun run pack:mac` - Apple Silicon 向けの unsigned `.app` をローカル確認用に生成します。
- `bun run dist:mac` - Apple Silicon 向けの unsigned `DMG` を生成します（配布前の形確認用）。
- `bun run dist:mac:release` - 署名 + notarization 前提の本番ビルドを生成します。
- `bun run release:staple` - 公証済みの **`release/mac-arm64/<製品名>.app`** に staple / validate（DMG ではなく .app 向け）。
- `bun run release:checksums` - `release/SHA256SUMS.txt` を生成します。
- `bun run release:upload-blob` - `release/film-lab-<version>-arm64.dmg` を **Vercel Blob** に載せます（要 `BLOB_READ_WRITE_TOKEN`）。`-- --sync-vercel-env` で `FILM_LAB_DESKTOP_DOWNLOAD_URL` を production に同期。
- `bun run release:upload-update-meta` - 更新案内用の **`update-meta.json`**（固定 pathname）を Blob に載せます。`-- --sync-vercel-env` で `FILM_LAB_DESKTOP_UPDATE_CHECK_URL` を production に同期。任意で `--download-page` / `--release-notes-url`。その後 **`FILM_LAB_DESKTOP_UPDATE_CHECK_URL` を付けて `bun run build`** すると、パッケージにチェック用 URL が埋め込まれます（`scripts/build-electron.mjs` の define）。

### リリース・公証（コピペは短縮ガイドのみ）

- [リリース列](../../docs/guides/film-lab-desktop-release-min-decisions.md) · [公証・1Password・`.notary.env`](../../docs/guides/film-lab-desktop-notarization-and-secrets.md)

ローカルの unsigned build では、`FILM_LAB_DESKTOP_SKIP_NOTARIZE=true` と `CSC_IDENTITY_AUTO_DISCOVERY=false` を使います。

## 開発用のスマートルック注記

公開版には含めませんが、開発中の検証として `desktop:with-bff` は残しています。これは `apps/web` のローカル BFF と一緒に Desktop を立ち上げるための **開発専用** 経路です。

## 「dev」という言葉について

- `bff:local` は **自分の Mac 上で BFF を一時起動する**ための一般的な名前です。Web を優先する意味ではありません。
- Filmtone Desktop の入口は **`bun run desktop`** です。ローカルでは Vite がレンダラ更新用 URL を立て、Electron の環境変数 `FILM_LAB_DESKTOP_RENDERER_URL` でその URL を開きます。
- `dev` はスクリプト互換のために **`desktop` のエイリアス**として残しています。

## いちばん手短（開発用 BFF も一緒に起動）

`apps/desktop-film-lab-batch` で:

```bash
bun run desktop:with-bff
```

1. `apps/web` で `bff:local`（ポート 3000 前後）
2. 3000 が応答したら `desktop`（Vite 5173 + Electron）

**前提:** `apps/web/.env.local` に BFF 用の秘密情報（寄付署名・スマートルック検証用キーなど）が入っていること。

## Desktop だけ（BFF は既に動いているとき）

```bash
bun run desktop
```

## パッケージ済みレンダラだけ（Vite なし）

```bash
bun run start
```

## `.env`（Desktop）

オプションです。未設定でも `vite.config` 側の既定で `http://127.0.0.1:3000` を向けます。`.env.example` を参照してください。

## ビルド

```bash
bun run build
```

## 動画出力（バッチタブ）

バッチタブ下部の **「動画を書き出す」** が利用できます。入力は最大 **3840×2160・900 秒**、出力は最大 **1920×1080・24fps**（アップスケールなし）です。バッチ用ルック（プリセット / JSON）がそのまま適用されます。動画は **編集タブに近い見え方** になるよう、**1 フレームずつグレードして MP4** にします。

**必須:** `PATH` 上に **`ffmpeg`** と **`ffprobe`** があること（例: `brew install ffmpeg`）。macOS では H.264 エンコードに **VideoToolbox** を優先します。
