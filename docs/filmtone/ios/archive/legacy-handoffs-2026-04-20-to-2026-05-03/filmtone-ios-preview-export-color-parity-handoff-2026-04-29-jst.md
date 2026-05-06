# Filmtone iOS Preview/Export Color Parity Handoff

Date: 2026-04-29 JST  
Repository: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`  
App: `apps/capacitor-film-lab-ios`  
Primary problem: iOS preview and exported media can diverge badly; the exported result is much darker than the live graded preview.

## Current Status

This handoff captures the investigation, the emergency route/color-class fix already implemented, and the next recommended final fix.

The current code has a product-safety gate: Quality/default export is source-direct and does not use mezzanine. Explicit Speed mode may use mezzanine only when the source color class makes that safe.

This is a correct immediate stabilization, but it should not be treated as the final color-management architecture. The final product-quality fix is preview/export color-pipeline parity: both paths should use the same source color interpretation, Core Image working/output color spaces, output tags, and tone/gamut conversion policy.

## User-Visible Symptom

Two user-provided screenshots show a large gap:

- Dark export image: `/Users/chibatakumi/Downloads/最新の写真を表示.png`
- Bright live preview screenshot: `/Users/chibatakumi/Downloads/スクリーンショット 0008-04-29 14.39.58.png`

Measured approximate brightness from the media area:

- Export crop mean brightness: about `0.24`
- Preview crop mean brightness: about `0.52`
- Center crop export: about `0.231`
- Center crop preview: about `0.424`

This is too large to explain as a normal UI/display variance. The source material also does not appear that dark. The likely failure is in export routing/color handling, not in the look parameters.

## Investigation Summary

Preview path:

- `FilmtoneMediaRuntime.makeGradedPreviewItem` creates `AVPlayerItem(asset: asset)`.
- It assigns `item.videoComposition = processor.makeVideoComposition(...)`.
- `FilmtoneSharedGradeProcessor.makeVideoComposition` uses `AVMutableVideoComposition(asset:applyingCIFiltersWithHandler:)`.
- Net effect: preview stays on the original selected source asset.

Export path:

- `FilmtoneExportSession.exportVideo` calls `resolvedVideoSourceURL()`.
- Export then runs a separate pipeline: `AVAssetReader` -> Core Image render -> `AVAssetWriter`.
- Before the fix, Quality export could route through cached SDR/HDR mezzanine depending on availability and source classification.
- Recent local changes made iPhone Display P3 SDR resolve as `sdrBt709`, allowing SDR mezzanine prewarm and later export use even though preview never used that mezzanine.

Root contributing issue:

- Display P3 SDR (`smpte431` / `smpte432`) was incorrectly classified as `.sdrBt709`.
- Strict BT.709 and Display P3 SDR are not the same color source class.
- A cached SDR mezzanine for a P3 source can become a stale/incorrect export source and cause preview/export divergence.

## Implemented Emergency Fix

Do not compensate by raising exposure or changing look values. This fix is about routing/color-path parity.

Changed files:

- `apps/capacitor-film-lab-ios/ios/App/App/SourceColorClassifier.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/MezzanineColorProbe.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/AssetPickerService.swift`
- `apps/capacitor-film-lab-ios/scripts/swift/test-source-color-classifier.swift`

Current relevant existing file:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`

Details:

1. `SourceColorClassifier` now treats `.sdrBt709` as strict BT.709 only.
   - Required primaries: `bt709`
   - Allowed SDR transfer: `bt709` or `nil`
   - Allowed matrix: `bt709` or `nil`
   - Display P3 (`smpte431` / `smpte432`) is no longer labeled BT.709.

2. Added `FilmtoneMezzanineRoutePolicy`.
   - Default/Quality route: source-direct, even when cached mezzanines exist.
   - Explicit Speed mode:
     - `.sdrBt709` may use SDR mezzanine if present.
     - HDR/PQ/HLG/Apple Log/wide-gamut-unknown may use HDR mezzanine if present.
     - `.unknown`, `.unsupported`, and nil source class use source-direct.
   - Prewarm policy:
     - strict BT.709 -> SDR mezzanine
     - HDR/log/wide gamut -> HDR mezzanine
     - P3/unknown/missing metadata -> no prewarm

3. `MezzanineColorProbe` now reads `CMFormatDescription` extensions, normalizes them with the same source-color normalizer/classifier, then asks route policy whether prewarm is safe.
   - This avoids the old fallback where missing/unknown metadata became SDR.

4. `AssetPickerService.kickOffMezzanine` now skips prewarm when `MezzanineColorProbe.prewarmVariant(sourceURL:)` returns nil.
   - This prevents Display P3 SDR and unknown sources from producing stale SDR mezzanine caches.

