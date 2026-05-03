import {
  OPTICAL_FILTER_PROFILES,
  type OpticalFilterProfile,
} from "./optical-filter-profiles";

export const IOS_OPTICAL_FILTER_SPATIAL_KEYS = [
  "bloomThreshold",
  "bloomStrength",
  "bloomRadius",
  "bloomSoftKnee",
  "diffusion",
  "halationIntensity",
  "halationThreshold",
  "halationRadius",
  "halationHue",
  "halationSoftKnee",
  "lensSoftness",
  "rgbShift",
] as const;

export type IosOpticalFilterSpatialKey =
  (typeof IOS_OPTICAL_FILTER_SPATIAL_KEYS)[number];

export const IOS_OPTICAL_FILTER_OPTICAL_KEYS = [
  "directTransmission",
  "blackRetention",
  "scatterStrength",
  "highlightReactivity",
  "warmScatter",
  "spectralTail",
] as const;

export type IosOpticalFilterOpticalKey =
  (typeof IOS_OPTICAL_FILTER_OPTICAL_KEYS)[number];

export type IosOpticalFilterSpatialPayload = Readonly<
  Record<IosOpticalFilterSpatialKey, number>
>;

export type IosOpticalFilterOpticalPayload = Readonly<
  Record<IosOpticalFilterOpticalKey, number>
>;

export interface IosOpticalFilterProfilePayload {
  readonly id: string;
  readonly family: "backlightVeil";
  readonly density: string;
  readonly displayName: string;
  readonly shortLabel: string;
  readonly spatial: IosOpticalFilterSpatialPayload;
  readonly optical: IosOpticalFilterOpticalPayload;
}

const IOS_PORTABLE_FAMILIES = ["backlightVeil"] as const;

type IosPortableFamily = (typeof IOS_PORTABLE_FAMILIES)[number];

function isIosPortableFamily(
  family: OpticalFilterProfile["family"],
): family is IosPortableFamily {
  return (IOS_PORTABLE_FAMILIES as readonly string[]).includes(family);
}

function pickSpatial(
  profile: OpticalFilterProfile,
): IosOpticalFilterSpatialPayload {
  const out: Partial<Record<IosOpticalFilterSpatialKey, number>> = {};
  for (const key of IOS_OPTICAL_FILTER_SPATIAL_KEYS) {
    const value = profile.params[key];
    if (typeof value !== "number") {
      throw new Error(
        `Optical filter profile ${profile.id} is missing spatial key '${key}' required by iOS payload.`,
      );
    }
    out[key] = value;
  }
  return out as IosOpticalFilterSpatialPayload;
}

function pickOptical(
  profile: OpticalFilterProfile,
): IosOpticalFilterOpticalPayload {
  const lookup: Record<IosOpticalFilterOpticalKey, number | undefined> = {
    directTransmission: profile.params.opticalDirectTransmission,
    blackRetention: profile.params.opticalBlackRetention,
    scatterStrength: profile.params.opticalScatterStrength,
    highlightReactivity: profile.params.opticalHighlightReactivity,
    warmScatter: profile.params.opticalWarmScatter,
    spectralTail: profile.params.opticalSpectralTail,
  };
  const out: Partial<Record<IosOpticalFilterOpticalKey, number>> = {};
  for (const key of IOS_OPTICAL_FILTER_OPTICAL_KEYS) {
    const value = lookup[key];
    if (typeof value !== "number") {
      throw new Error(
        `Optical filter profile ${profile.id} is missing optical key '${key}' required by iOS payload.`,
      );
    }
    out[key] = value;
  }
  return out as IosOpticalFilterOpticalPayload;
}

export function buildIosOpticalFilterPayload(
  profiles: readonly OpticalFilterProfile[] = OPTICAL_FILTER_PROFILES,
): readonly IosOpticalFilterProfilePayload[] {
  return profiles
    .filter((profile) => isIosPortableFamily(profile.family))
    .map((profile) => ({
      id: profile.id,
      family: profile.family as "backlightVeil",
      density: profile.density,
      displayName: profile.displayName,
      shortLabel: profile.shortLabel,
      spatial: pickSpatial(profile),
      optical: pickOptical(profile),
    }));
}

export const IOS_OPTICAL_FILTER_PAYLOAD = buildIosOpticalFilterPayload();
