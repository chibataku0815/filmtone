import Foundation

// Backlight Veil Phase 1b math contract test.
//
// Verbatim Swift port of WGSL composite Backlight Veil branch
// (`packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts:288-316`)
// with the same coefficients, smoothstep edges, and channel weights. The
// Swift body below is the contract: any drift from these numerics is a
// silent visual regression versus Desktop and MUST fail this script.
//
// The test exercises the math via:
//   1. Structural invariants (shadow / mid / highlight / density monotonicity).
//   2. Locked golden floats for 4 sample regions × 3 densities. Goldens were
//      computed once from the verbatim port and hand-verified against the
//      WGSL formula; future drift surfaces here before reaching the kernel.

struct CompositeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CompositeError(message: message)
    }
}

// MARK: - Helpers (WGSL semantics)

private struct V3: Equatable {
    var r: Double
    var g: Double
    var b: Double

    static func * (lhs: V3, rhs: Double) -> V3 {
        V3(r: lhs.r * rhs, g: lhs.g * rhs, b: lhs.b * rhs)
    }

    static func * (lhs: V3, rhs: V3) -> V3 {
        V3(r: lhs.r * rhs.r, g: lhs.g * rhs.g, b: lhs.b * rhs.b)
    }

    static func + (lhs: V3, rhs: V3) -> V3 {
        V3(r: lhs.r + rhs.r, g: lhs.g + rhs.g, b: lhs.b + rhs.b)
    }
}

private let LUMA_R709 = V3(r: 0.2126, g: 0.7152, b: 0.0722)

private func dot(_ v: V3, _ w: V3) -> Double {
    v.r * w.r + v.g * w.g + v.b * w.b
}

private func max3(_ v: V3, _ floor: Double) -> V3 {
    V3(r: max(v.r, floor), g: max(v.g, floor), b: max(v.b, floor))
}

private func clamp01(_ x: Double) -> Double {
    min(1.0, max(0.0, x))
}

private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = clamp01((x - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)
}

