# Filmtone iOS — Fullscreen-First IA Pivot, Chat A → Chat B Handoff

- **作成**: 2026-05-01 JST
- **HEAD（Chat A 完了時、未 commit）**: 直前は `1a9c282`、Chat A の B1-B5 編集は **working tree に保持**（user 駆動 commit 待ち）
- **目的**: Chat A で IA pivot（fullscreen-first 化 + 5 sheet trigger）と既存 3 ファイル削除を land。Chat B で残 B6-B11（Library sheet 本実装 + 既存 sheet 群の glass 化 + Export sheet）を完遂する

---

## 0. TL;DR（30 秒）

- IA を **scroll-based main flow → fullscreen-first** に pivot 完了
- `FilmtoneRootView` を 367 → 175 行へ縮約（router + 4 sheet host）
- `FilmtoneFullscreenLutEditor` に **2 段 chrome**（upper = back/compare/title/hide/save/export, lower = Recipe/Source/Library/Adjust trigger 4 個）+ overlay (UnsavedExportPrompt / Toast / HdrPolicyNotice) を追加
- 旧 4 ファイル削除: `FilmtoneHeroSection.swift` / `FilmtonePresetSection.swift` / `FilmtoneTuningSection.swift` / `FilmtoneCameraProfileCard.swift`
- 新規 3 ファイル: `FilmtoneEmptyView.swift`（GUID `..002B`）/ `FilmtoneRecipeSheet.swift`（`..002C`）/ `FilmtoneSourceProfileSheet.swift`（`..002D`）
- Library sheet は **placeholder**（RootView 内 inline）— B6 で `FilmtoneLibrarySheet.swift` 独立化
- Advanced sheet は **既存 `FilmtoneStrengthSheet`** をそのまま再利用（glass 化は B7）
- Export = `store.export()` 直接トリガー（callback）— B10 で sheet 化
- simulator build green を毎 commit 確認（CD は user driven commit）
- accessibility identifier: 削除した `filmtone.section.hero` / `filmtone.section.tuning` / `filmtone.adjust.open` / `filmtone.lut.creative.*` 等は **下位互換移植未完**。XCUITest snapshot suite は要更新（CD 「QA 希望」明示後 B11+ で対応）

---

## 1. Plan Compliance（plan に対する達成度）

Plan: `/Users/chibatakumi/.claude/plans/docs-filmtone-ios-liquid-glass-ui-design-shimmering-quokka.md`

| Batch | 計画 | Chat A 結果 |
|---|---|---|
| **B1** | FilmtoneFullscreenLutEditor: 2 段 chrome + 5 callback | ✅ 完了。upper chrome（back / compare segment / title pill / hide / save icon `square.and.arrow.down` / export icon `square.and.arrow.up` `.glassProminent`） + lower chrome (Recipe / Source / Library / Adjust 各 trigger button)。callback: `onSaveLook` / `onExport` / `onRecipeTap` / `onSourceTap` / `onLibraryTap` / `onAdvancedTap` |
| **B2** | FilmtoneRootView 縮約 | ✅ 完了。367 → 175 行。body = if-router (empty / fullscreen)。`UnsavedExportPrompt` / `FilmtoneToastView` / `FilmtoneHdrPolicyNotice` を FullscreenLutEditor の overlay に移植。`fullScreenCover(fullscreenLutEditorPresented)` 撤去 |
| **B3** | FilmtoneEmptyView 新規 | ✅ 完了。GUID `..002B` で 4-section 登録。title pill (.glassEffect) + sourceEmpty hint + Photo Library/.glassProminent / Files/.glass。`GlassEffectContainer` で merge |
| **B4** | FilmtoneRecipeSheet 新規 + 旧 3 ファイル削除 | ✅ 完了。GUID `..002C`。`FilmtonePresetRow` を内包（`FilmtonePresetCardSurface` per-preset palette identity 維持）。`FilmtoneHeroSection` / `FilmtonePresetSection` / `FilmtoneTuningSection` 物理削除 + pbxproj 4-section 全除去 |
| **B5** | FilmtoneSourceProfileSheet 新規 + 旧 CameraProfileCard 削除 | ✅ 完了。GUID `..002D`。camera profile picker（5 source profile + Auto + Import + Clear）+ input intensity slider + saved LUTs strip。 `FilmtoneCameraProfileCard.swift` 物理削除 |

