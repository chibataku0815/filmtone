#include "FilmtoneFinishParameters.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <string_view>

#include "FilmtoneResolveFactoryDefaults.h"

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

struct ParameterPresentation final {
    const char* label;
    const char* hint;
    double increment;
    int digits;
};

inline constexpr std::array<ParameterPresentation, 17> kBasePresentations{{
    {"Variation",
     "Changes the deterministic movement and material pattern while keeping the same settings.",
     1.0,
     0},
    {"Film Breath",
     "Turns Film Breath on or off without changing its stored controls.",
     1.0,
     0},
    {"Amount",
     "Sets the overall Film Breath strength.",
     0.01,
     2},
    {"Gate Weave",
     "Turns Gate Weave on or off without changing its stored controls.",
     1.0,
     0},
    {"Amount",
     "Sets the overall Gate Weave strength.",
     0.01,
     2},
    {"Horizontal Movement",
     "Sets horizontal travel as a fraction of the frame's short axis.",
     0.001,
     4},
    {"Vertical Movement",
     "Sets vertical travel as a fraction of the frame's short axis.",
     0.001,
     4},
    {"Rotation",
     "Sets the maximum clockwise rotation in degrees.",
     0.05,
     2},
    {"Cadence",
     "Sets the inverse correlation period: higher values make registration changes faster.",
     0.1,
     2},
    {"Instability",
     "Moves from smoothly correlated travel toward abrupt frame-to-frame registration changes.",
     0.01,
     2},
    {"Film Damage",
     "Turns Film Damage on or off without changing its stored controls.",
     1.0,
     0},
    {"Amount",
     "Sets the shared strength of enabled Film Damage families.",
     0.01,
     2},
    {"Dust",
     "Adds dark-weighted dust. If CinePrint35 uses Resolve Film Damage dust, leave one Dust treatment off.",
     0.01,
     2},
    {"Scratches",
     "Adds broken, persistent film scratches.",
     0.01,
     2},
    {"Fibers",
     "Adds persistent fibers and hair-like marks.",
     0.01,
     2},
    {"Stains",
     "Adds broad, slowly changing film-surface stains.",
     0.01,
     2},
    {"Gate Wear",
     "Adds broken wear along the left and right gate edges.",
     0.01,
     2},
}};

inline constexpr std::array<ParameterPresentation, 4>
    kFilmBreathPresentations{{
    {"Exposure Variation",
     "Sets the amplitude of frame-correlated Film Breath exposure changes.",
         0.01,
         2},
    {"Tonal Variation",
     "Sets the amplitude of frame-correlated Film Breath tonal changes.",
         0.01,
         2},
    {"Subtractive Color",
     "Sets the amplitude of frame-correlated subtractive CMY density variation.",
         0.01,
         2},
    {"Period (Frames)",
     "Sets the shared Film Breath period. Lower values change more quickly; higher values breathe over more frames.",
         1.0,
         0},
    }};

// labelOverride replaces the generated metadata label when non-null. The
// Quick Enable rows reuse the generated feature labels so the checkbox names
// stay identical to the detail-group names; Threshold Smooth renames the
// continuous quadratic threshold rolloff while its persistent softKnee ID is
// unchanged.
struct SpatialParameterPresentation final {
    const char* labelOverride;
    const char* hint;
    double increment;
    int digits;
};

inline constexpr std::array<SpatialParameterPresentation, 14>
    kSpatialPresentations{{
        {nullptr,
         "Chooses whether this node runs the complete graph, spatial optics only, or the three film modules only.",
         1.0,
         0},
        {kFilmtoneSpatialFeatureDefinitionsV1[0].label,
         "Turns Deep Glow on or off without changing its stored controls.",
         1.0,
         0},
        {nullptr,
         "Sets diffusion energy from a restrained highlight bloom to a pronounced glow.", 0.01, 2},
        {nullptr, "Sets the highlight level where glow begins.", 0.01, 2},
        {nullptr,
         "Moves glow from a tighter halo toward a broader light spread.", 0.01, 2},
        {"Threshold Smooth",
         "Softens the transition around the glow threshold.", 0.01, 2},
        {kFilmtoneSpatialFeatureDefinitionsV1[1].label,
         "Turns Peripheral Chromatic Shift on or off without changing its stored controls.",
         1.0,
         0},
        {nullptr,
         "Sets restrained radial red and blue separation toward the image perimeter.",
         0.0001,
         4},
        {kFilmtoneSpatialFeatureDefinitionsV1[2].label,
         "Turns Lens Softness on or off without changing its stored controls.",
         1.0,
         0},
        {nullptr,
         "Sets peripheral optical softness while keeping the image center coherent.",
         0.01,
         2},
        {kFilmtoneSpatialFeatureDefinitionsV1[3].label,
         "Turns Texture Softness on or off without changing its stored controls.",
         1.0,
         0},
        {nullptr,
         "Relaxes fine digital acutance, with stronger smoothing toward the top of the range.", 0.01, 2},
        {kFilmtoneSpatialFeatureDefinitionsV1[4].label,
         "Turns Vignette on or off without changing its stored controls.",
         1.0,
         0},
        {nullptr,
         "Sets a progressive off-axis light falloff while preserving source alpha.",
         0.01,
         2},
    }};

