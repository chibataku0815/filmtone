# Filmtone Connect Visual Equivalence Master Plan

Date: 2026-04-30 JST

This is the master plan for Filmtone Connect v2 visual equivalence work.

For immediate continuation in a new chat, use:

```text
docs/filmtone/ios/filmtone-connect-visual-equivalence-next-chat-handoff-2026-04-30-jst.md
```

## 1. Product Goal

The product goal is not package export, Lua import success, or a LUT/DCTL being
visible on node 1 in DaVinci Resolve.

The goal is:

```text
The same original Apple Log source should produce a visually equivalent
Filmtone result on iOS and in DaVinci Resolve through Filmtone Connect.
```

Current status: not achieved yet.

Current honest claim:

```text
Filmtone Connect v2 can import the same source into DaVinci Resolve, apply a
generated split-LUT DCTL bridge, include Resolve-verified RGB shift,
edge-masked softness, and center-masked diffusion steps, and improve A001
MAE/RMSE over the old combined-color DCTL. Missing optical/time effects remain
the main blocker.
```

Do not claim visual equivalence, full optical parity, grain parity, bloom /
halation parity, or production-ready Resolve parity until metrics and visual
inspection support those claims.

Latest continuation status later on 2026-04-30 JST:

- Production DCTL now includes scalar-safe center-masked diffusion after RGB
  shift + edge-masked softness and before the post-optical LUT.
- A001 improved from RGB+softness MAE/RMSE `18.828026 / 26.779573` to
  `17.401152 / 25.555996`.
- Edge `r > 0.70` remains unchanged versus the softness baseline
  (`0.0 / 0.0` diffusion-vs-softness MAE/RMSE).
- This is not full iOS diffusion/mip parity. Bloom, halation, full diffusion
  parity, vignette, grain, and time effects remain blockers.

## 2. Operating Principles

- Core product progress first.
- Product quality beats conservative general advice.
- Keep outer-shell/process/hygiene work minimal unless QA is the remaining need.
- Use `sequential-thinking` for real design branches, architecture choices, and
  product-quality tradeoffs.
- Search local source first when materially unknown. Use Gemini or web search
  only if local source/docs do not answer.
- Parallelize independent reads/checks.
- Do not silently lower quality for speed.

## 3. Current Architecture

Filmtone Connect v2 uses:

- original source media copied into the package
- rendered iOS media included for reference/user continuity
- reference-after still and poster time
- combined-color cube for compatibility
- pre-optical color cube
- post-optical color cube
- DCTL bridge for Resolve texture sampling and non-cube stages

Package layout:

```text
filmtone-connect-package-v2
```

Important compatibility rule:

- `mediaFilename` remains a deprecated v1 alias.
- In v2 it intentionally points to original source media, not the baked iOS
  render, so older importers are less likely to double-process the baked render.

Expected package file ordering:

1. rendered iOS export
2. sidecar JSON
3. source media copy
4. pre-optical cube
5. post-optical cube
6. combined-color cube
7. DCTL bridge
8. reference-after still

## 4. Color Bridge Plan

Split LUT structure:

- pre-optical LUT:
  - input LUT or automatic Apple Log transform
  - base grade
  - film compression
- post-optical LUT:
  - creative/legacy LUT
  - print stage
- combined LUT:
  - scalar compatibility bridge

For Apple Log sources, Resolve texture DCTL path currently uses measured color
compensation:

```text
red:   0.97959765
green: 1.06894074
blue:  1.10818274
```

This compensation is intentionally gated to Apple Log input transform policy.

## 5. DCTL Safety Rules

Resolve can silently fail while the UI still shows a DCTL on node 1.

Known failure log:

```text
Error Processing DaVinci CTL
```

Log location:

```text
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/ResolveDebug.txt
```

Avoid:

- custom `float3` helper functions
- `float3` accumulation / vector arithmetic
- large helper-heavy DCTL structure
- promoting many optical effects at once

Prefer:

- texture transform signature
- `DEFINE_LUT`
- `_tex2D`
- `APPLY_LUT`
- scalar helper functions only
- direct scalar math in `make_float3(...)`

Promotion gate for every DCTL change:

1. `ResolveDebug.txt` has no `Error Processing DaVinci CTL`.
2. exported frame differs meaningfully from no-LUT.
3. output is compared against iOS, no-LUT, and the previous production baseline.
4. no visual-equivalence claim is made unless metrics and visual inspection agree.

## 6. Current Baseline Metrics

