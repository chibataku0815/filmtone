import {
  PHASE0_PRESET_DEFAULT,
  createDefaultPhase0Params,
  type PresetName,
} from "film-lab-core";

export const SIGNATURE_PRESET_NAME: PresetName = PHASE0_PRESET_DEFAULT;

export const SIGNATURE_PRESET_PARAMS = createDefaultPhase0Params(SIGNATURE_PRESET_NAME);

export interface SignatureLutSlotPlan {
  slot: "inputLut" | "creativeLut";
  enabledByDefault: boolean;
  intendedFile: string;
  intendedRole: string;
  bundledRelPath: string | null;
}

export const SIGNATURE_LUT_PLAN: readonly SignatureLutSlotPlan[] = [
  {
    slot: "inputLut",
    enabledByDefault: true,
    intendedFile: "vlog-to-rec709.cube",
    intendedRole: "Camera Profile (Log -> Rec.709 input transform)",
    bundledRelPath: null,
  },
  {
    slot: "creativeLut",
    enabledByDefault: true,
    intendedFile: "filmtone-signature.cube",
    intendedRole: "Film Look (Filmtone signature creative grade)",
    bundledRelPath: null,
  },
] as const;

export const SIGNATURE_PRESET_BUNDLE_NOTE = [
  "Signature preset = the canonical Filmtone iOS default look (params-only).",
  "SIGNATURE_LUT_PLAN slots stay empty (bundledRelPath: null) — the signature preset is params-only across v1.3 / v1.4.",
  "Source profiles are handled native (Apple Log / Apple Log 2) + synthesized (D-Log / D-Log M / C-Log / Canon Log 3 + Cinema Gamut / V-Log / S-Log3 via FilmtoneSourceProfileMath) + Rec.709 default. Imported .cube remains as a user-side option.",
  "v1.4 Built-in Look catalog (FilmtoneBuiltInCatalog.swift) is separate from this plan: it ships Creative Pack 01 (Stone, Urban) with bundled .cube; v1.3 preset-wrapper Looks are removed. v1.5+ may revisit SIGNATURE_LUT_PLAN pending licensing.",
].join(" ");
