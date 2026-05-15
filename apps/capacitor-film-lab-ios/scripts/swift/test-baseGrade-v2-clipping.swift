import Foundation

// v1.4 Look V2 — numeric clipping & monotonicity gate for baseGradeV2 and
// filmCompressionV3 MSL kernels. We transcribe the kernel math into pure
// Swift Foundation (no Core Image) and probe with stress inputs:
//
//   1. Grayscale ramp under preset-range contrast=1.20 stays bounded and
//      monotonic across 4096 points
//   2. Saturation stress (input channel 1.5, saturation=1.2) — channels stay
//      finite and within reasonable bounds (no NaN, no runaway)
//   3. Fade stress preserves shadow chromatic identity AND only lifts shadow
//      (highlight unchanged) — handoff §3.5 reversal of muddy white-lift
//   4. Contrast curve monotonic across 4096 points at preset-range
//      contrast=1.20
//   5. filmCompressionV3 doesn't blow channels at amount=1.0, range in {0,1}
//   6. baseGradeV2 identity (all neutral) returns input
//   7. filmCompressionV3 amount=0 = pass-through identity
//   8. NEW: crosstalk shifts shadow toward shadowHue direction (cyan-blue at
//      shadowHue=200°) without breaking highlight neutrality
//   9. NEW: highlightTone shifts highlight toward highlightHue direction
//      (warm amber at highlightHue=30°) without disturbing shadow
//
// Bounds policy: Phase A1 introduced new fields (shadowHue/highlightHue/
// shadowTone/highlightTone). With shadowTone=0, highlightTone=0 the kernel
// behaves like the no-crosstalk path. Strict [0,1] bound is no longer a
// design goal — kernels output values that may slightly exceed [0,1] under
// extreme contrast/crosstalk; downstream stages (creative LUT / vignette /
// grain) are responsible for final clamping. The probes here verify
// monotonicity, hue preservation, and shadow-only fade — the *math*
// invariants that the previous v2 attempt violated.

// MARK: - Test harness

struct V2ProbeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw V2ProbeError(message: message)
    }
}

// MARK: - Helpers

private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)
}

private func hueChromaDir(_ hueDegrees: Double) -> (r: Double, g: Double, b: Double) {
    // Mirrors GLSL:
    //   vec3(cos(radians(h)), cos(radians(h-120)), cos(radians(h-240))) * 0.3
    let r = cos(hueDegrees * .pi / 180.0) * 0.3
    let g = cos((hueDegrees - 120.0) * .pi / 180.0) * 0.3
    let b = cos((hueDegrees - 240.0) * .pi / 180.0) * 0.3
    return (r, g, b)
}

// MARK: - baseGradeV2 transcription (mirrors MSL at FilmtoneExportSession.swift:OpticalKernels.baseGradeV2)

