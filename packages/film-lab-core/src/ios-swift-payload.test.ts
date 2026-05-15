import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  FILMTONE_IOS_PRESET_NAMES,
  FILMTONE_IOS_PRESET_PATCHES,
} from "./ios-preset-overrides";
import {
  CONTRACT_DEFAULT_KEY_ORDER,
  buildFilmtoneIosPresetMap,
  buildFilmtoneIosSwiftPayload,
  renderFilmtoneIosSwiftPayload,
} from "./ios-swift-payload";
import {
  createFilmtoneDefaultPhase0Params,
  phase0ParamsSchema,
  pickPhase0Params,
} from "./phase0-schema";
import { CONTRACT_DEFAULTS, PRESETS } from "./presets";

// v1.4 Look V2 — values track ios-preset-overrides.ts after the CD reference
// re-derivation (Filmtone Signature ↔ warmglow mid, Soft Blue ↔ guasha
// split-tone, Amber Glow ↔ warmglow-1.5s dramatic warm). New fields
// (shadowTone/highlightTone/shadowHue/highlightHue) are also pinned to catch
// drift from the Phase A1 schema expansion.
const EXPECTED_IPHONE_IOS_ENVELOPE = {
  exposure: 0.04,
  contrast: 1.12,
  saturation: 0.95,
  temperature: 0.06,
  compressionAmount: 0.28,
  compressionRange: 0.5,
  printContrast: 0.08,
  rgbShift: 0.0012,
  lensSoftness: 0.14,
  bloomThreshold: 0.72,
  bloomStrength: 0.18,
  diffusion: 0.06,
  halationIntensity: 0.10,
  halationHue: 28,
  shadowTone: 0.08,
  highlightTone: 0.06,
  shadowHue: 220,
  highlightHue: 30,
  fade: 0.04,
  grainIntensity: 0.012,
} as const;

const EXPECTED_SOFT_BLUE_IOS_ENVELOPE = {
  exposure: 0.04,
  contrast: 1.05,
  saturation: 0.92,
  temperature: -0.06,
  rgbShift: 0.0016,
  lensSoftness: 0.22,
  bloomThreshold: 0.60,
  bloomStrength: 0.24,
  diffusion: 0.10,
  halationIntensity: 0.06,
  halationHue: 14,
  compressionAmount: 0.40,
  compressionRange: 0.5,
  printContrast: 0.10,
  cyan: 0.015,
  yellow: -0.025,
  shadowTone: 0.10,
  highlightTone: 0.18,
  shadowHue: 30,
  highlightHue: 200,
  fade: 0.10,
  grainIntensity: 0.014,
} as const;

const EXPECTED_AMBER_GLOW_IOS_ENVELOPE = {
  exposure: 0.01,
  contrast: 1.18,
  saturation: 1.10,
  temperature: 0.20,
  rgbShift: 0.0015,
  lensSoftness: 0.16,
  bloomThreshold: 0.62,
  bloomStrength: 0.24,
  diffusion: 0.10,
  halationIntensity: 0.16,
  halationHue: 35,
  compressionAmount: 0.35,
  compressionRange: 0.5,
  printContrast: 0.12,
  cyan: -0.025,
  magenta: 0.06,
  yellow: 0.08,
  shadowTone: 0.06,
  highlightTone: 0.18,
  shadowHue: 30,
  highlightHue: 40,
  fade: 0.04,
  grainIntensity: 0.016,
} as const;

test("generated Swift payload stays in sync with current iOS phase0 payload truth", () => {
  const repoRoot = resolve(import.meta.dir, "../../..");
  const generatedPath = resolve(
    repoRoot,
    "packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift",
  );

  const actual = readFileSync(generatedPath, "utf8");
  const expected = renderFilmtoneIosSwiftPayload(undefined, {
    accessLevel: "public",
  });

  expect(actual).toBe(expected);
});

