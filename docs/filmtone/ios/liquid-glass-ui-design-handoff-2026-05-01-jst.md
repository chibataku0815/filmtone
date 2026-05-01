# Filmtone iOS — Apple Liquid Glass UI 拡張設計 Handoff

- **作成**: 2026-05-01 JST
- **HEAD**: `eb46fdad60b5ea910458660c06347a171bd3d365`（main、push 済）
- **目的**: 次チャットで Apple Liquid Glass を最大限活かす UI 案を 0 → 1 で設計する
- **前段**: 本日 12 commits の構造分離 refactor を完了し、Liquid Glass 全面採用の足場を整えた（後述 §4）

---

## 0. TL;DR（30 秒）

- iOS 26.0 deployment target に bump、`#available(iOS 26.0, *)` フォールバック路線を全廃
- amber chrome tint（`Color.filmtoneAmber` の chrome 装飾）を撤去 → `.buttonStyle(.glassProminent)` のシステム accent に委譲（content semantic の amber は維持）
- 1474 行の `FilmtoneRootView.swift` と 1637 行の `FilmtoneStrengthSheet.swift` を section / helper / extension で 17 ファイルに分離（それぞれ 367 / 376 行に縮小）
- **現状**: Liquid Glass はまだ 3 ファイル（`FilmtoneFullscreenLutEditor.swift` / `FilmtoneRootChrome.swift` / `FilmtoneStrengthSheet.swift` の done ボタン 1 箇所）のみで部分採用。**全 17 サブビューに広げる余地が残っている**
- **次チャットの仕事**: 各 surface（hero / preset / tuning / camera profile card / strength sheet sections / onboarding / library chips / unsaved export prompt / toast / disclosure section / advanced param chips）に Liquid Glass を当てるか / 当てないか / どう当てるかを CD（user）と詰めて、実装方針を決める

---

## 1. プロジェクトコンテキスト

### 1.1 Filmtone とは

ユーザー（CD = Creative Director、`chiba@fores-tone.co.jp`）が個人で開発するスタンドアロン iOS アプリ：写真・動画にフィルムグレード（カラー LUT、optical effect、grain、halation 等）を当てて書き出す native editor。Apple Log / S-Log3 / V-Log 等を含む 5 種の built-in source profile + creative LUT pack v1.4（Palermo→Urban density）+ 8 種の optical effect（halation / cross filter / halo prism 等）を持つ。

### 1.2 リポジトリ境界（必読）

| repo | 役割 | このリファクタとの関係 |
|---|---|---|
| **このリポ** `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` | apps + packages の **実装の正本** | 直近作業はすべてここ |
| **portfolio** `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` | 公開窓 `apps/web` のみ | `vendor/filmtone` submodule で packages を消費。filmtone code の編集は禁止、bump のみ |
| **life** `/Volumes/SamsungPortableSSDX5001/documents/life/` | docs/guides・truth scripts・5 ロール憲法 | knowledge hub。release/ios truth は life の `scripts/check-filmtone-*.sh` 経由 |

### 1.3 アプリ identity

```
Bundle ID:        com.chibatakumi.film.lab.ios
TeamID:           C3G77H8NM6
Workspace:        ios/App/App.xcworkspace
Scheme:           App
Capacitor:        7.4.3
iOS deployment:   26.0（本日 17.0 から bump）
Live Activities:  enabled
Real device UDID: 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9（iPhone 17 Pro、自動署名）
```

### 1.4 運用原則（CLAUDE.md §3 と整合、最優先）

| 原則 | 意味 |
|---|---|
| **本質優先 / 外殻最小** | 製品挙動を直接動かす変更（Swift / native / wiring / sidecar / Profile / fastlane / shader / preset 計算）= 本質。XCTest 6 並列 / formal QA 手順書 / 過剰 i18n 化 / 装飾的 banner = 外殻で **CD が「QA 希望」と明示した時のみ** |
| **保守的ヘッジ優先しない** | 「念のため fallback」「安全側でスキップ」「v1.x 後回し」のような逃げを優先しない。プロダクト品質に効く判断を取る |
| **思考は sequential-thinking** | 設計判断・lane 衝突・不変条件 gate 評価は `mcp__sequential-thinking` を使う（記憶ベース断言禁止） |
| **不確かなら検索** | iOS 26 / SwiftUI / Liquid Glass 仕様が曖昧な場合は `gemini-search` → `WebSearch` の順。記憶ベース推測禁止 |
| **handoff 鵜呑み禁止** | 旧 chat の handoff doc を引用する前に、現行 surface（`grep` / Swift / pbxproj）と突き合わせて live/frozen を確認 |
| **bun 必須** | `bun install` / `bun run` / `bun add`。`npm` 禁止 |
| **Git 操作は user が行う** | 自動 commit / push 禁止（user が明示するまで）|

---

## 2. 不変条件（絶対遵守）