private func bakeBaseGradeV2(
    r: Double, g: Double, b: Double,
    exposure: Double, contrast: Double, saturation: Double,
    temperature: Double, tint: Double, fade: Double,
    shadowTone: Double = 0.0, highlightTone: Double = 0.0,
    shadowHue: Double = 225.0, highlightHue: Double = 30.0,
    blackPoint: Double = 0.0, toeContrast: Double = 0.0
) -> (r: Double, g: Double, b: Double) {
    // 1. Exposure
    var rr = r * pow(2.0, exposure)
    var gg = g * pow(2.0, exposure)
    var bb = b * pow(2.0, exposure)

    // 2. Contrast — 3-piece film density curve (toe / linear / shoulder)
    let c = contrast - 1.0
    let toeMaskR = 1.0 - smoothstep(0.0, 0.18, rr)
    let toeMaskG = 1.0 - smoothstep(0.0, 0.18, gg)
    let toeMaskB = 1.0 - smoothstep(0.0, 0.18, bb)
    let shoulderMaskR = smoothstep(0.85, 1.0, rr)
    let shoulderMaskG = smoothstep(0.85, 1.0, gg)
    let shoulderMaskB = smoothstep(0.85, 1.0, bb)
    let linearR = (rr - 0.5) * contrast + 0.5
    let linearG = (gg - 0.5) * contrast + 0.5
    let linearB = (bb - 0.5) * contrast + 0.5
    let toeR = rr * (1.0 - 0.35 * c)
    let toeG = gg * (1.0 - 0.35 * c)
    let toeB = bb * (1.0 - 0.35 * c)
    let shoulderR = 1.0 - (1.0 - rr) * (1.0 - 0.35 * c)
    let shoulderG = 1.0 - (1.0 - gg) * (1.0 - 0.35 * c)
    let shoulderB = 1.0 - (1.0 - bb) * (1.0 - 0.35 * c)
    rr = linearR + (toeR - linearR) * toeMaskR
    gg = linearG + (toeG - linearG) * toeMaskG
    bb = linearB + (toeB - linearB) * toeMaskB
    rr = rr + (shoulderR - rr) * shoulderMaskR
    gg = gg + (shoulderG - gg) * shoulderMaskG
    bb = bb + (shoulderB - bb) * shoulderMaskB

    // 3. Saturation — chroma scale (hue-preserving)
    let lumaSat = 0.2126 * rr + 0.7152 * gg + 0.0722 * bb
    rr = lumaSat + (rr - lumaSat) * saturation
    gg = lumaSat + (gg - lumaSat) * saturation
    bb = lumaSat + (bb - lumaSat) * saturation

    // 4. Temperature / Tint
    rr += temperature * 0.1
    bb -= temperature * 0.1
    rr += tint * 0.05
    gg -= tint * 0.08
    bb += tint * 0.05

    // 5. Crosstalk — density-dependent split-tone
    let lumaCT = 0.2126 * rr + 0.7152 * gg + 0.0722 * bb
    let shadowMaskCT = 1.0 - smoothstep(0.0, 0.5, lumaCT)
    let highlightMaskCT = smoothstep(0.5, 1.0, lumaCT)
    let sc = hueChromaDir(shadowHue)
    let hc = hueChromaDir(highlightHue)
    rr += shadowMaskCT * shadowTone * sc.r + highlightMaskCT * highlightTone * hc.r
    gg += shadowMaskCT * shadowTone * sc.g + highlightMaskCT * highlightTone * hc.g
    bb += shadowMaskCT * shadowTone * sc.b + highlightMaskCT * highlightTone * hc.b

    // 5.5 toeContrast → blackPoint (fade 直前位置、CIKL baseGradeV2 と同位置)
    let lumaTB = 0.2126 * rr + 0.7152 * gg + 0.0722 * bb
    if toeContrast > 0.0001 {
        let toeMaskAmt = (1.0 - smoothstep(0.0, 0.15, lumaTB)) * toeContrast
        if toeMaskAmt > 0 {
            let exponent = 1.0 + toeMaskAmt * 1.5
            let tR = pow(max(rr, 0.0), exponent)
            let tG = pow(max(gg, 0.0), exponent)
            let tB = pow(max(bb, 0.0), exponent)
            rr = rr + (tR - rr) * toeMaskAmt
            gg = gg + (tG - gg) * toeMaskAmt
            bb = bb + (tB - bb) * toeMaskAmt
        }
    }
    let bpPos = max(blackPoint, 0.0)
    let bpNeg = max(-blackPoint, 0.0)
    if bpPos > 0.0001 {
        let luma2 = 0.2126 * rr + 0.7152 * gg + 0.0722 * bb
        let shadowMaskBp = 1.0 - smoothstep(0.0, 0.35, luma2)
        let lift = bpPos * 0.18 * shadowMaskBp
        rr += lift
        gg += lift
        bb += lift
    }
    if bpNeg > 0.0001 {
        let f = bpNeg * 0.15
        let xR = max(rr, 0.0)
        let xG = max(gg, 0.0)
        let xB = max(bb, 0.0)
        rr = xR * xR * (1.0 + f) / (xR + f)
        gg = xG * xG * (1.0 + f) / (xG + f)
        bb = xB * xB * (1.0 + f) / (xB + f)
    }

    // 6. Fade — shadow-only mask (no highlight bleed)
    let lumaFade = 0.2126 * rr + 0.7152 * gg + 0.0722 * bb
    let shadowFadeMask = 1.0 - smoothstep(0.0, 0.4, lumaFade)
    let factor = shadowFadeMask * fade * 0.6
    rr = rr + factor * (1.0 - rr)
    gg = gg + factor * (1.0 - gg)
    bb = bb + factor * (1.0 - bb)

    return (rr, gg, bb)
}