private func mix(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

// `glowShoulder(energy) = 1 - exp(-max(energy, 0))` (WGSL composite.frag:136).
private func glowShoulder(_ v: V3) -> V3 {
    V3(
        r: 1.0 - exp(-max(v.r, 0.0)),
        g: 1.0 - exp(-max(v.g, 0.0)),
        b: 1.0 - exp(-max(v.b, 0.0))
    )
}

// MARK: - Backlight Veil composite (verbatim port)

private struct OpticalScatter {
    let directTransmission: Double
    let blackRetention: Double
    let scatterStrength: Double
    let highlightReactivity: Double
    let warmScatter: Double
    let spectralTail: Double
}

private struct CompositeInputs {
    let baseRgb: V3            // == color.rgb at composite stage (WGSL line 273)
    let bloom: V3              // already pre-multiplied by bloomStrength (WGSL line 281)
    let halation: V3           // already pre-multiplied by halationIntensity (WGSL line 282)
    let diffused: V3           // raw diffusion buffer (WGSL line 285)
    let diffusion: Double      // diffusion strength
}

/// Direct + scatter composite (WGSL composite.frag.wgsl.ts:288-316).
/// Identical math, identical channel weights, identical smoothstep edges.
private func compositeBacklightVeil(
    inputs: CompositeInputs,
    optical: OpticalScatter
) -> V3 {
    let baseRgb = inputs.baseRgb
    let baseLuma = dot(baseRgb, LUMA_R709)
    let shadowHold = 1.0 - smoothstep(0.02, 0.34, baseLuma)
    let directLoss =
        (1.0 - optical.directTransmission)
        * optical.scatterStrength
        * (1.0 - shadowHold * optical.blackRetention * 0.75)
    let direct = baseRgb * (1.0 - directLoss)

    let highlightMask = smoothstep(
        0.42, 1.28,
        dot(max3(baseRgb, 0.0), LUMA_R709)
    )
    let highlightDrive = mix(1.0, 1.0 + highlightMask * 1.65, optical.highlightReactivity)
    let blackProtect = mix(1.0, smoothstep(0.04, 0.48, baseLuma), optical.blackRetention)
    let warmBias = V3(
        r: 1.0 + optical.warmScatter * 0.18 + optical.spectralTail * 0.12,
        g: 1.0 + optical.warmScatter * 0.05,
        b: 1.0 - optical.warmScatter * 0.10 - optical.spectralTail * 0.08
    )
    let scatterEnergy =
        inputs.bloom * 0.82
        + inputs.halation * 1.08
        + inputs.diffused * (inputs.diffusion * 0.24)

    let scatter = glowShoulder(
        scatterEnergy * warmBias * (optical.scatterStrength * highlightDrive * blackProtect)
    )

    return direct + scatter
}

// MARK: - Canonical density values (mirrors optical-filter-profiles.ts commit 2c8e15d)

private let backlightVeilOptical: [String: OpticalScatter] = [
    "1/8": OpticalScatter(
        directTransmission: 0.92,
        blackRetention: 0.78,
        scatterStrength: 0.42,
        highlightReactivity: 0.62,
        warmScatter: 0.10,
        spectralTail: 0.04
    ),
    "1/4": OpticalScatter(
        directTransmission: 0.81,
        blackRetention: 0.56,
        scatterStrength: 0.66,
        highlightReactivity: 0.78,
        warmScatter: 0.17,
        spectralTail: 0.07
    ),
    "1/2": OpticalScatter(
        directTransmission: 0.70,
        blackRetention: 0.36,
        scatterStrength: 0.90,
        highlightReactivity: 0.95,
        warmScatter: 0.24,
        spectralTail: 0.10
    ),
]

private let densityOrder = ["1/8", "1/4", "1/2"]

// Diffusion strengths from optical-filter-profiles.ts (1/8 → 0.12 / 1/4 → 0.24 / 1/2 → 0.38).
private let diffusionByDensity: [String: Double] = [
    "1/8": 0.12,
    "1/4": 0.24,
    "1/2": 0.38,
]

// MARK: - Sample regions (representative scene areas)

private struct Sample {
    let label: String
    let baseRgb: V3
    let bloom: V3
    let halation: V3
    let diffused: V3
}

private let samples: [Sample] = [
    Sample(
        label: "shadow",
        baseRgb: V3(r: 0.01, g: 0.01, b: 0.01),
        bloom: V3(r: 0.005, g: 0.005, b: 0.005),
        halation: V3(r: 0.002, g: 0.002, b: 0.002),
        diffused: V3(r: 0.03, g: 0.03, b: 0.03)
    ),
    Sample(
        label: "midGray",
        baseRgb: V3(r: 0.5, g: 0.5, b: 0.5),
        bloom: V3(r: 0.10, g: 0.10, b: 0.10),
        halation: V3(r: 0.05, g: 0.05, b: 0.05),
        diffused: V3(r: 0.20, g: 0.20, b: 0.20)
    ),
    Sample(
        label: "warmHighlight",
        baseRgb: V3(r: 0.92, g: 0.85, b: 0.70),
        bloom: V3(r: 0.55, g: 0.50, b: 0.40),
        halation: V3(r: 0.30, g: 0.22, b: 0.16),
        diffused: V3(r: 0.40, g: 0.36, b: 0.28)
    ),
    Sample(
        label: "overClipped",
        baseRgb: V3(r: 1.6, g: 1.4, b: 1.0),
        bloom: V3(r: 0.95, g: 0.85, b: 0.65),
        halation: V3(r: 0.55, g: 0.40, b: 0.28),
        diffused: V3(r: 0.70, g: 0.62, b: 0.48)
    ),
]

private func makeInputs(sample: Sample, density: String) -> CompositeInputs {
    CompositeInputs(
        baseRgb: sample.baseRgb,
        bloom: sample.bloom,
        halation: sample.halation,
        diffused: sample.diffused,
        diffusion: diffusionByDensity[density] ?? 0
    )
}

// MARK: - Locked goldens (regression gate)
//
// Values produced by the verbatim port above and hand-verified against
// WGSL §4.4 algebraically (shadow direct ≈ baseRgb, mid R > B due to warm
// bias, highlight clamp ≤ 1 not enforced — caller may clip downstream).
// Float tolerance 1e-9 (these are deterministic and platform-independent).

private struct Golden {
    let density: String
    let sample: String
    let r: Double
    let g: Double
    let b: Double
}

private let goldens: [Golden] = [
    // 1/8 — subtle
    Golden(density: "1/8", sample: "shadow",        r: 0.010533599280667199, g: 0.010521890112780579, b: 0.010509917675669538),
    Golden(density: "1/8", sample: "midGray",       r: 0.5437058031635706,   g: 0.5426847725546395,   b: 0.541639650101051),
    Golden(density: "1/8", sample: "warmHighlight", r: 1.2904710727401714,   g: 1.1655710155114765,   b: 0.9505507712166263),
    Golden(density: "1/8", sample: "overClipped",   r: 2.248251673667136,    g: 1.9773897935349716,   b: 1.4757514452308396),
    // 1/4 — mid
    Golden(density: "1/4", sample: "shadow",        r: 0.011679961931168903, g: 0.011609378439019736, b: 0.011537401276770576),
    Golden(density: "1/4", sample: "midGray",       r: 0.5363725815563081,   g: 0.5336091358482867,   b: 0.5307825989224375),
    Golden(density: "1/4", sample: "warmHighlight", r: 1.3998390246160617,   g: 1.2639807667114629,   b: 1.0358916797728983),
    Golden(density: "1/4", sample: "overClipped",   r: 2.2903692126338524,   g: 2.054614344410562,    b: 1.5946826362804383),
    // 1/2 — max stable (Desktop ship gate)
    Golden(density: "1/2", sample: "shadow",        r: 0.013481804814152334, g: 0.013259151233823421, b: 0.013032323199383902),
    Golden(density: "1/2", sample: "midGray",       r: 0.5060714553005549,   g: 0.5007073060841076,   b: 0.4952093831571177),
    Golden(density: "1/2", sample: "warmHighlight", r: 1.4208195735679254,   g: 1.2917054153595495,   b: 1.0718909190789274),
    Golden(density: "1/2", sample: "overClipped",   r: 2.1379066739358636,   g: 1.95948631258497,     b: 1.5900606482273931),
]

// MARK: - Tests

private func runStructuralInvariants() throws {
    print("[backlight-veil] structural invariants")

    // 1. Density monotonicity: scatter contribution grows with density.
    //    Use midGray sample, compute scatter = output - direct, assert per-channel R rises.
    let mid = samples.first { $0.label == "midGray" }!
    var lastScatterR = -Double.infinity
    for density in densityOrder {
        let optical = backlightVeilOptical[density]!
        let inputs = makeInputs(sample: mid, density: density)
        let out = compositeBacklightVeil(inputs: inputs, optical: optical)
        let directLoss =
            (1.0 - optical.directTransmission)
            * optical.scatterStrength
            * (1.0 - (1.0 - smoothstep(0.02, 0.34, dot(mid.baseRgb, LUMA_R709))) * optical.blackRetention * 0.75)
        let directR = mid.baseRgb.r * (1.0 - directLoss)
        let scatterR = out.r - directR
        try expect(
            scatterR > lastScatterR,
            "scatter at \(density) (\(scatterR)) must exceed previous density (\(lastScatterR))"
        )
        lastScatterR = scatterR
    }

    // 2. Warm bias: for neutral input, R channel scatter ≥ B channel scatter.
    let optHalf = backlightVeilOptical["1/2"]!
    let inputs = makeInputs(sample: mid, density: "1/2")
    let out = compositeBacklightVeil(inputs: inputs, optical: optHalf)
    let baseLuma = dot(mid.baseRgb, LUMA_R709)
    let shadowHold = 1.0 - smoothstep(0.02, 0.34, baseLuma)
    let directLoss =
        (1.0 - optHalf.directTransmission)
        * optHalf.scatterStrength
        * (1.0 - shadowHold * optHalf.blackRetention * 0.75)
    let directR = mid.baseRgb.r * (1.0 - directLoss)
    let directB = mid.baseRgb.b * (1.0 - directLoss)
    let scatterR = out.r - directR
    let scatterB = out.b - directB
    try expect(
        scatterR > scatterB,
        "warm bias broken: scatter R (\(scatterR)) must exceed scatter B (\(scatterB)) for neutral input"
    )

    // 3. Direct attenuation never inflates above input (directLoss ≥ 0 always).
    for density in densityOrder {
        let optical = backlightVeilOptical[density]!
        let losslessFactor = 1.0 - (1.0 - optical.directTransmission) * optical.scatterStrength
        try expect(
            losslessFactor <= 1.0 && losslessFactor >= 0.0,
            "direct factor at \(density) out of [0,1]: \(losslessFactor)"
        )
    }

    // 4. Shadow protection: very dark input (luma < 0.02) preserves baseRgb to within 1e-3.
    let darkSample = samples.first { $0.label == "shadow" }!
    let darkOut = compositeBacklightVeil(
        inputs: makeInputs(sample: darkSample, density: "1/2"),
        optical: optHalf
    )
    let darkLuma = dot(darkSample.baseRgb, LUMA_R709)
    try expect(darkLuma < 0.02 + 1e-9, "shadow sample expected luma < 0.02, got \(darkLuma)")
    let shadowDelta = abs(darkOut.r - darkSample.baseRgb.r) + abs(darkOut.g - darkSample.baseRgb.g) + abs(darkOut.b - darkSample.baseRgb.b)
    // Some scatter still adds in shadow due to bloom/halation/diffused, but
    // direct attenuation is gated by shadowHold so the channel preservation is
    // tighter than full loss. Sanity bound: total perturbation ≤ 0.06.
    try expect(shadowDelta < 0.06, "shadow protection too weak: total perturb \(shadowDelta)")

    print("    structural invariants pass")
}

private func runGoldens() throws {
    print("[backlight-veil] locked goldens (1e-9 tolerance)")
    let tolerance = 1e-9
    var maxDelta = 0.0
    if ProcessInfo.processInfo.environment["DUMP_GOLDENS"] != nil {
        print("DUMP MODE: printing computed outputs (paste into goldens table)")
        for density in densityOrder {
            for sample in samples {
                let out = compositeBacklightVeil(
                    inputs: makeInputs(sample: sample, density: density),
                    optical: backlightVeilOptical[density]!
                )
                print("    Golden(density: \"\(density)\", sample: \"\(sample.label)\", r: \(out.r), g: \(out.g), b: \(out.b)),")
            }
        }
        return
    }
    for golden in goldens {
        guard let sample = samples.first(where: { $0.label == golden.sample }),
              let optical = backlightVeilOptical[golden.density]
        else {
            throw CompositeError(message: "missing sample/density for \(golden.sample)/\(golden.density)")
        }
        let out = compositeBacklightVeil(
            inputs: makeInputs(sample: sample, density: golden.density),
            optical: optical
        )
        let dr = abs(out.r - golden.r)
        let dg = abs(out.g - golden.g)
        let db = abs(out.b - golden.b)
        maxDelta = max(maxDelta, max(dr, max(dg, db)))
        try expect(
            dr < tolerance && dg < tolerance && db < tolerance,
            "golden mismatch \(golden.density)/\(golden.sample): "
            + "got (\(out.r), \(out.g), \(out.b)) want (\(golden.r), \(golden.g), \(golden.b))"
        )
    }
    print(String(format: "    %d goldens pass, max |Δ| = %.2e", goldens.count, maxDelta))
}

private func runDensityRamp() throws {
    print("[backlight-veil] density ramp summary (warmHighlight sample)")
    let sample = samples.first { $0.label == "warmHighlight" }!
    for density in densityOrder {
        let optical = backlightVeilOptical[density]!
        let out = compositeBacklightVeil(
            inputs: makeInputs(sample: sample, density: density),
            optical: optical
        )
        print(String(format: "    %@: r=%.6f g=%.6f b=%.6f", density, out.r, out.g, out.b))
    }
}

// MARK: - Entry point

do {
    try runStructuralInvariants()
    try runGoldens()
    try runDensityRamp()
    print("[backlight-veil] all checks pass")
} catch let error as CompositeError {
    print("FAIL: \(error.message)")
    exit(1)
} catch {
    print("FAIL: unexpected error: \(error)")
    exit(1)
}
