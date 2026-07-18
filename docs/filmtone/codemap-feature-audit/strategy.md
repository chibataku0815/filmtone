# Codemap / Feature-Matrix Audit — ループ作業対応計画書

Date: 2026-07-19 JST
Status: 監査ループ 1 パス完了（codemap / 機能表 / 索引整合 done・静的ゲート green）。
Refactor R1-R5 は user smoke 待ちで staging（codemap `Refactor Findings` 参照）

## この計画の前提となる用語定義（2026-07-19 user 確定）

- **Codemap（確定: 新規正本を作成）** — リポジトリに `codemap` という成果物は
  存在しない（repo 内 grep は archive 1 件のみ、life 側にも Filmtone codemap
  慣習なし）。user 確認済みの定義: **「全 app / package の構造・責務・入口・
  生成境界・verify 手段を 1 枚に集約する新規 canonical doc」= codemap**。既存の
  `README.md` / `AGENTS.md` / `docs/filmtone/README.md` / `inventory.md` の
  routing 群はこの codemap の分散した断片であり、本計画で codemap へ集約し整合させる。
- **Feature（機能表の 1 行）** — user-facing capability。Look / capture mode /
  editor 操作 / optics module（lens softness・deep glow・vignette・peripheral
  chromatic shift・texture softness・film breath・gate weave・film damage）/
  export option / import（DRX / Imported Grade）等。内部 helper は行にしない。

## Goal

直近 main に着地した DaVinci Resolve OFX / spatial optics 波を含む現在の
実装状態に対して、(1) codemap と索引 doc 群が最新かつ正しいこと、(2) 各 app /
package が責務分離と feature-based アーキテクチャを保っていること、を
サーフェス単位のループで精査・確認・改善し、user が全機能網羅を目視検証できる
機能表を成果物として残す。

本質優先。リファクタリングは監査で構造的 drag が製品前進を阻む箇所に限定し、
外殻（cosmetic reorg・formal QA grid・過剰 i18n）は品質保証段階でのみ行う。

## 現状スナップショット（2026-07-19 検証済み）

索引ドリフト（新規サーフェスが入口 doc に未登録）:

