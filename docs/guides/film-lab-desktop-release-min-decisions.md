# Desktop リリース — 判断最小（短縮版）

**固定**: Vercel Blob · pathname はスクリプト任せ · Smart Look 載せない · public repo 前提にしない。

---

## 初回（手動はこの 2 つだけ）

1. Vercel → `chibatakumi-portfolio-web` → **Storage** で Blob を **プロジェクトに接続**
2. リポジトリルートで `bunx vercel@50 env pull .env.local`（`BLOB_READ_WRITE_TOKEN` 確認）

公証: [film-lab-desktop-notarization-and-secrets.md](./film-lab-desktop-notarization-and-secrets.md)（`.notary.env`）

---

## Filmtone リネーム後・**初めて**配る DMG だけ（判断ほぼなし）

**既定**: `productName` は **Filmtone**、`appId` は **`com.chibatakumi.film-lab-desktop` のまま**（中身の識別子は変えない）。やることは下だけ。

1. **いつもの「毎回」コマンド列**をそのまま実行（このファイル §毎回）。
2. **`release:upload-blob -- --sync-vercel-env`** を入れているなら **そのまま** — スクリプトが **新しい DMG URL を Vercel に載せ替え**る（ここを手で選ぶ必要なし）。
3. **Web を prod に載せる** — `bunx vercel deploy` まで入れているならそれもそのまま（download ページが新 URL を読む）。
4. **Applications に古い `Film Lab.app` が残っていたら** — **どちらか一方だけ残す**（通常は新しい **Filmtone.app** を残し、古い方をゴミ箱。**迷ったらこれで固定**。同じ `appId` なので多くの環境では上書きに近い動きだが、名前変更で二重表示が出ることがある）。
5. **リリースノートに 1 行** — 「表示名を Filmtone に変更」（任意・10 秒）。

**やらなくていいこと（当面）**: DMG **ファイル名**にまだ `film-lab` が残っていても配布上は問題にしにくい。Blob の **pathname を変えたい**のは気が向いたらでよい。

---

## 毎回（コピペ）

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch
set -a && source .notary.env && set +a && bun run dist:mac:release
bun run release:staple
bun run release:checksums
bun run release:upload-blob -- --sync-vercel-env
cd /path/to/chibatakumi-portfolio && bunx vercel@50 deploy --prod --yes
```

**deploy は必ず monorepo ルート**（`.vercel` が `chibatakumi-portfolio-web` の階層）。`desktop-film-lab-batch` 直下で叩くと **別プロジェクト**ができて失敗する。

Git デプロイだけなら最後の行は不要。`--sync-vercel-env` も不要なら外す。

---

## 詰まったら

- Blob: Storage 未接続 → 接続 → `env pull`
- 公証: `.notary.env` と Developer ID 証明書
- URL: スクリプトが出す `env add` 一行を手動

**実装**: `scripts/upload-dmg-to-vercel-blob.mjs` · Web redirect `desktop-release-info.ts`
