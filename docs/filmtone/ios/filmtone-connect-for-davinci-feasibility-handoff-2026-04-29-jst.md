# Filmtone Connect for DaVinci — Feasibility 精査ハンドオフ

- **作成日**: 2026-04-29 JST
- **目的**: 新規チャットで `Filmtone Connect for DaVinci` の実現性を最高精度で精査するための単独入口
- **対象 repo**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- **iOS app**: `apps/capacitor-film-lab-ios`
- **life hub**: `/Volumes/SamsungPortableSSDX5001/documents/life`
- **前提判断**: `Sidecar = Filmtone Connect for DaVinci のためのデータ契約 / manifest / receipt`
- **関連 doc**:
  - `docs/filmtone/ios/filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md`
  - `docs/filmtone/ios/filmtone-ios-v12-release-to-aso-handoff-2026-04-29-jst.md`
  - `docs/filmtone/ios/filmtone-ios-preview-export-color-parity-handoff-2026-04-29-jst.md`
  - `docs/filmtone/ios/filmtone-ios-dual-lut-clear-output-breakage-handoff-2026-04-29-jst.md`
  - `apps/capacitor-film-lab-ios/CLAUDE.md`

---

## 0. この文書の読み方

この文書は、次チャットで「Filmtone Connect for DaVinci は本当に作れるか」を精査するための引き継ぎである。

重要な前提:

- **本質の進行を最優先**する。
- 外殻、過剰 QA、issue hygiene、長い手順書化は、主要な実現性と product claim が固まったあとだけ行う。
- 保守的な一般論ではなく、プロダクト品質が最も高くなる判断を優先する。
- 設計分岐、DaVinci 連携方式、商品名、MVP 境界などは必ず `sequential-thinking` で考える。
- わからない API / DaVinci / Apple / App Store / Resolve scripting の事実は、Gemini または web search、可能ならローカルの DaVinci bundled docs で確認する。
- 記憶ベースで「DaVinci ならできる」「完全再現できる」と断定しない。

---

## 1. 背景

PeekLut が iPhone / iPad 上で「DaVinci Resolve 代替」に近いポジションを取りに来ている。

現行の Filmtone iOS は機能数で PeekLut に勝つ設計ではない。トーンカーブ、マスク、HSL、ヒストグラム、ProRes 出力、バッチ編集などを追うと、Filmtone の強みである物理整合・色管理・軽い ritual 体験が薄まる。

そのため、2026-04-29 の戦略判断では次に転換した。

> PeekLut は "DaVinci の代替" を狙う。Filmtone は "DaVinci の前段" を取る。

この転換の中核になる構想が:

> **Filmtone Connect for DaVinci**

である。

ただし、現時点での正確な理解は次の通り。

```text
Sidecar
  = Filmtone Connect for DaVinci のためのデータ契約
  = export session manifest / receipt / protocol

Filmtone Connect for DaVinci
  = その Sidecar と関連ファイルを読む DaVinci 側 companion
  = Lua / Python script / workflow integration / DCTL / DRX 等のどれか、または複合
```

Sidecar 自体が Connect ではない。Sidecar は Connect が読むための「意味のある書き出し記録」である。

---

## 2. 現行 truth snapshot

### 2.1 Filmtone iOS state

`/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh` を実行済み。

2026-04-29 JST 時点:

| 項目 | 値 |
|---|---|
| repo branch/head | `main @ 4cb2eb60` |
| upstream | `origin/main` |
| ahead / behind | `0 / 0` |
| local Xcode MARKETING_VERSION | `1.2` |
| local build | `1` |
| public App Store version | `1.1` |
| public release date | `2026-04-21T07:00:00Z` |
| public currentVersionReleaseDate | `2026-04-26T03:24:53Z` |
| public URL | `https://apps.apple.com/jp/app/filmtone/id6762564806?uo=4` |

解釈:

- 公開 App Store はまだ `1.1`。
- ローカル Xcode は `1.2 (1)`。
- v1.2 は公開状態とは別軸の候補 / unreleased stream として扱う。
- 新チャットでは必ず再度 truth script を実行すること。

### 2.2 PeekLut state

web / App Store lookup で確認した現行値。

日本 App Store:

