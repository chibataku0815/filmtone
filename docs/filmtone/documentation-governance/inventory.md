# Filmtone Documentation Inventory

Snapshot: 2026-07-14 JST（2026-07-19 refresh: DaVinci OFX / spatial optics 波と
codemap-feature-audit lane を反映）

この表はファイルの移動台帳ではなく、どの情報を現在の正本として読めるかを決める
分類台帳である。履歴本文は当時の根拠として保持し、現在性は入口文書と truth gate
で判断する。

## Snapshot

| 対象 | 件数（2026-07-19） | 扱い |
|---|---:|---|
| `docs/**/*.md` | 450 | この台帳の対象 |
| `docs/filmtone/**/*.md` | 436 | Filmtone の主なドキュメント領域 |
| `**/archive/**/*.md` | 316 | 歴史記録。現在状態としては使わない |
| `**/paused/**/*.md` | 9 | 中断中の作業記録。再開時だけ読む |
| `strategy.md` | 13 | 長期のレーン正本 |
| `active.md` | 1 | 現在の作業（davinci-bridge DB-M13。codemap-feature-audit は監査完了で archive 済み） |

## Classification

| Path or pattern | Role | Owner | Current-use rule |
|---|---|---|---|
| `README.md`, `AGENTS.md`, `CLAUDE.md` | Repository entry / operating rules | Repository | 現在のルーティングと制約だけを置く。製品の固定状態は置かない。 |
| `.ai/GLOBAL.md`, `.ai/parallel-work.md` | AI execution rules | Repository | `AGENTS.md` と矛盾させない。製品実装の詳細正本にはしない。 |
| `docs/filmtone/README.md` | Filmtone documentation entry | Filmtone cross-cutting | Desktop、iOS、package、copy、release truth の入口だけを提供する。 |
| `docs/filmtone/filmtone-*.md` | Cross-cutting canonical rules | Filmtone cross-cutting | copy、history、release-source の正本。release の現在値は truth script で確認する。 |
| `docs/filmtone/documentation-governance/strategy.md` | Documentation strategy | Documentation governance | 本整理の長期方針と Completion Log。 |
| `docs/filmtone/documentation-governance/active.md` | Documentation progress sheet | Documentation governance | 現在の 1 作業だけ。完了時に archive へ移す。 |
| `docs/filmtone/desktop/README.md` | Desktop entry | Desktop | Native macOS app と Native Desktop v2 の現在導線。 |
| `docs/filmtone/desktop/native-desktop-v2/{strategy,active}.md` | Desktop lane plan / progress | Native Desktop v2 | 当該レーンの現在正本。`active.md` は存在するときだけ読む。 |
| `docs/filmtone/desktop/native-desktop-v2/*.md` | Lane reference or historical task record | Native Desktop v2 | strategy/active が優先。未追跡または進行中の記録は移動しない。 |
| `docs/filmtone/desktop/{release-cutover,mac-app-store-readiness}/` | Historical operational lane | Desktop release | 現在の release state ではない。現在性は life truth scripts で確認する。 |
| `docs/filmtone/desktop/archive/**` | Historical evidence | Desktop | 現在状態として使わない。 |
| `docs/filmtone/ios/README.md` | iOS entry | iOS | app guide、各 lane、truth gate への導線。固定版番号を現在状態として載せない。 |
| `docs/filmtone/ios/*/strategy.md` | iOS lane plan | Respective iOS lane | そのレーンの長期正本。 |
| `docs/filmtone/ios/*/{archive,paused}/**` | iOS historical or paused task record | Respective iOS lane | strategy と active がある場合はそれらを優先する。 |
| `docs/filmtone/ios/20??-??-??-*.md` | Historical release / handoff evidence | iOS | 現在の App Store・TestFlight・version state は truth script で確認する。 |
| `docs/filmtone/{detail-softness,export-audio,shadow-latitude}/strategy.md` | Feature lane plan | Respective feature lane | 長期の feature 正本。 |
| `docs/filmtone/{detail-softness,export-audio,shadow-latitude}/{archive,paused}/**` | Feature history | Respective feature lane | 現在の状態は strategy を優先する。 |
| `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md` | Source planning evidence | Detail Softness | strategy から参照する原計画。移動は参照更新を伴う別作業で行う。 |
| `docs/filmtone/2026-05-11-export-audio-investigation.md` | Investigation evidence | Export Audio | 完了済み restoration records の根拠。現在の export behavior は live source で確認する。 |
| `docs/filmtone/2026-05-12-{detail-softness-dedicated-prompt,export-audio-detail-softness-handoff,vision3-500t-blue-hour-preset-handoff}.md` | Historical handoff evidence | Respective feature / core | 現在の計画や catalog ではない。本文を改竄せず、将来の移動は参照更新と一緒に行う。 |
| `docs/filmtone/2026-07-07-native-desktop-ipad-restart-research.md` | Current research reference | Native Desktop / iPad | 現在の Native Desktop archive から参照される未追跡文書。移動・編集しない。 |
| `docs/filmtone/davinci-bridge/` | Active product lane | DaVinci Bridge | `active.md` が現在の作業記録。strategy 不在は lane owner の closeout で正規化する。 |
| `docs/filmtone/articles/` | Publishing policy and draft evidence | Article publishing | `README.md` の publishing rules が正本。各 article directory は下書き・根拠。 |
| `docs/filmtone/web/` | Portfolio handoff evidence | Portfolio / Filmtone boundary | public web の実装正本は portfolio。ここは handoff と境界の記録。 |
| `docs/filmtone/shared-highlight-markers/evidence/` | Feature evidence | Shared highlight markers | 現在の contract は source/package を優先する。 |
| `docs/filmtone/archive/**`, `docs/archive/**` | Archived cross-cutting evidence | Filmtone / repository | 現在状態として使わない。 |
| `docs/guides/**` | Pre-standalone legacy evidence | Repository history | life の guides と混同しない。このリポジトリで新規 current guide を置かない。 |
| `apps/filmtone-desktop-macos/{README.md,fastlane/README.md}` | Native Desktop operational docs | Native Desktop | app implementation と release operation の入口。 |
| `apps/capacitor-film-lab-ios/{CLAUDE.md,docs/**,fastlane/**/README.md}` | iOS implementation / operation docs | iOS | iOS 実装・source math・release asset の正本。 |
| `apps/desktop-film-lab-batch/{README.md,docs/**}` | Frozen legacy Electron evidence | Legacy Electron | legacy / rollback 依頼に限り読む。通常の Desktop 正本ではない。 |
| `packages/*/docs/**` | Package-specific specification | Respective package | package contract の正本。特に core の terminology、LUT、preset versioning を優先する。 |
| `apps/filmtone-resolve-ofx/{Makefile,Sources/**,Scripts/GenerateContracts/README.md}` | DaVinci Resolve OFX plugin 実装 | Resolve OFX / DaVinci plugin | 新規 app（2026-07 OFX 波）。設計・進行正本は `docs/filmtone/davinci-plugin/`。build は app 直下 `Makefile`（root に `verify:*` script なし = ドリフト所見）。`Sources/Generated` は生成物。 |
| `packages/film-lab-swift-core/**` | Shared Swift runtime core package | film-lab-swift-core | Swift payload の共有 runtime。`Sources/**/Generated/` は `bun run generate:ios-swift` 生成物で手編集しない。 |
| `packages/film-lab-codex-mcp/**` | MCP automation server package | film-lab-codex-mcp | Filmtone automation を MCP として公開。build/verify は root `verify:filmtone-mcp` / `filmtone:mcp`。 |
| `docs/filmtone/davinci-plugin/{strategy,progress,delegation}.md` + `workstreams/**` | Active product lane（OFX / spatial optics） | DaVinci plugin | resolve-ofx の設計・進行正本。live lane として本整理では本文を移動・改稿しない。索引追加のみ。 |
| `docs/filmtone/codemap-feature-audit/{strategy,active}.md` | Codemap / feature-matrix 監査 lane | Documentation governance | 本監査ループの計画・進行。完了後に active を archive へ。 |
| `docs/filmtone/filmtone-codemap.md` | Canonical code-structure map | Filmtone cross-cutting | 全 app/package の構造・責務・入口・生成境界・verify の SSOT。 |
| `docs/filmtone/filmtone-feature-matrix.md` | User-facing feature coverage matrix | Filmtone cross-cutting | 全機能網羅の目視検証用。機能の現行仕様は各 source を優先する。 |

