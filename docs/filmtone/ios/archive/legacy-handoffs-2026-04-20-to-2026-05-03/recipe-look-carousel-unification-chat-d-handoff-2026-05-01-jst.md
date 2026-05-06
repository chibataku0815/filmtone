# Filmtone iOS — Recipe 概念を Look に吸収 (Chat D Handoff)

- **作成**: 2026-05-01 JST
- **HEAD (Chat D 完了時、未 commit)**: working tree dirty (Chat A-D 累積)、CD 駆動 commit 待ち
- **目的**: Recipe (preset) sheet と Look carousel の役割重複を IA 統合で解消。Recipe sheet と関連 trigger / Preset card 専用ファイルを物理削除し、bottom Look carousel を **Look 単一の vibe-selection surface** に絞った。Preset 4 件 (Natural / iPhone / SoftBlue / AmberGlow) の UI 露出は撤去。preset catalog 自体は data layer に残存 (SavedLook が serialize する `presetName` の名前空間として、および `FilmtoneEditorStore` が active preset の label 解決に使用)

---

## 0. TL;DR (30 秒)

- **D1**: Recipe sheet 廃止 + Look carousel を **Look のみ** の単一 hub 化を land。CD 指示 「元々のレシピは必要ない / 概念を Look に統合」 に従い preset chip 統合 案も撤回
- **D2**: option (i) FilmtoneEmptyView 妥協案 (CD 提供 FilmtoneSymbol01 + savedLooks teaser + 2 CTA + tagline 撤去) で finalize、本 Chat D は touch なし。motion-dot 統合議論は Chat E 以降へ申し送り
- 物理削除 2 ファイル: `FilmtoneRecipeSheet.swift` (72 行) / `FilmtonePresetRow.swift` (FilmtonePresetCardSurface + presetGlowPalette を内包)
- pbxproj 4-section × 2 ファイル = 8 行除去
- `FilmtoneRootView.swift` 編集 3 箇所 (`recipeSheetPresented` @State / `onRecipeTap` callback 渡し / `.sheet(isPresented: $recipeSheetPresented)` block)
- `FilmtoneFullscreenLutEditor.swift` 編集 (callback 定義削除 / lower chrome の Recipe trigger 削除 / `FullscreenLookCarousel` は signature・実装ともに **Chat A 形 (Clear + Look chips のみ)** へ復元、preset chip 統合は撤回)
- simulator BUILD SUCCEEDED 確認、grep gate 全通過 (pbxproj 0 / Recipe 起動経路 0)
- preset catalog (`FilmtonePresetCatalog.swift`) は data layer 用途で **保持**: `FilmtoneEditorStore.swift:552` が `descriptor(named:)` 経由で active preset の label を解決する

---

## 1. Plan Compliance (plan に対する達成度)

Plan SSoT: `/Users/chibatakumi/.claude/plans/filmtone-ios-ios-precious-church.md`

| Plan step | 結果 |
|---|---|
| FilmtoneRecipeSheet.swift 物理削除 | ✅ rm 済、pbxproj 4-section 全除去 |
| FilmtonePresetRow.swift 物理削除 | ✅ rm 済、pbxproj 4-section 全除去 (PresetRow は Recipe sheet 専用、grep 確認済) |
| FilmtoneRootView.swift 3 箇所編集 | ✅ `recipeSheetPresented` @State 削除 / `onRecipeTap:` callback 削除 / `.sheet(isPresented: $recipeSheetPresented)` block 削除 |
| FilmtoneFullscreenLutEditor.swift carousel | ✅ `onRecipeTap` callback 定義削除 / lower chrome の Recipe trigger button 削除 / `FullscreenLookCarousel` は **Chat A 形 (Clear + Look chips のみ) を維持** (Plan 第一案の preset chip 統合は CD 指示 「元々のレシピは必要ない / 概念を Look に統合」 で **撤回**) |
| Lower chrome の MARK / chromeLayer 説明 doc 更新 | ✅ "the four sheet triggers" → "the two sheet triggers (Source / Adjust)" に更新、Recipe 概念は Look に吸収済みである旨を docstring 化 |
| pbxproj 8 行除去 | ✅ PBXBuildFile×2 + PBXFileReference×2 + PBXGroup×2 + PBXSourcesBuildPhase×2 |
| simulator build green | ✅ `** BUILD SUCCEEDED **` (stale .o / .swiftconstvalues も DerivedData から自動除去) |
| grep gate | ✅ pbxproj=0 / 起動経路=0 / preset chip identifier 不在 |

