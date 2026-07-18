#include "GateWeaveTransform.h"

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace filmtone::resolve::gate_weave {
namespace {

constexpr double kTwoPi = 6.283185307179586476925286766559;
constexpr forestone::visual_effect::FilmDamageGateWeave
    kGeneratedGateWeaveDefaults{};
static_assert(kGeneratedGateWeaveDefaults.verticalAmplitude > 0.0f);
constexpr double kLegacyVerticalJitterRatio =
    static_cast<double>(kGeneratedGateWeaveDefaults.horizontalAmplitude) /
    static_cast<double>(kGeneratedGateWeaveDefaults.verticalAmplitude);

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
    const double phase =
        context.hostTimeSeconds * weave.frequency * kTwoPi +
        static_cast<double>(streamSeed) * 0.001;
    if (!isFinite(phase)) {
        return transform;
    }
    const double frameIndex = static_cast<double>(context.frameIndex);
    const double seed = static_cast<double>(streamSeed);
    const double jitterX =
        (hash3(frameIndex, seed, 101.0) - 0.5) * amplitudes.jitter *
        amplitudes.offsetX;
    // Revision 2.2 intentionally preserves the v2.1 vertical jitter envelope
    // while allowing an independent vertical movement amplitude.
    const double jitterY =
        (hash3(frameIndex, seed, 103.0) - 0.5) * amplitudes.jitter *
        amplitudes.offsetY * kLegacyVerticalJitterRatio;
    const double rotationJitter =
        (hash3(frameIndex, seed, 107.0) - 0.5) * amplitudes.jitter *
        amplitudes.rotationDegrees;

    transform.offsetX = static_cast<float>(
        (std::sin(phase) + std::sin(phase * 2.13 + 1.7) * 0.35) *
            amplitudes.offsetX +
        jitterX);
    transform.offsetY = static_cast<float>(
        std::cos(phase * 1.37 + 0.3) * amplitudes.offsetY +
        jitterY * 0.65);
    transform.rotationDegrees = static_cast<float>(
        (std::sin(phase * 0.83 + 2.1) +
         std::sin(phase * 1.91 + 0.4) * 0.25) *
            amplitudes.rotationDegrees +
        rotationJitter);
    return transform;
}

GateWeaveMotionEnvelope resolveGateWeaveMotionEnvelope(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe,
    const forestone::visual_render::DeterministicRenderContextV1& context) noexcept {
    const GateWeaveAmplitudes amplitudes = resolveAmplitudes(recipe, context);
    const double jitterMagnitude = std::abs(amplitudes.jitter);
    return GateWeaveMotionEnvelope{
        std::abs(amplitudes.offsetX) * (1.35 + 0.5 * jitterMagnitude),
        std::abs(amplitudes.offsetY) *
            (1.0 + 0.325 * jitterMagnitude * kLegacyVerticalJitterRatio),
        std::abs(amplitudes.rotationDegrees) *
            (1.25 + 0.5 * jitterMagnitude),
    };
}

}  // namespace filmtone::resolve::gate_weave
