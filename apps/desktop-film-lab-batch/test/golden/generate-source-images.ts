/**
 * Phase 0 Baseline A — Synthetic source image generator.
 *
 * Produces 10 deterministic 1280x720 PNG fixtures spanning highlight/shadow/
 * midtone/skin tonal categories for regression capture. Output:
 *   test/golden/source-images/{01..10}-*.png
 *   test/golden/source-images/manifest.json
 *
 * Run: bun run test/golden/generate-source-images.ts
 *
 * NOTE: Synthetic images are regression fixtures, not perceptual-quality bars.
 */

import { PNG } from "pngjs";
import * as fs from "node:fs";
import * as path from "node:path";

// ---------- config ----------
const WIDTH = 1280;
const HEIGHT = 720;
const SEED = 0xC0FFEE;
const OUT_DIR = path.resolve(__dirname, "source-images");

// ---------- deterministic RNG (mulberry32) ----------
function mulberry32(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------- helpers ----------
type RGB = [number, number, number];

function clamp8(v: number): number {
  return v < 0 ? 0 : v > 255 ? 255 : Math.round(v);
}

function setPixel(
  data: Buffer,
  x: number,
  y: number,
  r: number,
  g: number,
  b: number,
): void {
  const idx = (y * WIDTH + x) * 4;
  data[idx] = clamp8(r);
  data[idx + 1] = clamp8(g);
  data[idx + 2] = clamp8(b);
  data[idx + 3] = 255;
}

function fillRect(
  data: Buffer,
  x0: number,
  y0: number,
  w: number,
  h: number,
  rgb: RGB,
): void {
  const x1 = Math.min(WIDTH, x0 + w);
  const y1 = Math.min(HEIGHT, y0 + h);
  for (let y = Math.max(0, y0); y < y1; y++) {
    for (let x = Math.max(0, x0); x < x1; x++) {
      setPixel(data, x, y, rgb[0], rgb[1], rgb[2]);
    }
  }
}

function newBuffer(): Buffer {
  return Buffer.alloc(WIDTH * HEIGHT * 4);
}

function toPng(data: Buffer): Buffer {
  const png = new PNG({ width: WIDTH, height: HEIGHT });
  data.copy(png.data);
  return PNG.sync.write(png);
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

// Cheap smoothed noise: bilinear interpolate a coarse random grid.
function smoothedNoiseField(
  rng: () => number,
  cols: number,
  rows: number,
): (x: number, y: number) => number {
  const grid: number[] = new Array(cols * rows);
  for (let i = 0; i < grid.length; i++) grid[i] = rng();
  const cellW = WIDTH / (cols - 1);
  const cellH = HEIGHT / (rows - 1);
  return (x: number, y: number) => {
    const gx = x / cellW;
    const gy = y / cellH;
    const x0 = Math.floor(gx);
    const y0 = Math.floor(gy);
    const x1 = Math.min(cols - 1, x0 + 1);
    const y1 = Math.min(rows - 1, y0 + 1);
    const fx = gx - x0;
    const fy = gy - y0;
    const a = grid[y0 * cols + x0];
    const b = grid[y0 * cols + x1];
    const c = grid[y1 * cols + x0];
    const d = grid[y1 * cols + x1];
    return lerp(lerp(a, b, fx), lerp(c, d, fx), fy);
  };
}

// ---------- generators ----------

// 1. horizontal orange→yellow with sun disc.
function gen01HighlightSunset(rng: () => number): Buffer {
  const data = newBuffer();
  const L: RGB = [180, 80, 20];
  const R: RGB = [250, 220, 80];
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const t = x / (WIDTH - 1);
      const r = lerp(L[0], R[0], t);
      const g = lerp(L[1], R[1], t);
      const b = lerp(L[2], R[2], t);
      setPixel(data, x, y, r, g, b);
    }
  }
  // sun disc at (960, 300), radius 60
  const cx = 960, cy = 300, radius = 60;
  for (let y = cy - radius; y <= cy + radius; y++) {
    for (let x = cx - radius; x <= cx + radius; x++) {
      if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT) continue;
      const dx = x - cx, dy = y - cy;
      const d = Math.sqrt(dx * dx + dy * dy);
      if (d <= radius) {
        const falloff = 1 - d / radius;
        const idx = (y * WIDTH + x) * 4;
        const baseR = data[idx], baseG = data[idx + 1], baseB = data[idx + 2];
        setPixel(
          data,
          x,
          y,
          lerp(baseR, 255, falloff),
          lerp(baseG, 250, falloff),
          lerp(baseB, 200, falloff),
        );
      }
    }
  }
  // tiny noise to avoid flat banding
  for (let i = 0; i < data.length; i += 4) {
    const n = (rng() - 0.5) * 2;
    data[i] = clamp8(data[i] + n);
    data[i + 1] = clamp8(data[i + 1] + n);
    data[i + 2] = clamp8(data[i + 2] + n);
  }
  return toPng(data);
}