| 項目 | 値 |
|---|---|
| App | `写真・動画編集ソフト - PeekLut` |
| Seller | `Lauper Labs, LLC` |
| Version | `2.18.0` |
| Rating | `4.7` |
| Ratings count | `294` |
| Price | `無料 + IAP` |
| currentVersionReleaseDate | `2026-04-29T01:26:29Z` |
| IAP examples | `¥200/week`, `¥3,000/year`, `¥15,000 PeekPro Long` |
| URL | `https://apps.apple.com/jp/app/%E5%86%99%E7%9C%9F-%E5%8B%95%E7%94%BB%E7%B7%A8%E9%9B%86%E3%82%BD%E3%83%95%E3%83%88-peeklut/id6473661560` |

US App Store:

| 項目 | 値 |
|---|---|
| App | `Color Grade Video - PeekLut` |
| Version | `2.18.0` |
| Rating | `4.8` |
| Ratings count | `392` |
| currentVersionReleaseDate | `2026-04-29T01:26:29Z` |
| URL | `https://apps.apple.com/us/app/color-grade-video-peeklut/id6473661560` |

重要:

- PeekLut は既に App Store copy 上で DaVinci Resolve / Final Cut Pro / Adobe Premiere Pro 連携を訴求している。
- LUT export、DCTL compatibility、ProRes export、ProResRAW workflow、Apple Log、HSL、mask、tone curve なども訴求している。
- したがって Filmtone の差別化は単なる「DaVinci 連携」では弱い。
- 差別化の核は **dual-lane color contract + sidecar + reference package + 物理 / depth / optics の意味保持** に置く必要がある。

---

## 3. Filmtone の現行 Sidecar 実装

### 3.1 生成ファイル名

Sidecar は書き出しメディアの隣に置く JSON。

例:

```text
phase0-export.mp4
phase0-export.mp4.filmtone-ios-export-session-v1.json
```

実装:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
  - `schemaID = "filmtone-ios-export-session-v1"`
  - `kind = "filmtone-export-session"`
  - `schemaVersion = 1`
  - `sidecarFilenameSuffix = ".filmtone-ios-export-session-v1.json"`

`sidecarURL(for:)` は raw path に suffix を付ける。メディア拡張子を残すため、Finder / Files で並んでソートできる。

### 3.2 生成タイミング

`FilmtoneExportSession.run()` の書き出し完了後に `writeExportSidecar(...)` が呼ばれる。

重要:

- Sidecar 書き込み失敗は export 失敗にしない。
- 失敗時は `sidecarUri = nil`。
- 成功時は `Phase0ExportResultDTO.sidecarUri` に sidecar の URI が入る。

関連:

- `FilmtoneExportSession.swift`
- `FilmtoneMediaTypes.swift`

### 3.3 現行 JSON shape

概念的な shape:

```json
{
  "kind": "filmtone-export-session",
  "schema": "filmtone-ios-export-session-v1",
  "version": 1,
  "exportedAtIso": "2026-04-24T12:00:00.000Z",
  "appVersion": "1.2",
  "buildNumber": "1",
  "job": "video",
  "device": {
    "model": "iPhone16,2",
    "iosVersion": "17.5"
  },
  "input": {
    "sourceUri": "file:///...",
    "filename": "...",
    "kind": "video",
    "sourceProbe": {},
    "sourceVideoMetadata": {},
    "cameraOptics": {}
  },
  "hdrPolicy": {},
  "look": {
    "presetName": "cinematic",
    "presetVersion": "v1",
    "quickState": {},
    "params": {}
  },
  "lutRefs": {
    "inputLut": {
      "size": 33,
      "intensity": 1.0
    },
    "creativeLut": {
      "size": 33,
      "intensity": 0.72
    }
  },
  "output": {
    "longEdge": 1920,
    "fps": 24,
    "codec": "h264",
    "container": "mp4",
    "preserveAudio": true,
    "degradedDecodePath": false,
    "outputUri": "file:///...",
    "outputWidth": 1920,
    "outputHeight": 1080,
    "fileSizeBytes": 12345678,
    "elapsedMs": 4200,
    "realtimeRatio": 0.35,
    "outputColorProfile": "rec709-sdr-mp4",
    "colorPrimaries": "bt709",
    "colorTransfer": "bt709",
    "colorSpace": "bt709"
  },
  "renderMode": "quality",
  "mezzanine": {
    "used": false,
    "variant": null,
    "profileVersion": null
  },
  "depth": {
    "used": false,
    "source": null,
    "resolutionWidth": null,
    "resolutionHeight": null,
    "renderer": null,
    "framesWithDepth": null,
    "videoDepthSource": null
  }
}
```

