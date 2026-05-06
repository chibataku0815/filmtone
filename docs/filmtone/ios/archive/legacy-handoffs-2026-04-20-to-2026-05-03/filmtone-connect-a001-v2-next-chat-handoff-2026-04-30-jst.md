# Filmtone Connect A001 v2 Next Chat Handoff

Date: 2026-04-30 JST
Repository: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package`
Branch: `feature/filmtone-davinci-connect-package`
Known HEAD before local edits: `63622a8d feat(filmtone-ios): export DaVinci Connect package`

This document is intentionally self-contained for a new Codex chat. It records the product goal, user priorities, exact media, implementation changes, verification evidence, current acceptance state, and the next prompt to paste into the new chat.

## User Direction And Product Bar

The user explicitly prioritized product quality over conservative process:

- Core product progress first.
- Keep outer-shell work minimal.
- Do not expand into UI polish unless required for the claim.
- Do not silently lower the quality bar.
- If something is not equivalent, fail the equivalence gate explicitly.
- Use the supplied real material as the primary verification pair.
- Use sequential thinking for real design/product decisions.
- If a manual device operation is faster, say so instead of spending tokens.

The product claim to prove is:

> The same original LOG source should produce a visually equivalent Filmtone result on iOS and in DaVinci Resolve through Filmtone Connect.

Package creation, sidecar validity, Resolve import, LUT staging, marker notes, and Gallery still import are diagnostics. They are not final acceptance unless the source LOG media rendered in DaVinci matches the iOS render.

## Verification Material

Use this exact pair:

```text
source LOG:
/Users/chibatakumi/Downloads/A001_11221912_C011.MOV

iOS attached ground truth:
/Users/chibatakumi/Downloads/filmtone-export-b5d95ff3-a27a-4274-abb1-670e9082bf80.MP4
```

Known media facts:

- Source is ProRes 422 10-bit Apple Log.
- Source file in package is 3840x2160 raw with portrait display transform; display is 2160x3840.
- Source duration is about 9.0666667s.
- Source frame rate is 30 fps.
- iOS output is H.264 Rec.709 MP4, 1080x1920, 24 fps, about 9.041667s.
- Reference frame time used in sidecar: `2.2604195011337866` seconds.

The iOS device re-export and the user-supplied ground truth are close:

```text
iOS device export vs attached ground truth:
MAE 1.422186, RMSE 2.106416, SSIM(luma) 0.999225
```

This means the supplied ground truth is a valid comparison target for the current iOS export path.

## Current Implementation State

Modified files:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
```

Untracked docs currently include:

```text
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-log-source-visual-equivalence-handoff-2026-04-30-jst.md
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-a001-v2-next-chat-handoff-2026-04-30-jst.md
```

The temporary auto-export launch hook was removed from `AppDelegate.swift`. There is no current `AppDelegate.swift` diff.

## What Was Implemented

### Export CTA

`FilmtoneExportPanel.swift` keeps the minimal export-only CTA fix:

- Primary export button now calls `store.export()`.
- It no longer calls `exportAndSave()`.
- This avoids deleting the local export/package files immediately after save-to-Photos.
- Accessibility id: `filmtone.export.primary`.

Do not broaden this into UI polish.

### Connect Package v2

`FilmtoneExportSidecarBuilder.swift` now emits:

```json
{
  "layout": "filmtone-connect-package-v2",
  "mediaFilename": "<source copy>",
  "sourceMediaFilename": "<source copy>",
  "renderedMediaFilename": "<iOS rendered mp4>",
  "referenceAfterFilename": "<reference still>",
  "referenceAfterTimeSec": 2.2604195011337866,
  "luts": {
    "combinedColor": "<unique cube>"
  },
  "effects": {
    "dctl": "<unique DCTL>"
  }
}
```

Important contract details:

- `mediaFilename` is kept only as a deprecated v1 alias.
- In v2, `mediaFilename` intentionally points to the original source copy, not the rendered MP4.
- This prevents old import scripts from double-processing the baked iOS render.
- Each export writes unique companion filenames:
  - `<export-stem>-combined-color.cube`
  - `<export-stem>-filmtone-bridge.dctl`
  - `<export-stem>-reference-after.jpg`
  - `<export-stem>-source.mov`
- The source is copied into the export package as a managed package copy.
- The package no longer depends on the live `sources/` cache file.

### DCTL Generation

Current generated DCTL is deliberately minimal:

```c
DEFINE_LUT(FilmtoneCombinedColor, <unique-combined-color.cube>)

__DEVICE__ float3 transform(int p_Width, int p_Height, int p_X, int p_Y, float p_R, float p_G, float p_B)
{
    float3 rgb = make_float3(p_R, p_G, p_B);
    rgb = APPLY_LUT(rgb.x, rgb.y, rgb.z, FilmtoneCombinedColor);
    return clamp(rgb);
}
```

The DCTL comment explicitly states:

```text
This DCTL applies the package combined-color cube inside Resolve's documented
LUT graph path. Non-cube optical/time effects remain explicit equivalence
blockers until they are ported byte-for-byte from the iOS render pipeline.
```

Earlier approximate vignette/grain code was removed because it made Resolve output farther from iOS. Do not reintroduce approximate effects unless metrics prove improvement and the marker note remains honest.

### Package File Ordering

`FilmtoneConnectPackageFiles.orderedPackageFileUris(...)` orders:

```text
rendered MP4
sidecar JSON
source media copy
combined cube
DCTL
reference still
```

### DaVinci Importer

`filmtone_connect_import_package.lua` now:

- Recognizes `filmtone-connect-package-v2`.
- Prefers `sourceMediaFilename`.
- Treats `renderedMediaFilename` as iOS reference/rendered media, not source.
- Excludes `.dctl` from media fallback.
- Fails v2 if source media is missing.
- Fails v2 if declared DCTL is missing.
- Stages cube and DCTL into Resolve LUT storage.
- Applies the package DCTL to node 1 through Resolve's documented LUT graph path.
- Creates a v2 timeline from the source LOG media.
- Requests timeline/project settings from sidecar output:
  - `1080x1920`
  - `24fps`
- Imports the reference still into Gallery.
- Writes a marker note that clearly states package existence is not equivalence.

Marker note now includes:

```text
Bridge coverage: combined-color cube through DCTL; optical/time effects remain explicit visual equivalence blockers until ported.
Equivalence gate: source media plus Filmtone bridge must match the iOS rendered/reference output; package existence alone is not a claim.
```

## Verification Commands That Passed

Run from:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
```

Passed:

```sh
bun run verify:swift-contract
bun run build
bunx cap copy ios
```

Device build and install passed:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package

xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -destination 'platform=iOS,id=00008150-001674883C84401C' \
  -derivedDataPath /tmp/filmtone-ios-device-derived \
  build

xcrun devicectl device install app \
  --device 00008150-001674883C84401C \
  /tmp/filmtone-ios-device-derived/Build/Products/Debug-iphoneos/App.app
```

Resolve dry-run and import passed:

```sh
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --dry-run \
  --package /tmp/filmtone-connect-a001-v2-device-final

"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-a001-v2-device-final
```

Resolve import output confirmed:

```text
imported source media:
/tmp/filmtone-connect-a001-v2-device-final/filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-source.mov

applied staged LUT to node 1:
Filmtone Connect/filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-filmtone-bridge.dctl
```

## Real v2 Package To Reuse

The final package copied from the real iPhone is:

```text
/tmp/filmtone-connect-a001-v2-device-final
```

Files:

```text
filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c.mp4
filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c.mp4.filmtone-ios-export-session-v1.json
filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-source.mov
filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-combined-color.cube
filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-filmtone-bridge.dctl
filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-reference-after.jpg
```

Sidecar contract:

