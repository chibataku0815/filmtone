# Filmtone iOS v1.2 Release to ASO Handoff

- 作成日: 2026-04-29 JST
- 目的: 次の新規チャットで、Filmtone iOS の App Store ASO 対策を高精度に開始できるよう、今回の v1.2 リリース作業の経緯、現状、前提、禁止事項、次の調査・実装プロンプトを完全に引き継ぐ。
- 対象アプリ: Filmtone iOS
- App Store ID: `6762564806`
- Bundle ID: `com.chibatakumi.film.lab.ios`
- 実アプリrepo/root: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- iOS app root: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios`
- life hub root: `/Volumes/SamsungPortableSSDX5001/documents/life`

## 結論

Filmtone iOS `1.2 (1)` は App Store Connect へアップロードされ、2026-04-29 19:03:30 JST に Fastlane で App Review 提出が成功した。

ただし、公開 App Store lookup はまだ `1.1` のまま。これは正常で、Apple Review 通過後に公開版が `1.2` へ切り替わる。次チャットでは「公開済み」と断定せず、まず App Store Connect または `scripts/check-filmtone-ios-truth.sh` で現在状態を確認すること。

今回、スクリーンショットは一時的に自動生成版へローカル差分が出たが、ユーザーが「v1.1 のスクリーンショットが正しい」と確認したため、ローカルの `fastlane/screenshots` は元の v1.1 相当の正しい状態へ戻した。最終の審査提出では `skip_screenshots: true` で実行し、スクリーンショットは再アップロードしていない。

次の主題は ASO。ユーザー認識として「今その観点がなさすぎて全く検索に引っかかってない」。現在のメタデータはプロダクト説明寄りで、検索流入・キーワード設計・競合比較・日本語/英語の検索語彙最適化がほぼ未実施。

## 絶対に守る前提

1. v1.1 のスクリーンショットが正しい。勝手に再生成しない。
2. `bun run release:screenshots` は ASO作業では実行しない。
3. App Store Connect 上のスクリーンショットを上書きしない。
4. 公開版は、少なくとも 2026-04-29 19:04 JST 時点の lookup では `1.1`。`1.2` は提出済み候補として扱う。
5. ASO作業では、現在 App Review 中の `1.2` を編集・差し戻し・再提出する必要があるかを先に確認する。レビュー中のバージョンを不用意に変更しない。
6. App Store Connect や App Store 検索順位は時間で変わる。次チャットでは必ず最新状態を検索・確認する。
7. レビュー連絡先などの個人情報は `.env.local` / Fastlane workflow 内にある。ドキュメントへ秘密情報を転記しない。

## life repo からの正しい入り方

次チャットが `/Volumes/SamsungPortableSSDX5001/documents/life` で始まる場合:

```sh
node scripts/life-route.mjs "filmtone ios app store aso"
```

AGENTS.md のルーティング上、Filmtone iOS は以下から開始する:

- `docs/guides/film-lab-current-index.md`
- `scripts/check-filmtone-ios-truth.sh`

状態確認:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/life
./scripts/check-filmtone-ios-truth.sh
```

実装・metadata編集の作業場所:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
```

## 2026-04-29 19:04 JST 時点の確認済み状態

`scripts/check-filmtone-ios-truth.sh` の結果:

- branch/head: `main @ bb1be359`
- upstream: `origin/main`
- commits ahead of upstream: `13`
- commits behind upstream: `0`
- local Xcode marketing versions: `1.2`
- local Xcode build versions: `1`
- iOS deployment target: `17.0`
- public App Store version: `1.1`
- public bundle ID: `com.chibatakumi.film.lab.ios`
- public release date: `2026-04-21T07:00:00Z`
- public current version release date: `2026-04-26T03:24:53Z`
- public URL: `https://apps.apple.com/jp/app/filmtone/id6762564806?uo=4`

Fresh archive artifacts:

- IPA: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/build/fastlane/Filmtone.ipa`
- IPA size: 約 `82M`
- dSYM zip: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/build/fastlane/Filmtone.app.dSYM.zip`
- dSYM zip size: 約 `4.7M`
- IPA SHA-256 recorded during release work: `b071585eafdabf7372176dcfa703d743a27d85139f973c44305a375cb9764d7b`
- IPA internal versions verified:
  - App: `1.2 (1)`
  - Export Activity extension: `1.2 (1)`

