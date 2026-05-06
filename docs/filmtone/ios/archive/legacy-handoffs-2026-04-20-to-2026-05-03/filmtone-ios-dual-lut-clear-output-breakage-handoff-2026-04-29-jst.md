# Filmtone iOS dual LUT / clear後の出力破綻 調査ハンドオフ

作成日: 2026-04-29 JST
対象リポジトリ: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
主対象: `apps/capacitor-film-lab-ios`

## 目的

次チャットでは、Filmtone iOSで `.cube` LUTを一度読み込んだ後、`Clear` または `Auto` に戻しても、出力動画の絵が破綻する問題を調査する。

ユーザー観測:

- LUTを一度読み込む。
- その後、LUTをクリアする、またはカメラプロファイルを `Auto` に戻す。
- それでも出力動画の見た目が破綻する。
- LUTが残っているのか、別の状態が残っているのかは未確定。

重要:

- これは「dual LUT導線を作る」作業の直後に見つかった疑いがある。
- ただし、破綻原因が今回追加したUI導線だけとは限らない。
- 出力パイプライン、永続化、プレビュー/書き出しリクエスト、legacy `lut` fallback、Auto input transformのいずれかで状態が残っている可能性がある。

## これまでの大きなプロダクト判断

Filmtone iOSは「多数の映画風プリセット」ではなく、次の小さく強い編集体験へ寄せる方針。

- `Source Profile`: Auto / Apple Log / Rec.709 / custom input LUT
- `Look`: Filmtone look / custom creative LUT / Off
- `Filter`: Natural / Mist / Bloom / Halation / Print など
- `Strength`: 原則1本、必要なFilterだけ最大2から3ノブ

重要な思想:

- 2種LUTは本質的な差分。
- `inputLut` はsource-specific。素材変更時に消す。
- `creativeLut` はlook-specific。素材変更後も保持する。
- ハレーションは破綻しやすいため、iOSプリセット内の `halationIntensity` は全て0にする。
- ハレーションはプリセット既定要素ではなく、明示選択Filter側へ分離する。
- `Advanced Params` は完全削除しない。触りたい人には残す。
- ただし通常導線の外殻UI再設計は最小限にし、プロダクトの核を優先する。

## 直近の経緯

### 1. Advanced Params周辺

一度、通常UIから `Advanced Params` を外す方向で進めたが、ユーザーから「詳細パラメーター変更機能は行いたい人には残しておくべき」と明確に差し戻しが入った。

現在の前提:

- 詳細パラメータ機能は残す。
- レイアウト的な大変更は避ける。
- 外殻UIより、本質の安定と品質を優先する。

### 2. 階調ボタン再設計

`None / 階調 / Push` は意味が崩れているため廃止する方針になった。

実装済みの方向:

- Advanced Paramsの `階調` グループは以下の4レシピに固定。
  - `標準`
  - `爽やか`
  - `夕景`
  - `深み`
- `Push`, `Print`, `None` のような実装由来・現像用語はこのグループから外す。
- 最下部の別 `階調` グループは出さない。
- 手動スライダーは残す。
- レシピ選択後に手動変更されたら表示状態は `カスタム` になる。

関連ファイル:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift`

### 3. iOSプリセットとハレーション

プリセット内のハレーションがルック破綻を呼びやすいことが分かったため、iOSプリセットでは `halationIntensity = 0` を明示する方針。

関連契約:

- iOS preset contractで全プリセットの `halationIntensity === 0` を確認する。
- この契約はdual LUT作業では触っていない。

関連ファイル:

- `packages/film-lab-core/src/ios-preset-overrides.ts`
- `packages/film-lab-core/src/ios-phase0.test.ts`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift`

### 4. dual LUT導線

ユーザー要望:

```text
2種LUT適応（←現在一種しか適応できない）
```

解釈:

- コア/書き出しはすでに `inputLut` と `creativeLut` を持っている。
- しかしiOS UIでは `.cube` を1種類しか選べなかった。
- iOS編集画面で `inputLut` と `creativeLut` を別々に選べるようにする。

実装方針:

- 既存レイアウトを大きく変えない。
- 既存のカメラ/LUTカードを2行化する。
  - 上段: `Camera` / Source側 / `inputLut`
  - 下段: `Look` / creative側 / `creativeLut`
- 書き出し順やレンダリングパイプラインは触らない。

実装済み:

- `FilmtoneEditorFacade.pickCubeLut()` を追加。
- `FilmtoneEditorStore.importCreativeLut()` / `clearCreativeLut()` を追加。
- `FilmtoneEditorStore.lookProfileLabel` を追加。
- `FilmtoneRootView.cameraProfileCard` を2行表示へ変更。
- `Localizable.xcstrings` と `FilmtoneStrings.swift` にLook用文言を追加。
- UIテスト `testCameraProfileShowsInputAndCreativeLutControls` を追加。

関連ファイル:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorFacade.swift`
  - `pickCubeLut()`
  - `pickInputLut()` は `pickCubeLut()` のwrapper
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
  - `lookProfileLabel`
  - `importInputLut()`
  - `importCreativeLut()`
  - `clearInputLut()`
  - `clearCreativeLut()`
  - `applyProbe(source:probe:)`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift`
  - `cameraProfileCard`
  - `lutProfileRow`
  - accessibility ids:
    - `filmtone.lut.input.menu`
    - `filmtone.lut.creative.menu`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings`
- `apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift`

## 現在分かっているdual LUTの実装事実

### Core schema / bridge

`packages/film-lab-core/src/phase0-schema.ts`

- `inputLut`
- `creativeLut`
- legacy `lut` は `creativeLut` へ移行される。

`packages/film-lab-core/src/native-bridge.ts`

- export payloadへ `inputLut` と `creativeLut` を別々に渡す。

テスト:

- `packages/film-lab-core/src/ios-phase0.test.ts`
  - input only
  - creative only
  - both
  - both null
- `packages/film-lab-core/src/native-bridge.test.ts`
  - `maps input and creative LUT slots independently`

### Swift model

`apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift`

- `FilmtoneProjectState` は `inputLut` と `creativeLut` を持つ。
- decoding時、legacy `lut` は `creativeLut` に移行される。
- `buildExportRequest` は `transportLut(project.inputLut)` と `transportLut(project.creativeLut)` を渡す。

重要箇所:

- `inputLut` / `creativeLut` fields: around lines 301-302
- decode: around lines 370-372
- encode: around lines 386-387
- export request mapping: around lines 614-615

### Swift export DTO

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`

- `Phase0ExportRequestDTO` は `lut`, `inputLut`, `creativeLut` を持つ。
- `lut` はlegacy creative互換用。

重要箇所:

- `inputLut`: around line 349
- `creativeLut`: around line 350

