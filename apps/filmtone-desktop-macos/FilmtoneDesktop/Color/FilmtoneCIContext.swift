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
            .workingFormat: NSNumber(value: CIFormat.RGBAh.rawValue),
            .outputColorSpace: contract.destinationColorSpace,
            .useSoftwareRenderer: false,
        ])
    }

    static let outputColorSpace: CGColorSpace =
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
}
