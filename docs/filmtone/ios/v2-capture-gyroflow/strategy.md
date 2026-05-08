# Filmtone iOS V2 Capture / Gyroflow Strategy

Date: 2026-05-07 JST

## Placement

This directory is the current source of truth for the Filmtone iOS V2
capture / Gyroflow lane:

```text
docs/filmtone/ios/v2-capture-gyroflow/
├── strategy.md
├── active.md
└── archive/
```

Archived feasibility evidence remains read-only:

```text
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-v2-capture-gyroflow-realtime-preview-feasibility-2026-05-01-jst.md
```

## Final Goal

Make Filmtone useful enough for the owner to capture, grade, stabilize, finish,
and reuse in a real personal workflow.

This is not an App Store acquisition lane. Growth work is optional and
downstream. The core product work is capture truth, motion-data truth,
color-preview truth, and fast finishing.

## Measurable Done Conditions

V2 is done when the owner can repeatedly complete this loop:

1. Record a 30-60 second rear-camera clip inside Filmtone.
2. Use Apple Log or Apple Log 2 only when the device proves support for it.
3. Record gyro and accelerometer samples across the full clip duration.
4. Export `.mov`, `.gcsv`, and Filmtone sidecar files together.
5. Load `.mov + .gcsv` in Gyroflow and align sync without a new manual guess
   for every clip.
6. Open the same clip immediately in the existing Filmtone editor.
7. Apply Source Profile, Look, optical effects, quick adjustments, and export.
8. Confirm preview and export are close enough that preview decisions are not
   misleading.
9. Finish at least three owner clips that would otherwise have been shot
   outside Filmtone.

## Milestones

### M1 - Capability Probe

Goal:

Enumerate the owner device's real capture capabilities before building any
recording path.

Done:

- A capability JSON is produced from a real device.
- At least one rear-camera video mode is visible.
- Apple Log / Apple Log 2 support is shown only when runtime-reported.
- Unsupported modes are absent or disabled, not inferred.
- The probe does not start recording and does not add privacy keys unless the
  runtime path proves permission is required.

### M2 - Video-Only Writer Smoke

Goal:

Prove Filmtone can write one short video in the selected mode before motion or
Gyroflow work exists.

Done:

- A 5-10 second `.mov` opens normally.
- Video diagnostics include first / last PTS, frame count, dropped-frame count,
  selected format, selected color space, fps, dimensions, and writer status.
- `NSCameraUsageDescription` exists before any capture session is started.
- The selected codec follows the codec policy in Known Constraints.
- Rotation/orientation is pinned and recorded in diagnostics.
- Video stabilization is forced off when controllable and recorded when not.

Dependency:

- M1.

### M3 - Motion-Only Recorder Smoke

Goal:

Prove Core Motion sample delivery is stable enough before combining it with
video recording.

Done:

- A 10 second motion diagnostic file is produced.
- Gyro and accelerometer samples cover the requested duration.
- Median interval and max timestamp gap are visible.
- `NSMotionUsageDescription` exists before motion recording is requested.
- Raw gyro and raw accelerometer APIs are used; fused device-motion samples are
  not used for Gyroflow data.

Dependency:

- M1.

### M4 - Combined Timing Smoke

Goal:

Collect video PTS and Core Motion timestamps in the same recording session with
enough metadata to attempt mapping.

Done:

- A 30 second `.mov` and combined diagnostics are produced.
- Motion samples cover the full video duration plus a small margin.
- First / last video PTS and first / last motion timestamps are present.
- Offset mapping is explicit enough to start `.gcsv` generation.
- Diagnostics include the timestamp anchor needed to map video PTS and Core
  Motion timestamps.

Dependencies:

- M2.
- M3.

### M5 - Gyroflow `.gcsv` Proof

Goal:

Prove captured motion data can become a Gyroflow-readable sidecar.

Done:

- Package folder contains `.mov`, `.gcsv`, and diagnostics.
- Gyroflow loads the video and sidecar.
- A basic sync / optical-flow check can align the clip.
- One simple handheld pan stabilizes without obvious phase error.
- Rolling-shutter coefficient is recorded as device-once package metadata once
  it is dialed in.

Dependency:

- M4.

### M6 - AVFoundation Stabilization Smoke

Goal:

Decide whether AVFoundation built-in video stabilization is acceptable as
Filmtone capture-time stabilization on the M5-A locked format, before
committing to a custom Filmtone stabilization library.

Done:

- The M5-A locked format survives mode probing — `formatIndex`, `pixelFormat`,
  `colorSpace`, `dimensions`, `fps`, and writer codec are unchanged after a
  non-`.off` `preferredVideoStabilizationMode` is set.
- Diagnostics include the supported-modes set probed against the full iOS 26
  `AVCaptureVideoStabilizationMode` enum, the chosen preferred mode, and the
  observed active mode after `startRecording`.
- `activeVideoStabilizationMode != .off` is asserted as a smoke gate when the
  requested mode was non-`.off`. No silent fallback.
- The recorded `.mov` first video track FourCC is read from the file via
  `AVURLAsset` and matches the requested writer codec. No silent ProRes →
  HEVC writer downgrade.
- Apple Log 2 is preserved (`activeColorSpace.rawValue == 4`) after recording.
- Owner visual A/B (off vs. on, single 30s pan or handheld walk) judged at
  owner-quality bar.

Dependency:

- M5.

(Outcome: PASS on iPhone 17 Pro / iOS 26.4.2; commit `3968eafd`; findings
in `archive/2026-05-07-m6-avfoundation-stabilization-smoke.md`.
`cinematicExtendedEnhanced` accepted on the M5-A locked format.)

### M7 - Product Capture Stabilization Integration

Goal:

Integrate the M6 PASS stabilization mode into the real Filmtone capture
surface so owner clips are recorded with stabilization as the default product
behavior, not via a smoke-only build.

Done:

- The non-smoke product capture path (not `Filmtone*Smoke.swift`) sets
  `connection.preferredVideoStabilizationMode = .cinematicExtendedEnhanced`
  by default on the M5-A locked format.
- A runtime guard falls back to the highest supported mode the M6 probe
  recorded when `.cinematicExtendedEnhanced` is not supported on a given
  format, and the chosen mode is recorded in the export sidecar.
- The recorded `.mov` carries the same Stop Condition guarantees as M6
  (active != .off when requested non-.off, Apple Log 2 preserved, no format
  swap, writer codec verified by AVURLAsset post-write).
- Product capture diagnostics expose the chosen and active stabilization
  modes alongside the M5-A baseline diagnostics already recorded.
- Owner records at least one real clip through the product surface (not the
  smoke build) with stabilization on and confirms parity with the M6 visual
  bar.

Dependency:

- M6.

### M8 - Editor Handoff And Honest Preview

Goal:

Make captured clips useful inside Filmtone, then make capture-time preview good
enough for shooting decisions.

Done:

- A captured clip opens in the existing editor.
- Matching Source Profile is preselected or attached.
- Export sidecar references capture package metadata.
- Capture preview is close enough for exposure, framing, and Look choice.
- Any omitted preview effect classes are explicitly labeled during development.
- Capture preview reuses the existing Filmtone grade graph through a
  `AVCaptureVideoDataOutput` -> `CIImage` -> `CIContext` -> `MTKView` style
  path unless a later active task records why that is not viable.

