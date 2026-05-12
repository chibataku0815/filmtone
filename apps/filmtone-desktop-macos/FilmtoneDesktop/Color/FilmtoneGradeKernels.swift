import CoreImage

// CIColorKernel sources lifted verbatim from the iOS implementation
// (apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift,
// `OpticalKernels`). Phase 0 generator targets `presetVersion = "v2"` for all
// 4 built-in presets, so only the v2 kernels are wired here.
//
// Phase 2 C5a (per-pixel optical extension): vignette + grain added.
// Phase 2 C5c: RayAngleOptics integrated — vignette applyMask aware.
// Phase 2 C5b A.1: softKneeHighlight + glowComposite (CIColorKernel) and
// tentDownsample + tentUpsample (CIKernel) added for bloom mip pyramid.
// Phase 2 C5b A.3: radialRGBSplit + edgeSoftnessBlend (CIKernel) added for
// edgeOptics stage (radial chromatic aberration + edge softness blend).
//
// Kernel sources are CI Kernel Language (CIKL) strings; they have no UIKit
// dependency and run identically on macOS.

enum FilmtoneGradeKernels {
    static let baseGradeV2: CIColorKernel? = CIColorKernel(source: """
kernel vec4 baseGradeV2(__sample image, float exposure, float contrast, float saturation, float temperature, float tint, float fade, float shadowTone, float highlightTone, float shadowHue, float highlightHue) {
    vec4 color = image;

    color.rgb *= pow(2.0, exposure);

    float c = contrast - 1.0;
    vec3 toeMask = vec3(1.0) - smoothstep(vec3(0.0), vec3(0.18), color.rgb);
    vec3 shoulderMask = smoothstep(vec3(0.85), vec3(1.0), color.rgb);
    vec3 linearPart = (color.rgb - vec3(0.5)) * contrast + vec3(0.5);
    vec3 toePart = color.rgb * (1.0 - 0.35 * c);
    vec3 shoulderPart = vec3(1.0) - (vec3(1.0) - color.rgb) * (1.0 - 0.35 * c);
    color.rgb = mix(linearPart, toePart, toeMask);
    color.rgb = mix(color.rgb, shoulderPart, shoulderMask);

    float lumaSat = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 chroma = color.rgb - vec3(lumaSat);
    color.rgb = vec3(lumaSat) + chroma * saturation;

    color.r += temperature * 0.1;
    color.b -= temperature * 0.1;
    color.r += tint * 0.05;
    color.g -= tint * 0.08;
    color.b += tint * 0.05;

    float lumaCT = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float shadowMaskCT = 1.0 - smoothstep(0.0, 0.5, lumaCT);
    float highlightMaskCT = smoothstep(0.5, 1.0, lumaCT);
    vec3 shadowChroma = vec3(
        cos(radians(shadowHue)),
        cos(radians(shadowHue - 120.0)),
        cos(radians(shadowHue - 240.0))
    ) * 0.3;
    vec3 highlightChroma = vec3(
        cos(radians(highlightHue)),
        cos(radians(highlightHue - 120.0)),
        cos(radians(highlightHue - 240.0))
    ) * 0.3;
    color.rgb += shadowMaskCT * shadowTone * shadowChroma;
    color.rgb += highlightMaskCT * highlightTone * highlightChroma;

    float lumaFade = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float shadowFadeMask = 1.0 - smoothstep(0.0, 0.4, lumaFade);
    color.rgb = color.rgb + shadowFadeMask * fade * (vec3(1.0) - color.rgb) * 0.6;

    return color;
}
""")

