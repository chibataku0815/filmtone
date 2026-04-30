# Filmtone Connect Visual Equivalence Device-Verified Handoff

Date: 2026-04-30 JST
Last local verification time: 2026-04-30 20:47:03 JST (+0900)

This document supersedes the previous immediate continuation handoff for the
next chat. It includes the latest DCTL production state, Resolve metrics, and
physical-device verification.

## 0. Immediate Start

Repository:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
```

Branch:

```text
feature/filmtone-davinci-connect-package
```

Read first:

```text
docs/filmtone/ios/filmtone-connect-visual-equivalence-device-verified-handoff-2026-04-30-jst.md
docs/filmtone/ios/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md
```

Open next:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
```

Do not start with broad repo discovery. Continue from the current production
DCTL baseline:

```text
split texture DCTL + Resolve texture compensation + RGB shift +
edge-masked softness + center-masked diffusion
```

## 0.1 Master Plan Relationship

The overall plan is still maintained in:

```text
docs/filmtone/ios/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md
```

Use that master plan as the long-term source of truth for:

- product goal and honest claim boundaries
- visual-equivalence acceptance criteria
- DCTL safety rules
- effect promotion roadmap
- final multi-source validation requirements

Use this device-verified handoff as the immediate continuation document for:

- latest production DCTL state
- latest A001 metrics
- latest Resolve output paths
- latest physical-device verification
- the exact next-chat prompt

The two documents should be read together. If they appear to conflict, prefer
this handoff for the latest observed state and prefer the master plan for the
long-term acceptance model.

## 1. Standing User Priorities

- Product quality is the priority.
- Core progress first.
- Keep outer-shell work minimal until the product behavior or QA target is the
  actual remaining need.
- Do not prioritize conservative general advice when it lowers product quality.
- Use sequential-thinking for real architecture, design, visual-quality, and
  product-quality tradeoffs.
- If local source and current docs do not answer a material question, search
  with Gemini if available or web search. Ask the user only when the answer
  changes implementation and cannot be discovered.
- Run independent reads/checks in parallel whenever practical.
- Take time for exact reasoning.

## 2. Product Goal And Honest Claim

Product goal:

```text
The same original Apple Log source should produce a visually equivalent
Filmtone result on iOS and in DaVinci Resolve through Filmtone Connect.
```

Current status:

```text
Not visually equivalent yet.
```

Current honest claim:

```text
Filmtone Connect v2 can import the same source into DaVinci Resolve, apply a
generated split-LUT DCTL bridge, include Resolve-verified RGB shift,
edge-masked softness, and center-masked diffusion steps, and improve A001
MAE/RMSE over the old combined-color DCTL. Missing optical/time effects remain
the main blocker.
```

Do not claim visual equivalence, full optical parity, grain parity, bloom
parity, halation parity, or production-ready Resolve parity.

Remaining blockers:

- bloom
- halation
- full diffusion/mip parity
- vignette
- grain
- time effects
- multi-source validation beyond A001

## 3. Latest Completed Work

Latest production promotion:

- Implemented scalar-safe center-masked diffusion in `FilmtoneConnectDctlWriter`.
- It runs after RGB shift and edge-masked softness.
- It runs before the post-optical LUT.
- It is gated by `request.grade.params.diffusion`.
- It uses an 8-tap scalar diffusion plate.
- It masks the effect out toward already-bright edges.
- Halation probes compiled but regressed A001 and were not promoted.