実際の `sourceProbe` / `sourceVideoMetadata` / `cameraOptics` / `params` は DTO 全体が入る。

### 3.4 Sidecar が持つ情報

Sidecar が記録するもの:

- 書き出し schema / app version / build
- device model / iOS version
- export timestamp
- source URI / filename / media kind
- source probe
- source video metadata
- camera optics metadata
- HDR preparation policy
- preset name / preset version
- quick state
- Phase 0 params
- input LUT ref
- creative LUT ref
- output codec / container / fps / size
- output color contract
- render mode
- mezzanine usage
- depth usage

### 3.5 Sidecar が意図的に持たない情報

Sidecar は **LUT の full data array を持たない**。

`scripts/swift/test-sidecar-builder.swift` で以下が固定されている。

- sidecar payload は `8KB` 未満を期待。
- `"data":[` を含んではいけない。
- `"data" :` を含んではいけない。
- LUT refs は `size` と `intensity` の summary だけ。

理由:

- JSON を小さく保つ。
- LUT 本体は source project / exported `.cube` を SSOT にする。
- sidecar は「処理レシピと証跡」であり、全素材を内包する archive ではない。

### 3.6 Photos / Share の現行挙動

Photos 保存:

- `PhotoLibraryService` は media のみ Photos に保存する。
- Photos asset は任意 JSON sidecar を隣接保存できない。
- sidecar は app container に残るが、Photos 内には入らない。

Share:

- `FilmtoneEditorStore.shareOutput()` は `mediaURI` と `sidecarURI` を `facade.shareOutput(...)` に渡す。
- `FilmtoneMediaRuntime.shareOutput(...)` は media URL に sidecar URL を追加して share sheet に渡す。
- share 完了後は local export files が discard される。

意味:

- **Pro Tool bridge は Photos 保存では成立しない。**
- Files / AirDrop / iCloud Drive / share package 経由が本命。
- v1.3 以降で `Send to NLE` package を中核に置くべき。

---

## 4. Filmtone Connect for DaVinci の正しい理解

### 4.1 一文定義

> Filmtone Connect for DaVinci は、Filmtone iOS が書き出した media / sidecar / LUT / reference still を DaVinci Resolve に読み込み、Filmtone の pre-grade を DaVinci の finishing workflow に正しく渡す companion tool である。

### 4.2 Sidecar との関係

```text
Sidecar
  = data contract
  = manifest
  = export receipt
  = DaVinci 側が読む説明書

Connect for DaVinci
  = sidecar reader
  = Resolve importer / setup assistant
  = LUT placement helper
  = reference matching helper
```

### 4.3 理想 package

v1.3 以降で目指すべき package:

```text
FilmtoneExport/
  media.mov
  media.mov.filmtone-ios-export-session-v1.json
  source-transform.cube
  film-look.cube
  combined-color.cube
  reference-after.jpg
  reference-before.jpg
```

最小 MVP では以下でよい:

```text
media.mov
media.mov.filmtone-ios-export-session-v1.json
combined-color.cube
reference-after.jpg
```

ただし、Filmtone の差別化を出すなら `source-transform.cube` と `film-look.cube` を分けるほうが強い。

### 4.4 DaVinci 側で Connect が行う想定処理

MVP:

1. User が sidecar JSON または package folder を選択。
2. sidecar を parse。
3. media file を Media Pool に import。
4. timeline / clip を作成、または既存 timeline の選択 clip と紐づけ。
5. `.cube` を Resolve の LUT path に配置 / 検出可能化。
6. Project LUT list を refresh。
7. Color page の selected clip / timeline item に node を作る。
8. Source Transform LUT と Film Look LUT を別ノードとして適用。
9. sidecar の output color profile / source interpretation を note / marker / node label / timeline marker に残す。
10. reference-after still を Gallery / Media Pool / marker note のいずれかで参照可能にする。

