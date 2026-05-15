import Foundation

struct FilmtoneAutomationSuccess<T: Encodable>: Encodable {
    let ok: Bool
    let result: T

    init(_ result: T) {
        self.ok = true
        self.result = result
    }
}

struct FilmtoneAutomationFailure: Encodable {
    let ok: Bool = false
    let error: FilmtoneAutomationErrorPayload
}

struct FilmtoneAutomationErrorPayload: Encodable {
    let code: String
    let message: String
}

struct FilmtoneAutomationEvent<T: Encodable>: Encodable {
    let event: String
    let payload: T
}

struct FilmtoneAutomationJobStarted: Encodable {
    let totalItems: Int
    let readyItems: Int
}

struct FilmtoneAutomationItemStarted: Encodable {
    let index: Int
    let sourcePath: String
    let outputPath: String
    let profile: FilmtoneAutomationExportProfile
}

struct FilmtoneAutomationItemProgress: Encodable {
    let index: Int
    let sourcePath: String
    let outputPath: String
    let processedFrames: Int
    let estimatedTotalFrames: Int
    let normalized: Double
}

struct FilmtoneAutomationItemFinished: Encodable {
    let index: Int
    let sourcePath: String
    let outputPath: String
    let sidecarPath: String?
    let processedFrames: Int
    let outputSize: FilmtoneAutomationDimensions
    let audioPreserved: Bool
}

struct FilmtoneAutomationItemFailed: Encodable {
    let index: Int
    let sourcePath: String
    let outputPath: String
    let message: String
}

struct FilmtoneAutomationJobFinished: Encodable {
    let succeeded: Int
    let failed: Int
    let skipped: Int
}

@main
enum FilmtoneAutomationCLI {
    static func main() async {
        let decoder = JSONDecoder()
        do {
            let input = FileHandle.standardInput.readDataToEndOfFile()
            let envelope = try decoder.decode(FilmtoneAutomationEnvelope.self, from: input)
            switch envelope.command {
            case .inspectSources:
                guard let request = envelope.inspectSources else {
                    throw CLIError.missingPayload("inspectSources")
                }
                let result = try await FilmtoneAutomationCore.inspectSources(request)
                try writeJSON(FilmtoneAutomationSuccess(result))
            case .answerContext:
                guard let request = envelope.answerContext else {
                    throw CLIError.missingPayload("answerContext")
                }
                let result = try await FilmtoneAutomationCore.answerContext(request)
                try writeJSON(FilmtoneAutomationSuccess(result))
            case .previewBatch:
                guard let request = envelope.previewBatch else {
                    throw CLIError.missingPayload("previewBatch")
                }
                let result = try await FilmtoneAutomationCore.previewBatch(request)
                try writeJSON(FilmtoneAutomationSuccess(result))
            case .runBatch:
                guard let request = envelope.runBatch else {
                    throw CLIError.missingPayload("runBatch")
                }
                try await runBatch(request)
            }
        } catch {
            let payload = friendlyErrorPayload(for: error)
            try? writeJSON(FilmtoneAutomationFailure(error: payload))
            Foundation.exit(1)
        }
    }