Production file:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
```

Contract test file:

```text
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
```

## 4. Current DCTL Pipeline

The split texture DCTL now effectively follows this order:

1. Read Resolve texture samples.
2. Apply Apple Log Resolve texture color compensation when the source policy is
   Apple Log / Apple Log 2 to Rec.709.
3. Apply pre-optical color LUT to the center sample.
4. Apply scalar-safe RGB shift with fixed 2px offset and pre-LUTed shifted
   samples.
5. Apply scalar-safe edge-masked softness.
6. Apply scalar-safe center-masked diffusion.
7. Apply post-optical color LUT.

Resolve texture color compensation for Apple Log paths:

```text
red:   0.97959765
green: 1.06894074
blue:  1.10818274
```

RGB shift production parameters:

```text
threshold:      0.0001
reference max:  0.005
mix at max:     0.72
pixel offset:   2
```

Edge softness production parameters:

```text
threshold:                  0.0001
aberration soften scale:     32.0
aberration soften max:       0.52
aberration soften curve:     1.55
blur radius min:             1.6
blur radius max:             6.2
blur radius cap:             7.8
lens softness blur boost:    1.85
```

Diffusion production parameters:

```text
threshold:        0.0001
amount scale:     0.60
composite base:   0.87
tap radius:       12
center weight:    0.24
axis weight:      0.10
diagonal weight:  0.09
mask start:       0.25
mask end:         0.70
```

Important DCTL safety constraints:

- Avoid custom `float3` helper functions.
- Avoid `float3` accumulation / vector arithmetic.
- Prefer scalar helper functions only.
- Prefer direct scalar math in `make_float3(...)`.
- Always check Resolve CTL logs because Resolve can show a DCTL on node 1 even
  when DCTL processing failed.

Resolve CTL error log:

```text
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt
```

Failure marker:

```text
Error Processing DaVinci CTL
```

## 5. Active A001 Fixture

Fixture package:

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

Current production Resolve output:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-softness-diffusion-normalized.png
```

Current result JSON:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-softness-diffusion-results.json
```

Current visual sheet:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-diffusion-production-visual-check-sheet.png
```

## 6. Latest Metrics

Latest production Resolve result:

```text
ctl_error: false
```

Whole-frame metrics:

| Comparison | MAE | RMSE |
|---|---:|---:|
| RGB shift baseline vs iOS | 18.960514 | 26.957575 |
| RGB shift + softness vs iOS | 18.828026 | 26.779573 |
| RGB shift + softness + center-masked diffusion vs iOS | 17.401152 | 25.555996 |
| center-masked diffusion output vs softness baseline | 2.408518 | 3.438097 |
| center-masked diffusion output vs no-LUT | 26.727003 | 33.361699 |

Region metrics:

| Region | Softness vs iOS MAE/RMSE | Diffusion vs iOS MAE/RMSE | Diffusion vs softness MAE/RMSE |
|---|---:|---:|---:|
| center r < 0.25 | 30.199949 / 40.682311 | 27.074738 / 38.228532 | 5.104599 / 5.382130 |
| mid r 0.25-0.70 | 16.201946 / 23.021724 | 14.468359 / 21.497343 | 2.958017 / 3.713275 |
| edge r > 0.70 | 19.993406 / 27.309744 | 19.993406 / 27.309744 | 0.0 / 0.0 |

Interpretation:

- Center-masked diffusion materially improves the A001 whole-frame metrics.
- Center and mid regions improved versus iOS.
- Edge region remains unchanged versus the softness baseline, which was the
  intended guardrail.
- This is still not full iOS diffusion parity or visual equivalence.

## 7. Verification Completed

All of the following passed after the diffusion promotion:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bun run verify:swift-contract
```

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bun run build
```

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bunx cap copy ios
```

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

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
git diff --check
```

Resolve import/export verification also passed:

- Resolve import/export succeeded.
- `ctl_error` was `false`.
- Production output was generated at the path listed above.

## 8. Physical Device Verification

Connected device:

```text
Name: 千葉工のiPhone (7)
CoreDevice identifier: 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9
Xcode destination id: 00008150-001674883C84401C
Model: iPhone 17 Pro (iPhone18,1)
State: connected
```

Physical device build:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -destination 'id=00008150-001674883C84401C' \
  -derivedDataPath /tmp/filmtone-ios-device-derived \
  build