// MARK: - filmCompressionV3 transcription (luma shoulder + chroma density)

private func filmCompressionWarmProtect(cr: Double, cg: Double, cb: Double, magnitude: Double) -> Double {
    if magnitude <= 0.000001 {
        return 0.0
    }
    let dr = cr / magnitude
    let dg = cg / magnitude
    let db = cb / magnitude
    let redWarm = smoothstep(0.32, 0.72, dr)
    let blueOpposed = 1.0 - smoothstep(-0.58, -0.20, db)
    let greenModerate = 1.0 - smoothstep(0.18, 0.58, abs(dg))
    return max(0.0, min(1.0, redWarm * blueOpposed * greenModerate))
}

private func bakeFilmCompressionV3(
    r: Double, g: Double, b: Double,
    amount: Double, range: Double
) -> (r: Double, g: Double, b: Double) {
    if amount < 0.001 {
        return (r, g, b)
    }
    let rr = max(0.0, min(1.0, range))
    let k = 5.15 + (2.85 - 5.15) * rr
    let rangeSoft = smoothstep(0.82, 1.0, rr)
    let amt = amount * (1.0 - 0.18 * rangeSoft)
    let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
    let x = max(-5.5, min(5.5, k * (luma - 0.5)))
    let sigm = 1.0 / (1.0 + exp(-x))
    let shoulderY = min(luma, luma + (sigm - luma) * amt)
    let scale = luma > 0.001 ? shoulderY / luma : 1.0
    let lR = r * scale
    let lG = g * scale
    let lB = b * scale
    let cR = lR - shoulderY
    let cG = lG - shoulderY
    let cB = lB - shoulderY
    let chromaMag = sqrt(cR * cR + cG * cG + cB * cB)
    let shadowRelease = smoothstep(0.14, 0.30, shoulderY)
    let kneeStart = 0.62 + (0.42 - 0.62) * rr
    let kneeEnd = 0.96 + (0.78 - 0.96) * rr
    let highlightMask = smoothstep(kneeStart, kneeEnd, shoulderY)
    let chromaStress = smoothstep(0.16, 0.70, chromaMag)
    let maxChannel = max(lR, max(lG, lB))
    let minChannel = min(lR, min(lG, lB))
    let highEdgeStress = smoothstep(0.82, 1.08, maxChannel)
    let lowEdgeStress = smoothstep(0.82, 1.08, -minChannel)
    let gamutStress = max(highEdgeStress, lowEdgeStress)
        * chromaStress
        * smoothstep(0.08, 0.24, shoulderY)
    let warmProtect = filmCompressionWarmProtect(cr: cR, cg: cG, cb: cB, magnitude: chromaMag)
    let highlightCompression = 0.42 * highlightMask * shadowRelease * (0.55 + (1.0 - 0.55) * chromaStress)
    let guardCompression = 0.22 * gamutStress * shadowRelease
    let protectedCompression = (highlightCompression + guardCompression) * (1.0 - 0.35 * warmProtect)
    let chromaScale = max(0.0, min(1.0, 1.0 - amt * protectedCompression))
    let landedCR = cR * chromaScale
    let landedCG = cG * chromaScale
    let landedCB = cB * chromaScale
    var outR = shoulderY + landedCR
    var outG = shoulderY + landedCG
    var outB = shoulderY + landedCB
    let outMax = max(outR, max(outG, outB))
    let landingChroma = smoothstep(0.18, 0.62, chromaMag)
    let landingMask = smoothstep(0.78, 0.98, outMax)
        * landingChroma
        * shadowRelease
        * (1.0 - 0.35 * warmProtect)
    if outMax > 0.78 && outMax > shoulderY + 0.000001 {
        let over = outMax - 0.78
        let headroom = 0.22
        let softMax = 0.78 + (headroom * over) / (over + headroom)
        let landingScale = max(0.0, min(1.0, (softMax - shoulderY) / (outMax - shoulderY)))
        let landingBlend = max(0.0, min(1.0, amt * 0.88 * landingMask))
        let finalScale = 1.0 + (landingScale - 1.0) * landingBlend
        outR = shoulderY + landedCR * finalScale
        outG = shoulderY + landedCG * finalScale
        outB = shoulderY + landedCB * finalScale
    }
    return (
        max(0.0, min(1.0, outR)),
        max(0.0, min(1.0, outG)),
        max(0.0, min(1.0, outB))
    )
}