Plan 第一案 (preset chip 統合 + 1px divider + palette dot) は **撤回**。CD 指示 「元々のレシピは必要ない / 概念を Look に統合」 を受け、carousel は Look 単独へ。

---

## 2. Cross-Stream Visibility (並列 stream 想定 context)

本 chat は単 chat 直線実装、並列 stream なし。次 chat (Chat E) も単 chat 想定 (motion-dot 統合 architectural 検討)。Agent Teams は使用せず。

Chat D の Phase 1 で Explore agent 3 並列 (Recipe/Look data shape / EmptyView + asset / Recipe sheet UI structure) を一度のみ起動し読み取り集約 → AskUserQuestion → ExitPlanMode → 実装の単線フロー。

---

## 3. Scope Diff (plan からの差分)

### 3.1 plan に明記されていたが実装で省略 / 後送り

なし。

### 3.2 plan に明記されていなかったが実装で対処

- **Plan 第一案の preset chip 統合は撤回**: CD 指示 「元々のレシピは必要ない / 概念を Look に統合」 を受け、Plan で land 予定だった Preset 4 chip + 1px divider + `presetPaletteDot()` helper / `activePresetName` + `onApplyPreset` carousel signature 拡張 を **撤去**。`FullscreenLookCarousel` は Chat A 形 (Clear + Look chips) に復元。`FilmtonePresetCatalog.all` の UI 消費点はゼロ化、catalog 自体は data layer (store 内 `descriptor(named:)` 経由 label 解決) として保持
- **`chromeLayer` の MARK doc 更新** (FilmtoneFullscreenLutEditor.swift L282–290): "the four sheet triggers (Recipe / Source / Library / Advanced)" → "the two sheet triggers (Source / Adjust)" に更新
- **lower chrome の MARK 更新**: 「Recipe 概念は Look に吸収済み、preset catalog は data layer に残るが UI picker としては surface しない」を docstring 化
- **Recipe 撤去後の preset reset UX (要 CD 確認)**: 旧 Recipe sheet にあった `defaultResetButton` (= `store.restoreActivePresetDefaults()`) の起動点が UI から消えた。実装上 reset preset は SavedLook を持たない初期状態以外、ユーザーから到達不能。Adjust sheet 内 reset があるなら問題なし、無ければ CD 実機判断後に Adjust sheet へ reset action 追加候補 — 要 CD 確認

### 3.3 plan の不変条件への遵守

- ✅ `Profile.version` = 4 触らず
- ✅ `FilmtoneEditorStore` 既存 API のみ使用 (`clearCreativeLut` / `applySavedLook`、新 method 追加なし。`selectPreset` の UI call site は本撤回で 0 化、API 自体は live)
- ✅ Capacitor bridge 触らず
- ✅ `FilmtonePhase0Generated.swift` 編集なし
- ✅ `#available(iOS 26.0, *)` 再導入なし
- ✅ amber chrome 再導入なし
- ✅ pbxproj 4-section × 2 ファイル = 8 行除去 (grep wc -l 確認済 → 0)
- ✅ Chat C P1-FIX-A/B/C 編集箇所は触らず
- ✅ `FilmtoneEmptyView.swift` touch なし (D2=(i) finalize)
- ✅ `.presentationBackground(.thinMaterial)` 再導入なし、`.large` presentationDetent 再導入なし
- ✅ bun 使用 (npm 不使用)
- ✅ 自動 commit/push なし

