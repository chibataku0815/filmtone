import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { FILM_BREATH_CONTRACT } from "../../../../packages/film-lab-core/src/film-breath.ts";
import {
  FILMTONE_RESOLVE_SPATIAL_CONTRACT,
  FILMTONE_RESOLVE_SPATIAL_CONTRACT_VERSION,
} from "../../../../packages/film-lab-core/src/resolve-spatial-contract.ts";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(SCRIPT_DIR, "..", "..", "..", "..");
const OUTPUT_ROOT = resolve(
  REPO_ROOT,
  "apps/filmtone-resolve-ofx/Sources/Generated/Contracts",
);
const FILM_BREATH_SOURCE_PATH = resolve(
  REPO_ROOT,
  "packages/film-lab-core/src/film-breath.ts",
);
const SPATIAL_CONTRACT_SOURCE_PATH = resolve(
  REPO_ROOT,
  "packages/film-lab-core/src/resolve-spatial-contract.ts",
);
const SPATIAL_CONTRACT_INPUTS = {
  contract: {
    path: "packages/film-lab-core/src/resolve-spatial-contract.ts",
    absolutePath: SPATIAL_CONTRACT_SOURCE_PATH,
  },
  defaults: {
    path: "packages/film-lab-core/src/presets.ts",
    absolutePath: resolve(REPO_ROOT, "packages/film-lab-core/src/presets.ts"),
  },
  rgbShiftLimit: {
    path: "packages/film-lab-core/src/phase0-constants.ts",
    absolutePath: resolve(
      REPO_ROOT,
      "packages/film-lab-core/src/phase0-constants.ts",
    ),
  },
  detailSoftness: {
    path: "packages/film-lab-core/src/detail-softness.ts",
    absolutePath: resolve(
      REPO_ROOT,
      "packages/film-lab-core/src/detail-softness.ts",
    ),
  },
} as const;

const REGENERATION_COMMAND =
  "bun run apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts " +
  "--external-root <visual-effect-core-root>";

const FROZEN_EXTERNAL = {
  artifactSchemaVersion: 1,
  filmDamageContractVersion: 2,
  filmDamageContractRevision: "2.3",
  deterministicRenderContextContractVersion: 1,
  filmtoneFinishContractVersion: 1,
  manifest: {
    path: "packages/filmtone-pack/artifacts/filmtone-finish-contract-v1.json",
    sha256: "cf90a1e838470acd7a7f7272a77561eb254d057742e70a150a6cd28823f8710b",
  },
  artifacts: {
    filmDamageRecipeHeader: {
      path: "packages/visual-effect-core/artifacts/cpp/forestone_film_damage_recipe.hpp",
      outputName: "forestone_film_damage_recipe.hpp",
      sha256: "4cb78c964cc29270f2fb10bcd2f29d64438f2ab052ee86d3a61366bca032e874",
    },
    deterministicRenderContextHeader: {
      path: "packages/visual-render-core/artifacts/cpp/forestone_deterministic_render_context.hpp",
      outputName: "forestone_deterministic_render_context.hpp",
      sha256: "cf8c442a6ba7fbfe0331b7cfa71b36855cc39bca5ec99051e134d704c4379916",
    },
    filmtoneFinishMappingHeader: {
      path: "packages/filmtone-pack/artifacts/cpp/forestone_filmtone_finish_mapping.hpp",
      outputName: "forestone_filmtone_finish_mapping.hpp",
      sha256: "a7bca5ef716633ac7fedc25ed6890fb5f6b41599360088475c87cf2182665d44",
    },
  },
} as const;

interface ExternalManifest {
  artifactSchemaVersion: number;
  generatedBy: string;
  owners: {
    filmDamageRecipe: string;
    deterministicRenderContext: string;
    filmtoneFinishMapping: string;
  };
  deterministicRenderContext: {
    contractVersion: number;
  };
  filmDamage: {
    contractVersion: number;
    contractRevision: string;
  };
  filmtoneFinish: {
    contractVersion: number;
  };
  generatedArtifacts: Record<keyof typeof FROZEN_EXTERNAL.artifacts, string>;
}

interface LoadedArtifact {
  key: keyof typeof FROZEN_EXTERNAL.artifacts;
  path: string;
  outputName: string;
  sha256: string;
  contents: Buffer;
  text: string;
}

type SpatialContractInputKey = keyof typeof SPATIAL_CONTRACT_INPUTS;

interface LoadedSpatialContractInput {
  key: SpatialContractInputKey;
  path: string;
  sha256: string;
}

function fail(message: string): never {
  throw new Error(`Filmtone Finish contract generation failed: ${message}`);
}

function parseExternalRoot(args: readonly string[]): string {
  let externalRoot: string | undefined;
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument !== "--external-root") {
      fail(`unknown argument ${JSON.stringify(argument)}`);
    }
    const value = args[index + 1];
    if (!value || value.startsWith("--")) {
      fail("--external-root requires a path");
    }
    if (externalRoot) {
      fail("--external-root may only be specified once");
    }
    externalRoot = resolve(value);
    index += 1;
  }
  if (!externalRoot) {
    fail(
      `missing --external-root. Usage: ${REGENERATION_COMMAND}`,
    );
  }
  return externalRoot;
}

function resolveInput(root: string, relativePath: string): string {
  const path = resolve(root, relativePath);
  const pathFromRoot = relative(root, path);
  if (pathFromRoot.startsWith("..") || isAbsolute(pathFromRoot)) {
    fail(`input path escapes external root: ${relativePath}`);
  }
  return path;
}

function sha256(contents: string | Buffer): string {
  return createHash("sha256").update(contents).digest("hex");
}

function readRequired(path: string, label: string): Buffer {
  try {
    return readFileSync(path);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return fail(`cannot read ${label} at ${path}: ${detail}`);
  }
}

function assertEqual(
  label: string,
  actual: unknown,
  expected: string | number,
): void {
  if (actual !== expected) {
    fail(`${label} mismatch: expected ${expected}, received ${String(actual)}`);
  }
}

function assertHash(label: string, contents: Buffer, expected: string): string {
  const actual = sha256(contents);
  if (actual !== expected) {
    fail(`${label} SHA-256 mismatch: expected ${expected}, received ${actual}`);
  }
  return actual;
}

function parseManifest(contents: Buffer): ExternalManifest {
  try {
    return JSON.parse(contents.toString("utf8")) as ExternalManifest;
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return fail(`external manifest is not valid JSON: ${detail}`);
  }
}

