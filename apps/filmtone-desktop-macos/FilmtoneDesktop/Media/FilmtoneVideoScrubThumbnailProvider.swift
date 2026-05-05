import AppKit
import AVFoundation
import CoreImage
import CoreMedia
import Foundation

// M5-K4 — graded thumbnail provider for the video scrub bar.
//
// Owns one `AVAssetImageGenerator` whose `videoComposition` is built from
// the same `applyingCIFiltersWithHandler` factory as the live preview, but
// with a small render canvas (240px long edge) so per-frame grade cost
// stays well below the live 1280-edge preview cost. Hover requests funnel
// through `requestThumbnail(atSeconds:completion:)`; the provider quantizes
// the timestamp into 0.25s buckets, serves cache hits synchronously on the
// completion callback, and otherwise schedules a single in-flight async
// generation, cancelling any prior pending generation so rapid hover does
// not pile up GPU work.
//
// `updateInputs(_:)` is called by `FilmtoneDesktopVideoSession` whenever
// the live composition is rebuilt (preset / Look / strength / quick /
// overrides / source-profile change). The provider rebuilds its generator
// to honor the new edit and bumps an inputs signature so old cache entries
// drop out automatically.

@MainActor
final class FilmtoneVideoScrubThumbnailProvider {

    /// Long-edge cap for thumbnail rendering. Small enough that the grade
    /// pipeline (halation pyramid + grain) costs a small fraction of one
    /// 30Hz frame budget on integrated GPUs, large enough to stay readable
    /// over the scrub bar.
    static let thumbnailLongEdge: CGFloat = 240

    /// Bounded LRU. Hover-driven traffic is small (one bucket per ~0.25s
    /// of mouse motion); 32 keeps the working set generous without ever
    /// growing unbounded across long sessions.
    static let maxCacheEntries = 32

    private let asset: AVURLAsset
    private let videoTrack: AVAssetTrack
    private let naturalSize: CGSize
    private let preferredTransform: CGAffineTransform
    private let nominalFrameRate: Float
    private let durationSeconds: Double

    private var currentInputs: FilmtoneDesktopVideoRenderInputs
    private var inputsSignature: UInt64 = 0
    private var generator: AVAssetImageGenerator
    private var compositionRenderSize: CGSize

    private var cache: [FilmtoneScrubThumbnailCacheKey: NSImage] = [:]
    private var cacheOrder: [FilmtoneScrubThumbnailCacheKey] = []

    /// Last quantized timestamp passed to `requestThumbnail(...)`. Used to
    /// drop stale completions when hover skips ahead before a slower
    /// generation lands.
    private var latestRequestSeconds: Double?

    /// Cache key currently being generated, if any. Lets us coalesce
    /// repeated requests for the same key (continuous hover inside one
    /// 0.25s bucket) without cancelling and restarting the in-flight
    /// generation. Cleared in the completion path on the main actor.
    private var inFlightKey: FilmtoneScrubThumbnailCacheKey?

    init(
        asset: AVURLAsset,
        videoTrack: AVAssetTrack,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        nominalFrameRate: Float,
        durationSeconds: Double,
        inputs: FilmtoneDesktopVideoRenderInputs
    ) {
        self.asset = asset
        self.videoTrack = videoTrack
        self.naturalSize = naturalSize
        self.preferredTransform = preferredTransform
        self.nominalFrameRate = nominalFrameRate
        self.durationSeconds = durationSeconds
        self.currentInputs = inputs

        let renderSize = FilmtoneDesktopVideoComposition.thumbnailRenderSize(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )
        self.compositionRenderSize = renderSize

        self.generator = Self.makeGenerator(
            asset: asset,
            videoTrack: videoTrack,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            nominalFrameRate: nominalFrameRate,
            inputs: inputs,
            renderSize: renderSize
        )
    }

    /// Drop any in-flight generation. Called on session teardown so the
    /// generator does not keep ticking against a stale source.
    func teardown() {
        generator.cancelAllCGImageGeneration()
        cache.removeAll(keepingCapacity: false)
        cacheOrder.removeAll(keepingCapacity: false)
        latestRequestSeconds = nil
        inFlightKey = nil
    }

    /// Replace the captured render inputs; rebuild the generator so the
    /// next thumbnail reflects the new edit. Bumps the signature so cache
    /// keys from before the change can never collide.
    func updateInputs(_ inputs: FilmtoneDesktopVideoRenderInputs) {
        currentInputs = inputs
        inputsSignature &+= 1
        generator.cancelAllCGImageGeneration()
        cache.removeAll(keepingCapacity: false)
        cacheOrder.removeAll(keepingCapacity: false)
        latestRequestSeconds = nil
        inFlightKey = nil
        let renderSize = FilmtoneDesktopVideoComposition.thumbnailRenderSize(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )
        compositionRenderSize = renderSize
        generator = Self.makeGenerator(
            asset: asset,
            videoTrack: videoTrack,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            nominalFrameRate: nominalFrameRate,
            inputs: inputs,
            renderSize: renderSize
        )
    }