---

## 4. 残タスク enumeration (Chat E 以降に申し送り)

### 4.1 motion-dot 統合 (architectural 選択肢の再評価)

CD 確定 (本 chat 開始時 AskUserQuestion): D2=(i) 妥協案 finalize、motion-dot 統合は別 chat。前 chat handoff (`empty-view-redesign-final-handoff-2026-05-01-jst.md` §4.1) に詳細あり。4 path:

1. WKWebView 埋め込み — kinetic handoff prototyping、cold launch overhead 実測必要
2. pre-rendered video loop — motion-dot を web で 30s ProRes 録画 → bundle 同梱、loop seam / bundle bloat 評価
3. `film-lab-renderer` 拡張 — WGSL pipeline に metaball pass を mountable scene として注入
4. Metal native port — 数週間規模、scope 過大 (前 chat で確定)

### 4.2 XCUITest 復旧 (CD 「QA 希望」明示時)

**Chat D で削除した accessibility ID** (XCUITest が依存している可能性):

- `filmtone.sheet.recipe`
- `filmtone.section.presets`
- `filmtone.preset.default`
- `filmtone.fullscreen.trigger.recipe`
- `filmtone.preset.card.<name>` (FilmtonePresetRow.swift と同時消失、`<name>` ∈ {reset, iphone, softBlue, amberGlow})

**Chat D での accessibility ID 新規追加なし** (Plan 第一案の `filmtone.fullscreen.lookChip.preset.<name>` は CD 指示で撤回)。

Snapshot suite が depend していれば alias 移植で復旧可能。CLAUDE.md §1 「外殻最小」基準では XCUITest 復旧は「QA 希望」明示時のみ着手、land 自体は可能。

### 4.3 Look LUT import 配置の再評価 (D1 land 後の判断)

Chat C P1-FIX-B で `FilmtoneSourceProfileSheet.swift:87` の `creativeLutImportSection` に `importCreativeLut()` UI 起動点を集約。本 Chat D の D1 確定 (carousel = Look 単独) を踏まえて、CD 実機判断後に下記いずれかへ:

- (a) 現行 (Source sheet 内) を維持 — Source = カメラ / 入力 LUT 系の集約点として一貫
- (b) carousel 周辺に移動 — Look hub と LUT import の動線を集約

CD 実機で carousel + Source sheet の動線を確認した上で判断仰ぐ。

### 4.4 preset reset 経路の確認 (CD 実機 gate)

旧 Recipe sheet `defaultResetButton` (= `store.restoreActivePresetDefaults()`) の UI 起動点が消失。Adjust sheet 内に reset action があれば不要、無ければ CD 実機判断で:

- (a) Adjust sheet に reset action を追加
- (b) Look 「Natural / Default」 を built-in として追加 (FilmtoneBuiltInCatalog 拡張、scope 別)
- (c) 不要 (Look 選択 = preset replay でカバー、reset 自体を退役)

---

## 5. ビルド・検証チェーン (毎 batch 確認)

### simulator build (commit gate)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

→ `** BUILD SUCCEEDED **`

### grep gate

```bash
grep -c "FilmtoneRecipeSheet\|FilmtonePresetRow" apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
# → 0

grep -rn "recipeSheetPresented\|onRecipeTap\|FilmtoneRecipeSheet\|FilmtonePresetRow" apps/capacitor-film-lab-ios/ios/App/App/*.swift
# → 0 行

grep -n "filmtone.fullscreen.lookChip.preset" apps/capacitor-film-lab-ios/ios/App/App/FilmtoneFullscreenLutEditor.swift
# → 0 行 (Plan 第一案撤回により preset chip 不在)

grep -n "FilmtonePresetCatalog" apps/capacitor-film-lab-ios/ios/App/App/FilmtoneFullscreenLutEditor.swift
# → 0 行 (UI 消費点ゼロ。catalog 自体は store / FilmtoneStrings 用に残存)

ls apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRecipeSheet.swift apps/capacitor-film-lab-ios/ios/App/App/FilmtonePresetRow.swift 2>&1
# → No such file or directory (両方)
```

