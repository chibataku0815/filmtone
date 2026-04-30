# Filmtone iOS DaVinci Connect LOG Source Visual Equivalence Handoff

Date: 2026-04-30 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package`
Branch: `feature/filmtone-davinci-connect-package`
HEAD at handoff: `63622a8d feat(filmtone-ios): export DaVinci Connect package`

## Core Decision

The only verification that matters for this work is:

1. Take the same original LOG source.
2. Run it through Filmtone iOS and produce the iOS-rendered result.
3. Use Filmtone Connect sharing/package data to bring that same original LOG source into DaVinci Resolve.
4. Apply the Filmtone look in DaVinci.
5. Verify the DaVinci result visually/pixel-wise against the iOS-rendered result.

Package existence, native share plumbing, sidecar validity, LUT staging, marker creation, and Gallery import are useful diagnostics, but they are outer-shell checks. They do not prove the product claim unless the same LOG source produces the same picture in both iOS and DaVinci.

## 2026-04-30 JST Update: A001 v2 Source Package Verification

Verification source pair supplied by the user:

- Source LOG media: `/Users/chibatakumi/Downloads/A001_11221912_C011.MOV`
- iOS ground truth: `/Users/chibatakumi/Downloads/filmtone-export-b5d95ff3-a27a-4274-abb1-670e9082bf80.MP4`

Current v2 package generated on the real iPhone:

```text
/tmp/filmtone-connect-a001-v2-device-final
```

The package now contains six managed files:

- rendered iOS MP4: `filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c.mp4`
- sidecar JSON: `filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c.mp4.filmtone-ios-export-session-v1.json`
- source LOG copy: `filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-source.mov`
- combined color cube: `filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-combined-color.cube`
- Resolve DCTL bridge: `filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-filmtone-bridge.dctl`
- reference still: `filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-reference-after.jpg`

Sidecar package block now uses `layout: "filmtone-connect-package-v2"` and points both `sourceMediaFilename` and deprecated `mediaFilename` at the managed source copy, not the baked MP4. This is the correct product contract.

DaVinci Resolve import result:

- Lua dry-run passed.
- Resolve actual import passed.
- Current Resolve clip path was the package `*-source.mov`.
- Timeline/project was requested as `1080x1920`, `24fps`.
- Node 1 LUT was the package DCTL.
- Reference still was imported into Resolve Gallery.

Frame comparison at `referenceAfterTimeSec = 2.2604195011337866`:

```text
iOS device export vs attached ground truth: MAE 1.422186, RMSE 2.106416, SSIM(luma) 0.999225
Resolve DCTL vs iOS device export:        MAE 21.415565, RMSE 28.859980, SSIM(luma) 0.840251
Resolve DCTL vs attached ground truth:    MAE 21.414177, RMSE 28.860640, SSIM(luma) 0.840281
```

Comparison sheet:

```text
/tmp/filmtone-connect-a001-v2-device-final/compare/filmtone-connect-a001-comparison-sheet.jpg
```

Acceptance decision:

- Achieved: source-vs-rendered package distinction, package-managed source copy, unique companion filenames, DCTL file generation, Resolve source import, DCTL graph application, reference timestamp, and hard sidecar/importer contract.
- Partially achieved: a simple color bridge is wired and visibly changes the Resolve source toward the Filmtone look.
- Not achieved: verified color or visual equivalence. Do not mark "simple color reproduction" as product-quality complete while the Resolve-vs-iOS delta is still around MAE 21 / RMSE 29 / SSIM 0.84.

The current DCTL intentionally applies only the combined color cube through Resolve's documented LUT graph path. Earlier scalar vignette/grain approximations made the image farther from iOS and were removed. Bloom, halation, diffusion, lens softness, RGB shift, vignette, and grain remain explicit visual-equivalence blockers until ported accurately.

Next verification focus:

1. Compare Resolve no-LUT source frame vs Resolve DCTL frame vs iOS reference at the same frame.
2. Decide whether the remaining delta is mostly source color-management / Apple Log decode parity or missing non-cube optical effects.
3. Fix source color interpretation first if the cube bridge is not substantially closer than no-LUT.

Follow-up no-LUT isolation result:

```text
Resolve no-LUT vs iOS device export:  MAE 26.769266, RMSE 34.854301, SSIM(luma) 0.702690
Resolve DCTL/cube vs iOS device:      MAE 21.415565, RMSE 28.859980, SSIM(luma) 0.840251
Resolve no-LUT vs Resolve DCTL/cube:  MAE 25.824583, RMSE 31.751225, SSIM(luma) 0.801981
```

No-LUT comparison sheet:

```text
/tmp/filmtone-connect-a001-v2-device-final/compare/filmtone-connect-a001-no-lut-vs-dctl-sheet.jpg
```

Interpretation:

- The simple DCTL/cube bridge is working directionally: it improves SSIM from about `0.70` to `0.84` against the iOS export.
- This is still not product-quality simple color equivalence. The visible remaining gap is not only hue/white-balance; Resolve is also missing the iOS softness, diffusion, bloom/halation, RGB shift, vignette, and grain finish.
- Next implementation should port the non-cube optical/post stages into Resolve DCTL or explicitly offer a "color-only diagnostic" mode that cannot be confused with visual equivalence.

## Important Correction From The Previous Verification

The previous session successfully proved that a real iPhone can produce a 4-file package and that DaVinci Resolve can import that package. That is not the final product acceptance gate.

What actually happened:

- iPhone generated package directory:
  `/tmp/filmtone-connect-ios-real-package-20260430-114849`
- The package contained:
  - `filmtone-export-993ddaac-3041-4122-b6db-c15ca3fcca7f.mp4`
  - `filmtone-export-993ddaac-3041-4122-b6db-c15ca3fcca7f.mp4.filmtone-ios-export-session-v1.json`
  - `combined-color.cube`
  - `reference-after.jpg`
- The sidecar package block said:

```json
{
  "layout": "filmtone-connect-package-v1",
  "luts": {
    "combinedColor": "combined-color.cube"
  },
  "mediaFilename": "filmtone-export-993ddaac-3041-4122-b6db-c15ca3fcca7f.mp4",
  "referenceAfterFilename": "reference-after.jpg"
}
```

That `mediaFilename` is the iOS exported/baked MP4, not the original LOG source. The DaVinci script imported that baked MP4 and then applied `combined-color.cube` to it. This proves import plumbing, but it does not prove that DaVinci can reproduce the Filmtone image from the original LOG source. It may even represent double-processing.

## Current State Of The Worktree

The new worktree is active and should continue to be used. Leave the original worktree and its untracked docs untouched.

Current git state at handoff:

```text
branch: feature/filmtone-davinci-connect-package
HEAD: 63622a8d
modified:
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift
```

The only remaining code diff is intentionally small:

```diff
- Button(store.strings.exportAndSave) {
-     Task { await store.exportAndSave() }
+ Button(store.strings.exportStart) {
+     Task { await store.export() }
  }
  .buttonStyle(FilmtonePrimaryButtonStyle())
  .disabled(!canExport)
+ .accessibilityIdentifier("filmtone.export.primary")
```

Reason for this change:

- The old primary CTA ran `exportAndSave()`.
- `exportAndSave()` saved to Photos and then called `discardLocalExportFiles(result)`.
- That deleted the local package files before a normal user could share the Filmtone Connect package.
- Changing the primary CTA to export-only leaves the existing unsaved export prompt available for `Save to Photos` and `Share`.

Do not broaden this into UI polish. Keep this change unless the corrected visual-equivalence implementation finds a better minimal path.

## Device And Tooling Facts

Primary device:

- Name: `千葉工のiPhone (7)`
- CoreDevice ID: `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`
- Xcode destination UDID: `00008150-001674883C84401C`
- Model shown by Xcode/devicectl: `iPhone 17 Pro`
- OS shown in test result: `iOS 26.3.1`

Signing/build assumptions that worked:

- Workspace: `apps/capacitor-film-lab-ios/ios/App/App.xcworkspace`
- Scheme: `App`
- Bundle id: `com.chibatakumi.film.lab.ios`
- Team: `C3G77H8NM6`
- Derived data used: `/tmp/filmtone-ios-device-derived`

DaVinci:

- App: `/Applications/DaVinci Resolve/DaVinci Resolve.app`
- fuscript: `/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript`
- Version readback: `20.3.2.9`
- Project observed during prior import: `Filmtone Connect Package Verify 20260430-015818`

## Commands Already Run Successfully

Dependency recovery:

```sh
bun install --frozen-lockfile
```

Focused checks:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bun run verify:swift-contract
bun run build
bunx cap copy ios
```

The successful `verify:swift-contract` output included:

- Phase0 contract fixtures verified
- motion blur math tests passed
- cube parser tests passed
- CacheStore tests passed
- Source color classifier + normalizer + HDR policy tests passed
- Ray-angle optics tests passed
- Sidecar builder tests passed

Device build/install also succeeded after running CocoaPods:

```sh
cd apps/capacitor-film-lab-ios/ios/App
pod install --deployment
```

Then:

```sh
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -destination 'platform=iOS,id=00008150-001674883C84401C' \
  -configuration Debug \
  -derivedDataPath /tmp/filmtone-ios-device-derived \
  -allowProvisioningUpdates \
  build

xcrun devicectl device install app \
  --device 00008150-001674883C84401C \
  /tmp/filmtone-ios-device-derived/Build/Products/Debug-iphoneos/App.app

xcrun devicectl device process launch \
  --device 00008150-001674883C84401C \
  --terminate-existing \
  com.chibatakumi.film.lab.ios
```

## Real iPhone Package That Was Generated

The user selected a real video on the iPhone and exported it. The app container produced 4 files under:

```text
Library/Caches/FilmtonePhase0/exports
```

They were copied to:

```text
/tmp/filmtone-connect-ios-real-package-20260430-114849
```

Copied files:

```text
combined-color.cube                                                                            1.0 MB
filmtone-export-993ddaac-3041-4122-b6db-c15ca3fcca7f.mp4                                       21.3 MB
filmtone-export-993ddaac-3041-4122-b6db-c15ca3fcca7f.mp4.filmtone-ios-export-session-v1.json   6.4 KB
reference-after.jpg                                                                            378 KB
```

Package inspection passed:

- all 4 files existed and were non-empty
- sidecar `package.layout == "filmtone-connect-package-v1"`
- sidecar filenames matched actual package filenames
- Cube had `TITLE`, `LUT_3D_SIZE 33`, `DOMAIN_MIN`, `DOMAIN_MAX`, and `35937` RGB rows
- `reference-after.jpg` was a real JPEG, `1080x1920`
- output media was MP4, `1080x1920`, 24 fps, about 14.04 seconds

Again: this was useful evidence, but not final success.

## The Actual LOG Source Used

The sidecar input block contains the original source identity. This is the key object for the corrected verification.

From the real sidecar:

```json
{
  "filename": "B001_12191307_C052",
  "kind": "video",
  "sourceUri": "file:///var/mobile/Containers/Data/Application/2B89030A-C0A4-43A0-82FF-6057274F9310/Library/Caches/FilmtonePhase0/sources/B001_12191307_C052-5e68a72f-3447-46dc-9195-1b045abb173a.mov",
  "sourceProbe": {
    "codec": "apcs",
    "codecFamily": "prores-422",
    "durationSec": 14.078,
    "fileSizeBytes": 387840929,
    "frameRate": 25.003551483154297,
    "height": 3840,
    "width": 2160,
    "logTransferFunction": "apple-log"
  }
}
```

Color/source facts:

- Source is Apple Log.
- Codec family is ProRes 422 (`apcs`).
- Source display metadata says portrait display with preferred transform:
  - raw: `3840x2160`
  - display: `2160x3840`
  - rotation: `90`
- `inputTransformPolicy.strategy == "apple-log-to-rec709"`
- `hdrPreparationPolicy.strategy == "none"`

If the source still exists in the app container, it can be copied directly:

```sh
mkdir -p /tmp/filmtone-connect-log-equivalence-source
xcrun devicectl device copy from \
  --device 00008150-001674883C84401C \
  --domain-type appDataContainer \
  --domain-identifier com.chibatakumi.film.lab.ios \
  --source Library/Caches/FilmtonePhase0/sources/B001_12191307_C052-5e68a72f-3447-46dc-9195-1b045abb173a.mov \
  --destination /tmp/filmtone-connect-log-equivalence-source
```

If it no longer exists, rerun the real-device selection/export loop and copy both `sources/` and `exports/` before saving/sharing clears anything.

## Previous DaVinci Import Results

The old import command:

```sh
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-ios-real-package-20260430-114849
```

It succeeded and logged:

- imported media
- timeline item ready
- applied staged LUT to node 1:
  `Filmtone Connect/combined-color.cube`
- added Filmtone marker to timeline item
- imported reference still into Gallery

API readback succeeded:

```text
resolve_version=20.3.2.9
target_media_found=true
node1_lut=Filmtone Connect/combined-color.cube
filmtone_marker_found=true
marker_note_has_non_claim=true
gallery_current_album_stills=2
```

GUI screenshot:

```text
/tmp/filmtone-resolve-real-import-gui-20260430-1149.png
```

Why this is not enough:

- Target media was the iOS exported MP4.
- It did not import the original Apple Log ProRes source.
- It did not compare DaVinci output against iOS output from the same source.

## Aborted / Invalid Visual Compare Attempt

After the user challenged the acceptance gate, a partial visual comparison attempt started but was intentionally interrupted.

What happened:

- A Resolve current frame was exported:
  `/tmp/filmtone-resolve-current-frame-target-20260430-115543.png`
- That frame was from the baked exported MP4 import path.
- It was `3840x2160` because the Resolve project/timeline was UHD landscape.
- The package `reference-after.jpg` was `1080x1920`.
- The comparison target was therefore invalid for the real claim.

Do not continue from this comparison. Start the corrected LOG-source equivalence test instead.

## Corrected Plan

### Goal

Make the final Filmtone Connect claim true:

```text
same Apple Log source
  -> Filmtone iOS output
  == visually equivalent to
same Apple Log source
  -> DaVinci Resolve + Filmtone Connect look
```

### Required Contract Fix

The package contract must stop treating the iOS rendered output as the Resolve media input.

At minimum, the package or sidecar must distinguish:

- original source media: the Apple Log source that Resolve should import
- iOS rendered output: the ground truth Filmtone result
- reference-after: a still from the iOS rendered output at a known time
- combined-color.cube: the color LUT or color-transform component
- sidecar metadata: source transform, look params, output profile, frame/timestamp used for reference

Possible minimal package shape:

```text
source-log.mov
filmtone-rendered-output.mp4
filmtone-rendered-output.mp4.filmtone-ios-export-session-v1.json
combined-color.cube
reference-after.jpg
```

Possible sidecar package block:

```json
{
  "layout": "filmtone-connect-package-v2",
  "sourceMediaFilename": "source-log.mov",
  "renderedMediaFilename": "filmtone-rendered-output.mp4",
  "referenceAfterFilename": "reference-after.jpg",
  "referenceAfterTimeSec": 3.5195,
  "luts": {
    "combinedColor": "combined-color.cube"
  }
}
```

Do not bikeshed the schema name if a smaller additive v1 extension is safer. The product requirement is that Resolve imports the source LOG media, not the baked output.

### Required Resolve Import Fix

`apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua` must:

1. Discover the original source media from the package/sidecar.
2. Import that source media into Resolve.
3. Apply the Filmtone look to the source media.
4. Keep marker/non-claim/reference still behavior only as supporting metadata.
5. Never claim success from importing the baked iOS output and applying the LUT to it.

### Required Visual Verification

After the source-media import is fixed:

1. Export iOS ground-truth reference/output from the real iPhone.
2. Import the same original LOG source into Resolve via the package.
3. Move Resolve playhead to the same timestamp used by `reference-after.jpg`.
   - Current code uses `makePreviewPosterTime(sourceDurationSec:)`.
   - Formula observed in `FilmtoneExportSession.swift`: `sourceDurationSec * 0.25`, clamped to duration.
4. Export Resolve current frame:

```lua
project:ExportCurrentFrameAsStill("/tmp/resolve-frame.png")
```

5. Normalize dimensions/orientation/colorspace intentionally.
6. Compare against iOS ground truth:
   - first visually
   - then with numeric metrics such as MAE/RMSE/SSIM
7. Pass only if the difference is within a defined tolerance appropriate for codec/render differences.

### Critical Product Question

If Filmtone output includes effects that a `.cube` cannot reproduce, exact visual equivalence in DaVinci is impossible with a LUT-only package.

The real sidecar look params from this export included non-color effects:

```json
{
  "bloomStrength": 0.22,
  "bloomRadius": 0.52,
  "diffusion": 0.08,
  "halationSpread": 22,
  "halationRadius": 0.44,
  "grainSize": 0.3
}
```

Some intensities were zero, but the current marker note itself says:

```text
Non-claim: LUT does not recreate depth, ray-angle optics, grain, motion blur, or halation spread; those are baked/reference provenance.
```

This must be resolved honestly:

- Either the product claim becomes "Resolve matches the color-transform portion only", with visible non-LUT effects explicitly excluded.
- Or the DaVinci side must implement/apply equivalent effects, not just `combined-color.cube`.

Do not mark the work complete until this is explicit and verified.

## Files Most Likely To Change Next

Start with these, not broad repo discovery:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
  - currently writes package companions and sets `mediaFilename` to `outputURL.lastPathComponent`
  - likely needs to copy/include source LOG media or add package references to it
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
  - currently has `SidecarPackage.mediaFilename`
  - likely needs `sourceMediaFilename` and `renderedMediaFilename`, or equivalent additive fields
- `apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift`
  - update focused sidecar/package contract tests if schema changes
- `apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua`
  - currently discovers `package.mediaFilename` and imports it as Resolve media
  - must import original source media for the final gate
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift`
  - currently has the only uncommitted product fix: export-only primary CTA

## Commands For The Next Verification

Inspect current package truth:

```sh
jq '.input, .package, .output, .look' \
  /tmp/filmtone-connect-ios-real-package-20260430-114849/*.filmtone-ios-export-session-v1.json
```

List device exports:

```sh
xcrun devicectl device info files \
  --device 00008150-001674883C84401C \
  --domain-type appDataContainer \
  --domain-identifier com.chibatakumi.film.lab.ios \
  --subdirectory Library/Caches/FilmtonePhase0/exports
```

List/copy device sources:

```sh
xcrun devicectl device info files \
  --device 00008150-001674883C84401C \
  --domain-type appDataContainer \
  --domain-identifier com.chibatakumi.film.lab.ios \
  --subdirectory Library/Caches/FilmtonePhase0/sources
```

Run focused checks after code changes:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package/apps/capacitor-film-lab-ios
bun run verify:swift-contract
bun run build
bunx cap copy ios
```

Build/install to device:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -destination 'platform=iOS,id=00008150-001674883C84401C' \
  -configuration Debug \
  -derivedDataPath /tmp/filmtone-ios-device-derived \
  -allowProvisioningUpdates \
  build

xcrun devicectl device install app \
  --device 00008150-001674883C84401C \
  /tmp/filmtone-ios-device-derived/Build/Products/Debug-iphoneos/App.app

xcrun devicectl device process launch \
  --device 00008150-001674883C84401C \
  --terminate-existing \
  com.chibatakumi.film.lab.ios
```

Read Resolve version:

```sh
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  -l lua \
  -x 'local r=Resolve(); print(r and r:GetVersionString() or "NO_RESOLVE")'
```

Export current Resolve frame after corrected import:

```sh
export FILMTONE_RESOLVE_FRAME_OUT=/tmp/filmtone-resolve-log-equivalence-frame.png
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  -l lua \
  -x 'local out=os.getenv("FILMTONE_RESOLVE_FRAME_OUT"); local r=Resolve(); local p=r:GetProjectManager():GetCurrentProject(); print(p:ExportCurrentFrameAsStill(out)); print(out)'
```

## Do Not Do

Do not spend time on:

- zip packaging unless it is the smallest way to carry the original LOG source
- ASO
- docs cleanup outside this handoff
- DRX/PowerGrade/DCTL/OpenFX unless required to make the same LOG source render the same picture
- broad repo hygiene
- UI polish
- synthetic package success

Only the LOG-source visual equivalence gate matters.

## Highest-Precision Handoff Prompt For The Next Chat

Use this prompt verbatim in the next chat:

```text
We are continuing Filmtone iOS DaVinci Connect verification in:

/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio-filmtone-connect-package

Read this handoff first:

docs/filmtone/ios/filmtone-connect-log-source-visual-equivalence-handoff-2026-04-30-jst.md

Primary instruction:
The only meaningful acceptance gate is visual equivalence from the same original LOG source:

same Apple Log source -> Filmtone iOS output
must match
same Apple Log source -> DaVinci Resolve + Filmtone Connect look

Do not treat package existence, import success, sidecar validity, marker creation, LUT staging, or Gallery import as final success. Those are only diagnostics.

Current branch/state:
- branch: feature/filmtone-davinci-connect-package
- HEAD: 63622a8d
- only intended uncommitted product diff: apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift changes primary CTA from exportAndSave() to export() so package files are not deleted before Share.

Important correction:
The previous real iPhone package at /tmp/filmtone-connect-ios-real-package-20260430-114849 imported successfully into Resolve, but it was the wrong acceptance test. Its sidecar package.mediaFilename points to the iOS exported/baked MP4:

filmtone-export-993ddaac-3041-4122-b6db-c15ca3fcca7f.mp4

The original source was Apple Log ProRes 422:

Library/Caches/FilmtonePhase0/sources/B001_12191307_C052-5e68a72f-3447-46dc-9195-1b045abb173a.mov

The Resolve script imported the baked MP4 and applied combined-color.cube to it. That proves plumbing only and may be double-processing. It does not prove DaVinci can recreate the Filmtone image from LOG.

Your task:
1. Inspect the current package/sidecar/export/import contract.
2. Make the minimal product changes so the package/share/import path uses the original LOG source as Resolve input and the iOS rendered output/reference as ground truth.
3. If LUT-only cannot reproduce all Filmtone effects, state the product truth and either narrow the claim to color-only or implement the required DaVinci-side equivalent. Do not silently claim full-image parity from a LUT-only path.
4. Rebuild/install on the real paired iPhone:
   - device name: 千葉工のiPhone (7)
   - CoreDevice ID: 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9
   - Xcode destination UDID: 00008150-001674883C84401C
5. Use one real Apple Log source on the iPhone, export from Filmtone iOS, copy the exact iOS-produced package/source/output to /tmp.
6. Import into DaVinci Resolve 20.3.2.9 using the corrected package.
7. Export a Resolve still/frame at the same timestamp as iOS reference-after.jpg.
8. Compare iOS ground truth and Resolve result visually and numerically. Pass only if they match within an explicit tolerance.

Use sequential-thinking for the contract/product-quality choices. Search local source first. Use web search only if local docs/source do not answer a material question. Parallelize independent reads/checks. Do not do ASO, broad docs cleanup, zip packaging, UI polish, DRX/PowerGrade/DCTL/OpenFX, or repo hygiene unless strictly required for the same-LOG visual equivalence gate.

Relevant files:
- apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
- apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
- apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
- apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
- apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift

Known successful checks before the correction:
- bun run verify:swift-contract
- bun run build
- bunx cap copy ios
- device xcodebuild build/install

Do not mark this done until the same LOG source renders to the same picture in iOS and DaVinci, or until you have proven precisely why the current Filmtone Connect representation cannot make that claim.
```
