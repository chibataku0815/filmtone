// Filmtone V2 native camera capture — live preview surface (M10 / S8-F).
//
// S8-F F2: render the preview-only `AVCaptureVideoDataOutput` BGRA
// stream into a SwiftUI `MTKView` via Core Image so the capture
// surface can drive a real-time preview from the same session that the
// `AVCaptureMovieFileOutput` master is recording to.  No grade is
// applied here — F2 only proves the path.  F3 will inject the editor's
// Look / 調整 chain between `sink.latest` and the `CIContext.render`
// call.
//
// Master invariants are preserved by the session-level gates
// (`apch` ProRes 422 HQ FourCC + Apple Log 2 colorSpace +
// `cinematicExtendedEnhanced` stabilization), all verified at
// finalize time inside `FilmtoneCaptureSession.handleMovieFinished`.
// VDO is preview-only; if `canAddOutput` rejected the VDO at
// `prepare(lens:)` time the capture view falls back to the raw
// `AVCaptureVideoPreviewLayer` and this file is unused for that
// session.

import SwiftUI

#if os(iOS)

import AVFoundation
import CoreImage
import Metal
import MetalKit
import UIKit

/// S8-F F3-R: snapshot of the inputs the editor's grade chain is
/// about to apply to live VDO frames.  Built once when the capture
/// surface is presented (`FilmtoneEditorStore.makeLivePreviewGradeProcessor`)
/// and rendered as a top-left diagnostic overlay so we can compare
/// what the live preview is actually doing against what the editor
/// preview applies on the same source.  Two known parity gaps the
/// struct surfaces explicitly:
/// 1. `cameraProfilePassedToProcessor == false` — the runtime entry
///    point doesn't accept `cameraProfile`, so any user-picked
///    built-in source profile (Apple Log 2, V-Log, etc.) is
///    silently downgraded to `.auto` for the live preview only.
/// 2. `savedLookPassedToProcessor == false` — the runtime entry
///    point doesn't accept `appliedSavedLook`, so any applied
///    Saved Look (camera profile + adjustments bundle) is dropped
///    from the live preview.
struct FilmtoneLivePreviewDiagnostics: Equatable {
    let lookLabel: String
    let creativeLutPresent: Bool
    let creativeLutSize: Int?
    let creativeLutIntensity: Double?
    let creativeLutBundledSlug: String?
    let cameraProfileLabel: String
    let cameraProfilePassedToProcessor: Bool
    let savedLookId: String?
    let savedLookPassedToProcessor: Bool
    let detectedInputTransform: String?
    let inputLutWillApply: Bool
    let presetVersion: String
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let temperature: Double
}

/// S8-F F3-R: pair the live grade processor with its diagnostic
/// snapshot so the capture surface can both apply the chain and
/// surface what was actually wired.  The processor and diagnostics
/// are intentionally captured at the same moment — both reflect the
/// editor state as of `fullScreenCover` present time.
struct FilmtoneLivePreviewBundle {
    let processor: FilmtoneSharedGradeProcessor
    let diagnostics: FilmtoneLivePreviewDiagnostics
}

/// Single-slot, lock-protected sink shared between the capture
/// session's VDO sample-buffer delegate (writer, on
/// `previewSampleQueue`) and the SwiftUI `MTKView` renderer (reader,
/// on the main display tick).  At 24 fps the contention is negligible
/// and a plain `NSLock` keeps the data path obvious.
///
/// The renderer attaches a callback via `setOnFrameCallback` so each
/// camera sample triggers exactly one redraw, instead of letting
/// `MTKView` run a 24fps `CADisplayLink` that drifts against the
/// camera's own 24fps cadence.  Phase-locked rendering eliminates
/// the periodic judder where one camera frame is shown for two
/// display ticks while the next is dropped.
final class FilmtonePreviewFrameSink: @unchecked Sendable {

    private let lock = NSLock()
    private var stored: CIImage?
    private var onFrame: (@Sendable () -> Void)?

    /// Latest CIImage pushed by the VDO delegate, or nil when no frame
    /// has arrived yet (or after `clear()` post-teardown).
    var latest: CIImage? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    /// Register a callback that will be dispatched on the main queue
    /// each time a new frame is pushed.  The renderer view uses this
    /// to drive `setNeedsDisplay()`.  Pass `nil` to detach.
    func setOnFrameCallback(_ callback: (@Sendable () -> Void)?) {
        lock.lock()
        onFrame = callback
        lock.unlock()
    }

    /// Writer entry point.  Called from `previewSampleQueue` at ~24 fps.
    func push(_ image: CIImage) {
        lock.lock()
        stored = image
        let callback = onFrame
        lock.unlock()
        guard let callback else { return }
        DispatchQueue.main.async {
            callback()
        }
    }

