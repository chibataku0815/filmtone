# Filmtone Connect C052 Visual Equivalence Next Chat Handoff

Date: 2026-04-30 JST  
Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package`  
Branch: `feature/filmtone-davinci-connect-package`

## 0. Read This First

This document is the next-chat handoff after real Apple Log device/package
verification succeeded.

Do not restart from broad investigation. Do not redo the old C059 unknown-color
path. Do not treat package creation, sharing, Resolve import success, or node-1
DCTL visibility as the remaining product goal.

The remaining unfinished core work is:

```text
Measure and close visual equivalence for the real C052 Apple Log package:
iOS Filmtone rendered output vs DaVinci Resolve DCTL output from the same
original Apple Log source media.
```

The user explicitly said the white/flat Apple Log conversion appearance is not
the issue to pursue. Do not pivot into "make the iOS render less white" unless
new evidence or a new user request changes that.

## 1. Current Product State

### Completed / Accepted In This Thread

- Physical iPhone could select/import a real Apple Log source.
- Filmtone iOS exported a Connect package.
- The shared package contains the full expected v2 package set.
- The sidecar proves Apple Log classification:
  - `colorClass = apple-log`
  - `inputTransformPolicy.strategy = apple-log-to-rec709`
  - `sourceVideoMetadata.inputTransformPolicy.strategy = apple-log-to-rec709`
- The output MP4 is Rec.709 SDR:
  - `bt709 / bt709 / bt709`
  - `1080x1920`
  - `24fps`
- The package imports into DaVinci Resolve.
- Resolve applies the generated DCTL bridge on node 1.
- `ResolveDebug.txt` showed no `Error Processing DaVinci CTL` after import.
- The temporary `AppDelegate.swift` validation hook was removed. Confirmed:
  - `git diff -- apps/capacitor-film-lab-ios/ios/App/App/AppDelegate.swift`
    is empty.
- Normal device Debug build succeeded after hook removal.
- Normal app was installed back to the physical iPhone.

### Not Yet Completed

The whole Filmtone Connect product goal is still not complete:

```text
The same original Apple Log source should produce a visually equivalent
Filmtone result on iOS and in DaVinci Resolve through Filmtone Connect.
```

Next chat must compare:

1. iOS rendered output / reference from the C052 package.
2. Resolve DCTL output generated from the original source media in that same
   package.
3. Resolve no-LUT output as the baseline.

Only after those metrics and side-by-side sheets support the claim can visual
equivalence be called complete.

## 2. Simulator vs Physical Device

Short answer:

```text
The remaining visual-equivalence work can mostly proceed on Mac/Resolve from
the already shared C052 package. The simulator is not a complete replacement
for physical-device export validation.
```

What the simulator can reasonably cover:

- Swift contract tests.
- Sidecar builder contract tests.
- DCTL writer assertions.
- Web build / Capacitor copy.
- Simulator app build.
- Source classifier logic if tested with fixtures.
- Resolve import/export and image comparison from an already existing package.
- Reproducing visual-equivalence metrics from files already on the Mac.

What still needs a physical device when revalidating export behavior:

- Real Photos picker behavior.
- Real iPhone media import from Photos/Files.
- Real Apple Log ProRes decode/export path on Apple hardware.
- Real Photos save and iOS share sheet behavior.
- Performance and thermal/realtime export measurements.
- Real package availability after Photos save/share.

Why this matters:

- Earlier C059 simulator export failed with `exportFailed("デコードできません")`.
- The physical device succeeded on the ProRes path.
- Therefore, simulator is acceptable for code/contract/logic checks and Mac-side
  Resolve comparison, but not as proof that the iPhone Apple Log export path
  works on device.

For the next unfinished gate, do not spend time trying to make the simulator
re-export C052. Use the already shared package unless a fresh export is needed.

## 3. Primary Fixture For Next Chat

Use this as the active package:

```text
/tmp/filmtone-connect-user-share-d42927bb
```

Package prefix:

```text
filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652
```

Reference time:

```text
5.885419501133787s
```

Known package files:

```text
/tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652.mp4
/tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652.mp4.filmtone-ios-export-session-v1.json
/tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-source.mov
/tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-pre-optical-color.cube
/tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-post-optical-color.cube
/tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-combined-color.cube
/tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-filmtone-bridge.dctl
/tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-reference-after.jpg
```

If `/tmp/filmtone-connect-user-share-d42927bb` is missing, recreate it from
the files the user shared into this chat. Original shared paths were:

```text
/Users/chibatakumi/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard/items/22CF212B-8D90-44F8-9EAA-1FD69C2A6AA3/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652.mp4
/Users/chibatakumi/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard/items/8EB235BA-83DE-4013-981B-14FC7BF0CB36/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652.mp4.filmtone-ios-export-session-v1.json
/Users/chibatakumi/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard/items/850351F5-333C-4F01-AE0E-382E0047DE6D/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-source.mov
/Users/chibatakumi/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard/items/8CE800C6-EEC8-41AD-98BA-A3ACDA8E39A7/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-pre-optical-color.cube
/Users/chibatakumi/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard/items/05D0D6B4-C784-45BD-9187-CFEEA3EE917D/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-post-optical-color.cube
/Users/chibatakumi/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard/items/FE5CB98B-FDDB-4D1A-93EC-39C775AD62E4/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-combined-color.cube
/Users/chibatakumi/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard/items/60F3CE4C-025E-4D46-B935-D32D1926196A/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-filmtone-bridge.dctl
/Users/chibatakumi/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard/items/6021E924-491C-4BD2-B0B6-7E3C596BA1B9/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-reference-after.jpg
```

Do not copy the 584 MB source media into the repository.

## 4. Sidecar Proof Already Observed

Command used:

```sh
jq '{
  exportedAtIso,
  filename: .input.filename,
  colorClass: .input.sourceProbe.sourceVideoMetadata.colorClass,
  inputStrategy: .input.sourceProbe.inputTransformPolicy.strategy,
  metadataInputStrategy: .input.sourceProbe.sourceVideoMetadata.inputTransformPolicy.strategy,
  logTransfer: .input.sourceProbe.sourceVideoMetadata.logTransferFunction,
  codecFamily: .input.sourceProbe.codecFamily,
  width: .input.sourceProbe.width,
  height: .input.sourceProbe.height,
  durationSec: .input.sourceProbe.durationSec,
  package: .package,
  output: .output
}' \
  /tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652.mp4.filmtone-ios-export-session-v1.json