### Export session

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`

初期化:

- `preparedInputLut = makePreparedLut(from: request.inputLut)`
- `preparedCreativeLut = makePreparedLut(from: request.creativeLut ?? request.lut fallback)`

重要箇所:

- `preparedInputLut`: around line 15
- `preparedCreativeLut`: around line 16
- initialization: around lines 92-97

現在の書き出し順:

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

重要箇所:

- `applyInputLutStage`: around line 1137
- `applyCreativeLutStage`: around line 1144
- input guard: around lines 1179-1183
- creative guard: around lines 1468-1472

## 今回の新しい問題

ユーザーが報告している問題:

```text
一度LUTを読み込んだ後にクリアしたりオートに変更しても、
LUTが残ってなのかなんなのか出力動画の絵が破綻します
```

この報告から分かること:

- 破綻は「出力動画」で確認されている。
- プレビューでも破綻しているかは未確認。
- `inputLut` の話か `creativeLut` の話かは未確認。
- `Clear` と `Auto` のどちらでも起きる可能性がある。
- 「LUTが残っている」かどうかは仮説。実際にはAuto input transform、legacy field、cached request、prepared LUT、video preview sessionなど別要因の可能性がある。

## 最初に疑うべき仮説

### H1. Store上はnilだが、export requestにLUTが残っている

確認方法:

- `clearInputLut()` 後の `project.inputLut == nil` を確認。
- `clearCreativeLut()` 後の `project.creativeLut == nil` を確認。
- `FilmtonePhase0Math.buildExportRequest(...)` の直後に:
  - `request.inputLut == nil`
  - `request.creativeLut == nil`
  - `request.lut == nil` またはlegacy fallbackが意図せず入っていない
  を確認。

関連ファイル:

- `FilmtoneEditorStore.swift`
- `FilmtonePhase0Math.swift`
- `FilmtoneMediaTypes.swift`

### H2. `request.lut` legacy fieldが残ってcreative LUTとして再適用されている

`FilmtoneExportSession` は:

```swift
let legacyCreativeLut = request.creativeLut ?? request.lut.map { ... }
```

つまり `creativeLut` がnilでも、legacy `lut` が残っていれば creative LUTとして適用される。

確認方法:

- clear後のexport request JSON/DTOで `lut` が残っていないか見る。
- `FilmtonePhase0Math.buildExportRequest` がlegacy `lut` をどこで作るか調査する。
- Core/native bridge側でlegacy `lut` をまだ詰めていないか確認する。

関連ファイル:

- `FilmtoneExportSession.swift`
- `FilmtonePhase0Math.swift`
- `packages/film-lab-core/src/native-bridge.ts`
- `packages/film-lab-core/src/phase0-schema.ts`

### H3. Preview/export sessionが古いprepared LUTを保持している

`FilmtoneExportSession` は初期化時に `preparedInputLut` / `preparedCreativeLut` を作る。既存sessionを再利用している場合、requestがnilになっても古いprepared LUTが残る可能性がある。

確認方法:

- export時に毎回新しい `FilmtoneExportSession` が作られているか確認。
- video preview sessionが古いrequestやcompositionを保持していないか確認。
- `clearInputLut()` / `clearCreativeLut()` 後に `videoPreviewSession` などを破棄すべきか確認。

関連ファイル候補:

- `FilmtoneEditorStore.swift`
- `FilmtoneMediaRuntime` 周辺
- `FilmtoneExportSession.swift`
- preview composition作成経路

### H4. `clearInputLut()` 後にAuto input transformが効き、LUT残りに見えている

`Auto` は「無処理」ではない。Apple Logなどでは自動input transformが入る。

確認方法:

- 問題素材のprobe:
  - Apple Log
  - Apple Log 2
  - Rec.709
  - HDR/HLG/PQ
  を確認。
- clear後に `request.inputLut == nil` でも、Auto transformが別stageとして適用されていないか確認。
- Rec.709素材で同じ破綻が起きるか比較。

関連ファイル:

- `MezzanineColorProbe.swift`
- `SourceColorClassifier.swift`
- `FilmtoneExportSession.swift`
- `FilmtonePhase0Math.swift`

### H5. Persisted projectに古いLUTが残る、またはdecode migrationで復活する

`FilmtoneProjectState` はlegacy `lut` を `creativeLut` に移行する。保存済みJSONにlegacy `lut` が残っている場合、clear後に再起動・再読込で復活する可能性がある。

確認方法:

- `persist()` 後の保存先JSONを確認。
- clear前後のJSON差分を見る。
- `inputLut`, `creativeLut`, `lut` の3つを確認。
- `clearCreativeLut()` がlegacy `lut` を消す必要があるか検討する。ただし現在Swift model上にはlegacy `lut` propertyはない可能性が高い。

関連ファイル:

- `FilmtoneEditorStore.swift`
- project persistence周辺
- `FilmtonePhase0Math.swift`

### H6. LUT texture / CIColorCube cacheがnil時に前回値を再利用している

Core ImageやMetal/CI filterの再利用がある場合、input imageやfilter parameterがnilでも古いcube dataが残る可能性。

確認方法:

- `applyLut` 実装を確認。
- nilなら `applyInputLutStage` / `applyCreativeLutStage` は元画像をそのまま返すはず。
- filter objectを再利用していないか確認。
- `preparedInputLut` / `preparedCreativeLut` がnilの時にログを出す。

関連ファイル:

- `FilmtoneExportSession.swift`

## 次チャットの最小調査手順

1. `git status --short --branch` を確認する。
2. このドキュメントを読む。
3. 以下の対象だけを読む。
   - `FilmtoneEditorStore.swift`
   - `FilmtonePhase0Math.swift`
   - `FilmtoneExportSession.swift`
   - `FilmtoneMediaTypes.swift`
   - 必要なら `FilmtoneMediaRuntime` / preview session周辺
4. まずログまたはテストで「clear後のexport requestにLUTが残るか」を確定する。
5. `inputLut`, `creativeLut`, legacy `lut`, Auto transformを別々に切り分ける。
6. 原因が分かったら、最小パッチで直す。
7. 直したら、clear後にLUTなし出力と同じになることをテストする。

## 追加すべきテスト候補

### Store / request contract

Swift側で可能なら、以下の状態遷移をテストする。

```text
1. project.inputLut にdummy LUTを入れる
2. clearInputLut()
3. buildExportRequest()
4. request.inputLut == nil
5. request.creativeLut は変わらない
6. request.lut == nil
```

```text
1. project.creativeLut にdummy LUTを入れる
2. clearCreativeLut()
3. buildExportRequest()
4. request.creativeLut == nil
5. request.inputLut は変わらない
6. request.lut == nil
```

### Source replacement contract

既存前提:

- 素材変更時に `inputLut` だけ消える。
- `creativeLut` は保持される。

検証:

```text
1. inputLut と creativeLut の両方を入れる
2. source replacementする
3. inputLut == nil
4. creativeLut != nil
```

### Export parity

最重要:

```text
no LUT baseline output
==
import LUT -> clear/Auto -> export output
```

比較方法:

- 代表フレームのpixel diff
- request DTO JSON比較
- sidecar比較
- `preparedInputLut == nil` / `preparedCreativeLut == nil` のログ確認

## 直近の検証結果

dual LUT導線実装後に通ったもの:

```bash
bun run --cwd packages/film-lab-core test
```

結果:

- 122 pass
- 0 fail

```bash
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
```

結果:

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

結果:

- BUILD SUCCEEDED

```bash
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

