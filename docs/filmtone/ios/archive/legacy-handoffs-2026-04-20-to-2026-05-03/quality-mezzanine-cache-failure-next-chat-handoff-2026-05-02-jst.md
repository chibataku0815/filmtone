# Filmtone iOS Quality Mezzanine Cache Failure Next Chat Handoff

作成: 2026-05-02 20:31 JST  
対象 repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`  
現在観測した HEAD: `7a2e1d1`  
現在観測した branch: `main`  
同じ commit を指す branch: `feature/ios-quality-mezzanine-contract`

## 最重要結論

今回の目的は、iOS の重い ProRes / Apple Log 素材で Quality export 時に
`qualitySDR` / `qualityHDR` mezzanine cache を使い、source-direct decode より
速く、かつ品質を落とさずに書き出すことだった。

現時点の結論は **書き出し自体は成功したが、quality mezzanine cache 施策としては失敗**。

- 最新 export は sidecar 上 `mezzanine.used: true` / `variant: qualityHDR`。
- しかし実測の書き出し時間は 243.2 秒で、以前の source-direct 174.0 秒より遅い。
- 端末上に残っている mezzanine file は 84.9 MB / duration 5.88 秒しかなく、2分36秒素材の完全 cache ではない。
- その一方で出力 mp4 は 156.29 秒あり、sidecar の `qualityHDR` 使用記録、端末 cache 実体、出力 duration が完全には整合しない。
- 次チャットでは「速度最適化」より先に **cache 完全性 / route 真実性 / telemetry 真実性** を直す必要がある。

## 絶対に守る前提

- この repo が Filmtone 実装の source of truth。
- Portfolio repo は編集しない。
- `bun` を使う。npm/yarn/pnpm の lockfile churn は避ける。
- 既存の dirty / committed state を巻き戻さない。
- 生成 Swift `FilmtonePhase0Generated.swift` は手編集しない。
- 変更対象は iOS native export / mezzanine cache / shared contract に絞る。
- product quality 優先。保守的な一般論ではなく、実機で速く品質が落ちない状態を目標にする。
- 思考が必要な分岐は `sequential-thinking` を使う。

## 現在の Git 状態

2026-05-02 20:31 JST に確認:

```text
## main...origin/main [ahead 4]
?? .claude/worktrees/
```

`git log --oneline --decorate -8` の先頭:

```text
7a2e1d1 (HEAD -> main, feature/ios-quality-mezzanine-contract) feat(ios): add DJI D-Log M source profile (#9) + bundle v1.4 mezzanine in-flight
739d94b (feature/ios-dense-neon-noir-look, feature/filmtone-ios-dji-dlog-m-source-profile) feat(ios): add Canon Log 3 + Cinema Gamut source profile
fd1f512 feat(desktop): add built-in Camera Profile catalog parity with iOS
0fc5141 feat(ios): add D-Log and C-Log source profiles
72c7c5e (origin/main, origin/HEAD, docs/filmtone-pack-01-persona-worldview-ia) Fix iOS Files import from external storage
```

注意:

- 当初は `feature/ios-quality-mezzanine-contract` を作って作業していた。
- 現在は `main` と `feature/ios-quality-mezzanine-contract` が同じ `7a2e1d1` を指している。
- `7a2e1d1` には D-Log M 変更と今回の mezzanine 変更が同居している。
- 新チャットでは勝手に reset / checkout しないこと。まず `git status --short --branch` と `git log --oneline --decorate -5` で現状確認する。

## 当初の実装目的

Swift 側は `qualitySDR` / `qualityHDR` を出すようになっていたが、
`packages/film-lab-core` 側の型と benchmark markdown parser が `sdr` / `hdr`
しか認識しない契約穴があった。

最初の plan:

- `packages/film-lab-core` に `Phase0MezzanineProfileVariant`
  = `"sdr" | "hdr" | "qualitySDR" | "qualityHDR"` を追加 / export。
- `Phase0ExportBenchmarkRecord`, `BenchmarkRow`, row parse/format を4 variant対応。
- unknown strings は引き続き `null`。
- `packages/film-lab-core/dist/` を `bun run build:core` で再生成。
- stale Swift comments の `"sdr" | "hdr"` を必要最小限更新。

## これまで入った主な変更

### Shared contract

主なファイル:

- `packages/film-lab-core/src/native-bridge.ts`
- `packages/film-lab-core/src/benchmark-row.ts`
- `packages/film-lab-core/src/benchmark-row.test.ts`
- `packages/film-lab-core/src/index.ts`
- `packages/film-lab-core/dist/index.js`
- `packages/film-lab-core/dist/index.d.ts`

内容:

- `Phase0MezzanineProfileVariant` を追加 / export。
- known variants: `sdr`, `hdr`, `qualitySDR`, `qualityHDR`。
- benchmark row の `mezz=` が4 variantを round-trip。
- unknown mezzanine strings は `null`。

### Swift comments / sidecar wording

主なファイル:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`

内容:

- stale comment を4 variant前提に更新。

### Quality mezzanine export preparation

主なファイル:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/MezzanineService.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/test-source-color-classifier.swift`

入った挙動:

- Quality export かつ heavy source の場合、export 前に `qualitySDR` / `qualityHDR`
  mezzanine を準備する。
- 対象判定は `FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant`。
- ProRes / DNxHD / 100Mbps以上 HEVC などを heavy として扱う。
- Apple Log / ProRes 422 の今回素材は `qualityHDR` 対象。
- `resolvedVideoSourceURL()` は quality cache を candidate に含む。
- sidecar / benchmark は consumed mezzanine variant を出す。

### 6% freeze 対策

一度 `ensureMezzanineBlocking` を `Task` + semaphore で実装したが、実機で
6%「準備」から進まない状態になった。

その後の修正:

- export 時は `Task` を semaphore で待たず、同期生成 path で `.partial` へ生成して promote。
- progress は 6% 固定ではなく 6〜10% 台で動くよう変更。
- `git diff --check`, `verify:ios`, Xcode build は通った。

### prewarm / export in-flight 共有

ユーザー指摘:

> これ本当に読み込み時のキャッシュ出力時にも流用してる？明らかに遅いです

確認した設計問題:

- 新規 import 時は `AssetPickerService.kickOffMezzanine` で preview / quality prewarm を投げていた。
- しかし export が prewarm 完了前に始まると、export 側が同じ in-flight 生成を共有できず、別生成または別経路になり得た。
- 復元済み source / 既に開いている source では prewarm が再発火しない可能性があった。

入った修正:

- `MezzanineService` に `GenerationState` / `GenerationLease` を追加。
- `inFlight: [String: GenerationState]` で source+profile signature 単位の生成を共有。
- async prewarm と sync export が同じ generation state を使う。
- export が in-flight を見つけたら別生成せず待つ。
- progress observer で export UI が prewarm 中の進捗も受け取れる。
- `MezzanineService.prewarmEligibleMezzanines(for:)` を追加。
- `AssetPickerService` はその helper を呼ぶだけに整理。
- `FilmtoneMediaRuntime.prewarmMezzanines(for:)` と `FilmtoneEditorFacade.prewarmMezzanines(for:)` を追加。
- `FilmtoneEditorStore` 起動時と `applyProbe` 時に既存 source へ prewarm を再発火。

## 実機 / 環境

使用した端末:

- iPhone 17 Pro
- device model: `iPhone18,1`
- iOS: `26.3.1`
- devicectl visible name: `千葉工のiPhone (7)`
- CoreDevice identifier: `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`
- Xcode destination UDID used for build: `00008150-001674883C84401C`
- bundle id: `com.chibatakumi.film.lab.ios`

最終 install:

```bash
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -destination 'id=00008150-001674883C84401C' \
  -configuration Debug \
  -derivedDataPath build/ios-device-debug \
  build

xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  build/ios-device-debug/Build/Products/Debug-iphoneos/App.app

xcrun devicectl device process launch \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

最終 install output:

```text
App installed:
bundleID: com.chibatakumi.film.lab.ios
installationURL: file:///private/var/containers/Bundle/Application/496DF9C8-D05B-4713-BE4E-8D7DCB5E7DCF/App.app/
Launched application with com.chibatakumi.film.lab.ios bundle identifier.
```

## 検証済みコマンド

通ったもの:

```bash
bun test src/benchmark-row.test.ts
bun run build:core
bun run verify:ios
git diff --check
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

実機向け build / install / launch も成功。

注意:

- `verify:swift-contract` は root script ではなく、`apps/capacitor-film-lab-ios/package.json`
  内の script。root で直接 `bun run verify:swift-contract` は失敗した。
- `bun run verify:ios` 内では `./scripts/verify-phase0-contract.sh` が走っている。

## テスト素材と期待値

ユーザーの実機素材:

- filename: `A001_03270631_C008.mov`
- source size: `8884471469` bytes
- duration: `156.30666666666667` sec
- resolution: `3840x2160`
- frame rate: `30.005117416381836`
- codec: `apcn`
- codec family: `prores-422`
- color class: `apple-log`
- transfer: `apple-log`
- primaries: `bt2020`

最初の source-direct export 結果:

- elapsed: `174046 ms`
- realtimeRatio: `1.1134905740851317`
- output: `1920x1080`, 24fps, H.264 Rec.709
- output size: `246213415` bytes
- sidecar: `mezzanine.used: false`
- 当時の `Library/Caches/FilmtonePhase0/mezzanine/` は0 files。

当初の期待:

- この素材では `qualityHDR` mezzanine を作る。
- 2回目以降、または import prewarm 完了後の export では `qualityHDR` を再利用。
- sidecar は `mezzanine.used: true`, `variant: qualityHDR`。
- source-direct 174秒より速いか、少なくとも遅くならない。

## 最新の実機 export 結果

ユーザーが修正版 install 後に export したもの。

端末 `exports` listing:

```text
Library/Caches/FilmtonePhase0/exports

filmtone-export-ae5cde91-a998-419c-90fd-0e1af44e5ce9-combined-color.cube       1 MB
filmtone-export-ae5cde91-a998-419c-90fd-0e1af44e5ce9-filmtone-bridge.dctl      20 KB
filmtone-export-ae5cde91-a998-419c-90fd-0e1af44e5ce9-post-optical-color.cube   1 MB
filmtone-export-ae5cde91-a998-419c-90fd-0e1af44e5ce9-pre-optical-color.cube    1 MB
filmtone-export-ae5cde91-a998-419c-90fd-0e1af44e5ce9-reference-after.jpg       184 KB
filmtone-export-ae5cde91-a998-419c-90fd-0e1af44e5ce9-source.mov                8.27 GB
filmtone-export-ae5cde91-a998-419c-90fd-0e1af44e5ce9.mp4                       217 MB
filmtone-export-ae5cde91-a998-419c-90fd-0e1af44e5ce9.mp4.filmtone-ios-export-session-v1.json 8 KB
```

Pulled sidecar:

```text
build/device-inspection/filmtone-export-ae5cde91-a998-419c-90fd-0e1af44e5ce9.mp4.filmtone-ios-export-session-v1.json
```

sidecar summary:

```json
{
  "version": 1,
  "schema": "filmtone-ios-export-session-v1",
  "exportedAtIso": "2026-05-02T11:27:19.902Z",
  "input": {
    "filename": "A001_03270631_C008.mov",
    "fileSizeBytes": 8884471469,
    "durationSec": 156.30666666666667,
    "width": 3840,
    "height": 2160,
    "frameRate": 30.005117416381836,
    "codec": "apcn",
    "codecFamily": "prores-422",
    "colorClass": "apple-log",
    "transfer": "apple-log",
    "primaries": "bt2020"
  },
  "output": {
    "elapsedMs": 243203,
    "realtimeRatio": 1.5559349142710908,
    "fileSizeBytes": 227572451,
    "outputWidth": 1920,
    "outputHeight": 1080,
    "fps": 24,
    "degradedDecodePath": false
  },
  "mezzanine": {
    "profileVersion": 5,
    "used": true,
    "variant": "qualityHDR"
  },
  "renderMode": "quality",
  "packageMedia": "filmtone-export-ae5cde91-a998-419c-90fd-0e1af44e5ce9-source.mov"
}
```

Output mp4 ffprobe:

```json
{
  "streams": [
    {
      "codec_name": "h264",
      "profile": "High",
      "width": 1920,
      "height": 1080,
      "pix_fmt": "yuv420p",
      "color_space": "bt709",
      "color_transfer": "bt709",
      "color_primaries": "bt709",
      "r_frame_rate": "24/1",
      "avg_frame_rate": "24/1",
      "bit_rate": "11517235"
    }
  ],
  "format": {
    "duration": "156.291678",
    "size": "227572451",
    "bit_rate": "11648602"
  }
}
```

端末 `mezzanine` listing:

```text
Library/Caches/FilmtonePhase0/mezzanine

8c8fcd1f3b36e2459569b86070f1abbcf17455fb667ed51af000aa4f11f54c89.mp4 84.9 MB 2026/05/02, 19:08
```

Mezzanine file ffprobe:

```json
{
  "streams": [
    {
      "codec_name": "hevc",
      "profile": "Main 10",
      "width": 2160,
      "height": 3840,
      "pix_fmt": "yuv420p10le",
      "color_space": "bt2020nc",
      "color_transfer": "arib-std-b67",
      "color_primaries": "bt2020",
      "r_frame_rate": "24000/1001",
      "avg_frame_rate": "84600/3529",
      "bit_rate": "121003782"
    }
  ],
  "format": {
    "duration": "5.881667",
    "size": "89060615",
    "bit_rate": "121136562"
  }
}
```

## 最新結果の判定

成功していること:

- export は完了。
- sidecar は `qualityHDR` 使用を記録。
- output mp4 は 156秒全尺、1920x1080/24fps/H.264/Rec.709 として成立。

失敗していること:

- 速度は 243秒で、前回 source-direct 174秒より約69秒遅い。
- したがって current `qualityHDR` route は速度改善として失敗。
- 端末上に残っている mezzanine file は 5.88秒で不完全。
- `qualityHDR` として扱われた cache の真実性が怪しい。

未解決の矛盾:

- sidecar は `mezzanine.used: true` / `qualityHDR`。
- 端末上に見える mezzanine は 5.88秒しかない。
- しかし output mp4 は 156秒全尺。
- 現実に 5.88秒の cache を export input として使っていたなら output も短くなるはず。
- 可能性:
  - export 中には full-length qualityHDR cache があり、その後 prune / overwrite / cleanup で消えた。
  - `didUseMezzanineVariant` attribution が誤って true になっている。
  - `existingMezzanineURL` / signature / file identity が別 source の短い cache を指している。
  - `qualityHDR` generation が途中で終わった cache を complete と見なしている。
  - export package の source copy / cache prune / cache cap が想定外に干渉している。

この矛盾は次チャットの最初の blocker。

## 次に直すべき本質

### 1. Cache 完全性検証を入れる

`existingMezzanineURL` はファイル存在だけでなく、最低限以下を検証するべき:

- duration が source duration と十分近いこと。
- video track が存在すること。
- quality variant なら source resolution preserved と一致すること。
- profile codec / pixel format / color tags が期待に近いこと。
- 破損 / 途中終了 file を readable cache として使わないこと。

短期実装候補:

- `MezzanineService.isValidMezzanine(url:sourceURL:profile:)` を追加。
- `existingMezzanineURL` で validation 失敗なら file を削除して nil。
- promote 前にも generated temp を validation。
- validation failure は `GenerationError.writerFailed` などで fail loud。

### 2. Telemetry truth を強化する

sidecar だけでは「本当にどの file を使ったか」が追えない。

追加したい sidecar / debug fields:

- `mezzanine.urlLastPathComponent`
- `mezzanine.fileSizeBytes`
- `mezzanine.durationSec`
- `mezzanine.width`
- `mezzanine.height`
- `mezzanine.codec`
- `mezzanine.generatedDuringExport: Bool`
- `mezzanine.prewarmHit: Bool`
- `mezzanine.validationStatus`

少なくとも debug log で出す。

### 3. qualityHDR codec 方針を見直す

現状:

- `qualityHDR` は HEVC Main10 / HLG / BT.2020 / source resolution / 120Mbps。
- ProRes Apple Log source を HEVC Main10 HLG に変換してから export すると、decode が軽くなるとは限らない。
- 今回は速度改善どころか遅くなった。

次チャットで検討する選択肢:

1. ProRes Apple Log は source-direct に戻す。
2. quality cache を HEVC ではなく ProRes系 / intraframe intermediate にする。
3. cache は 1920 output-oriented にして最終 export の scaling/decode costを落とす。ただし品質要件と色変換の整合が必要。
4. Quality mode は cache を使わず、Speed mode / preview だけ cache を使う。

製品品質優先なら、まず source-direct を下回る route は無効化する。

### 4. Connect package source copy のディスク負荷を確認する

最新 export は `exports/` に `source.mov` 8.27GB をコピーしている。

これは Filmtone Connect package 用の companion と思われるが、通常 export で毎回 8GB コピーすると disk pressure / prune / runtime cost が大きい。

次チャットでは以下も確認:

- Connect package companion は常時必要か。
- 通常の写真保存 / 共有だけなら source copy を遅延生成できないか。
- package export mode のときだけ source copy するべきではないか。
- source copy が mezzanine prune や export timing に干渉していないか。

## 次チャットで最初に見るべきファイル

順番:

1. `AGENTS.md`
2. `apps/capacitor-film-lab-ios/CLAUDE.md`
3. `apps/capacitor-film-lab-ios/ios/App/App/MezzanineService.swift`
4. `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
5. `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
6. `apps/capacitor-film-lab-ios/ios/App/App/AssetPickerService.swift`
7. `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift`
8. `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorFacade.swift`
9. `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
10. `apps/capacitor-film-lab-ios/scripts/swift/test-source-color-classifier.swift`

Do not start with broad file discovery.

## Useful commands

Device listing:

```bash
xcrun devicectl list devices
```

List app cache:

```bash
xcrun devicectl device info files \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  --domain-type appDataContainer \
  --domain-identifier com.chibatakumi.film.lab.ios \
  --subdirectory Library/Caches/FilmtonePhase0/mezzanine \
  --recurse --columns '*'
```

Pull sidecar:

```bash
xcrun devicectl device copy from \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  --domain-type appDataContainer \
  --domain-identifier com.chibatakumi.film.lab.ios \
  --source Library/Caches/FilmtonePhase0/exports/<export>.mp4.filmtone-ios-export-session-v1.json \
  --destination build/device-inspection/<export>.json
```

Summarize sidecar:

```bash
jq '{version, schema, exportedAtIso, input: {filename: .input.filename, fileSizeBytes: .input.sourceProbe.fileSizeBytes, durationSec: .input.sourceProbe.durationSec, width: .input.sourceProbe.width, height: .input.sourceProbe.height, frameRate: .input.sourceProbe.frameRate, codec: .input.sourceProbe.codec, codecFamily: .input.sourceProbe.codecFamily, colorClass: .input.sourceProbe.sourceVideoMetadata.colorClass, transfer: .input.sourceProbe.sourceVideoMetadata.color.colorTransfer, primaries: .input.sourceProbe.sourceVideoMetadata.color.colorPrimaries}, output: {elapsedMs: .output.elapsedMs, realtimeRatio: .output.realtimeRatio, fileSizeBytes: .output.fileSizeBytes, outputWidth: .output.outputWidth, outputHeight: .output.outputHeight, fps: .output.fps, degradedDecodePath: .output.degradedDecodePath}, mezzanine, renderMode, packageMedia: .package.mediaFilename}' build/device-inspection/<export>.json
```

ffprobe:

```bash
ffprobe -v error \
  -select_streams v:0 \
  -show_entries stream=codec_name,profile,width,height,r_frame_rate,avg_frame_rate,bit_rate,pix_fmt,color_space,color_transfer,color_primaries \
  -show_entries format=duration,size,bit_rate \
  -of json <file>
```

Verification:

```bash
bun test src/benchmark-row.test.ts
bun run build:core
bun run verify:ios
git diff --check
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

Install to iPhone 17 Pro:

```bash
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -destination 'id=00008150-001674883C84401C' \
  -configuration Debug \
  -derivedDataPath build/ios-device-debug \
  build

xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  build/ios-device-debug/Build/Products/Debug-iphoneos/App.app

xcrun devicectl device process launch \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

## Completion Criteria For Next Chat

次チャットの成功条件:

1. Fresh import または cache clear 後、quality cache が生成された場合、その mezzanine file が source duration 156.3秒に近い。
2. `existingMezzanineURL` は 5.88秒の不完全 cache を絶対に採用しない。
3. sidecar の `mezzanine.used` と実際の `effectiveSourceURL` が一致する。
4. export 後に sidecar / ffprobe / device file listing が矛盾しない。
5. ProRes Apple Log 8.88GB / 156秒素材で source-direct 174秒より遅い route は product path から外す。
6. 最終的に Quality export は以下のどちらか:
   - source-direct より速く、全尺・品質・telemetry が正しい。
   - source-direct を選び、quality mezzanine を使わない理由が明確で sidecar に嘘がない。

## 最高精度を出せる引き継ぎ詳細プロンプト

以下を新規チャットの最初のメッセージに貼る。

```text
あなたは Filmtone repo の iOS quality mezzanine cache 失敗対応を引き継ぎます。

作業 repo:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

必ず最初に読む:
1. AGENTS.md
2. apps/capacitor-film-lab-ios/CLAUDE.md
3. docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/quality-mezzanine-cache-failure-next-chat-handoff-2026-05-02-jst.md

重要な現在状態:
- 2026-05-02 JST 時点。
- 現在観測した HEAD は 7a2e1d1。
- main と feature/ios-quality-mezzanine-contract が同じ commit を指している。
- origin/main は 72c7c5e で、local main は ahead 4。
- 7a2e1d1 には D-Log M 変更と quality mezzanine in-flight 共有修正が同居している。
- 勝手に reset / checkout / revert しない。
- portfolio repo は編集しない。
- bun を使う。
- 思考が必要な分岐は sequential-thinking を使う。

これまでの経緯:
- Swift は qualitySDR/qualityHDR を出すが film-lab-core は sdr/hdr しか型・parse していなかった。
- film-lab-core に Phase0MezzanineProfileVariant = "sdr" | "hdr" | "qualitySDR" | "qualityHDR" を追加し、benchmark row parser/formatter と dist を更新済み。
- iOS は Quality export で heavy source の qualityHDR/qualitySDR mezzanine を準備するよう修正済み。
- 一度 6% 準備で止まったので、Task + semaphore 待ちはやめ、MezzanineService に GenerationState/GenerationLease を追加して import prewarm と export が同じ in-flight 生成を共有するようにした。
- 復元済み/既存 source でも prewarmMezzanines が再発火するようにした。
- iPhone 17 Pro に修正版を install 済み。

実機素材:
- A001_03270631_C008.mov
- 8,884,471,469 bytes
- 156.30666666666667 sec
- 3840x2160
- 30.005fps
- codec apcn / codecFamily prores-422
- Apple Log / BT.2020

重要な実測:
1. 修正前 source-direct export:
   - elapsedMs 174046
   - realtimeRatio 1.11349
   - output 1920x1080 24fps H.264 Rec.709
   - fileSizeBytes 246213415
   - mezzanine.used false

2. 修正後 export:
   - sidecar: mezzanine.used true, variant qualityHDR, profileVersion 5
   - elapsedMs 243203
   - realtimeRatio 1.55593
   - output fileSizeBytes 227572451
   - output ffprobe duration 156.291678 sec
   - output is 1920x1080 24fps H.264 Rec.709
   - therefore export itself succeeded, but slower than source-direct

3. Device mezzanine cache after latest export:
   - only one file visible:
     Library/Caches/FilmtonePhase0/mezzanine/8c8fcd1f3b36e2459569b86070f1abbcf17455fb667ed51af000aa4f11f54c89.mp4
   - size 84.9 MB
   - ffprobe:
     HEVC Main10, 2160x3840, yuv420p10le, BT.2020/HLG, ~121Mbps
     duration 5.881667 sec
   - This is not a complete 156 sec cache.

Blocker:
- sidecar says qualityHDR was used, but visible mezzanine cache is only 5.88 sec, while output mp4 is full 156 sec.
- This means cache completeness, file identity, route truth, or telemetry truth is wrong.
- Do not assume the quality cache is working just because sidecar says used=true.

Your task:
Fix the real product problem, not just the type contract.

Priority order:
1. Prove and fix mezzanine cache validity:
   - existingMezzanineURL must reject incomplete/short/invalid cache files.
   - generated temp must be validated before promotion.
   - validation should compare duration against source duration.
   - for quality variants, validate expected resolution/codec/color enough to avoid false hits.
2. Prove and fix telemetry truth:
   - sidecar/debug logs should expose actual mezzanine file identity, duration, size, width/height, generatedDuringExport/prewarmHit if feasible.
   - didUseMezzanineVariant must be true only when effectiveSourceURL is truly a valid mezzanine file.
3. Reassess qualityHDR strategy:
   - Current HEVC Main10 4K 120Mbps path is slower than source-direct for ProRes Apple Log.
   - Product-quality answer may be disabling quality mezzanine for ProRes Apple Log, or switching to a better intermediate codec/path.
   - Do not keep a slower route just because it is already implemented.
4. Check Connect package source copy:
   - latest export writes an 8.27GB source.mov into exports.
   - Determine whether this should happen for normal export, whether it causes disk pressure/prune interference, and whether it should be delayed or gated by package export.

Verification required:
- bun test src/benchmark-row.test.ts in packages/film-lab-core if core is touched.
- bun run build:core if package dist changes.
- bun run verify:ios.
- xcodebuild generic iOS Debug build.
- git diff --check.
- Install to connected iPhone 17 Pro and run a real export if device is available.
- Pull latest sidecar and ffprobe output + mezzanine file.
- Success means the device listing, ffprobe, sidecar, and elapsed time tell the same story.

Useful commands:
- xcrun devicectl list devices
- xcrun devicectl device info files --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 --domain-type appDataContainer --domain-identifier com.chibatakumi.film.lab.ios --subdirectory Library/Caches/FilmtonePhase0/mezzanine --recurse --columns '*'
- Pull sidecars from Library/Caches/FilmtonePhase0/exports/
- ffprobe copied mp4/cache files for duration, codec, resolution, bitrate, color tags.

Do not commit or push unless explicitly asked.
```
