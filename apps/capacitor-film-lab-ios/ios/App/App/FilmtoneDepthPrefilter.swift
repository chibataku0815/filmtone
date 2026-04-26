import CoreImage
import CoreVideo
import Foundation

/// Depth × ray-angle prefilter for the glow-trio (Mist / Bloom / Halation).
///
/// Swift / Core Image port of the Desktop WGSL prefilters:
/// - `packages/film-lab-renderer/src/webgpu/shaders/diffusion-depth-prefilter.frag.wgsl.ts`
/// - `packages/film-lab-renderer/src/webgpu/shaders/bloom-depth-prefilter.frag.wgsl.ts`
/// - `packages/film-lab-renderer/src/webgpu/shaders/halation-depth-prefilter.frag.wgsl.ts`
///
/// Plan §6.2 / §13.5. Per-variant `mix(...)` coefficients are taken verbatim
/// from the Desktop WGSL (see `weightedSource` in each shader). Ray-angle
/// math is the Swift port of `rayAngleOptics.ts:96-135` and is identical to
/// the body of `FilmtoneRayAngleOptics.mask(...)`; the kernel inlines it
/// because CIKernel Language has no shared function imports.
///
/// Caller (Stream C) is responsible for passing a depth CIImage that is
/// already aligned (orientation + crop) to `image`. The caller typically
/// reads `FilmtoneDepthMap.ciImage` which applies orientation. This kernel
/// does not assume same resolution: depth is sampled with bilinear (CI
/// default) at the same destination uv, so a 1/4-resolution AVDepthData
/// payload still composes correctly. Edge-aware upsample is intentionally
/// deferred (plan §9 risk row).
///
/// Alpha is preserved (`src.a` flows through untouched, matching the
/// Desktop `vec4f(color.rgb * mult, color.a)` return).
enum FilmtoneDepthPrefilter {

    // MARK: - Public API

    enum Variant {
        case mist
        case bloom
        case halation
    }

    struct Params {
        let variant: Variant
        /// `depthMistGain` / `depthGlowGain` / `depthHalationGain`
        /// (Desktop "gain" uniform, contract-side already in [0, 1] range).
        let depthGain: Double
        /// `depthMistRayAngleGain` / `depthBloomRayAngleGain` / `depthHalationRayAngleGain`.
        let rayAngleGain: Double
        /// `CONTRACT_DEFAULTS.depthRayAngleGamma` — default 1.4.
        let rayAngleGamma: Double
        /// `CONTRACT_DEFAULTS.depthRayAngleInnerThreshold` — default 0.1.
        let rayAngleInnerThreshold: Double
    }

