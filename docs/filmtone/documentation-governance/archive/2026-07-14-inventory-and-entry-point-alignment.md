# Documentation Inventory And Entry-Point Alignment

## Completed

- `docs/` の 420 件の Markdown を、役割・所有領域・現在性で分類した。
- Filmtone 横断、iOS、Web、legacy guides の入口から、現在の正本と歴史記録を
  区別できるようにした。
- iOS の固定リリース状態を入口から外し、release truth script を唯一の確認経路に
  した。
- `.ai/GLOBAL.md` の正式 Desktop 定義を native macOS app に整合した。
- 既存の product lane、history、archive、未追跡のユーザー文書を移動・編集しなかった。

## Decision

孤立した dated handoff は分類済みの参照記録として当面は位置を維持する。移動が必要に
なった場合だけ、受け皿、参照元、リンクを同一の小作業で更新する。

## Known Exception

DaVinci Bridge は `active.md` を持つが strategy がない。現在の DB-M13 product lane と
衝突しないよう、このループでは正規化せず、lane owner の closeout に委ねる。

## Verification

テスト・検証コマンドは実行していない。リポジトリのグローバル必須ルールにより、
ユーザーから明示された場合以外は実行しない。
