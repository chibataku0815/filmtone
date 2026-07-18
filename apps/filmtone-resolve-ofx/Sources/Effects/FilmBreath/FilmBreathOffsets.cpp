#include "FilmBreathOffsets.h"

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace filmtone::resolve::effects::film_breath {
namespace {

// Resolve-local revision 3 keeps cadence in the integer frame domain and lets
// the persistent Period control scale every correlation span. The value is a
// frame interval, not a seconds-based oscillator, so random frame access and
// timeline-rate changes cannot alter a frame's deterministic sample.
constexpr std::int64_t kMinimumPeriodFrames = 1;
constexpr std::int64_t kMaximumPeriodFrames = 120;
constexpr std::int64_t kDefaultPeriodFrames = 24;

// Exposure is measured in stops. Contrast is a bounded log-luminance slope
// offset. CMY values are signed optical-density offsets consumed by the Metal
// response; one independent density lane is retained for every subtractive
// primary instead of collapsing colour to temperature/tint.
constexpr double kExposureLimit = 0.6;
constexpr double kTonalSlopeLimit = 0.2;
constexpr double kColorDensityLimit = 0.24;

constexpr std::uint32_t kPrimaryCarrierSalt = 0x4f1bbcdcu;
constexpr std::uint32_t kSecondaryCarrierSalt = 0xa511e9b3u;
constexpr std::uint32_t kExposureDetailSalt = 0x73a82f1du;
constexpr std::uint32_t kTonalDetailSalt = 0x9e2c6b6fu;
constexpr std::uint32_t kCyanDetailSalt = 0x27d4eb2fu;
constexpr std::uint32_t kMagentaDetailSalt = 0x165667b1u;
constexpr std::uint32_t kYellowDetailSalt = 0xb5297a4du;

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

std::int64_t resolvePeriodFrames(double value) noexcept {
    const double finitePeriod = clampFinite(
        value,
        static_cast<double>(kMinimumPeriodFrames),
        static_cast<double>(kMaximumPeriodFrames),
        static_cast<double>(kDefaultPeriodFrames));
    return std::clamp<std::int64_t>(
        static_cast<std::int64_t>(std::llround(finitePeriod)),
        kMinimumPeriodFrames,
        kMaximumPeriodFrames);
}

std::int64_t scaledCorrelationFrames(
    std::int64_t periodFrames,
    std::int64_t numerator,
    std::int64_t denominator) noexcept {
    const std::int64_t rounded =
        (periodFrames * numerator + denominator / 2) / denominator;
    return std::max<std::int64_t>(1, rounded);
}

double clampUnitSigned(double value) noexcept {
    return std::clamp(value, -1.0, 1.0);
}

double smootherstep(double value) noexcept {
    const double x = std::clamp(value, 0.0, 1.0);
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

std::uint32_t mixHash(
    std::uint32_t seed,
    std::int64_t lattice,
    std::uint32_t salt) noexcept {
    const std::uint64_t latticeBits = static_cast<std::uint64_t>(lattice);
    std::uint32_t value = seed ^ salt;
    value ^= static_cast<std::uint32_t>(latticeBits);
    value ^= static_cast<std::uint32_t>(latticeBits >> 32u) * 0x9e3779b1u;
    value ^= value >> 16u;
    value *= 0x7feb352du;
    value ^= value >> 15u;
    value *= 0x846ca68bu;
    value ^= value >> 16u;
    return value;
}

double signedHash(
    std::uint32_t seed,
    std::int64_t lattice,
    std::uint32_t salt) noexcept {
    constexpr double kInverseUint32 = 1.0 / 4294967295.0;
    return static_cast<double>(mixHash(seed, lattice, salt)) *
               kInverseUint32 * 2.0 -
           1.0;
}

struct FrameLatticePosition final {
    std::int64_t index = 0;
    double fraction = 0.0;
};

FrameLatticePosition frameLatticePosition(
    std::int64_t frameIndex,
    std::int64_t correlationFrames) noexcept {
    std::int64_t lattice = frameIndex / correlationFrames;
    std::int64_t remainder = frameIndex % correlationFrames;
    if (remainder < 0) {
        --lattice;
        remainder += correlationFrames;
    }
    return FrameLatticePosition{
        lattice,
        static_cast<double>(remainder) /
            static_cast<double>(correlationFrames),
    };
}

double frameValueNoise(
    std::int64_t frameIndex,
    std::int64_t correlationFrames,
    std::uint32_t seed,
    std::uint32_t salt) noexcept {
    const FrameLatticePosition position = frameLatticePosition(
        frameIndex,
        correlationFrames);
    const double first = signedHash(seed, position.index, salt);
    const double second = signedHash(seed, position.index + 1, salt);
    return first +
           (second - first) * smootherstep(position.fraction);
}

FilmBreathOffsets resolveFrameDomainOffsets(
    double amount,
    std::int64_t periodFrames,
    std::int64_t frameIndex,
    std::uint32_t seed) noexcept {
    const double normalizedAmount = clampFinite(amount, 0.0, 1.0, 0.0);
    if (normalizedAmount <= 0.0) {
        return kFilmBreathZeroOffsets;
    }

    const std::int64_t primarySpan = std::clamp(
        periodFrames,
        kMinimumPeriodFrames,
        kMaximumPeriodFrames);
    const std::int64_t secondarySpan = scaledCorrelationFrames(
        primarySpan,
        2,
        1);
    const double primaryCarrier = frameValueNoise(
        frameIndex,
        primarySpan,
        seed,
        kPrimaryCarrierSalt);
    const double secondaryCarrier = frameValueNoise(
        frameIndex,
        secondarySpan,
        seed,
        kSecondaryCarrierSalt);
    const double carrier = clampUnitSigned(
        primaryCarrier * 0.78 + secondaryCarrier * 0.22);

    // Every response follows one shared emulsion event while retaining a
    // smaller, independently salted component. The weights sum to one, so the
    // final clamp is only a finite-domain guard rather than a sustained hard
    // limiter. Separate C, M, and Y detail prevents the colour response from
    // collapsing back to a two-axis white-balance model.
    const double exposure = clampUnitSigned(
        carrier * 0.88 +
        frameValueNoise(
            frameIndex,
            scaledCorrelationFrames(primarySpan, 3, 4),
            seed,
            kExposureDetailSalt) * 0.12);
    const double tonal = clampUnitSigned(
        carrier * 0.76 +
        frameValueNoise(
            frameIndex,
            scaledCorrelationFrames(primarySpan, 5, 6),
            seed,
            kTonalDetailSalt) * 0.24);
    const double cyan = clampUnitSigned(
        carrier * 0.48 +
        frameValueNoise(
            frameIndex,
            scaledCorrelationFrames(primarySpan, 7, 10),
            seed,
            kCyanDetailSalt) * 0.52);
    const double magenta = clampUnitSigned(
        carrier * 0.42 +
        frameValueNoise(
            frameIndex,
            scaledCorrelationFrames(primarySpan, 11, 20),
            seed,
            kMagentaDetailSalt) * 0.58);
    const double yellow = clampUnitSigned(
        carrier * 0.55 +
        frameValueNoise(
            frameIndex,
            scaledCorrelationFrames(primarySpan, 13, 20),
            seed,
            kYellowDetailSalt) * 0.45);

    return FilmBreathOffsets{
        exposure * kExposureLimit * normalizedAmount,
        tonal * kTonalSlopeLimit * normalizedAmount,
        cyan * kColorDensityLimit * normalizedAmount,
        magenta * kColorDensityLimit * normalizedAmount,
        yellow * kColorDensityLimit * normalizedAmount,
    };
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
        return kFilmBreathZeroOffsets;
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

    const std::uint32_t streamSeed =
        forestone::visual_render::deriveDeterministicStreamSeed(
            actualResolveContext->deterministic.seed,
            mapping.filmBreathStreamSalt);
    const FilmBreathOffsets canonical = resolveFrameDomainOffsets(
        mapping.filmBreathAmount,
        resolvePeriodFrames(parameters.periodFrames),
        actualResolveContext->deterministic.frameIndex,
        streamSeed);

    return FilmBreathOffsets{
        canonical.exposure * responses.exposureResponse,
        canonical.contrast * responses.tonalResponse,
        canonical.cyanDensity * responses.colorResponse,
        canonical.magentaDensity * responses.colorResponse,
        canonical.yellowDensity * responses.colorResponse,
    };
}

bool isFilmBreathIdentity(const FilmBreathOffsets& offsets) noexcept {
    return offsets.exposure == 0.0 &&
           offsets.contrast == 0.0 &&
           offsets.cyanDensity == 0.0 &&
           offsets.magentaDensity == 0.0 &&
           offsets.yellowDensity == 0.0;
}

}  // namespace filmtone::resolve::effects::film_breath
