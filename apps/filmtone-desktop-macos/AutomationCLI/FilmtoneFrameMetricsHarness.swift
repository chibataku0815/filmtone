import CoreGraphics
import Foundation
import ImageIO

// Long-edge cap for deterministic sampling. 320 keeps the buffer small
// enough to walk every pixel in tests without dominating Verify runtime,
// while still capturing enough spatial signal for stress metrics.
let kFilmtoneFrameMetricsLongEdgeCap: Int = 320

private let kFilmtoneFrameMetricsHighLumaThreshold: Double = 0.95
private let kFilmtoneFrameMetricsLowLumaThreshold: Double = 0.05
private let kFilmtoneFrameMetricsBlackFloorThreshold: Double = 0.02
private let kFilmtoneFrameMetricsChannelCeilingThreshold: Double = 0.95
private let kFilmtoneFrameMetricsHighPercentile: Double = 0.95

struct FilmtoneFrameMetricsLumaSummary: Equatable {
    var min: Double
    var max: Double
    var mean: Double
    var highLumaRatio: Double
    var lowLumaRatio: Double
}

struct FilmtoneFrameMetricsChannelCeilingRatios: Equatable {
    var red: Double
    var green: Double
    var blue: Double
}

struct FilmtoneFrameMetricsChromaStress: Equatable {
    var meanChannelSpread: Double
    var highPercentileChannelSpread: Double
}

struct FilmtoneFrameMetricsBlackFloor: Equatable {
    var veryLowLumaRatio: Double
}

enum FilmtoneFrameMetricsWarning: String, Equatable {
    case emptyImage
    case unreadableImage
    case unsupportedPixelFormat
}

struct FilmtoneFrameMetrics: Equatable {
    var luma: FilmtoneFrameMetricsLumaSummary
    var channelCeiling: FilmtoneFrameMetricsChannelCeilingRatios
    var chromaStress: FilmtoneFrameMetricsChromaStress
    var blackFloor: FilmtoneFrameMetricsBlackFloor
    var sampledWidth: Int
    var sampledHeight: Int
    var warnings: [FilmtoneFrameMetricsWarning]

    static let zero = FilmtoneFrameMetrics(
        luma: FilmtoneFrameMetricsLumaSummary(
            min: 0, max: 0, mean: 0, highLumaRatio: 0, lowLumaRatio: 0
        ),
        channelCeiling: FilmtoneFrameMetricsChannelCeilingRatios(
            red: 0, green: 0, blue: 0
        ),
        chromaStress: FilmtoneFrameMetricsChromaStress(
            meanChannelSpread: 0, highPercentileChannelSpread: 0
        ),
        blackFloor: FilmtoneFrameMetricsBlackFloor(veryLowLumaRatio: 0),
        sampledWidth: 0,
        sampledHeight: 0,
        warnings: []
    )
}

