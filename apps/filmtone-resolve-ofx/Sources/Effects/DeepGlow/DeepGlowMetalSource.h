#pragma once

namespace filmtone::resolve::effects::deep_glow::detail {

inline constexpr char kDeepGlowReduceFunctionName[] =
    "filmtoneDeepGlowReduceV3";
inline constexpr char kDeepGlowTurnaroundFunctionName[] =
    "filmtoneDeepGlowTurnaroundV3";
inline constexpr char kDeepGlowUpsampleCombineFunctionName[] =
    "filmtoneDeepGlowUpsampleCombineV3";
inline constexpr char kDeepGlowCompositeFunctionName[] =
    "filmtoneDeepGlowCompositeV3";

// The shared library source changed for the progressive-upsample redesign and
// the host pipeline cache resolves by (device, cacheKey) alone, so the whole
// kernel family moves to v3 keys together.
inline constexpr char kDeepGlowReduceCacheKey[] =
    "filmtone.resolve.deep-glow.v3.reduce.rgba32f";
inline constexpr char kDeepGlowTurnaroundCacheKey[] =
    "filmtone.resolve.deep-glow.v3.turnaround.rgba32f";
inline constexpr char kDeepGlowUpsampleCombineCacheKey[] =
    "filmtone.resolve.deep-glow.v3.upsample-combine.rgba32f";
inline constexpr char kDeepGlowCompositeCacheKey[] =
    "filmtone.resolve.deep-glow.v3.composite.rgba32f";

inline constexpr char kDeepGlowMetalLibrarySource[] = R"FILMTONE_METAL(
#include <metal_stdlib>

using namespace metal;

constant float3 kDeepGlowLuminanceWeightsV3 =
    float3(0.2126f, 0.7152f, 0.0722f);

constant int2 kDeepGlowTentOffsetsV3[13] = {
    int2(-2,  2), int2( 0,  2), int2( 2,  2),
    int2(-1,  1), int2( 1,  1),
    int2(-2,  0), int2( 0,  0), int2( 2,  0),
    int2(-1, -1), int2( 1, -1),
    int2(-2, -2), int2( 0, -2), int2( 2, -2),
};

// Unit-sum 13-tap tent. Each reduction preserves constant-image energy, so
// every pyramid level keeps unit DC gain before reconstruction.
constant float kDeepGlowTentWeightsV3[13] = {
    0.03125f, 0.0625f, 0.03125f,
    0.125f,   0.125f,
    0.0625f,  0.125f,  0.0625f,
    0.125f,   0.125f,
    0.03125f, 0.0625f, 0.03125f,
};

constant int2 kDeepGlowSquareTentOffsetsV3[9] = {
    int2(-1,  1), int2(0,  1), int2(1,  1),
    int2(-1,  0), int2(0,  0), int2(1,  0),
    int2(-1, -1), int2(0, -1), int2(1, -1),
};

// Unit-sum 3x3 tent used for the deepest-level turnaround blur and for the
// coarse-to-fine upsample. Positive weights only: the reconstructed impulse
// response keeps monotone falloff with no negative lobes and no ringing.
constant float kDeepGlowSquareTentWeightsV3[9] = {
    0.0625f, 0.125f, 0.0625f,
    0.125f,  0.25f,  0.125f,
    0.0625f, 0.125f, 0.0625f,
};

struct DeepGlowReduceUniformsV3 {
    uint4 dimensions;  // source width/height, destination width/height
    float4 selection;  // threshold, threshold smooth, extract flag, alpha association
};

struct DeepGlowSpreadUniformsV3 {
    uint4 dimensions;  // source width/height, destination width/height
    float4 spread;     // level gain, alpha association, reserved, reserved
};

struct DeepGlowCompositeUniformsV3 {
    float4 effect;     // strength gain, threshold, threshold smooth, reserved
    uint4 metadata;    // reduced-level present, alpha association, width, height
};

static int2 deepGlowClampCoordinateV3(
    texture2d<float, access::read> texture,
    int2 coordinate) {
    const int2 maximum = int2(
        int(texture.get_width()) - 1,
        int(texture.get_height()) - 1);
    return clamp(coordinate, int2(0), maximum);
}

static float4 deepGlowReadClampV3(
    texture2d<float, access::read> texture,
    int2 coordinate) {
    return texture.read(uint2(deepGlowClampCoordinateV3(texture, coordinate)));
}

// Spatial ABI v1 deliberately does not assume RGBA32Float filterability.
// Reconstruct linear samples from integer reads with explicit clamp-to-edge.
static float4 deepGlowBilinearClampV3(
    texture2d<float, access::read> texture,
    float2 pixelCenter) {
    const float2 baseFloat = floor(pixelCenter - 0.5f);
    const float2 fraction = pixelCenter - 0.5f - baseFloat;
    const int2 base = int2(baseFloat);
    const float4 row0 = mix(
        deepGlowReadClampV3(texture, base),
        deepGlowReadClampV3(texture, base + int2(1, 0)),
        fraction.x);
    const float4 row1 = mix(
        deepGlowReadClampV3(texture, base + int2(0, 1)),
        deepGlowReadClampV3(texture, base + int2(1, 1)),
        fraction.x);
    return mix(row0, row1, fraction.y);
}

static float4 deepGlowHighlightV3(
    float4 source,
    float threshold,
    float thresholdSmooth,
    uint alphaAssociation) {
    float3 workingRgb = source.rgb;
    float coverage = 1.0f;
    if (alphaAssociation == 1u) {
        if (!(source.a > 1.0e-6f)) {
            return float4(0.0f);
        }
        workingRgb /= source.a;
        coverage = source.a;
    }

    // Negative source values remain untouched in the base image but cannot
    // become negative light energy that darkens neighbouring pixels.
    const float3 positiveRgb = max(workingRgb, float3(0.0f));
    const float luminance = dot(positiveRgb, kDeepGlowLuminanceWeightsV3);
    const float hardContribution = max(luminance - threshold, 0.0f);
    const float kneeWidth = threshold * thresholdSmooth;

    // Threshold Smooth widens a continuous quadratic transition around the
    // threshold so selection stays temporally quiet on video instead of
    // switching per frame at a hard boundary.
    float softContribution = 0.0f;
    if (kneeWidth > 1.0e-6f) {
        const float shoulder = clamp(
            luminance - threshold + kneeWidth,
            0.0f,
            2.0f * kneeWidth);
        softContribution =
            shoulder * shoulder / (4.0f * kneeWidth);
    }

    const float selectedEnergy = max(hardContribution, softContribution);
    const float scale = selectedEnergy / max(luminance, 1.0e-6f);
    return float4(positiveRgb * scale * coverage, coverage);
}

static float4 deepGlowReducedSampleV3(
    texture2d<float, access::read> source,
    float2 pixelCenter,
    float threshold,
    float thresholdSmooth,
    uint extractHighlights,
    uint alphaAssociation) {
    const float4 value = deepGlowBilinearClampV3(source, pixelCenter);
    if (extractHighlights != 0u) {
        return deepGlowHighlightV3(
            value,
            threshold,
            thresholdSmooth,
            alphaAssociation);
    }
    return value;
}

static float3 deepGlowResolveAssociationV3(
    float4 glow,
    uint alphaAssociation) {
    if (alphaAssociation != 1u) {
        return glow.rgb;
    }
    if (!(glow.a > 1.0e-6f)) {
        return float3(0.0f);
    }
    return glow.rgb / glow.a;
}

// 3x3 tent over manual bilinear taps in coarse-texel spacing: the standard
// multi-resolution reconstruction filter that avoids blocky upsampling and
// visible dyadic steps between pyramid scales.
static float4 deepGlowTentUpsampleV3(
    texture2d<float, access::read> coarse,
    uint2 gid,
    float2 coarseSize,
    float2 destinationSize) {
    const float2 coarseCenter =
        (float2(gid) + 0.5f) * coarseSize / max(destinationSize, float2(1.0f));
    float4 accumulated = float4(0.0f);
    for (uint index = 0u; index < 9u; ++index) {
        accumulated += deepGlowBilinearClampV3(
            coarse,
            coarseCenter + float2(kDeepGlowSquareTentOffsetsV3[index])) *
            kDeepGlowSquareTentWeightsV3[index];
    }
    return accumulated;
}

kernel void filmtoneDeepGlowReduceV3(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant DeepGlowReduceUniformsV3& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    const uint2 destinationSize = uniforms.dimensions.zw;
    if (gid.x >= destinationSize.x || gid.y >= destinationSize.y) {
        return;
    }

    const float2 sourceSize = float2(uniforms.dimensions.xy);
    const float2 sourceStep =
        sourceSize / max(float2(destinationSize), float2(1.0f));
    const float2 sourceCenter = (float2(gid) + 0.5f) * sourceStep;
    const uint extractHighlights = uint(uniforms.selection.z + 0.5f);
    const uint alphaAssociation = uint(uniforms.selection.w + 0.5f);

    // Extraction runs per source tap before tent averaging, so the smooth
    // threshold acts on original pixels and the average then stabilises it.
    float4 reduced = float4(0.0f);
    for (uint index = 0u; index < 13u; ++index) {
        reduced += deepGlowReducedSampleV3(
            source,
            sourceCenter + float2(kDeepGlowTentOffsetsV3[index]),
            uniforms.selection.x,
            uniforms.selection.y,
            extractHighlights,
            alphaAssociation) * kDeepGlowTentWeightsV3[index];
    }
    output.write(reduced, gid);
}

// Deepest-level turnaround: blur the deepest reduction in place-scale onto
// the opposite plane as the unassociated running accumulation, scaled by the
// fractional deepest-level fade so Radius sweeps continuously across level
// transitions with no pop or step.
kernel void filmtoneDeepGlowTurnaroundV3(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant DeepGlowSpreadUniformsV3& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    const uint2 destinationSize = uniforms.dimensions.zw;
    if (gid.x >= destinationSize.x || gid.y >= destinationSize.y) {
        return;
    }

    float4 blurred = float4(0.0f);
    for (uint index = 0u; index < 9u; ++index) {
        blurred += deepGlowReadClampV3(
            source,
            int2(gid) + kDeepGlowSquareTentOffsetsV3[index]) *
            kDeepGlowSquareTentWeightsV3[index];
    }

    const uint alphaAssociation = uint(uniforms.spread.y + 0.5f);
    const float3 unassociated =
        deepGlowResolveAssociationV3(blurred, alphaAssociation);
    output.write(float4(unassociated * uniforms.spread.x, 1.0f), gid);
}

// Progressive coarse-to-fine reconstruction. Each step adds this level's
// reduction to the tent-upsampled coarser accumulation:
//   U_k = unassociate(D_k) + persistence * upsample(U_{k+1})
// With persistence 1.0 every dyadic octave carries equal annular energy, so
// the composed impulse response approximates finite-core inverse-square
// falloff between the finest and deepest footprints. Level weights are
// intentionally not normalized: widening Radius extends luminous tail energy
// instead of diluting the core into a veil.
kernel void filmtoneDeepGlowUpsampleCombineV3(
    texture2d<float, access::read> coarseAccumulation [[texture(0)]],
    texture2d<float, access::read> levelReduction [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant DeepGlowSpreadUniformsV3& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    const uint2 destinationSize = uniforms.dimensions.zw;
    if (gid.x >= destinationSize.x || gid.y >= destinationSize.y) {
        return;
    }

    const float3 upsampled = deepGlowTentUpsampleV3(
        coarseAccumulation,
        gid,
        float2(uniforms.dimensions.xy),
        float2(destinationSize)).rgb;
    const uint alphaAssociation = uint(uniforms.spread.y + 0.5f);
    // Apply the same unit-sum tent to a level whether it is currently the
    // deepest turnaround level or becomes an intermediate band after Radius
    // crosses the next mip boundary. Without this, D_k would switch from a
    // tent-filtered turnaround to a raw texel read at that boundary, creating
    // a small but real discontinuity even though the new deepest level fades
    // in continuously.
    const float4 filteredLevel = deepGlowTentUpsampleV3(
        levelReduction,
        gid,
        float2(destinationSize),
        float2(destinationSize));
    const float3 levelEnergy = deepGlowResolveAssociationV3(
        filteredLevel,
        alphaAssociation);
    output.write(
        float4(levelEnergy + upsampled * uniforms.spread.x, 1.0f),
        gid);
}

// Additive scene-energy composite: no shoulder, headroom, tonemap, or clamp
// runs on glow energy. Negative base RGB and greater-than-one values pass
// through; output alpha is the unmodified source alpha.
kernel void filmtoneDeepGlowCompositeV3(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::read> glowAccumulation [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant DeepGlowCompositeUniformsV3& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.metadata.z || gid.y >= uniforms.metadata.w) {
        return;
    }

    const float4 base = source.read(gid);
    const uint reducedLevelPresent = uniforms.metadata.x;
    const uint alphaAssociation = uniforms.metadata.y;

    float3 glow;
    if (reducedLevelPresent != 0u) {
        glow = deepGlowTentUpsampleV3(
            glowAccumulation,
            gid,
            float2(
                glowAccumulation.get_width(),
                glowAccumulation.get_height()),
            float2(uniforms.metadata.zw)).rgb;
    } else {
        glow = deepGlowResolveAssociationV3(
            deepGlowHighlightV3(
                base,
                uniforms.effect.y,
                uniforms.effect.z,
                alphaAssociation),
            alphaAssociation);
    }

    float3 diffusion = glow * uniforms.effect.x;
    if (alphaAssociation == 1u) {
        diffusion *= max(base.a, 0.0f);
    }
    output.write(float4(base.rgb + diffusion, base.a), gid);
}
)FILMTONE_METAL";

}  // namespace filmtone::resolve::effects::deep_glow::detail
