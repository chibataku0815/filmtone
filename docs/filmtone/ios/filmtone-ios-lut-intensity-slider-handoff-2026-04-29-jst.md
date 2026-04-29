# Filmtone iOS LUT intensity slider handoff

作成日: 2026-04-29 JST  
対象リポジトリ: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`  
主対象: `apps/capacitor-film-lab-ios`  
次の目的: Filmtone iOSで、読み込んだ `.cube` LUT の適用量をスライダーで調整できるようにする。

## 現在の真実

2026-04-29 JST時点のiOS truth:

- 作業ブランチ: `main`
- HEAD: `90de10b7 fix(filmtone-ios): stabilize LUT clear state`
- `origin/main` から2コミットahead:
  - `90de10b7 fix(filmtone-ios): stabilize LUT clear state`
  - `761c8835 feat(filmtone-ios): refine mobile look pipeline`
- App Store公開版: `1.1`
- ローカルXcode `MARKETING_VERSION`: `1.1`, `1.2`
- ローカルXcode `CURRENT_PROJECT_VERSION`: `1`, `2`
- iOS deployment target: `17.0`
- 現在のdirty iOS working treeはなし。
- Web/Journal系の未コミット変更は残っている。次チャットでは触らない。

確認コマンド:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

重要:

- Public App Store stateとlocal candidate stateを混同しない。
- `docs/filmtone/ios/` には古いハンドオフもある。現状確認は必ずtruth scriptとHEADから行う。
- 別worktree `feature/filmtone-ios-code-residual` はmainに対して大量差分を持つ。次のLUT slider作業ではマージ対象にしない。

## ここまでの経緯

ユーザー要望:

```text
2種LUT適応（現在一種しか適応できない）
```

この要望を受け、iOS側はLUTを2系統に分ける方向で進んだ。

- `inputLut`: Source Profile / Camera側。Apple Logや外部camera transformなどsource-specificなLUT。
- `creativeLut`: Look側。Filmtone lookの上に載せるcreative/stylistic LUT。

プロダクト判断:

- `inputLut` は素材依存なので、素材変更時に消す。
- `creativeLut` はlook依存なので、素材変更後も保持する。
- 書き出し順は維持する:

```text
input LUT
-> base grade
-> tone compression
-> edge optics
-> glow family
-> vignette
-> grain
-> creative LUT
-> print
```

その後、ユーザー観測として次の問題が出た。

```text
一度LUTを読み込んだ後にクリアしたりオートに変更しても、
LUTが残ってなのかなんなのか出力動画の絵が破綻します
```

この問題に対して、直近コミット `90de10b7` で以下を実施済み:

- `FilmtoneEditorStore` のLUT変更経路を `applyLutMutation` に集約。
- LUT変更時に古いpreview session、compare frame、export result、export progressを破棄。
- `inputLut` clearは`creativeLut`を消さない。
- `creativeLut` clearは`inputLut`を消さない。
- Swift contractでclear後にlegacy `lut` が復活しないことを検証。
- core native bridge testでcurrent requestがlegacy `lut` fieldを出さないことを検証。

直近検証結果:

```bash
bun run --cwd packages/film-lab-core test
```

- `123 pass`
- `0 fail`

```bash
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
```

- Phase0 contract fixtures verified
- cube parser tests passed
- source-color-classifier tests passed
- ray-angle optics tests passed
- sidecar builder tests passed

```bash
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- `BUILD SUCCEEDED`
- 既存警告としてCapacitor/Cordova deprecationとbundle version mismatch warningあり。

## 次に作るもの

次チャットの目的は、読み込んだLUTの適用量をスライダーで調整できるようにすること。

想定する完成状態:

- Source側 custom input LUTに適用量スライダーを出す。
- Look側 custom creative LUTに適用量スライダーを出す。
- スライダー範囲は `0...1`、表示は `0%...100%`。
- LUT import直後の既定値は現在と同じ `100%`。
- `0%` は「LUTは選択されたままだが見た目への寄与はゼロ」。
- `Clear` はLUTそのものを消す。
- `Auto` はcustom `inputLut` を消し、素材probeに応じたautomatic input transformへ戻す。
- スライダーはcustom LUTが存在する時だけ表示する。
- Auto input transform自体の強度はこの作業では調整対象にしない。

UI方針:

- 既存の `cameraProfileCard` に最小限で追加する。
- 大きなUI再設計はしない。
- Advanced Paramsには入れない。LUT量は読み込んだLUTの直下で触れるべき核機能。
- 既存の2行構造を維持:
  - 上段: Camera / Source側 / `inputLut`
  - 下段: Look / creative側 / `creativeLut`