## 今回のリリース作業の時系列

### 1. Routing and release truth check

life repo の AGENTS.md に従い、Filmtone iOS route から開始した。

初期状態:

- 公開 App Store: `1.1`
- ローカル Xcode marketing versions: `1.1, 1.2`
- ローカル build versions: `1, 2`
- branch `main`, upstream より `13` commits ahead

`FilmtoneExportActivity` extension のバージョンが host app とズレていたため、Xcode project を修正して host app / extension を `1.2 (1)` に揃えた。

### 2. Verification before archive

主な検証:

```sh
bun run build
bun run verify:swift-contract
bun run --cwd packages/film-lab-core test
xcodebuild -workspace ios/App/App.xcworkspace -scheme App -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
git diff --check
```

結果:

- Vite build passed
- Swift contract verification passed
- `packages/film-lab-core` tests passed: `123 pass`, `0 fail`
- simulator Debug workspace build succeeded
- `git diff --check` passed

`bun run cap:sync:ios` は CocoaPods/system Ruby 権限問題で失敗したため、`bunx cap copy ios` を使用。これは成功した。

### 3. Screenshot issue and correction

`bun run release:screenshots` を実行し、UI test rail は最終的に pass した。

ただし、この自動生成 screenshot はユーザー意図と違った。ユーザー確認により、正しいのは v1.1 の既存 App Store screenshot set。

対応:

- ローカル `fastlane/screenshots` の生成差分を restore した。
- 最終提出では screenshot upload を skip した。
- 以後、ASO作業では screenshot を再生成・上書きしない。

ユーザーが App Store Connect 画面を確認し、「幸いなことにスクリーンショットは更新されていないようです」と報告した。画面上では v1.1 の意図した5枚が見えていた。

### 4. Archive export failure and Fastlane fix

`bun run release:archive` の初回は、Xcode archive 自体は成功したが IPA export で `Exit status: 64` になった。

原因:

- Fastlane 2.233.0 の gym package generator は export command に `export_xcargs` と `xcargs` の両方を追加する。
- 既存 Fastfile は同じ App Store Connect authentication args を `xcargs` と `export_xcargs` の両方に渡していた。
- その結果、`xcodebuild -exportArchive` に認証引数が二重渡しされて失敗していた。

対応:

- `fastlane/Fastfile` の archive lane から `export_xcargs: xcargs` を削除。
- `xcargs` は残した。Fastlane が export 時にも一度だけ再利用する。

注意:

- Xcode 26.4 の `xcodebuild -help` では `app-store` は deprecated で `app-store-connect` が現行名。
- ただし fastlane 2.233.0 の `gym` 側は old method names を前提に validation しているため、今回は `export_method: "app-store"` / `export_options.method: "app-store"` は変更していない。
- 手動 `xcodebuild -exportArchive` では deprecated warning は出るが export 自体は成功した。

### 5. Binary, metadata, screenshot upload attempt

`IPA_PATH=build/fastlane/Filmtone.ipa SUBMIT_FOR_REVIEW=1 AUTOMATIC_RELEASE=1 OVERWRITE_SCREENSHOTS=1 bun run release:appstore` を実行した。

結果:

- App Store Connect version `1.2` 作成/更新成功
- metadata upload 成功
- app review information upload 成功
- screenshot upload path は通ったが、ユーザー確認上 App Store Connect の見た目は既存 v1.1 screenshot のままだった
- binary upload 成功
- build processing complete
- build `1.2 (1)` selected
- precheck passed
- review submission は失敗

失敗理由:

```text
appStoreVersions ... is not in valid state.
The provided entity is missing a required attribute - You must provide a value for the attribute 'whatsNew' with this request
```

### 6. whatsNew fix and final submission

`fastlane/metadata/{ja,en-US}/release_notes.txt` は存在していたが、`release` lane が `release_notes:` を upload options に明示していなかったため、App Store Connect API 上で `whatsNew` が未設定扱いになっていた。

Fastfile 修正:

- `localized_release_note_texts`
  - deliver の `release_notes: { "ja" => "...", "en-US" => "..." }` 用
- `localized_build_release_notes`
  - TestFlight `localized_build_info` 用
