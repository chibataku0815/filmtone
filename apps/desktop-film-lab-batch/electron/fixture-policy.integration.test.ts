/**
 * @fileoverview Fixture-driven integration test for the HDR preparation policy.
 *
 * @overview For every video fixture under `fixtures/video/**\/*.{mov,mp4,mkv}`
 * that ships with a matching `<basename>.ffprobe.json` oracle, this test:
 *
 *   1. Runs real ffprobe against the fixture.
 *   2. Asserts the probe output is a structural superset of the oracle's
 *      `ffprobe` declaration (extra keys allowed, volatile fields like
 *      bit_rate / duration are simply not pinned by the oracle).
 *   3. Feeds the live probe metadata into `classifySourceColorForExport` and
 *      asserts the resulting colorClass matches the oracle's expected value.
 *   4. Runs `deriveDesktopHdrPreparationPolicy` against deterministic ffmpeg
 *      capability snapshots — missing filters, zscale-only, libplacebo-only,
 *      and both-capable. The returned strategy + reason must match the
 *      oracle's declared branch for each snapshot, so the test result does not
 *      depend on the runner's locally installed ffmpeg.
 *
 * When no fixtures exist the entire suite is skipped via `it.skip`, so CI stays
 * green until real HDR / SDR trims are added under `fixtures/video/{hdr,sdr}/`.
 * See `fixtures/README.md` for the capture recipe and oracle schema.
 *
 * @limitations This test invokes the real ffprobe binary resolved via
 * `resolveVideoCliBinary`. It therefore needs the same PATH-sensitive runtime
 * that the Electron main process uses. Failures from binary resolution surface
 * as real test failures when fixtures are present — intentionally loud so that
 * a broken dev environment does not silently pass this gate.
 */
import { execFile } from "node:child_process";
import { readdirSync, readFileSync, statSync, type Dirent } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { beforeAll, describe, expect, it } from "vitest";

import {
  parseFixtureOracle,
  isStructuralSubset,
  type FixtureOracle,
  type FixturePolicyCapabilityKey,
} from "./fixture-oracle";
import { resolveVideoCliBinary } from "./ffmpeg-cli-resolve";
import {
  classifySourceColorForExport,
  deriveDesktopHdrPreparationPolicy,
  deriveSourceColorMetadataFromFfprobeStream,
  deriveVideoDisplayGeometryFromFfprobeStream,
  type FFmpegHdrCapabilities,
  type SourceVideoMetadata,
} from "./video-export-source-metadata";

const execFileAsync = promisify(execFile);

const VIDEO_EXTENSIONS = new Set([".mov", ".mp4", ".mkv"]);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FIXTURES_ROOT = path.resolve(__dirname, "..", "fixtures", "video");

const POLICY_CAPABILITY_CASES: Array<{
  key: FixturePolicyCapabilityKey;
  label: string;
  capabilities: FFmpegHdrCapabilities;
}> = [
  {
    key: "missingHdrFilters",
    label: "missing HDR filters",
    capabilities: {
      hasZscale: false,
      hasLibplacebo: false,
      hasTonemap: true,
      hasColorspace: true,
    },
  },
  {
    key: "zscaleOnly",
    label: "zscale only",
    capabilities: {
      hasZscale: true,
      hasLibplacebo: false,
      hasTonemap: true,
      hasColorspace: true,
    },
  },
  {
    key: "libplaceboOnly",
    label: "libplacebo only",
    capabilities: {
      hasZscale: false,
      hasLibplacebo: true,
      hasTonemap: false,
      hasColorspace: true,
    },
  },
  {
    key: "zscaleAndLibplacebo",
    label: "zscale and libplacebo",
    capabilities: {
      hasZscale: true,
      hasLibplacebo: true,
      hasTonemap: true,
      hasColorspace: true,
    },
  },
];

type FixtureCase = {
  /** Relative path like `hdr/iphone-hlg-1s-abcd.mov`, stable test label */
  relativePath: string;
  /** Absolute path passed to ffprobe */
  absolutePath: string;
  /** Parsed `<basename>.ffprobe.json` contents */
  oracle: FixtureOracle;
};

/**
 * @description Walk the fixtures tree synchronously at test-load time. Sync I/O
 * is acceptable here because this runs once during module evaluation, before
 * any `it()` has started.
 */
function discoverFixtureCases(root: string): FixtureCase[] {
  const cases: FixtureCase[] = [];
  let rootStat;
  try {
    rootStat = statSync(root);
  } catch {
    return cases;
  }
  if (!rootStat.isDirectory()) return cases;

  const stack: string[] = [root];
  while (stack.length > 0) {
    const current = stack.pop() as string;
    let entries: Dirent<string>[];
    try {
      entries = readdirSync(current, {
        withFileTypes: true,
        encoding: "utf8",
      });
    } catch {
      continue;
    }
    for (const entry of entries) {
      const entryPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(entryPath);
        continue;
      }
      if (!entry.isFile()) continue;
      const ext = path.extname(entry.name).toLowerCase();
      if (!VIDEO_EXTENSIONS.has(ext)) continue;
      const oraclePath = `${entryPath.slice(0, -ext.length)}.ffprobe.json`;
      let oracleRaw: string;
      try {
        oracleRaw = readFileSync(oraclePath, "utf8");
      } catch {
        // A fixture without its oracle is a configuration error — fail loud
        // inside the generated test case rather than silently skipping.
        cases.push({
          relativePath: path.relative(root, entryPath),
          absolutePath: entryPath,
          oracle: {
            expected: {
              colorClass: "unknown",
              policy: { strategy: "none", reason: "source-color-unknown" },
            },
            ffprobe: {},
          },
        });
        continue;
      }
      let parsed: FixtureOracle;
      try {
        parsed = parseFixtureOracle(JSON.parse(oracleRaw));
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        throw new Error(`Invalid fixture oracle at ${oraclePath}: ${message}`);
      }
      cases.push({
        relativePath: path.relative(root, entryPath),
        absolutePath: entryPath,
        oracle: parsed,
      });
    }
  }
  cases.sort((a, b) => a.relativePath.localeCompare(b.relativePath));
  return cases;
}

