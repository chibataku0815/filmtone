import { z } from "zod";
import type { Params } from "./params";
import { PRESETS, type PresetName } from "./presets";
import { DEFAULT_QUICK_STATE, QUICK_AXIS_IDS } from "./quick-semantics";

export const PHASE0_SCHEMA_VERSION = 1 as const;
export const PHASE0_PRESET_DEFAULT = "cinematic" satisfies PresetName;
export const PHASE0_PRESET_STRENGTH_DEFAULT = 1;

export const PHASE0_PARAM_KEYS = [
  "exposure",
  "contrast",
  "saturation",
  "temperature",
  "tint",
  "fade",
  "vignette",
  "grainIntensity",
] as const;

export type Phase0ParamKey = (typeof PHASE0_PARAM_KEYS)[number];
export type Phase0Params = Pick<Params, Phase0ParamKey>;

export const PHASE0_MAX_SOURCE_DURATION_SEC = 60 * 5;
export const PHASE0_APPROX_SOURCE_LONG_EDGE_MAX = 3840;
export const PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES = 2 * 1024 * 1024 * 1024;

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

export const phase0ParamsSchema = z.object({
  exposure: z.number().min(-2).max(2).default(PRESETS.reset.exposure),
  contrast: z.number().min(0).max(2).default(PRESETS.reset.contrast),
  saturation: z.number().min(0).max(2).default(PRESETS.reset.saturation),
  temperature: z.number().min(-1).max(1).default(PRESETS.reset.temperature),
  tint: z.number().min(-1).max(1).default(PRESETS.reset.tint),
  fade: z.number().min(0).max(1).default(PRESETS.reset.fade),
  vignette: z.number().min(0).max(1).default(PRESETS.reset.vignette),
  grainIntensity: z.number().min(0).max(1).default(PRESETS.reset.grainIntensity),
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
  params: phase0ParamsSchema,
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
  ({ lut, inputLut, creativeLut, ...project }) => ({
    ...project,
    inputLut: inputLut ?? null,
    creativeLut: creativeLut ?? lut ?? null,
  }),
);

export type Phase0ProjectLut = z.infer<typeof phase0ProjectLutSchema>;
export type Phase0ProjectState = z.infer<typeof phase0ProjectSchema>;

export function pickPhase0Params(params: Params): Phase0Params {
  return {
    exposure: params.exposure,
    contrast: params.contrast,
    saturation: params.saturation,
    temperature: params.temperature,
    tint: params.tint,
    fade: params.fade,
    vignette: params.vignette,
    grainIntensity: params.grainIntensity,
  };
}

export function createDefaultPhase0Params(
  presetName: PresetName = PHASE0_PRESET_DEFAULT,
): Phase0Params {
  return pickPhase0Params(PRESETS[presetName]);
}

export function interpolatePhase0PresetParams(
  presetName: PresetName,
  strength: number,
): Phase0Params {
  const clamped = Math.max(0, Math.min(1, strength));
  const reset = pickPhase0Params(PRESETS.reset);
  const target = pickPhase0Params(PRESETS[presetName]);
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
