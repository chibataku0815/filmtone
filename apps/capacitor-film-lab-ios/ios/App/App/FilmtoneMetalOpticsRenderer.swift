// v1.5 — Quality export optics chain Metal renderer.
//
// Replaces `FilmtoneExportSession.applyGlowFamilyStage` (and, when
// vignette is supplied, also `applyVignetteStage`) with a single
// MTLCommandBuffer pipeline. Activated by `FILMTONE_EXPORT_METAL_OPTICS=1`
// for video Quality exports without depth payload. Production path is
// unchanged when the flag is off or the renderer fails to initialize.
//
// Math is a direct port of the existing CI kernels — same tent weights, same
// soft-knee shoulder, same composite formula, same vignette ray-angle field
// mask — so visual output should be equivalent modulo float precision.
//
// Phase 2 段階 1 (2026-05-03): Vignette を chain に追加。chain の同一
// command buffer 内で Glow → Vignette を連続 dispatch し、CI handoff は
// 入口 1 回のまま (Phase 2.b の方針)。EdgeOptics の Metal 化は段階 2 で
// 試行されたが Metal pass init failure → CI fallback + flag overhead で
// +45s 悪化が確認されたため revert (handoff doc 参照)。

import CoreGraphics
import CoreImage
import Foundation
import Metal

@available(iOS 13.0, *)
final class FilmtoneMetalOpticsRenderer {

    struct GlowFrameParams {
        let bloomStrength: Double
        let bloomThreshold: Double
        let bloomSoftKnee: Double
        let bloomRadius: Double
        let bloomMipLevels: Int
        let bloomSpreadBoost: Double

        let halationIntensity: Double
        let halationThreshold: Double
        let halationSoftKnee: Double
        let halationRadius: Double
        let halationHue: Double
        let halationMipLevels: Int
        let halationSpread: Double
        let halationSpreadDivisor: Double

        let diffusion: Double
        let diffusionMipLevels: Int
        let diffusionCompositeBase: Double

        let glowBaseScale: Double

        /// Backlight Veil Phase 1b: when non-nil, the composite stage swaps
        /// `filmtoneGlowComposite` for `filmtoneGlowCompositeBacklightVeil`
        /// which runs the WGSL §4.4 direct + scatter math. Nil keeps every
        /// pre-existing render path byte-equivalent.
        let opticalScatter: OpticalScatterParams?

        init(
            bloomStrength: Double,
            bloomThreshold: Double,
            bloomSoftKnee: Double,
            bloomRadius: Double,
            bloomMipLevels: Int,
            bloomSpreadBoost: Double,
            halationIntensity: Double,
            halationThreshold: Double,
            halationSoftKnee: Double,
            halationRadius: Double,
            halationHue: Double,
            halationMipLevels: Int,
            halationSpread: Double,
            halationSpreadDivisor: Double,
            diffusion: Double,
            diffusionMipLevels: Int,
            diffusionCompositeBase: Double,
            glowBaseScale: Double,
            opticalScatter: OpticalScatterParams? = nil
        ) {
            self.bloomStrength = bloomStrength
            self.bloomThreshold = bloomThreshold
            self.bloomSoftKnee = bloomSoftKnee
            self.bloomRadius = bloomRadius
            self.bloomMipLevels = bloomMipLevels
            self.bloomSpreadBoost = bloomSpreadBoost
            self.halationIntensity = halationIntensity
            self.halationThreshold = halationThreshold
            self.halationSoftKnee = halationSoftKnee
            self.halationRadius = halationRadius
            self.halationHue = halationHue
            self.halationMipLevels = halationMipLevels
            self.halationSpread = halationSpread
            self.halationSpreadDivisor = halationSpreadDivisor
            self.diffusion = diffusion
            self.diffusionMipLevels = diffusionMipLevels
            self.diffusionCompositeBase = diffusionCompositeBase
            self.glowBaseScale = glowBaseScale
            self.opticalScatter = opticalScatter
        }
    }

    /// Backlight Veil Phase 1b — six optical scatter coefficients sourced from
    /// `optical-filter-profiles.ts` Backlight Veil entries (commit 2c8e15d).
    /// Mirrors WGSL composite uniforms `optical*` (composite.frag.wgsl.ts:288-316).
    struct OpticalScatterParams {
        let directTransmission: Double
        let blackRetention: Double
        let scatterStrength: Double
        let highlightReactivity: Double
        let warmScatter: Double
        let spectralTail: Double
    }

    /// Vignette parameters mirroring the CI `vignette` kernel arguments.
    /// `opticsPack` packs `(tanHalfFovX, tanHalfFovY, refIncidence)` from
    /// `FilmtoneRayAngleOptics.kernelArgs`. `applyMask = 1.0` only when
    /// `cameraOptics.source == "metadata"`; otherwise `0.0` keeps the
    /// vignette byte-equivalent to the pre-Stream-2 path.
    struct VignetteFrameParams {
        let intensity: Double
        let opticsPack: SIMD3<Float>
        let applyMask: Float
        let gamma: Double
        let innerThreshold: Double
    }

    /// Composite parameter object for `renderOpticsChain`.
    struct OpticsChainParams {
        let glow: GlowFrameParams
        let vignette: VignetteFrameParams?
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let workingColorSpace: CGColorSpace
    private let ciContext: CIContext

    private let highlightExtractPS: MTLComputePipelineState
    private let tentDownsamplePS: MTLComputePipelineState
    private let tentUpsamplePS: MTLComputePipelineState
    private let copyTexturePS: MTLComputePipelineState
    private let clearTexturePS: MTLComputePipelineState
    private let upsampleAccumulatePS: MTLComputePipelineState
    private let glowCompositePS: MTLComputePipelineState
    private let glowCompositeBacklightVeilPS: MTLComputePipelineState
    private let vignettePS: MTLComputePipelineState

    // Texture pool — allocated lazily on first render call and reused across
    // frames within an export. Sizes only depend on outputExtent and mip
    // level counts which are constant for a given export.
    private var poolOutputSize: CGSize = .zero
    private var poolBloomLevels: Int = 0
    private var poolHalationLevels: Int = 0
    private var poolDiffusionLevels: Int = 0
    private var poolBloomInitial: Double = 0
    private var poolHalationInitial: Double = 0
    private var poolDiffusionInitial: Double = 0

    private var inputTexture: MTLTexture?
    private var outputTexture: MTLTexture?

    private var bloomPlate: MTLTexture?
    private var halationPlate: MTLTexture?