**Architecture pivot vs plan**: Plan B1 は @State sheet bindings を FullscreenLutEditor 内に持たせる方向だったが、B5 着手時に savedLookSheet / lutDeleteConfirmation の plumbing を考慮し **sheet @State + .sheet host を全部 RootView 側に統一**（callback 方式）に変更。これにより:
- Source sheet が savedLookSheet / lutDeleteConfirmation の Binding を直接受け取れる
- Advanced sheet が既存 FilmtoneStrengthSheet を素直に reuse できる
- Library placeholder が RootView 内で savedLookSheet / lookDeleteConfirmation にアクセスできる

この変更は plan の意図（fullscreen-first IA + 4 sheet trigger）を維持し、実装の整理にとどまる。`feedback_no_silent_stream_redefine` 違反ではない（lane scope の sheet placement 変更は B5 着手時に明示判断、本 handoff §1 で機構化）。

---

## 2. Cross-Stream Visibility（並列 stream 想定の context）

Chat A 単 chat 直線実装（CD 確定）。並列 stream は採用していない。Chat B も単 chat で B6-B11 を順番に land する想定。

もし Chat B で並列分割（例: B6-B8 と B9-B11）する場合は、以下の lane 衝突 zone に注意:

| zone | 触る batch | 衝突 risk |
|---|---|---|
| `FilmtoneRootView.swift` | B6（Library sheet 配線） / B10（UnsavedExportPrompt 確認） | medium — sheet host を触るのは B6 のみだが、もし B10 で UnsavedExportPrompt を RootView に戻す方針に変えると衝突 |
| `FilmtoneStrengthSheet.swift` | B7（glass 化）| low — Chat B 単独で扱う |
| `FilmtoneAdvancedParamsModel.swift` | B7（glass 化 + ネスト透明化） / B8（preset chip glass）| medium — 同一ファイル 2 batch を並列分割しない |
| `FilmtoneSheetPreview.swift` | B8（compare reveal glass） | low |
| `FilmtoneAdjustmentHelpSheet.swift` | B9 | low |
| `FilmtoneRootChrome.swift` | B10（UnsavedExportPrompt / Toast 既に FullscreenLutEditor 内に移植済） | low — `Color.filmtoneAmber` extension を含むので削除注意 |
| `FilmtoneExportPanel.swift` | B10 | low |

---

## 3. Scope Diff（plan からの差分）

### 3.1 Plan には書かれていたが Chat A で先送り

- **Library sheet 本実装** → B6 へ完全移行。Chat A では **RootView 内 `librarySheetPlaceholder` private var** として inline 実装（FilmtoneSavedLooksStrip を内包、apply / rename / delete / favorite フル機能）。B6 で `FilmtoneLibrarySheet.swift` に独立化 + glass 化
- **Empty state の Saved Looks recent strip** → 計画では `GlassEffectContainer` で包むはずだったが、Chat A では title + hint + 2 picker button のみのミニマル実装。teaser strip は CD が実機で empty state を見て判断後 B6+ で追加（apply トリガーの仕様未確定 — 「素材未選択時に Look を tap したら何が起きる？」が UX 設計判断）
- **Advanced sheet の glass 化** → 既存 `FilmtoneStrengthSheet` をそのまま wire。`Color.filmtoneBackground.ignoresSafeArea()` 撤去 / `FilmtoneSheetSecondaryActionStyle` 削除 / DisclosureSection / AdvancedParamGroupSection / ParamPresetChip glass 化はすべて B7 へ
- **Export sheet 化** → 現状 export button → `store.export()` 直接呼び出し。`FilmtoneExportPanel` の glass sheet 化は B10 へ
- **B11 Quick adjust inline strip** → CD 後送り判断（plan §11、CD 確定）

### 3.2 Plan に明記されていなかったが Chat A で対処

