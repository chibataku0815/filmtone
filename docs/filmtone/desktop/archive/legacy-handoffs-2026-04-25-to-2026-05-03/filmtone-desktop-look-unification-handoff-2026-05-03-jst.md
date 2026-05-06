# Filmtone Desktop Look Unification — Handoff

> ⚠️ **WITHDRAWN — 2026-05-04 撤回 (domain misunderstanding)**
>
> 本 handoff の前提「Filmtone Desktop の `Preset` 用語を `Look` canonical に rename / unification する」は撤回。**Look = Stone / Urban (Creative LUT Pack 01) の上位概念**であり、Preset (curve/grade 土台) とは別レイヤーの並存概念であることが iOS Pack 01 確定 (2026-05-01) と user 確認 (2026-05-04) で判明。本 doc を継承した後続 PR (filmtone #2 / portfolio #47) は両方 close。本 doc 内の vocab rename 計画は **後続作業の根拠にしない**。
>
> ただし PR #1 (`6757dcf`) として実 merge された code 変更 (Phase A `1f99d68` + Phase B `fd9ddd2`) は historical record として残置。merged 内容のうち `BaseLookName` / `BASE_LOOKS` / `lookPresetId` 等の **誤前提に基づく追加 alias** は別 chat で alias purge PR を流す予定。
>
> 詳細: `~/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/feedback_filmtone_preset_vs_look_domain.md`
>
> ---

Date: 2026-05-03 JST  
Branch (recovered): `feature/desktop-look-unification`  
Worktree (recovered): `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification`  
Plan file: `/Users/chibatakumi/.claude/plans/desktop-look-unification-bright-dusk.md`

> **Status (2026-05-03 JST late evening): Phase A + Phase B landed on the recovered worktree.**
> 詳細は §0 Resolution を参照。本ドキュメント §1〜§11 は **再開前の調査・設計記録**
> として保存している（worktree 喪失前の試行記録 + 第 3 版 scope 確定の根拠）。

## 0. Resolution (2026-05-03 JST late evening)

### 0.1 Recovery + landed commits

`feature/desktop-look-unification` worktree を main `732a273` (Backlight Veil 反映済) から
**新規作成** で再構築し、§4 / §5 を再実装した。reflog / `fsck` でも喪失 commit は
復元不可だったので、本 doc + plan doc + Phase 1b §6.5 / §10 を引きながら full
re-implementation を行った。

| Phase | commit | files | +/- | 内容 |
|---|---|---|---|---|
| **A** (core/schema 加算) | `1f99d68` | 13 | +424 / -9 | `BaseLookName` / `BASE_LOOKS` / `BASE_LOOK_BUTTONS` / `FILMTONE_DEFAULT_BASE_LOOK` / `findMatchingBaseLook` / `LOOK_RECIPE_VERSION` / `lookIdForBaseLook` / `LOOK_ID_BY_BASE_LOOK` / `gradeMatchesBaseLook` aliases、`filmLookGradeInputSchema` に `lookId` / `lookVersion` optional 追加、`normalizeFilmLookGradeInputIdentity()` (dual identity strict equality)、`createDefaultFilmLookGradeProps` / `buildGradeJsonPayload` を dual emit、`batch-pipeline` discriminator 拡張 + normalize 適用、20 新規テスト |
| **B** (renderer + UI sweep) | `fd9ddd2` | 23 | +534 / -415 | i18n 8 keys 値書き換え + 7 新 keys + pre-existing `mode.hint` drift 修正、`filmLabUiContract` / `filmLabPanelTokens` / `LookSearchSelect` canonical + deprecated alias / `film-lab-reducer` (state.baseLook + APPLY_BASE_LOOK / preserveBaseLook) / `FilmLabControlPanelCore` 全 ref / `index.ts` re-export、Desktop App.tsx (`batchPresetChoice` 37 / `canvasPreset` 4 / `batchGradeStateFromPreset` / `lookSource: "preset"` 7) → canonical、`batch-session.ts` parser fallback `batchLookChoice ?? batchPresetChoice` + writer single emit、`export-metadata-session.ts` `METADATA_LOOK_SOURCES` 拡張 + `parseFilmtoneExportSessionV1` で `look.source` 正規化 + `promoteLegacyLookSidecarFields()` で legacy `look.batchPresetChoice` 昇格、`globals.css` rename、8 test files fixture 更新 |

base: main `732a273` `feat(ios): add Backlight Veil optical filter as adjustment param (Phase 1b/1c)`

### 0.2 Verify gate 結果 (両 phase 終了時点)

| gate | 結果 |
|---|---|
| `bun run build:core` | ✓ |
| `bun run typecheck:shared` | ✓ clean |
| `bun run typecheck:desktop` | ✓ clean |
| `bun test packages/film-lab-core packages/film-lab-ui` | 205 pass / 2 fail (pre-existing `ios-swift-payload.test.ts` `CONTRACT_DEFAULT_KEY_ORDER` のみ、Backlight Veil drift、本 PR 無関係) |
| Desktop `bunx vitest run` | 39 files / 286 pass / 1 skipped / **0 fail** (Phase A 時点 1 fail だった `BatchTabPanel.test.tsx` i18n drift も同時解消) |
| `bun run verify:desktop` | ✓ (typecheck + smart-look smoke 5/5) |
| `bun run check:filmtone-copy` | ✓ Filmtone copy quality check passed |
| `git diff --check` | ✓ no whitespace |
| iOS `bun test src/` | ✓ 14 pass / 0 fail |
| life `check-filmtone-release-truth.sh` | ✓ |
| life `check-filmtone-ios-truth.sh` | ✓ |

### 0.3 §2 第 3 版 (locked-in) との差分監査

| 項目 | locked-in | 着地 | 差分 |
|---|---|---|---|
| core/schema 加算 (BaseLook aliases / lookId dual emit) | ✓ Phase A | ✓ commit `1f99d68` | — |
| film-lab-ui の component / reducer / 識別子 rename | ✓ Phase B | ✓ commit `fd9ddd2` | — |
| Electron renderer の識別子 rename (batchPresetChoice / canvasPreset / batchGradeStateFromPreset) | ✓ Phase B | ✓ commit `fd9ddd2` | — |
| i18n 値変更 (Preset → Look / プリセット → ルック) | ✓ Phase B | ✓ commit `fd9ddd2` | — |
| iOS messages.ts の値経由参照は値書き換えで自動カバー | ✓ Phase B | ✓ (旧 keys 残し、値だけ書き換え) | — |
| iOS messages.ts:75 `presetRowAriaLabel` 参照書き換え | ✗ 別 PR | ✗ (touched せず) | — |
| iOS Swift `FilmtoneStrings.swift:1580` "Preset Strength" | ✗ 別 PR | ✗ (touched せず) | — |
| batch-session / lookSource enum の parser fallback | ✓ Phase B | ✓ (`batchLookChoice ?? batchPresetChoice` + `METADATA_LOOK_SOURCES` に `"builtInLook"` 追加 + parser 正規化) | — |
| schema version bump | ✗ 禁止 | ✗ (`FilmLabBatchSessionV1` `version: 1` 維持、additive only) | — |
| `PresetStrip.tsx` (output format chooser) | ✗ 対象外 | ✗ | — |
| Smart Look `BaselineCandidate.basePreset` / Creative Pack 01 `CreativePackLook.basePreset` | ✗ 別概念、対象外 | ✗ | — |
| 生成済 Swift / generator の Look-first emit | ✗ 別 PR | ✗ (touched せず) | — |

### 0.4 OQ (§9) の最終決定 (locked-in)

| OQ | 決定 |
|---|---|
| #1 PresetBar component | 放置 (Desktop / iOS で未使用、export 維持で alias 不要) |
| #2 `filmLabUiContract.ts` slot 名 alias | **alias 残さず一気に rename**。consumer (FilmLabControlPanelCore.tsx + Desktop App.tsx) は本 PR で全更新。portfolio Web wrapper は submodule bump 時に併せて更新する必要あり (locked-in #2) |
| #3 batch-session writer | **`batchLookChoice` 単独 emit** (Electron 専用 userData、dual emit せず、locked-in #3) |
| #4 (iOS messages.ts 参照) | **本 PR では実施しない** (§4.6 が実装上正本、locked-in #5) |
| #5 テスト fixture | 既存 `lookSource: "preset"` を fallback regression として残し、新規 `"builtInLook"` を canonical fixture とする (Phase B test sweep で実施) |

### 0.5 残タスク (本 PR の外、別 lane)

| # | タスク | 担当 |
|---|---|---|
| 1 | `feature/desktop-look-unification` を `git push -u origin` | user |
| 2 | main への PR 作成 + merge | user |
| 3 | Phase 1b chat A への伝達 (main merged → Case A 切替可) | user (chat 間直接通信なし) |
| 4 | portfolio (`chibatakumi-portfolio`) の Web wrapper 更新 (slot ids `beforePresets` → `beforeLooks` 等、`onPresetChange` → `onBaseLookChange`、context API `activePreset` → `activeBaseLook`) → submodule bump | 別 PR (portfolio repo) |
| 5 | iOS messages.ts:75 `presetRowAriaLabel: "Film presets"` rename | 別 PR (iOS catch-up) |
| 6 | iOS Swift `FilmtoneStrings.swift:1580` "Preset Strength" rename | 別 PR (Swift catch-up、generator 経由) |
| 7 | generator (`scripts/generate-filmtone-ios-swift.ts`) Look-first Swift alias emit | 別 PR (generator 改修 main 取り込み後) |
| 8 | LP / FAQ / marketing copy の "presets" 単語 (heroSubtitle / faqQpresets 等) | LP rewrite 別 lane |
| 9 | export status keys `currentExportLookPreset` 等の `{preset}` template variable rename | 別 PR (variable name + consumer 同時更新が必要) |
| 10 | `ios-swift-payload.test.ts` `CONTRACT_DEFAULT_KEY_ORDER` Backlight Veil drift fix | 別 lane (本 PR 無関係) |

### 0.6 Native Desktop v2 (Phase 1b) との連携状況

- Phase 1b master handoff (`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md`) §6.5 / §10 の Case A vs Case B 判定:
  - 本 PR の Phase A 着地 grep (`BASE_LOOKS` export / `lookId` discriminator) は **`feature/desktop-look-unification` branch 上では PASS**、ただし **main 上では FAIL** (まだ merge されていない)
  - Phase 1b chat A は main 上の状態を見るため、現在は **Case B (Look canonical only) 継続**
  - main merge 完了後に user 経由で Phase 1b chat A に「Case A 切替可」を伝達 → emitter dual emit に変更
- Phase 1b 側の sidecar reader (`export-metadata-session.ts` / `parseFilmtoneExportSessionV1`) は本 PR の `promoteLegacyLookSidecarFields()` で legacy `batchPresetChoice` field を読めるので、**Phase 1b 着手前に作成された旧 Filmtone 出力 sidecar も互換**

### 0.7 Recovery 教訓 (今後同じ事故を起こさない)

1. **Phase A 完了直後に user に commit を依頼する** — 本 recovery では Phase A 完了直後の commit を取った (handoff §8 に従い、worktree 再喪失リスクを最小化)
2. **handoff doc の行番号 (e.g. `schema.ts:179-181`) は worktree 喪失前の記憶ベース** — 再開時は必ず現行 surface で grep / Read 再確認 (`feedback_verify_before_quoting_handoff` 適用)
3. **scope を chat 中で再議論しない** — §2 第 3 版 (option 1) を locked-in として固定し、Phase B sweep 中に "縮退" / "後送り" しない (`feedback_no_silent_stream_redefine` 適用)
4. **portfolio Web wrapper の更新は別 PR** — alias なし方針 (locked-in #2) のため、本 PR merge 直後は wrapper が壊れる。portfolio 側の bump PR を併せて作る必要あり

---

## なぜこのドキュメントが必要か (Resolution 前の文脈、保存)

Desktop の "Preset → Look" 統一作業をこのチャットで進めていたが、`feature/desktop-look-unification` の **worktree が削除され、branch も消滅した** (recovery 未確認)。チャット中の編集は git に残っていない。次の chat (または同じ chat の再起動) で巻き戻しなく再開できるよう、設計判断・実装内容・課題を全部書き出す。

## 1. オリジナルの依頼 (本質)

> Desktop の製品面から `Preset` の語彙を消して、Edit / Export / Metadata / Batch session を `Look` 起点に統一する。

**本質はユーザーが見える製品の語彙統一**。コード識別子整理ではない (が、副次的に伴う)。

vocabulary canonical: `life docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`

## 2. スコープ判断の進化 (重要 — 同じ間違いを繰り返さない)

このチャット中で 3 回スコープ判断を見直した。

### 第 1 版 (元 plan、ユーザーが pasted)
- Desktop 全面 (TSX renderer / 共有 UI / sidecar / batch session) の rename
- iOS と "match"

### 第 2 版 (Claude の修正、後に **誤り** と指摘される)
ユーザーから「Electron は SwiftUI に置き換える計画あり」と聞いて、Electron renderer の sweep を「捨てる作業」と判断し scope out。core/schema 加算 + sidecar dual-emit のみに縮小。

→ **この判断はユーザーから「本質からズレている」と指摘**:
> 最初の依頼はプリセットからLOOKに統合するということでしたよね？

→ 教訓: SwiftUI 移行を理由に現行 Electron の品質作業を捨てるヘッジは間違い。Electron は **製品品質 gate を越えるまで release rail として残る** (native desktop transition plan §Migration Strategy l.45-48 / l.215-216) ので、その間ずっと Preset 表示のままになる = 統合されていない。

### 第 3 版 (確定方針)
ユーザーが option 1 (現 worktree に Electron renderer の Look 文言 sweep を追加) を選択。

**スコープ確定**:
- core/schema 加算 (BaseLook aliases / lookId dual-emit)
- film-lab-ui の component / reducer / 識別子 rename
- Electron renderer の識別子 rename (batchPresetChoice / canvasPreset / batchGradeStateFromPreset)
- i18n 値変更 (Preset → Look / プリセット → ルック)
- iOS messages.ts の i18n 参照を新キーへ
- batch-session / lookSource enum の parser fallback 追加
- iOS Swift 側 (`FilmtoneStrings.swift:1580` "Preset Strength" / `messages.ts:75` `presetRowAriaLabel`) は別 PR

## 3. Native Desktop Transition Plan との整合 (制約)

`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/filmtone-native-desktop-transition-plan-2026-05-03-jst.md` (branch `feature/native-desktop-plan`) の要件:

| 制約 | 出典 | 反映 |
|---|---|---|
| Avoid schema version bumps until a product need requires them | §Data Contract l.199-201 | sidecar / batch session は **加算のみ**、version bump しない |
| 生成 Swift の手編集禁止 | l.75-76 | Swift 側 BaseLook alias は別 PR (生成器経由)、本 PR は対象外 |
| Native Desktop は既存 Electron 製 sidecar を読む | l.179-187 | sidecar dual-emit (legacy + Look) で互換 |
| 生成 Swift と film-lab-core を contract source として消費 | l.179-187 | film-lab-core に Look-first 正規名を加算 (`BaseLookName` / `BASE_LOOKS` etc.) |

## 4. 設計判断 (固まったもの)

### 4.1 core/schema 層 (加算のみ、rename しない)

| 場所 | 追加 |
|---|---|
| `packages/film-lab-core/src/presets.ts` | `BaseLookName = PresetName`、`BASE_LOOKS = PRESETS`、`BASE_LOOK_BUTTONS = PRESET_BUTTONS`、`FILMTONE_DEFAULT_BASE_LOOK = FILMTONE_DEFAULT_BASE_PRESET`、`findMatchingBaseLook = findMatchingPreset` |
| `packages/film-lab-core/src/look-ids.ts` | `LOOK_RECIPE_VERSION = PRESET_VERSION`、`lookIdForBaseLook = lookIdForPreset`、`LOOK_ID_BY_BASE_LOOK = LOOK_ID_BY_PRESET`。**schema を import しない** (循環依存回避) |
| `packages/film-lab-core/src/schema.ts` | `filmLookGradeInputSchema` に optional `lookId` / `lookVersion` 追加。`normalizeFilmLookGradeInputIdentity()` 新設 (両方ある時は **strict equality**、不一致は throw)。`gradeMatchesBaseLook = gradeMatchesPreset` alias |
| `packages/film-lab-core/src/defaults.ts` | `createDefaultFilmLookGradeProps()` を **dual emit** (legacy + Look 両方) |
| `packages/film-lab-core/src/index.ts` | 新 symbol を public re-export |

### 4.2 sidecar / Desktop renderer 層 (dual emit + parser fallback)

| 場所 | 変更 |
|---|---|
| `apps/desktop-film-lab-batch/src/renderer/grade-io.ts` | `buildGradeJsonPayload` を dual emit |
| `apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts` | discriminator を `("lookPresetId" in o \|\| "lookId" in o)` に拡張、parsed 後に `normalizeFilmLookGradeInputIdentity()` 適用 |
| `apps/desktop-film-lab-batch/src/renderer/batch-session.ts` | `FilmLabBatchSessionV1` の **on-disk shape は固定** (transition plan §Data Contract 制約)、parser は `o.batchLookChoice ?? o.batchPresetChoice` で fallback、writer は `batchLookChoice` を canonical として書く。version: 1 のまま |
| `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts` | `METADATA_LOOK_SOURCES` に `"builtInLook"` を canonical として追加、parser は legacy `"preset"` を `"builtInLook"` として読む。writer は `"builtInLook"` を書く |

### 4.3 film-lab-ui 層 (識別子刷新 + alias 残す)

| 場所 | 変更 | alias |
|---|---|---|
| `packages/film-lab-ui/src/PresetSearchSelect.tsx` | `LookSearchSelect` を canonical export、props `activeLook` / `onLook` | `PresetSearchSelect` / `PresetSearchSelectProps` / `activePreset` / `onPreset` を deprecated alias として再 export |
| `packages/film-lab-ui/src/film-lab-reducer.ts` | State `baseLook`、Action `APPLY_BASE_LOOK` (`lookName` / `params`)、`SET_PARAM.preserveBaseLook`、`APPLY_PARAMS.baseLook`、`createInitialState(initialBaseLook)` | 当面 alias なし (consumer 全部更新する想定) |
| `packages/film-lab-ui/src/index.ts` | 両名を re-export | ✓ |
| `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx` | i18n キー `controls.looks` / `controls.lookStrength` 経由、`activeSlotState.baseLook` 参照、`dispatch({ type: "APPLY_BASE_LOOK", lookName, params })` | — |

注意: `packages/film-lab-smart-look/src/index.ts` の `BaselineCandidate.basePreset` と `packages/film-lab-core/src/creative-pack-01.ts` の `CreativePackLook.basePreset` は **別概念** (Smart Look baseline / Creative Pack 01 look chip)、本 PR の対象外。

### 4.4 i18n (en/ja) — 値だけ書き換え + 新キー追加

旧キーは **値だけ** Look に書き換え (即時 UI 反映、iOS messages.ts の参照も自動的に新文言になる)。新キー (`controls.looks`, `controls.lookSelectTriggerLabel`, `controls.lookStrength` 等) を **forward-compat で追加**。

| 旧キー | 旧値 (en/ja) | 新値 (en/ja) |
|---|---|---|
| controls.presets | Presets / プリセット | Look / ルック |
| controls.presetSelectTriggerLabel | Choose preset / プリセットを選ぶ | Choose Look / ルックを選ぶ |
| controls.presetSearchEmpty | No presets … / 一致するプリセット… | No Looks … / 一致するルック… |
| controls.presetIntensity | Film Amount / フィルム量 | Look Strength / ルックの強さ |
| shortcuts.presetSelect | Select preset / プリセットを選択 | Select Look / ルックを選択 |
| shortcuts.presetSlider | Blend film preset … | Blend Look vs neutral … |
| (BatchTabPanel) presetQuickLabel | Preset (quick) / プリセット（クイック） | Look (quick) / ルック（クイック） |
| (BatchTabPanel) presetSelectAria | Preset used for export / 書き出しに使う Filmtone プリセット | Look used for export / 書き出しに使う Filmtone ルック |

新キー:
- `controls.looks` / `controls.lookSelectTriggerLabel` / `controls.lookSearchPlaceholder` / `controls.lookSearchEmpty` / `controls.lookStrength`
- `lookQuickLabel` / `lookSelectAria` (BatchTabPanel)

### 4.5 PresetStrip は対象外

`apps/desktop-film-lab-batch/src/renderer/batch-tab/PresetStrip.tsx` の `presetPhotoWebJpeg` / `presetPhotoMasterJpeg` / `presetPhotoArchivePng` / `presetVideoDefault` / `presetCustom` は **output format chooser** (encoder preset)、film look ではない。SwiftUI Desktop 側で再設計予定なので本 PR で触らない。

### 4.6 iOS scope

- iOS TS messages.ts (`apps/capacitor-film-lab-ios/src/lib/messages.ts:227-230`) — `filmLab.controls.presets` 等を参照。本 PR では旧キーの値を Look に書き換えるだけで対応 (参照変更は別 PR)。
- iOS Swift `FilmtoneStrings.swift:1580` "Preset Strength" — 別 PR (Swift 側 catch-up)
- iOS TS `messages.ts:75` `presetRowAriaLabel: "Film presets"` — 別 PR

## 5. このチャットで実際に編集した内容 (失われた)

git に残っていない。再現用の記録。

### Phase A (core/schema 加算) — 完了して verify 通過していた

11 files changed, +301/-7:
- `packages/film-lab-core/src/presets.ts` — alias 追加
- `packages/film-lab-core/src/look-ids.ts` — alias 追加
- `packages/film-lab-core/src/schema.ts` — `lookId` / `lookVersion` optional + `normalizeFilmLookGradeInputIdentity` + `gradeMatchesBaseLook`
- `packages/film-lab-core/src/defaults.ts` — dual emit
- `packages/film-lab-core/src/index.ts` — re-export 追加
- `packages/film-lab-core/src/look-ids.test.ts` (新規) — alias identity tests (5 件)
- `packages/film-lab-core/src/schema.test.ts` — +6 tests (legacy-only / dual-match / dual-mismatch / normalize round-trip)
- `packages/film-lab-core/src/filmtone-defaults.test.ts` — +1 alias identity test
- `apps/desktop-film-lab-batch/src/renderer/grade-io.ts` — dual emit
- `apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts` — discriminator + normalize 適用
- `apps/desktop-film-lab-batch/src/renderer/grade-io.test.ts` (新規 vitest) — 7 tests

検証通過:
- `bun run build:core` ✓
- `bun run typecheck:shared` ✓
- `bun run typecheck:desktop` ✓
- `bun run verify:desktop` ✓
- `bun run check:filmtone-copy` ✓
- 新規テスト 64 件すべて pass、Desktop 関連 vitest 42 件すべて pass
- 既存 `ios-swift-payload.test.ts` は pre-existing failure (Backlight Veil commit 2c8e15d で `CONTRACT_DEFAULTS` に追加された haloPrism* / optical* キーが `CONTRACT_DEFAULT_KEY_ORDER` に未反映、本 PR と無関係 — 親 main の dirty `M scripts/generate-filmtone-ios-swift.ts` がそれを直す lane)

### Phase B (Electron renderer + film-lab-ui sweep) — 部分完了で worktree 喪失

完了した編集 (失われた):
- `messages/en.json` — 旧 controls キー値を Look 化、新 look* キー追加、shortcuts も更新、BatchTabPanel 系も更新
- `messages/ja.json` — 同上 (ルック)
- `packages/film-lab-ui/src/PresetSearchSelect.tsx` — `LookSearchSelect` を canonical 関数として export、`activeLook` / `onLook` props、末尾に `PresetSearchSelect` deprecated wrapper 関数を残す
- `packages/film-lab-ui/src/index.ts` — `LookSearchSelect` / `PresetSearchSelect` 両 export
- `packages/film-lab-ui/src/film-lab-reducer.ts` — State `baseLook`、Action `APPLY_BASE_LOOK`、`preserveBaseLook`、`APPLY_PARAMS.baseLook`、`createInitialState(initialBaseLook)`、内部 helper の slot 参照すべて

`bun run check:filmtone-copy` は i18n 編集後に pass 確認済み。typecheck はまだ走らせていなかった (consumer 更新前で半分壊れた中間状態)。

未着手だった作業:
- `FilmLabControlPanelCore.tsx` の reducer 呼び出し更新 (`dispatch({ type: "APPLY_PRESET", ... })` → `APPLY_BASE_LOOK`、`activeSlotState.basePreset` → `baseLook` 参照)
- `filmLabUiContract.ts` の `FILM_LAB_PRESET_PRIMARY_SURFACE_ID` / section id `"presets"` / slot `beforePresets` / `afterPresets` / `renderAfterPresets`
- `filmLabPanelTokens.ts` の `filmLabPresetSectionDividerBlock`
- Desktop renderer の `batchPresetChoice` (47 refs) / `canvasPreset` (10 refs) / `batchGradeStateFromPreset` (8 callers) 全 rename
- `lookSource` enum `"preset"` → `"builtInLook"` + parser fallback
- `batch-session.ts` parser fallback (`o.batchLookChoice ?? o.batchPresetChoice`)
- iOS messages.ts の参照書き換え (本 PR でやるか別 PR か未確定)
- `filmtone-default-state.test.ts` 更新 (`state.slotA.basePreset` → `baseLook`)
- 全 affected vitest 更新

## 6. ground-truth マップ (Explore agent の結果、保管)

### film-lab-ui 内の Preset 参照

- `packages/film-lab-ui/src/PresetSearchSelect.tsx` — 本体
- `packages/film-lab-ui/src/index.ts:67` — re-export
- `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx:34` (import), `:998` (`<PresetSearchSelect>`)
- `packages/film-lab-ui/src/film-lab-reducer.ts` — state.basePreset (l.7), Action APPLY_PRESET (l.34), 多数の usage
- `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx:504,507-508,791` — basePreset 参照
- `packages/film-lab-ui/src/filmLabUiContract.ts:24` (`FILM_LAB_PRESET_PRIMARY_SURFACE_ID`), `:36` (section id), `:60-66` (slot ids)
- `packages/film-lab-ui/src/filmLabPanelTokens.ts:45` (comment), `filmLabPresetSectionDividerBlock` const
- `packages/film-lab-ui/src/PresetBar.tsx` — 別コンポーネント、Desktop/iOS で未使用 (本 PR では触らない判断)
- i18n: `messages/en.json` (l.568, 572, 582-586, 923) + `messages/ja.json` (相当行)

### Desktop renderer の Preset 参照

- `App.tsx`: batchPresetChoice (47 refs), canvasPreset (10 refs), MetadataLookSource "preset" (9 emit + 5 conditional)
- `batch-pipeline.ts:81` — `batchGradeStateFromPreset` 定義
- `effective-export-grade.ts:34,47,112,124,151,180` — 型 + fn 引数
- `metadata-json-runtime.ts:29,188,217,246-247` — 型 + 読み書き
- `export-metadata-session.ts:25-32` (`METADATA_LOOK_SOURCES` 定義), `:463-464,500` — 型 + writer
- `batch-session.ts:23-46` (`FilmLabBatchSessionV1`), `:84-131` (parser、`batchPresetChoice` 必須検証)
- `batch-tab/BatchTabPanel.tsx:147,198,439,586,596,746,922,943,946,951` — 型 + JSX + i18n キー参照
- `electron/main.ts:448,1573-1593` (IPC handler), `electron/preload.ts:258-262` — IPC payload
- 既存テスト: `metadata-json-runtime.test.ts` / `effective-export-grade.test.ts` / `export-metadata-session.test.ts` / `batch-tab/BatchTabPanel.test.tsx`

### iOS TS の i18n 参照

- `apps/capacitor-film-lab-ios/src/lib/messages.ts:227-230` — `filmLab.controls.presets` 等を `presetLabel` 等として再 export

## 7. 何が起きたか (worktree 喪失)

タイムライン:
1. Phase A 完了 → `git diff --stat` で 11 files / +301/-7 を確認
2. ユーザーから「本質からズレている」指摘、option 1 を選択
3. Phase B 開始 — i18n 編集、`PresetSearchSelect.tsx` rename、`film-lab-reducer.ts` rename を完了
4. `FilmLabControlPanelCore.tsx` の consumer 更新へ進もうとしたところ、`Read` で **File does not exist** エラー
5. `git worktree list` で `feature/desktop-look-unification` worktree が消えていることを確認
6. `git branch -a` でも branch が見つからない
7. 親 main HEAD が `32b3100` (worktree 切った地点) → `732a273` (`feat(ios): add Backlight Veil optical filter as adjustment param`) に進行

推定原因 (未確定):
- 別ターミナル / 別 Claude セッションで `git worktree remove` + `git branch -D` が走った
- ハーネスのフックや autocleanup の可能性 (要確認)
- ユーザー手動操作の可能性

`git reflog` を漁れば直前 commit の SHA が見つかる **可能性** はあるが、本 PR の編集は uncommitted なので reflog でも復元不可。worktree 削除前にユーザーが手動 commit してくれていない限り、ファイル内容は失われている。

## 8. 再開手順 (次セッション)

### 前提確認

```bash
git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone reflog | head -20
git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone branch -a | grep -i look
git -C /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone fsck --no-reflogs --lost-found 2>&1 | head
```

reflog に `feature/desktop-look-unification` の commit が残っていれば cherry-pick で復元可。残っていなければ本ドキュメントから再実装。

### worktree 再作成

新 main (`732a273` Backlight Veil 反映済) を base にする。Backlight Veil の `CONTRACT_DEFAULTS` 追加が `ios-swift-payload.test.ts` の pre-existing failure を解消している可能性があるので状態確認:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git worktree add -b feature/desktop-look-unification \
  /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-desktop-look-unification HEAD
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-desktop-look-unification
bun install
bun test packages/film-lab-core/src/ios-swift-payload.test.ts  # pre-existing failure 状態確認
```

### 実装順 (推奨)

Phase A (core/schema 加算) → Phase B (renderer / UI / i18n sweep) の順。本ドキュメント §4 / §5 の編集を再現。

**重要: worktree が消える前にこまめに commit を作る** (ユーザーは "Git 操作は user が行う" 方針なので、user に commit を依頼するタイミングを Phase A 完了直後に入れる)。

### 検証コマンド

```bash
bun run build:core
bun run typecheck:shared
bun run typecheck:desktop
bun run verify:desktop
bun run check:filmtone-copy
bun test packages/film-lab-core
cd apps/desktop-film-lab-batch && bunx vitest run --config vitest.config.ts
git diff --check
```

### 完走条件

1. legacy-only sidecar (lookPresetId/presetVersion のみ) を `filmLookGradeInputSchema` で parse できる
2. dual sidecar の identity 不一致は throw する
3. `buildGradeJsonPayload` の出力が legacy + Look 両方を含む
4. `batch-pipeline` discriminator が legacy / dual / Look-only sidecar すべてを wrapper として認識
5. `batch-session.ts` parser が legacy `batchPresetChoice` を `batchLookChoice` として読める
6. `lookSource` parser が legacy `"preset"` を `"builtInLook"` として読める
7. Electron Desktop UI が "Look / ルック" を表示する (Edit / Export / Batch / Metadata / shortcuts 全部)
8. `bun run verify:desktop` が通る
9. `typecheck:shared` が `PresetName` / `PRESETS` import の全 consumer で通る (alias 残してあるので無風のはず)

## 9. Open Questions (次セッションで決める)

1. **PresetBar component の扱い** — Desktop / iOS で未使用と Explore 結果。`LookBar` rename して alias 残すか、未使用なので放置するか。
2. **`filmLabUiContract.ts` の slot 名 alias** — `beforePresets` → `beforeLooks` rename 時に旧名 alias を残すか。consumer (FilmLabControlPanelCore.tsx 内、Desktop App.tsx 経由で props 渡し) を全部更新できるなら alias 不要。
3. **iOS messages.ts の参照書き換え** — 本 PR で `filmLab.controls.presets` → `controls.looks` まで書き換えるか、別 PR にするか。本 PR で値だけ書き換える方針なら参照は触らずに済む (= 別 PR)。
4. **batch-session writer の挙動** — canonical を `batchLookChoice` 単独 emit にするか、dual emit (旧 build へのダウングレード復元用) か。Electron 専用 userData なので単独で十分の判断もあるが、保守的に dual。
5. **テスト fixture の更新方針** — 既存 `lookSource: "preset"` を fixture に持つテストは、parser fallback の動作確認用に **そのまま残し**、新規テストで `"builtInLook"` を canonical として書く方が回帰検出しやすい。

## 10. 触らなかった / 触ってはいけないもの (再確認)

- `scripts/generate-filmtone-ios-swift.ts` — 親 main の dirty 作業中、worktree 切る前に commit されていないと取り込めない
- 生成済 Swift ファイル (`FilmtonePhase0Generated.swift` 等) — 手編集禁止
- `PresetStrip.tsx` の output-format keys
- iOS Swift `FilmtoneStrings.swift`
- `apps/capacitor-film-lab-ios/src/lib/messages.ts:75` `presetRowAriaLabel`
- `packages/film-lab-smart-look/src/index.ts` の `BaselineCandidate.basePreset` (Smart Look baseline 用、別概念)
- `packages/film-lab-core/src/creative-pack-01.ts` の `CreativePackLook.basePreset` (Creative Pack 01 look chip 用、別概念)
- sidecar / batch session の **version bump** (transition plan §Data Contract 制約)
- `packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/` (track 維持、submodule 即 import 用)

## 11. 参照 (本 PR の根拠)

- 元 plan: `/Users/chibatakumi/.claude/plans/desktop-look-unification-bright-dusk.md`
- vocabulary canonical: `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`
- native desktop transition plan: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`
- truth scripts: `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-{release,ios}-truth.sh`
- 関連既存ハンドオフ: `docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/filmtone-desktop-release-next-chat-handoff-2026-05-02-jst.md`
