# Filmtone iOS — Adjustment Help Sheet 余白破綻 引き継ぎ doc (Chat C → Chat D 専用)

- **作成**: 2026-05-01 JST
- **対象**: `FilmtoneAdjustmentHelpSheet.swift` 単体の余白破綻 fix
- **緊急度**: 中 (sheet 単体の visual issue、release blocker ではないが CD 視覚 gate 通過必須)
- **scope**: 本 issue **のみ** — Recipe/Look 統合や FilmtoneEmptyView 再設計は別 chat
- **HEAD (Chat C 完了時)**: working tree dirty、CD 駆動 commit 待ち。ブランチ = `main`、`origin/main` から 1 commit ahead

---

## 0. TL;DR (30 秒)

`FilmtoneAdjustmentHelpSheet.swift` (詳細調整 sheet 内のヘルプ「ⓘ」 button から起動する **nested sheet**) で **horizontal padding が完全に効いていない**。タイトル「調整」 / 比較画像 / body text / helpBlock すべて sheet 端に張り付き、Apple HIG / 他 sheet (Strength / Recipe / Source / Export) の余白と一致しない。

Chat C で 3 案試行 (`.padding(.horizontal, 20)` 内側 VStack / 外側 + 内側 / `.contentMargins(.scrollContent)`) すべて実機で **NG 確認**。simulator build SUCCEEDED だが iPhone 17 Pro 実機で余白消失が再現。

iOS 26 Liquid Glass の **nested sheet (sheet-on-sheet)** + system drag indicator の特殊な layout guide が原因と推測。次 chat で根本調査 + 別アプローチ (NavigationStack 化 / sheet 提示元の変更 / 別 detent / 別 material) を試す。

---

## 1. プロジェクト基本前提 (絶対遵守)

| 項目 | 値 |
|---|---|
| 編集 repo | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/` (standalone) |
| iOS deployment | 26.0+ |
| Bundle ID | `com.chibatakumi.film.lab.ios` |
| TeamID | `C3G77H8NM6` |
| Workspace | `apps/capacitor-film-lab-ios/ios/App/App.xcworkspace` |
| Scheme | `App` |
| Capacitor | `7.4.3` |
| 実機 (CD 視覚 gate) | iPhone 17 Pro / iOS 26.0 (UDID `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`) |
| Snapshot 端末 | iPhone 17 Pro Max / iOS 26.2 (UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192`) |
| パッケージマネージャ | bun (npm 禁止) |
| Git | **CD 駆動 (auto commit / push 禁止)** |
| 出力 | 日本語、ファイル参照は `path:line` 形式 |

**運用原則 (life CLAUDE.md / filmtone CLAUDE.md と整合)**:

- **本質優先 / 外殻最小**: 余白の修正に集中、装飾やリファクタは禁止
- **保守的なヘッジ優先しない**: 「念のため fallback」「一旦 .thinMaterial に戻す」等の逃げを取らない
- **思考は sequential-thinking**: `mcp__sequential-thinking__sequentialthinking` で詰めてから手を動かす
- **不確かなら検索**: `gemini-search` (1st) → `WebSearch` (2nd)、記憶ベース断言禁止
- **handoff 鵜呑み禁止**: 本 doc の主張も grep / Swift / 実機で live/frozen を確認

**絶対 freeze (触らない)**:

- `FilmtoneEditorStore` 既存 API 以外の追加禁止
- `Profile.version=4` 固定
- `FilmtonePhase0Generated.swift` 編集禁止
- Capacitor bridge / shader / WebGPU 触らない
- `FilmtoneFullscreenLutEditor` の chrome / Compare / title pill 等 Chat B-fix で land 済の箇所
- Chat C で land した P1-FIX-A/B/C + detent fix の編集 (詳細は §4)
- 全 sheet の `.presentationBackground(.thinMaterial)` を **再導入しない** (= iOS 26 Liquid Glass 撤退、Apple WWDC25 仕様に逆行)
- 全 sheet の `.presentationDetents([.medium])` の `.medium` only を **`.large` 追加で上書きしない** (= Liquid Glass が引き上げで消える、Apple iOS 26 仕様)

