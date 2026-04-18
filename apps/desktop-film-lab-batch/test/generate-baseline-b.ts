/**
 * Baseline B generator.
 *
 * Phase 1 T1-4. DIRECTION §10 Phase 1 default:
 *   x' = x * (1 + 0.08 * smoothstep(0.92, 1.0, x))
 * applied per RGB channel in linear space (A untouched).
 *
 * Source: `test/golden/baseline-A/{preset}/{image}.jpg` (Phase 0 WebGL
 * capture, JPEG Q=95). Output: `test/golden/baseline-B/{preset}/{image}.png`
 * as the Phase 2+ PSNR reference for the WebGPU path.
 *
 * The JPEG → linear → post-hoc-linearize → sRGB → PNG pipeline simulates
 * the output the WebGL renderer *would* have produced if its final-pass
 * clamp(0,1) were removed; the WebGPU path has no such clamp natively, so
 * its output is expected to land ≤ Baseline B (PSNR ≥ 40dB target).
 *
 * Invocation:
 *   bun run apps/desktop-film-lab-batch/test/generate-baseline-b.ts
 *   bun run --cwd apps/desktop-film-lab-batch test:golden:baseline-b
 */

import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import jpeg from "jpeg-js";
import { PNG } from "pngjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const GOLDEN_ROOT = resolve(__dirname, "golden");
const BASELINE_A_ROOT = join(GOLDEN_ROOT, "baseline-A");
const BASELINE_B_ROOT = join(GOLDEN_ROOT, "baseline-B");

function srgbToLinear(v: number): number {
  const x = v / 255;
  if (x <= 0.04045) return x / 12.92;
  return Math.pow((x + 0.055) / 1.055, 2.4);
}

function linearToSrgb(x: number): number {
  let out: number;
  if (x <= 0.0031308) out = x * 12.92;
  else out = 1.055 * Math.pow(x, 1 / 2.4) - 0.055;
  return Math.max(0, Math.min(255, Math.round(out * 255)));
}

function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)));
  return t * t * (3 - 2 * t);
}

function applyHighlightLift(linearChannel: number): number {
  const clamped = Math.max(0, Math.min(1, linearChannel));
  const lift = 1 + 0.08 * smoothstep(0.92, 1.0, clamped);
  return clamped * lift;
}

interface PresetImage {
  preset: string;
  image: string;
  srcPath: string;
  dstPath: string;
}

function enumerate(): PresetImage[] {
  const presets = readdirSync(BASELINE_A_ROOT, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);
  const rows: PresetImage[] = [];
  for (const preset of presets) {
    const presetDir = join(BASELINE_A_ROOT, preset);
    const files = readdirSync(presetDir).filter((f) => f.endsWith(".jpg"));
    for (const file of files) {
      rows.push({
        preset,
        image: file,
        srcPath: join(presetDir, file),
        dstPath: join(BASELINE_B_ROOT, preset, file.replace(/\.jpg$/i, ".png")),
      });
    }
  }
  return rows;
}

function processOne(src: string): Buffer {
  const raw = readFileSync(src);
  const decoded = jpeg.decode(raw, { useTArray: true, formatAsRGBA: true });
  const { width, height, data } = decoded as {
    width: number;
    height: number;
    data: Uint8Array;
  };
  const out = new PNG({ width, height });
  // PNG buffer is RGBA uint8 in sRGB space; we linearize each channel,
  // apply the highlight lift, then encode back to sRGB.
  for (let i = 0; i < data.length; i += 4) {
    const r = applyHighlightLift(srgbToLinear(data[i]));
    const g = applyHighlightLift(srgbToLinear(data[i + 1]));
    const b = applyHighlightLift(srgbToLinear(data[i + 2]));
    out.data[i] = linearToSrgb(r);
    out.data[i + 1] = linearToSrgb(g);
    out.data[i + 2] = linearToSrgb(b);
    out.data[i + 3] = data[i + 3] ?? 255;
  }
  return PNG.sync.write(out);
}

function main(): void {
  const rows = enumerate();
  console.log(`[baseline-b] ${rows.length} files in ${BASELINE_A_ROOT}`);
  let totalBytes = 0;
  const started = performance.now();
  for (const row of rows) {
    mkdirSync(dirname(row.dstPath), { recursive: true });
    const png = processOne(row.srcPath);
    writeFileSync(row.dstPath, png);
    totalBytes += png.byteLength;
    process.stdout.write(".");
  }
  process.stdout.write("\n");
  const dt = ((performance.now() - started) / 1000).toFixed(2);
  const mb = (totalBytes / (1024 * 1024)).toFixed(2);
  console.log(`[baseline-b] wrote ${rows.length} PNGs (${mb} MB) in ${dt}s`);
}

main();