test("iOS preset map exposes the four mobile looks without mutating shared presets", () => {
  const sharedCinematic = pickPhase0Params(PRESETS.cinematic);
  const presetMap = buildFilmtoneIosPresetMap();
  const pureReset = pickPhase0Params(PRESETS.reset);

  expect(Object.keys(presetMap)).toEqual([...FILMTONE_IOS_PRESET_NAMES]);
  expect(presetMap.reset).toEqual({
    ...createFilmtoneDefaultPhase0Params(),
    halationIntensity: 0,
  });
  expect(presetMap.reset).not.toEqual(pureReset);
  expect((presetMap as Record<string, unknown>).cinematic).toBeUndefined();
  expect((presetMap as Record<string, unknown>).portra).toBeUndefined();
  expect(pickPhase0Params(PRESETS.cinematic)).toEqual(sharedCinematic);
  expect(PRESETS.cinematic.contrast).toBe(1.24);
  expect(PRESETS.cinematic.printContrast).toBe(0);

  expect(presetMap.iphone).toMatchObject(FILMTONE_IOS_PRESET_PATCHES.iphone ?? {});
  expect(presetMap.softBlue).toMatchObject(FILMTONE_IOS_PRESET_PATCHES.softBlue ?? {});
  expect(presetMap.amberGlow).toMatchObject(FILMTONE_IOS_PRESET_PATCHES.amberGlow ?? {});
  expect(presetMap.iphone).toMatchObject(EXPECTED_IPHONE_IOS_ENVELOPE);
  expect(presetMap.softBlue).toMatchObject(EXPECTED_SOFT_BLUE_IOS_ENVELOPE);
  expect(presetMap.amberGlow).toMatchObject(EXPECTED_AMBER_GLOW_IOS_ENVELOPE);
  for (const name of FILMTONE_IOS_PRESET_NAMES) {
    expect(presetMap[name].shadowLatitude).toBe(0);
  }
  expect(presetMap.reset.halationIntensity).toBe(0);
  expect(renderFilmtoneIosSwiftPayload()).toContain('static let schemaVersion = 2');
  expect(renderFilmtoneIosSwiftPayload()).toContain('static let rgbShiftMax = 0.005');
  expect(renderFilmtoneIosSwiftPayload()).toContain('"shutterAngle"');
  expect(renderFilmtoneIosSwiftPayload()).toContain("trailIntensity: 0.0");
  expect(renderFilmtoneIosSwiftPayload()).toContain("filmBreathAmount: 0.0");
  expect(renderFilmtoneIosSwiftPayload()).toContain('"iphone": .init(');
  expect(renderFilmtoneIosSwiftPayload()).not.toContain('"cinematic": .init(');
});

test("iOS Swift payload keeps pure reset separate from the default reset target", () => {
  const payload = buildFilmtoneIosSwiftPayload();

  expect(payload.presetDefault).toBe("reset");
  expect(payload.resetParams).toEqual(pickPhase0Params(PRESETS.reset));
  expect(payload.resetParams.filmBreathAmount).toBe(0);
  expect(payload.presets.reset).toEqual({
    ...createFilmtoneDefaultPhase0Params(),
    halationIntensity: 0,
  });
  expect(payload.presets.reset.halationIntensity).toBe(0);
  expect(payload.presets.reset.bloomStrength).toBeGreaterThan(payload.resetParams.bloomStrength);
  expect(renderFilmtoneIosSwiftPayload()).toContain('static let presetDefault = "reset"');
});

test("iOS override leaves shared PRESETS byte-identical for all presets", () => {
  const snapshot = JSON.parse(JSON.stringify(PRESETS));
  const presetMap = buildFilmtoneIosPresetMap();
  expect(PRESETS).toEqual(snapshot);

  const presetNames = Object.keys(presetMap) as Array<keyof typeof presetMap>;
  for (const name of presetNames) {
    expect(() => phase0ParamsSchema.parse(presetMap[name])).not.toThrow();
  }
});

test("iOS swift payload exposes hiddenDefaults that deep-equal CONTRACT_DEFAULTS", () => {
  const payload = buildFilmtoneIosSwiftPayload();

  expect(payload.hiddenDefaults).toEqual(CONTRACT_DEFAULTS);
  expect(Object.keys(payload.hiddenDefaults)).toHaveLength(33);
  // Spot-check a few canonical values (T3 Stream 2 consumes depthRayAngle*)
  expect(payload.hiddenDefaults.depthRayAngleGamma).toBe(1.4);
  expect(payload.hiddenDefaults.depthRayAngleInnerThreshold).toBe(0.1);
  expect(payload.hiddenDefaults.crossFilterEdgeLengthGain).toBe(0.45);
  expect(payload.hiddenDefaults.depthMistFieldPsfRadiusPx).toBe(18);
  // The haloPrism / optical groups were added after the original 19-key
  // contract; pin one value from each so a future regression to the 19-key
  // shape fails here first instead of silently in the generator.
  expect(payload.hiddenDefaults.haloPrismRadius).toBe(0.62);
  expect(payload.hiddenDefaults.opticalDirectTransmission).toBe(1);
});

test("iOS swift payload rendering emits static let hiddenDefaults block", () => {
  const rendered = renderFilmtoneIosSwiftPayload();

  expect(rendered).toContain(
    "static let hiddenDefaults = FilmtonePhase0HiddenDefaults(",
  );
  // Distant key sanity check — catches a half-emitted block that would
  // compile-fail against FilmtonePhase0HiddenDefaults(33 fields).
  expect(rendered).toContain("depthRayAngleGamma: 1.4");
  expect(rendered).toContain("crossFilterEdgeStrengthGain: 0.25");
  expect(rendered).toContain("haloPrismRadius: 0.62");
  expect(rendered).toContain("opticalSpectralTail: 0.0");
});

