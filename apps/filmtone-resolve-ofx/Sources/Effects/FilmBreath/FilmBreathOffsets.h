#pragma once

#include <optional>

#include "FilmBreathParameters.h"
#include "../../Generated/Contracts/filmtone_finish_contracts.hpp"
#include "../../Host/RenderContext.h"

namespace filmtone::resolve::effects::film_breath {

using FilmBreathOffsets = ::filmtone::film_breath::FilmBreathOffsetsV1;

// Resolve's host time is expressed in frames. This resolver selects the
// timeline rate (falling back to the source rate only when necessary) and
// derives an unmodified Resolve context through the frozen adapter. Film
// Breath v1 uses the frozen facade and its canonical cadence without a
// feature-local time control.
[[nodiscard]] std::optional<FilmBreathOffsets> resolveFilmBreathOffsets(
    const FilmBreathParameters& parameters,
    const host::RenderContext& context) noexcept;

[[nodiscard]] bool isFilmBreathIdentity(
    const FilmBreathOffsets& offsets) noexcept;

}  // namespace filmtone::resolve::effects::film_breath