| 項目 | 現行値 | 触る条件 |
|---|---|---|
| `Profile.version` | **4 固定** | スキーマ追加 = bump、フィールド名 rename も bump。CD と sidecar reader 両側を同一 commit で更新 |
| Sidecar | **V1 schema 固定** | フィールド追加は OK（reader が ignore する形に）／ 型変更は V2 化必要 |
| `hiddenDefaults` | 既存値固定（例: `depthRayAngleGamma=1.4` / `innerThreshold=0.1`） | CD 承認 gate を通過した時だけ |
| `FilmtoneEditorStore` API | **変更禁止** | 既存 setter / publisher のみ使用 |
| Capacitor bridge | **変更禁止** | `FilmtoneMediaPlugin` / `FilmtoneMediaTypes`、`cap:sync:ios` を不要に保つ |
| `FilmtonePhase0Generated.swift` | **編集禁止** | 生成物 |
| `Info.plist` の Photos / Live Activities / Encryption キー | 現行通り | App Store 審査直結 |
| Snapshot 端末 | iPhone 17 Pro Max iOS 26.2 UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192` | fastlane `screenshots` lane が決め打ち |

### 2.1 pbxproj 4-section 登録の儀式（新規 .swift 追加時）

`apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` の **4 セクション全部に登録**:
1. `PBXBuildFile`（D-prefix GUID）
2. `PBXFileReference`（C-prefix GUID）
3. `PBXSourcesBuildPhase`（`files = (...)` リスト）
4. `PBXGroup`（App group `504EC3061FED79650016851F` の `children = (...)` リスト）

**GUID 採番ルール**:
- 旧便: `C100000100000000000000XX` / `D100000100000000000000XX`（max `..0010`）
- 新便: `C200000100000000000000XX` / `D200000100000000000000XX`（max **`..002A`** as of `eb46fda`、次は `..002B`）
- 新規 Swift は `C/D200000100000000000000XX` を順次連番採番

**確認コマンド**:
```bash
grep '<新ファイル名>' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj | wc -l   # ≥ 4 で OK
```

最大 GUID 取得:
```bash
grep -oE 'C200000100000000000000[0-9A-F]+' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj | sort -u | tail -3
```

### 2.2 アンチパターン（踏まない）

1. **`#available(iOS 26.0, *)` フォールバック分岐を再導入しない** — deployment target は 26.0、分岐は無意味
2. **`Color.filmtoneAmber` を chrome decoration（active glass button / top bar / sheet primary）に再導入しない** — `.glassProminent` のシステム accent に委譲済
3. **silent fallback パイプライン禁止**（`feedback_no_fallback_bug_hotbed`）— 色域 / depth / mezzanine いずれも、外す条件は明示 fail で出す
4. **JSX comment を `return (` の直下に置かない**（`feedback_no_jsx_comment_outside_root_return`）
5. **新ファイル追加時に pbxproj 4-section 登録忘れ** — `wc -l` ≥ 4 を必ず確認
6. **`packages/film-lab-renderer/dist/` `packages/film-lab-smart-look/dist/` を消さない** — submodule 即 import 用に意図的に track
7. **handoff 引用前に live/frozen を確認**（`feedback_verify_before_quoting_handoff`）
8. **動画用語は `動画` / `video` 固定**（× `短尺動画` / `short-form video`）

---

## 3. ビルド・検証・実機チェーン（canonical）

### 3.1 シミュレータ build（commit gate）

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios

xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

`** BUILD SUCCEEDED **` で OK。SourceKit の `No such module 'UIKit'` 警告は context 問題で実害なし。

### 3.2 実機 build / install / launch

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios

# build（自動署名）
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -destination 'platform=iOS,id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' \
  -configuration Debug -derivedDataPath build/local-iphone build

# install
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  build/local-iphone/Build/Products/Debug-iphoneos/App.app

# launch（端末 unlock 必要）
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

### 3.3 web shell sync（Capacitor bridge を触ったとき only）

```bash
bun run build         # tsc --noEmit + vite build
bun run cap:sync:ios  # web → ios/App/App/public
```

Swift だけの変更なら **不要**（cap:sync:ios の儀式は bridge 変更時だけ）。

### 3.4 Phase 0 contract test

```bash
bun test src/lib/phase0-state.test.ts        # web 側
bun run verify:swift-contract                # swift 側 ./scripts/verify-phase0-contract.sh
```

---

## 4. 本日（2026-05-01）の作業ログ — 16 commits

### 4.1 WIP 整理（3 commits）

`117005e` 以前は user manual。続く 3 commits は AI が論理単位で整理：

1. `1f0d735` **feat(filmtone): add Halo Prism optical filter** — WebGPU shader (`packages/film-lab-renderer/src/webgpu/shaders/halo-prism.frag.wgsl.ts`)、core params 8 種（`haloPrismStrength` / `Radius` / `Width` / `Chromatic` / `Threshold` / `Split` / `Angle` / `SourceReactivity`）、UI control panel、ja/en strings、renderer dist 再生成
2. `7b8edf3` **feat(ios): wire v1.4 Creative LUT Pack 01 provenance through library + sidecar** — `CreativeLutBinding.bundled(slug, filename, sha256, intensity)` 追加、`SidecarLutRef.bundledSlug/bundledPackId` 経路、`FilmtoneLibraryChip` の "FILMTONE" caption pill 廃止 → amber tint+stroke のみに整理
3. `dad8ce9` **feat(ios): expand strength sheet adjustments + ship help comparison image assets** — Strength Sheet に creative LUT intensity slider 追加、Quick adjust slot 入れ替え（filmCharacter ↔ dynamics、era 反転）、Advanced "basic" group（exposure/contrast/saturation/temperature/tint/fade）追加、in-Swift 手書きの help frame を 12 種の `HelpCompare*` JPEG asset に置換、`FilmtoneHelpAssetGenerator` 投入

