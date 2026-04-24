# Filmtone Metadata-Driven Export Quality Plan

Last updated: 2026-04-24
Authoring context: Codex desktop session
Primary repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
Scope: `apps/desktop-film-lab-batch`, shared `film-lab-core` metadata contracts, iOS parity notes where relevant

## 1. 目的

この文書は、入力動画 metadata を使って Filmtone の export 品質を改善するための全体計画です。

目的は metadata の表示や保持ではありません。信頼できる入力 metadata を使い、まず客観的に誤りやすい export 挙動を直し、その後に metadata-assisted な品質改善を小さく安全に積み上げます。

## 2. 基本方針

Filmtone は metadata を「撮影・コンテナ由来の証拠」として扱います。metadata を、ユーザーの creative intent を上書きする自動判断として扱いません。

最初に狙うべき成果は correctness improvement です。

- orientation / display geometry を正しく扱う
- SDR BT.709 出力へ固定する前に HDR / color-managed source を検出する
- frame timing の判断を説明可能にする

FOV-aware optical finish のような creative adaptation は、bounded かつ reversible にします。lens distortion、rolling shutter、gyro stabilization のような物理補正は calibrated profile と timed sensor stream が必要です。v1 の自動挙動には入れません。

## 3. 現状の metadata surface

Desktop probe は現在 `ffprobe -v error -show_streams -show_format -of json` を実行しています。

renderer へ渡っている normalized subset は以下です。

- source dimensions
- duration
- audio presence
- video codec
- source frame-rate trust result
- file size
- `cameraOptics`

`cameraOptics` が現在持てる情報は以下です。

- provenance: `metadata`, `assumed`, `manual`
- intrinsics: `fxPx`, `fyPx`, `cxPx`, `cyPx`
- FOV: `fovXDeg`, `fovYDeg`
- 35mm focal equivalent
- camera make / model
- lens model

ffprobe から取得可能だが、まだ Filmtone の first-class metadata になっていない情報は以下です。

- full stream tags / format tags
- full `side_data_list`
- Display Matrix / rotation
- color range, matrix, transfer, primaries
- mastering display metadata / content light metadata
- timecode / metadata tracks
- GoPro GPMF や CAMM 系の vendor timed telemetry tracks

主な現行実装の参照先:

- Desktop ffprobe entry: `apps/desktop-film-lab-batch/electron/main.ts`
- optics derivation: `apps/desktop-film-lab-batch/electron/video-export-camera-optics.ts`
- ffmpeg export args: `apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.ts`
- sidecar schema: `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts`
- shared bridge type: `packages/film-lab-core/src/native-bridge.ts`

## 4. 設計ガードレール

### 4.1 input LUT と capture metadata を混同しない

現状の `camera profile` は input-transform / input-LUT selection です。optical / capture metadata とは分離します。

分離すべき概念:

- input transform: camera profile UI、input LUT、Log-to-Rec.709 transform
- capture metadata: camera make/model、lens model、focal length、FOV、intrinsics、exposure-like tags
- export policy: `source is HDR, prepare SDR mezzanine before WebGL render` のような派生判断

camera make/model だけで S-Log3、V-Log、Apple Log、custom input LUT を自動選択しません。自動化してよいのは、PQ / HLG transfer characteristics のように source signal が明確な場合に限ります。

### 4.2 sidecar と container の正本を分ける

sidecar を正本にするもの:

- grade params
- input / creative LUT references
- manual metadata overrides
- full normalized `cameraOptics`
- Filmtone export 時に決めた export policy
- QA / 再現性のための normalized metadata snapshot

source container から再 probe するもの:

- dimensions, duration, codec, audio presence
- stream / format tags
- side data
- display matrix / rotation
- color fields / HDR side data
- frame-rate and timing evidence
- metadata track inventory

source file が変わった場合は container を再 probe します。古い sidecar を別 source file の truth として扱いません。

### 4.3 timed metadata track は安易に copy しない

Filmtone export は frame timing、resolution、crop、orientation を変える可能性があります。gyro、accelerometer、GPS、timecode、vendor telemetry のような timed metadata tracks は、rendered export へ盲目的に copy しません。

まず inventory だけを取り、必要なら sidecar に安全な summary を保存します。将来 copy / transform する場合は、rendered frame timing との整合を設計してから行います。

