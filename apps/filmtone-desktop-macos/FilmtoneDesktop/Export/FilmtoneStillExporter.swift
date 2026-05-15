import CoreImage
import CoreGraphics
import FilmLabSwiftCore
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum StillExportFormat: String {
    case png
    case jpeg

    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        }
    }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }
}

enum FilmtoneStillExportError: Error {
    case sourceUnreadable(URL)
    case renderFailed
    case writeFailed(URL)
}

struct FilmtoneStillExportRequest: FilmtoneSidecarRequest {
    let sourceURL: URL
    let outputURL: URL
    let presetName: String
    let presetStrength: Double
    let lookSlug: String?
    let format: StillExportFormat
    let jpegQuality: Double
    let sourceProfileSelection: CameraProfileSelection
    let quickState: FilmtoneQuickState
    let paramOverrides: FilmtonePhase0ParamsPatch
    let packageCreativeLut: PreparedCreativeLut?
    let importedGradeLook: FilmtoneImportedGradeLook?
    let importedGradeSidecarURL: URL?
    let gradeRecipe: FilmtoneGradeRecipe
    let capturePackageProvenance: FilmtoneCapturePackageProvenance?
    let highlightMarkers: FilmtoneHighlightMarkers?
    let opticalFilterProfileId: String?
    /// M5-M (CC-B): intensity scalar for the optical filter profile (0…1).
    let opticalFilterIntensity: Double
    var sourceKind: FilmtoneSourceKind { .still }

    init(
        sourceURL: URL,
        outputURL: URL,
        presetName: String,
        presetStrength: Double = FilmtonePresetCatalog.presetStrengthDefault,
        lookSlug: String? = nil,
        format: StillExportFormat,
        jpegQuality: Double = 0.95,
        sourceProfileSelection: CameraProfileSelection = .auto,
        quickState: FilmtoneQuickState = .zero,
        paramOverrides: FilmtonePhase0ParamsPatch = .empty,
        packageCreativeLut: PreparedCreativeLut? = nil,
        importedGradeLook: FilmtoneImportedGradeLook? = nil,
        importedGradeSidecarURL: URL? = nil,
        gradeRecipe: FilmtoneGradeRecipe? = nil,
        capturePackageProvenance: FilmtoneCapturePackageProvenance? = nil,
        highlightMarkers: FilmtoneHighlightMarkers? = nil,
        opticalFilterProfileId: String? = nil,
        opticalFilterIntensity: Double = 1.0
    ) {
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.presetName = presetName
        self.presetStrength = presetStrength
        self.lookSlug = lookSlug
        self.format = format
        // M5-C.4: clamp at request boundary so a stale UI value can't
        // push a bogus quality through to the encoder.
        self.jpegQuality = min(1.0, max(0.5, jpegQuality))
        self.sourceProfileSelection = sourceProfileSelection
        self.quickState = quickState
        self.paramOverrides = paramOverrides
        self.packageCreativeLut = packageCreativeLut
        self.importedGradeLook = importedGradeLook
        self.importedGradeSidecarURL = importedGradeSidecarURL
        if let gradeRecipe {
            self.gradeRecipe = gradeRecipe
        } else if let importedGradeLook {
            self.gradeRecipe = FilmtoneGradeRecipe(
                selection: .importedGrade(
                    look: importedGradeLook,
                    sidecarURL: importedGradeSidecarURL,
                    packageCreativeLut: packageCreativeLut
                ),
                quickState: quickState,
                paramOverrides: paramOverrides,
                opticalFilterProfileId: opticalFilterProfileId,
                opticalFilterIntensity: opticalFilterIntensity
            )
        } else {
            self.gradeRecipe = FilmtoneGradeRecipe(
                selection: .builtIn(
                    presetName: presetName,
                    presetStrength: presetStrength,
                    lookSlug: lookSlug,
                    packageCreativeLut: packageCreativeLut
                ),
                quickState: quickState,
                paramOverrides: paramOverrides,
                opticalFilterProfileId: opticalFilterProfileId,
                opticalFilterIntensity: opticalFilterIntensity
            )
        }
        self.capturePackageProvenance = capturePackageProvenance
        self.highlightMarkers = highlightMarkers
        self.opticalFilterProfileId = opticalFilterProfileId
        self.opticalFilterIntensity = max(0, min(1, opticalFilterIntensity))
    }
}

struct FilmtoneStillExportResult {
    let outputURL: URL
    let sidecarURL: URL?
    let pixelWidth: Int
    let pixelHeight: Int
}