function validateManifest(manifest: ExternalManifest): void {
  assertEqual(
    "artifact schema version",
    manifest.artifactSchemaVersion,
    FROZEN_EXTERNAL.artifactSchemaVersion,
  );
  assertEqual(
    "Film Damage contract version",
    manifest.filmDamage?.contractVersion,
    FROZEN_EXTERNAL.filmDamageContractVersion,
  );
  assertEqual(
    "Film Damage contract revision",
    manifest.filmDamage?.contractRevision,
    FROZEN_EXTERNAL.filmDamageContractRevision,
  );
  assertEqual(
    "deterministic render context contract version",
    manifest.deterministicRenderContext?.contractVersion,
    FROZEN_EXTERNAL.deterministicRenderContextContractVersion,
  );
  assertEqual(
    "Filmtone Finish mapping contract version",
    manifest.filmtoneFinish?.contractVersion,
    FROZEN_EXTERNAL.filmtoneFinishContractVersion,
  );
  assertEqual(
    "external generator provenance",
    manifest.generatedBy,
    "tools/filmtone-finish-contract/generate-cpp-handoff.ts",
  );
  assertEqual(
    "Film Damage owner",
    manifest.owners?.filmDamageRecipe,
    "@forestone/visual-effect-core",
  );
  assertEqual(
    "deterministic render context owner",
    manifest.owners?.deterministicRenderContext,
    "@forestone/visual-render-core",
  );
  assertEqual(
    "Filmtone Finish mapping owner",
    manifest.owners?.filmtoneFinishMapping,
    "@forestone/filmtone-pack",
  );

  for (const [key, frozen] of Object.entries(FROZEN_EXTERNAL.artifacts) as Array<
    [keyof typeof FROZEN_EXTERNAL.artifacts, (typeof FROZEN_EXTERNAL.artifacts)[keyof typeof FROZEN_EXTERNAL.artifacts]]
  >) {
    assertEqual(
      `${key} manifest path`,
      manifest.generatedArtifacts?.[key],
      frozen.path,
    );
  }
}

function validateHeaderMarkers(artifacts: readonly LoadedArtifact[]): void {
  const expectedMarkers: Record<LoadedArtifact["key"], readonly string[]> = {
    filmDamageRecipeHeader: [
      "kFilmDamageRecipeContractVersion = 2u;",
      'kFilmDamageRecipeContractRevision = "2.3";',
    ],
    deterministicRenderContextHeader: [
      "kDeterministicRenderContextContractVersion = 1u;",
    ],
    filmtoneFinishMappingHeader: [
      "kFilmtoneFinishContractVersion = 1u;",
    ],
  };

  for (const artifact of artifacts) {
    for (const marker of expectedMarkers[artifact.key]) {
      if (!artifact.text.includes(marker)) {
        fail(`${artifact.key} is missing frozen marker ${JSON.stringify(marker)}`);
      }
    }
  }
}

function validateFilmBreathContract(): void {
  assertEqual("Film Breath contract version", FILM_BREATH_CONTRACT.contractVersion, 1);
  assertEqual("Film Breath algorithm", FILM_BREATH_CONTRACT.algorithm, "filmtone-value-noise-v1");
  assertEqual(
    "Film Breath seed normalization",
    FILM_BREATH_CONTRACT.seedNormalization,
    "absolute-truncate-uint32-wrap",
  );
}

function spatialParameter(memberName: string) {
  const parameter = FILMTONE_RESOLVE_SPATIAL_CONTRACT.parameterDefinitions.find(
    (candidate) => candidate.memberName === memberName,
  );
  if (!parameter) {
    return fail(`spatial contract is missing parameter member ${memberName}`);
  }
  return parameter;
}

function validateSpatialContract(): void {
  const contract = FILMTONE_RESOLVE_SPATIAL_CONTRACT;
  assertEqual(
    "Resolve spatial contract version",
    contract.contractVersion,
    FILMTONE_RESOLVE_SPATIAL_CONTRACT_VERSION,
  );
  assertEqual(
    "Resolve spatial contract version freeze",
    contract.contractVersion,
    1,
  );
  assertEqual(
    "Resolve spatial contract owner",
    contract.owner,
    "packages/film-lab-core/src/resolve-spatial-contract.ts",
  );
  assertEqual(
    "Resolve public display name",
    contract.product.publicDisplayName,
    "Filmtone",
  );
  assertEqual(
    "Resolve compatibility plugin ID",
    contract.product.compatibilityPluginId,
    "com.chibatakumi.filmtone.finish",
  );
  assertEqual("Resolve spatial parameter count", contract.parameterDefinitions.length, 14);
  assertEqual("Resolve spatial feature count", contract.features.length, 5);
  assertEqual("Resolve Node Role count", contract.nodeRoles.length, 3);

  const parameterIds = new Set<string>();
  const memberNames = new Set<string>();
  for (const parameter of contract.parameterDefinitions) {
    if (parameterIds.has(parameter.id)) {
      fail(`duplicate spatial parameter ID ${parameter.id}`);
    }
    if (memberNames.has(parameter.memberName)) {
      fail(`duplicate spatial parameter member ${parameter.memberName}`);
    }
    if (
      !Number.isFinite(parameter.defaultValue) ||
      !Number.isFinite(parameter.minValue) ||
      !Number.isFinite(parameter.maxValue) ||
      parameter.minValue > parameter.maxValue ||
      parameter.defaultValue < parameter.minValue ||
      parameter.defaultValue > parameter.maxValue
    ) {
      fail(`invalid spatial parameter range/default for ${parameter.id}`);
    }
    parameterIds.add(parameter.id);
    memberNames.add(parameter.memberName);
  }

  const role = spatialParameter("nodeRole");
  assertEqual("Node Role default", role.defaultValue, 0);
  assertEqual("Node Role minimum", role.minValue, 0);
  assertEqual("Node Role maximum", role.maxValue, 2);
  assertEqual("Node Role kind", role.kind, "choice");

  for (const feature of contract.features) {
    const enabled = spatialParameter(feature.enabledMember);
    const identity = spatialParameter(feature.identityMember);
    assertEqual(`${feature.id} Enabled default`, enabled.defaultValue, 0);
    assertEqual(`${feature.id} identity amount default`, identity.defaultValue, 0);
  }

  const rgbShift = spatialParameter("rgbShift");
  assertEqual(
    "rgbShift generic mapping",
    rgbShift.genericMapping,
    "rejected-non-equivalent",
  );
  assertEqual(
    "rgbShift rejected generic path",
    rgbShift.genericPath,
    "optics.chromaticFringing",
  );
  const detailSoftness = spatialParameter("detailSoftness");
  assertEqual(
    "detailSoftness ownership",
    detailSoftness.genericMapping,
    "filmtone-only",
  );
  if (contract.spatialSemantics.textureSoftness.effectiveMaximum <= 0) {
    fail("Texture Softness effective maximum must be positive");
  }
}

function cppNumber(value: number): string {
  if (!Number.isFinite(value)) {
    return fail(`cannot emit non-finite C++ number ${value}`);
  }
  return Number.isInteger(value) ? `${value}.0` : String(value);
}

function cppFloat(value: number): string {
  return `${cppNumber(value)}f`;
}

function cppUint(value: number): string {
  if (!Number.isInteger(value) || value < 0 || value > 0xffffffff) {
    return fail(`cannot emit uint32 value ${value}`);
  }
  return `0x${(value >>> 0).toString(16).padStart(8, "0")}u`;
}

function cppString(value: string): string {
  return JSON.stringify(value);
}

function generatedBanner(owner: string): string[] {
  return [
    `// Generated by apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts.`,
    "// DO NOT EDIT. Regenerate from the named owning source.",
    `// Owner: ${owner}`,
    `// Regenerate: ${REGENERATION_COMMAND}`,
  ];
}

