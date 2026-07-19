# Active Parallel Tasks — MON-6 launch prep (2026-07-19)

計画正本: [`docs/filmtone/davinci-plugin/monetization/launch-parallel-work-plan.md`](../../docs/filmtone/davinci-plugin/monetization/launch-parallel-work-plan.md)

## S1: Release article (JP/EN)
- **Agent:** Claude Code (communicator, opus, background)
- **Completed:** 2026-07-19 JST
- **Status:** 完了
- **Changed Files:**
  - `docs/filmtone/articles/2026-07-19-davinci-resolve-film-damage-release/{note-ja,zenn-ja,medium-en,hashnode-en,behance-case}.md` (新規 5 件)
- **Verification:** ディレクターが note-ja.md を通読・検証済み(禁忌語 grep 結果は agent 側で機構化済み)
- **Notes:** Skill tool はこの agent のツールセットに存在せず、
  `.claude/skills/filmtone-release-articles/SKILL.md` を直接読んで手順に従った。
  標準 5 媒体 JP/EN 完成。Behance のみ visual asset が placeholder(実レンダー待ち)。
  Breath/Weave = 0 件、絶対語 = 0 件、競合名 = 0 件を grep で確認済み。発売日は
  全記事で TBD placeholder。publish/commit なし。

## S2: Owner runbook(Vercel + Polar 設定手順)
- **Agent:** Claude Code (engineer, opus, background)
- **Completed:** 2026-07-19 JST
- **Status:** 完了
- **Changed Files:**
  - `docs/filmtone/davinci-plugin/monetization/mon6-owner-runbook.md` (新規)
- **Verification:** ディレクターが内容通読・検証済み
- **Notes:** 新規判明事項 — (1) Vercel git auto-deploy 無効(private submodule 制約)、
  GitHub Actions workflow か `bunx vercel deploy --prod --yes` が必要。ダッシュボード
  「Redeploy」単独では反映されない。(2) Polar 確認メール本文は編集不可、Custom Benefit
  の Private note(checkout success page + 確認メール + Customer Portal に表示)が唯一の
  差し込み口。(3) **新規ギャップ**: trial 利用者は pkg 本体の入手経路が現状ない
  (Worker は `.license` のみ送付、Polar file benefit は購入者限定) —
  `PKG_DOWNLOAD_URL` の公開ホスト先を owner が判断する必要。(4) Checkout Link に
  $10 discount を preset すれば launch 価格終了時は preset を外すだけで URL 不変・
  再デプロイ不要。

## S3: MON-4 検証手順書(実行なし)
- **Agent:** Claude Code (engineer, opus, background)
- **Completed:** 2026-07-19 JST
- **Status:** 完了
- **Changed Files:**
  - `docs/filmtone/davinci-plugin/monetization/mon4-verification-runbook.md` (新規)
- **Verification:** ディレクターが内容通読・検証済み(hex値・CLI flag・source行番号を照合)
- **Notes:** Gate 3はPolar Sandboxが主経路と判明(実金銭不要)。Gate 2はportfolio側scaffoldの
  commit+Vercel env+redeployが前提でblocked。Gate 4はLicenseStore source確認済みでclock-forward
  手順のdate format bugを自己修正。実行はしていない(prep only)。