Dependency:

- M4 for editor handoff.
- M5 before public Gyroflow-facing claims.
- M7 so capture-time preview operates against the same stabilized image
  path as the recorded master.

### M9 - Native Recording Export Completion

Goal:

Close the product loop so a recorded clip can be edited and shipped as a
Filmtone artifact. Owner reaches "撮る → 映画調にする → 書き出す → 保存・共有"
in a single uninterrupted flow.

Done:

- Recording-derived source runs the existing export path end to end on
  iPhone 17 Pro / iOS 26.4.2 with the same surface treatment as Photo
  Library / Files sources (no record-only branch).
- Post-export state is unambiguous: Photos save / Files share / app-internal
  destination is decided, exposed, and the user can tell where the artifact
  landed.
- Sidecar / metadata / filename handling does not break for capture-package
  sources (no missing provenance, no duplicate-name collisions, no orphan
  asset references).
- Every failure path (export error, Photos auth denial, share cancel, write
  error) surfaces a localized user-visible message; no silent swallowing,
  no stuck `isBusy`.

Dependency:

- M8 (recorded clip already lands in the editor as the active source).

Out of scope (handled in later lanes):

- React/Capacitor stack purge, capture-time honest preview (was strategy
  M8's preview half — not shipped, deferred), preview / Look polish,
  multi-device acceptance matrix, doc cleanup, recording-stop gesture
  changes.

Note: the previous M9 ("Owner Clip Trial — three clips deciding stock-camera
replacement") is folded into post-M9 ad-hoc owner usage. The product
completion bar is the right next gate; the trial verdict comes after the
loop is closed.

### M10 - Native Camera Capture Surface + Proxy Workflow

Goal:

Make recording the entry surface for the iOS app — a native SwiftUI
capture view that records a high-quality master, generates an editor
proxy, and hands the proxy to the existing editor pipeline. Replaces
the React/Capacitor `recordClip` route as the primary owner flow.

Pinned capture contract (M10 baseline):

- 3840×2160 **24 fps** (cinematic 24p) — `FilmtoneCaptureSession.lockedFPS = 24`
- ProRes 422 HQ (`apch` FourCC verified post-finalize via `AVURLAsset`)
- Apple Log 2 colorspace (rawValue 4) verified active before record start
- `cinematicExtendedEnhanced` stabilization, exact-match gate (no downgrade)
- Single-cam rear `builtInWideAngleCamera`, format index 56
- SSD mode: external security-scoped folder, soft 60s ceiling
- No-SSD mode: local Caches package dir, hard 10s product cap
- Proxy generated next to package, used as the editor source
- `capture-package.json` persisted next to proxy + mirrored into
  external folder (best-effort) for relaunch reconnect

Done:

- Native `FilmtoneCaptureView` is the entry surface; the React
  `recordClip` UI is no longer the primary path.
- Storage policy + duration cap are derived from preflight (10 GB free
  + capacity-divergence hard reject for "On My iPhone" misclassification).
- Master truth gate fails loudly on stabilization downgrade, Apple Log 2
  downgrade, and ProRes downgrade (FourCC ≠ `apch`).
- `capture-package.json` write failure is a visible capture failure
  (`packagePersistenceFailed`), not a silent skip.
- Editor adopts the proxy via `adoptCaptureResult(_:)`; master URL +
  package linkage survive a relaunch through `currentCapturePackageRef`.
- Spec readout (`<K>K<fps> · <codec> · <colorspace> · <stabilization> · <cap>s cap`)
  is display-only — M10 does not expose camera knobs.

Dependency:

- M9 (export completion loop closed for any source).

Out of scope (handled in later lanes):

- Capture-time honest preview, preview / Look polish, multi-device
  acceptance matrix, audio capture, exposure / focus / WB knobs,
  Gyroflow handoff (separate library lane), variable-fps capture.

### M11 - Capture-Time Look Selection

Goal:

撮影画面で Look を選び、その場で live preview に反映し、録画後の
editor 初期状態にもその Look が引き継がれる。owner が「Look を選ぶ
ために素材を読み込む」遠回りを撤廃する。

Pinned capture contract (M10 baseline 不変):

- master file は ProRes 422 HQ (`apch`) / Apple Log 2 (rawValue 4) /
  3840×2160@24 / cinematicExtendedEnhanced のまま保持
- Look は **master に焼き込まない** — capture-package.json の
  `selectedLook` field と editor 初期状態にのみ反映
- live preview は M10 / S8-F F3-Fix #1 の VDO grade chain
  (`FilmtoneSharedGradeProcessor` + `appliedSavedLook` /
  `cameraProfile` 3-layer wiring) を再利用

Done:

- capture surface 内に compact Look chip strip(bundled Stone /
  Urban + 標準 Filmtone)が表示される。詳細 picker は外殻、必要なら
  別 lane
- Look chip タップで live preview が即反映される(VDO sample tick
  単位、再 prepare なし)
- editor から capture に入った場合: 現在の Look(`appliedSavedLookId`
  または default Filmtone)が初期選択
- empty から capture に入った場合: 最後に使った capture-Look、なければ
  default Filmtone
- `capture-package.json` schemaVersion を bump し `selectedLook`
  field を永続化(`canonicalUUID` + `slug` + `intensity`)
- `adoptCaptureResult(_:)` 内で `selectedLook` を editor store に適用
  (既存 `applySavedLook` 経路を通す — 二重実装しない)
- cancel した場合: 既存 editor の `appliedSavedLookId` /
  `creativeLut` / `quickState` / `paramOverrides` は破壊されない
  (capture-Look 状態は capture surface 内 ephemeral)
- master file FourCC `apch` / Apple Log 2 / cinematicEE は M10
  truth gate と同じ結果を返す

Dependency:

- M10 (live preview grade chain + capture-package persistence).

Out of scope (handled in later lanes):

- Library full Look picker(library sheet は editor 側のまま)
- saved Look の作成 / 削除 / 名称変更(library 経由)
- intensity slider(まず固定 intensity、必要なら別 lane)
- camera profile picker(capture 中は固定、editor で変更)
- Look chip strip の sort / favorite / search

### M12 - Advanced Capture Controls

Goal:

撮影画面で owner が **露出補正・focus 点・WB lock・lens 切替・manual
ISO/shutter** を制御できるようにし、明暗・寄り絵・色被り・画角条件下
でも owner-quality な master を撮れる capture surface に押し上げる。
M10 baseline(4K24 / ProRes 422 HQ / Apple Log 2 /
cinematicExtendedEnhanced)と M11 capture-Look 選択は **selected lens
上で** 維持され、silent downgrade を起こさない。

Pinned capture contract (M10 / M11 baseline — lens-aware):

- master.mov は selected lens でも ProRes 422 HQ (`apch`) / Apple Log 2
  (rawValue 4) / 3840×2160@24 / cinematicExtendedEnhanced を満たす
- lens 切替時は M1 capability probe(`m1-capability.json`)で確認済の
  対応 format index に lock。M10 baseline contract を満たさない lens
  / format への silent fallback 禁止 — 該当 lens は UI で明示 disable
- lens swap は session pre-record 状態のみ。録画中の lens swap は
  禁止(録画中ボタンは disable)
- 露出補正 / tap-to-focus / tap-to-meter は exposure auto モード時のみ
  有効、manual モード時は対象 control 自体を hide / disable
- M11 capture-Look chip strip / live preview rebuild は変更しない

Done:

- **lens 切替**: 利用可能な rear lens(builtInUltraWide /
  builtInWideAngle / builtInTelephoto / 5× tele 等)を pill /
  segmented row で表示。各 lens の M1 probe 上 4K24 / Apple Log 2 /
  ProRes 422 HQ / cinematicExtendedEnhanced 全部を満たす format index
  を pre-resolve、満たさない lens は disable + 理由 tooltip。
  AVCaptureDevice 切替時は format / colorspace / stabilization を
  選択済 format 値で再 lock し、master truth gate を全 lens で
  PASS させる
- **露出補正(EV)**: `setExposureTargetBias(_:)` で ±3 stop。
  exposure auto モード時のみ有効。slider / stepper、capture 中の
  調整可
- **tap-to-focus / tap-to-meter**: capture preview tap を AVCaptureDevice
  正規化 focusPointOfInterest / exposurePointOfInterest に変換、
  `focusMode = .autoFocus` / `exposureMode = .autoExpose`、tap 位置に
  短時間 reticle 表示。exposure auto モード時のみ
- **WB lock**: 「auto / locked-at-tap」の 2 モード。lock 時は現在の
  `deviceWhiteBalanceGains` を `setWhiteBalanceModeLocked(with:)` で
  固定、auto 戻しで `.continuousAutoWhiteBalance` に復帰
- **manual exposure (ISO + shutter)**: auto / manual トグル。manual 時
  は `setExposureModeCustom(duration:iso:)` で ISO + shutter duration
  を直接制御。slider range は active format の
  `minISO..maxISO` / `minExposureDuration..maxExposureDuration` から
  動的生成、24fps capture の shutter は 1/24s 上限で cap(物理
  最大 = 1 frame 露光)。180° shutter (1/48s) は marker 表示。
  manual モード入りで EV bias / tap-to-meter は無効化、tap-to-focus
  のみ残る
- **制御値の package 永続化**: `capture-package.json` に
  schemaVersion bump で以下を追加(forward-compat decode、
  pre-M12 package は全 field 欠落で OK):
  - `selectedLens: { deviceTypeRaw, localizedName, formatIndex }`
  - `exposureMode: "auto" | "manual"`
  - `exposureBiasEV: Double` (auto 時)
  - `manualISO: Double?` / `manualShutterDurationSeconds: Double?`
    (manual 時)
  - `focusPointNormalized: {x, y}?` /
    `exposurePointNormalized: {x, y}?` (auto 時の tap)
  - `whiteBalanceLock: {mode, redGain, greenGain, blueGain}?`
- **editor は触らない**: 制御値は capture surface 内 ephemeral、
  `adoptCaptureResult` でも editor state に書き戻さない(capture
  metadata は package に永続化、editor 自動適用しない)
- **master truth gate**: M11 verify script を全 lens × auto/manual の
  代表 4 通り(wide-auto / wide-manual / tele-auto / ultraWide-auto)で
  PASS — codec `apch` / colorspace Apple Log 2 / 3840×2160 / 24 fps /
  pix_fmt yuv422p10le

Dependency:

- M11 (capture surface に Look chip / live preview rebuild が
  既に存在する状態で制御 row を重ねる)

Out of scope (handled in later lanes):

- audio capture / mic input(`NSMicrophoneUsageDescription` を
  含む)
- variable-fps / slow-motion(M10 24p locking を動かす)
- focus peaking / exposure zebra overlay(honest preview lane で
  別途検討)
- 録画中の lens swap / 録画中の auto↔manual mode switch(pre-record
  fix policy)
- exposure / focus / WB の RAW metadata sidecar(Filmtone editor
  側で読み戻す要件が出てから)
- AE/AWB lock + AF lock の 1-button "AE/AF Lock" 統合 UI(別 lane)

### M13 - Capture Screen UI Consolidation + Liquid Glass

Goal:

M10〜M12で増えた撮影画面の操作を、実際に撮る時に迷わない UI に整理する。
Apple Liquid Glass は装飾ではなく、live preview を邪魔しない control layer
として使う。機能追加ではなく、優先順位・配置・状態表示・操作性の lane。

Experience bar:

- M13 is not complete when controls are merely split or restyled. The capture
  screen must read as an authored camera surface in a frozen screenshot: live
  preview and the active Look atmosphere as the stage, quiet reachable shutter
  control, compact camera HUD, and secondary controls arranged as intentional
  rails / instrument mode.
- Avoid equal-weight capsule piles. Liquid Glass should create hierarchy and
  tactility, not a collection of unrelated translucent buttons.
- Owner-provided Halide / Mobbin screenshots are reference evidence for
  structure only: preview-dominant stage, bottom camera console, compact
  instrument values, and a distinct advanced tray. Do not copy branding or
  literal iconography. Do not infer that Record / Stop must be the emotional
  center.
- TIDE iOS Mar 2026 screenshots are reference evidence for visual language:
  soft atmospheric sheets, low-contrast glass, calm selected states, sparse
  typography, and one coherent material system. Do not copy TIDE content or
  navigation.
- If owner reaction is "突貫工事" or below product bar, continue M13 rather
  than close it as a documentation success.

Done:

- Record / Stop は静かで上質、かつ確実に到達できる。録画中は停止状態が明確で、
  危険な操作は disabled。
- live preview と active Look atmosphere が画面の主役として読める。
- Look / lens / storage / duration が常用操作として整理され、撮影前に迷わず触れる。
- Advanced controls(EV / WB / ISO / shutter / focus / meter)は cockpit chip row
  に畳まれ、tap で必要時だけ ruler scrubber を出す(drawer は M13-M-4 で撤去)。
- manual active 状態は chip 表示で読める。ISO / SHUTTER chip が "Auto" → 数値、
  WB chip が "Auto" → "Lock" になる。Auto / Manual の状態が消えない。
- Liquid Glass は top status / bottom deck / drawer など control layer にのみ適用し、
  live preview content には使わない。
- `GlassEffectContainer` / `glassEffect` を使える箇所は使い、glass-on-glass やカード入れ子は避ける。
- Flat black translucent cards are not acceptable as the final M13 answer.
  Control-layer chrome must be Liquid Glass first, darkened/tinted only when
  needed for readability.
- master writer / proxy generation / capture package / Look preview / manual control behavior は維持。
- owner が片手で no-SSD recording、Look switch、lens switch、Advanced drawer open/close、
  manual active 確認、record/stop を一周できる。

Dependencies:

- M12 (Look / lens / storage / Advanced controls が揃っている状態).
- Read-only evidence:
  `2026-05-08-ios-camera-preview-liquid-glass-research.md`.

Out of scope:

- New capture features.
- Master/proxy export truth.
- Full camera monitoring tools(waveform / false color / focus peaking / zebra).
- React/Capacitor cleanup.
- Broad QA matrix.

Sub-milestones:

- M13-K (2026-05-08): rejected on owner walk — implementation read as a
  black-card UI rather than Apple Liquid Glass. M13 continues as M13-L
  (Liquid Glass capture spatial rebuild).
- M13-L (2026-05-09): superseded before owner acceptance. Liquid Glass
  primitives (`captureGlassRail` / `captureGlassControl` / `captureGlassHUD`
  / `captureGlassSelected`) and top HUD primitives landed; spatial model
  (vertical look / lens rails + bottom shelf) rejected on owner walk —
  selected pill overflowed rail clip, preview was cropped above the shelf
  leaving black space, and the atmosphere-first language did not exceed
  the M13-J 65 % bar. Owner pivoted UI direction.
- M13-M (2026-05-09 →): Blackmagic-style parameter cockpit. Top
  parameter row (lens / ISO / shutter / EV / WB / Look) with single-active
  ruler scrubber expansion, horizontal lens chip row at the bottom,
  quiet shutter + folder buttons on the bottom shelf. Liquid Glass
  primitives retained as the material vocabulary; spatial layout
  rebuilt for parameter-access density rather than atmospheric calm.
  See `active.md` for the M13-M-N sub-task chain.
- M13-M-1 (2026-05-09): partial PASS, archived without owner acceptance.
  Cockpit composition (top chip row + bottom lens row + no side rails +
  preview-dominant) and selected-pill correctness landed; corner radii
  and Liquid Glass material quality flagged for rework. Sub-task chain
  shifts back one step.
- M13-M-2 (2026-05-09): PASS — owner accepted angular shape vocabulary
  (chip 9pt / lens 8pt / HUD 10pt / peripheral 11pt), per-control
  Liquid Glass (no slab), HIG tint-as-hint selected state, and
  cockpit-component split (`FilmtoneCaptureView.swift` 1170 → 847).
- M13-M-3 (2026-05-09): PASS — owner accepted Canvas-rendered
  `FilmtoneCaptureRulerScrubber` primitive (center-pinned amber
  indicator, major/minor ticks, drag-clamped to range, per-tick
  selection haptics), session wiring through `setExposureBias` /
  `setManualISO` / `setManualShutter`, and the Blackmagic-style
  auto→manual one-tap entry pattern (ISO / Shutter chip tap in
  `.auto` enters manual + opens scrubber; tap again exits to auto).
- M13-M-4 (2026-05-09): PASS — drawer cleanup absorbed into the
  M13-M-3 cycle. `FilmtoneCaptureAdvancedDrawer.swift` deleted +
  4 pbxproj entries deregistered; `FilmtoneCaptureBottomDeck` no
  longer generic over `AdvancedContent`. The chip cockpit is the
  only remaining path into manual exposure / WB lock / Look pick.
- **M13 closed (2026-05-09)** — cockpit + Liquid Glass + ruler
  scrubber + auto↔manual chip-tap = authored capture surface owner
  accepted. Implementation work moves to M14 (master / proxy export
  truth).

### M15 - Editor Empty View + Library Chip Liquid Glass parity

Goal:

Bring the editor's empty-load surface (the screen the owner sees when
`store.source == nil`) and the Saved Looks / Saved LUTs library chips
into the same Apple Liquid Glass vocabulary the capture cockpit
adopted in M13. The pre-M13 surfaces still use opaque
`.background(RoundedRectangle.fill).overlay(stroke)` chrome and
`.glassProminent` system blue button styles, which read as cheap
consumer chrome alongside the cockpit's authored Liquid Glass.

Done:

- Saved Looks chips in `FilmtoneEmptyView` and `FilmtoneLibrarySection`
  render as Liquid Glass (refraction visible at the rim, amber tint as
  hint not fill, no opaque RoundedRectangle background).
- Empty-view CTA stack (Photo Library / Files / Record) reads as a
  single coherent Filmtone-amber accent system instead of the system-
  blue prominent CTA + neutral glass stack.
- The editor's other surfaces that share `FilmtoneLibraryChip` (LUT
  library, Saved Looks panel) inherit the new chip vocabulary by
  construction.