    static let filmCompressionV3: CIColorKernel? = CIColorKernel(source: """
float filmCompressionWarmProtect(vec3 chroma, float mag) {
    if (mag <= 0.000001) {
        return 0.0;
    }
    vec3 dir = chroma / mag;
    float redWarm = smoothstep(0.32, 0.72, dir.r);
    float blueOpposed = 1.0 - smoothstep(-0.58, -0.20, dir.b);
    float greenModerate = 1.0 - smoothstep(0.18, 0.58, abs(dir.g));
    return clamp(redWarm * blueOpposed * greenModerate, 0.0, 1.0);
}

kernel vec4 filmCompressionV3(__sample image, float amount, float range) {
    vec4 color = image;
    if (amount < 0.001) {
        return color;
    }
    float r = clamp(range, 0.0, 1.0);
    float k = mix(5.15, 2.85, r);
    float rangeSoft = smoothstep(0.82, 1.0, r);
    float amt = amount * (1.0 - 0.18 * rangeSoft);
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float x = clamp(k * (luma - 0.5), -5.5, 5.5);
    float sigm = 1.0 / (1.0 + exp(-x));
    // One-sided shoulder: only roll highlights, never lift shadows. Without
    // the min(), the symmetric sigmoid lifts deep blacks and boosts shadow
    // chroma — the opposite of the filmic density target.
    float shoulderY = min(luma, mix(luma, sigm, amt));
    float scale = luma > 0.001 ? shoulderY / luma : 1.0;
    vec3 lumaCompressed = color.rgb * scale;
    vec3 chroma = lumaCompressed - vec3(shoulderY);
    float chromaMag = length(chroma);

    float shadowRelease = smoothstep(0.14, 0.30, shoulderY);
    float kneeStart = mix(0.62, 0.42, r);
    float kneeEnd = mix(0.96, 0.78, r);
    float highlightMask = smoothstep(kneeStart, kneeEnd, shoulderY);
    float chromaStress = smoothstep(0.16, 0.70, chromaMag);
    float maxChannel = max(max(lumaCompressed.r, lumaCompressed.g), lumaCompressed.b);
    float minChannel = min(min(lumaCompressed.r, lumaCompressed.g), lumaCompressed.b);
    float highEdgeStress = smoothstep(0.82, 1.08, maxChannel);
    float lowEdgeStress = smoothstep(0.82, 1.08, -minChannel);
    float gamutStress = max(highEdgeStress, lowEdgeStress)
        * chromaStress
        * smoothstep(0.08, 0.24, shoulderY);
    float warmProtect = filmCompressionWarmProtect(chroma, chromaMag);

    float highlightCompression = 0.42 * highlightMask * shadowRelease * mix(0.55, 1.0, chromaStress);
    float guardCompression = 0.22 * gamutStress * shadowRelease;
    float protectedCompression = (highlightCompression + guardCompression) * (1.0 - 0.35 * warmProtect);
    float chromaScale = clamp(1.0 - amt * protectedCompression, 0.0, 1.0);
    vec3 landedChroma = chroma * chromaScale;
    vec3 outColor = vec3(shoulderY) + landedChroma;
    float outMax = max(max(outColor.r, outColor.g), outColor.b);
    float landingChroma = smoothstep(0.18, 0.62, chromaMag);
    float landingMask = smoothstep(0.78, 0.98, outMax)
        * landingChroma
        * shadowRelease
        * (1.0 - 0.35 * warmProtect);
    if (outMax > 0.78 && outMax > shoulderY + 0.000001) {
        float over = outMax - 0.78;
        float headroom = 0.22;
        float softMax = 0.78 + (headroom * over) / (over + headroom);
        float landingScale = clamp((softMax - shoulderY) / (outMax - shoulderY), 0.0, 1.0);
        float landingBlend = clamp(amt * 0.88 * landingMask, 0.0, 1.0);
        float finalScale = mix(1.0, landingScale, landingBlend);
        outColor = vec3(shoulderY) + landedChroma * finalScale;
    }
    color.rgb = clamp(outColor, 0.0, 1.0);
    return color;
}
""")

    static let toeSeparation: CIColorKernel? = CIColorKernel(source: """
kernel vec4 toeSeparation(__sample image, float amount) {
    vec4 color = image;
    float amt = clamp(amount, 0.0, 1.0);
    if (amt < 0.001) {
        return color;
    }

    float y = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float blackProtect = smoothstep(0.025, 0.055, y);
    float release = 1.0 - smoothstep(0.18, 0.30, y);
    float band = blackProtect * release;
    if (band <= 0.000001) {
        return color;
    }

    float toeShape = max(0.0, 1.0 - y / 0.30);
    float lumaLift = y * toeShape * 0.22 * amt * band;
    float outY = y + lumaLift;
    float chromaScale = 1.0 + 0.08 * amt * band;
    vec3 outColor = vec3(outY) + (color.rgb - vec3(y)) * chromaScale;
    color.rgb = clamp(outColor, 0.0, 1.0);
    return color;
}
""")

    static let printStage: CIColorKernel? = CIColorKernel(source: """
vec3 applyPrintContrast(vec3 rgb, float amount) {
    if (amount < 0.001) {
        return rgb;
    }
    float k = mix(1.0, 5.0, amount);
    vec3 s = 1.0 / (1.0 + exp(-k * (rgb - 0.5)));
    return clamp(mix(rgb, s, amount), 0.0, 1.0);
}

kernel vec4 printStage(__sample image, float printContrast, float cyan, float magenta, float yellow) {
    vec4 color = image;
    float cmyScale = 0.15;
    color.r -= cyan * cmyScale;
    color.g -= magenta * cmyScale;
    color.b -= yellow * cmyScale;
    color.rgb = applyPrintContrast(color.rgb, printContrast);
    return vec4(clamp(color.rgb, 0.0, 1.0), image.a);
}
""")