- `metadata` lane と `release` lane に `release_notes: localized_release_note_texts` を追加
- `submit_review` lane を新規追加
  - 既存 build を使う
  - `skip_binary_upload: true`
  - `skip_screenshots: true`
  - `skip_metadata: false`
  - `submit_for_review: true`
  - `automatic_release` は env で制御
  - `APP_VERSION` / `BUILD_NUMBER` を env または lane option から受け取る

最終実行:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
set -a; . ./.env.local; set +a
APP_VERSION=1.2 BUILD_NUMBER=1 AUTOMATIC_RELEASE=1 ./scripts/bundle.sh exec fastlane ios submit_review
```

結果:

- `release_notes.ja` / `release_notes.en-US` が deliver summary に明示された
- `skip_binary_upload: true`
- `skip_screenshots: true`
- metadata upload success
- precheck success
- existing build-number `1` selected
- build `1.2 (1)` selected
- `Successfully submitted the app for review!`
- 完了時刻: 2026-04-29 19:03:30 JST

## 現在のローカル変更ファイル

2026-04-29 19:04 JST 時点での主な dirty files:

```text
.claude/tasks/ACTIVE-PARALLEL-TASK.md
apps/capacitor-film-lab-ios/fastlane/Fastfile
apps/capacitor-film-lab-ios/fastlane/README.md
apps/capacitor-film-lab-ios/fastlane/metadata/en-US/release_notes.txt
apps/capacitor-film-lab-ios/fastlane/metadata/ja/release_notes.txt
apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift
```

`fastlane/screenshots` に差分はない。

`fastlane/README.md` は Fastlane 実行で自動更新され、`ios submit_review` lane が追記されている。

Untracked docs observed in portfolio repo at the time:

```text
docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-motion-180-baseline-industry-handoff-2026-04-29-jst.md
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-lut-intensity-slider-handoff-2026-04-29-jst.md
docs/journal/
```

これらは今回のリリース作業とは別の既存未追跡ファイルとして扱う。

## 今回編集した metadata/release notes

Japanese release notes:

```text
v1.2 では、iPhone でのルック作りと書き出しの安定性を強化しました。Source Profile と Look の2系統で .cube LUT を扱えるようになり、それぞれの適用量を 0% から 100% まで調整できます。プレビューと書き出しの色処理をそろえ、P3/HDR 系素材で不適切な mezzanine 経路を避けるようにしました。キャッシュ管理も見直し、未保存の書き出しや作業中の素材を守りながら古い一時ファイルを整理します。プリセット一覧には inner glow、画面上部には liquid glass chrome を追加し、編集画面の質感も整えています。
```

English release notes:

```text
v1.2 strengthens the iPhone grading and export workflow. Filmtone can now handle separate .cube LUTs for Source Profile and Look, with independent 0% to 100% amount controls for each slot. Preview and export color handling are better aligned, and P3/HDR sources avoid unsafe mezzanine routes. Cache management now keeps active sources and unsaved exports protected while pruning old temporary files. The preset list gains inner glow treatment, and the editor adds liquid glass top chrome for a more polished workspace.
```

## ASOの現状課題

ユーザーの問題意識:

- 「App StoreをASO対策したい」
- 「今その観点がなさすぎて全く検索に引っかかってない」

推定される課題:

1. App name / subtitle / keywords / promotional text / description が、検索語彙から逆算されていない。
2. 日本語ASOと英語ASOのキーワード設計が分離されていない。
3. Photo & Videoカテゴリ内の競合比較が未実施。
4. 「フィルム」「動画編集」「写真加工」「LUT」「カラーグレーディング」「Log」「Cinematic」「film look」などの検索 intent に対して、どの語をどこへ入れるかの戦略がない。
5. screenshots は視覚訴求として正しいが、テキストオーバーレイのASO訴求としての役割を別途評価できていない。ただし、次の作業では勝手に変えない。
6. App Store Connect の product page optimization / custom product pages / analytics を活用する設計が未着手。
7. 現在 `1.2` が審査提出済みのため、どのmetadataが編集可能か、編集すると審査状態へどう影響するかを確認してから動く必要がある。

## ASOで最初に見るべきファイル

```text
apps/capacitor-film-lab-ios/fastlane/metadata/ja/name.txt
apps/capacitor-film-lab-ios/fastlane/metadata/ja/subtitle.txt
apps/capacitor-film-lab-ios/fastlane/metadata/ja/keywords.txt
apps/capacitor-film-lab-ios/fastlane/metadata/ja/promotional_text.txt
apps/capacitor-film-lab-ios/fastlane/metadata/ja/description.txt
apps/capacitor-film-lab-ios/fastlane/metadata/ja/release_notes.txt
apps/capacitor-film-lab-ios/fastlane/metadata/en-US/name.txt
apps/capacitor-film-lab-ios/fastlane/metadata/en-US/subtitle.txt
apps/capacitor-film-lab-ios/fastlane/metadata/en-US/keywords.txt
apps/capacitor-film-lab-ios/fastlane/metadata/en-US/promotional_text.txt
apps/capacitor-film-lab-ios/fastlane/metadata/en-US/description.txt
apps/capacitor-film-lab-ios/fastlane/metadata/en-US/release_notes.txt
```

関連 Fastlane:

```text
apps/capacitor-film-lab-ios/fastlane/Fastfile
apps/capacitor-film-lab-ios/fastlane/Deliverfile
```

## ASO作業で必ず検索・調査すること

次チャットでは、ユーザーが「検索して調査」と明示している前提で動くこと。App Store検索順位・ASOのベストプラクティス・競合アプリのmetadataは変動するため、必ず Gemini か web search を使う。

最低限調べる:

1. 日本 App Store での競合:
   - LUT
   - フィルム
   - 写真加工
   - 動画編集
   - カラーグレーディング
   - film camera
   - film look
   - cinematic video
   - log video
2. 英語圏 App Store での競合:
   - LUT
   - film look
   - photo filter
   - video filter
   - color grading
   - cinematic
   - log video
   - film camera
3. Apple公式の現在のmetadata制限:
   - app name length
   - subtitle length
   - keyword field length
   - promotional text length
   - description edit rules
   - screenshots / product page optimization / custom product pages rules
4. App Store Connect の現在状態:
   - `1.2` が Waiting for Review なのか、In Review なのか、Rejected なのか、Approved なのか
   - その状態で metadata を編集可能か
   - 編集するとレビューにどう影響するか

## ASO作業の推奨順序

1. 現在状態を確認する。
   - `scripts/check-filmtone-ios-truth.sh`
   - App Store Connect UI
   - 可能なら現在の App Store 検索で露出確認
2. 既存metadataを読み、文字数を測る。
3. 競合と検索語を調査する。
4. 日本語と英語で別々に検索 intent を分類する。
5. keyword field に入れる語、title/subtitle に入れる語、description に自然に入れる語を分ける。
6. ユーザーに「今レビュー中の `1.2` を差し戻してでもmetadata変更するか」「次バージョンでASO反映するか」を確認する。
7. ユーザー承認後にmetadataを編集する。
8. screenshots はユーザーが明示するまで変更しない。
9. 変更後は Fastlane metadata lane でアップロードするか、App Store Connect状態に応じて安全な提出laneを使う。

## 使える/使ったコマンド

状態確認:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/life
./scripts/check-filmtone-ios-truth.sh
```

