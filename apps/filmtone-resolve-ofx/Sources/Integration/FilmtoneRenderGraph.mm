#import <Metal/Metal.h>

#include "FilmtoneRenderGraph.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>
#include <vector>

#include "../Effects/DeepGlow/DeepGlowProcessor.h"
#include "../Effects/FilmBreath/FilmBreathProcessor.h"
#include "../Effects/FilmDamage/FilmDamageProcessor.h"
#include "../Effects/GateWeave/GateWeaveProcessor.h"
#include "../Effects/LensSoftness/LensSoftnessProcessor.h"
#include "../Effects/PeripheralChromaticShift/PeripheralChromaticShiftProcessor.h"
#include "../Effects/TextureSoftness/TextureSoftnessProcessor.h"
#include "../Effects/Vignette/VignetteProcessor.h"
#include "../Host/MetalIdentityBlit.h"
#include "../Host/Spatial/SpatialMetalHost.h"
#include "../License/LicenseStore.h"
#include "../License/WatermarkPass.h"

namespace filmtone::resolve::integration {
namespace {

constexpr std::size_t kFloatRGBABytesPerPixel = sizeof(float) * 4u;
constexpr std::size_t kMaximumTemporalIntermediates = 2u;

enum class FilmModuleKind {
    filmBreath,
    gateWeave,
    filmDamage,
};

struct ActiveFilmModule final {
    FilmModuleKind kind = FilmModuleKind::filmBreath;
    const host::ModuleProcessor* processor = nullptr;
};

bool rectsEqual(const host::RectI& left, const host::RectI& right) noexcept {
    return left.x1 == right.x1 && left.y1 == right.y1 &&
           left.x2 == right.x2 && left.y2 == right.y2;
}

bool isPositiveFinite(double value) noexcept {
    return std::isfinite(value) && value > 0.0;
}

bool checkedMultiply(
    std::size_t left,
    std::size_t right,
    std::size_t& result) noexcept {
    if (left != 0u && right > std::numeric_limits<std::size_t>::max() / left) {
        return false;
    }
    result = left * right;
    return true;
}

bool checkedAdd(
    std::size_t left,
    std::size_t right,
    std::size_t& result) noexcept {
    if (right > std::numeric_limits<std::size_t>::max() - left) {
        return false;
    }
    result = left + right;
    return true;
}

const host::RectI* selectFullBounds(
    const host::RenderContext& context) noexcept {
    if (context.sourceBounds.has_value() &&
        !context.sourceBounds->isEmpty()) {
        return &*context.sourceBounds;
    }
    if (context.outputBounds.has_value() &&
        !context.outputBounds->isEmpty()) {
        return &*context.outputBounds;
    }
    if (!context.renderWindow.isEmpty()) {
        return &context.renderWindow;
    }
    return nullptr;
}

host::RenderContext makeSeededContext(
    const EvaluatedFilmtoneParameters& parameters,
    const host::RenderContext& context) noexcept {
    const std::uint64_t seed = context.explicitSeed.has_value()
        ? *context.explicitSeed
        : static_cast<std::uint64_t>(parameters.finish().variation);
    return host::RenderContext{
        context.time,
        context.frameRates,
        seed,
        context.renderScale,
        context.renderWindow,
        context.sourceBounds,
        context.outputBounds,
    };
}

host::RenderContext makeConfigurationOnlyContext(
    const EvaluatedFilmtoneParameters& parameters) noexcept {
    return host::RenderContext{
        0.0,
        host::FrameRates{0.0, 0.0},
        static_cast<std::uint64_t>(parameters.finish().variation),
        host::PointD{0.0, 0.0},
        host::RectI{0, 0, 0, 0},
        std::nullopt,
        std::nullopt,
    };
}

std::optional<contracts::ResolveRenderContextV1> makeDamageRenderContext(
    const host::RenderContext& context) noexcept {
    const host::RectI* bounds = selectFullBounds(context);
    if (bounds == nullptr ||
        !isPositiveFinite(context.frameRates.timeline) ||
        !isPositiveFinite(context.renderScale.x) ||
        !isPositiveFinite(context.renderScale.y)) {
        return std::nullopt;
    }

    forestone::visual_render::DeterministicRenderContextV1 deterministic{};
    deterministic.renderScaleX = static_cast<float>(context.renderScale.x);
    deterministic.renderScaleY = static_cast<float>(context.renderScale.y);
    deterministic.boundsX = static_cast<float>(
        static_cast<double>(bounds->x1) / context.renderScale.x);
    deterministic.boundsY = static_cast<float>(
        static_cast<double>(bounds->y1) / context.renderScale.y);
    deterministic.boundsWidth = static_cast<float>(
        static_cast<double>(bounds->width()) / context.renderScale.x);
    deterministic.boundsHeight = static_cast<float>(
        static_cast<double>(bounds->height()) / context.renderScale.y);
    deterministic.seed = context.explicitSeed.has_value()
        ? static_cast<std::uint32_t>(
              *context.explicitSeed & std::uint64_t{0xffffffffu})
        : 0u;
    return contracts::makeResolveRenderContextV1(
        context.time,
        context.frameRates.timeline,
        deterministic);
}

bool filmModulesIdentity(
    const EvaluatedFilmtoneParameters& parameters,
    const host::RenderContext& context) noexcept {
    const auto mapping = forestone::filmtone::mapFilmtoneFinish(
        parameters.finish());
    effects::film_breath::FilmBreathProcessor filmBreath(
        parameters.filmBreath);
    gate_weave::GateWeaveProcessor gateWeave(mapping);
    forestone::visual_render::FilmDamageRenderUniformsV1 damageUniforms{};
    damageUniforms.recipe = mapping.filmDamageRecipe;
    damage::FilmDamageProcessor filmDamage(damageUniforms);
    return filmBreath.isIdentity(context) &&
           gateWeave.isIdentity(context) &&
           filmDamage.isIdentity(context);
}

bool roleSchedulesActiveSpatial(
    const EvaluatedFilmtoneParameters& parameters) noexcept {
    return spatial::roleSchedulesSpatialV1(parameters.spatial.nodeRole) &&
           !spatial::isSpatialConfiguredIdentityV1(parameters.spatial);
}

class OwnedIntermediateBuffers final {
public:
    OwnedIntermediateBuffers() = default;

