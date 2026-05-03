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

**Status (2026-05-03 JST)**: branch + worktree が一度喪失。再開用 handoff:
`docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
(main checkout 側 — このリポは Native Desktop worktree で見えていない場合は
main の `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/` 側を
参照)。Phase A (core/schema 加算) は完了して verify 通過、Phase B (Electron
renderer + film-lab-ui sweep) が部分完了で worktree 喪失。

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
