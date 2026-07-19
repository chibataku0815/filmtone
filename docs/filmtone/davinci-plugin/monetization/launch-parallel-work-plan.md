# MON-6 ローンチ残作業 — 並列作業計画書

Date: 2026-07-19 JST
ディレクター: 本チャット(Claude Code、`claude/filmtone-davinci-release-65b85c` worktree)
協調プロトコル: [`.ai/parallel-work.md`](../../../../.ai/parallel-work.md) 準拠
進行(lock/status board): [`.claude/tasks/ACTIVE-PARALLEL-TASK.md`](../../../../.claude/tasks/ACTIVE-PARALLEL-TASK.md)
進行(coordinator-owned 正本): [progress.md](progress.md)

## 前提

- module scope = Film-Damage-first / 公開version = 0.1.0 as-is / 対応環境表記 = 狭い実測範囲のみ
  / ローンチ日 = 未確定(progress.md 改訂 26 で owner 承認済み)。
- 各 stream はディレクトリ・ファイル単位で排他(同一ファイルの同時編集なし)。
- 生成物はすべて draft。公開・commit・本番操作はディレクター(本チャット)が
  owner 確認を取ってから行う(stream 側で production 操作・commit・push はしない)。

## 並列 stream(Agent tool background 実行、本チャット内)

| ID | Stream | 担当ファイル/scope | Agent / model | Done 条件 |
|---|---|---|---|---|
| S1 | Release article(JP/EN) | `filmtone-release-articles` skill 経由の draft 一式(配置先は skill の規約に従う。`apps/web/src/app/.../filmtone/resolve/` 配下は編集しない = product page stream と非重複) | communicator / opus | JP/EN 揃った draft 一式、禁忌語チェック・truth gate 準拠を報告 |
| S2 | Owner runbook(Vercel + Polar 設定手順) | 新規 `docs/filmtone/davinci-plugin/monetization/mon6-owner-runbook.md` | engineer / opus | Vercel env 設定+redeploy 手順、Polar checkout URL 確定手順、file-delivery benefit への pkg アップロード手順、購入メール文面の貼り付け先を番号付きで具体化 |
| S3 | MON-4 検証手順書(実行はしない) | 新規 `docs/filmtone/davinci-plugin/monetization/mon4-verification-runbook.md` | engineer / opus | Turnstile hostname/action mismatch・実 trial 請求・テスト購入・clock-forward 失効確認、各々の実行コマンド/手順+期待結果+ロールバック手順を用意。**実行は禁止**(production request のため) |

各 stream 完了時、`.ai/parallel-work.md` の「タスク完了報告」フォーマットで
`.claude/tasks/ACTIVE-PARALLEL-TASK.md` を更新する(ディレクターが集約)。

## 並列化しない(owner 専任 / ディレクター専任)

以下はエージェント並列化の対象外。理由を明記する。

| 項目 | 理由 |
|---|---|
| Vercel env 設定 + 再デプロイ | owner の Vercel account 操作 |
| Polar checkout URL 確定・file-delivery benefit アップロード | owner の Polar dashboard 操作 |
| EULA/返金/trial-privacy の法務レビュー | owner のみが下せる承認判断 |
| MON-4 検証の実実行(Turnstile 本番 token・実メール送達・テスト購入・時計操作) | production request のため action-time confirmation が必須(一括事前承認しない) — S3 の手順書ができ次第、ディレクターが 1 件ずつ owner 確認を取り実行する |
| portfolio 側変更の commit/push | 別 repo・別 gate。owner 承認まで working tree のまま |
| progress.md 更新・monetization branch への commit/push | coordinator(ディレクター)専任 |

## 統合(ディレクター作業)

1. 各 stream の完了報告を受領。
2. 内容を検証(Trust but verify — 生成物を実際に読んで確認してから採用)。
3. `docs/filmtone/davinci-plugin/monetization/progress.md` に統合結果を記録。
4. owner に完了サマリと次の owner アクション(上表「並列化しない」項目)を提示。