static_assert(
    kFilmBreathPresentations.size() ==
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
static_assert(
    effects::film_breath::kFilmBreathParameterDescriptors[3].kind ==
    FilmtoneFinishParameterKind::real);

constexpr const FilmtoneFinishParameterDefinitionV1& definition(
    std::size_t index) noexcept {
    return kFilmtoneFinishParameterDefinitions[index];
}

constexpr const FilmtoneSpatialParameterDefinitionV1& spatialDefinition(
    std::size_t index) noexcept {
    return kFilmtoneSpatialParameterDefinitionsV1[index];
}

// Every Resolve factory-default entry must target one existing real-kind
// persistent parameter and stay inside its accepted range. Enabled, Node
// Role, and Variation therefore cannot receive a Resolve override, which
// keeps the add-time and reset-time output exact identity.
constexpr bool resolveFactoryDefaultsMatchDefinitions() noexcept {
    for (const auto& entry : kFilmtoneResolveFactoryDefaults) {
        const std::string_view id{entry.id};
        bool matched = false;
        for (const auto& metadata : kFilmtoneSpatialParameterDefinitionsV1) {
            if (std::string_view(metadata.id) != id) {
                continue;
            }
            if (metadata.kind != FilmtoneSpatialParameterKindV1::real ||
                entry.value < metadata.minValue ||
                entry.value > metadata.maxValue) {
                return false;
            }
            matched = true;
            break;
        }
        for (const auto& metadata : kFilmtoneFinishParameterDefinitions) {
            if (matched || std::string_view(metadata.id) != id) {
                continue;
            }
            if (metadata.kind != FilmtoneFinishParameterKind::real ||
                entry.value < metadata.minValue ||
                entry.value > metadata.maxValue) {
                return false;
            }
            matched = true;
            break;
        }
        if (!matched) {
            return false;
        }
    }
    return true;
}

static_assert(resolveFactoryDefaultsMatchDefinitions());

// The Film Breath response and cadence descriptors are already Resolve-local
// and store the Resolve factory values directly; assert them instead of
// duplicating a second default source.
static_assert(
    effects::film_breath::kFilmBreathParameterDescriptors[0].defaultValue ==
    1.0);
static_assert(
    effects::film_breath::kFilmBreathParameterDescriptors[1].defaultValue ==
    1.0);
static_assert(
    effects::film_breath::kFilmBreathParameterDescriptors[2].defaultValue ==
    1.0);
static_assert(
    effects::film_breath::kFilmBreathParameterDescriptors[3].defaultValue ==
    24.0);

// Gate Weave keeps its accepted mechanical-trajectory defaults; the stored
// translation amplitudes and cadence must remain non-zero so enabling Gate
// Weave from Quick Enable moves the frame immediately.
static_assert(
    kFilmtoneFinishParameterDefinitions[kGateWeaveHorizontalAmplitude]
        .defaultValue > 0.0);
static_assert(
    kFilmtoneFinishParameterDefinitions[kGateWeaveVerticalAmplitude]
        .defaultValue > 0.0);
static_assert(
    kFilmtoneFinishParameterDefinitions[kGateWeaveFrequency].defaultValue >
    0.0);
static_assert(
    kFilmtoneFinishParameterDefinitions[kGateWeaveJitter].defaultValue > 0.0);

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
    OFX::GroupParamDescriptor* parent) {
    const auto& value = definition(index);
    const auto& presentation = kBasePresentations[index];

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
            parameter->setDefault(
                resolveFactoryDefault(value.id, value.defaultValue));
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
    const char* label = presentation.labelOverride != nullptr
        ? presentation.labelOverride
        : metadata.label;
    descriptor.setLabels(label, label, label);
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
    OFX::GroupParamDescriptor* parent) {
    const auto& metadata = spatialDefinition(index);
    const auto& presentation = kSpatialPresentations[index];

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
            parameter->setDefault(
                resolveFactoryDefault(metadata.id, metadata.defaultValue));
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

OFX::DoubleParamDescriptor* defineFilmBreathParameter(
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
        return resolveFactoryDefault(metadata.id, metadata.defaultValue);
    }
    return std::clamp(value, metadata.minValue, metadata.maxValue);
}