    ~OwnedIntermediateBuffers() {
        for (id<MTLBuffer> buffer : buffers_) {
            [buffer release];
        }
    }

    OwnedIntermediateBuffers(const OwnedIntermediateBuffers&) = delete;
    OwnedIntermediateBuffers& operator=(const OwnedIntermediateBuffers&) = delete;

    bool allocate(
        void* commandQueue,
        const std::vector<host::RectI>& requestedBounds,
        std::string& error) {
        if (requestedBounds.empty()) {
            return true;
        }
        if (requestedBounds.size() > kMaximumTemporalIntermediates) {
            error = "Filmtone temporal graph exceeds its two-intermediate ceiling.";
            return false;
        }
        if (commandQueue == nullptr) {
            error = "Filmtone cannot allocate an intermediate without a Metal queue.";
            return false;
        }

        id<MTLCommandQueue> queue =
            static_cast<id<MTLCommandQueue>>(commandQueue);
        if (queue == nil || queue.device == nil) {
            error = "Filmtone received an invalid Metal queue for its pass graph.";
            return false;
        }

        buffers_.reserve(requestedBounds.size());
        views_.reserve(requestedBounds.size());
        for (const host::RectI& bounds : requestedBounds) {
            if (bounds.isEmpty()) {
                error = "Filmtone received empty full bounds for an intermediate.";
                return false;
            }
            const std::size_t width = static_cast<std::size_t>(bounds.width());
            const std::size_t height = static_cast<std::size_t>(bounds.height());
            std::size_t rowBytes = 0u;
            std::size_t length = 0u;
            if (!checkedMultiply(
                    width,
                    kFloatRGBABytesPerPixel,
                    rowBytes) ||
                rowBytes > static_cast<std::size_t>(
                               std::numeric_limits<std::ptrdiff_t>::max()) ||
                !checkedMultiply(rowBytes, height, length)) {
                error = "Filmtone intermediate size is not representable.";
                return false;
            }
            std::size_t nextTightBytes = 0u;
            if (!checkedAdd(tightBytes_, length, nextTightBytes)) {
                error = "Filmtone intermediate reservation is not representable.";
                return false;
            }

            id<MTLBuffer> buffer = [queue.device
                newBufferWithLength:length
                             options:MTLResourceStorageModePrivate];
            if (buffer == nil) {
                error = "Filmtone could not allocate a bounded Metal intermediate.";
                return false;
            }
            buffer.label = @"Filmtone Temporal Ping-Pong Intermediate";
            buffers_.push_back(buffer);
            views_.push_back(host::MetalImageView{
                static_cast<void*>(buffer),
                static_cast<std::ptrdiff_t>(rowBytes),
                bounds,
                host::PixelFormat::floatRGBA,
            });
            tightBytes_ = nextTightBytes;
        }
        // All processors commit on one Host queue. Metal command buffers
        // retain referenced resources, and queue ordering makes sequential
        // ping-pong reuse safe without a wait or readback.
        return true;
    }

