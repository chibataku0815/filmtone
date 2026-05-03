# CLAUDE.md

Filmtone — 独立モノレポ Claude Code 協業ガイド

## 1. プロジェクトスコープ

- 目的: Filmtone Desktop + Filmtone iOS + 共有 packages (`film-lab-core` / `film-lab-renderer` / `film-lab-ui` / `film-lab-smart-look`) の独立モノレポ
- GitHub: `chibataku0815/filmtone`(2026-05-01 に `chibatakumi-portfolio` から `git filter-repo` で履歴付き分離、tag `migration-from-portfolio-2026-05-01`)
- 公開窓(landing / support / privacy / release-notes / journal)は **portfolio 側** の `apps/web`(`vendor/filmtone` submodule 経由消費)。SNS 投稿は外部プラットフォーム自体で行うので portfolio スコープ外
- 知識ハブ・truth scripts・docs/guides は **life 側** (`/Volumes/SamsungPortableSSDX5001/documents/life/`)

## 2. リポジトリ境界(必読)

| リポ | 役割 | このリポとの関係 |
|---|---|---|
| **このリポ** (`/forestone/filmtone`) | apps + packages の **実装の正本** | — |
| **portfolio** (`/forestone/chibatakumi-portfolio`) | 公開窓のみ(`apps/web`) | `vendor/filmtone` submodule 経由で packages を消費。**filmtone コードは portfolio で編集しない** — bump のみ |
| **life** (`/Volumes/SamsungPortableSSDX5001/documents/life/`) | docs/guides・truth scripts・knowledge hub・5 ロール憲法 | このリポの release/ios truth は life の `scripts/check-filmtone-*.sh` から問い合わせる |

## 3. 運用原則(life CLAUDE.md と整合、最優先)

| 原則 | 意味 |
|------|------|
| **本質優先 / 外殻最小** | 製品挙動を直接動かす変更(Swift / native / wiring / sidecar / Profile / fastlane / shader / preset 計算)= 本質。XCTest 6 並列・formal QA 手順書・過剰 i18n 化・装飾的 banner = 外殻で **user が「QA 希望」と明示した時のみ** |
| **保守的ヘッジ優先しない** | 「念のため fallback」「安全側でスキップ」「v1.x 後回し」のような逃げを優先しない。プロダクト品質に効く判断を取る |
| **思考は sequential-thinking** | 設計判断・lane 衝突・不変条件 gate 評価は `mcp__sequential-thinking` を使う(記憶ベース断言禁止) |
| **不確かなら検索** | API / ASC / Capacitor / iOS SDK / WebGPU 仕様が曖昧な場合は `gemini-search` → `WebSearch` の順。記憶ベース推測は `feedback_no_guessing_davinci_plugins` / `feedback_verify_before_documenting` 違反 |
| **handoff 鵜呑み禁止** | 旧 chat の handoff doc を引用する前に、現行 surface (`grep` / Swift / pbxproj / WGSL) と突き合わせて live/frozen を確認 (`feedback_verify_before_quoting_handoff`) |
| **Native Desktop v2 は 2-layer 正本** | `docs/filmtone/desktop/native-desktop-v2/strategy.md` + `active.md` を現在状態の正本にする。旧 handoff / old plan docs は参照専用 |
| **並列 stream silently 縮退禁止** | Agent Teams や複数 chat で stream 分割時、§3 残タスクの silent 省略・lane の chat 独断 redefine は禁止。完了時は handoff §8.5 4 セクション (Plan Compliance / Cross-Stream Visibility / Scope Diff / 残タスク enumeration) で機構化 (`feedback_no_silent_stream_redefine`) |
| **bun 必須** | `bun install` / `bun run` / `bun add`。`npm` 禁止、`bun.lock` が正本(life CLAUDE.md §パッケージマネージャ) |

## 4. 必読(60 秒オンボーディング)

| パス | 内容 |
|---|---|
| `README.md` | workspaces + scripts(`bun run build:core` / `verify:desktop` / `verify:ios` 等) |
| `.ai/GLOBAL.md` | AI ツール共通グローバルルール(Cursor / Codex CLI 横断) |
| `.ai/parallel-work.md` | 並列 stream / Agent Teams 協調プロトコル |
| `docs/filmtone/desktop/native-desktop-v2/strategy.md` | Native Desktop v2 の長期戦略・マイルストーン正本 |
| `docs/filmtone/desktop/native-desktop-v2/active.md` | Native Desktop v2 の現在進行中サブタスク。存在しなければ次タスク案を作り、実装せずレビュー待ち |
| `apps/capacitor-film-lab-ios/CLAUDE.md` | iOS 専用 223 行(Swift / fastlane / pbxproj 不変条件・lane 番号・antipattern) |
| life `docs/guides/2026-05-01-filmtone-standalone-product-repo-migration-handoff.md` | 移行経緯の参照。現在状態の正本にはしない |
| life `docs/guides/film-lab-current-index.md` | live エントリ doc(read order・active lanes) |

