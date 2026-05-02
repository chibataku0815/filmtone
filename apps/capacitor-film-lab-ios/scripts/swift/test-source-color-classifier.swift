import AVFoundation
import CoreVideo
import Foundation

struct ClassifierCheckError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw ClassifierCheckError(message: message)
    }
}

@main
struct TestSourceColorClassifier {
    static func main() throws {
        try runNormalizerTransferTests()
        try runNormalizerLogTransferTests()
        try runNormalizerPrimariesTests()
        try runNormalizerMatrixTests()
        try runClassifierBranchTests()
        try runMezzanineRoutePolicyTests()
        try runColorPipelineContractTests()
        try runPolicyDeriverTests()
        try runHlgFixtureRoundTrip()
        try runAppleLogFixtureRoundTrips()
        print("Source color classifier + normalizer + HDR policy tests passed")
    }

    // MARK: - Normalizer: transfer

    static func runNormalizerTransferTests() throws {
        // Apple CoreMedia identifier -> ffprobe vocabulary
        try expect(
            SourceColorMetadataNormalizer.normalizeTransfer("ITU_R_709_2") == "bt709",
            "transfer ITU_R_709_2 -> bt709"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeTransfer("SMPTE_ST_2084_PQ") == "smpte2084",
            "transfer SMPTE_ST_2084_PQ -> smpte2084"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeTransfer("ITU_R_2100_HLG") == "arib-std-b67",
            "transfer ITU_R_2100_HLG -> arib-std-b67"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeTransfer("ITU_R_2020") == "bt2020-10",
            "transfer ITU_R_2020 -> bt2020-10"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeTransfer("SMPTE_240M_1995") == "smpte240m",
            "transfer SMPTE_240M_1995 -> smpte240m"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeTransfer("sRGB") == "iec61966-2-1",
            "transfer sRGB -> iec61966-2-1"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeTransfer("UseGamma") == nil,
            "transfer UseGamma -> nil (opaque without gamma dict)"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeTransfer(nil) == nil,
            "transfer nil -> nil"
        )
        // Accept prefixed constant names
        try expect(
            SourceColorMetadataNormalizer.normalizeTransfer(
                "kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG"
            ) == "arib-std-b67",
            "transfer with kCMFormatDescription prefix"
        )
    }

    static func runNormalizerLogTransferTests() throws {
        try expect(
            SourceColorMetadataNormalizer.normalizeLogTransferFunction("kCMFormatDescriptionLogTransferFunction_AppleLog") == .appleLog,
            "log transfer AppleLog constant -> appleLog"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeLogTransferFunction("kCVImageBufferLogTransferFunction_AppleLog2") == .appleLog2,
            "log transfer AppleLog2 constant -> appleLog2"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeLogTransferFunction("apple-log") == .appleLog,
            "log transfer apple-log -> appleLog"
        )
    }

    // MARK: - Normalizer: primaries

    static func runNormalizerPrimariesTests() throws {
        try expect(
            SourceColorMetadataNormalizer.normalizePrimaries("ITU_R_709_2") == "bt709",
            "primaries ITU_R_709_2 -> bt709"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizePrimaries("ITU_R_2020") == "bt2020",
            "primaries ITU_R_2020 -> bt2020"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizePrimaries("P3_D65") == "smpte432",
            "primaries P3_D65 -> smpte432"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizePrimaries("SMPTE_C") == "smpte170m",
            "primaries SMPTE_C -> smpte170m"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizePrimaries(nil) == nil,
            "primaries nil -> nil"
        )
    }

    // MARK: - Normalizer: matrix

    static func runNormalizerMatrixTests() throws {
        try expect(
            SourceColorMetadataNormalizer.normalizeMatrix("ITU_R_709_2") == "bt709",
            "matrix ITU_R_709_2 -> bt709"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeMatrix("ITU_R_2020") == "bt2020nc",
            "matrix ITU_R_2020 -> bt2020nc"
        )
        try expect(
            SourceColorMetadataNormalizer.normalizeMatrix("ITU_R_601_4") == "smpte170m",
            "matrix ITU_R_601_4 -> smpte170m"
        )
    }

