#pragma once

#include <optional>

#include "../Effects/FilmBreath/FilmBreathParameters.h"
#include "../Host/RenderContext.h"
#include "ofxsImageEffect.h"

namespace filmtone::resolve::integration {

struct EvaluatedFilmtoneParameters final {
    effects::film_breath::FilmBreathParameters filmBreath{};

    [[nodiscard]] const forestone::filmtone::FilmtoneFinishParametersV1&
    mapping() const noexcept {
        return filmBreath.mapping;
    }
};

// Registers the generated 17-entry base surface and the three accepted local
// Film Breath response controls. The generated definitions remain the only
// owner of base IDs, kinds, defaults, and ranges.
void describeFilmtoneParameters(OFX::ImageEffectDescriptor& descriptor);

class FilmtoneParameterSet final {
public:
    explicit FilmtoneParameterSet(OFX::ImageEffect& effect);

    [[nodiscard]] EvaluatedFilmtoneParameters evaluate(
        double time) const;

private:
    OFX::IntParam* variation_;

    OFX::BooleanParam* filmBreathEnabled_;
    OFX::DoubleParam* filmBreathAmount_;
    OFX::DoubleParam* filmBreathExposureResponse_;
    OFX::DoubleParam* filmBreathTonalResponse_;
    OFX::DoubleParam* filmBreathColorResponse_;

    OFX::BooleanParam* gateWeaveEnabled_;
    OFX::DoubleParam* gateWeaveAmount_;
    OFX::DoubleParam* gateWeaveHorizontalAmplitude_;
    OFX::DoubleParam* gateWeaveVerticalAmplitude_;
    OFX::DoubleParam* gateWeaveRotationAmplitudeDegrees_;
    OFX::DoubleParam* gateWeaveFrequency_;
    OFX::DoubleParam* gateWeaveJitter_;

    OFX::BooleanParam* filmDamageEnabled_;
    OFX::DoubleParam* filmDamageAmount_;
    OFX::DoubleParam* dustAmount_;
    OFX::DoubleParam* scratchAmount_;
    OFX::DoubleParam* fiberAmount_;
    OFX::DoubleParam* stainAmount_;
    OFX::DoubleParam* gateWearAmount_;
};

// Resolve the two host rates without inventing a material clock. Timeline is
// preferred for temporal evaluation; either valid host rate may safely fill a
// missing counterpart.
[[nodiscard]] std::optional<host::FrameRates> resolveFrameRates(
    double sourceFrameRate,
    double timelineFrameRate) noexcept;

}  // namespace filmtone::resolve::integration