enum FilmtoneStillExporter {
    static func export(
        _ request: FilmtoneStillExportRequest,
        writeSidecar: Bool = true
    ) throws -> FilmtoneStillExportResult {
        // Phase 2 C1: probe source CGImage color profile (Display P3 / sRGB /
        // Rec.709 / etc.) and let the canonical factory build the contract.
        // For unknown profiles the prober returns nil → factory returns a
        // sourceFallbackColorSpace=nil contract, identical to Phase 1b
        // behaviour. iPhone Display P3 photos now resolve to "smpte432"
        // primaries → factory sets a Display P3 fallback CIImage option so
        // the grade chain interprets the source pixels in P3 space rather
        // than the CIImage default.
        let probe = FilmtoneSourceProber.probeStill(sourceURL: request.sourceURL)
        let contract = FilmtoneColorPipeline.defaultOutputContract(
            sourceMetadata: probe.metadata,
            sourceColorClass: probe.colorClass
        )

        guard let source = CIImage(
            contentsOf: request.sourceURL,
            options: contract.stillImageOptions()
        ) else {
            throw FilmtoneStillExportError.sourceUnreadable(request.sourceURL)
        }

        // M5-C.1: resolve source profile (Auto matches detection-hint
        // catalog; .builtIn is sticky) and apply the cube before grade.
        // For SDR Rec.709 / Display P3 / unknown sources Auto resolves to
        // the Rec.709 nilCurve entry (or no entry) → no transform → bytewise
        // identity preserved against pre-M5-C.1 output.
        let resolvedProfile = FilmtoneSourceInputTransform.resolve(
            selection: request.sourceProfileSelection,
            probedColorClass: probe.colorClass
        )
        let normalizedSource = FilmtoneSourceInputTransform.apply(
            to: source,
            entry: resolvedProfile
        )

        let resolvedGrade = FilmtoneGradeResolution.resolve(recipe: request.gradeRecipe)
        let params = resolvedGrade.params
        let sourceSeed = FilmtoneGradePipeline.makeStableSourceSeed(
            from: request.sourceURL.absoluteString
        )
        let graded = FilmtoneGradePipeline.apply(
            to: normalizedSource,
            params: params,
            sourceSeed: sourceSeed,
            cameraOptics: probe.cameraOptics,
            creativeLut: resolvedGrade.creativeLut,
            lutIntensity: resolvedGrade.lutIntensity,
            opticalFilterProfileId: request.gradeRecipe.opticalFilterProfileId,
            opticalFilterIntensity: request.gradeRecipe.opticalFilterIntensity,
            sourceDetailBias: FilmtoneSourceDetailCompensation.resolve(
                FilmtoneSourceDetailCompensationInput(
                    cameraMake: probe.cameraOptics?.cameraMake,
                    cameraModel: probe.cameraOptics?.cameraModel,
                    colorClass: probe.colorClass?.rawValue,
                    sourceProfileId: resolvedProfile?.id
                )
            ).recommendedBias
        )

        try render(graded, request: request, contract: contract)

        var sidecarURL: URL? = nil
        if writeSidecar {
            sidecarURL = try FilmtoneSidecarWriter.writeSidecar(
                for: request,
                sourceInterpretation: contract.sourceInterpretationID,
                resolvedSourceProfile: resolvedProfile
            )
        }

        let extent = graded.extent
        return FilmtoneStillExportResult(
            outputURL: request.outputURL,
            sidecarURL: sidecarURL,
            pixelWidth: Int(extent.width),
            pixelHeight: Int(extent.height)
        )
    }

    private static func bundledCreativeLut(
        lookSlug: String?,
        strength: Double
    ) -> PreparedCreativeLut? {
        guard let lookSlug,
              strength > 0,
              let look = FilmtoneCreativePackCatalog.find(slug: lookSlug) else {
            return nil
        }
        return FilmtoneCreativeLutLoader.load(look: look)
    }

    private static func clampLutIntensity(_ intensity: Double) -> Double {
        max(0, min(1, intensity.isFinite ? intensity : 1))
    }

    private static func render(
        _ image: CIImage,
        request: FilmtoneStillExportRequest,
        contract: FilmtoneColorPipelineContract
    ) throws {
        let context = FilmtoneCIContext.shared
        let outputSpace = contract.destinationColorSpace

        let dir = request.outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        do {
            switch request.format {
            case .png:
                try context.writePNGRepresentation(
                    of: image,
                    to: request.outputURL,
                    format: .RGBA8,
                    colorSpace: outputSpace,
                    options: [:]
                )
            case .jpeg:
                try context.writeJPEGRepresentation(
                    of: image,
                    to: request.outputURL,
                    colorSpace: outputSpace,
                    options: [
                        // M5-C.4: request-driven quality (default 0.95
                        // matches pre-M5-C.4 hardcoded behavior).
                        kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: request.jpegQuality
                    ]
                )
            }
        } catch {
            throw FilmtoneStillExportError.writeFailed(request.outputURL)
        }
    }
}
