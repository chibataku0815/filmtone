# Filmtone Connect for DaVinci — Real Package Export Handoff

- **作成日**: 2026-04-30 JST
- **目的**: 次チャットで Filmtone iOS 側の `real package export` を最小単位で実装・検証するための完全引き継ぎ
- **対象 repo**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- **iOS app**: `apps/capacitor-film-lab-ios`
- **life hub**: `/Volumes/SamsungPortableSSDX5001/documents/life`
- **現在の核心**: DaVinci 側 v0 bridge は実機 smoke 済み。次は iOS から実 package を生成して DaVinci に食わせる。

---

## 0. 最重要方針

- **本質の進行を最優先**する。
- 次の本質は UI ではなく、`media + sidecar + combined-color.cube + reference-after.jpg` が Filmtone iOS から実際に出ること。
- 外殻、過剰 QA、ASO、長い手順書、zip 化、DRX、PowerGrade、DCTL、OpenFX、Source/Film 複数 node 分離は後段。
- 保守的な一般論より、プロダクト品質が高くなる実装を優先する。
- 設計判断、DaVinci 連携方式、package contract、MVP 境界は `sequential-thinking` で考える。
- DaVinci / iOS SDK / Files share / LUT format の不明点は記憶で断定せず、local source / bundled docs / web search で確認する。
- 既存 handoff は鵜呑みにせず、必ず live code と current truth に突き合わせる。

---

## 1. Current Truth Snapshot

`/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh` を 2026-04-30 JST に再実行済み。

| 項目 | 値 |
|---|---|
| branch/head | `main @ 9a1c43e8` |
| upstream | `origin/main` |
| ahead / behind | `1 / 0` |
| ahead commit | `9a1c43e8 feat(filmtone-ios): add DaVinci connect v0 spike` |
| local Xcode MARKETING_VERSION | `1.2` |
| local build | `1` |
| public App Store version | `1.1` |
| public release date | `2026-04-21T07:00:00Z` |
| public currentVersionReleaseDate | `2026-04-26T03:24:53Z` |
| public URL | `https://apps.apple.com/jp/app/filmtone/id6762564806?uo=4` |

Interpretation:

- 公開 App Store は `1.1`。
- local code は `1.2 (1)` candidate / unreleased stream。
- `main` は `origin/main` より 1 commit ahead。DaVinci v0 spike commit が未 push の可能性がある。
- 次チャットでも必ず truth script を再実行する。

### Dirty Worktree 注意

この handoff 作成時点で、DaVinci v0 commit とは別の dirty files が存在する。

```text
 M apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
 M apps/capacitor-film-lab-ios/ios/App/App/AppDelegate.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift
 M apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh
?? apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySchema.swift
?? apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySection.swift
?? apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibraryStore.swift
?? apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLutBlobCodec.swift
?? apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSavedLookSheet.swift
?? docs/filmtone/ios/filmtone-connect-for-davinci-feasibility-handoff-2026-04-29-jst.md
```

これらは DaVinci v0 spike commit には含めていない。次チャットで触る場合は、ユーザー/他作業の変更として扱い、絶対に revert しない。

---

## 2. ここまでの経緯

### 2.1 戦略転換

PeekLut が iPhone / iPad 上で「DaVinci Resolve 代替」に近い位置を取りに来ている。Filmtone iOS がトーンカーブ、マスク、HSL、ヒストグラム、ProRes 出力、バッチ編集などを追うと、Filmtone の強みである物理整合・色管理・軽い ritual 体験が薄まる。

そこで方向を次に固定した。

```text
PeekLut = DaVinci の代替
Filmtone = DaVinci の前段
```

中核構想:

```text
Filmtone Connect for DaVinci
  = media + sidecar + LUT + reference still を DaVinci に渡し、
    iPhone の pre-grade を finishing workflow に接続する bridge
```