## Maintenance Decision Table

| Situation | Action |
|---|---|
| 新しい現在の仕様または運用ルール | 所有領域の canonical document を更新し、索引にはリンクだけを追加する。 |
| 新しい短期作業 | レーンに `active.md` がなければ作成し、完了時に archive へ移す。 |
| 完了した調査・handoff | 所有領域の `archive/` に置く。本文の結論を現在状態として索引へ複写しない。 |
| release / App Store / version の主張 | life truth script を実行してから書く。公開状態とローカル候補を分ける。 |
| 古い文書の移動 | 受け皿、参照元、リンクを先に更新し、未追跡または進行中の文書は移動しない。 |
| 所有領域が不明 | `documentation-governance/active.md` に blocker として記録し、分類だけで止める。 |

## Known Exceptions

- DaVinci Bridge は `active.md` を持つが strategy がない。現在の DB-M13 作業と
  衝突するため、本整理では新しい strategy を作らない。DB-M13 `active.md` は
  2026-07-19 時点で全 checklist 完了・検証済みだが未アーカイブ。archive 判断は
  lane owner の closeout 領分で、本整理は所見提示のみ行う。
- `docs/filmtone/davinci-plugin/` は strategy/progress/delegation + workstreams を
  持つ live lane（resolve-ofx / spatial optics）。本整理は入口索引の追加と read の
  みで、本文は改稿しない。
- 2026-07 の OFX / spatial optics 波で `apps/filmtone-resolve-ofx`・
  `packages/film-lab-swift-core`・`packages/film-lab-codex-mcp` が入口 doc
  （`README.md` / `AGENTS.md` routing / `docs/filmtone/README.md` / `.ai/*`）へ
  未登録のまま着地した。この索引ドリフトは codemap-feature-audit lane が
  reconcile 中。
- 過去の release runbook には当時の version、環境、操作が残る。歴史記録として
  保持し、現在値を主張する入口にはしない。
- `docs/guides/` はこのリポジトリの旧移行前 handoff を含む。life の
  `docs/guides/` とは別物であり、現行の life guide を複製しない。
