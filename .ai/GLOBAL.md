# AI Agent Global Policy — Filmtone

**対象:** Claude Code / Cursor AI / Codex CLI / その他 AI ツール

このファイルは Filmtone standalone repo の AI ツール共通グローバルルール。Claude Code 固有の補足は `/CLAUDE.md` を、iOS 固有は `apps/capacitor-film-lab-ios/CLAUDE.md` を参照。

---

## プロジェクト概要

Filmtone は色再現・LUT・smart-look を提供するクロスプラットフォーム grading product。

| 面 | 技術 |
|----|------|
| Desktop | Electron + Vite + Playwright golden（macOS arm64 + notarization） |
| iOS | Capacitor 7.4.3 + Native Swift（Xcode automatic signing） |
| Renderer | WebGL / WebGPU（Three.js, three-stdlib） |
| Runtime | Bun |
| Workspace | bun workspaces（Turbo なし） |

---

## ソース・オブ・トゥルース

| ファイル | 役割 | 対象ツール |
|---------|------|-----------|
| `.ai/GLOBAL.md` | 共通グローバルルール | 全ツール |
| `.ai/parallel-work.md` | パラレルワーク協調 | 全ツール |
| `CLAUDE.md` | Claude Code 補足 | Claude Code |
| `apps/capacitor-film-lab-ios/CLAUDE.md` | iOS-specific | Claude Code |
| `messages/{en,ja}.json` | 共通コピー | 全ツール |

---

## エンジニアリング原則

- **KISS / DRY / YAGNI** を徹底
- **bun 一択**: `bun install` / `bun add` / `bun run`。npm 使用禁止
- **ループ記法**: `forEach` と `for (let i...)` 禁止。`for...of` / 配列メソッドを用いる
- **postinstall 尊重**: `bun install` 後の `build:core` → `build:renderer` → `build:smart-look` を skip しない
- **kernel 改変は core 経由**: `packages/film-lab-core` を canonical とし Desktop / iOS で独自分岐させない
- **不変条件 gate**: iOS は `apps/capacitor-film-lab-ios/CLAUDE.md` の commit gate / Profile schema を逸脱しない
- **release 番号**: Desktop = `apps/desktop-film-lab-batch/package.json`、iOS = pbxproj。両者を同時に動かさない（リリース面ごとに 1 commit）

---

## 思考と検索

| 状況 | 行動 |
|------|------|
| 設計判断 / lane 衝突 / 不変条件評価 | `mcp__sequential-thinking__sequentialthinking` |
| iOS / ASC / Capacitor / electron-builder / WebGPU / TS の挙動が曖昧 | `gemini-search` → `WebSearch` で確認してから書く |
| ファイル探索 / pattern 調査 | `Task(subagent_type=Explore)` |
| 複雑な実装の設計 | `Task(subagent_type=Plan)` |

記憶ベースで断言しない。

---

## サブエージェント運用

### 使用判断フロー

```
タスク受領
  ↓
専門領域に該当？（iOS native / electron / WebGPU shader / kernel math）
  YES → 関連 doc を Read してから着手
  NO  → 並列実行可能？
        YES → Task を並列起動（独立 stream を 4+ なら Agent Teams、`.ai/parallel-work.md` 参照）
        NO  → 探索が必要？
              YES → Task(Explore)
              NO  → 直接実装
```

### 並列実行の原則

- 独立 stream 4+ → Agent Teams
- 3 以下 → Sequential
- 迷ったら Sequential（安全側）
- 並列可能を逐次処理するのは禁止

---

## 出力スタイル

- 簡潔・行動志向
- ファイルパスはバッククォートで明示
- 過度な称賛・感情表現を避け、技術的に正確な表現
- 内部処理（thought / sub-agent prompt）は英語、ユーザー出力 / commit / ドキュメントは日本語

---

## 変更安全性

- 破壊的・広範囲変更前は意図/影響を簡潔に共有
- 新規環境変数や設定追加は原則禁止（必要時のみ合意の上）
- ログ/デバッグ用コードは提出前に除去
- コミットは明示的に指示された場合のみ
- 旧 chat の handoff doc を引用する前に grep で live/frozen を判定

---

## 言語ルール

| 処理 | 言語 |
|------|------|
| sequential-thinking thought | 英語 |
| Agent / subagent prompt | 英語 |
| 中間分析・計画 | 英語 |
| ユーザー出力 | 日本語 |
| ドキュメント / Issue / commit | 日本語 |
| コード / 技術用語 | 英語 |
