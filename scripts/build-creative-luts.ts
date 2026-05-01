/**
 * Filmtone iOS Creative LUT Pack 01 — orchestrator.
 *
 * Modes (mutually exclusive):
 *   --regenerate          Bake all Looks from `colorParams` and overwrite the
 *                         bundled .cube assets + manifest.
 *   --regenerate-identity Phase 1 PR placeholder mode: emit identity 33³
 *                         cubes regardless of `colorParams`. Used for the
 *                         configuration PR — Phase 2 swaps to --regenerate
 *                         after designer iteration lands.
 *   --verify              Re-bake from current source and assert the
 *                         shipped bytes match. Drift fails CI. Default mode
 *                         when no flag is passed.
 */

import { createHash } from "node:crypto";
import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";

import {
  BAKE_COLOR_IDENTITY,
  type BakeColorParams,
} from "../packages/film-lab-core/src/bake-color-only";
import {
  CREATIVE_PACK_01_BAKER_VERSION,
  CREATIVE_PACK_01_CUBE_SIZE,
  CREATIVE_PACK_01_ID,
  CREATIVE_PACK_01_LOOKS,
  type CreativePackLook,
} from "../packages/film-lab-core/src/creative-pack-01";
import {
  diagonalMaxDelta,
  makeCreativeCube,
  type CreativeCube,
} from "../packages/film-lab-core/src/creative-cube";
import { serializeCreativeCubeToText } from "../packages/film-lab-core/src/creative-cube-serialize";

type Mode = "regenerate" | "regenerate-identity" | "verify";

const REPO_ROOT = resolve(import.meta.dir, "..");
const RESOURCES_DIR = resolve(
  REPO_ROOT,
  "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts",
);
const FIXTURES_DIR = resolve(
  REPO_ROOT,
  "apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01",
);
const MANIFEST_PATH = resolve(FIXTURES_DIR, "manifest.json");
const MANIFEST_SCHEMA_VERSION = 1 as const;

interface ManifestLookEntry {
  slug: string;
  englishName: string;
  canonicalUUID: string;
  basePreset: string;
  cubeRelPath: string;
  cubeSize: number;
  cubeSha256: string;
  cubeBytes: number;
  diagonalMaxDelta: number;
  /**
   * `colorParams` snapshot at bake time. Phase 2 PR's Tier 1 fixture compares
   * a fresh bake against the recorded snapshot to catch unintended baker
   * drift. Identity placeholders show identity values here.
   */
  colorParams: BakeColorParams;
  paramOverrides: Record<string, number>;
  strength: number;
  bakeMode: "real" | "identity";
  sourceCubePath?: string;
  sourceCubeTransform?: string;
}

interface ManifestFile {
  schemaVersion: typeof MANIFEST_SCHEMA_VERSION;
  packId: string;
  bakerVersion: string;
  cubeSize: number;
  generatedAtIso: string;
  generatedFromCommit: string | null;
  bakeMode: "real" | "identity";
  looks: ManifestLookEntry[];
}

function parseMode(argv: string[]): Mode {
  if (argv.includes("--regenerate-identity")) return "regenerate-identity";
  if (argv.includes("--regenerate")) return "regenerate";
  if (argv.includes("--verify") || argv.length === 0) return "verify";
  // Allow no-flag default (verify) — same as --verify.
  return "verify";
}

function sha256Hex(bytes: Uint8Array): string {
  const hash = createHash("sha256");
  hash.update(bytes);
  return hash.digest("hex");
}

function parseCreativeCubeText(text: string, sourceLabel: string): CreativeCube {
  let size = 0;
  const values: number[] = [];

  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || line.startsWith("TITLE")) continue;
    const sizeMatch = line.match(/^LUT_3D_SIZE\s+(\d+)/);
    if (sizeMatch) {
      size = Number(sizeMatch[1]);
      continue;
    }
    if (line.startsWith("DOMAIN_MIN") || line.startsWith("DOMAIN_MAX")) continue;
    if (!/^[+-]?(?:\d|\.)/.test(line)) continue;

    const triple = line.split(/\s+/).slice(0, 3).map(Number);
    if (triple.length === 3 && triple.every(Number.isFinite)) {
      values.push(triple[0], triple[1], triple[2]);
    }
  }

  const expectedCount = size * size * size * 3;
  if (!Number.isInteger(size) || size < 2 || values.length !== expectedCount) {
    throw new Error(
      `[creative-luts] invalid cube ${sourceLabel}: size=${size}, values=${values.length}, expected=${expectedCount}`,
    );
  }

  return { size, data: Float32Array.from(values) };
}

function clamp01(x: number): number {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}

function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

