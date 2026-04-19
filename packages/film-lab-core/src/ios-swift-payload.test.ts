import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { FILMTONE_IOS_PRESET_OVERRIDES } from "./ios-preset-overrides";
import { buildFilmtoneIosPresetMap, renderFilmtoneIosSwiftPayload } from "./ios-swift-payload";
import { phase0ParamsSchema, pickPhase0Params } from "./phase0-schema";
import { PRESETS, type PresetName } from "./presets";

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

test("iOS preset map applies mobile-only overrides without mutating shared presets", () => {
  const presetMap = buildFilmtoneIosPresetMap();
  const sharedCinematic = pickPhase0Params(PRESETS.cinematic);

  expect(presetMap.reset).toEqual(pickPhase0Params(PRESETS.reset));
  expect(sharedCinematic).toEqual(pickPhase0Params(PRESETS.cinematic));
  expect(PRESETS.cinematic.contrast).toBe(1.24);
  expect(PRESETS.cinematic.printContrast).toBe(0);

  expect(presetMap.cinematic).toMatchObject(FILMTONE_IOS_PRESET_OVERRIDES.cinematic ?? {});
  expect(presetMap.cinematic).not.toEqual(sharedCinematic);
  expect(presetMap.cinematic.contrast).toBe(1.3);
  expect(presetMap.cinematic.compressionAmount).toBe(0.18);
  expect(presetMap.cinematic.printContrast).toBe(0.22);
  expect(presetMap.cinestill800t.bloomStrength).toBe(0.24);
  expect(presetMap.velvia50.printContrast).toBe(0.16);
  expect(renderFilmtoneIosSwiftPayload()).toContain('static let schemaVersion = 2');
  expect(renderFilmtoneIosSwiftPayload()).toContain('static let rgbShiftMax = 0.005');
});

test("iOS override leaves shared PRESETS byte-identical for all presets", () => {
  const snapshot = JSON.parse(JSON.stringify(PRESETS));
  const presetMap = buildFilmtoneIosPresetMap();
  expect(PRESETS).toEqual(snapshot);

  const presetNames = Object.keys(presetMap) as PresetName[];
  for (const name of presetNames) {
    expect(() => phase0ParamsSchema.parse(presetMap[name])).not.toThrow();
  }
});
