# Filmtone Connect Device Apple Log Verification Handoff

Date: 2026-04-30 JST  
Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package`  
Branch: `feature/filmtone-davinci-connect-package`

## Read This First

The next task is not broad investigation. The next task is:

1. Use the connected physical iPhone.
2. Select/import a real Apple Log source in the Filmtone iOS app.
3. Export a Filmtone Connect package.
4. Verify that the package sidecar proves the app classified the source as Apple Log.
5. Only then run Resolve import/export and compare iOS vs Resolve.

The previous device verification proved that the physical-device export/package/Resolve path works. It did not prove Apple Log visual equivalence because the tested C059 source was classified by iOS as `unknown`, not Apple Log.

## User Intent and Operating Rules

- Prioritize core product progress over documentation, issue hygiene, or broad audits.
- Do not treat package creation, Resolve import success, or LUT/DCTL presence as success.
- The product goal is iOS/Resolve visual equivalence from the same source media.
- Use sequential thinking for actual design/product-quality decisions.
- If local source does not answer a material question, search with Gemini/web search or ask only when the answer changes implementation.
- Do not revert unrelated dirty files.
- Do not touch docs/handoff again unless explicitly asked or QA/promotion requires it.

## Current Production Baseline

The current working baseline includes earlier promoted Filmtone Connect DCTL work:

- Scalar-safe RGB shift.
- Edge-masked softness.
- Center-masked / mip-like diffusion after softness.
- Split pre-optical and post-optical LUT flow.
- Resolve texture color compensation, including HLG-only compensation.

Known A001 production baseline after promoted diffusion:

```text
A001 iOS vs Resolve production diffusion:
MAE 17.150627
RMSE 25.384333
ctl_error false
visual sheet: /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-mip-diffusion-probe-sheet.png
```

Older diffusion baseline recorded in master plan:

```text
MAE 17.401151
RMSE 25.555996
ctl_error false
```

HLG non-Apple-Log validation was also completed and promoted:

```text
Source: /Users/chibatakumi/Downloads/C0061.MP4
Trim: /tmp/filmtone-connect-validation-c0061-hlg-6s.mp4

Before HLG gain:
DCTL vs iOS MAE 20.686066
DCTL vs iOS RMSE 24.701220
no-LUT vs iOS MAE 19.756489
no-LUT vs iOS RMSE 25.562290

After HLG-only gain 0.920 / 0.883 / 0.924:
DCTL vs iOS MAE 14.069118
DCTL vs iOS RMSE 21.609453
no-LUT vs iOS MAE 19.756489
no-LUT vs iOS RMSE 25.562290
ctl_error false
visual sheet: /tmp/filmtone-connect-c0061-hlg-gain-probe/compare/visual-sheet.png
```

Promoted HLG code path:

```swift
if request.sourceProbe?.sourceVideoMetadata?.colorClass == .hdrHlg {
    return (red: 0.92000000, green: 0.88300000, blue: 0.92400000)
}
```

## Current Dirty Worktree Context

Before this handoff was written, `git status --short` showed these existing changes:

```text
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
 M apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
 M apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-a001-minimal-effect-probe-handoff-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-a001-v2-complete-handoff-and-next-prompt-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-a001-v2-next-chat-handoff-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-log-source-visual-equivalence-handoff-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-visual-equivalence-device-verified-handoff-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-visual-equivalence-next-chat-handoff-2026-04-30-jst.md
```

This new handoff file is an additional untracked doc. Do not revert or clean unrelated files.

Important: a temporary `AppDelegate.swift` validation hook was added during device automation and removed afterward. `git diff -- apps/capacitor-film-lab-ios/ios/App/App/AppDelegate.swift` was empty after removal.

## Verification Already Passed Before Device Work

After HLG compensation promotion:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bun run verify:swift-contract
bun run build
bunx cap copy ios
```

All passed. `bun run build` only had the existing Vite chunk warning.

Simulator build also passed:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -destination 'id=D47FDCA4-BB84-41E1-9683-319D0F059CDF' \
  -derivedDataPath /tmp/filmtone-connect-validation-derived \
  build
