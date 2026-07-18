# Filmtone ライセンス発行ツール

仕様正本: `docs/filmtone/davinci-plugin/monetization/implementation-plan.md` §2 §4。
依存パッケージなし(Bun 内蔵 WebCrypto の Ed25519 のみ)。

ライセンスは envelope 形式: 署名は `payload`(base64)の**バイト列そのもの**に
対して行い、検証側は再 canonicalize せずに検証する。検証鍵は署名済みの
`kind`(full/trial)で内部選択されるため、trial 鍵で full を偽造できない。

## コマンド

```bash
# 鍵ペア生成(full + trial)。秘密鍵は repo 外・非 iCloud 領域に書かれる
bun run license:keygen            # 既定: ~/.filmtone/secrets/(0700)

# 購入ライセンス発行(full 鍵)
bun run license:issue -- --key ~/.filmtone/secrets/filmtone-full.key.json \
  --kind full --name "Taro Yamada" --email taro@example.com --order polar_ord_xxx \
  --out Filmtone.license

# trial 発行(通常は Worker が行う。手動フォールバック)
bun run license:issue -- --key ~/.filmtone/secrets/filmtone-trial.key.json \
  --kind trial --name "taro@example.com" --email taro@example.com --order trial-manual-0001

# 検証(kind に対応する鍵を渡す。両方渡せばどちらの kind も検証できる)
bun run license:verify -- --file Filmtone.license \
  --full-key ~/.filmtone/secrets/filmtone-full.key.json \
  --trial-key ~/.filmtone/secrets/filmtone-trial.key.json
# exit 0 = 有効 / 2 = 署名は正しいが期限切れ / 1 = 無効
```

購入者への案内: `Filmtone.license` を
`~/Library/Application Support/Filmtone/Filmtone.license` に置き、
Resolve でフレームを再レンダーするとウォーターマークが消える。

## 鍵の規律

- 既定の保管場所は `~/.filmtone/secrets/`。**`~/Documents` に置かない**
  (macOS の「デスクトップと書類」iCloud 同期の対象になるため)。
- `filmtone-full.key.json` は**オーナーの Mac と 1Password 以外に置かない**。
  Worker・クラウド・repo に持ち込まない(implementation-plan §2 の 2 鍵構成)。
- `filmtone-trial.key.json` の `privateKeyPkcs8Hex` だけを
  `wrangler secret put TRIAL_PRIVATE_KEY` で Worker に登録する。
- 生成直後に両 `.key.json` を 1Password へ保存する。
- `PublicKeys.h.snippet`(公開鍵のみ)は MON-2 で
  `apps/filmtone-resolve-ofx/Sources/License/PublicKeys.h` へ転記する。

## ローテーション / インシデント手順

プラグインは kind ごとに**公開鍵リスト**を持てる(実装は MON-2)。前提が
異なる 2 つのケースを区別する:

1. **予防的ローテーション(漏洩していない)**
   - 旧鍵ファイルを `*.key.json.retired-YYYYMMDD` にリネームし `keygen` 再実行。
   - full: 新旧両方の公開鍵をプラグインに載せたまま維持(発行済み購入
     ライセンスを無効化しない)。以後の発行は新鍵で行う。
   - trial: 新旧を **31 日以上併載**してから旧 trial 公開鍵を削除(有効期間中の
     trial を失効させない)。Worker の `TRIAL_PRIVATE_KEY` を新鍵に更新。
2. **full 鍵漏洩(インシデント)**
   - 旧 full 公開鍵を**削除**したアップデートを配布する(偽造を止める唯一の
     手段。正規購入者も旧署名では開けなくなる)。
   - Polar の注文記録から全購入者へ新鍵で再発行し、サポート窓口を案内する。
   - 漏洩日時・対応をこの README に追記する。
