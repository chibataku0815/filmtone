# Filmtone iOS — Code Residual Handoff (chat 1, 2026-04-26 JST)

> 本 handoff doc は `.claude/tasks/active/2026-04-26-filmtone-ios-code-residual-plan.md` (life repo) を SSoT として、chat 1 で land した Stream 1 の現状と次 chat 引継ぎを記録する。`feedback_no_silent_stream_redefine` Anti-drift §8.5 対象 (本 doc §8.5 4 必須セクション参照)。

---

## 0. 現在地サマリ (3 行)

- **Stream 1 全 essence (D4.1 - D4.1.4) land 完了** — worktree `.worktrees/filmtone-ios-code-residual` / branch `feature/filmtone-ios-code-residual` (from `origin/main` `ddb2d60c`)、5 files +217/-2 modified、**uncommitted**。
- `bun run build` PASS / `bun test phase0-state.test.ts` **14/14 pass** / `git diff origin/main -- ios/` byte-identical (native 不変 = transitively xcodebuild-green from PR #40)。
- 残: **D4.1.5 (browser preview)** + **commit (user authorization 待ち)** + **Stream 2 (P2 #1 user 判断)** + **Stream 3/4 (品質保証希望時のみ)** + **Stream 5 (本 doc 化で COORD-1 完了、COORD-2/3 = memory + MEMORY.md は life repo 側で実施)**。

---

## 1. 何を作ったか (本質)

### 1.1 ユーザー価値

Filmtone iOS で **Portrait Depth Realism (ポートレート深度リアリズム)** toggle を Export sheet 上に出した。これにより:

- v1.3 で実装済の depth pipeline (Phase A still + Phase B video AVDepthDataTrack) が **user-activable** になる (これまでは UI 不在で完全 dark code、構造的に到達不能だった)
- ON/OFF は session-only (アプリ再起動で OFF にリセット)
- ソースに portrait depth が無いと自動で disabled + "ソースにポートレート深度データが必要です" notice 表示
- Wire は v1.1/v1.2 と完全互換: OFF (default) は `request.depthEnabled` を emit せず、ON のみ `request.depthEnabled = true`

### 1.2 設計確定 (plan §6 verbatim 適用)

| 論点 | 決定 |
|---|---|
| 配置 | ExportSheet 内 RenderModeToggle 直下 (新 Settings page 作らない = 本質優先・外殻最小) |
| UI label JP | 「ポートレート深度リアリズム」(CD 指定で JP 翻訳。renderMode `Master/Postcard` untranslated 方針とは別判断) |
| UI label EN | 「Portrait Depth Realism」 |
| Wire pattern | Postcard 完全 mirror — OFF ≡ wire absent ≡ native gate `?? false` で false。ON のみ `request.depthEnabled = true` を emit |
| `available` 判定 | `probe?.hasDepth === true` (TS DTO に既存。Phase A D1.3 で AssetPickerService が HEIC sniff、Phase B で AVURLAsset.loadTracks(.depthData) も追加済) |
| `depthRenderer` | `nil` 維持 (Phase B 1 種類のみ、選択肢無し) |
| hiddenDefaults gain 値 | **本 chat では touch しない** (D5.5 CD承認 gate)。toggle ON でも視覚上 inert は許容 |
| Profile.version | v=4 維持 (depthEnabled は既に signature payload に含まれている) |
| Sidecar V1 | schemaVersion 不変 (Phase A D3.5 で既に depthEnabled 出力済) |

---

## 2. 実装変更ファイル (5 file / +217 / -2)

ベース: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-code-residual/`

| ファイル | 変更 | 担当 Team |
|---|---|---|
| `apps/capacitor-film-lab-ios/src/lib/phase0-state.ts` | +42/-2 | Team A |
| `apps/capacitor-film-lab-ios/src/lib/phase0-state.test.ts` | +54/-0 | Team A |
| `apps/capacitor-film-lab-ios/src/lib/messages.ts` | +11/-0 | Team B |
| `apps/capacitor-film-lab-ios/src/features/export/ExportSheet.tsx` | +104/-0 | Team C |
| `apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx` | +8/-0 | Team C |
| **合計** | **+219/-2** | (うち 5 files、217 net 加算) |

### 2.1 phase0-state.ts (Team A)

- 新 constant `PHASE0_DEPTH_ENABLED_DEFAULT: boolean = false`
- 新 field `Phase0EditorState.depthEnabled: boolean`
- `createInitialEditorState` に `depthEnabled: PHASE0_DEPTH_ENABLED_DEFAULT` 追加
- 新 reducer `applyDepthEnabled(state, enabled)` — identity-preserving on no-op
- `buildEditorExportRequest` 拡張: tail を `let request = base; if (renderMode === "speed") {...}; if (depthEnabled) {...}; return request;` パターンに refactor

### 2.2 phase0-state.test.ts (Team A)

新 5 test (既存 9 → 14、`applyRenderMode` の既存 convention に整合):

1. `initial state defaults depthEnabled to false (Off, wire-absent)`
2. `applyDepthEnabled flips between ON and OFF without touching project`
3. `applyDepthEnabled is a no-op when value is unchanged (preserves identity)`
4. `buildEditorExportRequest omits depthEnabled when OFF (default, v1.1/v1.2 wire-compat)`
5. `buildEditorExportRequest emits depthEnabled=true when toggle ON`

> 注: plan §6.1.7 は 4 cases と記載していたが、`applyDepthEnabled` を flip と no-op-identity の 2 test に分けるのが既存 `applyRenderMode` の convention なので 5 を採用。functional には等価で、convention 整合の方が repo 全体として一貫性が高い。

### 2.3 messages.ts (Team B)

`appCopy.en` と `appCopy.ja` に各 4 keys 追加 (合計 8 entries):

- `depthRealismSectionLabel` ("REALISM" / "リアリズム")
- `depthRealismToggleLabel` ("Portrait Depth Realism" / "ポートレート深度リアリズム")
- `depthRealismTooltip` ("Separates mist, glow, and halation intensity between subject and background using portrait depth." / "ポートレート深度を使い、被写体と背景で霞・グロウ・ハレーションの強度を分離します。")
- `depthRealismUnavailable` ("Source needs portrait depth data." / "ソースにポートレート深度データが必要です。")

`getAppStrings` は `...base` spread 済なので追加変更不要。`AppStrings = ReturnType<typeof getAppStrings>` で型に自動反映。

### 2.4 ExportSheet.tsx (Team C)

- `ExportSheetProps` 拡張: `depthEnabled: boolean` / `depthAvailable: boolean` / `strings.depthRealism*` 4 strings / `onDepthEnabledChange: (enabled: boolean) => void`
- `ExportSheet({ ... })` destructure に追加
- JSX 配置: `<RenderModeToggle ... />` 直下、`{probe && violations.length > 0 ? ... }` の前
- 新 component `DepthRealismToggle` を file 末尾に追加 — `role="switch"` + `aria-checked`、full-width pill button + sliding knob、disabled 時 unavailable notice 表示

### 2.5 MobilePhase0Editor.tsx (Team C)

- `applyDepthEnabled` を `@/lib/phase0-state` named import に追加
- 新 handler `handleDepthEnabledChange(enabled: boolean)` (`handleRenderModeChange` mirror)
- `<ExportSheet ... />` JSX に `depthEnabled={state.depthEnabled}` / `depthAvailable={state.probe?.hasDepth === true}` / `onDepthEnabledChange={handleDepthEnabledChange}` を threading

---

## 3. 検証結果 (exit gate)

| 項目 | 結果 |
|---|---|
| `bun run build` (capacitor-film-lab-ios) | ✅ `tsc --noEmit && vite build` PASS、4785 modules transformed in 935ms |
| `bun test src/lib/phase0-state.test.ts` | ✅ 14 pass / 0 fail / 37 expect() calls (既存 9 + 新 5) |
| `git diff origin/main -- 'apps/capacitor-film-lab-ios/ios/'` | ✅ **空** (native 完全 byte-identical) |
| `git diff origin/main -- DTO files (FilmtoneMediaTypes.swift / native-bridge.ts)` | ✅ **空** |
| `git diff origin/main -- 'FilmtonePhase0Generated.swift'` | ✅ **空** (hiddenDefaults 不変) |
| `git diff origin/main -- 'Info.plist'` | ✅ **空** (UIBackgroundModes 不在維持) |
| 修正 file 数 | ✅ **5 files** (plan §11 と完全一致) |
| Profile.version | ✅ v=4 維持 (touch なし) |
| Sidecar V1 | ✅ schemaVersion 不変 (touch なし) |
| `xcodebuild -workspace App.xcworkspace -scheme App` | ⚠️ worktree 内未実行 (Pods 不在 + Ruby 4.0.3 mise install 未着手 = 外殻 yak-shaving)。ただし上記 `git diff` で **native byte-identical to `ddb2d60c` (PR #40 merge = xcodebuild-green)** が確認済 = transitively green |

---

## 4. 残タスク (full enumeration、Anti-drift §8.5 対象)

### 4.1 Stream 1 残 (1 件)

- [ ] **D4.1.5** Storybook / visual QA — **user action**:
  ```bash
  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-code-residual/apps/capacitor-film-lab-ios
  bun run dev
  # ブラウザで http://localhost:5173 開く
  # ExportSheet 内で "Portrait Depth Realism" toggle 操作
  # probe.hasDepth=null/undefined のモック源で disabled + "ソースに必要" notice 表示確認
  ```

### 4.2 Stream 2 (user 判断 必要、code 改修なし or 0.3d)

- [ ] **P2-1.0** **user judgment**: v1.2 P2 #1 (Quality + SDR source) 仕様 — 案 A (no-op) or 案 B (variant-matched SDR fallback)
- [ ] **P2-1.1 - P2-1.3** [案 B 採用時のみ] `FilmtoneExportSession.swift:1866-1888` Quality gate を variant-matched mezzanine に置換

### 4.3 Stream 3 (Optional housekeeping、0.2d) — 品質保証希望時のみ

- [ ] **HK-1.1** Video depth defense fast-path: `resolveVideoDepthReader(asset:)` に `allGainsZero` short-circuit 追加 (D5.5 CD承認 後に意味出る)
- [ ] **HK-1.2** `videoDepthSource` label simplification: `"AVDepthDataTrack-Generic"` → `"AVDepthDataTrack"`
- [ ] **HK-1.3** Sidecar fixture test update (該当あれば)

### 4.4 Stream 4 (XCTest target setup + 6 unit tests、1.0d) — 品質保証希望時のみ

- [ ] **TEST-S1** Ruby `xcodeproj` gem 経由で `AppTests` unit test target を追加 (§6.4.1)
- [ ] **TEST-S2** `App/Tests/` directory 新設、6 test file scaffold
- [ ] **TEST-L1.5** `ExportCancelControllerTests.swift`
- [ ] **TEST-L2.5** `WritingTailTests.swift`
- [ ] **TEST-L3.9** `FilmtoneExportLiveActivityTests.swift`
- [ ] **TEST-L4.6** `FilmtoneExportNotificationTests.swift`
- [ ] **TEST-D1.4** `DepthSourceServiceTests.swift`
- [ ] **TEST-D2.6** `FilmtoneDepthPrefilterTests.swift`
- [ ] **TEST-S3** `xcodebuild test -scheme App` green 確認

### 4.5 Stream 5 (Coordination)

- [x] **COORD-1** 本 handoff doc 作成 — chat 1 で land
- [ ] **COORD-2** life-side memory `~/.claude/projects/.../memory/filmtone_ios_code_residual_active.md` 新設 — chat 1 末尾で実施 (life repo 側)
- [ ] **COORD-3** life-side `MEMORY.md` index entry 追加 — chat 1 末尾で実施 (life repo 側)

### 4.6 Commit + push (user authorization 必須)

CLAUDE.md §11 「Git操作はユーザーが行う（自動コミット禁止）」に従い、本 chat ではコミットしていない。user authorization 後、以下の commit を推奨:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-code-residual
git add apps/capacitor-film-lab-ios/src/lib/phase0-state.ts \
        apps/capacitor-film-lab-ios/src/lib/phase0-state.test.ts \
        apps/capacitor-film-lab-ios/src/lib/messages.ts \
        apps/capacitor-film-lab-ios/src/features/export/ExportSheet.tsx \
        apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx
git commit -m "feat(filmtone-ios): land v1.3 Portrait Depth Realism toggle

Activate the v1.3 depth pipeline (still + video AVDepthDataTrack) by
exposing a UI toggle on the Export sheet. Mirrors the Postcard wire
pattern (OFF=absent, ON=request.depthEnabled=true) for v1.1/v1.2
backward-compat. Visual gain is still hiddenDefaults-zero pending
CD-approved flip (D5.5).

- ExportSheet: new DepthRealismToggle subcomponent (role=switch, pill
  with sliding knob), placed below RenderModeToggle
- phase0-state: depthEnabled field + applyDepthEnabled reducer,
  buildEditorExportRequest emits the wire flag only when ON
- MobilePhase0Editor: handleDepthEnabledChange + thread props
  (depthAvailable derived from probe?.hasDepth === true)
- messages: 4 i18n keys × en/ja (CD-approved JP translation here,
  diverging from renderMode untranslated rule)
- phase0-state.test: +5 cases (default OFF / flip / no-op identity /
  wire absent on OFF / wire emit on ON), 14/14 pass
- Native byte-identical to origin/main; profile.version=4, sidecar V1,
  hiddenDefaults all unchanged" \
  -m "Plan: .claude/tasks/active/2026-04-26-filmtone-ios-code-residual-plan.md (Stream 1)
Handoff: docs/guides/2026-04-26-filmtone-ios-code-residual-handoff.md"
```

> 上記 message body の "Plan: .claude/..." は life repo 側のパス参照。chibatakumi-portfolio repo にはこの doc は無いため、リンクではなく文字列としての参照。

---

## 5. 引継ぎ用起動プロンプト (次 chat verbatim copy)

> Filmtone iOS Code Residual の続きを進める。本 chat 1 で **Stream 1 全 essence (D4.1 - D4.1.4) land 完了** (uncommitted、5 files +217/-2、`bun test 14/14`、`bun run build` PASS、native byte-identical)。
>
> 起動前提:
> 1. `.claude/tasks/active/2026-04-26-filmtone-ios-code-residual-plan.md` (life repo) を Read — Stream 1 の [x] 化を確認、§16 の chat 1 update 行を参照
> 2. `docs/guides/2026-04-26-filmtone-ios-code-residual-handoff.md` (chibatakumi-portfolio worktree) を Read — 本 doc の §3 検証結果 + §4 残タスク全列挙を参照
> 3. worktree に cd: `cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-code-residual`
> 4. `git status` で uncommitted 5 files を確認、必要なら `git diff origin/main` で再検証
>
> 次の選択肢 (user 指示で分岐):
>
> **Option α (commit + push)**: §4.6 の commit 文をそのまま実行 → push → PR draft 検討。Stream 1 の land を確定する最短ルート。
>
> **Option β (browser preview = D4.1.5)**: `bun run dev` で localhost を立て、ExportSheet 内 toggle 動作を実機 / シミュレーション確認。確認後に Option α へ。
>
> **Option γ (Stream 2 = v1.2 P2 #1 user 判断)**: 案 A (no-op、release note 補足のみ) or 案 B (variant-matched SDR fallback、code 改修) を確定。案 B 採用時は §6.2.2 spec で `FilmtoneExportSession.swift:1866-1888` 改修。
>
> **Option δ (Stream 3 + Stream 4 = 品質保証 wave)**: housekeeping + XCTest target setup を実施。`xcodeproj` gem (Ruby) 必要、user 環境で mise Ruby 4.0.3 install から (現状未 install)。
>
> 推奨順: Option β (確認) → Option α (commit) → Option γ (P2 #1 判断) → Option δ (品質保証希望時)。
>
> Anti-drift: chat 終了時に handoff doc §8.5 4 必須セクションを更新。

---

## 6. Risk / 既知の制約

| リスク | 状態 | 緩和策 |
|---|---|---|
| Stream 1 toggle ON でも視覚上 inert (gain 全 0) | **既知** | tooltip に効果説明あり、`hiddenDefaults` flip は D5.5 CD承認 gate (本 chat scope 外)、release narrative で「2026 Q3 で gain 値調整予定」明示推奨 |
| `xcodebuild` worktree 内未実行 | **代替検証済** | `git diff origin/main -- 'ios/'` byte-identical で transitively green。明示確認したい場合は main checkout で `bunx cap sync ios` 後に xcodebuild 可 |
| 本 worktree で `bun install` 実施済 (`node_modules` 2081 packages) | **正常** | worktree 用の独立 `node_modules`、main checkout に影響なし |
| renewal-2026 の uncommitted 作業 (main checkout `2e68873d` ahead 5 + 12 modified) | **不干渉** | 別 branch / 別 worktree 構成で完全 isolation |
| Stream 4 の AppTests target 追加で Capacitor sync が壊れる可能性 | **未到達** | Stream 4 は Option δ で別途検証必要 |

---

## 7. Cross-stream visibility

| Stream | 状態 | 備考 |
|---|---|---|
| Stream 1 (WebView depth toggle) | ✅ **essence land 完了** (D4.1 - D4.1.4 closed、D4.1.5 = browser preview のみ user action 待ち) | Agent Teams 3 並列で 1 chat 内 land |
| Stream 2 (v1.2 P2 #1 仕様判断) | ⏸ **user 判断ブロック** | Code touch なし、判断のみ |
| Stream 3 (housekeeping) | ⏸ **deferred** (品質保証希望時) | Stream 1 land 後に意味出る (allGainsZero short-circuit は D5.5 CD承認 後でないと常に発火) |
| Stream 4 (XCTest target setup) | ⏸ **deferred** (品質保証希望時) | Ruby 4.0.3 mise install から必要、外殻 cost 高 |
| Stream 5 (Coordination) | 🟢 **partial** (COORD-1 = 本 doc 完了、COORD-2/3 = life-side memory + MEMORY.md は chat 末尾で実施) | |

---

## 8. Anti-drift §8.5 4 必須セクション

### 8.1 Plan Compliance Audit

§7 deliverable 全列挙のうち本 chat 1 touched 状態:

**Stream 1 (touched)**:
- D4.1 / D4.1.1 / D4.1.2 / D4.1.3 / D4.2 / D4.3 / D4.4 / D4.1.4 = **8 closed**
- D4.1.5 = **partial** (実装側完了、user manual QA 待ち)

**Stream 2 (skipped)**:
- P2-1.0 / P2-1.1 / P2-1.2 / P2-1.3 = **0 closed** (全 user 判断ブロック扱い、本 chat scope 外)

**Stream 3 (skipped)**:
- HK-1.1 / HK-1.2 / HK-1.3 = **0 closed** (品質保証 wave に deferred)

**Stream 4 (skipped)**:
- TEST-S1 / TEST-S2 / TEST-L1.5 / TEST-L2.5 / TEST-L3.9 / TEST-L4.6 / TEST-D1.4 / TEST-D2.6 / TEST-S3 = **0 closed** (品質保証 wave に deferred)

**Stream 5 (touched)**:
- COORD-1 = **closed** (本 doc)
- COORD-2 / COORD-3 = chat 1 末尾で life-side 実施

### 8.2 Cross-Stream Visibility

§7 セクション参照 (本 doc §7)。Stream 1 essence 完了、Stream 2/3/4 は明示 deferred declare、Stream 5 は partial declare。

### 8.3 Scope Diff Table

| 本 chat 開始時 plan | 本 chat 終了時実態 | 差分理由 |
|---|---|---|
| D4.1.4 = 4 new test cases | 5 cases 実装 | `applyDepthEnabled` を flip と no-op-identity に分割 = `applyRenderMode` 既存 convention 整合 (functional 等価、品質向上) |
| D4.4 prop name = `available` | `depthAvailable` に rename | `available` は generic 過ぎる、ExportSheetProps 内で意味明示 (top-level prop は接頭辞付与) |
| §10 exit gate `xcodebuild ... ** BUILD SUCCEEDED **` 直接実行想定 | worktree で transitively 検証 (git diff byte-identical) | worktree 内 Pods 不在 + Ruby 4.0.3 install = 外殻 yak-shaving、本質 (native 不変) は git diff で確認可。明示 xcodebuild は main checkout で post-hoc 実施可 |
| `bun test phase0-state.test.ts` 期待 13 pass | 実際 14 pass | 上記 D4.1.4 の test 5 cases に伴う |

### 8.4 残タスク full enumeration

§4 全節 (4.1 - 4.6) 参照。Stream 1 残 1 + Stream 2 残 4 + Stream 3 残 3 + Stream 4 残 9 + Stream 5 残 2 + commit 1 = **計 20 項目**。

---

## 9. Reference

- Plan SSoT: `.claude/tasks/active/2026-04-26-filmtone-ios-code-residual-plan.md` (life repo)
- 関連 handoff:
  - `docs/guides/2026-04-26-filmtone-ios-v1-3-depth-coupling-handoff.md` (Phase A + Phase B 既存実装)
  - `docs/guides/2026-04-26-filmtone-ios-v1-3-foreground-resilient-export-ux-handoff.md` (chat 1+2+3 既存実装)
  - `docs/guides/2026-04-26-filmtone-ios-v1-2-hdr-mezzanine-handoff.md` (P2 #1 文脈)
- Memory (life repo `~/.claude/projects/.../memory/`):
  - `filmtone_ios_v1_3_depth_coupling_active.md`
  - `filmtone_ios_v1_3_foreground_resilient_active.md`
  - `filmtone_ios_export_speedup_v12_active.md`
  - `filmtone_ios_v1_1_live.md`
  - `filmtone_ios_code_residual_active.md` (chat 1 で新設)

---

*chat 1 終了時 (2026-04-26 JST). next chat 起動プロンプトは §5 verbatim.*
