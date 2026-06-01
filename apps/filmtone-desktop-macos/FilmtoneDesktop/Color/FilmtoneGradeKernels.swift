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
kernel vec4 baseGradeV2(__sample image, float exposure, float contrast, float saturation, float temperature, float tint, float fade, float shadowTone, float highlightTone, float shadowHue, float highlightHue, float blackPoint, float toeContrast) {
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

    // === toe contrast → black point (fade 直前位置) ===
    // 順序: toe 先 → blackPoint 後。blackPoint=+1 と toe=1 を独立に操作可能にするため。
    float lumaTB = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    if (toeContrast > 0.0001) {
        float toeMaskAmt = (1.0 - smoothstep(0.0, 0.15, lumaTB)) * toeContrast;
        vec3 toed = pow(max(color.rgb, vec3(0.0)), vec3(1.0 + toeMaskAmt * 1.5));
        color.rgb = mix(color.rgb, toed, vec3(toeMaskAmt));
    }
    float bpPos = max(blackPoint, 0.0);
    float bpNeg = max(-blackPoint, 0.0);
    if (bpPos > 0.0001) {
        float luma2 = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
        float shadowMaskBp = 1.0 - smoothstep(0.0, 0.35, luma2);
        color.rgb += vec3(bpPos * 0.18 * shadowMaskBp);
    }
    if (bpNeg > 0.0001) {
        float f = bpNeg * 0.15;
        vec3 x = max(color.rgb, vec3(0.0));
        color.rgb = x * x * (1.0 + f) / (x + vec3(f));
    }

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
    float n2 = grainPixelHash(floor(b), seed * 0.83 + 47.0);
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
    float neighborA = grainPixelHash(floor((pixelCoord + vec2(neighborScale, 0.0)) / neighborScale), fineSeed + 29.0);
    float neighborB = grainPixelHash(floor((pixelCoord + vec2(0.0, neighborScale)) / (neighborScale * 1.07)), fineSeed + 37.0);
    float arMix = mix(0.10, 0.22, coarseBlend);
    lumaGrain = mix(lumaGrain, lumaGrain * 0.78 + (neighborA + neighborB) * 0.11, arMix);

    float coarseChromaR = grainPixelHash(floor(grainCoord * 0.86 + vec2(5.0, sourceSeed * 0.01)), fineSeed + 503.0);
    float coarseChromaB = grainPixelHash(floor(grainCoord * 0.91 + vec2(sourceSeed * 0.008, 7.0)), fineSeed + 1009.0);
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

    float grainClock = max(timeSeconds, 0.0) * 24.0;
    float grainFrameA = floor(grainClock);
    float phaseGain = 1.0;
    vec4 signal = grainSignal(pixelCoord, grainFrameA, sourceSeed, size, coarseBlend);

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

    static let filmDamage: CIColorKernel? = CIColorKernel(source: """
	float damageHash(vec2 p, float seed) {
	    return fract(sin(dot(p + vec2(seed * 0.137, seed * 0.271), vec2(12.9898, 78.233))) * 43758.5453);
	}

	float damageValueNoise(vec2 p, float seed) {
	    vec2 i = floor(p);
	    vec2 f = fract(p);
	    vec2 u = f * f * (3.0 - 2.0 * f);
	    float a = damageHash(i, seed);
	    float b = damageHash(i + vec2(1.0, 0.0), seed);
	    float c = damageHash(i + vec2(0.0, 1.0), seed);
	    float d = damageHash(i + vec2(1.0, 1.0), seed);
	    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
	}

float damageEdge(vec2 p, vec2 size) {
    float distanceToEdge = min(min(p.x, p.y), min(size.x - 1.0 - p.x, size.y - 1.0 - p.y));
    return 1.0 - clamp(distanceToEdge / max(1.0, min(size.x, size.y) * 0.48), 0.0, 1.0);
}

float damageTemporalLife(vec2 id, float seed, float minLife, float maxLife) {
    return mix(minLife, maxLife, damageHash(id, seed + 11.0));
}

float damageTemporalPeriod(vec2 id, float seed, float life, float variation, float periodBase) {
    float jitter = mix(1.15, 3.40, damageHash(id, seed + 17.0));
    return max(life + 8.0, periodBase * jitter + life * mix(1.90, 3.40, variation));
}

float damageTemporalCycle(vec2 id, float frame, float seed, float minLife, float maxLife, float variation, float periodBase) {
    float life = damageTemporalLife(id, seed, minLife, maxLife);
    float period = damageTemporalPeriod(id, seed, life, variation, periodBase);
    float offset = floor(damageHash(id, seed + 23.0) * period * max(0.25, variation));
    return floor((frame + offset) / period);
}

float damageTemporalAge(vec2 id, float frame, float seed, float life, float variation, float periodBase) {
    float period = damageTemporalPeriod(id, seed, life, variation, periodBase);
    float offset = floor(damageHash(id, seed + 23.0) * period * max(0.25, variation));
    return mod(frame + offset, period);
}

float damageTemporalFade(vec2 id, float frame, float seed, float minLife, float maxLife, float fadeInFrames, float fadeOutFrames, float variation, float periodBase) {
    float life = damageTemporalLife(id, seed, minLife, maxLife);
    float age = damageTemporalAge(id, frame, seed, life, variation, periodBase);
    if (age >= life) {
        return 0.0;
    }
    float fadeIn = smoothstep(0.0, max(1.0, min(life, fadeInFrames)), age + 1.0);
    float fadeOutStart = max(fadeInFrames, life - min(life, fadeOutFrames) * mix(0.78, 1.18, damageHash(id, seed + 29.0)));
    float fadeOut = 1.0 - smoothstep(fadeOutStart, life, age);
    return fadeIn * fadeOut;
}

float damageTransitionPhase(vec2 id, float age, float life, float fadeInFrames, float fadeOutFrames, float seed) {
    if (age >= life) {
        return 0.0;
    }
    float attack = 1.0 - smoothstep(0.0, max(0.35, fadeInFrames * 1.25), age);
    float releaseFrames = max(0.35, min(life, fadeOutFrames) * mix(0.78, 1.18, damageHash(id, seed + 29.0)) * 1.22);
    float releaseStart = max(fadeInFrames, life - releaseFrames);
    float release = smoothstep(releaseStart, life, age);
    return clamp(max(attack, release), 0.0, 1.0);
}

float damageHeldVisibility(float fade, float stain) {
    if (fade <= 0.0) {
        return 0.0;
    }
    float eased = smoothstep(0.01, 0.30, fade);
    float materialFloor = mix(0.55, 0.74, stain);
    return eased * mix(materialFloor, 1.0, pow(clamp(fade, 0.0, 1.0), 0.22));
}

float damageSpot(vec2 pixel, vec2 cell, float cellSize, float amount, float frame, float seed, float edgeBoost, float stain, float profileScale, float periodBase) {
    float minLife = mix(8.0, 58.0, stain);
    float maxLife = mix(52.0, 260.0, stain);
    float fadeInFrames = mix(0.55, 1.75, stain);
    float fadeOutFrames = mix(0.95, 2.80, stain);
    float variation = mix(0.55, 0.22, stain);
    float life = damageTemporalLife(cell, seed, minLife, maxLife);
    float period = damageTemporalPeriod(cell, seed, life, variation, periodBase);
    float offset = floor(damageHash(cell, seed + 23.0) * period * max(0.25, variation));
    float eventClock = frame + offset;
    float cycle = floor(eventClock / period);
    vec2 eventId = cell + vec2(cycle * 13.0, cycle * 31.0);
    float presence = step(1.0 - clamp(amount * mix(0.34, 0.22, stain) * edgeBoost, 0.0, 0.88), damageHash(eventId, seed + 31.0));
    if (presence <= 0.0) {
        return 0.0;
    }
    float age = mod(eventClock, period);
    if (age >= life) {
        return 0.0;
    }
    float fadeIn = smoothstep(0.0, max(1.0, min(life, fadeInFrames)), age + 1.0);
    float fadeOutFramesResolved = min(life, fadeOutFrames) * mix(0.78, 1.18, damageHash(cell, seed + 29.0));
    float fadeOutStart = max(fadeInFrames, life - fadeOutFramesResolved);
    float fadeOut = 1.0 - smoothstep(fadeOutStart, life, age);
    float fade = damageHeldVisibility(fadeIn * fadeOut, stain);
    if (fade <= 0.0) {
        return 0.0;
    }
    float attack = 1.0 - smoothstep(0.0, max(0.35, fadeInFrames * 1.25), age);
    float releaseFrames = max(0.35, fadeOutFramesResolved * 1.22);
    float releaseStart = max(fadeInFrames, life - releaseFrames);
    float release = smoothstep(releaseStart, life, age);
    float transitionBlur = pow(clamp(max(attack, release), 0.0, 1.0), 0.55);
    vec2 center = (cell + vec2(damageHash(eventId, seed + 37.0), damageHash(eventId, seed + 41.0))) * cellSize;
    vec2 stableDrift = vec2(damageHash(eventId, seed + 43.0) - 0.5, damageHash(eventId, seed + 44.0) - 0.5) * cellSize * mix(0.035, 0.012, stain) * mix(0.25, 0.78, amount);
    vec2 transitionDrift = vec2(0.0);
    if (transitionBlur > 0.001) {
        transitionDrift = vec2(
            damageValueNoise(eventId * 0.19 + vec2(frame * 0.46, 0.0), seed + 45.0) - 0.5,
            damageValueNoise(eventId * 0.23 + vec2(0.0, frame * 0.39), seed + 46.0) - 0.5
        ) * cellSize * mix(0.30, 0.075, stain) * mix(0.45, 1.0, amount) * transitionBlur;
    }
    vec2 morphDrift = vec2(damageHash(eventId, seed + 47.0) - 0.5, damageHash(eventId, seed + 48.0) - 0.5) * cellSize * mix(0.16, 0.035, stain) * transitionBlur;
    center += stableDrift + transitionDrift + morphDrift;
    float baseRadius = mix(0.42, 2.55, amount) * mix(0.72, 1.38, damageHash(eventId, seed + 49.0)) * profileScale;
    float layerSize = mix(0.38, 0.62, stain);
    float stainRadius = mix(baseRadius, baseRadius * mix(3.4, 6.8, damageHash(eventId, seed + 53.0)), stain) * layerSize;
    float morphRadius = mix(0.72, 1.42, damageHash(eventId, seed + 55.0));
    float radius = mix(stainRadius, stainRadius * morphRadius, transitionBlur * mix(0.60, 0.36, stain));
    radius *= 1.0 + transitionBlur * mix(0.12, 0.08, stain);
    float softness = mix(0.84, 2.20, stain) + transitionBlur * mix(0.55, 1.05, stain);
    vec2 delta = pixel - center;
    float angle = damageHash(eventId, seed + 57.0) * 6.2831853;
    angle += (damageHash(eventId, seed + 58.0) - 0.5) * 0.85 * transitionBlur;
    float ca = cos(angle);
    float sa = sin(angle);
    vec2 rotated = vec2(delta.x * ca - delta.y * sa, delta.x * sa + delta.y * ca);
    float stableAnisotropy = mix(mix(0.78, 1.18, damageHash(eventId, seed + 59.0)), mix(0.35, 0.82, damageHash(eventId, seed + 61.0)), stain);
    float morphAnisotropy = mix(mix(0.60, 1.42, damageHash(eventId, seed + 62.0)), mix(0.28, 0.94, damageHash(eventId, seed + 64.0)), stain);
    float anisotropy = mix(stableAnisotropy, morphAnisotropy, transitionBlur * mix(0.55, 0.34, stain));
    float shapedDistance = length(vec2(rotated.x * anisotropy, rotated.y / max(0.35, anisotropy)));
    vec2 contourJitter = vec2(0.0);
    if (transitionBlur > 0.001) {
        contourJitter = vec2(
            damageValueNoise(eventId + vec2(frame * 0.41, 0.0), seed + 66.0) - 0.5,
            damageValueNoise(eventId + vec2(0.0, frame * 0.37), seed + 67.0) - 0.5
        ) * transitionBlur * mix(3.0, 8.0, stain);
    }
    float contour = mix(0.74, 1.26, damageHash(floor((pixel + contourJitter) / mix(6.5, 25.0, stain) + cell * 0.17), seed + 68.0));
    float shape = 1.0 - smoothstep(radius * 0.10 * contour, radius * softness * contour, shapedDistance);
    vec2 chipOffset = vec2(damageHash(eventId, seed + 69.0) - 0.5, damageHash(eventId, seed + 70.0) - 0.5) * radius * mix(0.70, 1.35, stain) * (1.0 + transitionBlur * mix(0.55, 0.25, stain));
    float chipDistance = length(vec2((rotated.x + chipOffset.x) * anisotropy, (rotated.y + chipOffset.y) / max(0.35, anisotropy)));
    float chip = 1.0 - smoothstep(radius * 0.08, radius * softness * mix(0.62, 0.92, stain), chipDistance);
    shape = max(max(0.0, shape), max(0.0, chip) * mix(0.20, 0.55, stain));
    if (shape <= 0.0) {
        return 0.0;
    }
    float ragged = mix(0.52, 1.0, smoothstep(0.12, 0.94, damageHash(floor(rotated * mix(0.16, 0.045, stain) + eventId * 0.13 + vec2(frame * 0.18, -frame * 0.11) * transitionBlur), seed + 73.0)));
    float mottled = mix(0.48, 1.0, damageHash(floor(pixel * mix(0.11, 0.038, stain) + cell), seed + 71.0));
    return shape * presence * fade * ragged * mottled * mottled;
}

float damageScratch(vec2 pixel, vec2 size, float amount, float frame, float seed, float fiber, float profileScale, float profileDensity, float periodBase) {
    float effectiveAmount = clamp(amount * profileDensity, 0.0, 1.0);
    float laneWidth = mix(230.0, 64.0, effectiveAmount) * mix(1.0, 2.15, fiber) / mix(1.0, 1.14, profileDensity - 1.0);
    float laneOffset = laneWidth * mix(0.37, 0.91, damageHash(vec2(fiber, 17.0), seed + 103.0));
    float lane = floor((pixel.x + laneOffset) / laneWidth);
    vec2 id = vec2(lane, fiber * 733.0);
    float minLife = mix(48.0, 140.0, fiber);
    float maxLife = mix(220.0, 460.0, fiber);
    float fadeInFrames = mix(0.85, 1.65, fiber);
    float fadeOutFrames = mix(1.25, 3.10, fiber);
    float variation = mix(0.34, 0.16, fiber);
    float scratchSeed = seed + mix(101.0, 401.0, fiber);
    float life = damageTemporalLife(id, scratchSeed, minLife, maxLife);
    float period = damageTemporalPeriod(id, scratchSeed, life, variation, periodBase);
    float offset = floor(damageHash(id, scratchSeed + 23.0) * period * max(0.25, variation));
    float eventClock = frame + offset;
    float cycle = floor(eventClock / period);
    vec2 eventId = id + vec2(cycle * 17.0, cycle * 29.0);
    float baseX = mod((lane + damageHash(eventId, seed + 113.0)) * laneWidth - laneOffset + size.x * 8.0, max(size.x, 1.0));
    float gateEdge = damageEdge(vec2(clamp(baseX, 0.0, size.x - 1.0), pixel.y), size);
    float interiorX = size.x * mix(0.12, 0.88, damageHash(eventId, seed + 115.0));
    baseX = mix(baseX, interiorX, smoothstep(0.78, 1.0, gateEdge));
    gateEdge = damageEdge(vec2(clamp(baseX, 0.0, size.x - 1.0), pixel.y), size);
    float edgePenalty = mix(1.0, 0.64, smoothstep(0.62, 1.0, gateEdge));
    float presence = step(1.0 - clamp(effectiveAmount * mix(0.72, 0.52, fiber) * edgePenalty, 0.0, 0.94), damageHash(eventId, seed + 109.0));
    if (presence <= 0.0) {
        return 0.0;
    }
    float age = mod(eventClock, period);
    if (age >= life) {
        return 0.0;
    }
    float fadeIn = smoothstep(0.0, max(1.0, min(life, fadeInFrames)), age + 1.0);
    float fadeOutFramesResolved = min(life, fadeOutFrames) * mix(0.78, 1.18, damageHash(id, scratchSeed + 29.0));
    float fadeOutStart = max(fadeInFrames, life - fadeOutFramesResolved);
    float fadeOut = 1.0 - smoothstep(fadeOutStart, life, age);
    float fade = damageHeldVisibility(fadeIn * fadeOut, mix(0.45, 0.88, fiber));
    if (fade <= 0.0) {
        return 0.0;
    }
    float attack = 1.0 - smoothstep(0.0, max(0.35, fadeInFrames * 1.25), age);
    float releaseFrames = max(0.35, fadeOutFramesResolved * 1.22);
    float releaseStart = max(fadeInFrames, life - releaseFrames);
    float release = smoothstep(releaseStart, life, age);
    float transitionBlur = pow(clamp(max(attack, release), 0.0, 1.0), 0.58);
    float waveFreq = mix(0.55, 2.15, damageHash(eventId, seed + 127.0));
    float wavePhase = damageHash(eventId, seed + 128.0) * 6.2831853 + seed * 0.002;
    float wave = sin((pixel.y / max(size.y, 1.0)) * waveFreq * 6.2831853 + wavePhase);
    float heldScratchTime = frame / mix(26.0, 42.0, fiber);
    wave += (damageHash(floor(vec2(pixel.y * 0.006 + frame * 0.090 * transitionBlur + heldScratchTime * 0.045, lane * 0.21)), seed + 129.0) - 0.5) * mix(0.55, 1.35, fiber);
    float waviness = laneWidth * mix(0.008, 0.042, effectiveAmount) * mix(0.72, 1.18, fiber);
    float heldDrift = (damageHash(floor(vec2(heldScratchTime, lane * 0.49) + eventId * 0.031), seed + 133.0) - 0.5) * laneWidth * mix(0.006, 0.018, effectiveAmount) * mix(1.0, 0.58, fiber);
    float tickFrame = floor(frame / mix(5.0, 9.0, fiber));
    float microJump = (damageHash(vec2(lane, tickFrame) + eventId * 0.019, seed + 134.0) - 0.5) * mix(0.26, 0.68, effectiveAmount) * mix(1.0, 0.52, fiber);
    float smear = 0.0;
    float morphBend = 0.0;
    if (transitionBlur > 0.001) {
        smear = (damageHash(floor(vec2(frame * 0.72, lane * 0.33)), seed + 130.0) - 0.5) * laneWidth * mix(0.016, 0.036, effectiveAmount) * transitionBlur;
        morphBend = (damageHash(floor(vec2(pixel.y * 0.022 + frame * 0.31, lane * 0.57)), seed + 132.0) - 0.5) * laneWidth * mix(0.010, 0.030, effectiveAmount) * transitionBlur;
    }
    float centerX = baseX + wave * waviness + heldDrift + microJump + smear + morphBend;
    float widthPx = mix(0.40, 1.18, effectiveAmount) * mix(1.0, 0.44, fiber) * mix(0.70, 1.30, damageHash(eventId, seed + 131.0)) * profileScale;
    widthPx *= 1.0 + transitionBlur * mix(0.38, 0.25, fiber);
    float roughEdge = mix(0.52, 1.0, damageHash(floor(vec2(pixel.y * mix(0.046, 0.15, effectiveAmount), lane * 0.37)), seed + 147.0));
    if (transitionBlur > 0.001) {
        float transitionRough = mix(0.42, 1.0, damageHash(floor(vec2(pixel.y * mix(0.060, 0.18, effectiveAmount) + frame * 0.27, lane * 0.51)), seed + 148.0));
        roughEdge = mix(roughEdge, transitionRough, transitionBlur * 0.45);
    }
    float lineDistance = abs(pixel.x - centerX);
    float lineCore = 1.0 - smoothstep(widthPx * (0.30 + roughEdge * 0.14), widthPx * mix(0.92, 1.34, effectiveAmount), lineDistance);
    float lineScuff = (1.0 - smoothstep(widthPx * 0.85, widthPx * mix(1.75, 2.95, effectiveAmount), lineDistance)) * mix(0.07, 0.17, effectiveAmount);
    float line = max(lineCore, lineScuff * damageHash(floor(vec2(pixel.y * 0.021, lane * 2.7)), seed + 145.0));
    float stableTravel = (damageHash(eventId, seed + 135.0) - 0.5) * size.y * mix(0.12, 0.06, fiber);
    float transitionTravel = 0.0;
    if (transitionBlur > 0.001) {
        transitionTravel = (damageHash(floor(vec2(frame * 0.37, lane * 0.61)), seed + 136.0) - 0.5) * size.y * mix(0.08, 0.035, fiber) * transitionBlur;
    }
    float travel = stableTravel + transitionTravel;
    float longPlate = damageHash(floor(vec2(lane * 0.19 + cycle * 0.07, (pixel.y + travel) / mix(220.0, 84.0, effectiveAmount))), seed + 137.0);
    float midPlate = damageHash(floor(vec2(lane * 0.41, (pixel.y - travel * 0.7) / mix(76.0, 24.0, effectiveAmount))), seed + 139.0);
    float densityBreath = mix(0.78, 1.18, damageHash(floor(vec2(frame / mix(9.0, 18.0, fiber), lane * 0.29) + eventId * 0.043), seed + 167.0));
    float segment = mix(0.40, 1.0, smoothstep(0.18, 0.78, longPlate)) * mix(0.58, 1.0, smoothstep(0.14, 0.86, midPlate));
    float gapDensity = clamp(effectiveAmount * mix(0.32, 0.18, fiber) + (1.0 - fiber) * 0.05, 0.0, 0.52);
    float gapCell = floor((pixel.y + travel) / max(9.0, mix(70.0, 20.0, gapDensity) * mix(1.0, 0.82, profileScale - 1.0)));
    float gapHash = damageHash(vec2(lane, gapCell) + eventId * 0.013, seed + 149.0);
    float gap = mix(1.0, mix(0.28, 0.78, damageHash(vec2(gapHash, lane), seed + 151.0)), step(gapHash, gapDensity * mix(0.46, 0.28, fiber)));
    float gapFlutter = mix(0.58, 1.0, damageHash(floor(vec2(gapCell * 0.43, frame / mix(6.0, 14.0, fiber)) + eventId * 0.037), seed + 155.0));
    gap = mix(gap, gap * gapFlutter, mix(0.42, 0.22, fiber));
    float breakupNoise = damageHash(floor(vec2(lane * 0.43, (pixel.y + travel) / mix(14.0, 4.8, gapDensity)) + eventId * 0.07), seed + 157.0);
    float breakup = mix(0.50, 1.0, smoothstep(0.20 + gapDensity * 0.12, 0.86, breakupNoise));
    float abrasion = mix(0.50, 1.0, damageHash(floor(vec2(pixel.y * 0.27, lane * 1.7) + eventId * 0.11), seed + 163.0));
    return max(0.0, line) * roughEdge * segment * gap * breakup * abrasion * densityBreath * presence * fade;
}

kernel vec4 filmDamage(__sample image, float dustAmount, float scratchAmount, float timeSeconds, float sourceSeed, vec2 extentOrigin, vec2 extentSize) {
    vec4 color = image;
    float dust = clamp(dustAmount, 0.0, 1.0);
    float scratch = clamp(scratchAmount, 0.0, 1.0);
    if (dust <= 0.0001 && scratch <= 0.0001) {
        return color;
    }
    dust = pow(dust, 0.50);
    scratch = pow(scratch, 0.46);

    vec2 pixelCoord = destCoord() - extentOrigin;
    float frame = max(timeSeconds, 0.0) * 24.0;
	    float seed = sourceSeed * 19.0;
	    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	    float sourceLuma = luma;
	    float edge = damageEdge(pixelCoord, extentSize);
	    float driver = max(dust, scratch);
	    float profileT = smoothstep(0.18, 1.0, driver);
	    float profileScale = mix(1.0, 1.36, profileT);
	    float profileDensity = mix(1.0, 1.22, profileT);
	    float periodBase = mix(72.0, 46.0, profileT);
	    float globalOpacity = mix(0.82, 0.94, profileT);
	    float globalChroma = mix(0.22, 0.42, profileT);
	    float globalEdgeBias = mix(0.22, 0.48, profileT);
	    float defectFrame = frame;
	    float edgeSoilBlend = 0.0;
	    float dirtBlend = 0.0;
	    float darkDustBlend = 0.0;
	    float sparkleBlend = 0.0;
	    float stainBlend = 0.0;
	    float scratchBlend = 0.0;
	    float fiberBlend = 0.0;
	    float lightScratch = 0.0;

		    float heldFrame = floor(frame / mix(10.0, 6.0, profileT));
		    float flickerNoise = damageHash(floor(vec2(frame / mix(18.0, 10.0, profileT), sourceSeed * 17.0)), seed + 701.0) - 0.5;
		    float flickerSlow = damageHash(floor(vec2(frame / 96.0, sourceSeed * 23.0)), seed + 707.0) - 0.5;
		    float flicker = 1.0 + max(dust, scratch * 0.55) * globalOpacity * (-0.006 + flickerNoise * 0.020 + flickerSlow * 0.014);
	    color.rgb *= flicker;

		    float gateDriver = max(dust, scratch * 0.55);
		    float gateWearWidth = mix(9.0, 36.0, gateDriver) * profileScale * (1.0 + scratch * 0.34);
		    float gateDistance = min(pixelCoord.x, extentSize.x - 1.0 - pixelCoord.x);
		    float gateMask = (1.0 - smoothstep(gateWearWidth * 0.18, gateWearWidth * 1.35, gateDistance));
		    float gateCell = floor(pixelCoord.y / max(4.0, mix(28.0, 9.0, dust + scratch * 0.35)));
		    float gateSide = step(extentSize.x * 0.5, pixelCoord.x);
		    float gateBreak = mix(0.54, 1.0, damageHash(floor(vec2(gateSide * 1.7 + floor(gateDistance / max(18.0, gateWearWidth * 0.72)) * 0.19, floor(gateCell / 4.0) * 0.33)), seed + heldFrame * 0.11 + 713.0));
		    float gateWear = gateMask * gateBreak * (dust * 0.052 + scratch * 0.036) * globalOpacity;
	    float gateLuma = clamp(luma * 0.54 - 0.028 * (0.4 + edge), 0.0, 1.0);
	    vec3 gateTarget = vec3(gateLuma);
	    float gateBlend = gateWear * 1.45;
	    color.rgb = mix(color.rgb, gateTarget, gateBlend);
	    if (dust > 0.0001) {
		    vec2 edgeSoilCoord = vec2(gateDistance / max(34.0, gateWearWidth * 0.92), pixelCoord.y / mix(170.0, 74.0, dust)) + vec2(seed * 0.010 + gateSide * 0.13, heldFrame * 0.030);
		    float edgeSoilNoise = damageHash(floor(edgeSoilCoord), seed + 719.0);
		    float edgeSoil = gateMask * smoothstep(0.56, 0.98, edgeSoilNoise) * dust * (0.012 + dust * 0.026) * globalOpacity;
	    float edgeSoilLuma = clamp(luma * 0.44 - 0.030 * (0.6 + edge), 0.0, 1.0);
	    vec3 edgeSoilTarget = vec3(edgeSoilLuma);
	    edgeSoilBlend = edgeSoil * 1.55;
	    color.rgb = mix(color.rgb, edgeSoilTarget, edgeSoilBlend);

		    vec2 dirtCell = floor(pixelCoord / (mix(128.0, 68.0, dust) * profileScale));
		    float dirtCellSize = mix(128.0, 68.0, dust) * profileScale;
		    float dirtAmount = clamp(dust * 1.05 + 0.06, 0.0, 1.0);
		    float dirtEdgeBoost = 1.0 + edge * dust * 0.72 * globalEdgeBias;
		    float dirtMask = 0.0;
		    dirtMask = max(dirtMask, damageSpot(pixelCoord, dirtCell, dirtCellSize, dirtAmount, defectFrame, seed + 331.0, dirtEdgeBoost, 0.72, profileScale, periodBase));
		    dirtMask = max(dirtMask, damageSpot(pixelCoord, dirtCell + vec2(1.0, 0.0), dirtCellSize, dirtAmount, defectFrame, seed + 331.0, dirtEdgeBoost, 0.72, profileScale, periodBase));
		    dirtMask = max(dirtMask, damageSpot(pixelCoord, dirtCell + vec2(-1.0, 0.0), dirtCellSize, dirtAmount, defectFrame, seed + 331.0, dirtEdgeBoost, 0.72, profileScale, periodBase));
		    dirtMask = max(dirtMask, damageSpot(pixelCoord, dirtCell + vec2(0.0, 1.0), dirtCellSize, dirtAmount, defectFrame, seed + 331.0, dirtEdgeBoost, 0.72, profileScale, periodBase));
		    dirtMask = max(dirtMask, damageSpot(pixelCoord, dirtCell + vec2(0.0, -1.0), dirtCellSize, dirtAmount, defectFrame, seed + 331.0, dirtEdgeBoost, 0.72, profileScale, periodBase));
	    float dirtTexture = mix(0.62, 1.0, damageHash(floor(pixelCoord / mix(22.0, 9.0, dust) + vec2(seed * 0.013, 0.0)), seed + 337.0));
	    float dirtLuma = clamp(luma * mix(0.50, 0.26, dust) - mix(0.035, 0.070, dust) * (0.70 + edge * 0.30), 0.0, 1.0);
	    vec3 dirtTarget = vec3(dirtLuma);
	    dirtBlend = dirtMask * dirtTexture * mix(0.10, 0.28, dust) * globalOpacity;
		    color.rgb = mix(color.rgb, dirtTarget, dirtBlend);

		    float speckAmount = dust * mix(0.82, 1.05, dust) * profileDensity;
		    vec2 dustCell = floor(pixelCoord / (mix(34.0, 13.5, dust) * profileScale));
		    float dustCellSize = mix(34.0, 13.5, dust) * profileScale;
		    float dustEdgeBoost = 1.0 + edge * dust * 0.34 * globalEdgeBias;
    float dustMask = 0.0;
    dustMask = max(dustMask, damageSpot(pixelCoord, dustCell, dustCellSize, speckAmount, defectFrame, seed + 1.0, dustEdgeBoost, 0.0, profileScale, periodBase));
    dustMask = max(dustMask, damageSpot(pixelCoord, dustCell + vec2(1.0, 0.0), dustCellSize, speckAmount, defectFrame, seed + 1.0, dustEdgeBoost, 0.0, profileScale, periodBase));
    dustMask = max(dustMask, damageSpot(pixelCoord, dustCell + vec2(-1.0, 0.0), dustCellSize, speckAmount, defectFrame, seed + 1.0, dustEdgeBoost, 0.0, profileScale, periodBase));
	    dustMask = max(dustMask, damageSpot(pixelCoord, dustCell + vec2(0.0, 1.0), dustCellSize, speckAmount, defectFrame, seed + 1.0, dustEdgeBoost, 0.0, profileScale, periodBase));
	    dustMask = max(dustMask, damageSpot(pixelCoord, dustCell + vec2(0.0, -1.0), dustCellSize, speckAmount, defectFrame, seed + 1.0, dustEdgeBoost, 0.0, profileScale, periodBase));
	    dustMask = smoothstep(0.07, 0.42, dustMask);
	    float dustPolarity = damageHash(dustCell, seed + 79.0);
		    float sparkleGate = step(1.0 - mix(0.055, 0.13, dust), dustPolarity);
		    float sparkleDust = dustMask * sparkleGate;
		    float darkDust = dustMask * (1.0 - sparkleGate);
		    float speckTexture = mix(0.78, 1.0, damageHash(floor(pixelCoord / mix(4.0, 1.8, dust)), seed + 83.0));
		    float darkDustLuma = clamp(luma * mix(0.34, 0.12, dust) - mix(0.020, 0.055, dust), 0.0, 1.0);
	    darkDustBlend = darkDust * speckTexture * mix(0.52, 1.00, dust) * globalOpacity;
		    color.rgb = mix(color.rgb, vec3(darkDustLuma), darkDustBlend);
		    float sparkleGuard = 1.0 - smoothstep(0.70, 0.98, luma);
		    vec3 sparkleTarget = vec3(mix(0.84, 0.96, damageHash(dustCell, seed + 86.0)));
	    sparkleBlend = sparkleDust * mix(0.42, 0.82, dust) * sparkleGuard * globalOpacity;
		    color.rgb = mix(color.rgb, sparkleTarget, sparkleBlend);

    vec2 stainCell = floor(pixelCoord / (mix(180.0, 86.0, dust) * profileScale));
    float stainCellSize = mix(180.0, 86.0, dust) * profileScale;
    float stainEdgeBoost = 1.0 + edge * dust * 1.15 * globalEdgeBias;
    float stainMask = 0.0;
    stainMask = max(stainMask, damageSpot(pixelCoord, stainCell, stainCellSize, dust, defectFrame, seed + 503.0, stainEdgeBoost, 1.0, profileScale, periodBase));
    stainMask = max(stainMask, damageSpot(pixelCoord, stainCell + vec2(1.0, 0.0), stainCellSize, dust, defectFrame, seed + 503.0, stainEdgeBoost, 1.0, profileScale, periodBase));
    stainMask = max(stainMask, damageSpot(pixelCoord, stainCell + vec2(-1.0, 0.0), stainCellSize, dust, defectFrame, seed + 503.0, stainEdgeBoost, 1.0, profileScale, periodBase));
    stainMask = max(stainMask, damageSpot(pixelCoord, stainCell + vec2(0.0, 1.0), stainCellSize, dust, defectFrame, seed + 503.0, stainEdgeBoost, 1.0, profileScale, periodBase));
    stainMask = max(stainMask, damageSpot(pixelCoord, stainCell + vec2(0.0, -1.0), stainCellSize, dust, defectFrame, seed + 503.0, stainEdgeBoost, 1.0, profileScale, periodBase));
		    float stainDarkLuma = clamp(luma * mix(0.58, 0.34, dust) - mix(0.030, 0.070, dust), 0.0, 1.0);
		    vec3 stainDarkTarget = vec3(stainDarkLuma);
	    stainBlend = stainMask * mix(0.04, 0.12, dust) * globalOpacity;
		    color.rgb = mix(color.rgb, stainDarkTarget, stainBlend);
	    }

	    if (scratch > 0.0001) {
		    float scratchWeaveSlow = damageHash(floor(vec2(frame / 19.0, sourceSeed * 31.0)), seed + 761.0) - 0.5;
		    float scratchWeaveFast = damageHash(floor(vec2(frame / 4.5, sourceSeed * 37.0)), seed + 763.0) - 0.5;
		    vec2 scratchCoord = pixelCoord + vec2(
		        (scratchWeaveSlow * 2.60 + scratchWeaveFast * 0.80) * scratch,
		        (damageHash(floor(vec2(frame / 23.0, sourceSeed * 41.0)), seed + 765.0) - 0.5) * scratch * 1.05
		    );
		    float scratchMask = max(
		        damageScratch(scratchCoord, extentSize, scratch, defectFrame, seed + 211.0, 0.0, profileScale, profileDensity, periodBase),
		        damageScratch(scratchCoord, extentSize, scratch, defectFrame, seed + 279.0, 0.0, profileScale, profileDensity, periodBase) * 0.82
		    );
		    float fiberMask = max(
		        damageScratch(scratchCoord, extentSize, scratch, defectFrame, seed + 733.0, 1.0, profileScale, profileDensity, periodBase),
		        damageScratch(scratchCoord, extentSize, scratch, defectFrame, seed + 877.0, 1.0, profileScale, profileDensity, periodBase) * 0.65
		    );
	    float scratchPolarity = damageHash(vec2(floor(scratchCoord.x / mix(180.0, 44.0, scratch)), 0.0), seed + 821.0);
	    scratchMask *= mix(0.55, 1.0, damageHash(floor(vec2(scratchCoord.x * 0.35, scratchCoord.y * 0.07 + frame * 0.018)), seed + 829.0));
	    fiberMask *= mix(0.50, 1.0, damageHash(floor(vec2(scratchCoord.x * 0.08, scratchCoord.y * 0.23 + frame * 0.014)), seed + 839.0));
	    lightScratch = step(0.92, scratchPolarity);
	    vec3 scratchDarkTarget = vec3(clamp(luma * 0.20 - 0.030, 0.0, 1.0));
	    vec3 scratchLightTarget = vec3(mix(0.82, 0.95, damageHash(vec2(scratchPolarity, floor(pixelCoord.y / 29.0)), seed + 847.0)));
	    vec3 scratchTarget = mix(scratchDarkTarget, scratchLightTarget, lightScratch);
	    scratchBlend = scratchMask * mix(0.58, 0.96, scratch) * globalOpacity;
	    fiberBlend = fiberMask * mix(0.42, 0.78, scratch) * globalOpacity;
		    color.rgb = mix(color.rgb, scratchTarget, scratchBlend);
		    color.rgb = mix(color.rgb, vec3(clamp(luma * 0.24 - 0.020, 0.0, 1.0)), fiberBlend);
	    }

	    float materialMask = max(max(max(gateBlend, edgeSoilBlend), max(dirtBlend, stainBlend)), max(max(darkDustBlend, sparkleBlend), max(scratchBlend, fiberBlend)));
	    materialMask = clamp(materialMask, 0.0, 1.0);
	    if (materialMask > 0.003) {
	        float materialFeather = smoothstep(0.018, 0.50, materialMask);
	        float regrainFrame = floor(frame);
	        vec2 fineCell = floor(pixelCoord * mix(0.62, 1.15, profileT) + vec2(regrainFrame * 0.37, seed * 0.17));
	        vec2 coarseCell = floor(pixelCoord / mix(12.0, 5.5, driver) + vec2(heldFrame * 0.23, seed * 0.07));
	        float regrainFine = damageHash(fineCell, seed + 911.0) - 0.5;
	        float regrainCoarse = damageHash(coarseCell, seed + 919.0) - 0.5;
	        float edgeRagged = mix(0.78, 1.08, damageHash(floor(pixelCoord / mix(5.5, 2.7, driver)) + vec2(heldFrame, 0.0), seed + 929.0));
	        float highlightEmbed = 1.0 - smoothstep(0.86, 1.0, sourceLuma);
	        float materialGrain = (regrainFine * 0.72 + regrainCoarse * 0.28) * mix(0.016, 0.045, profileT) * materialFeather * highlightEmbed;
	        color.rgb += vec3(materialGrain);
	        float brightDamageBlend = clamp(max(sparkleBlend, scratchBlend * lightScratch), 0.0, 1.0);
	        float whiteSoil = brightDamageBlend * mix(0.008, 0.028, driver) * edgeRagged * (1.0 - smoothstep(0.92, 1.0, sourceLuma));
	        color.rgb -= vec3(whiteSoil);
	        float sourceToneReturn = materialFeather * mix(0.030, 0.080, profileT) * smoothstep(0.12, 0.72, sourceLuma);
	        float postDamageLuma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	        color.rgb = mix(color.rgb, vec3(mix(postDamageLuma, sourceLuma, 0.28)), sourceToneReturn);
	        float neutralLock = materialFeather * mix(0.035, 0.095, driver);
	        color.rgb = mix(color.rgb, vec3(dot(color.rgb, vec3(0.2126, 0.7152, 0.0722))), neutralLock);
	    }

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
