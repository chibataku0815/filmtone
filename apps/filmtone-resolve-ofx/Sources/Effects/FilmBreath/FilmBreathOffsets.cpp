#include "FilmBreathOffsets.h"

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace filmtone::resolve::effects::film_breath {
namespace {

struct NormalizedFilmBreathResponses final {
    double exposureResponse;
    double tonalResponse;
    double colorResponse;
};

double clampFinite(
    double value,
    double minimum,
    double maximum,
    double fallback) noexcept {
    if (!std::isfinite(value)) {
        return fallback;
    }
    return std::clamp(value, minimum, maximum);
}

NormalizedFilmBreathResponses normalizeResponses(
    const FilmBreathParameters& parameters) noexcept {
    return NormalizedFilmBreathResponses{
        clampFinite(parameters.exposureResponse, 0.0, 1.0, 1.0),
        clampFinite(parameters.tonalResponse, 0.0, 1.0, 1.0),
        clampFinite(parameters.colorResponse, 0.0, 1.0, 1.0),
    };
}

bool hasPositiveExtent(const host::RectI& bounds) noexcept {
    return bounds.x2 > bounds.x1 && bounds.y2 > bounds.y1;
}

const host::RectI* selectBounds(const host::RenderContext& context) noexcept {
    if (context.sourceBounds.has_value() &&
        hasPositiveExtent(*context.sourceBounds)) {
        return &*context.sourceBounds;
    }
    if (context.outputBounds.has_value() &&
        hasPositiveExtent(*context.outputBounds)) {
        return &*context.outputBounds;
    }
    if (hasPositiveExtent(context.renderWindow)) {
        return &context.renderWindow;
    }
    return nullptr;
}

double resolveFrameRate(const host::FrameRates& frameRates) noexcept {
    if (std::isfinite(frameRates.timeline) && frameRates.timeline > 0.0) {
        return frameRates.timeline;
    }
    if (std::isfinite(frameRates.source) && frameRates.source > 0.0) {
        return frameRates.source;
    }
    return 0.0;
}

std::uint32_t resolveSeed(
    const host::RenderContext& context,
    std::uint32_t variation) noexcept {
    if (!context.explicitSeed.has_value()) {
        return variation;
    }
    return static_cast<std::uint32_t>(
        *context.explicitSeed & std::uint64_t{0xffffffffu});
}

}  // namespace

std::optional<FilmBreathOffsets> resolveFilmBreathOffsets(
    const FilmBreathParameters& parameters,
    const host::RenderContext& context) noexcept {
    const auto mapping = forestone::filmtone::mapFilmtoneFinish(
        parameters.finishParameters);
    const NormalizedFilmBreathResponses responses =
        normalizeResponses(parameters);
    if (mapping.filmBreathAmount <= 0.0f ||
        (responses.exposureResponse <= 0.0 &&
         responses.tonalResponse <= 0.0 &&
         responses.colorResponse <= 0.0)) {
        return ::filmtone::film_breath::kFilmBreathZeroOffsets;
    }

    const double resolvedFrameRate = resolveFrameRate(context.frameRates);
    const host::RectI* bounds = selectBounds(context);
    if (resolvedFrameRate <= 0.0 ||
        bounds == nullptr) {
        return std::nullopt;
    }

    const double boundsWidth =
        static_cast<double>(bounds->x2) - static_cast<double>(bounds->x1);
    const double boundsHeight =
        static_cast<double>(bounds->y2) - static_cast<double>(bounds->y1);

    forestone::visual_render::DeterministicRenderContextV1 deterministic{};
    deterministic.renderScaleX = static_cast<float>(context.renderScale.x);
    deterministic.renderScaleY = static_cast<float>(context.renderScale.y);
    deterministic.boundsX = static_cast<float>(bounds->x1);
    deterministic.boundsY = static_cast<float>(bounds->y1);
    deterministic.boundsWidth = static_cast<float>(boundsWidth);
    deterministic.boundsHeight = static_cast<float>(boundsHeight);
    deterministic.seed = resolveSeed(
        context,
        parameters.finishParameters.variation);

    const auto actualResolveContext = contracts::makeResolveRenderContextV1(
        context.time,
        resolvedFrameRate,
        deterministic);
    if (!actualResolveContext.has_value()) {
        return std::nullopt;
    }

    const FilmBreathOffsets canonical =
        contracts::makeFilmtoneFinishFilmBreathOffsetsV1(
            mapping,
            *actualResolveContext);

    return FilmBreathOffsets{
        canonical.exposure * responses.exposureResponse,
        canonical.contrast * responses.tonalResponse,
        canonical.temperature * responses.colorResponse,
        canonical.tint * responses.colorResponse,
    };
}

bool isFilmBreathIdentity(const FilmBreathOffsets& offsets) noexcept {
    return offsets.exposure == 0.0 &&
           offsets.contrast == 0.0 &&
           offsets.temperature == 0.0 &&
           offsets.tint == 0.0;
}

}  // namespace filmtone::resolve::effects::film_breath
