# Filmtone Desktop — 署名・Notarization Runbook

> 対象: macOS (Apple Silicon) / Developer ID Application 署名 + Apple notarization
> 最終確認: 2026-03-31 / v0.1.3 で署名・公証・配布成功

## 1. 前提条件

- [ ] Apple Developer Program メンバーシップ（有効期限内）
- [ ] 1Password アクセス（署名関連の vault）
- [ ] Xcode Command Line Tools インストール済み
  ```bash
  xcode-select --install
  ```

## 2. 秘密情報の保管場所マップ

| 情報 | 保管先 | repo に置くか |
|------|--------|:---:|
| Apple ID | 1Password → `.notary.env` | NO |
| App-specific password | 1Password → `.notary.env` | NO |
| Team ID | 1Password → `.notary.env` | NO |
| Developer ID Application 証明書 (.cer) | Apple Developer Portal（再DL 可） | NO |
| 秘密鍵 / .p12 | **1Password** | **絶対 NO** |
| CSR (.certSigningRequest) | 保管不要（再生成可） | NO |
| entitlements plist | `build/` にコミット済み | YES |
| `.notary.env.example` | テンプレート | YES |

## 3. 新しい Mac でゼロから署名環境を構築する

### 3-1. 証明書のインストール

**方法 A: 1Password から .p12 をインポート（推奨・最速）**

```bash
# 1. 1Password から .p12 ファイルをダウンロード（一時的に ~/Downloads へ）
# 2. Keychain にインポート
security import ~/Downloads/developer-id-application.p12 \
  -k ~/Library/Keychains/login.keychain-db \
  -T /usr/bin/codesign \
  -T /usr/bin/security

# 3. 検証
security find-identity -v -p codesigning
# → "Developer ID Application: {あなたの名前} (TEAM_ID)" が表示されること

# 4. ダウンロードした .p12 を削除（Downloads に放置しない）
rm ~/Downloads/developer-id-application.p12
```

**方法 B: 証明書を新規発行する場合（.p12 を紛失した / 初回発行）**

```bash
# 1. CSR を生成
#    Keychain Access.app → Certificate Assistant → Request a Certificate...
#    - User Email: Apple ID のメールアドレス
#    - Common Name: あなたの名前
#    - Saved to disk にチェック

# 2. Apple Developer Portal で証明書を発行
#    https://developer.apple.com/account/resources/certificates/add
#    → Developer ID Application を選択
#    → CSR をアップロード
#    → .cer をダウンロード

# 3. .cer をダブルクリックして Keychain にインストール

# 4. 検証
security find-identity -v -p codesigning

# 5. 秘密鍵を .p12 としてエクスポートして 1Password に保管
#    Keychain Access.app → 証明書を右クリック → Export...
#    → .p12 形式で保存 → パスワード設定 → 1Password に保管
#    → ローカルの .p12 / .cer / .csr を削除
```

### 3-2. .notary.env の設定

```bash
cd apps/desktop-film-lab-batch

# テンプレートからコピー
cp .notary.env.example .notary.env

# 1Password の値で埋める
# APPLE_ID="your-apple-id@example.com"
# APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
# APPLE_TEAM_ID="XXXXXXXXXX"
```

App-specific password の生成場所: https://appleid.apple.com/account/manage → Sign-In and Security → App-Specific Passwords

**検証:**
```bash
source .notary.env && echo "APPLE_ID=$APPLE_ID TEAM_ID=$APPLE_TEAM_ID"
# → 値が表示されること（パスワードは表示しない）
```

### 3-3. 署名 + Notarization テスト

```bash
cd apps/desktop-film-lab-batch

# .notary.env を読み込んでからビルド
source .notary.env
bun run dist:mac:release

# → electron-builder が Keychain から証明書を自動検出して署名
# → afterSign hook (scripts/notarize.mjs) が Apple に提出
# → 公証完了まで数分待つ
```

