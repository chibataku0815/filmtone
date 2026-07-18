import { deriveDetailSoftnessUniforms } from "./detail-softness";
import { PHASE0_RGB_SHIFT_MAX } from "./phase0-constants";
import { PRESETS } from "./presets";

/**
 * Canonical Filmtone-owned persistence and mapping contract for the Resolve
 * spatial expansion. Generic GlowRecipe/OpticsRecipe fields keep their
 * external ownership; this file owns only Filmtone semantics, durable Resolve
 * IDs, product defaults, role behavior, and the generated C++ facade.
 */
export const FILMTONE_RESOLVE_SPATIAL_CONTRACT_VERSION = 1 as const;

const UNIT_INTERVAL_MIN = 0;
const UNIT_INTERVAL_MAX = 1;
const DETAIL_SOFTNESS_NEUTRAL = deriveDetailSoftnessUniforms(0);
const DETAIL_SOFTNESS_MAXIMUM = deriveDetailSoftnessUniforms(1);
// Resolve's float full-frame pass has enough sampling headroom to expose the
// full control range. Shared app renderers keep their own host-specific
// calibration in detail-softness.ts.
const RESOLVE_DETAIL_SOFTNESS_EFFECTIVE_MAX = 1;
const RESOLVE_DETAIL_SOFTNESS_RADIUS_MAX = 5;
// Deep Glow selects emitters from scene-referred float values, so the
// threshold range extends above 1.0 to isolate HDR-only sources. The stored
// default and every old-project value stay inside the previous 0...1 range.
const RESOLVE_DEEP_GLOW_THRESHOLD_MAX = 4;

