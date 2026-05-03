import CoreImage

// CIColorKernel sources lifted verbatim from the iOS implementation
// (apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift,
// `OpticalKernels`). Phase 0 generator targets `presetVersion = "v2"` for all
// 4 built-in presets, so only the v2 kernels are wired here. v1 / motion /
// optics / grain / vignette kernels are deferred to Phase 1c / Phase 2 with
// the rest of the export session lift.
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
}