function luma(r: number, g: number, b: number): number {
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function applyColdGreenDensityTransform(cube: CreativeCube): CreativeCube {
  const data = new Float32Array(cube.data.length);

  for (let i = 0; i < cube.data.length; i += 3) {
    const r = cube.data[i + 0];
    const g = cube.data[i + 1];
    const b = cube.data[i + 2];
    const lum = luma(r, g, b);
    const maxChannel = Math.max(r, g, b);
    const minChannel = Math.min(r, g, b);
    const chroma = maxChannel - minChannel;

    // The raw Green Density cube mostly differs on chromatic colors; neutral
    // urban grays stay almost identical to Palermo Reference. This deliberate
    // cold pass makes gray concrete, asphalt, and white signage visibly diverge
    // while protecting saturated reds from turning muddy.
    const neutralWeight = 1 - smoothstep(0.04, 0.22, chroma);
    const highlightProtect = 1 - smoothstep(0.72, 0.98, lum);
    const shadowPresence = 0.65 + 0.35 * smoothstep(0.02, 0.18, lum);
    const cold = 0.58 * highlightProtect * shadowPresence * (0.35 + 0.65 * neutralWeight);
    const shadowBias = 1 - lum;

    data[i + 0] = clamp01(r * (1 - 0.23 * cold) - 0.010 * cold * shadowBias);
    data[i + 1] = clamp01(g * (1 + 0.035 * cold) + 0.010 * cold * shadowBias);
    data[i + 2] = clamp01(b * (1 + 0.34 * cold) + 0.030 * cold * shadowBias);
  }

  return { size: cube.size, data };
}

function applySourceCubeTransform(cube: CreativeCube, transformName: string): CreativeCube {
  switch (transformName) {
    case "cold-green-density-v1":
      return applyColdGreenDensityTransform(cube);
    default:
      throw new Error(`[creative-luts] unknown source cube transform: ${transformName}`);
  }
}

function gitHeadCommit(): string | null {
  try {
    const headPath = resolve(REPO_ROOT, ".git/HEAD");
    const head = readFileSync(headPath, "utf8").trim();
    if (head.startsWith("ref:")) {
      const refPath = head.slice(4).trim();
      const refFull = resolve(REPO_ROOT, ".git", refPath);
      return readFileSync(refFull, "utf8").trim();
    }
    return head;
  } catch {
    return null;
  }
}

function bakeLook(look: CreativePackLook, mode: Mode): {
  text: string;
  bytes: Uint8Array;
  sha256: string;
  diagonal: number;
  paramsUsed: BakeColorParams;
  bakeMode: "real" | "identity";
  cubeSize: number;
  sourceCubePath?: string;
  sourceCubeTransform?: string;
} {
  if (mode === "regenerate" && look.sourceCubePath) {
    const bytes = readFileSync(look.sourceCubePath);
    const text = bytes.toString("utf8");
    const sourceCube = parseCreativeCubeText(text, look.sourceCubePath);
    const cube = look.sourceCubeTransform
      ? applySourceCubeTransform(sourceCube, look.sourceCubeTransform)
      : sourceCube;
    if (look.sourceCubeTransform) {
      const transformedText = serializeCreativeCubeToText(cube, {
        title: `Filmtone ${look.englishName}`,
        comments: [
          `pack=${CREATIVE_PACK_01_ID}`,
          `slug=${look.slug}`,
          `bakerVersion=${CREATIVE_PACK_01_BAKER_VERSION}`,
          `sourceCube=${look.sourceCubePath}`,
          `sourceCubeTransform=${look.sourceCubeTransform}`,
        ],
      });
      const transformedBytes = new TextEncoder().encode(transformedText);
      return {
        text: transformedText,
        bytes: transformedBytes,
        sha256: sha256Hex(transformedBytes),
        diagonal: diagonalMaxDelta(cube),
        paramsUsed: look.colorParams,
        bakeMode: "real",
        cubeSize: cube.size,
        sourceCubePath: look.sourceCubePath,
        sourceCubeTransform: look.sourceCubeTransform,
      };
    }

    return {
      text,
      bytes,
      sha256: sha256Hex(bytes),
      diagonal: diagonalMaxDelta(cube),
      paramsUsed: look.colorParams,
      bakeMode: "real",
      cubeSize: cube.size,
      sourceCubePath: look.sourceCubePath,
      sourceCubeTransform: look.sourceCubeTransform,
    };
  }

  const paramsUsed: BakeColorParams =
    mode === "regenerate-identity"
      ? { ...BAKE_COLOR_IDENTITY }
      : look.colorParams;
  const cube = makeCreativeCube({
    params: paramsUsed,
    size: CREATIVE_PACK_01_CUBE_SIZE,
  });
  const text = serializeCreativeCubeToText(cube, {
    title: `Filmtone ${look.englishName}`,
    comments: [
      `pack=${CREATIVE_PACK_01_ID}`,
      `slug=${look.slug}`,
      `bakerVersion=${CREATIVE_PACK_01_BAKER_VERSION}`,
      `bakeMode=${mode === "regenerate-identity" ? "identity" : "real"}`,
    ],
  });
  const bytes = new TextEncoder().encode(text);
  return {
    text,
    bytes,
    sha256: sha256Hex(bytes),
    diagonal: diagonalMaxDelta(cube),
    paramsUsed,
    bakeMode: mode === "regenerate-identity" ? "identity" : "real",
    cubeSize: cube.size,
  };
}

function ensureDir(path: string): void {
  mkdirSync(path, { recursive: true });
}

function relPath(absPath: string): string {
  return relative(REPO_ROOT, absPath);
}

function removeStalePackCubes(): void {
  for (const filename of readdirSync(RESOURCES_DIR)) {
    if (
      filename.startsWith("filmtone-creative-pack-01-") &&
      filename.endsWith(".cube")
    ) {
      rmSync(resolve(RESOURCES_DIR, filename));
    }
  }
}

function buildManifest(
  entries: ManifestLookEntry[],
  bakeMode: "real" | "identity",
): ManifestFile {
  return {
    schemaVersion: MANIFEST_SCHEMA_VERSION,
    packId: CREATIVE_PACK_01_ID,
    bakerVersion: CREATIVE_PACK_01_BAKER_VERSION,
    cubeSize: CREATIVE_PACK_01_CUBE_SIZE,
    generatedAtIso: new Date().toISOString(),
    generatedFromCommit: gitHeadCommit(),
    bakeMode,
    looks: entries,
  };
}

async function runRegenerate(mode: Mode): Promise<void> {
  ensureDir(RESOURCES_DIR);
  ensureDir(FIXTURES_DIR);
  removeStalePackCubes();

  const entries: ManifestLookEntry[] = [];
  let firstBakeMode: "real" | "identity" | null = null;

  for (const look of CREATIVE_PACK_01_LOOKS) {
    const baked = bakeLook(look, mode);
    if (firstBakeMode === null) firstBakeMode = baked.bakeMode;

    const cubePath = resolve(RESOURCES_DIR, `${look.slug}.cube`);
    writeFileSync(cubePath, baked.bytes);

    entries.push({
      slug: look.slug,
      englishName: look.englishName,
      canonicalUUID: look.canonicalUUID,
      basePreset: look.basePreset,
      cubeRelPath: relPath(cubePath),
      cubeSize: baked.cubeSize,
      cubeSha256: baked.sha256,
      cubeBytes: baked.bytes.length,
      diagonalMaxDelta: baked.diagonal,
      colorParams: baked.paramsUsed,
      paramOverrides: { ...look.paramOverrides } as Record<string, number>,
      strength: look.strength,
      bakeMode: baked.bakeMode,
      sourceCubePath: baked.sourceCubePath,
      sourceCubeTransform: baked.sourceCubeTransform,
    });

    console.log(
      `[creative-luts] wrote ${relPath(cubePath)}  sha256=${baked.sha256.slice(
        0,
        12,
      )}…  bytes=${baked.bytes.length}  mode=${baked.bakeMode}`,
    );
  }

  const manifest = buildManifest(entries, firstBakeMode ?? "identity");
  writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2) + "\n");
  console.log(`[creative-luts] wrote ${relPath(MANIFEST_PATH)}`);
}

