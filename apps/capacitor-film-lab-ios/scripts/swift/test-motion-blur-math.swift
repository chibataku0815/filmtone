import Foundation

private struct MotionBlurMathError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw MotionBlurMathError(message: message)
    }
}

private func approx(_ a: Double, _ b: Double, _ eps: Double = 1e-9) -> Bool {
    abs(a - b) < eps
}

@main
struct MotionBlurMathTests {
    static func main() throws {
        try baselineDoesNotActivate()
        try threeSixtyUsesTwoFrameTriangle()
        try sevenTwentyUsesSlowShutterExtension()
        print("motion blur math tests passed")
    }

    private static func baselineDoesNotActivate() throws {
        for shutterAngle in [0.0, 180.0] {
            try expect(
                !FilmtoneMotionBlurMath.isActive(shutterAngle: shutterAngle),
                "\(shutterAngle) should not activate motion blur"
            )
            try expect(
                FilmtoneMotionBlurMath.activeFrameCount(shutterAngle: shutterAngle) == 1,
                "\(shutterAngle) should resolve to a single pass-through frame"
            )
            let weights = FilmtoneMotionBlurMath.blendWeights(
                shutterAngle: shutterAngle,
                activeFrames: 1,
                validSlots: 8
            )
            try expect(weights[0] == 1, "\(shutterAngle) newest weight should be 1")
            try expect(weights.dropFirst().allSatisfy { $0 == 0 }, "\(shutterAngle) stale weights should be 0")
        }
    }

    private static func threeSixtyUsesTwoFrameTriangle() throws {
        let activeFrames = FilmtoneMotionBlurMath.activeFrameCount(shutterAngle: 360)
        try expect(FilmtoneMotionBlurMath.isActive(shutterAngle: 360), "360 should activate motion blur")
        try expect(activeFrames == 2, "360 should use 2 frames")
        let weights = FilmtoneMotionBlurMath.blendWeights(
            shutterAngle: 360,
            activeFrames: activeFrames,
            validSlots: 8
        )
        try expect(approx(weights[0], 2.0 / 3.0), "360 newest weight should be 2/3")
        try expect(approx(weights[1], 1.0 / 3.0), "360 previous weight should be 1/3")
        try expect(weights.dropFirst(2).allSatisfy { $0 == 0 }, "360 should not read older slots")
    }

    private static func sevenTwentyUsesSlowShutterExtension() throws {
        let activeFrames = FilmtoneMotionBlurMath.activeFrameCount(shutterAngle: 720)
        try expect(FilmtoneMotionBlurMath.isActive(shutterAngle: 720), "720 should activate motion blur")
        try expect(activeFrames == 6, "720 should use 6 frames")
        let weights = FilmtoneMotionBlurMath.blendWeights(
            shutterAngle: 720,
            activeFrames: activeFrames,
            validSlots: 8
        )
        for index in 0..<6 {
            try expect(approx(weights[index], 1.0 / 6.0), "720 weight \(index) should be 1/6")
        }
        try expect(weights.dropFirst(6).allSatisfy { $0 == 0 }, "720 should not read slots 6 and 7")
    }
}
