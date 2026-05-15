import Foundation

func registerAutomationRuntimeTests() {
    runner.test("automation command envelope decodes inspect payload") {
        let json = """
        {
          "command": "inspectSources",
          "inspectSources": {
            "paths": ["/tmp/example.mov"],
            "recursive": true
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(FilmtoneAutomationEnvelope.self, from: json)
        try assertEqual(envelope.command, .inspectSources)
        try assertEqual(envelope.inspectSources?.paths, ["/tmp/example.mov"])
        try assertEqual(envelope.inspectSources?.recursive, true)
    }

    runner.test("automation output size preserves archive dimensions") {
        let size = FilmtoneAutomationCore.outputDimensions(
            displayWidth: 3840,
            displayHeight: 2160,
            profile: .archiveH264
        )
        try assertEqual(size, FilmtoneAutomationDimensions(width: 3840, height: 2160))
    }

    runner.test("automation social1080 caps long edge") {
        let landscape = FilmtoneAutomationCore.outputDimensions(
            displayWidth: 3840,
            displayHeight: 2160,
            profile: .social1080
        )
        let portrait = FilmtoneAutomationCore.outputDimensions(
            displayWidth: 2160,
            displayHeight: 3840,
            profile: .social1080
        )
        try assertEqual(landscape, FilmtoneAutomationDimensions(width: 1920, height: 1080))
        try assertEqual(portrait, FilmtoneAutomationDimensions(width: 1080, height: 1920))
    }

    runner.test("automation resolves built-in Look request") {
        let stone = FilmtoneAutomationCore.resolveLook("Stone", strength: 0.7)
        try assertEqual(stone.label, "Stone")
        try assertEqual(stone.presetName, FilmtonePresetCatalog.defaultName)
        try assertClose(stone.presetStrength, 0.7)
        try assertEqual(stone.lookSlug, "filmtone-creative-pack-01-stone")

        let none = FilmtoneAutomationCore.resolveLook("Unknown", strength: 2)
        try assertEqual(none.label, "None")
        try assertClose(none.presetStrength, 1)
        try assertEqual(none.lookSlug, nil)
    }

    runner.test("automation inspect reports still and missing paths") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmtone-automation-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let still = root.appendingPathComponent("image.png")
        try Data().write(to: still)
        let missing = root.appendingPathComponent("missing.mov")

        let result = try waitForAsync {
            try await FilmtoneAutomationCore.inspectSources(
                FilmtoneAutomationInspectSourcesRequest(
                    paths: [still.path, missing.path],
                    recursive: false
                )
            )
        }

        let byPath = Dictionary(uniqueKeysWithValues: result.sources.map { ($0.path, $0.kind) })
        try assertEqual(byPath[still.path], "still")
        try assertEqual(byPath[missing.path], "missing")
        try assertEqual(result.analysisLimits.visualFrameAnalysis, false)
    }

    runner.test("automation preview skips stills and records missing warnings") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmtone-preview-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let still = root.appendingPathComponent("image.png")
        try Data().write(to: still)
        let missing = root.appendingPathComponent("missing.mov")

        let result = try waitForAsync {
            try await FilmtoneAutomationCore.previewBatch(
                FilmtoneAutomationBatchPlanRequest(
                    paths: [still.path, missing.path],
                    recursive: false,
                    outputDirectory: nil,
                    look: "Stone",
                    strength: 0.8,
                    profiles: [.social1080, .archiveH264],
                    overwrite: nil,
                    continueOnError: nil
                )
            )
        }

        try assertEqual(result.plan.items.count, 0)
        try assertEqual(result.plan.options.overwrite, false)
        try assertEqual(result.plan.options.continueOnError, true)
        if !result.warnings.contains(where: { $0.contains("Skipped non-video source") }) {
            throw AssertionError(description: "Expected still skip warning")
        }
        if !result.warnings.contains(where: { $0.contains("Missing path skipped") }) {
            throw AssertionError(description: "Expected missing path warning")
        }
    }

    runner.test("automation security rejects source paths outside allowed roots") {
        do {
            _ = try waitForAsync {
                try await FilmtoneAutomationCore.inspectSources(
                    FilmtoneAutomationInspectSourcesRequest(
                        paths: ["/etc/passwd"],
                        recursive: false
                    )
                )
            }
            throw AssertionError(description: "Expected sensitive path rejection")
        } catch let error as FilmtoneAutomationSecurityError {
            if !String(describing: error).contains("sensitive path") {
                throw AssertionError(description: "Expected sensitive path error, got \(error)")
            }
        }
    }

    runner.test("automation security rejects unsigned runBatch plans") {
        let item = FilmtoneAutomationBatchItem(
            sourcePath: FileManager.default.temporaryDirectory.appendingPathComponent("in.mov").path,
            outputPath: FileManager.default.temporaryDirectory.appendingPathComponent("out.mp4").path,
            profile: .social1080,
            status: .ready,
            reason: nil,
            sourceDisplaySize: nil,
            outputSize: nil,
            durationSeconds: nil,
            nominalFrameRate: nil,
            hasAudio: nil,
            warnings: []
        )
        let plan = FilmtoneAutomationBatchPlan(
            createdAtIso: "2026-05-15T00:00:00.000Z",
            look: FilmtoneAutomationLookPlan(
                requested: "Stone",
                label: "Stone",
                presetName: FilmtonePresetCatalog.defaultName,
                presetStrength: 1,
                lookSlug: "filmtone-creative-pack-01-stone"
            ),
            profiles: [.social1080],
            options: FilmtoneAutomationBatchOptions(
                overwrite: false,
                continueOnError: true,
                recursive: false
            ),
            items: [item],
            warnings: [],
            security: nil
        )
        do {
            try FilmtoneAutomationSecurityPolicy.validateRunBatchPlan(plan)
            throw AssertionError(description: "Expected unsigned plan rejection")
        } catch FilmtoneAutomationSecurityError.missingPlanSignature {
            return
        }
    }
}

private final class AutomationAsyncBox<T>: @unchecked Sendable {
    var value: T?
}

private func waitForAsync<T>(_ body: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let box = AutomationAsyncBox<Result<T, Error>>()
    Task {
        do {
            box.value = .success(try await body())
        } catch {
            box.value = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    return try box.value!.get()
}
