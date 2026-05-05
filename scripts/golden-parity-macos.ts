/**
 * Phase 1b parity harness for the macOS Native Desktop still pipeline.
 *
 * This script drives FilmtoneDesktop's headless `--export-still` mode for
 * each (preset × source-image) cell and reports two PSNR numbers:
 *
 *   - **macOS vs source** — proves the CIImage roundtrip is correct. For
 *     `reset` preset (params identity) the macOS output should be
 *     bit-identical to source.
 *   - **macOS vs baseline-B** — pre-existing reference is the WebGL
 *     post-hoc-linearized capture from Phase 0 (`baseline-A` JPEG → linearize
 *     → highlight lift → sRGB → PNG). The fixture represents the legacy
 *     WebGL render path; the macOS pipeline lifts iOS's canonical
 *     `baseGradeV2` / `filmCompressionV2` / `printStage` CIColorKernel
 *     sources verbatim, which is a different stage graph (no LUT1/LUT2,
 *     no optics, no WebGL canvas EOTF/OETF flow). Parity here is therefore
 *     informational, not a gate, until Phase 2 either ports the WebGL
 *     pipeline or regenerates the fixtures from the iOS-canonical path.
 *
 * Optics (bloom / halation / diffusion / vignette / grain / motion blur)
 * are deferred to Phase 2 per master handoff §7. Of the 4 built-in presets
 * emitted by `bun run generate:swift`, only `reset` overlaps with
 * baseline-B's preset directory list — iphone / softBlue / amberGlow have
 * no fixture and are skipped here.
 *
 * Usage:
 *   bun run scripts/golden-parity-macos.ts
 *     [--preset <name>]          # default: reset
 *     [--image <stem>]           # default: all 10 source images
 *     [--app <path>]             # override .app binary
 *     [--threshold <db>]         # default: 35 (master handoff §7)
 */

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { compareAgainstBaselineB, psnr } from "../apps/desktop-film-lab-batch/test/golden-psnr.ts";
import { promises as fs } from "node:fs";
import { PNG } from "../apps/desktop-film-lab-batch/node_modules/pngjs/lib/png.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, "..");
const DEFAULT_APP = resolve(
  REPO_ROOT,
  "apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop",
);
const SOURCE_DIR = resolve(
  REPO_ROOT,
  "apps/desktop-film-lab-batch/test/golden/source-images",
);
const BASELINE_B_DIR = resolve(
  REPO_ROOT,
  "apps/desktop-film-lab-batch/test/golden/baseline-B",
);
const OUTPUT_DIR = resolve(REPO_ROOT, "test-out/parity");

const ALL_IMAGE_STEMS = [
  "01-highlight-sunset",
  "02-highlight-backlit",
  "03-highkey-whitedress",
  "04-highkey-cloud",
  "05-lowkey-shadow",
  "06-lowkey-noir",
  "07-midtone-gray",
  "08-midtone-gradient",
  "09-skin-light",
  "10-skin-dark",
];

interface ParityArgs {
  preset: string;
  images: string[];
  appBinary: string;
  threshold: number;
}

function parseArgs(argv: string[]): ParityArgs {
  const get = (flag: string): string | undefined => {
    const idx = argv.indexOf(flag);
    return idx >= 0 && idx + 1 < argv.length ? argv[idx + 1] : undefined;
  };
  const preset = get("--preset") ?? "reset";
  const imageStem = get("--image");
  const appBinary = get("--app") ?? DEFAULT_APP;
  const threshold = Number(get("--threshold") ?? 35);
  const images = imageStem ? [imageStem] : ALL_IMAGE_STEMS;
  return { preset, images, appBinary, threshold };
}

