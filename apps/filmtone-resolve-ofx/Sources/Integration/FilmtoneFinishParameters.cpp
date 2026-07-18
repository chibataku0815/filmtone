#include "FilmtoneFinishParameters.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <string_view>

namespace filmtone::resolve::integration {
namespace {

using forestone::filmtone::FilmtoneFinishParameterDefinitionV1;
using forestone::filmtone::FilmtoneFinishParameterKind;
using forestone::filmtone::kFilmtoneFinishParameterDefinitions;
using spatial::FilmtoneSpatialParameterDefinitionV1;
using spatial::FilmtoneSpatialParameterKindV1;
using spatial::kFilmtoneNodeRoleDefinitionsV1;
using spatial::kFilmtoneSpatialFeatureDefinitionsV1;
using spatial::kFilmtoneSpatialParameterDefinitionsV1;

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

enum SpatialParameterIndex : std::size_t {
    kNodeRole = 0u,
    kDeepGlowEnabled = 1u,
    kBloomStrength = 2u,
    kBloomThreshold = 3u,
    kBloomRadius = 4u,
    kBloomSoftKnee = 5u,
    kPeripheralChromaticShiftEnabled = 6u,
    kRgbShift = 7u,
    kLensSoftnessEnabled = 8u,
    kLensSoftness = 9u,
    kTextureSoftnessEnabled = 10u,
    kDetailSoftness = 11u,
    kVignetteEnabled = 12u,
    kVignette = 13u,
};

static_assert(kFilmtoneSpatialParameterDefinitionsV1.size() == 14u);
static_assert(kFilmtoneNodeRoleDefinitionsV1.size() == 3u);
static_assert(kFilmtoneSpatialFeatureDefinitionsV1.size() == 5u);
static_assert(std::string_view(
    kFilmtoneSpatialParameterDefinitionsV1[kNodeRole].memberName) ==
    "nodeRole");
static_assert(std::string_view(
    kFilmtoneSpatialParameterDefinitionsV1[kBloomStrength].memberName) ==
    "bloomStrength");
static_assert(std::string_view(
    kFilmtoneSpatialParameterDefinitionsV1[kRgbShift].memberName) ==
    "rgbShift");
static_assert(std::string_view(
    kFilmtoneSpatialParameterDefinitionsV1[kLensSoftness].memberName) ==
    "lensSoftness");
static_assert(std::string_view(
    kFilmtoneSpatialParameterDefinitionsV1[kDetailSoftness].memberName) ==
    "detailSoftness");
static_assert(std::string_view(
    kFilmtoneSpatialParameterDefinitionsV1[kVignette].memberName) ==
    "vignette");

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

struct SpatialParameterPresentation final {
    const char* hint;
    double increment;
    int digits;
};

inline constexpr std::array<SpatialParameterPresentation, 14>
    kSpatialPresentations{{
        {"Chooses whether this node runs the complete graph, spatial optics only, or the three film modules only.",
         1.0,
         0},
        {"Enables Deep Glow without changing its stored settings.", 1.0, 0},
        {"Sets highlight glow energy.", 0.01, 2},
        {"Sets the highlight level where glow begins.", 0.01, 2},
        {"Distributes glow from a tighter core toward broader scales.", 0.01, 2},
        {"Softens the transition around the glow threshold.", 0.01, 2},
        {"Enables Peripheral Chromatic Shift without changing its stored setting.",
         1.0,
         0},
        {"Sets restrained radial red and blue separation toward the image perimeter.",
         0.0001,
         4},
        {"Enables Lens Softness without changing its stored setting.", 1.0, 0},
        {"Sets peripheral optical softness while keeping the image center coherent.",
         0.01,
         2},
        {"Enables Texture Softness without changing its stored setting.", 1.0, 0},
        {"Relaxes fine digital acutance without applying a lens blur.", 0.01, 2},
        {"Enables Vignette without changing its stored setting.", 1.0, 0},
        {"Sets smooth off-axis RGB attenuation while preserving source alpha.",
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

struct SpatialParameterGroups final {
    OFX::GroupParamDescriptor* deepGlow;
    OFX::GroupParamDescriptor* peripheralChromaticShift;
    OFX::GroupParamDescriptor* lensSoftness;
    OFX::GroupParamDescriptor* textureSoftness;
    OFX::GroupParamDescriptor* vignette;
};

const FilmtoneFinishParameterDefinitionV1& definition(
    std::size_t index) noexcept {
    return kFilmtoneFinishParameterDefinitions[index];
}

const FilmtoneSpatialParameterDefinitionV1& spatialDefinition(
    std::size_t index) noexcept {
    return kFilmtoneSpatialParameterDefinitionsV1[index];
}

OFX::GroupParamDescriptor* spatialGroupFor(
    std::size_t index,
    const SpatialParameterGroups& groups) noexcept {
    if (index >= kDeepGlowEnabled && index <= kBloomSoftKnee) {
        return groups.deepGlow;
    }
    if (index >= kPeripheralChromaticShiftEnabled && index <= kRgbShift) {
        return groups.peripheralChromaticShift;
    }
    if (index >= kLensSoftnessEnabled && index <= kLensSoftness) {
        return groups.lensSoftness;
    }
    if (index >= kTextureSoftnessEnabled && index <= kDetailSoftness) {
        return groups.textureSoftness;
    }
    if (index >= kVignetteEnabled && index <= kVignette) {
        return groups.vignette;
    }
    return nullptr;
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

void configureSpatialValueDescriptor(
    OFX::ValueParamDescriptor& descriptor,
    const FilmtoneSpatialParameterDefinitionV1& metadata,
    const SpatialParameterPresentation& presentation,
    OFX::GroupParamDescriptor* parent) {
    descriptor.setLabels(metadata.label, metadata.label, metadata.label);
    descriptor.setScriptName(metadata.id);
    descriptor.setHint(presentation.hint);
    descriptor.setAnimates(true);
    descriptor.setIsPersistant(true);
    descriptor.setEvaluateOnChange(true);
    if (parent != nullptr) {
        descriptor.setParent(*parent);
    }
}

OFX::ParamDescriptor* defineSpatialParameter(
    OFX::ImageEffectDescriptor& descriptor,
    std::size_t index,
    const SpatialParameterGroups& groups) {
    const auto& metadata = spatialDefinition(index);
    const auto& presentation = kSpatialPresentations[index];
    OFX::GroupParamDescriptor* parent = spatialGroupFor(index, groups);

    switch (metadata.kind) {
        case FilmtoneSpatialParameterKindV1::boolean: {
            OFX::BooleanParamDescriptor* parameter =
                descriptor.defineBooleanParam(metadata.id);
            parameter->setDefault(metadata.defaultValue != 0.0);
            configureSpatialValueDescriptor(
                *parameter,
                metadata,
                presentation,
                parent);
            return parameter;
        }
        case FilmtoneSpatialParameterKindV1::real: {
            OFX::DoubleParamDescriptor* parameter =
                descriptor.defineDoubleParam(metadata.id);
            parameter->setDefault(metadata.defaultValue);
            parameter->setRange(metadata.minValue, metadata.maxValue);
            parameter->setDisplayRange(metadata.minValue, metadata.maxValue);
            parameter->setIncrement(presentation.increment);
            parameter->setDigits(presentation.digits);
            parameter->setDoubleType(OFX::eDoubleTypePlain);
            configureSpatialValueDescriptor(
                *parameter,
                metadata,
                presentation,
                parent);
            return parameter;
        }
        case FilmtoneSpatialParameterKindV1::choice: {
            OFX::ChoiceParamDescriptor* parameter =
                descriptor.defineChoiceParam(metadata.id);
            parameter->setDefault(static_cast<int>(metadata.defaultValue));
            for (const auto& role : kFilmtoneNodeRoleDefinitionsV1) {
                parameter->appendOption(role.label);
            }
            configureSpatialValueDescriptor(
                *parameter,
                metadata,
                presentation,
                parent);
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

std::uint32_t readSpatialChoice(
    OFX::ChoiceParam& parameter,
    const FilmtoneSpatialParameterDefinitionV1& metadata,
    double time) {
    int value = static_cast<int>(metadata.defaultValue);
    parameter.getValueAtTime(time, value);
    if (value < static_cast<int>(metadata.minValue) ||
        value > static_cast<int>(metadata.maxValue)) {
        value = static_cast<int>(metadata.defaultValue);
    }
    return static_cast<std::uint32_t>(value);
}

float readSpatialReal(
    OFX::DoubleParam& parameter,
    const FilmtoneSpatialParameterDefinitionV1& metadata,
    double time) {
    const double value = parameter.getValueAtTime(time);
    const double normalized = std::isfinite(value)
        ? std::clamp(value, metadata.minValue, metadata.maxValue)
        : metadata.defaultValue;
    return static_cast<float>(normalized);
}

bool isPositiveFinite(double value) noexcept {
    return std::isfinite(value) && value > 0.0;
}

}  // namespace

void describeFilmtoneFinishParameters(OFX::ImageEffectDescriptor& descriptor) {
    OFX::PageParamDescriptor* page = descriptor.definePageParam(
        "com.chibatakumi.filmtone.finish.page.controls");
    page->setLabels("Controls", "Controls", "Controls");

    const auto defineSpatialGroup = [&descriptor](
        std::size_t featureIndex,
        std::size_t firstParameterIndex,
        const char* hint) {
        const auto& feature = kFilmtoneSpatialFeatureDefinitionsV1[featureIndex];
        OFX::GroupParamDescriptor* group = descriptor.defineGroupParam(
            spatialDefinition(firstParameterIndex).groupId);
        group->setLabels(feature.label, feature.label, feature.label);
        group->setHint(hint);
        group->setOpen(false);
        return group;
    };

    OFX::GroupParamDescriptor* deepGlow = defineSpatialGroup(
        0u,
        kDeepGlowEnabled,
        "Highlight-selective, multi-scale glow with controlled energy.");
    OFX::GroupParamDescriptor* peripheralChromaticShift = defineSpatialGroup(
        1u,
        kPeripheralChromaticShiftEnabled,
        "Restrained radial red and blue separation toward the image perimeter.");
    OFX::GroupParamDescriptor* lensSoftness = defineSpatialGroup(
        2u,
        kLensSoftnessEnabled,
        "Field-weighted optical softness that keeps the image center coherent.");
    OFX::GroupParamDescriptor* textureSoftness = defineSpatialGroup(
        3u,
        kTextureSoftnessEnabled,
        "Edge-aware attenuation of fine digital acutance across the frame.");
    OFX::GroupParamDescriptor* vignette = defineSpatialGroup(
        4u,
        kVignetteEnabled,
        "Smooth aspect-aware attenuation from the image center toward the perimeter.");

    const SpatialParameterGroups spatialGroups{
        deepGlow,
        peripheralChromaticShift,
        lensSoftness,
        textureSoftness,
        vignette,
    };

    OFX::GroupParamDescriptor* filmBreath = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.finish.group.filmBreath");
    filmBreath->setLabels("Film Breath", "Film Breath", "Film Breath");
    filmBreath->setHint(
        "Deterministic exposure, tonal, and color movement using the established Filmtone cadence.");
    filmBreath->setOpen(true);

    OFX::GroupParamDescriptor* filmBreathAdvanced =
        descriptor.defineGroupParam(
            "com.chibatakumi.filmtone.finish.group.filmBreath.advanced");
    filmBreathAdvanced->setLabels("Advanced", "Advanced", "Advanced");
    filmBreathAdvanced->setHint(
        "Attenuates Film Breath response components without changing cadence.");
    filmBreathAdvanced->setParent(*filmBreath);
    filmBreathAdvanced->setOpen(false);

    OFX::GroupParamDescriptor* gateWeave = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.finish.group.gateWeave");
    gateWeave->setLabels("Gate Weave", "Gate Weave", "Gate Weave");
    gateWeave->setHint(
        "Mechanical image movement with constant automatic edge safety.");
    gateWeave->setOpen(true);

    OFX::GroupParamDescriptor* gateWeaveAdvanced =
        descriptor.defineGroupParam(
            "com.chibatakumi.filmtone.finish.group.gateWeave.advanced");
    gateWeaveAdvanced->setLabels("Advanced", "Advanced", "Advanced");
    gateWeaveAdvanced->setHint(
        "Movement range, rotation, cadence, and deterministic instability.");
    gateWeaveAdvanced->setParent(*gateWeave);
    gateWeaveAdvanced->setOpen(false);

    OFX::GroupParamDescriptor* filmDamage = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.finish.group.filmDamage");
    filmDamage->setLabels("Film Damage", "Film Damage", "Film Damage");
    filmDamage->setHint(
        "Dark-weighted dust, scratches, fibers, stains, and gate wear.");
    filmDamage->setOpen(true);

    OFX::GroupParamDescriptor* filmDamageAdvanced =
        descriptor.defineGroupParam(
            "com.chibatakumi.filmtone.finish.group.filmDamage.advanced");
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

    const auto addSpatialParameter = [&](std::size_t index) {
        OFX::ParamDescriptor* parameter =
            defineSpatialParameter(descriptor, index, spatialGroups);
        if (parameter != nullptr) {
            page->addChild(*parameter);
        }
    };

    for (std::size_t index = kNodeRole;
         index < kFilmtoneSpatialParameterDefinitionsV1.size();
         ++index) {
        addSpatialParameter(index);
    }

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
}

FilmtoneFinishParameterSet::FilmtoneFinishParameterSet(
    OFX::ImageEffect& effect)
    : nodeRole_(effect.fetchChoiceParam(spatialDefinition(kNodeRole).id)),
      deepGlowEnabled_(effect.fetchBooleanParam(
          spatialDefinition(kDeepGlowEnabled).id)),
      bloomStrength_(effect.fetchDoubleParam(
          spatialDefinition(kBloomStrength).id)),
      bloomThreshold_(effect.fetchDoubleParam(
          spatialDefinition(kBloomThreshold).id)),
      bloomRadius_(effect.fetchDoubleParam(
          spatialDefinition(kBloomRadius).id)),
      bloomSoftKnee_(effect.fetchDoubleParam(
          spatialDefinition(kBloomSoftKnee).id)),
      peripheralChromaticShiftEnabled_(effect.fetchBooleanParam(
          spatialDefinition(kPeripheralChromaticShiftEnabled).id)),
      rgbShift_(effect.fetchDoubleParam(spatialDefinition(kRgbShift).id)),
      lensSoftnessEnabled_(effect.fetchBooleanParam(
          spatialDefinition(kLensSoftnessEnabled).id)),
      lensSoftness_(effect.fetchDoubleParam(
          spatialDefinition(kLensSoftness).id)),
      textureSoftnessEnabled_(effect.fetchBooleanParam(
          spatialDefinition(kTextureSoftnessEnabled).id)),
      detailSoftness_(effect.fetchDoubleParam(
          spatialDefinition(kDetailSoftness).id)),
      vignetteEnabled_(effect.fetchBooleanParam(
          spatialDefinition(kVignetteEnabled).id)),
      vignette_(effect.fetchDoubleParam(spatialDefinition(kVignette).id)),
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

EvaluatedFilmtoneFinishParameters FilmtoneFinishParameterSet::evaluate(
    double time) const {
    EvaluatedFilmtoneFinishParameters result{};
    result.spatial.nodeRole = readSpatialChoice(
        *nodeRole_,
        spatialDefinition(kNodeRole),
        time);
    result.spatial.deepGlowEnabled =
        deepGlowEnabled_->getValueAtTime(time) ? 1u : 0u;
    result.spatial.bloomStrength = readSpatialReal(
        *bloomStrength_, spatialDefinition(kBloomStrength), time);
    result.spatial.bloomThreshold = readSpatialReal(
        *bloomThreshold_, spatialDefinition(kBloomThreshold), time);
    result.spatial.bloomRadius = readSpatialReal(
        *bloomRadius_, spatialDefinition(kBloomRadius), time);
    result.spatial.bloomSoftKnee = readSpatialReal(
        *bloomSoftKnee_, spatialDefinition(kBloomSoftKnee), time);
    result.spatial.peripheralChromaticShiftEnabled =
        peripheralChromaticShiftEnabled_->getValueAtTime(time) ? 1u : 0u;
    result.spatial.rgbShift = readSpatialReal(
        *rgbShift_, spatialDefinition(kRgbShift), time);
    result.spatial.lensSoftnessEnabled =
        lensSoftnessEnabled_->getValueAtTime(time) ? 1u : 0u;
    result.spatial.lensSoftness = readSpatialReal(
        *lensSoftness_, spatialDefinition(kLensSoftness), time);
    result.spatial.textureSoftnessEnabled =
        textureSoftnessEnabled_->getValueAtTime(time) ? 1u : 0u;
    result.spatial.detailSoftness = readSpatialReal(
        *detailSoftness_, spatialDefinition(kDetailSoftness), time);
    result.spatial.vignetteEnabled =
        vignetteEnabled_->getValueAtTime(time) ? 1u : 0u;
    result.spatial.vignette = readSpatialReal(
        *vignette_, spatialDefinition(kVignette), time);

    auto& finish = result.filmBreath.finishParameters;
    finish.variation = readVariation(*variation_, time);
    finish.filmBreathEnabled =
        filmBreathEnabled_->getValueAtTime(time) ? 1u : 0u;
    finish.filmBreathAmount = static_cast<float>(readFiniteReal(
        *filmBreathAmount_, definition(kFilmBreathAmount), time));
    finish.gateWeaveEnabled =
        gateWeaveEnabled_->getValueAtTime(time) ? 1u : 0u;
    finish.gateWeaveAmount = static_cast<float>(readFiniteReal(
        *gateWeaveAmount_, definition(kGateWeaveAmount), time));
    finish.gateWeaveHorizontalAmplitude = static_cast<float>(readFiniteReal(
        *gateWeaveHorizontalAmplitude_,
        definition(kGateWeaveHorizontalAmplitude),
        time));
    finish.gateWeaveVerticalAmplitude = static_cast<float>(readFiniteReal(
        *gateWeaveVerticalAmplitude_,
        definition(kGateWeaveVerticalAmplitude),
        time));
    finish.gateWeaveRotationAmplitudeDegrees = static_cast<float>(
        readFiniteReal(
            *gateWeaveRotationAmplitudeDegrees_,
            definition(kGateWeaveRotationAmplitudeDegrees),
            time));
    finish.gateWeaveFrequency = static_cast<float>(readFiniteReal(
        *gateWeaveFrequency_, definition(kGateWeaveFrequency), time));
    finish.gateWeaveJitter = static_cast<float>(readFiniteReal(
        *gateWeaveJitter_, definition(kGateWeaveJitter), time));
    finish.filmDamageEnabled =
        filmDamageEnabled_->getValueAtTime(time) ? 1u : 0u;
    finish.filmDamageAmount = static_cast<float>(readFiniteReal(
        *filmDamageAmount_, definition(kFilmDamageAmount), time));
    finish.dustAmount = static_cast<float>(readFiniteReal(
        *dustAmount_, definition(kDustAmount), time));
    finish.scratchAmount = static_cast<float>(readFiniteReal(
        *scratchAmount_, definition(kScratchAmount), time));
    finish.fiberAmount = static_cast<float>(readFiniteReal(
        *fiberAmount_, definition(kFiberAmount), time));
    finish.stainAmount = static_cast<float>(readFiniteReal(
        *stainAmount_, definition(kStainAmount), time));
    finish.gateWearAmount = static_cast<float>(readFiniteReal(
        *gateWearAmount_, definition(kGateWearAmount), time));

    result.filmBreath.exposureResponse = readFiniteFilmBreathResponse(
        *filmBreathExposureResponse_, 0u, time);
    result.filmBreath.tonalResponse = readFiniteFilmBreathResponse(
        *filmBreathTonalResponse_, 1u, time);
    result.filmBreath.colorResponse = readFiniteFilmBreathResponse(
        *filmBreathColorResponse_, 2u, time);
    return result;
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
