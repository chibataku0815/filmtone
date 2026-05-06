# Filmtone iOS external SSD Files import handoff

作成日時: 2026-05-02 13:37 JST
対象repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
対象surface: `apps/capacitor-film-lab-ios/`

## 1. 現在地

- branch: `main`
- HEAD: `72c7c5e Fix iOS Files import from external storage`
- `main...origin/main`: `ahead 16`
- このhandoff時点のSSD/Files修正はcommit済み。
- 別作業と思われる未commit変更が残っている。今回のSSD/Files修正には含めていない。

未commit変更:

```text
M apps/capacitor-film-lab-ios/fastlane/metadata/en-US/description.txt
M apps/capacitor-film-lab-ios/fastlane/metadata/en-US/promotional_text.txt
M apps/capacitor-film-lab-ios/fastlane/metadata/en-US/release_notes.txt
M apps/capacitor-film-lab-ios/fastlane/metadata/ja/description.txt
M apps/capacitor-film-lab-ios/fastlane/metadata/ja/promotional_text.txt
M apps/capacitor-film-lab-ios/fastlane/metadata/ja/release_notes.txt
```

## 2. ユーザー要求と作業方針

ユーザーの元要求:

```text
ios版でssdからファイルが選択できないのですがこれはなぜですか？
本質の進行を最優先にして、外殻は最小限。
保守的な意見は優先せず、プロダクト品質を最優先。
思考すべきところは必ずsequential-thinking。
不明点は検索して調査。
```

このため、QA手順書や外殻整理より先に、iOS nativeのFiles選択経路を直接調査・修正した。

## 3. 調査した実装経路

入口:

- `FilmtoneRootView`
  - pre-load empty view: `FilmtoneEmptyView(onPickFiles: { Task { await store.pickSource(route: .files) } })`
  - source差し替えdialog: `Button(store.strings.pickFromFiles) { Task { await store.pickSource(route: .files) } }`
- `FilmtoneEmptyView`
  - Files CTA: `Button(action: onPickFiles)`
- `FilmtoneEditorStore.pickSource(route:)`
  - `facade.pickSource(route: route, protectedCacheURIs: protectedCacheURIs, onImportProgress: ...)`
- `FilmtoneEditorFacade.pickSource(route:)`
  - top presenterを解決し、`AssetPickerService.pickSource(...)` へ渡す。
- `AssetPickerService.pickSource(route: .files)`
  - `UIDocumentPickerViewController(forOpeningContentTypes: [.image, .movie, .video], asCopy: ...)`
  - delegate後に `importDocumentSource(from:)`
- `importDocumentSource(from:)`
  - security scopeを開始
  - UTType判定
  - 空き容量preflight
  - cacheへ取り込み
  - videoならmezzanine prewarm
  - depth probe
  - `SourceInfoDTO` を返す

## 4. 根本原因

修正前のFilesルートは次の状態だった。

```swift
UIDocumentPickerViewController(
    forOpeningContentTypes: [.image, .movie, .video],
    asCopy: true
)
```

その後、Filmtone側でさらに:

```swift
cacheStore.importItem(from: url, suggestedName: url.lastPathComponent, bucket: .sources)
```

つまり外部SSD上の動画を選ぶと:

1. iOS Document Pickerがアプリ側へ一時コピーする。
2. Filmtoneがその一時コピーをさらに自前cacheへコピーする。

大容量MOV/MP4やProRes系素材では、この二重コピーが容量・時間・File Provider/外部ストレージ挙動に直撃し、「SSDから選べない」「選択後に戻らない」「失敗したように見える」主因になる。

Apple Developer Documentationで確認した要点:

- `UIDocumentPickerViewController` はopen/copyのモードを持つ。
- `asCopy` はdocument pickerが選択ドキュメントをコピーするかどうかを示す。
- 外部ドキュメントをopenする場合はsecurity-scoped URLとして扱う。
- 外部ドキュメントの読み書きはFile Coordinatorの使用が推奨されている。

参照:

- https://developer.apple.com/documentation/UIKit/UIDocumentPickerViewController
- https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/init%28foropeningcontenttypes%3Aascopy%3A%29
- https://developer.apple.com/documentation/uikit/uidocumentpickerdelegate/documentpicker%28_%3Adidpickdocumentsat%3A%29

## 5. 実施済み修正

commit:

```text
72c7c5e Fix iOS Files import from external storage
```

変更ファイル:

```text
apps/capacitor-film-lab-ios/ios/App/App/AssetPickerService.swift
apps/capacitor-film-lab-ios/ios/App/App/CacheStore.swift
```

変更内容:

1. Files source pickerをcopy modeからopen modeへ変更。

```swift
let picker = UIDocumentPickerViewController(
    forOpeningContentTypes: [.image, .movie, .video],
    asCopy: false
)
```

2. Files経由の外部URL取り込みだけ、`CacheStore.importExternalItem(...)` を使うよう変更。

```swift
let importedURL = try cacheStore.importExternalItem(
    from: url,
    suggestedName: url.lastPathComponent,
    bucket: .sources
)
```

3. `CacheStore.importExternalItem(...)` を追加。

外部URLを `NSFileCoordinator` で読み取りcoordinationし、Filmtone cacheへ1回だけコピーする。

```swift
let coordinator = NSFileCoordinator(filePresenter: nil)
var coordinationError: NSError?
var copyError: Error?
coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { readableURL in
    do {
        try fileManager.copyItem(at: readableURL, to: destinationURL)
    } catch {
        copyError = error
    }
}
```

設計意図:

- Filmtoneのexport/preview pipelineは、最終的にアプリ管理cache内の安定URLを前提にしている。
- そのため外部SSDのファイルを永続参照するのではなく、選択直後にFilmtone cacheへ1回だけ取り込む。
- `asCopy: false` によりDocument Picker側の先行コピーを避ける。
- security-scoped URLは既存どおり `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` で囲む。
- 外部documentの読み取りはFile Coordinatorで包む。

