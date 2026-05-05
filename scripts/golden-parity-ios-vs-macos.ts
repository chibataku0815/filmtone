/**
 * Phase 2 C3 truth gate — iOS canonical vs macOS Native Desktop direct PSNR.
 *
 * 案 C (06-quality-gates-risks.md row "baseline-B fixtures derive from legacy
 * WebGL render path"): Native の真値を旧 Desktop WebGL fixture に引かれない
 * ため、iOS app が出した canonical CIColorKernel export を baseline-C として
 * pin し、macOS Native Desktop の export と直接比較する。両者は同じ kernel
 * sources を verbatim lift している (Phase 1b で確認) ので、math が identical
 * なら PSNR は >> 35dB に出る。reset preset (params identity) は ∞ dB
 * (bit-identical) が期待値。
 *
 * baseline-C の生成方法は
 * `apps/desktop-film-lab-batch/test/golden/baseline-C/README.md` を参照
 * (iOS Simulator manual workflow → 実機 1 回で確定 → 以降 macOS 内 regression)。
 *
 * baseline-C は **incremental に populate される**。`<preset>/<image>.png` が
 * 存在しないセルは PENDING として報告し、harness はエラー終了しない。これに
 * より、user が iOS Simulator で 1 セルずつ baseline-C を増やしながら parity
 * を確認できる。
 *
 * Usage:
 *   bun run scripts/golden-parity-ios-vs-macos.ts
 *     [--preset <name>]          # default: reset
 *     [--image <stem>]           # default: all 10 source images
 *     [--app <path>]             # override .app binary
 *     [--threshold <db>]         # default: 35 (master handoff §7)
 */

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { promises as fs } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { PNG } from "../apps/desktop-film-lab-batch/node_modules/pngjs/lib/png.js";
import { psnr } from "../apps/desktop-film-lab-batch/test/golden-psnr.ts";

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
const BASELINE_C_DIR = resolve(
  REPO_ROOT,
  "apps/desktop-film-lab-batch/test/golden/baseline-C",
);
const OUTPUT_DIR = resolve(REPO_ROOT, "test-out/parity-ios-vs-macos");

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

const ALL_PRESETS = ["reset", "iphone", "softBlue", "amberGlow"];

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
  if (!ALL_PRESETS.includes(preset)) {
    console.error(
      `Unknown preset "${preset}". Allowed: ${ALL_PRESETS.join(", ")}`,
    );
    process.exit(64);
  }
  const imageStem = get("--image");
  const appBinary = get("--app") ?? DEFAULT_APP;
  const threshold = Number(get("--threshold") ?? 35);
  const images = imageStem ? [imageStem] : ALL_IMAGE_STEMS;
  return { preset, images, appBinary, threshold };
}

async function readPngBuffer(path: string): Promise<{ buf: Buffer; width: number; height: number }> {
  const file = await fs.readFile(path);
  const png = PNG.sync.read(file);
  return { buf: Buffer.from(png.data), width: png.width, height: png.height };
}

async function compareTwoPngs(aPath: string, bPath: string): Promise<number> {
  const a = await readPngBuffer(aPath);
  const b = await readPngBuffer(bPath);
  if (a.width !== b.width || a.height !== b.height) {
    throw new Error(
      `dimension mismatch: ${aPath}=${a.width}x${a.height} vs ${bPath}=${b.width}x${b.height}`,
    );
  }
  return psnr(a.buf, b.buf, a.width, a.height);
}