export const FILMTONE_RESOLVE_SPATIAL_CONTRACT = {
  contractId: "com.forestone.filmtone.resolve.spatial",
  contractVersion: FILMTONE_RESOLVE_SPATIAL_CONTRACT_VERSION,
  owner: "packages/film-lab-core/src/resolve-spatial-contract.ts",
  product: {
    publicDisplayName: "Filmtone",
    compatibilityPluginId: "com.chibatakumi.filmtone.finish",
    parameterIdPrefix: "com.forestone.filmtone.finish",
    parameterIdPolicy:
      "Retain the existing com.forestone.filmtone.finish parameter namespace; the visible product rename must not churn Resolve-project persistence IDs.",
  },
  nodeRoles: [
    {
      value: 0,
      key: "all",
      label: "All",
      schedulesSpatial: true,
      schedulesFilmModules: true,
    },
    {
      value: 1,
      key: "optics",
      label: "Optics",
      schedulesSpatial: true,
      schedulesFilmModules: false,
    },
    {
      value: 2,
      key: "filmModules",
      label: "Film Breath / Gate Weave / Film Damage",
      schedulesSpatial: false,
      schedulesFilmModules: true,
    },
  ],
  groups: [
    {
      id: "com.chibatakumi.filmtone.finish.group.deepGlow",
      feature: "deepGlow",
      label: "Deep Glow",
    },
    {
      id: "com.chibatakumi.filmtone.finish.group.peripheralChromaticShift",
      feature: "peripheralChromaticShift",
      label: "Peripheral Chromatic Shift",
    },
    {
      id: "com.chibatakumi.filmtone.finish.group.lensSoftness",
      feature: "lensSoftness",
      label: "Lens Softness",
    },
    {
      id: "com.chibatakumi.filmtone.finish.group.textureSoftness",
      feature: "textureSoftness",
      label: "Texture Softness",
    },
    {
      id: "com.chibatakumi.filmtone.finish.group.vignette",
      feature: "vignette",
      label: "Vignette",
    },
  ],
  parameterDefinitions: [
    {
      memberName: "nodeRole",
      id: "com.forestone.filmtone.finish.nodeRole",
      feature: "nodeRole",
      sourceField: "nodeRole",
      kind: "choice",
      label: "Node Role",
      groupId: "",
      unit: "stored-choice-index",
      defaultValue: 0,
      minValue: 0,
      maxValue: 2,
      identityValue: 0,
      normalization: "invalid-choice-to-default",
      genericMapping: "filmtone-only",
      genericPath: "",
    },
    {
      memberName: "deepGlowEnabled",
      id: "com.forestone.filmtone.finish.deepGlow.enabled",
      feature: "deepGlow",
      sourceField: "enabled",
      kind: "boolean",
      label: "Enabled",
      groupId: "com.chibatakumi.filmtone.finish.group.deepGlow",
      unit: "boolean",
      defaultValue: 0,
      minValue: 0,
      maxValue: 1,
      identityValue: 0,
      normalization: "zero-or-one",
      genericMapping: "filmtone-only",
      genericPath: "",
    },
    {
      memberName: "bloomStrength",
      id: "com.forestone.filmtone.finish.deepGlow.amount",
      feature: "deepGlow",
      sourceField: "bloomStrength",
      kind: "real",
      label: "Strength",
      groupId: "com.chibatakumi.filmtone.finish.group.deepGlow",
      unit: "normalized-glow-energy",
      defaultValue: PRESETS.reset.bloomStrength,
      minValue: UNIT_INTERVAL_MIN,
      maxValue: UNIT_INTERVAL_MAX,
      identityValue: 0,
      normalization: "finite-clamp-to-range",
      genericMapping: "direct",
      genericPath: "glow.bloom.strength",
    },
    {
      memberName: "bloomThreshold",
      id: "com.forestone.filmtone.finish.deepGlow.threshold",
      feature: "deepGlow",
      sourceField: "bloomThreshold",
      kind: "real",
      label: "Threshold",
      groupId: "com.chibatakumi.filmtone.finish.group.deepGlow",
      unit: "working-domain-input-luminance",
      defaultValue: PRESETS.reset.bloomThreshold,
      minValue: UNIT_INTERVAL_MIN,
      maxValue: RESOLVE_DEEP_GLOW_THRESHOLD_MAX,
      identityValue: PRESETS.reset.bloomThreshold,
      normalization: "finite-clamp-parameter-only-no-rgb-clamp",
      genericMapping: "direct",
      genericPath: "glow.bloom.threshold",
    },
    {
      memberName: "bloomRadius",
      id: "com.forestone.filmtone.finish.deepGlow.radius",
      feature: "deepGlow",
      sourceField: "bloomRadius",
      kind: "real",
      label: "Radius",
      groupId: "com.chibatakumi.filmtone.finish.group.deepGlow",
      unit: "normalized-log-psf-radius",
      defaultValue: PRESETS.reset.bloomRadius,
      minValue: UNIT_INTERVAL_MIN,
      maxValue: UNIT_INTERVAL_MAX,
      identityValue: PRESETS.reset.bloomRadius,
      normalization: "finite-clamp-to-range",
      genericMapping: "direct",
      genericPath: "glow.bloom.radius",
    },
    {
      memberName: "bloomSoftKnee",
      id: "com.forestone.filmtone.finish.deepGlow.softKnee",
      feature: "deepGlow",
      sourceField: "bloomSoftKnee",
      kind: "real",
      // Display label only: the persistent softKnee ID and stored values are
      // unchanged, so existing Resolve projects load identically.
      label: "Threshold Smooth",
      groupId: "com.chibatakumi.filmtone.finish.group.deepGlow",
      unit: "threshold-relative-soft-knee",
      defaultValue: PRESETS.reset.bloomSoftKnee,
      minValue: UNIT_INTERVAL_MIN,
      maxValue: UNIT_INTERVAL_MAX,
      identityValue: PRESETS.reset.bloomSoftKnee,
      normalization: "finite-clamp-to-range",
      genericMapping: "direct",
      genericPath: "glow.bloom.softKnee",
    },
    {
      memberName: "peripheralChromaticShiftEnabled",
      id: "com.forestone.filmtone.finish.peripheralChromaticShift.enabled",
      feature: "peripheralChromaticShift",
      sourceField: "enabled",
      kind: "boolean",
      label: "Enabled",
      groupId:
        "com.chibatakumi.filmtone.finish.group.peripheralChromaticShift",
      unit: "boolean",
      defaultValue: 0,
      minValue: 0,
      maxValue: 1,
      identityValue: 0,
      normalization: "zero-or-one",
      genericMapping: "filmtone-only",
      genericPath: "",
    },
    {
      memberName: "rgbShift",
      id: "com.forestone.filmtone.finish.peripheralChromaticShift.amount",
      feature: "peripheralChromaticShift",
      sourceField: "rgbShift",
      kind: "real",
      label: "Amount",
      groupId:
        "com.chibatakumi.filmtone.finish.group.peripheralChromaticShift",
      unit: "per-axis-frame-fraction",
      defaultValue: PRESETS.reset.rgbShift,
      minValue: 0,
      maxValue: PHASE0_RGB_SHIFT_MAX,
      identityValue: 0,
      normalization: "finite-clamp-to-range-no-rescale",
      genericMapping: "rejected-non-equivalent",
      genericPath: "optics.chromaticFringing",
    },
    {
      memberName: "lensSoftnessEnabled",
      id: "com.forestone.filmtone.finish.lensSoftness.enabled",
      feature: "lensSoftness",
      sourceField: "enabled",
      kind: "boolean",
      label: "Enabled",
      groupId: "com.chibatakumi.filmtone.finish.group.lensSoftness",
      unit: "boolean",
      defaultValue: 0,
      minValue: 0,
      maxValue: 1,
      identityValue: 0,
      normalization: "zero-or-one",
      genericMapping: "filmtone-only",
      genericPath: "",
    },
    {
      memberName: "lensSoftness",
      id: "com.forestone.filmtone.finish.lensSoftness.amount",
      feature: "lensSoftness",
      sourceField: "lensSoftness",
      kind: "real",
      label: "Amount",
      groupId: "com.chibatakumi.filmtone.finish.group.lensSoftness",
      unit: "normalized-optical-softness",
      defaultValue: PRESETS.reset.lensSoftness,
      minValue: UNIT_INTERVAL_MIN,
      maxValue: UNIT_INTERVAL_MAX,
      identityValue: 0,
      normalization: "finite-clamp-to-range",
      genericMapping: "direct",
      genericPath: "optics.lensSoftness",
    },
    {
      memberName: "textureSoftnessEnabled",
      id: "com.forestone.filmtone.finish.textureSoftness.enabled",
      feature: "textureSoftness",
      sourceField: "enabled",
      kind: "boolean",
      label: "Enabled",
      groupId: "com.chibatakumi.filmtone.finish.group.textureSoftness",
      unit: "boolean",
      defaultValue: 0,
      minValue: 0,
      maxValue: 1,
      identityValue: 0,
      normalization: "zero-or-one",
      genericMapping: "filmtone-only",
      genericPath: "",
    },
    {
      memberName: "detailSoftness",
      id: "com.forestone.filmtone.finish.textureSoftness.amount",
      feature: "textureSoftness",
      sourceField: "detailSoftness",
      kind: "real",
      label: "Amount",
      groupId: "com.chibatakumi.filmtone.finish.group.textureSoftness",
      unit: "normalized-texture-softness",
      defaultValue: PRESETS.reset.detailSoftness,
      minValue: UNIT_INTERVAL_MIN,
      maxValue: UNIT_INTERVAL_MAX,
      identityValue: 0,
      normalization: "finite-clamp-to-range",
      genericMapping: "filmtone-only",
      genericPath: "",
    },
    {
      memberName: "vignetteEnabled",
      id: "com.forestone.filmtone.finish.vignette.enabled",
      feature: "vignette",
      sourceField: "enabled",
      kind: "boolean",
      label: "Enabled",
      groupId: "com.chibatakumi.filmtone.finish.group.vignette",
      unit: "boolean",
      defaultValue: 0,
      minValue: 0,
      maxValue: 1,
      identityValue: 0,
      normalization: "zero-or-one",
      genericMapping: "filmtone-only",
      genericPath: "",
    },
    {
      memberName: "vignette",
      id: "com.forestone.filmtone.finish.vignette.amount",
      feature: "vignette",
      sourceField: "vignette",
      kind: "real",
      label: "Amount",
      groupId: "com.chibatakumi.filmtone.finish.group.vignette",
      unit: "normalized-multiplicative-attenuation",
      defaultValue: PRESETS.reset.vignette,
      minValue: UNIT_INTERVAL_MIN,
      maxValue: UNIT_INTERVAL_MAX,
      identityValue: 0,
      normalization: "finite-clamp-to-range",
      genericMapping: "direct",
      genericPath: "optics.vignette",
    },
  ],
  features: [
    {
      id: "deepGlow",
      label: "Deep Glow",
      enabledMember: "deepGlowEnabled",
      identityMember: "bloomStrength",
      renderScaleRule:
        "log-psf-radius-fraction-of-render-short-axis-rebuilt-per-render-scale",
      aspectRule: "isotropic-pixel-filtering-no-axis-stretch",
      identityCondition: "disabled-or-bloomStrength-zero",
    },
    {
      id: "peripheralChromaticShift",
      label: "Peripheral Chromatic Shift",
      enabledMember: "peripheralChromaticShiftEnabled",
      identityMember: "rgbShift",
      renderScaleRule: "frame-fraction-recomputed-from-render-bounds",
      aspectRule: "native-radial-v1-full-resolution-pixel-direction",
      identityCondition: "disabled-or-rgbShift-zero",
    },
    {
      id: "lensSoftness",
      label: "Lens Softness",
      enabledMember: "lensSoftnessEnabled",
      identityMember: "lensSoftness",
      renderScaleRule: "full-resolution-pixel-radius-times-render-scale",
      aspectRule: "half-diagonal-peripheral-distance",
      identityCondition: "disabled-or-lensSoftness-zero",
    },
    {
      id: "textureSoftness",
      label: "Texture Softness",
      enabledMember: "textureSoftnessEnabled",
      identityMember: "detailSoftness",
      renderScaleRule: "full-resolution-pixel-radius-times-render-scale",
      aspectRule: "center-inclusive-isotropic-pixel-neighborhood",
      identityCondition: "disabled-or-detailSoftness-zero",
    },
    {
      id: "vignette",
      label: "Vignette",
      enabledMember: "vignetteEnabled",
      identityMember: "vignette",
      renderScaleRule: "normalized-distance-recomputed-from-render-bounds",
      aspectRule: "full-resolution-pixel-half-diagonal-distance",
      identityCondition: "disabled-or-vignette-zero",
    },
  ],
  spatialSemantics: {
    opticalCenter: "center-of-source-bounds",
    fullResolutionCoordinates:
      "Derive full-resolution pixel coordinates by dividing render-space coordinates and bounds by the host render scale independently on X and Y.",
    alpha: "Preserve the unsplit source alpha; spatial amounts affect RGB only.",
    rgbRange:
      "Preserve negative and greater-than-one float RGB values; parameter normalization must never become a global RGB clamp.",
    edgePolicy:
      "Feature implementations must use the frozen spatial-host edge policy and must not introduce black or transparent samples.",
    peripheralChromaticShift: {
      radialExponent: 1.65,
      redDirection: "outward",
      greenDirection: "center",
      blueDirection: "inward",
      offset:
        "At the perimeter, rgbShift is the source-coordinate displacement as a fraction of the corresponding full-resolution frame axis. No generic conversion is applied.",
    },
    textureSoftness: {
      effectiveMaximum: RESOLVE_DETAIL_SOFTNESS_EFFECTIVE_MAX,
      kernelRadiusMinimumFullResolutionPixels:
        DETAIL_SOFTNESS_NEUTRAL.kernelRadiusPx,
      kernelRadiusMaximumFullResolutionPixels:
        RESOLVE_DETAIL_SOFTNESS_RADIUS_MAX,
      rangeSigma: DETAIL_SOFTNESS_MAXIMUM.rangeSigma,
      detailAmplitudeLow: DETAIL_SOFTNESS_MAXIMUM.detailAmplitudeLo,
      detailAmplitudeHigh: DETAIL_SOFTNESS_MAXIMUM.detailAmplitudeHi,
      chromaAttenuationScale: DETAIL_SOFTNESS_MAXIMUM.chromaAttenScale,
      highlightBias: DETAIL_SOFTNESS_MAXIMUM.highlightBias,
      resolveSourceDetailBias: 0,
    },
    vignette: {
      radius: "full-resolution-pixel-distance-divided-by-half-diagonal",
      attenuation:
        "rgb-times-(1-edgeLoss(vignette)*smoothstep(0,1,clamp(radius,0,1)))",
    },
  },
  genericContract: {
    glowOwner: "@forestone/visual-effect-core GlowRecipe",
    opticsOwner: "@forestone/visual-effect-core OpticsRecipe",
    directMappings: [
      "bloomStrength -> glow.bloom.strength",
      "bloomThreshold -> glow.bloom.threshold",
      "bloomRadius -> glow.bloom.radius",
      "bloomSoftKnee -> glow.bloom.softKnee",
      "lensSoftness -> optics.lensSoftness",
      "vignette -> optics.vignette",
    ],
    fixedValues: [
      "glow.bloom.colorResponse = 0 (current Filmtone native selection is luminance-keyed)",
    ],
    rejectedMappings: [
      "rgbShift != optics.chromaticFringing; do not apply an unproved x200 rescale",
      "detailSoftness has no generic owner and remains Filmtone-only",
    ],
  },
  backwardCompatibility: {
    missingNodeRole: "all",
    missingSpatialEnabledValues: 0,
    missingSpatialValues:
      "Use the parameter definition defaults. Every identity-driving amount defaults to zero.",
    roleMaskBehavior:
      "Role selection changes scheduling only. It must not overwrite, reset, or normalize stored feature values beyond read-time range handling.",
    oldProjectResult:
      "A project with no spatial fields resolves Node Role to All, schedules no spatial feature, and preserves the existing Film Breath/Gate Weave/Film Damage behavior exactly.",
  },
  evidence: {
    coreParameters: "packages/film-lab-core/src/params.ts",
    coreDefaults: "packages/film-lab-core/src/presets.ts",
    coreSchema: "packages/film-lab-core/src/phase0-schema.ts",
    rgbShiftLimit: "packages/film-lab-core/src/phase0-constants.ts",
    detailSoftness: "packages/film-lab-core/src/detail-softness.ts",
    nativeDeepGlow:
      "apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneMetalOpticsRenderer.swift",
    nativeDeepGlowOrchestration:
      "apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift",
    nativeDesktopOptics:
      "apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift",
  },
} as const;

export type FilmtoneResolveSpatialContract =
  typeof FILMTONE_RESOLVE_SPATIAL_CONTRACT;