```

Observed result:

```json
{
  "exportedAtIso": "2026-04-30T13:53:01.969Z",
  "filename": "16promax001_04301632_C052",
  "colorClass": "apple-log",
  "inputStrategy": "apple-log-to-rec709",
  "metadataInputStrategy": "apple-log-to-rec709",
  "logTransfer": "apple-log",
  "codecFamily": "prores-422",
  "width": 2160,
  "height": 3840,
  "durationSec": 23.5685,
  "package": {
    "effects": {
      "dctl": "filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-filmtone-bridge.dctl"
    },
    "layout": "filmtone-connect-package-v2",
    "luts": {
      "combinedColor": "filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-combined-color.cube",
      "postOpticalColor": "filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-post-optical-color.cube",
      "preOpticalColor": "filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-pre-optical-color.cube"
    },
    "mediaFilename": "filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-source.mov",
    "referenceAfterFilename": "filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-reference-after.jpg",
    "referenceAfterTimeSec": 5.885419501133787,
    "renderedMediaFilename": "filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652.mp4",
    "sourceMediaFilename": "filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-source.mov"
  },
  "output": {
    "codec": "h264",
    "colorPrimaries": "bt709",
    "colorSpace": "bt709",
    "colorTransfer": "bt709",
    "container": "mp4",
    "degradedDecodePath": false,
    "elapsedMs": 11822,
    "fileSizeBytes": 37075413,
    "fps": 24,
    "longEdge": 1920,
    "outputColorProfile": "rec709-sdr-mp4",
    "outputHeight": 1920,
    "outputWidth": 1080,
    "preserveAudio": true,
    "realtimeRatio": 0.5016017141523644
  }
}
```

## 5. Media Probe Observations

Rendered iOS output:

```text
Input: filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652.mp4
Duration: 23.541667s
Codec: h264 High
Pixel format: yuv420p
Resolution: 1080x1920
FPS: 24
Color: bt709 / bt709 / bt709
Audio: aac LC, 44100 Hz, stereo
Size: 37,075,413 bytes
```

Original source media in package:

```text
Input: filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-source.mov
Original clip ID: 16promax001_04301632_C052
Captured: 2026-04-30T16:32:45+0900
Camera app: Blackmagic Cam 3.3.100001
Camera: Apple iPhone 17 Pro 13mm
Codec: Apple ProRes 422 LT / apcs
Pixel format: yuv422p10le
Raw resolution: 3840x2160
Display resolution via transform: 2160x3840
FPS: 24000/1001
Color metadata from ffprobe: bt2020nc / bt2020 / unknown
Sidecar-normalized log transfer: apple-log
Size: 612,242,097 bytes
```

## 6. Resolve Import Already Passed

Command:

```sh
LOG="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt"
BEFORE=$(wc -c < "$LOG" 2>/dev/null || echo 0)
echo "$BEFORE" > /tmp/filmtone-resolve-log-before-d429.txt

cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-user-share-d42927bb
```

Important output:

```text
[Filmtone Connect] layout: filmtone-connect-package-v2
[Filmtone Connect] source media: /tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-source.mov
[Filmtone Connect] rendered media: /tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652.mp4
[Filmtone Connect] lut: /tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-combined-color.cube
[Filmtone Connect] dctl: /tmp/filmtone-connect-user-share-d42927bb/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-filmtone-bridge.dctl
[Filmtone Connect] applied staged LUT to node 1: Filmtone Connect/filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652-filmtone-bridge.dctl
[Filmtone Connect] applied Filmtone DCTL bridge; DCTL references package color LUTs
[Filmtone Connect] imported reference still into Gallery
[Filmtone Connect] done.
```

Resolve log check after import:

```sh
LOG="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt"
BEFORE=$(cat /tmp/filmtone-resolve-log-before-d429.txt)
AFTER=$(wc -c < "$LOG" 2>/dev/null || echo 0)
printf 'before=%s after=%s\n' "$BEFORE" "$AFTER"
tail -c +$((BEFORE + 1)) "$LOG" \
  | rg -n "Error Processing DaVinci CTL|DCTL|Filmtone|Error|Traceback|Lua|LUT" || true
```

Observed:

```text
before=299573 after=303297
No "Error Processing DaVinci CTL" found in the searched log range.
```

## 7. Existing Quick Frame Extraction

The following temporary frames were extracted during the thread:

```text
/tmp/filmtone-d429-frames/source-at-reference.jpg
/tmp/filmtone-d429-frames/output-at-reference.jpg
/tmp/filmtone-d429-frames/reference-after.jpg
/tmp/filmtone-d429-frames/output-vs-reference-rmse.png
```

They were used only for quick sanity, not as final visual-equivalence proof.

Quick ImageMagick stats:

```text
source-at-reference.jpg:    mean=0.469085 std=0.101214 min=7453  max=53713
output-at-reference.jpg:    mean=0.569828 std=0.111058 min=20817 max=65535
reference-after.jpg:        mean=0.630359 std=0.0982656 min=26214 max=65535
output vs reference RMSE:   4274.17 (0.0652196)
```

Do not overinterpret these stats. The user said the white/flat appearance is
not the target issue. The next required work is iOS-vs-Resolve equivalence.

## 8. Code Changes Made In This Thread

These changes were made to fix the share/save UX and should be preserved unless
the user explicitly asks otherwise:

### `FilmtoneEditorStore.swift`

- `saveExportResultToPhotos(_:)` no longer deletes local export/package files
  after Photos save.
- `shareOutput()` no longer deletes local export/package files after a
  completed share.
- Rationale: Filmtone Connect packages must remain available for subsequent
  share/inspection after Photos save and after share. Deleting them caused
  "saved but cannot share" behavior.

### `FilmtoneExportPanel.swift`

- Primary export button is now `exportStart` / `export()` instead of
  `exportAndSave()`.
- Finished-state buttons now have accessibility identifiers:
  - `filmtone.export.finished.saveToPhotos`
  - `filmtone.export.finished.share`
- Share button is disabled while Photos save is active.
- Save button label changes to saved-state label after save.
- Primary/secondary custom button styles now visually reflect disabled state.

### `FilmtoneRootView.swift`

- Toast overlay has `.allowsHitTesting(false)` so it cannot block controls.
- Unsaved export prompt share button is disabled while saving.
- Decorative prompt overlays have `.allowsHitTesting(false)`.

### `AppDelegate.swift`

- A temporary validation hook was added during device automation and then
  removed.
- Current expected diff for this file is empty.

## 9. Current Working Tree Context

At handoff time, `git status --short` showed:

```text
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift
 M apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
 M apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-a001-minimal-effect-probe-handoff-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-a001-v2-complete-handoff-and-next-prompt-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-a001-v2-next-chat-handoff-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-device-apple-log-verification-next-chat-handoff-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-log-source-visual-equivalence-handoff-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-visual-equivalence-device-verified-handoff-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-visual-equivalence-next-chat-handoff-2026-04-30-jst.md
