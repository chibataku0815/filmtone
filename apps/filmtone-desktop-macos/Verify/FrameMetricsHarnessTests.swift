import CoreGraphics
import Foundation
import ImageIO

func registerFrameMetricsHarnessTests() {
    runner.test("frame metrics: neutral gray has low stress everywhere") {
        let dir = try makeTempDir("filmtone-metrics-gray")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("gray.png")
        try writeSolidPNG(r: 128, g: 128, b: 128, size: 64, to: url)

        let metrics = FilmtoneFrameMetricsHarness.measure(fileURL: url)

        if !metrics.warnings.isEmpty {
            throw AssertionError(description: "Expected no warnings, got \(metrics.warnings)")
        }
        try expectInRange(metrics.luma.mean, low: 0.35, high: 0.65, "luma mean")
        try expectBelow(metrics.luma.highLumaRatio, threshold: 0.05, "highLumaRatio")
        try expectBelow(metrics.luma.lowLumaRatio, threshold: 0.05, "lowLumaRatio")
        try expectBelow(metrics.blackFloor.veryLowLumaRatio, threshold: 0.05, "blackFloor")
        try expectBelow(metrics.channelCeiling.red, threshold: 0.05, "ceiling.red")
        try expectBelow(metrics.channelCeiling.green, threshold: 0.05, "ceiling.green")
        try expectBelow(metrics.channelCeiling.blue, threshold: 0.05, "ceiling.blue")
        try expectBelow(metrics.chromaStress.meanChannelSpread, threshold: 0.05, "chromaMean")
        try expectBelow(
            metrics.chromaStress.highPercentileChannelSpread,
            threshold: 0.10,
            "chromaP95"
        )
        try assertEqual(metrics.sampledWidth, 64)
        try assertEqual(metrics.sampledHeight, 64)
    }

    runner.test("frame metrics: white clipped pegs luma and channel ceilings") {
        let dir = try makeTempDir("filmtone-metrics-white")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("white.png")
        try writeSolidPNG(r: 255, g: 255, b: 255, size: 64, to: url)

        let metrics = FilmtoneFrameMetricsHarness.measure(fileURL: url)

        try expectAbove(metrics.luma.mean, threshold: 0.95, "luma mean")
        try expectAbove(metrics.luma.highLumaRatio, threshold: 0.95, "highLumaRatio")
        try expectAbove(metrics.channelCeiling.red, threshold: 0.95, "ceiling.red")
        try expectAbove(metrics.channelCeiling.green, threshold: 0.95, "ceiling.green")
        try expectAbove(metrics.channelCeiling.blue, threshold: 0.95, "ceiling.blue")
        try expectBelow(metrics.blackFloor.veryLowLumaRatio, threshold: 0.05, "blackFloor")
    }

    runner.test("frame metrics: saturated red has high chroma stress and only red ceiling") {
        let dir = try makeTempDir("filmtone-metrics-red")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("red.png")
        try writeSolidPNG(r: 255, g: 0, b: 0, size: 64, to: url)

        let metrics = FilmtoneFrameMetricsHarness.measure(fileURL: url)

        try expectAbove(metrics.channelCeiling.red, threshold: 0.95, "ceiling.red")
        try expectBelow(metrics.channelCeiling.green, threshold: 0.05, "ceiling.green")
        try expectBelow(metrics.channelCeiling.blue, threshold: 0.05, "ceiling.blue")
        try expectAbove(metrics.chromaStress.meanChannelSpread, threshold: 0.90, "chromaMean")
        try expectAbove(
            metrics.chromaStress.highPercentileChannelSpread,
            threshold: 0.90,
            "chromaP95"
        )
    }

    runner.test("frame metrics: near-black collapses to low luma and black floor") {
        let dir = try makeTempDir("filmtone-metrics-black")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("black.png")
        try writeSolidPNG(r: 3, g: 3, b: 3, size: 64, to: url)

        let metrics = FilmtoneFrameMetricsHarness.measure(fileURL: url)

        try expectBelow(metrics.luma.mean, threshold: 0.05, "luma mean")
        try expectAbove(metrics.luma.lowLumaRatio, threshold: 0.95, "lowLumaRatio")
        try expectAbove(
            metrics.blackFloor.veryLowLumaRatio,
            threshold: 0.95,
            "blackFloor"
        )
        try expectBelow(metrics.luma.highLumaRatio, threshold: 0.05, "highLumaRatio")
    }

    runner.test("frame metrics: empty file returns emptyImage warning without crashing") {
        let dir = try makeTempDir("filmtone-metrics-empty")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("empty.png")
        try Data().write(to: url)

        let metrics = FilmtoneFrameMetricsHarness.measure(fileURL: url)

        if !metrics.warnings.contains(.emptyImage) {
            throw AssertionError(
                description: "Expected emptyImage warning, got \(metrics.warnings)"
            )
        }
        try assertEqual(metrics.sampledWidth, 0)
        try assertEqual(metrics.sampledHeight, 0)
    }

    runner.test("frame metrics: garbage bytes return a warning without crashing") {
        let dir = try makeTempDir("filmtone-metrics-garbage")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("garbage.png")
        try Data([0x47, 0x41, 0x52, 0x42, 0x41, 0x47, 0x45]).write(to: url)

        let metrics = FilmtoneFrameMetricsHarness.measure(fileURL: url)

        if metrics.warnings.isEmpty {
            throw AssertionError(description: "Expected warning for garbage bytes")
        }
    }

    runner.test("frame metrics: repeat measurement of same file is byte-identical") {
        let dir = try makeTempDir("filmtone-metrics-determinism")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("white.png")
        try writeSolidPNG(r: 255, g: 255, b: 255, size: 64, to: url)

        let first = FilmtoneFrameMetricsHarness.measure(fileURL: url)
        let second = FilmtoneFrameMetricsHarness.measure(fileURL: url)
        try assertEqual(first, second)
    }
}

private func makeTempDir(_ prefix: String) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func writeSolidPNG(r: UInt8, g: UInt8, b: UInt8, size: Int, to url: URL) throws {
    let bytesPerPixel = 4
    let bytesPerRow = size * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * size)
    var idx = 0
    while idx < pixels.count {
        pixels[idx] = r
        pixels[idx + 1] = g
        pixels[idx + 2] = b
        pixels[idx + 3] = 255
        idx += bytesPerPixel
    }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
        throw AssertionError(description: "Failed to create CGDataProvider")
    }
    guard let cgImage = CGImage(
        width: size,
        height: size,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ) else {
        throw AssertionError(description: "Failed to create CGImage")
    }
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, "public.png" as CFString, 1, nil
    ) else {
        throw AssertionError(description: "Failed to create PNG destination")
    }
    CGImageDestinationAddImage(dest, cgImage, nil)
    if !CGImageDestinationFinalize(dest) {
        throw AssertionError(description: "Failed to finalize PNG at \(url.path)")
    }
}

private func expectAbove(_ value: Double, threshold: Double, _ name: String) throws {
    if !(value > threshold) {
        throw AssertionError(
            description: "\(name): expected > \(threshold), got \(value)"
        )
    }
}

private func expectBelow(_ value: Double, threshold: Double, _ name: String) throws {
    if !(value < threshold) {
        throw AssertionError(
            description: "\(name): expected < \(threshold), got \(value)"
        )
    }
}

private func expectInRange(
    _ value: Double, low: Double, high: Double, _ name: String
) throws {
    if value < low || value > high {
        throw AssertionError(
            description: "\(name): expected in [\(low), \(high)], got \(value)"
        )
    }
}
