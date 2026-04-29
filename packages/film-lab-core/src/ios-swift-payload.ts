import { PRESET_VERSION } from "./look-ids";
import { FILM_GRAIN_INTENSITY_MAX } from "./params";
import {
  PHASE0_APPROX_SOURCE_LONG_EDGE_MAX,
  PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES,
  PHASE0_MAX_SOURCE_DURATION_SEC,
  PHASE0_OUTPUT_PROFILE,
  PHASE0_PARAM_KEYS,
  PHASE0_PRESET_DEFAULT,
  PHASE0_PRESET_STRENGTH_DEFAULT,
  PHASE0_RGB_SHIFT_MAX,
  PHASE0_SCHEMA_VERSION,
  createFilmtoneDefaultPhase0Params,
  mergePhase0Params,
  pickPhase0Params,
  type Phase0Params,
} from "./phase0-schema";
import {
  FILMTONE_IOS_PRESET_NAMES,
  FILMTONE_IOS_PRESET_PATCHES,
  type FilmtoneIosPresetName,
} from "./ios-preset-overrides";
import {
  CONTRACT_DEFAULTS,
  PRESETS,
  type ContractDefaultKey,
} from "./presets";
import type { Params } from "./params";
import {
  DEFAULT_QUICK_STATE,
  QUICK_AXIS_DEFAULT_RANGE,
  QUICK_AXIS_IDS,
  QUICK_PHASE0_AXIS_WEIGHTS,
  type QuickAxisId,
} from "./quick-semantics";

export interface FilmtoneIosSwiftPayload {
  schemaVersion: number;
  presetVersion: string;
  presetDefault: FilmtoneIosPresetName;
  presetStrengthDefault: number;
  paramKeys: readonly string[];
  quickAxisIds: readonly string[];
  quickAxisRange: typeof QUICK_AXIS_DEFAULT_RANGE;
  defaultQuickState: typeof DEFAULT_QUICK_STATE;
  outputProfile: typeof PHASE0_OUTPUT_PROFILE;
  rgbShiftMax: number;
  grainIntensityMax: number;
  sourceCaps: {
    durationSec: number;
    longEdge: number;
    fileSizeBytes: number;
  };
  resetParams: Phase0Params;
  presets: Record<FilmtoneIosPresetName, Phase0Params>;
  quickWeights: Record<QuickAxisId, Partial<Record<keyof Phase0Params, number>>>;
  /**
   * Hidden default values that are not user-tunable in iOS Phase 0 but must
   * match Desktop / WebGPU CONTRACT_DEFAULTS exactly so that drift between
   * platforms is impossible. The source of truth is
   * `packages/film-lab-core/src/presets.ts::CONTRACT_DEFAULTS`.
   *
   * The iOS renderer emits these into `FilmtonePhase0Generated.hiddenDefaults`
   * (struct `FilmtonePhase0HiddenDefaults`). Field order follows the
   * declaration order of ContractDefaultKey so the generated Swift diff is
   * stable across generator runs.
   */
  hiddenDefaults: Readonly<Pick<Params, ContractDefaultKey>>;
}

export function buildFilmtoneIosPresetMap(
  presetPatches: Partial<Record<FilmtoneIosPresetName, Partial<Phase0Params>>> = FILMTONE_IOS_PRESET_PATCHES,
): Record<FilmtoneIosPresetName, Phase0Params> {
  return Object.fromEntries(
    FILMTONE_IOS_PRESET_NAMES.map((name) => {
      const base = createFilmtoneDefaultPhase0Params();
      const patch = presetPatches[name];
      return [name, patch ? mergePhase0Params(base, patch) : base];
    }),
  ) as Record<FilmtoneIosPresetName, Phase0Params>;
}

