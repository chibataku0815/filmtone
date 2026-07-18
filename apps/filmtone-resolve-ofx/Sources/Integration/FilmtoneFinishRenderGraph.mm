#import <Metal/Metal.h>

#include "FilmtoneFinishRenderGraph.h"

#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>
#include <vector>

#include "../Effects/FilmBreath/FilmBreathProcessor.h"
#include "../Effects/FilmDamage/FilmDamageProcessor.h"
#include "../Effects/GateWeave/GateWeaveProcessor.h"
#include "../Host/MetalIdentityBlit.h"

namespace filmtone::resolve::integration {
namespace {

constexpr std::size_t kFloatRGBABytesPerPixel = sizeof(float) * 4u;

enum class ModuleKind {
    filmBreath,
    gateWeave,
    filmDamage,
};

struct ActiveModule final {
    ModuleKind kind = ModuleKind::filmBreath;
    const host::ModuleProcessor* processor = nullptr;
};

bool rectsEqual(const host::RectI& left, const host::RectI& right) noexcept {
    return left.x1 == right.x1 && left.y1 == right.y1 &&
           left.x2 == right.x2 && left.y2 == right.y2;
}

bool isPositiveFinite(double value) noexcept {
    return std::isfinite(value) && value > 0.0;
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
    const EvaluatedFilmtoneFinishParameters& parameters,
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
        if (commandQueue == nullptr) {
            error = "Filmtone Finish cannot allocate an intermediate without a Metal queue.";
            return false;
        }

        id<MTLCommandQueue> queue =
            static_cast<id<MTLCommandQueue>>(commandQueue);
        if (queue == nil || queue.device == nil) {
            error = "Filmtone Finish received an invalid Metal command queue for its pass graph.";
            return false;
        }

        buffers_.reserve(requestedBounds.size());
        views_.reserve(requestedBounds.size());
        for (const host::RectI& bounds : requestedBounds) {
            if (bounds.isEmpty()) {
                error = "Filmtone Finish received empty full bounds for an active-pass intermediate.";
                return false;
            }
            const std::size_t width =
                static_cast<std::size_t>(bounds.width());
            const std::size_t height =
                static_cast<std::size_t>(bounds.height());
            if (width > std::numeric_limits<std::size_t>::max() /
                            kFloatRGBABytesPerPixel) {
                error = "Filmtone Finish intermediate row size is not representable.";
                return false;
            }
            const std::size_t rowBytes = width * kFloatRGBABytesPerPixel;
            if (rowBytes > static_cast<std::size_t>(
                               std::numeric_limits<std::ptrdiff_t>::max()) ||
                (height != 0u &&
                 rowBytes > std::numeric_limits<std::size_t>::max() /
                                height)) {
                error = "Filmtone Finish intermediate buffer size is not representable.";
                return false;
            }
            const std::size_t length = rowBytes * height;
            id<MTLBuffer> buffer = [queue.device
                newBufferWithLength:length
                             options:MTLResourceStorageModePrivate];
            if (buffer == nil) {
                error = "Filmtone Finish could not allocate an active-pass Metal intermediate.";
                return false;
            }
            buffer.label = @"Filmtone Finish Active Pass Intermediate";
            buffers_.push_back(buffer);
            views_.push_back(host::MetalImageView{
                static_cast<void*>(buffer),
                static_cast<std::ptrdiff_t>(rowBytes),
                bounds,
                host::PixelFormat::floatRGBA,
            });
        }
        // Each accepted processor commits on the same queue. Metal command
        // buffers retain their referenced resources until execution finishes,
        // so this owner's +1 references may be released at scope exit.
        return true;
    }