Known baselines:

| Comparison | MAE | RMSE | SSIM(luma) |
|---|---:|---:|---:|
| iOS device export vs attached ground truth | 1.422186 | 2.106416 | 0.999225 |
| Resolve no-LUT vs iOS device export | 26.769266 | 34.854301 | 0.702690 |
| Resolve old DCTL/cube vs iOS device export | 21.415565 | 28.859980 | 0.840251 |

Current production baseline after RGB shift:

| Comparison | MAE | RMSE |
|---|---:|---:|
| Resolve split DCTL + RGB shift vs iOS device | 18.828026 | 26.779573 |
| Resolve split DCTL + RGB shift vs no-LUT | 25.869200 | 32.033693 |
| Resolve split DCTL + RGB shift vs previous split baseline | 1.588022 | 4.177829 |
| Resolve split DCTL + RGB shift recheck vs original RGB shift baseline | 0.385920 | 1.047139 |

Interpretation:

- RGB shift is a measured improvement.
- It is not visual equivalence.
- The main remaining gap is missing optical/time effects.

## 7. Effect Promotion Roadmap

Do not add all effects at once.

### Phase 1: RGB Shift

Status: done in production DCTL.

Implementation:

- fixed 2px scalar-safe offset
- request-scaled mix from `rgbShift`
- max `rgbShift=0.005` maps to `0.72` mix
- pre-optical LUT before sample mix
- post-optical LUT after sample mix

Rejected for now:

- radial nearest / fractional iOS-like DCTL variants

Reason:

- they compiled but worsened A001 metrics compared with the fixed 2px probe.

### Phase 2: Edge-Masked Softness

Next priority.

Do not promote the global 4-tap softness probe as-is. It barely improved metrics:

```text
baseline MAE: 19.042530
softness MAE: 19.032560
```

Plan:

- add scalar-safe edge-masked softness after pre-optical color and RGB shift
- keep center detail mostly unchanged
- use a small number of taps
- avoid custom `float3` helpers
- compare against current RGB shift baseline

Promotion gate:

- CTL error false
- not no-LUT
- no material metric regression unless visual inspection clearly justifies it

### Phase 3: Halation

Rework as:

- bright plate
- lower strength if needed
- multi-radius taps
- red/orange tinting from existing iOS hue semantics

The minimal halation probe proved syntax feasibility only.

### Phase 4: Bloom

Rework as:

- bright plate
- multi-radius taps
- lower strength than naive probe
- avoid washing or darkening the frame

The minimal bloom probe regressed A001 and should not be promoted as-is.

### Phase 5: Diffusion, Vignette, Grain

Delay until visual QA is part of the gate.

Reasons:

- diffusion probe was a bad approximation
- naive vignette worsened the already-dark Resolve mismatch
- grain is punished by pixel metrics and needs visual/temporal review

### Phase 6: Multi-Source Validation

A001 is the active fixture, but not sufficient for final product claim.

Before claiming broader quality:

- test at least one additional Apple Log source
- include a non-Apple-Log source if the input-transform policy supports it
- compare iOS vs Resolve normalized frames
- perform side-by-side visual inspection
- confirm no CTL errors

## 8. Acceptance Criteria

Minimum acceptance for each promoted effect:

- generated by production code, not only temp script
- covered by Swift contract tests where practical
- Resolve import/export succeeds
- `ResolveDebug.txt` has no CTL error
- output differs from no-LUT
- compared against the previous production baseline
- no unsupported user-facing claim is introduced

Final product acceptance:

- same source media in iOS and Resolve
- reproducible import path
- reproducible reference-frame comparison
- acceptable MAE/RMSE and visual side-by-side result across more than A001
- honest copy/marker language that does not overclaim

## 9. Core Files

Production code:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
```

Contract tests:

```text
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
```

Current fixture package:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test
```

Current baseline output:

```text
/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-split-dctl-rgb-shift-recheck-normalized.png
```

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

Resolve import/export:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-a001-v2-split-dctl-test

"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  /tmp/filmtone_export_resolve_split_still.lua
```

## 11. Failure Traps

- Do not treat import success as visual equivalence.
- Do not trust Resolve UI without checking CTL logs.
- Do not skip no-LUT comparison.
- Do not promote all effects together.
- Do not use custom `float3` helpers or vector accumulation in DCTL.
- Do not promote naive diffusion/vignette/grain based on theory.
- Do not judge grain only by MAE/RMSE.
- Do not infer current state from older handoffs.
