#pragma once

#include <optional>

#include "FilmBreathParameters.h"
#include "../../Generated/Contracts/filmtone_finish_contracts.hpp"
#include "../../Host/RenderContext.h"

namespace filmtone::resolve::effects::film_breath {

// Resolve owns this five-component value object because its Film Breath
// implementation models subtractive CMY density rather than the legacy
// generated temperature/tint pair. Density values are signed: positive C, M,
// and Y subtract their corresponding RGB primaries in the pixel processor;
// negative values move along the complementary direction.
struct FilmBreathOffsets final {
    double exposure = 0.0;
    double contrast = 0.0;
    double cyanDensity = 0.0;
    double magentaDensity = 0.0;
    double yellowDensity = 0.0;
};

inline constexpr FilmBreathOffsets kFilmBreathZeroOffsets{};

// Resolve's host time is expressed in frames. This resolver selects the
// timeline rate (falling back to the source rate only when necessary), then
// evaluates the Resolve-local frame-domain breath model. The three response
// families share one deterministic carrier instead of drifting on independent
// second-based clocks. Frame zero and negative timeline frames are ordinary
// samples; there is no timeline-start envelope or forced-zero special case.
[[nodiscard]] std::optional<FilmBreathOffsets> resolveFilmBreathOffsets(
    const FilmBreathParameters& parameters,
    const host::RenderContext& context) noexcept;

[[nodiscard]] bool isFilmBreathIdentity(
    const FilmBreathOffsets& offsets) noexcept;

}  // namespace filmtone::resolve::effects::film_breath
