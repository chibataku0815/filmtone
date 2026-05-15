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

        let result = waitForAsync {
            await FilmtoneAutomationCore.inspectSources(
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

        let result = waitForAsync {
            await FilmtoneAutomationCore.previewBatch(
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
}

private final class AutomationAsyncBox<T>: @unchecked Sendable {
    var value: T?
}

private func waitForAsync<T>(_ body: @escaping () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let box = AutomationAsyncBox<T>()
    Task {
        box.value = await body()
        semaphore.signal()
    }
    semaphore.wait()
    return box.value!
}
