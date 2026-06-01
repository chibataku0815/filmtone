import AppKit
import CoreImage
import Foundation

private struct ProbeCase {
    let name: String
    let dust: Double
    let scratch: Double
}

private struct TemporalSample {
    let name: String
    let timeSeconds: Double
    let sourceSeed: Double
}

private enum ProbePlate: String, CaseIterable {
    case dark
    case midtone
    case bright
}

private let cases: [ProbeCase] = [
    .init(name: "none", dust: 0.0, scratch: 0.0),
    .init(name: "default", dust: 0.20, scratch: 0.16),
    .init(name: "strong", dust: 0.52, scratch: 0.56),
    .init(name: "dust-only-strong", dust: 0.80, scratch: 0.0),
    .init(name: "scratch-only-strong", dust: 0.0, scratch: 0.80),
    .init(name: "stress", dust: 1.0, scratch: 1.0),
]

private let tileWidth = 320
private let tileHeight = 180
private let labelHeight = 34
private let gap = 12
private let defaultTimeSeconds = 1.25
private let defaultSourceSeed = 0.43

private let temporalSamples: [TemporalSample] = [
    .init(name: "t0.00", timeSeconds: 0.00, sourceSeed: defaultSourceSeed),
    .init(name: "t0.02", timeSeconds: 1.0 / 48.0, sourceSeed: defaultSourceSeed),
    .init(name: "t0.04", timeSeconds: 1.0 / 24.0, sourceSeed: defaultSourceSeed),
    .init(name: "t0.08", timeSeconds: 2.0 / 24.0, sourceSeed: defaultSourceSeed),
    .init(name: "t0.12", timeSeconds: 3.0 / 24.0, sourceSeed: defaultSourceSeed),
    .init(name: "t0.25", timeSeconds: 0.25, sourceSeed: defaultSourceSeed),
    .init(name: "t0.50", timeSeconds: 0.50, sourceSeed: defaultSourceSeed),
    .init(name: "t0.75", timeSeconds: 0.75, sourceSeed: defaultSourceSeed),
]

private func clampByte(_ value: Double) -> UInt8 {
    UInt8(max(0, min(255, Int(round(value * 255.0)))))
}

private func makePlate(_ plate: ProbePlate, width: Int, height: Int) -> CGImage {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
        let ny = Double(y) / Double(max(1, height - 1))
        for x in 0..<width {
            let nx = Double(x) / Double(max(1, width - 1))
            let wave = sin(nx * 9.0 + ny * 4.0) * 0.025 + cos(ny * 11.0) * 0.018
            let vignette = max(0.0, min(1.0, hypot(nx - 0.5, ny - 0.5) * 1.45))
            let stripe = ((x / 42) % 2 == 0) ? 0.018 : -0.012
            var r: Double
            var g: Double
            var b: Double
            switch plate {
            case .dark:
                r = 0.085 + nx * 0.12 + ny * 0.045 + wave + stripe
                g = 0.080 + nx * 0.10 + ny * 0.040 + wave * 0.8
                b = 0.090 + nx * 0.08 + ny * 0.050 + wave * 0.6
            case .midtone:
                r = 0.34 + nx * 0.20 + ny * 0.08 + wave + stripe
                g = 0.32 + nx * 0.17 + ny * 0.07 + wave * 0.85
                b = 0.29 + nx * 0.14 + ny * 0.09 + wave * 0.7
            case .bright:
                r = 0.68 + nx * 0.16 + ny * 0.08 + wave * 0.55
                g = 0.72 + nx * 0.14 + ny * 0.07 + wave * 0.48
                b = 0.76 + nx * 0.15 + ny * 0.10 + wave * 0.42
            }
            r -= vignette * 0.055
            g -= vignette * 0.052
            b -= vignette * 0.050
            let idx = (y * width + x) * 4
            pixels[idx] = clampByte(r)
            pixels[idx + 1] = clampByte(g)
            pixels[idx + 2] = clampByte(b)
            pixels[idx + 3] = 255
        }
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )!
}

private func renderCase(
    _ probeCase: ProbeCase,
    plate: CGImage,
    context: CIContext,
    timeSeconds: Double = defaultTimeSeconds,
    sourceSeed: Double = defaultSourceSeed
) throws -> CGImage {
    let extent = CGRect(x: 0, y: 0, width: tileWidth, height: tileHeight)
    let input = CIImage(cgImage: plate).cropped(to: extent)
    let output: CIImage
    if probeCase.dust <= 0.0001 && probeCase.scratch <= 0.0001 {
        output = input
    } else {
        guard let kernel = FilmtoneGradeKernels.filmDamage else {
            throw NSError(
                domain: "FilmDamageVisualProbe",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "filmDamage kernel failed to compile"]
            )
        }
        guard let applied = kernel.apply(
            extent: extent,
            arguments: [
                input,
                probeCase.dust,
                probeCase.scratch,
                timeSeconds,
                sourceSeed,
                CIVector(x: 0, y: 0),
                CIVector(x: CGFloat(tileWidth), y: CGFloat(tileHeight)),
            ]
        ) else {
            throw NSError(
                domain: "FilmDamageVisualProbe",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "filmDamage kernel failed to apply"]
            )
        }
        output = applied
    }
    guard let image = context.createCGImage(output, from: extent) else {
        throw NSError(
            domain: "FilmDamageVisualProbe",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "filmDamage output failed to render"]
        )
    }
    return image
}