enum FilmtoneFrameMetricsHarness {
    static func measure(fileURL: URL) -> FilmtoneFrameMetrics {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size = (attrs?[.size] as? NSNumber)?.intValue ?? -1
        if size == 0 {
            var z = FilmtoneFrameMetrics.zero
            z.warnings = [.emptyImage]
            return z
        }
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            var z = FilmtoneFrameMetrics.zero
            z.warnings = [.unreadableImage]
            return z
        }
        guard CGImageSourceGetCount(source) > 0 else {
            var z = FilmtoneFrameMetrics.zero
            z.warnings = [.emptyImage]
            return z
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            var z = FilmtoneFrameMetrics.zero
            z.warnings = [.unreadableImage]
            return z
        }
        return measure(cgImage: cgImage)
    }

    static func measure(cgImage: CGImage) -> FilmtoneFrameMetrics {
        let srcW = cgImage.width
        let srcH = cgImage.height
        if srcW <= 0 || srcH <= 0 {
            var z = FilmtoneFrameMetrics.zero
            z.warnings = [.emptyImage]
            return z
        }

        let cap = kFilmtoneFrameMetricsLongEdgeCap
        let scale: Double
        if srcW >= srcH {
            scale = min(1.0, Double(cap) / Double(srcW))
        } else {
            scale = min(1.0, Double(cap) / Double(srcH))
        }
        let dstW = max(1, Int((Double(srcW) * scale).rounded()))
        let dstH = max(1, Int((Double(srcH) * scale).rounded()))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = dstW * bytesPerPixel
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
        ).rawValue

        guard let ctx = CGContext(
            data: nil,
            width: dstW,
            height: dstH,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            var z = FilmtoneFrameMetrics.zero
            z.sampledWidth = dstW
            z.sampledHeight = dstH
            z.warnings = [.unsupportedPixelFormat]
            return z
        }

        // Nearest-neighbor render keeps pixel statistics deterministic across
        // hosts; Filmtone's metrics care about distribution, not sharpness.
        ctx.interpolationQuality = .none
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: dstW, height: dstH))

        guard let buffer = ctx.data else {
            var z = FilmtoneFrameMetrics.zero
            z.sampledWidth = dstW
            z.sampledHeight = dstH
            z.warnings = [.unsupportedPixelFormat]
            return z
        }
        let p = buffer.bindMemory(to: UInt8.self, capacity: bytesPerRow * dstH)

        let totalPixels = dstW * dstH
        if totalPixels == 0 {
            var z = FilmtoneFrameMetrics.zero
            z.sampledWidth = dstW
            z.sampledHeight = dstH
            z.warnings = [.emptyImage]
            return z
        }

        var lumaMinByte = 255
        var lumaMaxByte = 0
        var lumaSum = 0
        var highLumaCount = 0
        var lowLumaCount = 0
        var blackFloorCount = 0
        var redCeilingCount = 0
        var greenCeilingCount = 0
        var blueCeilingCount = 0
        var chromaSpreadSum = 0
        var spreadHistogram = [Int](repeating: 0, count: 256)

        let highByte = Int((kFilmtoneFrameMetricsHighLumaThreshold * 255.0).rounded())
        let lowByte = Int((kFilmtoneFrameMetricsLowLumaThreshold * 255.0).rounded())
        let blackByte = Int(
            (kFilmtoneFrameMetricsBlackFloorThreshold * 255.0).rounded()
        )
        let ceilingByte = Int(
            (kFilmtoneFrameMetricsChannelCeilingThreshold * 255.0).rounded()
        )

        for row in 0..<dstH {
            let rowStart = row * bytesPerRow
            var col = 0
            while col < dstW {
                let offset = rowStart + col * bytesPerPixel
                let r = Int(p[offset])
                let g = Int(p[offset + 1])
                let b = Int(p[offset + 2])
                // Rec.709 luma with SDR coefficients, scaled by 10000 to keep
                // the per-pixel math in integer space.
                let lumaByte = (2126 * r + 7152 * g + 722 * b) / 10000
                if lumaByte < lumaMinByte { lumaMinByte = lumaByte }
                if lumaByte > lumaMaxByte { lumaMaxByte = lumaByte }
                lumaSum += lumaByte
                if lumaByte >= highByte { highLumaCount += 1 }
                if lumaByte <= lowByte { lowLumaCount += 1 }
                if lumaByte <= blackByte { blackFloorCount += 1 }
                if r >= ceilingByte { redCeilingCount += 1 }
                if g >= ceilingByte { greenCeilingCount += 1 }
                if b >= ceilingByte { blueCeilingCount += 1 }
                let maxCh = max(r, max(g, b))
                let minCh = min(r, min(g, b))
                let spread = maxCh - minCh
                spreadHistogram[spread] += 1
                chromaSpreadSum += spread
                col += 1
            }
        }

        let n = Double(totalPixels)
        let p95Target = Int(
            (kFilmtoneFrameMetricsHighPercentile * Double(totalPixels)).rounded()
        )
        var cumulative = 0
        var p95Bin = 0
        for bin in 0..<256 {
            cumulative += spreadHistogram[bin]
            if cumulative >= p95Target {
                p95Bin = bin
                break
            }
        }

        return FilmtoneFrameMetrics(
            luma: FilmtoneFrameMetricsLumaSummary(
                min: Double(lumaMinByte) / 255.0,
                max: Double(lumaMaxByte) / 255.0,
                mean: Double(lumaSum) / (n * 255.0),
                highLumaRatio: Double(highLumaCount) / n,
                lowLumaRatio: Double(lowLumaCount) / n
            ),
            channelCeiling: FilmtoneFrameMetricsChannelCeilingRatios(
                red: Double(redCeilingCount) / n,
                green: Double(greenCeilingCount) / n,
                blue: Double(blueCeilingCount) / n
            ),
            chromaStress: FilmtoneFrameMetricsChromaStress(
                meanChannelSpread: Double(chromaSpreadSum) / (n * 255.0),
                highPercentileChannelSpread: Double(p95Bin) / 255.0
            ),
            blackFloor: FilmtoneFrameMetricsBlackFloor(
                veryLowLumaRatio: Double(blackFloorCount) / n
            ),
            sampledWidth: dstW,
            sampledHeight: dstH,
            warnings: []
        )
    }
}
