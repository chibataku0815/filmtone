#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const repoRoot = process.cwd();

const files = {
  strengthData: "apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheetData.swift",
  strings: "apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift",
  localizable: "apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings",
  generated: "packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift",
};

function read(rel) {
  return fs.readFileSync(path.join(repoRoot, rel), "utf8");
}

function fail(message) {
  console.error(`[ios-grain-catalog] ${message}`);
  process.exit(1);
}

function expect(condition, message) {
  if (!condition) fail(message);
}

function expectIncludes(source, needle, label) {
  expect(source.includes(needle), `${label} missing: ${needle}`);
}

const strengthData = read(files.strengthData);
const strings = read(files.strings);
const localizableSource = read(files.localizable);
const localizable = JSON.parse(localizableSource);
const generated = read(files.generated);

const grainSection = strengthData.match(
  /var grainAdvancedRecipes: \[FilmtoneAdvancedParamRecipe\] \{([\s\S]*?)\n    func standardAdvancedRecipes/
)?.[1];
expect(grainSection, "grainAdvancedRecipes section missing");

const recipeIds = [...grainSection.matchAll(/recipe\("([^"]+)"/g)].map((match) => match[1]);
const expectedRecipeIds = ["none", "fine", "classic", "push"];
expect(
  JSON.stringify(recipeIds) === JSON.stringify(expectedRecipeIds),
  `grain recipe ids drifted: ${JSON.stringify(recipeIds)}`
);

const expectedRecipeValues = {
  fine: {
    grainIntensity: "0.017",
    grainSize: "0.10",
    grainRadialMix: "0.60",
  },
  classic: {
    grainIntensity: "0.034",
    grainSize: "0.30",
    grainRadialMix: "0.85",
  },
  push: {
    grainIntensity: "0.064",
    grainSize: "0.62",
    grainRadialMix: "0.95",
  },
};

for (const [id, values] of Object.entries(expectedRecipeValues)) {
  const start = grainSection.indexOf(`recipe("${id}"`);
  const nextStarts = expectedRecipeIds
    .map((recipeId) => grainSection.indexOf(`recipe("${recipeId}"`, start + 1))
    .filter((index) => index > start);
  const end = nextStarts.length > 0 ? Math.min(...nextStarts) : grainSection.length;
  const block = grainSection.slice(start, end);
  expect(start >= 0, `grain recipe ${id} missing`);
  for (const [key, value] of Object.entries(values)) {
    expectIncludes(block, `"${key}": ${value}`, `grain recipe ${id}`);
  }
}

expectIncludes(strings, "let advancedGrainFineLabel: String", "FilmtoneStrings");
expectIncludes(strings, "let advancedGrainClassicLabel: String", "FilmtoneStrings");
expectIncludes(strings, "let advancedGrainPushLabel: String", "FilmtoneStrings");

const expectedLocalizedValues = {
  "filmtone.advanced.grain.fine": { en: "Fine", ja: "微粒子" },
  "filmtone.advanced.grain.classic": { en: "Classic", ja: "標準粒子" },
  "filmtone.advanced.grain.push": { en: "Push", ja: "粗粒子" },
};

for (const [key, values] of Object.entries(expectedLocalizedValues)) {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const occurrences = [...localizableSource.matchAll(new RegExp(`"${escapedKey}"\\s*:`, "g"))].length;
  expect(occurrences === 1, `Localizable key ${key} must appear exactly once, found ${occurrences}`);
  const row = localizable.strings[key];
  expect(row, `Localizable key missing: ${key}`);
  for (const [locale, value] of Object.entries(values)) {
    const actual = row.localizations?.[locale]?.stringUnit?.value;
    expect(actual === value, `Localizable ${key}/${locale} drifted: ${actual}`);
  }
}

const paramKeysSource = generated.match(/paramKeys: \[String\] = \[([^\]]+)\]/)?.[1];
expect(paramKeysSource, "generated paramKeys row missing");
const paramKeys = [...paramKeysSource.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
const grainParamKeys = paramKeys.filter((key) => key.startsWith("grain")).sort();
expect(
  JSON.stringify(grainParamKeys) === JSON.stringify(["grainIntensity", "grainRadialMix", "grainSize"]),
  `generated grain param keys drifted: ${JSON.stringify(grainParamKeys)}`
);
expect(!paramKeys.includes("grainType"), "generated paramKeys must not include grainType");
expectIncludes(generated, "public static let grainIntensityMax = 0.1", "generated grainIntensityMax");

console.log("[ios-grain-catalog] ok");
