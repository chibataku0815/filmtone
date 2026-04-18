#!/usr/bin/env node
/**
 * Blue-noise tile generator (void-and-cluster, Ulichney 1993).
 *
 * Produces a 256×256 uint8 pattern where neighboring samples are
 * maximally decorrelated (no low-frequency clumping). Used by the
 * Filmtone WebGPU grain pass — uniform in time, blue in space.
 *
 * Output: packages/film-lab-renderer/src/webgpu/assets/blue-noise-256.ts
 *   export const BLUE_NOISE_256_SIZE = 256;
 *   export const BLUE_NOISE_256_BYTES = new Uint8Array([...]);
 *
 * Invocation:
 *   bun run packages/film-lab-renderer/scripts/generate-blue-noise.mjs
 */

import { writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SIZE = 256;
const N = SIZE * SIZE;
const SIGMA = 1.9;
const TWO_SIGMA_SQ = 2 * SIGMA * SIGMA;
const KERNEL_RADIUS = 6;

// Torus distance squared (wrap-around on both axes).
function toroidDistSq(x1, y1, x2, y2) {
  let dx = Math.abs(x1 - x2);
  let dy = Math.abs(y1 - y2);
  if (dx > SIZE / 2) dx = SIZE - dx;
  if (dy > SIZE / 2) dy = SIZE - dy;
  return dx * dx + dy * dy;
}

function makeEnergy() {
  return new Float64Array(N);
}

function addEnergy(energy, cx, cy, sign) {
  for (let j = -KERNEL_RADIUS; j <= KERNEL_RADIUS; j++) {
    for (let i = -KERNEL_RADIUS; i <= KERNEL_RADIUS; i++) {
      const x = (cx + i + SIZE) % SIZE;
      const y = (cy + j + SIZE) % SIZE;
      const dsq = i * i + j * j;
      energy[y * SIZE + x] += sign * Math.exp(-dsq / TWO_SIGMA_SQ);
    }
  }
}

function findTightestCluster(pattern, energy) {
  let best = -1;
  let bestVal = -Infinity;
  for (let i = 0; i < N; i++) {
    if (pattern[i] && energy[i] > bestVal) {
      bestVal = energy[i];
      best = i;
    }
  }
  return best;
}

function findLargestVoid(pattern, energy) {
  let best = -1;
  let bestVal = Infinity;
  for (let i = 0; i < N; i++) {
    if (!pattern[i] && energy[i] < bestVal) {
      bestVal = energy[i];
      best = i;
    }
  }
  return best;
}

function seedPattern() {
  // Initial binary pattern: ~1/10 pixels on, scattered.
  const pattern = new Uint8Array(N);
  const target = Math.floor(N / 10);
  let placed = 0;
  let seed = 0x1a2b3c4d;
  function rng() {
    seed = (seed * 1664525 + 1013904223) | 0;
    return (seed >>> 0) / 0xffffffff;
  }
  while (placed < target) {
    const i = Math.floor(rng() * N);
    if (!pattern[i]) {
      pattern[i] = 1;
      placed++;
    }
  }
  return pattern;
}

function toInitialBinaryPattern() {
  // Phase 1: reposition seed pattern minima/maxima until stable.
  const pattern = seedPattern();
  const energy = makeEnergy();
  for (let i = 0; i < N; i++) if (pattern[i]) addEnergy(energy, i % SIZE, Math.floor(i / SIZE), 1);
  let iterations = 0;
  for (;;) {
    const cluster = findTightestCluster(pattern, energy);
    pattern[cluster] = 0;
    addEnergy(energy, cluster % SIZE, Math.floor(cluster / SIZE), -1);
    const voidIdx = findLargestVoid(pattern, energy);
    if (voidIdx === cluster) {
      pattern[cluster] = 1;
      addEnergy(energy, cluster % SIZE, Math.floor(cluster / SIZE), 1);
      break;
    }
    pattern[voidIdx] = 1;
    addEnergy(energy, voidIdx % SIZE, Math.floor(voidIdx / SIZE), 1);
    iterations++;
    if (iterations > 20000) break;
  }
  return { pattern, energy };
}

function generate() {
  console.log("[blue-noise] building initial binary pattern…");
  const { pattern, energy } = toInitialBinaryPattern();

  const ranks = new Int32Array(N).fill(-1);
  const workPattern = new Uint8Array(pattern);
  const workEnergy = new Float64Array(energy);

  const onCount = workPattern.reduce((a, b) => a + b, 0);

  // Phase II: remove pixels from tightest-cluster, assigning ranks
  // [onCount-1 … 0].
  let rank = onCount - 1;
  for (let step = 0; step < onCount; step++) {
    const cluster = findTightestCluster(workPattern, workEnergy);
    if (cluster < 0) break;
    workPattern[cluster] = 0;
    addEnergy(workEnergy, cluster % SIZE, Math.floor(cluster / SIZE), -1);
    ranks[cluster] = rank--;
  }

  // Phase III: re-fill from largest-void up to N/2, ranks [onCount … N/2 - 1].
  rank = onCount;
  const phase3Target = Math.floor(N / 2);
  workPattern.set(pattern);
  workEnergy.set(energy);
  for (let step = onCount; step < phase3Target; step++) {
    const voidIdx = findLargestVoid(workPattern, workEnergy);
    if (voidIdx < 0) break;
    workPattern[voidIdx] = 1;
    addEnergy(workEnergy, voidIdx % SIZE, Math.floor(voidIdx / SIZE), 1);
    ranks[voidIdx] = rank++;
  }

  // Phase IV: invert and repeat void-finding on the complement.
  const invPattern = new Uint8Array(N);
  for (let i = 0; i < N; i++) invPattern[i] = workPattern[i] ? 0 : 1;
  const invEnergy = makeEnergy();
  for (let i = 0; i < N; i++) if (invPattern[i]) addEnergy(invEnergy, i % SIZE, Math.floor(i / SIZE), 1);
  rank = phase3Target;
  for (let step = phase3Target; step < N; step++) {
    const cluster = findTightestCluster(invPattern, invEnergy);
    if (cluster < 0) break;
    invPattern[cluster] = 0;
    addEnergy(invEnergy, cluster % SIZE, Math.floor(cluster / SIZE), -1);
    ranks[cluster] = rank++;
  }

  // Normalize ranks to [0, 255].
  const out = new Uint8Array(N);
  for (let i = 0; i < N; i++) {
    const r = Math.max(0, ranks[i]);
    out[i] = Math.min(255, Math.round((r * 255) / (N - 1)));
  }
  return out;
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const outPath = resolve(__dirname, "..", "src/webgpu/assets/blue-noise-256.ts");

console.time("[blue-noise] total");
const bytes = generate();
console.timeEnd("[blue-noise] total");

const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
const header =
  "// AUTO-GENERATED by scripts/generate-blue-noise.mjs — do not edit by hand.\n" +
  "// Void-and-cluster 256×256 blue noise tile, single-channel (R8) values.\n" +
  "// Regenerate with: bun run packages/film-lab-renderer/scripts/generate-blue-noise.mjs\n\n";

const body =
  "export const BLUE_NOISE_256_SIZE = 256;\n\n" +
  `const HEX = "${hex}";\n\n` +
  "export const BLUE_NOISE_256_BYTES: Uint8Array = (() => {\n" +
  "  const out = new Uint8Array(HEX.length / 2);\n" +
  "  for (let i = 0; i < out.length; i++) {\n" +
  "    out[i] = parseInt(HEX.substr(i * 2, 2), 16);\n" +
  "  }\n" +
  "  return out;\n" +
  "})();\n";

writeFileSync(outPath, header + body, "utf8");
console.log(`[blue-noise] wrote ${bytes.length} bytes → ${outPath}`);