App root:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
```

Fastlane wrapper:

```sh
./scripts/bundle.sh exec fastlane --version
```

Metadata upload only:

```sh
set -a; . ./.env.local; set +a
./scripts/bundle.sh exec fastlane ios metadata
```

Submit existing uploaded build without screenshots/binary:

```sh
set -a; . ./.env.local; set +a
APP_VERSION=1.2 BUILD_NUMBER=1 AUTOMATIC_RELEASE=1 ./scripts/bundle.sh exec fastlane ios submit_review
```

Do not run for ASO unless the user explicitly wants screenshot regeneration:

```sh
bun run release:screenshots
```

## Known Fastlane lanes after this work

- `ios archive`
  - fresh archive and app-store export
  - fixed duplicate `export_xcargs` issue
- `ios screenshots`
  - screenshot UI test rail
  - do not use for ASO unless explicitly requested
- `ios metadata`
  - uploads localized metadata and review info
  - now passes `release_notes`
- `ios beta`
  - TestFlight upload
- `ios release`
  - full app-store build, metadata, screenshots upload
  - now passes `release_notes`
  - dangerous for ASO if screenshots should not be touched
- `ios submit_review`
  - added in this session
  - uses existing uploaded build
  - skips binary
  - skips screenshots
  - updates metadata and submits for review

## 次チャットへの注意

- App Review submission は成功済み。再提出や差し戻しは、まず現在の ASC 状態を確認してから。
- ASO改善は「今すぐ `1.2` に反映する」か「次バージョンで反映する」かで手順が変わる。
- App Store検索に出ない問題は、metadataだけでなく、新規アプリのインデックス時間、ダウンロード数、レビュー数、カテゴリ競合、キーワード競争率も絡む。metadata修正だけで即時に検索露出が変わるとは限らない。
- ただし、現在はASO観点が薄いので、まずmetadata改善余地は大きい。
- v1.1 screenshots は現時点の正しいブランド/訴求素材。ASOのために変える場合も、別タスクとして明示承認を取る。

## 最高精度を出すための新規チャット引き継ぎプロンプト

以下を次の新規チャットに貼る。

```text
あなたは Codex として、Filmtone iOS の App Store ASO 対策を行ってください。

