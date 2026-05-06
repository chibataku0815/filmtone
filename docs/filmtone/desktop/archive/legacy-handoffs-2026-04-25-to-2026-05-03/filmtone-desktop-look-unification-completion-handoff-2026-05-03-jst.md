# Filmtone Desktop Look Unification — Completion Handoff (Standalone)

> ⚠️ **WITHDRAWN as canonical — 2026-05-04 (domain misunderstanding)**
>
> 本 doc は PR #1 / portfolio PR #42 の merged 記録として **historical record** に残すが、`Preset → Look canonical` の vocab unification 前提は撤回。**Look = Stone / Urban (Creative LUT Pack 01)** であり、Preset (curve/grade 土台) とは rename 関係ではない。merged code に含まれる `BaseLookName` / `BASE_LOOKS` / `lookPresetId` / `currentExportLookPreset` 等の追加 alias は遺物であり、別 chat で alias purge PR 予定。
>
> trailing edges (messages.json prose / template var rename / PresetBar.tsx 命名) や iOS catch-up に関する後続計画は **すべて再評価が必要** (誤方向の sweep を引き起こす)。本 doc を新 chat の根拠にしない。
>
> 詳細: `~/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/feedback_filmtone_preset_vs_look_domain.md`
>
> ---

> **Date**: 2026-05-03 JST late evening (updated post-merge)
> **Status**: ✅ **Shipped** — filmtone main + portfolio main 両 merged。残: Phase 1b chat A 伝達 (user-side) + dead code purge / `/filmtone` page 戦略判断 (別 lane)
> **filmtone PR**: [#1 squash merged](https://github.com/chibataku0815/filmtone/pull/1) → main `6757dcf Filmtone Desktop Look Unification (Preset → Look canonical)`
> **portfolio PR**: [#42 squash merged](https://github.com/chibataku0815/chibatakumi-portfolio/pull/42) → main `061a2967 chore(filmtone): bump submodule for Look Unification (apps/web Look-aware)`
> **Phase A commit**: `1f99d68` (13 files, +424/-9, core/schema additive layer)
> **Phase B commit**: `fd9ddd2` (23 files, +534/-415, Electron renderer + film-lab-ui sweep)
> **Branch**: `feature/desktop-look-unification` (filmtone) / `chore/film-lab-look-unification-bump` (portfolio) — 両 merged、cleanup 候補
> **Worktrees**: `/forestone/filmtone-look-unification` / `/forestone/chibatakumi-portfolio-look-bump` — 両 cleanup 候補

> **Goal of this doc**: A fresh chat with **no conversation memory** can pick up this lane perfectly. Read §0 → §1 → §4 → §9 first; everything else is reference.

---

## 0. Read-this-first orientation (60 seconds)

1. **このlane の goal**: Filmtone の **製品面** (Edit / Export / Metadata / Batch session の UI 文言と code identifier) を `Preset` 語彙から `Look` 起点に統一する。Native Desktop v2 (`feature/native-desktop-plan`) Phase 1b sidecar emitter の Case A (dual emit) 切替トリガーになる。
2. **着地状況**: ✅ **両 PR squash-merged**。filmtone main `6757dcf` + portfolio main `061a2967`。verify gate 全 PASS、portfolio Vercel `chibatakumi-portfolio` deploy SUCCESS (※ 別 Vercel project `chibatakumi-portfolio-web` の FAILURE は pre-existing、本 PR 由来ではない — `30f3ba19` でも同じ failure)。
3. **残 user action**: (a) Phase 1b chat A への「Case A 切替可」伝達 (§7.2 メッセージ案、SHA 込み) → (b) worktree cleanup (任意) → (c) `/filmtone` page 戦略判断 + dead code purge (別 lane、§9.7)。
4. **絶対に触ってはいけないもの**: §10 critical invariants 参照。特に Native Desktop v2 worktree (`filmtone-native-desktop-plan`) は完全分離、生成 Swift は手編集禁止、`FilmLabBatchSessionV1` の version bump 禁止 (additive only)。
5. **この lane で chat 中 scope 再議論禁止**: §4 locked-in decisions が確定済。`feedback_no_silent_stream_redefine` / `feedback_verify_before_quoting_handoff` を機構的に守る。
6. **Recovery 教訓 (本 chat で発生)**: portfolio bump 着手前に **「Web 公開窓は本当に運用されているか」を user に確認するべきだった**。handoff §7.1 の「必須」記述は filmtone 内部視点で書かれた前提で、portfolio 運用実態の確認を飛ばして自動進行は越境。`feedback_verify_before_quoting_handoff` 違反。次回 lane では portfolio side の運用判断 (donation / AI / waitlist の live 状態 / `/filmtone` page 自体の存続) を必ず先に確認する。

---

## 1. Project context

### 1.1 Filmtone とは

- 用途: 短編動画の重いカラー工程に入る前に、すぐ作品っぽい完成感へ持っていく **Desktop-first の look-led finisher**
- 主役は **動画** (短尺動画 / short-form video の語は禁止、`動画` / `video` のみ使用)
- 写真は捨てず、`same-world extension` として扱う
- Resolve / Dehancer の代替を名乗らない、`exact film process fidelity` を front に出さない
- 4 surface: Web (try-first / marketing / docs)、iPhone (App Store ローカル仕上げ)、Desktop Electron (現行 production rail)、SwiftUI Desktop (`feature/native-desktop-plan` 移行先)

### 1.2 Look Unification とは

vocabulary canonical (`life docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`) で確定した user-facing 3 層 taxonomy:

1. **Base Looks** = 映像の world を決める土台層 (旧 `Presets`)
2. **Finish Tools** = Base Look の上に署名的 optical / motion character を足す層 (旧 `Artifacts`)
3. **Trim** = source correction (旧 `Source Trim`)

本 lane の scope は **`Preset` → `Look` (Base Look) の用語統一を Edit / Export / Metadata / Batch session の Desktop 製品面まで配線すること**。`Finish Tools` / `Trim` の rename は別 lane。

### 1.3 なぜ今やるのか

- Native Desktop v2 (SwiftUI 移行) 計画が並行進行中だが、**Electron Desktop は v2 が品質 gate を越えるまで release rail として残る** (transition plan §Migration Strategy l.45-48 / l.215-216)。SwiftUI 移行を理由に Electron の Look 統一を捨てるのは「逃げ」(handoff §2 第 2 版誤りの教訓)
- LP rewrite / SNS proof system を作る前に control panel 語彙を固定しないと、後から作り直しになる (vocab spec §1)
- Native Desktop v2 Phase 1b sidecar emitter は本 PR の core/schema landing を待っている (Case A vs Case B 分岐)

---

## 2. Repository / worktree topology

### 2.1 Repos

| repo | パス | 役割 | 本 lane との関係 |
|---|---|---|---|
| **filmtone** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` | apps + packages の **実装の正本**。GitHub: `chibatakumi0815/filmtone` | **本 PR の reach 範囲、ここに land** |
| **portfolio** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` | 公開窓のみ (`apps/web`)。`vendor/filmtone` submodule で消費 | 本 PR merge 後に **Web wrapper bump 別 PR が必要** (alias なし方針のため build break する) |
| **life** | `/Volumes/SamsungPortableSSDX5001/documents/life` | docs/guides・truth scripts・5 ロール憲法 | vocab canonical / truth scripts / memory はここ |
| **filmtone-native-desktop-plan** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan` | Native Desktop v2 (SwiftUI) 計画 worktree、branch `feature/native-desktop-plan` | **絶対に触らない**、本 PR の sidecar 契約はこれの §10 Case A/B に整合 |

### 2.2 Worktrees (filmtone repo 内)

```
/forestone/filmtone                                              732a273 [main]
/forestone/filmtone-look-unification                             fd9ddd2 [feature/desktop-look-unification]   ← THIS LANE
/forestone/filmtone-native-desktop-plan                          398743c [feature/native-desktop-plan]       ← DON'T TOUCH
/forestone/filmtone/.claude/worktrees/ios-dense-neon-noir-look   739d94b [feature/ios-dense-neon-noir-look]
/forestone/filmtone/.claude/worktrees/ios-quality-mezzanine-fix  3d56a6b [feature/ios-quality-mezzanine-cache-validation]
/forestone/filmtone/.claude/worktrees/ios-v1.5-export-profile    194ac84 [feature/ios-v1.5-export-profile]
```

### 2.3 並走 lane との接続

| 並走 lane | 本 lane への影響 | 連携 |
|---|---|---|
| **Phase 1b** (`filmtone-native-desktop-plan/feature/native-desktop-plan`) | sidecar emitter の Case A vs B が本 PR の main merge 状態で分岐 | main merge 後に user 経由で chat A に伝達。emitter dual emit に切替可 |
| **iOS v1.2 / v1.3 系 worktrees** | 不変 (本 PR は iOS Xcode project 触らず) | 干渉なし |
| **portfolio Web wrapper** | `vendor/filmtone` submodule で film-lab-ui を消費。alias なし rename で build break | 別 PR で wrapper 更新 + submodule bump 必要 |

---

## 3. Pre-history (recovery context)

### 3.1 元 plan

- パス: `~/.claude/plans/desktop-look-unification-bright-dusk.md` (v2 / "additive, native-desktop-aware")
- scope (元): core/schema 加算 + sidecar dual emit のみ (Electron renderer / film-lab-ui sweep は **scope out** だった)
- 理由: SwiftUI 移行を理由に Electron renderer の sweep を「捨てる作業」と判断していた → これが第 2 版

### 3.2 worktree 喪失

タイムライン:
1. 元 worktree (`filmtone-desktop-look-unification`) で Phase A 完了 (11 files / +301/-7、verify 通過)
2. ユーザーから「本質からズレている」指摘、scope 第 3 版に拡張 (Electron renderer も rename 範囲に含める)
3. Phase B 開始、i18n + `PresetSearchSelect.tsx` + `film-lab-reducer.ts` 編集中
4. ある時点で worktree が消失 (別セッション / フックの可能性、確定原因は不明)
5. `git reflog` / `fsck` でも uncommitted ゆえ復元不可

### 3.3 第 3 版 scope (本 PR の最終 scope)

- core/schema 加算 (BaseLook aliases / lookId dual emit) ← Phase A
- film-lab-ui の component / reducer / 識別子 rename ← Phase B
- Electron renderer の識別子 rename ← Phase B
- i18n 値変更 (Preset → Look / プリセット → ルック) ← Phase B
- batch-session / lookSource enum の parser fallback ← Phase B
- iOS Swift / iOS TS / generator は **対象外** (別 PR で catch-up)
- LP / FAQ / marketing copy は **対象外** (LP rewrite 別 lane)
- `PresetStrip.tsx` (output format chooser) は **対象外** (別概念)
- Smart Look / Creative Pack 01 の `basePreset` は **対象外** (別概念)

### 3.4 Recovery procedure

1. main `732a273` から worktree 新規作成 (`git worktree add -b feature/desktop-look-unification ../filmtone-look-unification main`)
2. `bun install` (1229 packages)
3. handoff doc + plan doc + Phase 1b §6.5/§10 を引きながら Phase A → Phase B を full re-implementation
4. Phase A 完了直後に commit (worktree 再喪失リスク回避、handoff §8 教訓)
5. Phase B 完了後に commit
6. 全 verify gate PASS 確認

---

## 4. Locked-in decisions (絶対変更しない、chat 中再議論禁止)

### 4.1 Scope (§3.3 第 3 版)

OQ レベルの最終決定:

| OQ | 質問 | 決定 | 理由 |
|---|---|---|---|
| **#1** | `PresetBar` component (Desktop / iOS で未使用) | **放置** | 未使用、export は維持して alias 不要 |
| **#2** | `filmLabUiContract.ts` slot 名 alias を残すか | **alias 残さず一気に rename** | consumer 全更新 (FilmLabControlPanelCore + Desktop App.tsx) で TS 型エラーで漏れ即検出。`Avoid backwards-compatibility hacks` 整合 |
| **#3** | `batch-session.ts` writer は dual emit か single emit か | **`batchLookChoice` 単独 emit** | Electron 専用 userData、別 user / 別 build に渡らない。parser fallback (`batchLookChoice ?? batchPresetChoice`) で旧 read のみ確保 |
| **#4** | テスト fixture の更新方針 | 既存 `lookSource: "preset"` を fallback regression として残す + 新規 `"builtInLook"` canonical fixture を追加 | dual coverage で parser fallback 仕様と整合 |
| **#5** | iOS messages.ts 参照書き換え | **本 PR では実施しない (別 PR)** | iOS v1.3 lane in-flight、blast radius 抑制。i18n 値書き換えで iOS UI も自動的に Look 化される |

### 4.2 工程上の不変条件

- **schema version bump 禁止** (`FilmLabBatchSessionV1` `version: 1` 維持、additive only — Native Desktop transition plan §Data Contract l.199-201)
- **生成 Swift 手編集禁止** (`FilmtonePhase0Generated.swift` 等 — transition plan l.75-76)
- **iOS Xcode project 編集禁止** (`apps/capacitor-film-lab-ios/` 全体)
- **Native Desktop v2 worktree 触らない** (`filmtone-native-desktop-plan/`)
- **`PresetStrip.tsx` の `presetPhotoWebJpeg` / `presetVideoDefault` 等は触らない** (output format chooser、film look ではない、§4.5)
- **`packages/film-lab-renderer/dist/` と `packages/film-lab-smart-look/dist/` を消さない** (submodule track 用、CLAUDE.md §6 antipattern #2)
- **bun mandatory、npm 禁止** (life CLAUDE.md パッケージマネージャ)
- **Git 操作は user 確認** (CLAUDE.md §11)
- **JSX comment は return ( の直下に置かない** (`feedback_no_jsx_comment_outside_root_return`)

### 4.3 用語ロック (vocab spec §3 / §4 / §5)

| 旧 | 新 (canonical) | スコープ | 例外 |
|---|---|---|---|
| `Preset` / `プリセット` (UI) | `Look` / `ルック` | control panel / batch / metadata / sidecar の user-facing 文言 | LP / FAQ marketing copy は LP rewrite 別 lane |
| `Presets` heading | `Look` heading | section title | iOS Swift `FilmtoneStrings.swift:1580` "Preset Strength" は別 PR |
| `presetIntensity` | `lookStrength` | i18n key (新 key 追加 + 旧 key 値書き換えで dual support) | iOS messages.ts:75 `presetRowAriaLabel` は別 PR |
| `basePreset` (state) | `baseLook` | film-lab-ui reducer state field | Smart Look `BaselineCandidate.basePreset` は別概念 (対象外) |
| `APPLY_PRESET` (action) | `APPLY_BASE_LOOK` | reducer action type | Creative Pack 01 `CreativePackLook.basePreset` は別概念 (対象外) |
| `batchPresetChoice` | `batchLookChoice` | Desktop renderer state + on-disk schema field | parser は legacy 名も読む |
| `canvasPreset` | `canvasLook` | Desktop renderer state | — |
| `batchGradeStateFromPreset` | `batchGradeStateFromBaseLook` | helper function | — |
| `lookSource: "preset"` | `lookSource: "builtInLook"` | metadata enum (writer 単独 emit) | parser は `"preset"` も読む (fallback) |
| `filmLabPresetSectionDividerBlock` | `filmLabLookSectionDividerBlock` | UI token | — |
| `FILM_LAB_PRESET_PRIMARY_SURFACE_ID` | `FILM_LAB_LOOK_PRIMARY_SURFACE_ID` | UI contract | — |
| `beforePresets` / `afterPresets` / `wrapperAfterPresets` / `renderAfterPresets` | `beforeLooks` / `afterLooks` / `wrapperAfterLooks` / `renderAfterLooks` | slot ids (alias なし) | — |
| `FILMTONE_DEFAULT_BASE_PRESET` | `FILMTONE_DEFAULT_BASE_LOOK` | core export | core 側は both export (alias) |
| `findMatchingPreset` | `findMatchingBaseLook` | core function | core 側 alias 加算 |
| `PresetName` (type) | `BaseLookName` (alias) | core type | core 側 both export |
| `lookIdForPreset` | `lookIdForBaseLook` | core function | core 側 alias |
| `LOOK_ID_BY_PRESET` | `LOOK_ID_BY_BASE_LOOK` | core const | core 側 alias |
| `PRESET_VERSION` | `LOOK_RECIPE_VERSION` | core const | core 側 alias |

**Allowed legacy survivors (本 PR で触らない、別 PR で扱う)**:
- `PresetName` / `PRESETS` / `lookPresetId` / `presetVersion` symbols (film-lab-core で canonical のまま、alias 加算)
- `lookSource: "preset"` enum 値 (parser fallback、writer は `"builtInLook"` canonical)
- iOS Swift `FilmtoneStrings.swift` "Preset Strength"、iOS TS `messages.ts:75` `presetRowAriaLabel: "Film presets"`
- LP / FAQ / marketing copy 内 `presets` 単語 (`heroSubtitle` / `faqQpresets` / `surfaceSplitWebBody` 等)
- export status template variable `{preset}` (`currentExportLookPreset` / `lookStatusPresetTitle` 等の i18n template var)
- `PresetStrip.tsx` の output format chooser (encoder preset、film look ではない)
- Smart Look `BaselineCandidate.basePreset`、Creative Pack 01 `CreativePackLook.basePreset` (別概念)

---

## 5. Phase A — landed details (commit `1f99d68`)

### 5.1 Files changed (13 files、+424/-9)

| ファイル | 内容 |
|---|---|
| `packages/film-lab-core/src/presets.ts` | 末尾に `BaseLookName` / `BASE_LOOKS` / `BASE_LOOK_BUTTONS` / `FILMTONE_DEFAULT_BASE_LOOK` / `findMatchingBaseLook` 5 alias 追加 (既存 export は不変) |
| `packages/film-lab-core/src/look-ids.ts` | `LOOK_RECIPE_VERSION` / `lookIdForBaseLook` / `LOOK_ID_BY_BASE_LOOK` 3 alias 追加。**`schema.ts` を import しない** (循環依存回避)。`gradeMatchesBaseLook` は schema.ts 側の export とする |
| `packages/film-lab-core/src/schema.ts` | `filmLookGradeInputSchema` に optional `lookId: z.string().min(1).optional()` / `lookVersion: z.literal(PRESET_VERSION).optional()` 追加。`normalizeFilmLookGradeInputIdentity()` 新設 (dual identity strict equality / 不一致 throw / legacy のみは Look-first 補完 / Look-only も legacy 補完で round-trip)。`gradeMatchesBaseLook = gradeMatchesPreset` alias |
| `packages/film-lab-core/src/defaults.ts` | `createDefaultFilmLookGradeProps()` を dual emit (`lookPresetId` / `presetVersion` + `lookId` / `lookVersion` 両方を含む) |
| `packages/film-lab-core/src/index.ts` | 新 11 symbol を public re-export (`BASE_LOOKS` / `BaseLookName` / `LOOK_RECIPE_VERSION` / `lookIdForBaseLook` / `LOOK_ID_BY_BASE_LOOK` / `findMatchingBaseLook` / `FILMTONE_DEFAULT_BASE_LOOK` / `BASE_LOOK_BUTTONS` / `gradeMatchesBaseLook` / `normalizeFilmLookGradeInputIdentity`) |
| `apps/desktop-film-lab-batch/src/renderer/grade-io.ts` | `buildGradeJsonPayload` を dual emit |
| `apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts` | discriminator を `("lookPresetId" in o \|\| "lookId" in o)` に拡張、parsed 後に `normalizeFilmLookGradeInputIdentity()` 適用 |
| `packages/film-lab-core/src/look-ids.test.ts` (NEW) | 5 alias identity tests |
| `packages/film-lab-core/src/schema.test.ts` (+6) | legacy-only 受理 / dual-match 受理 / dual-mismatch throw / normalize legacy 補完 round-trip / normalize 同一参照返し / `gradeMatchesBaseLook` 等価 |
| `packages/film-lab-core/src/filmtone-defaults.test.ts` (+1) | Base Look aliases identity (5 export 同時 strict equality) |
| `apps/desktop-film-lab-batch/src/renderer/grade-io.test.ts` (NEW) | 8 tests (dual emit / schema self-parse / normalize round-trip / fallback / JSON text / discriminator legacy / dual / mismatch throw) |
| `packages/film-lab-core/dist/index.d.ts` | build:core で再生成 (tracked、submodule consumption 用) |
| `packages/film-lab-core/dist/index.js` | 同上 |

### 5.2 Verify gate (Phase A 完了時)

- `bun run build:core` ✓
- `bun run typecheck:shared` ✓ clean
- `bun run typecheck:desktop` ✓ clean
- `bun test packages/film-lab-core` 201 pass / 2 fail (pre-existing `ios-swift-payload.test.ts` のみ、§11 参照)
- Desktop `bunx vitest run` 285 pass / 1 fail (pre-existing `BatchTabPanel.test.tsx` i18n drift、Phase B で同時解消)
- `bun run verify:desktop` ✓
- `bun run check:filmtone-copy` ✓
- `git diff --check` ✓ no whitespace
- life `check-filmtone-release-truth.sh` ✓

---

## 6. Phase B — landed details (commit `fd9ddd2`)

### 6.1 Files changed (23 files、+534/-415)

#### i18n (2 files)

| ファイル | 変更 |
|---|---|
| `messages/en.json` | 8 既存 keys 値書き換え (`presets` "Look" / `presetSelectTriggerLabel` "Choose Look" / `presetSearchEmpty` "No Looks match…" / `presetIntensity` "Look Strength" / `presetSelect` "Select Look" / `presetSlider` "Blend Look vs neutral…" / `presetQuickLabel` "Look (quick)" / `presetSelectAria` "Look used for export") + 7 新 keys (`controls.looks` / `controls.lookSelectTriggerLabel` / `controls.lookSearchPlaceholder` / `controls.lookSearchEmpty` / `controls.lookStrength` / `lookQuickLabel` / `lookSelectAria`) + pre-existing drift fix (`mode.hint` / `mode.hintInfoAria` 追加) |
| `messages/ja.json` | 同上 (ルック / ルックを選ぶ / 一致するルック… / ルックの強さ etc) + `mode.hint` を「クイックはルックと…」に書き換え |

#### film-lab-ui (7 files)

| ファイル | 変更 |
|---|---|
| `filmLabPanelTokens.ts` | `filmLabPresetSectionDividerBlock` → `filmLabLookSectionDividerBlock` |
| `filmLabUiContract.ts` | `FILM_LAB_PRESET_PRIMARY_SURFACE_ID` → `FILM_LAB_LOOK_PRIMARY_SURFACE_ID` (`"LookSearchSelect"` 値) / `"presets"` section → `"looks"` / `beforePresets` / `afterPresets` / `wrapperAfterPresets` / `renderAfterPresets` slot ids → `beforeLooks` / `afterLooks` / `wrapperAfterLooks` / `renderAfterLooks` (alias なし) |
| `PresetSearchSelect.tsx` (file 名は維持) | `LookSearchSelect` を canonical export (props `activeLook` / `onLook`、`BASE_LOOK_BUTTONS` import、`data-testid="film-lab-look-*"`、CSS class `film-lab-look-search-scroll`) + 末尾に `PresetSearchSelect` deprecated wrapper (旧 props `activePreset` / `onPreset` accept、内部で `LookSearchSelect` 呼ぶ) |
| `film-lab-reducer.ts` | `state.basePreset` → `baseLook` (21+ refs) / `APPLY_PRESET` action → `APPLY_BASE_LOOK` (`lookName` / `params`) / `preserveBasePreset` → `preserveBaseLook` / `APPLY_PARAMS.basePreset` → `baseLook` / `createInitialState(initialBaseLook)` / 内部 helper `interpolatePreset` → `interpolateBaseLook` (alias なし) |
| `FilmLabControlPanelCore.tsx` | imports update (`FILMTONE_DEFAULT_BASE_LOOK` / `findMatchingBaseLook` / `BaseLookName` / `LookSearchSelect` / `filmLabLookSectionDividerBlock`) / slot interface (beforeLooks 等) / render context (`activeBaseLook` / `setActiveBaseLook`) / `applyPreset` → `applyBaseLook` / `presetKeys` keyboard map → `baseLookKeys` / `presetIntensityAvailable` → `lookStrengthAvailable` / `presetSelectActive` → `lookSelectActive` / `onPresetChange` prop → `onBaseLookChange` / JSX `<LookSearchSelect activeLook=... onLook=...>` + i18n keys を新 keys に切替 (`controls.looks` / `lookSelectTriggerLabel` / `lookSearchPlaceholder` / `lookSearchEmpty` / `lookStrength`) |
| `index.ts` | re-export 更新 (`FILM_LAB_LOOK_PRIMARY_SURFACE_ID` / `filmLabLookSectionDividerBlock` / `LookSearchSelect` canonical + `LookSearchSelectProps` + `PresetSearchSelect` deprecated alias + `PresetSearchSelectProps` deprecated alias) |
| `filmtone-default-state.test.ts` | `FILMTONE_DEFAULT_BASE_LOOK` import / `state.slotA.baseLook` 期待値 |

#### Desktop renderer (10 files)

| ファイル | 変更 |
|---|---|
| `App.tsx` | `batchPresetChoice` (37 refs) → `batchLookChoice` / `canvasPreset` (4) → `canvasLook` / `setCanvasPreset` → `setCanvasBaseLook` / `applyBatchPreset` → `applyBatchBaseLook` / `handleControlPanelPresetChange` → `handleControlPanelBaseLookChange` / `onBatchPresetChoiceChange` → `onBatchLookChoiceChange` / `onReapplyBatchPresetBaseline` → `onReapplyBatchBaseLookBaseline` (replace_all 副作用、awkward だが動く) / `lookSource: "preset"` (7) → `"builtInLook"` / `FILMTONE_DEFAULT_BASE_PRESET` → `FILMTONE_DEFAULT_BASE_LOOK` / `PresetName` → `BaseLookName` / `onPresetChange={...}` → `onBaseLookChange={...}` |
| `batch-pipeline.ts` | `batchGradeStateFromPreset(preset: PresetName)` → `batchGradeStateFromBaseLook(baseLook: BaseLookName)` + `BaseLookName` import (PresetName も併記、内部 `presetFromLookId` helper の signature 互換用) |
| `batch-session.ts` | type field `batchPresetChoice` → `batchLookChoice` / parser は `o.batchLookChoice ?? o.batchPresetChoice` で fallback / writer は `batchLookChoice` 単独 emit (locked-in #3、Electron 専用 userData) / `version: 1` 維持 |
| `export-metadata-session.ts` | `METADATA_LOOK_SOURCES` に `"builtInLook"` canonical 追加 (legacy `"preset"` 保持) + `canonicalizeMetadataLookSource()` helper / `parseFilmtoneExportSessionV1` で `look.source: "preset"` → `"builtInLook"` 正規化 / `promoteLegacyLookSidecarFields()` で legacy `look.batchPresetChoice` → canonical `look.batchLookChoice` field 昇格 (旧 sidecar も parse 通過) / `batchPresetChoice` field → `batchLookChoice` / `inferPresetChoiceFromImportedJson` → `inferBaseLookChoiceFromImportedJson` / `presetNameSchema` → `baseLookNameSchema` / `FIRST_PRESET_NAME` → `FIRST_BASE_LOOK_NAME` / `findMatchingPreset` → `findMatchingBaseLook` / `lookIdForPreset` → `lookIdForBaseLook` |
| `effective-export-grade.ts` | `batchPresetChoice` / `canvasPreset` / `fallbackBatchPresetChoice` 全 rename / 内部 trace `preset=` → `baseLook=` / `PresetName` → `BaseLookName` / `FILMTONE_DEFAULT_BASE_PRESET` → `FILMTONE_DEFAULT_BASE_LOOK` |
| `metadata-json-runtime.ts` | `batchPresetChoice` → `batchLookChoice` / 既定 fallback `lookSource: "preset"` → `"builtInLook"` / `inferBaseLookChoiceFromImportedJson` import |
| `batch-tab/BatchTabPanel.tsx` | type props (`batchLookChoice` / `onBatchLookChoiceChange` / `onReapplyBatchBaseLookBaseline`) / `t("presetQuickLabel")` → `t("lookQuickLabel")` / `t("presetSelectAria")` → `t("lookSelectAria")` / `formatPresetChoiceLabel` → `formatBaseLookChoiceLabel` / `PRESET_NAMES` → `BASE_LOOK_NAMES` |
| `globals.css` | `.film-lab-preset-search-scroll` → `.film-lab-look-search-scroll` (7 selectors) |
| `desktop-smart-look-render.test.tsx` | description "Look select" / `data-testid="film-lab-look-select-trigger"` |
| `desktop-smart-look-pending.test.ts` | description "Look select" / 期待文字列 `ルック` |

#### Tests (4 files)

| ファイル | 変更 |
|---|---|
| `effective-export-grade.test.ts` | `batchLookChoice` / `canvasLook` / `fallbackBatchLookChoice` / `lookSource: "builtInLook"` / 期待値 fix |
| `export-metadata-session.test.ts` | `batchLookChoice` field / `lookSource: "builtInLook"` / `inferBaseLookChoiceFromImportedJson` / `batchGradeStateFromBaseLook` |
| `metadata-json-runtime.test.ts` | `batchLookChoice` / `lookSource: "builtInLook"` / `batchGradeStateFromBaseLook` |
| `batch-tab/BatchTabPanel.test.tsx` | `batchLookChoice` / `onBatchLookChoiceChange` / `onReapplyBatchBaseLookBaseline` / `formatBaseLookChoiceLabel` |

### 6.2 Verify gate (Phase B 完了時、本 PR 最終)

- `bun run build:core` ✓
- `bun run typecheck:shared` ✓ clean
- `bun run typecheck:desktop` ✓ clean
- `bun test packages/film-lab-core packages/film-lab-ui` **205 pass / 2 fail** (pre-existing only)
- Desktop `bunx vitest run` **39 files / 286 pass / 1 skipped / 0 fail** (Phase A 時点 1 fail だった `BatchTabPanel.test.tsx` i18n drift も解消)
- `bun run verify:desktop` ✓ (typecheck + smart-look smoke 5/5)
- `bun run check:filmtone-copy` ✓ Filmtone copy quality check passed
- `git diff --check` ✓ no whitespace
- iOS `bun test src/` ✓ 14 pass / 0 fail
- life `check-filmtone-release-truth.sh` ✓
- life `check-filmtone-ios-truth.sh` ✓

---

## 7. Cross-PR / cross-repo coordination

### 7.1 portfolio Web wrapper (chibatakumi-portfolio) — 別 PR、必須

`chibatakumi-portfolio/apps/web` は `vendor/filmtone` submodule で `film-lab-ui` を消費。本 PR を main merge → submodule bump 時に **build break する** (alias なし方針 locked-in #2 のため)。

**bump PR で更新が必要な API**:
- slot ids: `beforePresets` → `beforeLooks` / `afterPresets` → `afterLooks` / `renderAfterPresets` → `renderAfterLooks`
- props: `onPresetChange` → `onBaseLookChange`
- render context: `activePreset` → `activeBaseLook` / `setActivePreset` → `setActiveBaseLook` / `restoreSession({ activePreset })` → `restoreSession({ activeBaseLook })`
- reducer state read: `state.slotA.basePreset` → `state.slotA.baseLook` / `state.slotA.intensity` 不変
- reducer dispatch: `{ type: "APPLY_PRESET", presetName, preset }` → `{ type: "APPLY_BASE_LOOK", lookName, params }` / `{ type: "SET_PARAM", preserveBasePreset }` → `preserveBaseLook` / `{ type: "APPLY_PARAMS", basePreset }` → `baseLook`
- core symbol: `FILMTONE_DEFAULT_BASE_PRESET` → `FILMTONE_DEFAULT_BASE_LOOK` (両方 export されているので bump 即時必須ではないが clean up 推奨) / `findMatchingPreset` → `findMatchingBaseLook` / `PresetName` → `BaseLookName`
- UI contract: `FILM_LAB_PRESET_PRIMARY_SURFACE_ID` → `FILM_LAB_LOOK_PRIMARY_SURFACE_ID`
- token: `filmLabPresetSectionDividerBlock` → `filmLabLookSectionDividerBlock`

**bump PR の存続コード**: 旧 `PresetSearchSelect` / `PresetSearchSelectProps` は deprecated wrapper として残る (内部で `LookSearchSelect` 呼ぶ)。consumer は immediate update 不要だが、deprecation warning 整合のため徐々に置換推奨。

### 7.2 Native Desktop v2 Phase 1b chat A — main merge 後の伝達必須

Phase 1b master handoff (`/forestone/filmtone/docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md`) §6.5 / §10:

- 現状 (本 PR main merge 前): Phase 1b sidecar emitter は **Case B (Look canonical only)** で動く
- 本 PR main merge 後: Phase 1b emitter を **Case A (dual emit)** に切替可
- 切替判定 grep (Phase 1b chat A が main で実行):
  ```bash
  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
  git log origin/main --oneline | grep -iE "Look Unification|Phase A core/schema additive"
  grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
  grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
  ```
  - `BASE_LOOKS` export ある + `batch-pipeline` discriminator に `lookId` ある → landed → **Case A**
  - 上記が無い → 未 landed → **Case B 継続**

**user 経由で Phase 1b chat A に伝達するメッセージ案** (本 PR main merge 後):

> Look Unification main merged (commits `1f99d68` Phase A + `fd9ddd2` Phase B、merge SHA は <your-merge-commit>)。
> §10 Case A 切替可。`BASE_LOOKS` / `LOOK_ID_BY_BASE_LOOK` / `lookId` discriminator が main 上で利用可能。
> sidecar emitter を dual emit (`lookPresetId` + `presetVersion` + `lookId` + `lookVersion` + `batchPresetChoice` + `batchLookChoice` 全部含む) に切替してください。
> 既存 sidecar reader (`parseFilmtoneExportSessionV1` + `promoteLegacyLookSidecarFields`) が legacy `batchPresetChoice` field を `batchLookChoice` に昇格させて読むので、Phase 1b 着手前に作成された旧 sidecar も互換。

### 7.3 Phase 1b master handoff §6.5 / §10 の状態更新 — 別 chat / user 経由で Patch

Native Desktop v2 worktree は本 lane では絶対に触らない (§4.2 invariant)。以下の patch を Phase 1b chat A 経由 (または user の手動編集) で適用:

```diff
 ### Lane 概要

 - branch: `feature/desktop-look-unification`
-- worktree: 一度喪失 (recovery 未確認)、main checkout で再開予定
+- worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification` (recovery 完了)
 - 元 plan: `~/.claude/plans/desktop-look-unification-bright-dusk.md`
 - 再開 handoff (canonical):
   `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
+- Completion handoff (post-implementation, standalone):
+  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/filmtone-desktop-look-unification-completion-handoff-2026-05-03-jst.md`
   (このリポは Native Desktop worktree なので main checkout 側を読む)
-- 状態 (2026-05-03 JST 時点): Phase A (core/schema 加算) は完了して verify
-  通過、Phase B (Electron renderer + film-lab-ui sweep) が部分完了で worktree
-  喪失 → 再開待ち
+- 状態 (2026-05-03 JST late evening 更新):
+  - Phase A commit `1f99d68` (13 files +424/-9): core/schema 加算
+  - Phase B commit `fd9ddd2` (23 files +534/-415): Electron renderer + film-lab-ui sweep
+  - **main へは未 merge** (push / PR 待ち)
+  - main merge 完了後に Phase 1b の sidecar emitter を Case A (dual emit)
+    に切替可。それまでは Case B (Look canonical only) 継続
```

### 7.4 iOS catch-up — 別 PR 2 件 (急がない、本 PR ship に block しない)

| target | rename | 場所 | 備考 |
|---|---|---|---|
| iOS TS | `presetRowAriaLabel: "Film presets"` → `lookRowAriaLabel: "Film looks"` (or "Base Looks") | `apps/capacitor-film-lab-ios/src/lib/messages.ts:75` (en と ja 両方) | iOS UI で aria-label として使用、ja value も合わせて更新 |
| iOS Swift | "Preset Strength" → "Look Strength" | `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift:1580` | **手編集禁止**、generator 経由で書き換える必要あり (§7.5 と組み合わせ) |

iOS messages.ts が legacy `filmLab.controls.presets` keys を参照している (本 PR で値書き換え済み、自動的に Look 化)。これは **正常**、Phase B locked-in #5 で残置決定。

### 7.5 generator (filmtone) — 別 PR、dirty 作業 main 取り込み後

`scripts/generate-filmtone-ios-swift.ts` は親 main の dirty 作業中で、本 PR の worktree 切る前に commit されていない。dirty 作業が main に入ってから別 PR で:

- `typealias PresetName = String` の隣に `typealias BaseLookName = PresetName` を生成 Swift 末尾に出す
- `presetDefault`, `paramsByName` の隣に `baseLookDefault`, `paramsByBaseLookName` を alias constant として出す (値は同じ)

これにより既存 iOS code は無風、Native Desktop SwiftUI は BaseLook 名で書ける。

### 7.6 LP / FAQ / marketing copy — LP rewrite 別 lane

`messages/{en,ja}.json` の以下のキーは本 PR で **触らなかった** (LP rewrite 別 lane):
- `heroSubtitle` / `surfaceSplitWebBody` / `expandAuxiliaryPanelsHint` / `demoBody` / `metadataDescription` / `surfaceWebBody` / `surfaceIosBody` / `heroLead` / `cardsTitle`
- `faqQpresets` / `faqApresets`
- `webDemoDescription` / `iosDescription`
- `tipLookJsonDetails` / `tipApplyEditGradeToBatch`
- promo variants (`fourPresets` 等)
- Filmtone signature pack の copy 系

これらは LP rewrite の grammar (`finished feel` / `play / compare / Desktop finish` / `Base Look + Finish Tool` 等) で全面書き直しするため、preset 単語だけ抜き出して書き換えるのは avoid (vocab spec §7.4 の rewrite template に従う)。

### 7.7 export status template variable — 別 PR

`messages/{en,ja}.json` の以下の i18n keys は `{preset}` template variable を使う:
- `currentExportLookPreset: "Starting from preset \"{preset}\"…"` 
- `lookStatusPresetTitle: "Look: preset \"{preset}\""`
- `lookStatusPresetBody`, `lookPresetHiddenWhileSyncedBody`, `lookPresetHiddenWhileRecommendedBody`, `lookRevertToPresetOnlyBtn`
- `gradeMemoryLine`, `batchPipelineGradeMemory`, `gradePresetLine`
- `presetWhenOpenLabel`, `presetWhenOpenCompactLabel`

これらは i18n key 名 + value 内 "preset" 単語 + template variable name `{preset}` + consumer code の同時更新が必要。ad-hoc 書き換えは consumer code との不整合を起こすため、別 PR で独立スコープとして扱う。

---

## 8. Final verify gate matrix (両 phase 終了時、本 PR ship 直前)

| gate | 期待値 | 結果 |
|---|---|---|
| `bun run build:core` | success | ✓ |
| `bun run typecheck:shared` | clean (no errors) | ✓ |
| `bun run typecheck:desktop` | clean (no errors) | ✓ |
| `bun test packages/film-lab-core packages/film-lab-ui` | 205 pass / 2 fail (pre-existing only) | ✓ (`ios-swift-payload.test.ts` `CONTRACT_DEFAULT_KEY_ORDER` Backlight Veil drift のみ、§11 参照) |
| Desktop `bunx vitest run` | 286 pass / 1 skipped / 0 fail (39 test files) | ✓ |
| `bun run verify:desktop` | typecheck + smart-look smoke 5/5 PASS | ✓ |
| `bun run check:filmtone-copy` | "Filmtone copy quality check passed." | ✓ |
| `git diff --check` | no whitespace issues | ✓ |
| iOS `cd apps/capacitor-film-lab-ios && bun test src/` | 14 pass / 0 fail | ✓ |
| `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh` | no errors (public 1.0.3 / commits ahead 既知) | ✓ |
| `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh` | no errors | ✓ |

### 再現方法 (新しい chat で gate を確認したい時)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification
bun install                                                                # if not already
bun run build:core
bun run typecheck:shared
bun run typecheck:desktop
bun test packages/film-lab-core packages/film-lab-ui
cd apps/desktop-film-lab-batch && bunx vitest run --config vitest.config.ts
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification
bun run verify:desktop
bun run check:filmtone-copy
git diff --check
cd apps/capacitor-film-lab-ios && bun test src/
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification
FILMTONE_REPO_ROOT=$(pwd) /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
FILMTONE_REPO_ROOT=$(pwd) /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

---

## 9. Remaining tasks (full enumeration)

### 9.1 A: Ship rail ✅ DONE

| # | タスク | 状態 |
|---|---|---|
| 1 | `feature/desktop-look-unification` を origin に push | ✅ |
| 2 | filmtone main への PR 作成 (#1) | ✅ |
| 3 | PR review + main merge (squash → `6757dcf`) | ✅ |

### 9.2 B: main merge 後の連動 (進行中)

| # | タスク | 担当 | 状態 |
|---|---|---|---|
| 4 | Phase 1b chat A への伝達 (Case A 切替可、SHA `6757dcf` 込み) | **user (chat 間通信なし)** | ⏳ 残 |
| 5 | Phase 1b master handoff §6.5 / §10 状態更新 (§7.3 patch) | user (or Phase 1b chat A) | ⏳ 残 (Native Desktop v2 worktree、本 lane では触らない) |

### 9.3 C: 連動別 PR (Look Unification 完結に必要)

| # | タスク | repo | 状態 |
|---|---|---|---|
| 6 | portfolio Web wrapper 更新 (§7.1) + submodule bump | `chibatakumi-portfolio` PR #42 → main `061a2967` | ✅ squash merged |
| 7 | iOS TS `messages.ts:75` rename (§7.4) | `filmtone` | ⏳ 急がない |
| 8 | iOS Swift `FilmtoneStrings.swift:1580` rename (§7.4) | `filmtone` (generator 経由) | ⏳ 急がない |
| 9 | generator (`scripts/generate-filmtone-ios-swift.ts`) Look-first emit (§7.5) | `filmtone` | ⏳ dirty 作業 main 取り込み後 |

### 9.4 D: 派生 (Look Unification 完結後でも OK)

| # | タスク | 備考 |
|---|---|---|
| 10 | LP / FAQ / marketing copy "presets" 単語 sweep (§7.6) | LP rewrite 別 lane (vocab spec §7) |
| 11 | export status template variable `{preset}` rename (§7.7) | i18n key + consumer 同時更新が必要、別 PR |
| 12 | `PresetBar.tsx` 扱い決定 | OQ #1 default = 放置、後で判断可 |

### 9.5 E: 本 PR 無関係だが残作業

| # | タスク | 備考 |
|---|---|---|
| 13 | `ios-swift-payload.test.ts` `CONTRACT_DEFAULT_KEY_ORDER` 2 件 fail fix | Backlight Veil の `CONTRACT_DEFAULTS` 追加で `ios-swift-payload.ts` の ordered list が drift。別 lane で fix (本 PR 無関係) |

### 9.6 優先順序

最優先 (残): 4 (Phase 1b 伝達) → 5 (handoff sync)
並行 / 任意: 7・8・9 (iOS catch-up)、10・11 (LP rewrite に乗せる)、12・13 (任意)、9.7 (戦略判断)

### 9.7 F: portfolio `/filmtone` page 戦略判断 + dead code purge (新規追加、別 lane)

本 PR 着地中に判明した事実: **portfolio `apps/web` の filmtone 関連 server module の多くが dormant**。本 PR では `feedback_verify_before_quoting_handoff` 違反で portfolio 側の運用実態を確認せずに bump PR を進めてしまったが、user 確認の結果以下が判明:

| 機能 | 状態 | 削除可? |
|---|---|---|
| AI smart-look BFF (`/api/film-lab/ai/smart-look`) | dormant (caller は `FilmLabSmartLookSection` のみ、user 言「使っていない」) | ⭕ 削除候補 |
| Donation (Stripe webhook + cookie signing) | dormant (env-conditional、user 言「使っていない」) | ⭕ 削除候補 |
| Filmtone signature waitlist (`/api/waitlist`) | dormant (user 言「使っていない」) | ⭕ 削除候補 |
| AI scene-pick BFF (`/api/film-lab/ai/scene-pick`) | dev-only PoC、prod deploy NG (file header 明記)、Desktop からのみ caller | ⭕ portfolio から削除可 |
| 旧 waitlist v1 (`/api/film-lab/waitlist`) | apps/web 内 caller 0 件 (新 `/api/waitlist` に移行) | ⭕ 削除候補 |
| `/filmtone` page interactive playground (`<FilmLabFullPage>`) | **未確認** (user 確認待ち) | user 戦略判断次第 |

**戦略判断 (別 lane で planning)**:

- **(α) `/filmtone` page を filmtone microsite として分離** (`filmtone.fores-tone.co.jp` 等)、portfolio は 301 redirect のみ
- **(β) `/filmtone` page を archive** (filmtone は Desktop / iOS / 標準リポでのみ提供、Web 公開窓は廃止)
- **(γ) 現状維持** (薄い Web playground を portfolio に残す、ただし dead code は purge)

どれを取るかで「portfolio が抱えるべき filmtone 関連コード量」が大きく変わる。

---

## 10. Critical invariants (the next chat MUST hold)

絶対変更しない (§4.2 から再掲 + 補強):

1. **Native Desktop v2 worktree (`/forestone/filmtone-native-desktop-plan`) は絶対に触らない** — Phase 1b chat A が同時編集中
2. **生成 Swift (`FilmtonePhase0Generated.swift` 等) を手編集しない**、generator 経由のみ (Swift 側 BaseLook alias は別 PR)
3. **schema version bump しない** (`FilmLabBatchSessionV1` の on-disk shape は固定、additive only — Native Desktop transition plan §Data Contract)
4. **iOS Xcode project (`apps/capacitor-film-lab-ios/`) を編集しない** — v1.3 lane in-flight
5. **`packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/` を消さない** (submodule track 用、CLAUDE.md §6 antipattern #2)
6. **`PresetStrip.tsx` (output format chooser) は対象外** — encoder preset、film look ではない、SwiftUI Desktop 側で再設計予定
7. **Smart Look `BaselineCandidate.basePreset` / Creative Pack 01 `CreativePackLook.basePreset` は別概念**、対象外
8. **bun mandatory、npm 禁止** (`package-lock.json` と `bun.lock` 共存時は前者削除)
9. **用語ロック**: `動画` (× 短尺動画) / `video` (× short-form video)。`Look` (× Preset) — vocab canonical は `life docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`
10. **Git 操作は user 確認** (CLAUDE.md §11)、自動 commit / push 禁止
11. **JSX comment を `return (` の直下に置かない** (`feedback_no_jsx_comment_outside_root_return`)
12. **handoff doc 鵜呑み禁止** — 引用前に現行 surface (grep / Read / pbxproj / WGSL) と突き合わせて live/frozen 確認 (`feedback_verify_before_quoting_handoff`)
13. **scope を chat 中で再議論しない** — §4 locked-in を固定し、Phase B sweep 中の "縮退" / "後送り" は禁止 (`feedback_no_silent_stream_redefine`)
14. **Phase A 完了直後に user に commit を依頼する** — worktree 再喪失リスク回避 (handoff §0.7 教訓)

---

## 11. Pre-existing failures (out of scope, do NOT fix here)

### 11.1 `ios-swift-payload.test.ts` `CONTRACT_DEFAULT_KEY_ORDER`

- 失敗テスト 2 件 (`packages/film-lab-core/src/ios-swift-payload.test.ts:174` および `:199`)
- 原因: Backlight Veil 実装 (`732a273` `feat(ios): add Backlight Veil optical filter…`) で `CONTRACT_DEFAULTS` (presets.ts) に haloPrism* 8 keys + optical* 6 keys を追加したが、`ios-swift-payload.ts` 側の `CONTRACT_DEFAULT_KEY_ORDER` ordered list が同時更新されなかった drift
- 本 PR の編集とは無関係 (本 PR commit 前 main で既に fail していた、recovery base check で確認済み)
- 別 lane で fix (推測: `scripts/generate-filmtone-ios-swift.ts` の dirty 作業がこれを直す lane の可能性)
- **本 PR で触らない** (scope 外、別 lane)

### 11.2 `BatchTabPanel.test.tsx` i18n key sync drift (Phase A 完了時点)

- Phase A 完了時点で 1 fail だった `BatchTabPanel.test.tsx > BatchTabPanel glass-unified layout (2026-04-19) > keeps ja.json and en.json key sets in sync`
- 原因: `mode.hint` / `mode.hintInfoAria` が ja.json にあって en.json にない (drift)
- **Phase B i18n sweep で同時解消済**: en.json の `mode` block に `hint` / `hintInfoAria` 追加、ja.json は既存値を「クイックはルックと…」に書き換え
- 現在は PASS

---

## 12. Documentation index (where to look)

### 12.1 本 lane の canonical docs (filmtone repo)

| 用途 | パス |
|---|---|
| **Recovery + resolution + 第 3 版 scope 確定根拠 + 元 §1〜§11** | `forestone/filmtone/docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md` (worktree 喪失前 → 復旧、§0 Resolution 章追加済) |
| **本 lane post-implementation full handoff (THIS doc)** | `forestone/filmtone/docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/filmtone-desktop-look-unification-completion-handoff-2026-05-03-jst.md` (standalone、別 chat 引継ぎ用) |
| **元 plan** | `~/.claude/plans/desktop-look-unification-bright-dusk.md` (Status: Implemented header 追加済) |

### 12.2 並走 docs

| 用途 | パス |
|---|---|
| **Native Desktop v2 transition plan** (Data Contract / Migration Strategy) | `/forestone/filmtone/docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/filmtone-native-desktop-transition-plan-2026-05-03-jst.md` |
| **Phase 1b master handoff** (§6.5 Concurrent Lane / §10 Sidecar Contract Case A/B) | `/forestone/filmtone/docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md` |

### 12.3 vocab / truth / repo rules

| 用途 | パス |
|---|---|
| **vocabulary canonical** (Base Look / Finish Tool / Trim 3 層 taxonomy) | `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md` |
| **Filmtone repo rules** (CLAUDE.md) — antipattern #5 用語ロックに Look 追記済 | `/forestone/filmtone/CLAUDE.md` |
| **life repo rules** (CLAUDE.md) | `/Volumes/SamsungPortableSSDX5001/documents/life/CLAUDE.md` |
| **filmtone live entry index** (Copy Vocabulary Gate に Look ロック追記済) | `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/film-lab-current-index.md` |
| **release truth script** | `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh` |
| **iOS truth script** | `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh` |
| **filmtone copy quality check** | `/forestone/filmtone/scripts/check-filmtone-copy-quality.mjs` |

### 12.4 memory entries (life)

| エントリ | パス |
|---|---|
| Look Unification landed — primary memory | `/Users/chibatakumi/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/filmtone_desktop_look_unification_landed.md` |
| Memory index | `/Users/chibatakumi/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-life/memory/MEMORY.md` (Active work 先頭に Look Unification entry) |

---

## 13. Recovery lessons (今後同じ事故を起こさない)

1. **Phase A 完了直後に user に commit を依頼する** — handoff §8 / §0.7 教訓。worktree 再喪失リスクを最小化。本 recovery では Phase A `1f99d68` 完了直後に commit を取った
2. **handoff doc の行番号 (例: `schema.ts:179-181`) は worktree 喪失前の記憶ベース** — 再開時は必ず現行 surface で grep / Read 再確認 (`feedback_verify_before_quoting_handoff` 適用)。本 recovery では Backlight Veil 後の再開で偶然全行番号一致だったが、検証ステップは飛ばさない
3. **scope を chat 中で再議論しない** — 第 3 版 (option 1) を locked-in として固定し、Phase B sweep 中に "縮退" / "後送り" しない (`feedback_no_silent_stream_redefine`)。本 recovery では §0.3 差分監査で全項目突き合わせを実施
4. **portfolio Web wrapper の更新は別 PR** — alias なし方針 (locked-in #2) のため、本 PR merge 直後は wrapper が壊れる。bump PR を併走させる必要あり (§7.1)
5. **第 3 版 scope は Electron renderer の rename を含む** — 「SwiftUI 移行を理由に Electron sweep を捨てる」のは第 2 版誤り。Electron は Native Desktop v2 が品質 gate を越えるまで release rail として残るので、その間ずっと Preset 表示のままになる = 統合されていない (handoff §2 第 2 版誤り教訓)
6. **`replace_all` の副作用注意** — `applyBatchPreset` → `applyBatchBaseLook` の rename で、内部に `applyBatchPreset` substring を含む `onReapplyBatchPresetBaseline` も `onReapplyBatchBaseLookBaseline` に副作用 rename された。awkward だが動く。次回はより慎重なパターン使用

---

## 14. 引継ぎ詳細プロンプト (最高精度版、新 chat へ verbatim paste)

> 以下の文章を新 chat に **そのまま貼り付け** ることで、本 lane を完璧に引き継げる。

---

### Verbatim handoff prompt

```
このリポは Filmtone (forestone film-lab 系プロダクト)。Desktop の "Preset → Look"
統一作業 (lane: feature/desktop-look-unification) を引き継いで完成まで進めたい。

**Status (2026-05-03 JST late evening)**:
Phase A + Phase B 両方が `feature/desktop-look-unification` worktree (
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification) に
local commit 済、verify gate 全 PASS、worktree clean。残るは push → main PR →
merge → Phase 1b chat A への伝達 → portfolio Web wrapper bump 別 PR。

**Branch**: `feature/desktop-look-unification`
**Worktree**: /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification
**Base**: main `732a273` (Backlight Veil)
**Phase A commit**: `1f99d68` (13 files +424/-9, core/schema additive layer)
**Phase B commit**: `fd9ddd2` (23 files +534/-415, Electron renderer + film-lab-ui sweep)

最初に必ず以下を順番に読んで完全文脈を復元してから作業に入る:

1. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/filmtone-desktop-look-unification-completion-handoff-2026-05-03-jst.md
   ← **本 lane の post-implementation standalone handoff (これだけで本 lane は
   引継ぎ可能)**。skim 禁止、§0 → §1 → §4 → §9 を最初に通読、§5・§6・§7・§10
   は実装 / 連携時に参照、§14 はこのプロンプト自身。

2. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md
   ← Recovery + resolution + 第 3 版 scope 確定根拠 + 元 §1〜§11 (worktree 喪失
   経緯)。歴史的経緯と OQ 最終決定の理由が必要なときに参照。

3. /Users/chibatakumi/.claude/plans/desktop-look-unification-bright-dusk.md
   ← 元 plan (lane の origin、Status: Implemented header 追加済)。core/schema
   加算の Design 節 (identity normalization) が必要なときに参照。

4. /Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md
   ← vocabulary canonical (Base Look / Finish Tool / Trim 3 層 taxonomy の正本)。
   §3 / §4 / §5 を vocab lock の根拠として参照。

5. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md
   ← project rules。§6 antipattern #5 に Look 用語ロック追記済 (commits
   1f99d68 + fd9ddd2 を起点として明記)。

6. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/archive/native-desktop-v2-legacy-2026-05-03/filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md
   の §6.5 (Concurrent Lane: Desktop Look Unification) と §10 (Sidecar
   Contract Case A/B 分岐)
   ← Native Desktop v2 側がどう Look Unification を消費するかの正本。
   本 PR の sidecar 契約はこれに整合済。**この worktree (filmtone-native-desktop-plan)
   は絶対に触らない** — Phase 1b chat A が同時編集中。

読み終わったら以下の grep / verify を実行して current state を確認:

  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification
  git log --oneline -5                                              # 1f99d68 + fd9ddd2 が見える
  git status                                                        # clean
  git worktree list | grep look-unification                         # worktree 残存確認

  # Phase A 着地 grep (worktree 上では PASS、main 上では未 merge)
  grep -E "^\s*BASE_LOOKS," packages/film-lab-core/src/index.ts
  grep "lookIdForBaseLook" packages/film-lab-core/src/look-ids.ts
  grep "normalizeFilmLookGradeInputIdentity" packages/film-lab-core/src/schema.ts

  # Phase B 着地 grep
  grep "FILM_LAB_LOOK_PRIMARY_SURFACE_ID" packages/film-lab-ui/src/filmLabUiContract.ts
  grep "LookSearchSelect" packages/film-lab-ui/src/PresetSearchSelect.tsx
  grep "baseLook:" packages/film-lab-ui/src/film-lab-reducer.ts
  grep "batchLookChoice" apps/desktop-film-lab-batch/src/renderer/App.tsx | head
  grep "builtInLook" apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts

  # i18n 値書き換え確認
  grep '"presets":' messages/en.json    # "Look" になっているはず
  grep '"presets":' messages/ja.json    # "ルック" になっているはず

  # verify gate 再現 (任意、時間がある時)
  bun install
  bun run build:core
  bun run typecheck:shared
  bun run typecheck:desktop
  bun test packages/film-lab-core packages/film-lab-ui
  cd apps/desktop-film-lab-batch && bunx vitest run --config vitest.config.ts
  # 期待: 286 pass / 1 skipped / 0 fail (39 test files)

絶対に守る invariants (handoff §10 critical invariants から再掲):

- Native Desktop v2 worktree (filmtone-native-desktop-plan) は **絶対に触らない**
- 生成 Swift (FilmtonePhase0Generated.swift 等) を手編集しない、generator のみ
- `FilmLabBatchSessionV1` の version bump しない (additive only、on-disk shape 固定)
- iOS Xcode project (apps/capacitor-film-lab-ios/) を編集しない
- packages/film-lab-renderer/dist/ packages/film-lab-smart-look/dist/ を消さない
  (submodule track 用、`.gitignore` に dist 追加禁止)
- PresetStrip.tsx (output format chooser) は対象外、film look ではない
- Smart Look の BaselineCandidate.basePreset / Creative Pack 01 の
  CreativePackLook.basePreset は **別概念**、対象外
- bun mandatory、npm 禁止
- 用語ロック: 動画 / video、短尺動画 禁止 / Look (× Preset) — vocab canonical
  は life docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md
- git は user 確認 (CLAUDE.md §11)、自動 commit / push 禁止
- JSX comment を return ( の直下に置かない
  (feedback_no_jsx_comment_outside_root_return)
- handoff doc 鵜呑み禁止、引用前に現行 surface (grep / Read) と突き合わせて
  live/frozen 確認 (feedback_verify_before_quoting_handoff)
- scope を chat 中で再議論しない、§4 locked-in を固定 (feedback_no_silent_stream_redefine)

設計判断は mcp__sequential-thinking で考える。記憶ベース断言は禁止。
不確かな Zod schema / film-lab-core symbol / film-lab-ui consumer の挙動は
grep / Read で必ず確認。

残タスク (handoff §9 から):

A. Ship rail (本 PR の最終配信、最優先):
  1. `git push -u origin feature/desktop-look-unification`
  2. `gh pr create` でタイトル "Filmtone Desktop Look Unification (Preset → Look canonical)"、
     description は handoff §0 / §5 / §6 から要約
  3. PR review + main merge

B. main merge 後の連動:
  4. Phase 1b chat A への「main merged → Case A 切替可」伝達 (§7.2 メッセージ案
     を使う、merge SHA を含めて伝達)
  5. Phase 1b master handoff §6.5 / §10 状態更新 (§7.3 patch を user 経由で
     適用、Native Desktop v2 worktree なので chat からは触らない)

C. 連動別 PR (Look Unification 完結に必要):
  6. portfolio (chibatakumi-portfolio) Web wrapper 更新 (§7.1) + submodule bump
     — 本 PR merge 直後に必須 (alias なし方針で build break する)
  7. iOS TS messages.ts:75 presetRowAriaLabel rename (§7.4) — 急がない
  8. iOS Swift FilmtoneStrings.swift:1580 "Preset Strength" rename (§7.4) —
     generator 経由、急がない
  9. generator (scripts/generate-filmtone-ios-swift.ts) Look-first emit (§7.5)
     — dirty 作業 main 取り込み後

D. 派生 (本 PR ship 後でも OK):
  10. LP / FAQ / marketing copy "presets" 単語 sweep (§7.6) — LP rewrite 別 lane
  11. export status template variable {preset} rename (§7.7) — i18n key + consumer
      同時更新が必要、別 PR
  12. PresetBar.tsx 扱い決定 (OQ #1 default = 放置)

E. 本 PR 無関係 (out of scope):
  13. ios-swift-payload.test.ts CONTRACT_DEFAULT_KEY_ORDER 2 件 fail
      (Backlight Veil drift、別 lane で fix)

優先順序:
最優先: 1 → 2 → 3 → 4 → 6
並行 / 任意: 5 (handoff sync)、7・8・9 (iOS catch-up)、10・11 (LP rewrite)、12・13

まず以下を user に確認してから着手 (順序 + 担当の 2 軸):

(i) push を chat に依頼するか、user 自身で実行するか
(ii) PR 作成を chat に `gh pr create` で依頼するか、user 自身で実行するか
(iii) PR description に handoff §0 / §5 / §6 の何を含めるか (default 提案: §0
     Resolution + §5 Phase A files + §6 Phase B files + §9 残タスク表 +
     §10 critical invariants の要約)
(iv) main merge 方式 (squash / merge commit)
(v) Phase 1b chat A への伝達タイミング (push 直後 vs main merge 後 — handoff
     §7.2 default 提案: main merge 後)

応答方針:
- 日本語、技術用語は英語可
- ファイル参照: path/to/file:line 形式
- 簡潔・行動志向
- mcp__sequential-thinking で設計判断
- 記憶ベース断言禁止、不確かな点は gemini-search / WebSearch で検証
```

---

## 15. このドキュメント自身について

- **ID / Date**: 2026-05-03 JST late evening
- **次の更新タイミング**: main merge 完了後 (§9.1 #3 完了時) に §0 / §9 を「merge 済、Phase 1b chat A 伝達済、portfolio bump 待ち」状態に更新
- **削除タイミング**: §9 全タスク完了 (portfolio bump merge + iOS catch-up merge + LP rewrite 着地) 後、archive / digest 化を検討
- **本 doc の親 doc**: `forestone/filmtone/docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md` (recovery + §0 Resolution)
- **本 doc の子 doc / 派生**: portfolio bump PR description / iOS catch-up PR description で本 doc §7.1 / §7.4 を参照する想定
