#include "VignetteProcessor.h"

#include <cmath>
#include <cstdint>
#include <string>

namespace filmtone::resolve::effects::vignette {
namespace {

constexpr char kVignettePipelineCacheKey[] =
    "filmtone.resolve.spatial.vignette.v1";
constexpr char kVignetteKernelFunction[] =
    "filmtoneResolveSpatialVignetteV1";

constexpr char kVignetteMetalSource[] = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct FilmtoneResolveVignetteUniformsV1 {
    uint width;
    uint height;
    float normalizedRadiusPerRenderedPixelX;
    float normalizedRadiusPerRenderedPixelY;
    float centerX;
    float centerY;
    float amount;
    float reserved;
};

kernel void filmtoneResolveSpatialVignetteV1(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant FilmtoneResolveVignetteUniformsV1& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) {
        return;
    }

    const float4 sourceColor = source.read(gid);
    const float2 renderedPixelCenter = float2(gid) + 0.5f;
    const float2 normalizedDistance =
        (renderedPixelCenter - float2(uniforms.centerX, uniforms.centerY)) *
        float2(
            uniforms.normalizedRadiusPerRenderedPixelX,
            uniforms.normalizedRadiusPerRenderedPixelY);
    const float normalizedDistanceSquared =
        dot(normalizedDistance, normalizedDistance);
    const float attenuation = clamp(
        1.0f - uniforms.amount * normalizedDistanceSquared,
        0.0f,
        1.0f);

    // The scalar multiplication preserves RGB sign, hue ratios, and values
    // above one. Alpha is copied from the unsplit source sample.
    output.write(
        float4(sourceColor.rgb * attenuation, sourceColor.a),
        gid);
}
)METAL";

struct alignas(16) VignetteMetalUniformsV1 final {
    std::uint32_t width;
    std::uint32_t height;
    float normalizedRadiusPerRenderedPixelX;
    float normalizedRadiusPerRenderedPixelY;
    float centerX;
    float centerY;
    float amount;
    float reserved;
};

static_assert(sizeof(VignetteMetalUniformsV1) == 32u);
static_assert(alignof(VignetteMetalUniformsV1) == 16u);

bool makeUniforms(
    const host::spatial::SpatialFrameDescriptor& frame,
    const spatial::VignetteParameterViewV1& parameters,
    VignetteMetalUniformsV1& uniforms,
    std::string& error) {
    if (frame.width == 0u || frame.height == 0u ||
        !std::isfinite(frame.renderScaleX) || frame.renderScaleX <= 0.0 ||
        !std::isfinite(frame.renderScaleY) || frame.renderScaleY <= 0.0 ||
        !std::isfinite(frame.pixelAspectRatio) ||
        frame.pixelAspectRatio <= 0.0 ||
        !std::isfinite(frame.logicalDisplayWidth) ||
        frame.logicalDisplayWidth <= 0.0 ||
        !std::isfinite(frame.logicalDisplayHeight) ||
        frame.logicalDisplayHeight <= 0.0 ||
        !std::isfinite(parameters.amount) || parameters.amount <= 0.0f) {
        error = "Vignette requires an active finite amount and finite positive display geometry.";
        return false;
    }

    const double halfDiagonal = 0.5 * std::hypot(
        frame.logicalDisplayWidth,
        frame.logicalDisplayHeight);
    const double displayPixelsPerRenderedPixelX =
        frame.pixelAspectRatio / frame.renderScaleX;
    const double displayPixelsPerRenderedPixelY =
        1.0 / frame.renderScaleY;
    const double normalizedRadiusPerRenderedPixelX =
        displayPixelsPerRenderedPixelX / halfDiagonal;
    const double normalizedRadiusPerRenderedPixelY =
        displayPixelsPerRenderedPixelY / halfDiagonal;
    if (!std::isfinite(halfDiagonal) || halfDiagonal <= 0.0 ||
        !std::isfinite(displayPixelsPerRenderedPixelX) ||
        !std::isfinite(displayPixelsPerRenderedPixelY) ||
        !std::isfinite(normalizedRadiusPerRenderedPixelX) ||
        normalizedRadiusPerRenderedPixelX <= 0.0 ||
        !std::isfinite(normalizedRadiusPerRenderedPixelY) ||
        normalizedRadiusPerRenderedPixelY <= 0.0) {
        error = "Vignette could not derive its full-resolution display-space radius.";
        return false;
    }

    const float normalizedScaleX =
        static_cast<float>(normalizedRadiusPerRenderedPixelX);
    const float normalizedScaleY =
        static_cast<float>(normalizedRadiusPerRenderedPixelY);
    if (!std::isfinite(normalizedScaleX) || normalizedScaleX <= 0.0f ||
        !std::isfinite(normalizedScaleY) || normalizedScaleY <= 0.0f) {
        error = "Vignette display-space radius exceeds float precision.";
        return false;
    }

    uniforms = VignetteMetalUniformsV1{
        frame.width,
        frame.height,
        normalizedScaleX,
        normalizedScaleY,
        static_cast<float>(static_cast<double>(frame.width) * 0.5),
        static_cast<float>(static_cast<double>(frame.height) * 0.5),
        parameters.amount,
        0.0f,
    };
    return true;
}

}  // namespace

VignetteProcessor::VignetteProcessor(
    spatial::VignetteParameterViewV1 parameters) noexcept
    : parameters_(parameters) {}

const spatial::VignetteParameterViewV1& VignetteProcessor::parameters()
    const noexcept {
    return parameters_;
}

const char* VignetteProcessor::name() const noexcept {
    return "Vignette";
}

bool VignetteProcessor::isIdentity(
    const host::RenderContext& context) const noexcept {
    (void)context;
    return !parameters_.active;
}

bool VignetteProcessor::makeResourcePlan(
    const host::RenderContext& context,
    const host::spatial::SpatialFrameDescriptor& frame,
    host::spatial::SpatialResourcePlan& plan,
    std::string& error) const {
    (void)context;
    VignetteMetalUniformsV1 uniforms{};
    if (!makeUniforms(frame, parameters_, uniforms, error)) {
        return false;
    }

    plan = host::spatial::SpatialResourcePlan{
        host::spatial::kSpatialModuleAbiVersion,
        1u,
        1u,
        host::spatial::SpatialEdgeMode::clampToEdge,
        true,
        true,
        true,
    };
    return true;
}

bool VignetteProcessor::encodeSpatialMetal(
    const host::RenderContext& context,
    const host::spatial::SpatialEncodeInvocation& invocation,
    std::string& error) const {
    (void)context;
    VignetteMetalUniformsV1 uniforms{};
    if (!makeUniforms(invocation.frame, parameters_, uniforms, error)) {
        return false;
    }

    const host::MetalPipelineRequest pipeline{
        kVignettePipelineCacheKey,
        kVignetteMetalSource,
        kVignetteKernelFunction,
        false,
    };
    const host::spatial::SpatialTextureBinding textureBindings[]{
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
    const host::spatial::SpatialBytesBinding bytesBindings[]{
        {0u, &uniforms, sizeof(uniforms)},
    };
    const host::spatial::SpatialComputePass pass{
        "Filmtone Vignette",
        &pipeline,
        textureBindings,
        2u,
        bytesBindings,
        1u,
        {invocation.frame.width, invocation.frame.height, 1u},
    };
    return invocation.commands.encodeComputePass(pass, error);
}

}  // namespace filmtone::resolve::effects::vignette
