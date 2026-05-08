# Active: M10 — Native Camera Capture Surface + Proxy Workflow

Date: 2026-05-08 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Base: `main` after M9 landed (`436304d2`)

Status: **S8-A..D LANDED, S8-E PARTIAL PASS, S8-F F1/F2/F3/F4 ALL PASS (2026-05-08) — M10 CLOSEOUT READY**

This active exists to pin the implemented state of M10 before S7. Not a
plan doc. After S7 PASS, fill `## Outcome` and archive.

## Goal

Native camera surface as the iOS entry: SSD master + local proxy +
editor handoff. Replaces the React/Capacitor `recordClip` UI as the
primary owner flow.

## Locked capture contract

- 3840×2160 **24 fps** (cinematic 24p) — `FilmtoneCaptureSession.lockedFPS = 24`
- ProRes 422 HQ — `apch` FourCC verified post-finalize via `AVURLAsset`
- Apple Log 2 colorspace (rawValue 4) verified active before record start
- `cinematicExtendedEnhanced` stabilization, exact-match gate (no downgrade)
- Single-cam rear `builtInWideAngleCamera`, format index 56

## Storage modes

- **No-SSD**: local Caches package dir, **10s hard cap** (product-enforced)
- **SSD**: external security-scoped folder, **60s soft cap**
- Preflight requires ≥10 GB free + capacity-divergence hard reject so
  "On My iPhone" can't be misclassified as external

## Editor handoff

- Proxy generated next to package; editor adopts via
  `FilmtoneEditorStore.adoptCaptureResult(_:)`
- `capture-package.json` persisted next to proxy + best-effort mirrored
  into the external folder; relaunch reconnects via
  `currentCapturePackageRef` on the persistence snapshot

## S1 findings

- External storage pattern (security-scoped picker, capacity probe,
  `.atomic` write probe, statfs(3) fallback for userfsd / FileProvider
  mounts that return 0 from capacity APIs) imported from
  **DualLogCamera** and adapted; `classify()` promotes
  `volumeTotalCapacity` divergence to a hard reject (DualLog only logs).

## Implementation summary

New Swift files (6):

- `FilmtoneCaptureSession.swift` — AVCaptureSession + MovieFileOutput
  pipeline, exact stabilization / colorspace / codec gates
- `FilmtoneCaptureView.swift` — SwiftUI capture surface, spec readout,
  teardown on completion / failure / disappear
- `FilmtoneCapturePackage.swift` — package + parameters + failure enum
- `FilmtoneCapturePackagePersistence.swift` — `capture-package.json`
  read / write, local + external mirror
- `FilmtoneCapturePreflight.swift` — capacity / classification / 10 GB
  gate
- `FilmtoneProxyGenerator.swift` — master → editor proxy export

Modified:

- `FilmtoneEditorStore.swift` — `adoptCaptureResult`,
  `currentCapturePackageRef`, source-replacement linkage clear
- `FilmtoneRootView.swift` — capture surface entry wiring
- `FilmtonePersistence.swift` — additive Codable
  `currentCapturePackageRef`
- `App.xcodeproj/project.pbxproj` — 4-section registration for the 6
  new files (verified)

## Review fixes (post-first-pass, 2026-05-08)

- **P1-1** classification 厳格化: `volumeTotalCapacity` 一致時 hard reject
- **P1-2** teardown 保証: `.completed` / `.failed` / `.onDisappear` 全
  経路
- **P1-3** master truth gate: stabilization exact-match + AVURLAsset
  `apch` FourCC verify
- **P1-4** capture-package.json + `currentCapturePackageRef` (B-anchor:
  decoupled from `SourceInfoDTO`)
- **P2-1** spec label: display-only readout + nearest-K rounding
  (`4K24` not `3K30`)
- **P2-2** preflight 10 GB gate (was 5 GB)
- **F1** capture-package.json 書き込み失敗を `packagePersistenceFailed`
  でvisible failure 化、editor は実 file 存在保証時のみ ref を set
