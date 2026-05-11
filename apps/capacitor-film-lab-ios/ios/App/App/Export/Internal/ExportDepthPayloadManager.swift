import AVFoundation
import FilmLabSwiftCore
import Foundation

/// Owner of the video-depth track probe and the per-frame depth pull
/// sync-bridge used by `FilmtoneExportSession`. Extracted from the
/// `FilmtoneExportSession` god object so the per-frame depth contract can
/// be reasoned about in isolation. The members are `static` because no
/// instance state is needed — `request.depthEnabled` is lifted to a
/// parameter, and the `FilmtonePhase0Generated.hiddenDefaults` fast-path
/// reads a module-level constant.
enum ExportDepthPayloadManager {
    /// Tri-state result of `pullNextFrame` so callers can distinguish
    /// "stream ended" from "transient failure". The case names match the
    /// pre-extraction nested enum so `FilmtoneExportSession`'s frame loop
    /// `switch` body is unchanged.
    enum PullResult {
        case frame((presentationTime: CMTime, depthMap: FilmtoneDepthMap))
        case endOfStream
        case failure(Error)
    }

    /// Probes the asset for a depth track and opens a
    /// `VideoDepthFrameReader`. Returns nil when depth is disabled by
    /// request or when every depth gain in the active profile is zero
    /// (defense-in-depth fast-path mirroring
    /// `FilmtoneDepthPrefilter.apply`'s `depthGain <= 0 && rayAngleGain <= 0`
    /// short-circuit). Throws `FilmtoneMediaError.depthUnsupportedForVideoSource`
    /// when depth WAS requested but the asset has no depth track, and
    /// propagates `depthUnsupportedFormat` from `VideoDepthSourceService`
    /// when a track exists but the reader can't be wired.
    static func resolveReader(
        asset: AVAsset,
        depthEnabled: Bool
    ) throws -> VideoDepthFrameReader? {
        guard depthEnabled else {
            return nil
        }
        let hidden = FilmtonePhase0Generated.hiddenDefaults
        if hidden.depthMistGain == 0 && hidden.depthGlowGain == 0 {
            NSLog("FilmtoneExportSession: video depth track decode skipped (all profile depth gains zero)")
            return nil
        }
        let service = VideoDepthSourceService()
        let semaphore = DispatchSemaphore(value: 0)
        var hasTrack = false
        var probeError: Error?
        Task.detached(priority: .userInitiated) {
            defer { semaphore.signal() }
            hasTrack = await service.hasDepthTrack(in: asset)
        }
        semaphore.wait()
        guard hasTrack else {
            throw FilmtoneMediaError.depthUnsupportedForVideoSource
        }
        var reader: VideoDepthFrameReader?
        let openSemaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            defer { openSemaphore.signal() }
            do {
                reader = try await service.makeReader(for: asset)
            } catch {
                probeError = error
            }
        }
        openSemaphore.wait()
        if let probeError {
            throw probeError
        }
        return reader
    }

    /// Sync-bridges `VideoDepthFrameReader.nextFrame` for the per-frame
    /// loop on `FilmtoneExportSession.videoQueue`. The result is a
    /// tri-state instead of `throws` because callers want to distinguish
    /// "stream ended" from "transient failure" so they can apply the
    /// per-source recovery contract from Phase A.
    static func pullNextFrame(reader: VideoDepthFrameReader) -> PullResult {
        let semaphore = DispatchSemaphore(value: 0)
        var pulled: (presentationTime: CMTime, depthMap: FilmtoneDepthMap)?
        var pullError: Error?
        Task.detached(priority: .userInitiated) {
            defer { semaphore.signal() }
            do {
                pulled = try await reader.nextFrame()
            } catch {
                pullError = error
            }
        }
        semaphore.wait()
        if let pullError {
            return .failure(pullError)
        }
        guard let pulled else {
            return .endOfStream
        }
        return .frame(pulled)
    }
}