    // MARK: - Classifier branches

    static func runClassifierBranchTests() throws {
        // Branch 1: PQ
        try expect(
            SourceColorClassifier.classify(metadata(transfer: "smpte2084", primaries: "bt2020")) == .hdrPq,
            "classifier: transfer=smpte2084 -> hdrPq"
        )
        // Branch 2: HLG
        try expect(
            SourceColorClassifier.classify(metadata(transfer: "arib-std-b67", primaries: "bt2020")) == .hdrHlg,
            "classifier: transfer=arib-std-b67 -> hdrHlg"
        )
        // Branch 3: wide-gamut via bt2020 primaries
        try expect(
            SourceColorClassifier.classify(metadata(transfer: "bt709", primaries: "bt2020")) == .wideGamutUnknown,
            "classifier: primaries=bt2020 -> wideGamutUnknown"
        )
        try expect(
            SourceColorClassifier.classify(metadata(
                transfer: "apple-log", primaries: "bt2020", logTransfer: .appleLog
            )) == .appleLog,
            "classifier: Apple Log -> appleLog"
        )
        try expect(
            SourceColorClassifier.classify(metadata(
                transfer: "apple-log2", primaries: "apple-wide-gamut", logTransfer: .appleLog2
            )) == .appleLog2,
            "classifier: Apple Log 2 -> appleLog2"
        )
        // Branch 3: wide-gamut via mastering display presence
        try expect(
            SourceColorClassifier.classify(metadata(
                transfer: "bt709", primaries: "bt709",
                hasMastering: true
            )) == .wideGamutUnknown,
            "classifier: hasMasteringDisplay -> wideGamutUnknown"
        )
        // Branch 4: SDR BT.709 fully specified
        try expect(
            SourceColorClassifier.classify(metadata(
                transfer: "bt709", primaries: "bt709", space: "bt709"
            )) == .sdrBt709,
            "classifier: full bt709 -> sdrBt709"
        )
        // Branch 4: SDR BT.709 with nil space
        try expect(
            SourceColorClassifier.classify(metadata(
                transfer: "bt709", primaries: "bt709", space: nil
            )) == .sdrBt709,
            "classifier: bt709 primaries+transfer, nil space -> sdrBt709"
        )
        // Branch 5: iPhone SDR Display P3 / DCI P3 must not be labeled BT.709.
        try expect(
            SourceColorClassifier.classify(metadata(
                transfer: "bt709", primaries: "smpte432", space: "bt709"
            )) == .unknown,
            "classifier: Display P3 SDR -> unknown"
        )
        try expect(
            SourceColorClassifier.classify(metadata(
                transfer: "iec61966-2-1", primaries: "smpte431", space: nil
            )) == .unknown,
            "classifier: DCI P3 SDR transfer -> unknown"
        )
        // Branch 5: unknown (everything nil)
        try expect(
            SourceColorClassifier.classify(metadata(transfer: nil, primaries: nil, space: nil)) == .unknown,
            "classifier: all nil -> unknown"
        )
        // Branch 5: unknown (non-bt709 primaries without HDR hints)
        try expect(
            SourceColorClassifier.classify(metadata(transfer: "smpte170m", primaries: "smpte170m")) == .unknown,
            "classifier: smpte170m -> unknown"
        )
    }

    // MARK: - Mezzanine route policy