function renderFilmBreathHeader(): string {
  const contract = FILM_BREATH_CONTRACT;
  const fast = contract.noise.bands.fast;
  const medium = contract.noise.bands.medium;
  const slow = contract.noise.bands.slow;
  const long = contract.noise.bands.long;

  return [
    ...generatedBanner("packages/film-lab-core/src/film-breath.ts"),
    "#pragma once",
    "",
    "#include <cmath>",
    "#include <cstdint>",
    "#include <type_traits>",
    "",
    "namespace filmtone::film_breath {",
    "",
    `inline constexpr std::uint32_t kFilmBreathContractVersion = ${contract.contractVersion}u;`,
    `inline constexpr double kExposureLimit = ${cppNumber(contract.limits.exposure)};`,
    `inline constexpr double kContrastLimit = ${cppNumber(contract.limits.contrast)};`,
    `inline constexpr double kTemperatureLimit = ${cppNumber(contract.limits.temperature)};`,
    `inline constexpr double kTintLimit = ${cppNumber(contract.limits.tint)};`,
    `inline constexpr std::uint32_t kExposureSalt = ${cppUint(contract.outputSalts.exposure)};`,
    `inline constexpr std::uint32_t kContrastSalt = ${cppUint(contract.outputSalts.contrast)};`,
    `inline constexpr std::uint32_t kTemperatureSalt = ${cppUint(contract.outputSalts.temperature)};`,
    `inline constexpr std::uint32_t kTintSalt = ${cppUint(contract.outputSalts.tint)};`,
    `inline constexpr double kFastPeriodSeconds = ${cppNumber(fast.periodSeconds)};`,
    `inline constexpr double kMediumPeriodSeconds = ${cppNumber(medium.periodSeconds)};`,
    `inline constexpr double kSlowPeriodSeconds = ${cppNumber(slow.periodSeconds)};`,
    `inline constexpr double kLongPeriodSeconds = ${cppNumber(long.periodSeconds)};`,
    "",
    "struct FilmBreathOffsetsV1 {",
    "  double exposure = 0.0;",
    "  double contrast = 0.0;",
    "  double temperature = 0.0;",
    "  double tint = 0.0;",
    "};",
    "",
    "inline constexpr FilmBreathOffsetsV1 kFilmBreathZeroOffsets{};",
    "",
    "namespace detail {",
    "",
    "inline double clamp(double value, double minimum, double maximum) noexcept {",
    "  if (std::isnan(value)) return value;",
    "  if (value < minimum) return minimum;",
    "  if (value > maximum) return maximum;",
    "  return value;",
    "}",
    "",
    "inline double smoothstep(double value) noexcept {",
    "  const double x = clamp(value, 0.0, 1.0);",
    "  return x * x * (3.0 - 2.0 * x);",
    "}",
    "",
    "inline std::uint32_t normalizeUint32(double value) noexcept {",
    "  if (!std::isfinite(value)) return 0u;",
    "  double wrapped = std::fmod(std::trunc(std::fabs(value)), 4294967296.0);",
    "  if (wrapped < 0.0) wrapped += 4294967296.0;",
    "  return static_cast<std::uint32_t>(wrapped);",
    "}",
    "",
    "inline std::uint32_t normalizeLattice(double value) noexcept {",
    "  if (!std::isfinite(value)) return 0u;",
    "  double wrapped = std::fmod(value, 4294967296.0);",
    "  if (wrapped < 0.0) wrapped += 4294967296.0;",
    "  return static_cast<std::uint32_t>(wrapped);",
    "}",
    "",
    "inline double hashUnit(std::uint32_t seed, double lattice, std::uint32_t salt) noexcept {",
    "  std::uint32_t value = seed;",
    `  value ^= normalizeLattice(lattice) * ${cppUint(contract.hash.latticeMultiplier)};`,
    `  value ^= salt * ${cppUint(contract.hash.saltMultiplier)};`,
    "  value ^= value >> 16u;",
    `  value *= ${cppUint(contract.hash.avalancheMultiplierA)};`,
    "  value ^= value >> 15u;",
    `  value *= ${cppUint(contract.hash.avalancheMultiplierB)};`,
    "  value ^= value >> 16u;",
    `  return static_cast<double>(value) / ${cppNumber(contract.hash.divisor)};`,
    "}",
    "",
    "inline double valueNoise(",
    "    double hostTimeSeconds,",
    "    std::uint32_t seed,",
    "    std::uint32_t salt,",
    "    double periodSeconds) noexcept {",
    `  const double phase = hashUnit(seed, 0.0, salt ^ ${cppUint(contract.noise.phaseSaltXor)}) * ${cppNumber(contract.noise.phaseScale)};`,
    "  const double position = hostTimeSeconds / periodSeconds + phase;",
    "  const double lattice = std::floor(position);",
    "  const double fraction = position - lattice;",
    "  const double a = hashUnit(seed, lattice, salt) * 2.0 - 1.0;",
    "  const double b = hashUnit(seed, lattice + 1.0, salt) * 2.0 - 1.0;",
    "  return a + (b - a) * smoothstep(fraction);",
    "}",
    "",
    "inline double breathNoise(",
    "    double hostTimeSeconds,",
    "    std::uint32_t seed,",
    "    std::uint32_t salt) noexcept {",
    `  const double fast = valueNoise(hostTimeSeconds, seed, salt ^ ${cppUint(fast.saltXor)}, kFastPeriodSeconds);`,
    `  const double medium = valueNoise(hostTimeSeconds, seed, salt ^ ${cppUint(medium.saltXor)}, kMediumPeriodSeconds);`,
    `  const double slow = valueNoise(hostTimeSeconds, seed, salt ^ ${cppUint(slow.saltXor)}, kSlowPeriodSeconds);`,
    `  const double longValue = valueNoise(hostTimeSeconds, seed, salt ^ ${cppUint(long.saltXor)}, kLongPeriodSeconds);`,
    `  const double weighted = fast * ${cppNumber(fast.weight)} + medium * ${cppNumber(medium.weight)} + slow * ${cppNumber(slow.weight)} + longValue * ${cppNumber(long.weight)};`,
    `  return clamp(weighted * ${cppNumber(contract.noise.calibration)}, ${cppNumber(contract.noise.min)}, ${cppNumber(contract.noise.max)});`,
    "}",
    "",
    "}  // namespace detail",
    "",
    "inline FilmBreathOffsetsV1 deriveFilmBreathOffsets(",
    "    double amount,",
    "    double hostTimeSeconds,",
    "    double sourceSeed) noexcept {",
    `  const double clampedAmount = detail::clamp(amount, ${cppNumber(contract.amount.min)}, ${cppNumber(contract.amount.max)});`,
    "  if (clampedAmount <= 0.0 || !std::isfinite(hostTimeSeconds) || hostTimeSeconds <= 0.0) {",
    "    return kFilmBreathZeroOffsets;",
    "  }",
    `  const double drive = std::pow(clampedAmount, ${cppNumber(contract.amount.exponent)});`,
    `  const double envelope = detail::smoothstep(hostTimeSeconds / ${cppNumber(contract.amount.envelopeSeconds)});`,
    "  const double scale = drive * envelope;",
    "  if (scale <= 0.0) return kFilmBreathZeroOffsets;",
    "  const std::uint32_t seed = detail::normalizeUint32(sourceSeed);",
    "  return {",
    "      detail::breathNoise(hostTimeSeconds, seed, kExposureSalt) * kExposureLimit * scale,",
    "      detail::breathNoise(hostTimeSeconds, seed, kContrastSalt) * kContrastLimit * scale,",
    "      detail::breathNoise(hostTimeSeconds, seed, kTemperatureSalt) * kTemperatureLimit * scale,",
    "      detail::breathNoise(hostTimeSeconds, seed, kTintSalt) * kTintLimit * scale,",
    "  };",
    "}",
    "",
    "static_assert(std::is_standard_layout_v<FilmBreathOffsetsV1>);",
    "",
    "}  // namespace filmtone::film_breath",
    "",
  ].join("\n");
}