// 2. bright window (top half) + dark silhouette ellipse center-bottom.
function gen02HighlightBacklit(): Buffer {
  const data = newBuffer();
  fillRect(data, 0, 0, WIDTH, HEIGHT, [40, 40, 45]);
  fillRect(data, 0, 0, WIDTH, HEIGHT / 2, [240, 235, 220]);
  // silhouette ellipse at center-bottom
  const cx = WIDTH / 2;
  const cy = HEIGHT * 0.72;
  const rx = 140, ry = 220;
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const nx = (x - cx) / rx;
      const ny = (y - cy) / ry;
      if (nx * nx + ny * ny <= 1) {
        setPixel(data, x, y, 20, 20, 20);
      }
    }
  }
  return toPng(data);
}

// 3. high-key white dress — bg ~235, fabric patch with noise 245-255 + fold lines.
function gen03HighkeyWhiteDress(rng: () => number): Buffer {
  const data = newBuffer();
  for (let y = 0; y < HEIGHT; y++) {
    const tY = y / (HEIGHT - 1);
    const baseR = lerp(240, 230, tY);
    const baseG = lerp(240, 230, tY);
    const baseB = lerp(245, 235, tY);
    for (let x = 0; x < WIDTH; x++) {
      const n = (rng() - 0.5) * 6;
      setPixel(data, x, y, baseR + n, baseG + n, baseB + n);
    }
  }
  // fabric patch: 520x420 centered
  const px0 = (WIDTH - 520) / 2;
  const py0 = (HEIGHT - 420) / 2;
  for (let y = py0; y < py0 + 420; y++) {
    for (let x = px0; x < px0 + 520; x++) {
      const v = 245 + Math.floor(rng() * 11); // 245..255
      setPixel(data, x, y, v, v, v);
    }
  }
  // faint darker fold lines (stay >= 200)
  for (let k = 0; k < 6; k++) {
    const y = Math.floor(py0 + rng() * 420);
    const amp = 6 + Math.floor(rng() * 8);
    for (let x = px0; x < px0 + 520; x++) {
      const idx = (y * WIDTH + x) * 4;
      data[idx] = clamp8(data[idx] - amp);
      data[idx + 1] = clamp8(data[idx + 1] - amp);
      data[idx + 2] = clamp8(data[idx + 2] - amp);
    }
  }
  return toPng(data);
}

// 4. high-key cloud — noise ~230 with soft low-freq blobs 210..250.
function gen04HighkeyCloud(rng: () => number): Buffer {
  const data = newBuffer();
  const field = smoothedNoiseField(rng, 12, 8);
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const f = field(x, y); // 0..1
      const base = lerp(210, 250, f);
      const n = (rng() - 0.5) * 6;
      setPixel(data, x, y, base + n, base - 2 + n, base - 4 + n);
    }
  }
  return toPng(data);
}