    // Vignette kernel verbatim from iOS OpticalKernels (FilmtoneExportSession
    // line 4321-4347). With `applyMask = 0` (no source camera-optics metadata
    // path), ray-angle math collapses to the byte-identical pre-Stream-2
    // radial form `1 - intensity * dist^2`. macOS Native call site passes
    // applyMask=0 + identity opticsPack until FilmtoneRayAngleOptics is
    // ported in C5b/C7.
    static let vignette: CIColorKernel? = CIColorKernel(source: """
kernel vec4 vignette(__sample image, float intensity, vec2 extentOrigin, vec2 extentSize, float rayAngleGamma, float rayAngleInner, vec3 opticsPack, float applyMask) {
    vec4 color = image;
    vec2 uv = (destCoord() - extentOrigin) / extentSize;
    vec2 distPx = (uv - vec2(0.5, 0.5)) * extentSize;
    float halfDiag = length(extentSize * 0.5);
    float dist = length(distPx) / max(halfDiag, 1.0);

    vec2 sensor = (uv - vec2(0.5, 0.5)) * 2.0;
    float rayX = sensor.x * opticsPack.x;
    float rayY = sensor.y * opticsPack.y;
    float viewZ = 1.0 / sqrt(rayX * rayX + rayY * rayY + 1.0);
    float incidence = 1.0 - viewZ;
    float refIncidence = max(opticsPack.z, 1.0e-5);
    float normalized = clamp(incidence / refIncidence, 0.0, 1.0);
    float gammaSafe = max(rayAngleGamma, 0.001);
    float innerSafe = clamp(rayAngleInner, 0.0, 0.8);
    float shaped = pow(normalized, gammaSafe);
    float t = clamp((shaped - innerSafe) / max(1.0 - innerSafe, 1.0e-6), 0.0, 1.0);
    float mask = t * t * (3.0 - 2.0 * t);
    float effectiveMask = mix(1.0, mask, clamp(applyMask, 0.0, 1.0));

    float vig = 1.0 - intensity * dist * dist * effectiveMask;
    color.rgb *= clamp(vig, 0.0, 1.0);
    return color;
}
""")