private func drawText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
    NSString(string: text).draw(in: rect, withAttributes: attributes)
}

private func makeContactSheet(
    plateName: String,
    images: [(ProbeCase, CGImage)]
) -> NSBitmapImageRep {
    let width = cases.count * tileWidth + (cases.count + 1) * gap
    let height = tileHeight + labelHeight + gap * 3
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let cg = graphics.cgContext
    cg.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 1).cgColor)
    cg.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: NSColor.white,
    ]
    let labelAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.88, alpha: 1),
    ]
    drawText(
        "Film Damage monochrome physical proof - \(plateName) plate - t=\(defaultTimeSeconds), seed=\(defaultSourceSeed)",
        in: CGRect(x: gap, y: height - gap - 20, width: width - gap * 2, height: 20),
        attributes: titleAttrs
    )

    for (index, pair) in images.enumerated() {
        let x = gap + index * (tileWidth + gap)
        let imageRect = CGRect(x: x, y: gap, width: tileWidth, height: tileHeight)
        cg.draw(pair.1, in: imageRect)
        let label = "\(pair.0.name)  d:\(pair.0.dust) s:\(pair.0.scratch)"
        drawText(
            label,
            in: CGRect(x: x, y: gap + tileHeight + 6, width: tileWidth, height: 18),
            attributes: labelAttrs
        )
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

private func makeTemporalContactSheet(
    plateName: String,
    probeCase: ProbeCase,
    images: [(TemporalSample, CGImage)]
) -> NSBitmapImageRep {
    let width = images.count * tileWidth + (images.count + 1) * gap
    let height = tileHeight + labelHeight + gap * 3
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let cg = graphics.cgContext
    cg.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 1).cgColor)
    cg.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: NSColor.white,
    ]
    let labelAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.88, alpha: 1),
    ]
    drawText(
        "Film Damage monochrome physical temporal proof - \(plateName) plate - \(probeCase.name) d:\(probeCase.dust) s:\(probeCase.scratch)",
        in: CGRect(x: gap, y: height - gap - 20, width: width - gap * 2, height: 20),
        attributes: titleAttrs
    )

    for (index, pair) in images.enumerated() {
        let x = gap + index * (tileWidth + gap)
        let imageRect = CGRect(x: x, y: gap, width: tileWidth, height: tileHeight)
        cg.draw(pair.1, in: imageRect)
        drawText(
            pair.0.name,
            in: CGRect(x: x, y: gap + tileHeight + 6, width: tileWidth, height: 18),
            attributes: labelAttrs
        )
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

@main
private struct FilmDamageVisualProbe {
    static func main() throws {
        let arguments = CommandLine.arguments
        let outputRoot = arguments.count > 1
            ? URL(fileURLWithPath: arguments[1], isDirectory: true)
            : URL(fileURLWithPath: "docs/filmtone/desktop/native-desktop-v2/artifacts/film-damage-visual-probe", isDirectory: true)
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)

        let context = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
        for plate in ProbePlate.allCases {
            let source = makePlate(plate, width: tileWidth, height: tileHeight)
            let rendered = try cases.map { probeCase in
                (probeCase, try renderCase(probeCase, plate: source, context: context))
            }
            let sheet = makeContactSheet(plateName: plate.rawValue, images: rendered)
            let pngData = sheet.representation(using: .png, properties: [:])!
            let url = outputRoot.appendingPathComponent("film-damage-current-\(plate.rawValue).png")
            try pngData.write(to: url)
            print(url.path)
        }

        let temporalSource = makePlate(.midtone, width: tileWidth, height: tileHeight)
        for probeCase in [cases[2], cases[3], cases[4]] {
            let rendered = try temporalSamples.map { sample in
                (
                    sample,
                    try renderCase(
                        probeCase,
                        plate: temporalSource,
                        context: context,
                        timeSeconds: sample.timeSeconds,
                        sourceSeed: sample.sourceSeed
                    )
                )
            }
            let sheet = makeTemporalContactSheet(plateName: ProbePlate.midtone.rawValue, probeCase: probeCase, images: rendered)
            let pngData = sheet.representation(using: .png, properties: [:])!
            let url = outputRoot.appendingPathComponent("film-damage-temporal-\(probeCase.name).png")
            try pngData.write(to: url)
            print(url.path)
        }
    }
}