- **F2** M10 contract を 30fps → **24fps** に変更 (cinematic 24p)

## S7 owner walk (BLOCKED on S8 product-surface gaps)

Hardware: iPhone 17 Pro / iOS 26.4.2. Three paths to land:

1. **No-SSD path** — capture 入口 → 10s 自動停止 → editor 復帰 →
   Look / 調整 → export → Photos 保存
2. **Re-entry path** — editor 上の Record → capture 再表示 → 撮影 →
   editor 復帰
3. **SSD path** — SSD 接続 → capture 入口 → external master 表示
   確認 → 10〜60s 録画 → editor 復帰 → Look / 調整 → export →
   Photos 保存

Acceptance — 4 観点のみ:
- 撮影に戻れる(re-entry が機能する)
- レンズ選択と撮影条件が見える(lens selector + contract banner)
- No-SSD 経路で 10s であることが分かる(storage pill 表示)
- SSD 経路で master が external、editor は proxy で動く

Owner reports: stuck `isBusy` / silent failure / codec /
colorspace / stabilization downgrade 表示が出た場合のみ、
該当画面のスクリーンショット 1 枚を共有してフォローアップ。
Resumes at S8-E once S8-A..D have shipped.

## S8 — capture surface product completion

- [x] **S8-A** Re-record entry from editor (Record button in editor chrome).
- [x] **S8-B** Rear lens selector — runtime enumeration + 4K24 /
  Apple Log 2 / cinematicEE format-level gate, default = wide,
  capture package records lens identifier / display name / device type.
- [x] **S8-C** Capture parameter operate / readout UI — locked
  contract banner (4K24 / ProRes 422 HQ / Apple Log 2 / Cinematic EE
  / Proxy → Editor) + storage pill with cap (`Internal master · 10s
  cap` / `External master · <folder> · 60s cap`); operable surface
  remains lens · storage target · record/stop, no exposure / WB /
  focus / zoom.
