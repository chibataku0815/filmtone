# Filmtone Connect Visual Equivalence Next Chat Handoff

Date: 2026-04-30 JST

This is the operational handoff for the next chat.

## 0. Latest Continuation Update

Continuation completed later on 2026-04-30 JST:

- Promoted scalar-safe center-masked diffusion in `FilmtoneConnectDctlWriter`.
- The block runs after RGB shift + edge-masked softness and before the
  post-optical LUT.
- It is gated by `request.grade.params.diffusion`, uses a small 8-tap scalar
  diffusion plate, and masks the effect out toward already-bright edges.
- Halation probes compiled but regressed A001 and were not promoted.
- Do not claim visual equivalence. Bloom, halation, full diffusion/mip parity,
  vignette, grain, and time effects remain blockers.

Latest production Resolve output:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-softness-diffusion-normalized.png
```

Latest metrics:

| Comparison | MAE | RMSE |
|---|---:|---:|
| RGB shift + softness vs iOS | 18.828026 | 26.779573 |
| RGB shift + softness + center-masked diffusion vs iOS | 17.401152 | 25.555996 |
| diffusion output vs softness baseline | 2.408518 | 3.438097 |

Region check:

| Region | Softness vs iOS MAE/RMSE | Diffusion vs iOS MAE/RMSE | Diffusion vs softness |
|---|---:|---:|---:|
| center r < 0.25 | 30.199949 / 40.682311 | 27.074738 / 38.228532 | 5.104599 / 5.382130 |
| mid r 0.25-0.70 | 16.201946 / 23.021724 | 14.468359 / 21.497343 | 2.958017 / 3.713275 |
| edge r > 0.70 | 19.993406 / 27.309744 | 19.993406 / 27.309744 | 0.0 / 0.0 |

Visual sheet:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-diffusion-production-visual-check-sheet.png
```

For the long-term roadmap and acceptance criteria, read:

```text
docs/filmtone/ios/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md
```

## 1. Start Here

Repository:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
```

Branch:

```text
feature/filmtone-davinci-connect-package
```

Current app/package area:

```text
apps/capacitor-film-lab-ios
```

Core task for the next chat:

```text
Continue from the production RGB shift + edge-masked softness + center-masked
diffusion DCTL baseline. Next likely blockers are bloom, halation, full
diffusion/mip parity, vignette, grain, and time effects.
```

Do not start with broad repo discovery. Open this handoff, the master plan, and
the active target files.

## 2. Product Goal

The goal is:

```text
The same original Apple Log source should produce a visually equivalent
Filmtone result on iOS and in DaVinci Resolve through Filmtone Connect.
```

Current status: not achieved yet.

Do not claim visual equivalence. Current honest claim is only that v2 can import
the same source, apply a split-LUT DCTL bridge with RGB shift, and improve A001
metrics over older baselines.

## 3. Current Fixture

Active package:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test
```

Original source:

```text
/Users/chibatakumi/Downloads/A001_11221912_C011.MOV
```

iOS ground truth export:

```text
/Users/chibatakumi/Downloads/filmtone-export-b5d95ff3-a27a-4274-abb1-670e9082bf80.MP4
```

Reference time:

```text
2.2604195011337866s
```

Primary comparison frames:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/ios-device-rendered.png
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-no-lut-normalized.png
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-recheck-normalized.png
```

Expected next output:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-softness-normalized.png
```

## 4. Current Production State

`FilmtoneConnectDctlWriter` currently generates a split texture DCTL with:

- pre-optical LUT
- scalar-safe RGB shift
- post-optical LUT
- Apple Log Resolve texture color compensation

RGB shift details:

- request-scaled from `request.grade.params.rgbShift`
- reference max: `0.005`
- max mix: `0.72`
- fixed offset: `2px`
- center/red/blue samples are pre-LUTed before channel mix
- post-optical LUT is applied after the RGB shift mix

The fixed 2px probe was chosen because the more iOS-like radial variants
compiled but worsened A001 metrics.

## 5. Latest Metrics

Current verified state:

| Comparison | MAE | RMSE |
|---|---:|---:|
| Resolve no-LUT vs iOS | 26.769266 | 34.854301 |
| old combined DCTL/cube vs iOS | 21.415565 | 28.859980 |
| split compensated DCTL before RGB shift vs iOS | 19.042530 | 27.116449 |
| production split DCTL + RGB shift vs iOS | 18.828026 | 26.779573 |
| production split DCTL + RGB shift vs no-LUT | 25.869200 | 32.033693 |
| production split DCTL + RGB shift vs previous split baseline | 1.588022 | 4.177829 |
| production recheck vs original RGB shift baseline | 0.385920 | 1.047139 |

Latest RGB shift result:

```text
ctl_error: false
output: /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-recheck-normalized.png
side_by_side: /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-recheck-side-by-side.png
diff_x4: /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-recheck-diff-x4.png
```

Result JSON:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-recheck-results.json
```

## 6. Files To Open

Open these first:

```text
docs/filmtone/ios/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
```

Useful references only if needed:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
/tmp/filmtone_dctl_effect_probe.py
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/probe-minimal-effects-results.json
```

## 7. Working Tree State

Current modified files:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
```

Current untracked docs:

```text
docs/filmtone/ios/filmtone-connect-a001-minimal-effect-probe-handoff-2026-04-30-jst.md
docs/filmtone/ios/filmtone-connect-a001-v2-complete-handoff-and-next-prompt-2026-04-30-jst.md
docs/filmtone/ios/filmtone-connect-a001-v2-next-chat-handoff-2026-04-30-jst.md
docs/filmtone/ios/filmtone-connect-log-source-visual-equivalence-handoff-2026-04-30-jst.md
docs/filmtone/ios/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md
docs/filmtone/ios/filmtone-connect-visual-equivalence-next-chat-handoff-2026-04-30-jst.md
```

Important:

- Not all modified files were changed in the latest continuation.
- Prior work already included v2 package layout, split LUTs, source media
  sharing, DCTL staging, Resolve importer work, and tests.
- The latest continuation specifically promoted RGB shift into production DCTL
  and added/updated DCTL writer assertions.
- Do not revert unrelated modified files.

## 8. DCTL Constraints

Resolve can silently fail while UI still shows a DCTL on node 1.

Always check:

```text
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt
```

Look for:

```text
Error Processing DaVinci CTL
```

Avoid:

- custom `float3` helper functions
- `float3` accumulation / vector arithmetic
- large helper-heavy DCTL blocks

Keep the next DCTL change scalar-safe and small.

## 9. Next Implementation: Edge-Masked Softness

Do not promote the old global 4-tap softness probe as-is.

Next implementation shape:

1. Keep the current RGB shift baseline intact.
2. Add scalar-safe edge-masked softness after pre-optical color and RGB shift,
   before post-optical LUT.
3. Use edge weighting so the image center remains mostly unchanged.
4. Use a small number of taps.
5. Avoid custom `float3` helpers and vector accumulation.
6. Compare against iOS, no-LUT, and current RGB shift baseline.

Promotion gate:

- `ctl_error=false`
- output is not no-LUT
- no material metric regression vs RGB shift baseline unless visual inspection
  clearly justifies the tradeoff
- no unverified diffusion/vignette/grain approximation is added

## 10. Verification Commands

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

Whitespace:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
git diff --check
```

## 11. Resolve Verification Commands

Regenerate A001 companions with current production Swift:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
xcrun swiftc \
  -o /tmp/filmtone-generate-connect-companions \
  apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneColorPipeline.swift \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLutBlobCodec.swift \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift \
  /tmp/filmtone-generate-connect-companions.swift

/tmp/filmtone-generate-connect-companions \
  /tmp/filmtone-a001-request-from-sidecar.json \
  /tmp/filmtone-connect-a001-v2-split-dctl-test \
  filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c
```

Import package into Resolve:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-a001-v2-split-dctl-test
```

Export reference still:

```sh
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  /tmp/filmtone_export_resolve_split_still.lua
```

Normalize:

```sh
ffmpeg -y -v error \
  -i /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-normalized-source.png \
  -vf "scale=1080:1920:flags=lanczos,setsar=1,format=rgb24" \
  /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-softness-normalized.png
```