```

Do not revert unrelated dirty files. Some modified files predate this thread
and contain previous Connect v2/DCTL work.

`git diff --check` passed after the share/save fixes.

## 10. Relevant Existing Planning Docs

Use this document as the latest handoff, then consult:

```text
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-visual-equivalence-next-chat-handoff-2026-04-30-jst.md
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-device-apple-log-verification-next-chat-handoff-2026-04-30-jst.md
```

Important interpretation update:

- The old device Apple Log handoff said Apple Log verification was not complete
  because C059 probed as `unknown`.
- That is now superseded by the C052/d429 shared package, whose sidecar proves
  Apple Log classification.
- The old visual-equivalence handoff's core product goal remains valid.

## 11. Next Work: Exact Decision Path

Follow this order.

1. Confirm the d429 package exists and sidecar still proves Apple Log.
2. Import/re-import package into Resolve if needed.
3. Export a Resolve DCTL still at `referenceAfterTimeSec`.
4. Export a Resolve no-LUT still at the same time.
5. Extract the corresponding iOS rendered frame from the package MP4.
6. Normalize orientation/resolution/color handling consistently.
7. Compute:
   - iOS rendered/reference vs Resolve DCTL
   - iOS rendered/reference vs Resolve no-LUT
   - Resolve DCTL vs Resolve no-LUT
8. Generate side-by-side and diff sheets.
9. Decide:
   - If Resolve DCTL is meaningfully closer than no-LUT and visually acceptable,
     record the metrics as the C052 Apple Log equivalence baseline.
   - If Resolve DCTL is not closer or visually wrong, improve the DCTL bridge
     using the existing scalar-safe, small-promotion rules.

Do not change iOS Apple Log tone unless the user explicitly reopens that issue.

## 12. DCTL / Resolve Rules

Resolve can silently fail while the UI still shows a DCTL on node 1.

Always check:

```text
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt
```

Failure signature:

```text
Error Processing DaVinci CTL
```

Avoid in DCTL:

- custom `float3` helper functions
- `float3` accumulation / vector arithmetic
- large helper-heavy DCTL blocks
- promoting many optical effects at once

Prefer:

- texture transform signature
- `DEFINE_LUT`
- `_tex2D`
- `APPLY_LUT`
- scalar helper functions only
- direct scalar math in `make_float3(...)`

Promotion gate for any DCTL change:

- `ResolveDebug.txt` has no CTL error.
- output differs meaningfully from no-LUT.
- output is compared against iOS, no-LUT, and previous production baseline.
- no visual-equivalence claim unless metrics and visual inspection agree.

## 13. Verification Commands

Swift contract:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bun run verify:swift-contract
```

