# 03 Migration And Concurrent Lanes

Parent index:
[filmtone-native-desktop-transition-plan-2026-05-03-jst.md](../filmtone-native-desktop-transition-plan-2026-05-03-jst.md)

## Migration Strategy

Use a parallel Native Desktop v2 lane.

```text
current Electron Desktop
  remains shipping rail
  keeps urgent export/color fixes

Native Desktop v2
  starts as a thin macOS app
  earns parity through vertical slices
  becomes default only after quality gates pass
```

The migration is not a rewrite of every file in one pass. It is a sequence of
working product slices. Each slice must either improve native product quality
or remove a concrete blocker.

## Concurrent Work Streams

Native Desktop v2 と並行して走る lane。Phase plan の各 Phase の deliverable
や acceptance gate に直接影響するため、ここで明示する。これらの lane は
**main checkout 側で進行**し、本 worktree (`feature/native-desktop-plan`) に
は別タイミングで合流する。

## Desktop Look Unification (lane: `feature/desktop-look-unification`)

**Goal**: Desktop の製品面から `Preset` の語彙を消し、Edit / Export / Metadata /
Batch session を `Look` 起点に統一する。本質はユーザーが見える製品の語彙統一
(コード識別子整理ではない、副次的に伴う)。

vocabulary canonical:
`life docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`

**Status (2026-05-03 JST late evening 更新)**: 一度 worktree 喪失 → 再開 chat B
起動 → **branch 上で Phase A + Phase B 両方 landed (main 未 merge)**。Native
Desktop v2 Phase 1c (chat A、worktree `filmtone-native-desktop-plan`) は
**Case B 継続** (sidecar emitter は Look canonical only)。

- handoff (canonical):
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
  (main checkout 側、§0 Resolution に landing 詳細)
- 元 plan: `~/.claude/plans/desktop-look-unification-bright-dusk.md`
- chat B worktree path:
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification`
- chat B branch: `feature/desktop-look-unification` (新規作成、main `732a273` から)
- **Phase A** (core/schema 加算): commit `1f99d68`、13 files +424/-9。
  `BaseLookName` / `BASE_LOOKS` / `BASE_LOOK_BUTTONS` /
  `FILMTONE_DEFAULT_BASE_LOOK` / `findMatchingBaseLook` aliases、
  `LOOK_RECIPE_VERSION` / `lookIdForBaseLook` / `LOOK_ID_BY_BASE_LOOK`、
  `filmLookGradeInputSchema` に `lookId` / `lookVersion` optional 追加、
  `normalizeFilmLookGradeInputIdentity()`、`createDefaultFilmLookGradeProps`
  / `buildGradeJsonPayload` を dual emit、`batch-pipeline` discriminator 拡張
  + normalize 適用、20 新規 tests。
- **Phase B** (renderer + UI sweep): commit `fd9ddd2`、23 files +534/-415。
  i18n 8 keys 値書き換え + 7 new keys、`filmLabUiContract` /
  `filmLabPanelTokens` / `LookSearchSelect` canonical + deprecated alias /
  `film-lab-reducer` (state.baseLook + APPLY_BASE_LOOK / preserveBaseLook) /
  `FilmLabControlPanelCore` 全 ref / `index.ts` re-export、Desktop
  App.tsx canonical rename、`batch-session.ts` parser fallback +
  writer single emit、`export-metadata-session.ts` `METADATA_LOOK_SOURCES` 拡張
  + `parseFilmtoneExportSessionV1` で `look.source` 正規化 + legacy 昇格、8 test
  files fixture 更新。
- **main へは未 merge** (2026-05-03 JST late evening 時点)。Native Desktop v2
  Phase 1b / 1c chat A は main 上の状態を見るため、現在は **Case B (Look
  canonical only) 継続**。main merge 完了後に user 経由で chat A に「Case A
  切替可」を伝達 → emitter dual emit に変更 (chat 中観測時は同 chat 内対応)。
- **Native Desktop ユーザー配布 (Phase 5 release rail 切替) 前には dual emit
  (Case A) 化が必須**。Look Unification main merge + emitter dual emit 切替
  + Electron reader catch-up が release blocker (Phase 5 acceptance gate)。
  vocabulary 不統一のまま public release しない方針 (06 risk row、Phase 5
  release gate)。

### chat B 着手時に確定した方針 (本 PR スコープ)

| # | 領域 | 方針 |
|---|---|---|
| 1 | `filmLabUiContract.ts` slot 名 (`beforePresets` → `beforeLooks` 等) | **alias 残さず一気に rename**。consumer (`FilmLabControlPanelCore.tsx` + Desktop `App.tsx` 経由 props) は本 PR で全て更新、TS 型エラーで漏れ即検出 |
| 2 | `batch-session` writer | **`batchLookChoice` 単独 emit**。Electron 専用 userData なので dual emit 不要。parser fallback (`o.batchLookChoice ?? o.batchPresetChoice`) で旧 session 読み込みは引き続き可能 |
| 3 | テスト fixture | 既存 `lookSource: "preset"` fixture は **parser fallback regression** 用に残す。新規 fixture は `"builtInLook"` canonical。dual coverage |
| 4 | iOS messages.ts 参照書き換え | **本 PR では実施しない (別 PR)**。i18n 値書き換え (`controls.presets` 値 = "Look") で iOS が見る文字列は自動 Look 化されるが、`messages.ts:75 presetRowAriaLabel` / `messages.ts:227-230` の **キー名参照** 書き換えは別 PR |

これらは Look Unification handoff §4 の方針と整合 (本 doc は Native Desktop 側
からの参照用 summary)。

**Native Desktop v2 が依存する成果物** (Look Unification が main へ landed
した時点で利用可):

- `film-lab-core` の Look-first canonical 名 (旧 Preset 名は alias で残る、
  schema 加算のみ):
  - `BaseLookName = PresetName`、`BASE_LOOKS = PRESETS`、
    `BASE_LOOK_BUTTONS = PRESET_BUTTONS`、
    `FILMTONE_DEFAULT_BASE_LOOK = FILMTONE_DEFAULT_BASE_PRESET`、
    `findMatchingBaseLook = findMatchingPreset`
  - `LOOK_RECIPE_VERSION = PRESET_VERSION`、
    `lookIdForBaseLook = lookIdForPreset`、
    `LOOK_ID_BY_BASE_LOOK = LOOK_ID_BY_PRESET`
  - `filmLookGradeInputSchema` に optional `lookId` / `lookVersion` 追加
  - `normalizeFilmLookGradeInputIdentity()` で identity 不一致 throw
  - `gradeMatchesBaseLook = gradeMatchesPreset` alias
- Desktop sidecar dual emit (legacy + Look 両方を含む):
  - `buildGradeJsonPayload` が `lookId` / `lookVersion` を追加 emit
  - `batch-pipeline` discriminator は `("lookPresetId" in o || "lookId" in o)`
- Batch session contract (additive):
  - `FilmLabBatchSessionV1` の **on-disk shape は固定** (Data Contract の
    "additive only" 制約準拠)
  - parser は `o.batchLookChoice ?? o.batchPresetChoice` で fallback
  - writer は `batchLookChoice` を canonical
- `lookSource` enum:
  - `METADATA_LOOK_SOURCES` に `"builtInLook"` を canonical 追加
  - parser は legacy `"preset"` を `"builtInLook"` として読む
- i18n: `messages/en.json` / `ja.json` の `controls.presets` 系の **値だけ**
  Look 化 (旧キーの値書き換え + 新 `controls.looks` キー追加)

**iOS lane の catch-up は別 PR** (本 plan / Look Unification PR どちらの
scope 外):

- `apps/capacitor-film-lab-ios/src/lib/messages.ts` の `presetRowAriaLabel` 等
  の参照書き換え
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift:1580`
  "Preset Strength"

