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
import {
  CREATIVE_PACK_01_STONE_TRANSFORM,
  CREATIVE_PACK_01_URBAN_TRANSFORM,
  type CreativePack01SourceTransform,
} from "./creative-pack-01-generator";
import type { FilmtoneIosPresetName } from "./ios-preset-overrides";
import type { Phase0ParamKey } from "./phase0-schema";

export const CREATIVE_PACK_01_ID = "creative-pack-01" as const;
export const CREATIVE_PACK_01_BAKER_VERSION = "1.5.0-stone-palermo-signature" as const;
export const CREATIVE_PACK_01_CUBE_SIZE = 65 as const;

export interface CreativePackLook {
  readonly slug: string;
  readonly englishName: string;
  readonly canonicalUUID: string;
  readonly basePreset: FilmtoneIosPresetName;
  readonly colorParams: BakeColorParams;
  readonly paramOverrides: Partial<Record<Phase0ParamKey, number>>;
  readonly strength: number;
  readonly sourceCubeTransform?: CreativePack01SourceTransform;
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
 * Pack 01 Look catalog. Stone adapts DJI D-Log M Palermo into a
 * display-referred Filmtone cube; Urban is the Palermo Green Density
 * derivative; Noir is Filmtone's toned print monochrome recipe. External
 * reference cubes are build-only inputs; the exported product catalog carries
 * the generated Filmtone recipe and never direct reference cube paths.
 *
 * `colorParams` is baked into the generated 65³ cube. Runtime
 * `paramOverrides` still neutralizes the host color ops so the bundled cube is
 * the sole color expression, while Filmtone's optical controls carry the
 * product signature.
 */
export const CREATIVE_PACK_01_LOOKS: readonly CreativePackLook[] = [
  {
    slug: "filmtone-creative-pack-01-stone",
    englishName: "Stone",
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
      rgbShift: 0.0021,
      bloomThreshold: 0.72,
      bloomStrength: 0.135,
      bloomRadius: 0.60,
      halationIntensity: 0.065,
      halationHue: 24,
      diffusion: 0.015,
      lensSoftness: 0.082,
      grainIntensity: 0.013,
      grainSize: 0.16,
      vignette: 0.1,
    }),
    strength: 1.0,
    sourceCubeTransform: CREATIVE_PACK_01_STONE_TRANSFORM,
  },
  {
    slug: "filmtone-creative-pack-01-urban",
    englishName: "Urban",
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
      rgbShift: 0.0028,
      bloomThreshold: 0.66,
      bloomStrength: 0.18,
      bloomRadius: 0.58,
      halationIntensity: 0.055,
      halationHue: 20,
      diffusion: 0.065,
      lensSoftness: 0.11,
      grainIntensity: 0.0075,
      grainSize: 0.13,
      vignette: 0.075,
    }),
    strength: 1.0,
    sourceCubeTransform: CREATIVE_PACK_01_URBAN_TRANSFORM,
  },
  {
    slug: "filmtone-creative-pack-01-noir",
    englishName: "Noir",
    canonicalUUID: "FB1A0001-0000-4000-8000-000000000010",
    basePreset: "reset",
    colorParams: {
      exposure: -0.24,
      contrast: 1.9,
      saturation: 0.012,
      temperature: 0.015,
      tint: -0.055,
      fade: 0.022,
      compressionAmount: 0.38,
      compressionRange: 0.56,
      printContrast: 0.86,
      cyan: 0.075,
      magenta: -0.052,
      yellow: 0.3,
    },
    paramOverrides: buildLookParamOverrides({
      rgbShift: 0,
      bloomThreshold: 0.56,
      bloomStrength: 0.2,
      bloomRadius: 0.64,
      halationIntensity: 0.028,
      halationHue: 36,
      diffusion: 0.13,
      lensSoftness: 0.16,
      grainRadialMix: 0.9,
      grainIntensity: 0.075,
      grainSize: 0.48,
      vignette: 0.16,
    }),
    strength: 1.0,
  },
] as const;

export function findCreativePack01Look(slug: string): CreativePackLook | undefined {
  return CREATIVE_PACK_01_LOOKS.find((look) => look.slug === slug);
}
