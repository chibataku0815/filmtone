#include "DeepGlowProcessor.h"

#include "DeepGlowMetalSource.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <string>

namespace filmtone::resolve::effects::deep_glow {
namespace {

constexpr std::uint32_t kMaximumReducedLevelCount = 5u;

struct alignas(16) DeepGlowReduceUniformsV1 final {
    std::array<std::uint32_t, 4> dimensions{};
    std::array<float, 4> selection{};
};

struct alignas(16) DeepGlowCompositeUniformsV1 final {
    std::array<float, 4> effect{};
    std::array<float, 4> weights0{};
    std::array<float, 4> weights1{};
    std::array<std::uint32_t, 4> metadata{};
};

static_assert(sizeof(DeepGlowReduceUniformsV1) == 32u);
static_assert(alignof(DeepGlowReduceUniformsV1) == 16u);
static_assert(sizeof(DeepGlowCompositeUniformsV1) == 64u);
static_assert(alignof(DeepGlowCompositeUniformsV1) == 16u);

bool isUnitFinite(float value) noexcept {
    return std::isfinite(value) && value >= 0.0f && value <= 1.0f;
}

bool isKnownAlphaAssociation(
    DeepGlowAlphaAssociationV1 alphaAssociation) noexcept {
    return alphaAssociation == DeepGlowAlphaAssociationV1::unassociatedOrOpaque ||
           alphaAssociation == DeepGlowAlphaAssociationV1::premultiplied;
}

bool validateEncodeInvocation(
    const host::spatial::SpatialEncodeInvocation& invocation,
    std::string& error) {
    const auto& source = invocation.source;
    const auto& output = invocation.output;
    if (source.executionToken == 0u || output.executionToken == 0u ||
        source.executionToken != output.executionToken) {
        error = "Deep Glow received missing or mismatched spatial execution tokens.";
        return false;
    }
    if (source.mipLevel != 0u || output.mipLevel != 0u) {
        error = "Deep Glow requires full-resolution mip-zero graph endpoints.";
        return false;
    }
    if (source.width != invocation.frame.width ||
        source.height != invocation.frame.height ||
        output.width != invocation.frame.width ||
        output.height != invocation.frame.height) {
        error = "Deep Glow graph endpoints disagree with the full frame dimensions.";
        return false;
    }
    if (source.plane == output.plane) {
        error = "Deep Glow requires distinct source and output ping-pong planes.";
        return false;
    }
    return true;
}

std::uint32_t reducedLevelCount(
    const host::spatial::SpatialFrameDescriptor& frame) noexcept {
    std::uint32_t width = frame.width;
    std::uint32_t height = frame.height;
    std::uint32_t count = 0u;
    while ((width > 1u || height > 1u) &&
           count < kMaximumReducedLevelCount) {
        width = std::max<std::uint32_t>(1u, width / 2u);
        height = std::max<std::uint32_t>(1u, height / 2u);
        ++count;
    }
    return count;
}

std::array<float, kMaximumReducedLevelCount> makeEnergyWeights(
    float radius,
    std::uint32_t levelCount) noexcept {
    std::array<float, kMaximumReducedLevelCount> weights{};
    if (levelCount == 0u) {
        return weights;
    }
    if (levelCount == 1u) {
        weights[0] = 1.0f;
        return weights;
    }

    // A narrow radius-centred distribution carries the visible body while a
    // restrained exponential core prevents the broadest settings from
    // becoming a hollow low-frequency veil. Normalization makes radius a
    // spatial-distribution control rather than an unintended gain control.
    constexpr double kCoreMix = 0.18;
    constexpr double kFocusMix = 1.0 - kCoreMix;
    const double sigma = 0.22 + 0.08 * static_cast<double>(radius);
    double total = 0.0;
    for (std::uint32_t index = 0u; index < levelCount; ++index) {
        const double t = static_cast<double>(index) /
            static_cast<double>(levelCount - 1u);
        const double delta = (t - static_cast<double>(radius)) / sigma;
        const double focus = std::exp(-0.5 * delta * delta);
        const double core = std::exp(-3.5 * t);
        const double raw = kFocusMix * focus + kCoreMix * core;
        weights[index] = static_cast<float>(raw);
        total += raw;
    }
    if (!(total > 0.0) || !std::isfinite(total)) {
        weights = {};
        weights[0] = 1.0f;
        return weights;
    }
    const float inverseTotal = static_cast<float>(1.0 / total);
    for (std::uint32_t index = 0u; index < levelCount; ++index) {
        weights[index] *= inverseTotal;
    }
    return weights;
}

}  // namespace

DeepGlowProcessor::DeepGlowProcessor(
    spatial::DeepGlowParameterViewV1 parameters,
    DeepGlowAlphaAssociationV1 alphaAssociation) noexcept
    : parameters_(parameters),
      alphaAssociation_(alphaAssociation) {}

const char* DeepGlowProcessor::name() const noexcept {
    return "Filmtone Deep Glow";
}

bool DeepGlowProcessor::isIdentity(
    const host::RenderContext& context) const noexcept {
    (void)context;
    return !parameters_.active || parameters_.strength == 0.0f;
}

bool DeepGlowProcessor::makeResourcePlan(
    const host::RenderContext& context,
    const host::spatial::SpatialFrameDescriptor& frame,
    host::spatial::SpatialResourcePlan& plan,
    std::string& error) const {
    (void)context;
    plan = host::spatial::SpatialResourcePlan{};
    error.clear();

    if (isIdentity(context)) {
        return true;
    }
    if (!isUnitFinite(parameters_.strength) ||
        !(parameters_.strength > 0.0f) ||
        !isUnitFinite(parameters_.threshold) ||
        !isUnitFinite(parameters_.radius) ||
        !isUnitFinite(parameters_.softKnee)) {
        error = "Deep Glow received values outside its generated parameter view.";
        return false;
    }
    if (!isKnownAlphaAssociation(alphaAssociation_)) {
        error = "Deep Glow requires an explicit valid OFX alpha association.";
        return false;
    }
    if (frame.width == 0u || frame.height == 0u) {
        error = "Deep Glow cannot plan resources for an empty frame.";
        return false;
    }

    const std::uint32_t glowLevels = reducedLevelCount(frame);
    plan.abiVersion = host::spatial::kSpatialModuleAbiVersion;
    plan.passCount = glowLevels * 2u + 1u;
    plan.mipLevelCount = glowLevels + 1u;
    plan.edgeMode = host::spatial::SpatialEdgeMode::clampToEdge;
    plan.requiresFullFrame = true;
    plan.preservesExtendedRange = true;
    plan.preservesAlpha = true;
    return true;
}

bool DeepGlowProcessor::encodeSpatialMetal(
    const host::RenderContext& context,
    const host::spatial::SpatialEncodeInvocation& invocation,
    std::string& error) const {
    error.clear();
    if (!validateEncodeInvocation(invocation, error)) {
        return false;
    }
    host::spatial::SpatialResourcePlan plan{};
    if (!makeResourcePlan(context, invocation.frame, plan, error)) {
        return false;
    }
    if (isIdentity(context)) {
        error = "Deep Glow identity must be removed before spatial encoding.";
        return false;
    }

    const std::uint32_t glowLevels = plan.mipLevelCount - 1u;
    std::array<host::spatial::SpatialImageView,
               kMaximumReducedLevelCount> retainedGlowMips{};
    retainedGlowMips.fill(invocation.source);

    const host::MetalPipelineRequest reducePipeline{
        detail::kDeepGlowReduceCacheKey,
        detail::kDeepGlowMetalLibrarySource,
        detail::kDeepGlowReduceFunctionName,
        false,
    };
    const host::MetalPipelineRequest copyPipeline{
        detail::kDeepGlowCopyCacheKey,
        detail::kDeepGlowMetalLibrarySource,
        detail::kDeepGlowCopyFunctionName,
        false,
    };

    for (std::uint32_t level = 1u; level <= glowLevels; ++level) {
        const host::spatial::SpatialImageView levelSource =
            level == 1u ? invocation.source : retainedGlowMips[level - 2u];
        host::spatial::SpatialImageView scratch{};
        host::spatial::SpatialImageView retained{};
        if (!invocation.resources.image(
                invocation.output.plane,
                level,
                scratch,
                error) ||
            !invocation.resources.image(
                invocation.source.plane,
                level,
                retained,
                error)) {
            return false;
        }

        const DeepGlowReduceUniformsV1 uniforms{
            {
                levelSource.width,
                levelSource.height,
                scratch.width,
                scratch.height,
            },
            {
                parameters_.threshold,
                parameters_.softKnee,
                level == 1u ? 1.0f : 0.0f,
                alphaAssociation_ == DeepGlowAlphaAssociationV1::premultiplied
                    ? 1.0f
                    : 0.0f,
            },
        };
        const std::array<host::spatial::SpatialTextureBinding, 2>
            reduceTextures{{
                {0u, levelSource, host::spatial::SpatialTextureAccess::readOnly},
                {1u, scratch, host::spatial::SpatialTextureAccess::writeOnly},
            }};
        const host::spatial::SpatialBytesBinding reduceBytes{
            0u,
            &uniforms,
            sizeof(uniforms),
        };
        const host::spatial::SpatialComputePass reducePass{
            level == 1u
                ? "Filmtone Deep Glow Highlight Extract"
                : "Filmtone Deep Glow Tent Reduction",
            &reducePipeline,
            reduceTextures.data(),
            reduceTextures.size(),
            &reduceBytes,
            1u,
            {scratch.width, scratch.height, 1u},
        };
        if (!invocation.commands.encodeComputePass(reducePass, error)) {
            return false;
        }

        const std::array<host::spatial::SpatialTextureBinding, 2>
            copyTextures{{
                {0u, scratch, host::spatial::SpatialTextureAccess::readOnly},
                {1u, retained, host::spatial::SpatialTextureAccess::writeOnly},
            }};
        const host::spatial::SpatialComputePass copyPass{
            "Filmtone Deep Glow Retain Mip",
            &copyPipeline,
            copyTextures.data(),
            copyTextures.size(),
            nullptr,
            0u,
            {retained.width, retained.height, 1u},
        };
        if (!invocation.commands.encodeComputePass(copyPass, error)) {
            return false;
        }
        retainedGlowMips[level - 1u] = retained;
    }

    const auto energyWeights = makeEnergyWeights(
        parameters_.radius,
        glowLevels);
    const DeepGlowCompositeUniformsV1 compositeUniforms{
        {
            parameters_.strength,
            parameters_.threshold,
            parameters_.softKnee,
            0.0f,
        },
        {
            energyWeights[0],
            energyWeights[1],
            energyWeights[2],
            energyWeights[3],
        },
        {
            energyWeights[4],
            0.0f,
            0.0f,
            0.0f,
        },
        {
            glowLevels,
            alphaAssociation_ == DeepGlowAlphaAssociationV1::premultiplied
                ? 1u
                : 0u,
            invocation.output.width,
            invocation.output.height,
        },
    };

    std::array<host::spatial::SpatialTextureBinding, 7> compositeTextures{};
    compositeTextures[0] = {
        0u,
        invocation.source,
        host::spatial::SpatialTextureAccess::readOnly,
    };
    for (std::uint32_t index = 0u;
         index < kMaximumReducedLevelCount;
         ++index) {
        compositeTextures[index + 1u] = {
            index + 1u,
            retainedGlowMips[index],
            host::spatial::SpatialTextureAccess::readOnly,
        };
    }
    compositeTextures[6] = {
        6u,
        invocation.output,
        host::spatial::SpatialTextureAccess::writeOnly,
    };
    const host::spatial::SpatialBytesBinding compositeBytes{
        0u,
        &compositeUniforms,
        sizeof(compositeUniforms),
    };
    const host::MetalPipelineRequest compositePipeline{
        detail::kDeepGlowCompositeCacheKey,
        detail::kDeepGlowMetalLibrarySource,
        detail::kDeepGlowCompositeFunctionName,
        false,
    };
    const host::spatial::SpatialComputePass compositePass{
        "Filmtone Deep Glow Energy Composite",
        &compositePipeline,
        compositeTextures.data(),
        compositeTextures.size(),
        &compositeBytes,
        1u,
        {invocation.output.width, invocation.output.height, 1u},
    };
    return invocation.commands.encodeComputePass(compositePass, error);
}

}  // namespace filmtone::resolve::effects::deep_glow
