# Filmtone — Documentation

Filmtone の現在の正本、運用ルール、歴史記録への入口。
この索引に固定した release / App Store / version 状態は置かない。現在状態は
`filmtone-release-version-sources.md` の truth scripts で確認する。
パッケージ単位の SSoT (terminology / LUT / preset versioning) は
`packages/film-lab-core/docs/` にある。

## ディレクトリ構成

| サブディレクトリ | 内容 |
|---|---|
| [`desktop/`](./desktop/) | Desktop / Native Desktop v2 リリース・QA・実装 handoff |
| [`ios/`](./ios/) | iOS (Capacitor + SwiftUI) docs index and archive |
| [`web/`](./web/) | Web support / LP copy docs index and archive |
| [`documentation-governance/`](./documentation-governance/) | 横断ドキュメントの情報設計・整理作業の計画と進行書 |

## Documentation Governance

- 長期の整理方針と運用規則:
  [`documentation-governance/strategy.md`](./documentation-governance/strategy.md)
- 現在の作業: なし。完了記録は
  [`documentation-governance/archive/`](./documentation-governance/archive/) を参照。
- 全文書の役割・所有領域・現在性:
  [`documentation-governance/inventory.md`](./documentation-governance/inventory.md)

## ルートの cross-cutting docs

| ファイル | 用途 |
|---|---|
| [`filmtone-copy-quality-harness.md`](./filmtone-copy-quality-harness.md) | Copy quality harness |
| [`filmtone-copy-context-sync.md`](./filmtone-copy-context-sync.md) | Implementation changes と copy / history claim の同期ルール |
| [`filmtone-implementation-history.md`](./filmtone-implementation-history.md) | WebGPU / WebGL → React + Capacitor → native SwiftUI / AVFoundation の実装経緯 |
| [`filmtone-release-version-sources.md`](./filmtone-release-version-sources.md) | Filmtone release version の正本ソース一覧 |
| [`web/filmtone-lp-copy-handoff-2026-05-05-jst.md`](./web/filmtone-lp-copy-handoff-2026-05-05-jst.md) | LP copy discussion handoff; do not implement portfolio LP copy from this without a fresh copy decision |
| [`archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/`](./archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/) | Older cross-cutting handoffs retained as evidence |

## Desktop

| ファイル | 内容 |
|---|---|
| [`desktop/README.md`](./desktop/README.md) | Desktop docs index and current routing |
| [`desktop/native-desktop-v2/strategy.md`](./desktop/native-desktop-v2/strategy.md) | Native Desktop v2 current strategy |
| [`desktop/archive/`](./desktop/archive/) | Legacy Electron を含む過去の Desktop handoff |

## iOS

| ファイル | 内容 |
|---|---|
| [`ios/README.md`](./ios/README.md) | iOS docs index and truth gate |
| [`../apps/capacitor-film-lab-ios/CLAUDE.md`](../../apps/capacitor-film-lab-ios/CLAUDE.md) | iOS implementation guide |
| [`ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/`](./ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/) | Older iOS handoffs and v1.1 task specs retained as evidence |

## Web

| ファイル | 内容 |
|---|---|
| [`web/README.md`](./web/README.md) | Web docs index |
| [`web/filmtone-lp-copy-handoff-2026-05-05-jst.md`](./web/filmtone-lp-copy-handoff-2026-05-05-jst.md) | LP copy discussion handoff |
| [`web/archive/`](./web/archive/) | Older Support / Privacy deploy handoff |