### 4.2 Phase 1: deployment + Liquid Glass cleanup（4 commits）

4. `3b99a3d` **chore(ios): bump deployment target to iOS 26.0** — `IPHONEOS_DEPLOYMENT_TARGET` 8 行（App + FilmtoneExportActivity × Debug/Release）を 17.0 → 26.0
5. `1843857` **refactor(ios): drop iOS 26 availability fallbacks from fullscreen LUT editor** — `LiquidGlassSurface` / `GlassActionButton` / `GlassGroup` から `#available(iOS 26.0, *)` 分岐削除、`.ultraThinMaterial` / `legacyButton` / 素 `content()` パス削除（-37 行 net）
6. `65b8bc6` **refactor(ios): inline FilmtoneTopChrome to single Liquid Glass path** — `FilmtoneFallbackTopChrome` struct と `FilmtoneLiquidGlassTopChrome` ラッパ撤去、body に `GlassEffectContainer` + `.glassEffect()` 直書き（-65 行 net）
7. `65a1a4b` **refactor(ios): drop amber tint from chrome decoration** — `FilmtoneChromeActionStyle` / `FilmtoneTopBarActionStyle`（dead code、Phase 1C で消えた fallback 専用）削除、`FilmtoneSheetPrimaryActionStyle` 削除して call site を `.buttonStyle(.glassProminent)` に、`UnsavedExportPrompt` の amber save icon と amber stroke を neutral に、`backgroundLayer` の amber radial gradient 撤去（-76 行 net）

**保持された content semantic amber**:
- `FilmtoneSliderRow` の active label / value foreground / slider tint
- `FilmtoneLibraryChip` の amber star / built-in marker（catalog identity）
- `FilmtoneHdrPolicyNotice` の amber（warn semantic）
- `FilmtonePresetRow` の amber（preset 識別 / lookup color）
- `FilmtonePreviewView` / `FilmtoneExportPanel` / `FilmtoneTermHelpSheet` の amber accent
- `FilmtoneOnboardingView` 内の amber（onboarding 装飾、別 phase 議論）
- `sourceLoadBanner` の amber（progress semantic）

### 4.3 Phase 2: 共通コンポーネント抽出（2 commits）

8. `38341a4` **refactor(ios): extract FilmtoneSliderRow to its own file** — StrengthSheet 内 `private struct FilmtoneSliderRow`（label + slider + value + help button、active label を amber で highlight）を新ファイルへ。`FilmtoneHelpIconButton` も `private` 解除して module-level に。pbxproj GUID `..001C`
9. `eaf79e9` **refactor(ios): extract LUT control helpers to FilmtoneLutControls namespace** — `lutProfileRow` / `lutIntensityControl` / `lutIntensityPercentLabel` を `enum FilmtoneLutControls` namespace に。call site は `FilmtoneLutControls.profileRow(...)` 形式。pbxproj GUID `..001D`

**Chip 統一は対象外と判断**: handoff doc に書かれていた `FullscreenLookChip` ↔ `FilmtoneLibraryChip` 統合は実コードに `FullscreenLookChip` struct が存在せず、`FullscreenLookCarousel` は `GlassActionButton` 直書き / `FilmtoneLibraryChip` は amber pill でデザイン言語が異なるため。fullscreen は glass、inline は amber pill のまま並存。**この判断は次チャットで再評価対象**（§7.2 参照）。

### 4.4 Phase 3A: RootView section split（4 commits）

`FilmtoneRootView.swift` 1474 → 367 行（**75% 削減**）。

10. `bd86e34` **split RootView into Hero / Preset / Tuning / CameraProfileCard** — 4 section を独立 View struct に。各 `@ObservedObject store` + 必要な `@Binding` を受け取る。pbxproj GUIDs `..001E` 〜 `..0021`
11. `a1aa3dc` **extract Onboarding flow to FilmtoneOnboardingView.swift** — `FilmtoneOnboardingLaunchArguments` / `FilmtoneOnboardingState` / `FilmtoneOnboardingSlide` / `FilmtoneOnboardingView` / `FilmtoneOnboardingPage` / `FilmtoneOnboardingPreviewCard` を一括移動。pbxproj GUID `..0022`
12. `118f090` **extract RootView chrome + SavedLookSheetMode helpers** — `SavedLookSheetMode` enum を `FilmtoneSavedLookSheetMode.swift` に、`FilmtoneSectionHeader` / `FilmtoneTopChrome` / `FilmtoneTopChromeTitle` / `UnsavedExportPrompt` / `Color.filmtone*` extension / `FilmtoneToastView` を `FilmtoneRootChrome.swift` に。pbxproj GUIDs `..0023` `..0024`