    static func runMezzanineRoutePolicyTests() throws {
        try expect(
            FilmtoneMezzanineRoutePolicy.selectedVariant(
                renderMode: nil,
                colorClass: .sdrBt709,
                hasHDRMezzanine: true,
                hasSDRMezzanine: true
            ) == nil,
            "route: default quality must stay source-direct without quality mezzanines"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.selectedVariant(
                renderMode: "quality",
                colorClass: .hdrHlg,
                hasHDRMezzanine: true,
                hasSDRMezzanine: true
            ) == nil,
            "route: explicit quality must stay source-direct without quality mezzanines"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.selectedVariant(
                renderMode: "quality",
                colorClass: .appleLog,
                hasHDRMezzanine: false,
                hasSDRMezzanine: false,
                hasQualityHDRMezzanine: true,
                hasQualitySDRMezzanine: false
            ) == .qualityHDR,
            "route: quality must use qualityHDR when the heavy-source cache exists"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.selectedVariant(
                renderMode: "quality",
                colorClass: .sdrBt709,
                hasHDRMezzanine: false,
                hasSDRMezzanine: false,
                hasQualityHDRMezzanine: false,
                hasQualitySDRMezzanine: true
            ) == .qualitySDR,
            "route: quality must use qualitySDR when the heavy-source cache exists"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.selectedVariant(
                renderMode: "speed",
                colorClass: .sdrBt709,
                hasHDRMezzanine: true,
                hasSDRMezzanine: true
            ) == .sdr,
            "route: speed may use SDR mezzanine only for strict BT.709"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.selectedVariant(
                renderMode: "speed",
                colorClass: .hdrHlg,
                hasHDRMezzanine: true,
                hasSDRMezzanine: true
            ) == .hdr,
            "route: speed prefers HDR mezzanine for HDR classes"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.selectedVariant(
                renderMode: "speed",
                colorClass: .unknown,
                hasHDRMezzanine: true,
                hasSDRMezzanine: true
            ) == nil,
            "route: stale unknown/P3 mezzanine cache must not be selected"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.selectedVariant(
                renderMode: "speed",
                colorClass: .wideGamutUnknown,
                hasHDRMezzanine: false,
                hasSDRMezzanine: true
            ) == nil,
            "route: wide-gamut unknown must not fall back to SDR mezzanine"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.prewarmVariant(for: .sdrBt709) == .sdr,
            "route: prewarm strict BT.709 as SDR"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.prewarmVariant(for: .unknown) == nil,
            "route: skip prewarm for unknown/P3 sources"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant(
                for: .appleLog,
                codecFamily: .prores422,
                estimatedDataRate: nil
            ) == .qualityHDR,
            "route: ProRes Apple Log must generate qualityHDR"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant(
                for: .sdrBt709,
                codecFamily: .hevc,
                estimatedDataRate: 150_000_000
            ) == .qualitySDR,
            "route: >=100Mbps SDR HEVC must generate qualitySDR"
        )
        try expect(
            FilmtoneMezzanineRoutePolicy.qualityPrewarmVariant(
                for: .sdrBt709,
                codecFamily: .hevc,
                estimatedDataRate: 50_000_000
            ) == nil,
            "route: typical iPhone HEVC must stay source-direct in Quality"
        )
    }

    // MARK: - Shared color pipeline