    // Grain kernel verbatim from iOS OpticalKernels. `timeSeconds` advances
    // deterministic blended grain phases; for still export pass 0.
    // `sourceSeed` is a per-source salt; Phase 2 C5d wires
    // `FilmtoneGradePipeline.makeStableSourceSeed(from: sourceURL.absoluteString)`
    // verbatim from iOS L2411-2418 across still/video export + preview, so
    // macOS and iOS produce the same grain pattern for a given source URL.
    static let grain: CIColorKernel? = CIColorKernel(source: """
float grainPixelHash(vec2 p, float seed) {
    return fract(sin(dot(p + vec2(seed, seed * 0.73), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

float grainValueNoise(vec2 p, float seed) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = grainPixelHash(i, seed);
    float b = grainPixelHash(i + vec2(1.0, 0.0), seed);
    float c = grainPixelHash(i + vec2(0.0, 1.0), seed);
    float d = grainPixelHash(i + vec2(1.0, 1.0), seed);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float grainClumpHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grainClumpNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = grainClumpHash(i);
    float b = grainClumpHash(i + vec2(1.0, 0.0));
    float c = grainClumpHash(i + vec2(0.0, 1.0));
    float d = grainClumpHash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 grainRotate(vec2 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float grainFineNoise(vec2 p, float seed) {
    vec2 a = grainRotate(p * 1.07, 0.73 + seed * 0.011);
    vec2 b = grainRotate(p * 0.61 + vec2(13.7, 2.1), -0.52 + seed * 0.007);
    float n1 = grainPixelHash(floor(a), seed * 1.21 + 19.0);
    float n2 = grainValueNoise(b, seed * 0.83 + 47.0);
    return n1 * 0.58 + n2 * 0.42;
}

vec4 grainSignal(vec2 pixelCoord, float grainFrame, float sourceSeed, float size, float coarseBlend) {
    float fineSeed = grainFrame * 1.7 + sourceSeed * 13.0;
    vec2 fineWarp = vec2(
        grainValueNoise(pixelCoord / 96.0 + vec2(sourceSeed * 0.013, grainFrame * 0.17), fineSeed + 5.0),
        grainValueNoise(pixelCoord / 113.0 + vec2(sourceSeed * 0.019 + 9.0, grainFrame * 0.11), fineSeed + 11.0)
    );
    float fineScale = mix(1.34, 0.90, smoothstep(0.0, 0.25, size));
    vec2 fineCoord = pixelCoord * fineScale + fineWarp * 2.35;
    float fineLuma = grainFineNoise(fineCoord, fineSeed);
    float fineChromaR = grainFineNoise(fineCoord + vec2(37.2, 11.4), fineSeed + 101.0);
    float fineChromaB = grainFineNoise(fineCoord + vec2(7.6, 53.8), fineSeed + 211.0);

    float grainDiameter = mix(1.55, 6.40, pow(size, 0.68));
    vec2 grainCoord = pixelCoord / grainDiameter;
    vec2 grainCell = floor(grainCoord);
    float pixelLuma = grainPixelHash(pixelCoord, fineSeed + 3.0);
    float cellHard = grainPixelHash(grainCell, fineSeed);
    float cellSoft = grainValueNoise(
        grainCoord * mix(1.15, 0.72, size) + vec2(sourceSeed * 0.004, grainFrame * 0.031),
        fineSeed + 17.0
    );
    float coarseCore = mix(cellHard, cellSoft, 0.58);
    float coarseLuma = mix(pixelLuma, coarseCore, mix(0.34, 0.84, size));
    float lumaGrain = mix(fineLuma, coarseLuma, coarseBlend);

    float neighborScale = mix(1.25, grainDiameter * 0.74, coarseBlend);
    float neighborA = grainValueNoise((pixelCoord + vec2(neighborScale, 0.0)) / neighborScale, fineSeed + 29.0) - 0.5;
    float neighborB = grainValueNoise((pixelCoord + vec2(0.0, neighborScale)) / (neighborScale * 1.07), fineSeed + 37.0) - 0.5;
    float arMix = mix(0.10, 0.22, coarseBlend);
    lumaGrain = mix(lumaGrain, lumaGrain * 0.78 + (neighborA + neighborB) * 0.11, arMix);

    float coarseChromaR = grainValueNoise(grainCoord * 0.86 + vec2(5.0, sourceSeed * 0.01), fineSeed + 503.0) - 0.5;
    float coarseChromaB = grainValueNoise(grainCoord * 0.91 + vec2(sourceSeed * 0.008, 7.0), fineSeed + 1009.0) - 0.5;
    float chromaR = mix(fineChromaR, coarseChromaR, coarseBlend);
    float chromaB = mix(fineChromaB, coarseChromaB, coarseBlend);

    float clumpScale = mix(140.0, 24.0, size);
    float clump = grainClumpNoise((pixelCoord / clumpScale) + vec2(grainFrame * 0.43 + sourceSeed * 0.1, sourceSeed * 0.07));
    float fineDensity = mix(
        0.92,
        1.08,
        grainClumpNoise(pixelCoord / 170.0 + vec2(sourceSeed * 0.021 + 3.0, grainFrame * 0.09))
    );
    float coarseDensity = mix(1.0, 0.34 + clump * 1.32, size * 0.80);
    float densityMod = mix(fineDensity, coarseDensity, coarseBlend);
    return vec4(lumaGrain, chromaR, chromaB, densityMod);
}

kernel vec4 grain(__sample image, float intensity, float radialMix, float grainSize, float timeSeconds, float sourceSeed, vec2 extentOrigin, vec2 extentSize) {
    vec4 color = image;
    vec2 uv = (destCoord() - extentOrigin) / extentSize;
    float size = clamp(grainSize, 0.0, 1.0);
    float coarseBlend = smoothstep(0.12, 0.42, size);
    vec2 grainDelta = uv - vec2(0.5, 0.5);
    grainDelta.x *= extentSize.x / max(extentSize.y, 1.0);
    float grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);
    float grainRadialWeight = mix(0.76, 1.42, pow(grainRadial, 1.35));
    float grainRadialEffective = mix(1.0, grainRadialWeight, clamp(radialMix, 0.0, 1.0));

    vec2 pixelCoord = uv * extentSize;
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float chromaSpread = max(max(abs(color.r - color.g), abs(color.r - color.b)), abs(color.g - color.b));

    float grainClock = max(timeSeconds, 0.0) * mix(1.85, 2.75, coarseBlend);
    float grainFrameA = floor(grainClock);
    float grainPhase = smoothstep(0.0, 1.0, fract(grainClock));
    vec4 signalA = grainSignal(pixelCoord, grainFrameA, sourceSeed, size, coarseBlend);
    vec4 signalB = grainSignal(pixelCoord, grainFrameA + 1.0, sourceSeed, size, coarseBlend);
    float phaseVariance = (1.0 - grainPhase) * (1.0 - grainPhase) + grainPhase * grainPhase;
    float phaseGain = min(1.28, 1.0 / sqrt(max(phaseVariance, 0.001)));
    vec4 signal = mix(signalA, signalB, grainPhase);

    float lumaGrain = signal.x * phaseGain;
    float densityMod = signal.w;
    float deepShadowGate = smoothstep(0.025, 0.11, luma);
    float shadowPresence = mix(0.86, 1.18, smoothstep(0.08, 0.36, luma));
    float highlightGuard = mix(1.0, 0.58, smoothstep(0.58, 0.96, luma));
    float lumaVisibility = deepShadowGate * shadowPresence * highlightGuard;

    float monochromeChromaGate = mix(0.08, 1.0, smoothstep(0.025, 0.18, chromaSpread));
    float highlightChromaGate = mix(1.0, 0.38, smoothstep(0.52, 0.92, luma));
    float chromaGate = monochromeChromaGate * highlightChromaGate;
    float independentChroma = mix(0.050, 0.16, coarseBlend);
    float chromaCouple = mix(0.035, 0.11, coarseBlend);
    float chromaR = (signal.y * phaseGain * independentChroma + lumaGrain * chromaCouple) * chromaGate;
    float chromaB = (signal.z * phaseGain * independentChroma - lumaGrain * chromaCouple * 0.70) * chromaGate;

    float weight = intensity * mix(0.94, 1.08, coarseBlend) * grainRadialEffective * densityMod * lumaVisibility;
    color.r += (lumaGrain + chromaR) * weight;
    color.g += lumaGrain * weight;
    color.b += (lumaGrain + chromaB) * weight;
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    return color;
}
""")