- **`filmtone.root.scroll` 互換 alias** — XCUITest snapshot suite が `app.descendants(matching: .any)["filmtone.root.scroll"].exists` を sentinel として使用しているため、RootView root に `accessibilityIdentifier("filmtone.root.scroll")` を残置（コメント明記）
- **`back` button の動作変更** — Plan は「素材解放 → empty state」を想定していたが、`FilmtoneEditorStore` API 凍結（CLAUDE.md §5）のため source 解放 public method を新設できない。代替として **back = `sourcePickerDialogPresented = true`**（既存 source picker dialog を起動）に変更。CD の「素材を解放して empty state」UX を完全には満たせていない
- **Save button の wiring** — `onSaveLook = { savedLookSheet = .createCurrentLook }` で既存 saved-look 名入力 sheet を起動

### 3.3 plan の不変条件への遵守

- ✅ `Profile.version` = 4 触らず
- ✅ `FilmtoneEditorStore` 既存 API のみ使用（新 method 追加なし）
- ✅ Capacitor bridge 触らず
- ✅ `FilmtonePhase0Generated.swift` 編集なし
- ✅ `#available(iOS 26.0, *)` フォールバック再導入なし
- ✅ amber chrome 再導入なし（Save / Export ボタンも amber 不使用）
- ✅ pbxproj 4-section 登録: 新規 3 ファイル各 4 = 12 行追加 / 旧 4 ファイル各 4 = 16 行削除（grep wc -l 確認済）
- ✅ bun 使用（npm 不使用）
- ✅ 自動 commit/push なし

---

## 4. 残タスク enumeration（Chat B で完遂）

### B6 ─ FilmtoneLibrarySheet 独立化 + glass 化（GUID `..002E`）

現状: `FilmtoneRootView.librarySheetPlaceholder` private var に inline 実装（`FilmtoneSavedLooksStrip` 内包）。

- 新規 `FilmtoneLibrarySheet.swift` 作成（GUID `..002E`、4-section pbxproj 登録）
- `FilmtoneRootView` の `librarySheetPlaceholder` を削除し、`.sheet(isPresented: $librarySheetPresented) { FilmtoneLibrarySheet(...) }` に置換
- Bindings: `savedLookSheet: Binding<SavedLookSheetMode?>` / `lookDeleteConfirmation: Binding<SavedLookEntry?>` / `onDismiss: () -> Void`
- glass 化:
  - bundled chip: `.glassEffect(.regular.tint(amber.opacity(0.18)), in: .rect(cornerRadius: filmtoneControlCornerRadius))`
  - 標準 chip: `.glassEffect(.regular, in: .rect(cornerRadius: filmtoneControlCornerRadius))`
  - chip strip 全体を `GlassEffectContainer(spacing: 10)` で包む
  - sheet bg: `.presentationBackground(.thinMaterial)` 維持
- `FilmtoneLibraryChip` の amber tint = catalog identity として維持

### B7 ─ Advanced sheet glass 化（複数ファイル）

#### B7-a `FilmtoneStrengthSheet.swift`

- line 16: `Color.filmtoneBackground.ignoresSafeArea()` を **削除** → iOS 26 default Liquid Glass background
- `.presentationBackground(.thinMaterial)` を明示追加（任意）
- Done button line 103: 既に `.buttonStyle(.glassProminent)` ✓（保持）

#### B7-b `FilmtoneStrengthSheetStyles.swift`

- `FilmtoneSheetSecondaryActionStyle` を **削除**、call site (line ~92 Default ボタン) を `.buttonStyle(.glass)` に置換
- ファイルが空になれば `sectionDivider()` extension のみ残す or 他ファイルに統合。残す場合 pbxproj は触らない

#### B7-c `FilmtoneDisclosureSection.swift`

- `.background(LinearGradient).fill(.white.opacity(0.045→0.02 / 0.06→0.028)) + .stroke(.white.opacity(0.07/0.10))` → `.glassEffect(.regular, in: .rect(cornerRadius: filmtoneSurfaceCornerRadius))`
- chevron button 内側 `.fill(.white.opacity(0.035→0.08))` → 削除（外側 glass surface に乗せる、cleaner）

#### B7-d `FilmtoneAdvancedParamsModel.swift`