    static func runColorPipelineContractTests() throws {
        let p3Metadata = metadata(
            transfer: "bt709",
            primaries: "smpte432",
            space: "bt709"
        )
        let p3Class = SourceColorClassifier.classify(p3Metadata)
        try expect(
            p3Class != .sdrBt709,
            "color pipeline precondition: Display P3 SDR must not classify as strict BT.709"
        )

        let p3Contract = FilmtoneColorPipeline.defaultOutputContract(
            sourceMetadata: p3Metadata,
            sourceColorClass: p3Class
        )
        try expect(
            p3Contract.outputProfileID == "rec709-sdr-mp4",
            "color pipeline: Display P3 SDR should map to Rec.709 SDR MP4 output"
        )
        try expect(
            p3Contract.sourceInterpretationID == "display-p3-sdr",
            "color pipeline: source interpretation should retain Display P3 SDR truth"
        )
        try expect(p3Contract.outputColorPrimariesID == "bt709", "color pipeline: primaries id")
        try expect(p3Contract.outputColorTransferID == "bt709", "color pipeline: transfer id")
        try expect(p3Contract.outputColorSpaceID == "bt709", "color pipeline: matrix/space id")

        try expect(
            p3Contract.writerColorProperties[AVVideoColorPrimariesKey] as? String == AVVideoColorPrimaries_ITU_R_709_2,
            "color pipeline: writer primaries tag"
        )
        try expect(
            p3Contract.writerColorProperties[AVVideoTransferFunctionKey] as? String == AVVideoTransferFunction_ITU_R_709_2,
            "color pipeline: writer transfer tag"
        )
        try expect(
            p3Contract.writerColorProperties[AVVideoYCbCrMatrixKey] as? String == AVVideoYCbCrMatrix_ITU_R_709_2,
            "color pipeline: writer matrix tag"
        )
        try expect(
            CFEqual(p3Contract.pixelBufferColorPrimariesTag, kCVImageBufferColorPrimaries_ITU_R_709_2),
            "color pipeline: CV primaries tag"
        )
        try expect(
            CFEqual(p3Contract.pixelBufferTransferFunctionTag, kCVImageBufferTransferFunction_ITU_R_709_2),
            "color pipeline: CV transfer tag"
        )
        try expect(
            CFEqual(p3Contract.pixelBufferYCbCrMatrixTag, kCVImageBufferYCbCrMatrix_ITU_R_709_2),
            "color pipeline: CV matrix tag"
        )

        let readerSettings = p3Contract.videoReaderOutputSettings(pixelFormat: kCVPixelFormatType_32BGRA)
        try expect(
            readerSettings[AVVideoAllowWideColorKey] as? Bool == true,
            "color pipeline: reader must allow wide color before mapping to Rec.709 output"
        )
        try expect(
            readerSettings[kCVPixelBufferPixelFormatTypeKey as String] as? Int == Int(kCVPixelFormatType_32BGRA),
            "color pipeline: reader pixel format should be preserved"
        )
    }

    // MARK: - HDR policy deriver


    static func runPolicyDeriverTests() throws {
        let sdr = HdrPreparationPolicyDeriver.derive(colorClass: .sdrBt709)
        try expect(sdr.strategy == .none, "deriver: sdr -> none")
        try expect(sdr.reason == "source-is-sdr-bt709", "deriver: sdr reason")
        try expect(sdr.requiresFixtureValidation == false, "deriver: sdr fixture=false")

        let pq = HdrPreparationPolicyDeriver.derive(colorClass: .hdrPq)
        try expect(pq.strategy == .coreImageToneMapSdr, "deriver: pq -> coreImageToneMapSdr")
        try expect(pq.reason == "source-is-hdr-pq", "deriver: pq reason")
        try expect(pq.requiresFixtureValidation == true, "deriver: pq fixture=true")

        let hlg = HdrPreparationPolicyDeriver.derive(colorClass: .hdrHlg)
        try expect(hlg.strategy == .coreImageToneMapSdr, "deriver: hlg -> coreImageToneMapSdr")
        try expect(hlg.reason == "source-is-hdr-hlg", "deriver: hlg reason")
        try expect(hlg.requiresFixtureValidation == true, "deriver: hlg fixture=true")

        let wg = HdrPreparationPolicyDeriver.derive(colorClass: .wideGamutUnknown)
        try expect(wg.strategy == .deferVisibleWarning, "deriver: wide-gamut -> deferVisibleWarning")
        try expect(wg.reason == "wide-gamut-transfer-unknown", "deriver: wide-gamut reason")
        try expect(wg.requiresFixtureValidation == true, "deriver: wide-gamut fixture=true")

        let appleLog = SourceInputTransformPolicyDeriver.derive(
            colorClass: .appleLog,
            codecFamily: .prores422,
            logTransferFunction: .appleLog
        )
        try expect(appleLog.strategy == .appleLogToRec709, "input deriver: Apple Log -> appleLogToRec709")
        try expect(appleLog.reason == "source-is-apple-log", "input deriver: Apple Log reason")

        let raw = SourceInputTransformPolicyDeriver.derive(
            colorClass: .appleLog2,
            codecFamily: .proresRaw,
            logTransferFunction: .appleLog2
        )
        try expect(raw.strategy == .unsupported, "input deriver: ProRes RAW -> unsupported")
        try expect(raw.reason == "source-is-prores-raw", "input deriver: ProRes RAW reason")

        let unknown = HdrPreparationPolicyDeriver.derive(colorClass: .unknown)
        try expect(unknown.strategy == .none, "deriver: unknown -> none")
        try expect(unknown.reason == "source-color-unknown", "deriver: unknown reason")
        try expect(unknown.requiresFixtureValidation == false, "deriver: unknown fixture=false")
    }

