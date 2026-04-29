# Filmtone iOS Process / Tone プリセット再設計ハンドオフ

作成日: 2026-04-29 JST  
対象リポジトリ: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`

## 目的

次チャットでは、Filmtone iOS版の詳細パラメータカードのうち `Process` と `Tone` だけを再設計する。

現状は各詳細グループに `None / Default / Strong` の3ボタンがあるが、`Process` と `Tone` は効果の性質が単純な強弱ではないため、`Default` / `Strong` という名前だとユーザーに意味が伝わりにくい。次の作業では、この2グループだけを「何が起きるか分かるプリセットボタン」に置き換える。

## これまでの経緯

1. 詳細パラメータ数が多く、スクロールが大変だった。
2. `FilmtoneStrengthSheet` の詳細パラメータを `Process / Optics / Glow / Grain / Tone` のDisclosureカードへ分割した。
3. 各カードは閉じた状態で操作できるよう、カードヘッダ下にプリセットチップを置いた。
4. 初期実装では `Default / Strong` の2ボタンだった。
5. `Strong` が弱すぎて変化が分かりにくかったため、各グループのStrong値を強めた。
6. その後「閉じている状態を正」とし、詳細カードは自動展開せず、閉じたカードから効果を選ぶ思想へ寄せた。
7. ボタンは `None / Default / Strong` の3つになった。
8. `None` は対象グループの `paramOverrides` を消す。
9. `Default` と `Strong` は既存の `paramOverrides` にグループ単位で値を入れる。新しい永続化schemaは増やしていない。
10. `Grain` はDefaultが強すぎ、かつStrongと近すぎたため、Defaultだけ下げた。
11. 最新のユーザー意図として、次は `Process` と `Tone` の `Default / Strong` という抽象名をやめ、意味のあるプリセットボタンへ置き換えたい。

## 現在の重要な前提

現在の設計上、詳細グループは「閉じた状態で選ぶ」のが正。ユーザーが細かく詰めたい時だけ開いてスライダーを触る。

現在の状態判定は `FilmtoneParamGroupPresetSelection` で行う。

- `nonePreset`: 対象グループのoverrideが0件
- `defaultPreset`: 対象グループの実効値がdefaultValuesと一致
- `strongPreset`: 対象グループの実効値がstrongValuesと一致
- `custom(activeCount:)`: 手動調整などでどちらにも一致しない

新しい保存スキーマ、DTO、生成契約は増やさない。既存の `paramOverrides` を使い、ボタン押下で対象キーだけ一括設定または一括クリアする。

## 現在の主な対象ファイル

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift`
  - 詳細パラメータカードUI
  - グループ定義
  - `defaultValues` / `strongValues`
  - 各チップの表示とaction
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
  - `FilmtoneParamGroupPresetSelection`
  - `paramPresetSelection(for:defaultValues:strongValues:)`
  - `clearParamOverrides(for:)`
  - `applyParamPreset(values:for:)`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
  - `None / Default / Strong / Custom` のSwift fallback文字列
- `apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift`
  - 詳細シートのUI回帰テスト

## 現在のローカル状態

このドキュメント作成時点の最新観測 `git status --short --branch` は以下。

```text
## main...origin/main
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtonePresetCatalog.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSnapshotSupport.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift
 M apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings
 M apps/capacitor-film-lab-ios/scripts/swift/verify-phase0-contract.swift
 M apps/web/src/features/liquid-glass/LiquidGlassProvider.tsx
 M packages/film-lab-core/src/index.ts
 M packages/film-lab-core/src/ios-phase0.test.ts
 M packages/film-lab-core/src/ios-phase0.ts
 M packages/film-lab-core/src/ios-preset-overrides.ts
 M packages/film-lab-core/src/ios-swift-payload.test.ts
 M packages/film-lab-core/src/ios-swift-payload.ts
?? docs/filmtone/ios/filmtone-ios-process-tone-preset-handoff-2026-04-29-jst.md
```