### 4.5 Phase 3B: StrengthSheet section split（3 commits）

`FilmtoneStrengthSheet.swift` 1637 → 376 行（**77% 削減**）。

13. `5cb5929` **extract adjustment help system to its own file** — `FilmtoneAdjustmentHelpTopic` / `FilmtoneAdjustmentComparisonStyle`（+ Family extension）/ `FilmtoneAdjustmentHelpSheet` / `FilmtoneHelpComparisonImage` / `FilmtoneHelpSampleFrame` を `FilmtoneAdjustmentHelpSheet.swift` に。pbxproj GUID `..0025`
14. `530c36e` **split StrengthSheet into preview / advanced-params / disclosure / styles** — `FilmtoneSheetPreview` + `FilmtoneCompareRevealPreview` を `FilmtoneSheetPreview.swift`、`FilmtoneAdvancedParamGroup` / `Recipe` / `Control` / `RecipeSelection` enum / `FilmtoneAdvancedParamGroupSection` / `FilmtoneParamPresetChip` を `FilmtoneAdvancedParamsModel.swift`、`FilmtoneHelpIconButton` + `FilmtoneDisclosureSection` を `FilmtoneDisclosureSection.swift`、`FilmtoneSheetSecondaryActionStyle` + `sectionDivider` extension を `FilmtoneStrengthSheetStyles.swift`。pbxproj GUIDs `..0026` 〜 `..0029`
15. `eb46fda` **hoist StrengthSheet data layer to extension file** — `makeHelpTopic` / `comparisonStyleForGroup` / `comparisonStyleForParam` / `advancedParamGroups` / `toneAdvancedRecipes` / `standardAdvancedRecipes` / `recipe` / `control` + `percentLabel` / `signedPercentLabel` / `decimalLabel` static helpers を `FilmtoneStrengthSheetData.swift` の `extension FilmtoneStrengthSheet` に。pbxproj GUID `..002A`

---

## 5. 現在の Liquid Glass 採用面マップ（2026-05-01 21:00 JST 時点）

### 5.1 既に Liquid Glass を使っている surfaces（3 ファイル）

| file | line | 種別 |
|---|---|---|
| `FilmtoneFullscreenLutEditor.swift` | 109 | `LiquidGlassSurface` ViewModifier — `.glassEffect(glassConfig, in: shape)`（tint / interactive 両対応） |
| `FilmtoneFullscreenLutEditor.swift` | 158 | `GlassActionButton.body` — `.buttonStyle(.glassProminent)`（active state） |
| `FilmtoneFullscreenLutEditor.swift` | 160 | `GlassActionButton.body` — `.buttonStyle(.glass)`（passive state） |
| `FilmtoneFullscreenLutEditor.swift` | 178 | `GlassGroup` ラッパ — `GlassEffectContainer(spacing:content:)` |
| `FilmtoneRootChrome.swift` | 21 | `FilmtoneTopChrome.body` — `GlassEffectContainer(spacing: 10)` |
| `FilmtoneRootChrome.swift` | 27 | `FilmtoneTopChromeTitle` 周りに `.glassEffect(.regular.tint(Color.black.opacity(0.10)), in: .rect(cornerRadius: 18))` |
| `FilmtoneRootChrome.swift` | 38 | top bar action button — `.buttonStyle(.glassProminent)` |
| `FilmtoneStrengthSheet.swift` | 103 | sheet "Done" button — `.buttonStyle(.glassProminent) + .controlSize(.regular)` |

**`Glass` 構成パターン（`FilmtoneFullscreenLutEditor.swift:111-117` 参照）**:
```swift
private var glassConfig: Glass {
    var g: Glass = .regular
    if let tint { g = g.tint(tint) }
    if interactive { g = g.interactive() }
    return g
}
```

### 5.2 Liquid Glass まだ採用していない surfaces（候補）