    // MARK: - HLG fixture round-trip

    static func runHlgFixtureRoundTrip() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        try expect(
            args.count >= 1,
            "usage: test-source-color-classifier <hlg-export-request>"
        )
        let url = URL(fileURLWithPath: args[0])
        let decoder = JSONDecoder()
        let request = try decoder.decode(Phase0ExportRequestDTO.self, from: Data(contentsOf: url))
        let probeMetadata = request.sourceProbe?.sourceVideoMetadata
        try expect(probeMetadata != nil, "HLG fixture missing sourceVideoMetadata")
        try expect(
            probeMetadata?.colorClass == .hdrHlg,
            "HLG fixture colorClass should be hdrHlg"
        )
        try expect(
            probeMetadata?.hdrPreparationPolicy?.strategy == .coreImageToneMapSdr,
            "HLG fixture strategy should be coreImageToneMapSdr"
        )
        try expect(
            probeMetadata?.hdrPreparationPolicy?.reason == "source-is-hdr-hlg",
            "HLG fixture reason should be source-is-hdr-hlg"
        )
        try expect(
            probeMetadata?.display.rotationDeg == 90,
            "HLG fixture rotationDeg should be 90 (portrait)"
        )
        try expect(
            probeMetadata?.timing?.trustReason == "nominal-only",
            "HLG fixture trustReason should be nominal-only"
        )
    }

    // MARK: - Apple Log / ProRes fixture round-trips

    static func runAppleLogFixtureRoundTrips() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        let hlgURL = URL(fileURLWithPath: args[0])
        let fixtureDir = hlgURL.deletingLastPathComponent()

        try assertAppleLogFixture(
            fixtureDir.appendingPathComponent("apple-log-prores-422-export-request.json"),
            expectedCodec: "apcn",
            expectedTransfer: "apple-log",
            expectedLogTransfer: .appleLog,
            expectedCodecFamily: .prores422,
            expectedColorClass: .appleLog,
            expectedInputStrategy: .appleLogToRec709,
            expectedInputReason: "source-is-apple-log",
            expectedHdrStrategy: .none,
            expectedHdrReason: "source-is-apple-log",
            expectedHdrRequiresFixtureValidation: true,
            expectedDisplayWidth: 3840,
            expectedDisplayHeight: 2160,
            expectedRotation: 0,
            expectedFrameRate: 30,
            label: "Apple Log / ProRes 422"
        )

        try assertAppleLogFixture(
            fixtureDir.appendingPathComponent("apple-log-2-prores-raw-export-request.json"),
            expectedCodec: "aprn",
            expectedTransfer: "apple-log2",
            expectedLogTransfer: .appleLog2,
            expectedCodecFamily: .proresRaw,
            expectedColorClass: .unsupported,
            expectedInputStrategy: .unsupported,
            expectedInputReason: "source-is-prores-raw",
            expectedHdrStrategy: .deferVisibleWarning,
            expectedHdrReason: "source-unsupported",
            expectedHdrRequiresFixtureValidation: false,
            expectedDisplayWidth: 2160,
            expectedDisplayHeight: 3840,
            expectedRotation: 90,
            expectedFrameRate: 24,
            label: "Apple Log 2 / ProRes RAW"
        )
    }

    static func assertAppleLogFixture(
        _ url: URL,
        expectedCodec: String,
        expectedTransfer: String,
        expectedLogTransfer: SourceLogTransferFunctionDTO,
        expectedCodecFamily: SourceCodecFamilyDTO,
        expectedColorClass: SourceColorClassDTO,
        expectedInputStrategy: SourceInputTransformStrategyDTO,
        expectedInputReason: String,
        expectedHdrStrategy: HdrPreparationStrategyDTO,
        expectedHdrReason: String,
        expectedHdrRequiresFixtureValidation: Bool,
        expectedDisplayWidth: Int,
        expectedDisplayHeight: Int,
        expectedRotation: Int,
        expectedFrameRate: Double,
        label: String
    ) throws {
        let decoder = JSONDecoder()
        let request = try decoder.decode(Phase0ExportRequestDTO.self, from: Data(contentsOf: url))
        let probe = request.sourceProbe
        let metadata = probe?.sourceVideoMetadata

        try expect(probe?.codec == expectedCodec, "\(label) codec should be \(expectedCodec)")
        try expect(probe?.codecFamily == expectedCodecFamily, "\(label) codecFamily should be \(expectedCodecFamily.rawValue)")
        try expect(probe?.logTransferFunction == expectedLogTransfer, "\(label) top-level logTransferFunction should match")
        try expect(probe?.inputTransformPolicy?.strategy == expectedInputStrategy, "\(label) top-level input strategy should match")
        try expect(probe?.inputTransformPolicy?.reason == expectedInputReason, "\(label) top-level input reason should match")
        try expect(metadata != nil, "\(label) fixture missing sourceVideoMetadata")
        try expect(
            metadata?.color.colorTransfer == expectedTransfer,
            "\(label) colorTransfer should be \(expectedTransfer)"
        )
        try expect(
            metadata?.color.logTransferFunction == expectedLogTransfer,
            "\(label) color.logTransferFunction should match"
        )
        try expect(
            metadata?.codecFamily == expectedCodecFamily,
            "\(label) metadata.codecFamily should match"
        )
        try expect(
            metadata?.logTransferFunction == expectedLogTransfer,
            "\(label) metadata.logTransferFunction should match"
        )
        try expect(
            metadata?.inputTransformPolicy?.strategy == expectedInputStrategy,
            "\(label) metadata input strategy should match"
        )
        try expect(
            metadata?.inputTransformPolicy?.reason == expectedInputReason,
            "\(label) metadata input reason should match"
        )
        try expect(
            metadata?.colorClass == expectedColorClass,
            "\(label) colorClass should be \(expectedColorClass.rawValue)"
        )
        try expect(
            metadata?.hdrPreparationPolicy?.strategy == expectedHdrStrategy,
            "\(label) HDR strategy should be \(expectedHdrStrategy.rawValue)"
        )
        try expect(
            metadata?.hdrPreparationPolicy?.reason == expectedHdrReason,
            "\(label) HDR reason should be \(expectedHdrReason)"
        )
        try expect(
            metadata?.hdrPreparationPolicy?.requiresFixtureValidation == expectedHdrRequiresFixtureValidation,
            "\(label) requiresFixtureValidation should be \(expectedHdrRequiresFixtureValidation)"
        )
        try expect(
            metadata?.display.displayWidth == expectedDisplayWidth,
            "\(label) displayWidth should be \(expectedDisplayWidth)"
        )
        try expect(
            metadata?.display.displayHeight == expectedDisplayHeight,
            "\(label) displayHeight should be \(expectedDisplayHeight)"
        )
        try expect(
            metadata?.display.rotationDeg == expectedRotation,
            "\(label) rotationDeg should be \(expectedRotation)"
        )
        try expect(
            metadata?.timing?.nominalFrameRate == expectedFrameRate,
            "\(label) nominalFrameRate should be \(expectedFrameRate)"
        )
        try expect(
            metadata?.timing?.trustReason == "nominal-only",
            "\(label) trustReason should be nominal-only"
        )
    }

    // MARK: - Fixture helpers

    static func metadata(
        transfer: String?,
        primaries: String?,
        space: String? = nil,
        logTransfer: SourceLogTransferFunctionDTO? = nil,
        hasMastering: Bool = false,
        hasContentLight: Bool = false
    ) -> SourceColorMetadataDTO {
        SourceColorMetadataDTO(
            colorRange: nil,
            colorSpace: space,
            colorTransfer: transfer,
            colorPrimaries: primaries,
            logTransferFunction: logTransfer,
            hasMasteringDisplayMetadata: hasMastering,
            hasContentLightMetadata: hasContentLight
        )
    }
}
