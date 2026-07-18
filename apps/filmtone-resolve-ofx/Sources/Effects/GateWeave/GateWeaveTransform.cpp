#include "GateWeaveTransform.h"

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace filmtone::resolve::gate_weave {
namespace {

// Gate movement is stochastic, not cyclic. Frequency is interpreted as the
// inverse correlation time; frameRate / frequency gives the primary
// correlation span in frames. Each output is a bounded convex combination, so
// the existing constant automatic-crop envelope remains exact.
constexpr std::uint32_t kSharedSmoothLane = 0x8f6c2a31u;
constexpr std::uint32_t kHorizontalSmoothLane = 0x4f1bbcdcu;
constexpr std::uint32_t kVerticalSmoothLane = 0x9e2c6b6fu;
constexpr std::uint32_t kRotationSmoothLane = 0x27d4eb2fu;
constexpr std::uint32_t kSharedRoughLane = 0xa511e9b3u;
constexpr std::uint32_t kHorizontalRoughLane = 0x52a7b9c4u;
constexpr std::uint32_t kVerticalRoughLane = 0x6d2b79f5u;
constexpr std::uint32_t kRotationRoughLane = 0x1b873593u;
constexpr std::uint32_t kHorizontalScatterLane = 0x85ebca6bu;
constexpr std::uint32_t kVerticalScatterLane = 0x7feb352du;
constexpr std::uint32_t kRotationScatterLane = 0x846ca68bu;

struct GateWeaveAmplitudes final {
    double offsetX = 0.0;
    double offsetY = 0.0;
    double rotationDegrees = 0.0;
    double jitter = 0.0;
};

bool isFinite(double value) noexcept {
    return std::isfinite(value);
}

bool isKnownFormatProfile(
    forestone::visual_effect::FilmDamageFormatProfile profile) noexcept {
    using forestone::visual_effect::FilmDamageFormatProfile;
    switch (profile) {
        case FilmDamageFormatProfile::film35mm:
        case FilmDamageFormatProfile::film16mm:
        case FilmDamageFormatProfile::film8mm:
            return true;
    }
    return false;
}

bool isKnownTravelAxis(
    forestone::visual_effect::FilmDamageTravelAxis axis) noexcept {
    using forestone::visual_effect::FilmDamageTravelAxis;
    switch (axis) {
        case FilmDamageTravelAxis::horizontal:
        case FilmDamageTravelAxis::vertical:
        case FilmDamageTravelAxis::mixed:
            return true;
    }
    return false;
}

double gateInstabilityFor(
    forestone::visual_effect::FilmDamageFormatProfile profile) noexcept {
    using forestone::visual_effect::FilmDamageFormatProfile;
    switch (profile) {
        case FilmDamageFormatProfile::film8mm:
            return 1.55;
        case FilmDamageFormatProfile::film16mm:
            return 1.25;
        case FilmDamageFormatProfile::film35mm:
            return 1.0;
    }
    return 0.0;
}

double smootherstep(double value) noexcept {
    const double x = std::clamp(value, 0.0, 1.0);
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

std::uint32_t normalizeLattice(double value) noexcept {
    if (!isFinite(value)) {
        return 0u;
    }
    double wrapped = std::fmod(value, 4294967296.0);
    if (wrapped < 0.0) {
        wrapped += 4294967296.0;
    }
    return static_cast<std::uint32_t>(wrapped);
}

std::uint32_t mixHash(
    std::uint32_t seed,
    std::uint32_t lattice,
    std::uint32_t lane) noexcept {
    std::uint32_t value = seed ^ lane;
    value ^= lattice * 0x9e3779b1u;
    value ^= value >> 16u;
    value *= 0x7feb352du;
    value ^= value >> 15u;
    value *= 0x846ca68bu;
    value ^= value >> 16u;
    return value;
}

double signedHash(
    std::uint32_t seed,
    double lattice,
    std::uint32_t lane) noexcept {
    constexpr double kInverseUint32 = 1.0 / 4294967295.0;
    return static_cast<double>(
               mixHash(seed, normalizeLattice(lattice), lane)) *
               kInverseUint32 * 2.0 -
           1.0;
}

double valueNoise(
    double frameIndex,
    double correlationFrames,
    std::uint32_t seed,
    std::uint32_t lane) noexcept {
    const double position = frameIndex / correlationFrames;
    const double lattice = std::floor(position);
    const double fraction = position - lattice;
    const double first = signedHash(seed, lattice, lane);
    const double second = signedHash(seed, lattice + 1.0, lane);
    return first + (second - first) * smootherstep(fraction);
}

double trajectoryValue(
    double frameIndex,
    double correlationFrames,
    double jitter,
    std::uint32_t seed,
    std::uint32_t smoothLane,
    std::uint32_t roughLane,
    std::uint32_t scatterLane) noexcept {
    const double smooth =
        valueNoise(
            frameIndex,
            correlationFrames,
            seed,
            kSharedSmoothLane) * 0.42 +
        valueNoise(
            frameIndex,
            correlationFrames,
            seed,
            smoothLane) * 0.58;
    const double roughCorrelation = std::max(
        1.0,
        correlationFrames * (0.38 - 0.23 * jitter));
    const double rough =
        valueNoise(
            frameIndex,
            roughCorrelation,
            seed,
            kSharedRoughLane) * 0.30 +
        valueNoise(
            frameIndex,
            roughCorrelation,
            seed,
            roughLane) * 0.70;
    const double scatter = signedHash(
        seed,
        std::floor(frameIndex),
        scatterLane);
    const double jerky = rough * 0.78 + scatter * 0.22;
    return (1.0 - jitter) * smooth + jitter * jerky;
}

GateWeaveAmplitudes resolveAmplitudes(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe,
    const forestone::visual_render::DeterministicRenderContextV1& context) noexcept {
    GateWeaveAmplitudes amplitudes{};
    if (!isGateWeaveConfigurationValid(recipe) ||
        isGateWeaveConfiguredIdentity(recipe) ||
        !isFinite(context.renderScaleX) || context.renderScaleX <= 0.0f ||
        !isFinite(context.renderScaleY) || context.renderScaleY <= 0.0f ||
        !isFinite(context.boundsWidth) || context.boundsWidth <= 0.0f ||
        !isFinite(context.boundsHeight) || context.boundsHeight <= 0.0f) {
        return amplitudes;
    }

    const auto& weave = recipe.gateWeave;
    const double shortAxisCanonical =
        std::min(static_cast<double>(context.boundsWidth),
                 static_cast<double>(context.boundsHeight));
    const double gain =
        static_cast<double>(recipe.global.amount) * recipe.global.opacity;
    const double motionScale =
        static_cast<double>(weave.amount) * gain *
        gateInstabilityFor(recipe.formatProfile);

    using forestone::visual_effect::FilmDamageTravelAxis;
    if (weave.travelAxis != FilmDamageTravelAxis::vertical) {
        amplitudes.offsetX =
            shortAxisCanonical * weave.horizontalAmplitude * motionScale *
            context.renderScaleX;
    }
    if (weave.travelAxis != FilmDamageTravelAxis::horizontal) {
        amplitudes.offsetY =
            shortAxisCanonical * weave.verticalAmplitude * motionScale *
            context.renderScaleY;
    }
    amplitudes.rotationDegrees =
        static_cast<double>(weave.rotationAmplitudeDegrees) * motionScale;
    amplitudes.jitter = weave.jitter;
    return amplitudes;
}

}  // namespace

bool isGateWeaveConfigurationValid(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe) noexcept {
    const auto& weave = recipe.gateWeave;
    return isKnownFormatProfile(recipe.formatProfile) &&
           isKnownTravelAxis(weave.travelAxis) &&
           isFinite(recipe.global.amount) &&
           isFinite(recipe.global.opacity) &&
           isFinite(weave.amount) &&
           isFinite(weave.horizontalAmplitude) &&
           isFinite(weave.verticalAmplitude) &&
           isFinite(weave.rotationAmplitudeDegrees) &&
           isFinite(weave.frequency) &&
           isFinite(weave.jitter);
}

bool isGateWeaveConfiguredIdentity(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe) noexcept {
    if (!isGateWeaveConfigurationValid(recipe)) {
        return false;
    }

    const auto& weave = recipe.gateWeave;
    const double gain =
        static_cast<double>(recipe.global.amount) * recipe.global.opacity;
    if (recipe.enabled == 0u || weave.amount <= 0.0f ||
        weave.frequency <= 0.0f || gain <= 0.0) {
        return true;
    }

    using forestone::visual_effect::FilmDamageTravelAxis;
    const bool hasX =
        weave.travelAxis != FilmDamageTravelAxis::vertical &&
        weave.horizontalAmplitude != 0.0f;
    const bool hasY =
        weave.travelAxis != FilmDamageTravelAxis::horizontal &&
        weave.verticalAmplitude != 0.0f;
    return !hasX && !hasY && weave.rotationAmplitudeDegrees == 0.0f;
}

bool isGateWeaveTransformIdentity(
    const GateWeaveTransform& transform) noexcept {
    return transform.offsetX == 0.0f && transform.offsetY == 0.0f &&
           transform.rotationDegrees == 0.0f;
}

GateWeaveTransform resolveGateWeaveTransform(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe,
    const forestone::visual_render::DeterministicRenderContextV1& context) noexcept {
    const std::uint32_t streamSeed =
        forestone::visual_render::deriveDeterministicStreamSeed(
            context.seed,
            forestone::visual_effect::kGateWeaveStreamSalt);
    GateWeaveTransform transform{};
    const GateWeaveAmplitudes amplitudes = resolveAmplitudes(recipe, context);
    if ((amplitudes.offsetX == 0.0 && amplitudes.offsetY == 0.0 &&
         amplitudes.rotationDegrees == 0.0)) {
        return transform;
    }

    const auto& weave = recipe.gateWeave;
    if (!isFinite(context.frameRate) || context.frameRate <= 0.0) {
        return transform;
    }
    const double frameIndex = static_cast<double>(context.frameIndex);
    const double jitter = std::clamp(amplitudes.jitter, 0.0, 1.0);
    const double correlationFrames = std::max(
        1.0,
        context.frameRate / static_cast<double>(weave.frequency));
    const double horizontal = trajectoryValue(
        frameIndex,
        correlationFrames,
        jitter,
        streamSeed,
        kHorizontalSmoothLane,
        kHorizontalRoughLane,
        kHorizontalScatterLane);
    const double vertical = trajectoryValue(
        frameIndex,
        correlationFrames,
        jitter,
        streamSeed,
        kVerticalSmoothLane,
        kVerticalRoughLane,
        kVerticalScatterLane);
    const double rotation = trajectoryValue(
        frameIndex,
        correlationFrames,
        jitter,
        streamSeed,
        kRotationSmoothLane,
        kRotationRoughLane,
        kRotationScatterLane);

    transform.offsetX = static_cast<float>(amplitudes.offsetX * horizontal);
    transform.offsetY = static_cast<float>(amplitudes.offsetY * vertical);
    transform.rotationDegrees =
        static_cast<float>(amplitudes.rotationDegrees * rotation);
    return transform;
}

GateWeaveMotionEnvelope resolveGateWeaveMotionEnvelope(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe,
    const forestone::visual_render::DeterministicRenderContextV1& context) noexcept {
    const GateWeaveAmplitudes amplitudes = resolveAmplitudes(recipe, context);
    // Every stochastic stage and blend is bounded to one unit, so this remains
    // an exact envelope for automatic crop and cubic reconstruction safety.
    return GateWeaveMotionEnvelope{
        std::abs(amplitudes.offsetX),
        std::abs(amplitudes.offsetY),
        std::abs(amplitudes.rotationDegrees),
    };
}

}  // namespace filmtone::resolve::gate_weave