```

`git diff --check` passed.

## Device Used

Physical device detected:

```text
Name: 千葉工のiPhone (7)
Model: iPhone 17 Pro
Xcode destination id: 00008150-001674883C84401C
devicectl identifier: 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9
OS: 26.3.1
Interface: USB
```

`xcrun devicectl` printed a provisioning provider warning but still worked:

```text
Failed to load provisioning paramter list due to error:
Error Domain=com.apple.dt.CoreDeviceError Code=1002 "No provider was found."
```

This warning did not block install, file copy, launch, or retrieval.

## What Was Verified on Device

Source tried for Apple Log validation:

```text
Original: /Users/chibatakumi/Downloads/16promax001_04021250_C059.MOV
Trim used: /tmp/filmtone-connect-validation-c059-6s.mov
Container/codec: QuickTime ProRes 422 LT
Resolution: 3840x2160 source, portrait transform to 2160x3840
Duration: 6.006333s
ffprobe color metadata: bt2020nc / bt2020 primaries, no explicit Apple Log transfer
```

Simulator result before device:

```text
Simulator production export failed:
{"status":"error","error":"exportFailed(\"デコードできません\")"}
```

This was treated as a Simulator ProRes decode limitation, so physical device was used.

Physical device result:

```text
Device export succeeded.
Exit code: 0
Recovered package: /tmp/filmtone-connect-c059-device-validation
```

Recovered package files:

```text
/tmp/filmtone-connect-c059-device-validation/result.json
/tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5-reference-after.jpg
/tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5-pre-optical-color.cube
/tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5-source.mov
/tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5.mp4.filmtone-ios-export-session-v1.json
/tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5.mp4
/tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5-combined-color.cube
/tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5-filmtone-bridge.dctl
/tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5-post-optical-color.cube
```

Device export performance:

```text
Output: 1080x1920, 24fps, H.264 MP4
elapsedMs: 4373
realtimeRatio: 0.7279840186449142
```

## Why Apple Log Validation Did Not Complete

The package/export path worked, but the app did not classify C059 as Apple Log.

Sidecar/probe result:

```json
{
  "codecFamily": "prores-422",
  "colorClass": "unknown",
  "hdrPreparationPolicy": {
    "reason": "source-color-unknown",
    "requiresFixtureValidation": false,
    "strategy": "none"
  },
  "inputTransformPolicy": {
    "reason": "source-color-unknown",
    "requiresFixtureValidation": false,
    "strategy": "none"
  }
}
```

Top-level probe summary:

```text
filename: filmtone-connect-validation-c059-6s.mov
width/height: 2160x3840
durationSec: 6.007
codec: apcs
codecFamily: prores-422
frameRate: 23.974693298339844
colorClass: unknown
inputTransform: none
```

Meaning:

- The physical iPhone can decode/export this ProRes clip.
- Filmtone Connect package generation works on device.
- Resolve import and DCTL application work.
- But this run is not an Apple Log validation, because iOS did not apply `apple-log-to-rec709` or `apple-log2-to-rec709`.

Plain-language conclusion:

```text
動作確認時に Apple Log 素材を選択して読み込んで検証する、という認識は正しい。
ただし成立条件は「アプリの sidecar/probe がその素材を Apple Log と判定したこと」。
今回の C059 は実機で読めたが、アプリ判定が unknown だったため Apple Log 検証としては未成立。
```

## Resolve Verification for C059

Resolve import command:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-c059-device-validation
```

Resolve import succeeded:

```text
source media: /tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5-source.mov
rendered media: /tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5.mp4
dctl: /tmp/filmtone-connect-c059-device-validation/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5-filmtone-bridge.dctl
node1LUT: Filmtone Connect/filmtone-export-4c8b1fbd-bed9-482f-bbc3-e9a31bbf0cb5-filmtone-bridge.dctl
Reference time: 1.5s
```

Resolve still export script used:

```text
/tmp/filmtone_export_resolve_c059_device_stills.lua
```

Exported stills:

```text
/tmp/filmtone-connect-c059-device-validation/compare/resolve-dctl.png
/tmp/filmtone-connect-c059-device-validation/compare/resolve-no-lut.png
```

ResolveDebug log check:

```text
Log byte offset before import/export: 286089
Search after offset: no "Error Processing DaVinci CTL"
ctl_error: false
```

Comparison outputs:

```text
/tmp/filmtone-connect-c059-device-validation/compare/metrics.json
/tmp/filmtone-connect-c059-device-validation/compare/visual-sheet.png
/tmp/filmtone-connect-c059-device-validation/compare/diff-ios-vs-dctl-x4.png
/tmp/filmtone-connect-c059-device-validation/compare/diff-ios-vs-no_lut-x4.png
/tmp/filmtone-connect-c059-device-validation/compare/ios_reference-normalized.png
/tmp/filmtone-connect-c059-device-validation/compare/ios-rendered-frame-accurate.png
/tmp/filmtone-connect-c059-device-validation/compare/ios-rendered-frame-best.png
/tmp/filmtone-connect-c059-device-validation/compare/resolve_dctl-normalized.png
/tmp/filmtone-connect-c059-device-validation/compare/resolve_no_lut-normalized.png
```

Metrics:

```json
{
  "ios_reference_vs_resolve_dctl": {
    "mae": 23.7063045501709,
    "rmse": 25.987811239267774
  },
  "ios_reference_vs_resolve_no_lut": {
    "mae": 26.934907913208008,
    "rmse": 29.9837704309817
  },
  "ios_rendered_frame_vs_resolve_dctl": {
    "mae": 13.2459077835083,
    "rmse": 15.530531315898422
  },
  "ios_rendered_frame_vs_resolve_no_lut": {
    "mae": 16.674335479736328,
    "rmse": 19.42714677924738
  },
  "resolve_dctl_vs_no_lut": {
    "mae": 3.599372386932373,
    "rmse": 4.624191213462319
  }
}
```

Interpretation:

- DCTL was active and directionally improved C059 versus no-LUT.
- Metrics are useful as a non-Apple-Log device pipeline smoke test.
- Do not use these numbers as Apple Log visual equivalence evidence.

## Device Automation Notes

The device automation path worked, but the next chat may not need it if the user manually selects the Apple Log source in the app.

Useful commands:

```sh
xcrun xcdevice list
xcrun devicectl list devices
xcodebuild -showdestinations \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App
```

Device build:

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

Install:

```sh
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-connect-device-derived/Build/Products/Debug-iphoneos/App.app \
  --timeout 120 \
  --json-output /tmp/filmtone-connect-device-install.json \
  --log-output /tmp/filmtone-connect-device-install.log
```

Important devicectl copy detail:

- Copying with `--destination Documents` created a file named `Documents`.
- For a source file, copy to an explicit filename such as `tmp/filename.mov`.

Working copy command:

```sh
xcrun devicectl device copy to \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  --source /tmp/filmtone-connect-validation-c059-6s.mov \
  --destination tmp/filmtone-connect-validation-c059-6s.mov \
  --domain-type appDataContainer \
  --domain-identifier com.chibatakumi.film.lab.ios \
  --timeout 180
```

Working launch command used for automation:

```sh
xcrun devicectl device process launch \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  --terminate-existing \
  --console \
  --timeout 900 \
  --environment-variables '{"FILMTONE_CONNECT_VALIDATION_SOURCE":"tmp/filmtone-connect-validation-c059-6s.mov","FILMTONE_CONNECT_VALIDATION_RESULT":"tmp/FilmtoneConnectValidationOutput"}' \
  com.chibatakumi.film.lab.ios \
  -- -filmtoneConnectValidationExport
```

The `--` before the app launch argument is required; otherwise `-filmtone...` is parsed by `devicectl`.

Retrieve output:

```sh
rm -rf /tmp/filmtone-connect-c059-device-validation
xcrun devicectl device copy from \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  --source tmp/FilmtoneConnectValidationOutput \
  --destination /tmp/filmtone-connect-c059-device-validation \
  --domain-type appDataContainer \
  --domain-identifier com.chibatakumi.film.lab.ios \
  --timeout 240
```

Do not leave an automation hook in `AppDelegate.swift`.

## What To Do Next

The next chat should follow this exact decision path:

1. Have the user connect the physical iPhone.
2. Use the Filmtone iOS app to select/import the intended Apple Log source.
3. Export a Filmtone Connect package.
4. Retrieve/share the package to the Mac.
5. Inspect the sidecar before Resolve.
6. Proceed to Resolve only if sidecar proves Apple Log classification.

Sidecar proof to look for:

```json
{
  "input": {
    "sourceProbe": {
      "sourceVideoMetadata": {
        "colorClass": "apple-log"
      },
      "inputTransformPolicy": {
        "strategy": "apple-log-to-rec709"
      }
    }
  }
}
```

or Apple Log 2:

```json
{
  "input": {
    "sourceProbe": {
      "sourceVideoMetadata": {
        "colorClass": "apple-log2"
      },
      "inputTransformPolicy": {
        "strategy": "apple-log2-to-rec709"
      }
    }
  }
}
```

If the sidecar says `unknown` / `none`, stop and do not call it Apple Log validation.

If Apple Log classification fails on a source the user knows is Apple Log:

1. Check whether the selected/exported file retains Apple Log metadata.
2. Prefer testing the original camera file rather than a trimmed file.
3. If original camera file still probes as unknown, fix `SourceProbeService` / `SourceColorMetadataNormalizer` / `SourceColorClassifier`.
4. Only add a Blackmagic/iPhone ProRes fallback if there is strong evidence. Avoid broad false-positive Apple Log classification.

## Files Most Likely Relevant If Probe Fix Is Needed

```text
apps/capacitor-film-lab-ios/ios/App/App/SourceProbeService.swift
apps/capacitor-film-lab-ios/ios/App/App/SourceColorMetadataNormalizer.swift
apps/capacitor-film-lab-ios/ios/App/App/SourceColorClassifier.swift
apps/capacitor-film-lab-ios/scripts/swift/test-source-color-classifier.swift
apps/capacitor-film-lab-ios/scripts/fixtures/phase0-contract/apple-log-prores-422-export-request.json
apps/capacitor-film-lab-ios/scripts/fixtures/phase0-contract/apple-log-2-prores-raw-export-request.json
```