| file | surface | 現状 | 採用検討余地 |
|---|---|---|---|
| `FilmtoneHeroSection.swift` | preview frame surround | `FilmtonePreviewView` 内（実体未確認） | preview frame を glass で囲む、controls overlay を glass |
| `FilmtonePresetSection.swift` | "Default" reset button (line 17–35) | amber capsule overlay | `.buttonStyle(.glass)` + amber tint or system accent |
| `FilmtonePresetSection.swift` | `FilmtonePresetRow` chips | 別ファイル（実体未確認） | preset chip 自体を glass 化 |
| `FilmtoneTuningSection.swift` | "Adjust" launcher button (line 16–66) | `.fill(Color.white.opacity(0.03))` + stroke 0.06 の rounded surface | glass surface への置き換え可 |
| `FilmtoneTuningSection.swift` | slider icon badge (line 37–49) | `.fill(Color.white.opacity(0.05))` + stroke の rounded square | mini glass surface 化 |
| `FilmtoneCameraProfileCard.swift` | card surround (line 138–146) | `.fill(Color.white.opacity(0.03))` + stroke 0.06 | glass card に |
| `FilmtoneCameraProfileCard.swift` | LUT picker menu trigger（`FilmtoneLutControls.profileRow` 内 menu の background, `FilmtoneLutControls.swift:54-64`） | `.fill(Color.white.opacity(0.05))` + stroke 0.08 | glass button or glass surface |
| `FilmtoneStrengthSheet.swift` | sheet background | `Color.filmtoneBackground.ignoresSafeArea()` (line 16) | sheet 全体を Liquid Glass material に |
| `FilmtoneStrengthSheet.swift` | "Default" button (line 92, `FilmtoneSheetSecondaryActionStyle`) | white opacity rounded fill + stroke | `.buttonStyle(.glass)` 移行候補 |
| `FilmtoneSheetSecondaryActionStyle` (`FilmtoneStrengthSheetStyles.swift:4-21`) | 自前 ButtonStyle | white opacity + stroke | `.buttonStyle(.glass)` への置換で削除候補 |
| `FilmtoneSliderRow.swift` | row 全体 | 透明（VStack 直） | row 単位の glass ribbon にする案 |
| `FilmtoneAdvancedParamsModel.swift` | `FilmtoneAdvancedParamGroupSection` panel | （実体未読） | section panel を glass 化 |
| `FilmtoneAdvancedParamsModel.swift` | `FilmtoneParamPresetChip` | （実体未読） | chip を glass 化 |
| `FilmtoneDisclosureSection.swift` | disclosure container | （実体未読） | container を glass 化 |
| `FilmtoneRootChrome.swift` | `UnsavedExportPrompt` (line ~125+) | `.fill(.ultraThinMaterial) + .black.opacity(0.34) + Color.white.opacity(0.10) stroke` | `.glassEffect(.regular, in: rect)` に置換 |
| `FilmtoneRootChrome.swift` | `FilmtoneToastView` (line ~155+) | （実体未読） | toast を glass capsule に |
| `FilmtoneOnboardingView.swift` | onboarding cards / controls | (`FilmtoneOnboardingPreviewCard` line ~225 周辺) | onboarding pages を glass で構築 |
| `FilmtoneAdjustmentHelpSheet.swift` | help sheet 全体 | （実体未読） | help sheet も glass material |
| `FilmtoneSheetPreview.swift` | preview overlay labels | amber pills + black opacity | label pill を glass にする案 |
| `FilmtoneLibrarySection.swift` | `FilmtoneLibraryChip` | amber tint pill（catalog identity） | **CD 判断保留**（今回 2C で chip 抽出/glass 化を見送り）|
| `FilmtoneFullscreenLutEditor.swift:600` | `FullscreenLookCarousel` 内 chips | `GlassActionButton` 直書き | 既に glass、設計 OK |

### 5.3 amber が依然 chrome 寄りに残る箇所（次チャットで議論候補）

これらは **§4.2 で「content semantic」と判定して保持**したが、次チャットで Liquid Glass への置換を再検討する余地あり：

- `FilmtonePresetSection.swift` の "Default" reset capsule（amber stroke + amber foreground）
- `FilmtoneTuningSection.swift` の slider icon amber tint
- `FilmtoneCameraProfileCard.swift` 内 amber 残存箇所
- `FilmtoneRootChrome.swift` の onboarding system 残存 amber
- `FilmtoneSheetPreview.swift` の preview overlay amber pills

---

## 6. ファイル構成（refactor 後）

### 6.1 ディレクトリ

`apps/capacitor-film-lab-ios/ios/App/App/` に 76 個の `.swift`。UI 関連は以下 18 ファイル：

```
View root + composition
  FilmtoneRootView.swift                  367 行   body / sheets / lifecycle / topChrome / messageStack / bottomOverlay
  FilmtoneHeroSection.swift                58 行   preview + activePresetLabel + adjustmentSummaryText
  FilmtonePresetSection.swift              55 行   preset row + "Default" reset button
  FilmtoneTuningSection.swift              83 行   "Adjust" launcher + cameraProfileCard 埋め込み
  FilmtoneCameraProfileCard.swift         167 行   camera + creative LUT pickers + saved LUTs/Looks strips
  FilmtoneOnboardingView.swift            315 行   4-page onboarding flow + preview card

Sheets / fullscreen
  FilmtoneStrengthSheet.swift             376 行   body / handle / header / sheetPreview / strength / adjustments / advanced / lookLutAmountControl
  FilmtoneStrengthSheetData.swift         312 行   extension: makeHelpTopic / comparisonStyleFor* / advancedParamGroups / control / recipes / static label helpers
  FilmtoneSheetPreview.swift              264 行   FilmtoneSheetPreview + FilmtoneCompareRevealPreview
  FilmtoneAdjustmentHelpSheet.swift       250 行   FilmtoneAdjustmentHelpTopic + ComparisonStyle + Family ext + HelpSheet + ComparisonImage + SampleFrame
  FilmtoneFullscreenLutEditor.swift       601 行   Liquid Glass fullscreen editor（既に Liquid Glass 全面）
  FilmtoneSavedLookSheetMode.swift         56 行   .sheet(item:) ID enum

Reusable components
  FilmtoneSliderRow.swift                  39 行   labeled slider + help icon + active state
  FilmtoneLutControls.swift               109 行   namespace enum: profileRow / intensityControl / intensityPercentLabel
  FilmtoneAdvancedParamsModel.swift       218 行   data structs + GroupSection + RecipeSelection + ParamPresetChip
  FilmtoneDisclosureSection.swift         201 行   FilmtoneHelpIconButton + FilmtoneDisclosureSection (collapsible)
  FilmtoneStrengthSheetStyles.swift        33 行   FilmtoneSheetSecondaryActionStyle + sectionDivider extension
  FilmtoneRootChrome.swift                200 行   FilmtoneSectionHeader + FilmtoneTopChrome + Title + UnsavedExportPrompt + Color ext + ToastView
```

