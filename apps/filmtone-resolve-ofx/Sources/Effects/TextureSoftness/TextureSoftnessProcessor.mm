#include "TextureSoftnessProcessor.h"

#include <cmath>
#include <cstdint>
#include <limits>
#include <string>

namespace filmtone::resolve::texture_softness {
namespace {

constexpr char kPipelineCacheKey[] =
    "filmtone.resolve.spatial.texture-softness.acutance-relaxation.v2";
constexpr char kMetalFunctionName[] = "filmtoneTextureSoftnessV2";

// Texture Softness deliberately evaluates its compact bilateral neighborhood
// directly. Spatial ABI v1 exposes RGBA32Float textures without a filterability
// guarantee, so fractional taps use explicit clamp-to-edge bilinear reads.
constexpr char kMetalSource[] = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct FilmtoneTextureSoftnessUniformsV2 {
    uint width;
    uint height;
    uint reserved0;
    uint reserved1;

    float radiusX;
    float radiusY;
    float effectiveAmount;
    float rangeSigma;

    float reserved2;
    float reserved3;
    float chromaAttenuationScale;
    float highlightBias;
};

constant float2 kFilmtoneTextureSoftnessDirectionsV2[8] = {
    float2(1.0f, 0.0f),
    float2(-1.0f, 0.0f),
    float2(0.0f, 1.0f),
    float2(0.0f, -1.0f),
    float2(0.7071067811865475f, 0.7071067811865475f),
    float2(-0.7071067811865475f, 0.7071067811865475f),
    float2(0.7071067811865475f, -0.7071067811865475f),
    float2(-0.7071067811865475f, -0.7071067811865475f),
};

float filmtoneTextureSoftnessLuma709(float3 rgb) {
    return dot(rgb, float3(0.2126f, 0.7152f, 0.0722f));
}

float4 filmtoneTextureSoftnessReadClamped(
    texture2d<float, access::read> source,
    int2 coordinate,
    uint2 dimensions) {
    const int2 maximum = int2(dimensions) - int2(1);
    const int2 safeCoordinate = clamp(coordinate, int2(0), maximum);
    return source.read(uint2(safeCoordinate));
}

float4 filmtoneTextureSoftnessSampleLinearClamped(
    texture2d<float, access::read> source,
    float2 position,
    uint2 dimensions) {
    const float2 maximum = float2(dimensions - uint2(1));
    const float2 safePosition = clamp(position, float2(0.0f), maximum);
    const int2 lower = int2(floor(safePosition));
    const int2 upper = min(lower + int2(1), int2(dimensions) - int2(1));
    const float2 fraction = safePosition - float2(lower);

    const float4 row0 = mix(
        filmtoneTextureSoftnessReadClamped(source, lower, dimensions),
        filmtoneTextureSoftnessReadClamped(
            source,
            int2(upper.x, lower.y),
            dimensions),
        fraction.x);
    const float4 row1 = mix(
        filmtoneTextureSoftnessReadClamped(
            source,
            int2(lower.x, upper.y),
            dimensions),
        filmtoneTextureSoftnessReadClamped(source, upper, dimensions),
        fraction.x);
    return mix(row0, row1, fraction.y);
}

float filmtoneTextureSoftnessRangeWeight(
    float3 sampleRgb,
    float centerLuma,
    float inverseSigmaSquared) {
    const float difference =
        filmtoneTextureSoftnessLuma709(sampleRgb) - centerLuma;
    return exp(-(difference * difference) * inverseSigmaSquared);
}

float4 filmtoneTextureSoftnessContributionV2(
    texture2d<float, access::read> source,
    float2 position,
    uint2 dimensions,
    float centerLuma,
    float inverseSigmaSquared,
    float spatialWeight) {
    const float3 sampleRgb = filmtoneTextureSoftnessSampleLinearClamped(
        source,
        position,
        dimensions).rgb;
    const float weight = spatialWeight * filmtoneTextureSoftnessRangeWeight(
        sampleRgb,
        centerLuma,
        inverseSigmaSquared);
    return float4(sampleRgb * weight, weight);
}

kernel void filmtoneTextureSoftnessV2(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant FilmtoneTextureSoftnessUniformsV2& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) {
        return;
    }

    const uint2 dimensions = uint2(uniforms.width, uniforms.height);
    const float4 center = source.read(gid);
    const float2 position = float2(gid);
    const float2 radius = float2(uniforms.radiusX, uniforms.radiusY);

