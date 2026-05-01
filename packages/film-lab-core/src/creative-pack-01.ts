/**
 * Filmtone iOS Creative LUT Pack 01 — definitions.
 *
 * Each Look in this pack consists of:
 *   - `slug`: stable filename slug (kebab-case). Used as both the bundled
 *     resource filename stem and the `bundledSlug` in sidecar provenance.
 *   - `englishName`: catalog default; iOS localizes via `FilmtoneStrings`.
 *   - `canonicalUUID`: stable UUID v4 in the `FB1A0001-0000-4000-8000-...`
 *     namespace. Mirrors the Swift `BuiltInLookUUID` enum so a single id is
 *     shared across TS / Swift / sidecar.
 *   - `basePreset`: one of the 4 locked iOS preset names. The Look chip's
 *     non-color expression (halation / bloom / grain / vignette / glow trio)
 *     comes from this preset's spatial fields at runtime. Locked to the iOS
 *     preset whitelist so this pack does not require regenerating
 *     `FilmtonePhase0Generated.swift`.
 *   - `colorParams`: 12-op color parameters baked INTO the cube at build
 *     time. These are intentionally NOT applied at runtime — `paramOverrides`
 *     neutralizes them plus the runtime v2 split-tone fields so the cube
 *     carries the entire color expression. (See `bake-color-only.ts` doc on
 *     the non-double-apply contract.)
 *   - `paramOverrides`: spatial / glow overrides applied AT RUNTIME on top
 *     of `basePreset`. The 12 color-op fields and v2 split-tone strengths
 *     here are pinned to neutral so the runtime path leaves color to the cube.
 *   - `strength`: default LUT intensity for `applyCreativeLutStage` — the
 *     user can still adjust via the existing strength slider.
 *
 * The bundled cubes carry color expression; runtime `paramOverrides` carry
 * Filmtone's optical expression while keeping the color-only fields neutral.
 */

import {
  BAKE_COLOR_IDENTITY,
  BAKE_COLOR_PARAM_KEYS,
  type BakeColorParams,
} from "./bake-color-only";
import type { FilmtoneIosPresetName } from "./ios-preset-overrides";
import type { Phase0ParamKey } from "./phase0-schema";

export const CREATIVE_PACK_01_ID = "creative-pack-01" as const;
export const CREATIVE_PACK_01_BAKER_VERSION = "1.1.0-palermo-reference" as const;
export const CREATIVE_PACK_01_CUBE_SIZE = 65 as const;
export const CREATIVE_PACK_01_PALERMO_REFERENCE_SOURCE =
  "/Volumes/SamsungPortableSSDX5001/filmtone/Palermo_Powergrade & LUTs/Palermo Standalone LUTs/DJI_DLOG-M-Palermo.cube" as const;
export const CREATIVE_PACK_01_PALERMO_GREEN_DENSITY_SOURCE =
  "/Volumes/SamsungPortableSSDX5001/filmtone/Palermo_Powergrade & LUTs/Palermo Standalone LUTs/LUT + Extras/Palermo + Colour Density + Green Density.cube" as const;

export interface CreativePackLook {
  readonly slug: string;
  readonly englishName: string;
  readonly canonicalUUID: string;
  readonly basePreset: FilmtoneIosPresetName;
  readonly colorParams: BakeColorParams;
  readonly paramOverrides: Partial<Record<Phase0ParamKey, number>>;
  readonly strength: number;
  readonly sourceCubePath?: string;
  readonly sourceCubeTransform?: "cold-green-density-v1";
}

/**
 * Build the runtime `paramOverrides` patch for a Look. Pins all 12 baked
 * color-op fields plus the v2 split-tone strengths to neutral to honor the
 * non-double-apply contract; merges any spatial overrides (halation / bloom /
 * grain / etc) the Look declares.
 */
export function buildLookParamOverrides(
  spatial: Partial<Record<Phase0ParamKey, number>>,
): Partial<Record<Phase0ParamKey, number>> {
  const out: Partial<Record<Phase0ParamKey, number>> = { ...spatial };
  for (const key of BAKE_COLOR_PARAM_KEYS) {
    out[key as Phase0ParamKey] = BAKE_COLOR_IDENTITY[key];
  }
  out.shadowTone = 0;
  out.highlightTone = 0;
  return out;
}

/**
 * Pack 01 Look catalog. Current CD direction is a small set of strong
 * Palermo-derived baselines, not a weak multi-look sampler. Entries bundle
 * Palermo 65³ cubes directly so iteration starts from measured LUT behavior
 * instead of small param nudges.
 *
 * `colorParams` remains identity because source-cube entries do not bake from
 * Filmtone's 12-op baker. Runtime `paramOverrides` still neutralizes the host
 * color ops so the bundled cube is the sole color expression, while Filmtone's
 * optical controls stay available for the next tuning pass.
 */
export const CREATIVE_PACK_01_LOOKS: readonly CreativePackLook[] = [
  {
    slug: "filmtone-creative-pack-01-palermo-reference",
    englishName: "Palermo Reference",
    canonicalUUID: "FB1A0001-0000-4000-8000-000000000006",
    basePreset: "reset",
    colorParams: {
      exposure: 0,
      contrast: 1,
      saturation: 1,
      temperature: 0,
      tint: 0,
      fade: 0,
      compressionAmount: 0,
      compressionRange: 0.5,
      printContrast: 0,
      cyan: 0,
      magenta: 0,
      yellow: 0,
    },
    paramOverrides: buildLookParamOverrides({
      // First optical baseline: enough Filmtone lens behavior to judge the
      // product direction, without hiding the Palermo color transform.
      bloomThreshold: 0.62,
      bloomStrength: 0.22,
      bloomRadius: 0.58,
      halationIntensity: 0.08,
      halationHue: 24,
      diffusion: 0.045,
      lensSoftness: 0.08,
      grainIntensity: 0.006,
      grainSize: 0.16,
      vignette: 0.06,
    }),
    strength: 1.0,
    sourceCubePath: CREATIVE_PACK_01_PALERMO_REFERENCE_SOURCE,
  },
  {
    slug: "filmtone-creative-pack-01-palermo-green-density",
    englishName: "Palermo Green Density",
    canonicalUUID: "FB1A0001-0000-4000-8000-000000000007",
    basePreset: "reset",
    colorParams: {
      exposure: 0,
      contrast: 1,
      saturation: 1,
      temperature: 0,
      tint: 0,
      fade: 0,
      compressionAmount: 0,
      compressionRange: 0.5,
      printContrast: 0,
      cyan: 0,
      magenta: 0,
      yellow: 0,
    },
    paramOverrides: buildLookParamOverrides({
      // Green-density companion baseline: keep warmth from optics restrained so
      // the source cube can carry the cool cyan-green density.
      bloomThreshold: 0.66,
      bloomStrength: 0.18,
      bloomRadius: 0.54,
      halationIntensity: 0.045,
      halationHue: 18,
      diffusion: 0.07,
      lensSoftness: 0.10,
      grainIntensity: 0.005,
      grainSize: 0.14,
      vignette: 0.07,
    }),
    strength: 1.0,
    sourceCubePath: CREATIVE_PACK_01_PALERMO_GREEN_DENSITY_SOURCE,
    sourceCubeTransform: "cold-green-density-v1",
  },
] as const;

export function findCreativePack01Look(slug: string): CreativePackLook | undefined {
  return CREATIVE_PACK_01_LOOKS.find((look) => look.slug === slug);
}