**検証コマンド:**
```bash
# 署名の検証
codesign --verify --deep --strict release/mac-arm64/Filmtone.app
# → "valid on disk" が出れば OK

# Gatekeeper 検証
spctl --assess --type exec release/mac-arm64/Filmtone.app
# → "accepted" が出れば OK

# Staple（notarization チケットの埋め込み）
bun run release:staple
# → scripts/staple-mac.mjs が staple + validate を実行
```

## 4. リリースフロー（通常）

署名環境が構築済みの状態での通常リリース手順:

```bash
cd apps/desktop-film-lab-batch
source .notary.env

# 1. ビルド + 署名 + 公証
bun run dist:mac:release

# 2. Staple
bun run release:staple

# 3. チェックサム生成
bun run release:checksums

# 4. Vercel Blob にアップロード
bun run release:upload-blob
bun run release:upload-update-meta
```

## 5. トラブルシューティング

### 「開発元を確認できません」(Gatekeeper 警告)
- **原因:** notarization が失敗した / staple を忘れた
- **対処:**
  1. `xcrun notarytool log <submission-id>` でログ確認
  2. `bun run release:staple` で再 staple
  3. DMG を再作成（staple は .app に対して行うため、DMG 再パッケージが必要）

### `security find-identity` に証明書が出ない
- **原因:** Keychain にインポートされていない / 秘密鍵がない
- **対処:** §3-1 の方法 A or B でインストールし直す

### `CSC_IDENTITY_AUTO_DISCOVERY` で証明書が見つからない
- **原因:** Keychain のアクセス制御で codesign にアクセス許可されていない
- **対処:**
  ```bash
  # Keychain Access.app → 証明書の秘密鍵 → Access Control
  # → "Allow all applications to access this item" にチェック
  # または codesign を明示的に追加
  ```

### notarization がタイムアウト / エラー
- **原因:** Apple サーバー側の問題 / entitlements 不正
- **対処:**
  1. Apple Developer System Status を確認: https://developer.apple.com/system-status/
  2. entitlements を確認: `codesign -d --entitlements :- release/mac-arm64/Filmtone.app`
  3. リトライ: `bun run dist:mac:release`

### unsigned ビルドを作りたい（開発中）
```bash
bun run dist:mac:unsigned
# → FILM_LAB_DESKTOP_SKIP_NOTARIZE=true CSC_IDENTITY_AUTO_DISCOVERY=false で実行
```

## 6. 証明書ライフサイクル

- **Developer ID Application 証明書の有効期限:** 発行日から **5 年**
- **更新手順:** Apple Developer Portal → Certificates → 新規 CSR → 発行 → .p12 export → 1Password 更新
- **カレンダーリマインダー:** 期限 **1 ヶ月前**に設定すること
- **revoke した場合:** 既に署名済みのアプリは影響なし。新規署名に新しい証明書が必要

## 7. repo に置いてはいけないファイル

以下は `apps/desktop-film-lab-batch/.gitignore` で除外済み:

| パターン | 内容 |
|---------|------|
| `.notary.env` | Apple 認証情報 |
| `*.p12` | 秘密鍵を含む証明書バンドル |
| `*.cer` | 証明書ファイル |
| `*.key` | 秘密鍵 |
| `*.csr` / `*.certSigningRequest` | 証明書署名要求 |
| `*.provisionprofile` | プロビジョニングプロファイル |

## 8. 参考: notarize.mjs の認証モード

現在 **Apple ID モード**を使用中。将来 CI/CD を導入する場合は **API Key モード**に切り替え可能（コード変更不要）。

| モード | 環境変数 | 用途 |
|--------|---------|------|
| Apple ID | `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID` | ローカル開発（現在使用中） |
| API Key | `APPLE_API_KEY`(ファイルパス), `APPLE_API_KEY_ID`, `APPLE_API_ISSUER` | CI/CD 向け（将来用） |
