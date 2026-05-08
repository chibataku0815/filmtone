# Active — M12 Advanced Capture Controls

Status: **S12-A〜E PASS / S12-F partial PASS — product-sufficient evidence で M12 closeout**
(2026-05-08 JST)

S12-A 設計ロック → S12-B lens label refactor → S12-C EV bias / tap
focus+meter / reticle → S12-D WB lock → S12-E manual ISO/shutter +
180° marker → S12-F partial device verify(wide-auto full PASS、
wide-manual package field PASS、tele/ultraWide deferred as non-blocking)。
M12 closeout 実施。

## S12-F Outcome(2026-05-08, partial PASS / product sufficient)

実機 iPhone 17 Pro #7(`3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`) /
iOS 26.4 で device build → install 後、owner 操作で 4-profile matrix
を試行。広範な lens 網羅検証を取りにいくのは外殻寄りで、product
として M12 が壊れていないかの本質シグナルが取れた段階で closeout 判断
(owner 明示)。

| profile | 取得状態 | gate |
|---|---|---|
| `wide-auto` (`c4c8ef93`, 8.33s, Stone Look, internal storage) | master.mov を sandbox 経由で pull、`scripts/verify-m12-capture-master.sh wide-auto` 全 OK | **PASS** — codec=`apch` / pix_fmt=`yuv422p10le` / 3840×2160 / 24/1、package field 全項目 expected |
| `wide-manual` (`95272ca2`, 2.96s, external SSD) | package 取得 — `manualISO=1212.92` / `manualShutterDurationSeconds≈0.025003s (≈1/40s, 24fps cap 内)` / `manualInheritedFromAuto=true`。WB を Locked に切替忘れ(operator miss)、master は SSD 上 / iPhone userfsd マウント中で Mac 不可視 | **partial — manual ISO/shutter package persist は evidenced**、master truth と WB locked は未 evidence |
| `tele-auto` | 未録画 | **deferred(non-blocking)** |
| `ultraWide-auto` | 未録画 | **deferred(non-blocking)** |

### Closeout 判断(owner 明示)

> M12 PASS with product-sufficient evidence: advanced controls landed,
> wide-auto master truth passed, manual ISO/shutter package persisted;
> broad lens matrix deferred as non-blocking.

理由:

- M12 lens swap plumbing は **S8-B(M10)既存** で、S12-B は表示
  ラベル(`magnificationLabel(for:device:)`)と package 永続化
  (`lensMagnificationLabel` / `lensFormatIndex`)を足しただけ。
  lens 切替経路自体は M10 baseline で実機検証済 — `tele-auto` /
  `ultraWide-auto` は再検証 scope 外で OK
- wide-auto で master truth(`apch` / Apple Log 2 / 4K24 /
  cinematicEE)が M10 baseline 維持されている事を実機 ffprobe で
  確認済。M12 制御 stack を積んでも codec / colorspace / fps /
  pix_fmt は壊れない、という最重要シグナルは取れた
- wide-manual の master が SSD 上で Mac から read できないのは
  iOS userfsd の挙動(同時マウント不可)で、M12 product としては
  blocker ではない
- WB を Locked にしなかったのは UI bug ではなく operator miss

## S12-E Outcome(2026-05-08, commit `b0b33c2e`)

manual exposure (ISO + shutter) を実装、auto/manual segmented で
切替。manual 切替時は直前の auto reading
(`device.iso` / `device.exposureDuration`) を inherit、
`setExposureModeCustom(duration:iso:)` で ISO + shutter duration を
直接制御。slider range は active format
(`minISO..maxISO` / `minExposureDuration..maxExposureDuration`)から
動的、24fps cap で `min(format.maxExposureDuration, 1.0/24)` を
shutter 上限に固定。180° shutter (1/48s) は黄色 tick marker で表示
(±1ms 以内で readout も yellow 化)。manual 中は EV slider /
tap-to-meter を hide / no-op、tap-to-focus は残す。`inheritedFromAuto`
flag で「auto 値そのままロック」と「明示的に追い込み」を区別、
`enterManualExposure` は idempotent。capture-package に `manualISO` /
`manualShutterDurationSeconds` / `manualInheritedFromAuto` を additive
optional で追加(schemaVersion 2 維持)。xcodebuild iOS Simulator
Debug = `BUILD SUCCEEDED` 0 warning / 0 error。実機 verify は S12-F
で wide-manual package side が PASS(master/WB は上記の通り未 evidence)。

## S12-D Outcome(2026-05-08, commit `1f206596`)

WB の auto / locked segmented を追加。Locked 切替時に
`device.deviceWhiteBalanceGains` を sample →
`setWhiteBalanceModeLocked(with:)`。auto 復帰で
`.continuousAutoWhiteBalance`。**判断**: locked 時の R/G/B gains だけを
package に永続化、auto 時の瞬間 gains は drift するので persist しない
(memory `feedback_check_ios_canonical_for_veil_look_parity` 路線)。
schemaVersion 2 維持(WB 4 field は additive optional)。

## S12-C Outcome(2026-05-08, commit `db36328e`)

EV bias slider(±3 stop、`setExposureTargetBias(_:)`)、tap-to-focus
(focus point 常時)、tap-to-meter(exposure point は auto 時のみ)、
64pt reticle(0.6s fade-out)を実装。focus / metering / EV bias を
capture-package に永続化。

## S12-B Outcome(2026-05-08, commit `a6b94e99`)

lens 表示を `0.5× / 1× / 2× / 5×` の倍率主体に refactor。
`magnificationLabel(for:device:)` + `canonicalSubtext(for:)` を新設、
`displayName(for:)` は legacy 用に残置。capture-package に
`lensMagnificationLabel` / `lensFormatIndex` を additive optional で
追加。

## S12-A — 着手前に固定した判断(全部 ロック済)

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