    [[nodiscard]] const host::MetalImageView& view(
        std::size_t index) const noexcept {
        return views_[index];
    }

private:
    std::vector<id<MTLBuffer>> buffers_;
    std::vector<host::MetalImageView> views_;
};

bool validateMultiPassLayout(
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    const std::array<ActiveModule, 3>& active,
    std::size_t activeCount,
    std::string& error) {
    if (context.sourceBounds.has_value() &&
        !rectsEqual(*context.sourceBounds, invocation.source.bounds)) {
        error = "Filmtone Finish source bounds disagree with the shared render context.";
        return false;
    }
    if (context.outputBounds.has_value() &&
        !rectsEqual(*context.outputBounds, invocation.output.bounds)) {
        error = "Filmtone Finish output bounds disagree with the shared render context.";
        return false;
    }

    for (std::size_t index = 1u; index < activeCount; ++index) {
        if (active[index].kind == ModuleKind::gateWeave &&
            !rectsEqual(context.renderWindow, invocation.source.bounds)) {
            error = "Filmtone Finish requires a full-bounds host render when Gate Weave follows another active module.";
            return false;
        }
    }
    return true;
}

}  // namespace

bool isFilmtoneFinishConfiguredIdentity(
    const EvaluatedFilmtoneFinishParameters& parameters) noexcept {
    const auto mapping = forestone::filmtone::mapFilmtoneFinish(
        parameters.finish());
    const host::RenderContext configurationOnlyContext{
        0.0,
        host::FrameRates{0.0, 0.0},
        static_cast<std::uint64_t>(parameters.finish().variation),
        host::PointD{0.0, 0.0},
        host::RectI{0, 0, 0, 0},
        std::nullopt,
        std::nullopt,
    };

    // Film Breath returns identity before consulting time/fps only when its
    // mapped amount or every accepted local response is zero. Gate Weave and
    // Film Damage configuration identity is already context-independent.
    effects::film_breath::FilmBreathProcessor filmBreath(
        parameters.filmBreath);
    gate_weave::GateWeaveProcessor gateWeave(mapping);
    forestone::visual_render::FilmDamageRenderUniformsV1 identityUniforms{};
    identityUniforms.recipe = mapping.filmDamageRecipe;
    damage::FilmDamageProcessor filmDamage(identityUniforms);

    return filmBreath.isIdentity(configurationOnlyContext) &&
           gateWeave.isIdentity(configurationOnlyContext) &&
           filmDamage.isIdentity(configurationOnlyContext);
}

bool isFilmtoneFinishIdentity(
    const EvaluatedFilmtoneFinishParameters& parameters,
    const host::RenderContext& context) noexcept {
    const host::RenderContext seededContext = makeSeededContext(parameters, context);
    const auto mapping = forestone::filmtone::mapFilmtoneFinish(
        parameters.finish());

    effects::film_breath::FilmBreathProcessor filmBreath(
        parameters.filmBreath);
    gate_weave::GateWeaveProcessor gateWeave(mapping);
    forestone::visual_render::FilmDamageRenderUniformsV1 identityUniforms{};
    identityUniforms.recipe = mapping.filmDamageRecipe;
    damage::FilmDamageProcessor filmDamage(identityUniforms);

    return filmBreath.isIdentity(seededContext) &&
           gateWeave.isIdentity(seededContext) &&
           filmDamage.isIdentity(seededContext);
}