## 6. 検証済み

実行済み:

```bash
git diff --check
bun run verify:ios
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

結果:

- `git diff --check`: OK
- `bun run verify:ios`: OK
  - generated Swift contract drift check OK
  - web build OK
  - `cap sync ios` OK
  - phase0 contract OK
  - motion blur math OK
  - cube parser OK
  - cache store test OK
  - source color classifier / normalizer / HDR policy OK
  - ray-angle optics OK
  - source profile math OK
  - sidecar builder OK
- `xcodebuild ... CODE_SIGNING_ALLOWED=NO`: `** BUILD SUCCEEDED **`

補足:

- xcodebuild中に接続中の実機がpasscode lockedという `DTDKRemoteDeviceConnection` 警告が出たが、指定destinationは `generic/platform=iOS Simulator` であり、build自体は成功した。
- 実機 + 外部SSDのUI操作はこのチャットでは未実施。

## 7. 残タスク

最優先:

1. 実機で外部SSDを接続し、Files CTAから素材を選べるか確認する。
2. 大容量MOV/MP4、可能ならProResサイズの素材で確認する。
3. 選択後の流れを確認する。
   - Files pickerから戻る
   - import progress表示
   - probe完了
   - preview表示
   - export開始
   - export完了
4. SSD由来素材で失敗する場合、次のどこで止まるかを切り分ける。
   - Document Picker上でファイルがグレーアウトする: UTType/拡張子問題
   - pickerから戻らない: File Provider/外部ストレージコピーまたはopen問題
   - 戻るがFilmtone error: security scope / File Coordinator / copy /容量preflight
   - import後にprobe失敗: codec/container/AVURLAsset処理
   - preview/export失敗: renderer/export pipeline側

次点:

5. 実機でまだ詰まる場合、Files import pathに最小限のdiagnostic logを追加する。
   - selected URL pathExtension
   - `resourceValues(.contentTypeKey, .fileSizeKey, .totalFileAllocatedSizeKey)`
   - `startAccessingSecurityScopedResource()` の戻り値
   - preflight required/available bytes
   - File Coordinator error / copy error domain+code
6. エラー文がユーザーに十分伝わらない場合、既存toast/error surfaceに乗せて、外部SSD/容量/非対応形式の区別を出す。
7. `.braw` などFilmtoneが処理対象にしていないカメラRAW系containerは、今回の修正後も対象外。対応するなら別プロダクト判断。

外殻として後回し:

- formal QA doc作成
- snapshot suite拡張
- App Store metadata調整
- release/version claim更新

## 8. 触らない/注意すること

- 残っているfastlane metadata 6ファイルは今回のSSD修正とは別作業。勝手にrevertしない。
- `packages/film-lab-renderer/dist/` と `packages/film-lab-smart-look/dist/` は生成noiseとして消さない。
- iOS generated Swift (`FilmtonePhase0Generated.swift`) は手編集しない。
- release/version/App Store状態を言う必要が出たら、必ずtruth scriptsを実行する。

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

- commit/push/submodule bumpはユーザーが明示した時だけ行う。

## 9. 次チャット向け最高精度プロンプト

次チャットには以下を貼る。

```text
Filmtone iOSの外部SSD Files import修正の続きです。

repo:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

まず必ず以下を読んでください:
1. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/AGENTS.md
2. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios/CLAUDE.md
3. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/2026-05-02-ios-external-ssd-files-import-handoff-jst.md

現在地:
- branchはmain
- SSD/Files修正commit済み:
  72c7c5e Fix iOS Files import from external storage
- mainはorigin/mainよりahead 16
- 未commitのfastlane metadata 6ファイルが残っていますが、今回のSSD修正とは別作業です。勝手にrevertしないでください。

実施済み修正:
- AssetPickerServiceのFiles source pickerを `asCopy: true` から `asCopy: false` に変更。
- Files経由の外部URL取り込みは `CacheStore.importExternalItem(...)` を使うように変更。
- `importExternalItem(...)` は `NSFileCoordinator` で外部URLを読み、Filmtone cacheへ1回だけコピーします。
- 目的は、外部SSD上の大容量動画でDocument Picker側コピー + Filmtone cacheコピーの二重コピーを避けることです。

検証済み:
- `git diff --check`
- `bun run verify:ios`
- `xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO`
すべて成功済みです。

次にやること:
1. 実機に外部SSDを接続し、Filmtone iOSのFiles CTAからMOV/MP4素材を選択できるか確認してください。
2. 可能なら大容量/ProRes相当の素材で、選択 -> import progress -> probe -> preview -> export完了まで確認してください。
3. まだ失敗する場合、どこで止まるかを切り分けてください:
   - Document Picker上でグレーアウト: UTType/拡張子問題
   - pickerから戻らない: File Provider/外部ストレージopen問題
   - 戻るがFilmtone error: security scope / File Coordinator / copy /容量preflight
   - import後probe失敗: codec/container/AVURLAsset
   - preview/export失敗: renderer/export pipeline
4. 必要な場合だけ、Files import pathに最小限のdiagnostic logを追加してください。外殻QAやリリース作業より、実機での素材選択/読み込み/書き出し品質を優先してください。

作業方針:
- 本質の進行を最優先。外殻は最小限。
- 保守的な一般論よりプロダクト品質を優先。
- 思考すべき判断ではsequential-thinkingを使う。
- 不明点はローカルsource、必要ならweb searchで確認してから断言する。
- `bun` を使う。npm/yarn/pnpm lockfile churnは起こさない。
- ユーザー未承認のpush/submodule bumpはしない。
```