### accessibility ID 全数

```bash
grep -rh "accessibilityIdentifier" apps/capacitor-film-lab-ios/ios/App/App/*.swift | grep -oE '"filmtone\.[^"]*"' | sort -u | wc -l
```

→ 90 (実測、Chat C 完了 99 → 削除 5 + Chat A-D の他撤去分が累積)

### 実機 視覚 gate (CD 駆動、iPhone 17 Pro Max iOS 26.2 / 実機 `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`)

- [ ] fullscreen lower chrome の Recipe trigger 消失、Source/Adjust の 2 trigger のみ
- [ ] bottom carousel に [Clear Look] + [Stone/Urban built-in + saved Look] のみが単一行で並ぶ (preset chip / divider なし)
- [ ] Look chip tap → preset + strength + quickState + paramOverrides + LUT 全 replay (Chat C P1-FIX-B 通り)
- [ ] Clear Look chip tap → LUT のみ解除、現 preset は touch されず
- [ ] Active state: 現選択 Look が `.glassProminent`、他は通常 glass
- [ ] Recipe sheet は完全消失、ドラッグ / outside tap で sheet 開閉なし

---

## 6. 不変条件 reminder (Chat E 以降でも遵守)

| 項目 | 値 |
|---|---|
| `Profile.version` | 4 固定 |
| `FilmtoneEditorStore` API | 既存のみ (新 method 追加禁止) |
| Capacitor bridge | 触らない |
| `FilmtonePhase0Generated.swift` | 編集禁止 |
| amber chrome | 再導入禁止 (content semantic = Look 識別 / warn / preset palette identity 等は維持) |
| `#available(iOS 26.0, *)` | 再導入禁止 |
| pbxproj 4-section 登録 | 削除 2 ファイル分は完了。以降の新規 .swift は `..002E` から付番 (B6 用 GUID は未使用のままなので next GUID = `..002E`、本 Chat D で新規 .swift 追加なし) |
| sheet bg | iOS 26 デフォルト Liquid Glass (`presentationBackground` 撤去済) |
| `.large` presentationDetent | 再導入禁止 |
| `bun` 必須 (`npm` 禁止) | |
| Git 操作 | user 駆動 (auto commit / push 禁止) |
| `FilmtoneEmptyView.swift` | D2=(i) finalize、motion-dot 統合は Chat E 以降 |

---

## 7. 引き継ぎプロンプト (Chat E 起動時に貼る)