- No regressions to capture cockpit Liquid Glass quality.

Dependencies:

- M13 (capture cockpit Liquid Glass landed).
- M14-A / M14-B (separate concern; empty-view lane is orthogonal).

Out of scope:

- Editor chrome refactor beyond the chip + CTA touchpoints.
- Sidecar provenance (M14-C, separate lane).
- New illustration / hero work.

### M14 - Master/Proxy Export Truth

Goal:

capture package の master/proxy linkage を export pipeline が理解し、最終成果物の品質と保存先を曖昧にしない。

Done:

- editor は proxy で軽く動く。
- export 時に master が available なら master を使う。
- external master が unavailable なら明示的に reconnect / unavailable を出す。
- proxy export になる場合は明示する。
- large master を local iPhone storage に silent copy しない。
- sidecar / export metadata に master/proxy provenance を残す。

Dependency:

- M13 so capture UI is stable before export-truth work resumes.

## Known Constraints

- No implementation starts without `active.md`.
- Only one current `active.md` may exist for this lane.
- No silent capture fallback. Apple Log / Apple Log 2, ProRes, HEVC, lens, fps,
  stabilization, and storage choices must be explicit.
- No fake preview. Preview may be partial, but it must not claim more than it
  shows.
- Video capture defaults to ProRes 422 or 422 HQ when runtime writer support is
  available. HEVC 10-bit is an explicit fallback. HEVC 8-bit plus Log is not an
  acceptable capture mode.
