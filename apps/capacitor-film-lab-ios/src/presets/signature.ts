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
  "Signature preset = the canonical Filmtone iOS default look.",
  "It is wired through the shared default preset so the app already selects Neutral / Clean Base with the soft finish on first launch and after Reset.",
  "LUT slots default to empty until .cube assets are dropped into apps/capacitor-film-lab-ios/src/presets/luts/ and SIGNATURE_LUT_PLAN.bundledRelPath is filled in.",
  "Until then, the user picks Camera Profile / Film Look manually. The dual-LUT pipeline behaves the same.",
].join(" ");