// 5. low-key vertical gradient (bottom 5,5,8 → top 50,50,55) + fine noise.
function gen05LowkeyShadow(rng: () => number): Buffer {
  const data = newBuffer();
  for (let y = 0; y < HEIGHT; y++) {
    const t = 1 - y / (HEIGHT - 1); // top=1 => 50; bottom=0 => 5
    const r = lerp(5, 50, t);
    const g = lerp(5, 50, t);
    const b = lerp(8, 55, t);
    for (let x = 0; x < WIDTH; x++) {
      const n = (rng() - 0.5) * 8; // +/-4
      setPixel(data, x, y, r + n, g + n, b + n);
    }
  }
  return toPng(data);
}

// 6. low-key noir — RGB 8,8,12 bg + diagonal highlight stripe 80px wide.
function gen06LowkeyNoir(rng: () => number): Buffer {
  const data = newBuffer();
  fillRect(data, 0, 0, WIDTH, HEIGHT, [8, 8, 12]);
  // add tiny noise
  for (let i = 0; i < data.length; i += 4) {
    const n = (rng() - 0.5) * 3;
    data[i] = clamp8(data[i] + n);
    data[i + 1] = clamp8(data[i + 1] + n);
    data[i + 2] = clamp8(data[i + 2] + n);
    data[i + 3] = 255;
  }
  // diagonal stripe: y = x * (HEIGHT/WIDTH) + c; width 80
  const slope = HEIGHT / WIDTH;
  const stripeHalf = 40;
  for (let x = 0; x < WIDTH; x++) {
    const yCenter = Math.round(x * slope);
    for (let dy = -stripeHalf; dy <= stripeHalf; dy++) {
      const y = yCenter + dy;
      if (y < 0 || y >= HEIGHT) continue;
      // soft edge — linear falloff near bounds
      const edge = 1 - Math.abs(dy) / stripeHalf;
      const e = Math.max(0, edge);
      const r = lerp(8, 200, e);
      const g = lerp(8, 195, e);
      const b = lerp(12, 185, e);
      setPixel(data, x, y, r, g, b);
    }
  }
  return toPng(data);
}

// 7. 18% gray + 4x3 Macbeth-ish color chart bottom-right.
function gen07MidtoneGray(rng: () => number): Buffer {
  const data = newBuffer();
  for (let i = 0; i < data.length; i += 4) {
    const n = (rng() - 0.5) * 2;
    data[i] = clamp8(118 + n);
    data[i + 1] = clamp8(118 + n);
    data[i + 2] = clamp8(118 + n);
    data[i + 3] = 255;
  }
  // Chart region: 300x225 in lower-right quadrant. 4 cols x 3 rows, each 75x75.
  const chartX0 = WIDTH - 300 - 40; // some margin
  const chartY0 = HEIGHT - 225 - 40;
  const patches: RGB[] = [
    [180, 50, 50],   // R
    [50, 180, 50],   // G
    [50, 50, 180],   // B
    [50, 180, 180],  // C
    [180, 50, 180],  // M
    [180, 180, 50],  // Y
    [235, 200, 175], // light skin
    [195, 150, 120], // mid skin
    [120, 85, 60],   // dark skin
    [80, 80, 80],    // dark gray
    [160, 160, 160], // light gray
    [240, 240, 240], // near white
  ];
  for (let i = 0; i < 12; i++) {
    const col = i % 4;
    const row = Math.floor(i / 4);
    fillRect(data, chartX0 + col * 75, chartY0 + row * 75, 75, 75, patches[i]);
  }
  return toPng(data);
}

// 8. three stacked horizontal RGB gradient stripes.
function gen08MidtoneGradient(): Buffer {
  const data = newBuffer();
  const third = Math.floor(HEIGHT / 3);
  for (let y = 0; y < HEIGHT; y++) {
    const band = y < third ? 0 : y < 2 * third ? 1 : 2;
    for (let x = 0; x < WIDTH; x++) {
      const t = x / (WIDTH - 1);
      const v = lerp(60, 200, t);
      let r = 110, g = 110, b = 110;
      if (band === 0) r = v;
      else if (band === 1) g = v;
      else b = v;
      setPixel(data, x, y, r, g, b);
    }
  }
  return toPng(data);
}