bool encodeFilmtoneFinishMetal(
    const EvaluatedFilmtoneFinishParameters& parameters,
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    host::MetalPipelineCache& pipelineCache,
    std::string& error) {
    error.clear();
    const host::RenderContext seededContext = makeSeededContext(parameters, context);
    if (seededContext.renderWindow.isEmpty()) {
        return true;
    }

    const auto mapping = forestone::filmtone::mapFilmtoneFinish(
        parameters.finish());
    effects::film_breath::FilmBreathProcessor filmBreath(
        parameters.filmBreath);
    gate_weave::GateWeaveProcessor gateWeave(mapping);

    forestone::visual_render::FilmDamageRenderUniformsV1 identityUniforms{};
    identityUniforms.recipe = mapping.filmDamageRecipe;
    damage::FilmDamageProcessor filmDamageIdentityProbe(identityUniforms);

    const bool filmBreathActive = !filmBreath.isIdentity(seededContext);
    const bool gateWeaveActive = !gateWeave.isIdentity(seededContext);
    const bool filmDamageActive =
        !filmDamageIdentityProbe.isIdentity(seededContext);

    std::optional<damage::FilmDamageProcessor> filmDamage;
    if (filmDamageActive) {
        const auto damageContext = makeDamageRenderContext(seededContext);
        if (!damageContext.has_value()) {
            error = "Filmtone Finish could not resolve Film Damage time, frame rate, scale, seed, and bounds.";
            return false;
        }
        filmDamage.emplace(mapping, *damageContext);
    }

    std::array<ActiveModule, 3> active{};
    std::size_t activeCount = 0u;
    if (filmBreathActive) {
        active[activeCount++] = ActiveModule{
            ModuleKind::filmBreath,
            &filmBreath,
        };
    }
    if (gateWeaveActive) {
        active[activeCount++] = ActiveModule{
            ModuleKind::gateWeave,
            &gateWeave,
        };
    }
    if (filmDamageActive) {
        active[activeCount++] = ActiveModule{
            ModuleKind::filmDamage,
            &*filmDamage,
        };
    }

    if (activeCount == 0u) {
        return host::encodeMetalIdentityBlit(seededContext, invocation, error);
    }
    if (activeCount == 1u) {
        const bool gateWeaveNeedsDistinctOutput =
            active[0].kind == ModuleKind::gateWeave &&
            invocation.source.buffer == invocation.output.buffer;
        if (gateWeaveNeedsDistinctOutput) {
            OwnedIntermediateBuffers gateWeaveOutput;
            std::vector<host::RectI> outputBounds;
            outputBounds.push_back(invocation.output.bounds);
            if (!gateWeaveOutput.allocate(
                    invocation.commandQueue,
                    outputBounds,
                    error)) {
                return false;
            }

            const host::MetalRenderInvocation warpInvocation{
                invocation.commandQueue,
                invocation.source,
                gateWeaveOutput.view(0u),
            };
            if (!active[0].processor->encodeMetal(
                    seededContext,
                    warpInvocation,
                    pipelineCache,
                    error)) {
                return false;
            }

            // Gate Weave and the exact windowed copy commit in this order on
            // the same queue. The source is therefore fully sampled before
            // the aliased Host output is overwritten.
            const host::MetalRenderInvocation copyInvocation{
                invocation.commandQueue,
                gateWeaveOutput.view(0u),
                invocation.output,
            };
            return host::encodeMetalIdentityBlit(
                seededContext,
                copyInvocation,
                error);
        }
        return active[0].processor->encodeMetal(
            seededContext,
            invocation,
            pipelineCache,
            error);
    }
    if (!validateMultiPassLayout(
            seededContext,
            invocation,
            active,
            activeCount,
            error)) {
        return false;
    }

    OwnedIntermediateBuffers intermediates;
    std::vector<host::RectI> intermediateBounds;
    intermediateBounds.reserve(activeCount - 1u);
    for (std::size_t index = 0u; index + 1u < activeCount; ++index) {
        const bool gateWeaveReadsThisBuffer =
            active[index + 1u].kind == ModuleKind::gateWeave;
        intermediateBounds.push_back(
            gateWeaveReadsThisBuffer
                ? invocation.source.bounds
                : invocation.output.bounds);
    }
    if (!intermediates.allocate(
            invocation.commandQueue,
            intermediateBounds,
            error)) {
        return false;
    }

    const host::MetalImageView* currentSource = &invocation.source;
    for (std::size_t index = 0u; index < activeCount; ++index) {
        const bool isFinalPass = index + 1u == activeCount;
        const host::MetalImageView* currentOutput = isFinalPass
            ? &invocation.output
            : &intermediates.view(index);
        const host::MetalRenderInvocation passInvocation{
            invocation.commandQueue,
            *currentSource,
            *currentOutput,
        };
        if (!active[index].processor->encodeMetal(
                seededContext,
                passInvocation,
                pipelineCache,
                error)) {
            return false;
        }
        currentSource = currentOutput;
    }
    return true;
}

}  // namespace filmtone::resolve::integration
