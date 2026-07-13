# Filmtone Documentation Governance — Strategy

## Goal

Filmtone の実装・リリース・運用ドキュメントを、必要な人とエージェントが
短時間で正しい現在情報へ到達でき、古い記録を誤って現在状態として使わず、
保守コストを増やさずに更新できる状態へ整える。

対象はこのリポジトリの `docs/`、ルートのガイド文書、各 app/package が持つ
運用ドキュメントである。portfolio と life の正本をこのリポジトリへ複製しない。

## Done Conditions

- 各ドキュメントに、現在の正本・運用手順・参照記録・アーカイブのいずれかの
  役割を与えられる。
- 現在情報への入口は領域ごとに 1 つに定まり、索引から辿れる。
- 固定値のリリース状態を含む文書には、truth script または現行ソースへの
  確認方法が明記される。
- 新規文書の置き場所、命名、更新責任、終了時のアーカイブ判断を、短い規則で
  決定できる。
- 旧 handoff と調査記録は削除せず、現在状態ではないことが明確になる。
- リンクを壊さず、進行中の製品レーンの `strategy.md` と `active.md` の権限を
  変更しない。

## Information Architecture

| 種別 | 役割 | 置き場所 | 更新の扱い |
|---|---|---|---|
| 入口索引 | 読み始める場所と正本への導線 | `README.md` | 現在の導線だけを保つ |
| 正本 | 現在のルール、仕様、長期戦略 | 所有領域直下 | 変更時に直接更新する |
| 進行書 | いま 1 つだけ進める作業 | レーン直下の `active.md` | 完了後に archive へ移す |
| 作業計画 | 目的、Done 条件、判断、短い完了記録 | レーン直下の `strategy.md` | 長期的に維持する |
| 参照記録 | 調査、handoff、過去の判断の根拠 | 所有領域の `evidence/` または明示した参照場所 | 内容を現在状態として書き換えない |
| アーカイブ | 完了・置換済み・履歴としてのみ必要な記録 | 所有領域の `archive/` | 現在の正本から明確に区別する |

### Canonical Entry Points

- リポジトリ全体: `README.md`、運用ルール: `AGENTS.md`
- Filmtone 横断ドキュメント: `docs/filmtone/README.md`
- Desktop: `docs/filmtone/desktop/README.md`。Native Desktop v2 は
  `native-desktop-v2/strategy.md` と、存在する場合の `active.md`。
- iOS: `docs/filmtone/ios/README.md` と
  `apps/capacitor-film-lab-ios/CLAUDE.md`。
- パッケージ固有の仕様: 対象 package の `docs/` とその実装。
- リリース状態: 固定した handoff ではなく life の truth scripts。

## Operating Rules

1. **先に分類する。** 新規・既存を問わず、移動・更新・削除の前に上表の種別と
   所有領域を決める。分類できない文書は一旦「参照記録」とし、現在の正本にしない。
2. **正本は重複させない。** 同じ現在情報を複数の README や handoff に複写しない。
   索引には要約とリンクだけを置く。
3. **現在状態は検証可能にする。** release、version、App Store、配布、対応状況は
   truth script または現行ソースの確認方法を添える。日付つきの状態説明は、その
   日時点の記録として扱う。
4. **進行書は一つだけにする。** 同じレーンに同時の `active.md` を複数作らない。
   中断時は既存レーンの pause/archive 規則を優先する。
5. **完了した作業は短く残す。** `active.md` の完了記録を archive へ移し、
   `strategy.md` には判断・結果・既知のリスクだけを 1〜3 行で残す。
6. **履歴を改竄しない。** 旧 handoff の誤りは、現在の正本・索引・注記で補正する。
   内容を書き換えて当時の文脈を失わせない。
7. **ファイル名は役割を表す。** 現在の恒久文書は `README.md`、`strategy.md`、
   `active.md` のように役割で命名する。履歴・調査・完了記録は
   `YYYY-MM-DD-meaningful-slug.md` を使い、実装順序だけを表す語を使わない。
8. **リンク先を先に用意する。** 移動・統合時は新しい入口と転送用の注記を先に作り、
   参照元の更新を終えてから旧ファイルを archive へ移す。

## Work Loops

### Foundation — Complete

この戦略と進行書を作り、全体索引から到達できるようにする。既存記録は移動しない。

### Inventory And Classification — Complete

`docs/`、app/package の運用文書、ルートのガイドを一覧化し、所有領域・種別・
現在性・移行要否を記録する。進行中のレーン文書は読み取り専用で扱う。

### Entry-Point Alignment — Complete

各領域の README を、現在の正本・truth gate・アーカイブへの短い導線に揃える。
固定リリース値や旧実装への誤誘導は、現行の確認方法へ置き換える。

### Safe Migration — On Demand

分類済みの孤立 handoff・調査記録を所有領域または archive へ小さな単位で移す。
移動ごとに受け皿、参照元、リンクを確認する。曖昧な所有者は移動しない。

### Maintenance — Ongoing

新しい長期レーンと完了記録に本ルールを適用し、重複・孤立・古い現在主張を
定期的に小さく解消する。

## Boundaries

- Native Desktop v2 と iOS の既存レーン運用を置換しない。
- app/package の実装仕様を一般的な横断文書へ複製しない。
- portfolio または life が所有する公開コピー、knowledge hub、truth scripts を
  このリポジトリへ移管しない。
- 既存の履歴文書を、調査・分類なしに削除または一括移動しない。

## Completion Log

- 2026-07-14: documentation-governance の戦略と初回進行書を作成。既存文書の移動は
  行わず、分類と入口整合を次の作業として分離した。
- 2026-07-14: 420 件の Markdown を役割と所有領域で分類し、横断・iOS・Web・legacy
  guides の入口を整合した。既存の履歴や進行中の product lane は移動せず、以降の
  移動は受け皿と参照更新が揃う場合だけ行う。
