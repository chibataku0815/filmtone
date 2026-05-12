# Export Audio / Detail Softness Handoff

Date: 2026-05-12 JST
Status: handoff only. No product code changed in this document.
Primary source docs:

- `docs/filmtone/2026-05-11-export-audio-investigation.md`
- `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`

This handoff exists because the iOS feature-architecture refactor changed the
code layout after the two source documents were written. A new chat should use
this document as the current orientation layer, then open the two source docs for
the full original context.

## Current Repository State

Repository:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Current branch at handoff time:

```text
main @ 95f1be03 merge: integrate iOS feature architecture refactor
git status --short --branch: ## main...origin/main [ahead 108]
```

The `feature/ios-feature-architecture` lane has been merged to `main`, and the
temporary feature worktree / branch cleanup was handled before this handoff.
Do not route future work to the retired feature worktree.

Release truth checked on 2026-05-12:

- iOS public App Store version: `1.8`
- iOS Xcode marketing version/build in this repo: `1.8` / `7`
- iOS public release date from App Store metadata:
  `2026-05-10T10:57:25Z`
- Native Desktop public update metadata: `1.6`
- Native Desktop Xcode marketing version/build: `1.6` / `3`
- The old Desktop tag `desktop-v1.4` is not the Native Desktop public truth
  after the v1.4 cutover; trust the truth scripts over stale docs.

Before making fresh release/version claims, rerun:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
FILMTONE_REPO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone \
  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

## Operating Premise

The owner explicitly set this priority:

- Product quality and core progress come first.
- Keep outer-shell work minimal until the product surface is working.
- Do not bias toward conservative delay when a direct product-quality fix is
  available.
- Use larger implementation bundles when the boundaries are coherent. The
  earlier tiny Phase 2B sub-stages were useful for refactor risk control, but
  the next product work should not copy that granularity unless the code demands
  it.
- Gyroflow is not part of the immediate next work. Do not create a Gyroflow lane
  unless the owner explicitly reopens that direction.

The two current issues are independent:

1. Export audio preservation: user-observed product bug / missing feature.
2. Detail Softness + Source Detail Compensation: new image-quality feature.

Do not implement both in the same `active.md`. If both are pursued, use two
separate lanes or pause one lane before opening the other.

## Current iOS Architecture After Refactor

The iOS app is now feature-foldered under:

```text
apps/capacitor-film-lab-ios/ios/App/App/
```

The old flat-root paths in pre-refactor docs are no longer current.

Important current line counts:

```text
Export/FilmtoneExportSession.swift    1078 lines
Editor/FilmtoneEditorStore.swift      1723 lines
Capture/FilmtoneCaptureSession.swift   880 lines
```

Current export collaborators relevant to these tasks:

```text
apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoIOBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMediaWriter.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoAudioPump.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoCompletionCoordinator.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportFrameAppender.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSidecarWriter.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift
```

The source docs mention old line numbers from the pre-refactor export session.
Use `rg` in the current paths instead of trusting those line numbers.

## Task 1: Export Audio Preservation

### Product Truth

The user-observed symptom is the source of truth for this investigation:

- Current exported media from both iOS and Desktop has no audible audio track.
- The important truth is the final exported file, not whether the code appears
  to intend audio preservation.
- iOS Photos save and Share pass the already-rendered file URL through; they are
  unlikely to strip audio themselves. If those outputs are silent, first suspect
  the rendered export file.

### Native Desktop Current State

Current Native Desktop app:

```text
apps/filmtone-desktop-macos/
```

Relevant files:

```text
apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoWriter.swift
apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoReader.swift
```

Current Native Desktop export is video-only by construction:

- `FilmtoneVideoWriter` owns `AVAssetWriter`, one video
  `AVAssetWriterInput`, and one pixel-buffer adaptor.
- It has no audio writer input.
- `FilmtoneVideoReader` creates one video `AVAssetReaderTrackOutput`.
- The exporter appends rendered video frames only.
- Preview audio is not evidence. Native Desktop preview uses `AVPlayer`, so
  preview can play audio while export remains silent.

Conclusion:

```text
Native Desktop silent exports are expected from current implementation.
This is missing export functionality, not a downstream save/playback issue.
```

Old Electron Desktop contrast:

```text
apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.ts
apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.test.ts
```

The old Electron path did have ffmpeg audio copy:

- second input when `hasAudio`
- `-map 1:a:0`
- `-c:a copy`

That proves audio preservation existed historically, but it does not apply to
the current Native Desktop app.

### iOS Current State

Shared default says audio should be preserved:

```text
packages/film-lab-core/src/phase0-schema.ts
PHASE0_OUTPUT_PROFILE.preserveAudio: true
```

Current iOS export path after refactor:

```text
Export/Internal/ExportVideoIOBuilder.swift
Export/Internal/ExportMediaWriter.swift
Export/Internal/ExportVideoAudioPump.swift
Export/FilmtoneExportSession.swift
Export/Internal/ExportSidecarWriter.swift
Export/FilmtoneExportSidecarBuilder.swift
```

Current intended audio flow:

1. `ExportVideoIOBuilder.makeContext(...)` selects an audio track only when:

   ```swift
   highlightTimeline == nil && request.output.preserveAudio
   ```

2. If an audio track is found, it calls:

   ```swift
   mediaWriter.makeAudioPipeline(for: audioTrack)
   ```

3. The writer pipeline creates:

   - `AVAssetReaderTrackOutput` configured as 16-bit Linear PCM
   - `AVAssetWriterInput` configured as AAC, 128 kbps, 2 channels, 44.1 kHz

4. `ExportVideoAudioPump` drains `audioOutput.copyNextSampleBuffer()` and
   appends to the audio writer input.

5. `FilmtoneExportSession.exportVideo(...)` returns:

   ```swift
   audioPreserved: audioInput != nil
   ```

Current weak points:

- If `writer.canAdd(audioInput)` is false, `ExportVideoIOBuilder` simply does
  not add the input, but `audioInput` remains non-nil.
- If `reader.canAdd(audioOutput)` is false, it simply does not add the output,
  but `audioOutput` remains non-nil.
- `audioPreserved` means "we had an intended audio input", not "the completed
  output file has an audio track".
- There is no post-export validation that opens `outputURL` and checks final
  output audio tracks.
- `FilmtoneExportSidecarBuilder` receives `audioPreserved`, but currently does
  not surface actual audio truth in schema:

  ```swift
  _ = inputs.audioPreserved // currently not surfaced in schema; runtime uses output.preserveAudio
  ```

Conclusion:

```text
iOS has an intended audio preservation path, but its truth checks are weak.
Treat it as unverified and currently failing in practice until a completed
output file proves otherwise.
```

### Mezzanine Caveat

`apps/capacitor-film-lab-ios/ios/App/App/Services/MezzanineService.swift` also
has audio reader/writer code. Do not confuse that with the main final export
truth. The product bug is about final exported media. Mezzanine behavior is
relevant only insofar as final export uses a routed mezzanine source.

### Missing Verification

There is no current verification gate that proves exported files contain audio.

CLI check:

```bash
ffprobe -v error -select_streams a \
  -show_entries stream=index,codec_type,codec_name,channels,sample_rate,duration \
  -of json /path/to/export.mp4
```

Equivalent Swift check:

```swift
let asset = AVURLAsset(url: outputURL)
let audioTracks = try await asset.loadTracks(withMediaType: .audio)
// When the source had audio and preserveAudio is true, audioTracks must be non-empty.
```

For iOS and Native Desktop, final output validation should be based on the
completed file, not on intermediate writer intent.

### Recommended Implementation Order

Start with export audio before Detail Softness unless the owner redirects. It is
a user-observed output bug.

Use a larger but coherent bundle, not tiny sub-stages:

1. Add a small output-audio validation primitive.
   - It can be platform-specific Swift first.
   - It should inspect source audio presence and final output audio presence.
   - It should return explicit truth, not only log.

2. Fix iOS audio setup truth.
   - If source has audio and `preserveAudio` is true, failure to add the writer
     input or reader output should fail loudly or disable audio with an explicit
     reason. Do not silently return `audioPreserved: true`.
   - `CompletedExport.audioPreserved` should reflect the completed output
     validation, not `audioInput != nil`.
   - Preserve highlight-reel behavior: `highlightTimeline != nil` intentionally
     disables source audio unless product direction changes.

3. Add Native Desktop audio writing.
   - Port the iOS AVAssetReader / AVAssetWriter audio pattern into the Native
     Desktop exporter/writer path.
   - Keep the existing rendered video frame path intact.
   - Validate the completed output asset before reporting success.

4. Add the smallest durable gate.
   - Prefer a fixture or command that proves final output audio stream presence.
   - Avoid broad QA matrix until the basic product truth is fixed.

Potential first lane placement:

```text
docs/filmtone/export-audio/
├── strategy.md
├── active.md
└── archive/
```

Potential first `active.md` goal:

```text
Milestone: Export Audio Restoration A
Goal: make iOS export audio preservation truthful and fail-loud, then add final
output audio validation that can be reused by Native Desktop.
```