### 6.2 関連ファイル（次チャットでも参照する）

```
Library / Catalog
  FilmtoneLibrarySection.swift            chip + saved looks/luts strips
  FilmtoneBuiltInCatalog.swift            5 built-in looks + UUID namespace
  FilmtoneSourceProfileCatalog.swift      5 built-in source profiles

Other UI
  FilmtonePreviewView.swift               compare-aware preview
  FilmtonePreviewPlayerView.swift         video preview (showsPlaybackControls supported)
  FilmtonePresetRow.swift                 horizontal preset chip row
  FilmtoneHdrPolicyNotice.swift           HDR warning panel
  FilmtoneTermHelpSheet.swift             generic term help sheet
  FilmtoneExportPanel.swift               export status / share

State / domain
  FilmtoneEditorStore.swift               primary @ObservedObject（API 凍結）
  FilmtoneEditorFacade.swift              façade
  FilmtonePersistence.swift               disk
  FilmtoneStrings.swift                   i18n strings
```

---

## 7. 次チャットへの引き継ぎポイント

### 7.1 設計ゴール（CD と詰めるべきもの）

CD の本日の合意（再掲）:
1. iOS 17/18 切り捨て **済**（deployment 26.0）
2. Apple Liquid Glass 全面採用 **方針 OK**、但し実装はまだ部分採用
3. amber chrome 全廃 **済**（chrome 限定、content semantic は保持）
4. SwiftUI 責務分離 **済**（17 ファイル化）

**次チャットで詰めること**:
- 各 surface に Liquid Glass を当てるか / 当てないか / 形は何か（material variant、tint、interactive、container 単位の merge）
- amber が依然残る箇所（§5.3）の扱い
- chip 統一の再評価（§4.3 の「対象外」判断を覆すか）
- Strength Sheet の sheet background を `Color.filmtoneBackground` から Liquid Glass material に置換するか
- onboarding system の glass 化（amber gradient 残存）

### 7.2 設計の制約・ガードレール

- `FilmtonePreviewView` の中身は preview pipeline と密結合（compare、video, fullscreen open hook）— glass 装飾は **外側**（surround）で
- `FilmtoneEditorStore` API を変えない
- Profile.version = 4 / sidecar V1 を変えない
- accessibility identifiers を維持（XCUITest が依存）— grep で全件監査推奨
- `accessibilityIdentifier` / `accessibilityLabel` 既存値は壊さない
- `feedback_no_silent_stream_redefine` — 並列 stream を切る場合は handoff §8.5 4 セクションで機構化
- `feedback_minimize_decision_cost` — CD 承認受領後は「commit + push + 次手」をまとめて出す

### 7.3 評価軸（CD が判断するもの）

各 Liquid Glass 採用案について、以下軸で CD 判断を仰ぐ：

1. **視覚 wow**: Apple HIG / Liquid Glass の特性（refraction、specular highlight、interactive shimmer）が活きる surface か
2. **content vs chrome**: その surface は chrome 装飾か content semantic（カタログ identity / progress / warning）か
3. **読みやすさ**: glass 化で text contrast / legibility が損なわれないか
4. **performance**: 実機で 60 fps を維持できるか（`GlassEffectContainer` の merge は GPU 効率を上げるが要計測）
5. **regression**: 既存ユーザーの動線（preset 選択、保存、書き出し）に影響しないか

### 7.4 探索順序の提案

CD の手元で価値を最大化する順番:

1. **Strength Sheet** — 編集体験の中心、現状 `Color.filmtoneBackground` で glass 不採用。sheet 全体を `.glassEffect()` で覆えるか（`presentationDetents([.medium, .large])` との相互作用）
2. **Hero / Preview surround** — アプリ顔。preview frame を glass で囲む、`FilmtonePreviewView` の compare label pills を glass に
3. **Camera Profile Card** — 機能高密度、現状 white opacity rounded surface。card を glass に
4. **Tuning Section "Adjust" launcher** — 大きい button area、glass surface 化 → tap 時 specular highlight
5. **Disclosure sections / Advanced Params chips** — `FilmtoneDisclosureSection` / `FilmtoneAdvancedParamGroupSection` / `FilmtoneParamPresetChip` を glass に
6. **Bottom overlays** — `UnsavedExportPrompt` / `FilmtoneToastView` を glass に
7. **Onboarding** — amber gradient 残存、glass で再構築
8. **Help / Term sheets** — `FilmtoneAdjustmentHelpSheet` / `FilmtoneTermHelpSheet`
9. **Library chips の再評価** — CD と相談して amber pill を glass に置換するか / 並存維持か

