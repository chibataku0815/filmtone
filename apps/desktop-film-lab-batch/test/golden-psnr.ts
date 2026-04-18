import { promises as fs } from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { PNG } from "pngjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const GOLDEN_DIR = path.join(__dirname, "golden");

export function psnr(a: Buffer, b: Buffer, width: number, height: number): number {
  if (a.length !== b.length) throw new Error('buffer length mismatch');
  const n = width * height * 3;
  let sse = 0;
  for (let i = 0; i < a.length; i += 4) {
    const dr = a[i]! - b[i]!;
    const dg = a[i + 1]! - b[i + 1]!;
    const db = a[i + 2]! - b[i + 2]!;
    sse += dr * dr + dg * dg + db * db;
  }
  const mse = sse / n;
  return mse === 0 ? Infinity : 10 * Math.log10((255 * 255) / mse);
}

async function readPngRgba(filePath: string): Promise<PNG> {
  const buf = await fs.readFile(filePath);
  return PNG.sync.read(buf);
}

/**
 * Phase 1 T1-4. PSNR in dB between a WebGPU output PNG and the
 * post-hoc-linearized Baseline B for the same (preset × image) cell.
 *
 * `presetId` matches the directory name under `baseline-B/`; `imageId` is
 * the filename stem (no extension) — e.g. `"01-highlight-sunset"`. The
 * WebGPU output may be supplied as a file path or as a decoded RGBA
 * buffer of matching dimensions.
 *
 * Throws if Baseline B is absent; the caller is expected to have run
 * `bun run apps/desktop-film-lab-batch/test/generate-baseline-b.ts` first.
 */
export async function compareAgainstBaselineB(
  webgpuOutput: string | { width: number; height: number; data: Buffer | Uint8Array },
  presetId: string,
  imageId: string,
): Promise<number> {
  const basePath = path.join(GOLDEN_DIR, "baseline-B", presetId, `${imageId}.png`);
  const reference = await readPngRgba(basePath);

  let outputBuf: Buffer;
  let outWidth: number;
  let outHeight: number;
  if (typeof webgpuOutput === "string") {
    const decoded = await readPngRgba(webgpuOutput);
    outputBuf = Buffer.from(decoded.data);
    outWidth = decoded.width;
    outHeight = decoded.height;
  } else {
    outputBuf = Buffer.from(webgpuOutput.data);
    outWidth = webgpuOutput.width;
    outHeight = webgpuOutput.height;
  }

  if (outWidth !== reference.width || outHeight !== reference.height) {
    throw new Error(
      `compareAgainstBaselineB: dimension mismatch ` +
      `(output=${outWidth}×${outHeight}, baseline-B=${reference.width}×${reference.height})`,
    );
  }

  return psnr(outputBuf, Buffer.from(reference.data), reference.width, reference.height);
}
