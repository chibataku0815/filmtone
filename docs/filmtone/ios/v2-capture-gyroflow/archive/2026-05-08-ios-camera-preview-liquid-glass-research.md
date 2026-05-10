# iOS Camera Preview API + Liquid Glass Research

Date: 2026-05-08 JST
Lane: M10 / S8-F
Target: Filmtone iOS native capture surface

## Product Question

Filmtone needs a capture surface that lets the owner judge the image before
recording, not only after editor handoff. The open questions are:

- Can live capture preview show the current Look / adjustment direction without
  weakening the master recording path?
- Which Apple camera APIs should drive that preview?
- How should the capture controls use Liquid Glass so the UI feels native,
  beautiful, and legible over live video?

## Sources Checked

Apple docs and local SDK were both used. Local SDK truth matters because this
app builds against iPhoneOS 26.4.

- Apple Developer: [AVCaptureVideoDataOutput](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput)
- Apple Developer: [AVCaptureVideoPreviewLayer](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer)
- Apple Developer: [Recording movies in alternative formats](https://developer.apple.com/documentation/avfoundation/recording-movies-in-alternative-formats)
- Apple Developer: [AVCaptureColorSpace](https://developer.apple.com/documentation/avfoundation/avcapturecolorspace)
- Apple Developer: [preferredVideoStabilizationMode](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/preferredvideostabilizationmode)
- Apple Developer: [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- Apple Developer: [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- WWDC25: [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)
- WWDC25: [Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- WWDC25: [Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/)
- Local SDK:
  `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.4.sdk`

## Current Filmtone State

S8-D currently uses:

- raw `AVCaptureVideoPreviewLayer` for the live camera image
- a small Look reference thumbnail from the editor's already-rendered poster
- explicit "Live ungraded" disclosure

The worktree also has an uncommitted S8-F F1 start:

- `FilmtoneCaptureSession` attaches a preview-only
  `AVCaptureVideoDataOutput`
- pixel format = `kCVPixelFormatType_32BGRA`
- delegate currently discards frames
- master path remains `AVCaptureMovieFileOutput`

That is the right direction, but it needs a documented contract before F2/F3.

## API Findings

### 1. `AVCaptureVideoPreviewLayer` Is Fast, But Not Filterable

`AVCaptureVideoPreviewLayer` is the right raw camera pass-through preview. It
connects directly to an `AVCaptureSession` and is cheap. It is not a frame
processing API. If Filmtone needs per-frame Look application, the processed path
must be `AVCaptureVideoDataOutput` or a downstream rendering layer.

Decision:

- Keep `AVCaptureVideoPreviewLayer` as fallback / emergency raw preview.
- Live Look preview must come from VDO frames, not from trying to filter the
  preview layer.

### 2. `AVCaptureMovieFileOutput` Remains The Master Writer

Apple's movie-file path allows setting `AVVideoCodecKey` when the requested
codec appears in `availableVideoCodecTypes`. Filmtone already gates ProRes 422
HQ (`apch`) by setting output settings and verifying the finished file via
`AVURLAsset`.

Decision:

- Do not replace MovieFileOutput for M10.
- Do not make VDO an alternate writer.
- S8-F can add VDO only as a preview output.

### 3. VDO Is The Correct Preview Processing API

`AVCaptureVideoDataOutput` gives sample buffers to a delegate queue. SDK notes
that:

- `alwaysDiscardsLateVideoFrames` should be used so slow processing drops old
  frames instead of building memory pressure.
- On iOS 16+, width and height keys are supported in `videoSettings`, but they
  must match orientation and source aspect ratio constraints.
- `deliversPreviewSizedOutputBuffers` tells AVFoundation the output is for
  on-screen preview, not recording.
- If setting `deliversPreviewSizedOutputBuffers` manually, set
  `automaticallyConfiguresOutputBufferDimensions = false` first.

Decision:

- Preview VDO should be `alwaysDiscardsLateVideoFrames = true`.
- Prefer preview-sized buffers for M10; do not process 4K frames for UI.
- Use BGRA for simplest Core Image / Metal path. This is 8-bit preview, not
  master truth.
- The master still records ProRes 422 HQ / Apple Log 2 through MovieFileOutput.

Implementation contract:

```swift
let vdo = AVCaptureVideoDataOutput()
vdo.videoSettings = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
]
vdo.alwaysDiscardsLateVideoFrames = true
if #available(iOS 13.0, *) {
    vdo.automaticallyConfiguresOutputBufferDimensions = false
    vdo.deliversPreviewSizedOutputBuffers = true
}
```

If this combination throws or `canAddOutput` fails on device, stop S8-F and keep
the reference thumbnail path.

### 4. Apple Log 2 Has Capture-Surface Implications

Local SDK confirms:

- `AVCaptureColorSpace.appleLog2` is raw value 4 and iOS 26+.
- Setting Apple Log / Apple Log 2 on an `AVCaptureDevice` makes photo outputs
  inactive.
- Changing `activeColorSpace` while the session is running is disruptive:
  movie captures end, photo requests abort, and preview freezes.
- To prevent session auto wide-color behavior from undoing manual color space,
  set `session.automaticallyConfiguresCaptureDeviceForWideColor = false`.

Decision:

- S8-F must not change `activeColorSpace` after session start.
- Do not add `AVCapturePhotoOutput` for preview stills in this lane.
- Live Look preview cannot be allowed to reconfigure Apple Log 2 while
  recording.

### 5. Stabilization Must Stay Exact On Master

Local SDK confirms:

- `cinematicExtendedEnhanced` exists on iOS 18+.
- `lowLatency` exists on iOS 26+.
- `previewOptimized` is supported only on preview-layer connections or
  preview-sized VDO connections.
- Stabilization modes may add latency, memory pressure, and format limits.

M6 already proved on iPhone 17 Pro / iOS 26.4.2:

- `cinematicExtendedEnhanced` works on the locked format.
- `previewOptimized` and `lowLatency` are not supported on formatIndex 56.
- Master `.mov` FourCC stays `apch`.

Decision:

- Master MovieFileOutput connection remains exact
  `cinematicExtendedEnhanced`.
- Preview VDO should not weaken master stabilization.
- If preview VDO exposes its own connection, record its supported and active
  stabilization in diagnostics, but do not let it redefine the master gate.

### 6. External SSD Has An Apple-Native API

The local SDK includes `AVExternalStorageDevice` and
`AVExternalStorageDeviceDiscoverySession`:

- devices represent physical external storage devices
- devices expose display name, free size, total size, connection state, UUID,
  and `isNotRecommendedForCaptureUse`
- `nextAvailableURLsWithPathExtensions` returns security-scoped DCF-compliant
  URLs
- authorization is explicit via `requestAccessWithCompletionHandler`

Current M10 uses a Files folder picker plus DualLogCamera-style preflight. That
is acceptable for the current product loop, but the Apple-native SSD API is the
right follow-up path for a polished camera app.

Decision:

- Do not switch storage implementation inside S8-F.
- Record follow-up: M11/M12 should evaluate `AVExternalStorageDevice` so SSD UI
  can show physical device identity and Apple capture suitability flags.

## Liquid Glass Findings

### 1. SwiftUI Has Native Glass APIs On iOS 26

Local SDK confirms:

- `View.glassEffect(_:in:)` is available on iOS 26+.
- `GlassEffectContainer` combines multiple glass shapes for performance and
  morphing behavior.
- `glassEffectID` supports matched glass identity transitions.

Apple docs describe Liquid Glass as a material that blurs, reflects surrounding
content, reacts to interaction, and can morph. Standard SwiftUI controls pick
up the system design automatically; custom components use the glass APIs.

Decision:

- Capture surface controls should use SwiftUI `glassEffect` where possible.
- Group neighboring pills/buttons in `GlassEffectContainer`.
- Use `glassEffectID` for record state / capture re-entry morphs only when it
  does not complicate the surface.

### 2. UIKit Has `UIGlassEffect`

Local SDK confirms:

- `UIGlassEffect(style: .regular | .clear)` is available on iOS 26+.
- `UIGlassEffect.interactive` and `tintColor` exist.
- `UIGlassContainerEffect.spacing` combines multiple glass elements.

Decision:

- SwiftUI is preferred because `FilmtoneCaptureView` is SwiftUI.
- UIKit glass is only needed inside UIKit wrappers (`UIViewRepresentable`) if a
  custom `MTKView` / `UIView` overlay needs a native effect.

### 3. Design Principles For Capture Preview

WWDC25 guidance matters directly for camera UI:

- Liquid Glass should be a navigation/control layer floating above content.
- Do not put glass into the content layer itself.
- Avoid glass-on-glass.
- Use Regular for most controls; Clear is only for media-rich content with a
  dimming layer and strong foreground content.
- Tint only primary actions; tinting every control destroys hierarchy.
- Controls should stay legible as the live image changes behind them.

Decision:

- Full-bleed camera image is content.
- Control decks, lens selector, storage pill, and record button are floating
  glass.
- Use Regular glass for the parameter deck and lens pills.
- Consider Clear glass only for the record control cluster if a localized
  dimming layer makes text/icons reliably legible.
- Do not stack cards inside cards.

## Recommended M10 Capture UI Direction

### Layout

Use a three-zone camera UI:

1. **Top layer**: close, storage status, SSD selector, Look state.
2. **Live image**: full-bleed processed preview when S8-F succeeds; raw preview
   fallback when it fails.
3. **Bottom glass deck**: lens selector, fixed capture contract, record/stop.

Avoid a settings screen. The camera should be operable from the preview.

### Liquid Glass Use

- Wrap the top and bottom floating controls in `GlassEffectContainer`.
- Use capsule/rounded-rect glass shapes matching the control shape.
- Use monochrome icons by default.
- Red tint only for the primary record/stop action.
- Keep tap targets large enough for thumbs.
- Keep text tight: `4K24`, `Log 2`, `ProRes HQ`, `Cinematic EE`, `Internal 10s`,
  `External 60s`.

### Preview Look Application

Preferred pipeline:

```text
AVCaptureMovieFileOutput
  -> ProRes 422 HQ / Apple Log 2 / 4K24 master

AVCaptureVideoDataOutput
  -> preview-sized BGRA sample buffer
  -> CIImage
  -> Filmtone Look / adjustment preview transform
  -> CIContext + Metal-backed view
  -> SwiftUI capture surface
```

Fallback pipeline:

```text
AVCaptureVideoPreviewLayer raw preview
  + Look reference thumbnail strip
```

Do not silently choose fallback. If live Look preview is unavailable, show the
reference strip and keep the capture UI explicit.

## S8-F Revised Implementation Plan

F0 — Research gate (this document)

- [x] Confirm Apple / SDK API surface.
- [x] Confirm Liquid Glass UI APIs.
- [x] Define implementation stop conditions.

F1 — Preview-only VDO coexistence

- Add VDO with BGRA, preview-sized buffers, and late-frame discard.
- No-op delegate is enough for F1.
- Device gate: session starts, records, finalizes, and master file still passes
  `apch`, Apple Log 2, 4K24, and exact stabilization.

F2 — Processed live preview surface

- Introduce a small renderer object:
  `FilmtoneCaptureLookPreviewRenderer`.
- Convert `CMSampleBuffer` to `CIImage`.
- Render into a Metal-backed `UIViewRepresentable` or `MTKView`.
- Keep `AVCaptureVideoPreviewLayer` as fallback until F2 passes.

F3 — Look / adjustment transform

- Reuse the editor grade graph if it can accept `CIImage`.
- If the current editor graph is file/poster-oriented, create a capture-preview
  transform that maps the same Look / adjustment values to Core Image filters.
- Document any effect class not applied live.

F4 — Liquid Glass camera UI pass

- Apply `glassEffect` / `GlassEffectContainer` to top and bottom control groups.
- Keep the live image as content, not glass.
- Remove old opaque black pills where glass gives sufficient contrast.
- Keep record / stop as the only strongly tinted control.

F5 — Owner device acceptance

- No-SSD 10s + live Look preview + editor handoff.
- SSD 10-60s + live Look preview + external master + local proxy.
- Verify master gates after capture.
- If live preview fails but master remains healthy, stop and decide whether
  fallback is acceptable for this milestone.

## Stop Conditions

- Adding VDO changes master codec, color space, stabilization, frame rate, or
  file validity.
- VDO cannot coexist with MovieFileOutput on owner device.
- VDO sample delivery introduces visible capture stutter or high thermal /
  pressure issues.
- Core Image / Metal renderer cannot maintain a responsive live preview at
  preview-sized buffers.
- Liquid Glass controls become illegible over real camera content.
- Implementing live Look preview requires replacing the export renderer or
  changing master recording.

## Future Follow-ups

- Replace Files-folder SSD picker with `AVExternalStorageDevice` discovery and
  Apple-native URL allocation.
- Add manual exposure / focus / white balance only after live preview and SSD
  capture are stable.
- Consider EDR/HDR preview only after the SDR preview path is fast and honest.
- Add measured preview latency diagnostics once S8-F is working.

