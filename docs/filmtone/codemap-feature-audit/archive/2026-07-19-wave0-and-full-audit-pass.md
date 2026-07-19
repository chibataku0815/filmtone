# Wave 0 — Bootstrap（codemap / feature-matrix skeleton + 索引ドリフト所見）

Milestone: Wave 0（同パスで Wave 1-Z 監査まで継続）
Status: 完了（archive 対象）

## Goal

以降の per-surface ループが追記していく codemap / feature-matrix の skeleton を
用意し、"feature" 定義を確定し、索引ドリフトを列挙し、inventory を新規サーフェス
へ更新（分類のみ）する。**source は一切変更しない doc-only wave**。

## Edit targets

- `docs/filmtone/filmtone-codemap.md`（新規・skeleton）
- `docs/filmtone/filmtone-feature-matrix.md`（新規・skeleton）
- `docs/filmtone/documentation-governance/inventory.md`（新規サーフェス分類追記）
- `docs/filmtone/codemap-feature-audit/strategy.md`（所見確定時に 1-3 行）

## Read-only references

- `README.md` / `AGENTS.md` / `.ai/GLOBAL.md` / `.ai/parallel-work.md`
- `docs/filmtone/README.md` / `docs/filmtone/documentation-governance/strategy.md`
- `docs/filmtone/davinci-plugin/strategy.md` / `.../progress.md`（read-only）
- `docs/filmtone/davinci-bridge/active.md`（read-only）

## Checklist

- [ ] `filmtone-codemap.md` skeleton: 4 app + 6 package の見出し・列（構造 /
      責務 / 入口 / 生成境界 / verify）を stub 化。値は各 Wave で埋める。
- [ ] `filmtone-feature-matrix.md` skeleton: "feature" 定義を冒頭に固定し、
      サーフェス別セクション + グループ列（Look / Capture / Editor / Optics /
      Export / Import 等）を stub 化。
- [ ] 索引ドリフト所見リストを strategy に確定（現状表を検証済みで転記済み）。
- [ ] `inventory.md` に `apps/filmtone-resolve-ofx`・`packages/film-lab-swift-core`・
      `packages/film-lab-codex-mcp`・davinci-plugin lane を分類行として追記
      （現在性・所有・current-use rule）。snapshot 日付を更新。

## Verification

- [ ] `bun run check:filmtone-reference-guards` — pass（routing 整合）。
- [ ] `bun run check:filmtone-context` — pass（copy/context sync）。
- [ ] `git diff --check` — clean。
- [ ] markdown リンク切れがないこと（新規リンク先の存在確認）。

## Done conditions

- codemap / feature-matrix の skeleton が存在し、README / docs/filmtone/README
  から到達可能（リンク追加は Wave Z で最終整合、Wave 0 では最小の入口のみ）。
- inventory が新規サーフェスを分類済み。
- 索引ドリフトが所見として列挙済み。

## Stop conditions

- Done conditions 達成。
- live lane doc への書き込みが必要になった場合（scope 逸脱 → 停止・報告）。
- 同一 verify コマンドで 3 連続失敗。

## Out of scope

- source の refactor・移動（Wave 1 以降）。
- live lane（davinci-plugin / davinci-bridge）本文の改稿。
- README / AGENTS / .ai/* の全面 routing 整合（Wave Z で実施）。

## Unexpected

- 同パスで Wave 0 の doc-only skeleton を超えて Wave 1-Z（6 並列監査 + codemap /
  機能表 本体充填 + 全索引整合）まで完走した。source refactor（R1-R5）は smoke
  必須のため未実行で staging。詳細は `strategy.md` Completion Log と
  `filmtone-codemap.md` Refactor Findings 参照。

## 完了記録

- Checklist（Wave 0）: codemap / 機能表 skeleton・索引ドリフト所見・inventory 更新 = 全完了。
- 継続分: 全 10 サーフェス監査、codemap 全節充填、機能表全カテゴリ充填、
  README / AGENTS / docs 索引 / .ai/* / CLAUDE.md 整合。
- Verification: `check:filmtone-reference-guards` green / `check:filmtone-context`
  green / `git diff --check` clean / 新規リンク先存在確認 OK。
- 次 subtask: Refactor R1-R5 のうち user が greenlight した 1 本を active.md 化
  （smoke 付き）。それまで active.md なし。