- 各行の下または行内に、custom LUTがある場合だけ小さなSlider + percent labelを追加する。
- `inputLut` と `creativeLut` のsliderは独立。

アクセシビリティID候補:

- `filmtone.lut.input.intensity.slider`
- `filmtone.lut.creative.intensity.slider`
- `filmtone.lut.input.intensity.value`
- `filmtone.lut.creative.intensity.value`

文言候補:

- English:
  - `Input LUT Amount`
  - `Look LUT Amount`
- Japanese:
  - `入力LUTの量`
  - `ルックLUTの量`

既存文言の追加場所:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings`

## 実装上の重要事実

強度のデータモデルとレンダリングはすでに存在する。

### DTO / project state

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`

```swift
struct ParsedCubeLutDTO: Codable {
    let title: String
    let size: Int
    let data: [Double]
    let intensity: Double
}

struct SerializableLutDTO: Codable {
    let size: Int
    let data: [Double]
    let intensity: Double
}
```

`apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift`

- `FilmtoneProjectState` は `inputLut: ParsedCubeLutDTO?` と `creativeLut: ParsedCubeLutDTO?` を持つ。
- legacy `lut` はdecode時に `creativeLut` へ移行される。
- encode時はlegacy `lut` を出さない。
- `buildExportRequest` は `lut: nil` を明示し、`inputLut` / `creativeLut` を別々にtransportする。
- `transportLut` は `intensity` を保持する。

### Import default

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCubeParser.swift`

- `.cube` import時、`ParsedCubeLutDTO.intensity` は `1` で作られる。
- つまりimport直後は100%。

### Export rendering

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`

- `makePreparedLut(from:)` は `SerializableLutDTO.intensity` を `PreparedLut` に渡す。
- `applyLut(_:, to:)` は `intensity >= 0.999` ならLUT結果をそのまま返す。
- `intensity < 0.999` なら `CIColorMatrix` + `CISourceOverCompositing` で元画像とLUT結果をblendする。
- したがって、Slider実装に必要なのは主にUI + Store setter + tests。

### Store state mutation

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`

直近コミットで追加済み:

```swift
private func applyLutMutation(_ mutate: (inout FilmtoneProjectState) -> Void) {
    mutate(&project)
    project.updatedAt = FilmtonePhase0Math.isoTimestamp()
    invalidateRenderedOutputState()
    persist()
    schedulePreviewRender()
}
```

次チャットではこのhelperを使う。

追加すべきStore API候補:

```swift
func setInputLutIntensity(_ intensity: Double) {
    applyLutMutation {
        guard var lut = $0.inputLut else { return }
        lut.intensity = FilmtonePhase0Math.clampLutIntensity(intensity)
        $0.inputLut = lut
    }
}

func setCreativeLutIntensity(_ intensity: Double) {
    applyLutMutation {
        guard var lut = $0.creativeLut else { return }
        lut.intensity = FilmtonePhase0Math.clampLutIntensity(intensity)
        $0.creativeLut = lut
    }
}
```

注意:

- `ParsedCubeLutDTO` のpropertyが `let` なので、setter内で `var lut = ...` してから代入する。
- `clampLutIntensity` は `0...1` にする。既存の汎用clamp helperがあれば使う。なければ `FilmtoneEditorStore` private helperでもよいが、contractで使いやすいのは `FilmtonePhase0Math` 側。
- slider drag中に頻繁に `persist()` とpreview render scheduleが走る。既存 `schedulePreviewRender()` はdebounce/cancelを持つので、まずはlive更新を優先してよい。
- もしドラッグ中の重さが出るなら、次段で `onEditingChanged` によるcommit-only previewを検討する。最初から保守的にしすぎない。

### UI entry point

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift`

現在:

- `cameraProfileCard` がSource/Lookの2行を表示。
- `lutProfileRow(...)` がtitle/value/menuを描画。
- `inputLut` menu ID:
  - `filmtone.lut.input.menu`
- `creativeLut` menu ID:
  - `filmtone.lut.creative.menu`

次チャットの実装候補:

- `lutProfileRow` を拡張して、optional intensity controlを受け取れるようにする。
- あるいは `cameraProfileCard` 側で各 `lutProfileRow` の下に `lutIntensityControl(...)` を置く。
- 既存レイアウトを大きく変えないため、後者が安全。

例:

```swift
if let inputLut = store.project.inputLut {
    lutIntensityControl(
        title: store.strings.inputLutAmountLabel,
        value: inputLut.intensity,
        valueIdentifier: "filmtone.lut.input.intensity.value",
        sliderIdentifier: "filmtone.lut.input.intensity.slider"
    ) { next in
        store.setInputLutIntensity(next)
    }
}
```

