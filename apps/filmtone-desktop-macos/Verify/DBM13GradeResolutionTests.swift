import FilmLabSwiftCore
import Foundation

func registerDBM13GradeResolutionTests() {
    func makeImportedGrade(id: UUID = UUID()) -> FilmtoneImportedGradeLook {
        FilmtoneImportedGradeLook(
            id: id,
            title: "Verify DRX Grade",
            source: .davinciDrx(drxPath: "/tmp/verify.drx"),
            baseLook: .none,
            preLutControls: [
                FilmtoneImportedGradeControl(
                    id: "exposure-log",
                    slot: .preLut,
                    operation: "logExposure",
                    paramKey: "exposure",
                    label: "Exposure",
                    defaultValue: 0.2,
                    min: -1,
                    max: 1
                ),
            ],
            postLutControls: [],
            sourceGraph: FilmtoneImportedGradeSourceGraph(
                decoded: true,
                bodyVersionFlag: 129,
                nodes: [
                    FilmtoneImportedGradeSourceGraph.Node(
                        index: 0,
                        protobufPath: [1],
                        recognizedOps: ["protobufMessage:1"],
                        unsupportedPayloadBase64: nil,
                        approximateInnerFieldCount: 1
                    ),
                ],
                approximateNodeCount: 1,
                unsupportedNotes: ["graph-only; no Resolve parity claimed"]
            ),
            unsupportedMetadata: ["custom curve unsupported"]
        )
    }

    runner.test("DB-M13 GradeResolution resolves imported grade source + unsupported metadata") {
        let id = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let imported = makeImportedGrade(id: id)
        let resolved = FilmtoneGradeResolution.resolve(
            recipe: FilmtoneGradeRecipe(
                selection: .importedGrade(
                    look: imported,
                    sidecarURL: nil,
                    packageCreativeLut: nil
                )
            )
        )
        try assertClose(resolved.params.value(for: "exposure"), 0.2, "imported exposure")
        try assertEqual(resolved.source, .importedGrade(id: id, title: "Verify DRX Grade", sourceKind: "davinci-drx"))
        try assertEqual(resolved.sourceGraph?.approximateNodeCount, 1, "graph summary")
        guard resolved.unsupportedMetadata.contains("custom curve unsupported"),
              resolved.unsupportedMetadata.contains("graph-only; no Resolve parity claimed") else {
            throw AssertionError(description: "unsupported metadata was not preserved")
        }
    }

    runner.test("DB-M13 GradeResolution keeps user overrides authoritative on imported grade") {
        let imported = makeImportedGrade()
        let resolved = FilmtoneGradeResolution.resolve(
            recipe: FilmtoneGradeRecipe(
                selection: .importedGrade(
                    look: imported,
                    sidecarURL: nil,
                    packageCreativeLut: nil
                ),
                paramOverrides: FilmtonePhase0ParamsPatch(values: ["exposure": -0.35])
            )
        )
        try assertClose(resolved.params.value(for: "exposure"), -0.35, "manual exposure override")
    }

    runner.test("DB-M13 GradeRecipe key changes when imported grade changes") {
        let first = FilmtoneGradeRecipe(
            selection: .importedGrade(
                look: makeImportedGrade(id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!),
                sidecarURL: nil,
                packageCreativeLut: nil
            )
        )
        let second = FilmtoneGradeRecipe(
            selection: .importedGrade(
                look: makeImportedGrade(id: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!),
                sidecarURL: nil,
                packageCreativeLut: nil
            )
        )
        try assertEqual(first.key == second.key, false, "video refresh key must observe imported grade identity")
    }

    runner.test("DB-M13 GradeResolution built-in path matches catalog resolution") {
        let patch = FilmtonePhase0ParamsPatch(values: ["contrast": 1.12])
        let resolved = FilmtoneGradeResolution.resolve(
            presetName: "reset",
            presetStrength: 0.65,
            lookSlug: "filmtone-creative-pack-01-urban",
            quickState: .zero,
            paramOverrides: patch,
            packageCreativeLut: nil,
            importedGradeLook: nil,
            opticalFilterProfileId: nil,
            opticalFilterIntensity: 1.0
        )
        let expected = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 0.65,
            lookSlug: "filmtone-creative-pack-01-urban",
            quickState: .zero,
            paramOverrides: patch
        )
        try assertParamsEqual(resolved.params, expected, "built-in GradeResolution parity")
    }

    runner.test("DB-M13 sidecar emits importedGrade block instead of built-in look claim") {
        struct ImportedRequest: FilmtoneSidecarRequest {
            let sourceURL = URL(fileURLWithPath: "/tmp/in.png")
            let outputURL = URL(fileURLWithPath: "/tmp/out.png")
            let presetName = "reset"
            let presetStrength = 1.0
            let lookSlug: String? = "filmtone-creative-pack-01-stone"
            let sourceKind: FilmtoneSourceKind = .still
            let quickState = FilmtoneQuickState.zero
            let paramOverrides = FilmtonePhase0ParamsPatch.empty
            let importedGradeLook: FilmtoneImportedGradeLook?
            let importedGradeSidecarURL: URL? = nil
            let highlightMarkers: FilmtoneHighlightMarkers? = nil
            let opticalFilterProfileId: String? = nil
        }

        let payload = FilmtoneSidecarWriter.sidecarPayload(
            for: ImportedRequest(importedGradeLook: makeImportedGrade())
        )
        guard let imported = payload["imported_grade"] as? [String: Any] else {
            throw AssertionError(description: "imported_grade block missing")
        }
        try assertEqual(imported["title"] as? String, "Verify DRX Grade", "imported title")
        try assertEqual(imported["sourceKind"] as? String, "davinci-drx", "source kind")
        if payload["lookId"] != nil {
            throw AssertionError(description: "imported grade sidecar must not claim built-in lookId")
        }
    }
}