    // softKneeHighlight: highlight plate extraction for bloom/halation pyramid
    // (verbatim from iOS OpticalKernels line 4227–4237)
    static let softKneeHighlight: CIColorKernel? = CIColorKernel(source: """
kernel vec4 softKneeHighlight(__sample image, float threshold, float knee, __color tintColor) {
    float luma = dot(image.rgb, vec3(0.2126, 0.7152, 0.0722));
    float safeThreshold = max(threshold, 1e-4);
    float safeKnee = max(knee * safeThreshold, 1e-4);
    float t = clamp((luma - threshold + safeKnee) / (2.0 * safeKnee), 0.0, 1.0);
    float contribution = t * t * mix(safeKnee, 1.0, t);
    contribution = max(contribution, max(0.0, luma - threshold));
    return vec4(image.rgb * contribution * tintColor.rgb, image.a);
}
""")

    // M5-M (CC-B): Backlight Veil composite — CI Kernel Language port of
    // the iOS MSL `filmtoneGlowCompositeBacklightVeil` (FilmtoneMetalOpticsRenderer)
    // and the WGSL §4.4 reference (`composite.frag.wgsl.ts:288-316`).
    // Same channel weights, smoothstep edges, and warm-bias coefficients
    // as `FilmtoneOpticalScatterMath.composite` so the CPU port (used by
    // Verify) and the GPU kernel produce the same result on a given pixel.
    // Selected only when `FilmtoneGradePipeline.apply` is invoked with a
    // Backlight Veil `opticalFilterProfileId`; the legacy `glowComposite`
    // kernel above remains the default path so non-veil renders stay
    // bytewise identical to pre-M5-M.
    static let glowCompositeBacklightVeil: CIColorKernel? = CIColorKernel(source: """
vec3 veilShoulder(vec3 energy) {
    return 1.0 - exp(-max(energy, vec3(0.0)));
}

kernel vec4 glowCompositeBacklightVeil(
    __sample base,
    __sample bloom,
    __sample halation,
    __sample diffusionImage,
    float bloomStrength,
    float halationIntensity,
    float diffusionAmount,
    float directTransmission,
    float blackRetention,
    float scatterStrength,
    float highlightReactivity,
    float warmScatter,
    float spectralTail
) {
    vec3 baseRgb = base.rgb;
    vec3 bloomRgb = bloom.rgb * bloomStrength;
    vec3 halationRgb = halation.rgb * halationIntensity;
    vec3 diffusedRgb = diffusionImage.rgb;

    float baseLuma = dot(baseRgb, vec3(0.2126, 0.7152, 0.0722));
    float shadowHold = 1.0 - smoothstep(0.02, 0.34, baseLuma);
    float directLoss = (1.0 - directTransmission)
                     * scatterStrength
                     * (1.0 - shadowHold * blackRetention * 0.75);
    vec3 direct = baseRgb * (1.0 - directLoss);

    float highlightMask = smoothstep(0.42, 1.28, dot(max(baseRgb, vec3(0.0)), vec3(0.2126, 0.7152, 0.0722)));
    float highlightDrive = mix(1.0, 1.0 + highlightMask * 1.65, highlightReactivity);
    float blackProtect = mix(1.0, smoothstep(0.04, 0.48, baseLuma), blackRetention);
    vec3 warmBias = vec3(
        1.0 + warmScatter * 0.18 + spectralTail * 0.12,
        1.0 + warmScatter * 0.05,
        1.0 - warmScatter * 0.10 - spectralTail * 0.08
    );
    vec3 scatterEnergy = bloomRgb * 0.82
                       + halationRgb * 1.08
                       + diffusedRgb * diffusionAmount * 0.24;
    vec3 scatter = veilShoulder(scatterEnergy * warmBias * scatterStrength * highlightDrive * blackProtect);

    return vec4(direct + scatter, base.a);
}
""")