## Native Desktop v2 への影響 (Phase 別)

| Phase | Look Unification 着地済の場合 | 着地前の場合 |
|---|---|---|
| Phase 0 (skeleton) | 影響なし (UI / sidecar 触らない) | 同左 |
| Phase 1 (vertical slice) | macOS sidecar emitter は **dual emit を継承** (legacy + Look)。`lookId` / `lookVersion` を吐き、`normalizeFilmLookGradeInputIdentity` を通す。Electron 側 reader 互換が確保されている | macOS sidecar emitter は Look canonical (`lookId` / `lookVersion`) のみで書く。Look Unification 着地後に Electron 側が両読みできるようになる |
| Phase 2 (color/render backbone) | 生成 Swift の Look 名 alias を generator に追加可能 (generator multi-target に拡張) | 生成器拡張は Look Unification 着地待ち |
| Phase 3 (native UI) | i18n 値は既に Look 化済。macOS app が `messages/*.json` を消費するなら追加作業なし | macOS app は自前で Look 文言を持ち、後で messages へ統合 |
| Phase 4 (batch / session) | `FilmLabBatchSessionV1` parser fallback / `batchLookChoice` writer 仕様に従う | 同上、ただし旧 `batchPresetChoice` のみ書く |
| Phase 5 (release / QA) | public copy も Look 統一済、screenshot / release notes も Look | release 前に Look Unification を着地必須 |

**Phase plan に対する追加制約**:

- Phase 1 / Phase 2 acceptance gate に「Look Unification の sidecar contract と
  bit-互換であること」を含める (Look Unification 着地後)。
- Phase 5 の release に進む前に Look Unification が main へ landed していること
  を gate 条件にする (vocabulary 不統一のまま public release しない)。
- Phase 1 着手時に Look Unification の main 着地状況を確認:
  - `git log --oneline main | grep -i "look unification\|baselook"` で commit 有無
  - `packages/film-lab-core/src/index.ts` で `BASE_LOOKS` export 有無
  - sidecar reader (`grade-io.ts` / `batch-pipeline.ts`) の discriminator が
    `lookId` を見ているか
