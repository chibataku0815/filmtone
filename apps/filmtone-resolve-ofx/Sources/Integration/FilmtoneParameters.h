#pragma once

#include <optional>

#include "../Effects/FilmBreath/FilmBreathParameters.h"
#include "../Generated/Contracts/filmtone_resolve_spatial.hpp"
#include "../Host/RenderContext.h"
#include "ofxsImageEffect.h"

namespace filmtone::resolve::integration {

// Read-only License status label (derived from the license file; not persisted).
inline constexpr char kLicenseStatusParamId[] =
    "com.chibatakumi.filmtone.resolve.license.status";

struct EvaluatedFilmtoneParameters final {
    spatial::FilmtoneSpatialParametersV1 spatial{};
    effects::film_breath::FilmBreathParameters filmBreath{};

    [[nodiscard]] const forestone::filmtone::FilmtoneFinishParametersV1&
    finish() const noexcept {
        return filmBreath.finishParameters;
    }
};

// Registers the generated 17-entry accepted film surface, the generated
// 14-entry spatial surface, and the four accepted local Film Breath response
// and cadence controls. Generated metadata retains ownership of generated
// controls; the local Film Breath descriptor array owns these four controls.
//
// Layout: Node Role, then the always-open Quick Enable group that reuses the
// eight persistent Enabled parameters under their feature names, then
// Variation, then one closed detail group per feature holding only stored
// adjustment controls. Real-valued descriptor defaults and the non-finite
// evaluate fallbacks both resolve through the Resolve-only factory table in
// FilmtoneResolveFactoryDefaults.h; Enabled, Node Role, and Variation keep
// generated identity defaults so the effect stays exact identity at add time
// and after reset.
void describeFilmtoneParameters(OFX::ImageEffectDescriptor& descriptor);

class FilmtoneParameterSet final {
public:
    explicit FilmtoneParameterSet(OFX::ImageEffect& effect);

    [[nodiscard]] EvaluatedFilmtoneParameters evaluate(
        double time) const;

    // Re-evaluates the license file and writes the read-only status label.
    // Panel-refresh dependent: call at instance creation and on param changes.
    void updateLicenseStatus() const;

private:
    OFX::StringParam* licenseStatus_;
    OFX::ChoiceParam* nodeRole_;

    OFX::BooleanParam* deepGlowEnabled_;
    OFX::DoubleParam* bloomStrength_;
    OFX::DoubleParam* bloomThreshold_;
    OFX::DoubleParam* bloomRadius_;
    OFX::DoubleParam* bloomSoftKnee_;

    OFX::BooleanParam* peripheralChromaticShiftEnabled_;
    OFX::DoubleParam* rgbShift_;

    OFX::BooleanParam* lensSoftnessEnabled_;
    OFX::DoubleParam* lensSoftness_;

    OFX::BooleanParam* textureSoftnessEnabled_;
    OFX::DoubleParam* detailSoftness_;

    OFX::BooleanParam* vignetteEnabled_;
    OFX::DoubleParam* vignette_;

    OFX::IntParam* variation_;

    OFX::BooleanParam* filmBreathEnabled_;
    OFX::DoubleParam* filmBreathAmount_;
    OFX::DoubleParam* filmBreathExposureResponse_;
    OFX::DoubleParam* filmBreathTonalResponse_;
    OFX::DoubleParam* filmBreathColorResponse_;
    OFX::DoubleParam* filmBreathPeriodFrames_;

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