    const float centerLuma = filmtoneTextureSoftnessLuma709(center.rgb);
    const float sigmaSquared = max(
        uniforms.rangeSigma * uniforms.rangeSigma,
        1.0e-6f);
    const float inverseSigmaSquared = 1.0f / sigmaSquared;
    // A center-weighted inner ring relaxes fine digital acutance while the
    // wider ring reaches the visible texture scale at high Amount. Range
    // weights, rather than a residual-detail kill switch, protect major edges.
    float4 reference = float4(center.rgb * 1.5f, 1.5f);
    for (uint directionIndex = 0u; directionIndex < 8u; ++directionIndex) {
        const float2 direction =
            kFilmtoneTextureSoftnessDirectionsV2[directionIndex];
        reference += filmtoneTextureSoftnessContributionV2(
            source,
            position + direction * radius * 0.45f,
            dimensions,
            centerLuma,
            inverseSigmaSquared,
            1.0f);
        reference += filmtoneTextureSoftnessContributionV2(
            source,
            position + direction * radius,
            dimensions,
            centerLuma,
            inverseSigmaSquared,
            0.65f);
    }
    const float3 referenceRgb = reference.rgb / max(reference.a, 1.0e-6f);
    const float3 detail = center.rgb - referenceRgb;

    const float3 lumaWeights = float3(0.2126f, 0.7152f, 0.0722f);
    const float detailLuma = dot(detail, lumaWeights);
    // Rec.709 weights measure luminance; a neutral RGB vector reconstructs
    // that luminance. Multiplying by the weights here would retain most
    // grayscale acutance and manufacture a false chroma residual.
    const float3 detailLumaVector = float3(detailLuma);
    const float3 detailChroma = detail - detailLumaVector;
    const float highlightWeight = mix(
        1.0f,
        uniforms.highlightBias,
        smoothstep(0.6f, 0.9f, centerLuma));
    const float amount = clamp(uniforms.effectiveAmount, 0.0f, 1.0f);
    const float relaxation = amount * (0.58f + 0.42f * amount);
    const float lumaAttenuation = clamp(
        relaxation * max(highlightWeight, 0.0f),
        0.0f,
        1.0f);
    const float chromaAttenuation = clamp(
        lumaAttenuation * uniforms.chromaAttenuationScale,
        0.0f,
        1.0f);
    const float3 softened = center.rgb -
        detailLumaVector * lumaAttenuation -
        detailChroma * chromaAttenuation;

    output.write(float4(softened, center.a), gid);
}
)METAL";

struct alignas(16) TextureSoftnessUniformsV2 final {
    std::uint32_t width;
    std::uint32_t height;
    std::uint32_t reserved0;
    std::uint32_t reserved1;

    float radiusX;
    float radiusY;
    float effectiveAmount;
    float rangeSigma;

    float reserved2;
    float reserved3;
    float chromaAttenuationScale;
    float highlightBias;
};

static_assert(sizeof(TextureSoftnessUniformsV2) == 48u);
static_assert(alignof(TextureSoftnessUniformsV2) == 16u);

bool validateParameters(
    const spatial::TextureSoftnessParameterViewV1& parameters,
    std::string& error) {
    const bool finite =
        std::isfinite(parameters.amount) &&
        std::isfinite(parameters.effectiveAmount) &&
        std::isfinite(parameters.kernelRadiusFullResolutionPixels) &&
        std::isfinite(parameters.rangeSigma) &&
        std::isfinite(parameters.chromaAttenuationScale) &&
        std::isfinite(parameters.highlightBias);
    if (!parameters.active || !finite || parameters.amount <= 0.0f ||
        parameters.effectiveAmount <= 0.0f ||
        parameters.effectiveAmount >
            spatial::kTextureSoftnessEffectiveMaximumV1 ||
        parameters.kernelRadiusFullResolutionPixels <
            spatial::kTextureSoftnessKernelRadiusMinimumFullResolutionPixelsV1 ||
        parameters.kernelRadiusFullResolutionPixels >
            spatial::kTextureSoftnessKernelRadiusMaximumFullResolutionPixelsV1 ||
        parameters.rangeSigma <= 0.0f ||
        parameters.chromaAttenuationScale < 0.0f ||
        parameters.chromaAttenuationScale > 1.0f ||
        parameters.highlightBias < 0.0f) {
        error = "Texture Softness received values outside its frozen parameter view.";
        return false;
    }
    return true;
}

bool scaledRadius(
    float fullResolutionRadius,
    double renderScale,
    float& result) noexcept {
    const double value =
        static_cast<double>(fullResolutionRadius) * renderScale;
    if (!std::isfinite(value) || value <= 0.0 ||
        value > static_cast<double>(std::numeric_limits<float>::max())) {
        return false;
    }
    result = static_cast<float>(value);
    return std::isfinite(result) && result > 0.0f;
}