```json
{
  "layout": "filmtone-connect-package-v2",
  "sourceMediaFilename": "filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-source.mov",
  "renderedMediaFilename": "filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c.mp4",
  "mediaFilename": "filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-source.mov",
  "referenceAfterFilename": "filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-reference-after.jpg",
  "referenceAfterTimeSec": 2.2604195011337866,
  "luts": {
    "combinedColor": "filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-combined-color.cube"
  },
  "effects": {
    "dctl": "filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-filmtone-bridge.dctl"
  }
}
```

Look parameters in this package:

```text
presetName: reset
bloomStrength: 0.24
bloomRadius: 0.68
bloomThreshold: 0.64
bloomSoftKnee: 0.76
diffusion: 0.09
halationIntensity: 0.06
halationSpread: 34
halationHue: 20
halationThreshold: 0.56
halationRadius: 0.66
halationSoftKnee: 0.58
lensSoftness: 0.44
rgbShift: 0.005
vignette: 0.62
grainIntensity: 0.025
grainRadialMix: 1
grainSize: 0.3
printContrast: 0.04
cyan: 0.018
magenta: -0.025
yellow: -0.03
compressionAmount: 0.04
compressionRange: 0.54
```

Input source sidecar facts:

```text
filename: A001_11221912_C011
codec: apcn
codecFamily: prores-422
logTransferFunction: apple-log
durationSec: 9.066666666666666
frameRate: 30
width: 2160
height: 3840
display raw: 3840x2160
display rotated: 2160x3840
rotationDeg: 90
colorPrimaries: bt2020
colorSpace: bt2020nc
colorTransfer: apple-log
inputTransformPolicy.strategy: apple-log-to-rec709
hdrPreparationPolicy.strategy: none
```

## Verification Outputs

Comparison frames:

```text
/tmp/filmtone-connect-a001-v2-device-final/compare/ios-attached-ground-truth.png
/tmp/filmtone-connect-a001-v2-device-final/compare/ios-device-rendered.png
/tmp/filmtone-connect-a001-v2-device-final/compare/ios-package-reference-after.png
/tmp/filmtone-connect-a001-v2-device-final/compare/resolve-reference-after-normalized.png
/tmp/filmtone-connect-a001-v2-device-final/compare/resolve-no-lut-normalized.png
```

Comparison sheets:

```text
/tmp/filmtone-connect-a001-v2-device-final/compare/filmtone-connect-a001-comparison-sheet.jpg
/tmp/filmtone-connect-a001-v2-device-final/compare/filmtone-connect-a001-no-lut-vs-dctl-sheet.jpg
```

Metrics:

```text
iOS device export vs attached ground truth:
MAE 1.422186, RMSE 2.106416, SSIM(luma) 0.999225

Resolve no-LUT vs iOS device export:
MAE 26.769266, RMSE 34.854301, SSIM(luma) 0.702690

Resolve DCTL/cube vs iOS device export:
MAE 21.415565, RMSE 28.859980, SSIM(luma) 0.840251

Resolve DCTL/cube vs attached ground truth:
MAE 21.414177, RMSE 28.860640, SSIM(luma) 0.840281

Resolve no-LUT vs Resolve DCTL/cube:
MAE 25.824583, RMSE 31.751225, SSIM(luma) 0.801981
```

Interpretation:

- The iOS re-export is equivalent enough to the attached ground truth for this verification.
- The Resolve DCTL/cube bridge is working directionally.
- It improves SSIM against iOS from about `0.70` to about `0.84`.
- This proves the simple color bridge is wired and active.
- It does not prove product-quality simple color reproduction.
- The Resolve output remains visibly harder/sharper and lacks the iOS optical/post finish.

## Correction To User's "Simple Color Reproduction" Assumption

Precise wording:

- Correct: "The simple color bridge is wired and moves Resolve output in the right direction."
- Not correct yet: "Simple color reproduction is complete at the quality bar."

Reason:

- If color reproduction were complete, Resolve DCTL/cube vs iOS would be close enough for the chosen tolerance.
- Current Resolve-vs-iOS is still around `MAE 21 / RMSE 29 / SSIM 0.84`.
- The remaining visual difference is large enough that the product claim must remain failed.

## Known Product Blocker

The package/import contract is now correct, but visual equivalence is blocked by missing or incomplete Resolve-side reproduction of iOS render stages:

- softness / lensSoftness
- diffusion
- bloom
- halation
- RGB shift / chromatic split
- vignette
- grain
- potentially color-management parity between iOS Apple Log transform and Resolve source interpretation

The next agent must not mark the current DCTL/cube bridge as equivalence. It is a diagnostic color bridge.

## Recommended Next Work

Priority order:

1. Keep v2 package/source import contract intact. Do not regress to importing rendered MP4 as source.
2. Keep current DCTL honest. It may be a color-only bridge until more effects are accurately ported.
3. Decide whether the next step is:
   - Implement accurate Resolve reproduction of non-cube optical/post stages, or
   - Expose/label the current path as "color-only diagnostic" and create a separate equivalence path.
4. Before porting spatial effects, confirm the Resolve DCTL API form supports neighborhood sampling or the needed graph construction. If not, do not fake diffusion/softness with per-pixel scalar approximations.
5. If DCTL can sample neighboring pixels, port effects in the smallest order that moves metrics:
   - lensSoftness/diffusion first, because the visible gap is sharpness/softness.
   - bloom/halation next.
   - vignette and RGB shift next.
   - grain last, because deterministic temporal grain equivalence is harder and may reduce pixel metrics.
6. After each effect, export the Resolve frame at `2.2604195011337866s` and compare against both:
   - package iOS rendered frame
   - attached ground truth frame

Acceptance for the next phase should be explicit. Suggested interim gates:

- Color-only diagnostic gate: DCTL/cube improves no-LUT materially and marker says non-cube effects are unsupported.
- Visual equivalence gate: Resolve frame matches iOS within agreed codec/render tolerance and passes visual inspection.

Do not collapse these gates.

## Useful Commands

Inspect sidecar:

```sh
jq '{package, output, look:{presetName:.look.presetName, params:.look.params}, input:.input}' \
  /tmp/filmtone-connect-a001-v2-device-final/*.json
```

Run importer:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package

"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-a001-v2-device-final
```

Extract iOS reference frame:

```sh
SEC=2.2604195011337866
BASE=/tmp/filmtone-connect-a001-v2-device-final

ffmpeg -y -v error -ss "$SEC" \
  -i "$BASE/filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c.mp4" \
  -frames:v 1 \
  -vf "scale=1080:1920:flags=lanczos,setsar=1,format=rgb24" \
  "$BASE/compare/ios-device-rendered.png"
```

Extract attached ground truth frame:

```sh
SEC=2.2604195011337866
BASE=/tmp/filmtone-connect-a001-v2-device-final

ffmpeg -y -v error -ss "$SEC" \
  -i /Users/chibatakumi/Downloads/filmtone-export-b5d95ff3-a27a-4274-abb1-670e9082bf80.MP4 \
  -frames:v 1 \
  -vf "scale=1080:1920:flags=lanczos,setsar=1,format=rgb24" \
  "$BASE/compare/ios-attached-ground-truth.png"
```

Temporary Resolve verification scripts used in the previous chat:

```text
/tmp/filmtone_export_resolve_still.lua
/tmp/filmtone_export_resolve_no_lut.lua
```

If those files are gone, recreate scripts that:

- open Resolve Color page
- get current project/timeline
- set current timecode to `01:00:02:06`
- confirm current clip path is package `*-source.mov`
- confirm node 1 LUT is package DCTL
- call `project:ExportCurrentFrameAsStill(...)`
- for no-LUT, temporarily disable node 1 with `graph:SetNodeEnabled(1, false)`, export, then re-enable it

## High-Precision Prompt For The Next Chat

Paste the following into a new Codex chat:

```text
We are continuing Filmtone Connect A001 v2 visual-equivalence work.