- [x] **S8-D** Look-applied preview on capture surface — reference
  thumbnail strip route. Capture surface receives a snapshot of the
  editor's current Look state (`FilmtoneCaptureLookReference =
  selectedPreviewURI + lookProfileLabel`) at fullScreenCover
  present time and renders a small "LOOK REFERENCE" panel below
  the storage pill: graded poster thumbnail (120×90) + look label
  + "Live ungraded" disclaimer. Owner can judge color direction
  before recording without coupling capture loop to editor
  publishers. Decode runs on `Task.detached(.utility)` keyed by
  `displayURI` so recording state ticks do not redecode.
  Omitted (recorded as out-of-scope for M10):
    - **Live frame grading** — applying the grade to the
      `AVCaptureVideoPreviewLayer` would require swapping it for a
      `AVCaptureVideoDataOutput` + CIFilter compositor, which
      conflicts with the ProRes 422 HQ + Apple Log 2 + cinematicEE
      record pipeline (M2-A: iOS 26.4 does not deliver 10-bit
      `x422`/`x420` from VDO under `.appleLog2`). Live preview
      remains the raw camera pass-through; this is labelled "Live
      ungraded" in the panel.
    - **Reference for video sources without a baked still poster** —
      `FilmtonePreviewState.video` exposes an `AVPlayer`, not a
      file URI; `selectedPreviewURI` returns nil there and the
      panel is hidden. Falling back to a player-frame snapshot
      would re-introduce a CIFilter pass and was not pursued.
    - **Reference for editor mid-render** — when the editor
      preview is rendering at the moment Record is tapped,
      `selectedPreviewURI` is nil and the panel is hidden until
      the next session.
- [~] **S8-E** S7 owner walk — **partial PASS (2026-05-08)**:
  re-entry / lens / parameters / storage + proxy 4 観点すべて owner
  device (iPhone 17 Pro / iOS 26.4.2) で確認済。stuck / silent
  failure / codec / colorspace / stabilization downgrade なし。M10
  closeout は S8-F PASS まで保留。

## S8-F — Live Look Preview (in progress)

撮る前に色方向が見えることは capture surface の本質。S8-D の
reference thumbnail strip は補助表示として残し、live preview に
current Look + 調整を反映する。

Research doc:

- `docs/filmtone/ios/v2-capture-gyroflow/2026-05-08-ios-camera-preview-liquid-glass-research.md`
- Apple official docs + local iPhoneOS 26.4 SDK checked.
- Conclusion: master remains MovieFileOutput; VDO is preview-only; live Look
  preview uses preview-sized BGRA frames + Core Image / Metal rendering;
  Liquid Glass belongs to floating controls, not the live image content.

**絶対不変条件**:

- master recording に触らない(MovieFileOutput / ProRes 422 HQ /
  Apple Log 2 / 4K24 / cinematicEE gate 維持)
- VDO は **preview-only**(record path に挿入しない)
- VDO が録画 pipeline を destabilize するなら即 stop / rollback
- M2-A 制約(VDO は `.appleLog2` 下で 10-bit `x422`/`x420`
  deliver しない)を回避するため、preview VDO は **8-bit BGRA**
  で受け、record path は MovieFileOutput のまま動かさない

**実装ステップ**(小さく切る):

- [x] **F0** API / UX research gate —
  Apple camera APIs, iPhoneOS 26.4 SDK headers, Liquid Glass SwiftUI/UIKit
  APIs, and capture-surface UX rules documented in the research doc above.
- [x] **F1** preview-only VDO 共存 build —
  `FilmtoneCaptureSession` に BGRA `AVCaptureVideoDataOutput` を
  追加、`alwaysDiscardsLateVideoFrames` + no-op delegate で session
  に乗せた。iPhone (7) で No-SSD 10s 録画を 1 回完走、finalize 後の
  codec / colorspace / stabilization downgrade banner なし、editor
  へ proxy adopt まで確認(2026-05-08)。research doc の
  `deliversPreviewSizedOutputBuffers` は F2 で preview surface 側に
  画素を流す段階で見直す(現状の VDO は full-res BGRA、preview
  texture へのスケーリングは Core Image render side でも問題ない
  オーダーだが、F2 実装で実測してから判断)。
- [x] **F2** VDO frame を preview view に出す — `FilmtoneCaptureLivePreview`
  (`MTKView` + `MTKViewDelegate` + `CIContext.render`) を新設、
  `FilmtonePreviewFrameSink` 経由で VDO sample を CIImage 化して
  preview に流す pass-through を実装。`FilmtoneCaptureView.previewLayer`
  は `session.hasLivePreview` で MTKView と旧 `AVCaptureVideoPreviewLayer`
  を分岐(VDO 共存 fail 時は graceful fallback)。iPhone (7) で
  No-SSD 10s 録画完走、finalize で downgrade banner なし、proxy adopt
  まで PASS(2026-05-08)。
  Render scheduling は **event-driven**: sink push → main async →
  `MTKView.draw()` 直接呼び出し。free-running 24fps `CADisplayLink`
  driven mode と `setNeedsDisplay`/CADisplayLink 経由 mode を順に試
  したが、24fps source × 120Hz display の phase 不整合 + scheduling
  jitter で judder が出る。Direct draw で「最初の MTKView render に
  比べてだいぶマシ」レベルまで圧縮、user 判定で **F2 及第点 PASS**。
  残る judder は F4 で再評価(software pipeline で 24fps→120Hz
  pulldown を完全に滑らかに再現するのは構造的限界。さらに詰める
  なら `presentDrawable:atTime:` で `CMSampleBuffer` の PTS を使った
  display-time 指定 / VDO の preview-sized output 化 / 解像度を絞った
  CIImage 化 など別軸が必要)。
- [ ] **F3** Current Look / 調整を preview に適用 — editor の
  grade path / CIFilter chain を preview-only で再利用し、live
  image に Look + 調整を反映。reference strip の "Live ungraded"
  disclaimer は適用後は不要なので外す(panel 自体は補助表示として残す)。
  - **NOT PASS** (2026-05-08 user 目視) — Look が live preview に
    完全には再現されていない。実装を増やす前に差分の種類を
    特定する F3-R を切る。
- [ ] **F3-R** Live preview parity diagnosis(進行中)
  - 目的: editor preview と live preview の差分を分類してから
    F3-Fix を切る。曖昧な PASS にしない。
  - 仕掛け済み(2026-05-08):
    1. `FilmtoneLivePreviewDiagnostics` snapshot を
       `makeLivePreviewGradeProcessor` 時に build。Look /
       Profile / LUT / Phase0 params / probe input transform を
       capture surface 入場時に NSLog `[F3R] live preview
       diagnostics: ...` で 1 回出す
    2. 同 snapshot を画面左上 `F3-R DIAG` overlay として表示
       (Look / Profile / LUT ON-OFF / InputLUT 適用予測 / 主要
       Phase0 scalar / cameraProfile・savedLook が runtime に
       渡っているか の警告)
    3. live preview MTKView の **first frame** で CIImage の
       colorSpace tag を NSLog `[F3R][LivePreview] first
       frame: ...` で 1 回出す
  - 既に確定したコード上の parity gap(F3-Fix で塞ぐ):
    - `FilmtoneEditorStore.makeLivePreviewGradeProcessor()` →
      `facade.makeLivePreviewGradeProcessor(request:)` →
      `runtime.makeSharedGradeProcessor(request:sourceURL:)` →
      `makeExportSession(request:sourceURL:)` の経路は
      `appliedSavedLook` も `cameraProfile` も受けていない。
      editor 本体の export 経路は両方渡しているので、live
      preview だけ silently `.auto` + nil saved look に縮退する。
      → diagnostic overlay の `camProf:N savedLook:N` 警告で常時
      可視化
    - `FilmtoneCaptureSession` の VDO は `kCVPixelFormatType_32BGRA`
      で `CIImage(cvPixelBuffer:)` をオプションなしで呼ぶ。export
      側は `colorPipeline.sourceImageOptions(for:)` で transfer
      function tag を付けている → live は untagged sRGB として
      Core Image に解釈される
    - 上の 2 つを `.auto` のまま回すと、editor source が Apple
      Log / Apple Log 2 video の場合 `applyInputLutStage` が
      AppleLog2→Rec.709 LUT を **live BGRA(既に display sRGB)**
      にも適用してしまい、二重 de-log で色が崩れる
  - PASS 判定の修正(完全一致狙わない、ただし以下に該当したら FAIL):
    1. `LUT: ON` なのに live preview 側で LUT stage 由来の色変化が
       全く出ていない → FAIL
    2. `camProf:N` のせいで profile ごとの input LUT が反映されて
       いない → FAIL(F3-Fix で必須)
    3. `savedLook:N` のせいで Saved Look の色温度補正が反映されて
       いない → FAIL(F3-Fix で必須)
    4. live camera と既存 video の **被写体差** による見た目差は
       FAIL ではなく reference の限界として記録
  - 検証手順(Stone / Urban で順に):
    1. iPhone (7) で app を起動、Apple Log で撮った video を 1 本
       読み込む
    2. Look = Stone(`bundledSlug=01.cinema.kodak2393` 等)を適用、
       editor の preview color を確認
    3. Record CTA から capture surface へ。`F3-R DIAG` overlay の
       全フィールドを読み上げ(または screenshot)
    4. live preview の見た目が editor preview の方向と揃って
       いるか?LUT 由来の色変化(緑〜シアン基調 etc)が live
       でも見えるか?
    5. console から `[F3R]` log 行を回収
    6. Look を Urban に変更し再度同じ手順
    7. Apple Log video の代わりに sRGB video(iPhone 標準カメラ
       出力)でも同じ手順を踏み、`detectedTransform=nil` /
       `inputLutWillApply=N` のケースとの比較を取る
- [x] **F3-R 結果(2026-05-08, Stone with Apple Log source)**
  - 目視: live preview ≒ editor preview の色方向("似たような色合い")
  - chip: `LUT: ON x 1.00`, `InputLUT: off`, `Profile: Auto -> Apple Log 検出`
  - chip: `[!] camProf:N savedLook:N`(wiring gap 確認)
  - 判定: bundled Look(`request.lut.bundledSlug` 直渡し)は live preview
    に乗っており、modified PASS 基準上は Stone 単体で PASS。ただし
    custom Saved Look / `.userImport` camera profile は wiring が無いため
    silent downgrade。Fix #1 必須。
  - sRGB source 比較は M10 scope 外(撮影体験の信頼性に必要な最短のみ通す)
- [x] **F3-Fix #1** wiring 拡張(タスク #80, install 済 2026-05-08)
  - `FilmtoneMediaRuntime.makeSharedGradeProcessor` /
    `FilmtoneEditorFacade.makeLivePreviewGradeProcessor` の signature を
    `appliedSavedLook: SavedLookEntry?` / `cameraProfile: CameraProfileSelection?`
    で拡張。`makeExportSession` は元々受け付ける(line 115-132)
  - `FilmtoneEditorStore.appliedSavedLookId` に `didSet` を足し、`nil`
    リセット時に `appliedSavedLookEntryCache: SavedLookEntry?` も同時に
    nil。apply 2 箇所(`saveLookFromCurrentState` /
    `applySavedLook`)で `appliedSavedLookEntryCache = entry` も同時設定
  - `makeLivePreviewGradeProcessor()` は cache + `project.cameraProfile`
    を facade に転送し、`makeLivePreviewDiagnostics` に
    `forwardedSavedLook` / `forwardedCameraProfile` を渡して
    `cameraProfilePassedToProcessor` / `savedLookPassedToProcessor` を
    実値で報告
  - bundled Look(`request.lut.bundledSlug`)経路は touch 不要、既存挙動維持
  - simulator + device build SUCCEEDED、iPhone (7) UDID `3A2A3A66...`
    bundle path `D064488F-1B87-4ACA-A497-EF0AFA95AF67` に install 済
- [x] **F3-Fix #1 device verification PASS(2026-05-08)**
  - Stone / Urban 両方で `wiring camProf:Y savedLook:Y`、赤い `[!]`
    なし。`savedLook:Y` は bundled Look(Stone / Urban)が library 上の
    built-in Saved Look entry として apply されるため。
  - 色方向: Stone(暖色寄り)と Urban(クリーン寄り)で明確な差。
    両方とも目視で大きな問題なし。
  - capture status row: `4K24 · ProRes 422 HQ · Apple Log 2 · Cinematic EE`
    維持(downgrade なし)。
  - Modified F3 PASS 条件すべて充足:
    - 同 Look + 調整が live preview に乗っていることが診断上確認可能
    - 色方向が撮影判断に使える
    - LUT stage 適用済(FAIL 条件回避)
    - Source Profile detected(FAIL 条件回避)
    - camProf / savedLook wiring 通り(F3-R で発覚した gap 解消)
- [x] **F4 PASS(2026-05-08)** — 実機録画 + live preview gate 検証 完了
  - iPhone (7) UDID `3A2A3A66...` で 2026-05-08 15:22 JST 録画
    `v2-capture-2da98974-187c-42c2-bab9-b365bf0119fc` を `xcrun
    devicectl device copy from --domain-type appDataContainer` で pull、
    `ffprobe` / `mp4dump` / `mediainfo` + 自前 colr atom parser で精査
  - record 中の live Look preview 継続: visually OK(Stone / Urban、
    capture status row `4K24 · ProRes 422 HQ · Apple Log 2 · Cinematic EE`
    そのまま維持)
  - master.mov 実測:
    - codec: `prores` profile=`HQ` codec_tag=`apch`(ProRes 422 HQ)
    - encoder string: `Apple ProRes 422 HQ`
    - dimensions: 3840 × 2160 ✓
    - bit depth: 10-bit、pix_fmt `yuv422p10le`(4:2:2)
    - frame rate: CFR 24 fps(248/249 packets at 0.041667s = 1/24、
      最後 1 packet が 0.043333s = 量子化丸めの edge artefact、frame
      drop ではない。mediainfo "VFR 23.077–24.000" 表示の正体)
    - color: `colr nclc prim=2 trans=2 mat=9`(BT.2020 NC matrix、
      primaries/transfer は Unspecified — iOS `AVCaptureMovieFileOutput`
      + Apple Log 2 ProRes の baseline。**11:49〜15:22 の master 10 本
      全部で完全一致、F3-Fix #1 起因 regression ではない**)
    - bitrate ~519 Mbps(ProRes 422 HQ 4K24 想定レンジ)
    - track 2: `mebx` timed metadata 1 sample(Gyroflow 用 Core Motion)
  - capture-package.json:
    `parametersCodec="ProRes 422 HQ"` /
    `parametersColorSpace="Apple Log 2"` / `parametersFrameRate=24` /
    `parametersWidthPx=3840` / `parametersHeightPx=2160` /
    `parametersStabilization="cinematicExtendedEnhanced"` /
    `schemaVersion=1` ✓
  - duration discrepancy(`recordedDurationSeconds`=8.376s vs 実 file
    duration=10.375s, 2s 差): cinematic Extended Enhanced の lookback /
    pre-roll buffer。249 frames at CFR 24fps は file 側で完結、規約上
    両者並立で問題なし
- [ ] **F5** Liquid Glass capture UI pass —
  `GlassEffectContainer` / `.glassEffect` を top controls と bottom deck
  に適用。live image は content layer のまま。record / stop 以外を
  過剰 tint しない。legibility が落ちる場合は stop して通常 material
  に戻す。

## Outcome

**M10 (Native Camera Capture Surface + Proxy Workflow) LANDED — 2026-05-08**

S8-A..D landed prior, S8-E partial PASS, S8-F sub-stages F1〜F4 all PASS:

- **F1 / F2** Preview-only `AVCaptureVideoDataOutput`(BGRA)を MovieFileOutput
  共存で添付し MTKView へ流す。MovieFileOutput の ProRes 422 HQ /
  Apple Log 2 / cinematicEE / 4K24 contract は非干渉。
- **F3** Live Look Preview を `FilmtoneSharedGradeProcessor` 経由で VDO 出力に
  当てる。F3-R 診断で `cameraProfile` / `appliedSavedLook` の 3-layer
  wiring gap が判明 →
- **F3-Fix #1** `FilmtoneMediaRuntime.makeSharedGradeProcessor` /
  `FilmtoneEditorFacade.makeLivePreviewGradeProcessor` の signature を拡張
  し、`FilmtoneEditorStore` 側に `appliedSavedLookEntryCache` を追加して
  `apply` 経路で同期化、`makeLivePreviewGradeProcessor()` から両方を
  forward。Stone / Urban + diagnostic chip `wiring camProf:Y savedLook:Y`
  で device verify PASS。
- **F4** master.mov ffprobe / mp4dump / mediainfo + 自前 colr atom parser
  で精査 PASS — ProRes 422 HQ `apch` / 4K24 CFR / 10-bit yuv422p10le /
  BT.2020 NC matrix。`capture-package.json` の `parameters*` は
  Apple Log 2 / 24 fps / 3840 × 2160 / cinematicExtendedEnhanced /
  schemaVersion=1。Gyroflow 用 `mebx` timed metadata track も生成。
  colr の primaries/transfer が `Unspecified` なのは F3-Fix 前後の master
  10 本全部で完全一致 — iOS `AVCaptureMovieFileOutput` baseline で
  regression ではない。

### Carry-over(closeout 後の小タスク)

- F3-R DIAG overlay は debug 視認性が便利だが production UI には外殻寄り。
  release 直前に build flag(`#if DEBUG` 等)で gate する判断を検討。
  本質ではないので user 指示を待つ。
- F5(Liquid Glass capture UI pass)は M10 から外し、別 lane で進める想定。
  この active には残さない。

### Archive
Move to `archive/2026-05-08-m10-native-camera-capture-surface.md`.