interface CellResult {
  image: string;
  vsSource: number;
  vsBaselineC: number | null; // null = baseline-C entry missing
  pending: boolean;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!existsSync(args.appBinary)) {
    console.error(
      `App binary not found: ${args.appBinary}\nRun \`bun run verify:macos\` first.`,
    );
    process.exit(2);
  }

  const baselineCPresetDir = resolve(BASELINE_C_DIR, args.preset);
  if (!existsSync(baselineCPresetDir)) {
    console.warn(
      `baseline-C/${args.preset}/ directory missing — all cells will be PENDING.`,
    );
    console.warn(
      `See ${BASELINE_C_DIR}/README.md for the iOS Simulator workflow.`,
    );
  }

  mkdirSync(OUTPUT_DIR, { recursive: true });

  console.log(`Phase 2 C3 truth gate — preset=${args.preset}`);
  console.log("=".repeat(94));
  console.log(
    `${"image".padEnd(26)}  ${"macOS↔source".padStart(14)}  ${"macOS↔baseC".padStart(14)}  status`,
  );
  console.log("-".repeat(94));

  const results: CellResult[] = [];

  for (const image of args.images) {
    const sourcePath = resolve(SOURCE_DIR, `${image}.png`);
    const macOSOutputPath = resolve(OUTPUT_DIR, `${args.preset}-${image}.png`);
    const baselineCPath = resolve(baselineCPresetDir, `${image}.png`);

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
          "--output", macOSOutputPath,
          "--preset", args.preset,
          "--no-sidecar",
        ],
        { stdio: "pipe" },
      );
    } catch (err) {
      console.error(`export failed for ${image}: ${err}`);
      results.push({ image, vsSource: NaN, vsBaselineC: NaN, pending: false });
      continue;
    }

    let vsSource: number;
    try {
      vsSource = await compareTwoPngs(macOSOutputPath, sourcePath);
    } catch (err) {
      console.error(`source compare failed for ${image}: ${err}`);
      vsSource = NaN;
    }

    let vsBaselineC: number | null = null;
    let pending = false;
    if (existsSync(baselineCPath)) {
      try {
        vsBaselineC = await compareTwoPngs(macOSOutputPath, baselineCPath);
      } catch (err) {
        console.error(`baseline-C compare failed for ${image}: ${err}`);
        vsBaselineC = NaN;
      }
    } else {
      pending = true;
    }

    results.push({ image, vsSource, vsBaselineC, pending });

    const sourceText = !Number.isFinite(vsSource)
      ? `${vsSource}`
      : vsSource === Infinity
      ? "∞ dB"
      : `${vsSource.toFixed(2)}dB`;

    let baseCText: string;
    let statusText: string;
    if (pending) {
      baseCText = "—";
      statusText = "PENDING";
    } else if (vsBaselineC === null || !Number.isFinite(vsBaselineC)) {
      baseCText = `${vsBaselineC}`;
      statusText = "ERROR";
    } else if (vsBaselineC === Infinity) {
      baseCText = "∞ dB";
      statusText = "PASS (∞)";
    } else {
      baseCText = `${vsBaselineC.toFixed(2)}dB`;
      statusText = vsBaselineC >= args.threshold ? "PASS" : "FAIL";
    }

    console.log(
      `${image.padEnd(26)}  ${sourceText.padStart(14)}  ${baseCText.padStart(14)}  ${statusText}`,
    );
  }

  console.log("=".repeat(94));

  // macOS↔source aggregate
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

  // macOS↔baseline-C aggregate
  const baselineFinite = results
    .map((r) => r.vsBaselineC)
    .filter((v): v is number => v !== null && Number.isFinite(v));
  const baselinePass = results.filter(
    (r) =>
      !r.pending &&
      r.vsBaselineC !== null &&
      Number.isFinite(r.vsBaselineC) &&
      (r.vsBaselineC === Infinity || r.vsBaselineC >= args.threshold),
  ).length;
  const baselinePresent = results.filter((r) => !r.pending && r.vsBaselineC !== null).length;
  const pendingCount = results.filter((r) => r.pending).length;
  const baselineMean =
    baselineFinite.length > 0
      ? baselineFinite.reduce((a, b) => a + b, 0) / baselineFinite.length
      : NaN;

  if (baselinePresent === 0) {
    console.log(
      `macOS↔baseC  : 0 cells with baseline-C entry (${pendingCount} PENDING) — see ${BASELINE_C_DIR}/README.md`,
    );
  } else {
    const meanText = Number.isFinite(baselineMean) ? `${baselineMean.toFixed(2)}dB` : "n/a";
    console.log(
      `macOS↔baseC  : ${baselinePass}/${baselinePresent} >= ${args.threshold}dB; mean ${meanText}` +
      (pendingCount > 0 ? ` (${pendingCount} PENDING)` : ""),
    );
  }

  console.log(
    "\nThis script compares macOS Native Desktop export against iOS canonical",
  );
  console.log(
    "CIColorKernel pipeline pinned in baseline-C/. Both lift the same kernel",
  );
  console.log(
    "sources verbatim, so identical math should produce >> 35dB (reset = ∞ dB).",
  );

  // Exit non-zero only if any cell failed (not for PENDING).
  const hardFails = results.filter(
    (r) =>
      !r.pending &&
      r.vsBaselineC !== null &&
      (Number.isNaN(r.vsBaselineC) ||
        (Number.isFinite(r.vsBaselineC) && r.vsBaselineC < args.threshold)),
  );
  if (hardFails.length > 0) {
    process.exitCode = 1;
  }
}

await main();
