import Foundation

private enum CaptureTransformLutClassifierTestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

@main
struct CaptureTransformLutClassifierTests {
    static func main() throws {
        try warnsFromFilenameEvenWhenTitleIsHarmless()
        try warnsFromTitleKeyword()
        try warnsFromNeutralRampShape()
        try doesNotWarnForSmallCreativeColorBias()
        print("capture transform LUT classifier tests passed")
    }

    private static func warnsFromFilenameEvenWhenTitleIsHarmless() throws {
        let warning = FilmtoneCaptureTransformLutClassifier.warning(
            title: "Soft Neutral",
            originalFilename: "AppleLog_to_Rec709.cube",
            size: 17,
            data: identityCube(size: 17)
        )
        try expect(warning?.kind == .filenameKeyword, "filename keyword should warn")
        try expect(warning?.matchedSignal != nil, "filename keyword should record matched signal")
    }

    private static func warnsFromTitleKeyword() throws {
        let warning = FilmtoneCaptureTransformLutClassifier.warning(
            title: "Log to Rec709",
            originalFilename: "nice.cube",
            size: 17,
            data: identityCube(size: 17)
        )
        try expect(warning?.kind == .titleKeyword, "title keyword should warn")
    }

    private static func warnsFromNeutralRampShape() throws {
        let warning = FilmtoneCaptureTransformLutClassifier.warning(
            title: "Tone Lift",
            originalFilename: "tone.cube",
            size: 17,
            data: cube(size: 17) { r, g, b in
                let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                let lifted = sqrt(max(0, min(1, luma)))
                return (lifted, lifted, lifted)
            }
        )
        try expect(warning?.kind == .neutralRampShape, "neutral ramp shape should warn")
    }

    private static func doesNotWarnForSmallCreativeColorBias() throws {
        let warning = FilmtoneCaptureTransformLutClassifier.warning(
            title: "Warm Creative",
            originalFilename: "warm-creative.cube",
            size: 17,
            data: cube(size: 17) { r, g, b in
                (
                    min(1, r * 1.02),
                    min(1, g * 0.99),
                    min(1, b * 0.98)
                )
            }
        )
        try expect(warning == nil, "small creative color bias should not warn")
    }

    private static func identityCube(size: Int) -> [Double] {
        cube(size: size) { r, g, b in (r, g, b) }
    }

    private static func cube(
        size: Int,
        transform: (Double, Double, Double) -> (Double, Double, Double)
    ) -> [Double] {
        var data: [Double] = []
        data.reserveCapacity(size * size * size * 3)
        for bIndex in 0..<size {
            for gIndex in 0..<size {
                for rIndex in 0..<size {
                    let divisor = Double(size - 1)
                    let r = Double(rIndex) / divisor
                    let g = Double(gIndex) / divisor
                    let b = Double(bIndex) / divisor
                    let out = transform(r, g, b)
                    data.append(out.0)
                    data.append(out.1)
                    data.append(out.2)
                }
            }
        }
        return data
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw CaptureTransformLutClassifierTestFailure.failed(message)
        }
    }
}
