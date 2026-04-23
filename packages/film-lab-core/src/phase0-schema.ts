import { z } from "zod";
import type { Params } from "./params";
import { PHASE0_RGB_SHIFT_MAX } from "./phase0-constants";
import {
  PRESETS,
  createFilmtoneDefaultParams,
  type PresetName,
} from "./presets";
import {
  DEFAULT_QUICK_STATE,
  QUICK_AXIS_IDS,
  applyQuickStateToPhase0Params,
} from "./quick-semantics";

export { PHASE0_RGB_SHIFT_MAX } from "./phase0-constants";

export const PHASE0_SCHEMA_VERSION = 2 as const;
export const PHASE0_PRESET_DEFAULT = "reset" satisfies PresetName;
export const PHASE0_PRESET_STRENGTH_DEFAULT = 1;
export const PHASE0_HALATION_HUE_MIN = 0;
export const PHASE0_HALATION_HUE_MAX = 100;

export const PHASE0_PARAM_KEYS = [
  "exposure",
  "contrast",
  "saturation",
  "temperature",
  "tint",
  "rgbShift",
  "lensSoftness",
  "grainRadialMix",
  "grainSize",
  "bloomThreshold",
  "bloomStrength",
  "bloomRadius",
  "diffusion",
  "halationIntensity",
  "halationSpread",
  "halationHue",
  "halationThreshold",
  "halationRadius",
  "bloomSoftKnee",
  "halationSoftKnee",
  "compressionAmount",
  "compressionRange",
  "printContrast",
  "cyan",
  "magenta",
  "yellow",
  "fade",
  "vignette",
  "grainIntensity",
] as const;

export type Phase0ParamKey = (typeof PHASE0_PARAM_KEYS)[number];
export type Phase0Params = Pick<Params, Phase0ParamKey>;

export const PHASE0_MAX_SOURCE_DURATION_SEC = 60 * 5;
export const PHASE0_APPROX_SOURCE_LONG_EDGE_MAX = 3840;
export const PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES = 8 * 1024 * 1024 * 1024;

export const PHASE0_OUTPUT_PROFILE = {
  longEdge: 1920,
  fps: 30,
  codec: "h264",
  container: "mp4",
  preserveAudio: true,
} as const;

export type Phase0OutputProfile = typeof PHASE0_OUTPUT_PROFILE;

export const PHASE0_BENCHMARK_GATES = {
  passRealtimeRatio: 2.5,
  strongGoRealtimeRatio: 2.0,
  noGoRealtimeRatio: 3.0,
} as const;

const phase0HalationHueSchema = z
  .number()
  .min(PHASE0_HALATION_HUE_MIN)
  .max(PHASE0_HALATION_HUE_MAX);
const phase0RgbShiftSchema = z.number().min(0).max(PHASE0_RGB_SHIFT_MAX);

export const phase0ParamsSchema = z.object({
  exposure: z.number().min(-2).max(2).default(PRESETS.reset.exposure),
  contrast: z.number().min(0).max(2).default(PRESETS.reset.contrast),
  saturation: z.number().min(0).max(2).default(PRESETS.reset.saturation),
  temperature: z.number().min(-1).max(1).default(PRESETS.reset.temperature),
  tint: z.number().min(-1).max(1).default(PRESETS.reset.tint),
  rgbShift: phase0RgbShiftSchema.default(PRESETS.reset.rgbShift),
  lensSoftness: z.number().min(0).max(1).default(PRESETS.reset.lensSoftness),
  grainRadialMix: z.number().min(0).max(1).default(PRESETS.reset.grainRadialMix),
  grainSize: z.number().min(0).max(1).default(PRESETS.reset.grainSize),
  bloomThreshold: z.number().min(0).max(1).default(PRESETS.reset.bloomThreshold),
  bloomStrength: z.number().min(0).max(1).default(PRESETS.reset.bloomStrength),
  bloomRadius: z.number().min(0).max(1).default(PRESETS.reset.bloomRadius),
  diffusion: z.number().min(0).max(1).default(PRESETS.reset.diffusion),
  halationIntensity: z.number().min(0).max(1).default(PRESETS.reset.halationIntensity),
  halationSpread: z.number().min(0).max(40).default(PRESETS.reset.halationSpread),
  halationHue: phase0HalationHueSchema.default(PRESETS.reset.halationHue),
  halationThreshold: z.number().min(0).max(1).default(PRESETS.reset.halationThreshold),
  halationRadius: z.number().min(0).max(1).default(PRESETS.reset.halationRadius),
  bloomSoftKnee: z.number().min(0).max(1).default(PRESETS.reset.bloomSoftKnee),
  halationSoftKnee: z.number().min(0).max(1).default(PRESETS.reset.halationSoftKnee),
  compressionAmount: z.number().min(0).max(1).default(PRESETS.reset.compressionAmount),
  compressionRange: z.number().min(0).max(1).default(PRESETS.reset.compressionRange),
  printContrast: z.number().min(0).max(1).default(PRESETS.reset.printContrast),
  cyan: z.number().min(-1).max(1).default(PRESETS.reset.cyan),
  magenta: z.number().min(-1).max(1).default(PRESETS.reset.magenta),
  yellow: z.number().min(-1).max(1).default(PRESETS.reset.yellow),
  fade: z.number().min(0).max(1).default(PRESETS.reset.fade),
  vignette: z.number().min(0).max(1).default(PRESETS.reset.vignette),
  grainIntensity: z.number().min(0).max(1).default(PRESETS.reset.grainIntensity),
});

