#pragma once

#include "../../Generated/Contracts/filmtone_finish_contracts.hpp"

namespace filmtone::resolve::gate_weave {

// Keep the generated transform ABI. Values use the frozen generic screen-space
// convention: X points right, Y points down, and positive rotation is
// clockwise. Offsets are expressed in pixels at the current render scale.
using GateWeaveTransform =
    forestone::visual_render::FilmDamageGateWeaveTransformV1;

// Exact absolute motion limits for every time, seed, and jitter value admitted
// by one normalized revision-2.3 recipe. These limits let the Metal pass use a
// constant safety crop rather than a frame-varying zoom.
struct GateWeaveMotionEnvelope final {
    double maxOffsetX = 0.0;
    double maxOffsetY = 0.0;
    double maxRotationDegrees = 0.0;
};

[[nodiscard]] bool isGateWeaveConfigurationValid(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe) noexcept;

[[nodiscard]] bool isGateWeaveConfiguredIdentity(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe) noexcept;

[[nodiscard]] bool isGateWeaveTransformIdentity(
    const GateWeaveTransform& transform) noexcept;

[[nodiscard]] GateWeaveTransform resolveGateWeaveTransform(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe,
    const forestone::visual_render::DeterministicRenderContextV1& context) noexcept;

[[nodiscard]] GateWeaveMotionEnvelope resolveGateWeaveMotionEnvelope(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe,
    const forestone::visual_render::DeterministicRenderContextV1& context) noexcept;

}  // namespace filmtone::resolve::gate_weave