| サーフェス | 実体 | README | AGENTS routing | docs/filmtone/README | inventory | .ai/* |
|---|---|---|---|---|---|---|
| `apps/filmtone-resolve-ofx` | 39 C++/Metal, OFX plugin | ✗ | ✗ | ✗ | ✗ | ✗ |
| `packages/film-lab-swift-core` | 33 swift（Generated 含む） | ✗ | 非負条件のみ | ✗ | 総称のみ | ✗ |
| `packages/film-lab-codex-mcp` | 4 ts, MCP automation | ✗ | ✗ | ✗ | 総称のみ | ✗ |
| davinci-plugin / davinci-bridge lane | live lane 群 | ✗ | ✗ | ✗ | bridge のみ言及 | ✗ |

構造健全性（多くは既に整理済み — 大型リライトは想定しない）:

- `apps/capacitor-film-lab-ios`（181 swift）: feature folder（Export/Editor/
  Capture/Look/Optics/Source/Services/Root/Smoke/Strings）維持。ただし
  `FilmtoneEditorStore.swift` が refactor 完了時 1723 → **2002 行**、
  `FilmtoneExportSession.swift` が 1078 → **1281 行** にリグロース。god-object
  分割の一部浸食 = 監査対象の実ドリフト。
- `apps/filmtone-desktop-macos`（84 swift）: Color/UI/State/Media/Domain/
  Export/App の layer 分離済み。最大は `UI/RootWindowView.swift` 1366 行 /
  `Color/FilmtoneGradeKernels.swift` 1128 行で、iOS refactor 前の 3000+ 行級
  god-object は無い。RootWindowView（最大の UI view）は Wave 8 監査で肥大の
  可否を確認する候補。
- `apps/filmtone-resolve-ofx`（39）: `Sources/{Effects,Host,Integration,
  Generated}` で既に分離済み。build は `Makefile`、**root に `verify:*`
  スクリプトなし = ドリフト所見**。
- `packages/film-lab-swift-core`（33）: `FilmLabSwiftCore` + Tests + `Generated/`。
- `apps/desktop-film-lab-batch`（103 ts）: frozen legacy Electron。

live lane（本計画は書き換えず索引追加と read のみ）:

- `docs/filmtone/davinci-plugin/{strategy,progress,delegation}.md` + `workstreams/`
  — resolve-ofx / spatial optics の稼働 lane 正本。
- `docs/filmtone/davinci-bridge/active.md`（DB-M13）— 全 checklist `[x]`・検証
  完了だが未アーカイブ。governance 上の closeout ドリフトだが lane owner 領分。
  本計画は所見として記録し、archive 操作はしない。

## Done Conditions

1. `docs/filmtone/filmtone-codemap.md`（仮名）が SSOT として存在し、4 app +
   6 package の構造・責務・入口・生成境界・verify 手段を網羅し、README /
   docs/filmtone/README から到達できる。
2. `docs/filmtone/filmtone-feature-matrix.md`（仮名）が全 user-facing 機能を
   サーフェス別・人間が走査できる粒度で列挙し、completeness pass を経て user が
   網羅を目視確認できる。
3. `README.md` / `AGENTS.md` routing / `docs/filmtone/README.md` /
   `.ai/GLOBAL.md` / `.ai/parallel-work.md` / `inventory.md` が現行全サーフェス
   （resolve-ofx / swift-core / codex-mcp / davinci lane 含む）へ整合。
4. 各サーフェスが責務分離 + feature-arch で監査され、所見が記録され、構造的
   drag が製品前進を阻む箇所は essence refactor 済みで verify green。
5. live lane doc を書き換えず、生成領域を編集せず、legacy Electron を frozen の
   まま扱う。

## Loop Units（essence 順・legacy 最後）

各ユニットは 1 iteration = 1 `active.md`。以下の per-unit checklist を実行:

1. **Audit** — source top-level を読み、責務分離 / feature-arch を評価。god
   object・責務混在・flat namespace・kernel 分岐違反・生成境界を所見化。
2. **Essence refactor（条件付き）** — 構造的 drag が製品前進を阻む箇所のみ。
   parity gate は loud。生成領域・cosmetic reorg は禁止。無ければ no-op。
3. **Codemap section** — 構造・責務・入口・生成マーカー・verify コマンドを追記。
4. **Feature-matrix rows** — 当該サーフェスの user-facing 機能をグループ化して追記。
5. **Docs sync** — 索引 routing 整合、欠落 README 補完、inventory 分類。
6. **Verify** — 当該サーフェス最小の verify を実行・記録。

順序:

- **Wave 0 — Bootstrap**: codemap / feature-matrix の skeleton 作成、"feature"
  定義確定、索引ドリフト所見の列挙、inventory snapshot を新規サーフェスへ更新（分類のみ）。
- **Wave 1** `packages/film-lab-core`（kernel canonical・全 consumer 波及の土台）
- **Wave 2** `packages/film-lab-renderer`（WebGL / WebGPU）
- **Wave 3** `packages/film-lab-smart-look`（look 推論・極小）
- **Wave 4** `packages/film-lab-ui`（Desktop / iOS 双方参照の共通 UI）
- **Wave 5** `packages/film-lab-swift-core`（Swift runtime 共有・Generated 境界明示）
- **Wave 6** `packages/film-lab-codex-mcp`（MCP automation server）
- **Wave 7** `apps/filmtone-resolve-ofx`（既存構造監査 + optics module 機能行 +
  verify script 欠落所見。davinci-plugin lane は read-only）
- **Wave 8** `apps/filmtone-desktop-macos`（layer 分離監査。DB-M13 領域尊重）
- **Wave 9** `apps/capacitor-film-lab-ios`（EditorStore / ExportSession リグロース
  監査 + 必要なら essence refactor + 機能行）
- **Wave 10** `apps/desktop-film-lab-batch`（**doc 分類のみ・refactor 禁止**の
  frozen legacy。機能表には legacy/frozen 注記）
- **Wave Z — Reconciliation + completeness**: codemap / feature-matrix 確定、
  全索引整合、inventory 更新、completeness critic pass（全サーフェス・全機能
  被覆の確認 = user 目視 gate）、cross-lane closeout（DB-M13 等）は owner へ所見提示。

## 制約・ガードレール

- **本質優先 / 外殻最小**: refactor は監査 gated。10 サーフェス一律リライトは約束しない。
- **生成領域は scope 外**: `film-lab-swift-core/**/Generated/`、iOS
  `*Generated.swift`、`resolve-ofx/Sources/Generated`、tracked `packages/*/dist/`。
  codemap に生成マーカーを付け "cleanup" 対象にしない。
- **live lane doc 不可侵**: davinci-plugin / davinci-bridge / 他 `active.md` は
  索引追加と read のみ。本文書き換えなし。
- **legacy Electron frozen**: `desktop-film-lab-batch` は分類のみ。
- **2-layer 遵守**: `active.md` は常に 1 つ。本 lane は documentation-governance
  規則の下で運用し、進行に応じ `inventory.md` を更新する。
- **bun 一択 / git 操作は user / 自動 commit 禁止**。
- resolve-ofx verify は `Makefile`。root `verify:resolve` の欠落は所見として
  提示するが、本 lane では自動追加しない（別途 user 判断）。

## Out Of Scope

- live lane（davinci-plugin / davinci-bridge / native-desktop-v2 active）の再設計・本文改稿。
- 生成コードの手編集、tracked dist/ の削除。
- legacy Electron のリファクタリング。
- 公開コピー / release / App Store 主張の変更（必要時は truth gate 経由で別扱い）。
- formal QA matrix / XCTest 拡張 / PSNR fixtures（user が QA 希望時のみ）。

## Interrupt / Decision Log

- 2026-07-19 JST — Lane を提案。codemap の実体不在を受け「新規 canonical doc」を
  前提定義とし、レビュー確認事項として明示。索引ドリフトの主軸は resolve-ofx /
  swift-core / codex-mcp / davinci lane の入口未登録と判定。多くのサーフェスは
  構造健全のため大型リライトは想定せず、iOS god-object リグロースと resolve-ofx
  verify 欠落を具体的 refactor / 所見候補として特定。
- 2026-07-19 JST — user レビューで 2 前提を確定: (1) codemap は新規 canonical doc
  を作成、(2) リファクタリングは監査 gated・本質優先（cosmetic reorg / 全面再編は
  しない）。両者は本計画の初稿前提と一致。Wave 0（doc-only）着手可。

## Completion Log

- **2026-07-19 JST — 監査ループ 1 パス完了（Wave 0-Z、refactor 実行を除く）。**
  6 並列 read-only 監査 agent で 4 app + 6 package を精査。成果:
  - `filmtone-codemap.md` 新規作成（全 10 サーフェスの構造・責務・入口・生成境界・
    verify + Refactor Findings 表）。
  - `filmtone-feature-matrix.md` 新規作成（8 カテゴリ × 6 サーフェスの機能網羅表）。
  - 索引整合: `README.md` / `AGENTS.md` routing / `docs/filmtone/README.md` /
    `.ai/GLOBAL.md` / `.ai/parallel-work.md` / `inventory.md` へ resolve-ofx /
    swift-core / codex-mcp / davinci lane を登録。`CLAUDE.md` の iOS doc "223 行"
    → 実 139 行に修正、package 一覧に swift-core / codex-mcp / resolve-ofx 追加。
  - 監査結論: **構造は大半健全**。clean = core / smart-look / swift-core /
    codex-mcp / resolve-ofx(code) / desktop-macos。要 refactor = film-lab-renderer
    (WebGPU 4384 / WebGL 2621) / film-lab-ui (Canvas 2460 / Panel 2070、実 consumer
    は legacy + web) / iOS EditorStore(+279) ・ExportSession(+203) リグロース。
  - 静的ゲート: `check:filmtone-reference-guards` / `check:filmtone-context` /
    `git diff --check` 全 green。
  - watch-item（desktop-macos RootWindowView geometry / AutomationCLI SecurityPolicy）は
    named product move 発生時に着手。frozen legacy Electron は対象外。

- **2026-07-19 JST — Refactor 実行フェーズ（user 指示: 本質固定・止めず完遂）。**
  監査で検出した god object を build gate 検証付きで実際に分割（codemap `Refactor
  Log` 参照）:
  - iOS R3/R4/R5 = **landed・`verify:ios` build + contract gate green**。EditorStore
    2002→1517、ExportSession 1281→1097、collaborator 3 本追加・pbxproj 登録済。
  - renderer R1 = **landed**。WebGPU 4384→2870（`webgpu/passes/` 9）+ WebGL 2621→2257
    （`webgl/passes/` 6）、呼び出し順不変、`build:renderer` + tsc green。desktop-batch
    consumer の 2 typecheck エラーは stash 検証で既存 legacy ドリフト（arri-logc3 /
    globals.css）と確認、本 refactor 起因ではない。
  - ui R2 = Panel **landed**（ControlPanelCore 2070→1204, typecheck green）。Canvas は
    安全 helper 抽出済で残余が不可分 stateful React wiring のため非強行（雑な hook
    分割は stale-closure runtime bug でプロダクトを害する = 本質に反する）。
  - 認識合わせ: 検証は「壊れ確認」の従属手段であり本質ではない。本質はコード構造が
    実際に改善されること + docs が真実であること。最終の実機 / web 視覚 smoke のみ
    owner gate として残す。