MVP の product claim:

> Pre-grade on iPhone. Finish in DaVinci.

言ってよいこと:

- Filmtone の pre-grade package を DaVinci に持ち込める。
- Filmtone の source / look の分離を DaVinci ノードとして保持できる。
- reference still と sidecar で iPhone 上の意図を確認できる。
- LUT 化できる色変換を DaVinci へ渡せる。

言ってはいけないこと:

- DaVinci 上で Filmtone の全処理を完全再現できる。
- Sidecar だけで色が再現できる。
- 3D LUT だけで depth / ray-angle / grain / motion blur / halation spread を正確に再現できる。

---

## 5. 技術的に重要な境界

### 5.1 LUT で表現できる領域

3D LUT で扱いやすいもの:

- source transform
- film look
- color balance
- tone / contrast の一部
- saturation / channel mix の一部
- print matrix 的な color transform

Filmtone の v1.3 P0 ではここを `.cube` として外部化する。

### 5.2 LUT で表現しづらい / 表現できない領域

LUT だけでは正しく表現できないもの:

- depth-aware grading
- ray-angle optics
- 180° shutter physics motion blur
- bloom radius / halation radius / diffusion spread
- spatial vignette
- grain
- temporal trail
- lens softness / radial RGB shift の一部
- source-size / frame-time / optics dependent な処理

これらは sidecar に params / flags / metadata として記録し、DaVinci 側では以下のいずれかで扱う。

- baked media として受け取る。
- reference still で目合わせする。
- node label / marker note に「Filmtone baked effect」として残す。
- 将来 OpenFX / DCTL / Fusion macro で近似する。

ただし、初回 MVP で OpenFX まで踏み込むのは重すぎる可能性が高い。まず scripting + LUT + reference が妥当。

### 5.3 Sidecar と `.cube` の役割分担

```text
.cube
  = DaVinci が直接適用できる color transform

sidecar
  = Filmtone が何をしたかの意味情報
  = .cube の lane 意味
  = source / output color contract
  = non-LUT effects の記録
  = debugging / provenance

reference still
  = DaVinci 側で見た目確認する ground truth
```

### 5.4 完全再現ではなく "handoff bridge"

Filmtone Connect for DaVinci の初期 claim は:

> Filmtone iOS で作った下地を、DaVinci の仕上げ作業に持ち込む。

である。

完全再現 plugin ではない。

最終的に有料 SKU 化するなら:

```text
Filmtone Connect for DaVinci
  v0: Lua/Python importer + LUT setup + notes
  v1: package validator + reference still matching
  v2: DRX / PowerGrade export
  v3: DCTL / OpenFX approximations
```

という段階が自然。

---

## 6. DaVinci Resolve 側の現時点の調査メモ

このチャットでは最小限の web search のみ実施した。新チャットでは必ず再調査すること。

確認済みの範囲:

- DaVinci Resolve には Lua / Python scripting API がある。
- bundled documentation は通常 DaVinci Resolve install 内に存在する。
- script は Console / command line / Workspace Scripts から呼べる。
- API には LUT 関連メソッドが存在する。
- `SetLUT()` の `nodeIndex` は Resolve v16.2.0 以降 1-based という記述を確認。

参照した web source:

- `https://wiki.dvresolve.com/developer-docs/scripting-api`
  - Blackmagic Design bundled scripting docs の mirror とされている。
  - ただし Blackmagic 公式 URL ではない。

新チャットでの重要調査:

1. ローカルに DaVinci Resolve が入っているか。
2. 入っているなら bundled docs を確認する。
   - macOS 例:
     - `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting`
     - `/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so`
3. `SetLUT` / node create / selected clip / timeline item / Media Pool import / Gallery still import / marker note / clip metadata 書き込みが scriptable か。
4. Free 版と Studio 版で scripting の制約があるか。
5. App Store 版 DaVinci Resolve と Blackmagic 配布版で scripting path / permissions が違うか。
6. Resolve 20.x / 19.x の現在 API 差分があるか。
7. DCTL compatibility の現実。
8. DRX / PowerGrade の生成・import が scriptable か。

---

## 7. Feasibility 仮説