    // glowComposite: bloom + halation + diffusion energy compositing
    // (verbatim from iOS OpticalKernels line 4239–4263)
    static let glowComposite: CIColorKernel? = CIColorKernel(source: """
vec3 glowShoulder(vec3 energy) {
    return 1.0 - exp(-max(energy, vec3(0.0)));
}

float glowHeadroom(vec3 baseRgb, float floorValue) {
    float luma = dot(baseRgb, vec3(0.2126, 0.7152, 0.0722));
    return mix(floorValue, 1.0, sqrt(clamp(1.0 - luma, 0.0, 1.0)));
}

kernel vec4 glowComposite(__sample base, __sample bloom, __sample halation, __sample diffusionImage, float bloomStrength, float halationIntensity, float diffusionAmount, float diffusionBase) {
    vec3 baseRgb = base.rgb;
    vec3 result = baseRgb;
    vec3 glowEnergy = bloom.rgb * bloomStrength + halation.rgb * halationIntensity;
    vec3 glow = glowShoulder(glowEnergy) * glowHeadroom(baseRgb, 0.82);
    result = result + min(glow, max(vec3(0.0), vec3(1.0) - result));

    if (diffusionAmount > 0.0) {
        vec3 diffOpacity = glowShoulder(diffusionImage.rgb * diffusionAmount * diffusionBase) * glowHeadroom(baseRgb, 0.88);
        result = result + min(diffOpacity, max(vec3(0.0), vec3(1.0) - result));
    }

    return vec4(clamp(result, 0.0, 1.0), base.a);
}
""")

    // tentDownsample: mirror-padded 13-tap tent downsample for mip pyramid
    // (verbatim from iOS OpticalKernels line 4424–4464)
    static let tentDownsample: CIKernel? = CIKernel(source: """
vec2 mirrorCoord(vec2 coord, vec2 origin, vec2 size) {
    vec2 safeSize = max(size, vec2(1.0, 1.0));
    vec2 uv = (coord - origin) / safeSize;
    vec2 tiled = mod(uv, 2.0);
    vec2 mirroredUv = 1.0 - abs(tiled - 1.0);
    return origin + (mirroredUv * safeSize);
}

vec4 sampleMirror(sampler image, vec2 coord, vec2 origin, vec2 size) {
    return sample(image, samplerTransform(image, mirrorCoord(coord, origin, size)));
}

kernel vec4 tentDownsample(sampler image, vec2 sourceOrigin, vec2 sourceSize, vec2 targetOrigin, vec2 sourceStep) {
    vec2 coord = destCoord();
    vec2 sourceCoord = sourceOrigin + ((coord - targetOrigin) * sourceStep);

    vec4 a = sampleMirror(image, sourceCoord + vec2(-2.0,  2.0), sourceOrigin, sourceSize);
    vec4 b = sampleMirror(image, sourceCoord + vec2( 0.0,  2.0), sourceOrigin, sourceSize);
    vec4 c = sampleMirror(image, sourceCoord + vec2( 2.0,  2.0), sourceOrigin, sourceSize);

    vec4 dd = sampleMirror(image, sourceCoord + vec2(-1.0,  1.0), sourceOrigin, sourceSize);
    vec4 e  = sampleMirror(image, sourceCoord + vec2( 1.0,  1.0), sourceOrigin, sourceSize);

    vec4 f = sampleMirror(image, sourceCoord + vec2(-2.0, 0.0), sourceOrigin, sourceSize);
    vec4 g = sampleMirror(image, sourceCoord, sourceOrigin, sourceSize);
    vec4 h = sampleMirror(image, sourceCoord + vec2( 2.0, 0.0), sourceOrigin, sourceSize);

    vec4 ii = sampleMirror(image, sourceCoord + vec2(-1.0, -1.0), sourceOrigin, sourceSize);
    vec4 j  = sampleMirror(image, sourceCoord + vec2( 1.0, -1.0), sourceOrigin, sourceSize);

    vec4 k = sampleMirror(image, sourceCoord + vec2(-2.0, -2.0), sourceOrigin, sourceSize);
    vec4 l = sampleMirror(image, sourceCoord + vec2( 0.0, -2.0), sourceOrigin, sourceSize);
    vec4 m = sampleMirror(image, sourceCoord + vec2( 2.0, -2.0), sourceOrigin, sourceSize);

    return ((dd + e + ii + j) * 0.125)
         + (g * 0.125)
         + ((a + c + k + m) * 0.03125)
         + ((b + f + h + l) * 0.0625);
}
""")

