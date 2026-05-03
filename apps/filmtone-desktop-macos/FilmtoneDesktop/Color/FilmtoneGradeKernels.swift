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
// CIKernel-based stages (radialRGBSplit / edgeSoftnessBlend) remain deferred
// until C5b A.3.
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

    static let filmCompressionV2: CIColorKernel? = CIColorKernel(source: """
kernel vec4 filmCompressionV2(__sample image, float amount, float range) {
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
    float scale = luma > 0.001 ? mix(luma, sigm, amt) / luma : 1.0;
    vec3 compressed = color.rgb * scale;
    float hiMask = smoothstep(0.7, 1.0, luma);
    float squeezeFactor = 1.0 - hiMask * amt * 0.10;
    color.rgb = clamp(compressed * squeezeFactor, 0.0, 1.0);
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

    // Grain kernel verbatim from iOS OpticalKernels (FilmtoneExportSession
    // line 4350-4403). `timeSeconds` advances grain frame stochastically
    // (floor(t * 3.0) → 3 grain refresh per second of source); for still
    // export pass 0. `sourceSeed` is a per-export salt; macOS Native uses 0
    // as a stable default until per-export seed wiring is added.
    static let grain: CIColorKernel? = CIColorKernel(source: """
float grainPixelHash(vec2 p, float seed) {
    return fract(sin(dot(p + vec2(seed, seed * 0.73), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
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

kernel vec4 grain(__sample image, float intensity, float radialMix, float grainSize, float timeSeconds, float sourceSeed, vec2 extentOrigin, vec2 extentSize) {
    vec4 color = image;
    vec2 uv = (destCoord() - extentOrigin) / extentSize;
    float size = clamp(grainSize, 0.0, 1.0);
    vec2 grainDelta = uv - vec2(0.5, 0.5);
    grainDelta.x *= extentSize.x / max(extentSize.y, 1.0);
    float grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);
    float grainRadialWeight = mix(0.76, 1.42, pow(grainRadial, 1.35));
    float grainRadialEffective = mix(1.0, grainRadialWeight, clamp(radialMix, 0.0, 1.0));

    float grainFrame = floor(max(timeSeconds, 0.0) * 3.0);
    vec2 pixelCoord = uv * extentSize;
    float grainDiameter = mix(1.6, 5.6, pow(size, 0.72));
    vec2 grainCell = floor(pixelCoord / grainDiameter);
    float fineLuma = grainPixelHash(pixelCoord, grainFrame * 1.7 + sourceSeed * 13.0);
    float cellLuma = grainPixelHash(grainCell, grainFrame * 1.7 + sourceSeed * 13.0);
    float lumaGrain = mix(fineLuma, cellLuma, mix(0.28, 0.76, size));
    float chromaR = grainPixelHash(grainCell, grainFrame * 2.3 + 500.0 + sourceSeed * 7.0) * 0.22;
    float chromaB = grainPixelHash(grainCell, grainFrame * 3.1 + 1000.0 + sourceSeed * 5.0) * 0.22;

    float clumpScale = mix(80.0, 20.0, size);
    float clump = grainClumpNoise((uv * extentSize / clumpScale) + vec2(grainFrame * 0.5 + sourceSeed * 0.1, sourceSeed * 0.07));
    float densityMod = mix(1.0, 0.3 + clump * 1.4, size * 0.7);
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float lumaVisibility = mix(1.12, 0.78, smoothstep(0.18, 0.92, luma));

    float weight = intensity * 1.08 * grainRadialEffective * densityMod * lumaVisibility;
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
}