作業前提:
- life hub: /Volumes/SamsungPortableSSDX5001/documents/life
- 実アプリrepo: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
- iOS app root: /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
- まず /Volumes/SamsungPortableSSDX5001/documents/life の AGENTS.md に従い、Filmtone iOS route を確認してください。
- `scripts/check-filmtone-ios-truth.sh` で公開版とローカル版の真実を必ず確認してください。
- 2026-04-29 19:03 JST に Filmtone iOS `1.2 (1)` は Fastlane で App Review 提出済みです。ただし公開 App Store lookup はその時点では `1.1` でした。現在状態は必ず再確認してください。
- v1.1 のスクリーンショットが正しい状態です。勝手に `release:screenshots` を実行しないでください。スクリーンショットを再生成・上書きしないでください。
- 今回の提出では `skip_screenshots: true` の `ios submit_review` lane を使い、既存 build `1.2 (1)` を提出しました。
- Fastfileには `release_notes` 明示と `submit_review` lane が追加済みです。

目的:
Filmtone iOS が App Store検索にほとんど引っかかっていないため、ASO観点で App Store metadata を高精度に改善したいです。日本語と英語の両方を対象にしてください。

必須:
- 思考が必要な判断では sequential-thinking を使ってください。
- わからないこと、現在性が必要なこと、ASOベストプラクティス、Appleのmetadata制限、競合App Store状態は Gemini または web search で調査してください。
- 複数の独立した確認は並列実行してください。
- まず現在の App Store Connect / public lookup / local metadata / git status を確認してください。
- App Review中の `1.2` を編集・差し戻し・再提出する必要があるか、あるならユーザーに影響を説明して確認してください。
- metadata改善だけを先に提案し、スクリーンショット変更は別扱いにしてください。

最初に読むべきhandoff:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-v12-release-to-aso-handoff-2026-04-29-jst.md

最初に見るべきmetadata:
- apps/capacitor-film-lab-ios/fastlane/metadata/ja/name.txt
- apps/capacitor-film-lab-ios/fastlane/metadata/ja/subtitle.txt
- apps/capacitor-film-lab-ios/fastlane/metadata/ja/keywords.txt
- apps/capacitor-film-lab-ios/fastlane/metadata/ja/promotional_text.txt
- apps/capacitor-film-lab-ios/fastlane/metadata/ja/description.txt
- apps/capacitor-film-lab-ios/fastlane/metadata/en-US/name.txt
- apps/capacitor-film-lab-ios/fastlane/metadata/en-US/subtitle.txt
- apps/capacitor-film-lab-ios/fastlane/metadata/en-US/keywords.txt
- apps/capacitor-film-lab-ios/fastlane/metadata/en-US/promotional_text.txt
- apps/capacitor-film-lab-ios/fastlane/metadata/en-US/description.txt

期待する成果:
1. 現在のApp Store状態とmetadata状態の正確な整理
2. 日本語ASOの検索語/競合/intent分析
3. 英語ASOの検索語/競合/intent分析
4. App name / subtitle / keywords / promotional text / description の改善案
5. 文字数制限を満たす実編集案
6. 今レビュー中の `1.2` に反映すべきか、次バージョンに回すべきかの安全な判断
7. ユーザー承認後、必要なら fastlane metadata を安全に更新する手順
```