If the owner wants Desktop fixed in the same bundle, widen the goal to:

```text
Goal: restore final output audio preservation on iOS and Native Desktop, with
completed-file validation on both platforms.
```

## Task 2: Detail Softness / Source Detail Compensation

### Goal

Add a filmic softness system that reduces hard digital detail without making the
image look simply blurred.

Separate two concepts:

- `detailSoftness`: user-facing creative control.
- Source Detail Compensation: automatic source-aware bias, especially for
  iPhone and other heavily processed consumer video.

This is not a 1-inch-camera-only recipe. The feature should help any source
that arrives too sharp, too locally contrasty, or too edge-enhanced.

### Current Product Premise

Filmtone already has:

- `lensSoftness` for lens/periphery softness.
- RGB shift, edge softness, vignette, bloom, halation, diffusion, optical
  scatter.
- film compression / print controls.
- grain with luma-aware behavior in native pipelines.

The missing piece is a center-inclusive fine-detail treatment. Do not overload
`lensSoftness` for this; it is semantically and technically tied to lens/edge
behavior.

Current `detailSoftness` code state:

- `rg detailSoftness` has no product-code hits except the planning document.
- `lensSoftness` is already present across core schemas, Swift params, iOS
  strings, Desktop advanced controls, optical recommendations, and render code.

### Proposed Contract

User control:

```text
key: detailSoftness
range: 0...1
default: 0
```

Useful working range:

```text
0.06-0.10  subtle digital edge relief
0.12-0.18  visible filmic softening
0.20-0.28  strong soft finish
>0.30      allowed only with protection against obvious blur
```

Effective render value:

```text
effectiveDetailSoftness = clamp(detailSoftness + sourceDetailBias, 0, effectiveMax)
```

Initial clamps:

```text
effectiveMax: 0.34
unknown source bias: 0.00-0.03
known strong-sharpening consumer auto contribution: cap around 0.14
```

The auto source bias must not be saved into user Looks by default. A Look should
remain portable across footage.

### Algorithm Direction

Do not implement this as a plain Gaussian blur.

Target behavior:

1. Build a small-radius local reference from the graded image.
2. Compute high-frequency detail as source minus local reference.
3. Reduce high-frequency contrast by `effectiveDetailSoftness`.
4. Protect major edges and readable boundaries with a gradient guard.
5. Reduce luma detail more than chroma detail.
6. Let hard highlight edges soften slightly more than midtone texture.
7. Apply before grain so generated grain remains crisp.

Initial behavior:

- radius roughly `0.55-1.45 px`, depending on strength and output scale.
- optional wider support only at stronger values.
- luma detail attenuation stronger than chroma attenuation.
- edge guard based on local luma gradient.
- highlight-edge bias using luma and local contrast.

Failure modes to reject:

- all-over blur
- waxy skin
- unreadable text
- smeared hair or foliage
- halo doubling before bloom
- preview/export mismatch
- temporal shimmer on video

### Pipeline Placement

Preferred target ordering:

```text
input LUT
-> base grade
-> tone compression
-> Detail Softness
-> edge optics / lensSoftness / rgbShift
-> glow family: bloom, halation, diffusion, optical scatter
-> vignette
-> grain
-> creative LUT
-> print stage
```

Reasoning:

- after base grade/compression, it sees the intended tonal shape.
- before glow, hard digital edges do not over-feed bloom or halation.
- before grain, generated grain remains crisp.
- before creative LUT/print, color pipeline behavior stays stable.

Composite-only MVP is lower quality because bloom/halation would still be
generated from the hard source. Use that only as a temporary spike, not as the
target architecture.

### Source Detail Profiles

Initial source-compensation profile groups:

```text
Apple iPhone SDR / HEVC / non-Log: +0.08...+0.14
Apple Log / Apple Log 2:            +0.04...+0.08
DJI Osmo / action consumer video:   +0.06...+0.12
GoPro / action camera:              +0.08...+0.15
Sony / Canon / Panasonic Log:       +0.00...+0.04
Unknown Rec.709:                    +0.00...+0.03
Unknown Log:                         0.00
```

These are tuning starting points, not manufacturer-certified transforms.

Useful metadata:

```text
cameraOptics.cameraMake
cameraOptics.cameraModel
cameraOptics.lensModel
sourceVideoMetadata.logTransferFunction
sourceVideoMetadata.inputTransformPolicy
codec family where available
```

Suggested future struct:

```text
SourceDetailProfile {
  id: string
  confidence: low | medium | high
  manufacturer?: string
  modelFamily?: string
  transferClass?: rec709 | hdr | log | unknown
  recommendedBias: number
  effectiveMax: number
  reason: string
}
```

### Contract Targets

Expected shared core targets:

```text
packages/film-lab-core/src/params.ts
packages/film-lab-core/src/schema.ts
packages/film-lab-core/src/phase0-schema.ts
packages/film-lab-core/src/quick-semantics.ts
packages/film-lab-core/src/ios-swift-payload.ts
packages/film-lab-core/src/ios-phase0.test.ts
packages/film-lab-core/src/ios-swift-payload.test.ts
packages/film-lab-core/src/schema.test.ts
```

Expected Swift / generated targets:

```text
packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtonePhase0Params.swift
packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtonePhase0ParamsPatch.swift
packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift
```

Generated Swift must be regenerated, not hand-edited.

Decision point:

```text
FilmtonePhase0ParamsPatch.opticsGlowKeys
```

Include `detailSoftness` there only if it is part of Look optical identity.
Never include automatic `sourceDetailBias` as a saved Look param.

### Render Targets

Expected implementation surfaces:

```text
packages/film-lab-renderer/
apps/filmtone-desktop-macos/
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift
apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift
apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneSharedGradeProcessor.swift
```

The exact native Swift render insertion point must be verified from current
code. The target is after tone compression and before edge optics/glow/grain.

### UI / Copy

Initial UI should be minimal:

- Add `Detail Softness` to Advanced > Optics or a renamed Optics / Texture
  group.
- Keep `Lens Softness`, but later clarify that it is lens-like edge/periphery
  softness.
- Do not expose many technical sub-controls.

Copy direction:

```text
Detail Softness: "Softens hard fine detail without adding glow."
Lens Softness: "Adds lens-like edge softness."
Source compensation: "Balances capture sharpening from the source."
```

Before changing user-facing copy, read:

```text
docs/filmtone/filmtone-copy-quality-harness.md
```

### Recommended Detail Softness Phases

If this lane is opened after export audio, use larger phase slices than the iOS
architecture refactor did.

Recommended lane placement:

```text
docs/filmtone/detail-softness/
├── strategy.md
├── active.md
└── archive/
```

Recommended phases:

1. Contract + neutral plumbing.
   - Add `detailSoftness` everywhere with default `0`.
   - No visual change.
   - Existing projects and Looks load unchanged.
   - `detailSoftness: 0` must be bit-neutral.

2. Real render pass.
   - WebGL, WebGPU, macOS native, iOS export/preview.
   - Place before glow and grain.
   - Reject plain blur.

3. UI exposure + recipe decision.
   - Advanced control and labels.
   - Decide whether optical recipes include it.
   - Suggested first recipe values:
     - default optical recipe: `max(base.detailSoftness, 0.10)`
     - strong optical recipe: `max(base.detailSoftness, 0.18)`

4. Source Detail Compensation.
   - Shared resolver.
   - Metadata-driven conservative bias.
   - Keep user value and auto bias separate in debug / sidecar.

5. Visual tuning matrix.
   - iPhone SDR HEVC
   - iPhone Apple Log / ProRes
   - DJI / action camera Rec.709
   - Sony / Canon / Panasonic Log
   - low-light noisy clip
   - hair / foliage / brick / text
   - strong practical light or window highlight

## Verification Guidance

Use the smallest verification that proves the changed surface.

Export audio:

```bash
bun run verify:ios
bun run verify:macos
git diff --check
```

Also add a direct audio-track proof, either `ffprobe` or AVFoundation, against
the completed output file. The audio bug is not fixed until this proof is green.

Detail Softness:

```bash
bun run build:core
bun run build:renderer
bun run verify:macos
bun run verify:ios
git diff --check
```

For generated Swift:

```bash
bun run generate:ios-swift
```

If the generator has a check mode, use it. Otherwise inspect the generated diff.

For user-facing copy:

```bash
bun run check:filmtone-copy
```

For public claims, release wording, or implementation-history sync:

```bash
bun run check:filmtone-context
```

## Stop Conditions

Export audio:

- Source file has audio, `preserveAudio` is true, completed output has no audio.
- Code reports `audioPreserved: true` without completed-output proof.
- Writer/reader audio input/output cannot be attached and the failure is silent.
- A fix changes video render order, color, sidecar schema, or highlight behavior
  without explicit owner approval.

Detail Softness:

- `detailSoftness: 0` changes existing output.
- Preview/export parity fails after two focused fix attempts.
- Manufacturer profile logic requires claims that local metadata cannot support.
- Strong values cannot preserve readable text/hair/foliage without new algorithm
  work.