### 7.1 High-confidence

以下は実現性が高い。

- Sidecar JSON を parse する。
- Filmtone package folder を選ばせる。
- media を DaVinci に import する。
- `.cube` を所定 LUT folder にコピーする。
- Resolve の LUT list を refresh する。
- selected clip / timeline item に LUT を適用する。
- sidecar の内容を log / note / marker として表示する。
- reference still を同梱し、ユーザーが見比べられるようにする。

### 7.2 Medium-confidence

調査が必要。

- DaVinci の node tree をどこまで安定して script で構築できるか。
- 複数 LUT lane を node label 付きで置けるか。
- clip marker / timeline marker に sidecar summary を入れられるか。
- Gallery still へ reference を入れられるか。
- DRX / PowerGrade を programmatically export / import できるか。
- Mac sandbox / App Store build の制約。

### 7.3 Low-confidence / 後段

初回 MVP から外すべき可能性が高い。

- OpenFX plugin として Filmtone optics を再実装。
- DCTL で depth / motion blur / grain / spatial effects まで再現。
- DaVinci 内で Filmtone の全 shader pipeline を完全再現。
- iOS から DaVinci project を直接生成。

---

## 8. 推奨 MVP

### 8.1 v0 feasibility prototype

目的:

> 手動で export package を用意し、DaVinci script が sidecar を読み、media と LUT を読み込んで、選択 clip に LUT を当てられるかを確認する。

必要物:

- sample media
- sample sidecar
- sample `.cube`
- sample reference still
- Lua または Python script

MVP script がやること:

1. package folder path を受け取る。
2. `*.filmtone-ios-export-session-v1.json` を探す。
3. JSON parse。
4. media path を解決。
5. `.cube` を探す。
6. Resolve に media import。
7. LUT list refresh。
8. selected clip または imported clip に LUT apply。
9. sidecar summary を console に出す。

Success criteria:

- Resolve 上で media が読み込まれる。
- `.cube` が適用される。
- sidecar から output color profile / preset / LUT lane が読める。
- reference still と比較できる状態になる。

### 8.2 v1 product MVP

UX:

```text
DaVinci > Workspace > Scripts > Filmtone Connect > Import Filmtone Package
```

または command line:

```bash
python filmtone_connect_for_davinci.py /path/to/FilmtoneExport
```

出力:

- Media Pool に media
- Timeline clip
- Color nodes:
  - Node 01: Filmtone Source Transform
  - Node 02: Filmtone Film Look
  - Node 03: Filmtone Finish / manual
- Marker / note:
  - Filmtone preset
  - app version
  - output color profile
  - non-LUT effects present
  - depth / mezzanine status
- reference still import or file link

### 8.3 v2 paid SKU candidate

将来:

- `.drx` / PowerGrade generation
- sidecar validator UI
- package integrity check
- color contract warnings
- DCTL approximations for print / tone / source transform
- reference matching panel

商品名:

```text
Filmtone Connect for DaVinci
```

サブコピー案:

```text
Bring iPhone pre-grades into DaVinci Resolve.
```

日本語:

```text
iPhone の下地を、DaVinci の仕上げへ。
```

---

## 9. iOS 側 v1.3 で必要になりそうな変更

Connect の実現性精査と並行して、iOS 側では次が必要になる可能性が高い。

### 9.1 LUT export

Color-only `.cube` export。

優先 lane:

1. `source-transform.cube`
2. `film-look.cube`
3. `combined-color.cube`

注意:

- 「現在の grade 全部を .cube に焼く」と言ってはいけない。
- depth / ray-angle / glow / grain / motion blur は `.cube` 化できない。
- `.cube` は color transform の bridge として扱う。

### 9.2 Sidecar schema public doc

必要:

- schema fields
- optional additive policy
- versioning policy
- unsupported / ignored field policy
- example JSON
- package layout

既存 schemaVersion は `1`。additive optional fields は v1 のまま追加している。

破壊的変更:

- field rename
- type change
- semantics change

これらは v2 schema が必要。

### 9.3 Send to NLE package

Photos 保存では sidecar が保存されないため、bridge 用には package export が必要。

候補:

```text
Send to DaVinci
Send to NLE
Export Package
```

中身:

- media
- sidecar
- LUTs
- reference still

最初は zip でなく folder share でもよいが、AirDrop / Files の UX を要検証。

### 9.4 Reference still

DaVinci 側での目合わせ用。

候補:

- after reference still
- before reference still
- side-by-side contact sheet

初回は `reference-after.jpg` だけでよい。

### 9.5 Sidecar path portability

現行 sidecar の `sourceUri` / `outputUri` は app container URI 前提。

Connect package では:

- package-relative path
- file hash
- media filename
- sidecar adjacent media convention

のどれかが必要。

v1.3 additive field 例:

```json
{
  "package": {
    "layout": "filmtone-connect-package-v1",
    "mediaFilename": "media.mov",
    "referenceAfterFilename": "reference-after.jpg",
    "luts": {
      "sourceTransform": "source-transform.cube",
      "filmLook": "film-look.cube",
      "combinedColor": "combined-color.cube"
    }
  }
}
```

これは additive optional field なので sidecar schema v1 のまま追加可能。ただし public schema doc では明記する。

---

## 10. 重要な落とし穴

### 10.1 「完全再現」claim

禁止。

Filmtone の pipeline には spatial / temporal / depth / optics 処理がある。3D LUT と Resolve standard nodes だけで完全再現できない。

正しい claim:

> Filmtone の pre-grade と色変換を DaVinci finishing workflow に渡す。

### 10.2 Sidecar 単体で完結する誤解

禁止。

Sidecar は LUT data も media data も持たない。Connect は package を読む必要がある。

### 10.3 PeekLut と同じ "LUT export" 競争

禁止。

PeekLut も LUT export / DaVinci / Adobe 連携を訴求している。Filmtone の差別化は LUT export そのものではなく、以下。

- Source Profile lane
- Film Look lane
- sidecar color contract
- source metadata normalizer
- HDR / P3 / Log policy
- depth / optics / physical pipeline provenance

### 10.4 DaVinci API を記憶で断言

禁止。

Resolve scripting は version / distribution / Free vs Studio / preference settings の差がありうる。必ず現行 docs / installed docs / web で確認する。

### 10.5 外殻 UI から着手

禁止。

まずは DaVinci 側で sidecar parse + media import + LUT apply が成立するか。

---

## 11. 新チャットで必ず読む source files

まず life route:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/life
node scripts/life-route.mjs "Filmtone iOS DaVinci Connect Sidecar feasibility"
./scripts/check-filmtone-ios-truth.sh
```

次に最小で読む:

- `docs/guides/film-lab-current-index.md`
- `docs/filmtone/ios/filmtone-connect-for-davinci-feasibility-handoff-2026-04-29-jst.md`
- `docs/filmtone/ios/filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`

実装確認:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneColorPipeline.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/PhotoLibraryService.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift`

必要なら:

- `packages/film-lab-core/src/phase0-schema.ts`
- `packages/film-lab-core/src/native-bridge.ts`
- `packages/film-lab-core/src/cube-parser.ts`
- `packages/film-lab-core/src/ios-phase0.test.ts`

---

## 12. 新チャットでの調査順

1. 現行 truth を確認。
2. Sidecar 実装を live code で再確認。
3. DaVinci Resolve がローカルに入っているか確認。
4. 入っている場合、bundled scripting docs を読む。
5. 入っていない場合、Blackmagic official docs / bundled docs mirror / current API docs を検索。
6. Resolve scripting で以下ができるかを表にする。
   - import media
   - create timeline / append clip
   - select timeline item
   - create color node
   - set LUT
   - refresh LUT list
   - set CDL
   - add marker / note
   - import still / gallery still
   - import / export DRX
   - read/write project setting
7. 最小 viable implementation を選ぶ。
8. `Filmtone Connect for DaVinci v0` の prototype plan を書く。
9. iOS 側 package requirements を返す。
10. "claim language" を決める。

---

## 13. 期待される結論の形

新チャットの成果物は以下。

### A. Feasibility matrix