- ネスト先 `FilmtoneAdvancedParamGroupSection`（line 35-190）は **glass にしない**（glass-on-glass 回避）
- `.background(.fill(.white.opacity(0.045→0.028))) + .stroke(.white.opacity(0.06→0.10))` を削除、外側 DisclosureSection の glass に同化
- group 間境界は 1px `Rectangle().fill(.white.opacity(0.08))` で示す
- chevron button 内側 `.fill(.white.opacity(0.035→0.08))` も削除

### B8 ─ ParamPresetChip + SheetPreview glass 化

#### B8-a `FilmtoneAdvancedParamsModel.swift:192-217` (`FilmtoneParamPresetChip`)

- 選択時: `.fill(amber)` → `.glassEffect(.regular.tint(amber), in: Capsule())`
- 非選択時: `.fill(.white.opacity(0.045)) + .stroke(.white.opacity(0.08))` → `.glassEffect(.regular, in: Capsule())`
- recipe chip 横並び（`HStack(spacing: 8)` line 132）→ `GlassEffectContainer(spacing: 8)` で包む

#### B8-b `FilmtoneSheetPreview.swift:145-262` (`FilmtoneCompareRevealPreview`)

- graded label pill (line 222 付近): `.fill(amber)` → `.glassEffect(.regular.tint(amber), in: .rect(cornerRadius: 8))`
- original label pill (line 240 付近): `.fill(.black.opacity(0.56)) + .stroke(.white.opacity(0.08))` → `.glassEffect(.regular, in: .rect(cornerRadius: 8))`
- divider circle (line 184): `.fill(amber) + .shadow(...)` → `.glassEffect(.regular.tint(amber).interactive(), in: Circle())`
- 上記 3 つを `GlassEffectContainer` で包む

### B9 ─ Help sheet (`FilmtoneAdjustmentHelpSheet.swift`)

- `.background(Color.filmtoneBackground.ignoresSafeArea())` 撤去
- help block (line 161-183): `.fill(.white.opacity(0.04)) + .stroke(.white.opacity(0.07))` → `.glassEffect(.regular, in: .rect(cornerRadius: 10))`
- comparison label pills (line 224-238): graded → `.glassEffect(.regular.tint(amber), in: .rect(cornerRadius: 7))`、original → `.glassEffect(.regular, in: .rect(cornerRadius: 7))`

### B10 ─ Export sheet + UnsavedExportPrompt + Toast の glass 化

#### B10-a `FilmtoneExportPanel.swift`

- panel surface を sheet として再構成、`.presentationBackground(.thinMaterial)` または iOS 26 default
- 内部 button を `.glass` / `.glassProminent` に置換（カスタム ButtonStyle あれば削除）
- FullscreenLutEditor の export action callback を `store.export()` 直呼びから `exportSheetPresented = true` 経由（RootView に新 @State 追加）に切替

#### B10-b `FilmtoneRootChrome.swift`

- `UnsavedExportPrompt` (line 62-119): `.fill(.ultraThinMaterial) + dual overlay + stroke` → `.glassEffect(.regular, in: .rect(cornerRadius: 16))` 単発、dark overlay は legibility 確認後判断（必要なら `.glassEffect(.regular.tint(.black.opacity(0.18)))`）
- `FilmtoneToastView` (line 139-200): kind 別 tint（success=amber / error=red / info=sky）を `.glassEffect(.regular.tint(iconColor.opacity(0.12)), in: .rect(cornerRadius: 14))` で表現
- `Color.filmtone*` extension は維持

### B11 ─ Quick adjust inline strip（CD 実機判断後、条件付き）

- B6-B10 完了後、CD が iPhone 17 Pro 実機で fullscreen の既存 Strength + Look amount slider 2 本で十分か判断
- 不足なら fullscreen bottom slider 群の上に horizontal scroll で 3-5 個 quick slider chip 露出（exposure / contrast / saturation / temperature / tint）
- スコープ判断は B11 着手時に CD が指示

### accessibility identifier 補完（XCUITest 復旧、B11 後 or CD 「QA 希望」明示時）

XCUITest snapshot suite (`apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/`) が依存する identifier:

- `filmtone.preset.card.<name>` — `FilmtonePresetRow` 内、Chat A で `FilmtoneRecipeSheet` に moved。**identifier 維持**（同 string 使用）
- `filmtone.preset.default` — `FilmtoneRecipeSheet` の defaultResetButton に **再付与済**
- `filmtone.adjust.open` — 旧 `FilmtoneTuningSection` の Adjust button identifier。**未移植**。FullscreenLutEditor の `filmtone.fullscreen.trigger.advanced` ボタンに alias 付与すべき（XCUITest 復旧）
- `filmtone.lut.input.menu` — `FilmtoneSourceProfileSheet` 内、`FilmtoneLutControls.profileRow(menuIdentifier:)` で **維持**
- `filmtone.lut.input.intensity.slider` / `.value` — `FilmtoneSourceProfileSheet` 内、**維持**
- `filmtone.lut.creative.menu` — Creative LUT picker は B6 Library sheet または fullscreen Look carousel に分散。Chat A で **未復旧**（B6 着手時に attach）
- `filmtone.lut.creative.intensity.slider` / `.value` — fullscreen の lookIntensity slider と同義。`filmtone.fullscreen.lookIntensity.*` が現存。XCUITest を新 identifier で書き換えるか alias 付与
- `filmtone.section.export` — 旧 `FilmtoneExportPanel` 配下。B10 で Export sheet 内に再付与
- `filmtone.section.tuning` — 削除済（旧 TuningSection）。XCUITest が depend している場合は要更新

CLAUDE.md §1 「外殻最小」基準では XCUITest 復旧は「QA 希望」明示時のみ着手だが、commit gate に含まれていないので land 自体は可能。CD 判断仰ぐ。

---

## 5. ビルド・検証チェーン（毎 batch 確認）