## 触ってはいけない / 変更しない前提

- 書き出し順は変えない。
- `inputLut` と `creativeLut` の意味を入れ替えない。
- `inputLut` clear時に `creativeLut` を消さない。
- `creativeLut` clear時に `inputLut` を消さない。
- source replacement時は `inputLut` だけ消し、`creativeLut` は保持する前提を崩さない。
- legacy `lut` compatibilityはdecode/export session fallback用に残すが、current request buildでは `lut: nil` を維持する。
- Auto input transformの強度調整は今回の範囲外。
- Apple Log 2 Auto変換の精度問題は別件として扱う。
- iOSプリセット/ハレーション/Advanced Paramsの大改造はしない。
- `apps/web` / Journal / Portfolio renewal系の未コミット変更は触らない。
- `feature/filmtone-ios-code-residual` の巨大差分は取り込まない。

## Apple Log 2 Autoについての注意

`FilmtoneExportSession` は `request.inputLut == nil` の時、`request.sourceProbe?.inputTransformPolicy` からautomatic input LUTを作る。

```swift
self.preparedInputLut = Self.makePreparedLut(from: request.inputLut)
    ?? Self.makeAutomaticInputLut(for: request.sourceProbe?.inputTransformPolicy)
```

現在の実装では:

- `.appleLogToRec709` -> `makeAppleLogToRec709Lut`
- `.appleLog2ToRec709` -> `makeAppleLogToRec709Lut`

AppleのFinal Cut ProガイドではCamera LUTとして `Apple Log` と `Apple Log 2` が別々に扱われる。したがってApple Log 2 Autoの精度は今後の別リスクとして残る。

今回のslider実装では、custom `inputLut` / `creativeLut` の `intensity` だけを調整する。Auto transformはproject LUTではないため、slider対象にしない。

参考:

- https://support.apple.com/lv-lv/guide/final-cut-pro/ver24f966423/mac

## テスト計画

最低限:

```bash
bun run --cwd packages/film-lab-core test
```

```bash
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
```

```bash
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

追加したいcontract:

- Swift contract:
  - `inputLut.intensity = 0.37` が `buildExportRequest().inputLut?.intensity == 0.37` になる。
  - `creativeLut.intensity = 0.42` が `buildExportRequest().creativeLut?.intensity == 0.42` になる。
  - intensity変更後も `request.lut == nil`。
  - `inputLut` intensity変更は `creativeLut` を変えない。
  - `creativeLut` intensity変更は `inputLut` を変えない。

- Core bridge test:
  - `buildPhase0ExportRequest` が `inputLut.intensity` と `creativeLut.intensity` を別々に保持する。
  - current requestにlegacy `lut` fieldを出さない既存テストを維持する。

- UI test候補:
  - `testCameraProfileShowsInputAndCreativeLutControls` を拡張し、custom LUT fixture時にslider IDsが見えることを確認する。
  - ただしUI testは既存不安定箇所があるため、まずcontract/buildを優先。

既存の注意:

- フル `testCaptureAppStoreScreenshots` は過去にsourceLoad banner label検証で失敗したことがある。
- dual LUT menu専用テストは以前成功している。

## 現在のdirty worktree注意

このドキュメント作成前の `git status --short --branch` では、mainは `origin/main` より2コミットahead。

未コミットはWeb/Journal系のみ:

```text
 M apps/web/messages/en.json
 M apps/web/messages/ja.json
 M apps/web/src/app/[locale]/(portfolio)/journal/page.tsx
 M apps/web/src/app/sitemap.ts
?? apps/web/src/app/[locale]/(portfolio)/journal/journal-typography-wordmark-system/
?? apps/web/src/app/[locale]/(portfolio)/journal/mobile-safari-touch-controller/
?? apps/web/src/app/[locale]/(portfolio)/journal/motion-studies/
?? apps/web/src/app/[locale]/(portfolio)/journal/portfolio-renewal-2026/
?? apps/web/src/features/journal/
?? apps/web/src/shared/data/journal.ts
```

次チャットではこのWeb/Journal変更をrevertしない、stageしない、formatしない。

このハンドオフ自体を作成した後は、以下の新規ファイルがdirtyになる:

```text
docs/filmtone/ios/filmtone-ios-lut-intensity-slider-handoff-2026-04-29-jst.md
```

## 推奨実装手順

1. `check-filmtone-ios-truth.sh` と `git status --short --branch` で現状確認。
2. このドキュメントを読む。
3. `FilmtoneEditorStore.swift` に `setInputLutIntensity` / `setCreativeLutIntensity` を追加。
4. intensity clampを追加する。場所は `FilmtonePhase0Math` が望ましい。
5. `FilmtoneRootView.swift` の `cameraProfileCard` に、custom LUTがある時だけsliderを追加。
6. `FilmtoneStrings.swift` / `Localizable.xcstrings` に最小文言を追加。
7. Swift contractとcore bridge testを追加。
8. 最小検証を実行。
9. 必要ならfocused UI testを実行。

## 最高精度を出せる引き継ぎ詳細プロンプト

```text
あなたはFilmtone iOSのLUT適用量スライダーを実装するエンジニアです。

