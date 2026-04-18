# Filmtone WebGPU Migration — Progress Tracker

**Master plan**: `~/.claude/plans/sequential-thinking-gemini-web-swirling-prism.md`
**Direction principles**: [DIRECTION.md](./DIRECTION.md) — 各 phase chat 開始時に必読
**Direction chat**: 別 chat で orchestration のみ、ここには書き込まない原則

---

## 現在フェーズ

**Phase 0**: ✅ done 2026-04-18(commit は user 承認待ち)
**Pending**: Phase 1 — Foundation + Simple shaders (Day 1)

### Kickoff snippet(新規 chat で貼付)

```
@apps/desktop-film-lab-batch/docs/webgpu-migration/DIRECTION.md と @apps/desktop-film-lab-batch/docs/webgpu-migration/phase-1-handoff.md を読んで Phase 1 を実行してください。
```

### Phase 1 以降の運用

- Git: **自動 commit 禁止**(DIRECTION §7 / life CLAUDE.md §11)。Phase chat は commit msg 案を提示、user が実行
- Phase chat は §10 Decision Defaults を即適用、tactical で迷ったら "【Direction 判断要請】" 書式で direction chat へ
- Phase 完了時、STATUS.md 更新 + 完了報告 1 段落を user に出す

---

## Progress

| Phase | 内容 | Budget | State | Handoff | Commit |
|---|---|---|---|---|---|
| Day 0 | Electron WebGPU 疎通 + Golden Baseline A | 2h | **done** | [phase-0-handoff.md](./phase-0-handoff.md) | pending (user approval) |
| Day 1 | Foundation + Simple shaders (9 本) + Baseline B | 10h | ready | [phase-1-handoff.md](./phase-1-handoff.md) (pre-written + Phase 0 注記付き) | — |
| Day 2 | filmlab.wgsl + composite.wgsl + motion blur | 12h | not started | [phase-2-handoff.md](./phase-2-handoff.md) (pre-written) | — |
| Day 3 | Cross-filter(Hard 除く)+ Export + Ship | 10h | not started | [phase-3-handoff.md](./phase-3-handoff.md) (pre-written) | — |
| Day 4 | 予備(条件付き) | 4h | conditional | (Phase 3 終了時に判断) | — |

**Total budget**: 38h(Day 0 = 2h + Day 1-3 = 32h + Day 4 予備 = 4h)

**Handoff 事前執筆**: Phase 1-3 は direction chat が skeleton まで pre-write 済み。各 phase chat は skeleton を実行しつつ、末尾の "Known gotchas" / 次 phase の Entry 欄を実態に合わせて追記。

---

## Key artifacts

- `test/golden/baseline-A/` — 現行 WebGL 実出力 PNG 80 枚(Phase 0 で生成)
- `test/golden/baseline-B/` — post-hoc linearized PNG 80 枚(Phase 1 で生成)
- `test/golden.harness.ts` — Playwright ベース PSNR 計測 harness(Phase 0 で作成)
- `packages/film-lab-renderer/src/webgpu/` — 新規 WebGPU backend(Phase 1-3)
- `packages/film-lab-renderer/src/webgl/` — 既存 WebGL backend(Phase 1 退避)

---

## Decisions log

各 phase で戦略変更が必要になった場合、**まず direction chat に戻る**。ad-hoc に決めて進めない。直近の確定事項は [DIRECTION.md](./DIRECTION.md) §1 を正本、tactical 回答は [DIRECTION.md](./DIRECTION.md) §10 を正本とする。

| 日付 | 決定 | 変更理由 |
|---|---|---|
| 2026-04-18 | 初期計画確定 (D1-D5) | master plan 通り |
| 2026-04-18 | Phase 0 T1 実施方法: 手動 DevTools + adapter-info.json 手書き(Option 3 ハイブリッド) | ゲート判定は最短ルート優先、自動化と結合しない |
| 2026-04-18 | Phase 0 commit 方針: Case A → 1 commit、Case B → 2 commit(main.ts flag と infra 分離) | production 変更は独立 commit で review 容易性担保 |
| 2026-04-18 | Phase 1-3 handoff を pre-write、全 tactical 判断を DIRECTION §10 に集約 | ユーザー判断コスト最小化(User interaction budget ≤ 8 msg) |

---

## Regressions log

(phase chat が視覚 regression / perf 劣化を発見したらここに追記)

| Phase | Date | Preset / Image | Detail | Action |
|---|---|---|---|---|

---

## Progress Notes

(phase chat が overrun / 工数超過 / dep 追加を随時追記)

### Phase 0 — 2026-04-18(完了)

- T1: **Case A** 確定 — adapter: `apple / metal-3`, features: 15, limits: 32 keys, deviceOk: true, flag 不要
- T1 実施手段: 手動 DevTools ではなく **CDP automation**(`--remote-debugging-port=9222` + Bun WebSocket → `Runtime.evaluate`) — self-XSS warning 回避のため。所要 2min、Option 3 ハイブリッドの精神は維持(ゲート判定のみに自動化を限定)
- T2 Stream B: `bun add -d playwright @playwright/test pixelmatch pngjs @types/pixelmatch @types/pngjs` 成功、`test:golden` + `test:golden:baseline-a` script 追加
- T2 Stream C: 10 synthetic PNG 生成(1280×720, seed 0xC0FFEE, 5 categories: highlight/high-key/low-key/midtone/skin 各 2)
- T2 Stream D: `App.tsx` に `window.__filmtoneTest` hook(?__test=1 + prod-gated)+ harness + spec + psnr util
- T2 bugs fixed: ESM `__dirname` → `fileURLToPath(import.meta.url)`、manifest key `filename` vs `path` の不整合(両方受ける形)
- Baseline A: 80 枚 capture(53.7s、1 pass)→ PNG 131MB → JPEG Q=95 変換で 19MB(size gate の 50-200MB 帯)
- Commit: Case A なので 1 commit 予定、ユーザー承認待ち
- User タッチポイント実績: 2 回(初期の起動確認 + paste 諦め → CDP 切替判断)、plan 想定の 3 回以内

---

## Last updated

2026-04-18 Phase 0 完了。Phase 1 ready。
