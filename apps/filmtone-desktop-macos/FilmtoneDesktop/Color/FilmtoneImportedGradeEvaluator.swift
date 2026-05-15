import CryptoKit
import FilmLabSwiftCore
import Foundation

struct FilmtoneImportedGradeEvaluation: Sendable, Equatable {
    let params: FilmtonePhase0Params
    let creativeLut: PreparedCreativeLut?
    let lutIntensity: Double
    let unsupportedMetadata: [String]
}

enum FilmtoneImportedGradeEvaluator {
    static func evaluate(
        look: FilmtoneImportedGradeLook,
        controlOverrides: [String: Double] = [:],
        sidecarURL: URL? = nil
    ) -> FilmtoneImportedGradeEvaluation {
        var params = FilmtonePhase0Generated.resetParams
        var unsupported = look.unsupportedMetadata

        for control in look.preLutControls {
            let value = control.clamped(controlOverrides[control.id])
            if let paramKey = phase0ParamKey(for: control), FilmtonePhase0Params.keyPaths[paramKey] != nil {
                params.setValue(value, for: paramKey)
            } else {
                unsupported.append("unsupported preLut operation: \(control.operation)")
            }
        }

        let baseLut = loadBaseLut(look: look, sidecarURL: sidecarURL)
        var lutIntensity = defaultLutIntensity(look.baseLook)
        for control in look.postLutControls {
            let value = control.clamped(controlOverrides[control.id])
            if control.operation == "cubeIntensity" {
                lutIntensity = clamp01(value)
            } else {
                unsupported.append("unsupported postLut operation: \(control.operation)")
            }
        }

        if let sourceGraph = look.sourceGraph {
            unsupported.append(contentsOf: sourceGraph.unsupportedNotes)
            if sourceGraph.decoded, sourceGraph.approximateNodeCount == 0, look.preLutControls.isEmpty {
                unsupported.append("graph-only imported grade")
            }
        }

        return FilmtoneImportedGradeEvaluation(
            params: params,
            creativeLut: baseLut,
            lutIntensity: lutIntensity,
            unsupportedMetadata: Array(Set(unsupported)).sorted()
        )
    }

    static func evaluationOrderKeys(look: FilmtoneImportedGradeLook) -> [String] {
        look.preLutControls.map(\.id) + look.postLutControls.map(\.id)
    }

    private static func phase0ParamKey(for control: FilmtoneImportedGradeControl) -> String? {
        if let paramKey = control.paramKey {
            return paramKey
        }
        switch control.operation {
        case "logExposure": return "exposure"
        case "logTemperature": return "temperature"
        case "logTint": return "tint"
        case "logContrast": return "contrast"
        case "logSaturation": return "saturation"
        default: return nil
        }
    }

    private static func defaultLutIntensity(_ baseLook: FilmtoneImportedGradeLook.BaseLook) -> Double {
        if case .cube(_, _, let intensity, _) = baseLook {
            return clamp01(intensity)
        }
        return 1.0
    }

    private static func clamp01(_ value: Double) -> Double {
        max(0, min(1, value.isFinite ? value : 1))
    }

    private static func loadBaseLut(
        look: FilmtoneImportedGradeLook,
        sidecarURL: URL?
    ) -> PreparedCreativeLut? {
        guard case .cube(let path, let size, let intensity, let sourceHash) = look.baseLook else {
            return nil
        }
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else if let sidecarURL {
            url = sidecarURL.deletingLastPathComponent().appendingPathComponent(path)
        } else {
            url = URL(fileURLWithPath: path)
        }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8),
              let parsed = try? FilmtoneCubeParser.parse(text: text, defaultTitle: look.title) else {
            return nil
        }
        let rgba = packRGBToRGBA(parsed.data, size: parsed.size)
        let cubeData = rgba.withUnsafeBufferPointer { Data(buffer: $0) }
        let hash = sourceHash ?? SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return PreparedCreativeLut(
            slug: "imported-grade:\(look.id.uuidString)",
            size: size > 0 ? size : parsed.size,
            intensity: clamp01(intensity),
            cubeData: cubeData,
            sourceHash: hash
        )
    }

    private static func packRGBToRGBA(_ data: [Double], size: Int) -> [Float] {
        let expectedRGBCount = size * size * size * 3
        let expectedRGBACount = size * size * size * 4
        if data.count == expectedRGBACount {
            return data.map(Float.init)
        }

        var rgba: [Float] = []
        rgba.reserveCapacity(expectedRGBACount)
        let count = min(data.count, expectedRGBCount)
        var index = 0
        while index < count {
            rgba.append(Float(data[index]))
            rgba.append(Float(index + 1 < count ? data[index + 1] : 0))
            rgba.append(Float(index + 2 < count ? data[index + 2] : 0))
            rgba.append(1)
            index += 3
        }
        while rgba.count < expectedRGBACount {
            rgba.append(0)
            rgba.append(0)
            rgba.append(0)
            rgba.append(1)
        }
        return rgba
    }
}