- Capture diagnostics must record orientation, stabilization state, OIS/EIS
  limits, codec, color space, fps, dimensions, and timestamp anchors.
- M1-M4 use internal sandbox output only. External SSD / security-scoped output
  is deferred until owner workflow polish unless an active task explicitly
  expands scope.
- M1-M4 produce silent video. Audio capture and `NSMicrophoneUsageDescription`
  are deferred until owner workflow polish.
- The first device target is the owner device.
- Broad device coverage, App Store copy, screenshots, and marketing wait until
  the owner workflow works.
- "Gyro recorded" is not the same as "Gyroflow-quality stabilization."
- The Filmtone-optimized motion / stabilization library lane that M5-B
  BLOCKED implied is **deprioritized for capture-time stabilization**: M6
  PASS shows AVFoundation built-in `cinematicExtendedEnhanced` is
  acceptable on the M5-A locked format. If the lane survives at all,
  scope narrows to "post-capture motion-data uses AVFoundation cannot
  handle" (e.g. honest preview overlay, exporter metadata, off-device
  Gyroflow-equivalent integrations) and is not a milestone in this
  strategy.

## Open Questions

- Which rear-camera format should be the first real recording mode on the owner
  device?
- Does the owner device runtime-report Apple Log 2 for the desired mode?
- ~~Can `AVCaptureVideoDataOutput + AVAssetWriter` produce stable PTS for this
  use case?~~ **Closed 2026-05-07**: VDO rejected as the sole product master
  writer path (Path C selected — see Completion Log). VDO is retained as a
  timing / diagnostics side-band only.
