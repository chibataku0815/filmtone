import Foundation

enum FilmtoneMotionBlurMath {
    static let baselineShutterAngle = 180.0
    static let maxShutterAngle = 720.0
    static let defaultSlotCount = 8

    static func clampShutterAngle(_ shutterAngle: Double) -> Double {
        guard shutterAngle.isFinite else {
            return 0
        }
        return min(max(shutterAngle, 0), maxShutterAngle)
    }

    static func additionalAngle(shutterAngle: Double) -> Double {
        clampShutterAngle(shutterAngle) - baselineShutterAngle
    }

    static func isActive(shutterAngle: Double) -> Bool {
        additionalAngle(shutterAngle: shutterAngle) > 0
    }

    static func activeFrameCount(
        shutterAngle: Double,
        slotCount: Int = defaultSlotCount
    ) -> Int {
        let additionalAngle = additionalAngle(shutterAngle: shutterAngle)
        guard additionalAngle > 0 else {
            return 1
        }
        let slots = max(1, slotCount)
        let raw = Int(((additionalAngle / 360.0) * (Double(slots) / 2.0)).rounded())
        return max(2, min(slots, raw))
    }

    static func blendWeights(
        shutterAngle: Double,
        activeFrames: Int,
        validSlots: Int,
        slotCount: Int = defaultSlotCount
    ) -> [Double] {
        let slots = max(1, slotCount)
        var weights = Array(repeating: 0.0, count: slots)
        let effective = min(max(0, activeFrames), max(0, validSlots), slots)
        guard effective > 0 else {
            return weights
        }
        if effective == 1 {
            weights[0] = 1
            return weights
        }

        let clampedShutterAngle = clampShutterAngle(shutterAngle)
        let flatness = min(max((clampedShutterAngle - 360.0) / 360.0, 0), 1)
        var sum = 0.0
        for index in 0..<effective {
            let triangle = Double(effective - index)
            let box = 1.0
            let weight = triangle * (1 - flatness) + box * flatness
            weights[index] = weight
            sum += weight
        }
        if sum > 0 {
            for index in 0..<effective {
                weights[index] /= sum
            }
        }
        return weights
    }
}
