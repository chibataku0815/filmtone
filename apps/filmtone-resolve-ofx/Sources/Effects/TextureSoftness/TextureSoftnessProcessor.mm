#include "TextureSoftnessProcessor.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <string>

namespace filmtone::resolve::texture_softness {
namespace {

constexpr char kPipelineCacheKey[] =
    "filmtone.resolve.spatial.texture-softness.bilateral-detail.v1";
constexpr char kMetalFunctionName[] = "filmtoneTextureSoftnessV1";

// Texture Softness deliberately evaluates its compact bilateral neighborhood
// directly. Spatial ABI v1 exposes RGBA32Float textures without a filterability
// guarantee, so fractional taps use explicit clamp-to-edge bilinear reads.
constexpr char kMetalSource[] = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct FilmtoneTextureSoftnessUniformsV1 {
    uint width;
    uint height;
    uint reserved0;
    uint reserved1;

    float radiusX;
    float radiusY;
    float effectiveAmount;
    float rangeSigma;

    float detailAmplitudeLow;
    float detailAmplitudeHigh;
    float chromaAttenuationScale;
    float highlightBias;
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

kernel void filmtoneTextureSoftnessV1(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant FilmtoneTextureSoftnessUniformsV1& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) {
        return;
    }

    const uint2 dimensions = uint2(uniforms.width, uniforms.height);
    const float4 center = source.read(gid);
    const float2 position = float2(gid);
    const float diagonalScale = 0.7071067811865475f;
    const float2 radius = float2(uniforms.radiusX, uniforms.radiusY);
    const float2 diagonalRadius = radius * diagonalScale;

    const float3 east = filmtoneTextureSoftnessSampleLinearClamped(
        source, position + float2(radius.x, 0.0f), dimensions).rgb;
    const float3 west = filmtoneTextureSoftnessSampleLinearClamped(
        source, position - float2(radius.x, 0.0f), dimensions).rgb;
    const float3 north = filmtoneTextureSoftnessSampleLinearClamped(
        source, position + float2(0.0f, radius.y), dimensions).rgb;
    const float3 south = filmtoneTextureSoftnessSampleLinearClamped(
        source, position - float2(0.0f, radius.y), dimensions).rgb;
    const float3 northEast = filmtoneTextureSoftnessSampleLinearClamped(
        source, position + diagonalRadius, dimensions).rgb;
    const float3 northWest = filmtoneTextureSoftnessSampleLinearClamped(
        source,
        position + float2(-diagonalRadius.x, diagonalRadius.y),
        dimensions).rgb;
    const float3 southEast = filmtoneTextureSoftnessSampleLinearClamped(
        source,
        position + float2(diagonalRadius.x, -diagonalRadius.y),
        dimensions).rgb;
    const float3 southWest = filmtoneTextureSoftnessSampleLinearClamped(
        source, position - diagonalRadius, dimensions).rgb;

    const float centerLuma = filmtoneTextureSoftnessLuma709(center.rgb);
    const float sigmaSquared = max(
        uniforms.rangeSigma * uniforms.rangeSigma,
        1.0e-6f);
    const float inverseSigmaSquared = 1.0f / sigmaSquared;
    const float eastWeight = filmtoneTextureSoftnessRangeWeight(
        east, centerLuma, inverseSigmaSquared);
    const float westWeight = filmtoneTextureSoftnessRangeWeight(
        west, centerLuma, inverseSigmaSquared);
    const float northWeight = filmtoneTextureSoftnessRangeWeight(
        north, centerLuma, inverseSigmaSquared);
    const float southWeight = filmtoneTextureSoftnessRangeWeight(
        south, centerLuma, inverseSigmaSquared);
    const float northEastWeight = filmtoneTextureSoftnessRangeWeight(
        northEast, centerLuma, inverseSigmaSquared);
    const float northWestWeight = filmtoneTextureSoftnessRangeWeight(
        northWest, centerLuma, inverseSigmaSquared);
    const float southEastWeight = filmtoneTextureSoftnessRangeWeight(
        southEast, centerLuma, inverseSigmaSquared);
    const float southWestWeight = filmtoneTextureSoftnessRangeWeight(
        southWest, centerLuma, inverseSigmaSquared);

    const float3 referenceSum = center.rgb +
        east * eastWeight + west * westWeight +
        north * northWeight + south * southWeight +
        northEast * northEastWeight + northWest * northWestWeight +
        southEast * southEastWeight + southWest * southWestWeight;
    const float referenceWeight = 1.0f +
        eastWeight + westWeight + northWeight + southWeight +
        northEastWeight + northWestWeight +
        southEastWeight + southWestWeight;
    const float3 referenceRgb = referenceSum / referenceWeight;
    const float3 detail = center.rgb - referenceRgb;

    const float3 lumaWeights = float3(0.2126f, 0.7152f, 0.0722f);
    const float detailLuma = dot(detail, lumaWeights);
    const float3 detailLumaVector = detailLuma * lumaWeights;
    const float3 detailChroma = detail - detailLumaVector;
    const float detailGate = 1.0f - smoothstep(
        uniforms.detailAmplitudeLow,
        uniforms.detailAmplitudeHigh,
        abs(detailLuma));
    const float highlightWeight = mix(
        1.0f,
        uniforms.highlightBias,
        smoothstep(0.6f, 0.9f, centerLuma));
    const float lumaAttenuation =
        uniforms.effectiveAmount * detailGate * highlightWeight;
    const float chromaAttenuation =
        lumaAttenuation * uniforms.chromaAttenuationScale;
    const float3 softened = center.rgb -
        detailLumaVector * lumaAttenuation -
        detailChroma * chromaAttenuation;

    output.write(float4(softened, center.a), gid);
}
)METAL";

struct alignas(16) TextureSoftnessUniformsV1 final {
    std::uint32_t width;
    std::uint32_t height;
    std::uint32_t reserved0;
    std::uint32_t reserved1;