Repository:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package

Branch:
feature/filmtone-davinci-connect-package

Read this handoff first:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-a001-v2-next-chat-handoff-2026-04-30-jst.md

Also read the related verification handoff if needed:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-log-source-visual-equivalence-handoff-2026-04-30-jst.md

User priorities:
- Product quality is the top priority.
- Core progress first; keep outer-shell/documentation/UI polish minimal.
- Do not mark diagnostic import/package success as visual equivalence.
- Use sequential-thinking for real design or product-quality decisions.
- If local context is insufficient, search or ask. If device operation is faster, ask me to operate the iPhone.
- For independent reads/checks, run tools in parallel.

Verification media:
- Source LOG: /Users/chibatakumi/Downloads/A001_11221912_C011.MOV
- iOS ground truth: /Users/chibatakumi/Downloads/filmtone-export-b5d95ff3-a27a-4274-abb1-670e9082bf80.MP4
- Current real iPhone v2 package: /tmp/filmtone-connect-a001-v2-device-final
- Reference time: 2.2604195011337866 seconds

Current implementation state:
- Connect package v2 is implemented.
- v2 sourceMediaFilename points to package-managed source LOG copy.
- legacy mediaFilename is a deprecated alias to the source copy, not the baked MP4.
- renderedMediaFilename points to the iOS rendered MP4.
- package includes unique cube, DCTL, reference still, and source copy.
- DaVinci importer imports the LOG source and applies package DCTL to node 1.
- DCTL currently applies only the combined-color cube. It deliberately does not approximate optical/time effects.

Important correction:
The simple color bridge is wired and active, but product-quality simple color reproduction is not complete.
Metrics:
- Resolve no-LUT vs iOS: SSIM(luma) 0.702690
- Resolve DCTL/cube vs iOS: SSIM(luma) 0.840251
- Resolve DCTL/cube vs iOS still has MAE about 21 and RMSE about 29.
So the bridge improves the image directionally, but visual/color equivalence is still failed.

Task:
Continue from this state. Do not redo already completed package/import work unless needed for verification.

Main objective:
Move DaVinci output from "color-only diagnostic bridge" toward real visual equivalence with the iOS output from the same LOG source.

Recommended first step:
Use sequential-thinking to decide whether the next implementation should:
1. Port non-cube optical/post stages into Resolve DCTL or another Resolve-supported graph path, or
2. First isolate source color-management / Apple Log decode parity further.

Constraints:
- Do not regress the v2 source package contract.
- Do not import the baked iOS MP4 as the source.
- Do not reintroduce approximate vignette/grain/softness code unless metrics and visual inspection improve.
- Keep marker/user-facing claims honest: color-only diagnostic is not visual equivalence.
- Prefer focused changes in:
  - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
  - apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
  - apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
  - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift only if the sidecar/package needs new effect metadata

Verification required after changes:
1. bun run verify:swift-contract
2. bun run build
3. bunx cap copy ios
4. Device xcodebuild/install only if iOS-generated package changes are needed.
5. DaVinci Lua dry-run and import against /tmp/filmtone-connect-a001-v2-device-final or a newly generated package.
6. Export Resolve still at 2.2604195011337866s.
7. Normalize to 1080x1920 RGB and compare against:
   - /tmp/filmtone-connect-a001-v2-device-final/compare/ios-device-rendered.png
   - /Users/chibatakumi/Downloads/filmtone-export-b5d95ff3-a27a-4274-abb1-670e9082bf80.MP4 extracted at the same time.
8. Report MAE, RMSE, SSIM, and visual interpretation.

Acceptance:
- Source package contract remains correct.
- DaVinci uses the source LOG media.
- DCTL/Resolve graph path is applied.
- Any improvement is measured against the previous baseline.
- Do not call it visual equivalence until the Resolve frame actually matches iOS within the chosen tolerance.

Start by reading the handoff, checking current git status, and inspecting the current DCTL/importer code. Then continue implementation/verification.
```
