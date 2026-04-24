import CoreImage
import Foundation

/// Ray-angle optics helper for field-of-view aware kernels.
///
/// Swift port of `packages/film-lab-renderer/src/webgpu/rayAngleOptics.ts`
/// (lines 11-135 in Desktop v1.0.3). Frozen constants per
/// `.claude/plans/sorted-juggling-garden.md` §"Ray-angle 定数":
///
///   referenceTanHalfHfov = tan(65° / 2) ≈ 0.6370702608
///
/// v1.1 wires this into the vignette kernel only, and only when
/// `cameraOptics.source == "metadata"` is true. `"assumed"` / nil sources
/// use a `applyMask = 0.0` toggle so the mask collapses to 1.0 and the
/// vignette path is byte-identical to pre-Stream-2 output.
enum FilmtoneRayAngleOptics {
    // MARK: - Frozen constants (see rayAngleOptics.ts:11-17)

    static let fallbackHfovDeg: Double = 65.0
    static let fovMinDeg: Double = 1.0
    static let fovMaxDeg: Double = 178.0
    static let referenceTanHalfHfov: Double = tan(65.0 * .pi / 360.0)

    // Hidden defaults mirror `CONTRACT_DEFAULTS.depthRayAngleGamma` and
    // `.depthRayAngleInnerThreshold` in `packages/film-lab-core/src/presets.ts`.
    // Stream 4 exposes these through `FilmtonePhase0Generated.hiddenDefaults`;
    // until that lands, callers fall back to the constants below (same values).
    static let defaultGamma: Double = 1.4
    static let defaultInnerThreshold: Double = 0.1

    // MARK: - Types

    struct Resolved {
        let tanHalfFovX: Double
        let tanHalfFovY: Double
        /// "metadata" | "assumed" | "fallback65"
        let source: String
    }

    // MARK: - Helpers

    private static func finitePositive(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value.isFinite && value > 0
    }

    private static func sourceAspectY(imageWidth: Double, imageHeight: Double) -> Double {
        let w = finitePositive(imageWidth) ? imageWidth : 1
        let h = finitePositive(imageHeight) ? imageHeight : w
        return h / max(w, 1)
    }

    private static func tanHalfFovFromDeg(_ fovDeg: Double?) -> Double? {
        guard let fovDeg, fovDeg.isFinite, fovDeg >= fovMinDeg, fovDeg <= fovMaxDeg else {
            return nil
        }
        return tan(fovDeg * .pi / 360)
    }