```

Result:

```text
BUILD SUCCEEDED
```

Signing observed:

```text
Apple Development: takumi chiba (262F3A4568)
iOS Team Provisioning Profile: *
```

Physical install:

```sh
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-ios-device-derived/Build/Products/Debug-iphoneos/App.app
```

Installed app:

```text
Name: Filmtone
Bundle Identifier: com.chibatakumi.film.lab.ios
Version: 1.2
Bundle Version: 1
installationURL: file:///private/var/containers/Bundle/Application/C5DDDD84-E3A7-4EC5-9D06-03B9BA16C5E3/App.app/
```

Physical launch:

```sh
xcrun devicectl device process launch \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  --terminate-existing \
  --json-output /tmp/filmtone-device-launch-after-uitest.json \
  --log-output /tmp/filmtone-device-launch-after-uitest.log \
  com.chibatakumi.film.lab.ios
```

Result:

```text
outcome: success
processIdentifier: 64636
executable: file:///private/var/containers/Bundle/Application/C5DDDD84-E3A7-4EC5-9D06-03B9BA16C5E3/App.app/App
```

Device launch JSON:

```text
/tmp/filmtone-device-launch-after-uitest.json
```

Device launch log:

```text
/tmp/filmtone-device-launch-after-uitest.log
```

Notes:

- `devicectl` printed `Failed to load provisioning paramter list... No provider
  was found.` during several commands, but build/install/launch succeeded.
- Xcode build emitted Core Image Kernel Language API deprecation warnings in
  `FilmtoneExportSession.swift`; the build still succeeded.

Physical UI test attempt:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
xcodebuild test \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -destination 'id=00008150-001674883C84401C' \
  -derivedDataPath /tmp/filmtone-ios-device-derived \
  -only-testing:FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests/testExportSaveCtaVisibleWithoutScrolling
```

Result:

```text
TEST FAILED
Timed out while enabling automation mode.
```

Interpretation:

- This failed before the app UI test could initialize.
- It is an XCTest/device automation-mode initialization failure, not evidence of
  an app behavior regression.
- The app itself was successfully built, installed, and launched on the physical
  device after this failed UI test attempt.

XCTest result bundle:

```text
/tmp/filmtone-ios-device-derived/Logs/Test/Test-App-2026.04.30_20-44-38-+0900.xcresult
```

## 9. Working Tree State

Current branch:

```text
feature/filmtone-davinci-connect-package
```

Modified tracked files:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
```

Untracked docs present before this new handoff was added:

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
- Do not revert unrelated modified files.
- The latest code work specifically touched:
  - `FilmtoneExportSidecarBuilder.swift`
  - `test-sidecar-builder.swift`
  - the two visual-equivalence docs
- This new handoff is intentionally a new untracked document unless the next
  operator stages it.

## 10. Commands Worth Reusing

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

Simulator build:

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

Physical device build:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -destination 'id=00008150-001674883C84401C' \
  -derivedDataPath /tmp/filmtone-ios-device-derived \
  build
```

Physical install:

```sh
xcrun devicectl device install app \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-ios-device-derived/Build/Products/Debug-iphoneos/App.app
```

Physical launch:

```sh
xcrun devicectl device process launch \
  --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  --terminate-existing \
  --json-output /tmp/filmtone-device-launch-after-uitest.json \
  --log-output /tmp/filmtone-device-launch-after-uitest.log \
  com.chibatakumi.film.lab.ios
```

Whitespace:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
git diff --check
```

Resolve import:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-a001-v2-split-dctl-test
```

Resolve still export:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  /tmp/filmtone_export_resolve_split_still.lua
```

## 11. Recommended Next Product Work

The next operator should continue visual-equivalence work from the current
production baseline. Recommended priority:

1. Bloom or halation, but only through small scalar-safe probes.
2. Preserve the current diffusion edge guardrail.
3. Compare every probe against:
   - iOS ground truth
   - no-LUT
   - current production diffusion baseline
4. Promote only one effect at a time.
5. Keep DCTL syntax conservative.
6. After A001 improvement is meaningful, add at least one additional Apple Log
   source before making broader product claims.

Do not promote:

- naive full-frame diffusion
- naive vignette
- grain judged only by MAE/RMSE
- broad helper-heavy DCTL refactors
- all remaining effects in one change

## 12. Final Handoff Prompt For A New Chat

Copy this prompt into the next chat:

```text
We are in:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package