    /// Drop the cached frame so a fresh prepare(lens:) starts on a
    /// blank slate rather than briefly showing a stale frame from the
    /// previous lens / session.
    func clear() {
        lock.lock()
        stored = nil
        lock.unlock()
    }
}

/// SwiftUI wrapper around an `MTKView`-backed Core Image renderer.
/// Pulls the latest frame from `FilmtonePreviewFrameSink` on each VDO
/// sample arrival (event-driven `draw()`), optionally applies the
/// editor's grade chain via `FilmtoneSharedGradeProcessor`, and
/// aspect-fills the result into the view bounds.  When the sink has
/// no frame yet, `draw(in:)` exits without committing a buffer and the
/// view shows the clear color (black, matching the surrounding capture
/// chrome).
struct FilmtoneCaptureLivePreview: UIViewRepresentable {

    let sink: FilmtonePreviewFrameSink
    /// S8-F F3: optional grade processor pinned to the editor's
    /// current request.  When non-nil the renderer applies the
    /// chain to every VDO frame before render.  When nil the
    /// preview is the F2 ungraded pass-through.
    let gradeProcessor: FilmtoneSharedGradeProcessor?
    /// S6: preview compensation from `AVCaptureDevice.RotationCoordinator`.
    /// The session deliberately leaves the VDO connection unrotated; this
    /// renderer applies the preview transform so grading keeps using raw
    /// camera buffers without paying the capture-output rotation cost.
    let previewRotation: FilmtoneCaptureVideoRotation

    func makeUIView(context: Context) -> RendererView {
        let view = RendererView()
        view.attach(
            sink: sink,
            gradeProcessor: gradeProcessor,
            previewRotation: previewRotation
        )
        return view
    }

    func updateUIView(_ uiView: RendererView, context: Context) {
        uiView.attach(
            sink: sink,
            gradeProcessor: gradeProcessor,
            previewRotation: previewRotation
        )
    }

    final class RendererView: MTKView, MTKViewDelegate {

        private weak var attachedSink: FilmtonePreviewFrameSink?
        /// Strong reference: the processor (and the export session it
        /// wraps) outlive the capture view by design — the editor
        /// builds it once at fullScreenCover present time and the
        /// view holds onto it for the duration of the capture session.
        private var gradeProcessor: FilmtoneSharedGradeProcessor?

        /// Fallback context used when no grade processor is attached
        /// (F2 ungraded pass-through).  When grading is enabled we
        /// switch to `gradeProcessor.ciContext` so the live preview
        /// renders through the same CIContext that compiled the grade
        /// chain — keeping the live preview byte-parity-compatible
        /// with the master export the editor will run on adopt.
        private var fallbackCIContext: CIContext?
        private var commandQueue: MTLCommandQueue?
        private var previewRotation: FilmtoneCaptureVideoRotation = .portraitPinned
        private let renderColorSpace = CGColorSpaceCreateDeviceRGB()
        /// S8-F F3-R: log the first VDO frame's CIImage color space tag
        /// once so we can compare against the editor's `sourceImageOptions`
        /// which tags the source CIImage with the probed transfer function
        /// (Apple Log 2 → Rec.709 etc.).  Untagged BGRA frames mean the
        /// grade chain is being fed bytes Core Image interprets as plain
        /// sRGB, which is the wrong upstream prerequisite for `applyGrade`.
        private var hasLoggedFirstFrameDiagnostics = false

        init() {
            let device = MTLCreateSystemDefaultDevice()
            super.init(frame: .zero, device: device)
            if let device {
                self.fallbackCIContext = CIContext(
                    mtlDevice: device,
                    options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()]
                )
                self.commandQueue = device.makeCommandQueue()
            }
            framebufferOnly = false
            colorPixelFormat = .bgra8Unorm
            // Event-driven rendering: the sink calls `setNeedsDisplay`
            // on each camera sample (dispatched to main).  This phase-
            // locks the renderer to the camera output instead of
            // letting MTKView run a free CADisplayLink at 24fps that
            // drifts against the 24fps capture cadence.  The drift
            // shows up on device as periodic judder where the same
            // frame is held for two display ticks while the next is
            // dropped.
            isPaused = true
            enableSetNeedsDisplay = true
            autoResizeDrawable = true
            isOpaque = true
            backgroundColor = .black
            delegate = self
            accessibilityIdentifier = "filmtone.capture.preview.live"
        }

        @available(*, unavailable)
        required init(coder: NSCoder) {
            fatalError("FilmtoneCaptureLivePreview.RendererView is code-only")
        }