function spatialInputHash(
  inputs: readonly LoadedSpatialContractInput[],
  key: SpatialContractInputKey,
): string {
  const input = inputs.find((candidate) => candidate.key === key);
  if (!input) {
    return fail(`missing loaded spatial contract input ${key}`);
  }
  return input.sha256;
}

function spatialParameterKind(kind: string): string {
  switch (kind) {
    case "boolean":
      return "FilmtoneSpatialParameterKindV1::boolean";
    case "real":
      return "FilmtoneSpatialParameterKindV1::real";
    case "choice":
      return "FilmtoneSpatialParameterKindV1::choice";
    default:
      return fail(`unsupported spatial parameter kind ${kind}`);
  }
}

function spatialGenericMapping(mapping: string): string {
  switch (mapping) {
    case "filmtone-only":
      return "FilmtoneSpatialGenericMappingV1::filmtoneOnly";
    case "direct":
      return "FilmtoneSpatialGenericMappingV1::direct";
    case "rejected-non-equivalent":
      return "FilmtoneSpatialGenericMappingV1::rejectedNonEquivalent";
    default:
      return fail(`unsupported spatial generic mapping ${mapping}`);
  }
}

function renderSpatialContractHeader(
  inputs: readonly LoadedSpatialContractInput[],
): string {
  const contract = FILMTONE_RESOLVE_SPATIAL_CONTRACT;
  const parameters = contract.parameterDefinitions;
  const roles = contract.nodeRoles;
  const features = contract.features;
  const parameterRows = parameters.map((parameter) =>
    `  {${cppString(parameter.id)}, ${cppString(parameter.memberName)}, ${cppString(parameter.feature)}, ` +
    `${cppString(parameter.sourceField)}, ${cppString(parameter.label)}, ${cppString(parameter.groupId)}, ` +
    `${spatialParameterKind(parameter.kind)}, ${cppString(parameter.unit)}, ` +
    `${cppNumber(parameter.defaultValue)}, ${cppNumber(parameter.minValue)}, ` +
    `${cppNumber(parameter.maxValue)}, ${cppNumber(parameter.identityValue)}, ` +
    `${cppString(parameter.normalization)}, ${spatialGenericMapping(parameter.genericMapping)}, ` +
    `${cppString(parameter.genericPath)}},`,
  );
  const roleRows = roles.map((role) =>
    `  {FilmtoneNodeRoleV1::${role.key}, ${cppString(role.key)}, ${cppString(role.label)}, ` +
    `${role.schedulesSpatial ? "true" : "false"}, ` +
    `${role.schedulesFilmModules ? "true" : "false"}},`,
  );
  const featureRows = features.map((feature) =>
    `  {${cppString(feature.id)}, ${cppString(feature.label)}, ` +
    `${cppString(feature.enabledMember)}, ${cppString(feature.identityMember)}, ` +
    `${cppString(feature.renderScaleRule)}, ${cppString(feature.aspectRule)}, ` +
    `${cppString(feature.identityCondition)}},`,
  );
  const parameterFields = parameters.map((parameter) => {
    const type = parameter.kind === "real" ? "float" : "std::uint32_t";
    const value = parameter.kind === "real"
      ? cppFloat(parameter.defaultValue)
      : `${Math.trunc(parameter.defaultValue)}u`;
    return `  ${type} ${parameter.memberName} = ${value};`;
  });

  const strength = spatialParameter("bloomStrength");
  const threshold = spatialParameter("bloomThreshold");
  const radius = spatialParameter("bloomRadius");
  const softKnee = spatialParameter("bloomSoftKnee");
  const rgbShift = spatialParameter("rgbShift");
  const lensSoftness = spatialParameter("lensSoftness");
  const detailSoftness = spatialParameter("detailSoftness");
  const vignette = spatialParameter("vignette");
  const texture = contract.spatialSemantics.textureSoftness;

  return [
    ...generatedBanner(contract.owner),
    "#pragma once",
    "",
    "#include <algorithm>",
    "#include <array>",
    "#include <cmath>",
    "#include <cstdint>",
    "#include <string_view>",
    "",
    "namespace filmtone::resolve::spatial {",
    "",
    `inline constexpr std::uint32_t kFilmtoneResolveSpatialContractVersion = ${contract.contractVersion}u;`,
    `inline constexpr std::string_view kFilmtoneResolveSpatialContractId = ${cppString(contract.contractId)};`,
    `inline constexpr std::string_view kFilmtoneResolveSpatialContractOwner = ${cppString(contract.owner)};`,
    `inline constexpr std::string_view kFilmtonePublicDisplayName = ${cppString(contract.product.publicDisplayName)};`,
    `inline constexpr std::string_view kFilmtoneCompatibilityPluginId = ${cppString(contract.product.compatibilityPluginId)};`,
    `inline constexpr std::string_view kSpatialContractSourceSha256 = ${cppString(spatialInputHash(inputs, "contract"))};`,
    `inline constexpr std::string_view kSpatialDefaultsSourceSha256 = ${cppString(spatialInputHash(inputs, "defaults"))};`,
    `inline constexpr std::string_view kSpatialRgbShiftLimitSourceSha256 = ${cppString(spatialInputHash(inputs, "rgbShiftLimit"))};`,
    `inline constexpr std::string_view kSpatialDetailSoftnessSourceSha256 = ${cppString(spatialInputHash(inputs, "detailSoftness"))};`,
    "inline constexpr bool kRoleMasksPreserveStoredValues = true;",
    "inline constexpr bool kSpatialPreservesSourceAlpha = true;",
    "inline constexpr bool kSpatialPreservesExtendedRangeRgb = true;",
    "inline constexpr float kGenericBloomColorResponseV1 = 0.0f;",
    "",
    "enum class FilmtoneNodeRoleV1 : std::uint32_t {",
    ...roles.map((role) => `  ${role.key} = ${role.value}u,`),
    "};",
    "",
    "enum class FilmtoneSpatialParameterKindV1 : std::uint32_t {",
    "  boolean = 0u,",
    "  real = 1u,",
    "  choice = 2u,",
    "};",
    "",
    "enum class FilmtoneSpatialGenericMappingV1 : std::uint32_t {",
    "  filmtoneOnly = 0u,",
    "  direct = 1u,",
    "  rejectedNonEquivalent = 2u,",
    "};",
    "",
    "struct FilmtoneNodeRoleDefinitionV1 {",
    "  FilmtoneNodeRoleV1 value;",
    "  const char* key;",
    "  const char* label;",
    "  bool schedulesSpatial;",
    "  bool schedulesFilmModules;",
    "};",
    "",
    `inline constexpr std::array<FilmtoneNodeRoleDefinitionV1, ${roles.length}> kFilmtoneNodeRoleDefinitionsV1{{`,
    ...roleRows,
    "}};",
    "",
    "struct FilmtoneSpatialParameterDefinitionV1 {",
    "  const char* id;",
    "  const char* memberName;",
    "  const char* feature;",
    "  const char* sourceField;",
    "  const char* label;",
    "  const char* groupId;",
    "  FilmtoneSpatialParameterKindV1 kind;",
    "  const char* unit;",
    "  double defaultValue;",
    "  double minValue;",
    "  double maxValue;",
    "  double identityValue;",
    "  const char* normalization;",
    "  FilmtoneSpatialGenericMappingV1 genericMapping;",
    "  const char* genericPath;",
    "};",
    "",
    `inline constexpr std::array<FilmtoneSpatialParameterDefinitionV1, ${parameters.length}> kFilmtoneSpatialParameterDefinitionsV1{{`,
    ...parameterRows,
    "}};",
    "",
    "struct FilmtoneSpatialFeatureDefinitionV1 {",
    "  const char* id;",
    "  const char* label;",
    "  const char* enabledMember;",
    "  const char* identityMember;",
    "  const char* renderScaleRule;",
    "  const char* aspectRule;",
    "  const char* identityCondition;",
    "};",
    "",
    `inline constexpr std::array<FilmtoneSpatialFeatureDefinitionV1, ${features.length}> kFilmtoneSpatialFeatureDefinitionsV1{{`,
    ...featureRows,
    "}};",
    "",
    "struct FilmtoneSpatialParametersV1 {",
    ...parameterFields,
    "};",
    "",
    "struct DeepGlowParameterViewV1 {",
    "  bool active = false;",
    `  float strength = ${cppFloat(strength.defaultValue)};`,
    `  float threshold = ${cppFloat(threshold.defaultValue)};`,
    `  float radius = ${cppFloat(radius.defaultValue)};`,
    `  float softKnee = ${cppFloat(softKnee.defaultValue)};`,
    "};",
    "",
    "struct PeripheralChromaticShiftParameterViewV1 {",
    "  bool active = false;",
    `  float amount = ${cppFloat(rgbShift.defaultValue)};`,
    "};",
    "",
    "struct LensSoftnessParameterViewV1 {",
    "  bool active = false;",
    `  float amount = ${cppFloat(lensSoftness.defaultValue)};`,
    "};",
    "",
    "struct TextureSoftnessParameterViewV1 {",
    "  bool active = false;",
    `  float amount = ${cppFloat(detailSoftness.defaultValue)};`,
    "  float effectiveAmount = 0.0f;",
    `  float kernelRadiusFullResolutionPixels = ${cppFloat(texture.kernelRadiusMinimumFullResolutionPixels)};`,
    `  float rangeSigma = ${cppFloat(texture.rangeSigma)};`,
    `  float detailAmplitudeLow = ${cppFloat(texture.detailAmplitudeLow)};`,
    `  float detailAmplitudeHigh = ${cppFloat(texture.detailAmplitudeHigh)};`,
    `  float chromaAttenuationScale = ${cppFloat(texture.chromaAttenuationScale)};`,
    `  float highlightBias = ${cppFloat(texture.highlightBias)};`,
    "};",
    "",
    "struct VignetteParameterViewV1 {",
    "  bool active = false;",
    `  float amount = ${cppFloat(vignette.defaultValue)};`,
    "};",
    "",
    `inline constexpr float kPeripheralChromaticShiftRadialExponentV1 = ${cppFloat(contract.spatialSemantics.peripheralChromaticShift.radialExponent)};`,
    `inline constexpr float kTextureSoftnessEffectiveMaximumV1 = ${cppFloat(texture.effectiveMaximum)};`,
    `inline constexpr float kTextureSoftnessKernelRadiusMinimumFullResolutionPixelsV1 = ${cppFloat(texture.kernelRadiusMinimumFullResolutionPixels)};`,
    `inline constexpr float kTextureSoftnessKernelRadiusMaximumFullResolutionPixelsV1 = ${cppFloat(texture.kernelRadiusMaximumFullResolutionPixels)};`,
    "",
    "namespace detail {",
    "",
    "inline float clampFinite(float value, float minimum, float maximum, float fallback) noexcept {",
    "  if (!std::isfinite(value)) return fallback;",
    "  return std::min(maximum, std::max(minimum, value));",
    "}",
    "",
    "}  // namespace detail",
    "",
    "[[nodiscard]] inline FilmtoneNodeRoleV1 normalizeNodeRoleV1(std::uint32_t value) noexcept {",
    "  switch (value) {",
    ...roles.map((role) =>
      `    case ${role.value}u: return FilmtoneNodeRoleV1::${role.key};`,
    ),
    "    default: return FilmtoneNodeRoleV1::all;",
    "  }",
    "}",
    "",
    "[[nodiscard]] inline bool roleSchedulesSpatialV1(std::uint32_t storedRole) noexcept {",
    "  const auto role = normalizeNodeRoleV1(storedRole);",
    "  return role == FilmtoneNodeRoleV1::all || role == FilmtoneNodeRoleV1::optics;",
    "}",
    "",
    "[[nodiscard]] inline bool roleSchedulesFilmModulesV1(std::uint32_t storedRole) noexcept {",
    "  const auto role = normalizeNodeRoleV1(storedRole);",
    "  return role == FilmtoneNodeRoleV1::all || role == FilmtoneNodeRoleV1::filmModules;",
    "}",
    "",
    "[[nodiscard]] inline DeepGlowParameterViewV1 makeDeepGlowParameterViewV1(",
    "    const FilmtoneSpatialParametersV1& parameters) noexcept {",
    `  const float strength = detail::clampFinite(parameters.bloomStrength, ${cppFloat(strength.minValue)}, ${cppFloat(strength.maxValue)}, ${cppFloat(strength.defaultValue)});`,
    "  return {",
    "      parameters.deepGlowEnabled != 0u && strength > 0.0f,",
    "      strength,",
    `      detail::clampFinite(parameters.bloomThreshold, ${cppFloat(threshold.minValue)}, ${cppFloat(threshold.maxValue)}, ${cppFloat(threshold.defaultValue)}),`,
    `      detail::clampFinite(parameters.bloomRadius, ${cppFloat(radius.minValue)}, ${cppFloat(radius.maxValue)}, ${cppFloat(radius.defaultValue)}),`,
    `      detail::clampFinite(parameters.bloomSoftKnee, ${cppFloat(softKnee.minValue)}, ${cppFloat(softKnee.maxValue)}, ${cppFloat(softKnee.defaultValue)}),`,
    "  };",
    "}",
    "",
    "[[nodiscard]] inline PeripheralChromaticShiftParameterViewV1 makePeripheralChromaticShiftParameterViewV1(",
    "    const FilmtoneSpatialParametersV1& parameters) noexcept {",
    `  const float amount = detail::clampFinite(parameters.rgbShift, ${cppFloat(rgbShift.minValue)}, ${cppFloat(rgbShift.maxValue)}, ${cppFloat(rgbShift.defaultValue)});`,
    "  return {parameters.peripheralChromaticShiftEnabled != 0u && amount > 0.0f, amount};",
    "}",
    "",
    "[[nodiscard]] inline LensSoftnessParameterViewV1 makeLensSoftnessParameterViewV1(",
    "    const FilmtoneSpatialParametersV1& parameters) noexcept {",
    `  const float amount = detail::clampFinite(parameters.lensSoftness, ${cppFloat(lensSoftness.minValue)}, ${cppFloat(lensSoftness.maxValue)}, ${cppFloat(lensSoftness.defaultValue)});`,
    "  return {parameters.lensSoftnessEnabled != 0u && amount > 0.0f, amount};",
    "}",
    "",
    "[[nodiscard]] inline TextureSoftnessParameterViewV1 makeTextureSoftnessParameterViewV1(",
    "    const FilmtoneSpatialParametersV1& parameters) noexcept {",
    `  const float amount = detail::clampFinite(parameters.detailSoftness, ${cppFloat(detailSoftness.minValue)}, ${cppFloat(detailSoftness.maxValue)}, ${cppFloat(detailSoftness.defaultValue)});`,
    "  const float effective = std::min(kTextureSoftnessEffectiveMaximumV1, amount);",
    "  const float t = effective / kTextureSoftnessEffectiveMaximumV1;",
    "  const float radius = kTextureSoftnessKernelRadiusMinimumFullResolutionPixelsV1 +",
    "      t * (kTextureSoftnessKernelRadiusMaximumFullResolutionPixelsV1 -",
    "           kTextureSoftnessKernelRadiusMinimumFullResolutionPixelsV1);",
    "  return {",
    "      parameters.textureSoftnessEnabled != 0u && amount > 0.0f,",
    "      amount,",
    "      effective,",
    "      radius,",
    `      ${cppFloat(texture.rangeSigma)},`,
    `      ${cppFloat(texture.detailAmplitudeLow)},`,
    `      ${cppFloat(texture.detailAmplitudeHigh)},`,
    `      ${cppFloat(texture.chromaAttenuationScale)},`,
    `      ${cppFloat(texture.highlightBias)},`,
    "  };",
    "}",
    "",
    "[[nodiscard]] inline VignetteParameterViewV1 makeVignetteParameterViewV1(",
    "    const FilmtoneSpatialParametersV1& parameters) noexcept {",
    `  const float amount = detail::clampFinite(parameters.vignette, ${cppFloat(vignette.minValue)}, ${cppFloat(vignette.maxValue)}, ${cppFloat(vignette.defaultValue)});`,
    "  return {parameters.vignetteEnabled != 0u && amount > 0.0f, amount};",
    "}",
    "",
    "[[nodiscard]] inline bool isSpatialConfiguredIdentityV1(",
    "    const FilmtoneSpatialParametersV1& parameters) noexcept {",
    "  return !makeDeepGlowParameterViewV1(parameters).active &&",
    "      !makePeripheralChromaticShiftParameterViewV1(parameters).active &&",
    "      !makeLensSoftnessParameterViewV1(parameters).active &&",
    "      !makeTextureSoftnessParameterViewV1(parameters).active &&",
    "      !makeVignetteParameterViewV1(parameters).active;",
    "}",
    "",
    `static_assert(kFilmtoneSpatialParameterDefinitionsV1.size() == ${parameters.length}u);`,
    `static_assert(kFilmtoneSpatialFeatureDefinitionsV1.size() == ${features.length}u);`,
    "static_assert(kGenericBloomColorResponseV1 == 0.0f);",
    "static_assert(kTextureSoftnessEffectiveMaximumV1 > 0.0f);",
    "",
    "}  // namespace filmtone::resolve::spatial",
    "",
  ].join("\n");
}

