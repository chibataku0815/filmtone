// Filmtone V2 native camera capture — proxy generator (M10).
//
// Generates a lightweight local proxy from the recorded master.  Editor
// previews / probes / preset application all run against the proxy so
// the master can stay external (security-scoped SSD) without the app
// dragging large ProRes files into iPhone storage on every preview
// refresh.
//
// Preset is `AVAssetExportPreset1920x1080` H.264 — Apple Log 2 metadata
// is dropped on tone-mapped Rec.709 by AVAssetExportSession; that's
// acceptable for the proxy because the editor's existing pipeline
// expects Rec.709-shaped sources from Photos / Files routes.

import Foundation

#if os(iOS)

import AVFoundation

enum FilmtoneProxyGenerator {

    enum Outcome {
        case success
        case failure(reason: String)
    }

    /// Export `masterURL` into `proxyURL` as a 1080p H.264 .mov.  Caller
    /// must hold any security-scoped resource access on the master path.
    static func export(masterURL: URL, proxyURL: URL) async -> Outcome {
        try? FileManager.default.removeItem(at: proxyURL)

        let asset = AVURLAsset(url: masterURL)

        let presets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        let chosenPreset: String
        if presets.contains(AVAssetExportPreset1920x1080) {
            chosenPreset = AVAssetExportPreset1920x1080
        } else if presets.contains(AVAssetExportPreset1280x720) {
            chosenPreset = AVAssetExportPreset1280x720
        } else if let first = presets.first {
            chosenPreset = first
        } else {
            return .failure(reason: "no compatible AVAssetExportSession preset for master")
        }

        guard let session = AVAssetExportSession(asset: asset, presetName: chosenPreset) else {
            return .failure(reason: "AVAssetExportSession init returned nil for preset \(chosenPreset)")
        }
        session.outputURL = proxyURL
        session.outputFileType = .mov
        session.shouldOptimizeForNetworkUse = false

        return await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    continuation.resume(returning: .success)
                case .failed:
                    let msg = session.error?.localizedDescription ?? "unknown export error"
                    continuation.resume(returning: .failure(reason: msg))
                case .cancelled:
                    continuation.resume(returning: .failure(reason: "export cancelled"))
                default:
                    continuation.resume(returning: .failure(reason: "unexpected export status \(session.status.rawValue)"))
                }
            }
        }
    }
}

#endif