---

## 2. Chat 履歴 (重要、context 全把握必須)

### Chat A (B1-B5、land 済 working tree)

- IA pivot: scroll-based main flow → **fullscreen-first** に転換
- `FilmtoneRootView` を 367 → 175 行に縮約
- 旧 4 ファイル削除 (`FilmtoneHeroSection` / `FilmtonePresetSection` / `FilmtoneTuningSection` / `FilmtoneCameraProfileCard`)
- 新規 3 ファイル (`FilmtoneEmptyView` / `FilmtoneRecipeSheet` / `FilmtoneSourceProfileSheet`)
- handoff: `docs/filmtone/ios/liquid-glass-fullscreen-pivot-chat-b-handoff-2026-05-01-jst.md`

### Chat B (P0-FIX-A/B + B6-B10、land 済)

- **P0-FIX-A**: fullscreen chrome 再設計 (Compare segment 縦書き bug 修正、title pill ガード化、Hide overlay 化、lower chrome ラベル truncate 解消)
- **P0-FIX-B**: Empty view 再設計 (hero gradient + wordmark + tagline + Saved Looks teaser + CTA — 後に Chat B-fix で「チープ」と CD 指摘、別 chat で 0 ベース再設計予定)
- **B6**: `FilmtoneLibrarySheet` 独立化 + glass 化
- **B7**: Advanced sheet glass 化 (StrengthSheet / DisclosureSection / AdvancedParamsModel)
- **B8**: ParamPresetChip + SheetPreview glass 化
- **B9**: Help sheet (FilmtoneAdjustmentHelpSheet) 一部 glass 化 — **本 issue の対象 sheet**
- **B10**: Export sheet + UnsavedExportPrompt + Toast glass 化
- plan: `/Users/chibatakumi/.claude/plans/docs-filmtone-ios-liquid-glass-fullscree-pure-journal.md`

### Chat B-fix (P0-FIX-C/D/E、land 済)

- **P0-FIX-C**: `FilmtoneLibrarySheet` 完全削除 (lower chrome の Library trigger も削除、3 button 化) — Look carousel が下部に常駐するため IA 二重化排除
- **P0-FIX-D**: 詳細調整 sheet (StrengthSheet) から `FilmtoneSheetPreview` (compare reveal) 削除
- **P0-FIX-E**: upper chrome title pill を「LUT ブラウザ」 固定 → active Look 名に変更 (`appliedSavedLookId` resolve)

### Chat C (P1-FIX-A/B/C + detent fix、本 chat、working tree dirty)

| commit candidate | 内容 | 対象ファイル |
|---|---|---|
| **1 (P1-FIX-A)** | sheet 内改行 / 余白圧迫 / 重複表示の解消 | `FilmtoneStrengthSheet` / `FilmtoneExportPanel` / `FilmtoneRecipeSheet` |
| **2 (P1-FIX-B)** | dual LUT 読み込み導線復旧 (creative LUT picker を Source sheet に追加) | `FilmtoneSourceProfileSheet` (`creativeLutImportSection` 新規 private var、`store.importCreativeLut()` 既存 API 使用) |
| **3 (P1-FIX-C)** | iOS 26 デフォルト Liquid Glass 正規化 (`.presentationBackground(.thinMaterial)` 全撤去 + 残存 `Color.filmtoneBackground` 撤去) | 全 sheet 7 ファイル: `FilmtoneStrengthSheet` / `FilmtoneExportPanel` / `FilmtoneRecipeSheet` / `FilmtoneSourceProfileSheet` / `FilmtoneAdjustmentHelpSheet` / `FilmtoneSavedLookSheet` / `FilmtoneTermHelpSheet` |
| **4 (detent fix)** | `.large` detent 撤去 (Apple WWDC25 仕様: `.large` では Liquid Glass が消えるため `.medium` only に統一) | 5 sheet: `FilmtoneStrengthSheet` / `FilmtoneExportPanel` / `FilmtoneRecipeSheet` / `FilmtoneSourceProfileSheet` / `FilmtoneAdjustmentHelpSheet` |