export function buildFilmtoneIosSwiftPayload(): FilmtoneIosSwiftPayload {
  const presets = buildFilmtoneIosPresetMap();

  return {
    schemaVersion: PHASE0_SCHEMA_VERSION,
    presetVersion: PRESET_VERSION,
    presetDefault: PHASE0_PRESET_DEFAULT,
    presetStrengthDefault: PHASE0_PRESET_STRENGTH_DEFAULT,
    paramKeys: PHASE0_PARAM_KEYS,
    quickAxisIds: QUICK_AXIS_IDS,
    quickAxisRange: QUICK_AXIS_DEFAULT_RANGE,
    defaultQuickState: DEFAULT_QUICK_STATE,
    outputProfile: PHASE0_OUTPUT_PROFILE,
    rgbShiftMax: PHASE0_RGB_SHIFT_MAX,
    grainIntensityMax: FILM_GRAIN_INTENSITY_MAX,
    sourceCaps: {
      durationSec: PHASE0_MAX_SOURCE_DURATION_SEC,
      longEdge: PHASE0_APPROX_SOURCE_LONG_EDGE_MAX,
      fileSizeBytes: PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES,
    },
    resetParams: pickPhase0Params(PRESETS.reset),
    presets,
    quickWeights: QUICK_PHASE0_AXIS_WEIGHTS as Record<
      QuickAxisId,
      Partial<Record<keyof Phase0Params, number>>
    >,
    hiddenDefaults: CONTRACT_DEFAULTS,
  };
}

/**
 * Declaration-order list of ContractDefaultKey. Kept in sync by hand with
 * `presets.ts`; the ios-swift-payload test asserts this ordering against
 * `Object.keys(CONTRACT_DEFAULTS)` so a divergence fails CI before drift
 * reaches the generated Swift file.
 */
const CONTRACT_DEFAULT_KEY_ORDER: readonly ContractDefaultKey[] = [
  "depthMistGain",
  "depthGlowGain",
  "depthRayAngleGamma",
  "depthRayAngleInnerThreshold",
  "depthMistRayAngleGain",
  "depthBloomRayAngleGain",
  "depthHalationRayAngleGain",
  "depthMistFieldPsfGain",
  "depthBloomFieldPsfGain",
  "depthHalationFieldPsfGain",
  "depthMistFieldPsfRadiusPx",
  "depthBloomFieldPsfRadiusPx",
  "depthHalationFieldPsfRadiusPx",
  "crossFilterDepthGain",
  "crossFilterAngleGain",
  "crossFilterAngleGamma",
  "crossFilterAngleInnerThreshold",
  "crossFilterEdgeLengthGain",
  "crossFilterEdgeStrengthGain",
];

export { CONTRACT_DEFAULT_KEY_ORDER };

function renderSwiftString(value: string): string {
  return JSON.stringify(value);
}

function renderSwiftNumber(value: number): string {
  if (Number.isInteger(value)) {
    return value.toFixed(1);
  }
  const rendered = value.toString();
  return rendered.includes("e") ? value.toFixed(8) : rendered;
}

function renderSwiftStringArray(values: readonly string[]): string {
  return `[${values.map(renderSwiftString).join(", ")}]`;
}

function renderPhase0ParamsInit(params: Phase0Params, indent = "        "): string {
  const lines = PHASE0_PARAM_KEYS.map((key) => `${indent}${key}: ${renderSwiftNumber(params[key])}`);
  const closingIndent = indent.slice(0, -4);
  return [
    ".init(",
    lines.join(",\n"),
    `${closingIndent})`,
  ].join("\n");
}

function renderPresetMap(presets: Record<FilmtoneIosPresetName, Phase0Params>): string {
  const presetNames = Object.keys(presets) as FilmtoneIosPresetName[];
  return [
    "[",
    presetNames
      .map((name) => `        ${renderSwiftString(name)}: ${renderPhase0ParamsInit(presets[name], "            ")}`)
      .join(",\n"),
    "    ]",
  ].join("\n");
}