    float radiusX;
    float radiusY;
    float effectiveAmount;
    float rangeSigma;

    float detailAmplitudeLow;
    float detailAmplitudeHigh;
    float chromaAttenuationScale;
    float highlightBias;
};

static_assert(sizeof(TextureSoftnessUniformsV1) == 48u);
static_assert(alignof(TextureSoftnessUniformsV1) == 16u);

bool validateParameters(
    const spatial::TextureSoftnessParameterViewV1& parameters,
    std::string& error) {
    const bool finite =
        std::isfinite(parameters.amount) &&
        std::isfinite(parameters.effectiveAmount) &&
        std::isfinite(parameters.kernelRadiusFullResolutionPixels) &&
        std::isfinite(parameters.rangeSigma) &&
        std::isfinite(parameters.detailAmplitudeLow) &&
        std::isfinite(parameters.detailAmplitudeHigh) &&
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
        parameters.detailAmplitudeLow < 0.0f ||
        parameters.detailAmplitudeHigh <= parameters.detailAmplitudeLow ||
        parameters.chromaAttenuationScale < 0.0f ||
        parameters.chromaAttenuationScale > 1.0f ||
        parameters.highlightBias < 0.0f ||
        parameters.effectiveAmount *
                std::max(1.0f, parameters.highlightBias) >
            1.0f) {
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
    TextureSoftnessUniformsV1& uniforms,
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
    uniforms = TextureSoftnessUniformsV1{
        frame.width,
        frame.height,
        0u,
        0u,
        radiusX,
        radiusY,
        parameters.effectiveAmount,
        parameters.rangeSigma,
        parameters.detailAmplitudeLow,
        parameters.detailAmplitudeHigh,
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

    TextureSoftnessUniformsV1 uniforms{};
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

    TextureSoftnessUniformsV1 uniforms{};
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
        "Filmtone Texture Softness Bilateral Detail",
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