Sidecar は Connect そのものではない。Sidecar は Connect が読むための **data contract / manifest / receipt**。

### 2.2 Product Claim

言ってよい claim:

```text
Pre-grade on iPhone. Finish in DaVinci.
```

日本語:

```text
iPhone で下地を、DaVinci で仕上げを。
```

言ってはいけないこと:

- DaVinci 上で Filmtone の全処理を完全再現できる。
- Sidecar だけで色が再現できる。
- 3D LUT で depth / ray-angle optics / grain / motion blur / halation spread を完全再現できる。
- PeekLut と同じ単なる LUT export 競争に寄せる。

正しい境界:

```text
Color transform
  -> .cube として DaVinci node へ渡す

Optics / glow / grain / depth / temporal effects
  -> baked media + reference still + sidecar provenance として渡す
```

---

## 3. 完了済み: DaVinci v0 Spike

### 3.1 Commit

```text
9a1c43e8 feat(filmtone-ios): add DaVinci connect v0 spike
```

含まれる files:

- `apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua`
- `docs/filmtone/ios/filmtone-connect-davinci-v0-spike-verified-2026-04-30-jst.md`

### 3.2 Script の役割

DaVinci Workspace Script として動く Lua script。

入力 package:

```text
FilmtoneExport/
  media.mov
  media.mov.filmtone-ios-export-session-v1.json
  combined-color.cube
  reference-after.jpg
```

処理:

1. package folder を解決。
2. `*.filmtone-ios-export-session-v1.json` を探す。
3. embedded Lua JSON parser で sidecar を parse。
4. media を Media Pool に import。
5. current timeline に append、または timeline を作成。
6. `combined-color.cube` を Resolve LUT tree に stage。
7. `Project:RefreshLUTList()`。
8. `Graph:SetLUT(1, "Filmtone Connect/combined-color.cube")`。
9. timeline item marker に Filmtone summary を書く。
10. `reference-after.jpg` を Gallery に import。失敗時は Media Pool fallback。

### 3.3 Script の入力解決順

```text
1. --package /path/to/package
2. first positional argument
3. FILMTONE_CONNECT_PACKAGE
4. macOS folder picker
5. console prompt
```

### 3.4 Verified Resolve

```text
DaVinci Resolve 20.3.2.9
```

### 3.5 実機 smoke 結果

DaVinci が未起動の状態では `fuscript` から `NO_RESOLVE`。`open -a "DaVinci Resolve"` 後、`20.3.2.9` に接続できた。

一時 package を作成し、実際の Resolve project に import した。

成功ログ:

```text
SMOKE_PROJECT=Filmtone Connect Smoke 20260430 010638
SMOKE_NODE1_LUT=Filmtone Connect/combined-color.cube
SMOKE_TIMELINE_MARKERS=1
SMOKE_FILMTONE_NOTE_FOUND=true
SMOKE_GALLERY_STILLS=2
```

成功したこと:

- media import
- timeline 作成/配置
- LUT stage + node 1 apply
- marker note 追加
- reference still Gallery import

失敗 project:

- 初回 smoke project `Filmtone Connect Smoke 20260430 010553` は LUT discovery 失敗で作られた。
- その後 `ProjectManager:DeleteProject(...)` で削除済み。

成功 project:

```text
Filmtone Connect Smoke 20260430 010638
```

確認するなら Resolve でこの project を開き、Color page の node 1、timeline marker、Gallery still を見る。

### 3.6 Critical Finding

Resolve scripting README では `Graph:SetLUT(nodeIndex, lutPath)` が absolute path を受けると読めるが、package-local absolute `.cube` は実機 smoke で discovery されなかった。

安定経路:

```text
copy .cube ->
  /Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/Filmtone Connect/

Project:RefreshLUTList()

Graph:SetLUT(1, "Filmtone Connect/combined-color.cube")
```

この挙動を前提にすること。package-local path を直接 `SetLUT` する設計へ戻さない。

