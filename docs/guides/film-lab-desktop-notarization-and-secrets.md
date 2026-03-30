# Desktop 公証 — 1Password & コピペ（短縮版）

**方針**: Apple ID 方式だけ。シークレットは **1Password**、作業は **`.notary.env` + 下のコマンド**。git に載せない。

---

## 1Password（Secure Note 推奨）

| 保存名 | 中身 |
|--------|------|
| `APPLE_ID` | Developer ログインのメール |
| `APPLE_APP_SPECIFIC_PASSWORD` | [appleid.apple.com](https://appleid.apple.com) → アプリ用パスワード |
| `APPLE_TEAM_ID` | 10 文字の Team ID |

任意（別 Note 可）: `BLOB_READ_WRITE_TOKEN` · `FILM_LAB_DESKTOP_DOWNLOAD_URL`

---

## `apps/desktop-film-lab-batch/.notary.env`

**エージェントができること**: テンプレ `.notary.env` / 正本 `.notary.env.example` を置く（中身は **REPLACE_ME のみ**。秘密は入れない）。  
**あなただけができること**: `.notary.env` の `REPLACE_ME` を 1Password の値に置換。

- 既に `apps/desktop-film-lab-batch/.notary.env` がある → **エディタで 3 か所だけ編集**して保存。
- 無い／消した → `cp .notary.env.example .notary.env` → 編集。  
- `.notary.env` は **gitignore**（コミット禁止）。`.notary.env.example` は **コミット可**（秘密なし）。

`source` で失敗する場合は **`cd` が `desktop-film-lab-batch` か**確認。

---

## ビルド

パスだけ自分の環境に合わせる。

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch
set -a && source .notary.env && set +a && bun run dist:mac:release
bun run release:staple
bun run release:checksums
```

**前提**: キーチェーンに `Developer ID Application` が valid（`security find-identity -v -p codesigning`）。

**API Key 方式**を使うときだけ: `scripts/notarize.mjs` の env 名に合わせる（日常は上で十分）。