function renderQuickWeights(
  quickWeights: Record<QuickAxisId, Partial<Record<keyof Phase0Params, number>>>,
): string {
  return [
    "[",
    QUICK_AXIS_IDS.map((axis) => {
      const weights = quickWeights[axis];
      const entries = Object.entries(weights)
        .filter(([, value]) => typeof value === "number")
        .map(([key, value]) => `            ${renderSwiftString(key)}: ${renderSwiftNumber(value)}`)
        .join(",\n");
      return [
        `        ${renderSwiftString(axis)}: [`,
        entries,
        "        ]",
      ].join("\n");
    }).join(",\n"),
    "    ]",
  ].join("\n");
}

function renderHiddenDefaults(
  hiddenDefaults: Readonly<Pick<Params, ContractDefaultKey>>,
): string {
  const lines = CONTRACT_DEFAULT_KEY_ORDER.map((key, index) => {
    const suffix = index === CONTRACT_DEFAULT_KEY_ORDER.length - 1 ? "" : ",";
    return `        ${key}: ${renderSwiftNumber(hiddenDefaults[key])}${suffix}`;
  });
  return [
    "FilmtonePhase0HiddenDefaults(",
    lines.join("\n"),
    "    )",
  ].join("\n");
}

export function renderFilmtoneIosSwiftPayload(payload = buildFilmtoneIosSwiftPayload()): string {
  const resetParams = renderPhase0ParamsInit(payload.resetParams, "        ").replace(/^/gm, "    ");
  return `import Foundation

enum FilmtonePhase0Generated {
    static let schemaVersion = ${payload.schemaVersion}
    static let presetVersion = ${renderSwiftString(payload.presetVersion)}
    static let presetDefault = ${renderSwiftString(payload.presetDefault)}
    static let presetStrengthDefault = ${renderSwiftNumber(payload.presetStrengthDefault)}
    static let paramKeys: [String] = ${renderSwiftStringArray(payload.paramKeys)}
    static let quickAxisIds: [String] = ${renderSwiftStringArray(payload.quickAxisIds)}
    static let quickAxisMin = ${renderSwiftNumber(payload.quickAxisRange.min)}
    static let quickAxisMax = ${renderSwiftNumber(payload.quickAxisRange.max)}
    static let quickAxisStep = ${renderSwiftNumber(payload.quickAxisRange.step)}
    static let defaultQuickState = FilmtoneQuickState(
        filmCharacter: ${renderSwiftNumber(payload.defaultQuickState.filmCharacter)},
        era: ${renderSwiftNumber(payload.defaultQuickState.era)},
        dynamics: ${renderSwiftNumber(payload.defaultQuickState.dynamics)}
    )
    static let outputProfile = Phase0OutputProfileDTO(
        longEdge: ${payload.outputProfile.longEdge},
        fps: ${payload.outputProfile.fps},
        codec: ${renderSwiftString(payload.outputProfile.codec)},
        container: ${renderSwiftString(payload.outputProfile.container)},
        preserveAudio: ${payload.outputProfile.preserveAudio ? "true" : "false"}
    )
    static let rgbShiftMax = ${renderSwiftNumber(payload.rgbShiftMax)}
    static let grainIntensityMax = ${renderSwiftNumber(payload.grainIntensityMax)}
    static let sourceDurationCapSec = ${renderSwiftNumber(payload.sourceCaps.durationSec)}
    static let sourceLongEdgeCap = ${payload.sourceCaps.longEdge}
    static let sourceFileSizeCapBytes = ${payload.sourceCaps.fileSizeBytes}
    static let resetParams: FilmtonePhase0Params =
${resetParams}
    static let paramsByName: [String: FilmtonePhase0Params] = ${renderPresetMap(payload.presets)}
    static let hiddenDefaults = ${renderHiddenDefaults(payload.hiddenDefaults)}
    static let quickWeights: [String: [String: Double]] = ${renderQuickWeights(payload.quickWeights)}
}
`;
}