Compare against:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/ios-device-rendered.png
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-no-lut-normalized.png
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-recheck-normalized.png
```

## 12. Latest Verification Status

Latest continuation verification:

```text
bun run verify:swift-contract: passed
bun run build: passed
bunx cap copy ios: passed
xcodebuild generic/platform=iOS Simulator: passed
git diff --check: passed
xcodebuild physical iPhone Debug build: passed
xcrun devicectl install to iPhone 17 Pro: passed
Resolve import/export for RGB shift DCTL: passed
Resolve CTL error for RGB shift DCTL: false
```

Physical device build/install is now completed on:

```text
3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9
iPhone 17 Pro (iPhone18,1)
```

Physical iPhone export from the app is still not completed.

## 13. Highest-Precision Next Chat Prompt

Use this prompt in the next chat:

```text
We are in:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package

Branch:
feature/filmtone-davinci-connect-package

Read first:
docs/filmtone/ios/filmtone-connect-visual-equivalence-next-chat-handoff-2026-04-30-jst.md
docs/filmtone/ios/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md

Product goal:
The same original Apple Log source must produce a visually equivalent Filmtone result on iOS and in DaVinci Resolve through Filmtone Connect. Do not treat package existence, Lua import success, or LUT/DCTL application as success. The missing effects are the core product blocker.

User preference:
Prioritize core product progress and product quality. Keep outer-shell/process/hygiene work minimal. Do not prioritize conservative advice over product quality. Use sequential-thinking for real design/architecture/product-quality tradeoffs. If materially unknown, search local source first, then Gemini or web search if needed. Parallelize independent operations.

Current verified state:
- no-LUT Resolve vs iOS: MAE 26.769266, RMSE 34.854301
- old combined DCTL/cube vs iOS: MAE 21.415565, RMSE 28.859980
- split compensated DCTL before RGB shift vs iOS: MAE 19.042530, RMSE 27.116449
- production split DCTL + RGB shift vs iOS: MAE 18.828026, RMSE 26.779573
- production split DCTL + RGB shift vs no-LUT: MAE 25.869200, RMSE 32.033693
- production split DCTL + RGB shift vs previous split baseline: MAE 1.588022, RMSE 4.177829
- production recheck vs original RGB shift baseline: MAE 0.385920, RMSE 1.047139
- production RGB shift CTL error: false

Current production DCTL state:
FilmtoneConnectDctlWriter generates a split texture DCTL with:
- pre-optical LUT
- scalar-safe RGB shift
- post-optical LUT
- Apple Log Resolve texture color compensation

Important Resolve DCTL constraint:
Do not use custom float3 helper functions, float3 accumulation, or large helper-heavy DCTL blocks. Resolve can silently fail while UI still shows the DCTL on node 1. Always check ResolveDebug.txt for "Error Processing DaVinci CTL" and compare against no-LUT to ensure the DCTL actually rendered.

Core task:
Continue from the RGB shift baseline and implement edge-masked softness in production FilmtoneConnectDctlWriter. Do not add all effects at once. Do not promote the prior global softness probe as-is. Keep the DCTL scalar-safe and small.

Required fixture:
/tmp/filmtone-connect-a001-v2-split-dctl-test

Reference frame time:
2.2604195011337866s

Current baseline output:
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-recheck-normalized.png

Compare new output against:
1. /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/ios-device-rendered.png
2. /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-no-lut-normalized.png
3. /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-recheck-normalized.png

Useful scripts:
/tmp/filmtone-generate-connect-companions.swift
/tmp/filmtone-generate-connect-companions
/tmp/filmtone-a001-request-from-sidecar.json
/tmp/filmtone_export_resolve_split_still.lua
/tmp/filmtone_dctl_effect_probe.py

Verification after code changes:
cd apps/capacitor-film-lab-ios && bun run verify:swift-contract
cd apps/capacitor-film-lab-ios && bun run build
cd apps/capacitor-film-lab-ios && bunx cap copy ios
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package && xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/filmtone-ios-simulator-derived build
git diff --check

Resolve verification:
Regenerate A001 DCTL with current Swift, import package into Resolve with fuscript, export the reference still, normalize to 1080x1920 RGB, check ResolveDebug.txt for CTL errors, and compute MAE/RMSE against iOS, no-LUT, and the current RGB shift baseline.

Do not claim visual equivalence unless metrics and visual inspection support it.
```