function renderResolveTimeAdapterHeader(): string {
  return [
    ...generatedBanner(
      "apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts",
    ),
    "#pragma once",
    "",
    "#include <cmath>",
    "#include <cstdint>",
    "#include <optional>",
    "",
    '#include "forestone_deterministic_render_context.hpp"',
    "",
    "namespace filmtone::resolve::contracts {",
    "",
    "struct ResolveTemporalContextV1 {",
    "  double hostTimeSeconds;",
    "  std::int64_t frameIndex;",
    "  double frameRate;",
    "};",
    "",
    "struct ResolveRenderContextV1 {",
    "  forestone::visual_render::DeterministicRenderContextV1 deterministic;",
    "",
    "  [[nodiscard]] double filmBreathHostTimeSeconds() const noexcept {",
    "    return deterministic.hostTimeSeconds;",
    "  }",
    "};",
    "",
    "[[nodiscard]] inline std::optional<ResolveTemporalContextV1> deriveResolveTemporalContextV1(",
    "    double ofxTimeFrames,",
    "    double resolvedFrameRate) noexcept {",
    "  if (!std::isfinite(ofxTimeFrames) ||",
    "      !std::isfinite(resolvedFrameRate) ||",
    "      resolvedFrameRate <= 0.0) {",
    "    return std::nullopt;",
    "  }",
    "  const double hostTimeSeconds = ofxTimeFrames / resolvedFrameRate;",
    "  const double roundedFrame = std::floor(ofxTimeFrames + 0.5);",
    "  const double int64Limit = std::ldexp(1.0, 63);",
    "  if (!std::isfinite(hostTimeSeconds) ||",
    "      !std::isfinite(roundedFrame) ||",
    "      roundedFrame < -int64Limit ||",
    "      roundedFrame >= int64Limit) {",
    "    return std::nullopt;",
    "  }",
    "  return ResolveTemporalContextV1{",
    "      hostTimeSeconds,",
    "      static_cast<std::int64_t>(roundedFrame),",
    "      resolvedFrameRate,",
    "  };",
    "}",
    "",
    "[[nodiscard]] inline std::optional<ResolveRenderContextV1> makeResolveRenderContextV1(",
    "    double ofxTimeFrames,",
    "    double resolvedFrameRate,",
    "    forestone::visual_render::DeterministicRenderContextV1 context) noexcept {",
    "  const auto temporal = deriveResolveTemporalContextV1(ofxTimeFrames, resolvedFrameRate);",
    "  if (!temporal.has_value() ||",
    "      !std::isfinite(context.renderScaleX) || context.renderScaleX <= 0.0f ||",
    "      !std::isfinite(context.renderScaleY) || context.renderScaleY <= 0.0f ||",
    "      !std::isfinite(context.boundsX) ||",
    "      !std::isfinite(context.boundsY) ||",
    "      !std::isfinite(context.boundsWidth) || context.boundsWidth <= 0.0f ||",
    "      !std::isfinite(context.boundsHeight) || context.boundsHeight <= 0.0f) {",
    "    return std::nullopt;",
    "  }",
    "  context.hostTimeSeconds = temporal->hostTimeSeconds;",
    "  context.frameIndex = temporal->frameIndex;",
    "  context.frameRate = temporal->frameRate;",
    "  return ResolveRenderContextV1{context};",
    "}",
    "",
    "}  // namespace filmtone::resolve::contracts",
    "",
  ].join("\n");
}

