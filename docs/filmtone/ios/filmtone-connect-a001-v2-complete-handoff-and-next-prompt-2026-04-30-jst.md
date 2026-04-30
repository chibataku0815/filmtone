# Filmtone Connect A001 v2 Complete Handoff and Next Prompt

Date: 2026-04-30 JST

This document is the full transfer context for the next chat. It should be
read first. It supersedes the scattered details from the previous conversation.

## 1. Product Goal

The product goal is not merely to export a package or apply a LUT in DaVinci
Resolve.

The goal is:

> The same original Apple Log source should produce a visually equivalent
> Filmtone result on iOS and in DaVinci Resolve through Filmtone Connect.

Current status: not achieved yet.

However, the current branch now has a stronger v2 package structure and a
verified Resolve DCTL path. The next implementation should focus on porting
the missing visual effects one by one, beginning with RGB shift.

## 2. Working Repo

Repository:

`/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package`

Current branch:

`feature/filmtone-davinci-connect-package`

Current app/package area:

`apps/capacitor-film-lab-ios`

Important instruction from the user:

- Prioritize core product progress.
- Keep outer-shell/process/hygiene work minimal unless quality assurance is the
  remaining need.
- Do not prioritize conservative advice over product quality.
- Use `sequential-thinking` for real design branches, architecture choices, and
  product-quality tradeoffs.
- If materially unknown, search or ask.
- Parallelize independent operations.

## 3. Core Fixture

The active A001 fixture is:

- Original source:
  `/Users/chibatakumi/Downloads/A001_11221912_C011.MOV`
- iOS ground truth export:
  `/Users/chibatakumi/Downloads/filmtone-export-b5d95ff3-a27a-4274-abb1-670e9082bf80.MP4`
- Real package baseline:
  `/tmp/filmtone-connect-a001-v2-device-final`
- Temporary split-DCTL test package:
  `/tmp/filmtone-connect-a001-v2-split-dctl-test`
- Reference time:
  `2.2604195011337866s`

Important normalized comparison frames:

- iOS device rendered:
  `/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/ios-device-rendered.png`
- iOS attached ground truth:
  `/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/ios-attached-ground-truth.png`
- Resolve no-LUT:
  `/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-no-lut-normalized.png`
- Resolve old combined DCTL/cube:
  `/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-reference-after-normalized.png`
- Resolve latest split compensated DCTL:
  `/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-normalized.png`

## 4. Baseline Metrics Before This Work

These were the known metrics from the prior handoff:

| Comparison | MAE | RMSE | SSIM(luma) |
|---|---:|---:|---:|
| iOS device export vs attached ground truth | 1.422186 | 2.106416 | 0.999225 |
| Resolve no-LUT vs iOS device export | 26.769266 | 34.854301 | 0.702690 |
| Resolve old DCTL/cube vs iOS device export | 21.415565 | 28.859980 | 0.840251 |

The old DCTL/cube was directionally useful, but far from visual equivalence.

## 5. What Was Changed in Production Code

### 5.1 Package v2 Sidecar Contract

File:

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`

The package layout was moved from:

`filmtone-connect-package-v1`

to:

`filmtone-connect-package-v2`

v2 package fields now include:

- original source media filename
- rendered iOS media filename
- reference-after filename
- reference-after time in seconds
- combined color LUT
- pre-optical color LUT
- post-optical color LUT
- DCTL bridge filename

Important compatibility detail:

`mediaFilename` is kept as a deprecated v1 alias, but now intentionally points
to the original source media so older importers are less likely to import the
baked iOS render as the source.

### 5.2 Package File Ordering

File:

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`

Added `FilmtoneConnectPackageFiles.orderedPackageFileUris(...)`.

Expected order:

1. rendered iOS export
2. sidecar JSON
3. source media copy
4. pre-optical cube
5. post-optical cube
6. combined-color cube
7. DCTL bridge
8. reference-after still

### 5.3 Companion File Generation

File:

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`

Connect package companions now include:

- `*-source.mov` or original extension
- `*-combined-color.cube`
- `*-pre-optical-color.cube`
- `*-post-optical-color.cube`
- `*-filmtone-bridge.dctl`
- `*-reference-after.jpg`

The generated reference still now returns and records its actual poster time.

### 5.4 Split LUT Generation

File:

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`

Added:

- `writePreOpticalColorCube`
- `writePostOpticalColorCube`
- `makePreOpticalColorCubeText`
- `makePostOpticalColorCubeText`

Color split:

- pre-optical LUT: input LUT or automatic Apple Log transform, base grade, film
  compression
- post-optical LUT: creative/legacy LUT and print stage
- combined LUT remains as scalar compatibility bridge