### 3.7 Local Install

Workspace Script として検証するため、以下を symlink 済み。

```text
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/Filmtone Connect/Import Filmtone Package.lua
  -> apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
```

DaVinci メニュー:

```text
Workspace > Scripts > Filmtone Connect > Import Filmtone Package
```

---

## 4. 現行 iOS Sidecar の事実

重要 source:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/PhotoLibraryService.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift`

### 4.1 Sidecar filename

```text
<output>.filmtone-ios-export-session-v1.json
```

例:

```text
phase0-export.mp4
phase0-export.mp4.filmtone-ios-export-session-v1.json
```

### 4.2 Sidecar schema

```text
kind = "filmtone-export-session"
schema = "filmtone-ios-export-session-v1"
version = 1
```

Additive optional fields は v1 のまま追加可能。field rename / type change / semantics change は v2 が必要。

### 4.3 Sidecar が持つ情報

- app version / build
- device model / iOS version
- source URI / filename / media kind
- source probe
- source video metadata
- camera optics metadata
- HDR preparation policy
- preset name / preset version
- quick state
- Phase 0 params
- `lutRefs.inputLut` / `lutRefs.creativeLut` の `size` と `intensity`
- output codec / container / fps / size
- output color contract
- render mode
- mezzanine block
- depth block

### 4.4 Sidecar が意図的に持たないもの

LUT の full data array は持たない。

`scripts/swift/test-sidecar-builder.swift` で以下が固定されている。

- sidecar payload は `8KB` 未満。
- `"data":[` を含まない。
- `"data" :` を含まない。
- LUT refs は `size` と `intensity` の summary のみ。

理由:

- JSON を小さく保つ。
- LUT 本体は source project / exported `.cube` を SSOT にする。
- sidecar は「処理レシピと証跡」であり、全素材 archive ではない。

### 4.5 Photos / Share の現行挙動

Photos 保存:

- `PhotoLibraryService` は media のみ Photos に保存する。
- Photos asset は任意 JSON sidecar を隣接保存できない。
- Pro Tool bridge は Photos 保存では成立しない。

Share:

- `FilmtoneEditorStore.shareOutput()` は media + sidecar を share sheet に渡す。
- share 完了後は local export files が discard される。

意味:

- 次の package export は Photos save ではなく Files / AirDrop / share package 経由が本命。
- 現行 shareOutput は複数 URL を渡せるので、package files を渡す拡張余地がある。

---

## 5. 次チャットの本質タスク

### 5.1 やること

**iOS 側 real package export spike**。

目標:

```text
Filmtone iOS export
  -> media
  -> sidecar
  -> combined-color.cube
  -> reference-after.jpg
  -> DaVinci script で import
```

最小 success criteria:

```text
- iOS から generated package を作れる
- package に media / sidecar / combined-color.cube / reference-after.jpg が入る
- sidecar に package-relative fields が入る
- DaVinci script がその package を読み込める
- DaVinci node 1 に generated combined-color.cube が入る
- marker note に preset / output profile / baked effects / depth / mezzanine が残る
- reference-after.jpg が Gallery に入る
- DaVinci 上の media が Filmtone export の見た目と一致する
```

### 5.2 優先順位

1. `combined-color.cube` を Filmtone の現在 grade から生成する。
2. `reference-after.jpg` を export 時に生成する。
3. sidecar に package-relative fields を追加する。
4. media + sidecar + cube + reference をまとめて share / Files に渡す。
5. その実 package を DaVinci script に食わせて再検証する。

### 5.3 まだやらない

- iOS UI の作り込み。
- zip 化。
- Source Profile / Film Look の複数 node 分離。
- DRX / PowerGrade。
- DCTL / OpenFX。
- DaVinci 上で optics / glow / grain / depth を再実装すること。
- ASO / release copy。

---

## 6. 実装方針案

### 6.1 Package layout

最小:

```text
FilmtoneExport/
  media.mov
  media.mov.filmtone-ios-export-session-v1.json
  combined-color.cube
  reference-after.jpg
```

将来拡張:

```text
FilmtoneExport/
  media.mov
  media.mov.filmtone-ios-export-session-v1.json
  source-transform.cube
  film-look.cube
  combined-color.cube
  reference-before.jpg
  reference-after.jpg
```

### 6.2 Sidecar additive field

v1 のまま additive optional field として追加する。

```json
{
  "package": {
    "layout": "filmtone-connect-package-v1",
    "mediaFilename": "media.mov",
    "referenceAfterFilename": "reference-after.jpg",
    "luts": {
      "combinedColor": "combined-color.cube"
    }
  }
}
```

将来:

```json
{
  "package": {
    "layout": "filmtone-connect-package-v1",
    "mediaFilename": "media.mov",
    "referenceAfterFilename": "reference-after.jpg",
    "referenceBeforeFilename": "reference-before.jpg",
    "luts": {
      "sourceTransform": "source-transform.cube",
      "filmLook": "film-look.cube",
      "combinedColor": "combined-color.cube"
    }
  }
}
```

### 6.3 LUT 生成の注意

最初は `combined-color.cube` のみでよい。

ただし、言い方は重要:

```text
combined-color.cube
  = LUT 化できる color transform bridge
  != Filmtone 全処理の完全再現
```

光学 / glow / grain / depth は `.cube` 化できない領域があるため、DaVinci へは baked media + sidecar provenance + reference still として渡す。

実装候補:

- 33x33x33 grid を生成。
- RGB cube sample に、LUT 化可能な color-only transform を適用。
- `.cube` serializer を追加。
- `TITLE "Filmtone Combined Color"` と `LUT_3D_SIZE 33` を出す。
- domain は default `0 0 0` to `1 1 1`。

注意:

- `SerializableLutDTO.data` は TS 側では RGBA Float32Array 由来で alpha を含む。`.cube` は RGB 行が必要。
- Filmtone iOS の `applyLut` は intensity < 0.999 のとき `lut * intensity + original * (1 - intensity)` の線形 blend。
- Apple Log / HDR / P3 の automatic input transform は現行 export path で `preparedInputLut` / `makeAutomaticInputLut` 周辺にある。`combined-color.cube` にどこまで含めるかは sequential-thinking で決める。

### 6.4 Reference still

最初は `reference-after.jpg` だけでよい。

目的:

- DaVinci 側で baked optics / glow / grain / depth の見た目を確認する ground truth。
- `.cube` が再現しない部分を visual reference として残す。

生成候補:

- export source の代表 frame / current preview frame を、export と同じ pipeline で JPEG 書き出し。
- 既存 preview image writing (`filmtone-preview-graded`) 周辺を調査して再利用する。

### 6.5 Share / Files

現行 `ShareSheetService.share(fileURLs:)` は複数 file URL を渡せる。

次の最小実装は、zip 化ではなく複数 files share でよい可能性が高い。

ただし AirDrop / Files UX は実機確認が必要。

最小:

```text
share items:
  media
  sidecar
  combined-color.cube
  reference-after.jpg
```

将来:

- package folder export
- `.zip`
- `.filmtonepackage`

---

## 7. 主要ファイル読み順

次チャットでは広く探索しない。以下から入る。

### life route / truth

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/life
node scripts/life-route.mjs "Filmtone iOS DaVinci Connect real package export"
./scripts/check-filmtone-ios-truth.sh
```

### current docs

- `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/film-lab-current-index.md`
- `docs/filmtone/ios/filmtone-connect-davinci-v0-spike-verified-2026-04-30-jst.md`
- `docs/filmtone/ios/filmtone-connect-davinci-real-package-export-handoff-2026-04-30-jst.md`（この doc）
- `docs/filmtone/ios/filmtone-connect-for-davinci-feasibility-handoff-2026-04-29-jst.md`（untracked の可能性あり。読むなら live code と照合）
- `apps/capacitor-film-lab-ios/CLAUDE.md`

### DaVinci side

- `apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua`

### iOS export / sidecar / share

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneColorPipeline.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/PhotoLibraryService.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/ShareSheetService.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift`

### shared LUT / state

- `packages/film-lab-core/src/cube-parser.ts`
- `packages/film-lab-core/src/native-bridge.ts`
- `packages/film-lab-core/src/ios-phase0.test.ts`
- `apps/capacitor-film-lab-ios/src/lib/phase0-state.ts`
- `apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx`

---

## 8. 検証計画

### 8.1 Unit / contract

必要に応じて追加:

- sidecar builder test:
  - `package.layout`
  - `package.mediaFilename`
  - `package.referenceAfterFilename`
  - `package.luts.combinedColor`
  - sidecar が LUT data array を含まないこと
- cube serializer test:
  - valid `LUT_3D_SIZE`
  - RGB line count = `size^3`
  - identity cube round trip

既存:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
bun run verify:swift-contract
```

### 8.2 iOS build

Swift / bridge を触ったら:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
bun run build
bun run cap:sync:ios
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

Swift だけなら `cap:sync:ios` は不要だが、bridge / TS を触ったら必須。

### 8.3 DaVinci dry-run

実 package を生成したら:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --dry-run \
  --package /path/to/FilmtoneExport
```

### 8.4 DaVinci実機 import

Resolve を起動:

```bash
open -a "DaVinci Resolve"
```

接続確認:

```bash
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  -l lua \
  -x 'local r=Resolve(); print(r and r:GetVersionString() or "NO_RESOLVE")'
```

期待:

```text
20.3.2.9
```

Workspace Script:

```text
Workspace > Scripts > Filmtone Connect > Import Filmtone Package
```

または `--package` で `fuscript` 実行。

成功条件:

```text
SMOKE_NODE1_LUT=Filmtone Connect/combined-color.cube
SMOKE_TIMELINE_MARKERS>=1
SMOKE_FILMTONE_NOTE_FOUND=true
Gallery still imported or Media Pool fallback works
```

---

## 9. Plan Compliance / Cross-Stream Visibility / Scope Diff / 残タスク

### Plan Compliance

完了済み:

- DaVinci v0 script 実装。
- sidecar parse。
- media import。
- timeline placement。
- node 1 LUT apply。
- marker note。
- reference still Gallery import。
- Resolve 20.3.2.9 実機 smoke。
- verified knowledge doc commit。

未完:

- iOS から real package を生成すること。
- generated `combined-color.cube` の色一致検証。
- generated `reference-after.jpg` の visual reference 検証。

### Cross-Stream Visibility

別作業の dirty Swift files が存在する。特に以下は次タスクと衝突しうる:

- `FilmtoneExportSidecarBuilder.swift`
- `FilmtoneEditorStore.swift`
- `FilmtoneRootView.swift`
- `project.pbxproj`
- `FilmtoneLibrary*` / `FilmtoneSavedLookSheet` 系 untracked files

次チャットはこれらを user/他作業の変更として扱い、必要なら読んで合わせる。revert 禁止。

### Scope Diff

今回の DaVinci v0 は iOS UI / export package 実装を含まない。

次の scope は iOS package export の最小実装のみ。DaVinci script の大型化や UI polishing は scope 外。

### 残タスク

1. live code を読んで、package export を入れる最短経路を決める。
2. `combined-color.cube` serializer / generator を作る。
3. `reference-after.jpg` を export 時に生成する。
4. sidecar に additive `package` block を追加する。
5. media + sidecar + cube + reference を share する。
6. real package を DaVinci v0 script に食わせる。
7. DaVinci 上で node 1 LUT / marker note / reference still / visual parity を確認する。

---

## 10. 最高精度を出せる引き継ぎ詳細プロンプト

以下を次の新規チャットにそのまま貼る。

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/ios/filmtone-connect-davinci-real-package-export-handoff-2026-04-30-jst.md

上記 handoff を入口に、Filmtone Connect for DaVinci の次段階として iOS 側 real package export spike を実装・検証してください。

最重要方針:
- 本質の進行を最優先にしてください。
- 外殻、過剰 QA、issue hygiene、長い手順書化、ASO、UI polish は、主要な package export と DaVinci import が通ったあとだけにしてください。
- 保守的な一般論ではなく、プロダクト品質が最も高くなる判断を優先してください。
- 設計分岐、package contract、LUT 生成範囲、reference still 生成、DaVinci 連携境界は必ず sequential-thinking で考えてください。
- わからない API / DaVinci / Resolve scripting / iOS Files share / LUT format の事実は、記憶で断定せず、local source、DaVinci bundled docs、web search の順で調査してください。
- 複数の独立チェックがある場合は並列で実行してください。
- 既存 dirty files はユーザーまたは他作業の変更として扱い、絶対に revert しないでください。

まず以下を実行してください:

cd /Volumes/SamsungPortableSSDX5001/documents/life
node scripts/life-route.mjs "Filmtone iOS DaVinci Connect real package export"
./scripts/check-filmtone-ios-truth.sh

その後、最小限以下を読んでください:
- docs/guides/film-lab-current-index.md
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/ios/filmtone-connect-davinci-real-package-export-handoff-2026-04-30-jst.md
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/ios/filmtone-connect-davinci-v0-spike-verified-2026-04-30-jst.md
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/CLAUDE.md

live code として以下を確認してください:
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneColorPipeline.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/PhotoLibraryService.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/ShareSheetService.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/packages/film-lab-core/src/cube-parser.ts
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/packages/film-lab-core/src/native-bridge.ts

実装対象:
1. Filmtone iOS export から real package を生成する最小経路
2. `combined-color.cube` 生成
3. `reference-after.jpg` 生成
4. sidecar additive `package` block
5. media + sidecar + cube + reference の share / Files handoff
6. 生成した実 package を DaVinci v0 script に食わせる検証

最小 package:

FilmtoneExport/
  media.mov
  media.mov.filmtone-ios-export-session-v1.json
  combined-color.cube
  reference-after.jpg

sidecar additive field 案:

{
  "package": {
    "layout": "filmtone-connect-package-v1",
    "mediaFilename": "media.mov",
    "referenceAfterFilename": "reference-after.jpg",
    "luts": {
      "combinedColor": "combined-color.cube"
    }
  }
}

禁止事項:
- Sidecar 単体で DaVinci 上の完全再現ができる、と言わない。
- 3D LUT で depth / ray-angle optics / grain / motion blur / halation spread まで完全再現できる、と言わない。
- DaVinci script を package-local absolute LUT path へ戻さない。実機では Resolve LUT tree へ stage + RefreshLUTList + relative path が安定。
- UI polish / zip / DRX / PowerGrade / DCTL / OpenFX / Source+Film 複数 node 分離から始めない。

検証:
- iOS contract / build は該当範囲に応じて `bun run build`, `bun run verify:swift-contract`, `xcodebuild ... CODE_SIGNING_ALLOWED=NO` を実行。
- generated package に対して DaVinci script の `--dry-run` を実行。
- DaVinci Resolve 20.3.2.9 を起動し、real package import を実行。
- 成功条件は node 1 LUT apply、marker note、reference still import、Filmtone export 見た目との visual parity。

成果物として返してください:
- 実装したファイル
- package layout
- sidecar field
- generated cube/reference の確認結果
- DaVinci import 検証ログ
- 残る非 claim / 後段候補

時間がかかってもよいので、正確に推論して進めてください。
```
