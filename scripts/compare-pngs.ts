/**
 * Quick diagnostic: compute PSNR between two PNGs (RGB only, alpha skipped).
 *   bun run scripts/compare-pngs.ts <a.png> <b.png>
 */

import { promises as fs } from "node:fs";
import { PNG } from "../apps/desktop-film-lab-batch/node_modules/pngjs/lib/png.js";

async function readPng(path: string): Promise<PNG> {
  return PNG.sync.read(await fs.readFile(path));
}

function psnr(a: Buffer, b: Buffer, width: number, height: number): number {
  if (a.length !== b.length) throw new Error("buffer length mismatch");
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

function maxAbsDiff(a: Buffer, b: Buffer): { r: number; g: number; b: number } {
  let mr = 0, mg = 0, mb = 0;
  for (let i = 0; i < a.length; i += 4) {
    mr = Math.max(mr, Math.abs(a[i]! - b[i]!));
    mg = Math.max(mg, Math.abs(a[i + 1]! - b[i + 1]!));
    mb = Math.max(mb, Math.abs(a[i + 2]! - b[i + 2]!));
  }
  return { r: mr, g: mg, b: mb };
}

const [aPath, bPath] = process.argv.slice(2);
if (!aPath || !bPath) {
  console.error("usage: bun run scripts/compare-pngs.ts <a.png> <b.png>");
  process.exit(64);
}

const a = await readPng(aPath);
const b = await readPng(bPath);
if (a.width !== b.width || a.height !== b.height) {
  console.error(`dimension mismatch: ${a.width}x${a.height} vs ${b.width}x${b.height}`);
  process.exit(1);
}
const aBuf = Buffer.from(a.data);
const bBuf = Buffer.from(b.data);
console.log(`PSNR: ${psnr(aBuf, bBuf, a.width, a.height).toFixed(2)}dB`);
const md = maxAbsDiff(aBuf, bBuf);
console.log(`max |Δ| per channel: R=${md.r} G=${md.g} B=${md.b}`);

// Sample a few specific pixels
const samples = [
  [a.width / 2 | 0, a.height / 2 | 0, "center"],
  [10, 10, "topleft"],
  [a.width - 10, 10, "topright"],
  [10, a.height - 10, "bottomleft"],
];
for (const [x, y, label] of samples as Array<[number, number, string]>) {
  const i = (y * a.width + x) * 4;
  console.log(`  ${label} (${x},${y}): a=(${aBuf[i]},${aBuf[i + 1]},${aBuf[i + 2]}) b=(${bBuf[i]},${bBuf[i + 1]},${bBuf[i + 2]})`);
}
