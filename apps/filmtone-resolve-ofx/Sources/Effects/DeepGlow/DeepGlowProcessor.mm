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

// Radius maps logarithmically onto a physical point-spread radius measured as
// a fraction of the render-frame short axis, so proxy and full-resolution
// renders keep the same apparent footprint. Radius 0 is a tight core; Radius
// 1 reaches half the short axis.
constexpr double kDeepGlowMinRadiusFraction = 0.003;
constexpr double kDeepGlowMaxRadiusFraction = 0.5;

// Approximate full-resolution footprint radius of the finest reduce/upsample
// chain; deeper levels double it per octave.
constexpr double kDeepGlowLevelOneRadiusPixels = 2.0;

// Deepest reduction the pyramid may request; UHD short axis needs eleven
// octaves to reach the half-frame maximum radius.
constexpr std::uint32_t kDeepGlowMaxReducedLevelCount = 11u;

// Per-octave persistence of the coarse accumulation during reconstruction.
// 1.0 keeps annular energy constant per dyadic octave, which approximates
// finite-core inverse-square falloff between the finest and deepest
// footprints. This is a design constant, not a hidden user control.
constexpr float kDeepGlowOctavePersistence = 1.0f;

// Strength response: delicate below the low range, clearly strong at the top,
// with no compensating shoulder anywhere downstream.
constexpr double kDeepGlowStrengthLinearBase = 0.30;
constexpr double kDeepGlowStrengthCubicLift = 1.20;

// Mirrors the widened bloomThreshold contract range so above-1.0 HDR sources
// can be selected alone once the generated facade is regenerated. Values from
// the current facade (clamped to 1.0) remain valid.
constexpr float kDeepGlowThresholdMaximum = 4.0f;

struct alignas(16) DeepGlowReduceUniformsV3 final {
    std::array<std::uint32_t, 4> dimensions{};
    std::array<float, 4> selection{};
};

struct alignas(16) DeepGlowSpreadUniformsV3 final {
    std::array<std::uint32_t, 4> dimensions{};
    std::array<float, 4> spread{};
};

struct alignas(16) DeepGlowCompositeUniformsV3 final {
    std::array<float, 4> effect{};
    std::array<std::uint32_t, 4> metadata{};
};

static_assert(sizeof(DeepGlowReduceUniformsV3) == 32u);
static_assert(alignof(DeepGlowReduceUniformsV3) == 16u);
static_assert(sizeof(DeepGlowSpreadUniformsV3) == 32u);
static_assert(alignof(DeepGlowSpreadUniformsV3) == 16u);
static_assert(sizeof(DeepGlowCompositeUniformsV3) == 32u);
static_assert(alignof(DeepGlowCompositeUniformsV3) == 16u);

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

host::spatial::SpatialImagePlane opposite(
    host::spatial::SpatialImagePlane plane) noexcept {
    return plane == host::spatial::SpatialImagePlane::ping
        ? host::spatial::SpatialImagePlane::pong
        : host::spatial::SpatialImagePlane::ping;
}

std::uint32_t representableReducedLevelCount(
    const host::spatial::SpatialFrameDescriptor& frame) noexcept {
    std::uint32_t width = frame.width;
    std::uint32_t height = frame.height;
    std::uint32_t count = 0u;
    while ((width > 1u || height > 1u) &&
           count < kDeepGlowMaxReducedLevelCount) {
        width = std::max<std::uint32_t>(1u, width / 2u);
        height = std::max<std::uint32_t>(1u, height / 2u);
        ++count;
    }
    return count;
}

struct DeepGlowDiffusionShape final {
    std::uint32_t reducedLevelCount = 0u;
    float deepestLevelFade = 1.0f;
};

// Radius selects the actual diffusion depth: the deepest active octave covers
// the mapped pixel radius and fades in fractionally so a Radius sweep changes
// the point spread continuously with no level-count pop.
DeepGlowDiffusionShape makeDiffusionShape(
    float radius,
    const host::spatial::SpatialFrameDescriptor& frame) noexcept {
    const std::uint32_t maximumLevels = representableReducedLevelCount(frame);
    if (maximumLevels == 0u) {
        return DeepGlowDiffusionShape{0u, 1.0f};
    }

    const double shortAxis = static_cast<double>(
        std::min(frame.width, frame.height));
    const double fraction = kDeepGlowMinRadiusFraction * std::pow(
        kDeepGlowMaxRadiusFraction / kDeepGlowMinRadiusFraction,
        static_cast<double>(radius));
    const double pixelRadius = fraction * shortAxis;
    const double levelsReal = std::max(
        1.0,
        1.0 + std::log2(
            std::max(pixelRadius, 1.0e-6) / kDeepGlowLevelOneRadiusPixels));
    if (!std::isfinite(levelsReal)) {
        return DeepGlowDiffusionShape{1u, 1.0f};
    }

    const double clamped = std::min(
        levelsReal,
        static_cast<double>(maximumLevels));
    const double ceiling = std::ceil(clamped);
    const std::uint32_t reducedLevels = std::max<std::uint32_t>(
        1u,
        static_cast<std::uint32_t>(ceiling));
    const double fade = clamped - ceiling + 1.0;
    return DeepGlowDiffusionShape{
        reducedLevels,
        static_cast<float>(std::clamp(fade, 0.0, 1.0)),
    };
}