### 7.5 実装作法の reminder

- 各案は **atomic commit / file 単位** で landing
- 各 commit ごとに `xcodebuild -workspace ... build CODE_SIGNING_ALLOWED=NO` green
- 新規 .swift 追加時は **pbxproj 4-section 登録**（`grep '<file>' project.pbxproj | wc -l` ≥ 4）
- 実機で視覚回帰確認（端末 unlock 必須）
- iOS 26 SwiftUI 仕様で曖昧な点は `gemini-search` / `WebSearch` で確認
- 設計判断は `mcp__sequential-thinking` で詰める
- user 明示までは push しない

---

## 8. 参考リソース

### 8.1 Apple 公式（iOS 26 Liquid Glass）

- WWDC25 Sessions on Liquid Glass material（"Adopting Liquid Glass" / "Designing with Liquid Glass" 等）
- SwiftUI APIs: `.glassEffect(_:in:)` / `Glass` struct（`.regular` / `.tint(_:)` / `.interactive()`） / `GlassEffectContainer` / `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`
- Apple HIG — Materials → Liquid Glass セクション（"only apply tint to active / primary state"）

### 8.2 コードベース内の reference

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneFullscreenLutEditor.swift:99-180` — Liquid Glass の **canonical 実装パターン**（`LiquidGlassSurface` ViewModifier / `GlassActionButton` / `GlassGroup`）。新しい glass 採用は基本このパターンを model にする
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootChrome.swift:14-43` — top chrome の Liquid Glass 採用例
- `apps/capacitor-film-lab-ios/CLAUDE.md` — iOS サブツリー専用ガイド（223 行）

### 8.3 計画・履歴

- 本日の plan file: `/Users/chibatakumi/.claude/plans/filmtone-ios-eager-melody.md`
- repo root CLAUDE.md: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md`
- iOS CLAUDE.md: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios/CLAUDE.md`
- life CLAUDE.md: `/Volumes/SamsungPortableSSDX5001/documents/life/CLAUDE.md`
- truth scripts: `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-{release,ios}-truth.sh`

### 8.4 直近 handoff docs（同 chat 群）

- `docs/filmtone/ios/creative-lut-pack-01-material-adaptive-next-handoff-2026-05-01-jst.md`
- `docs/filmtone/ios/creative-lut-pack-01-originalization-handoff-2026-05-01-jst.md`
- `docs/filmtone/ios/creative-lut-pack-01-quality-iteration-handoff-2026-05-01-jst.md`
- `docs/filmtone/filmtone-halo-prism-filter-handoff-2026-05-01-jst.md`

---

## 9. 引き継ぎプロンプト（次チャットに貼る）

下記をそのままコピペすれば、新規 chat で最高精度のコンテキストを与えられる。

````
あなたは Filmtone iOS（Apple iOS 26.0 deployment、SwiftUI + Capacitor 7.4.3、`com.chibatakumi.film.lab.ios`）の Liquid Glass UI 設計を担当する SwiftUI engineer + designer です。

# 必読ドキュメント（順番厳守）

1. `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/liquid-glass-ui-design-handoff-2026-05-01-jst.md` ← この chat の全コンテキスト
2. `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md` ← repo root ルール
3. `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios/CLAUDE.md` ← iOS サブツリー固有ルール（223 行）
4. `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneFullscreenLutEditor.swift:99-180` ← Liquid Glass 採用の canonical 実装パターン

# あなたが守ること（最優先）

- 本質優先 / 外殻最小（CLAUDE.md §3）— XCTest 並列 / formal QA / 装飾 banner は CD が「QA 希望」と明示した時だけ
- 保守的ヘッジを優先しない — 「念のため fallback」「v1.x 後回し」のような逃げを取らない
- 設計判断は `mcp__sequential-thinking` で詰める（記憶ベース断言禁止）
- 不確かな iOS 26 / SwiftUI / Liquid Glass 仕様は `gemini-search` → `WebSearch` で確認
- handoff doc の機能言及を引用する前に `grep` / Swift / pbxproj で live/frozen 確認
- 自動 commit / push **禁止**（user 明示まで）
- 並列 stream の silent 縮退禁止 — handoff §8.5 4 セクション（Plan Compliance / Cross-Stream Visibility / Scope Diff / 残タスク enumeration）で機構化
- bun 必須（npm 禁止）
- 出力は日本語、ファイル参照は `path:line` 形式

# 不変条件（絶対遵守）