注意:
- `FilmtoneStrengthSheet.swift` の未コミット差分は、Grain Defaultだけを小さくした変更。
- `packages/film-lab-core/src/*` と生成Swift/検証script周辺の未コミット差分は、iOSプリセットセットを `reset / iphone / softBlue / amberGlow` に絞る別作業の可能性が高い。Process/Toneボタン再設計では、必要がなければ触らない。
- `apps/web/src/features/liquid-glass/LiquidGlassProvider.tsx` はFilmtone iOS作業と無関係の可能性が高い。触らない。
- 作業開始時には必ず `git status --short --branch` を取り直す。このドキュメント作成中にも別チャット由来と思われる変更が増えていた。
- `main` は `origin/main` と一致している。

最新の関連コミット:

```text
377f886c (HEAD -> main, origin/main, origin/HEAD) Merge remote-tracking branch 'origin/main'
d127d4ba fix(filmtone-ios): refine advanced presets and preview refresh
44e87f53 fix(filmtone-ios): make film grain visible
f72fac4e feat(filmtone-ios): intensify advanced strong presets
cf3ef6e7 feat(filmtone-ios): group advanced params with presets
```

## 現在のグループ値

### Process

対象キー:

```swift
cyan, magenta, yellow, printContrast, compressionAmount, compressionRange
```

現在のDefault:

```swift
"cyan": max(base.cyan - 0.08, -1.0)
"magenta": min(base.magenta + 0.06, 1.0)
"yellow": min(base.yellow + 0.14, 1.0)
"printContrast": max(base.printContrast, 0.38)
"compressionAmount": max(base.compressionAmount, 0.42)
"compressionRange": max(base.compressionRange, 0.76)
```

現在のStrong:

```swift
"cyan": max(base.cyan - 0.14, -1.0)
"magenta": min(base.magenta + 0.10, 1.0)
"yellow": min(base.yellow + 0.22, 1.0)
"printContrast": max(base.printContrast, 0.58)
"compressionAmount": max(base.compressionAmount, 0.62)
"compressionRange": max(base.compressionRange, 0.88)
```

問題:
- `Process` は「強弱」というより、プリント工程・CMYバイアス・ハイライト圧縮の複合効果。
- `Default / Strong` では、何が変わるか予測できない。
- 1軸の強弱ではなく、方向性のある名前にした方がよい。

次チャットで検討する候補:

- `Neutral / Print / Dense`
- `None / Print / Push`
- `Clean / Print / Punch`
- `Soft Print / Rich Print`
- `Print Soft / Print Deep`

ただし3ボタン設計を維持するなら、`None` は残し、Processだけ `Default / Strong` の表示名を `Print / Push` のような意味名に変えるのが最小変更。

### Tone

対象キー:

```swift
exposure, contrast, saturation, temperature, tint, fade
```

現在のDefault:

```swift
"contrast": min(base.contrast + 0.30, 2.0)
"saturation": base.saturation <= 0.05 ? base.saturation : min(base.saturation + 0.24, 2.0)
```

現在のStrong:

```swift
"contrast": min(base.contrast + 0.46, 2.0)
"saturation": base.saturation <= 0.05 ? base.saturation : min(base.saturation + 0.36, 2.0)
```

注意:
- `Tone` の現在プリセットはcontrast/saturationだけを触る。
- `exposure / temperature / tint / fade` は維持している。
- monochrome相当として `base.saturation <= 0.05` の場合はsaturationを維持する。

問題:
- `Tone` も単純なDefault/Strongだと意味が弱い。
- 実際には「コントラストと彩度を上げる」だけなので、ユーザーには `Vivid` / `Punch` / `Crisp` のような名前の方が伝わる。
- もしToneプリセットを本当に豊かにするなら、2段階の強弱ではなく、方向性を分けるべき。

次チャットで検討する候補:

- `Natural / Vivid / Punch`
- `Flat / Vivid / Punch`
- `Clean / Vivid / Crisp`
- `Soft / Pop / Punch`

ただし `None` を既に持っているので、3ボタンの意味は `None / Vivid / Punch` が自然。現在のDefault値を `Vivid`、Strong値を `Punch` にリネームするだけでも改善する。