float makeStrengthGain(float strength) noexcept {
    const double normalized = static_cast<double>(strength);
    return static_cast<float>(
        normalized * (kDeepGlowStrengthLinearBase +
                      kDeepGlowStrengthCubicLift * normalized * normalized));
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
        !std::isfinite(parameters_.threshold) ||
        parameters_.threshold < 0.0f ||
        parameters_.threshold > kDeepGlowThresholdMaximum ||
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

    const DeepGlowDiffusionShape shape = makeDiffusionShape(
        parameters_.radius,
        frame);
    plan.abiVersion = host::spatial::kSpatialModuleAbiVersion;
    plan.passCount = shape.reducedLevelCount == 0u
        ? 1u
        : shape.reducedLevelCount * 2u + 1u;
    plan.mipLevelCount = shape.reducedLevelCount + 1u;
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

    const DeepGlowDiffusionShape shape = makeDiffusionShape(
        parameters_.radius,
        invocation.frame);
    const std::uint32_t glowLevels = shape.reducedLevelCount;
    const std::uint32_t alphaAssociationValue =
        alphaAssociation_ == DeepGlowAlphaAssociationV1::premultiplied
            ? 1u
            : 0u;

    const host::MetalPipelineRequest reducePipeline{
        detail::kDeepGlowReduceCacheKey,
        detail::kDeepGlowMetalLibrarySource,
        detail::kDeepGlowReduceFunctionName,
        false,
    };
    const host::MetalPipelineRequest turnaroundPipeline{
        detail::kDeepGlowTurnaroundCacheKey,
        detail::kDeepGlowMetalLibrarySource,
        detail::kDeepGlowTurnaroundFunctionName,
        false,
    };
    const host::MetalPipelineRequest combinePipeline{
        detail::kDeepGlowUpsampleCombineCacheKey,
        detail::kDeepGlowMetalLibrarySource,
        detail::kDeepGlowUpsampleCombineFunctionName,
        false,
    };
    const host::MetalPipelineRequest compositePipeline{
        detail::kDeepGlowCompositeCacheKey,
        detail::kDeepGlowMetalLibrarySource,
        detail::kDeepGlowCompositeFunctionName,
        false,
    };

    // Downsample chain with fused extraction on the first pass. Passes
    // alternate ping-pong planes (odd levels on the output plane, even levels
    // on the source plane), which satisfies the one-plane read/write ABI rule
    // without any retain-copy pass and leaves every level slot needed by the
    // reconstruction on a provably free plane.
    std::array<host::spatial::SpatialImageView,
               kDeepGlowMaxReducedLevelCount> reducedLevels{};
    host::spatial::SpatialImageView previous = invocation.source;
    for (std::uint32_t level = 1u; level <= glowLevels; ++level) {
        const host::spatial::SpatialImagePlane destinationPlane =
            (level % 2u) == 1u
                ? invocation.output.plane
                : invocation.source.plane;
        host::spatial::SpatialImageView destination{};
        if (!invocation.resources.image(
                destinationPlane,
                level,
                destination,
                error)) {
            return false;
        }

        const DeepGlowReduceUniformsV3 uniforms{
            {
                previous.width,
                previous.height,
                destination.width,
                destination.height,
            },
            {
                parameters_.threshold,
                parameters_.softKnee,
                level == 1u ? 1.0f : 0.0f,
                static_cast<float>(alphaAssociationValue),
            },
        };
        const std::array<host::spatial::SpatialTextureBinding, 2>
            reduceTextures{{
                {0u, previous, host::spatial::SpatialTextureAccess::readOnly},
                {1u, destination,
                 host::spatial::SpatialTextureAccess::writeOnly},
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
            {destination.width, destination.height, 1u},
        };
        if (!invocation.commands.encodeComputePass(reducePass, error)) {
            return false;
        }
        reducedLevels[level - 1u] = destination;
        previous = destination;
    }

    if (glowLevels == 0u) {
        // Frames too small for one reduction extract inline in the composite.
        const DeepGlowCompositeUniformsV3 compositeUniforms{
            {
                makeStrengthGain(parameters_.strength),
                parameters_.threshold,
                parameters_.softKnee,
                0.0f,
            },
            {
                0u,
                alphaAssociationValue,
                invocation.output.width,
                invocation.output.height,
            },
        };
        const std::array<host::spatial::SpatialTextureBinding, 3>
            compositeTextures{{
                {0u, invocation.source,
                 host::spatial::SpatialTextureAccess::readOnly},
                {1u, invocation.source,
                 host::spatial::SpatialTextureAccess::readOnly},
                {2u, invocation.output,
                 host::spatial::SpatialTextureAccess::writeOnly},
            }};
        const host::spatial::SpatialBytesBinding compositeBytes{
            0u,
            &compositeUniforms,
            sizeof(compositeUniforms),
        };
        const host::spatial::SpatialComputePass compositePass{
            "Filmtone Deep Glow Additive Composite",
            &compositePipeline,
            compositeTextures.data(),
            compositeTextures.size(),
            &compositeBytes,
            1u,
            {invocation.output.width, invocation.output.height, 1u},
        };
        return invocation.commands.encodeComputePass(compositePass, error);
    }

    // Deepest-level turnaround: convert the deepest reduction into the
    // unassociated running accumulation on the opposite plane, scaled by the
    // fractional fade, and smooth the truncation scale with one more tent.
    const host::spatial::SpatialImageView deepest =
        reducedLevels[glowLevels - 1u];
    host::spatial::SpatialImageView accumulation{};
    if (!invocation.resources.image(
            opposite(deepest.plane),
            glowLevels,
            accumulation,
            error)) {
        return false;
    }
    const DeepGlowSpreadUniformsV3 turnaroundUniforms{
        {
            deepest.width,
            deepest.height,
            accumulation.width,
            accumulation.height,
        },
        {
            shape.deepestLevelFade,
            static_cast<float>(alphaAssociationValue),
            0.0f,
            0.0f,
        },
    };
    const std::array<host::spatial::SpatialTextureBinding, 2>
        turnaroundTextures{{
            {0u, deepest, host::spatial::SpatialTextureAccess::readOnly},
            {1u, accumulation,
             host::spatial::SpatialTextureAccess::writeOnly},
        }};
    const host::spatial::SpatialBytesBinding turnaroundBytes{
        0u,
        &turnaroundUniforms,
        sizeof(turnaroundUniforms),
    };
    const host::spatial::SpatialComputePass turnaroundPass{
        "Filmtone Deep Glow Tail Turnaround",
        &turnaroundPipeline,
        turnaroundTextures.data(),
        turnaroundTextures.size(),
        &turnaroundBytes,
        1u,
        {accumulation.width, accumulation.height, 1u},
    };
    if (!invocation.commands.encodeComputePass(turnaroundPass, error)) {
        return false;
    }

    // Coarse-to-fine reconstruction. The accumulation and this level's
    // reduction always share one plane by the alternation invariant, and the
    // combined result lands on the opposite plane, finishing on the source
    // plane at level one for the final composite read.
    for (std::uint32_t level = glowLevels - 1u; level >= 1u; --level) {
        const host::spatial::SpatialImageView levelReduction =
            reducedLevels[level - 1u];
        host::spatial::SpatialImageView combined{};
        if (!invocation.resources.image(
                opposite(levelReduction.plane),
                level,
                combined,
                error)) {
            return false;
        }
        const DeepGlowSpreadUniformsV3 combineUniforms{
            {
                accumulation.width,
                accumulation.height,
                combined.width,
                combined.height,
            },
            {
                kDeepGlowOctavePersistence,
                static_cast<float>(alphaAssociationValue),
                0.0f,
                0.0f,
            },
        };
        const std::array<host::spatial::SpatialTextureBinding, 3>
            combineTextures{{
                {0u, accumulation,
                 host::spatial::SpatialTextureAccess::readOnly},
                {1u, levelReduction,
                 host::spatial::SpatialTextureAccess::readOnly},
                {2u, combined,
                 host::spatial::SpatialTextureAccess::writeOnly},
            }};
        const host::spatial::SpatialBytesBinding combineBytes{
            0u,
            &combineUniforms,
            sizeof(combineUniforms),
        };
        const host::spatial::SpatialComputePass combinePass{
            "Filmtone Deep Glow Upsample Combine",
            &combinePipeline,
            combineTextures.data(),
            combineTextures.size(),
            &combineBytes,
            1u,
            {combined.width, combined.height, 1u},
        };
        if (!invocation.commands.encodeComputePass(combinePass, error)) {
            return false;
        }
        accumulation = combined;
    }

    const DeepGlowCompositeUniformsV3 compositeUniforms{
        {
            makeStrengthGain(parameters_.strength),
            parameters_.threshold,
            parameters_.softKnee,
            0.0f,
        },
        {
            1u,
            alphaAssociationValue,
            invocation.output.width,
            invocation.output.height,
        },
    };
    const std::array<host::spatial::SpatialTextureBinding, 3>
        compositeTextures{{
            {0u, invocation.source,
             host::spatial::SpatialTextureAccess::readOnly},
            {1u, accumulation,
             host::spatial::SpatialTextureAccess::readOnly},
            {2u, invocation.output,
             host::spatial::SpatialTextureAccess::writeOnly},
        }};
    const host::spatial::SpatialBytesBinding compositeBytes{
        0u,
        &compositeUniforms,
        sizeof(compositeUniforms),
    };
    const host::spatial::SpatialComputePass compositePass{
        "Filmtone Deep Glow Additive Composite",
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
