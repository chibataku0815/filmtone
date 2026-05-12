import AppKit
import Foundation
import SwiftUI

// Headless export entry: when launched with `--export-still` or
// `--export-video`, the app runs the Phase 1b / 1c export pipeline once and
// exits without showing UI. Used by `scripts/golden-parity-macos.ts` (still)
// and the Phase 1c video smoke harness.
//
// Usage:
//   FilmtoneDesktop --export-still \
//     --input <path/to/source.png> \
//     --output <path/to/output.png> \
//     [--preset <generated preset id>] \
//     [--look filmtone-creative-pack-01-stone|filmtone-creative-pack-01-urban] \
//     [--strength 0.0..1.0] \
//     [--format png|jpeg] [--no-sidecar]
//
//   FilmtoneDesktop --export-video \
//     --input <path/to/source.mov> \
//     --output <path/to/output.mp4> \
//     [--preset ...] [--look ...] [--strength 0.0..1.0] [--no-sidecar]
//
// `--preset` and `--look` may both be present. When they are, --look wins
// (basePreset is forced to `reset` so the cube + paramOverrides are the
// SSOT) and a warning is written to stderr. Unknown --look slugs exit with
// status 64 (usage error) before any rendering starts.

@main
struct FilmtoneDesktopApp: App {
    init() {
        FilmtoneDesktopCLI.runIfRequested()
    }

    var body: some Scene {
        WindowGroup("Filmtone") {
            RootWindowView()
        }
        // M5-H.1: pin a sensible first-launch size so the right rail
        // never lands clipped on the trailing edge, but stay below the
        // typical 14"/16" laptop screen so the window doesn't dominate.
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentMinSize)
        // macOS 26 unified Apple Liquid Glass toolbar/chrome requires
        // explicit opt-in; .automatic falls back to a flat opaque bar.
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands()
        }
    }
}

enum FilmtoneDesktopCLI {
    static func runIfRequested() {
        let args = CommandLine.arguments
        if args.contains("--export-still") {
            runStillExport(args: args)
        } else if args.contains("--export-video") {
            runVideoExport(args: args)
        }
    }

    // MARK: still

    private static func runStillExport(args: [String]) {
        do {
            let request = try parseStillExportArgs(args)
            let writeSidecar = !args.contains("--no-sidecar")
            let result = try FilmtoneStillExporter.export(request, writeSidecar: writeSidecar)
            FileHandle.standardOutput.write(
                Data("ok \(result.pixelWidth)x\(result.pixelHeight) \(result.outputURL.path)\n".utf8)
            )
            exit(0)
        } catch {
            FileHandle.standardError.write(
                Data("filmtone-desktop --export-still: \(error)\n".utf8)
            )
            exit(1)
        }
    }

    private static func parseStillExportArgs(_ args: [String]) throws -> FilmtoneStillExportRequest {
        let inputPath = try value(for: "--input", in: args)
        let outputPath = try value(for: "--output", in: args)
        let rawPreset = (try? value(for: "--preset", in: args)) ?? FilmtonePresetCatalog.defaultName
        let lookSlug = try parseLook(args: args)
        let strength = parseStrength(args)
        let formatString = (try? value(for: "--format", in: args)) ?? "png"
        let format = StillExportFormat(rawValue: formatString) ?? .png
        let preset = lookSlug == nil ? rawPreset : FilmtonePresetCatalog.defaultName

        return FilmtoneStillExportRequest(
            sourceURL: URL(fileURLWithPath: inputPath),
            outputURL: URL(fileURLWithPath: outputPath),
            presetName: preset,
            presetStrength: strength,
            lookSlug: lookSlug,
            format: format
        )
    }

    // MARK: video