| 機能 | 実現性 | 根拠 | 初回 MVP | 備考 |
|---|---:|---|---|---|
| sidecar parse | High | local script | Yes | JSON |
| media import | High/Med | Resolve API docs | Yes | 要確認 |
| LUT apply | High/Med | `SetLUT` docs | Yes | nodeIndex |
| reference still | Med | API確認 | Maybe | import or note |
| DRX generation | Low/Med | 要調査 | No | v2 |
| full Filmtone optics | Low | 3D LUT不可 | No | baked / future |

### B. MVP architecture

```text
iOS package export
  -> sidecar + media + LUT + reference
  -> DaVinci script
  -> media import + LUT nodes + notes
```

### C. Implementation spike

1 day / 2 day / 1 week などで現実的に切る。

### D. Product claim

売ってよい文言 / 禁止文言。

---

## 14. 最高精度を出すための引き継ぎ詳細プロンプト

以下を新規チャットにそのまま貼る。

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/ios/filmtone-connect-for-davinci-feasibility-handoff-2026-04-29-jst.md

上記について、Filmtone Connect for DaVinci の実現性を最高精度で精査してください。

最重要方針:
- 本質の進行を最優先にしてください。
- 外殻、過剰 QA、issue hygiene、長い手順書化は、主要な実現性と product claim が固まったあとだけにしてください。
- 保守的な一般論ではなく、プロダクト品質が最も高くなる判断を優先してください。
- 設計分岐、DaVinci 連携方式、MVP 境界、商品 claim は必ず sequential-thinking で考えてください。
- わからない API / DaVinci / Resolve scripting の事実は、記憶で断定せず、ローカルの DaVinci bundled docs、Gemini、web search の順で調査してください。
- 複数の独立チェックがある場合は並列で実行してください。

まず以下を実行してください:

cd /Volumes/SamsungPortableSSDX5001/documents/life
node scripts/life-route.mjs "Filmtone iOS DaVinci Connect Sidecar feasibility"
./scripts/check-filmtone-ios-truth.sh

その後、以下を最小限読んでください:
- docs/guides/film-lab-current-index.md
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/ios/filmtone-connect-for-davinci-feasibility-handoff-2026-04-29-jst.md
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/ios/filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/CLAUDE.md

live code として以下を確認してください:
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneColorPipeline.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/PhotoLibraryService.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift
- /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift

調査対象:
1. DaVinci Resolve 側で Sidecar JSON を読む companion を作る実現性
2. Lua / Python script / DCTL / DRX / OpenFX / Workflow Integration のどれが MVP に最適か
3. DaVinci API で media import, LUT apply, node creation, marker/note, reference still import, DRX import/export が可能か
4. Free 版 / Studio 版 / App Store 版 / Blackmagic 配布版での制約
5. Filmtone iOS 側に必要な package export 仕様
6. Sidecar schema に追加すべき package-relative fields
7. 何を商品 claim として言ってよく、何を言ってはいけないか

特に以下の誤解は禁止です:
- Sidecar 単体で DaVinci 上の完全再現ができる、とは言わない。
- 3D LUT で depth / ray-angle / grain / motion blur / halation spread まで完全再現できる、とは言わない。
- PeekLut と同じ LUT export 競争に寄せない。
- DaVinci API を記憶で断定しない。

成果物として以下を返してください:
- Feasibility matrix
- 推奨 MVP architecture
- DaVinci 側 prototype plan
- iOS 側 package export requirements
- Sidecar schema 追加案
- product claim / non-claim
- 次に実装するなら最初の 1-2 日でやる spike plan

時間がかかってもよいので、正確に推論してください。
```

---

## 15. 結論

ユーザーの認識:

> Sidecar は `Filmtone Connect for DaVinci` をイメージするためのものか？

答え:

> **はい。ただし Sidecar 自体が Connect ではなく、Connect を成立させるためのデータ契約である。**

最初に目指すべき product:

```text
Filmtone Connect for DaVinci
  = media + sidecar + .cube + reference still を読み、
    Filmtone の iPhone pre-grade を DaVinci finishing workflow に渡す companion
```

最初の claim:

```text
Pre-grade on iPhone. Finish in DaVinci.
```

日本語:

```text
iPhone で下地を、DaVinci で仕上げを。
```

これは PeekLut の「DaVinci 代替」とは別カテゴリであり、Filmtone の Sidecar / dual-LUT / color contract / physical pipeline provenance を活かせる方向である。