function renderFinishAdapterHeader(): string {
  return [
    ...generatedBanner(
      "apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts",
    ),
    "#pragma once",
    "",
    '#include "filmtone_film_breath.hpp"',
    '#include "filmtone_finish_resolve_time.hpp"',
    '#include "forestone_filmtone_finish_mapping.hpp"',
    "",
    "namespace filmtone::resolve::contracts {",
    "",
    "[[nodiscard]] inline film_breath::FilmBreathOffsetsV1 makeFilmtoneFinishFilmBreathOffsetsV1(",
    "    const forestone::filmtone::FilmtoneFinishMappingV1& mapping,",
    "    const ResolveRenderContextV1& renderContext) noexcept {",
    "  const std::uint32_t streamSeed =",
    "      forestone::visual_render::deriveDeterministicStreamSeed(",
    "          renderContext.deterministic.seed,",
    "          mapping.filmBreathStreamSalt);",
    "  return film_breath::deriveFilmBreathOffsets(",
    "      mapping.filmBreathAmount,",
    "      renderContext.filmBreathHostTimeSeconds(),",
    "      static_cast<double>(streamSeed));",
    "}",
    "",
    "[[nodiscard]] inline forestone::visual_render::FilmDamageRenderUniformsV1",
    "makeFilmtoneFinishFilmDamageUniformsV1(",
    "    const forestone::filmtone::FilmtoneFinishMappingV1& mapping,",
    "    const ResolveRenderContextV1& renderContext) noexcept {",
    "  return forestone::visual_render::makeFilmDamageRenderUniforms(",
    "      mapping.filmDamageRecipe,",
    "      renderContext.deterministic);",
    "}",
    "",
    "}  // namespace filmtone::resolve::contracts",
    "",
  ].join("\n");
}