## 4.5 Native Desktop v2 2-layer 運用

詳細なルールは `AGENTS.md` の "Long-Running Task Model" に置く。Claude
固有の運用は以下だけ:

- Native Desktop v2 では開始時に `strategy.md` を読み、`active.md` があれば
  その範囲だけ作業する。
- `active.md` がなければ次の 30 分以内粒度のサブタスク案を作り、実装は
  開始しない。
- 完了時は `active.md` を archive へ移動し、`strategy.md` には 1〜3 行だけ
  追記する。長大な handoff は作らない。
- 半日〜数日の差し込みは、現 `active.md` に `Paused` を追記して
  `paused/` へ退避し、差し込み専用の `active.md` に差し替える。軽微修正は
  現 active の `Unexpected` / `Follow-up` で扱う。差し込み完了後は archive し、
  必要な場合だけ `strategy.md` に 1〜3 行追記してから退避中の active を戻す。
- マイルストーンを変える差し込みは `strategy.md` の
  `Interrupt / Decision Log` に短く追記してから `active.md` を作る。長期方針を
  変える場合は実装前にレビューする。
- 旧 handoff / transition plan は事実確認の参照専用。現在状態として引用する前
  に `strategy.md` / `active.md` / 現行 source を優先する。

## 5. Truth Gates(life スクリプト)

release/iOS 状態を主張する前に必ず通す:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

doc とスクリプトが食い違ったら **スクリプトを信頼**(handoff §"Trust truth scripts over handoffs")。`FILMTONE_REPO_ROOT` env で root 上書き可。

## 6. アンチパターン(踏まない)

1. **npm publishing を再導入しない** — packages は submodule 消費前提。`npm publish` は portfolio の build 経路を壊す
2. **`packages/film-lab-renderer/dist/` `packages/film-lab-smart-look/dist/` を消さない** — submodule 即 import 用に **意図的に track**(root `.gitignore` に `dist` 除外規則は **書かない**、`.gitignore` 編集時に `dist` を ignore に追加しないこと)。再生成必要なら `bun run build:renderer` / `build:smart-look` で上書き
3. **portfolio を実装の正本扱いしない** — 古い handoff (`2026-03-30-*`, `2026-04-09-*` 等)が `chibatakumi-portfolio/apps/desktop-film-lab-batch` を参照していても、それは pre-migration の記述。実装は **このリポ**
4. **iOS public 版と local candidate を混ぜない** — 固定値を書かない。毎回 release truth script で public App Store state / local Xcode candidate / upstream delta を確認してから書く
5. **用語ロック** — `動画`(× `短尺動画`)/ `video`(× `short-form video`)。canonical spec は life `docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`、video vocabulary lock は life commit `5ce6d55`(2026-05-01)を起点
   **Preset / Look の訂正** — `Preset` は curve / grade 土台、`Look` は Stone / Urban Creative LUT Pack 文脈専用。`feature/desktop-look-unification` の rename 前提は 2026-05-04 に撤回済み。`BaseLookName` / `BASE_LOOKS` / `lookPresetId` / `currentExportLookPreset` などの alias artifact は新規参照しない。既存 artifact は purge lane で扱う
6. **JSX comment を return ( の直下に置かない** — `feedback_no_jsx_comment_outside_root_return` 既発火 2 回

## 7. Submodule update 手順(portfolio 側へのバンプ)

このリポで commit/push した後、portfolio に変更を波及させる:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
# (commit + push は user が実行)

cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
git submodule update --remote vendor/filmtone
git add vendor/filmtone
git commit -m "chore(filmtone): bump submodule"
# (portfolio push も user が実行)
```

vercel deploy は portfolio 側の `apps/web` build に依存するので submodule pin が古いと公開窓が古いままになる。

## 8. per-app CLAUDE.md ポインタ

| パス | 状態 |
|---|---|
| `apps/capacitor-film-lab-ios/CLAUDE.md` | **既存**(223 行)。iOS の不変条件はここから引く |
| `apps/desktop-film-lab-batch/CLAUDE.md` | **未作成**。Desktop 専用の不変条件が顕在化した時に user 指示で追加(現状は README + このファイルで足りる) |
| `docs/filmtone/desktop/native-desktop-v2/strategy.md` + `active.md` | **既存**。Native Desktop v2 はこの 2-layer docs を正本にする |

## 9. 出力ルール(life CLAUDE.md §11 と整合)

- 日本語。技術用語は英語可
- ファイル参照: `path/to/file:line` 形式
- 簡潔・行動志向
- **Git 操作は user が行う**(自動コミット禁止)