        /// Idempotent: rebinds the sink on every SwiftUI update without
        /// leaking stale callbacks to a previous sink instance.  Also
        /// rebinds the grade processor — SwiftUI may call
        /// `updateUIView` during a parent body recompute, so a fresh
        /// processor reference must replace any prior one.
        func attach(
            sink: FilmtonePreviewFrameSink,
            gradeProcessor: FilmtoneSharedGradeProcessor?,
            previewRotation: FilmtoneCaptureVideoRotation
        ) {
            attachedSink = sink
            self.gradeProcessor = gradeProcessor
            self.previewRotation = previewRotation
            sink.setOnFrameCallback { [weak self] in
                // Drive `draw()` directly instead of `setNeedsDisplay()`
                // so the render-and-present commit fires immediately on
                // the same main-thread tick that received the camera
                // sample, rather than waiting for the next CADisplayLink
                // callback.  At 24 fps source on a 120 Hz display the
                // 8–16 ms scheduling jitter from the CADisplayLink
                // path was visible as residual judder even after the
                // free-running 24 fps timer was removed.
                self?.draw()
            }
            // Repaint immediately if a frame is already cached so the
            // surface doesn't flash black on first attach.
            draw()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // No-op: the renderer recomputes its scale + translation
            // each draw() from the live drawable size.
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let rawImage = attachedSink?.latest
            else {
                return
            }

            // F3: when a grade processor is attached, route the render
            // through its CIContext (configured with linear sRGB
            // working space + bt709 output) so the live preview matches
            // the editor's grade output.  Falling back to the local
            // device-RGB context only when no grade is being applied
            // keeps the F2 ungraded path bit-identical to before.
            let processor = gradeProcessor
            let ciContext = processor?.ciContext ?? fallbackCIContext
            guard let ciContext else {
                return
            }

            // F3-R: one-shot first-frame log so we can read the CIImage
            // color space Core Image inferred from the untagged BGRA
            // pixel buffer.  Compare against the editor's source path
            // (`FilmtoneExportSession.sourceVideoImage` calls
            // `colorPipeline.sourceImageOptions(for:)` which sets the
            // proper transfer-function tag on the CIImage).
            if !hasLoggedFirstFrameDiagnostics {
                hasLoggedFirstFrameDiagnostics = true
                let csName: String
                if let cf = rawImage.colorSpace?.name {
                    csName = cf as String
                } else {
                    csName = "(untagged)"
                }
                let extent = rawImage.extent
                NSLog(
                    "[F3R][LivePreview] first frame: extent=%.0fx%.0f input.colorSpace=%@ gradeProcessor=%@",
                    extent.width, extent.height, csName, processor == nil ? "nil" : "attached"
                )
            }

            let orientedRawImage = orient(rawImage, rotation: previewRotation)
            let graded = processor?.applyForLivePreview(orientedRawImage) ?? orientedRawImage

            let drawableSize = view.drawableSize
            let extent = graded.extent
            guard extent.width > 0, extent.height > 0,
                  drawableSize.width > 0, drawableSize.height > 0
            else {
                return
            }

            // Aspect-fill: scale the longer source axis to cover the
            // drawable, then center the result so the overflow is
            // cropped symmetrically.  Mirrors the layer-based fallback
            // (`AVCaptureVideoPreviewLayer.videoGravity =
            // .resizeAspectFill`).
            let scale = max(
                drawableSize.width / extent.width,
                drawableSize.height / extent.height
            )
            let scaled = graded.transformed(
                by: CGAffineTransform(scaleX: scale, y: scale)
            )
            let scaledExtent = scaled.extent
            let translateX =
                (drawableSize.width - scaledExtent.width) / 2 - scaledExtent.origin.x
            let translateY =
                (drawableSize.height - scaledExtent.height) / 2 - scaledExtent.origin.y
            let positioned = scaled.transformed(
                by: CGAffineTransform(translationX: translateX, y: translateY)
            )

            ciContext.render(
                positioned,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                bounds: CGRect(origin: .zero, size: drawableSize),
                colorSpace: renderColorSpace
            )
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        private func orient(
            _ image: CIImage,
            rotation: FilmtoneCaptureVideoRotation
        ) -> CIImage {
            let radians = CGFloat(rotation.degrees * .pi / 180)
            let rotated = image.transformed(
                by: CGAffineTransform(rotationAngle: radians)
            )
            let extent = rotated.extent
            guard extent.origin != .zero else { return rotated }
            return rotated.transformed(
                by: CGAffineTransform(
                    translationX: -extent.origin.x,
                    y: -extent.origin.y
                )
            )
        }
    }
}

#endif