async function compareAgainstSource(macOsPath: string, sourcePath: string): Promise<number> {
  const aBuf = await fs.readFile(macOsPath);
  const bBuf = await fs.readFile(sourcePath);
  const a = PNG.sync.read(aBuf);
  const b = PNG.sync.read(bBuf);
  if (a.width !== b.width || a.height !== b.height) {
    throw new Error(
      `dimension mismatch: macOS=${a.width}x${a.height} vs source=${b.width}x${b.height}`,
    );
  }
  return psnr(Buffer.from(a.data), Buffer.from(b.data), a.width, a.height);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!existsSync(args.appBinary)) {
    console.error(
      `App binary not found: ${args.appBinary}\nRun \`bun run verify:macos\` first.`,
    );
    process.exit(2);
  }

  const baselineDir = resolve(BASELINE_B_DIR, args.preset);
  const baselineExists = existsSync(baselineDir);
  if (!baselineExists) {
    console.warn(
      `Baseline-B missing for preset "${args.preset}" — only reporting macOS-vs-source.`,
    );
  }

  mkdirSync(OUTPUT_DIR, { recursive: true });

  console.log(`Phase 1b parity — preset=${args.preset}`);
  console.log("=".repeat(86));
  console.log(
    `${"image".padEnd(26)}  ${"macOS↔source".padStart(14)}  ${"macOS↔baseB".padStart(14)}`,
  );
  console.log("-".repeat(86));

  const results: Array<{ image: string; vsSource: number; vsBaseline: number | null }> = [];

  for (const image of args.images) {
    const sourcePath = resolve(SOURCE_DIR, `${image}.png`);
    const outputPath = resolve(OUTPUT_DIR, `${args.preset}-${image}.png`);

    if (!existsSync(sourcePath)) {
      console.warn(`skip ${image}: source missing (${sourcePath})`);
      continue;
    }

    try {
      execFileSync(
        args.appBinary,
        [
          "--export-still",
          "--input", sourcePath,
          "--output", outputPath,
          "--preset", args.preset,
          "--no-sidecar",
        ],
        { stdio: "pipe" },
      );
    } catch (err) {
      console.error(`export failed for ${image}: ${err}`);
      results.push({ image, vsSource: NaN, vsBaseline: NaN });
      continue;
    }

    let vsSource: number;
    try {
      vsSource = await compareAgainstSource(outputPath, sourcePath);
    } catch (err) {
      console.error(`source compare failed for ${image}: ${err}`);
      vsSource = NaN;
    }

    let vsBaseline: number | null = null;
    if (baselineExists) {
      try {
        vsBaseline = await compareAgainstBaselineB(outputPath, args.preset, image);
      } catch (err) {
        console.error(`baseline-B compare failed for ${image}: ${err}`);
        vsBaseline = NaN;
      }
    }

    results.push({ image, vsSource, vsBaseline });

    const sourceText = !Number.isFinite(vsSource)
      ? `${vsSource}`
      : vsSource === Infinity
      ? "∞ dB"
      : `${vsSource.toFixed(2)}dB`;
    const baselineText =
      vsBaseline === null
        ? "—"
        : !Number.isFinite(vsBaseline)
        ? `${vsBaseline}`
        : vsBaseline === Infinity
        ? "∞ dB"
        : `${vsBaseline.toFixed(2)}dB`;

    console.log(
      `${image.padEnd(26)}  ${sourceText.padStart(14)}  ${baselineText.padStart(14)}`,
    );
  }

  console.log("=".repeat(86));

  const sourceFinite = results
    .map((r) => r.vsSource)
    .filter((v) => Number.isFinite(v) && v !== Infinity);
  const sourceMean =
    sourceFinite.length > 0
      ? sourceFinite.reduce((a, b) => a + b, 0) / sourceFinite.length
      : NaN;
  const sourceInfCount = results.filter((r) => r.vsSource === Infinity).length;
  const sourceText = sourceInfCount === results.length
    ? "all ∞ dB (bit-identical roundtrip)"
    : Number.isFinite(sourceMean)
    ? `mean ${sourceMean.toFixed(2)}dB (${sourceInfCount}/${results.length} bit-identical)`
    : "n/a";
  console.log(`macOS↔source : ${sourceText}`);

  if (baselineExists) {
    const baselineFinite = results
      .map((r) => r.vsBaseline)
      .filter((v): v is number => v !== null && Number.isFinite(v));
    const baselineMean =
      baselineFinite.length > 0
        ? baselineFinite.reduce((a, b) => a + b, 0) / baselineFinite.length
        : NaN;
    const baselinePass = results.filter(
      (r) => r.vsBaseline !== null && Number.isFinite(r.vsBaseline) && r.vsBaseline >= args.threshold,
    ).length;
    console.log(
      `macOS↔baseB  : ${baselinePass}/${results.length} ≥ ${args.threshold}dB; mean ${
        Number.isFinite(baselineMean) ? baselineMean.toFixed(2) + "dB" : "n/a"
      }`,
    );
    console.log(
      "\nNote: baseline-B was generated from the legacy WebGL render path",
    );
    console.log(
      "(see apps/desktop-film-lab-batch/test/generate-baseline-b.ts).",
    );
    console.log(
      "macOS lifts iOS's canonical CIColorKernel grade — different stage graph,",
    );
    console.log(
      "so baseline-B parity is informational until Phase 2.",
    );
  }
}

await main();
