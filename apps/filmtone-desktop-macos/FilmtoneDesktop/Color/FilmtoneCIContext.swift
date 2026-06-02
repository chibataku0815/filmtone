import CoreImage
import CoreGraphics
import Foundation

// Single shared CIContext for preview + export. Working color space is
// linear sRGB so the CIColorKernel math (lifted from iOS, see
// FilmtoneGradeKernels.swift) sees linear values matching the iOS
// reference. Output color space at render time is sRGB so the produced
// PNG is directly comparable against `apps/desktop-film-lab-batch/test/
// golden/baseline-B/<preset>/<image>.png`.

enum FilmtoneCIContext {
    static let shared: CIContext = {
        let workingSpace =
            CGColorSpace(name: CGColorSpace.linearSRGB)
            ?? CGColorSpaceCreateDeviceRGB()
        let outputSpace =
            CGColorSpace(name: CGColorSpace.sRGB)
            ?? CGColorSpaceCreateDeviceRGB()
        return CIContext(options: [
            .workingColorSpace: workingSpace,
            .outputColorSpace: outputSpace,
            .useSoftwareRenderer: false,
        ])
    }()

    static func makeExportContext(contract: FilmtoneColorPipelineContract) -> CIContext {
        CIContext(options: [
            .cacheIntermediates: false,
            .priorityRequestLow: false,
            .workingColorSpace: contract.workingColorSpace,
            // Current Desktop video export writes 8-bit BGRA/H.264 SDR. Keeping
            // this path at RGBA8 matches the preview/output precision and avoids
            // the 4K/60 half-float render cost; revisit for HDR/10-bit exports.
            .workingFormat: NSNumber(value: CIFormat.RGBA8.rawValue),
            .outputColorSpace: contract.destinationColorSpace,
            .useSoftwareRenderer: false,
        ])
    }

    static let outputColorSpace: CGColorSpace =
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
}