double readFiniteFilmBreathReal(
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
        : resolveFactoryDefault(metadata.id, metadata.defaultValue);
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

    const auto addSpatialParameter = [&](
        std::size_t index,
        OFX::GroupParamDescriptor* parent) {
        OFX::ParamDescriptor* parameter =
            defineSpatialParameter(descriptor, index, parent);
        if (parameter != nullptr) {
            page->addChild(*parameter);
        }
    };

    const auto addBaseParameter = [&](
        std::size_t index,
        OFX::GroupParamDescriptor* parent) {
        OFX::ParamDescriptor* parameter =
            defineBaseParameter(descriptor, index, parent);
        if (parameter != nullptr) {
            page->addChild(*parameter);
        }
    };

    // Resolve lays the inspector out in parameter-definition order, so the
    // definition sequence below is the authoritative page order: Node Role,
    // the always-open Quick Enable group holding every persistent Enabled
    // toggle, Variation, then one closed detail group per feature holding
    // only its stored adjustment controls.
    addSpatialParameter(kNodeRole, nullptr);

    OFX::GroupParamDescriptor* quickEnable = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.finish.group.quickEnable");
    quickEnable->setLabels("Quick Enable", "Quick Enable", "Quick Enable");
    quickEnable->setHint(
        "Turns individual Filmtone modules on or off without changing their stored controls.");
    quickEnable->setOpen(true);

    addSpatialParameter(kDeepGlowEnabled, quickEnable);
    addSpatialParameter(kPeripheralChromaticShiftEnabled, quickEnable);
    addSpatialParameter(kLensSoftnessEnabled, quickEnable);
    addSpatialParameter(kTextureSoftnessEnabled, quickEnable);
    addSpatialParameter(kVignetteEnabled, quickEnable);
    addBaseParameter(kFilmBreathEnabled, quickEnable);
    addBaseParameter(kGateWeaveEnabled, quickEnable);
    addBaseParameter(kFilmDamageEnabled, quickEnable);

    addBaseParameter(kVariation, nullptr);

    const auto defineSpatialGroup = [&descriptor](
        std::size_t featureIndex,
        std::size_t groupIdParameterIndex,
        const char* hint) {
        const auto& feature = kFilmtoneSpatialFeatureDefinitionsV1[featureIndex];
        OFX::GroupParamDescriptor* group = descriptor.defineGroupParam(
            spatialDefinition(groupIdParameterIndex).groupId);
        group->setLabels(feature.label, feature.label, feature.label);
        group->setHint(hint);
        group->setOpen(false);
        return group;
    };

    OFX::GroupParamDescriptor* deepGlow = defineSpatialGroup(
        0u,
        kBloomStrength,
        "Highlight-selective diffusion with independent strength and spread.");
    addSpatialParameter(kBloomStrength, deepGlow);
    addSpatialParameter(kBloomThreshold, deepGlow);
    addSpatialParameter(kBloomRadius, deepGlow);
    addSpatialParameter(kBloomSoftKnee, deepGlow);

    OFX::GroupParamDescriptor* peripheralChromaticShift = defineSpatialGroup(
        1u,
        kRgbShift,
        "Restrained radial red and blue separation toward the image perimeter.");
    addSpatialParameter(kRgbShift, peripheralChromaticShift);

    OFX::GroupParamDescriptor* lensSoftness = defineSpatialGroup(
        2u,
        kLensSoftness,
        "Field-weighted optical softness that keeps the image center coherent.");
    addSpatialParameter(kLensSoftness, lensSoftness);

    OFX::GroupParamDescriptor* textureSoftness = defineSpatialGroup(
        3u,
        kDetailSoftness,
        "Edge-aware relief of fine digital acutance across the frame.");
    addSpatialParameter(kDetailSoftness, textureSoftness);

    OFX::GroupParamDescriptor* vignette = defineSpatialGroup(
        4u,
        kVignette,
        "Progressive aspect-aware light falloff from the image center toward the perimeter.");
    addSpatialParameter(kVignette, vignette);

    OFX::GroupParamDescriptor* filmBreath = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.finish.group.filmBreath");
    filmBreath->setLabels("Film Breath", "Film Breath", "Film Breath");
    filmBreath->setHint(
        "Frame-correlated exposure, tonal contrast, and subtractive color variation with deterministic playback.");
    filmBreath->setOpen(false);
    addBaseParameter(kFilmBreathAmount, filmBreath);

    OFX::GroupParamDescriptor* filmBreathAdvanced =
        descriptor.defineGroupParam(
            "com.chibatakumi.filmtone.finish.group.filmBreath.advanced");
    filmBreathAdvanced->setLabels("Advanced", "Advanced", "Advanced");
    filmBreathAdvanced->setHint(
        "Sets Film Breath exposure, tonal contrast, subtractive color variation, and period.");
    filmBreathAdvanced->setParent(*filmBreath);
    filmBreathAdvanced->setOpen(false);
    for (std::size_t index = 0u;
         index < kFilmBreathPresentations.size();
         ++index) {
        page->addChild(*defineFilmBreathParameter(
            descriptor,
            index,
            kFilmBreathPresentations[index],
            *filmBreathAdvanced));
    }

    OFX::GroupParamDescriptor* gateWeave = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.finish.group.gateWeave");
    gateWeave->setLabels("Gate Weave", "Gate Weave", "Gate Weave");
    gateWeave->setHint(
        "Frame-correlated mechanical registration movement with automatic edge safety. If CinePrint35 Gate Wv is active, leave one Gate Weave treatment off.");
    gateWeave->setOpen(false);
    addBaseParameter(kGateWeaveAmount, gateWeave);

    OFX::GroupParamDescriptor* gateWeaveAdvanced =
        descriptor.defineGroupParam(
            "com.chibatakumi.filmtone.finish.group.gateWeave.advanced");
    gateWeaveAdvanced->setLabels("Advanced", "Advanced", "Advanced");
    gateWeaveAdvanced->setHint(
        "Movement range, rotation, correlation cadence, and frame-to-frame instability.");
    gateWeaveAdvanced->setParent(*gateWeave);
    gateWeaveAdvanced->setOpen(false);
    for (std::size_t index = kGateWeaveHorizontalAmplitude;
         index <= kGateWeaveJitter;
         ++index) {
        addBaseParameter(index, gateWeaveAdvanced);
    }

    OFX::GroupParamDescriptor* filmDamage = descriptor.defineGroupParam(
        "com.chibatakumi.filmtone.finish.group.filmDamage");
    filmDamage->setLabels("Film Damage", "Film Damage", "Film Damage");
    filmDamage->setHint(
        "Dark-weighted dust, scratches, fibers, stains, and gate wear.");
    filmDamage->setOpen(false);
    addBaseParameter(kFilmDamageAmount, filmDamage);

    OFX::GroupParamDescriptor* filmDamageAdvanced =
        descriptor.defineGroupParam(
            "com.chibatakumi.filmtone.finish.group.filmDamage.advanced");
    filmDamageAdvanced->setLabels("Advanced", "Advanced", "Advanced");
    filmDamageAdvanced->setHint(
        "Independent Film Damage material-family strengths.");
    filmDamageAdvanced->setParent(*filmDamage);
    filmDamageAdvanced->setOpen(false);
    for (std::size_t index = kDustAmount;
         index <= kGateWearAmount;
         ++index) {
        addBaseParameter(index, filmDamageAdvanced);
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
      filmBreathPeriodFrames_(effect.fetchDoubleParam(
          effects::film_breath::kFilmBreathPeriodFramesParameterId)),
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

    result.filmBreath.exposureResponse = readFiniteFilmBreathReal(
        *filmBreathExposureResponse_, 0u, time);
    result.filmBreath.tonalResponse = readFiniteFilmBreathReal(
        *filmBreathTonalResponse_, 1u, time);
    result.filmBreath.colorResponse = readFiniteFilmBreathReal(
        *filmBreathColorResponse_, 2u, time);
    result.filmBreath.periodFrames = readFiniteFilmBreathReal(
        *filmBreathPeriodFrames_, 3u, time);
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