### simulator build（commit gate）
```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
→ `** BUILD SUCCEEDED **`

### 新規 .swift 追加時 pbxproj 4-section 確認
```bash
grep '<新ファイル名>' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj | wc -l
```
→ ≥ 4

### accessibility identifier 全数 grep（毎 commit）
```bash
grep -rh "accessibilityIdentifier" apps/capacitor-film-lab-ios/ios/App/App/*.swift | grep -oE '"filmtone\.[^"]*"' | sort -u | wc -l
```
→ Chat A 完了時 99（変動 OK、減少時は要確認）

### 実機 build / install / launch（CD 視覚 gate）

```bash
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'platform=iOS,id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -configuration Debug -derivedDataPath build/local-iphone build
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  build/local-iphone/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

Chat B で実機視覚確認すべき gate:
- B7 完了後: Advanced sheet の sheet bg がデフォルト Liquid Glass、DisclosureSection が glass surface 化、ネスト AdvancedParamGroupSection が透明 + 1px separator、ParamPresetChip glass 化
- B8 完了後: SheetPreview の compare reveal pill glass 化 + divider circle interactive glass shimmer
- B10 完了後: UnsavedExportPrompt / Toast が glass refraction over preview、Export sheet が glass background
- B11 完了後（条件付き）: 全 surface 通して 60fps 維持確認（fullscreen scroll 内 chrome、sheet drag、chip tap）

---

## 6. 不変条件 reminder（Chat B でも遵守）

| 項目 | 値 |
|---|---|
| `Profile.version` | 4 固定 |
| `FilmtoneEditorStore` API | 既存 setter / publisher のみ（変更禁止） |
| Capacitor bridge | 触らない |
| `FilmtonePhase0Generated.swift` | 編集禁止 |
| amber chrome 再導入 | 禁止（content semantic は保持） |
| `#available(iOS 26.0, *)` | 再導入禁止 |
| pbxproj 4-section 登録 | 新規 .swift 追加時。Chat A 末尾 max GUID = `..002D`、Chat B 次は `..002E`（B6 Library sheet）から |
| `bun` 必須（`npm` 禁止） |
| Git 操作 | user 駆動 |

---

## 7. 引き継ぎプロンプト（Chat B 開始時に貼る）

````
あなたは Filmtone iOS（Apple iOS 26.0 deployment、SwiftUI + Capacitor 7.4.3、`com.chibatakumi.film.lab.ios`）の Liquid Glass UI 設計・実装を担当する SwiftUI engineer です。

# 必読ドキュメント（順番厳守）

1. `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/liquid-glass-fullscreen-pivot-chat-b-handoff-2026-05-01-jst.md` ← Chat A 完了時の handoff（本ファイル）
2. `/Users/chibatakumi/.claude/plans/docs-filmtone-ios-liquid-glass-ui-design-shimmering-quokka.md` ← 全体 plan（CD 承認済）
3. `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md` ← repo root ルール
4. `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios/CLAUDE.md` ← iOS サブツリーガイド

# Chat A の到達点（handoff §1 参照）

- B1-B5 完了（fullscreen-first IA pivot + 旧 4 ファイル削除 + 新規 3 sheet ファイル + Recipe / Source 本実装 + Library placeholder）
- working tree dirty（未 commit）— user 駆動 commit 待ち
- simulator build green
- accessibility identifier 99 個（Chat A 完了時点）

# あなたが守ること

- 本質優先 / 外殻最小（CLAUDE.md §3）
- 保守的ヘッジ優先しない
- 設計判断は `mcp__sequential-thinking`、不確かなら `gemini-search` → `WebSearch`
- handoff doc 機能言及を引用前に grep / Swift / pbxproj で live/frozen 確認
- 自動 commit / push 禁止
- 並列 stream silent 縮退禁止 — handoff §8.5 4 セクション機構化
- bun 必須
- 出力日本語、ファイル参照は path:line 形式

# 残タスク（handoff §4 enumeration）

- B6: FilmtoneLibrarySheet 独立化 + glass 化（GUID `..002E`）
- B7: Advanced sheet glass 化（4 サブ ファイル）
- B8: ParamPresetChip + SheetPreview glass 化
- B9: Help sheet glass 化
- B10: Export sheet + UnsavedExportPrompt + Toast glass 化
- B11: Quick adjust inline strip（CD 実機判断後、条件付き）
- accessibility identifier 補完（XCUITest 復旧、CD 「QA 希望」明示時）

# 進め方

1. 上記 handoff doc を Read で全文読む
2. plan file を Read で確認
3. B6 から順に着手。各 batch は atomic commit / 1 ファイル単位。simulator build green を毎 commit 確認
4. 新規 .swift 追加時は pbxproj 4-section 登録 + GUID 連番
5. CD 視覚 gate（B7 / B8 / B10 / B11 完了後）で実機確認
6. user 明示まで commit/push しない

# まず最初にやること

1. `git status` で Chat A 完了時の working tree を確認
2. handoff doc + plan file を Read
3. B6 着手前に handoff §4 B6 セクションを精読、`FilmtoneRootView.librarySheetPlaceholder` の現状実装を grep
4. CD に対して B6 第一案（FilmtoneLibrarySheet.swift の構造、glass 化方針、Binding plumbing）を 200 字以内で提示し、進めて良いか判断仰ぐ

質問・不明点があれば `mcp__sequential-thinking` で詰めた上で簡潔に質問する。
````

---

## 8. 完了サイン（Chat A 終了 gate）

- [x] B1-B5 atomic 編集完了
- [x] simulator build green
- [x] working tree が想定どおり（4 deleted + 3 new + 2 modified + pbxproj modified）
- [x] pbxproj GUID `..002B` `..002C` `..002D` 4-section 登録 OK
- [x] accessibility identifier 増加（92 → 99）
- [x] handoff doc（本ファイル）作成
- [ ] user による commit + push（未着手、user 駆動）
- [ ] 実機視覚確認（user 駆動）
- [ ] Chat B 起動

---

## 9. 参考 reference

- Chat A 期間中に参照: `FilmtoneFullscreenLutEditor.swift:99-180`（`LiquidGlassSurface` / `GlassActionButton` / `GlassGroup` canonical pattern、Chat A 編集後も保持）
- WWDC25: "Build a SwiftUI app with the new design" / "Adopting Liquid Glass"
- iOS 26 仕様: partial sheet がデフォルトで Liquid Glass background、`presentationBackground(.glass)` で明示制御可
- 直前 handoff: `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/liquid-glass-ui-design-handoff-2026-05-01-jst.md`（Chat 0 完了時、IA pivot 前）