    // tentUpsample: mirror-padded 9-tap tent upsample for mip pyramid
    // (verbatim from iOS OpticalKernels line 4466–4498)
    static let tentUpsample: CIKernel? = CIKernel(source: """
vec2 mirrorCoord(vec2 coord, vec2 origin, vec2 size) {
    vec2 safeSize = max(size, vec2(1.0, 1.0));
    vec2 uv = (coord - origin) / safeSize;
    vec2 tiled = mod(uv, 2.0);
    vec2 mirroredUv = 1.0 - abs(tiled - 1.0);
    return origin + (mirroredUv * safeSize);
}

vec4 sampleMirror(sampler image, vec2 coord, vec2 origin, vec2 size) {
    return sample(image, samplerTransform(image, mirrorCoord(coord, origin, size)));
}

kernel vec4 tentUpsample(sampler image, vec2 sourceOrigin, vec2 sourceSize, vec2 targetOrigin, vec2 sourceStep) {
    vec2 coord = destCoord();
    vec2 sourceCoord = sourceOrigin + ((coord - targetOrigin) * sourceStep);

    vec4 s  = sampleMirror(image, sourceCoord, sourceOrigin, sourceSize);
    vec4 s0 = sampleMirror(image, sourceCoord + vec2(-1.0,  1.0), sourceOrigin, sourceSize);
    vec4 s1 = sampleMirror(image, sourceCoord + vec2( 0.0,  1.0), sourceOrigin, sourceSize);
    vec4 s2 = sampleMirror(image, sourceCoord + vec2( 1.0,  1.0), sourceOrigin, sourceSize);
    vec4 s3 = sampleMirror(image, sourceCoord + vec2(-1.0,  0.0), sourceOrigin, sourceSize);
    vec4 s4 = sampleMirror(image, sourceCoord + vec2( 1.0,  0.0), sourceOrigin, sourceSize);
    vec4 s5 = sampleMirror(image, sourceCoord + vec2(-1.0, -1.0), sourceOrigin, sourceSize);
    vec4 s6 = sampleMirror(image, sourceCoord + vec2( 0.0, -1.0), sourceOrigin, sourceSize);
    vec4 s7 = sampleMirror(image, sourceCoord + vec2( 1.0, -1.0), sourceOrigin, sourceSize);

    vec4 upsampled = (s * 4.0)
                   + ((s1 + s3 + s4 + s6) * 2.0)
                   + (s0 + s2 + s5 + s7);
    return upsampled / 16.0;
}
""")

    // Phase 5-B Detail Softness — amplitude-gated bilateral detail-layer
    // attenuation. Working color space at the insertion point is linear
    // sRGB (FilmtoneCIContext) so Rec.709 luma weights apply directly.
    // Identity at `effectiveDetailSoftness == 0` is enforced both by
    // the Swift caller (short-circuit before kernel apply) and by the
    // kernel itself (`return center` guard) so any preview/export path
    // that skips the caller short-circuit still produces bit-identical
    // output. See packages/film-lab-core/src/detail-softness.ts for the
    // algorithm narrative.
    static let detailSoftness: CIKernel? = CIKernel(source: """
kernel vec4 detailSoftness(
    sampler image,
    float effectiveDetailSoftness,
    float kernelRadiusPx,
    float rangeSigma,
    float detailAmplitudeLo,
    float detailAmplitudeHi,
    float chromaAttenScale,
    float highlightBias
) {
    vec2 coord = destCoord();
    vec4 center = sample(image, samplerTransform(image, coord));
    if (effectiveDetailSoftness < 1e-4) {
        return center;
    }

    float r = max(kernelRadiusPx, 0.0001);
    float rd = r * 0.70710678;
    vec3 lumaWeights = vec3(0.2126, 0.7152, 0.0722);

    vec3 srcRGB = center.rgb;
    vec3 nE  = sample(image, samplerTransform(image, coord + vec2( r,  0.0))).rgb;
    vec3 nW  = sample(image, samplerTransform(image, coord + vec2(-r,  0.0))).rgb;
    vec3 nN  = sample(image, samplerTransform(image, coord + vec2( 0.0,  r))).rgb;
    vec3 nS  = sample(image, samplerTransform(image, coord + vec2( 0.0, -r))).rgb;
    vec3 nNE = sample(image, samplerTransform(image, coord + vec2( rd,  rd))).rgb;
    vec3 nNW = sample(image, samplerTransform(image, coord + vec2(-rd,  rd))).rgb;
    vec3 nSE = sample(image, samplerTransform(image, coord + vec2( rd, -rd))).rgb;
    vec3 nSW = sample(image, samplerTransform(image, coord + vec2(-rd, -rd))).rgb;

    float lumaC  = dot(srcRGB, lumaWeights);
    float sigma2 = max(rangeSigma * rangeSigma, 1e-6);

    float dE  = dot(nE,  lumaWeights) - lumaC;
    float dW  = dot(nW,  lumaWeights) - lumaC;
    float dN  = dot(nN,  lumaWeights) - lumaC;
    float dS  = dot(nS,  lumaWeights) - lumaC;
    float dNE = dot(nNE, lumaWeights) - lumaC;
    float dNW = dot(nNW, lumaWeights) - lumaC;
    float dSE = dot(nSE, lumaWeights) - lumaC;
    float dSW = dot(nSW, lumaWeights) - lumaC;

    float wE  = exp(-(dE  * dE)  / sigma2);
    float wW  = exp(-(dW  * dW)  / sigma2);
    float wN  = exp(-(dN  * dN)  / sigma2);
    float wS  = exp(-(dS  * dS)  / sigma2);
    float wNE = exp(-(dNE * dNE) / sigma2);
    float wNW = exp(-(dNW * dNW) / sigma2);
    float wSE = exp(-(dSE * dSE) / sigma2);
    float wSW = exp(-(dSW * dSW) / sigma2);

    vec3 sumRGB = srcRGB
        + nE  * wE  + nW  * wW  + nN  * wN  + nS  * wS
        + nNE * wNE + nNW * wNW + nSE * wSE + nSW * wSW;
    float sumW = 1.0
        + wE + wW + wN + wS
        + wNE + wNW + wSE + wSW;

    vec3 ref = sumRGB / sumW;
    vec3 detail = srcRGB - ref;

    float detailLuma = dot(detail, lumaWeights);
    vec3 detailLumaVec = detailLuma * lumaWeights;
    vec3 detailChroma = detail - detailLumaVec;

    float detailMag = abs(detailLuma);
    float gate = 1.0 - smoothstep(detailAmplitudeLo, detailAmplitudeHi, detailMag);
    float highlightWeight = mix(1.0, highlightBias, smoothstep(0.6, 0.9, lumaC));

    float lumaAtten   = effectiveDetailSoftness * gate * highlightWeight;
    float chromaAtten = lumaAtten * chromaAttenScale;

    vec3 softened = srcRGB - (detailLumaVec * lumaAtten) - (detailChroma * chromaAtten);
    return vec4(softened, center.a);
}
""")

