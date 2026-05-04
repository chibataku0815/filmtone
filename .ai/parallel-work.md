# Parallel Work Coordination Protocol — Filmtone

複数の AI エージェント（Claude Code, Cursor, Codex CLI）が同時に作業する際の協調ルール。

---

## 原則

1. **作業宣言必須:** タスク開始前に変更予定ファイルを宣言
2. **排他制御:** 同一ファイルの同時編集を禁止
3. **完了報告:** タスク完了時に状態を更新
4. **競合時は停止:** コンフリクト検出時は統括ロールに報告
5. **stream の silent redefine 禁止:** lane 内での scope 拡大・縮退は handoff §8.5 で機構化

---

## 作業宣言（Lock Declaration）

タスク開始時に `.claude/tasks/ACTIVE-PARALLEL-TASK.md` に記録（必要に応じて新規作成）。
ただし Native Desktop v2 では `docs/filmtone/desktop/native-desktop-v2/active.md`
が現在 subtask の正本なので、そこに edit targets / read-only references /
verification を書く。Native v2 では `.claude/tasks/ACTIVE-PARALLEL-TASK.md`
を現在状態の正本にしない。

```markdown
## [タスク名]
- **Agent:** Claude Code / Cursor / Codex CLI
- **Started:** 2026-05-01 10:00 JST
- **Status:** 進行中
- **Files:**
  - `packages/film-lab-core/src/kernel/...` (編集)
  - `apps/capacitor-film-lab-ios/ios/App/App/...` (新規)
```

---

## ディレクトリレベル分離

機能単位でディレクトリを分離し、競合を最小化:

| ディレクトリ | 担当 | 備考 |
|------------|------|------|
| `packages/film-lab-core/` | kernel 専門 | math / schema / preset / LUT |
| `packages/film-lab-renderer/` | renderer 専門 | WebGL / WebGPU / Three.js |
| `packages/film-lab-ui/` | UI 共通 | **要調整**（Desktop と iOS 双方から参照） |
| `packages/film-lab-smart-look/` | smart-look pipeline | look 推論 |
| `apps/desktop-film-lab-batch/` | Desktop 専門 | Electron / Playwright |
| `apps/capacitor-film-lab-ios/` | iOS 専門 | Capacitor / Swift / Xcode |
| `messages/`, `public/`, `scripts/` | **要調整** | 全 workspace に波及 |

---

## タスク完了報告

```markdown
## [タスク名]
- **Agent:** Claude Code
- **Completed:** 2026-05-01 11:30 JST
- **Status:** 完了
- **Changed Files:**
  - `packages/film-lab-core/src/...`
- **Verification:**
  - `bun run verify:desktop` : pass
  - `bun run verify:ios` : pass
- **Notes:** 他チームがレビュー可能
```

---

## コンフリクト解消フロー

1. `.claude/tasks/ACTIVE-PARALLEL-TASK.md` で競合を検出
2. 競合するエージェントは作業を一時停止
3. 統括ロール（または project-coordinator）に報告
4. 調整完了後に再開

---

## タスク分割の粒度

### 最小作業単位（Atomic Task）
- 1 つの機能追加 / 1 つのバグ修正
- 変更ファイル数: 1〜5 個程度
- 完結した単位で分割

### 並列可能な条件
- ファイル競合がない
- 機能的依存関係がない
- 各チームが独立検証可能（`verify:desktop` / `verify:ios` で独立 pass）

### 並列不可の条件
- `packages/film-lab-core` の schema / kernel 変更（全 consumer 波及）
- 同一コンポーネントへの変更
- workspaces 設定 / postinstall chain の変更
- release 番号 bump（Desktop と iOS を同時に動かさない）

---

## ハンドオフ（引き継ぎ）

作業を別のエージェントに引き継ぐ場合:

1. 引き継ぎドキュメントを作成（必要に応じて `.claude/tasks/`）
2. 現状、完了済み、未完了、ブロッカーを明記
3. `ACTIVE-PARALLEL-TASK.md` のステータスを「引き継ぎ待ち」に更新
4. 次のエージェントは引き継ぎ doc を読んでから開始

Native Desktop v2 では長大な handoff を新規作成しない。完了した
`active.md` を `docs/filmtone/desktop/native-desktop-v2/archive/` に移動し、
`strategy.md` へ 1〜3 行だけ追記する。旧 handoff / dated plan docs は
参照専用で、現在状態の正本にしない。

Native Desktop v2 の中規模差し込みは handoff ではなく `paused/` で扱う。
現 `active.md` 末尾に `Paused` を追記して完了済み / 未完を短く書き、
`paused/YYYY-MM-DD-{slug}.md` へ退避する。その後、差し込み専用の
`active.md` を 1 つだけ作る。差し込み完了後は archive し、必要なら
`strategy.md` に短く追記してから退避中の active を `active.md` に戻す。
milestone を変える差し込みは先に `strategy.md` の
`Interrupt / Decision Log` へ記録する。

### handoff §8.5（並列 stream 用 4 セクション機構化）

並列 stream を完了する際、以下を必ず埋める（silent redefine / 残タスク黙殺の禁止）:

1. **Plan Compliance:** 当初 lane 範囲との一致
2. **Cross-Stream Visibility:** 他 stream への影響
3. **Scope Diff:** 想定 scope と実 scope の差分
4. **残タスク enumeration:** 未完成項目の列挙
