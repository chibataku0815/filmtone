# Filmtone iOS — Code Residual Handoff (chat 1+2+3, 2026-04-26 JST)

> 本 handoff doc は `.claude/tasks/active/2026-04-26-filmtone-ios-code-residual-plan.md` (life repo) を SSoT として、chat 1/2/3 で land した Stream 1+2+3 の現状と次 chat 引継ぎを記録する。`feedback_no_silent_stream_redefine` Anti-drift §8.5 対象 (本 doc §8.5 4 必須セクション参照、§10 chat 3 update も参照)。

---

## 0. 現在地サマリ (chat 3 終了時点)

- **Stream 1** (WebView depth toggle, D4.1-D4.1.4) — ✅ chat 1 essence land、chat 2 commit + push (`e1eb0b2b on feature/filmtone-ios-code-residual`、5 src + 1 handoff doc)
- **Stream 2** (v1.2 P2 #1 案 B = variant-matched SDR Quality fallback) — ✅ chat 3 essence land (uncommitted、user 指示「保守的意見不採用・プロダクト品質最優先」より案 B 採用)
- **Stream 3** (Optional housekeeping HK-1.1/1.2/1.3) — ✅ chat 3 essence land (uncommitted、Agent A 実装 + plan 仕様の `depthHalationGain` 不在判明 → 2-field 判定に修正、`AVDepthDataTrack-Generic` → `AVDepthDataTrack` 3 箇所更新、sidecar fixture test = no-op)
- **chat 3 累積 diff** (`e1eb0b2b..HEAD` uncommitted): 2 files = `FilmtoneExportSession.swift` (+47/-8) + `FilmtoneMediaTypes.swift` (+6/-3)。`swiftc -parse` clean、`bun run build` PASS、`bun test phase0-state.test.ts` 14/14 pass、`grep AVDepthDataTrack-Generic` 0 hit。
- **残**: commit + push (user authorization 待ち、本 chat handoff timing) + COORD-2/3 (life-side memory + MEMORY.md update) + Stream 4 (XCTest 6 並列、外殻 = 品質保証希望時のみ) + D4.1.5 (browser preview) + P2-1.3 (device QA log 確認)。

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

### 4.2 Stream 2 (chat 3 で land、device QA のみ残)

- [x] **P2-1.0** user judgment: **案 B** 採用 (chat 3、user 指示「保守的意見不採用・プロダクト品質最優先」)
- [x] **P2-1.1** Quality gate を `FilmtoneExportSession.swift:2203-2224` (実線; 当初 plan の 1866-1888 は version 進捗で line ずれ判明) で variant-matched に置換
- [x] **P2-1.2** `existingMezzanineURL(for: sourceURL, variant: sourceVariant)` 呼び出しに置換、Speed branch 不変
- [ ] **P2-1.3** xcodebuild + SDR ProRes fixture log 確認 — **device QA wave deferred** (本 chat scope 外。代替検証: `swiftc -parse` clean + `git diff` で v1.2 Speed branch byte-identical 確認 + `filmtonePreviewCompositionDebugLog` log 追加)

### 4.3 Stream 3 (chat 3 で land、deferred 解除)

- [x] **HK-1.1** Video depth defense fast-path: `FilmtoneExportSession.swift:1799-1816` で short-circuit 追加。**deviation**: plan 仕様の `depthHalationGain` フィールド不在判明 (halation variant 呼び出し側で `depthGlowGain` 流用) → `depthMistGain == 0 && depthGlowGain == 0` 2-field 判定に修正。`profile.hiddenDefaults` ではなく `FilmtonePhase0Generated.hiddenDefaults` 直接参照 (line 1136 の既存 pattern 整合)。`NSLog` 採用 (line 486 既存 pattern 整合)
- [x] **HK-1.2** `videoDepthSource` label simplification: `"AVDepthDataTrack-Generic"` → `"AVDepthDataTrack"` を 3 箇所更新 (`FilmtoneExportSession.swift:42` doc / `:311` literal / `FilmtoneMediaTypes.swift:573-578` doc)。`grep AVDepthDataTrack-Generic` 0 hit
- [x] **HK-1.3** Sidecar fixture test = **no-op** (`scripts/swift/test-sidecar-builder.swift` + `verify-phase0-contract.sh` + `fixtures/` に該当 assert 0 件)

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

> Filmtone iOS Code Residual の続きを進める。本 chat 3 で **Stream 2 案 B + Stream 3 (HK-1.1/1.2/1.3) 全 essence land 完了** (chat handoff timing で commit + push 推奨)。Stream 1 は chat 2 で `e1eb0b2b` push 済。
>
> 起動前提:
> 1. `.claude/tasks/active/2026-04-26-filmtone-ios-code-residual-plan.md` (life repo) を Read — Stream 1/2/3 の [x] 化を確認、§16 の chat 1+2+3 update 行を参照
> 2. `docs/guides/2026-04-26-filmtone-ios-code-residual-handoff.md` (chibatakumi-portfolio worktree) を Read — 本 doc の §0 サマリ + §4 残タスク全列挙 + §10 chat 3 update を参照
> 3. worktree に cd: `cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-code-residual`
> 4. `git status` で uncommitted 状態を確認 (commit handoff 中なら 2 files modified、push 後なら clean)
>
> 次の選択肢 (user 指示で分岐):
>
> **Option ε (PR open + merge prep)**: `gh pr create` で `feature/filmtone-ios-code-residual` → `main` を draft 作成。Stream 1+2+3 essence 全 land 済、release narrative の文面検討に進む。
>
> **Option γ' (release note 案 B 文面化)**: case B (variant-matched SDR Quality fallback) のリリースノート + sidecar consumer ドキュメント (variant=sdr が `mezzanine.variantUsed` で観測可能になる旨) を準備。release prep chat に渡す素材。
>
> **Option δ (Stream 4 = QA infra wave、品質保証希望時のみ)**: XCTest target setup (Ruby `xcodeproj` gem) + 6 unit test files (L1.5 / L2.5 / L3.9 / L4.6 / D1.4 / D2.6) を Agent Teams 6 並列で land。Ruby 4.0.3 mise install から (cost 高、external dependency あり)。
>
> **Option β (browser preview = D4.1.5)**: `bun run dev` で localhost を立て、ExportSheet 内 depth toggle 動作を browser 上で確認。release narrative 用 screenshot にも転用可。
>
> 推奨順: Option ε (PR) → Option γ' (release narrative) → Option δ (QA wave) → Option β (browser QA は user 直接実施で十分)。
>
> Anti-drift: chat 終了時に handoff doc §8.5 4 必須セクションを更新 (本 chat は §10 で対応済)。

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

## 7. Cross-stream visibility (chat 3 終了時点)

| Stream | 状態 | 備考 |
|---|---|---|
| Stream 1 (WebView depth toggle) | ✅ **commit + push 完了** (`e1eb0b2b`、chat 1 essence + chat 2 commit) | D4.1.5 (browser preview) のみ user action 残 |
| Stream 2 (v1.2 P2 #1 案 B = variant-matched SDR Quality fallback) | ✅ **essence land 完了 (uncommitted、chat 3)** | 案 B 採用 (user 指示「保守的意見不採用・プロダクト品質最優先」)。P2-1.3 device QA log のみ残 |
| Stream 3 (housekeeping) | ✅ **essence land 完了 (uncommitted、chat 3)** | HK-1.1/1.2/1.3 全 closed。HK-1.1 は plan 仕様の `depthHalationGain` 不在で 2-field 判定に修正 |
| Stream 4 (XCTest target setup) | ⏸ **deferred** (品質保証希望時のみ) | user policy「外殻は QA 希望時のみ」につき本 chat 群 skip。Ruby 4.0.3 mise install + xcodeproj gem 1.23.0 が前提 |
| Stream 5 (Coordination) | 🟢 **本 chat 内で完了見込み** (COORD-1 = 本 doc 更新済、COORD-2/3 = chat 3 末尾で life-side 実施予定) | |

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

*chat 1 終了時 (2026-04-26 JST). chat 2/3 update は §10 verbatim.*

---

## 10. chat 2/3 update (2026-04-26 JST)

### 10.1 chat 2: Stream 1 commit + push

`e1eb0b2b` on `feature/filmtone-ios-code-residual` push 済。chat 1 で land した 5 src + 1 handoff doc を「feat(filmtone-ios): land v1.3 Portrait Depth Realism toggle」として 1 commit にまとめた。CLAUDE.md §11 user authorization を経て実施、push 後 working tree clean を確認。

### 10.2 chat 3: Stream 2 案 B + Stream 3 essence land

**user 判断**: chat 3 冒頭で AskUserQuestion 経由で「Stream 2 案 A or 案 B」を提示。user 回答「本質の進行を最優先保守的な意見は優先せずにプロダクトの品質を最優先してください」を受け、**案 B (variant-matched SDR Quality fallback) 採用**を確定。同時に handoff timing は「Stream 2 + Stream 3 を 1 commit にまとめて land 後 (Recommended)」を選択。

**実装フロー** (Agent Teams 並列 + main thread):
- **Agent A (engineer subagent)** = Stream 3 HK-1.1/1.2/1.3 native 実装 + validation
- **Agent B (Explore subagent)** = Stream 2 案 B feasibility 調査 + patch 設計 (read-only)
- **main thread** = Agent B の patch 設計を確認後、Stream 2 案 B 実装 (`FilmtoneExportSession.swift:2203-2224`) を直接適用

**Stream 2 案 B の実装内容** (`FilmtoneExportSession.swift:2203-2243`):
- `sourceVariant: ProfileVariant` を `request.sourceProbe?.sourceVideoMetadata?.colorClass == .sdrBt709 ? .sdr : .hdr` (nil → `.hdr` 安全側 default) で派生
- Quality branch: `mezz.existingMezzanineURL(for: sourceURL, variant: sourceVariant)` で variant-matched 取得、無ければ source-direct fallback
- Speed branch: 不変 (HDR-preferred → SDR-fallback → source、v1.2 Wave 4 から byte-identical)
- `filmtonePreviewCompositionDebugLog("Quality gate: matched sdr/hdr source to ... mezzanine")` で DEBUG 観測可能

**Stream 3 の実装内容**:
- HK-1.1 (`FilmtoneExportSession.swift:1799-1816`): `resolveVideoDepthReader(asset:)` に defense fast-path 追加。**deviation**: plan §6.3.1 は `depthHalationGain` 参照だが現実コードでは halation variant 呼び出し側で `depthGlowGain` 流用 (line 1187) → `depthMistGain == 0 && depthGlowGain == 0` の 2-field 判定に修正。`profile.hiddenDefaults` ではなく `FilmtonePhase0Generated.hiddenDefaults` 直接参照 (line 1136 の既存 pattern 整合)。`NSLog` 採用 (line 486 既存 pattern 整合)
- HK-1.2 (`FilmtoneExportSession.swift:42` doc / `:311` literal / `FilmtoneMediaTypes.swift:573-578` doc): `AVDepthDataTrack-Generic` → `AVDepthDataTrack` 3 箇所更新、`grep AVDepthDataTrack-Generic` 0 hit
- HK-1.3 = no-op (該当 fixture assert 0 件確認済)

**chat 3 累積 diff**:
```
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift   | 55 +++++++++++++++-------
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift      |  6 ++--
2 files changed, 47 insertions(+), 14 deletions(-)
```

**chat 3 検証結果**:

| 項目 | 結果 |
|---|---|
| `swiftc -parse FilmtoneExportSession.swift` (iphonesimulator SDK) | ✅ error 0 |
| `bun run build` (capacitor-film-lab-ios) | ✅ 4785 modules transformed in 722ms |
| `bun test src/lib/phase0-state.test.ts` | ✅ 14 pass / 0 fail (回帰なし) |
| `grep -rn "AVDepthDataTrack-Generic"` (swift/ts/tsx) | ✅ 0 matches |
| `git diff --stat` | ✅ 2 files (+47/-14)、Stream 2/3 のみ touch |
| Profile.version | ✅ v=4 維持 (touch なし) |
| Sidecar V1 schemaVersion | ✅ 不変 |
| `Info.plist` / `UIBackgroundModes` | ✅ 不変 |
| hiddenDefaults gain 値 | ✅ 不変 (read のみ、D5.5 CD承認 gate 尊重) |
| xcodebuild | ⚠️ worktree 内 Pods 不在で skip。`swiftc -parse` clean + 既存 pattern 整合 + git diff `e1eb0b2b..HEAD` 経由で transitively green を期待 (xcodebuild は main checkout 経由で post-hoc 検証可) |

### 10.3 commit message (chat 3 land、user authorization 経由)

```
feat(filmtone-ios): land v1.3 Stream 2 案 B + Stream 3 housekeeping

Stream 2 (v1.2 P2 #1 案 B = variant-matched SDR Quality fallback):
Quality mode now matches the mezzanine variant to the source color
class — HDR sources still prefer the HDR mezzanine, SDR (BT.709)
sources prefer the SDR mezzanine. An SDR source has no wide-gamut data
to preserve, so an SDR mezzanine is a faithful rebuild (not silent
degradation). When the matched mezzanine is absent we fall back to the
v1.1 source-direct path. Sources without color metadata default to HDR.
Speed branch is byte-identical to v1.2 Wave 4.

Stream 3 (Optional housekeeping):
- HK-1.1: defense fast-path in resolveVideoDepthReader skips the
  asset-side AVDepthDataTrack probe + reader bring-up when both
  depthMistGain and depthGlowGain are zero in the active profile.
  Today this is dead code (gains are 0 by D5.5 CD-approved gate); it
  becomes a real win once the gains flip.
- HK-1.2: simplify videoDepthSource sidecar label
  ("AVDepthDataTrack-Generic" → "AVDepthDataTrack"). Phase B never
  ships another variant — drop the discriminator suffix now.
- HK-1.3: sidecar fixture tests are no-op (no asserts on the old
  label).

Native byte-identical to v1.1/v1.2 ship surfaces:
- Profile.version = 4 (unchanged)
- sidecar V1 schemaVersion (unchanged)
- hiddenDefaults gain values (read-only, D5.5 gate respected)
- Info.plist UIBackgroundModes (unchanged)
- DTO files (unchanged)

Plan: .claude/tasks/active/2026-04-26-filmtone-ios-code-residual-plan.md (Stream 2 + Stream 3, chat 3)
Handoff: docs/guides/2026-04-26-filmtone-ios-code-residual-handoff.md §10
```

### 10.4 chat 3 anti-drift §8.5 4 セクション

#### 10.4.1 Plan Compliance Audit

§7 deliverable 全列挙のうち本 chat 3 touched 状態:

**Stream 2 (touched)**:
- P2-1.0 / P2-1.1 / P2-1.2 = **3 closed** (案 B 採用 + Quality gate 置換 + variant-matched 呼び出し)
- P2-1.3 = **partial** (代替検証 = swiftc-parse + git diff + log 追加)

**Stream 3 (touched)**:
- HK-1.1 / HK-1.2 / HK-1.3 = **3 closed** (HK-1.3 は no-op、HK-1.1 は spec deviation あり = 上記 §10.2 参照)

**Stream 1 (chat 2 で touched、chat 3 では unchanged)**:
- D4.1 - D4.1.4 = closed、D4.1.5 = partial (browser preview = user action)

**Stream 4 (skipped)**:
- TEST-S1 / TEST-S2 / TEST-L1.5 / TEST-L2.5 / TEST-L3.9 / TEST-L4.6 / TEST-D1.4 / TEST-D2.6 / TEST-S3 = **0 closed** (user policy「外殻は QA 希望時のみ」につき deferred 維持)

**Stream 5 (touched)**:
- COORD-1 = **closed** (本 doc 更新で chat 3 状態反映)
- COORD-2 / COORD-3 = chat 3 末尾で life-side 実施予定

#### 10.4.2 Cross-Stream Visibility

§7 セクション参照 (chat 3 状態に更新済)。Stream 1 = ship-pushed、Stream 2/3 = essence-landed-uncommitted、Stream 4 = 明示 deferred、Stream 5 = ほぼ完了見込み。

#### 10.4.3 Scope Diff Table (chat 3)

| 本 chat 3 開始時 plan | 本 chat 3 終了時実態 | 差分理由 |
|---|---|---|
| §6.3.1 HK-1.1 = `depthMistGain == 0 && depthGlowGain == 0 && depthHalationGain == 0` の 3-field 判定 | 実装は `depthMistGain == 0 && depthGlowGain == 0` の 2-field 判定 | `FilmtonePhase0Generated.hiddenDefaults` に `depthHalationGain` フィールド不在判明 (halation variant 呼び出し側で `depthGlowGain` 流用、line 1187)。spec を実コードに合わせた |
| §6.3.1 fast-path の log = `log.info("Video depth track decode skipped ...")` | 実装は `NSLog("FilmtoneExportSession: video depth track decode skipped ...")` | 既存 line 486 の log pattern と整合 |
| §6.2.2 patch line range = `1866-1888` | 実線は `2203-2224` | v1.2 Wave 4 + v1.3 depth/foreground land 後で line 番号進捗、機能上の差はなし |
| §6.2.2 spec の `sourceProbe?.colorSpace == .bt709` | 実装は `request.sourceProbe?.sourceVideoMetadata?.colorClass == .sdrBt709` | `SourceProbeDTO.colorSpace` フィールド不在判明、実構造は `sourceVideoMetadata?.colorClass: SourceColorClassDTO?` (Agent B 調査結果) |
| §6.2.2 patch は variant=hdr or sdr のみ | 実装は nil colorClass → `.hdr` 安全 default 追加 | HDR 同等の legacy 互換 (regression なし)、release narrative で説明予定 |
| Stream 4 = 計画上は本 chat 群で着手候補 | 完全 deferred | user policy「外殻は QA 希望時のみ」につき skip |

#### 10.4.4 残タスク full enumeration (chat 3 終了時点)

§4 全節 (4.1 - 4.6) 参照。chat 3 で **Stream 2 案 B 4/4 (P2-1.3 のみ device QA partial) + Stream 3 3/3 closed**。残:

- D4.1.5 (Stream 1 browser preview = user action)
- P2-1.3 (Stream 2 device QA log 確認)
- HK-1.1 の D5.5 CD承認 gate 後の効果検証 (本 chat 群 scope 外、別 lane)
- TEST-S1/S2/L1.5/L2.5/L3.9/L4.6/D1.4/D2.6/S3 (Stream 4 = 9 件、品質保証希望時のみ)
- COORD-2 (life-side memory update)
- COORD-3 (life-side MEMORY.md index update)
- commit + push (本 doc + plan + chat 3 native diff、user authorization 経由)
- PR open + main merge

### 10.5 next-chat 起動の推奨優先順 (再掲)

§5 verbatim 参照。Option ε (PR open) → Option γ' (release narrative) → Option δ (Stream 4 QA wave) → Option β (browser QA は user 直接実施推奨)。