    // radialRGBSplit: radial chromatic aberration via per-channel offset
    // sampling (verbatim from iOS OpticalKernels line 4567–4583)
    static let radialRGBSplit: CIKernel? = CIKernel(source: """
kernel vec4 radialRGBSplit(sampler image, float amount, vec2 extentOrigin, vec2 extentSize) {
    vec2 coord = destCoord();
    vec2 uv = (coord - extentOrigin) / extentSize;
    vec2 delta = uv - vec2(0.5, 0.5);
    delta.x *= extentSize.x / max(extentSize.y, 1.0);
    float radial = clamp(length(delta) * 2.0, 0.0, 1.0);
    float weight = pow(radial, 1.65);
    float amt = amount * weight;
    vec2 dir = normalize(delta + vec2(1e-5, 1e-5));
    vec2 offset = vec2(dir.x * amt * extentSize.x, dir.y * amt * extentSize.y);
    vec4 center = sample(image, samplerTransform(image, coord));
    float r = sample(image, samplerTransform(image, coord + offset)).r;
    float b = sample(image, samplerTransform(image, coord - offset)).b;
    return vec4(r, center.g, b, center.a);
}
""")

    // edgeSoftnessBlend: radial mix of sharp/blurred plates driven by
    // aberrationSoften (chromatic-aberration coupled) + lensSoftness
    // (verbatim from iOS OpticalKernels line 4696–4715)
    static let edgeSoftnessBlend: CIKernel? = CIKernel(source: """
kernel vec4 edgeSoftnessBlend(sampler sharp, sampler blurred, float aberrationSoften, float lensSoftness, vec2 extentOrigin, vec2 extentSize) {
    vec2 coord = destCoord();
    vec2 uv = (coord - extentOrigin) / extentSize;
    vec2 edgePx = (uv - vec2(0.5, 0.5)) * extentSize;
    float halfDiag = length(extentSize * 0.5);
    float edgeR = clamp(length(edgePx) / max(halfDiag, 1.0), 0.0, 1.0);
    float edgeMask = smoothstep(0.25, 1.0, edgeR);
    float lensR = clamp(length(edgePx) / max(halfDiag, 1.0), 0.0, 1.0);
    float lensW = pow(lensR, 1.52);
    float lensDrive = pow(clamp(lensSoftness, 0.0, 1.0), 0.78);
    float lensWeight = clamp(lensDrive * lensW, 0.0, 1.0);
    float lensMix = lensWeight * 0.72;
    float softenAmt = clamp((aberrationSoften * edgeMask) + (lensMix * edgeMask), 0.0, 1.0);
    vec4 sharpSample = sample(sharp, samplerTransform(sharp, coord));
    vec4 blurSample = sample(blurred, samplerTransform(blurred, coord));
    return mix(sharpSample, blurSample, softenAmt);
}
""")
}
