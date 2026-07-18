#include "FilmtoneParameters.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>

#include "../License/LicenseStore.h"

namespace filmtone::resolve::integration {
namespace {

using forestone::filmtone::FilmtoneFinishParameterDefinitionV1;
using forestone::filmtone::FilmtoneFinishParameterKind;
using forestone::filmtone::kFilmtoneFinishParameterDefinitions;

enum BaseParameterIndex : std::size_t {
    kVariation = 0u,
    kFilmBreathEnabled = 1u,
    kFilmBreathAmount = 2u,
    kGateWeaveEnabled = 3u,
    kGateWeaveAmount = 4u,
    kGateWeaveHorizontalAmplitude = 5u,
    kGateWeaveVerticalAmplitude = 6u,
    kGateWeaveRotationAmplitudeDegrees = 7u,
    kGateWeaveFrequency = 8u,
    kGateWeaveJitter = 9u,
    kFilmDamageEnabled = 10u,
    kFilmDamageAmount = 11u,
    kDustAmount = 12u,
    kScratchAmount = 13u,
    kFiberAmount = 14u,
    kStainAmount = 15u,
    kGateWearAmount = 16u,
};

static_assert(kFilmtoneFinishParameterDefinitions.size() == 17u);

enum class ParameterGroup {
    root,
    filmBreath,
    filmBreathAdvanced,
    gateWeave,
    gateWeaveAdvanced,
    filmDamage,
    filmDamageAdvanced,
};

struct ParameterPresentation final {
    const char* label;
    const char* hint;
    ParameterGroup group;
    double increment;
    int digits;
};

inline constexpr std::array<ParameterPresentation, 17> kBasePresentations{{
    {"Variation",
     "Changes the deterministic movement and material pattern while keeping the same settings.",
     ParameterGroup::root,
     1.0,
     0},
    {"Enabled",
     "Enables Film Breath exposure, tonal, and color movement.",
     ParameterGroup::filmBreath,
     1.0,
     0},
    {"Amount",
     "Sets the overall Film Breath strength.",
     ParameterGroup::filmBreath,
     0.01,
     2},
    {"Enabled",
     "Enables mechanical frame movement. If CinePrint35 Gate Wv is active, leave one Gate Weave treatment off.",
     ParameterGroup::gateWeave,
     1.0,
     0},
    {"Amount",
     "Sets the overall Gate Weave strength.",
     ParameterGroup::gateWeave,
     0.01,
     2},
    {"Horizontal Movement",
     "Sets horizontal travel as a fraction of the frame's short axis.",
     ParameterGroup::gateWeaveAdvanced,
     0.001,
     4},
    {"Vertical Movement",
     "Sets vertical travel as a fraction of the frame's short axis.",
     ParameterGroup::gateWeaveAdvanced,
     0.001,
     4},
    {"Rotation",
     "Sets the maximum clockwise rotation in degrees.",
     ParameterGroup::gateWeaveAdvanced,
     0.05,
     2},
    {"Cadence",
     "Sets Gate Weave movement cycles per second.",
     ParameterGroup::gateWeaveAdvanced,
     0.1,
     2},
    {"Instability",
     "Adds deterministic frame-to-frame variation to the smooth movement.",
     ParameterGroup::gateWeaveAdvanced,
     0.01,
     2},
    {"Enabled",
     "Enables the Film Damage material families below.",
     ParameterGroup::filmDamage,
     1.0,
     0},
    {"Amount",
     "Sets the shared strength of enabled Film Damage families.",
     ParameterGroup::filmDamage,
     0.01,
     2},
    {"Dust",
     "Adds dark-weighted dust. If CinePrint35 uses Resolve Film Damage dust, leave one Dust treatment off.",
     ParameterGroup::filmDamageAdvanced,
     0.01,
     2},
    {"Scratches",
     "Adds broken, persistent film scratches.",
     ParameterGroup::filmDamageAdvanced,
     0.01,
     2},
    {"Fibers",
     "Adds persistent fibers and hair-like marks.",
     ParameterGroup::filmDamageAdvanced,
     0.01,
     2},
    {"Stains",
     "Adds broad, slowly changing film-surface stains.",
     ParameterGroup::filmDamageAdvanced,
     0.01,
     2},
    {"Gate Wear",
     "Adds broken wear along the left and right gate edges.",
     ParameterGroup::filmDamageAdvanced,
     0.01,
     2},
}};

inline constexpr std::array<ParameterPresentation, 3>
    kFilmBreathResponsePresentations{{
        {"Exposure Response",
         "Controls how strongly Film Breath changes exposure.",
         ParameterGroup::filmBreathAdvanced,
         0.01,
         2},
        {"Tonal Response",
         "Controls how strongly Film Breath changes tonal contrast.",
         ParameterGroup::filmBreathAdvanced,
         0.01,
         2},
        {"Color Response",
         "Controls how strongly Film Breath changes temperature and tint.",
         ParameterGroup::filmBreathAdvanced,
         0.01,
         2},
    }};

static_assert(
    kFilmBreathResponsePresentations.size() ==
    effects::film_breath::kFilmBreathParameterDescriptors.size());
static_assert(
    effects::film_breath::kFilmBreathParameterDescriptors[0].kind ==
    FilmtoneFinishParameterKind::real);
static_assert(
    effects::film_breath::kFilmBreathParameterDescriptors[1].kind ==
    FilmtoneFinishParameterKind::real);
static_assert(
    effects::film_breath::kFilmBreathParameterDescriptors[2].kind ==
    FilmtoneFinishParameterKind::real);

struct ParameterGroups final {
    OFX::GroupParamDescriptor* filmBreath;
    OFX::GroupParamDescriptor* filmBreathAdvanced;
    OFX::GroupParamDescriptor* gateWeave;
    OFX::GroupParamDescriptor* gateWeaveAdvanced;
    OFX::GroupParamDescriptor* filmDamage;
    OFX::GroupParamDescriptor* filmDamageAdvanced;
};

const FilmtoneFinishParameterDefinitionV1& definition(
    std::size_t index) noexcept {
    return kFilmtoneFinishParameterDefinitions[index];
}

OFX::GroupParamDescriptor* groupFor(
    ParameterGroup group,
    const ParameterGroups& groups) noexcept {
    switch (group) {
        case ParameterGroup::root:
            return nullptr;
        case ParameterGroup::filmBreath:
            return groups.filmBreath;
        case ParameterGroup::filmBreathAdvanced:
            return groups.filmBreathAdvanced;
        case ParameterGroup::gateWeave:
            return groups.gateWeave;
        case ParameterGroup::gateWeaveAdvanced:
            return groups.gateWeaveAdvanced;
        case ParameterGroup::filmDamage:
            return groups.filmDamage;
        case ParameterGroup::filmDamageAdvanced:
            return groups.filmDamageAdvanced;
    }
    return nullptr;
}

void configureValueDescriptor(
    OFX::ValueParamDescriptor& descriptor,
    const char* id,
    const ParameterPresentation& presentation,
    OFX::GroupParamDescriptor* parent) {
    descriptor.setLabels(
        presentation.label,
        presentation.label,
        presentation.label);
    descriptor.setScriptName(id);
    descriptor.setHint(presentation.hint);
    descriptor.setAnimates(true);
    descriptor.setIsPersistant(true);
    descriptor.setEvaluateOnChange(true);
    if (parent != nullptr) {
        descriptor.setParent(*parent);
    }
}

OFX::ParamDescriptor* defineBaseParameter(
    OFX::ImageEffectDescriptor& descriptor,
    std::size_t index,
    const ParameterGroups& groups) {
    const auto& value = definition(index);
    const auto& presentation = kBasePresentations[index];
    OFX::GroupParamDescriptor* parent = groupFor(presentation.group, groups);

    switch (value.kind) {
        case FilmtoneFinishParameterKind::boolean: {
            OFX::BooleanParamDescriptor* parameter =
                descriptor.defineBooleanParam(value.id);
            parameter->setDefault(value.defaultValue != 0.0);
            configureValueDescriptor(*parameter, value.id, presentation, parent);
            return parameter;
        }
        case FilmtoneFinishParameterKind::real: {
            OFX::DoubleParamDescriptor* parameter =
                descriptor.defineDoubleParam(value.id);
            parameter->setDefault(value.defaultValue);
            parameter->setRange(value.minValue, value.maxValue);
            parameter->setDisplayRange(value.minValue, value.maxValue);
            parameter->setIncrement(presentation.increment);
            parameter->setDigits(presentation.digits);
            parameter->setDoubleType(OFX::eDoubleTypePlain);
            configureValueDescriptor(*parameter, value.id, presentation, parent);
            return parameter;
        }
        case FilmtoneFinishParameterKind::integer: {
            OFX::IntParamDescriptor* parameter =
                descriptor.defineIntParam(value.id);
            parameter->setDefault(static_cast<int>(value.defaultValue));
            parameter->setRange(
                static_cast<int>(value.minValue),
                static_cast<int>(value.maxValue));
            parameter->setDisplayRange(
                static_cast<int>(value.minValue),
                static_cast<int>(value.maxValue));
            configureValueDescriptor(*parameter, value.id, presentation, parent);
            return parameter;
        }
    }
    return nullptr;
}

OFX::DoubleParamDescriptor* defineFilmBreathResponseParameter(
    OFX::ImageEffectDescriptor& descriptor,
    std::size_t index,
    const ParameterPresentation& presentation,
    OFX::GroupParamDescriptor& parent) {
    const auto& value =
        effects::film_breath::kFilmBreathParameterDescriptors[index];
    OFX::DoubleParamDescriptor* parameter =
        descriptor.defineDoubleParam(value.id);
    parameter->setDefault(value.defaultValue);
    parameter->setRange(value.minValue, value.maxValue);
    parameter->setDisplayRange(value.minValue, value.maxValue);
    parameter->setIncrement(presentation.increment);
    parameter->setDigits(presentation.digits);
    parameter->setDoubleType(OFX::eDoubleTypePlain);
    configureValueDescriptor(*parameter, value.id, presentation, &parent);
    return parameter;
}

double readFiniteReal(
    OFX::DoubleParam& parameter,
    const FilmtoneFinishParameterDefinitionV1& metadata,
    double time) {
    const double value = parameter.getValueAtTime(time);
    if (!std::isfinite(value)) {
        return metadata.defaultValue;
    }
    return std::clamp(value, metadata.minValue, metadata.maxValue);
}

double readFiniteFilmBreathResponse(
    OFX::DoubleParam& parameter,
    std::size_t index,
    double time) {
    const auto& metadata =
        effects::film_breath::kFilmBreathParameterDescriptors[index];
    const double value = parameter.getValueAtTime(time);
    if (!std::isfinite(value)) {
        return metadata.defaultValue;
    }
    return std::clamp(value, metadata.minValue, metadata.maxValue);
}

std::uint32_t readVariation(OFX::IntParam& parameter, double time) {
    const auto& metadata = definition(kVariation);
    const int value = parameter.getValueAtTime(time);
    const int minimum = static_cast<int>(metadata.minValue);
    const int maximum = static_cast<int>(metadata.maxValue);
    return static_cast<std::uint32_t>(std::clamp(value, minimum, maximum));
}

bool isPositiveFinite(double value) noexcept {
    return std::isfinite(value) && value > 0.0;
}

}  // namespace

void describeFilmtoneParameters(OFX::ImageEffectDescriptor& descriptor) {
    OFX::PageParamDescriptor* page = descriptor.definePageParam(
        "com.chibatakumi.filmtone.resolve.page.controls");
    page->setLabels("Controls", "Controls", "Controls");

    OFX::GroupParamDescriptor* filmBreath = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.resolve.group.filmBreath");
    filmBreath->setLabels("Film Breath", "Film Breath", "Film Breath");
    filmBreath->setHint(
        "Deterministic exposure, tonal, and color movement using the established Filmtone cadence.");
    filmBreath->setOpen(true);

    OFX::GroupParamDescriptor* filmBreathAdvanced =
        descriptor.defineGroupParam(
            "com.chibatakumi.filmtone.resolve.group.filmBreath.advanced");
    filmBreathAdvanced->setLabels("Advanced", "Advanced", "Advanced");
    filmBreathAdvanced->setHint(
        "Attenuates Film Breath response components without changing cadence.");
    filmBreathAdvanced->setParent(*filmBreath);
    filmBreathAdvanced->setOpen(false);

    OFX::GroupParamDescriptor* gateWeave = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.resolve.group.gateWeave");
    gateWeave->setLabels("Gate Weave", "Gate Weave", "Gate Weave");
    gateWeave->setHint(
        "Mechanical image movement with constant automatic edge safety.");
    gateWeave->setOpen(true);

    OFX::GroupParamDescriptor* gateWeaveAdvanced =
        descriptor.defineGroupParam(
            "com.chibatakumi.filmtone.resolve.group.gateWeave.advanced");
    gateWeaveAdvanced->setLabels("Advanced", "Advanced", "Advanced");
    gateWeaveAdvanced->setHint(
        "Movement range, rotation, cadence, and deterministic instability.");
    gateWeaveAdvanced->setParent(*gateWeave);
    gateWeaveAdvanced->setOpen(false);

    OFX::GroupParamDescriptor* filmDamage = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.resolve.group.filmDamage");
    filmDamage->setLabels("Film Damage", "Film Damage", "Film Damage");
    filmDamage->setHint(
        "Dark-weighted dust, scratches, fibers, stains, and gate wear.");
    filmDamage->setOpen(true);

    OFX::GroupParamDescriptor* filmDamageAdvanced =
        descriptor.defineGroupParam(
            "com.chibatakumi.filmtone.resolve.group.filmDamage.advanced");
    filmDamageAdvanced->setLabels("Advanced", "Advanced", "Advanced");
    filmDamageAdvanced->setHint(
        "Independent Film Damage material-family strengths.");
    filmDamageAdvanced->setParent(*filmDamage);
    filmDamageAdvanced->setOpen(false);

    const ParameterGroups groups{
        filmBreath,
        filmBreathAdvanced,
        gateWeave,
        gateWeaveAdvanced,
        filmDamage,
        filmDamageAdvanced,
    };

    const auto addBaseParameter = [&](std::size_t index) {
        OFX::ParamDescriptor* parameter =
            defineBaseParameter(descriptor, index, groups);
        if (parameter != nullptr) {
            page->addChild(*parameter);
        }
    };

    addBaseParameter(kVariation);
    addBaseParameter(kFilmBreathEnabled);
    addBaseParameter(kFilmBreathAmount);
    for (std::size_t index = 0u;
         index < kFilmBreathResponsePresentations.size();
         ++index) {
        page->addChild(*defineFilmBreathResponseParameter(
            descriptor,
            index,
            kFilmBreathResponsePresentations[index],
            *filmBreathAdvanced));
    }
    for (std::size_t index = kGateWeaveEnabled;
         index <= kGateWeaveJitter;
         ++index) {
        addBaseParameter(index);
    }
    for (std::size_t index = kFilmDamageEnabled;
         index <= kGateWearAmount;
         ++index) {
        addBaseParameter(index);
    }

    // Read-only License status, derived from the license file (not persisted).
    OFX::GroupParamDescriptor* license = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.resolve.group.license");
    license->setLabels("License", "License", "License");
    license->setHint(
        "Current license state. Place Filmtone.license in "
        "~/Library/Application Support/Filmtone/ to remove the trial watermark.");
    license->setOpen(true);

    OFX::StringParamDescriptor* licenseStatus =
        descriptor.defineStringParam(kLicenseStatusParamId);
    licenseStatus->setLabels("Status", "Status", "Status");
    licenseStatus->setStringType(OFX::eStringTypeLabel);
    licenseStatus->setDefault("Trial mode (watermarked)");
    licenseStatus->setHint("Current Filmtone license state.");
    licenseStatus->setEnabled(false);
    licenseStatus->setIsPersistant(false);
    licenseStatus->setAnimates(false);
    licenseStatus->setEvaluateOnChange(false);
    licenseStatus->setParent(*license);
    page->addChild(*licenseStatus);
}

FilmtoneParameterSet::FilmtoneParameterSet(
    OFX::ImageEffect& effect)
    : licenseStatus_(effect.fetchStringParam(kLicenseStatusParamId)),
      variation_(effect.fetchIntParam(definition(kVariation).id)),
      filmBreathEnabled_(
          effect.fetchBooleanParam(definition(kFilmBreathEnabled).id)),
      filmBreathAmount_(
          effect.fetchDoubleParam(definition(kFilmBreathAmount).id)),
      filmBreathExposureResponse_(effect.fetchDoubleParam(
          effects::film_breath::kFilmBreathExposureResponseParameterId)),
      filmBreathTonalResponse_(effect.fetchDoubleParam(
          effects::film_breath::kFilmBreathTonalResponseParameterId)),
      filmBreathColorResponse_(effect.fetchDoubleParam(
          effects::film_breath::kFilmBreathColorResponseParameterId)),
      gateWeaveEnabled_(
          effect.fetchBooleanParam(definition(kGateWeaveEnabled).id)),
      gateWeaveAmount_(
          effect.fetchDoubleParam(definition(kGateWeaveAmount).id)),
      gateWeaveHorizontalAmplitude_(effect.fetchDoubleParam(
          definition(kGateWeaveHorizontalAmplitude).id)),
      gateWeaveVerticalAmplitude_(effect.fetchDoubleParam(
          definition(kGateWeaveVerticalAmplitude).id)),
      gateWeaveRotationAmplitudeDegrees_(effect.fetchDoubleParam(
          definition(kGateWeaveRotationAmplitudeDegrees).id)),
      gateWeaveFrequency_(
          effect.fetchDoubleParam(definition(kGateWeaveFrequency).id)),
      gateWeaveJitter_(
          effect.fetchDoubleParam(definition(kGateWeaveJitter).id)),
      filmDamageEnabled_(
          effect.fetchBooleanParam(definition(kFilmDamageEnabled).id)),
      filmDamageAmount_(
          effect.fetchDoubleParam(definition(kFilmDamageAmount).id)),
      dustAmount_(effect.fetchDoubleParam(definition(kDustAmount).id)),
      scratchAmount_(effect.fetchDoubleParam(definition(kScratchAmount).id)),
      fiberAmount_(effect.fetchDoubleParam(definition(kFiberAmount).id)),
      stainAmount_(effect.fetchDoubleParam(definition(kStainAmount).id)),
      gateWearAmount_(effect.fetchDoubleParam(definition(kGateWearAmount).id)) {}

EvaluatedFilmtoneParameters FilmtoneParameterSet::evaluate(
    double time) const {
    EvaluatedFilmtoneParameters result{};
    auto& mapping = result.filmBreath.mapping;
    mapping.variation = readVariation(*variation_, time);
    mapping.filmBreathEnabled =
        filmBreathEnabled_->getValueAtTime(time) ? 1u : 0u;
    mapping.filmBreathAmount = static_cast<float>(readFiniteReal(
        *filmBreathAmount_, definition(kFilmBreathAmount), time));
    mapping.gateWeaveEnabled =
        gateWeaveEnabled_->getValueAtTime(time) ? 1u : 0u;
    mapping.gateWeaveAmount = static_cast<float>(readFiniteReal(
        *gateWeaveAmount_, definition(kGateWeaveAmount), time));
    mapping.gateWeaveHorizontalAmplitude = static_cast<float>(readFiniteReal(
        *gateWeaveHorizontalAmplitude_,
        definition(kGateWeaveHorizontalAmplitude),
        time));
    mapping.gateWeaveVerticalAmplitude = static_cast<float>(readFiniteReal(
        *gateWeaveVerticalAmplitude_,
        definition(kGateWeaveVerticalAmplitude),
        time));
    mapping.gateWeaveRotationAmplitudeDegrees = static_cast<float>(
        readFiniteReal(
            *gateWeaveRotationAmplitudeDegrees_,
            definition(kGateWeaveRotationAmplitudeDegrees),
            time));
    mapping.gateWeaveFrequency = static_cast<float>(readFiniteReal(
        *gateWeaveFrequency_, definition(kGateWeaveFrequency), time));
    mapping.gateWeaveJitter = static_cast<float>(readFiniteReal(
        *gateWeaveJitter_, definition(kGateWeaveJitter), time));
    mapping.filmDamageEnabled =
        filmDamageEnabled_->getValueAtTime(time) ? 1u : 0u;
    mapping.filmDamageAmount = static_cast<float>(readFiniteReal(
        *filmDamageAmount_, definition(kFilmDamageAmount), time));
    mapping.dustAmount = static_cast<float>(readFiniteReal(
        *dustAmount_, definition(kDustAmount), time));
    mapping.scratchAmount = static_cast<float>(readFiniteReal(
        *scratchAmount_, definition(kScratchAmount), time));
    mapping.fiberAmount = static_cast<float>(readFiniteReal(
        *fiberAmount_, definition(kFiberAmount), time));
    mapping.stainAmount = static_cast<float>(readFiniteReal(
        *stainAmount_, definition(kStainAmount), time));
    mapping.gateWearAmount = static_cast<float>(readFiniteReal(
        *gateWearAmount_, definition(kGateWearAmount), time));

    result.filmBreath.exposureResponse = readFiniteFilmBreathResponse(
        *filmBreathExposureResponse_, 0u, time);
    result.filmBreath.tonalResponse = readFiniteFilmBreathResponse(
        *filmBreathTonalResponse_, 1u, time);
    result.filmBreath.colorResponse = readFiniteFilmBreathResponse(
        *filmBreathColorResponse_, 2u, time);
    return result;
}

void FilmtoneParameterSet::updateLicenseStatus() const {
    const license::LicenseState state = license::LicenseStore::shared().evaluate();
    licenseStatus_->setValue(state.statusLine());
}

std::optional<host::FrameRates> resolveFrameRates(
    double sourceFrameRate,
    double timelineFrameRate) noexcept {
    const bool hasSource = isPositiveFinite(sourceFrameRate);
    const bool hasTimeline = isPositiveFinite(timelineFrameRate);
    if (!hasSource && !hasTimeline) {
        return std::nullopt;
    }
    return host::FrameRates{
        hasSource ? sourceFrameRate : timelineFrameRate,
        hasTimeline ? timelineFrameRate : sourceFrameRate,
    };
}

}  // namespace filmtone::resolve::integration