リポジトリ:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

必ず最初に実行:
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
git status --short --branch

必ず最初に読む:
docs/filmtone/ios/filmtone-ios-lut-intensity-slider-handoff-2026-04-29-jst.md

目的:
Filmtone iOSで、読み込んだ .cube LUT の適用量をスライダーで調整できるようにする。
対象は custom inputLut と custom creativeLut の2つ。

現在の重要前提:
- main HEADは 90de10b7 fix(filmtone-ios): stabilize LUT clear state の想定。
- mainはorigin/mainより2コミットaheadのローカル候補状態。
- App Store公開版は1.1、ローカルXcodeは1.1/1.2が混在。
- inputLutはSource Profile / Camera側でsource-specific。
- creativeLutはLook側でlook-specific。
- source replacement時はinputLutだけ消し、creativeLutは保持する。
- Auto input transformはcustom LUTではない。今回のslider対象にしない。
- current request buildではlegacy lutは出さない。lut: nil を維持する。
- legacy lut decode/fallback compatibilityは壊さない。
- 書き出し順は変えない。
- iOS preset/halation/Advanced Params/UI大改造には踏み込まない。
- Web/Journal系の未コミット変更は触らない。

実装方針:
1. FilmtoneEditorStore.swift に setInputLutIntensity(_:) と setCreativeLutIntensity(_:) を追加する。
2. 既存の applyLutMutation helperを必ず使う。これによりupdatedAt更新、preview/export状態破棄、persist、preview再生成が揃う。
3. intensityは0...1にclampする。可能ならFilmtonePhase0Mathに clampLutIntensity を追加する。
4. ParsedCubeLutDTOはlet propertyなので、setterでは guard var lut = project.inputLut のようにcopyして intensity を差し替え、slotへ再代入する。
5. FilmtoneRootView.swift の cameraProfileCard に、project.inputLut != nil の時だけ入力LUT量slider、project.creativeLut != nil の時だけルックLUT量sliderを表示する。
6. 既存の2行カード構造は維持する。大きな再設計やAdvanced Params移動はしない。
7. sliderは0...1、表示は0%...100%。import直後は既存通り100%。
8. accessibility identifiers:
   - filmtone.lut.input.intensity.slider
   - filmtone.lut.creative.intensity.slider
   - filmtone.lut.input.intensity.value
   - filmtone.lut.creative.intensity.value
9. FilmtoneStrings.swift / Localizable.xcstrings に最小限の英日文言を追加する。

実装上の既存事実:
- ParsedCubeLutDTO / SerializableLutDTO はすでに intensity を持つ。
- FilmtoneCubeParser はimport時 intensity: 1 を入れる。
- FilmtonePhase0Math.buildExportRequest は inputLut / creativeLut を別々にtransportし、legacy lutは nil。
- FilmtoneExportSession.makePreparedLut は intensity をPreparedLutへ渡す。
- FilmtoneExportSession.applyLut は intensity < 0.999 の時に元画像とLUT画像をblendする。
- つまりrender pipelineはすでに強度対応済み。欠けているのはUI/Store setter/contract。

追加テスト:
- Swift contract:
  - inputLut intensity変更がrequest.inputLut.intensityへ反映される。
  - creativeLut intensity変更がrequest.creativeLut.intensityへ反映される。
  - intensity変更後もrequest.lut == nil。
  - input側変更でcreative側が変わらない。
  - creative側変更でinput側が変わらない。
- Core bridge test:
  - buildPhase0ExportRequestがinput/creativeのintensityを独立保持する。
  - legacy lut fieldを出さない既存テストを維持する。
- UI testは必要ならfocused testだけ。フルscreenshot testは既存不安定箇所に注意。

検証コマンド:
bun run --cwd packages/film-lab-core test
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

最終出力に含めるもの:
- 変更ファイル一覧
- inputLut / creativeLut のsliderが独立している理由
- intensity変更後もlegacy lutが復活しない理由
- 実行した検証コマンドと結果
- Auto input transform / Apple Log 2は今回対象外として残したこと
```
