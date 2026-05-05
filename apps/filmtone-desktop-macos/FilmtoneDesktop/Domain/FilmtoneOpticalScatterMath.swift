import Foundation

// M5-M (CC-B) — Foundation-only port of the iOS `OpticalScatterParams`
// composite. The CIKL kernel `glowCompositeBacklightVeil` and the iOS
// MSL kernel `filmtoneGlowCompositeBacklightVeil` use identical math
// (WGSL §4.4 / `composite.frag.wgsl.ts:288-316`); this CPU port lets
// the Verify harness exercise the exact composite formula without
// pulling CoreImage into the Foundation-only build, and gives the
// CIKernel a single source of truth for the six scatter coefficients.

struct FilmtoneOpticalScatterParams: Hashable, Sendable {
    let directTransmission: Double
    let blackRetention: Double
    let scatterStrength: Double
    let highlightReactivity: Double
    let warmScatter: Double
    let spectralTail: Double
}

enum FilmtoneOpticalScatterMath {

    /// Luma weights match the iOS / WGSL `kFilmtoneLumaWeights` constant.
    static let lumaWeights: (Double, Double, Double) = (0.2126, 0.7152, 0.0722)

    /// Compose a single pixel through the Backlight Veil math. Inputs
    /// match the kernel arguments byte-for-byte: `base` is the pre-glow
    /// pixel, `bloom` / `halation` / `diffusion` are the energy plates
    /// already mip-blurred by the glow stage, `bloomStrength` /
    /// `halationIntensity` / `diffusionAmount` are the per-plate
    /// scalars, and `optical` is the resolved scatter profile.
    /// Output is intentionally unclamped (HDR scatter survives into
    /// vignette / final-encode), exactly like the WGSL composite.
    static func composite(
        base: (Double, Double, Double),
        bloom: (Double, Double, Double),
        halation: (Double, Double, Double),
        diffusion: (Double, Double, Double),
        bloomStrength: Double,
        halationIntensity: Double,
        diffusionAmount: Double,
        optical: FilmtoneOpticalScatterParams
    ) -> (Double, Double, Double) {
        let baseLuma = luma(base)
        let shadowHold = 1.0 - smoothstep(0.02, 0.34, baseLuma)
        let directLoss = (1.0 - optical.directTransmission)
            * optical.scatterStrength
            * (1.0 - shadowHold * optical.blackRetention * 0.75)
        let direct = (
            base.0 * (1.0 - directLoss),
            base.1 * (1.0 - directLoss),
            base.2 * (1.0 - directLoss)
        )

        let highlightMaskInput = luma((
            max(base.0, 0.0),
            max(base.1, 0.0),
            max(base.2, 0.0)
        ))
        let highlightMask = smoothstep(0.42, 1.28, highlightMaskInput)
        let highlightDrive = mix(1.0, 1.0 + highlightMask * 1.65, optical.highlightReactivity)
        let blackProtect = mix(1.0, smoothstep(0.04, 0.48, baseLuma), optical.blackRetention)

        let warmBias = (
            1.0 + optical.warmScatter * 0.18 + optical.spectralTail * 0.12,
            1.0 + optical.warmScatter * 0.05,
            1.0 - optical.warmScatter * 0.10 - optical.spectralTail * 0.08
        )

        let scatterEnergy = (
            bloom.0 * bloomStrength * 0.82
                + halation.0 * halationIntensity * 1.08
                + diffusion.0 * diffusionAmount * 0.24,
            bloom.1 * bloomStrength * 0.82
                + halation.1 * halationIntensity * 1.08
                + diffusion.1 * diffusionAmount * 0.24,
            bloom.2 * bloomStrength * 0.82
                + halation.2 * halationIntensity * 1.08
                + diffusion.2 * diffusionAmount * 0.24
        )
        let scatterDriver = optical.scatterStrength * highlightDrive * blackProtect
        let scatter = (
            shoulder(scatterEnergy.0 * warmBias.0 * scatterDriver),
            shoulder(scatterEnergy.1 * warmBias.1 * scatterDriver),
            shoulder(scatterEnergy.2 * warmBias.2 * scatterDriver)
        )

        return (direct.0 + scatter.0, direct.1 + scatter.1, direct.2 + scatter.2)
    }

    static func luma(_ rgb: (Double, Double, Double)) -> Double {
        lumaWeights.0 * rgb.0 + lumaWeights.1 * rgb.1 + lumaWeights.2 * rgb.2
    }

    static func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> Double {
        let span = max(edge1 - edge0, 1e-12)
        let t = max(0.0, min(1.0, (value - edge0) / span))
        return t * t * (3.0 - 2.0 * t)
    }

    static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    static func shoulder(_ energy: Double) -> Double {
        1.0 - exp(-max(energy, 0.0))
    }
}
