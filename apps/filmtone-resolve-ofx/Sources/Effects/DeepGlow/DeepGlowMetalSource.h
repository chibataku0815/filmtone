#pragma once

namespace filmtone::resolve::effects::deep_glow::detail {

inline constexpr char kDeepGlowReduceFunctionName[] =
    "filmtoneDeepGlowReduceV1";
inline constexpr char kDeepGlowCopyFunctionName[] =
    "filmtoneDeepGlowCopyV1";
inline constexpr char kDeepGlowCompositeFunctionName[] =
    "filmtoneDeepGlowCompositeV1";

inline constexpr char kDeepGlowReduceCacheKey[] =
    "filmtone.resolve.deep-glow.v1.reduce.rgba32f";
inline constexpr char kDeepGlowCopyCacheKey[] =
    "filmtone.resolve.deep-glow.v1.copy.rgba32f";
inline constexpr char kDeepGlowCompositeCacheKey[] =
    "filmtone.resolve.deep-glow.v1.composite.rgba32f";

inline constexpr char kDeepGlowMetalLibrarySource[] = R"FILMTONE_METAL(
#include <metal_stdlib>

using namespace metal;

constant float3 kDeepGlowLuminanceWeightsV1 =
    float3(0.2126f, 0.7152f, 0.0722f);

constant int2 kDeepGlowTentOffsetsV1[13] = {
    int2(-2,  2), int2( 0,  2), int2( 2,  2),
    int2(-1,  1), int2( 1,  1),
    int2(-2,  0), int2( 0,  0), int2( 2,  0),
    int2(-1, -1), int2( 1, -1),
    int2(-2, -2), int2( 0, -2), int2( 2, -2),
};

// Unit-sum 13-tap tent. Each reduction therefore preserves constant-image
// energy before the independently normalized multi-scale reconstruction.
constant float kDeepGlowTentWeightsV1[13] = {
    0.03125f, 0.0625f, 0.03125f,
    0.125f,   0.125f,
    0.0625f,  0.125f,  0.0625f,
    0.125f,   0.125f,
    0.03125f, 0.0625f, 0.03125f,
};

struct DeepGlowReduceUniformsV1 {
    uint4 dimensions;  // source width/height, destination width/height
    float4 selection;  // threshold, knee, extract flag, alpha association
};

struct DeepGlowCompositeUniformsV1 {
    float4 effect;     // strength, threshold, knee, reserved
    float4 weights0;   // reduced levels 1...4
    float4 weights1;   // reduced level 5, reserved...
    uint4 metadata;    // reduced-level count, alpha association, width, height
};

static int2 deepGlowClampCoordinateV1(
    texture2d<float, access::read> texture,
    int2 coordinate) {
    const int2 maximum = int2(
        int(texture.get_width()) - 1,
        int(texture.get_height()) - 1);
    return clamp(coordinate, int2(0), maximum);
}

static float4 deepGlowReadClampV1(
    texture2d<float, access::read> texture,
    int2 coordinate) {
    return texture.read(uint2(deepGlowClampCoordinateV1(texture, coordinate)));
}

// Spatial ABI v1 deliberately does not assume RGBA32Float filterability.
// Reconstruct linear samples from integer reads with explicit clamp-to-edge.
static float4 deepGlowBilinearClampV1(
    texture2d<float, access::read> texture,
    float2 pixelCenter) {
    const float2 baseFloat = floor(pixelCenter - 0.5f);
    const float2 fraction = pixelCenter - 0.5f - baseFloat;
    const int2 base = int2(baseFloat);
    const float4 row0 = mix(
        deepGlowReadClampV1(texture, base),
        deepGlowReadClampV1(texture, base + int2(1, 0)),
        fraction.x);
    const float4 row1 = mix(
        deepGlowReadClampV1(texture, base + int2(0, 1)),
        deepGlowReadClampV1(texture, base + int2(1, 1)),
        fraction.x);
    return mix(row0, row1, fraction.y);
}

static float4 deepGlowHighlightV1(
    float4 source,
    float threshold,
    float softKnee,
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
    const float luminance = dot(positiveRgb, kDeepGlowLuminanceWeightsV1);
    const float hardContribution = max(luminance - threshold, 0.0f);
    const float kneeWidth = threshold * softKnee;

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

static float4 deepGlowReducedSampleV1(
    texture2d<float, access::read> source,
    float2 pixelCenter,
    float threshold,
    float softKnee,
    uint extractHighlights,
    uint alphaAssociation) {
    const float4 value = deepGlowBilinearClampV1(source, pixelCenter);
    if (extractHighlights != 0u) {
        return deepGlowHighlightV1(
            value,
            threshold,
            softKnee,
            alphaAssociation);
    }
    return value;
}

static float3 deepGlowResolveAssociationV1(
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

kernel void filmtoneDeepGlowReduceV1(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant DeepGlowReduceUniformsV1& uniforms [[buffer(0)]],
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

    float4 reduced = float4(0.0f);
    for (uint index = 0u; index < 13u; ++index) {
        reduced += deepGlowReducedSampleV1(
            source,
            sourceCenter + float2(kDeepGlowTentOffsetsV1[index]),
            uniforms.selection.x,
            uniforms.selection.y,
            extractHighlights,
            alphaAssociation) * kDeepGlowTentWeightsV1[index];
    }
    output.write(reduced, gid);
}

kernel void filmtoneDeepGlowCopyV1(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    output.write(source.read(gid), gid);
}

kernel void filmtoneDeepGlowCompositeV1(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::read> glowMip1 [[texture(1)]],
    texture2d<float, access::read> glowMip2 [[texture(2)]],
    texture2d<float, access::read> glowMip3 [[texture(3)]],
    texture2d<float, access::read> glowMip4 [[texture(4)]],
    texture2d<float, access::read> glowMip5 [[texture(5)]],
    texture2d<float, access::write> output [[texture(6)]],
    constant DeepGlowCompositeUniformsV1& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    const float4 base = source.read(gid);
    const uint reducedLevelCount = uniforms.metadata.x;
    const uint alphaAssociation = uniforms.metadata.y;
    const float2 unitPosition =
        (float2(gid) + 0.5f) / max(float2(uniforms.metadata.zw), float2(1.0f));

    float3 glow = float3(0.0f);
    if (reducedLevelCount == 0u) {
        glow = deepGlowResolveAssociationV1(
            deepGlowHighlightV1(
                base,
                uniforms.effect.y,
                uniforms.effect.z,
                alphaAssociation),
            alphaAssociation);
    } else {
        if (reducedLevelCount >= 1u) {
            glow += deepGlowResolveAssociationV1(
                deepGlowBilinearClampV1(
                    glowMip1,
                    unitPosition * float2(glowMip1.get_width(), glowMip1.get_height())),
                alphaAssociation) * uniforms.weights0.x;
        }
        if (reducedLevelCount >= 2u) {
            glow += deepGlowResolveAssociationV1(
                deepGlowBilinearClampV1(
                    glowMip2,
                    unitPosition * float2(glowMip2.get_width(), glowMip2.get_height())),
                alphaAssociation) * uniforms.weights0.y;
        }
        if (reducedLevelCount >= 3u) {
            glow += deepGlowResolveAssociationV1(
                deepGlowBilinearClampV1(
                    glowMip3,
                    unitPosition * float2(glowMip3.get_width(), glowMip3.get_height())),
                alphaAssociation) * uniforms.weights0.z;
        }
        if (reducedLevelCount >= 4u) {
            glow += deepGlowResolveAssociationV1(
                deepGlowBilinearClampV1(
                    glowMip4,
                    unitPosition * float2(glowMip4.get_width(), glowMip4.get_height())),
                alphaAssociation) * uniforms.weights0.w;
        }
        if (reducedLevelCount >= 5u) {
            glow += deepGlowResolveAssociationV1(
                deepGlowBilinearClampV1(
                    glowMip5,
                    unitPosition * float2(glowMip5.get_width(), glowMip5.get_height())),
                alphaAssociation) * uniforms.weights1.x;
        }
    }

    if (alphaAssociation == 1u) {
        glow *= max(base.a, 0.0f);
    }
    output.write(float4(base.rgb + glow * uniforms.effect.x, base.a), gid);
}
)FILMTONE_METAL";

}  // namespace filmtone::resolve::effects::deep_glow::detail