**Chat C 検証完了**:
- simulator build: `** BUILD SUCCEEDED **` ✓
- `presentationBackground` 残存 grep: 0
- `Color.filmtoneBackground` (sheet 群) grep: 0
- `importCreativeLut()` UI call site grep: 1 (FilmtoneSourceProfileSheet:90)

**Chat C 残課題 (本 doc の主題)**: **`FilmtoneAdjustmentHelpSheet` の余白破綻**。3 案試行すべて NG。

plan: `/Users/chibatakumi/.claude/plans/filmtone-ios-ios-precious-hippo.md` (Chat C 全実行記録)

---

## 3. バグの正確な記述

### 3.1 再現手順

1. iPhone 17 Pro 実機 (iOS 26.0) で Filmtone を起動
2. 素材 (写真 / 動画) をロード → fullscreen LUT editor 進入
3. lower chrome の **「調整」 trigger** (= `filmtone.fullscreen.trigger.advanced`) tap
4. → `FilmtoneStrengthSheet` (詳細調整 sheet) が `.medium` detent で表示
5. Strength sheet 内のいずれかの **ヘルプアイコン「ⓘ」** (例: 「強さ」 slider 横、「調整」 disclosure header、「詳細パラメータ」 disclosure header、各 advanced param slider 横) tap
6. → `FilmtoneAdjustmentHelpSheet` が **Strength sheet の上に nested sheet** として `.medium` detent で表示
7. **観察**: タイトル「調整」 / 比較画像 / body text / helpBlock すべて sheet 左端に張り付き、horizontal margin が消失

### 3.2 視覚的 evidence

CD が iPhone 17 Pro 実機で撮影、time 23:23 のスクリーンショット (本 chat の途中で添付) が示す症状:

- 上部: Status bar (23:23 / 信号 / WiFi / 100%)
- 中部: fullscreen LUT editor の chrome (back / compare / save / export + lower chrome レシピ/素材/調整) が暗く透けて見える
- 下半分 = Help sheet:
  - **タイトル「調整」 (amber color)** が sheet の左端 (≈ 0pt margin) に貼り付き
  - **「閉じる」 button** (text-only / `.buttonStyle(.plain)`) が右端に貼り付き、画面端で truncate 寸前
  - **比較画像 (before / after の 2 frame)** が sheet の **full width** を占有、左右余白ゼロ
  - body text 「明るさ、コントラスト、彩度を大きい軸で整える場所です。細かい光学効果に入る前に、素材全体の読みやすさを決めます。」 が sheet 左端 (0pt margin) から右端まで貼り付き
  - 「見た目の変化」 helpBlock も glass 表面が sheet 左端 (0pt margin) から右端 (0pt margin) まで full width
- 他 sheet (Strength / Recipe / Source / Export) は **同 commit 状態でも正常に 20pt 余白が出ている** (Chat C の 23:14 Strength sheet スクショで確認済)

### 3.3 期待される挙動

Apple HIG + 他 sheet (Strength / Recipe / Source / Export) との一貫性:

- 左右 horizontal margin = **20pt** (タイトル / 本文 / 比較画像 / helpBlock すべて)
- Top margin (drag indicator 下〜タイトル上) = **18-24pt**
- Bottom margin (最後の helpBlock 下〜sheet 端) = **28-32pt**

---

## 4. 試行ログ (3 案、すべて NG)

### 4.1 試行 1: 元のコード (Chat B B9 land 時 / Chat C P1-FIX-C 編集前)

```swift
var body: some View {
    ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 20) {
            header
            FilmtoneHelpComparisonImage(...)
            Text(topic.copy.body)
            VStack { helpBlock(effectLabel, ...); helpBlock(guidanceLabel, ...) }
        }
        .padding(.horizontal, 20)  // ← 内側 VStack に padding
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
    .presentationDetents([.medium, .large])
    .presentationBackground(.thinMaterial)  // ← Material 明示
    .presentationDragIndicator(.visible)
}
```