    /// Request a thumbnail for `seconds`. Quantized to 0.25s buckets so
    /// adjacent hover positions hit cache. Completion fires on the main
    /// actor with the rendered `NSImage` and the bucket timestamp the
    /// image actually represents (so the caller can position the
    /// thumbnail at the right scrub-bar offset even when bucketing
    /// rounded the request away from the cursor).
    func requestThumbnail(
        atSeconds seconds: Double,
        completion: @MainActor @escaping (NSImage, Double) -> Void
    ) {
        // Quantize within the asset's duration. A naive clamp-then-quantize
        // still lets bucket rounding overshoot the asset's end (e.g. a
        // 12.38s clip would round 12.38 → 12.50, which AVAssetImage-
        // Generator silently rejects), so use the helper that floors back
        // to the last in-range bucket when the rounded one escapes.
        let quantized = FilmtoneScrubThumbnailMath.quantizeWithinDuration(
            seconds: seconds,
            duration: durationSeconds
        )
        let key = FilmtoneScrubThumbnailCacheKey(
            quantizedSeconds: quantized,
            signature: inputsSignature
        )

        if let cached = cache[key] {
            promoteCacheKey(key)
            latestRequestSeconds = quantized
            completion(cached, quantized)
            return
        }

        latestRequestSeconds = quantized

        // P1 — coalesce same-key requests. Continuous hover inside one
        // 0.25s bucket would otherwise re-cancel and re-start the same
        // generation on every mouse-move, starving the in-flight job.
        // Same key, same in-flight job: nothing to do.
        if inFlightKey == key { return }

        // Different key (or no key in flight): cancel the prior
        // generation, claim the new key, and dispatch.
        if inFlightKey != nil {
            generator.cancelAllCGImageGeneration()
        }
        inFlightKey = key

        let signatureAtRequest = inputsSignature
        let cm = CMTime(seconds: quantized, preferredTimescale: 600)
        let times = [NSValue(time: cm)]

        generator.generateCGImagesAsynchronously(
            forTimes: times
        ) { [weak self] _, image, _, result, _ in
            // Hop to the main actor first so we can clear `inFlightKey`
            // even on cancellation / failure paths.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.inFlightKey == key {
                    self.inFlightKey = nil
                }
                guard result == .succeeded, let image else { return }
                let nsImage = NSImage(
                    cgImage: image,
                    size: NSSize(width: image.width, height: image.height)
                )
                // Drop the result if a new generation wave invalidated it.
                guard self.inputsSignature == signatureAtRequest else { return }
                self.storeCache(key: key, image: nsImage)
                // Only fire completion if this is still the user's target
                // bucket; otherwise the scrub bar would briefly snap back.
                guard self.latestRequestSeconds == quantized else { return }
                completion(nsImage, quantized)
            }
        }
    }

    // MARK: - Cache plumbing

    private func storeCache(key: FilmtoneScrubThumbnailCacheKey, image: NSImage) {
        if cache[key] == nil {
            cacheOrder.append(key)
        } else {
            promoteCacheKey(key)
        }
        cache[key] = image
        while cacheOrder.count > Self.maxCacheEntries {
            let evict = cacheOrder.removeFirst()
            cache.removeValue(forKey: evict)
        }
    }

    private func promoteCacheKey(_ key: FilmtoneScrubThumbnailCacheKey) {
        if let idx = cacheOrder.firstIndex(of: key) {
            cacheOrder.remove(at: idx)
        }
        cacheOrder.append(key)
    }

    // MARK: - Generator factory

    private static func makeGenerator(
        asset: AVURLAsset,
        videoTrack: AVAssetTrack,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        nominalFrameRate: Float,
        inputs: FilmtoneDesktopVideoRenderInputs,
        renderSize: CGSize
    ) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        // Wide tolerance keeps generation fast — for a hover scrub
        // thumbnail nearest-keyframe is fine; the user is going to move
        // again imminently.
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        // Honor the orientation-aware render canvas — without this, the
        // generator returns the asset's source pixel size, which can be
        // megapixel-class on 4K iPhone footage.
        generator.maximumSize = CGSize(
            width: max(1, renderSize.width.rounded()),
            height: max(1, renderSize.height.rounded())
        )
        if let composition = FilmtoneDesktopVideoComposition.makeThumbnailComposition(
            asset: asset,
            videoTrack: videoTrack,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            nominalFrameRate: nominalFrameRate,
            inputs: inputs,
            renderSize: renderSize
        ) {
            generator.videoComposition = composition
        }
        return generator
    }
}