結果:

- TEST BUILD SUCCEEDED

専用UIテスト:

```bash
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'id=F89B3755-527E-47EF-8B50-6D1A80CEB6AC' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests/testCameraProfileShowsInputAndCreativeLutControls \
  test
```

結果:

- TEST SUCCEEDED
- `filmtone.lut.input.menu` と `filmtone.lut.creative.menu` はアクセシビリティツリー上で検出された。

注意:

- フルの `testCaptureAppStoreScreenshots` も試した。
- 1回目はdestinationに `OS=26.4` を指定して失敗。利用可能一覧では `26.4.1` だった。
- device id指定で再実行したところ、追加したdual LUT menu検証は通過した。
- その後、既存の `sourceLoad` banner label検証で失敗した。
- これは今回のdual LUTメニュー追加とは別の既存UIテスト不安定箇所として扱う。

## 現在のdirty worktree注意

このハンドオフ作成時点で、作業ツリーには多数の未コミット変更がある。

重要:

- 次チャットは絶対に無関係な差分をrevertしない。
- Filmtone iOS関連でも、ハレーションゼロ、階調ボタン、dual LUT導線の差分が混在している。
- `apps/web/src/features/journal/` などFilmtoneと無関係そうな未追跡/変更もある。

直近観測の主なdirty files:

```text
M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorFacade.swift
M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
M apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift
M apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift
M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift
M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift
M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift
M apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings
M apps/capacitor-film-lab-ios/ios/App/App/MezzanineColorProbe.swift
M apps/capacitor-film-lab-ios/ios/App/App/SourceColorClassifier.swift
M apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift
M apps/capacitor-film-lab-ios/scripts/fixtures/phase0-contract/*.json
M apps/capacitor-film-lab-ios/scripts/swift/*.swift
M packages/film-lab-core/src/*.ts
M packages/film-lab-core/dist/*
?? apps/web/src/features/journal/
?? apps/web/src/shared/data/journal.ts
```

## 次チャットで避けること