5. Contract tests were updated.
   - P3 SDR no longer resolves to `.sdrBt709`.
   - Added route-selection tests:
     - default Quality is source-direct even with cached SDR/HDR mezzanines.
     - explicit Quality is source-direct.
     - Speed can use SDR only for strict BT.709.
     - Speed can use HDR for HDR source classes.
     - P3/unknown with stale SDR cache still stays source-direct.

## Important Code References

`FilmtoneExportSession.resolvedVideoSourceURL()` currently contains the Quality gate:

- Quality/default: log `Quality gate: source-direct export route`, return `sourceURL`.
- Speed only: inspect cached HDR/SDR mezzanine URLs and call `FilmtoneMezzanineRoutePolicy.selectedVariant(...)`.
- If no acceptable mezzanine exists, Speed also falls back to `sourceURL`.

`exportVideo(...)` records actual mezzanine use into sidecar via `didUseMezzanineVariant`.

Expected sidecar truth for Quality after this fix:

- `renderMode`: `quality`
- `mezzanineUsedVariant`: `null` / absent
- `mezzanineProfileVersion`: `null` / absent

## Verification Already Run

Swift contract verification passed:

```bash
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
```

The run included:

- Phase0 contract fixture verification
- motion blur math tests
- cube parser tests
- source-color-classifier tests
- ray-angle optics tests
- sidecar builder tests

iOS simulator workspace build passed:

```bash
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Note: direct `xcodebuild -project ios/App/App.xcodeproj ...` failed because Capacitor dependencies are resolved through the workspace. Use the workspace invocation.

Device verification is still required:

1. Import the same iPhone clip.
2. Wait long enough for mezzanine prewarm.
3. Export/save using Quality/default mode.
4. Confirm sidecar reports no mezzanine for Quality.
5. Visually compare export to preview; brightness should be close enough that only normal player/display differences remain.

## Industry-Standard Direction

The emergency fix is justified, but industry-standard color handling is not "avoid mezzanine forever." The correct final architecture is a single color-managed render contract shared by preview and export.

Official Apple references used during investigation:

- AVFoundation video color tagging: https://developer.apple.com/documentation/avfoundation/tagging-media-with-video-color-information
- Core Image `CIContext`: https://developer.apple.com/documentation/coreimage/cicontext
- Core Image `CIImage` color space option: https://developer.apple.com/documentation/coreimage/ciimageoption/colorspace
- `AVMutableVideoComposition` Core Image filtering: https://developer.apple.com/documentation/avfoundation/avmutablevideocomposition/videocomposition%28with%3Aapplyingcifilterswithhandler%3Acompletionhandler%3A%29
- Core Graphics `CGColorSpace`: https://developer.apple.com/documentation/CoreGraphics/CGColorSpace

Key conclusions:

1. Color tags are part of the media contract.
   - Reader/writer/composition paths must not silently discard or invent source color properties.
   - Output files need correct `AVVideoColorPropertiesKey`.

2. Wide color must be explicit.
   - Preserve it intentionally, or gamut-map/tone-map intentionally.
   - Do not silently treat Display P3 SDR as BT.709.

3. Core Image should not be left to implicit color decisions in this product path.
   - Input image color space, working color space, and destination color space should be explicit.
   - Preview and export should agree on those choices.

4. If the product output is H.264/Rec.709 MP4, preview should show the Rec.709 export look.
   - That means the preview video composition target should match the export target.
   - Export should use a destination color space aligned with the file tags.

5. If the product wants true P3 output later, add an explicit HEVC/P3 output profile.
   - Do not "sort of" preserve P3 through an H.264/Rec.709-looking path.

## Remaining Risk

Even after this emergency fix, there are still two render paths:

- Preview: `AVMutableVideoComposition` + AVPlayer pipeline on original asset.
- Export: `AVAssetReader` + manual Core Image render + `AVAssetWriter`.

That split can still create differences unless both paths share the same color contract.

Known concern to inspect next:

- `FilmtoneExportSession` has used `CGColorSpace.sRGB` as output color space while the file is tagged/treated like Rec.709.
- For fixed Rec.709 MP4 output, consider `CGColorSpace(name: CGColorSpace.itur_709)` where supported, and make writer color properties/pixel buffer attachments match.
- Preview should set composition color properties to the same output target if the preview is meant to represent the export.

## Recommended Next Fix

Keep the emergency route gate. Build the final fix on top of it.

Recommended implementation:

1. Add a central color contract/policy, for example `FilmtoneColorPipeline`.
   - Input: `SourceColorMetadataDTO` / source class / requested export profile.
   - Output: source interpretation, working color space, destination color space, writer color tags, preview composition color tags, and whether wide color is allowed.

2. Define the current default output profile explicitly.
   - Likely: Rec.709 SDR MP4 for broad compatibility.
   - If so, destination color space and `AVVideoColorPropertiesKey` should be Rec.709.

3. Apply the same contract to preview.
   - `FilmtoneSharedGradeProcessor.makeVideoComposition(...)` should receive/derive the target output color policy.
   - If preview is a preview of the export, it should target the same Rec.709 output behavior.

4. Apply the same contract to export.
   - `AVAssetReader` output settings, Core Image image construction, CIContext working/destination color space, pixel buffer attachments, and writer color tags should all agree.

5. Add focused tests.
   - Pure policy tests for P3 SDR -> Rec.709 output policy.
   - Contract tests for writer color properties.
   - A sidecar assertion that Quality export is source-direct and records output color profile.
   - If possible, a small fixture/synthetic color ramp test that compares preview/export transform intent.

6. Device verification with the original clip.
   - This is required because the failure was visual/color-managed and screenshots were the proof.

## Do Not Do

- Do not fix the dark export by increasing exposure, gamma, LUT intensity, contrast, bloom, or look parameters.
- Do not classify Display P3 SDR as `.sdrBt709`.
- Do not let Quality/default export silently use cached mezzanine.
- Do not make Speed mode fall back from wide-gamut/P3/unknown to SDR mezzanine.
- Do not rely on old handoff/status documents for the current Filmtone iOS release truth; use the current code and the app route index.

## Commit Scope Notes

Only commit the Filmtone iOS color-routing/classifier changes and this handoff document.

Do not include unrelated dirty files from `/Volumes/SamsungPortableSSDX5001/documents/life`.

Do not include unrelated untracked app document:

- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-lut-intensity-slider-handoff-2026-04-29-jst.md`

