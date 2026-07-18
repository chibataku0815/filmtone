#include "PeripheralChromaticShiftProcessor.h"

#include <cmath>
#include <cstdint>

#include "PeripheralChromaticShiftMetalSource.h"

namespace filmtone::resolve::effects::peripheral_chromatic_shift {
namespace {

constexpr char kProcessorName[] = "Peripheral Chromatic Shift";
constexpr char kPipelineCacheKey[] =
    "filmtone.resolve.peripheral-chromatic-shift.bilinear.v1";
constexpr char kMetalFunctionName[] =
    "filmtonePeripheralChromaticShiftV1";

struct alignas(16) PeripheralChromaticShiftUniformsV1 final {
    std::uint32_t width;
    std::uint32_t height;
    float amount;
    float radialExponent;

    float canonicalUnitsPerPixelX;
    float canonicalUnitsPerPixelY;
    float maximumOffsetX;
    float maximumOffsetY;
};

static_assert(sizeof(PeripheralChromaticShiftUniformsV1) == 32u);
static_assert(alignof(PeripheralChromaticShiftUniformsV1) == 16u);

bool hasValidActiveParameters(
    const spatial::PeripheralChromaticShiftParameterViewV1& parameters)
    noexcept {
    return parameters.active &&
        std::isfinite(parameters.amount) &&
        parameters.amount > 0.0f;
}

bool hasValidFrame(
    const host::spatial::SpatialFrameDescriptor& frame) noexcept {
    return frame.width > 0u && frame.height > 0u &&
        std::isfinite(frame.canonicalUnitsPerPixelX) &&
        frame.canonicalUnitsPerPixelX > 0.0 &&
        std::isfinite(frame.canonicalUnitsPerPixelY) &&
        frame.canonicalUnitsPerPixelY > 0.0;
}

bool hasValidMetalUniforms(
    const PeripheralChromaticShiftUniformsV1& uniforms) noexcept {
    return uniforms.width > 0u && uniforms.height > 0u &&
        std::isfinite(uniforms.amount) && uniforms.amount > 0.0f &&
        std::isfinite(uniforms.radialExponent) &&
        uniforms.radialExponent > 0.0f &&
        std::isfinite(uniforms.canonicalUnitsPerPixelX) &&
        uniforms.canonicalUnitsPerPixelX > 0.0f &&
        std::isfinite(uniforms.canonicalUnitsPerPixelY) &&
        uniforms.canonicalUnitsPerPixelY > 0.0f &&
        std::isfinite(uniforms.maximumOffsetX) &&
        uniforms.maximumOffsetX > 0.0f &&
        std::isfinite(uniforms.maximumOffsetY) &&
        uniforms.maximumOffsetY > 0.0f;
}

const host::MetalPipelineRequest& pipelineRequest() {
    static const host::MetalPipelineRequest request{
        kPipelineCacheKey,
        detail::kPeripheralChromaticShiftMetalSource,
        kMetalFunctionName,
        false,
    };
    return request;
}

}  // namespace

PeripheralChromaticShiftProcessor::PeripheralChromaticShiftProcessor(
    const spatial::FilmtoneSpatialParametersV1& parameters) noexcept
    : parameterView_(
          spatial::makePeripheralChromaticShiftParameterViewV1(parameters)) {}

const spatial::PeripheralChromaticShiftParameterViewV1&
PeripheralChromaticShiftProcessor::parameterView() const noexcept {
    return parameterView_;
}

const char* PeripheralChromaticShiftProcessor::name() const noexcept {
    return kProcessorName;
}

bool PeripheralChromaticShiftProcessor::isIdentity(
    const host::RenderContext& context) const noexcept {
    static_cast<void>(context);
    return !parameterView_.active;
}

bool PeripheralChromaticShiftProcessor::makeResourcePlan(
    const host::RenderContext& context,
    const host::spatial::SpatialFrameDescriptor& frame,
    host::spatial::SpatialResourcePlan& plan,
    std::string& error) const {
    static_cast<void>(context);
    plan = host::spatial::SpatialResourcePlan{};
    error.clear();

    if (!hasValidActiveParameters(parameterView_)) {
        error = "Peripheral Chromatic Shift received an invalid active generated parameter view.";
        return false;
    }
    if (!hasValidFrame(frame)) {
        error = "Peripheral Chromatic Shift received invalid canonical frame coordinates.";
        return false;
    }

    plan.abiVersion = host::spatial::kSpatialModuleAbiVersion;
    plan.passCount = 1u;
    plan.mipLevelCount = 1u;
    plan.edgeMode = host::spatial::SpatialEdgeMode::clampToEdge;
    plan.requiresFullFrame = true;
    plan.preservesExtendedRange = true;
    plan.preservesAlpha = true;
    return true;
}

bool PeripheralChromaticShiftProcessor::encodeSpatialMetal(
    const host::RenderContext& context,
    const host::spatial::SpatialEncodeInvocation& invocation,
    std::string& error) const {
    static_cast<void>(context);
    error.clear();

    if (!hasValidActiveParameters(parameterView_)) {
        error = "Peripheral Chromatic Shift cannot encode an invalid or identity parameter view.";
        return false;
    }
    if (!hasValidFrame(invocation.frame)) {
        error = "Peripheral Chromatic Shift cannot encode invalid canonical frame coordinates.";
        return false;
    }
    if (invocation.source.mipLevel != 0u ||
        invocation.output.mipLevel != 0u ||
        invocation.source.executionToken == 0u ||
        invocation.source.executionToken != invocation.output.executionToken ||
        invocation.source.plane == invocation.output.plane ||
        invocation.source.width != invocation.frame.width ||
        invocation.source.height != invocation.frame.height ||
        invocation.output.width != invocation.frame.width ||
        invocation.output.height != invocation.frame.height) {
        error = "Peripheral Chromatic Shift requires distinct full-resolution mip-zero views.";
        return false;
    }

    const PeripheralChromaticShiftUniformsV1 uniforms{
        invocation.frame.width,
        invocation.frame.height,
        parameterView_.amount,
        spatial::kPeripheralChromaticShiftRadialExponentV1,
        static_cast<float>(invocation.frame.canonicalUnitsPerPixelX),
        static_cast<float>(invocation.frame.canonicalUnitsPerPixelY),
        parameterView_.amount * static_cast<float>(invocation.frame.width),
        parameterView_.amount * static_cast<float>(invocation.frame.height),
    };
    if (!hasValidMetalUniforms(uniforms)) {
        error = "Peripheral Chromatic Shift derived invalid Metal uniform values.";
        return false;
    }
    const host::MetalPipelineRequest& pipeline = pipelineRequest();
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
        "Filmtone Peripheral Chromatic Shift",
        &pipeline,
        textureBindings,
        2u,
        bytesBindings,
        1u,
        {
            invocation.frame.width,
            invocation.frame.height,
            1u,
        },
    };
    return invocation.commands.encodeComputePass(pass, error);
}

}  // namespace filmtone::resolve::effects::peripheral_chromatic_shift