const fixtureCases = discoverFixtureCases(FIXTURES_ROOT);
const hasFixtures = fixtureCases.length > 0;

type ProbedFixture = {
  streams: Array<Record<string, unknown>>;
  format: Record<string, unknown>;
  videoStream: Record<string, unknown> | undefined;
  /** Raw ffprobe JSON, for subset matching against the oracle */
  raw: Record<string, unknown>;
};

async function runLiveFfprobe(absPath: string): Promise<ProbedFixture> {
  const ffprobe = resolveVideoCliBinary("ffprobe");
  const { stdout } = await execFileAsync(
    ffprobe.commandPath,
    [
      "-v",
      "error",
      "-show_streams",
      "-show_format",
      "-of",
      "json",
      absPath,
    ],
    { maxBuffer: 10 * 1024 * 1024, env: ffprobe.childEnv },
  );
  const parsed = JSON.parse(stdout as string) as Record<string, unknown>;
  const streams = Array.isArray(parsed.streams)
    ? (parsed.streams.filter((s): s is Record<string, unknown> =>
        typeof s === "object" && s !== null,
      ) as Array<Record<string, unknown>>)
    : [];
  const format =
    typeof parsed.format === "object" && parsed.format !== null
      ? (parsed.format as Record<string, unknown>)
      : {};
  const videoStream = streams.find(
    (stream) => stream.codec_type === "video",
  );
  return { streams, format, videoStream, raw: parsed };
}

function buildSourceVideoMetadata(
  probe: ProbedFixture,
): SourceVideoMetadata {
  const videoStream = probe.videoStream ?? {};
  const rawWidth = Number(videoStream.width) || 0;
  const rawHeight = Number(videoStream.height) || 0;
  const color = deriveSourceColorMetadataFromFfprobeStream(videoStream);
  return {
    display: deriveVideoDisplayGeometryFromFfprobeStream({
      rawWidth,
      rawHeight,
      stream: videoStream,
    }),
    color,
    colorClass: classifySourceColorForExport(color),
  };
}

// When no fixtures exist, emit a single skipped sentinel test and exit.
// `describe.skipIf(true, ...)` keeps the tree visible in vitest's output, so
// the absence of fixtures is discoverable rather than silently inert.
describe.skipIf(hasFixtures)(
  "fixture-policy integration (no fixtures present)",
  () => {
    it.skip(
      "drop *.mov/*.mp4/*.mkv + <basename>.ffprobe.json under fixtures/video/",
      () => {
        // Intentional sentinel — see fixtures/README.md for the capture recipe.
      },
    );
  },
);

describe.skipIf(!hasFixtures)("fixture-policy integration", () => {
  describe.each(fixtureCases)("$relativePath", (fixture) => {
    let probe: ProbedFixture;

    beforeAll(async () => {
      probe = await runLiveFfprobe(fixture.absolutePath);
    });

    it("live ffprobe output is a structural superset of the oracle", () => {
      const mismatches = isStructuralSubset(
        fixture.oracle.ffprobe,
        probe.raw,
      );
      expect(mismatches, mismatches.join("\n")).toEqual([]);
    });

    it("classifies into the oracle's expected colorClass", () => {
      const sourceMeta = buildSourceVideoMetadata(probe);
      expect(sourceMeta.colorClass).toBe(fixture.oracle.expected.colorClass);
    });

    it("derives the oracle's expected HDR preparation policy branches", () => {
      const sourceMeta = buildSourceVideoMetadata(probe);
      const policyByCapability = fixture.oracle.expected.policyByCapability;
      if (policyByCapability) {
        for (const capabilityCase of POLICY_CAPABILITY_CASES) {
          const policy = deriveDesktopHdrPreparationPolicy(
            sourceMeta,
            capabilityCase.capabilities,
          );
          expect(
            {
              strategy: policy.strategy,
              reason: policy.reason,
            },
            capabilityCase.label,
          ).toEqual(policyByCapability[capabilityCase.key]);
        }
        return;
      }

      // Backward-compatible fallback for local pre-S-5 fixture experiments.
      // New committed fixtures should use policyByCapability.
      const policy = deriveDesktopHdrPreparationPolicy(sourceMeta, null);
      expect({
        strategy: policy.strategy,
        reason: policy.reason,
      }).toEqual(fixture.oracle.expected.policy);
    });
  });
});