- Auto source compensation changes saved Look identity.

## Copy / History Impact

This handoff document alone has no public copy or implementation-history impact.

Export audio fix:

- Copy / release notes may mention restored or verified audio preservation only
  after final-output validation exists.
- Article Opportunity: release-note only unless the owner wants a short
  technical note.
- Change-History Opportunity: yes, because old Electron used ffmpeg audio copy
  while Native Desktop initially shipped a video-only AVFoundation writer.

Detail Softness implementation:

- Copy labels/help/release notes will be affected.
- Article Opportunity: developer note only after implementation and A/B samples
  exist.
- Change-History Opportunity: yes, because this marks the move from
  lens/periphery softness only to a source-aware detail softness model.

## High-Precision English Handoff Prompt

Use this prompt to start the next chat:

```text
You are working in:

/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

Read AGENTS.md first, then run `git status --short --branch`. Do not begin with
broad discovery. This repository is the source of truth for Filmtone iOS, Native
Desktop, and shared film-lab packages.

Current context:

- Main already includes the iOS feature-architecture refactor:
  `main @ 95f1be03 merge: integrate iOS feature architecture refactor`.
- The old feature worktree/branch is gone. Use current post-refactor paths.
- The key iOS export file is now
  `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  and export helpers live under
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/`.
- Gyroflow is not the current task. Do not route this work into a Gyroflow lane.
- Product quality and core progress are the priority. Keep outer-shell work
  minimal until the product behavior is fixed or proven.
- Use coherent larger bundles. Do not split work into tiny administrative
  sub-stages unless verification or code ownership requires it.

Read these documents in order:

1. `docs/filmtone/2026-05-12-export-audio-detail-softness-handoff.md`
2. `docs/filmtone/2026-05-11-export-audio-investigation.md`
3. `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`

There are two independent issues:

1. Export audio preservation.
2. Detail Softness / Source Detail Compensation.

Do not implement both in one `active.md`. Start with Export Audio unless I
explicitly tell you to start with Detail Softness.

For Export Audio:

- Treat the user-observed symptom as product truth: current exported media from
  both iOS and Native Desktop has no audible audio.
- Native Desktop is currently video-only by construction:
  `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoWriter.swift`
  has no audio writer input, and
  `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoReader.swift`
  has only video reader output.
- iOS intends to preserve audio, but current truth checks are weak:
  `ExportVideoIOBuilder` keeps non-nil audio input/output even if writer/reader
  cannot add them, and `CompletedExport.audioPreserved` is currently based on
  intent rather than completed output inspection.
- Add completed-output audio validation. A fix is not complete until the final
  exported file is proven to contain an audio track when the source has audio and
  `preserveAudio` is true.
- Preserve highlight-reel behavior: `highlightTimeline != nil` currently
  disables source audio unless the owner explicitly changes product behavior.
- Preferred first bundle: create or update a lane under
  `docs/filmtone/export-audio/`, then implement iOS fail-loud audio attachment
  plus completed-output validation. If scope is acceptable, include Native
  Desktop audio writer/reader support in the same product bundle.

For Detail Softness:

- This is a separate image-quality feature, not an audio fix.
- Add user-facing `detailSoftness` with range `0...1`, default `0`, and keep
  `detailSoftness: 0` bit-neutral.
- Do not overload `lensSoftness`; that is lens/periphery softness.
- Target render placement is after base grade/tone compression and before edge
  optics/glow/grain.
- Do not implement as a plain blur. Use a local-reference/high-frequency-detail
  reduction with major-edge protection, stronger luma than chroma attenuation,
  and grain applied afterward.
- Keep automatic Source Detail Compensation separate from saved Look identity.
- Preferred lane placement:
  `docs/filmtone/detail-softness/`.

Verification:

- For iOS native/export changes: `bun run verify:ios` and `git diff --check`.
- For Native Desktop changes: `bun run verify:macos` and `git diff --check`.
- For shared contract changes: `bun run build:core`; for renderer changes:
  `bun run build:renderer`.
- For generated Swift, use `bun run generate:ios-swift` and inspect generated
  diffs unless a check mode exists.
- For user-facing copy, read
  `docs/filmtone/filmtone-copy-quality-harness.md` and run
  `bun run check:filmtone-copy`.
- For release/version/public claims, rerun the life truth scripts before making
  the claim.

Do not push, bump portfolio submodules, or edit portfolio implementation unless
I explicitly ask. Work with any dirty worktree changes; do not revert changes
you did not make.
```