const phase0ParamsPatchSchema = z.object({
  exposure: z.number().min(-2).max(2).optional(),
  contrast: z.number().min(0).max(2).optional(),
  saturation: z.number().min(0).max(2).optional(),
  temperature: z.number().min(-1).max(1).optional(),
  tint: z.number().min(-1).max(1).optional(),
  rgbShift: phase0RgbShiftSchema.optional(),
  lensSoftness: z.number().min(0).max(1).optional(),
  grainRadialMix: z.number().min(0).max(1).optional(),
  grainSize: z.number().min(0).max(1).optional(),
  bloomThreshold: z.number().min(0).max(1).optional(),
  bloomStrength: z.number().min(0).max(1).optional(),
  bloomRadius: z.number().min(0).max(1).optional(),
  diffusion: z.number().min(0).max(1).optional(),
  halationIntensity: z.number().min(0).max(1).optional(),
  halationSpread: z.number().min(0).max(40).optional(),
  halationHue: phase0HalationHueSchema.optional(),
  halationThreshold: z.number().min(0).max(1).optional(),
  halationRadius: z.number().min(0).max(1).optional(),
  bloomSoftKnee: z.number().min(0).max(1).optional(),
  halationSoftKnee: z.number().min(0).max(1).optional(),
  compressionAmount: z.number().min(0).max(1).optional(),
  compressionRange: z.number().min(0).max(1).optional(),
  printContrast: z.number().min(0).max(1).optional(),
  cyan: z.number().min(-1).max(1).optional(),
  magenta: z.number().min(-1).max(1).optional(),
  yellow: z.number().min(-1).max(1).optional(),
  fade: z.number().min(0).max(1).optional(),
  vignette: z.number().min(0).max(1).optional(),
  grainIntensity: z.number().min(0).max(1).optional(),
});

export const phase0QuickStateSchema = z.object(
  {
    [QUICK_AXIS_IDS[0]]: z.number().min(-1).max(1),
    [QUICK_AXIS_IDS[1]]: z.number().min(-1).max(1),
    [QUICK_AXIS_IDS[2]]: z.number().min(-1).max(1),
  },
);

export const phase0ProjectLutSchema = z.object({
  title: z.string().min(1),
  size: z.number().int().positive(),
  data: z.array(z.number()),
  intensity: z.number().min(0).max(1).default(1),
});