bool makeUniforms(
    const spatial::TextureSoftnessParameterViewV1& parameters,
    const host::spatial::SpatialFrameDescriptor& frame,
    TextureSoftnessUniformsV2& uniforms,
    std::string& error) {
    float radiusX = 0.0f;
    float radiusY = 0.0f;
    if (frame.width == 0u || frame.height == 0u ||
        !scaledRadius(
            parameters.kernelRadiusFullResolutionPixels,
            frame.renderScaleX,
            radiusX) ||
        !scaledRadius(
            parameters.kernelRadiusFullResolutionPixels,
            frame.renderScaleY,
            radiusY)) {
        error = "Texture Softness could not resolve its render-scale radius.";
        return false;
    }
    uniforms = TextureSoftnessUniformsV2{
        frame.width,
        frame.height,
        0u,
        0u,
        radiusX,
        radiusY,
        parameters.effectiveAmount,
        parameters.rangeSigma,
        0.0f,
        0.0f,
        parameters.chromaAttenuationScale,
        parameters.highlightBias,
    };
    return true;
}

}  // namespace

TextureSoftnessProcessor::TextureSoftnessProcessor(
    spatial::TextureSoftnessParameterViewV1 parameters) noexcept
    : parameters_(parameters) {}

const char* TextureSoftnessProcessor::name() const noexcept {
    return "Texture Softness";
}

bool TextureSoftnessProcessor::isIdentity(
    const host::RenderContext& context) const noexcept {
    static_cast<void>(context);
    // Invalid active views deliberately reach resource planning and fail
    // closed. Only the generated inactive/zero view is an identity.
    return !parameters_.active || parameters_.effectiveAmount == 0.0f;
}

bool TextureSoftnessProcessor::makeResourcePlan(
    const host::RenderContext& context,
    const host::spatial::SpatialFrameDescriptor& frame,
    host::spatial::SpatialResourcePlan& plan,
    std::string& error) const {
    static_cast<void>(context);
    error.clear();
    if (!validateParameters(parameters_, error)) {
        return false;
    }

    TextureSoftnessUniformsV2 uniforms{};
    if (!makeUniforms(parameters_, frame, uniforms, error)) {
        return false;
    }

    plan = host::spatial::SpatialResourcePlan{};
    plan.abiVersion = host::spatial::kSpatialModuleAbiVersion;
    plan.passCount = 1u;
    plan.mipLevelCount = 1u;
    plan.edgeMode = host::spatial::SpatialEdgeMode::clampToEdge;
    plan.requiresFullFrame = true;
    plan.preservesExtendedRange = true;
    plan.preservesAlpha = true;
    return true;
}

bool TextureSoftnessProcessor::encodeSpatialMetal(
    const host::RenderContext& context,
    const host::spatial::SpatialEncodeInvocation& invocation,
    std::string& error) const {
    static_cast<void>(context);
    error.clear();
    if (!validateParameters(parameters_, error)) {
        return false;
    }
    if (invocation.source.executionToken == 0u ||
        invocation.source.executionToken != invocation.output.executionToken ||
        invocation.source.mipLevel != 0u ||
        invocation.output.mipLevel != 0u ||
        invocation.source.width != invocation.frame.width ||
        invocation.source.height != invocation.frame.height ||
        invocation.output.width != invocation.frame.width ||
        invocation.output.height != invocation.frame.height ||
        invocation.source.plane == invocation.output.plane) {
        error = "Texture Softness received an invalid Spatial ABI image pair.";
        return false;
    }

    TextureSoftnessUniformsV2 uniforms{};
    if (!makeUniforms(parameters_, invocation.frame, uniforms, error)) {
        return false;
    }

    const host::MetalPipelineRequest pipeline{
        kPipelineCacheKey,
        kMetalSource,
        kMetalFunctionName,
        false,
    };
    const host::spatial::SpatialTextureBinding textures[] = {
        {
            0u,
            invocation.source,
            host::spatial::SpatialTextureAccess::readOnly,
        },
        {
            1u,
            invocation.output,
            host::spatial::SpatialTextureAccess::writeOnly,
        },
    };
    const host::spatial::SpatialBytesBinding bytes[] = {
        {0u, &uniforms, sizeof(uniforms)},
    };
    const host::spatial::SpatialComputePass pass{
        "Filmtone Texture Softness Acutance Relaxation",
        &pipeline,
        textures,
        2u,
        bytes,
        1u,
        {
            invocation.frame.width,
            invocation.frame.height,
            1u,
        },
    };
    return invocation.commands.encodeComputePass(pass, error);
}

}  // namespace filmtone::resolve::texture_softness