function renderProvenanceHeader(
  filmBreathSourceSha256: string,
  spatialInputs: readonly LoadedSpatialContractInput[],
): string {
  const artifacts = FROZEN_EXTERNAL.artifacts;
  return [
    ...generatedBanner(
      "apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts",
    ),
    "#pragma once",
    "",
    "#include <cstdint>",
    "#include <string_view>",
    "",
    "namespace filmtone::resolve::contracts::provenance {",
    "",
    "inline constexpr std::uint32_t kAdapterHandoffVersion = 1u;",
    `inline constexpr std::string_view kExternalManifestPath = ${cppString(FROZEN_EXTERNAL.manifest.path)};`,
    `inline constexpr std::string_view kExternalManifestSha256 = ${cppString(FROZEN_EXTERNAL.manifest.sha256)};`,
    `inline constexpr std::string_view kFilmDamageRecipePath = ${cppString(artifacts.filmDamageRecipeHeader.path)};`,
    `inline constexpr std::string_view kFilmDamageRecipeSha256 = ${cppString(artifacts.filmDamageRecipeHeader.sha256)};`,
    `inline constexpr std::string_view kDeterministicRenderContextPath = ${cppString(artifacts.deterministicRenderContextHeader.path)};`,
    `inline constexpr std::string_view kDeterministicRenderContextSha256 = ${cppString(artifacts.deterministicRenderContextHeader.sha256)};`,
    `inline constexpr std::string_view kFilmtoneFinishMappingPath = ${cppString(artifacts.filmtoneFinishMappingHeader.path)};`,
    `inline constexpr std::string_view kFilmtoneFinishMappingSha256 = ${cppString(artifacts.filmtoneFinishMappingHeader.sha256)};`,
    `inline constexpr std::string_view kFilmBreathSourcePath = "packages/film-lab-core/src/film-breath.ts";`,
    `inline constexpr std::string_view kFilmBreathSourceSha256 = ${cppString(filmBreathSourceSha256)};`,
    `inline constexpr std::string_view kSpatialContractSourcePath = ${cppString(SPATIAL_CONTRACT_INPUTS.contract.path)};`,
    `inline constexpr std::string_view kSpatialContractSourceSha256 = ${cppString(spatialInputHash(spatialInputs, "contract"))};`,
    `inline constexpr std::string_view kSpatialDefaultsSourcePath = ${cppString(SPATIAL_CONTRACT_INPUTS.defaults.path)};`,
    `inline constexpr std::string_view kSpatialDefaultsSourceSha256 = ${cppString(spatialInputHash(spatialInputs, "defaults"))};`,
    `inline constexpr std::string_view kSpatialRgbShiftLimitSourcePath = ${cppString(SPATIAL_CONTRACT_INPUTS.rgbShiftLimit.path)};`,
    `inline constexpr std::string_view kSpatialRgbShiftLimitSourceSha256 = ${cppString(spatialInputHash(spatialInputs, "rgbShiftLimit"))};`,
    `inline constexpr std::string_view kSpatialDetailSoftnessSourcePath = ${cppString(SPATIAL_CONTRACT_INPUTS.detailSoftness.path)};`,
    `inline constexpr std::string_view kSpatialDetailSoftnessSourceSha256 = ${cppString(spatialInputHash(spatialInputs, "detailSoftness"))};`,
    "",
    "}  // namespace filmtone::resolve::contracts::provenance",
    "",
  ].join("\n");
}

function renderUmbrellaHeader(): string {
  return [
    ...generatedBanner(
      "apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts",
    ),
    "#pragma once",
    "",
    '#include "forestone_film_damage_recipe.hpp"',
    '#include "forestone_deterministic_render_context.hpp"',
    '#include "forestone_filmtone_finish_mapping.hpp"',
    '#include "filmtone_film_breath.hpp"',
    '#include "filmtone_finish_adapter.hpp"',
    '#include "filmtone_finish_contract_provenance.hpp"',
    '#include "filmtone_finish_resolve_time.hpp"',
    '#include "filmtone_resolve_spatial.hpp"',
    "",
    "static_assert(forestone::visual_effect::kFilmDamageRecipeContractVersion == 2u);",
    "static_assert(forestone::visual_effect::kFilmDamageRecipeContractRevision.size() == 3u);",
    "static_assert(forestone::visual_effect::kFilmDamageRecipeContractRevision[0] == '" +
      FROZEN_EXTERNAL.filmDamageContractRevision[0] +
      "');",
    "static_assert(forestone::visual_effect::kFilmDamageRecipeContractRevision[1] == '" +
      FROZEN_EXTERNAL.filmDamageContractRevision[1] +
      "');",
    "static_assert(forestone::visual_effect::kFilmDamageRecipeContractRevision[2] == '" +
      FROZEN_EXTERNAL.filmDamageContractRevision[2] +
      "');",
    "static_assert(forestone::visual_render::kDeterministicRenderContextContractVersion == 1u);",
    "static_assert(forestone::filmtone::kFilmtoneFinishContractVersion == 1u);",
    "static_assert(filmtone::film_breath::kFilmBreathContractVersion == 1u);",
    "static_assert(filmtone::resolve::spatial::kFilmtoneResolveSpatialContractVersion == 1u);",
    "static_assert(filmtone::resolve::spatial::kFilmtonePublicDisplayName == std::string_view{\"Filmtone\"});",
    "static_assert(filmtone::resolve::spatial::kFilmtoneCompatibilityPluginId == std::string_view{\"com.chibatakumi.filmtone.finish\"});",
    "static_assert(filmtone::resolve::spatial::kSpatialContractSourceSha256 == filmtone::resolve::contracts::provenance::kSpatialContractSourceSha256);",
    "static_assert(filmtone::resolve::spatial::kSpatialDefaultsSourceSha256 == filmtone::resolve::contracts::provenance::kSpatialDefaultsSourceSha256);",
    "static_assert(filmtone::resolve::spatial::kSpatialRgbShiftLimitSourceSha256 == filmtone::resolve::contracts::provenance::kSpatialRgbShiftLimitSourceSha256);",
    "static_assert(filmtone::resolve::spatial::kSpatialDetailSoftnessSourceSha256 == filmtone::resolve::contracts::provenance::kSpatialDetailSoftnessSourceSha256);",
    "static_assert(forestone::filmtone::kGateWeaveStreamSalt == forestone::visual_effect::kGateWeaveStreamSalt);",
    "static_assert(forestone::filmtone::kFilmDamageStreamSalt == forestone::visual_effect::kFilmDamageStreamSalt);",
    "",
  ].join("\n");
}