    private static func tanHalfFovFromFocalPx(_ focalPx: Double?, imageExtentPx: Double) -> Double? {
        guard finitePositive(focalPx), finitePositive(imageExtentPx),
              let focalPx = focalPx
        else {
            return nil
        }
        return (imageExtentPx * 0.5) / focalPx
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func smoothstep(edge0: Double, edge1: Double, value: Double) -> Double {
        let t = clamp01((value - edge0) / max(edge1 - edge0, 1e-6))
        return t * t * (3 - 2 * t)
    }

    // MARK: - Resolve

    /// Port of `resolveRayAngleOptics` in rayAngleOptics.ts:51-85.
    ///
    /// Both fov and focal-px missing → returns `Resolved(source: "fallback65")`
    /// with reference fov (65° hfov, aspect-corrected vfov). Otherwise keeps
    /// whatever source marker the optics DTO carried ("metadata" / "assumed").
    static func resolve(
        optics: CameraOpticsDTO?,
        imageWidth: Double,
        imageHeight: Double
    ) -> Resolved {
        let aspectY = sourceAspectY(imageWidth: imageWidth, imageHeight: imageHeight)
        let aspectX = 1 / max(aspectY, 1e-6)

        var tanHalfFovX = tanHalfFovFromDeg(optics?.fovXDeg)
            ?? tanHalfFovFromFocalPx(optics?.fxPx, imageExtentPx: imageWidth)
        var tanHalfFovY = tanHalfFovFromDeg(optics?.fovYDeg)
            ?? tanHalfFovFromFocalPx(optics?.fyPx, imageExtentPx: imageHeight)

        if tanHalfFovX == nil, let y = tanHalfFovY {
            tanHalfFovX = y * aspectX
        }
        if tanHalfFovY == nil, let x = tanHalfFovX {
            tanHalfFovY = x * aspectY
        }

        guard let resolvedX = tanHalfFovX, let resolvedY = tanHalfFovY else {
            return Resolved(
                tanHalfFovX: referenceTanHalfHfov,
                tanHalfFovY: referenceTanHalfHfov * aspectY,
                source: "fallback65"
            )
        }

        let source = optics?.source ?? "assumed"
        return Resolved(
            tanHalfFovX: resolvedX,
            tanHalfFovY: resolvedY,
            source: source
        )
    }

    // MARK: - Mask

    /// Port of `rayAngleMaskValue` in rayAngleOptics.ts:96-135.
    ///
    /// `uvX`, `uvY` are normalized image coordinates in [0, 1]. Returns the
    /// smoothstep mask in [0, 1] where 0 = center and 1 = edge incidence.
    static func mask(
        uvX: Double,
        uvY: Double,
        imageWidth: Double,
        imageHeight: Double,
        optics: CameraOpticsDTO?,
        gamma: Double = defaultGamma,
        innerThreshold: Double = defaultInnerThreshold
    ) -> Double {
        let resolved = resolve(
            optics: optics,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )
        return mask(
            uvX: uvX,
            uvY: uvY,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            resolved: resolved,
            gamma: gamma,
            innerThreshold: innerThreshold
        )
    }

    static func mask(
        uvX: Double,
        uvY: Double,
        imageWidth: Double,
        imageHeight: Double,
        resolved: Resolved,
        gamma: Double = defaultGamma,
        innerThreshold: Double = defaultInnerThreshold
    ) -> Double {
        let sensorX = (uvX - 0.5) * 2
        let sensorY = (uvY - 0.5) * 2
        let rayX = sensorX * resolved.tanHalfFovX
        let rayY = sensorY * resolved.tanHalfFovY
        let viewZ = 1 / (rayX * rayX + rayY * rayY + 1).squareRoot()
        let incidence = 1 - viewZ
        let refIncidence = referenceIncidence(imageWidth: imageWidth, imageHeight: imageHeight)
        let normalized = clamp01(incidence / max(refIncidence, 1e-5))
        let safeGamma = max(gamma, 0.001)
        let safeInner = min(0.8, max(0, innerThreshold))
        return smoothstep(edge0: safeInner, edge1: 1, value: pow(normalized, safeGamma))
    }

    /// Reference incidence used to normalize the mask so that a 65° hfov
    /// source with 16:9 aspect lands at mask ≈ 1 at the corner.
    static func referenceIncidence(imageWidth: Double, imageHeight: Double) -> Double {
        let aspectY = sourceAspectY(imageWidth: imageWidth, imageHeight: imageHeight)
        let refX = referenceTanHalfHfov
        let refY = referenceTanHalfHfov * aspectY
        return 1 - 1 / (refX * refX + refY * refY + 1).squareRoot()
    }

    // MARK: - Kernel arg packing

    /// Packs `(tanHalfFovX, tanHalfFovY, referenceIncidence)` into a CIVector
    /// matching the vec3 `opticsPack` argument consumed by the vignette
    /// Core Image kernel. The fourth component is unused (zero) but CIVector
    /// stays 3D to line up with the CI Kernel Language `vec3` binding.
    static func kernelArgs(
        resolved: Resolved,
        imageWidth: Double,
        imageHeight: Double
    ) -> CIVector {
        let refIncidence = referenceIncidence(imageWidth: imageWidth, imageHeight: imageHeight)
        return CIVector(
            x: CGFloat(resolved.tanHalfFovX),
            y: CGFloat(resolved.tanHalfFovY),
            z: CGFloat(refIncidence)
        )
    }
}
