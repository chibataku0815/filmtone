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
        try runNormalizerPrimariesTests()
        try runNormalizerMatrixTests()
        try runClassifierBranchTests()
        try runPolicyDeriverTests()
        try runHlgFixtureRoundTrip()
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

    // MARK: - Fixture helpers

    static func metadata(
        transfer: String?,
        primaries: String?,
        space: String? = nil,
        hasMastering: Bool = false,
        hasContentLight: Bool = false
    ) -> SourceColorMetadataDTO {
        SourceColorMetadataDTO(
            colorRange: nil,
            colorSpace: space,
            colorTransfer: transfer,
            colorPrimaries: primaries,
            hasMasteringDisplayMetadata: hasMastering,
            hasContentLightMetadata: hasContentLight
        )
    }
}