- いきなり大規模UI再設計しない。
- 書き出し順を変更しない。
- ハレーション契約を触らない。
- `creativeLut` を素材変更時に消す方向へ変えない。
- 原因未確定のまま「clear時に全部reset」する雑な修正をしない。
- `git reset --hard` や `git checkout --` で未コミット差分を消さない。
- 古いhandoffや古いrelease noteから現状を推測しない。

## 次チャットで最初に見るべきコマンド

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
git status --short --branch
rg -n "inputLut|creativeLut|request\\.lut|preparedInputLut|preparedCreativeLut|clearInputLut|clearCreativeLut|buildExportRequest|applyInputLutStage|applyCreativeLutStage" \
  apps/capacitor-film-lab-ios/ios/App/App \
  packages/film-lab-core/src
```

対象ファイルを絞って読む:

```bash
sed -n '760,845p' apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
sed -n '930,985p' apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
sed -n '580,630p' apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift
sed -n '80,105p' apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
sed -n '1128,1150p' apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
sed -n '1175,1188p' apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
sed -n '1464,1476p' apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
```

## 最高精度を出すための引き継ぎ詳細プロンプト

```text
あなたはFilmtone iOSの出力破綻バグを調査・修正するエンジニアです。

リポジトリ:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

必ず最初に読んでください:
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-dual-lut-clear-output-breakage-handoff-2026-04-29-jst.md

ユーザー観測:
Filmtone iOSで一度.cube LUTを読み込んだ後、ClearまたはAutoに戻しても、出力動画の絵が破綻する。
LUTが残っているのか、別の状態が残っているのかは未確定。

重要な前提:
- dual LUTはSource Profile用のinputLutとLook用のcreativeLutを別々に扱う。
- inputLutはsource-specific。素材変更時に消す。
- creativeLutはlook-specific。素材変更後も保持する。
- iOSプリセットのhalationIntensity = 0契約は維持する。触らない。
- Advanced Paramsは残す。
- レイアウトの大変更はしない。
- 書き出し順は維持する: input LUT -> grade/optics -> creative LUT -> print。
- 未コミット差分が多いので、無関係な変更は絶対にrevertしない。

まず確認すること:
1. git status --short --branch
2. clearInputLut() / clearCreativeLut() 後に project.inputLut / project.creativeLut がnilになるか
3. clear後の FilmtonePhase0Math.buildExportRequest(...) が request.inputLut / request.creativeLut / legacy request.lut をnilにしているか
4. FilmtoneExportSession初期化時に preparedInputLut / preparedCreativeLut がnilになるか
5. request.creativeLutがnilでも legacy request.lut fallbackでLUTが復活していないか
6. export時に古いpreview/export sessionやprepared LUTが再利用されていないか
7. Auto input transformがLUT残りに見えているだけではないか。Rec.709素材とApple Log素材で分ける。

調査方針:
- まずログまたは小さいテストで、Clear/Auto後のexport request DTOを確定する。
- その後、export sessionのprepared LUT状態を確定する。
- さらに必要なら実際の出力フレームを no-LUT baseline と import->clear 後で比較する。
- 原因が分かるまでUI再設計や大規模refactorをしない。

期待する修正:
- Clear/Auto後の出力が、LUTを一度も読み込んでいない状態と一致する。
- inputLut clearはcreativeLutを消さない。
- creativeLut clearはinputLutを消さない。
- source replacementではinputLutだけ消え、creativeLutは保持される。
- legacy lut fallbackが必要なら互換性を壊さず、clear後に復活しないようにする。

検証:
- bun run --cwd packages/film-lab-core test
- bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
- xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
- 必要なら専用UIテスト:
  xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -sdk iphonesimulator -destination 'id=F89B3755-527E-47EF-8B50-6D1A80CEB6AC' CODE_SIGNING_ALLOWED=NO -only-testing:FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests/testCameraProfileShowsInputAndCreativeLutControls test

出力してほしいもの:
- 原因の確定説明
- 変更ファイル一覧
- なぜその修正でClear/Auto後にLUTが残らないと言えるか
- 実行した検証コマンドと結果
- 残るリスクがあれば明記
```