    /// Apply the depth × ray-angle prefilter to `image` using `depth` as the
    /// auxiliary R-only sampler. Returns `image` unchanged when both gains
    /// are zero (cheap byte-identical short-circuit, defense-in-depth — the
    /// caller typically already gates on `depthMap != nil`).
    ///
    /// - Parameters:
    ///   - image: Source CIImage (linearSRGB working space, RGBAh).
    ///   - depth: Depth CIImage. R channel is sampled (R32f normalized
    ///     `[0, 1]` where `0` = nearest, `1` = farthest). Must already be
    ///     orientation-aligned to `image` (caller's responsibility).
    ///   - imageExtent: Extent of `image` used for uv normalization.
    ///   - optics: Optional camera optics DTO. `nil` falls back to the
    ///     reference 65° HFOV (matches Desktop fallback).
    ///   - params: Variant and per-variant gains.
    /// - Returns: Prefiltered CIImage cropped to `imageExtent`. Falls back
    ///   to `image` if the underlying CIKernel cannot compile or apply.
    static func apply(
        to image: CIImage,
        depth: CIImage,
        imageExtent: CGRect,
        optics: CameraOpticsDTO?,
        params: Params
    ) -> CIImage {
        // Defense-in-depth fast path (matches Desktop `if (gain <= 0.0)`).
        // When both gains are zero the kernel would compute `mult = 1.0` for
        // every pixel; skipping the dispatch keeps the output byte-identical
        // and avoids a useless GPU pass.
        if params.depthGain <= 0 && params.rayAngleGain <= 0 {
            return image
        }

        guard let kernel = Self.kernel(for: params.variant) else {
            // CIKernel compilation failure is unrecoverable; fall back so
            // the export pipeline never aborts mid-frame.
            return image
        }

        let width = Double(imageExtent.width)
        let height = Double(imageExtent.height)
        let resolved = FilmtoneRayAngleOptics.resolve(
            optics: optics,
            imageWidth: width,
            imageHeight: height
        )
        let opticsPack = FilmtoneRayAngleOptics.kernelArgs(
            resolved: resolved,
            imageWidth: width,
            imageHeight: height
        )
        let imageResolution = CIVector(x: CGFloat(width), y: CGFloat(height))

        // Clamp depth to its own extent so an undersized AVDepthData payload
        // (typically 1/4 source resolution) doesn't contribute black borders
        // when the kernel samples beyond its bounds.
        let clampedDepth = depth.clampedToExtent()

        let depthExtent = depth.extent
        let result = kernel.apply(
            extent: imageExtent,
            roiCallback: { index, rect in
                // index 0 = image, 1 = depth. Image roi is identity; depth
                // roi clamps to the depth's own extent so CI doesn't request
                // pixels outside the payload.
                if index == 1 {
                    return rect.intersection(depthExtent).isNull
                        ? depthExtent
                        : rect.intersection(depthExtent)
                }
                return rect
            },
            arguments: [
                image,
                clampedDepth,
                NSNumber(value: params.depthGain),
                NSNumber(value: params.rayAngleGain),
                NSNumber(value: params.rayAngleGamma),
                NSNumber(value: params.rayAngleInnerThreshold),
                imageResolution,
                opticsPack,
            ]
        )

        return result?.cropped(to: imageExtent) ?? image
    }

    // MARK: - Kernel cache

    private static func kernel(for variant: Variant) -> CIKernel? {
        switch variant {
        case .mist: return Self.kernels?.mist
        case .bloom: return Self.kernels?.bloom
        case .halation: return Self.kernels?.halation
        }
    }

    private struct KernelTrio {
        let mist: CIKernel
        let bloom: CIKernel
        let halation: CIKernel
    }

    /// Loaded once on first use. `CIKernel.makeKernels(source:)` returns the
    /// kernels in declaration order, so the array is mapped positionally to
    /// (mist, bloom, halation).
    private static let kernels: KernelTrio? = {
        guard let all = CIKernel.makeKernels(source: Self.source),
              all.count >= 3 else {
            return nil
        }
        return KernelTrio(
            mist: all[0],
            bloom: all[1],
            halation: all[2]
        )
    }()