Branch:
feature/filmtone-davinci-connect-package

Read first:
docs/filmtone/ios/filmtone-connect-visual-equivalence-device-verified-handoff-2026-04-30-jst.md
docs/filmtone/ios/filmtone-connect-visual-equivalence-master-plan-2026-04-30-jst.md

Do not start with broad repo discovery. Open the handoff, the master plan, and
the active target files:
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift

Current production state:
Filmtone Connect DCTL includes Resolve texture compensation, scalar-safe RGB
shift, scalar-safe edge-masked softness, and scalar-safe center-masked
diffusion. The order is RGB shift + edge softness + center-masked diffusion
before the post-optical LUT.

Latest completed work:
Promoted center-masked diffusion in FilmtoneConnectDctlWriter. Halation probes
compiled but regressed A001 and were not promoted. Do not claim visual
equivalence.

Latest A001 output:
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-softness-diffusion-normalized.png

Latest result JSON:
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-softness-diffusion-results.json

Latest visual sheet:
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-diffusion-production-visual-check-sheet.png

Latest metrics:
- RGB shift baseline vs iOS: MAE 18.960514, RMSE 26.957575
- RGB shift + softness vs iOS: MAE 18.828026, RMSE 26.779573
- RGB shift + softness + center-masked diffusion vs iOS: MAE 17.401152, RMSE 25.555996
- diffusion output vs softness baseline: MAE 2.408518, RMSE 3.438097
- diffusion output vs no-LUT: MAE 26.727003, RMSE 33.361699
- Resolve CTL error: false

Region check:
- center r < 0.25 improved vs iOS: 30.199949/40.682311 -> 27.074738/38.228532
- mid r 0.25-0.70 improved vs iOS: 16.201946/23.021724 -> 14.468359/21.497343
- edge r > 0.70 unchanged vs softness baseline: 0.0/0.0 diffusion-vs-softness MAE/RMSE

Verification completed:
- Swift contract passed
- web build passed
- cap copy ios passed
- xcodebuild generic iOS Simulator passed
- git diff --check passed
- Resolve import/export passed
- Resolve CTL error false
- physical iPhone build passed
- physical iPhone install passed
- physical iPhone launch passed

Physical device details:
- Device: 千葉工のiPhone (7)
- CoreDevice id: 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9
- Xcode destination id: 00008150-001674883C84401C
- Model: iPhone 17 Pro (iPhone18,1)
- Bundle: com.chibatakumi.film.lab.ios
- Version/build: 1.2 / 1
- Latest launch JSON: /tmp/filmtone-device-launch-after-uitest.json
- Latest launch outcome: success
- Latest launched process id: 64636

Physical UI test note:
An xcodebuild UI test attempt failed before app UI testing initialized with
`Timed out while enabling automation mode`. Treat this as a device/XCTest
automation-mode issue, not as evidence of an app behavior regression. The app
was successfully built, installed, and launched on the physical device after
that attempt.

Remaining blockers:
bloom, halation, full diffusion/mip parity, vignette, grain, time effects, and
multi-source validation. Do not claim visual equivalence.

Next likely phase:
Continue visual equivalence work. Prioritize core product progress and product
quality. Keep outer-shell work minimal. Use sequential-thinking for real
design/product-quality tradeoffs. Search local source first, then Gemini/web if
local context is insufficient. Ask only when the answer changes implementation
and cannot be discovered. Parallelize independent operations.

Important constraints:
- Resolve can silently show a DCTL while CTL processing failed; always inspect
  ResolveDebug.txt for `Error Processing DaVinci CTL`.
- Avoid custom float3 helper functions and float3 accumulation/vector arithmetic
  in DCTL.
- Promote only one effect at a time.
- Compare against iOS, no-LUT, and the current production diffusion baseline.
- Do not revert unrelated modified files in the working tree.
```
