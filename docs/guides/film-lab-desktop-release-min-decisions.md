# Desktop リリース — 判断最小（短縮版）

**固定**: Vercel Blob · pathname はスクリプト任せ · Smart Look 載せない · public repo 前提にしない。

---

## 初回（手動はこの 2 つだけ）

1. Vercel → `chibatakumi-portfolio-web` → **Storage** で Blob を **プロジェクトに接続**
2. リポジトリルートで `bunx vercel@50 env pull .env.local`（`BLOB_READ_WRITE_TOKEN` 確認）

公証: [film-lab-desktop-notarization-and-secrets.md](./film-lab-desktop-notarization-and-secrets.md)（`.notary.env`）

---

## 毎回（コピペ）

```bash
cd /path/to/chibatakumi-portfolio/apps/desktop-film-lab-batch
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