const phase0ProjectSchemaInput = z.object({
  schemaVersion: z.literal(PHASE0_SCHEMA_VERSION),
  projectId: z.string().min(1),
  createdAt: z.string().min(1),
  updatedAt: z.string().min(1),
  presetName: z.string().min(1),
  strength: z.number().min(0).max(1).default(PHASE0_PRESET_STRENGTH_DEFAULT),
  quickState: phase0QuickStateSchema.default(DEFAULT_QUICK_STATE),
  params: phase0ParamsPatchSchema,
  // Legacy creative LUT slot. Keep parse-compatible so older saved projects
  // normalize into the current dual-LUT shape on load.
  lut: phase0ProjectLutSchema.nullable().optional(),
  inputLut: phase0ProjectLutSchema.nullable().optional(),
  creativeLut: phase0ProjectLutSchema.nullable().optional(),
  output: z.object({
    longEdge: z.literal(PHASE0_OUTPUT_PROFILE.longEdge),
    fps: z.literal(PHASE0_OUTPUT_PROFILE.fps),
    codec: z.literal(PHASE0_OUTPUT_PROFILE.codec),
    container: z.literal(PHASE0_OUTPUT_PROFILE.container),
    preserveAudio: z.boolean().default(PHASE0_OUTPUT_PROFILE.preserveAudio),
  }),
});

export const phase0ProjectSchema = phase0ProjectSchemaInput.transform(
  ({ lut, inputLut, creativeLut, ...project }) => {
    const safePresetName = Object.prototype.hasOwnProperty.call(PRESETS, project.presetName)
      ? (project.presetName as PresetName)
      : PHASE0_PRESET_DEFAULT;
    const derivedParams = applyQuickStateToPhase0Params(
      interpolatePhase0PresetParams(safePresetName, project.strength),
      project.quickState,
    );

    return {
      ...project,
      presetName: safePresetName,
      params: mergePhase0Params(derivedParams, project.params),
      inputLut: inputLut ?? null,
      creativeLut: creativeLut ?? lut ?? null,
    };
  },
);

export type Phase0ProjectLut = z.infer<typeof phase0ProjectLutSchema>;
export type Phase0ProjectState = z.infer<typeof phase0ProjectSchema>;

export function pickPhase0Params(
  params: Pick<Params, Phase0ParamKey>,
): Phase0Params {
  const next = {} as Phase0Params;
  for (const key of PHASE0_PARAM_KEYS) {
    next[key] = params[key];
  }
  return phase0ParamsSchema.parse(next);
}

export function createFilmtoneDefaultPhase0Params(): Phase0Params {
  return pickPhase0Params(createFilmtoneDefaultParams());
}

function phase0PresetTargetParams(presetName: PresetName): Phase0Params {
  if (presetName === PHASE0_PRESET_DEFAULT) {
    return createFilmtoneDefaultPhase0Params();
  }

  return pickPhase0Params(PRESETS[presetName]);
}

export function createDefaultPhase0Params(
  presetName: PresetName = PHASE0_PRESET_DEFAULT,
): Phase0Params {
  return phase0PresetTargetParams(presetName);
}

export function interpolatePhase0PresetParams(
  presetName: PresetName,
  strength: number,
): Phase0Params {
  const clamped = Math.max(0, Math.min(1, strength));
  const reset = pickPhase0Params(PRESETS.reset);
  const target = phase0PresetTargetParams(presetName);
  const params = { ...reset };

  for (const key of PHASE0_PARAM_KEYS) {
    params[key] = reset[key] + (target[key] - reset[key]) * clamped;
  }

  return phase0ParamsSchema.parse(params);
}

export function mergePhase0Params(
  base: Phase0Params,
  patch: Partial<Phase0Params>,
): Phase0Params {
  return phase0ParamsSchema.parse({ ...base, ...patch });
}

function makeProjectId(): string {
  const fromCrypto = globalThis.crypto?.randomUUID?.();
  if (typeof fromCrypto === "string" && fromCrypto.length > 0) {
    return fromCrypto;
  }
  return `phase0-${Date.now().toString(36)}`;
}

export function createPhase0ProjectState(
  presetName: PresetName = PHASE0_PRESET_DEFAULT,
): Phase0ProjectState {
  const now = new Date().toISOString();
  return phase0ProjectSchema.parse({
    schemaVersion: PHASE0_SCHEMA_VERSION,
    projectId: makeProjectId(),
    createdAt: now,
    updatedAt: now,
    presetName,
    strength: PHASE0_PRESET_STRENGTH_DEFAULT,
    quickState: DEFAULT_QUICK_STATE,
    params: createDefaultPhase0Params(presetName),
    inputLut: null,
    creativeLut: null,
    output: PHASE0_OUTPUT_PROFILE,
  });
}
