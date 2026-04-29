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

const EXPECTED_IPHONE_IOS_ENVELOPE = {
  contrast: 1.08,
  saturation: 0.94,
  compressionAmount: 0.18,
  bloomStrength: 0.18,
  lensSoftness: 0.035,
} as const;

const EXPECTED_SOFT_BLUE_IOS_ENVELOPE = {
  contrast: 0.94,
  saturation: 1.08,
  temperature: -0.18,
  bloomStrength: 0.36,
  diffusion: 0.24,
  compressionAmount: 0.32,
  cyan: 0.05,
} as const;

const EXPECTED_AMBER_GLOW_IOS_ENVELOPE = {
  contrast: 1.12,
  saturation: 1.12,
  temperature: 0.26,
  bloomStrength: 0.24,
  diffusion: 0.12,
  halationIntensity: 0.14,
  yellow: 0.12,
} as const;

test("generated Swift payload stays in sync with current iOS phase0 payload truth", () => {
  const repoRoot = resolve(import.meta.dir, "../../..");
  const generatedPath = resolve(
    repoRoot,
    "apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift",
  );

  const actual = readFileSync(generatedPath, "utf8");
  const expected = renderFilmtoneIosSwiftPayload();

  expect(actual).toBe(expected);
});

test("iOS preset map exposes the four mobile looks without mutating shared presets", () => {
  const sharedCinematic = pickPhase0Params(PRESETS.cinematic);
  const presetMap = buildFilmtoneIosPresetMap();
  const pureReset = pickPhase0Params(PRESETS.reset);

  expect(Object.keys(presetMap)).toEqual([...FILMTONE_IOS_PRESET_NAMES]);
  expect(presetMap.reset).toEqual(createFilmtoneDefaultPhase0Params());
  expect(presetMap.reset).not.toEqual(pureReset);
  expect((presetMap as Record<string, unknown>).cinematic).toBeUndefined();
  expect((presetMap as Record<string, unknown>).portra).toBeUndefined();
  expect(pickPhase0Params(PRESETS.cinematic)).toEqual(sharedCinematic);
  expect(PRESETS.cinematic.contrast).toBe(1.24);
  expect(PRESETS.cinematic.printContrast).toBe(0);

  expect(presetMap.iphone).toMatchObject(FILMTONE_IOS_PRESET_PATCHES.iphone ?? {});
  expect(presetMap.iphone).toMatchObject(EXPECTED_IPHONE_IOS_ENVELOPE);
  expect(presetMap.softBlue).toMatchObject(EXPECTED_SOFT_BLUE_IOS_ENVELOPE);
  expect(presetMap.amberGlow).toMatchObject(EXPECTED_AMBER_GLOW_IOS_ENVELOPE);
  expect(renderFilmtoneIosSwiftPayload()).toContain('static let schemaVersion = 2');
  expect(renderFilmtoneIosSwiftPayload()).toContain('static let rgbShiftMax = 0.005');
  expect(renderFilmtoneIosSwiftPayload()).toContain('"iphone": .init(');
  expect(renderFilmtoneIosSwiftPayload()).not.toContain('"cinematic": .init(');
});

test("iOS Swift payload keeps pure reset separate from the default reset target", () => {
  const payload = buildFilmtoneIosSwiftPayload();

  expect(payload.presetDefault).toBe("reset");
  expect(payload.resetParams).toEqual(pickPhase0Params(PRESETS.reset));
  expect(payload.presets.reset).toEqual(createFilmtoneDefaultPhase0Params());
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
  expect(Object.keys(payload.hiddenDefaults)).toHaveLength(19);
  // Spot-check a few canonical values (T3 Stream 2 consumes depthRayAngle*)
  expect(payload.hiddenDefaults.depthRayAngleGamma).toBe(1.4);
  expect(payload.hiddenDefaults.depthRayAngleInnerThreshold).toBe(0.1);
  expect(payload.hiddenDefaults.crossFilterEdgeLengthGain).toBe(0.45);
  expect(payload.hiddenDefaults.depthMistFieldPsfRadiusPx).toBe(18);
});

test("iOS swift payload rendering emits static let hiddenDefaults block", () => {
  const rendered = renderFilmtoneIosSwiftPayload();

  expect(rendered).toContain(
    "static let hiddenDefaults = FilmtonePhase0HiddenDefaults(",
  );
  // Distant key sanity check — catches a half-emitted block that would
  // compile-fail against FilmtonePhase0HiddenDefaults(19 fields).
  expect(rendered).toContain("crossFilterEdgeStrengthGain: 0.25");
  expect(rendered).toContain("depthRayAngleGamma: 1.4");
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
