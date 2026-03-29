# Film Lab Desktop（Electron）

**メインの利用場所はこの Desktop アプリ**です。スマートルックは同リポの `apps/web` の **共有 BFF**（Next API）へ HTTP でつなぎます。

## 「dev」という言葉について

- **バックエンド（Next）**の `bff:local` は、要するに **自分 PC 上で BFF を一時起動する**コマンドの業界標準的な名前です（中身は `next dev`）。**Web アプリ本体を優先している意味ではありません。**
- **Film Lab Desktop**の入口は **`bun run desktop`** です。ローカルでは Vite がレンダラの更新用 URL を立て、Electron の環境変数 **`FILM_LAB_DESKTOP_RENDERER_URL`** でその URL を開きます（旧名 `VITE_DEV_SERVER_URL` もそのまま使えます）。「dev」という語はスクリプト互換用に **`dev` → `desktop` のエイリアス**だけ残しています。

## いちばん手短（BFF も一緒に起動）

`apps/desktop-film-lab-batch` で:

```bash
bun run desktop:with-bff
```

1. `apps/web` で `bff:local`（ポート 3000 前後）
2. 3000 が応答したら `desktop`（Vite 5173 + Electron）

**前提:** `apps/web/.env.local` に BFF 用の秘密情報（寄付署名・スマートルック用キーなど）が入っていること。これだけはサーバー側の都合で省略できません。

## Desktop だけ（BFF はもう動いているとき）

```bash
bun run desktop
```

## パッケージ済みレンダラだけ（Vite なし）

```bash
bun run start
```

## `.env`（Desktop）

オプション。未設定でも `vite.config` 側の既定で `http://127.0.0.1:3000` へ向く構成にできます。`.env.example` 参照。

## ビルド

```bash
bun run build
```

## 動画出力（バッチタブ）

バッチタブ下部の **「動画を書き出す」** が利用できます。入力は最大 **3840×2160・900 秒**、出力は最大 **1920×1080・24fps**（アップスケールなし）。バッチ用ルック（プリセット / JSON）がそのまま適用されます。**既定は高速 ffmpeg（近似）** です。編集タブのプレビューにより近い逐次処理が必要なときだけ、手順内のチェックで **WebGL** をオンにしてください。

**必須:** マシンの `PATH` 上に **`ffmpeg`** と **`ffprobe`** があること（例: `brew install ffmpeg`）。macOS では H.264 エンコードに **VideoToolbox** を優先します。
