import Foundation

struct FilmtoneCaptureTransformLutWarning: Equatable, Codable {
    enum Kind: String, Codable {
        case filenameKeyword
        case titleKeyword
        case neutralRampShape
    }

    let kind: Kind
    let matchedSignal: String?
    let message: String
}

enum FilmtoneCaptureTransformLutClassifier {
    static func warning(
        title: String,
        originalFilename: String?,
        size: Int,
        data: [Double]
    ) -> FilmtoneCaptureTransformLutWarning? {
        if let filenameMatch = keywordMatch(in: originalFilename ?? "") {
            return FilmtoneCaptureTransformLutWarning(
                kind: .filenameKeyword,
                matchedSignal: filenameMatch,
                message: transformWarningMessage
            )
        }

        if let titleMatch = keywordMatch(in: title) {
            return FilmtoneCaptureTransformLutWarning(
                kind: .titleKeyword,
                matchedSignal: titleMatch,
                message: transformWarningMessage
            )
        }

        if neutralRampLooksTransformLike(size: size, data: data) {
            return FilmtoneCaptureTransformLutWarning(
                kind: .neutralRampShape,
                matchedSignal: "neutral-ramp",
                message: neutralRampWarningMessage
            )
        }

        return nil
    }

    static func warningReason(
        title: String,
        originalFilename: String?,
        size: Int,
        data: [Double]
    ) -> String? {
        warning(
            title: title,
            originalFilename: originalFilename,
            size: size,
            data: data
        )?.message
    }

    private static let transformWarningMessage =
        "FilmtoneはApple Log 2からの変換を先に行います。このLUTがLog変換用の場合、二重変換になり色が破綻する可能性があります。"

    private static let neutralRampWarningMessage =
        "このLUTはニュートラルな階調を大きく変換しています。Log変換用LUTの場合、Filmtone側の変換と二重にかかり色が破綻する可能性があります。"

    private static let strongSignals = [
        "log-to", "log to", "logtorec", "to-rec", "to rec", "torec", "log2rec",
        "conversion", "convert", "transform", "technical",
        "input", "idt", "odt", "output transform"
    ]

    private static let sourceSignals = [
        "slog", "s-log", "s log", "slog3", "s-log3", "s log3",
        "vlog", "v-log", "v log", "dlog", "d-log", "d log",
        "clog", "c-log", "c log", "logc", "log-c", "log c",
        "apple log", "arri", "alexa", "aces"
    ]

    private static let displaySignals = [
        "rec709", "rec.709", "rec 709", "709"
    ]

    private static func keywordMatch(in text: String) -> String? {
        let variants = normalizedVariants(for: text)
        guard !variants.isEmpty else { return nil }

        if let signal = strongSignals.first(where: { contains($0, in: variants) }) {
            return signal
        }

        let source = sourceSignals.first(where: { contains($0, in: variants) })
        let display = displaySignals.first(where: { contains($0, in: variants) })
        if let source, let display {
            return "\(source)+\(display)"
        }

        return nil
    }

    private static func normalizedVariants(for text: String) -> [String] {
        let lower = text.lowercased()
        guard !lower.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let spaced = lower.replacingOccurrences(
            of: #"[_\-.]+"#,
            with: " ",
            options: .regularExpression
        )
        let compact = lower.filter { $0.isLetter || $0.isNumber }
        return [lower, spaced, compact]
    }

    private static func contains(_ signal: String, in variants: [String]) -> Bool {
        let signalVariants = normalizedVariants(for: signal)
        return variants.contains { variant in
            signalVariants.contains { signalVariant in
                variant.contains(signalVariant)
            }
        }
    }

    private static func neutralRampLooksTransformLike(size: Int, data: [Double]) -> Bool {
        let samples = [0.18, 0.5, 0.9].compactMap {
            sampleNeutral(size: size, data: data, at: $0)
        }
        guard samples.count == 3 else { return false }

        var neutralPreservingCount = 0
        var largeToneMoveCount = 0
        for sample in samples {
            let maxChannel = max(sample.r, max(sample.g, sample.b))
            let minChannel = min(sample.r, min(sample.g, sample.b))
            if maxChannel - minChannel < 0.04 {
                neutralPreservingCount += 1
            }
            if abs(sample.luma - sample.input) > 0.14 {
                largeToneMoveCount += 1
            }
        }
        return neutralPreservingCount >= 2 && largeToneMoveCount >= 2
    }

    private static func sampleNeutral(
        size: Int,
        data: [Double],
        at value: Double
    ) -> (input: Double, r: Double, g: Double, b: Double, luma: Double)? {
        guard size > 1 else { return nil }
        let clamped = min(1, max(0, value))
        let index = Int((clamped * Double(size - 1)).rounded())
        let offset = ((index * size * size) + (index * size) + index) * 3
        guard offset + 2 < data.count else { return nil }
        let r = data[offset]
        let g = data[offset + 1]
        let b = data[offset + 2]
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return (clamped, r, g, b, luma)
    }
}