    [[nodiscard]] const host::MetalImageView& view(
        std::size_t index) const noexcept {
        return views_[index];
    }

    [[nodiscard]] std::size_t tightBytes() const noexcept {
        return tightBytes_;
    }

private:
    std::vector<id<MTLBuffer>> buffers_;
    std::vector<host::MetalImageView> views_;
    std::size_t tightBytes_ = 0u;
};

bool validateTemporalLayout(
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    const std::array<ActiveFilmModule, 3>& active,
    std::size_t activeCount,
    bool followsSpatial,
    std::string& error) {
    if (context.sourceBounds.has_value() &&
        !rectsEqual(*context.sourceBounds, invocation.source.bounds)) {
        error = "Filmtone source bounds disagree with the shared render context.";
        return false;
    }
    if (context.outputBounds.has_value() &&
        !rectsEqual(*context.outputBounds, invocation.output.bounds)) {
        error = "Filmtone output bounds disagree with the shared render context.";
        return false;
    }

    for (std::size_t index = 0u; index < activeCount; ++index) {
        const bool hasPriorStage = followsSpatial || index != 0u;
        if (hasPriorStage && active[index].kind == FilmModuleKind::gateWeave &&
            !rectsEqual(context.renderWindow, invocation.source.bounds)) {
            error = "Filmtone requires a full-bounds Host render when Gate Weave follows another active stage.";
            return false;
        }
    }
    return true;
}

bool makeDeepGlowAlphaAssociation(
    SourceAlphaAssociation association,
    effects::deep_glow::DeepGlowAlphaAssociationV1& result,
    std::string& error) {
    switch (association) {
        case SourceAlphaAssociation::unassociatedOrOpaque:
            result = effects::deep_glow::DeepGlowAlphaAssociationV1::
                unassociatedOrOpaque;
            return true;
        case SourceAlphaAssociation::premultiplied:
            result = effects::deep_glow::DeepGlowAlphaAssociationV1::
                premultiplied;
            return true;
    }
    error = "Filmtone received an unsupported OFX alpha association.";
    return false;
}

}  // namespace

bool requiresFilmtoneTemporalFrameRate(
    const EvaluatedFilmtoneParameters& parameters) noexcept {
    if (!spatial::roleSchedulesFilmModulesV1(parameters.spatial.nodeRole)) {
        return false;
    }
    return !filmModulesIdentity(
        parameters,
        makeConfigurationOnlyContext(parameters));
}

bool isFilmtoneConfiguredIdentity(
    const EvaluatedFilmtoneParameters& parameters) noexcept {
    const bool spatialIdentity =
        !spatial::roleSchedulesSpatialV1(parameters.spatial.nodeRole) ||
        spatial::isSpatialConfiguredIdentityV1(parameters.spatial);
    const bool filmIdentity =
        !spatial::roleSchedulesFilmModulesV1(parameters.spatial.nodeRole) ||
        filmModulesIdentity(
            parameters,
            makeConfigurationOnlyContext(parameters));
    return spatialIdentity && filmIdentity;
}

bool isFilmtoneIdentity(
    const EvaluatedFilmtoneParameters& parameters,
    const host::RenderContext& context) noexcept {
    const host::RenderContext seededContext = makeSeededContext(parameters, context);
    const bool spatialIdentity =
        !spatial::roleSchedulesSpatialV1(parameters.spatial.nodeRole) ||
        spatial::isSpatialConfiguredIdentityV1(parameters.spatial);
    const bool filmIdentity =
        !spatial::roleSchedulesFilmModulesV1(parameters.spatial.nodeRole) ||
        filmModulesIdentity(parameters, seededContext);
    return spatialIdentity && filmIdentity;
}

static bool encodeFilmtoneModulesGraph(
    const EvaluatedFilmtoneParameters& parameters,
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    double pixelAspectRatio,
    SourceAlphaAssociation alphaAssociation,
    host::MetalPipelineCache& pipelineCache,
    std::string& error) {
    error.clear();
    const host::RenderContext seededContext = makeSeededContext(parameters, context);
    if (seededContext.renderWindow.isEmpty()) {
        return true;
    }

    const bool spatialActive = roleSchedulesActiveSpatial(parameters);
    const bool schedulesFilmModules =
        spatial::roleSchedulesFilmModulesV1(parameters.spatial.nodeRole);
    const auto mapping = forestone::filmtone::mapFilmtoneFinish(
        parameters.finish());
    effects::film_breath::FilmBreathProcessor filmBreath(
        parameters.filmBreath);
    gate_weave::GateWeaveProcessor gateWeave(mapping);

    forestone::visual_render::FilmDamageRenderUniformsV1 identityUniforms{};
    identityUniforms.recipe = mapping.filmDamageRecipe;
    damage::FilmDamageProcessor filmDamageIdentityProbe(identityUniforms);

    const bool filmBreathActive = schedulesFilmModules &&
        !filmBreath.isIdentity(seededContext);
    const bool gateWeaveActive = schedulesFilmModules &&
        !gateWeave.isIdentity(seededContext);
    const bool filmDamageActive = schedulesFilmModules &&
        !filmDamageIdentityProbe.isIdentity(seededContext);

    std::optional<damage::FilmDamageProcessor> filmDamage;
    if (filmDamageActive) {
        const auto damageContext = makeDamageRenderContext(seededContext);
        if (!damageContext.has_value()) {
            error = "Filmtone could not resolve Film Damage time, frame rate, scale, seed, and bounds.";
            return false;
        }
        filmDamage.emplace(mapping, *damageContext);
    }

    std::array<ActiveFilmModule, 3> activeFilm{};
    std::size_t activeFilmCount = 0u;
    if (filmBreathActive) {
        activeFilm[activeFilmCount++] = ActiveFilmModule{
            FilmModuleKind::filmBreath,
            &filmBreath,
        };
    }
    if (gateWeaveActive) {
        activeFilm[activeFilmCount++] = ActiveFilmModule{
            FilmModuleKind::gateWeave,
            &gateWeave,
        };
    }
    if (filmDamageActive) {
        activeFilm[activeFilmCount++] = ActiveFilmModule{
            FilmModuleKind::filmDamage,
            &*filmDamage,
        };
    }

    if (!spatialActive && activeFilmCount == 0u) {
        return host::encodeMetalIdentityBlit(seededContext, invocation, error);
    }
    if (!validateTemporalLayout(
            seededContext,
            invocation,
            activeFilm,
            activeFilmCount,
            spatialActive,
            error)) {
        return false;
    }

    std::vector<host::RectI> intermediateBounds;
    const bool loneAliasedGateWeave = !spatialActive &&
        activeFilmCount == 1u &&
        activeFilm[0].kind == FilmModuleKind::gateWeave &&
        invocation.source.buffer == invocation.output.buffer;
    if (spatialActive && activeFilmCount != 0u) {
        if (!rectsEqual(invocation.source.bounds, invocation.output.bounds)) {
            error = "Filmtone Spatial ABI v1 requires identical source and output bounds.";
            return false;
        }
        const std::size_t intermediateCount = std::min<std::size_t>(
            kMaximumTemporalIntermediates,
            activeFilmCount);
        intermediateBounds.reserve(intermediateCount);
        for (std::size_t index = 0u;
             index < intermediateCount;
             ++index) {
            intermediateBounds.push_back(invocation.source.bounds);
        }
    } else if (loneAliasedGateWeave) {
        intermediateBounds.push_back(invocation.output.bounds);
    } else if (activeFilmCount > 1u) {
        intermediateBounds.reserve(activeFilmCount - 1u);
        for (std::size_t index = 0u;
             index + 1u < activeFilmCount;
             ++index) {
            const bool gateWeaveReadsThisBuffer =
                activeFilm[index + 1u].kind == FilmModuleKind::gateWeave;
            intermediateBounds.push_back(
                gateWeaveReadsThisBuffer
                    ? invocation.source.bounds
                    : invocation.output.bounds);
        }
    }

    OwnedIntermediateBuffers intermediates;
    if (!intermediates.allocate(
            invocation.commandQueue,
            intermediateBounds,
            error)) {
        return false;
    }

    const host::MetalImageView* temporalSource = &invocation.source;
    if (spatialActive) {
        effects::deep_glow::DeepGlowAlphaAssociationV1 deepGlowAlpha{};
        if (!makeDeepGlowAlphaAssociation(
                alphaAssociation,
                deepGlowAlpha,
                error)) {
            return false;
        }

        texture_softness::TextureSoftnessProcessor textureSoftness(
            spatial::makeTextureSoftnessParameterViewV1(parameters.spatial));
        effects::peripheral_chromatic_shift::PeripheralChromaticShiftProcessor
            peripheralChromaticShift(parameters.spatial);
        effects::lens_softness::LensSoftnessProcessor lensSoftness(
            parameters.spatial);
        effects::deep_glow::DeepGlowProcessor deepGlow(
            spatial::makeDeepGlowParameterViewV1(parameters.spatial),
            deepGlowAlpha);
        effects::vignette::VignetteProcessor vignette(
            spatial::makeVignetteParameterViewV1(parameters.spatial));
        const std::array<const host::spatial::SpatialModuleProcessor*, 5u>
            spatialModules{{
                &textureSoftness,
                &peripheralChromaticShift,
                &lensSoftness,
                &deepGlow,
                &vignette,
            }};

        const host::MetalImageView& spatialOutput = activeFilmCount == 0u
            ? invocation.output
            : intermediates.view(0u);
        const host::MetalRenderInvocation spatialInvocation{
            invocation.commandQueue,
            invocation.source,
            spatialOutput,
        };
        host::spatial::SpatialExecutionReport spatialReport{};
        if (!host::spatial::encodeSpatialMetalSequence(
                seededContext,
                spatialInvocation,
                pixelAspectRatio,
                intermediates.tightBytes(),
                spatialModules.data(),
                spatialModules.size(),
                pipelineCache,
                spatialReport,
                error)) {
            return false;
        }
        if (spatialReport.outcome !=
            host::spatial::SpatialExecutionOutcome::encoded) {
            error = "Filmtone active spatial graph returned without encoding.";
            return false;
        }
        if (activeFilmCount == 0u) {
            return true;
        }
        temporalSource = &intermediates.view(0u);
    }

    for (std::size_t index = 0u; index < activeFilmCount; ++index) {
        const bool isFinalFilmPass = index + 1u == activeFilmCount;
        const host::MetalImageView* temporalOutput = nullptr;
        if (loneAliasedGateWeave) {
            temporalOutput = &intermediates.view(0u);
        } else if (isFinalFilmPass) {
            temporalOutput = &invocation.output;
        } else if (spatialActive) {
            temporalOutput = &intermediates.view((index + 1u) % 2u);
        } else {
            temporalOutput = &intermediates.view(index);
        }

        const host::MetalRenderInvocation filmInvocation{
            invocation.commandQueue,
            *temporalSource,
            *temporalOutput,
        };
        if (!activeFilm[index].processor->encodeMetal(
                seededContext,
                filmInvocation,
                pipelineCache,
                error)) {
            return false;
        }
        temporalSource = temporalOutput;
    }

    if (loneAliasedGateWeave) {
        const host::MetalRenderInvocation copyInvocation{
            invocation.commandQueue,
            *temporalSource,
            invocation.output,
        };
        return host::encodeMetalIdentityBlit(
            seededContext,
            copyInvocation,
            error);
    }
    return true;
}

bool encodeFilmtoneMetal(
    const EvaluatedFilmtoneParameters& parameters,
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    double pixelAspectRatio,
    SourceAlphaAssociation alphaAssociation,
    host::MetalPipelineCache& pipelineCache,
    std::string& error) {
    if (!encodeFilmtoneModulesGraph(
            parameters,
            context,
            invocation,
            pixelAspectRatio,
            alphaAssociation,
            pipelineCache,
            error)) {
        return false;
    }
    // License gate: composite the trial watermark on the final output whenever
    // the state is not a valid full/active-trial license. A valid license leaves
    // the module output bit-exact (identity invariant preserved).
    if (!license::LicenseStore::shared().evaluate().watermarked()) {
        return true;
    }
    const host::RenderContext seededContext =
        makeSeededContext(parameters, context);
    if (seededContext.renderWindow.isEmpty()) {
        return true;
    }
    return watermark::encodeMetalTrialWatermark(
        seededContext, invocation, pipelineCache, error);
}

}  // namespace filmtone::resolve::integration