    private var bloomMipsDown: [MTLTexture] = []
    private var bloomMipsAccum: [MTLTexture] = []
    private var halationMipsDown: [MTLTexture] = []
    private var halationMipsAccum: [MTLTexture] = []
    private var diffusionMipsDown: [MTLTexture] = []
    private var diffusionMipsAccum: [MTLTexture] = []

    private var bloomFinal: MTLTexture?
    private var halationFinal: MTLTexture?
    private var diffusionFinal: MTLTexture?
    /// Vignette is the next stage after Glow composite. Read+write alias is
    /// disallowed in Metal compute, so vignette writes into a dedicated
    /// texture rather than reusing `outputTexture`.
    private var vignetteFinal: MTLTexture?

    init?(workingColorSpace: CGColorSpace, ciContext: CIContext) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue()
        else {
            NSLog("FilmtoneMetalOpticsRenderer: Metal device unavailable")
            return nil
        }
        self.device = device
        self.queue = queue
        self.workingColorSpace = workingColorSpace
        self.ciContext = ciContext

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: Self.metalSource, options: nil)
        } catch {
            NSLog("FilmtoneMetalOpticsRenderer: shader compile failed: \(error)")
            return nil
        }

        guard
            let extractFn = library.makeFunction(name: "filmtoneSoftKneeHighlight"),
            let downFn = library.makeFunction(name: "filmtoneTentDownsample"),
            let upFn = library.makeFunction(name: "filmtoneTentUpsample"),
            let copyFn = library.makeFunction(name: "filmtoneCopyTexture"),
            let clearFn = library.makeFunction(name: "filmtoneClearTexture"),
            let accFn = library.makeFunction(name: "filmtoneTentUpsampleAccumulate"),
            let compFn = library.makeFunction(name: "filmtoneGlowComposite"),
            let veilFn = library.makeFunction(name: "filmtoneGlowCompositeBacklightVeil"),
            let vignetteFn = library.makeFunction(name: "filmtoneVignette")
        else {
            NSLog("FilmtoneMetalOpticsRenderer: shader function lookup failed")
            return nil
        }

        do {
            self.highlightExtractPS = try device.makeComputePipelineState(function: extractFn)
            self.tentDownsamplePS = try device.makeComputePipelineState(function: downFn)
            self.tentUpsamplePS = try device.makeComputePipelineState(function: upFn)
            self.copyTexturePS = try device.makeComputePipelineState(function: copyFn)
            self.clearTexturePS = try device.makeComputePipelineState(function: clearFn)
            self.upsampleAccumulatePS = try device.makeComputePipelineState(function: accFn)
            self.glowCompositePS = try device.makeComputePipelineState(function: compFn)
            self.glowCompositeBacklightVeilPS = try device.makeComputePipelineState(function: veilFn)
            self.vignettePS = try device.makeComputePipelineState(function: vignetteFn)
        } catch {
            NSLog("FilmtoneMetalOpticsRenderer: pipeline state creation failed: \(error)")
            return nil
        }
    }

    /// Run the configured optics chain on `input` and return a CIImage whose
    /// backing MTLTexture holds the final composited result. Returns nil on
    /// any allocation / encoding failure; caller falls back to the Core Image
    /// path.
    ///
    /// `outputExtent` must match the output frame size (origin .zero, integral
    /// width/height). `input` must already be at that extent.
    ///
    /// Phase 2 段階 1 chain order:
    ///   inputTexture
    ///     → (bloom/halation/diffusion plates + glowComposite) → outputTexture
    ///     → (vignette, optional)                              → vignetteFinal
    /// CI handoff occurs once at the entry `ciContext.render(input, to:)`.
    func renderOpticsChain(
        input: CIImage,
        outputExtent: CGRect,
        params: OpticsChainParams
    ) -> CIImage? {
        guard outputExtent.width >= 1, outputExtent.height >= 1 else {
            return nil
        }
        let outSize = CGSize(
            width: max(1.0, outputExtent.width.rounded()),
            height: max(1.0, outputExtent.height.rounded())
        )

        let glow = params.glow
        let bloomLevels = max(glow.bloomMipLevels, 1)
        let halationLevels = max(glow.halationMipLevels, 1)
        let diffusionLevels = max(glow.diffusionMipLevels, 1)
        let bloomInitial = glow.glowBaseScale / max(glow.bloomSpreadBoost, 0.0001)
        let halationSpreadMul = 1.0 + max(glow.halationSpread, 0) / max(glow.halationSpreadDivisor, 0.0001)
        let halationInitial = glow.glowBaseScale / max(halationSpreadMul, 0.0001)
        let diffusionInitial = glow.glowBaseScale / 1.15

        let needsRealloc =
            poolOutputSize != outSize ||
            poolBloomLevels != bloomLevels ||
            poolHalationLevels != halationLevels ||
            poolDiffusionLevels != diffusionLevels ||
            abs(poolBloomInitial - bloomInitial) > 1e-6 ||
            abs(poolHalationInitial - halationInitial) > 1e-6 ||
            abs(poolDiffusionInitial - diffusionInitial) > 1e-6

        if needsRealloc {
            guard
                allocatePool(
                    outSize: outSize,
                    bloomLevels: bloomLevels,
                    bloomInitial: bloomInitial,
                    halationLevels: halationLevels,
                    halationInitial: halationInitial,
                    diffusionLevels: diffusionLevels,
                    diffusionInitial: diffusionInitial
                )
            else {
                return nil
            }
            self.poolOutputSize = outSize
            self.poolBloomLevels = bloomLevels
            self.poolHalationLevels = halationLevels
            self.poolDiffusionLevels = diffusionLevels
            self.poolBloomInitial = bloomInitial
            self.poolHalationInitial = halationInitial
            self.poolDiffusionInitial = diffusionInitial
        }

        guard
            let inputTexture,
            let outputTexture,
            let bloomPlate,
            let halationPlate,
            let bloomFinal,
            let halationFinal,
            let diffusionFinal,
            let vignetteFinal,
            let cb = queue.makeCommandBuffer()
        else {
            return nil
        }

        // Render the upstream CIImage into our input texture. CIContext handles
        // colorspace conversion to workingColorSpace and Y-flip; the texture
        // ends up bottom-left origin (matches what CIImage(mtlTexture:) expects
        // on the wrap-back).
        ciContext.render(
            input,
            to: inputTexture,
            commandBuffer: cb,
            bounds: outputExtent,
            colorSpace: workingColorSpace
        )

        guard let enc = cb.makeComputeCommandEncoder() else { return nil }

        let bloomActive = glow.bloomStrength > 0.0001
        let halationActive = glow.halationIntensity > 0.0001
        let diffusionActive = glow.diffusion > 0.0001
        let glowActive = bloomActive || halationActive || diffusionActive
        let vignetteActive = (params.vignette?.intensity ?? 0) > 0.0001

        // Stage 1: Glow family. Always writes into `outputTexture`. When all
        // three components are inactive but vignette is active, fall back to
        // an identity copy so the vignette pass has a consistent source.
        if glowActive {
            if bloomActive {
                encodeHighlightExtract(
                    enc: enc,
                    input: inputTexture,
                    output: bloomPlate,
                    threshold: Float(glow.bloomThreshold),
                    knee: Float(glow.bloomSoftKnee),
                    tint: SIMD3<Float>(1, 1, 1)
                )
                encodeMipPyramid(
                    enc: enc,
                    source: bloomPlate,
                    mipsDown: bloomMipsDown,
                    mipsAccum: bloomMipsAccum,
                    final: bloomFinal,
                    radius: glow.bloomRadius
                )
            } else {
                encodeClear(enc: enc, target: bloomFinal)
            }

            if halationActive {
                let halationTint = halationColor(forHue: glow.halationHue)
                encodeHighlightExtract(
                    enc: enc,
                    input: inputTexture,
                    output: halationPlate,
                    threshold: Float(glow.halationThreshold),
                    knee: Float(glow.halationSoftKnee),
                    tint: halationTint
                )
                encodeMipPyramid(
                    enc: enc,
                    source: halationPlate,
                    mipsDown: halationMipsDown,
                    mipsAccum: halationMipsAccum,
                    final: halationFinal,
                    radius: glow.halationRadius
                )
            } else {
                encodeClear(enc: enc, target: halationFinal)
            }

            if diffusionActive {
                encodeMipPyramid(
                    enc: enc,
                    source: inputTexture,
                    mipsDown: diffusionMipsDown,
                    mipsAccum: diffusionMipsAccum,
                    final: diffusionFinal,
                    radius: 0.9
                )
            } else {
                encodeClear(enc: enc, target: diffusionFinal)
            }

            if let optical = glow.opticalScatter {
                encodeGlowCompositeBacklightVeil(
                    enc: enc,
                    base: inputTexture,
                    bloom: bloomFinal,
                    halation: halationFinal,
                    diffusion: diffusionFinal,
                    output: outputTexture,
                    bloomStrength: Float(glow.bloomStrength),
                    halationIntensity: Float(glow.halationIntensity),
                    diffusionAmount: Float(glow.diffusion),
                    optical: optical
                )
            } else {
                encodeGlowComposite(
                    enc: enc,
                    base: inputTexture,
                    bloom: bloomFinal,
                    halation: halationFinal,
                    diffusion: diffusionFinal,
                    output: outputTexture,
                    bloomStrength: Float(glow.bloomStrength),
                    halationIntensity: Float(glow.halationIntensity),
                    diffusionAmount: Float(glow.diffusion),
                    diffusionBase: Float(glow.diffusionCompositeBase)
                )
            }
        } else {
            // No glow contributions: passthrough into outputTexture so the
            // wrap-back path (and vignette stage, if any) is consistent.
            encodeCopy(enc: enc, source: inputTexture, destination: outputTexture)
        }

        // Stage 2 (optional): Vignette. Reads outputTexture, writes
        // vignetteFinal to avoid a read+write alias on the same texture.
        var lastTexture: MTLTexture = outputTexture
        if vignetteActive, let vignetteParams = params.vignette {
            encodeVignette(
                enc: enc,
                input: outputTexture,
                output: vignetteFinal,
                params: vignetteParams
            )
            lastTexture = vignetteFinal
        }

        enc.endEncoding()
        cb.commit()
        // No wait: Metal will synchronize when downstream CI/render reads the
        // texture-backed CIImage on its own command queue.

        return ciImage(from: lastTexture)
    }

    // MARK: Encoders

    private func encodeHighlightExtract(
        enc: MTLComputeCommandEncoder,
        input: MTLTexture,
        output: MTLTexture,
        threshold: Float,
        knee: Float,
        tint: SIMD3<Float>
    ) {
        enc.setComputePipelineState(highlightExtractPS)
        enc.setTexture(input, index: 0)
        enc.setTexture(output, index: 1)
        var t = threshold
        var k = knee
        var tnt = tint
        enc.setBytes(&t, length: MemoryLayout<Float>.size, index: 0)
        enc.setBytes(&k, length: MemoryLayout<Float>.size, index: 1)
        enc.setBytes(&tnt, length: MemoryLayout<SIMD3<Float>>.size, index: 2)
        dispatch(enc: enc, pipeline: highlightExtractPS, width: output.width, height: output.height)
    }

    private func encodeCopy(
        enc: MTLComputeCommandEncoder,
        source: MTLTexture,
        destination: MTLTexture
    ) {
        enc.setComputePipelineState(copyTexturePS)
        enc.setTexture(source, index: 0)
        enc.setTexture(destination, index: 1)
        dispatch(enc: enc, pipeline: copyTexturePS, width: destination.width, height: destination.height)
    }

    private func encodeClear(enc: MTLComputeCommandEncoder, target: MTLTexture) {
        // Dedicated write-only clear. Earlier prototype reused
        // `filmtoneSoftKneeHighlight` with the same texture bound as both
        // read and write; that's undefined behavior in Metal even though
        // the test material happened never to exercise this path (all
        // bloom/halation/diffusion components were active). A separate
        // write-only kernel removes the alias before Phase 2 expansion.
        enc.setComputePipelineState(clearTexturePS)
        enc.setTexture(target, index: 0)
        dispatch(enc: enc, pipeline: clearTexturePS, width: target.width, height: target.height)
    }

    private func encodeMipPyramid(
        enc: MTLComputeCommandEncoder,
        source: MTLTexture,
        mipsDown: [MTLTexture],
        mipsAccum: [MTLTexture],
        final: MTLTexture,
        radius: Double
    ) {
        let levels = mipsDown.count
        guard levels >= 1, mipsAccum.count == levels else { return }

        // Down: source -> mipsDown[0] (initial scale); mipsDown[i-1] -> mipsDown[i] (0.5x).
        encodeTentDownsample(enc: enc, source: source, destination: mipsDown[0])
        for i in 1..<levels {
            encodeTentDownsample(enc: enc, source: mipsDown[i - 1], destination: mipsDown[i])
        }

        // Up + accumulate: deepest accum is just a copy of deepest down.
        if levels == 1 {
            encodeCopy(enc: enc, source: mipsDown[0], destination: mipsAccum[0])
        } else {
            encodeCopy(enc: enc, source: mipsDown[levels - 1], destination: mipsAccum[levels - 1])
            let weights = computeMipWeights(radius: clampUnit(radius), levels: levels)
            for index in stride(from: levels - 2, through: 0, by: -1) {
                encodeUpsampleAccumulate(
                    enc: enc,
                    lowRes: mipsAccum[index + 1],
                    highRes: mipsDown[index],
                    output: mipsAccum[index],
                    weight: Float(weights[index + 1])
                )
            }
        }

        // Final tent upsample mips[0] -> output extent.
        encodeTentUpsample(enc: enc, source: mipsAccum[0], destination: final)
    }

    private func encodeTentDownsample(
        enc: MTLComputeCommandEncoder,
        source: MTLTexture,
        destination: MTLTexture
    ) {
        enc.setComputePipelineState(tentDownsamplePS)
        enc.setTexture(source, index: 0)
        enc.setTexture(destination, index: 1)
        var srcSize = SIMD2<UInt32>(UInt32(source.width), UInt32(source.height))
        var dstSize = SIMD2<UInt32>(UInt32(destination.width), UInt32(destination.height))
        enc.setBytes(&srcSize, length: MemoryLayout<SIMD2<UInt32>>.size, index: 0)
        enc.setBytes(&dstSize, length: MemoryLayout<SIMD2<UInt32>>.size, index: 1)
        dispatch(enc: enc, pipeline: tentDownsamplePS, width: destination.width, height: destination.height)
    }

    private func encodeTentUpsample(
        enc: MTLComputeCommandEncoder,
        source: MTLTexture,
        destination: MTLTexture
    ) {
        enc.setComputePipelineState(tentUpsamplePS)
        enc.setTexture(source, index: 0)
        enc.setTexture(destination, index: 1)
        var srcSize = SIMD2<UInt32>(UInt32(source.width), UInt32(source.height))
        var dstSize = SIMD2<UInt32>(UInt32(destination.width), UInt32(destination.height))
        enc.setBytes(&srcSize, length: MemoryLayout<SIMD2<UInt32>>.size, index: 0)
        enc.setBytes(&dstSize, length: MemoryLayout<SIMD2<UInt32>>.size, index: 1)
        dispatch(enc: enc, pipeline: tentUpsamplePS, width: destination.width, height: destination.height)
    }

    private func encodeUpsampleAccumulate(
        enc: MTLComputeCommandEncoder,
        lowRes: MTLTexture,
        highRes: MTLTexture,
        output: MTLTexture,
        weight: Float
    ) {
        enc.setComputePipelineState(upsampleAccumulatePS)
        enc.setTexture(lowRes, index: 0)
        enc.setTexture(highRes, index: 1)
        enc.setTexture(output, index: 2)
        var lowSize = SIMD2<UInt32>(UInt32(lowRes.width), UInt32(lowRes.height))
        var outSize = SIMD2<UInt32>(UInt32(output.width), UInt32(output.height))
        var w = weight
        enc.setBytes(&lowSize, length: MemoryLayout<SIMD2<UInt32>>.size, index: 0)
        enc.setBytes(&outSize, length: MemoryLayout<SIMD2<UInt32>>.size, index: 1)
        enc.setBytes(&w, length: MemoryLayout<Float>.size, index: 2)
        dispatch(enc: enc, pipeline: upsampleAccumulatePS, width: output.width, height: output.height)
    }

    private func encodeVignette(
        enc: MTLComputeCommandEncoder,
        input: MTLTexture,
        output: MTLTexture,
        params: VignetteFrameParams
    ) {
        enc.setComputePipelineState(vignettePS)
        enc.setTexture(input, index: 0)
        enc.setTexture(output, index: 1)
        var intensity = Float(params.intensity)
        var outSize = SIMD2<UInt32>(UInt32(output.width), UInt32(output.height))
        var gamma = Float(params.gamma)
        var innerThreshold = Float(params.innerThreshold)
        var opticsPack = params.opticsPack
        var applyMask = params.applyMask
        enc.setBytes(&intensity, length: MemoryLayout<Float>.size, index: 0)
        enc.setBytes(&outSize, length: MemoryLayout<SIMD2<UInt32>>.size, index: 1)
        enc.setBytes(&gamma, length: MemoryLayout<Float>.size, index: 2)
        enc.setBytes(&innerThreshold, length: MemoryLayout<Float>.size, index: 3)
        enc.setBytes(&opticsPack, length: MemoryLayout<SIMD3<Float>>.size, index: 4)
        enc.setBytes(&applyMask, length: MemoryLayout<Float>.size, index: 5)
        dispatch(enc: enc, pipeline: vignettePS, width: output.width, height: output.height)
    }

    private func encodeGlowComposite(
        enc: MTLComputeCommandEncoder,
        base: MTLTexture,
        bloom: MTLTexture,
        halation: MTLTexture,
        diffusion: MTLTexture,
        output: MTLTexture,
        bloomStrength: Float,
        halationIntensity: Float,
        diffusionAmount: Float,
        diffusionBase: Float
    ) {
        enc.setComputePipelineState(glowCompositePS)
        enc.setTexture(base, index: 0)
        enc.setTexture(bloom, index: 1)
        enc.setTexture(halation, index: 2)
        enc.setTexture(diffusion, index: 3)
        enc.setTexture(output, index: 4)
        var bs = bloomStrength
        var hi = halationIntensity
        var da = diffusionAmount
        var db = diffusionBase
        enc.setBytes(&bs, length: MemoryLayout<Float>.size, index: 0)
        enc.setBytes(&hi, length: MemoryLayout<Float>.size, index: 1)
        enc.setBytes(&da, length: MemoryLayout<Float>.size, index: 2)
        enc.setBytes(&db, length: MemoryLayout<Float>.size, index: 3)
        dispatch(enc: enc, pipeline: glowCompositePS, width: output.width, height: output.height)
    }

    /// Backlight Veil Phase 1b dispatcher. Verbatim Swift companion to the
    /// MSL kernel `filmtoneGlowCompositeBacklightVeil` (WGSL §4.4 port).
    private func encodeGlowCompositeBacklightVeil(
        enc: MTLComputeCommandEncoder,
        base: MTLTexture,
        bloom: MTLTexture,
        halation: MTLTexture,
        diffusion: MTLTexture,
        output: MTLTexture,
        bloomStrength: Float,
        halationIntensity: Float,
        diffusionAmount: Float,
        optical: OpticalScatterParams
    ) {
        enc.setComputePipelineState(glowCompositeBacklightVeilPS)
        enc.setTexture(base, index: 0)
        enc.setTexture(bloom, index: 1)
        enc.setTexture(halation, index: 2)
        enc.setTexture(diffusion, index: 3)
        enc.setTexture(output, index: 4)
        var bs = bloomStrength
        var hi = halationIntensity
        var da = diffusionAmount
        var dt = Float(optical.directTransmission)
        var br = Float(optical.blackRetention)
        var ss = Float(optical.scatterStrength)
        var hr = Float(optical.highlightReactivity)
        var ws = Float(optical.warmScatter)
        var st = Float(optical.spectralTail)
        enc.setBytes(&bs, length: MemoryLayout<Float>.size, index: 0)
        enc.setBytes(&hi, length: MemoryLayout<Float>.size, index: 1)
        enc.setBytes(&da, length: MemoryLayout<Float>.size, index: 2)
        enc.setBytes(&dt, length: MemoryLayout<Float>.size, index: 3)
        enc.setBytes(&br, length: MemoryLayout<Float>.size, index: 4)
        enc.setBytes(&ss, length: MemoryLayout<Float>.size, index: 5)
        enc.setBytes(&hr, length: MemoryLayout<Float>.size, index: 6)
        enc.setBytes(&ws, length: MemoryLayout<Float>.size, index: 7)
        enc.setBytes(&st, length: MemoryLayout<Float>.size, index: 8)
        dispatch(
            enc: enc,
            pipeline: glowCompositeBacklightVeilPS,
            width: output.width,
            height: output.height
        )
    }

    private func dispatch(
        enc: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        width: Int,
        height: Int
    ) {
        let tg = MTLSize(width: 16, height: 16, depth: 1)
        let grid = MTLSize(width: width, height: height, depth: 1)
        if device.supportsFamily(.apple3) {
            // Apple GPUs since A11 support non-uniform threadgroups, which lets
            // us pass exact grid dimensions and avoid bounds-checking inside
            // the kernel.
            enc.dispatchThreads(grid, threadsPerThreadgroup: tg)
        } else {
            let tgCount = MTLSize(
                width: (width + tg.width - 1) / tg.width,
                height: (height + tg.height - 1) / tg.height,
                depth: 1
            )
            enc.dispatchThreadgroups(tgCount, threadsPerThreadgroup: tg)
        }
    }

    // MARK: Texture allocation

    private func allocatePool(
        outSize: CGSize,
        bloomLevels: Int,
        bloomInitial: Double,
        halationLevels: Int,
        halationInitial: Double,
        diffusionLevels: Int,
        diffusionInitial: Double
    ) -> Bool {
        let w = max(1, Int(outSize.width.rounded()))
        let h = max(1, Int(outSize.height.rounded()))

        guard
            let inTex = makeTexture(width: w, height: h, label: "filmtone-glow-input"),
            let outTex = makeTexture(width: w, height: h, label: "filmtone-glow-output"),
            let bloomP = makeTexture(width: w, height: h, label: "filmtone-glow-bloom-plate"),
            let halationP = makeTexture(width: w, height: h, label: "filmtone-glow-halation-plate"),
            let bloomF = makeTexture(width: w, height: h, label: "filmtone-glow-bloom-final"),
            let halationF = makeTexture(width: w, height: h, label: "filmtone-glow-halation-final"),
            let diffusionF = makeTexture(width: w, height: h, label: "filmtone-glow-diffusion-final"),
            let vignetteF = makeTexture(width: w, height: h, label: "filmtone-vignette-final")
        else {
            return false
        }

        guard
            let bloomDown = allocateMipChain(
                base: outSize, levels: bloomLevels, initial: bloomInitial, prefix: "filmtone-glow-bloom-down"),
            let bloomAcc = allocateMipChain(
                base: outSize, levels: bloomLevels, initial: bloomInitial, prefix: "filmtone-glow-bloom-acc"),
            let halDown = allocateMipChain(
                base: outSize, levels: halationLevels, initial: halationInitial, prefix: "filmtone-glow-halation-down"),
            let halAcc = allocateMipChain(
                base: outSize, levels: halationLevels, initial: halationInitial, prefix: "filmtone-glow-halation-acc"),
            let diffDown = allocateMipChain(
                base: outSize, levels: diffusionLevels, initial: diffusionInitial, prefix: "filmtone-glow-diffusion-down"),
            let diffAcc = allocateMipChain(
                base: outSize, levels: diffusionLevels, initial: diffusionInitial, prefix: "filmtone-glow-diffusion-acc")
        else {
            return false
        }

        self.inputTexture = inTex
        self.outputTexture = outTex
        self.bloomPlate = bloomP
        self.halationPlate = halationP
        self.bloomFinal = bloomF
        self.halationFinal = halationF
        self.diffusionFinal = diffusionF
        self.vignetteFinal = vignetteF
        self.bloomMipsDown = bloomDown
        self.bloomMipsAccum = bloomAcc
        self.halationMipsDown = halDown
        self.halationMipsAccum = halAcc
        self.diffusionMipsDown = diffDown
        self.diffusionMipsAccum = diffAcc
        return true
    }

    private func allocateMipChain(
        base: CGSize,
        levels: Int,
        initial: Double,
        prefix: String
    ) -> [MTLTexture]? {
        guard levels >= 1 else { return [] }
        var chain: [MTLTexture] = []
        var w = max(1.0, (base.width * initial).rounded())
        var h = max(1.0, (base.height * initial).rounded())
        for level in 0..<levels {
            guard let tex = makeTexture(
                width: max(1, Int(w)),
                height: max(1, Int(h)),
                label: "\(prefix)-\(level)"
            ) else {
                return nil
            }
            chain.append(tex)
            w = max(1.0, (w * 0.5).rounded())
            h = max(1.0, (h * 0.5).rounded())
        }
        return chain
    }

    private func makeTexture(width: Int, height: Int, label: String) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .private
        let tex = device.makeTexture(descriptor: desc)
        tex?.label = label
        return tex
    }

    // MARK: CI bridging

    private func ciImage(from texture: MTLTexture) -> CIImage? {
        // CI treats MTLTexture pixel (0,0) as bottom-left for the wrapped
        // CIImage; the round-trip through ciContext.render(_, to:) preserves
        // orientation since CI flips on the way in too.
        guard let image = CIImage(
            mtlTexture: texture,
            options: [.colorSpace: workingColorSpace]
        ) else {
            return nil
        }
        // Wrap matches outputExtent at origin .zero to match the CI graph
        // expectation downstream filters have.
        return image.cropped(to: CGRect(x: 0, y: 0, width: texture.width, height: texture.height))
    }

    // MARK: Math helpers (mirrors of FilmtoneExportSession statics)

    private func clampUnit(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    private func computeMipWeights(radius: Double, levels: Int) -> [Double] {
        (0..<levels).map { index in
            let t = Double(index) / Double(max(levels - 1, 1))
            let base = exp(-3.0 * (1.0 - radius) * t)
            let wide = exp(-0.5 * radius * (1.0 - t))
            return (base * (1.0 - radius)) + (wide * radius)
        }
    }

    private func halationColor(forHue hue: Double) -> SIMD3<Float> {
        // Mirrors FilmtoneExportSession.halationColor.
        let t = clampUnit(hue / 100.0)
        let red = (Double(0xe8) + (Double(0xc8 - 0xe8) * t)) / 255.0
        let green = (Double(0x10) + (Double(0x60 - 0x10) * t)) / 255.0
        let blue = (Double(0x20) + (Double(0x10 - 0x20) * t)) / 255.0
        return SIMD3<Float>(Float(red), Float(green), Float(blue))
    }

    // MARK: Metal shader source (compiled at init time)

    private static let metalSource: String = """
    #include <metal_stdlib>
    using namespace metal;

    constant float3 kFilmtoneLumaWeights = float3(0.2126, 0.7152, 0.0722);

    static half4 fmtSampleClampPx(texture2d<half, access::read> tex, int2 px) {
        int2 sz = int2(tex.get_width(), tex.get_height());
        // Mirror addressing: reflect coordinates that fall outside [0, sz-1].
        // mirrorRepeat in pixel space: tile=2*sz, mirroredUv folds back.
        int2 size2 = sz * 2;
        int2 wrapped = ((px % size2) + size2) % size2;
        int2 mirrored = wrapped;
        if (mirrored.x >= sz.x) { mirrored.x = size2.x - 1 - mirrored.x; }
        if (mirrored.y >= sz.y) { mirrored.y = size2.y - 1 - mirrored.y; }
        return tex.read(uint2(mirrored));
    }

    static half4 fmtSampleBilinearPx(texture2d<half, access::read> tex, float2 px) {
        // Bilinear interpolation with mirror addressing.
        float2 base = floor(px - 0.5);
        float2 frac = (px - 0.5) - base;
        int2 b = int2(base);
        half4 a00 = fmtSampleClampPx(tex, b + int2(0, 0));
        half4 a10 = fmtSampleClampPx(tex, b + int2(1, 0));
        half4 a01 = fmtSampleClampPx(tex, b + int2(0, 1));
        half4 a11 = fmtSampleClampPx(tex, b + int2(1, 1));
        half4 r0 = mix(a00, a10, half(frac.x));
        half4 r1 = mix(a01, a11, half(frac.x));
        return mix(r0, r1, half(frac.y));
    }

    kernel void filmtoneSoftKneeHighlight(
        texture2d<half, access::read>  inTex  [[ texture(0) ]],
        texture2d<half, access::write> outTex [[ texture(1) ]],
        constant float  &threshold [[ buffer(0) ]],
        constant float  &knee      [[ buffer(1) ]],
        constant float3 &tint      [[ buffer(2) ]],
        uint2 gid [[ thread_position_in_grid ]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        half4 src = inTex.read(gid);
        float3 srcRgb = float3(src.rgb);
        float luma = dot(srcRgb, kFilmtoneLumaWeights);
        float safeThreshold = max(threshold, 1e-4);
        float safeKnee = max(knee * safeThreshold, 1e-4);
        float t = clamp((luma - threshold + safeKnee) / (2.0 * safeKnee), 0.0, 1.0);
        float contribution = t * t * mix(safeKnee, 1.0, t);
        contribution = max(contribution, max(0.0, luma - threshold));
        float3 result = srcRgb * contribution * tint;
        outTex.write(half4(half3(result), src.a), gid);
    }

    kernel void filmtoneCopyTexture(
        texture2d<half, access::read>  inTex  [[ texture(0) ]],
        texture2d<half, access::write> outTex [[ texture(1) ]],
        uint2 gid [[ thread_position_in_grid ]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        // Same dimensions only — caller guarantees src.size == dst.size.
        outTex.write(inTex.read(gid), gid);
    }

    // Write-only clear. Used when an inactive glow component still needs its
    // contribution texture zeroed out before the composite kernel reads it.
    // Must not be merged with `filmtoneSoftKneeHighlight` to avoid an
    // undefined read+write alias on a single texture.
    kernel void filmtoneClearTexture(
        texture2d<half, access::write> outTex [[ texture(0) ]],
        uint2 gid [[ thread_position_in_grid ]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        outTex.write(half4(half3(0.0), half(1.0)), gid);
    }

    // 13-tap COD:AW dual-filter tent downsample. Source is sampled in pixel
    // coords centered at the destination pixel, with mirrored addressing
    // mirroring the existing Core Image GLSL kernel exactly.
    kernel void filmtoneTentDownsample(
        texture2d<half, access::read>  inTex  [[ texture(0) ]],
        texture2d<half, access::write> outTex [[ texture(1) ]],
        constant uint2 &srcSize [[ buffer(0) ]],
        constant uint2 &dstSize [[ buffer(1) ]],
        uint2 gid [[ thread_position_in_grid ]]
    ) {
        if (gid.x >= dstSize.x || gid.y >= dstSize.y) return;
        float2 sourceStep = float2(srcSize) / max(float2(dstSize), float2(1.0));
        // Center of destination pixel in source pixel coords.
        float2 srcCenter = (float2(gid) + 0.5) * sourceStep;

        half4 a  = fmtSampleBilinearPx(inTex, srcCenter + float2(-2.0,  2.0));
        half4 b  = fmtSampleBilinearPx(inTex, srcCenter + float2( 0.0,  2.0));
        half4 c  = fmtSampleBilinearPx(inTex, srcCenter + float2( 2.0,  2.0));
        half4 dd = fmtSampleBilinearPx(inTex, srcCenter + float2(-1.0,  1.0));
        half4 e  = fmtSampleBilinearPx(inTex, srcCenter + float2( 1.0,  1.0));
        half4 f  = fmtSampleBilinearPx(inTex, srcCenter + float2(-2.0,  0.0));
        half4 g  = fmtSampleBilinearPx(inTex, srcCenter);
        half4 h  = fmtSampleBilinearPx(inTex, srcCenter + float2( 2.0,  0.0));
        half4 ii = fmtSampleBilinearPx(inTex, srcCenter + float2(-1.0, -1.0));
        half4 j  = fmtSampleBilinearPx(inTex, srcCenter + float2( 1.0, -1.0));
        half4 k  = fmtSampleBilinearPx(inTex, srcCenter + float2(-2.0, -2.0));
        half4 l  = fmtSampleBilinearPx(inTex, srcCenter + float2( 0.0, -2.0));
        half4 m  = fmtSampleBilinearPx(inTex, srcCenter + float2( 2.0, -2.0));

        half4 outV = ((dd + e + ii + j) * half(0.125))
                   + (g * half(0.125))
                   + ((a + c + k + m) * half(0.03125))
                   + ((b + f + h + l) * half(0.0625));
        outTex.write(outV, gid);
    }

    // 9-tap COD:AW dual-filter tent upsample.
    kernel void filmtoneTentUpsample(
        texture2d<half, access::read>  inTex  [[ texture(0) ]],
        texture2d<half, access::write> outTex [[ texture(1) ]],
        constant uint2 &srcSize [[ buffer(0) ]],
        constant uint2 &dstSize [[ buffer(1) ]],
        uint2 gid [[ thread_position_in_grid ]]
    ) {
        if (gid.x >= dstSize.x || gid.y >= dstSize.y) return;
        float2 sourceStep = float2(srcSize) / max(float2(dstSize), float2(1.0));
        float2 srcCenter = (float2(gid) + 0.5) * sourceStep;

        half4 s  = fmtSampleBilinearPx(inTex, srcCenter);
        half4 s0 = fmtSampleBilinearPx(inTex, srcCenter + float2(-1.0,  1.0));
        half4 s1 = fmtSampleBilinearPx(inTex, srcCenter + float2( 0.0,  1.0));
        half4 s2 = fmtSampleBilinearPx(inTex, srcCenter + float2( 1.0,  1.0));
        half4 s3 = fmtSampleBilinearPx(inTex, srcCenter + float2(-1.0,  0.0));
        half4 s4 = fmtSampleBilinearPx(inTex, srcCenter + float2( 1.0,  0.0));
        half4 s5 = fmtSampleBilinearPx(inTex, srcCenter + float2(-1.0, -1.0));
        half4 s6 = fmtSampleBilinearPx(inTex, srcCenter + float2( 0.0, -1.0));
        half4 s7 = fmtSampleBilinearPx(inTex, srcCenter + float2( 1.0, -1.0));

        half4 sum = (s * half(4.0))
                  + ((s1 + s3 + s4 + s6) * half(2.0))
                  + (s0 + s2 + s5 + s7);
        outTex.write(sum / half(16.0), gid);
    }

    // Tent upsample of low-res, multiply by `weight`, add to high-res, write
    // to output. Equivalent to the CI sequence:
    //   restored = tentUpsample(low, to: high.extent)
    //   weighted = restored * weight
    //   output = weighted + high
    kernel void filmtoneTentUpsampleAccumulate(
        texture2d<half, access::read>  lowRes   [[ texture(0) ]],
        texture2d<half, access::read>  highRes  [[ texture(1) ]],
        texture2d<half, access::write> outTex   [[ texture(2) ]],
        constant uint2 &lowSize [[ buffer(0) ]],
        constant uint2 &outSize [[ buffer(1) ]],
        constant float &weight  [[ buffer(2) ]],
        uint2 gid [[ thread_position_in_grid ]]
    ) {
        if (gid.x >= outSize.x || gid.y >= outSize.y) return;
        float2 sourceStep = float2(lowSize) / max(float2(outSize), float2(1.0));
        float2 srcCenter = (float2(gid) + 0.5) * sourceStep;

        half4 s  = fmtSampleBilinearPx(lowRes, srcCenter);
        half4 s0 = fmtSampleBilinearPx(lowRes, srcCenter + float2(-1.0,  1.0));
        half4 s1 = fmtSampleBilinearPx(lowRes, srcCenter + float2( 0.0,  1.0));
        half4 s2 = fmtSampleBilinearPx(lowRes, srcCenter + float2( 1.0,  1.0));
        half4 s3 = fmtSampleBilinearPx(lowRes, srcCenter + float2(-1.0,  0.0));
        half4 s4 = fmtSampleBilinearPx(lowRes, srcCenter + float2( 1.0,  0.0));
        half4 s5 = fmtSampleBilinearPx(lowRes, srcCenter + float2(-1.0, -1.0));
        half4 s6 = fmtSampleBilinearPx(lowRes, srcCenter + float2( 0.0, -1.0));
        half4 s7 = fmtSampleBilinearPx(lowRes, srcCenter + float2( 1.0, -1.0));

        half4 sum = (s * half(4.0))
                  + ((s1 + s3 + s4 + s6) * half(2.0))
                  + (s0 + s2 + s5 + s7);
        half4 restored = sum / half(16.0);
        half4 weighted = restored * half(weight);
        half4 highVal = highRes.read(gid);
        outTex.write(weighted + highVal, gid);
    }

    static float3 fmtGlowShoulder(float3 energy) {
        return 1.0 - exp(-max(energy, float3(0.0)));
    }

    static float fmtGlowHeadroom(float3 baseRgb, float floorValue) {
        float luma = dot(baseRgb, kFilmtoneLumaWeights);
        return mix(floorValue, 1.0, sqrt(clamp(1.0 - luma, 0.0, 1.0)));
    }

    kernel void filmtoneGlowComposite(
        texture2d<half, access::read>  baseTex      [[ texture(0) ]],
        texture2d<half, access::read>  bloomTex     [[ texture(1) ]],
        texture2d<half, access::read>  halationTex  [[ texture(2) ]],
        texture2d<half, access::read>  diffusionTex [[ texture(3) ]],
        texture2d<half, access::write> outTex       [[ texture(4) ]],
        constant float &bloomStrength      [[ buffer(0) ]],
        constant float &halationIntensity  [[ buffer(1) ]],
        constant float &diffusionAmount    [[ buffer(2) ]],
        constant float &diffusionBase      [[ buffer(3) ]],
        uint2 gid [[ thread_position_in_grid ]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        half4 base = baseTex.read(gid);
        float3 baseRgb = float3(base.rgb);
        float3 result = baseRgb;

        half4 bloom = bloomTex.read(gid);
        half4 halation = halationTex.read(gid);
        float3 glowEnergy = float3(bloom.rgb) * bloomStrength
                          + float3(halation.rgb) * halationIntensity;
        float3 glow = fmtGlowShoulder(glowEnergy) * fmtGlowHeadroom(baseRgb, 0.82);
        result = result + min(glow, max(float3(0.0), float3(1.0) - result));

        if (diffusionAmount > 0.0) {
            half4 diff = diffusionTex.read(gid);
            float3 diffOpacity = fmtGlowShoulder(float3(diff.rgb) * diffusionAmount * diffusionBase)
                               * fmtGlowHeadroom(baseRgb, 0.88);
            result = result + min(diffOpacity, max(float3(0.0), float3(1.0) - result));
        }

        outTex.write(half4(half3(clamp(result, float3(0.0), float3(1.0))), base.a), gid);
    }

    // Backlight Veil composite — verbatim MSL port of WGSL §4.4
    // (composite.frag.wgsl.ts:288-316). Same channel weights, smoothstep
    // edges, and warm-bias coefficients as the iOS CI kernel
    // `glowCompositeBacklightVeil` and the Swift CPU goldens
    // (scripts/swift/test-backlight-veil-composite.swift). Only invoked when
    // GlowFrameParams.opticalScatter is non-nil — the legacy
    // `filmtoneGlowComposite` kernel above stays the path for every other
    // render so existing exports remain byte-equivalent. Output is
    // intentionally unclamped so HDR scatter survives into the vignette /
    // final-encode stages, matching WGSL.
    kernel void filmtoneGlowCompositeBacklightVeil(
        texture2d<half, access::read>  baseTex      [[ texture(0) ]],
        texture2d<half, access::read>  bloomTex     [[ texture(1) ]],
        texture2d<half, access::read>  halationTex  [[ texture(2) ]],
        texture2d<half, access::read>  diffusionTex [[ texture(3) ]],
        texture2d<half, access::write> outTex       [[ texture(4) ]],
        constant float &bloomStrength       [[ buffer(0) ]],
        constant float &halationIntensity   [[ buffer(1) ]],
        constant float &diffusionAmount     [[ buffer(2) ]],
        constant float &directTransmission  [[ buffer(3) ]],
        constant float &blackRetention      [[ buffer(4) ]],
        constant float &scatterStrength     [[ buffer(5) ]],
        constant float &highlightReactivity [[ buffer(6) ]],
        constant float &warmScatter         [[ buffer(7) ]],
        constant float &spectralTail        [[ buffer(8) ]],
        uint2 gid [[ thread_position_in_grid ]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        half4 base = baseTex.read(gid);
        float3 baseRgb = float3(base.rgb);
        float3 bloomRgb = float3(bloomTex.read(gid).rgb) * bloomStrength;
        float3 halationRgb = float3(halationTex.read(gid).rgb) * halationIntensity;
        float3 diffusedRgb = float3(diffusionTex.read(gid).rgb);

        float baseLuma = dot(baseRgb, kFilmtoneLumaWeights);
        float shadowHold = 1.0 - smoothstep(0.02, 0.34, baseLuma);
        float directLoss = (1.0 - directTransmission)
                         * scatterStrength
                         * (1.0 - shadowHold * blackRetention * 0.75);
        float3 direct = baseRgb * (1.0 - directLoss);

        float highlightMask = smoothstep(0.42, 1.28, dot(max(baseRgb, float3(0.0)), kFilmtoneLumaWeights));
        float highlightDrive = mix(1.0, 1.0 + highlightMask * 1.65, highlightReactivity);
        float blackProtect = mix(1.0, smoothstep(0.04, 0.48, baseLuma), blackRetention);
        float3 warmBias = float3(
            1.0 + warmScatter * 0.18 + spectralTail * 0.12,
            1.0 + warmScatter * 0.05,
            1.0 - warmScatter * 0.10 - spectralTail * 0.08
        );
        float3 scatterEnergy = bloomRgb * 0.82
                             + halationRgb * 1.08
                             + diffusedRgb * diffusionAmount * 0.24;
        float3 scatter = fmtGlowShoulder(scatterEnergy * warmBias * scatterStrength * highlightDrive * blackProtect);

        float3 result = direct + scatter;
        outTex.write(half4(half3(result), base.a), gid);
    }

    // Vignette with optional ray-angle field mask (CIColorKernel `vignette`
    // direct port). UV is derived from `(gid + 0.5) / outSize`, matching the
    // CI kernel which uses `destCoord()` over an extent that always starts
    // at origin (0, 0) for the export pipeline. opticsPack carries
    // (tanHalfFovX, tanHalfFovY, refIncidence) from FilmtoneRayAngleOptics.
    // applyMask is 1.0 only when `cameraOptics.source == "metadata"`; for
    // "assumed" / nil / "fallback65" sources it is 0.0 so effectiveMask
    // collapses to 1.0 and the formula reproduces the pre-Stream-2 vignette
    // byte-equivalently.
    kernel void filmtoneVignette(
        texture2d<half, access::read>  inTex            [[ texture(0) ]],
        texture2d<half, access::write> outTex           [[ texture(1) ]],
        constant float  &intensity                      [[ buffer(0) ]],
        constant uint2  &outSize                        [[ buffer(1) ]],
        constant float  &gamma                          [[ buffer(2) ]],
        constant float  &innerThreshold                 [[ buffer(3) ]],
        constant float3 &opticsPack                     [[ buffer(4) ]],
        constant float  &applyMask                      [[ buffer(5) ]],
        uint2 gid [[ thread_position_in_grid ]]
    ) {
        if (gid.x >= outSize.x || gid.y >= outSize.y) return;
        half4 src = inTex.read(gid);
        float2 sz = float2(outSize);
        float2 uv = (float2(gid) + 0.5) / sz;
        float2 distPx = (uv - float2(0.5)) * sz;
        float halfDiag = length(sz * 0.5);
        float dist = length(distPx) / max(halfDiag, 1.0);

        float2 sensor = (uv - float2(0.5)) * 2.0;
        float rayX = sensor.x * opticsPack.x;
        float rayY = sensor.y * opticsPack.y;
        float viewZ = 1.0 / sqrt(rayX * rayX + rayY * rayY + 1.0);
        float incidence = 1.0 - viewZ;
        float refIncidence = max(opticsPack.z, 1.0e-5);
        float normalized = clamp(incidence / refIncidence, 0.0, 1.0);
        float gammaSafe = max(gamma, 0.001);
        float innerSafe = clamp(innerThreshold, 0.0, 0.8);
        float shaped = pow(normalized, gammaSafe);
        float t = clamp((shaped - innerSafe) / max(1.0 - innerSafe, 1.0e-6), 0.0, 1.0);
        float mask = t * t * (3.0 - 2.0 * t);
        float effectiveMask = mix(1.0, mask, clamp(applyMask, 0.0, 1.0));

        float vig = 1.0 - intensity * dist * dist * effectiveMask;
        vig = clamp(vig, 0.0, 1.0);
        float3 result = float3(src.rgb) * vig;
        outTex.write(half4(half3(result), src.a), gid);
    }
    """
}