// 9. light skin swatch with shadow side + cheek flush.
function gen09SkinLight(rng: () => number): Buffer {
  const data = newBuffer();
  // base fills full frame — left=lit, right=shadow.
  const litBase: RGB = [225, 190, 170];
  const shadow: RGB = [180, 140, 115];
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      // smooth left→right transition with a bias curve
      const t = Math.min(1, Math.max(0, (x - WIDTH * 0.35) / (WIDTH * 0.55)));
      const r = lerp(litBase[0], shadow[0], t) + (rng() - 0.5) * 4;
      const g = lerp(litBase[1], shadow[1], t) + (rng() - 0.5) * 4;
      const b = lerp(litBase[2], shadow[2], t) + (rng() - 0.5) * 4;
      setPixel(data, x, y, r, g, b);
    }
  }
  // cheek-flush disc toward lit side
  const cx = WIDTH * 0.3, cy = HEIGHT * 0.55, rad = 120;
  for (let y = cy - rad; y <= cy + rad; y++) {
    for (let x = cx - rad; x <= cx + rad; x++) {
      if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT) continue;
      const dx = x - cx, dy = y - cy;
      const d = Math.sqrt(dx * dx + dy * dy);
      if (d > rad) continue;
      const falloff = Math.pow(1 - d / rad, 2);
      const idx = (Math.floor(y) * WIDTH + Math.floor(x)) * 4;
      data[idx] = clamp8(lerp(data[idx], 235, falloff));
      data[idx + 1] = clamp8(lerp(data[idx + 1], 170, falloff));
      data[idx + 2] = clamp8(lerp(data[idx + 2], 160, falloff));
    }
  }
  return toPng(data);
}

// 10. dark skin — base 110/75/55 with highlights/shadows.
function gen10SkinDark(rng: () => number): Buffer {
  const data = newBuffer();
  const base: RGB = [110, 75, 55];
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const n = (rng() - 0.5) * 5;
      setPixel(data, x, y, base[0] + n, base[1] + n, base[2] + n);
    }
  }
  // highlight region (upper-left elliptical blend up to 150,110,85)
  const hx = WIDTH * 0.32, hy = HEIGHT * 0.38, hrx = 300, hry = 200;
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const nx = (x - hx) / hrx;
      const ny = (y - hy) / hry;
      const d2 = nx * nx + ny * ny;
      if (d2 < 1) {
        const falloff = Math.pow(1 - d2, 2);
        const idx = (y * WIDTH + x) * 4;
        data[idx] = clamp8(lerp(data[idx], 150, falloff));
        data[idx + 1] = clamp8(lerp(data[idx + 1], 110, falloff));
        data[idx + 2] = clamp8(lerp(data[idx + 2], 85, falloff));
      }
    }
  }
  // deep shadow pocket (lower-right, down to 40,25,18)
  const sx = WIDTH * 0.78, sy = HEIGHT * 0.72, srx = 260, sry = 180;
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const nx = (x - sx) / srx;
      const ny = (y - sy) / sry;
      const d2 = nx * nx + ny * ny;
      if (d2 < 1) {
        const falloff = Math.pow(1 - d2, 2);
        const idx = (y * WIDTH + x) * 4;
        data[idx] = clamp8(lerp(data[idx], 40, falloff));
        data[idx + 1] = clamp8(lerp(data[idx + 1], 25, falloff));
        data[idx + 2] = clamp8(lerp(data[idx + 2], 18, falloff));
      }
    }
  }
  // tiny noise pass for grain
  for (let i = 0; i < data.length; i += 4) {
    const n = (rng() - 0.5) * 3;
    data[i] = clamp8(data[i] + n);
    data[i + 1] = clamp8(data[i + 1] + n);
    data[i + 2] = clamp8(data[i + 2] + n);
  }
  return toPng(data);
}

