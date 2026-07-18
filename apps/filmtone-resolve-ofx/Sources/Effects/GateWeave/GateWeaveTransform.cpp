#include "GateWeaveTransform.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>

namespace filmtone::resolve::gate_weave {
namespace {

constexpr double kTwoPi = 6.283185307179586476925286766559;

// Film Damage 2.3 Gate Weave reference: each axis is a convex blend of
// correlated multi-band drift and deterministic per-frame registration
// scatter. The blend stays inside one unit of resolved amplitude, allowing an
// exact constant edge-safety envelope without playback-history state.
constexpr std::size_t kDriftBandCount = 5u;
constexpr std::array<double, kDriftBandCount> kDriftBandFrequencyRatios{
    0.2317, 0.4671, 1.0, 2.0893, 4.3117};

constexpr std::array<double, kDriftBandCount> normalizedDriftWeights(
    double spectralCenterRatio) noexcept {
    std::array<double, kDriftBandCount> weights{};
    double sum = 0.0;
    for (std::size_t band = 0u; band < kDriftBandCount; ++band) {
        const double relative =
            kDriftBandFrequencyRatios[band] / spectralCenterRatio;
        weights[band] = 1.0 / (1.0 + relative * relative);
        sum += weights[band];
    }
    for (std::size_t band = 0u; band < kDriftBandCount; ++band) {
        weights[band] /= sum;
    }
    return weights;
}

constexpr std::array<double, kDriftBandCount> kHorizontalDriftWeights =
    normalizedDriftWeights(0.6);
constexpr std::array<double, kDriftBandCount> kVerticalDriftWeights =
    normalizedDriftWeights(1.0);
constexpr std::array<double, kDriftBandCount> kRotationDriftWeights =
    normalizedDriftWeights(0.4);

constexpr double kHorizontalPhaseLane = 211.0;
constexpr double kVerticalPhaseLane = 223.0;
constexpr double kRotationPhaseLane = 227.0;
constexpr double kVerticalModulationPhaseLane = 229.0;
constexpr double kHorizontalScatterLane = 101.0;
constexpr double kVerticalScatterLane = 103.0;
constexpr double kRotationScatterLane = 107.0;
constexpr double kHorizontalScatterShare = 0.22;
constexpr double kVerticalScatterShare = 0.40;
constexpr double kRotationScatterShare = 0.12;
constexpr double kVerticalModulationFrequencyRatio = 0.1117;
constexpr double kVerticalModulationDepth = 0.35;

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

double fract(double value) noexcept {
    return value - std::floor(value);
}

double hash3(double a, double b, double c) noexcept {
    return fract(std::sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453123);
}

double driftValue(
    const std::array<double, kDriftBandCount>& weights,
    double baseAngle,
    double seed,
    double phaseLane) noexcept {
    double value = 0.0;
    for (std::size_t band = 0u; band < kDriftBandCount; ++band) {
        const double phase =
            hash3(static_cast<double>(band), seed, phaseLane) * kTwoPi;
        value += weights[band] *
                 std::sin(baseAngle * kDriftBandFrequencyRatios[band] + phase);
    }
    return value;
}

double scatterValue(double frameIndex, double seed, double lane) noexcept {
    return 2.0 * (hash3(frameIndex, seed, lane) - 0.5);
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
         amplitudes.rotationDegrees == 0.0) ||
        !isFinite(context.hostTimeSeconds)) {
        return transform;
    }

    const auto& weave = recipe.gateWeave;
    const double baseAngle =
        context.hostTimeSeconds * static_cast<double>(weave.frequency) * kTwoPi;
    if (!isFinite(baseAngle)) {
        return transform;
    }
    const double seed = static_cast<double>(streamSeed);
    const double frameIndex = static_cast<double>(context.frameIndex);
    const double jitter = std::clamp(amplitudes.jitter, 0.0, 1.0);
    const double horizontalShare = kHorizontalScatterShare * jitter;
    const double verticalShare = kVerticalScatterShare * jitter;
    const double rotationShare = kRotationScatterShare * jitter;

    const double modulationPhase =
        hash3(0.0, seed, kVerticalModulationPhaseLane) * kTwoPi;
    const double verticalModulation =
        1.0 -
        kVerticalModulationDepth *
            (0.5 +
             0.5 * std::sin(baseAngle * kVerticalModulationFrequencyRatio +
                            modulationPhase));

    const double horizontal =
        (1.0 - horizontalShare) *
            driftValue(
                kHorizontalDriftWeights, baseAngle, seed, kHorizontalPhaseLane) +
        horizontalShare *
            scatterValue(frameIndex, seed, kHorizontalScatterLane);
    const double vertical =
        (1.0 - verticalShare) * verticalModulation *
            driftValue(
                kVerticalDriftWeights, baseAngle, seed, kVerticalPhaseLane) +
        verticalShare * scatterValue(frameIndex, seed, kVerticalScatterLane);
    const double rotation =
        (1.0 - rotationShare) *
            driftValue(
                kRotationDriftWeights, baseAngle, seed, kRotationPhaseLane) +
        rotationShare * scatterValue(frameIndex, seed, kRotationScatterLane);

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
    // Revision 2.3 guarantees that the convex drift/scatter blend stays inside
    // one unit of the resolved amplitude on every axis.
    return GateWeaveMotionEnvelope{
        std::abs(amplitudes.offsetX),
        std::abs(amplitudes.offsetY),
        std::abs(amplitudes.rotationDegrees),
    };
}

}  // namespace filmtone::resolve::gate_weave