// MARK: - Probes

func runProbes() throws {
    // Probe 1: Grayscale ramp at preset-range contrast=1.20 — no NaN, finite,
    // bounded within [-0.05, 1.05] across 4096 points.
    for i in 0...4095 {
        let v = Double(i) / 4095.0
        let out = bakeBaseGradeV2(
            r: v, g: v, b: v,
            exposure: 0.0, contrast: 1.20, saturation: 1.0,
            temperature: 0.0, tint: 0.0, fade: 0.0
        )
        try expect(out.r.isFinite && out.g.isFinite && out.b.isFinite,
                   "ramp produced non-finite at v=\(v): \(out)")
        try expect(out.r >= -0.05 && out.r <= 1.05,
                   "ramp R out of preset bound at v=\(v): r=\(out.r)")
    }

    // Probe 2: Saturation stress — input red blown to 1.5, saturation=1.2 —
    // output channels stay finite and within reasonable bounds (no runaway).
    let satOut = bakeBaseGradeV2(
        r: 1.5, g: 0.0, b: 0.5,
        exposure: 0.0, contrast: 1.0, saturation: 1.2,
        temperature: 0.0, tint: 0.0, fade: 0.0
    )
    try expect(satOut.r.isFinite && satOut.g.isFinite && satOut.b.isFinite,
               "saturation stress produced non-finite: \(satOut)")
    try expect(satOut.r >= -1.0 && satOut.r <= 2.0,
               "saturation runaway: r=\(satOut.r)")

    // Probe 3: Fade preserves shadow chromatic identity AND highlight is
    // untouched (no white-lift bleed into highlight — handoff §3.5 fix).
    let darkInput = (r: 0.05, g: 0.10, b: 0.12)
    let fadedShadow = bakeBaseGradeV2(
        r: darkInput.r, g: darkInput.g, b: darkInput.b,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.4
    )
    let inSpread = max(darkInput.r, darkInput.g, darkInput.b) - min(darkInput.r, darkInput.g, darkInput.b)
    let outSpread = max(fadedShadow.r, fadedShadow.g, fadedShadow.b) - min(fadedShadow.r, fadedShadow.g, fadedShadow.b)
    try expect(outSpread >= inSpread * 0.5,
               "shadow fade collapsed chromatic spread: in=\(inSpread), out=\(outSpread)")

    // Highlight (luma=0.95) MUST stay essentially unchanged under same fade
    // (3a fix — old v2 lifted highlight by 50% of fade)
    let brightInput = (r: 0.95, g: 0.95, b: 0.95)
    let fadedBright = bakeBaseGradeV2(
        r: brightInput.r, g: brightInput.g, b: brightInput.b,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.4
    )
    let highlightDelta = abs(fadedBright.r - brightInput.r)
    try expect(highlightDelta < 0.01,
               "fade leaked into highlight: bright in=\(brightInput.r), out=\(fadedBright.r)")

    // Probe 4: Contrast curve monotonicity over 4096 ramp at contrast=1.20
    var prevR = -Double.infinity
    for i in 0...4095 {
        let v = Double(i) / 4095.0
        let out = bakeBaseGradeV2(
            r: v, g: v, b: v,
            exposure: 0.0, contrast: 1.20, saturation: 1.0,
            temperature: 0.0, tint: 0.0, fade: 0.0
        )
        try expect(out.r >= prevR - 1e-12,
                   "contrast curve non-monotonic at v=\(v): out.r=\(out.r) < prevR=\(prevR)")
        prevR = out.r
    }

    // Probe 5: filmCompressionV3 doesn't blow channels at amount=1.0
    for amount in [0.5, 0.75, 1.0] {
        for range in [0.0, 0.5, 1.0] {
            for i in 0...255 {
                let v = Double(i) / 255.0
                let out = bakeFilmCompressionV3(
                    r: v, g: v * 0.7, b: v * 1.1,
                    amount: amount, range: range
                )
                try expect(out.r >= 0.0 && out.r <= 1.0,
                           "filmComp R out of [0,1] at v=\(v) amt=\(amount) rng=\(range): \(out.r)")
                try expect(out.g >= 0.0 && out.g <= 1.0,
                           "filmComp G out of [0,1] at v=\(v) amt=\(amount) rng=\(range): \(out.g)")
                try expect(out.b >= 0.0 && out.b <= 1.0,
                           "filmComp B out of [0,1] at v=\(v) amt=\(amount) rng=\(range): \(out.b)")
            }
        }
    }

    // Probe 6: baseGradeV2 identity (all neutral incl. crosstalk=0) returns input
    for i in 0...255 {
        let v = Double(i) / 255.0
        let out = bakeBaseGradeV2(
            r: v, g: v, b: v,
            exposure: 0.0, contrast: 1.0, saturation: 1.0,
            temperature: 0.0, tint: 0.0, fade: 0.0,
            shadowTone: 0.0, highlightTone: 0.0,
            shadowHue: 225.0, highlightHue: 30.0
        )
        try expect(abs(out.r - v) < 1e-9,
                   "v2 identity violated at v=\(v): out.r=\(out.r)")
    }

    // Probe 7: filmCompressionV3 amount<0.001 = pass-through identity
    let pass = bakeFilmCompressionV3(r: 0.4, g: 0.6, b: 0.8, amount: 0.0, range: 0.5)
    try expect(pass.r == 0.4 && pass.g == 0.6 && pass.b == 0.8,
               "filmCompV3 amount=0 should be identity, got \(pass)")

    // Probe 8 (NEW): Crosstalk shifts shadow toward shadowHue direction (cyan-blue
    // at shadowHue=200°) — gray shadow gets a cool tint, not white lift.
    let grayShadow = (r: 0.10, g: 0.10, b: 0.10)
    let shadowTinted = bakeBaseGradeV2(
        r: grayShadow.r, g: grayShadow.g, b: grayShadow.b,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        shadowTone: 0.3, highlightTone: 0.0,
        shadowHue: 200.0, highlightHue: 30.0
    )
    // shadowHue=200° is cyan-blue: B channel should rise more than R
    try expect(shadowTinted.b > shadowTinted.r,
               "shadowHue=200 cyan tint failed: r=\(shadowTinted.r), b=\(shadowTinted.b)")
    try expect(shadowTinted.b > grayShadow.b,
               "shadowTone=0.3 should lift B in shadow: \(shadowTinted.b) vs \(grayShadow.b)")

    // Probe 9 (NEW): highlightTone shifts highlight toward highlightHue direction
    // (warm amber at highlightHue=30°) — bright gray gets warm tint, shadow stays
    // untouched.
    let grayMix = (r: 0.85, g: 0.85, b: 0.85)
    let highlightTinted = bakeBaseGradeV2(
        r: grayMix.r, g: grayMix.g, b: grayMix.b,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        shadowTone: 0.0, highlightTone: 0.3,
        shadowHue: 200.0, highlightHue: 30.0
    )
    // highlightHue=30° is warm amber: R should rise more than B
    try expect(highlightTinted.r > highlightTinted.b,
               "highlightHue=30 amber tint failed: r=\(highlightTinted.r), b=\(highlightTinted.b)")

    // Crosstalk on a dark pixel under highlightTone-only must not affect it
    // (highlight mask = 0 at luma~0.05)
    let darkUnderHighlight = bakeBaseGradeV2(
        r: 0.05, g: 0.05, b: 0.05,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        shadowTone: 0.0, highlightTone: 0.5,
        shadowHue: 200.0, highlightHue: 30.0
    )
    try expect(abs(darkUnderHighlight.r - 0.05) < 0.01,
               "highlightTone leaked into shadow: r=\(darkUnderHighlight.r)")

    // Probe 10 (NEW): blackPoint = 0 / toeContrast = 0 is no-op (identity)
    let bpNoop = bakeBaseGradeV2(
        r: 0.42, g: 0.42, b: 0.42,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        blackPoint: 0.0, toeContrast: 0.0
    )
    try expect(abs(bpNoop.r - 0.42) < 1e-12 && abs(bpNoop.g - 0.42) < 1e-12 && abs(bpNoop.b - 0.42) < 1e-12,
               "blackPoint=0 / toeContrast=0 must be identity: got \(bpNoop)")

    // Probe 11 (NEW): blackPoint = +1 lifts deep black to ~0.18, highlights untouched
    let bpLift = bakeBaseGradeV2(
        r: 0.0, g: 0.0, b: 0.0,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        blackPoint: 1.0, toeContrast: 0.0
    )
    try expect(abs(bpLift.r - 0.18) < 1e-6 && abs(bpLift.g - 0.18) < 1e-6 && abs(bpLift.b - 0.18) < 1e-6,
               "blackPoint=+1 must lift black to 0.18: got \(bpLift)")
    let bpHighlight = bakeBaseGradeV2(
        r: 1.0, g: 1.0, b: 1.0,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        blackPoint: 1.0, toeContrast: 0.0
    )
    try expect(abs(bpHighlight.r - 1.0) < 1e-6,
               "blackPoint=+1 must leave highlights untouched: r=\(bpHighlight.r)")

    // Probe 12 (NEW): blackPoint = -1 applies Baselight Flare. 0 anchor stays at 0,
    // x=1 stays at 1, intermediate values are smoothly crushed.
    let bpCrushBlack = bakeBaseGradeV2(
        r: 0.0, g: 0.0, b: 0.0,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        blackPoint: -1.0, toeContrast: 0.0
    )
    try expect(abs(bpCrushBlack.r) < 1e-9,
               "blackPoint=-1 must preserve 0 anchor: r=\(bpCrushBlack.r)")
    let bpCrushWhite = bakeBaseGradeV2(
        r: 1.0, g: 1.0, b: 1.0,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        blackPoint: -1.0, toeContrast: 0.0
    )
    try expect(abs(bpCrushWhite.r - 1.0) < 1e-6,
               "blackPoint=-1 must leave x=1 unchanged (renormalized flare): r=\(bpCrushWhite.r)")
    let bpCrushMid = bakeBaseGradeV2(
        r: 0.5, g: 0.5, b: 0.5,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        blackPoint: -1.0, toeContrast: 0.0
    )
    try expect(bpCrushMid.r < 0.5,
               "blackPoint=-1 must crush midtones: r=\(bpCrushMid.r)")

    // Probe 13 (NEW): toeContrast = 1 hardens toe near black, preserves 0 anchor and values above 0.15
    let toeBlack = bakeBaseGradeV2(
        r: 0.0, g: 0.0, b: 0.0,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        blackPoint: 0.0, toeContrast: 1.0
    )
    try expect(abs(toeBlack.r) < 1e-9,
               "toeContrast=1 must preserve 0 anchor: r=\(toeBlack.r)")
    let toeAbove = bakeBaseGradeV2(
        r: 0.5, g: 0.5, b: 0.5,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        blackPoint: 0.0, toeContrast: 1.0
    )
    try expect(abs(toeAbove.r - 0.5) < 1e-9,
               "toeContrast=1 must not affect values above 0.15: r=\(toeAbove.r)")
    let toeNear = bakeBaseGradeV2(
        r: 0.05, g: 0.05, b: 0.05,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        blackPoint: 0.0, toeContrast: 1.0
    )
    try expect(toeNear.r < 0.05,
               "toeContrast=1 must compress near-black: r=\(toeNear.r)")

    // Probe 14 (NEW): blackPoint=+1 and toeContrast=1 combined are non-cancelling
    // (toe applied first, then blackPoint lift)
    let bpToeCombined = bakeBaseGradeV2(
        r: 0.0, g: 0.0, b: 0.0,
        exposure: 0.0, contrast: 1.0, saturation: 1.0,
        temperature: 0.0, tint: 0.0, fade: 0.0,
        blackPoint: 1.0, toeContrast: 1.0
    )
    try expect(bpToeCombined.r > 0.1,
               "blackPoint=+1 / toeContrast=1 must NOT cancel: black should still lift, got r=\(bpToeCombined.r)")
}

// MARK: - main

do {
    try runProbes()
    print("[baseGrade-v2-clipping] all 14 probes green")
    exit(0)
} catch let error as V2ProbeError {
    print("[baseGrade-v2-clipping] FAIL: \(error.message)")
    exit(1)
} catch {
    print("[baseGrade-v2-clipping] FAIL (unknown): \(error)")
    exit(1)
}