function relativeOutputPath(name: string): string {
  return `apps/filmtone-resolve-ofx/Sources/Generated/Contracts/${name}`;
}

const externalRoot = parseExternalRoot(process.argv.slice(2));
const manifestPath = resolveInput(externalRoot, FROZEN_EXTERNAL.manifest.path);
const manifestContents = readRequired(manifestPath, "external manifest");
const manifest = parseManifest(manifestContents);
validateManifest(manifest);
assertHash("external manifest", manifestContents, FROZEN_EXTERNAL.manifest.sha256);
validateFilmBreathContract();
validateSpatialContract();

const externalArtifacts = (
  Object.entries(FROZEN_EXTERNAL.artifacts) as Array<
    [keyof typeof FROZEN_EXTERNAL.artifacts, (typeof FROZEN_EXTERNAL.artifacts)[keyof typeof FROZEN_EXTERNAL.artifacts]]
  >
).map(([key, frozen]): LoadedArtifact => {
  const path = resolveInput(externalRoot, frozen.path);
  const contents = readRequired(path, key);
  return {
    key,
    path: frozen.path,
    outputName: frozen.outputName,
    sha256: sha256(contents),
    contents,
    text: contents.toString("utf8"),
  };
});
validateHeaderMarkers(externalArtifacts);
for (const artifact of externalArtifacts) {
  assertHash(
    artifact.key,
    artifact.contents,
    FROZEN_EXTERNAL.artifacts[artifact.key].sha256,
  );
}

const filmBreathSourceContents = readRequired(FILM_BREATH_SOURCE_PATH, "Film Breath source");
const filmBreathSourceSha256 = sha256(filmBreathSourceContents);
const spatialContractInputs = (
  Object.entries(SPATIAL_CONTRACT_INPUTS) as Array<
    [SpatialContractInputKey, (typeof SPATIAL_CONTRACT_INPUTS)[SpatialContractInputKey]]
  >
).map(([key, input]): LoadedSpatialContractInput => {
  const contents = readRequired(input.absolutePath, `spatial contract input ${key}`);
  return {
    key,
    path: input.path,
    sha256: sha256(contents),
  };
});
const outputContents = new Map<string, Buffer>();
outputContents.set("filmtone-finish-contract-v1.json", manifestContents);
for (const artifact of externalArtifacts) {
  outputContents.set(artifact.outputName, artifact.contents);
}
outputContents.set(
  "filmtone_film_breath.hpp",
  Buffer.from(renderFilmBreathHeader(), "utf8"),
);
outputContents.set(
  "filmtone_finish_resolve_time.hpp",
  Buffer.from(renderResolveTimeAdapterHeader(), "utf8"),
);
outputContents.set(
  "filmtone_finish_adapter.hpp",
  Buffer.from(renderFinishAdapterHeader(), "utf8"),
);
outputContents.set(
  "filmtone_resolve_spatial.hpp",
  Buffer.from(renderSpatialContractHeader(spatialContractInputs), "utf8"),
);
outputContents.set(
  "filmtone_finish_contract_provenance.hpp",
  Buffer.from(
    renderProvenanceHeader(filmBreathSourceSha256, spatialContractInputs),
    "utf8",
  ),
);
outputContents.set(
  "filmtone_finish_contracts.hpp",
  Buffer.from(renderUmbrellaHeader(), "utf8"),
);

const generatedOutputProvenance = [...outputContents.entries()].map(([name, contents]) => ({
  path: relativeOutputPath(name),
  sha256: sha256(contents),
}));
const provenance = {
  artifactSchemaVersion: 1,
  generatedBy: "apps/filmtone-resolve-ofx/Scripts/GenerateContracts/generate.ts",
  regenerationCommand: REGENERATION_COMMAND,
  externalInput: {
    repository: "visual-effect-core",
    manifest: FROZEN_EXTERNAL.manifest,
    contracts: {
      filmDamage: {
        version: FROZEN_EXTERNAL.filmDamageContractVersion,
        revision: FROZEN_EXTERNAL.filmDamageContractRevision,
      },
      deterministicRenderContext: {
        version: FROZEN_EXTERNAL.deterministicRenderContextContractVersion,
      },
      filmtoneFinishMapping: {
        version: FROZEN_EXTERNAL.filmtoneFinishContractVersion,
      },
    },
    artifacts: Object.values(FROZEN_EXTERNAL.artifacts).map(({ path, sha256: hash }) => ({
      path,
      sha256: hash,
    })),
    verificationState:
      "interface frozen and adapter input hashes enforced; " +
      "CONTRACT build/test/generated-artifact hash verification debt retained",
  },
  filmBreathInput: {
    owner: "packages/film-lab-core/src/film-breath.ts",
    contractVersion: FILM_BREATH_CONTRACT.contractVersion,
    sha256: filmBreathSourceSha256,
  },
  spatialInput: {
    owner: FILMTONE_RESOLVE_SPATIAL_CONTRACT.owner,
    contractId: FILMTONE_RESOLVE_SPATIAL_CONTRACT.contractId,
    contractVersion: FILMTONE_RESOLVE_SPATIAL_CONTRACT.contractVersion,
    publicDisplayName:
      FILMTONE_RESOLVE_SPATIAL_CONTRACT.product.publicDisplayName,
    compatibilityPluginId:
      FILMTONE_RESOLVE_SPATIAL_CONTRACT.product.compatibilityPluginId,
    inputs: spatialContractInputs.map(({ path, sha256: hash }) => ({
      path,
      sha256: hash,
    })),
    parameterCount:
      FILMTONE_RESOLVE_SPATIAL_CONTRACT.parameterDefinitions.length,
    featureCount: FILMTONE_RESOLVE_SPATIAL_CONTRACT.features.length,
    verificationState:
      "canonical source and generated facade/provenance hashes frozen; " +
      "build/test/Resolve verification not authorized",
  },
  generatedOutputs: generatedOutputProvenance,
};
outputContents.set(
  "filmtone_finish_contracts.provenance.json",
  Buffer.from(`${JSON.stringify(provenance, null, 2)}\n`, "utf8"),
);

mkdirSync(OUTPUT_ROOT, { recursive: true });
for (const [name, contents] of outputContents) {
  writeFileSync(resolve(OUTPUT_ROOT, name), contents);
}

process.stdout.write(
  `Generated ${outputContents.size} Filmtone Finish contract artifacts in ${OUTPUT_ROOT}.\n`,
);