**結果**: Chat C P1-FIX-C 直前まで `.thinMaterial` がある状態では padding が効いていた **可能性が高い** (CD 23:14 Strength sheet スクショは「半透明黒スラブ」と認識される程度には sheet 内のコンテンツに余白あり)。`.thinMaterial` 撤去後 (Chat C P1-FIX-C 完了後) → 余白破綻が顕在化。

### 4.2 試行 2: header を ScrollView 外に出す (Chat C 1st 修正)

`FilmtoneStrengthSheet` / `FilmtoneRecipeSheet` の動作している pattern を踏襲:

```swift
var body: some View {
    VStack(spacing: 0) {
        header
            .padding(.horizontal, 20)  // ← header に直接 padding
            .padding(.top, 18)
            .padding(.bottom, 14)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                FilmtoneHelpComparisonImage(...)
                Text(topic.copy.body)
                VStack { helpBlock(...); helpBlock(...) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
}
```

**simulator build**: SUCCEEDED ✓
**実機**: CD 「ヘルプの余白直ってないよ」 = NG

### 4.3 試行 3: `.contentMargins` (iOS 17+ ScrollView 推奨 API) (Chat C 2nd 修正)

```swift
var body: some View {
    ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 20) {
            header
            FilmtoneHelpComparisonImage(...)
            Text(topic.copy.body)
            VStack { helpBlock(...); helpBlock(...) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .contentMargins(.horizontal, 20, for: .scrollContent)  // ← Apple 公式 ScrollView 内側 margin API
    .contentMargins(.top, 24, for: .scrollContent)
    .contentMargins(.bottom, 32, for: .scrollContent)
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
}
```

**simulator build**: SUCCEEDED ✓
**実機**: CD 「直ってないですね」 = NG

**現在の HEAD (Chat D 開始時の working tree 状態)** はこの試行 3 のコード (`FilmtoneAdjustmentHelpSheet.swift:105-138`)。

---

## 5. 仮説 (次 chat で検証すべき)

### 5.1 仮説 A: iOS 26 Liquid Glass の **sheet-on-sheet (nested sheet)** で internal layoutGuide が padding/contentMargins を override

- **証拠**: Strength / Recipe / Source / Export sheet (= **root sheet**、`FilmtoneRootView` から `.sheet(isPresented:)` で起動) は同じ Chat C 編集後でも余白正常。Help sheet **だけ** は `FilmtoneStrengthSheet:43` から `.sheet(item: $activeHelpTopic)` で起動された **nested sheet**
- **検証方法**: Help sheet を nested ではなく root sheet として起動 (state を `FilmtoneRootView` まで持ち上げ、root の `.sheet(item:)` で表示) → 余白が直るか実機確認
- **修正 path**: 状態 `activeHelpTopic` を `FilmtoneStrengthSheet` から `FilmtoneRootView` に移動 + state 通信を Binding で行う。store に新 method 追加禁止 (= `FilmtoneEditorStore` API freeze) のため、UI state は SwiftUI binding で plumbing

### 5.2 仮説 B: `.presentationDragIndicator(.visible)` が Liquid Glass partial sheet で safe area を override し、それが ScrollView の content inset 計算を狂わせる

- **証拠**: 他 sheet も `.presentationDragIndicator(.visible)` だが、Strength sheet は `.hidden` で **自前の `handle: some View`** (Rectangle) を描画している (`FilmtoneStrengthSheet:57-64`)
- **検証方法**: Help sheet で `.presentationDragIndicator(.hidden)` に変更 + 自前 handle 追加 → 余白が直るか確認
- **修正 path**:
  ```swift
  private var handle: some View {
      Rectangle()
          .fill(Color.white.opacity(0.22))
          .frame(width: 44, height: 3)
          .frame(maxWidth: .infinity)
          .padding(.top, 12)
          .padding(.bottom, 8)
  }
  ```
  body の最上段に `handle` を置き、`.presentationDragIndicator(.hidden)` に切替