Web build:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bun run build
```

Capacitor copy:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bunx cap copy ios
```

iOS Simulator build:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/filmtone-ios-simulator-derived \
  build
```

Physical device Debug build if needed:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -destination 'id=00008150-001674883C84401C' \
  -derivedDataPath /tmp/filmtone-connect-device-derived \
  build
```

Whitespace:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
git diff --check
```

## 14. Highest-Precision Next Chat Prompt

Paste this into the next chat:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-c052-visual-equivalence-next-chat-handoff-2026-04-30-jst.md

本質の進行を最優先にして、外殻は最小限、品質保証が必要な時だけ行ってください。
保守的な意見ではなくプロダクト品質を優先してください。
思考すべきところは必ず sequential-thinking を使ってください。
わからないことがある場合はローカルソースを確認し、必要なら検索してください。
複数の独立した確認は並列に実行してください。

目的:
Filmtone Connect の未校了の本筋を進めます。
Apple Log実機検証、共有パッケージ生成、sidecar Apple Log証明、Resolve import、DCTL適用、CTLエラーなしは完了済みです。
残っている本筋は、C052/d429 の実Apple Logパッケージで iOS Filmtone出力と DaVinci Resolve DCTL出力の visual equivalence を測定し、必要ならDCTL bridge側を改善することです。

重要:
白っぽいApple Log変換品質は今回は問題として扱わないでください。
シミュレーターで実機Apple Log ProRes exportを再検証しようとする必要はありません。
次の未校了ゲートは既に共有済みの package を使って Mac/Resolve 側で進められます。
ただしシミュレーターは contract/build/classifier などの補助確認には使って構いません。

最初に読むもの:
1. このhandoff:
   docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-c052-visual-equivalence-next-chat-handoff-2026-04-30-jst.md
2. 全体計画:
   docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md
3. 必要なら:
   docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-visual-equivalence-next-chat-handoff-2026-04-30-jst.md

使う主フィクスチャ:
/tmp/filmtone-connect-user-share-d42927bb

パッケージprefix:
filmtone-export-d42927bb-2320-447a-b503-793eb5fa9652

参照時刻:
5.885419501133787s

最初に確認すること:
1. /tmp/filmtone-connect-user-share-d42927bb が存在するか。
2. sidecar が colorClass=apple-log と inputTransformPolicy.strategy=apple-log-to-rec709 を示すか。
3. Resolve import が必要なら再実行し、ResolveDebug.txt に Error Processing DaVinci CTL がないことを確認する。

次に実行する本筋:
1. Resolve DCTL still を referenceAfterTimeSec で書き出す。
2. Resolve no-LUT still を同じ時刻で書き出す。
3. iOS rendered MP4 から同じ時刻のフレームを抽出する。
4. orientation/resolution/color handling を揃えて正規化する。
5. 以下を比較する:
   - iOS rendered/reference vs Resolve DCTL
   - iOS rendered/reference vs Resolve no-LUT
   - Resolve DCTL vs Resolve no-LUT
6. MAE/RMSE と side-by-side / diff sheet を作る。
7. DCTL が no-LUT より意味のある改善をしているか、視覚的に許容できるかを判断する。

判断:
- 改善していて視覚的に許容できるなら、C052 Apple Log equivalence baseline として記録する。
- 改善が弱い/悪化/視覚的に違うなら、iOSの白っぽさではなく Resolve DCTL bridge / 残り光学効果側を小さく安全に改善する。

禁止:
- package生成成功だけで完了扱いにしない。
- Resolve UIにDCTLが見えるだけで成功扱いにしない。
- CTLログ確認を省略しない。
- C059 unknown-color の古い検証に戻らない。
- 白っぽさを勝手にiOSトーン修正課題へ戻さない。
- 未検証の visual equivalence claim を書かない。
- unrelated dirty files を revert しない。

最後に、実行したコマンド、生成物パス、MAE/RMSE、CTL error有無、次に残る判断を端的に報告してください。
```
