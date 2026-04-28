# Filmtone — Documentation

Filmtone (Desktop / iOS / Web support) のリリース・実装 handoff ドキュメント。
パッケージ単位の SSoT (terminology / LUT / preset versioning) は `packages/film-lab-core/docs/` にある。

## ディレクトリ構成

| サブディレクトリ | 内容 |
|---|---|
| [`desktop/`](./desktop/) | Desktop (Electron) リリース・QA・実装 handoff |
| [`ios/`](./ios/) | iOS (Capacitor + SwiftUI) リリース・parity handoff |
| [`web/`](./web/) | Web support / privacy ページの deploy handoff |
| [`ios-v1.1-tasks/`](./ios-v1.1-tasks/) | iOS v1.1 task spec (T1〜T10) |

## ルートの cross-cutting docs

| ファイル | 用途 |
|---|---|
| [`filmtone-effect-terminology-alignment-handoff-2026-04-26-jst.md`](./filmtone-effect-terminology-alignment-handoff-2026-04-26-jst.md) | Effect terminology alignment chat handoff（SSoT は `packages/film-lab-core/docs/EFFECT_TERMINOLOGY_SSOT.md`） |
| [`filmtone-release-version-sources.md`](./filmtone-release-version-sources.md) | Filmtone release version の正本ソース一覧 |

## Desktop

| ファイル | 内容 |
|---|---|
| [`desktop/filmtone-desktop-v1.0.3-qa-handoff-2026-04-24-jst.md`](./desktop/filmtone-desktop-v1.0.3-qa-handoff-2026-04-24-jst.md) | Desktop v1.0.3 QA handoff |
| [`desktop/filmtone-desktop-export-parity-investigation-handoff-2026-04-25-jst.md`](./desktop/filmtone-desktop-export-parity-investigation-handoff-2026-04-25-jst.md) | Desktop export parity 調査 |
| [`desktop/filmtone-desktop-hdr-sdr-complete-implementation-handoff-2026-04-25-jst.md`](./desktop/filmtone-desktop-hdr-sdr-complete-implementation-handoff-2026-04-25-jst.md) | Desktop HDR/SDR 実装完了 |

## iOS

| ファイル | 内容 |
|---|---|
| [`ios/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md`](./ios/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md) | iOS v1.0 public release handoff |
| [`ios/filmtone-ios-parity-gap-vs-desktop-v1.0.3-2026-04-24-jst.md`](./ios/filmtone-ios-parity-gap-vs-desktop-v1.0.3-2026-04-24-jst.md) | iOS vs Desktop v1.0.3 gap 分析 |
| [`ios/filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`](./ios/filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md) | iOS v1.1 parity plan |
| [`ios/filmtone-ios-v1.1-release-handoff-2026-04-25-jst.md`](./ios/filmtone-ios-v1.1-release-handoff-2026-04-25-jst.md) | iOS v1.1 release handoff |

## Web

| ファイル | 内容 |
|---|---|
| [`web/filmtone-web-support-privacy-deploy-handoff-2026-04-20-0300-jst.md`](./web/filmtone-web-support-privacy-deploy-handoff-2026-04-20-0300-jst.md) | Filmtone iOS の Support / Privacy 公開ページを `chibatakumi.studio` にデプロイ |