### 5.3 仮説 C: `NavigationStack` 化が iOS 26 Liquid Glass nested sheet の標準 pattern

- **証拠**: `FilmtoneSavedLookSheet.swift:41` は `NavigationStack { ... }` で wrap されており、navigation toolbar 経由で cancel / submit を提供。NavigationStack は SafeArea / contentInsets を統一管理し、padding が確実に効く
- **検証方法**: Help sheet を `NavigationStack { ScrollView { content }.padding(.horizontal, 20) }` に変更、`navigationTitle(topic.copy.title)` + ToolbarItem で「閉じる」 button → 余白が直るか確認
- **修正 path**:
  ```swift
  var body: some View {
      NavigationStack {
          ScrollView(showsIndicators: false) {
              VStack(alignment: .leading, spacing: 20) {
                  FilmtoneHelpComparisonImage(...)
                  Text(topic.copy.body)
                  VStack { helpBlock(...); helpBlock(...) }
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 20)
          }
          .navigationTitle(topic.copy.title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                  Button(dismissLabel, action: onDismiss)
              }
          }
      }
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
  }
  ```
  これで Apple 純正パターンに統一、padding は NavigationStack の Form/ScrollView 標準挙動で必ず効く

### 5.4 仮説 D: `Color.filmtoneAmber` 等の **`Color.filmtoneXxx` 拡張が安全領域を消費** している

- **証拠**: 低い (Color extension は frame に影響しない)
- **検証方法**: title の `foregroundStyle(Color.filmtoneAmber)` を `.foregroundStyle(.white)` に一時変更して padding が直るか確認
- **修正 path**: 一時 debug、もし直れば Color extension の bug を root cause として深掘り

### 5.5 仮説 E: `FilmtoneHelpComparisonImage` 内部の `.frame(maxWidth: .infinity, maxHeight: .infinity)` (line 213) が親の padding を override

- **証拠**: 中 — `.frame(maxWidth: .infinity)` は通常 padding を尊重するが、`.clipped()` と組み合わせるとレイアウトが破綻するケースが過去にあった
- **検証方法**: `FilmtoneHelpComparisonImage` を一時的に `Color.red.frame(height: 184)` に置換、padding が出るか確認 → 出るなら ComparisonImage が原因
- **修正 path**: ComparisonImage を `GeometryReader` で wrap し明示的に親 width を尊重させる

### 5.6 推奨優先順位

1. **仮説 C (NavigationStack 化)** ← 最も確実、Apple 純正パターン、副次的に title styling / dismiss button も改善
2. **仮説 B (drag indicator + 自前 handle)** ← Strength sheet の動作実績ベースで最小変更
3. **仮説 A (root sheet 化)** ← state plumbing 増えるが nested sheet 自体を回避
4. **仮説 D / E** ← debug 用、root cause 特定後の対応

仮説 C が success すれば本 issue は close。失敗なら B → A → D/E の順で削り込む。

---

## 6. 動作している sheet との構造比較 (重要 reference)

### 6.1 `FilmtoneStrengthSheet.swift:14-55` (動作 OK)

```swift
var body: some View {
    VStack(spacing: 0) {
        handle  // 自前 Rectangle drag handle

        header
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                strengthSection
                adjustmentsSection
                advancedParamsSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
    .presentationDetents([.medium])
    .presentationBackground(.thinMaterial)  // Chat C で削除済
    .presentationDragIndicator(.hidden)  // ← .hidden、自前 handle 使用
}
```

ポイント:
- root sheet (`FilmtoneRootView` から `.sheet(isPresented:)` で起動)
- `.presentationDragIndicator(.hidden)` + 自前 handle Rectangle
- VStack(spacing: 0) で handle / header / ScrollView を縦並べ
- Header と ScrollView の inner VStack に **同じ** `.padding(.horizontal, 20)` を適用