    // MARK: - Kernel source
    //
    // Three sibling kernels share the same body except for the `mix(...)`
    // coefficients in the `depthMult` line. The ray-angle math is the
    // CIKernel-Language inlining of `FilmtoneRayAngleOptics.mask(...)`
    // (lines 152-172 in `FilmtoneRayAngleOptics.swift`), which is itself a
    // Swift port of `rayAngleOptics.ts:96-135`.
    //
    // Per-variant coefficients (verified against Desktop WGSL on
    // 2026-04-26):
    // - mist     : `mix(1.0 - gain * 0.5,  1.0 + gain * 2.0,  depthVal)`
    //              (diffusion-depth-prefilter.frag.wgsl.ts:108)
    // - bloom    : `mix(1.0 - gain * 0.3,  1.0 + gain * 0.8,  depthVal)`
    //              (bloom-depth-prefilter.frag.wgsl.ts:106)
    // - halation : `mix(1.0 - gain * 0.25, 1.0 + gain * 0.5,  depthVal)`
    //              (halation-depth-prefilter.frag.wgsl.ts:101)
    //
    // The Desktop shaders also wrap depthMult with
    //   mult * (1 + angleGain * rayAngleMask)
    // and apply only to `color.rgb` (alpha unchanged). Both behaviors are
    // preserved here.
    private static let source: String = """
kernel vec4 depthMistPrefilter(
    sampler image,
    sampler depth,
    float gain,
    float angleGain,
    float angleGamma,
    float innerThreshold,
    vec2 imageResolution,
    vec3 opticsPack
) {
    vec4 src = sample(image, samplerCoord(image));
    vec2 dc = destCoord();
    vec2 uv = dc / imageResolution;

    float depthVal = sample(depth, samplerCoord(depth)).r;

    vec2 sensor = (uv - vec2(0.5)) * 2.0;
    vec2 ray = vec2(sensor.x * opticsPack.x, sensor.y * opticsPack.y);
    float viewZ = 1.0 / sqrt(dot(ray, ray) + 1.0);
    float incidence = 1.0 - viewZ;
    float normalized = clamp(incidence / max(opticsPack.z, 1.0e-5), 0.0, 1.0);
    float t = pow(normalized, max(angleGamma, 0.001));
    float safeInner = clamp(innerThreshold, 0.0, 0.8);
    float ts = clamp((t - safeInner) / max(1.0 - safeInner, 1.0e-6), 0.0, 1.0);
    float angleMask = ts * ts * (3.0 - 2.0 * ts);

    float depthMult = mix(1.0 - gain * 0.5, 1.0 + gain * 2.0, depthVal);
    float angleMult = 1.0 + max(angleGain, 0.0) * angleMask;
    float mult = depthMult * angleMult;
    return vec4(src.rgb * mult, src.a);
}

kernel vec4 depthBloomPrefilter(
    sampler image,
    sampler depth,
    float gain,
    float angleGain,
    float angleGamma,
    float innerThreshold,
    vec2 imageResolution,
    vec3 opticsPack
) {
    vec4 src = sample(image, samplerCoord(image));
    vec2 dc = destCoord();
    vec2 uv = dc / imageResolution;

    float depthVal = sample(depth, samplerCoord(depth)).r;

    vec2 sensor = (uv - vec2(0.5)) * 2.0;
    vec2 ray = vec2(sensor.x * opticsPack.x, sensor.y * opticsPack.y);
    float viewZ = 1.0 / sqrt(dot(ray, ray) + 1.0);
    float incidence = 1.0 - viewZ;
    float normalized = clamp(incidence / max(opticsPack.z, 1.0e-5), 0.0, 1.0);
    float t = pow(normalized, max(angleGamma, 0.001));
    float safeInner = clamp(innerThreshold, 0.0, 0.8);
    float ts = clamp((t - safeInner) / max(1.0 - safeInner, 1.0e-6), 0.0, 1.0);
    float angleMask = ts * ts * (3.0 - 2.0 * ts);

    float depthMult = mix(1.0 - gain * 0.3, 1.0 + gain * 0.8, depthVal);
    float angleMult = 1.0 + max(angleGain, 0.0) * angleMask;
    float mult = depthMult * angleMult;
    return vec4(src.rgb * mult, src.a);
}

kernel vec4 depthHalationPrefilter(
    sampler image,
    sampler depth,
    float gain,
    float angleGain,
    float angleGamma,
    float innerThreshold,
    vec2 imageResolution,
    vec3 opticsPack
) {
    vec4 src = sample(image, samplerCoord(image));
    vec2 dc = destCoord();
    vec2 uv = dc / imageResolution;

    float depthVal = sample(depth, samplerCoord(depth)).r;

    vec2 sensor = (uv - vec2(0.5)) * 2.0;
    vec2 ray = vec2(sensor.x * opticsPack.x, sensor.y * opticsPack.y);
    float viewZ = 1.0 / sqrt(dot(ray, ray) + 1.0);
    float incidence = 1.0 - viewZ;
    float normalized = clamp(incidence / max(opticsPack.z, 1.0e-5), 0.0, 1.0);
    float t = pow(normalized, max(angleGamma, 0.001));
    float safeInner = clamp(innerThreshold, 0.0, 0.8);
    float ts = clamp((t - safeInner) / max(1.0 - safeInner, 1.0e-6), 0.0, 1.0);
    float angleMask = ts * ts * (3.0 - 2.0 * ts);

    float depthMult = mix(1.0 - gain * 0.25, 1.0 + gain * 0.5, depthVal);
    float angleMult = 1.0 + max(angleGain, 0.0) * angleMask;
    float mult = depthMult * angleMult;
    return vec4(src.rgb * mult, src.a);
}
"""
}
