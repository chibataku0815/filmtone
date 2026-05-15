import FilmLabSwiftCore
import Foundation

func registerImportedGradeRuntimeTests() {
    // Test group 19 — iOS capture package import parity.
    // ---------------------------------------------------------------------------

    struct PackageSidecarRequest: FilmtoneSidecarRequest {
        let sourceURL: URL
        let outputURL: URL
        let presetName: String
        let presetStrength: Double
        let lookSlug: String?
        let sourceKind: FilmtoneSourceKind
        let sourceProfileSelection: CameraProfileSelection
        let quickState: FilmtoneQuickState
        let paramOverrides: FilmtonePhase0ParamsPatch
        let packageCreativeLut: PreparedCreativeLut?
        let capturePackageProvenance: FilmtoneCapturePackageProvenance?
        let highlightMarkers: FilmtoneHighlightMarkers? = nil
        let opticalFilterProfileId: String? = nil
    }

    func makeCapturePackageFixture(
        selectedLookUUID: String? = nil,
        selectedLookSlug: String? = nil,
        selectedLookName: String? = nil,
        includeMaster: Bool = true,
        includeCustomLutMetadata: Bool = false,
        includeCustomLutPayload: Bool = false
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmtone-package-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let masterURL = root.appendingPathComponent("master.mov")
        let proxyURL = root.appendingPathComponent("proxy.mov")
        if includeMaster {
            try Data("master".utf8).write(to: masterURL)
        }
        try Data("proxy".utf8).write(to: proxyURL)

        var payload: [String: Any] = [
            "schemaVersion": 2,
            "captureId": "verify-capture",
            "storagePolicyTag": "internal",
            "masterURLPath": masterURL.path,
            "proxyURLPath": proxyURL.path,
            "packageDirURLPath": root.path,
            "durationLimitSeconds": 10.0,
            "recordedDurationSeconds": 3.0,
            "parametersWidthPx": 3840,
            "parametersHeightPx": 2160,
            "parametersFrameRate": 24.0,
            "parametersCodec": "ProRes 422 HQ",
            "parametersColorSpace": "Apple Log 2",
            "parametersStabilization": "cinematicExtendedEnhanced",
            "writtenAtISO8601": "2026-05-12T00:00:00Z",
            "parametersRequestedStabilization": "on",
            "observedStabilization": "cinematicExtendedEnhanced",
            "requestedCaptureRotationDegrees": 90.0,
            "observedCaptureRotationDegrees": 90.0,
            "masterAudioTrackCount": 1,
        ]
        if let selectedLookUUID, let selectedLookName {
            payload["selectedLookCanonicalUUID"] = selectedLookUUID
            payload["selectedLookSlug"] = selectedLookSlug
            payload["selectedLookEnglishName"] = selectedLookName
            payload["selectedLookIntensity"] = 1.0
        }
        if includeCustomLutMetadata {
            let lutData = stride(from: 0, to: 24, by: 1).map { Double($0) / 23.0 }
            let lutBlob = try FilmtoneLutBlobCodec.encode(data: lutData, size: 2)
            let lutHash = FilmtoneLutBlobCodec.sourceHash(blob: lutBlob)
            payload["customLutTitle"] = "Verify LUT"
            payload["customLutSize"] = 2
            payload["customLutSourceHash"] = lutHash
            payload["customLutIntensity"] = 0.5
            payload["customLutConversionPolicy"] = "apple-log2-to-rec709-before-creative-lut"
            payload["customLutTransformWarningAccepted"] = true
            if includeCustomLutPayload {
                payload["customLutDataRef"] = "custom-lut.lutbin"
                payload["customLutDataFormat"] = FilmtoneLutBlobCodec.dataFormat
                try lutBlob.write(to: root.appendingPathComponent("custom-lut.lutbin"))
            }
        }
        let jsonURL = root.appendingPathComponent("capture-package.json")
        let json = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try json.write(to: jsonURL)
        return jsonURL
    }

    runner.test("capture package importer resolves Noir and master source") {
        let jsonURL = try makeCapturePackageFixture(
            selectedLookUUID: "FB1A0001-0000-4000-8000-000000000010",
            selectedLookSlug: "filmtone-creative-pack-01-noir",
            selectedLookName: "Noir"
        )
        let imported = try FilmtoneCapturePackageImporter.importPackage(from: jsonURL)
        try assertEqual(imported.provenance.sourceMode, .master, "source mode")
        try assertEqual(imported.selectedLookSlug, "filmtone-creative-pack-01-noir", "Noir slug")
        try assertEqual(
            imported.sourceProfileSelection,
            .builtIn(catalogId: "built-in:source-profile.apple-log-2"),
            "master Apple Log 2 source profile"
        )
    }

    runner.test("capture package importer falls back to proxy when master is missing") {
        let jsonURL = try makeCapturePackageFixture(includeMaster: false)
        let imported = try FilmtoneCapturePackageImporter.importPackage(from: jsonURL)
        try assertEqual(imported.provenance.sourceMode, .proxy, "source mode")
        try assertEqual(imported.provenance.fallbackReason, "master-unreachable", "fallback")
        try assertEqual(imported.sourceURL.lastPathComponent, "proxy.mov", "proxy selected")
        try assertEqual(imported.sourceProfileSelection, .auto, "proxy stays Rec.709-shaped")
    }

    runner.test("capture package importer prepares package-local custom LUT") {
        let jsonURL = try makeCapturePackageFixture(
            includeCustomLutMetadata: true,
            includeCustomLutPayload: true
        )
        let imported = try FilmtoneCapturePackageImporter.importPackage(from: jsonURL)
        guard let lut = imported.packageCreativeLut else {
            throw AssertionError(description: "packageCreativeLut missing")
        }
        try assertEqual(lut.size, 2, "custom LUT size")
        try assertClose(lut.intensity, 0.5, "custom LUT intensity")
        try assertEqual(imported.customLutMissingReason, nil, "missing reason")
        try assertEqual(imported.provenance.customLutPayloadState, "ready", "payload state")
    }

    runner.test("capture package importer blocks metadata-only custom LUT") {
        let jsonURL = try makeCapturePackageFixture(
            includeCustomLutMetadata: true,
            includeCustomLutPayload: false
        )
        let imported = try FilmtoneCapturePackageImporter.importPackage(from: jsonURL)
        try assertEqual(imported.packageCreativeLut == nil, true, "no LUT should be prepared")
        try assertEqual(imported.provenance.customLutPayloadState, "metadata-only", "payload state")
        guard imported.customLutMissingReason?.contains("Verify LUT") == true else {
            throw AssertionError(description: "missing reason should name the custom LUT")
        }
    }

    runner.test("sidecar emits capture provenance and package creative LUT") {
        let jsonURL = try makeCapturePackageFixture(
            includeCustomLutMetadata: true,
            includeCustomLutPayload: true
        )
        let imported = try FilmtoneCapturePackageImporter.importPackage(from: jsonURL)
        let req = PackageSidecarRequest(
            sourceURL: imported.sourceURL,
            outputURL: URL(fileURLWithPath: "/tmp/package-out.mp4"),
            presetName: "reset",
            presetStrength: 1.0,
            lookSlug: imported.selectedLookSlug,
            sourceKind: .video,
            sourceProfileSelection: imported.sourceProfileSelection,
            quickState: .zero,
            paramOverrides: .empty,
            packageCreativeLut: imported.packageCreativeLut,
            capturePackageProvenance: imported.provenance
        )
        let payload = FilmtoneSidecarWriter.sidecarPayload(for: req)
        guard let provenance = payload["captureProvenance"] as? [String: Any] else {
            throw AssertionError(description: "captureProvenance missing")
        }
        try assertEqual(provenance["sourceMode"] as? String, "master", "sourceMode")
        try assertEqual(provenance["customLutPayloadState"] as? String, "ready", "payload state")
        guard let creative = payload["creativeLut"] as? [String: Any] else {
            throw AssertionError(description: "creativeLut missing")
        }
        try assertEqual(creative["source"] as? String, "capture-package", "creative source")
    }

    // ---------------------------------------------------------------------------
    // Test group — Twilight bundled built-in Look (preset-only, no cube).
    // Ports `vision3500t` from `packages/film-lab-core/src/presets.ts:632-689`.
    // Confirms: catalog wiring, preset-only materialize emits creativeLut: nil,
    // representative Phase0 values match presets.ts, store helpers treat
    // Twilight as immutable + materializable, and the sidecar payload routes
    // through the preset path (gradeParams reflect twilightPatch on top of
    // reset baseline). Mirrors `FilmtoneBuiltInCatalog.twilightPatch` on iOS.
    // ---------------------------------------------------------------------------

    runner.test("Twilight is registered in FilmtoneCreativePackCatalog.presetOnlyLooks") {
        let twilight = FilmtoneCreativePackCatalog.presetOnlyLooks.first { $0.englishName == "Twilight" }
        guard let entry = twilight else {
            throw AssertionError(description: "Twilight entry missing from presetOnlyLooks")
        }
        try assertEqual(entry.slug, "filmtone-built-in-twilight")
        try assertEqual(
            entry.canonicalUUID,
            UUID(uuidString: "FB1A0001-0000-4000-8000-000000000011")!,
            "Twilight canonicalUUID must match iOS BuiltInLookUUID.twilight"
        )
    }

    runner.test("Twilight materializes with creativeLut: nil and bundled flags") {
        guard let preset = FilmtoneCreativePackCatalog.findPresetOnly(slug: "filmtone-built-in-twilight") else {
            throw AssertionError(description: "findPresetOnly(slug:) returned nil")
        }
        let entry = FilmtoneCreativePackCatalog.materializeAsSavedLookEntry(preset)
        try assertEqual(entry.name, "Twilight")
        try assertEqual(entry.presetName, FilmtonePresetCatalog.defaultName)
        try assertEqual(entry.strength, 1.0)
        try assertEqual(entry.bundled, true)
        try assertEqual(entry.immutable, true)
        try assertEqual(entry.bundledSlug, Optional("filmtone-built-in-twilight"))
        if entry.creativeLut != nil {
            throw AssertionError(description: "Twilight must have creativeLut: nil — selecting it must stay on the preset path")
        }
    }

    runner.test("Twilight stays catalog-addressable but hidden from Desktop library snapshot") {
        let id = UUID(uuidString: "FB1A0001-0000-4000-8000-000000000011")!
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("filmtone-verify-twilight-hidden-\(UUID().uuidString)", isDirectory: true)
        let suiteName = "filmtone-verify-twilight-hidden-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = try FilmtoneSavedLookStore(rootURL: root, defaults: defaults)
        let semaphore = DispatchSemaphore(value: 0)
        var caught: Error?
        var visibleNames: [String] = []
        var materializedName: String?

        Task {
            do {
                let snapshot = try await store.loadOrRebuild()
                visibleNames = snapshot.looks.map(\.name)
                materializedName = try await store.loadLook(id: id).name
            } catch {
                caught = error
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let caught { throw AssertionError(description: "store flow failed: \(caught)") }
        if visibleNames.contains("Twilight") {
            throw AssertionError(description: "Twilight must not be visible in the Desktop Look picker snapshot")
        }
        try assertEqual(materializedName, "Twilight", "runtime catalog lookup should remain compatible")
    }

    runner.test("Twilight patch carries the representative vision3500t values") {
        guard let preset = FilmtoneCreativePackCatalog.findPresetOnly(slug: "filmtone-built-in-twilight") else {
            throw AssertionError(description: "Twilight preset missing")
        }
        let v = preset.paramOverridesPatch.values
        try assertClose(v["temperature"] ?? .nan, -0.40, eps: 1e-9, "temperature")
        try assertClose(v["contrast"] ?? .nan, 1.22, eps: 1e-9, "contrast")
        try assertClose(v["saturation"] ?? .nan, 1.02, eps: 1e-9, "saturation")
        try assertClose(v["shadowHue"] ?? .nan, 225, eps: 1e-9, "shadowHue")
        try assertClose(v["highlightHue"] ?? .nan, 214, eps: 1e-9, "highlightHue")
        try assertClose(v["grainIntensity"] ?? .nan, 0.10, eps: 1e-9, "grainIntensity")
        try assertClose(v["grainSize"] ?? .nan, 0.52, eps: 1e-9, "grainSize")
        try assertClose(v["vignette"] ?? .nan, 0.36, eps: 1e-9, "vignette")
        try assertClose(v["rgbShift"] ?? .nan, 0.0015, eps: 1e-9, "rgbShift")
        try assertClose(v["fade"] ?? .nan, 0.012, eps: 1e-9, "fade")
    }

    runner.test("Twilight UUID resolves through the unified built-in helpers") {
        let id = UUID(uuidString: "FB1A0001-0000-4000-8000-000000000011")!
        try assertEqual(
            FilmtoneCreativePackCatalog.builtInSlug(canonicalUUID: id),
            Optional("filmtone-built-in-twilight"),
            "builtInSlug must recognize Twilight as a built-in"
        )
        guard let materialized = FilmtoneCreativePackCatalog.materializeAnyBuiltIn(canonicalUUID: id) else {
            throw AssertionError(description: "materializeAnyBuiltIn returned nil for Twilight")
        }
        try assertEqual(materialized.name, "Twilight")
        if materialized.creativeLut != nil {
            throw AssertionError(description: "materializeAnyBuiltIn must emit creativeLut: nil for Twilight")
        }
    }

    runner.test("Twilight sidecar payload resolves through preset path (no Creative LUT)") {
        guard let preset = FilmtoneCreativePackCatalog.findPresetOnly(slug: "filmtone-built-in-twilight") else {
            throw AssertionError(description: "Twilight preset missing")
        }
        let req = StubSidecarRequest(
            sourceURL: URL(fileURLWithPath: "/tmp/in.png"),
            outputURL: URL(fileURLWithPath: "/tmp/out.png"),
            presetName: FilmtonePresetCatalog.defaultName,
            presetStrength: 1.0,
            lookSlug: nil,
            sourceKind: .still,
            quickState: .zero,
            paramOverrides: preset.paramOverridesPatch
        )
        let payload = FilmtoneSidecarWriter.sidecarPayload(for: req)
        guard let grade = payload["gradeParams"] as? [String: Double] else {
            throw AssertionError(description: "gradeParams missing")
        }
        try assertClose(grade["temperature"] ?? .nan, -0.40, eps: 1e-6, "gradeParams.temperature")
        try assertClose(grade["shadowHue"] ?? .nan, 225, eps: 1e-6, "gradeParams.shadowHue")
        try assertClose(grade["highlightHue"] ?? .nan, 214, eps: 1e-6, "gradeParams.highlightHue")
        try assertClose(grade["vignette"] ?? .nan, 0.36, eps: 1e-6, "gradeParams.vignette")
        if payload["creativeLut"] != nil {
            throw AssertionError(description: "Twilight must not emit a creativeLut sidecar block — preset path only")
        }
    }
}