## 他グループの現状

### Optics

現状の `Default / Strong` はまだ強弱として意味が通る。対象はRGBずれ、レンズソフト、ビネット。

Default:

```swift
rgbShift 0.0035
lensSoftness 0.24
vignette 0.64
```

Strong:

```swift
rgbShift 0.0048
lensSoftness 0.38
vignette 0.82
```

### Glow

現状の `Default / Strong` はまだ強弱として意味が通る。対象はbloom / halation / diffusion。

Defaultはかなり見える設定、Strongは強い発光・拡散設定。

### Grain

ユーザー指摘により、Defaultだけ小さくした。

現在の未コミット差分:

```swift
// Default
"grainIntensity": max(base.grainIntensity, 0.055)
"grainSize": max(base.grainSize, 0.48)
"grainRadialMix": 1.0

// Strong
"grainIntensity": max(base.grainIntensity, 0.10)
"grainSize": max(base.grainSize, 0.94)
"grainRadialMix": 1.0
```

理由:
- `grainIntensityMax` は `0.1`。
- 以前はDefault `0.095` / Strong `0.10` で、表示上も効果上も近すぎた。
- 現在はDefaultとStrongの差が明確。

## UI構造の重要点

`FilmtoneAdvancedParamGroupSection` は現在、全グループ共通で以下を受け取る。

```swift
selection
noneLabel
defaultLabel
strongLabel
customLabel
onNone
onDefault
onStrong
```

このままだと全グループで `None / Default / Strong` 表示になる。

Process/Toneだけ意味名にするなら、設計案は2つある。

### 案A: グループごとにボタンラベルだけ差し替える

最小変更。`FilmtoneAdvancedParamGroup` に以下のようなラベル情報を持たせる。

```swift
let noneLabelOverride: String?
let defaultLabelOverride: String?
let strongLabelOverride: String?
```

またはより整理して:

```swift
let presetLabels: FilmtoneAdvancedGroupPresetLabels
```

Process:

```swift
None / Print / Push
```

Tone:

```swift
None / Vivid / Punch
```

Optics / Glow / Grain:

```swift
None / Default / Strong
```

メリット:
- 保存schema変更なし
- selection enum変更なし
- 既存テスト影響が小さい
- 今のUXを壊しにくい

デメリット:
- enum名は `defaultPreset / strongPreset` のままで、内部名と表示名がズレる。

### 案B: グループごとにプリセット配列を持つ

より本質的。各グループにプリセット配列を持たせる。

```swift
struct FilmtoneAdvancedGroupPreset: Identifiable {
    let id: String
    let label: String
    let values: (FilmtonePhase0Params) -> [String: Double]?
}
```

`values == nil` をNoneとして扱うか、clear actionを別に持つ。

Process:

```swift
none, print, push
```

Tone:

```swift
none, vivid, punch
```

Optics:

```swift
none, default, strong
```

メリット:
- `Default/Strong` に縛られず、グループごとの意味名へ自然に拡張できる。
- 将来 `Glow: Bloom / Halation / Dream` のような方向性プリセットにも広げられる。

デメリット:
- selection判定とUIが少し大きめに変わる。
- 今回の範囲を超えて抽象化しすぎる危険がある。

今回のおすすめは案A。Process/Toneだけ名前を変えるのが目的なら、まず表示名だけをグループ別に差し替える。プロダクト品質としては「閉じた状態で意味が分かる」ことが最優先。

## 推奨するProcess/Tone名

まずは以下を推奨する。

### Process

```text
None / Print / Push
```

理由:
- `Print` はCMY + printContrast + compressionの複合効果として自然。
- `Push` はより強い現像・プリント工程の押し出し感を表せる。
- `Default / Strong` より具体的で、短くチップに収まる。

### Tone

```text
None / Vivid / Punch
```

理由:
- 現在のTone presetはcontrast/saturationを増やすだけなので、`Vivid` が実態に近い。
- `Punch` はより強いcontrast/saturation増加として自然。
- `Default / Strong` よりユーザーが結果を予測しやすい。

