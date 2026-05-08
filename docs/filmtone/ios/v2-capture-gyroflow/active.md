# Active — M12 Advanced Capture Controls

Status: **S12-A 設計ロック / S12-B 着手前**
(2026-05-08 JST)

M11 archive 後の次 milestone。short-form review 形式 — 長い検討 doc は
書かず、code に入れる判断だけを残す。

## 既に存在する土台(再実装しない)

- **lens swap の plumbing**: `FilmtoneCaptureLensCatalog` が rear lens
  を enumerate + `findContractFormatIndex(on:)` で M10 baseline
  (4K24 / Apple Log 2 / ProRes 422 HQ / cinematicExtendedEnhanced) を
  満たす format index に既に絞り込み済。`prepare(lens:)` も per-lens
  reconfig 完備、`FilmtoneCaptureView.lensSelector` pill row + recording 中
  disable も済(S8-B)
- **capture-package.json schemaVersion bump**: `currentSchemaVersion = 2`
  は M11 で既に bump 済。M12 は **forward-compat field 追加のみ**(別 bump
  不要)
- **M11 capture-Look chip strip / live preview rebuild**: 触らない

## S12-A — 着手前に固定する判断(全部 ロック済)

### lens 表示
- primary: `0.5× / 1× / 2× / 5×` の倍率
- subtext: 必要なら 10pt で `Ultra Wide / Wide / Tele`
- mapping は deviceType + 実機 zoom factor から runtime 解決
  (iPhone 17 Pro は tele = 5×、別機種は 2× / 3× がありうる)。
  `displayName(for:)` を捨て、`magnificationLabel(for:device:)` /
  `canonicalSubtext(for:)` を新設

### 露出補正(EV bias)
- ±3 stop 連続、`setExposureTargetBias(_:)` 直結
- exposure auto モード時のみ surface 上に表示、manual 時は隠す
- UI: 縦 slider(右辺、record button の上)、tap-and-hold で 0 stop に reset
- 値は `exposureBiasEV: Double` で package 永続化

### tap-to-focus / tap-to-meter
- `previewLayer` の tap gesture を normalized point に変換
- `focusMode = .autoFocus` + `focusPointOfInterest = pt`
- `exposureMode = .autoExpose` + `exposurePointOfInterest = pt`(auto 時のみ)
- tap 位置に 64pt の reticle、0.6s で fade-out
- manual exposure 時は tap-to-focus のみ実行(point-of-interest は focus に
  だけ、exposure は触らない)
- 値は `focusPointNormalized` / `exposurePointNormalized` で package 永続化
  (auto モード時の最後の tap、または明示 reset で nil)

### WB lock
- 「auto / locked」の 2 モード segmented(EV slider 隣接)
- locked 切替時に現在の `deviceWhiteBalanceGains` を sample →
  `setWhiteBalanceModeLocked(with:)`
- auto 復帰で `.continuousAutoWhiteBalance`
- 値は `whiteBalanceLock: { mode, redGain, greenGain, blueGain }?` で永続化

### manual exposure (ISO + shutter)
- auto / manual トグル(WB lock とは別 row、EV slider 上方)
- manual 切替時:
  - 直前の auto 状態の `device.iso` / `device.exposureDuration` を
    inherit
  - 24fps の shutter cap (1/24s = 41.67ms) と active format の
    `min/maxISO`、`min/maxExposureDuration` で clamp
  - 180° shutter (1/48s ≈ 20.83ms) に近い場合(±1ms)slider に marker
- manual 中の調整: ISO slider + shutter slider、`setExposureModeCustom(
  duration:iso:)` で連続 apply
- manual 中も tap-to-focus は有効、tap-to-meter は無効
- auto 復帰で `.continuousAutoExposure`
- 値は `exposureMode: "auto" | "manual"` + `manualISO: Double?` +
  `manualShutterDurationSeconds: Double?` で永続化

### lens swap の package 永続化
- `selectedLens: { deviceTypeRaw, magnificationLabel, formatIndex }`
  を package に追加。S8-B では package に乗っていない(`lens` は
  capture session 内 ephemeral)— M12 で永続化開始

### control surface の record 中可否
- lens swap: 不可(既存通り、teardown が走るため)
- EV bias / tap / WB lock 切替 / manual ISO / manual shutter:
  **可**(`AVCaptureDevice.lockForConfiguration()` で seamless)
- 録画中の auto ↔ manual mode toggle: **不可**(画が急変するため
  pre-record fix policy)。録画開始時の mode を package に固定

### editor 側影響
- `adoptCaptureResult` は触らない。capture metadata は package
  永続化のみで editor state には書き戻さない

## サブステージ(順序)

| Stage | 範囲 | 期待粒度 |
|---|---|---|
| **S12-B** | lens label refactor — `magnificationLabel(...)` + subtext + selectedLens の package 永続化 | 30〜45 min |
| **S12-C** | EV bias slider + tap-to-focus / tap-to-meter + reticle + auto モード package 永続化 | 60〜90 min |
| **S12-D** | WB lock segmented + package 永続化 | 30〜45 min |
| **S12-E** | manual ISO/shutter mode + slider + clamp + 180° marker + package 永続化 | 90〜120 min |
| **S12-F** | device verify(wide-auto / wide-manual / tele-auto / ultraWide-auto の master truth gate × M11 verify script PASS、capture-package.json field 全揃い) | 60 min |

## Verify(各 stage 終了時)

- xcodebuild iOS Simulator generic Debug = `BUILD SUCCEEDED`
- 該当 stage の package field が round-trip(encode → decode → equal)
- S12-F のみ実機 4 通り × `verify-m11-capture-master.sh` PASS

## Out of scope(M12 範囲外、別 lane)

- audio capture / `NSMicrophoneUsageDescription`
- variable-fps / slow-motion(24p 固定維持)
- focus peaking / exposure zebra overlay(honest preview lane)
- 録画中の lens swap / mode switch
- exposure / focus / WB の RAW metadata sidecar
- 1-button "AE/AF Lock" 統合 UI

## Unexpected / Follow-up

(stage 進行中に出た差し込み・後で見る項目をここに追記)