### 5.5 DCTL Generation

File:

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`

Added `FilmtoneConnectDctlWriter`.

Current production DCTL strategy:

- If pre/post LUT filenames are present, generate a texture-signature DCTL.
- Apply pre-optical LUT.
- Apply post-optical LUT.
- For Apple Log sources only, apply small Resolve texture color compensation:
  - red: `0.97959765`
  - green: `1.06894074`
  - blue: `1.10818274`
- Avoid custom `float3` helper functions.
- Avoid vector accumulation.
- Return direct scalar-clamped `make_float3(...)`.

Why compensation exists:

Resolve's DCTL texture path did not match the iOS/Core Image sample path for
the A001 Apple Log fixture. A small channel compensation reduced the A001
MAE/RMSE. It is intentionally gated to Apple Log input transform policy.

Important: this is not final visual equivalence. It is a measured improvement
over the old DCTL/cube baseline.

### 5.6 Resolve Importer

File:

`apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua`

Importer now:

- recognizes package v2
- requires source media for package v2
- requires DCTL for package v2
- stages declared LUT companions
- stages all `.cube` files in the package before applying DCTL
- applies DCTL instead of cube-only when present
- creates a unique timeline name using `os.time()` to avoid duplicate timeline
  creation failure
- sets project/timeline frame rate and resolution from the sidecar where
  possible
- marker note now explicitly states that source equivalence must be verified

### 5.7 Swift Contract Tests

File:

`apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift`

Tests now cover:

- package v2 fields
- pre/post LUT sidecar fields
- package URI order
- DCTL references to pre/post LUTs
- DCTL texture signature
- absence of unverified grain/vignette approximation
- avoidance of custom `float3` helpers

## 6. Files Modified in Working Tree

Current modified files:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua`
- `apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift`

Current untracked docs in the same repo:

- `docs/filmtone/ios/filmtone-connect-a001-minimal-effect-probe-handoff-2026-04-30-jst.md`
- `docs/filmtone/ios/filmtone-connect-a001-v2-next-chat-handoff-2026-04-30-jst.md`
- `docs/filmtone/ios/filmtone-connect-log-source-visual-equivalence-handoff-2026-04-30-jst.md`
- this document

The first two pre-existing untracked handoff docs were already present from
the earlier flow. Do not assume they were all newly authored in the last step.

## 7. Important Failure Found

A full optical DCTL was attempted with:

- RGB split
- edge softness
- highlight/glow taps
- diffusion taps
- vignette
- split pre/post LUTs

Resolve appeared to apply the DCTL in the UI, but the exported frame was
exactly no-LUT. Resolve logged:

`Error Processing DaVinci CTL`

Log location:

`~/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt`

The failure is dangerous because it can look successful in the UI while the
render silently falls back.

Likely cause:

- custom `float3` helper functions
- `float3` accumulation / vector arithmetic
- large helper-heavy DCTL structure

Empirical fix:

Use minimal scalar-safe DCTL style:

- no custom `float3` helper functions
- no vector accumulation
- direct scalar math in `make_float3(...)`

## 8. Current Verified Metrics After Production DCTL Change

Measured using the temporary split package and Resolve export at the reference
frame:

| Comparison | MAE | RMSE |
|---|---:|---:|
| Resolve no-LUT vs iOS device | 26.769266 | 34.854301 |
| Resolve old combined DCTL/cube vs iOS device | 21.415565 | 28.859980 |
| Resolve split compensated DCTL vs iOS device | 19.042530 | 27.116449 |
| Resolve split compensated DCTL vs attached ground truth | 19.041178 | 27.117682 |
| Resolve split compensated DCTL vs no-LUT | 25.848776 | 32.005596 |
| Resolve split compensated DCTL vs old combined DCTL | 8.709058 | 9.885320 |

Interpretation:

- The new DCTL is not no-LUT.
- It improves MAE/RMSE over the old combined DCTL baseline.
- It is not visual equivalence.
- Optical/time effects are still missing from production DCTL.

## 9. Minimal Effect Probe

Because the effects are the core product quality issue, each missing effect was
tested as a smallest possible Resolve DCTL unit.

Probe handoff:

`docs/filmtone/ios/filmtone-connect-a001-minimal-effect-probe-handoff-2026-04-30-jst.md`

Probe runner:

`/tmp/filmtone_dctl_effect_probe.py`

Raw results:

`/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/probe-minimal-effects-results.json`

Rendered frames:

`/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/probe-*.png`

All probes compiled/rendered with `ctl_error=false`.