- Does Core Motion sampling remain stable while the selected video mode records?
- Can Core Motion boot-time timestamps and video PTS be mapped cleanly enough
  for Gyroflow?
- ~~Which stabilization / lens path makes gyro data agree with the image
  path?~~ **Closed 2026-05-07**: M6 PASS — AVFoundation
  `cinematicExtendedEnhanced` on the M5-A locked format is the
  capture-time stabilization path. Gyro / image-path agreement for
  desktop stabilization lives downstream of capture and is not a
  capture-pipeline milestone.
- Does capture-time preview need Metal earlier than expected?
- ~~Can `AVCaptureMovieFileOutput` (ProRes Apple Log 2 master) and
  `AVCaptureVideoDataOutput` (timing side-band) coexist on the same
  `AVCaptureSession` at 4K Apple Log 2 on iPhone 17 Pro / iOS 26.4?~~
  **Closed 2026-05-07**: M2-B passed on iPhone 17 Pro / iOS 26.4.2.

## Completion Log

- 2026-05-07: Created iOS V2 capture / Gyroflow 2-layer operating structure and
  scoped the first active task to M1 Capability Probe.
- 2026-05-07: M1 done. Real-device JSON pulled from iPhone 17 Pro / iOS 26.4.2;
  Apple Log 2 confirmed runtime-reported on all 7 rear cameras. M2 candidate
  locked: BuiltInWideAngleCamera formatIndex 56, pixelFormat `x422`, Apple Log 2,
  3840×2160@30, writer = ProRes 422 HQ.
- 2026-05-07: M2-A (Video-Only Writer Smoke) **blocked**.
  `AVCaptureVideoDataOutput.availableVideoPixelFormatTypes` on iPhone 17 Pro /
  iOS 26.4 does not include `x422` or `x420` for the M1 candidate format —
  only `420v`, `420f`, `BGRA`, plus 6 lossless/lossy compressed 8-bit
  variants (`&8v0`, `-8v0`, `&8f0`, `-8f0`, `&BGA`, `-BGA`). The M1-locked
  ProRes 422 HQ + Apple Log 2 master cannot be built directly through VDO.
  Frozen Inputs need redesign before M2 can resume — see active.md
  "Scope Review Required". Next active.md is a design review, not a
  continuation of M2-A.
- 2026-05-07: M2 writer path **decided — Path C (Quality-first dual-output)**.
  `AVCaptureMovieFileOutput` writes the ProRes Apple Log 2 master;
  `AVCaptureVideoDataOutput` runs as a timing / diagnostics side-band.
  VDO is rejected as the sole product master writer for M2 product capture.
  Decision evidence: Apple TN3121 (`availableVideoPixelFormatTypes` is
  "connected to" semantics), Apple `.inputPriority` documentation
  (auto-switch on `activeFormat` change), Apple Forum thread 769888
  (4K60 ProRes Log uses `AVCaptureMovieFileOutput`), iPhoneOS 26.4 SDK
  `CVPixelBuffer.h` (all 9 M2-A deliverable FourCCs decoded as 8-bit). A
  parallel observation: M2-A's `availableVideoPixelFormatTypes` was queried
  before VDO was attached to the session (TN3121 connected-to semantics),
  so M2-A's blocker may reflect ordering rather than an Apple Log 2 +
  VDO 10-bit limitation. That ordering question is intentionally not
  resolved in this active because Path C is preferred regardless. See
  next active proposal "M2-B Path C Dual-Output Coexistence Smoke".
- 2026-05-07: M2-B Path C dual-output coexistence smoke **passed** on
  iPhone 17 Pro / iOS 26.4.2. `AVCaptureMovieFileOutput` + VDO coexisted at
  `hardwareCost = 0.5`; the master `.mov` is ProRes 422 HQ (`apch`),
  3840x2160, 30 fps, 6.166667s; VDO delivered `x422` timing samples
  (191 frames, 0 dropped). M3 motion-only recorder smoke can proceed.
- 2026-05-07: M3 motion-only recorder smoke **passed** on iPhone 17 Pro /
  iOS 26.4.2 (no `AVCaptureSession` running). Raw `startGyroUpdates` +
  `startAccelerometerUpdates` (fused not started); both streams 1048
  samples / coverage 10.479s / effectiveHz 99.92 / maxGap 10.0ms /
  gapCountOver50/100/200ms = 0/0/0. M4 combined timing smoke can proceed.
- 2026-05-07: M4 combined timing smoke **passed** on iPhone 17 Pro /
  iOS 26.4.2 with one `AVCaptureSession` driving Path C dual output (ProRes
  422 HQ Apple Log 2 master + VDO timing side-band) alongside raw gyro +
  accel. 30s run; `video.movieFile.startPTSSeconds = 139121.811449` (finite —
  startPTS gate satisfied), VDO 957 samples / 29.999 fps, gyro 3183 / accel
  3182 (both 99.92 Hz; 200 Hz request capped by iOS 26.4 IMU), all gap
  counters 0, `mapping.vdoPTSMinusGyroTSSeconds = -48.05ms`,
  `vdoPTSMinusAccelTSSeconds = -58.06ms`. `session.synchronizationClock` is
  `HostTimeClock` so VDO PTS, MovieFile startPTS, and `CMLogItem.timestamp`
  share a single `mach_absolute_time` axis — M5 `.gcsv` proof can proceed.
- 2026-05-07: M5-A Gyroflow `.gcsv` proof (on-device writer + package)
  **passed** on iPhone 17 Pro / iOS 26.4.2 (Run #2,
  `m5-package-a8ca4b0a-7f8e-4747-833b-9921a56ade4f`). Strategy C
  combined-on-gyro-timeline writer + boundary-trim policy: `accelDroppedRowCount
  = 0` (in-range tolerance gate), `gyroAccelTrimDurationTotalSeconds = 5.003ms
  ≤ 20ms` (boundary trim within `max(1.5 × gyroMedianInterval, 20ms)`),
  reconciliation `exactRow 3170 + interpRow 18 + droppedRow 0 + outOfRangeTotal
  1 = 3189 = gyroSampleCount` and `gcsv.rowCount = 3188 = gyroSampleCount -
  outOfRangeTotal - droppedRow`. Master ProRes 422 HQ Apple Log 2 30.567s /
  2.7 GB; `movieFile.startPTSSeconds = 143361.71016770799` (M4 startPTS gate
  not regressed); VDO 958 / 29.999 fps; gyro/accel 3189/3189 / 99.93 Hz / 0
  gaps; M4 baseline drift gate within ±200ms (Δ23.2 / 28.2 ms). Run-local
  M5-B sync seed `runLocalMovieStartToGyroOffsetSeconds = +141.81ms`
  (PRIMARY). Strategy C exact-match rate 99.4% (3170/3188) confirms gyro and
  accel CoreMotion handlers share the same scheduling cadence on this device.
  Run #1 pre-revision FAIL drove the writer split between in-range drops
  (`accelDroppedRowCount`) and boundary trim (`accelOutOfRange*Count` /
  `gyroAccelTrimDuration*`); revised writer + smoke evidence in
  `apps/capacitor-film-lab-ios/diagnostics/m5-combined-timing.json /
  m5-motion.gcsv / m5-debug.log`. M5-B (Gyroflow desktop validation) and
  M5-C (RS calibration) are deferred to separate active scopes.