## 5. Priority roadmap

### P0-A: Display geometry / rotation の正規化

Impact: high
Effort: low to medium
Risk: medium

現状のリスク:

- `cameraOptics` derive は Display Matrix rotation を見て display dimensions を作っている。
- 一方で export dimension selection は probe width/height を source size として使う。
- portrait / rotated source で optics-derived geometry と export geometry がズレる可能性がある。

目標:

- ffprobe JSON から `rawWidth`, `rawHeight`, `rotationDeg`, `displayWidth`, `displayHeight` を正規化する。
- user-visible frame の export sizing には display dimensions を使う。
- decoder / diagnostics 用には raw dimensions も残す。

最小実装:

- pure helper を追加する。
  - `deriveVideoDisplayGeometryFromFfprobeStream(stream): SourceDisplayGeometry`
- desktop probe result に optional `sourceVideoMetadata.display` を追加する。
- synthetic ffprobe stream unit test を追加する。
  - no rotation
  - Display Matrix 90
  - Display Matrix 270
  - malformed rotation
  - square video

完了条件:

- 既存 camera optics tests が通る。
- rotated source の export sizing が display dimensions を使う。
- portrait / rotated fixture または synthetic integration test で aspect swap regression がない。

### P0-B: Source color / HDR classification

Impact: high
Effort: medium
Risk: low for classification, high for automatic tone mapping

現状のリスク:

- Desktop export は BT.709 limited-range output metadata を固定で付ける。
- proxy / mezzanine path も BT.709 前提で normalize している。
- PQ / HLG / BT.2020 source は decode / convert が環境依存になりやすい。
- iOS 側は pixel-buffer transfer metadata に基づく HDR-to-SDR handling を持っており、Desktop の policy visibility が弱い。

目標:

- source color metadata を normalized object として抽出する。
- source を `sdr-bt709`, `hdr-pq`, `hdr-hlg`, `wide-gamut-unknown`, `unknown` に分類する。
- first patch では pixel を変えない。policy を tests / logs / sidecar から見えるようにする。

最小実装:

- pure helper を追加する。
  - `deriveSourceColorMetadataFromFfprobeStream(stream): SourceColorMetadata`
  - `classifySourceColorForExport(metadata): SourceColorClass`
- 対象 fields:
  - `color_range`
  - `color_space`
  - `color_transfer`
  - `color_primaries`
  - mastering display side data presence
  - content light side data presence
- unit test を追加する。
  - BT.709 SDR
  - PQ / `smpte2084`
  - HLG / `arib-std-b67`
  - BT.2020 without explicit transfer
  - missing metadata

完了条件:

- classification が deterministic。
- first patch では既存 export args を変えない。
- source が HDR / unknown と判定された理由を debug metadata から説明できる。

### P0-C: Explicit HDR-to-SDR preparation path

Impact: high for HDR camera footage
Effort: medium to high
Risk: high without real fixtures

前提:

- P0-B が先に入っている。
- PQ と HLG の real sample が最低 1 本ずつある。

目標:

- 現在の SDR BT.709 H.264 export へ向けて、HDR input を deterministic な SDR source に準備してから WebGL render path に渡す。
- browser / platform の implicit tone mapping に依存しない。
- double tone mapping を避ける。

初期方針:

- HDR source は FFmpeg SDR mezzanine/proxy preparation path へ送る。
- source color classification で branch を決める。
- final output は BT.709 limited として tag する。

実装メモ:

- まず full filter chain ではなく policy helper から始める。
  - `deriveDesktopHdrPreparationPolicy(sourceColor): HdrPreparationPolicy`
- その後、fixture-backed tests 付きで 1 branch ずつ wire する。
- local FFmpeg build が必要 filter を持つか確認する。

完了条件:

- HDR fixture export が source preview expectation に対して washed-out / clipped にならない。
- SDR source は HDR preparation path に入らない。
- tone mapping 後の output metadata が SDR BT.709 になる。

### P1-A: Normalized source metadata の sidecar 保存

Impact: medium
Effort: low to medium
Risk: low

目的:

- export decision を再現可能にする。
- raw ffprobe JSON を保存せず、将来の debugging に必要な情報だけを残す。

目標:

- sidecar schema に optional `input.sourceVideoMetadata` を追加する。
- raw ffprobe JSON ではなく normalized metadata を保存する。
- privacy-safe で export policy / QA に必要な fields だけに絞る。

推奨 fields:

- display geometry
- source color metadata / classification
- frame-rate trust data
- codec family
- metadata track inventory by handler/codec/type
- camera optics snapshot

完了条件:

- old sidecars が import できる。
- new sidecars で過去 export decision を説明できる。
- source file がある場合、source facts は re-probe が優先される。

### P1-B: Frame timing / VFR policy

Impact: medium
Effort: medium
Risk: medium

現状:

- Export は 24fps CFR 固定。
- source frame reuse は source frame-rate evidence が trusted の場合だけ有効。
- duration-based frame count は simple / deterministic。

目標:

- 24fps は default product behavior として維持する。
- VFR / `avg_frame_rate` と `r_frame_rate` mismatch の diagnostics を強化する。
- product decision なしに automatic source-fps export は追加しない。

最小実装:

- probe metadata に以下を追加する。
  - `avg_frame_rate`
  - `r_frame_rate`
  - parsed values
  - trust reason
- known mismatch の unit test を追加する。
- export log に VFR/CFR decision を簡潔に出す。

optional later work:

- 明示的な `match source frame rate` export mode。
- motion aesthetic と file size が変わるため、UI / product review 後に入れる。

完了条件:

- normal 24/30/60 CFR files の挙動が変わらない。
- untrusted frame-rate case を sidecar / debug metadata から説明できる。

### P2-A: FOV / focal-length-aware optical recommendations

Impact: medium
Effort: low to medium
Risk: medium creative side effects

目的:

- reliable optics metadata を suggested finishing に使う。
- physical correction ではなく、optical finish の推奨に留める。
- user control と deterministic rendering を維持する。

目標:

- `cameraOptics.source === "metadata"` または `"manual"` の場合だけ bounded recommendation を出す。
- `source === "assumed"` では何もしない。
- recommendation は user apply 時だけ optical-finish lanes を変更する。

変更を許可する lanes:

- diffusion
- halation
- bloom
- cross filter
- RGB shift
- lens softness
- vignette は product direction が optical finish として許容する場合のみ

最小実装:

- pure helper を追加する。
  - `deriveOpticalMetadataRecommendation(cameraOptics, currentParams): OpticalMetadataRecommendation | null`
- unit test を追加する。
  - wide FOV
  - normal FOV
  - telephoto / narrow FOV
  - missing FOV
  - assumed optics
  - manual optics

ガードレール:

- input LUT を変えない。
- lens distortion correction をしたと見せない。
- patch magnitude を小さくする。
- rationale は numeric metadata score ではなく human-readable にする。

完了条件:

- recommendation patch が deterministic / bounded。
- 既存 scene-aware optical recommendation behavior を壊さない。
- manual user edits が常に優先される。

### P2-B: Camera / lens profile research

Impact: medium to high if done correctly
Effort: high
Risk: high

これは immediate implementation item ではありません。

調査項目:

- どの camera/lens combinations が profile variant を識別できるだけの metadata を持つか。
- Filmtone が calibration database にならずに小さな profile set を維持できるか。
- Apple / Sony / GoPro / Insta360 の sample fixtures を用意できるか。
- Filmtone にとって profile output がどこに効くか。
  - color policy
  - optical recommendation
  - crop safety
  - decode path

実装しないもの:

- make/model だけの distortion correction
- generic camera model だけの rolling shutter correction
- camera model からの automatic LUT selection

implementation に進む条件:

- supported family ごとに最低 3 本の real fixtures。
- versioned profile format。
- unsupported mode の fallback strategy。
- visual QA protocol。

### P3: Gyro / IMU / rolling shutter track inventory

Impact: high in theory
Effort: high
Risk: high

Filmtone が motion-metadata processing へ意図的に広げるまでは、inventory-only phase とします。

外部調査からの前提:

- Gyroflow は logged motion data、lens calibration、rolling shutter correction、timestamp-based calculations を組み合わせて stabilization quality を上げる。
- GoPro GPMF は MP4 metadata track として telemetry を保存する。
- CAMM は stabilization / rolling shutter workflows 向けの camera motion metadata track を定義する。

Filmtone v1 の対象:

- timed metadata tracks の存在を検出する。
- sidecar に安全な inventory だけを記録する。
- rendered export へ copy / transform しない。
- stabilization / rolling-shutter correction は実装しない。

完了条件:

- GoPro-like GPMF file と CAMM-like file を telemetry-containing source として識別できる。
- Filmtone export behavior は変えない。
- sidecar は raw telemetry payload ではなく track presence/type だけを記録する。

## 6. Proposed data model additions

名前は仮です。実装時は既存 TypeScript naming に合わせます。

```ts
export type SourceDisplayGeometry = {
  rawWidth: number;
  rawHeight: number;
  displayWidth: number;
  displayHeight: number;
  rotationDeg: 0 | 90 | 180 | 270 | null;
  source: "ffprobe-side-data" | "ffprobe-tags" | "raw";
};

export type SourceColorMetadata = {
  colorRange: string | null;
  colorSpace: string | null;
  colorTransfer: string | null;
  colorPrimaries: string | null;
  hasMasteringDisplayMetadata: boolean;
  hasContentLightMetadata: boolean;
};

export type SourceColorClass =
  | "sdr-bt709"
  | "hdr-pq"
  | "hdr-hlg"
  | "wide-gamut-unknown"
  | "unknown";

export type SourceVideoMetadata = {
  display: SourceDisplayGeometry;
  color: SourceColorMetadata;
  colorClass: SourceColorClass;
  timing: {
    avgFrameRate: string | null;
    rFrameRate: string | null;
    sourceFrameRate: number | null;
    sourceFrameRateTrusted: boolean;
    trustReason: string;
  };
  metadataTracks: Array<{
    index: number;
    codecType: string | null;
    codecName: string | null;
    handlerName: string | null;
    tagKeys: string[];
  }>;
};
```

## 7. Test strategy

最初は pure unit tests から始めます。UI や export pipeline rewiring から始めません。

必須 test groups:

- ffprobe display geometry normalization
- ffprobe color metadata classification
- sidecar schema backward compatibility
- sidecar roundtrip for normalized source metadata
- FFmpeg arg behavior unchanged before tone-map wiring
- HDR policy builder once P0-C begins
- optical metadata recommendation helper once P2-A begins

fixture policy:

- P0-A、P0-B、P1-A、P1-B は synthetic ffprobe JSON で十分。
- P0-C で pixels を変える前に real video fixtures が必要。
- Gyro / GPMF / CAMM は container structure が重要なため、real files または sanitized small fixtures が必要。

## 8. Rollout order

推奨 implementation sequence:

1. P0-A display geometry helper and probe metadata。
2. P0-B color metadata helper and classification。pixel changes なし。
3. P1-A sidecar support for normalized source metadata。
4. P1-B frame timing diagnostics。
5. P0-C HDR-to-SDR preparation path。fixture-backed tests 後。
6. P2-A optical metadata recommendations。opt-in。
7. P2-B profile research。
8. P3 timed telemetry inventory。

この順序なら、metadata plumbing と creative changes を混ぜず、各 step を独立して検証できます。

## 9. Non-goals

first implementation wave では以下を含めません。

- gyro stabilization
- rolling shutter correction
- physical lens distortion correction
- automatic source-fps export
- automatic camera-profile / Log LUT selection from make/model
- raw ffprobe JSON in sidecar
- telemetry tracks の rendered export への copy

## 10. External references

- Gyroflow overview: https://docs.gyroflow.xyz/app
- Gyroflow supported cameras: https://docs.gyroflow.xyz/app/getting-started/supported-cameras
- Gyroflow GoPro notes: https://docs.gyroflow.xyz/app/getting-started/supported-cameras/gopro
- Gyroflow Sony notes: https://docs.gyroflow.xyz/app/getting-started/supported-cameras/sony
- FFprobe documentation: https://ffmpeg.org/ffprobe-all.html
- FFmpeg filters documentation: https://www.ffmpeg.org/ffmpeg-filters.html
- GoPro GPMF parser: https://github.com/gopro/gpmf-parser
- Google CAMM specification: https://developers.google.com/streetview/publish/camm-spec
- Apple Stereo Video ISOBMFF Extensions: https://developer.apple.com/av-foundation/Stereo-Video-ISOBMFF-Extensions.pdf