| Probe | CTL error | vs iOS MAE | vs iOS RMSE | vs no-LUT MAE | vs no-LUT RMSE | Interpretation |
|---|---|---:|---:|---:|---:|---|
| baseline | false | 19.042530 | 27.116449 | 25.848776 | 32.005596 | current baseline |
| RGB shift | false | 18.960514 | 26.957575 | 25.944052 | 32.113711 | best single-effect improvement |
| softness | false | 19.032560 | 27.097082 | 25.839653 | 31.997585 | tiny improvement |
| diffusion | false | 32.180904 | 43.659882 | 33.471470 | 41.522681 | bad approximation |
| bloom | false | 19.455194 | 27.580306 | 27.757359 | 34.115657 | worse |
| halation | false | 19.025793 | 27.098546 | 25.965443 | 32.150255 | tiny improvement |
| vignette | false | 26.716019 | 32.419998 | 19.309742 | 23.011825 | much worse |
| grain | false | 21.039751 | 28.920228 | 24.921204 | 29.629192 | worse by pixel metric |

Important nuance:

Bad MAE/RMSE for grain does not mean grain is unimportant. Pixel metrics punish
uncorrelated noise. Grain needs visual/temporal evaluation in addition to
MAE/RMSE.

## 10. Recommended Next Implementation Order

Do not try to port all optical effects at once again. That already caused
silent DCTL failure.

Recommended order:

1. Promote RGB shift into production DCTL using the scalar-safe pattern from
   `/tmp/filmtone_dctl_effect_probe.py`.
2. Re-run Resolve import/export and compare:
   - against iOS device frame
   - against no-LUT frame
   - against current split compensated baseline
3. Add edge-masked softness, not global softness.
   - The probe used global 4-tap softness and only barely improved metrics.
   - Production should use radial/edge weighting.
4. Rework halation as a bright-plate plus multi-radius tap approximation.
   - The minimal probe proves syntax feasibility only.
   - It is not a real mip-pyramid halation model.
5. Rework bloom similarly, with lower strength and proper bright plate.
   - The minimal bloom probe worsened metrics.
6. Delay diffusion, vignette, and grain until visual comparison is part of the
   gate.
   - Current minimal versions regressed A001 by MAE/RMSE.

## 11. Verification Commands Already Run

Swift contract:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bun run verify:swift-contract
```

Result: passed.

Web build:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bun run build
```

Result: passed. Vite emitted only the existing large chunk warning.

Capacitor copy:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bunx cap copy ios
```

Result: passed.

iOS Debug build:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -destination 'platform=iOS,id=00008150-001674883C84401C' \
  -derivedDataPath /tmp/filmtone-ios-device-derived \
  build
```

Result: passed.

Install to device:

```sh
xcrun devicectl device install app \
  --device 00008150-001674883C84401C \
  /tmp/filmtone-ios-device-derived/Build/Products/Debug-iphoneos/App.app
```

Result: passed. Bundle ID:

`com.chibatakumi.film.lab.ios`

Diff whitespace:

```sh
git diff --check
```

Result: passed.

## 12. Resolve Commands Used

Import package into Resolve:

```sh
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-a001-v2-split-dctl-test
```

Export current reference still:

```sh
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  /tmp/filmtone_export_resolve_split_still.lua
```

Normalize exported still:

```sh
ffmpeg -y -v error \
  -i /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-normalized-source.png \
  -vf "scale=1080:1920:flags=lanczos,setsar=1,format=rgb24" \
  /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-normalized.png
```

Minimal effect probe:

```sh
python3 /tmp/filmtone_dctl_effect_probe.py
```

## 13. Temporary Files and Scripts

Useful temp generator:

`/tmp/filmtone-generate-connect-companions.swift`

Compiled binary:

`/tmp/filmtone-generate-connect-companions`

Request JSON:

`/tmp/filmtone-a001-request-from-sidecar.json`

No-input-transform experiment JSON:

`/tmp/filmtone-a001-request-no-input-transform.json`

Resolve still export script:

`/tmp/filmtone_export_resolve_split_still.lua`

Minimal effect probe runner:

`/tmp/filmtone_dctl_effect_probe.py`

## 14. Failed or Rejected Experiments

### Full optical DCTL

Rejected because Resolve logged CTL error and output matched no-LUT exactly.

### Vignette-only DCTL

It compiled and rendered, but worsened A001:

- baseline MAE: `19.042530`
- vignette MAE: `26.716019`

Reason: the current Resolve output is already darker/wrong in a way that naive
vignette makes worse.

### No automatic Apple Log input transform

This was tested by removing input transform policy in the temporary request.
It made Resolve output near no-LUT and worsened vs iOS:

- no-input-transform vs iOS: `MAE 27.309105`, `RMSE 35.430579`
- no-input-transform vs no-LUT: `MAE 1.098566`, `RMSE 1.364996`

Conclusion: Apple Log input transform is still needed.

### Simple post-scale compensation

This was promoted into the current production DCTL for Apple Log sources because
it improved A001 MAE/RMSE and remained Resolve-valid when written in scalar-safe
style.

## 15. Current Best Technical Understanding

The current gap is a combination of:

- color/tone mismatch in Resolve texture path
- missing RGB shift
- missing edge/ray-angle softness
- missing real bloom/halation mip-pyramid behavior
- missing diffusion model
- missing vignette model
- missing grain
- missing motion/time effects
- possible mismatch between Core Image and Resolve sampling/color management

The first practical next win is RGB shift, because:

- it compiled
- it changed output
- it improved A001 metrics
- it is structurally simple enough to keep Resolve-valid

## 16. Do Not Claim

Do not claim:

- visual equivalence
- full Filmtone optical parity
- DaVinci result matches iOS
- grain parity
- bloom/halation parity

Current honest claim:

> Filmtone Connect v2 can import the same source into DaVinci Resolve, apply a
> generated split-LUT DCTL bridge, and improve A001 MAE/RMSE over the old
> combined-color DCTL. Missing optical/time effects remain the main blocker.

## 17. Highest-Precision Prompt for the Next Chat

Use this prompt in the next chat:

```text
We are in:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package

Branch:
feature/filmtone-davinci-connect-package

Read first:
docs/filmtone/ios/filmtone-connect-a001-v2-complete-handoff-and-next-prompt-2026-04-30-jst.md
docs/filmtone/ios/filmtone-connect-a001-minimal-effect-probe-handoff-2026-04-30-jst.md

Product goal:
The same original Apple Log source must produce a visually equivalent Filmtone result on iOS and in DaVinci Resolve through Filmtone Connect. Do not treat package existence or LUT application as success. The missing effects are the most important part: softness, diffusion, bloom, halation, RGB shift, vignette, grain.

User preference:
Prioritize core product progress and product quality. Keep outer-shell work minimal. Use sequential-thinking for real design/architecture/product-quality tradeoffs. If materially unknown, search or ask. Parallelize independent operations.

Current verified state:
- Resolve no-LUT vs iOS: MAE 26.769266, RMSE 34.854301
- old combined DCTL/cube vs iOS: MAE 21.415565, RMSE 28.859980
- current split compensated DCTL vs iOS: MAE 19.042530, RMSE 27.116449
- best minimal single effect probe is RGB shift: MAE 18.960514, RMSE 26.957575

Important Resolve DCTL constraint:
Do not use custom float3 helper functions, float3 accumulation, or large helper-heavy DCTL blocks. Resolve can silently fail while UI still shows the DCTL on node 1. Always check ResolveDebug.txt for "Error Processing DaVinci CTL" and compare against no-LUT to ensure the DCTL actually rendered.

Core task:
Promote the minimal RGB shift probe into production FilmtoneConnectDctlWriter using the scalar-safe DCTL pattern. Do not add all effects at once. After RGB shift, regenerate the A001 temporary package DCTL, import into Resolve, export the reference frame at 2.2604195011337866s, normalize it to 1080x1920 RGB, and compute MAE/RMSE against:
1. /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/ios-device-rendered.png
2. /tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-no-lut-normalized.png
3. the current split compensated baseline

Required fixture:
/tmp/filmtone-connect-a001-v2-split-dctl-test

Useful scripts:
/tmp/filmtone-generate-connect-companions
/tmp/filmtone-a001-request-from-sidecar.json
/tmp/filmtone_export_resolve_split_still.lua
/tmp/filmtone_dctl_effect_probe.py

Resolve command:
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-a001-v2-split-dctl-test

Export still command:
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  /tmp/filmtone_export_resolve_split_still.lua

Verification after code changes:
cd apps/capacitor-film-lab-ios && bun run verify:swift-contract
cd apps/capacitor-film-lab-ios && bun run build
cd apps/capacitor-film-lab-ios && bunx cap copy ios
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -configuration Debug -destination 'platform=iOS,id=00008150-001674883C84401C' -derivedDataPath /tmp/filmtone-ios-device-derived build
git diff --check

Next recommended sequence after RGB shift:
1. edge-masked softness, not global softness
2. halation bright-plate + multi-radius taps
3. bloom bright-plate + multi-radius taps with lower strength
4. diffusion/vignette/grain only after visual QA is part of the gate, because the naive probes regressed A001 metrics

Do not claim visual equivalence unless metrics and visual inspection support it.
```