- 2026-05-07: M5-B Gyroflow desktop validation **closed as BLOCKED**
  (not PASS, not FAIL). Gyroflow v1.6.3 (macOS) loaded `m5-master.mov`
  + `m5-motion.gcsv` cleanly: `.gcsv` recognized as
  `filmtone filmtone ios m5`, gyro X/Y/Z waveforms render finite over
  full 30s, `Max rotation Pitch 4.8° / Yaw 4.9° / Roll 2.6°`,
  stabilization preview pipeline became active. **Auto sync produced
  no sync points** — clip is gentle handheld over bright laptop screen
  content (low optical-flow feature density, ~5° max rotation),
  `OpenCV (DIS)` + `findEssentialMat` + `rs-sync` did not converge.
  `Rough gyro offset` field clamped to 0.1s precision in v1.6.3 GUI;
  entered `0.1` (true M5-A seed `+0.14181`, gap 41.8ms — within
  ±100ms Done tolerance, so not the blocker). **Owner observed visual
  axis inversion** when stabilization preview engaged — sensor-frame
  IMU (`axisConvention.mode = sensor-native`, `orientation = XYZ`)
  fed into Gyroflow's pipeline that expects image-frame, with
  `.mov` carrying `appliedAngle 90` / Gyroflow display rotation 270°.
  Decision: **M5-A writer stays sensor-native** (raw Core Motion is
  the honest capture truth; image-frame remap would bake a downstream
  consumer's convention into Filmtone). **Gyroflow is not the
  long-term motion consumer**; Filmtone will build an iPhone-optimized
  stabilization / motion-data library in a separate lane (not defined
  in this active). M5-A code at `d0e847e1` is unchanged. Strategy
  `M5` Done conditions referencing Gyroflow stabilization quality may
  need rewording when the Filmtone-optimized motion library lane
  opens — deferred to that active. Findings recorded in
  `archive/2026-05-07-m5-b-gyroflow-desktop-proof.md`.
- 2026-05-07: M6 AVFoundation stabilization smoke **passed** on iPhone 17 Pro /
  iOS 26.4.2. `AVCaptureConnection.preferredVideoStabilizationMode =
  .cinematicExtendedEnhanced` (raw 5) on the M5-A locked format
  (formatIndex 56 / x422 / Apple Log 2 / 3840x2160@30 / writer ProRes
  422 HQ) clears all four Stop Conditions: active resolves to
  requested (no silent `.off` fallback), Apple Log 2 preserved
  (`colorSpaceRaw=4`), no format swap
  (`activeFormatMatchesLockedAfterRecordStart=true`), and the recorded
  `.mov` first video track FourCC reads `apch` via `AVURLAsset` (no
  ProRes 422 HQ → HEVC writer downgrade — direct file evidence, not
  the constant `writer.codec` field). Per-format probe of the full
  iOS 26 candidate set (`off, standard, cinematic, cinematicExtended,
  previewOptimized, cinematicExtendedEnhanced, lowLatency, auto`)
  empirically reports `previewOptimized (raw 4)` and `lowLatency
  (raw 6)` as NOT supported on formatIndex 56. Owner visual A/B
  (run #2, handheld pan + light shake) judged the on-clip acceptable
  at owner-quality bar with no visible Apple Log 2 tonal-range
  downgrade. Implication: the Filmtone-optimized motion /
  stabilization library lane that M5-B BLOCKED implied is **not
  required for capture-time stabilization** — re-scope to
  "post-capture motion-data uses AVFoundation cannot do" or
  deprioritisation is **proposed** in the archived active and held
  for owner review (not applied here). Findings recorded in
  `archive/2026-05-07-m6-avfoundation-stabilization-smoke.md`.
- 2026-05-07: Strategy realigned — M6 redefined as "AVFoundation
  Stabilization Smoke" (PASS), new M7 = "Product Capture Stabilization
  Integration", old M6 / M7 renumbered to M8 / M9 with deps updated,
  Filmtone-optimized motion library lane deprioritized for capture-time
  stabilization (Known Constraints bullet added). M1-M6 prior history
  untouched. Realignment scope: numbering + deps + lane note only.
- 2026-05-08: M7 Product Capture Stabilization Integration **passed**
  on iPhone 17 Pro / iOS 26.4.2. Owner-tapped third CTA on
  `FilmtoneEmptyView` ("録画する / Record") triggered
  `FilmtoneEditorStore.recordProductClip()` →
  `FilmtoneProductCapture.recordClip(durationSeconds: 5)` directly
  (no Capacitor plugin bridge); resulting `clip.mov` auto-loaded into
  the editor as the active source. Mid-implementation discovery: the
  React/Capacitor MobilePhase0Editor is **not the live UI** —
  `AppDelegate` boots a native SwiftUI tree via
  `FilmtoneRootHostingController` + `FilmtoneRootView`. The earlier
  React-side wiring (MobilePhase0Editor.tsx record button + JS bridge
  + Capacitor plugin method) never rendered. Outcome: M7 product
  surface shipped as native SwiftUI; React/Capacitor stack confirmed
  dead in launch path. Findings recorded in
  `archive/2026-05-08-m7-product-capture-stabilization.md`. Follow-up
  lane: React/Capacitor purge from `apps/capacitor-film-lab-ios`.
- 2026-05-08: M9 redefined — "Owner Clip Trial" → "Native Recording
  Export Completion" (close record → edit → export → save/share). Trial
  verdict folds into post-M9 ad-hoc usage.
- 2026-05-08: M8 (Native Recording Product Flow) **landed** — fixed
  5s product capture surfaced via SwiftUI: `FilmtoneRootView`
  recording overlay (TimelineView countdown ring + integer seconds +
  pulsing red dot + localized label) and `.alert` bound to a
  dedicated `recordingError` state. Capture surface contract
  unchanged (no stop affordance, M7 owner-locked design). xcodebuild
  PASS; owner device acceptance pending. Details in
  `archive/2026-05-08-m8-native-recording-product-flow.md`.
- 2026-05-08: M9 (Native Recording Export Completion) **landed** —
  closes record → edit → Look / adjustment → export → save/share product loop
  on the output side. S1 confirmed CTA hierarchy + save-destination
  feedback already existed; S3 added `toastShareSuccess`; S4 routed
  export/save failures through the existing toast surface (mirrors
  `toastShareFailed`, no new UI binding). S5 owner walk PASS on
  iPhone 17 Pro / iOS 26.4.2. Polish observed during the walk is
  deferred to a separate UI/UX lane. Details in
  `archive/2026-05-08-m9-native-recording-export-completion.md`.
- 2026-05-08: M10 (Native Camera Capture Surface + Proxy Workflow)
  **landed** — S8-F sub-stages F1〜F4 全 PASS。VDO+MovieFileOutput
  共存 live preview に F3-Fix #1 で `cameraProfile`/`appliedSavedLook`
  3-layer wiring を通し、Stone/Urban で diagnostic chip
  `wiring camProf:Y savedLook:Y` を device verify。F4 で master.mov
  を ffprobe/mp4dump/mediainfo + 自前 colr parser で精査 — ProRes
  422 HQ `apch`/4K24 CFR/10-bit yuv422p10le/BT.2020 NC + Gyroflow
  用 `mebx` track。capture-package.json `parameters*` も
  Apple Log 2/cinematicExtendedEnhanced/24/3840×2160 全保持。
  Details in `archive/2026-05-08-m10-native-camera-capture-surface.md`.
- 2026-05-08: M11 (Capture-Time Look Selection) **landed** — capture
  surface に Filmtone / Stone / Urban の固定 3-chip strip、live preview
  rebuild closure 経由 + record success → editor `applySavedLook` で
  cancel-preserving な Look handoff。実機 iPhone 17 Pro / iOS 26.4.2
  で chip 切替 → live preview 反映 / record → editor 反映 / cancel →
  editor 不変 / master truth M10 baseline 維持を verify。closeout 中
  に SSD bookmark 永続化(`FilmtoneExternalFolderBookmark`)と
  cold-start chip preview structural gap(synthetic SourceInfoDTO /
  Probe with `file://` URI)を 2 件 fix。live preview 切替遅延は
  post-M11 polish 候補として保留。Details in
  `archive/2026-05-08-m11-capture-look-selection.md`.
- 2026-05-08: M12 (Advanced Capture Controls) **PASS with
  product-sufficient evidence**: advanced controls landed, wide-auto
  master truth passed, manual ISO/shutter package persisted; broad
  lens matrix deferred as non-blocking. S12-A〜E が landed
  (commits `a6b94e99` / `db36328e` / `1f206596` / `b0b33c2e`):
  S12-B lens magnification label refactor + package 永続化、S12-C
  EV bias slider + tap-to-focus / tap-to-meter + reticle、S12-D
  WB auto/locked segmented + locked 時のみ R/G/B gains を persist、
  S12-E manual ISO/shutter mode + 24fps shutter cap + 180° marker +
  inheritedFromAuto flag + manual 中は EV/tap-to-meter no-op /
  tap-to-focus 残す。schemaVersion 2 維持(全 M12 field は additive
  optional、pre-M12 snapshot は forward-compat decode)。S12-F は
  実機 iPhone 17 Pro #7 / iOS 26.4 で partial PASS:wide-auto は
  full master truth(`apch` / `yuv422p10le` / 3840×2160 / 24/1)+
  全 package field が `scripts/verify-m12-capture-master.sh
  wide-auto` で PASS、wide-manual は package side に
  `manualISO=1212.92` / `manualShutterDurationSeconds≈0.025003s` /
  `manualInheritedFromAuto=true` が persist されている事を確認
  (master は SSD userfsd マウント中で Mac 不可視 / WB Locked は
  operator miss)、tele-auto / ultraWide-auto は M10 baseline の
  S8-B lens swap 既存検証範囲なので deferred。Details in
  `archive/2026-05-08-m12-advanced-capture-controls.md`.
- 2026-05-08: M13 (Capture Screen UI Consolidation + Liquid Glass)
  split pass **completed but not product-complete** — view-only refactor split
  `FilmtoneCaptureView.swift` into 6 sibling files and preserved
  writer/session/package/proxy behavior. Owner walk found no major functional
  regression, but owner rated the experience roughly 40% and rejected it as
  still feeling like突貫工事. M13 continues as M13-I composition rebuild:
  make the capture screen feel authored and fun before moving to M14.
- 2026-05-08: M13-I (Composition Rebuild) + M13-J (TIDE-informed material
  refinement) landed view-only on iPhone 17 Pro #7. M13-I established the
  hierarchy lock (1 hero shutter / 2 capture rails / 1 compact HUD / 1 tray)
  and unified the rails into single glass capsules with internal segments;
  M13-J replaced equal-weight capsule polish with one TIDE-style translucent
  console surface and soft selected states. Owner rating 40%→65%, but
  spatial composition (上下左右の zone 設計 / eye-thumb flow) still reads
  engineered rather than authored.
- 2026-05-08: M13-K re-scoped before implementation closeout after owner
  clarified that Record / Stop is **not** the center of the shooting
  experience. M13-K now targets a Liquid Glass shooting space: preview and
  Look atmosphere lead, Record stays quiet and reachable, and Advanced becomes
  a console mode rather than an overlay patch. Details in current `active.md`.
- 2026-05-09: M13-L superseded before owner acceptance. Liquid Glass
  primitives + top HUD landed; vertical rail spatial model rejected on
  owner walk for selected pill overflow + preview cropping. Owner pivoted
  to Blackmagic-style parameter cockpit (top parameter row + ruler
  scrubbers + horizontal lens chip row). M13-M-1 (cockpit layout shell)
  opens as the next active.
- 2026-05-09: M13-M-1 (cockpit layout shell) **archived as partial PASS**.
  Composition + selected-pill bug fix landed on iPhone 17 Pro #7. Owner
  walk flagged corner radii reading too round (Capsule everywhere) and
  the bottom shelf glass rail collapsing into plain frosted glass
  rather than Apple Liquid Glass. M13-M-2 opens to address material
  quality + shape vocabulary + responsibility-separated component
  refactor; the previous M13-M-N (ruler primitive, ruler wiring, mode
  toggle integration, owner walk) chain slides back one step.
- 2026-05-09: M13-M-2 (Liquid Glass quality + cockpit refactor)
  **PASS** on iPhone 17 Pro #7 — owner accepted angular RoundedRectangle
  shape vocabulary, per-control Liquid Glass primitives (no shelf slab),
  HIG tint-as-hint selected state. `FilmtoneCaptureView.swift`
  1170 → 847 lines via `Cockpit / Lens / Look` sibling extraction.
  M13-M-3 opens for ruler scrubber primitive + session wiring + the
  auto↔manual tap pattern (decision: ISO/Shutter chip tap in `.auto`
  enters manual exposure + opens scrubber, tap again exits to auto —
  Blackmagic-style one-tap mode entry rather than a separate Auto/Manual
  toggle).
- 2026-05-09: M13-M-3 (RulerScrubber primitive + session wiring +
  auto↔manual tap pattern) and M13-M-4 (drawer cleanup addendum)
  **PASS** on iPhone 17 Pro #7. New `FilmtoneCaptureRulerScrubber.swift`
  Canvas primitive landed; cockpit chip row scrubs `session.setExposureBias`
  / `setManualISO` / `setManualShutter` with per-tick selection haptics;
  ISO / Shutter chip tap auto-enters manual exposure inheriting the
  current auto reading. `FilmtoneCaptureAdvancedDrawer.swift` deleted
  (4 pbxproj entries deregistered, `FilmtoneCaptureBottomDeck` no longer
  generic over `AdvancedContent`).
- 2026-05-09: **M13 (Capture Screen UI Consolidation + Liquid Glass)
  closed** after the M13-K → M13-L → M13-M-1 → M13-M-2 → M13-M-3 + M13-M-4
  iteration chain. Owner-accepted authored capture surface =
  preview-dominant stage, parameter chip cockpit (ISO / Shutter / EV /
  WB / Look) with one-tap manual entry, ruler scrubber per active chip,
  horizontal lens chip row, compact shutter cluster with quiet record
  button, all in angular RoundedRectangle Liquid Glass vocabulary.
  M14 (Master / Proxy Export Truth) opens next.
- 2026-05-09: M14-A (Master Availability + Master/Proxy Decision)
  **PASS** on iPhone 17 Pro #7. New `ExportSourceDecision` enum +
  `resolveExportSource()` two-gate detection (fileExists →
  facade.probeSource), decision-aware success toasts
  (`toastExportUsedMaster` / `toastExportUsedProxyMasterUnavailable` /
  legacy `toastExportComplete` for non-capture sources). Internal-
  Documents masters export from master; SSD-mounted master export
  still falls back to proxy at this step because no security-scoped
  resource is held at editor time — addressed in M14-B. Photos /
  Files edits unchanged.
- 2026-05-09: M14-B (security-scoped bookmark for SSD masters) opens.
  New stateless `FilmtoneSecurityScopedBookmark` helper, additive
  optional `masterBookmark: Data?` on `FilmtoneCapturePackage` +
  `FilmtoneCapturePackageSnapshotV1` (no schemaVersion bump per
  existing additive-optional convention). Capture session writes the
  bookmark when storagePolicy is external; editor resolves at export
  start, calls `startAccessingSecurityScopedResource()`, releases
  scope via `ResolvedExportSource.release()` deferred from the
  export call site. App-relaunch SSD master export becomes the new
  default outcome.
- 2026-05-09: M14-B **PASS** on iPhone 17 Pro #7. Owner accepted
  bookmark write at capture finalize + scope acquire-and-release at
  editor export. SSD same-session, SSD new-session, and SSD
  post-relaunch master exports all land on the master path; SSD-
  unmounted falls back to proxy with the existing M14-A toast.
  Internal-Documents and Photos / Files paths unchanged.
- 2026-05-09: **M15 (Editor Empty View + Library Chip Liquid Glass)
  opens** as a parallel lane to M14-C. Owner-supplied screenshot
  flagged the empty-load surface (Stone / Urban Saved-Look chips and
  the bottom CTA stack) as still using pre-M13 opaque
  RoundedRectangle chrome + `.glassProminent` system blue button.
  Scope: lift `FilmtoneLibraryChip` to `glassEffect`-based Liquid
  Glass (amber tint hint for bundled, neutral for unbundled), add
  `FilmtoneEmptyCTAButtonStyle` with primary/secondary tint
  hierarchy in the Filmtone-amber accent system, harmonize empty-view
  CTA stack. M14-C (sidecar provenance) deferred until M15 lands.
- 2026-05-09: M15 **REJECTED** at 20点. Mechanical flaw:
  `.background(Color.clear.glassEffect(...))` pattern in the custom
  button style rendered the label behind the material → diffuse
  unreadable text. Design flaw: amber tint at 0.18 saturated to opaque
  brown on the dark substrate, three stacked equal-weight CTAs gave
  no hierarchy, no atmospheric substrate for Liquid Glass refraction.
  M15-bis opens to redesign the page from scratch using owner's
  TIDE iOS Mar 2026 reference (silvery clear glass cards, single
  dominant primary, atmospheric layout).
- 2026-05-09: M15-bis (Editor Empty View — TIDE-inspired card grid)
  opens. New `FilmtoneEmptySourceCard` view component (replaces the
  rejected `FilmtoneEmptyCTAButtonStyle`). Glass via direct
  `.glassEffect(_:in:)` on the padded content (no Color.clear
  background trick). No amber tint on material — amber stays as
  icon / favorite-star accent only. Library chip drops amber bg
  tint entirely; bundled status communicated by icon color +
  hairline white rim. Card grid: 2-up Photo Library / Files row +
  full-width Record row. Subtle vertical gradient backdrop gives
  Liquid Glass refraction substrate.
- 2026-05-09: M15-bis **REJECTED at 30点** (up from M15's 20). Owner
  critique: (1) hex symbol / wordmark / tagline not mandatory and is
  stealing visual budget; (2) the M15-bis near-black backdrop gives
  Liquid Glass nothing to refract — the chips and cards still read
  as flat translucent rectangles; (3) reference is **grunge fluid
  gradient** (vibrant amber / coral / pink / purple meshed blobs
  filling the screen) per owner-supplied images. M15-ter opens to
  drop the hero block and rebuild the backdrop as a `MeshGradient`
  fluid gradient that lets Liquid Glass actually refract. Cards +
  chips from M15-bis stay (the mechanical glass implementation was
  correct; only the substrate behind it was wrong).
- 2026-05-09: M15-ter **REJECTED ≤20点**. Owner observed (a) three
  "redesign" rounds had produced iteration not redesign — the core
  structure (cards + chips + some-kind-of-background) had never been
  questioned at the design level; (b) card sizes were copied from
  TIDE references without earning their footprint with content; (c)
  MeshGradient 3×3 + blur + vignette produced a low-quality muddy
  substrate, not the polished pastel sphere of reference Image #8.
  Owner committed to direction A (single-sphere hero, Image #8) under
  the bar 「**最高レベルの美しい流体グランジアニメーション**」.
- 2026-05-09: **M15-final** opens. Metal-shader-driven fluid sphere
  (`FilmtoneFluidSphere.metal` + `.swift`). SwiftUI's `colorEffect`
  + `[[stitchable]]` shader function does single-pass GPU rendering:
  inverse-distance-weighted pastel-blob mixing (ice blue / coral /
  soft amber / soft pink) with sin/cos drift, soft specular at
  upper-left, hash-based procedural grain, smooth edge falloff.
  TimelineView feeds the time uniform per frame. Empty view body
  drops the card grid in favor of a single primary text-link
  ("フォトライブラリから始める") + inline secondary
  ("ファイル · 録画する") so nothing competes with the sphere as
  visual hero. M14-C deferred until empty view lands.
- 2026-05-09: **M15 PASS** after a v1 → v8 iteration chain (sphere
  display bug fix, Apple Liquid Glass UI restored, sphere mask
  dropped for free-floating blobs, full-screen α=1 substrate
  composite, 8 blobs at σ=0.20 floor, palette + substrate switched
  to vibrant pastel + warm cream `(0.86, 0.82, 0.78)`,
  `.preferredColorScheme(.light)` on the empty view, `.primary`-
  based adaptive text on shared chips, anisotropic σ pulse for
  size + shape morph, onboarding alignment). Owner accepted v6
  「かなり良くなりました」. Single commit `d851b5d8` + the v7/v8
  refinements landed all M13 + M14-A/B + M15 work as one unit.
  Strategy lane returns to **M14-C (sidecar provenance)** as the
  next active.
- 2026-05-09: Interrupt **PASS** — native recording entry points now
  disable on devices that do not runtime-report the current Filmtone
  capture contract (4K24 / Apple Log 2 raw=4 /
  cinematicExtendedEnhanced). No Apple Log / HDR / SDR fallback was
  added; unsupported devices can still use Photo Library / Files
  editing.
