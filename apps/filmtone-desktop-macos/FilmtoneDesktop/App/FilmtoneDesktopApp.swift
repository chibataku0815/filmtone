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
//     --preset reset \
//     [--format png|jpeg] [--no-sidecar]
//
//   FilmtoneDesktop --export-video \
//     --input <path/to/source.mov> \
//     --output <path/to/output.mp4> \
//     --preset reset \
//     [--no-sidecar]

@main
struct FilmtoneDesktopApp: App {
    init() {
        FilmtoneDesktopCLI.runIfRequested()
    }

    var body: some Scene {
        WindowGroup("Filmtone Desktop") {
            RootWindowView()
        }
        .windowResizability(.contentMinSize)
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
        let preset = (try? value(for: "--preset", in: args)) ?? FilmtonePresetCatalog.defaultName
        let formatString = (try? value(for: "--format", in: args)) ?? "png"
        let format = StillExportFormat(rawValue: formatString) ?? .png

        return FilmtoneStillExportRequest(
            sourceURL: URL(fileURLWithPath: inputPath),
            outputURL: URL(fileURLWithPath: outputPath),
            presetName: preset,
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
        let preset = (try? value(for: "--preset", in: args)) ?? FilmtonePresetCatalog.defaultName

        return FilmtoneVideoExportRequest(
            sourceURL: URL(fileURLWithPath: inputPath),
            outputURL: URL(fileURLWithPath: outputPath),
            presetName: preset,
            codec: .h264
        )
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