Do not start by changing DCTL if the sidecar still says the source is not Apple Log. The blocker is source classification, not Resolve.

## Resolve Commands For A Valid Apple Log Package

Replace `PACKAGE_DIR` with the package path retrieved from the device.

```sh
PACKAGE_DIR="/path/to/retrieved/package"
LOG="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt"
wc -c "$LOG"

cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package "$PACKAGE_DIR"
```

Then export DCTL and no-LUT stills at `package.referenceAfterTimeSec`. You can adapt:

```text
/tmp/filmtone_export_resolve_c059_device_stills.lua
/tmp/filmtone_export_resolve_c0061_hlg_gain_stills.lua
/tmp/filmtone_export_resolve_split_still.lua
```

Always check Resolve log after the prior byte offset:

```sh
tail -c +<OFFSET_PLUS_ONE> "$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt" \
  | rg -n "Error Processing DaVinci CTL|DaVinci CTL|DCTL|filmtone" || true
```

`Error Processing DaVinci CTL` means the DCTL result is invalid even if Resolve UI shows the LUT/DCTL.

## Acceptance Criteria For Next Step

A successful Apple Log device verification requires all of this:

- Physical iPhone export succeeds.
- Package is recovered.
- Sidecar proves `colorClass` is `apple-log` or `apple-log2`.
- Sidecar proves `inputTransformPolicy.strategy` is Apple Log to Rec.709.
- Resolve imports original/source media, not the baked iOS MP4.
- Node 1 DCTL is applied.
- ResolveDebug has no `Error Processing DaVinci CTL` after import/export.
- DCTL output differs meaningfully from no-LUT.
- DCTL improves or clearly explains metric/visual tradeoff versus no-LUT.
- Do not claim full visual equivalence unless the normalized Resolve frame actually matches iOS within the chosen tolerance.

## Exact Next-Chat Prompt

Paste this into the next chat:

```text
Continue Filmtone Connect iOS/Resolve visual-equivalence work from:

/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package

Branch:
feature/filmtone-davinci-connect-package

Read this handoff first and do not do broad discovery:
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-device-apple-log-verification-next-chat-handoff-2026-04-30-jst.md

Core objective:
Verify a real Apple Log source on the connected physical iPhone. The previous C059 device run proved ProRes/device/package/Resolve pipeline works, but did NOT complete Apple Log validation because the app classified that source as colorClass=unknown and inputTransformPolicy=none.

Important:
- Do not treat package creation, Resolve import, or node 1 DCTL presence as success.
- First prove the iOS sidecar classifies the selected source as apple-log/apple-log2 and applies apple-log-to-rec709/apple-log2-to-rec709.
- If sidecar says unknown/none again, stop Resolve validation and investigate source metadata / SourceProbeService classification.
- Do not leave any temporary AppDelegate hook in production.
- Do not revert unrelated dirty files.
- Use sequential-thinking for real decisions.
- Prioritize core product progress; docs/handoff only if explicitly asked.

What I will do in this next chat:
1. Confirm connected iPhone with xcrun xcdevice/devicectl.
2. Have the user select/import the intended Apple Log source in the iOS app, or automate only if necessary.
3. Export/retrieve the Filmtone Connect package.
4. Inspect the sidecar:
   - required: input.sourceProbe.sourceVideoMetadata.colorClass == apple-log or apple-log2
   - required: input.sourceProbe.inputTransformPolicy.strategy == apple-log-to-rec709 or apple-log2-to-rec709
5. If Apple Log classification is proven, run Resolve import/export:
   - import package with apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
   - export DCTL and no-LUT stills at package.referenceAfterTimeSec
   - check ResolveDebug.txt for "Error Processing DaVinci CTL"
   - normalize frames and compute MAE/RMSE against iOS reference and no-LUT
6. If Apple Log classification is not proven, investigate SourceProbeService / SourceColorMetadataNormalizer / SourceColorClassifier and do not call it Apple Log validation.

Key previous artifacts:
- C059 device package: /tmp/filmtone-connect-c059-device-validation
- C059 metrics: /tmp/filmtone-connect-c059-device-validation/compare/metrics.json
- C059 visual sheet: /tmp/filmtone-connect-c059-device-validation/compare/visual-sheet.png
- A001 current baseline: /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-mip-diffusion-probe-sheet.png
- HLG validated/promoted package: /tmp/filmtone-connect-c0061-hlg-gain-probe

Expected output:
Report clearly whether Apple Log validation is established or blocked. If blocked, state the exact sidecar fields and the next implementation fix.
```