    private static func runVideoExport(args: [String]) {
        do {
            let request = try parseVideoExportArgs(args)
            let writeSidecar = !args.contains("--no-sidecar")
            let result = try syncRunVideoExport(request: request, writeSidecar: writeSidecar)
            FileHandle.standardOutput.write(
                Data("ok \(result.outputWidth)x\(result.outputHeight) frames=\(result.processedFrames) \(result.outputURL.path)\n".utf8)
            )
            exit(0)
        } catch {
            FileHandle.standardError.write(
                Data("filmtone-desktop --export-video: \(error)\n".utf8)
            )
            exit(1)
        }
    }

    private static func parseVideoExportArgs(_ args: [String]) throws -> FilmtoneVideoExportRequest {
        let inputPath = try value(for: "--input", in: args)
        let outputPath = try value(for: "--output", in: args)
        let rawPreset = (try? value(for: "--preset", in: args)) ?? FilmtonePresetCatalog.defaultName
        let lookSlug = try parseLook(args: args)
        let strength = parseStrength(args)
        let preset = lookSlug == nil ? rawPreset : FilmtonePresetCatalog.defaultName

        return FilmtoneVideoExportRequest(
            sourceURL: URL(fileURLWithPath: inputPath),
            outputURL: URL(fileURLWithPath: outputPath),
            presetName: preset,
            presetStrength: strength,
            lookSlug: lookSlug,
            codec: .h264
        )
    }

    /// Parses `--look <slug>`, validates against the bundled catalog, and
    /// emits a stderr warning when both `--preset` and `--look` are set
    /// (look wins). Unknown slugs throw exit-code 64 (usage error)
    /// before any IO so a CI script gets a clear signal.
    private static func parseLook(args: [String]) throws -> String? {
        guard let raw = try? value(for: "--look", in: args), !raw.isEmpty else {
            return nil
        }
        guard FilmtoneCreativePackCatalog.find(slug: raw) != nil else {
            throw NSError(
                domain: "FilmtoneDesktopCLI",
                code: 64,
                userInfo: [NSLocalizedDescriptionKey: "unknown --look slug: \(raw)"]
            )
        }
        if args.contains("--preset") {
            FileHandle.standardError.write(
                Data("filmtone-desktop: --look \(raw) overrides --preset (basePreset = reset)\n".utf8)
            )
        }
        return raw
    }

    private static func parseStrength(_ args: [String]) -> Double {
        guard let raw = try? value(for: "--strength", in: args),
              let parsed = Double(raw)
        else {
            return FilmtonePresetCatalog.presetStrengthDefault
        }
        return FilmtonePresetCatalog.clampStrength(parsed)
    }

    // Bridges async export into the sync CLI entry by parking the calling
    // thread on a semaphore until the detached Task signals.
    private static func syncRunVideoExport(
        request: FilmtoneVideoExportRequest,
        writeSidecar: Bool
    ) throws -> FilmtoneVideoExportResult {
        let semaphore = DispatchSemaphore(value: 0)
        let box = SyncResultBox()
        Task.detached {
            do {
                let result = try await FilmtoneVideoExporter.export(
                    request,
                    writeSidecar: writeSidecar,
                    progress: nil
                )
                box.result = result
            } catch {
                box.error = error
            }
            semaphore.signal()
        }
        semaphore.wait()
        if let err = box.error {
            throw err
        }
        guard let result = box.result else {
            throw NSError(
                domain: "FilmtoneDesktopCLI",
                code: 70,
                userInfo: [NSLocalizedDescriptionKey: "video export produced no result"]
            )
        }
        return result
    }

    // MARK: shared helpers

    private static func value(for flag: String, in args: [String]) throws -> String {
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else {
            throw NSError(
                domain: "FilmtoneDesktopCLI",
                code: 64,
                userInfo: [NSLocalizedDescriptionKey: "missing value for \(flag)"]
            )
        }
        return args[idx + 1]
    }
}

// Heap box used to bridge the detached async export back to the sync CLI.
// `@unchecked Sendable` because access is serialized by the semaphore — the
// detached task writes before signalling, the caller reads after waiting.
private final class SyncResultBox: @unchecked Sendable {
    var result: FilmtoneVideoExportResult?
    var error: Error?
}