test("CONTRACT_DEFAULT_KEY_ORDER matches CONTRACT_DEFAULTS declaration order", () => {
  // Guard against the ordered list in ios-swift-payload.ts drifting away
  // from the actual CONTRACT_DEFAULTS object in presets.ts. Object literal
  // key order in TS is preserved at runtime, so Object.keys() reflects
  // declaration order.
  expect(CONTRACT_DEFAULT_KEY_ORDER).toEqual(Object.keys(CONTRACT_DEFAULTS));
});

test("rendered hiddenDefaults block emits fields in ContractDefaultKey declaration order", () => {
  const rendered = renderFilmtoneIosSwiftPayload();
  const blockStart = rendered.indexOf("static let hiddenDefaults = FilmtonePhase0HiddenDefaults(");
  expect(blockStart).toBeGreaterThan(-1);
  const blockEnd = rendered.indexOf("\n    )", blockStart);
  expect(blockEnd).toBeGreaterThan(blockStart);
  const block = rendered.slice(blockStart, blockEnd);

  const observedOrder: string[] = [];
  for (const key of CONTRACT_DEFAULT_KEY_ORDER) {
    const offset = block.indexOf(`${key}:`);
    expect(offset).toBeGreaterThan(-1);
    observedOrder.push(key);
    // strip everything up to and including this hit so later indexOf calls
    // only find fields that appear AFTER the current one
  }

  // Ensure each expected key's offset is strictly monotonically increasing
  const offsets = CONTRACT_DEFAULT_KEY_ORDER.map((key) => block.indexOf(`${key}:`));
  for (let i = 1; i < offsets.length; i++) {
    expect(offsets[i]).toBeGreaterThan(offsets[i - 1]);
  }
  expect(observedOrder).toEqual([...CONTRACT_DEFAULT_KEY_ORDER]);
});

test("iOS preset overrides never mutate hiddenDefaults values", () => {
  const payload = buildFilmtoneIosSwiftPayload();
  // iOS preset overrides are applied to Phase0 params (subset of Params),
  // and none of the CONTRACT_DEFAULT_KEYs are in the Phase0 param subset,
  // so hiddenDefaults MUST remain byte-identical to CONTRACT_DEFAULTS even
  // after the overrides run.
  expect(payload.hiddenDefaults).toEqual(CONTRACT_DEFAULTS);
});

test("default access level is internal — iOS App / Desktop SharedGenerated emit shape unchanged", () => {
  const rendered = renderFilmtoneIosSwiftPayload();
  expect(rendered).toContain("\nenum FilmtonePhase0Generated {");
  expect(rendered).not.toContain("public enum FilmtonePhase0Generated");
  expect(rendered).not.toContain("public static let");
  // Spot-check a representative member is emitted as plain `static let`.
  expect(rendered).toContain("    static let schemaVersion = 2");
  expect(rendered).toContain("    static let resetParams: FilmtonePhase0Params =");
});

test("public access level prefixes enum + every static let with `public` for FilmLabSwiftCore package", () => {
  const rendered = renderFilmtoneIosSwiftPayload(undefined, { accessLevel: "public" });
  expect(rendered).toContain("\npublic enum FilmtonePhase0Generated {");
  // Every `static let` member must be public so cross-module consumers
  // (Desktop / iOS via `import FilmLabSwiftCore`) can reach them.
  for (const member of [
    "schemaVersion",
    "presetVersion",
    "presetDefault",
    "presetStrengthDefault",
    "paramKeys",
    "quickAxisIds",
    "quickAxisMin",
    "quickAxisMax",
    "quickAxisStep",
    "defaultQuickState",
    "outputProfile",
    "rgbShiftMax",
    "grainIntensityMax",
    "sourceDurationCapSec",
    "sourceLongEdgeCap",
    "sourceFileSizeCapBytes",
    "resetParams",
    "paramsByName",
    "hiddenDefaults",
    "quickWeights",
  ]) {
    expect(rendered).toContain(`public static let ${member}`);
  }
  // Sanity: literal initializers are unchanged (still call public inits in
  // the package context — emitter does not re-emit those call sites).
  expect(rendered).toContain('"iphone": .init(');
  expect(rendered).toContain("crossFilterEdgeStrengthGain: 0.25");
});

test("public-vs-internal output is byte-identical except for the access modifier", () => {
  const internal_ = renderFilmtoneIosSwiftPayload();
  const public_ = renderFilmtoneIosSwiftPayload(undefined, { accessLevel: "public" });
  // Stripping every `public ` prefix from the public output must reduce it
  // to the internal output exactly. This catches accidental shape drift
  // between modes (e.g. one mode adding a comment or a reordered field).
  const stripped = public_.replace(/public /g, "");
  expect(stripped).toBe(internal_);
});