- Profile.version = 4 / sidecar V1 schema を変えない
- `FilmtoneEditorStore` API（既存 setter / publisher）を変えない
- Capacitor bridge（`FilmtoneMediaPlugin` / `FilmtoneMediaTypes`）を変えない（cap:sync:ios 不要を維持）
- `FilmtonePhase0Generated.swift` 編集禁止
- `hiddenDefaults`（`depthRayAngleGamma=1.4` / `innerThreshold=0.1` 等）触らない
- `#available(iOS 26.0, *)` フォールバック分岐を再導入しない（deployment 26.0 で無意味）
- `Color.filmtoneAmber` を chrome decoration（active glass button / top bar / sheet primary）に再導入しない
- silent fallback パイプライン禁止（外す条件は明示 fail）
- 新規 .swift 追加時は project.pbxproj 4 セクション全部に登録（PBXBuildFile / PBXFileReference / PBXSourcesBuildPhase / PBXGroup）— GUID は `C/D200000100000000000000XX` 形式、次は `..002B` から
- accessibilityIdentifier / accessibilityLabel 既存値を壊さない（XCUITest 依存）

# 直近の前提（2026-05-01 完了済）

- 本日 16 commits land（HEAD = `eb46fda`、push 済）
- iOS 26.0 deployment、Liquid Glass フォールバック路線全廃
- amber chrome 撤去（content semantic は保持）
- FilmtoneRootView 1474 → 367 行、FilmtoneStrengthSheet 1637 → 376 行
- 17 ファイルに分離（Hero / Preset / Tuning / CameraProfileCard / Onboarding / Chrome / SavedLookSheetMode / SliderRow / LutControls / AdjustmentHelpSheet / SheetPreview / AdvancedParamsModel / DisclosureSection / Styles / Data extension）

# 既に Liquid Glass を使っている surfaces（参考）

- `FilmtoneFullscreenLutEditor.swift` — 全面（`LiquidGlassSurface` ViewModifier / `GlassActionButton` / `GlassGroup`）
- `FilmtoneRootChrome.swift:14-43` — top chrome の `GlassEffectContainer` + `.glassEffect()` + `.buttonStyle(.glassProminent)`
- `FilmtoneStrengthSheet.swift:103` — sheet "Done" button `.buttonStyle(.glassProminent)`

それ以外の 15 surfaces はまだ glass 不採用。詳細は handoff doc §5.2 を参照。

# 今回のミッション

Apple Liquid Glass を最大限活かす UI 案を 0 → 1 で設計する。具体的には：

1. handoff doc §5.2 の "まだ採用していない surfaces" 一覧を読み、各 surface に Liquid Glass を当てるか / 当てないか / どう当てるか（material variant、tint、interactive、container 単位の merge）を CD に提案する
2. handoff doc §7.4 の探索順（Strength Sheet → Hero → Camera Profile Card → ...）を起点に進める。最初に Strength Sheet 全体を Liquid Glass material で覆う案を CD と詰める
3. amber が依然残る箇所（§5.3）の扱いを再評価
4. chip 統一の再評価（§4.3 の「対象外」判断）

# 進め方

1. 最初に handoff doc 全文を Read した上で、CD に対して以下を提示：
   - 第一手の提案（Strength Sheet 全体の glass 化 or 別 surface）
   - その提案で何が wow になるか / 何が壊れる可能性があるか
   - 必要な検証（実機計測 / accessibility / regression）
2. CD の指示を受けたら `mcp__sequential-thinking` で設計を詰めて、`/Users/chibatakumi/.claude/plans/<topic>.md` に plan を書いてから ExitPlanMode で承認を仰ぐ
3. 承認されたら atomic commit / file 単位で実装、各 commit ごとに simulator build green を確認
4. 新規 .swift は pbxproj 4-section 登録（`grep '<file>' project.pbxproj | wc -l` ≥ 4）
5. 実機（iPhone 17 Pro UDID `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`）で視覚回帰確認
6. user 明示までは push しない

# まず最初にやること

1. 上記 handoff doc を Read で全文読む
2. `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneFullscreenLutEditor.swift:99-180` の Liquid Glass 採用パターンを Read
3. `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift` の body / handle / sheetPreview / strengthSection（line 14-147）を Read して、sheet 全体の構造を把握
4. CD に対して **Strength Sheet 全体 Liquid Glass 化の第一案**（material variant、tint、presentationDetents との相互作用、accessibility への影響）を 200 字以内で提示し、進めるか別 surface から行くかの判断を仰ぐ

質問・不明点があれば `mcp__sequential-thinking` で詰めた上で簡潔に質問する。
````

---

## 10. 完了サイン（次チャットで確認するべき gate）

このチャットは以下を満たして終了：

- [x] 16 commits land（main、push 済 = origin/main も `eb46fda`）
- [x] simulator build green
- [x] real device build / install / launch green
- [x] working tree clean（`git status` で clean）
- [x] pbxproj 4-section 登録 OK（全新規ファイル `grep | wc -l` ≥ 4）
- [x] handoff doc（本ファイル）作成

次チャット開始時に上記が崩れていないことを `git status` / `git log --oneline -16` で確認してから着手すること。