### 6.2 `FilmtoneRecipeSheet.swift:12-45` (動作 OK)

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 0) {
        header
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FilmtonePresetRow(...)
                if store.hasPresetCustomValues {
                    defaultResetButton
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)  // ← .visible、system drag indicator
    .accessibilityIdentifier("filmtone.sheet.recipe")
}
```

ポイント:
- root sheet
- `.presentationDragIndicator(.visible)` でも余白正常 → drag indicator 自体は原因ではない可能性
- VStack(alignment: .leading, spacing: 0) で header / ScrollView を縦並べ
- Header と ScrollView の inner VStack で padding を別々に管理 (ScrollView 側は `.padding(.vertical, 16)` のみ、horizontal は `FilmtonePresetRow` の内部 ScrollView と `defaultResetButton` の `.padding(.horizontal, 20)` で個別に)

### 6.3 `FilmtoneSourceProfileSheet.swift:17-39` (動作 OK)

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 0) {
        header
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                cameraProfileSection
                creativeLutImportSection  // P1-FIX-B 追加
                inputIntensitySection
                savedLutsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
    .accessibilityIdentifier("filmtone.sheet.source")
}
```

ポイント: Recipe sheet と同パターン。

### 6.4 `FilmtoneExportPanel.swift:7-21` (動作 OK)

```swift
var body: some View {
    ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 18) {
            header
            statePanel
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 28)
    }
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
    .accessibilityIdentifier("filmtone.section.export")
}
```

ポイント:
- root sheet
- 構造的には Help sheet とほぼ同じ (ScrollView 直下の VStack に padding) → **これが動作するなら Help sheet も動作するはず**

### 6.5 重要な観察

`FilmtoneExportPanel` と `FilmtoneAdjustmentHelpSheet` は **構造的に等価** (ScrollView { VStack {…}.padding(.horizontal, 20) }) なのに **Export は動作、Help は不動作**。

差分:
1. Export = root sheet (`FilmtoneRootView:80-84` の `.sheet(isPresented: $exportSheetPresented)`)
2. Help = nested sheet (`FilmtoneStrengthSheet:43-54` の `.sheet(item: $activeHelpTopic)`、Strength sheet 上に nest)

→ **仮説 A (sheet-on-sheet が原因) の有力な裏付け**

### 6.6 NavigationStack 使用例: `FilmtoneSavedLookSheet.swift:40-107` (動作 OK)

```swift
var body: some View {
    NavigationStack {
        VStack(alignment: .leading, spacing: 18) {
            Text(headlineText) ...
            Text(bodyText) ...
            TextField(...) ...
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(...) }
            ToolbarItem(placement: .confirmationAction) { Button(...) }
        }
    }
    .onAppear { ... }
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
}
```

`SavedLookSheet` は `FilmtoneRootView:122-143` から `.sheet(item: $savedLookSheet)` で起動 → root sheet なので参考限定的。ただし NavigationStack 使用例として構造は流用可能。

---

## 7. 関連 file path 集約

### 7.1 編集対象 (本 issue で唯一触ってよい)