## High-Precision Prompt For Next Chat

Use this prompt verbatim in a new chat:

```text
We are working in /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio on Filmtone iOS preview/export color parity.

Read docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-preview-export-color-parity-handoff-2026-04-29-jst.md first, then inspect only the active files it references before editing.

Problem:
- iOS live preview and Quality export diverged badly; export was much darker.
- User screenshots showed export crop mean brightness about 0.24 vs preview about 0.52.
- The source is likely iPhone Display P3 SDR.
- A recent classifier path treated Display P3 SDR as sdrBt709, allowing cached SDR mezzanine use while preview used the original asset.

Current committed emergency fix:
- Quality/default export is source-direct in FilmtoneExportSession.resolvedVideoSourceURL().
- Only explicit Speed mode may use mezzanine.
- SourceColorClassifier now restricts sdrBt709 to strict BT.709 primaries.
- Display P3 SDR / unknown sources are not prewarmed as SDR mezzanine.
- FilmtoneMezzanineRoutePolicy prevents stale SDR mezzanine selection for P3/unknown.
- Contract tests cover P3 classification and route policy.

Do not solve this by changing exposure/look/LUT parameters. The final fix is color-pipeline parity.

Task:
Investigate and implement the industry-standard final fix: a shared, explicit color-managed render contract for preview and export.

Expected direction:
1. Add or reuse a central Filmtone color policy/pipeline that derives:
   - source interpretation from SourceColorMetadataDTO / source class
   - Core Image working color space
   - Core Image destination/output color space
   - AVFoundation writer color tags
   - preview AVMutableVideoComposition target color properties
   - whether wide color is preserved or mapped to Rec.709
2. For current default MP4 export, likely make Rec.709 SDR explicit end-to-end.
3. Align preview with export if preview is intended to represent saved output.
4. Keep Quality source-direct and the P3/unknown mezzanine safety gate.
5. Add focused tests for the color policy and update existing Swift contract tests.
6. Run:
   bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
   xcodebuild -workspace ios/App/App.xcworkspace -scheme App -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

Use official Apple docs as source of truth if needed:
- AVFoundation video color tagging
- Core Image CIContext color management
- CIImage colorSpace option
- AVMutableVideoComposition Core Image filtering
- CGColorSpace / Rec.709 / Display P3

Device verification remains required:
- Import the same iPhone clip.
- Wait for prewarm.
- Quality export/save.
- Confirm sidecar reports no mezzanine for Quality.
- Compare export brightness against preview.

Be careful:
- The repo may have unrelated dirty files. Stage only files you changed for this task.
- There is an unrelated untracked handoff doc docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-lut-intensity-slider-handoff-2026-04-29-jst.md; do not include it unless explicitly asked.
```