    private static func runBatch(_ request: FilmtoneAutomationRunBatchRequest) async throws {
        try FilmtoneAutomationSecurityPolicy.validateRunBatchPlan(request.plan)
        let overwrite = request.overwrite ?? request.plan.options.overwrite
        let continueOnError = request.continueOnError ?? request.plan.options.continueOnError
        let runnableItems = request.plan.items.enumerated().filter { _, item in
            item.status == .ready
        }
        try writeJSONLine(FilmtoneAutomationEvent(
            event: "jobStarted",
            payload: FilmtoneAutomationJobStarted(
                totalItems: request.plan.items.count,
                readyItems: runnableItems.count
            )
        ))

        var succeeded = 0
        var failed = 0
        var skipped = request.plan.items.count - runnableItems.count

        for (index, item) in runnableItems {
            if FileManager.default.fileExists(atPath: item.outputPath), !overwrite {
                skipped += 1
                try writeJSONLine(FilmtoneAutomationEvent(
                    event: "itemFailed",
                    payload: FilmtoneAutomationItemFailed(
                        index: index,
                        sourcePath: item.sourcePath,
                        outputPath: item.outputPath,
                        message: "Output already exists and overwrite is false."
                    )
                ))
                if !continueOnError { break }
                continue
            }

            try writeJSONLine(FilmtoneAutomationEvent(
                event: "itemStarted",
                payload: FilmtoneAutomationItemStarted(
                    index: index,
                    sourcePath: item.sourcePath,
                    outputPath: item.outputPath,
                    profile: item.profile
                )
            ))

            do {
                let exportRequest = FilmtoneAutomationCore.exportRequest(for: item, in: request.plan)
                let result = try await FilmtoneVideoExporter.export(exportRequest) { progress in
                    try? writeJSONLine(FilmtoneAutomationEvent(
                        event: "itemProgress",
                        payload: FilmtoneAutomationItemProgress(
                            index: index,
                            sourcePath: item.sourcePath,
                            outputPath: item.outputPath,
                            processedFrames: progress.processedFrames,
                            estimatedTotalFrames: progress.estimatedTotalFrames,
                            normalized: progress.normalized
                        )
                    ))
                }
                succeeded += 1
                try writeJSONLine(FilmtoneAutomationEvent(
                    event: "itemFinished",
                    payload: FilmtoneAutomationItemFinished(
                        index: index,
                        sourcePath: item.sourcePath,
                        outputPath: item.outputPath,
                        sidecarPath: result.sidecarURL?.path,
                        processedFrames: result.processedFrames,
                        outputSize: FilmtoneAutomationDimensions(
                            width: result.outputWidth,
                            height: result.outputHeight
                        ),
                        audioPreserved: result.audioPreserved
                    )
                ))
            } catch {
                failed += 1
                try writeJSONLine(FilmtoneAutomationEvent(
                    event: "itemFailed",
                    payload: FilmtoneAutomationItemFailed(
                        index: index,
                        sourcePath: item.sourcePath,
                        outputPath: item.outputPath,
                        message: String(describing: error)
                    )
                ))
                if !continueOnError { break }
            }
        }

        try writeJSONLine(FilmtoneAutomationEvent(
            event: "jobFinished",
            payload: FilmtoneAutomationJobFinished(
                succeeded: succeeded,
                failed: failed,
                skipped: skipped
            )
        ))
    }

    private static func writeJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func writeJSONLine<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func friendlyErrorPayload(for error: Error) -> FilmtoneAutomationErrorPayload {
        if case let DecodingError.dataCorrupted(context) = error,
           let payload = unsupportedProfilePayload(from: context) {
            return payload
        }
        return FilmtoneAutomationErrorPayload(
            code: "automation_cli_error",
            message: String(describing: error)
        )
    }

    private static func unsupportedProfilePayload(
        from context: DecodingError.Context
    ) -> FilmtoneAutomationErrorPayload? {
        let codingPath = context.codingPath
            .map(\.stringValue)
            .joined(separator: ".")
        let description = context.debugDescription
        guard codingPath.contains("profiles")
            || description.contains("FilmtoneAutomationExportProfile")
        else {
            return nil
        }

        let requested = invalidStringValue(from: description)
        let subject = requested.map { "Unsupported export profile '\($0)'." }
            ?? "Unsupported export profile."
        return FilmtoneAutomationErrorPayload(
            code: "unsupported_export_profile",
            message: "\(subject) v1 supports social1080 and archiveH264 only. ProRes, HEVC, and cloud upload are not supported yet."
        )
    }

    private static func invalidStringValue(from description: String) -> String? {
        let marker = "invalid String value "
        guard let range = description.range(of: marker) else {
            return nil
        }
        let tail = description[range.upperBound...]
        let value = tail.prefix { character in
            !character.isWhitespace && character != "."
        }
        return value.isEmpty ? nil : String(value)
    }
}

enum CLIError: Error, CustomStringConvertible {
    case missingPayload(String)

    var description: String {
        switch self {
        case .missingPayload(let command):
            return "Missing payload for \(command)"
        }
    }
}