| ファイル | 役割 |
|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneAdjustmentHelpSheet.swift` | 余白破綻している nested sheet 本体。修正対象 |

### 7.2 編集対象 (仮説 A 採用時のみ)

| ファイル | 編集内容 |
|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift` | `@State private var activeHelpTopic` (line 12) と `.sheet(item: $activeHelpTopic)` (line 43-54) を削除、parent (`FilmtoneRootView`) から binding 受領 |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift` | `@State private var activeHelpTopic: FilmtoneAdjustmentHelpTopic?` 追加、`StrengthSheet` 起動時に binding を pass、`.sheet(item: $activeHelpTopic) { FilmtoneAdjustmentHelpSheet(...) }` を root level で追加 |

### 7.3 触らない (絶対 freeze)

| ファイル | 理由 |
|---|---|
| `FilmtoneFullscreenLutEditor.swift` | Chat A/B/B-fix で land 済 chrome、freeze |
| `FilmtoneEmptyView.swift` | 別 chat で 0 ベース再設計予定 |
| `FilmtoneEditorStore.swift` | 既存 API 凍結 |
| `FilmtoneEditorFacade.swift` / `FilmtonePersistence.swift` / `FilmtonePhase0Generated.swift` | freeze |
| `FilmtoneMediaPlugin.swift` / Capacitor bridge / shader / WebGPU | freeze |
| `FilmtoneRecipeSheet.swift` | Chat C P1-FIX-A の cancel button 削除のみ land、それ以外触らない |
| `FilmtoneSourceProfileSheet.swift` | Chat C P1-FIX-B の `creativeLutImportSection` 追加のみ land、それ以外触らない |
| `FilmtoneExportPanel.swift` | Chat C P1-FIX-A の header layout / readyState dup 解消のみ land、それ以外触らない |
| `FilmtoneSavedLookSheet.swift` / `FilmtoneTermHelpSheet.swift` | Chat C P1-FIX-C の `Color.filmtoneBackground` 撤去のみ land、それ以外触らない |
| `Localizable.xcstrings` | 文字列追加禁止 (本 issue は layout のみ) |
| `project.pbxproj` | 新規 .swift 追加禁止 (本 issue は既存 file 編集のみ) |

---

## 8. ビルド / 検証チェーン (Chat D で繰り返し叩く)

### 8.1 simulator build (毎編集後)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
# → ** BUILD SUCCEEDED **
```

### 8.2 実機 build / install / launch (CD 視覚 gate、毎案検証時)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios

xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'platform=iOS,id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -configuration Debug -derivedDataPath build/local-iphone build

xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  build/local-iphone/Build/Products/Debug-iphoneos/App.app

xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

実機 install 後、CD が以下を視覚確認:
1. 素材 (写真) ロード → 「調整」 trigger tap → Strength sheet
2. Strength sheet 内のヘルプアイコン「ⓘ」 tap → Help sheet
3. **Help sheet の左右 horizontal margin が他 sheet と同等の 20pt に達しているか目視確認**
4. タイトル「調整」 / 比較画像 / 本文 / helpBlock すべてが sheet 端から 20pt 以上 inset しているか確認
5. CD OK 確認後、commit (CD 駆動)

### 8.3 grep 検証 (state sanity)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

# Help sheet が現在どの構造か確認
grep -n "padding\|contentMargins\|frame" \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneAdjustmentHelpSheet.swift | head -20

# 他 sheet の padding pattern 確認 (reference)
grep -A 1 "ScrollView" apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift | head -10
```

---

## 9. 必読 doc (順番厳守、Chat D 開始時にすべて Read)

1. **本 doc**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/adjustment-help-sheet-padding-bug-handoff-2026-05-01-jst.md` ← Chat D の正本
2. **filmtone repo CLAUDE.md**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md`
3. **iOS 専用 CLAUDE.md**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios/CLAUDE.md`
4. **Chat A handoff**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/liquid-glass-fullscreen-pivot-chat-b-handoff-2026-05-01-jst.md`
5. **Chat B + B-fix plan**: `/Users/chibatakumi/.claude/plans/docs-filmtone-ios-liquid-glass-fullscree-pure-journal.md`
6. **Chat C plan**: `/Users/chibatakumi/.claude/plans/filmtone-ios-ios-precious-hippo.md`
7. **WWDC25 公式 (参考)**: [Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
8. **iOS 26 Liquid Glass sheet 実装ガイド (参考)**: [Presenting Liquid Glass sheets in SwiftUI on iOS 26](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/)

---

## 10. Anti-pattern (踏まない)

1. ❌ `.presentationBackground(.thinMaterial)` を Help sheet **だけ** 再導入する → Apple WWDC25 仕様逆行、他 sheet と挙動不整合
2. ❌ `.presentationDetents([.medium, .large])` で `.large` を再導入 → Liquid Glass が引き上げで消える
3. ❌ `Color.filmtoneBackground.ignoresSafeArea()` を Help sheet 内に追加 → Liquid Glass を消す
4. ❌ `FilmtoneEditorStore` API に新 method 追加 → store 凍結違反
5. ❌ Localizable.xcstrings に文字列追加 → 本 issue は layout のみ、文言は既存使用
6. ❌ `FilmtoneAdjustmentHelpCopy` 等の他 type 編集 → scope 外
7. ❌ 他 sheet (Strength / Recipe / Source / Export / SavedLook / TermHelp) の編集 → 動作 OK な sheet を巻き添えにしない
8. ❌ Hot fix 的な「workaround」 (例: Help sheet を NavigationView に変える等の deprecated API) → iOS 26 native pattern に倒す
9. ❌ commit / push を auto で行う → CD 駆動
10. ❌ 仮説検証なしに勘で `.scrollContentBackground` / `.scrollIndicatorsFlash` 等を追加する → root cause を特定してから打つ

---

## 11. CD への質問テンプレ (Chat D 開始時、第一案提示前に判断仰ぐ)

`mcp__sequential-thinking__sequentialthinking` で 4-6 thought 詰めた後、CD に以下を 200 字以内で報告:

> Chat C handoff doc の §5 仮説 C (NavigationStack 化) を第一案として実装したいです。
> Apple 純正パターンで余白が確実に効き、副次的に amber title 色 / plain dismiss button も
> 統一されます。実装 ≈ 30 行差分。よろしいですか? (NG なら仮説 B → A の順で fallback)

CD OK なら実装 → simulator green → 実機確認 → CD 視覚 gate で OK 確定 → commit (CD 駆動)。

---

## 12. 完了サイン (Chat D 終了 gate)

- [ ] `FilmtoneAdjustmentHelpSheet` の余白が他 sheet と同等の 20pt 水平 inset を実機で達成
- [ ] simulator build SUCCEEDED 維持
- [ ] 他 sheet の挙動は変えない (Strength / Recipe / Source / Export 等を実機で巻き添え retest)
- [ ] 触らない list (§7.3) を完全遵守
- [ ] CD 視覚 gate を通過
- [ ] commit (CD 駆動、message 提案を Chat D が出す)
- [ ] handoff doc 更新 (本 doc に Chat D の解決策を追記、または別 doc 作成)

---

## 13. Chat C 残務 (Chat D 着手前に確認)

Chat D を始める前に、Chat C の 4 commit candidate (P1-FIX-A/B/C + detent fix) が **commit 済か未 commit か** を確認:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git status
git log --oneline -5
```

- working tree dirty で Chat C の編集が残っている場合 → CD に「Chat C の 4 commit を land してから Chat D に進むか、すべてまとめて 1 commit にするか」 を判断仰ぐ
- すでに land 済の場合 → Chat D は本 issue の Help sheet 修正だけに集中

---

## 14. 次 chat への申し送り (本 issue 解決後の deferred タスク)

本 issue 解決後、CD 確認済の以下の deferred タスクが Chat E 以降で必要:

- **Recipe (preset) と Look (Stone/Urban) の役割重複統合** (Chat C で CD 確定 deferred): `FilmtoneRecipeSheet` + `FilmtonePresetRow` と `FullscreenLookCarousel` の IA 再設計。詳細は `/Users/chibatakumi/.claude/plans/filmtone-ios-ios-precious-hippo.md` §「次 chat への申し送り」 参照
- **`FilmtoneEmptyView` 0 ベース再設計** (Chat B-fix で CD 確定 deferred): hero 背景 / wordmark / tagline / Saved Looks teaser の組み立て直し。LUT/grading app の opening surface に何が必要かを sequential-thinking + 競合 / Apple HIG 調査で詰め直し
- **本 Chat C の Look LUT import 配置 (Source sheet) の再評価**: Recipe / Look 統合確定後に Look hub が確定すれば、`creativeLutImportSection` をそちらに移動