## 実装上の注意

- `None` の意味は全グループ共通で「対象グループのoverrideを削除」。
- `Default` 相当の内部値は、Processでは `Print`、Toneでは `Vivid` として表示する。
- `Strong` 相当の内部値は、Processでは `Push`、Toneでは `Punch` として表示する。
- `Custom · N active` は維持する。
- `FilmtonePhase0Generated.swift`、TS生成契約、export DTO、永続化schemaは変更しない。
- `Localizable.xcstrings` は必須ではない。必要な表示語は `FilmtoneStrings.swift` のSwift fallbackで足せばよい。
- ただし本格ローカライズするなら後続で `Localizable.xcstrings` に足す。
- 既存の未コミット変更を巻き込まない。特に `packages/film-lab-core/src/*` のiOS preset contract系差分は別作業の可能性が高い。

## 検証コマンド

最低限:

```bash
xcrun swiftc -parse \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift

git diff --check -- \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift
```

通常確認:

```bash
bun run --cwd apps/capacitor-film-lab-ios build
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

UI回帰を触る場合:

```bash
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination 'id=<available simulator id>' \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

## 最高精度引き継ぎ詳細プロンプト

以下を次の新規チャットにそのまま貼る。

```text
Filmtone iOS版の詳細パラメータUXを続きから改善してください。

対象リポジトリ:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`

必ず最初に読んでください:
`docs/filmtone/ios/filmtone-ios-process-tone-preset-handoff-2026-04-29-jst.md`

目的:
詳細パラメータカードは現在 `Process / Optics / Glow / Grain / Tone` に分かれ、閉じた状態で `None / Default / Strong` を選べます。ただし `Process` と `Tone` だけは `Default / Strong` という名前だと意味が伝わりません。この2グループだけ、何が起きるか分かる適切なプリセットボタン名に変えてください。

最重要方針:
- 閉じているカード状態を正とする。
- ユーザーは閉じたまま効果プリセットを選び、微調整したい時だけ開く。
- 新しい保存schema、DTO、生成契約は増やさない。
- 既存の `paramOverrides` だけを使う。
- `None` は対象グループのoverride削除。
- Process/Toneの既存defaultValues/strongValuesは基本維持し、まず表示名と意味付けを直す。
- GrainはDefaultが大きすぎたため、現状の `grainIntensity 0.055 / grainSize 0.48` を維持する。
- `FilmtonePhase0Generated.swift`、TS生成契約、export DTO、永続化schemaは触らない。
- 既存の未コミット変更を巻き込まない。特に `packages/film-lab-core/src/*` の差分は別作業の可能性が高いので、必要がなければ触らない。

推奨UI:
- Process: `None / Print / Push`
- Tone: `None / Vivid / Punch`
- Optics / Glow / Grain: `None / Default / Strong` のまま
- `Custom · N active` 表示は維持

想定実装:
`FilmtoneAdvancedParamGroup` にグループ別のpreset labelを持たせる。
最小実装なら `none/default/strong` の内部selectionは維持し、表示ラベルだけProcess/Toneで差し替える。

対象ファイル:
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
- 必要なら `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- UIテストを更新するなら `apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift`

現在の実装要点:
- `FilmtoneParamGroupPresetSelection` は `nonePreset / defaultPreset / strongPreset / custom(activeCount:)`
- `paramPresetSelection(for:defaultValues:strongValues:)` で判定
- `FilmtoneAdvancedParamGroupSection` が `noneLabel / defaultLabel / strongLabel / customLabel` を受け取り、3チップを表示
- 現状は全グループで共通の `None / Default / Strong` が表示されている

検証:
最低限以下を通してください。

`xcrun swiftc -parse apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`

`git diff --check -- apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`

可能なら以下も通してください。

`bun run --cwd apps/capacitor-film-lab-ios build`
`bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract`
`xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

作業後:
- 何を変えたか、Process/Toneの最終ボタン名、触ったファイル、検証結果を短く報告してください。
- コミットは明示的に依頼されるまでしないでください。
```
