#pragma once

#include <array>

#include "../../Generated/Contracts/filmtone_finish_contracts.hpp"

namespace filmtone::resolve::effects::film_breath {

struct FilmBreathParameterDescriptor final {
    const char* id;
    forestone::filmtone::FilmtoneFinishParameterKind kind;
    double defaultValue;
    double minValue;
    double maxValue;
};

inline constexpr char kFilmBreathExposureResponseParameterId[] =
    "com.forestone.filmtone.finish.filmBreath.exposureResponse";
inline constexpr char kFilmBreathTonalResponseParameterId[] =
    "com.forestone.filmtone.finish.filmBreath.tonalResponse";
inline constexpr char kFilmBreathColorResponseParameterId[] =
    "com.forestone.filmtone.finish.filmBreath.colorResponse";

// Variation, Film Breath Enabled, and Film Breath Amount IDs/defaults/ranges
// remain owned by kFilmtoneFinishParameterDefinitions. Only response controls
// that are genuinely local to this module are described here.
inline constexpr std::array<FilmBreathParameterDescriptor, 3>
    kFilmBreathParameterDescriptors{{
        {kFilmBreathExposureResponseParameterId,
         forestone::filmtone::FilmtoneFinishParameterKind::real,
         1.0,
         0.0,
         1.0},
        {kFilmBreathTonalResponseParameterId,
         forestone::filmtone::FilmtoneFinishParameterKind::real,
         1.0,
         0.0,
         1.0},
        {kFilmBreathColorResponseParameterId,
         forestone::filmtone::FilmtoneFinishParameterKind::real,
         1.0,
         0.0,
         1.0},
    }};

struct FilmBreathParameters final {
    forestone::filmtone::FilmtoneFinishParametersV1 finishParameters{};
    double exposureResponse = 1.0;
    double tonalResponse = 1.0;
    double colorResponse = 1.0;
};

}  // namespace filmtone::resolve::effects::film_breath