// ---------- orchestration ----------

interface ManifestImage {
  filename: string;
  category: string;
  description: string;
}

const MANIFEST_IMAGES: ManifestImage[] = [
  { filename: "01-highlight-sunset.png",    category: "highlight-rich", description: "Gradient + sun disc, highlights dominant" },
  { filename: "02-highlight-backlit.png",   category: "highlight-rich", description: "Bright backlight + dark silhouette" },
  { filename: "03-highkey-whitedress.png",  category: "high-key",       description: "Overall high-luminance scene" },
  { filename: "04-highkey-cloud.png",       category: "high-key",       description: "Cloudy high-key with soft low-freq noise" },
  { filename: "05-lowkey-shadow.png",       category: "low-key",        description: "Near-black gradient with fine noise" },
  { filename: "06-lowkey-noir.png",         category: "low-key",        description: "Dark background + narrow highlight stripe" },
  { filename: "07-midtone-gray.png",        category: "midtone",        description: "18% gray + color/skin chart" },
  { filename: "08-midtone-gradient.png",    category: "midtone",        description: "RGB stripe gradients for balance" },
  { filename: "09-skin-light.png",          category: "skin",           description: "Light skin swatch with cheek flush" },
  { filename: "10-skin-dark.png",           category: "skin",           description: "Dark skin swatch with highlight/shadow range" },
];

function main(): void {
  const start = Date.now();
  if (!fs.existsSync(OUT_DIR)) {
    fs.mkdirSync(OUT_DIR, { recursive: true });
  }

  // Each generator gets its own RNG instance seeded from SEED + index so that
  // a change to any single image doesn't cascade into the others.
  const jobs: Array<(rng: () => number) => Buffer> = [
    (rng) => gen01HighlightSunset(rng),
    (_rng) => gen02HighlightBacklit(),
    (rng) => gen03HighkeyWhiteDress(rng),
    (rng) => gen04HighkeyCloud(rng),
    (rng) => gen05LowkeyShadow(rng),
    (rng) => gen06LowkeyNoir(rng),
    (rng) => gen07MidtoneGray(rng),
    (_rng) => gen08MidtoneGradient(),
    (rng) => gen09SkinLight(rng),
    (rng) => gen10SkinDark(rng),
  ];

  const sizes: Array<{ filename: string; bytes: number }> = [];
  for (let i = 0; i < jobs.length; i++) {
    const meta = MANIFEST_IMAGES[i];
    const rng = mulberry32(SEED + i * 0x9E3779B1);
    const buf = jobs[i](rng);
    const outPath = path.join(OUT_DIR, meta.filename);
    fs.writeFileSync(outPath, buf);
    sizes.push({ filename: meta.filename, bytes: buf.length });
    console.log(`  [${String(i + 1).padStart(2, "0")}/10] ${meta.filename}  ${(buf.length / 1024).toFixed(1)} KB`);
  }

  const manifest = {
    provenance: "synthetic-phase-0",
    generator: "test/golden/generate-source-images.ts",
    seed: SEED,
    size: [WIDTH, HEIGHT],
    images: MANIFEST_IMAGES,
    note:
      "Phase 0 synthetic. Replace with real photography in Phase 1 if perceptual review required.",
  };
  fs.writeFileSync(
    path.join(OUT_DIR, "manifest.json"),
    JSON.stringify(manifest, null, 2) + "\n",
  );

  const elapsed = Date.now() - start;
  const totalKB = sizes.reduce((s, x) => s + x.bytes, 0) / 1024;
  console.log(
    `\nGenerated 10 images + manifest in ${elapsed} ms (total ${totalKB.toFixed(1)} KB) -> ${OUT_DIR}`,
  );
}

main();