```
あなたは Filmtone iOS (iOS 26.0 / SwiftUI / Capacitor 7.4.3 /
`com.chibatakumi.film.lab.ios`) の Liquid Glass UI 担当です。

Chat D で Recipe sheet 廃止 + Look carousel 単一化が land 完了
(working tree dirty / CD 駆動 commit 待ち)。Chat E では FilmtoneEmptyView の
motion-dot 統合 (architectural 選択肢の再評価) を扱う。

# 必読 (順番厳守)

1. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md
2. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios/CLAUDE.md
3. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/recipe-look-carousel-unification-chat-d-handoff-2026-05-01-jst.md ← Chat D handoff (本ファイル)
4. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/empty-view-redesign-final-handoff-2026-05-01-jst.md ← motion-dot deferred decision の起点
5. /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/renewal-2026/motion-dot-transplant-handoff-2026-04-26.md
6. /Users/chibatakumi/.claude/plans/filmtone-ios-ios-precious-church.md ← Chat D 実行 plan

# Chat D の到達点

- D1 land 完了: Recipe sheet 廃止 + Recipe 概念は Look に吸収 (carousel = Clear + Look chips のみ、preset chip 統合は CD 指示で撤回)
- D2 land 維持: 妥協案 (FilmtoneSymbol01 hero + savedLooks teaser + 2 CTA + tagline 撤去) のまま、motion-dot は Chat E 以降
- working tree dirty (Chat A-D 累積)、CD 駆動 commit 待ち
- preset reset 経路の UI 消失 (旧 Recipe sheet `defaultResetButton`) は §4.4 で要 CD 確認
- simulator BUILD SUCCEEDED、grep gate 全通過

# あなたが守ること

- 本質優先 / 外殻最小、保守的ヘッジ優先しない
- 設計判断は mcp__sequential-thinking、不確かなら gemini-search → WebSearch
- handoff 機能言及を引用前に grep / Swift / pbxproj で live/frozen 確認
- 自動 commit / push 禁止、bun 必須、出力は日本語
- store API 凍結、`Profile.version=4` 固定、`FilmtonePhase0Generated.swift` 編集禁止
- Chat A-D 編集箇所は regress させない (sheet 群の `presentationBackground` / `.large` detent 再導入禁止)

# まず最初にやること

1. git status で working tree 確認 (Chat D の land が commit 済か未 commit か)
2. 本 handoff doc + portfolio motion-dot doc + main.ts (668 行) を Read
3. sequential-thinking で「motion-dot を Filmtone iOS empty view に統合する最小 viable な path」を 6-10 thought で詰める
4. CD に統合方針 (WKWebView prototype / pre-rendered video loop / film-lab-renderer 拡張 / Metal port) を 200 字以内で提示、選択を仰ぐ
```

---

## 8. 完了サイン (Chat D 終了 gate)

- [x] D1 atomic 編集完了 (FilmtoneRecipeSheet.swift / FilmtonePresetRow.swift 削除 + RootView 3 箇所 + FullscreenLutEditor: callback / lower chrome trigger 削除 + pbxproj 8 行除去)
- [x] Plan 第一案の preset chip 統合は CD 指示で撤回、carousel は Clear + Look のみ
- [x] D2 no-op (CD=(i) 確定、touch なし)
- [x] simulator BUILD SUCCEEDED (撤回再ビルド後も green)
- [x] grep gate 全通過 (pbxproj=0 / 起動経路=0 / preset chip 不在)
- [x] working tree が想定どおり (Chat A-C 累積 + D1 編集が dirty 状態で重なる、CD 駆動 commit 待ち)
- [x] handoff doc (本ファイル) 作成 + CD 指示反映の改訂
- [ ] CD 駆動 commit + push
- [ ] CD 視覚 gate (iPhone 17 Pro Max iOS 26.2 実機)
- [ ] preset reset 経路の確認 (§4.4 の (a)/(b)/(c) いずれを取るか CD 判断)
- [ ] Chat E 起動 (motion-dot 統合 architectural 検討)

---

## 9. 参考 reference

- Plan SSoT: `/Users/chibatakumi/.claude/plans/filmtone-ios-ios-precious-church.md`
- Chat C handoff (P1-FIX-A/B/C + detent fix): `/Users/chibatakumi/.claude/plans/filmtone-ios-ios-precious-hippo.md`
- Chat B handoff (B6-B10): `/Users/chibatakumi/.claude/plans/docs-filmtone-ios-liquid-glass-fullscree-pure-journal.md`
- Chat A handoff (B1-B5): `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/liquid-glass-fullscreen-pivot-chat-b-handoff-2026-05-01-jst.md`
- Empty view redesign final (前 chat): `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/empty-view-redesign-final-handoff-2026-05-01-jst.md`
- WWDC25 "Build a SwiftUI app with the new design": Liquid Glass partial sheet 仕様 / chip glass / GlassEffectContainer