async function runVerify(): Promise<void> {
  let manifestRaw: string;
  try {
    manifestRaw = readFileSync(MANIFEST_PATH, "utf8");
  } catch {
    console.error(
      `[creative-luts] manifest not found at ${relPath(MANIFEST_PATH)}. ` +
        "Run --regenerate-identity (Phase 1 placeholder) or --regenerate (Phase 2) first.",
    );
    process.exitCode = 1;
    return;
  }

  const manifest = JSON.parse(manifestRaw) as ManifestFile;
  const expectedMode = manifest.bakeMode;
  const replayMode: Mode =
    expectedMode === "identity" ? "regenerate-identity" : "regenerate";

  const failures: string[] = [];

  for (const look of CREATIVE_PACK_01_LOOKS) {
    const expected = manifest.looks.find((entry) => entry.slug === look.slug);
    if (!expected) {
      failures.push(`manifest missing entry for slug=${look.slug}`);
      continue;
    }

    const cubePath = resolve(RESOURCES_DIR, `${look.slug}.cube`);
    let onDisk: Buffer;
    try {
      onDisk = readFileSync(cubePath);
    } catch {
      failures.push(`cube missing on disk: ${relPath(cubePath)}`);
      continue;
    }
    const onDiskHash = sha256Hex(onDisk);
    if (onDiskHash !== expected.cubeSha256) {
      failures.push(
        `${look.slug}: shipped cube sha256 ${onDiskHash} != manifest ${expected.cubeSha256}`,
      );
      continue;
    }

    const fresh = bakeLook(look, replayMode);
    if (fresh.sha256 !== expected.cubeSha256) {
      failures.push(
        `${look.slug}: re-bake sha256 ${fresh.sha256} != manifest ${expected.cubeSha256}` +
          " (baker drift — Pack 01 cubes are byte-pinned; bump bakerVersion + re-run --regenerate if intentional)",
      );
    }
  }

  if (failures.length > 0) {
    console.error("[creative-luts] verify FAILED:");
    for (const f of failures) console.error(`  - ${f}`);
    process.exitCode = 1;
    return;
  }
  console.log(
    `[creative-luts] verify OK — ${CREATIVE_PACK_01_LOOKS.length} cubes, mode=${expectedMode}, packId=${manifest.packId}`,
  );
}

async function main(): Promise<void> {
  const mode = parseMode(process.argv.slice(2));
  if (mode === "regenerate" || mode === "regenerate-identity") {
    await runRegenerate(mode);
  } else {
    await runVerify();
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
