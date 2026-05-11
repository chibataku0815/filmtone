import FilmLabSwiftCore
import Foundation

/// Phase 2B-8B: Filmtone Connect package companion artifact assembler lifted
/// out of `FilmtoneExportSession`. Owns source-media copy, combined /
/// pre-optical / post-optical cube writing through
/// `FilmtoneConnectCubeWriter`, DCTL writing through
/// `FilmtoneConnectDctlWriter`, reference-after JPEG path orchestration via a
/// session-supplied closure, the eight URL fields of the `Companions` value,
/// the `SidecarPackage` payload that feeds `writeExportSidecar`, and the
/// ordered package-file URI list returned to clients in
/// `Phase0ExportResultDTO.packageFileUris`.
///
/// `writeReferenceAfterImage`, `makePreviewPosterTime`, `copyPreviewCGImage`,
/// `writeJPEGImage`, and `writeExportSidecar` stay on
/// `FilmtoneExportSession`. The session passes a `(URL, Double?) throws ->
/// Double` closure into `makeCompanions(result:writeReferenceAfterImage:)` so
/// reference-after writing keeps the existing poster-time logic, AVURLAsset
/// duration fallback, and `outputColorSpace` JPEG color profile.
final class ExportConnectPackageAssembler {
    struct Companions {
        let sourceMediaURL: URL
        let cubeURL: URL
        let preOpticalCubeURL: URL
        let postOpticalCubeURL: URL
        let dctlURL: URL
        let referenceAfterURL: URL
        let referenceAfterTimeSec: Double
        let sidecarPackage: SidecarPackage
    }

    private static let connectCubeFilenameSuffix = "combined-color.cube"
    private static let connectPreOpticalCubeFilenameSuffix = "pre-optical-color.cube"
    private static let connectPostOpticalCubeFilenameSuffix = "post-optical-color.cube"
    private static let connectReferenceAfterFilenameSuffix = "reference-after.jpg"
    private static let connectDctlFilenameSuffix = "filmtone-bridge.dctl"

    private let request: Phase0ExportRequestDTO
    private let sourceURL: URL
    private let outputURL: URL
    private let sourceSeed: Double

    init(
        request: Phase0ExportRequestDTO,
        sourceURL: URL,
        outputURL: URL,
        sourceSeed: Double
    ) {
        self.request = request
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.sourceSeed = sourceSeed
    }

    func makeCompanions(
        result: CompletedExport,
        writeReferenceAfterImage: (URL, Double?) throws -> Double
    ) -> Companions? {
        let directoryURL = outputURL.deletingLastPathComponent()
        let packageStem = outputURL.deletingPathExtension().lastPathComponent
        let sourceExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let sourcePackageURL = directoryURL
            .appendingPathComponent("\(packageStem)-source.\(sourceExtension)")
        let cubeURL = directoryURL
            .appendingPathComponent("\(packageStem)-\(Self.connectCubeFilenameSuffix)")
        let preOpticalCubeURL = directoryURL
            .appendingPathComponent("\(packageStem)-\(Self.connectPreOpticalCubeFilenameSuffix)")
        let postOpticalCubeURL = directoryURL
            .appendingPathComponent("\(packageStem)-\(Self.connectPostOpticalCubeFilenameSuffix)")
        let dctlURL = directoryURL
            .appendingPathComponent("\(packageStem)-\(Self.connectDctlFilenameSuffix)")
        let referenceURL = directoryURL
            .appendingPathComponent("\(packageStem)-\(Self.connectReferenceAfterFilenameSuffix)")

        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: sourcePackageURL.path) {
                try fileManager.removeItem(at: sourcePackageURL)
            }
            try fileManager.copyItem(at: sourceURL, to: sourcePackageURL)
            try FilmtoneConnectCubeWriter.writeCombinedColorCube(
                for: request,
                to: cubeURL
            )
            try FilmtoneConnectCubeWriter.writePreOpticalColorCube(
                for: request,
                to: preOpticalCubeURL
            )
            try FilmtoneConnectCubeWriter.writePostOpticalColorCube(
                for: request,
                to: postOpticalCubeURL
            )
            try FilmtoneConnectDctlWriter.writeBridgeDctl(
                for: request,
                cubeFilename: cubeURL.lastPathComponent,
                preOpticalColorFilename: preOpticalCubeURL.lastPathComponent,
                postOpticalColorFilename: postOpticalCubeURL.lastPathComponent,
                outputFps: request.output.fps,
                sourceSeed: sourceSeed,
                to: dctlURL
            )
            let referenceAfterTimeSec = try writeReferenceAfterImage(
                referenceURL,
                result.sourceDurationSec
            )
            return Companions(
                sourceMediaURL: sourcePackageURL,
                cubeURL: cubeURL,
                preOpticalCubeURL: preOpticalCubeURL,
                postOpticalCubeURL: postOpticalCubeURL,
                dctlURL: dctlURL,
                referenceAfterURL: referenceURL,
                referenceAfterTimeSec: referenceAfterTimeSec,
                sidecarPackage: SidecarPackage(
                    sourceMediaFilename: sourcePackageURL.lastPathComponent,
                    renderedMediaFilename: outputURL.lastPathComponent,
                    referenceAfterFilename: referenceURL.lastPathComponent,
                    referenceAfterTimeSec: referenceAfterTimeSec,
                    combinedColorFilename: cubeURL.lastPathComponent,
                    preOpticalColorFilename: preOpticalCubeURL.lastPathComponent,
                    postOpticalColorFilename: postOpticalCubeURL.lastPathComponent,
                    effectsDctlFilename: dctlURL.lastPathComponent
                )
            )
        } catch {
            filmtonePreviewCompositionDebugLog(
                "Filmtone Connect package companion write failed: \(error.localizedDescription)"
            )
            return nil
        }
    }

    func makePackageFileUris(
        sidecarUri: String?,
        companions: Companions?
    ) -> [String]? {
        guard let sidecarUri, let companions else {
            return nil
        }
        return FilmtoneConnectPackageFiles.orderedPackageFileUris(
            renderedUri: outputURL.absoluteString,
            sidecarUri: sidecarUri,
            sourceMediaUri: companions.sourceMediaURL.absoluteString,
            preOpticalCubeUri: companions.preOpticalCubeURL.absoluteString,
            postOpticalCubeUri: companions.postOpticalCubeURL.absoluteString,
            cubeUri: companions.cubeURL.absoluteString,
            dctlUri: companions.dctlURL.absoluteString,
            referenceAfterUri: companions.referenceAfterURL.absoluteString
        )
    }
}
