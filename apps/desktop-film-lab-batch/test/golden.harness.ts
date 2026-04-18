/**
 * Phase 0 WebGPU migration — golden baseline capture harness.
 *
 * Node-side orchestrator. Invoked by `golden.spec.ts` inside Playwright.
 * The renderer's `window.__filmtoneTest` (exposed by App.tsx when `?__test=1`) is the only
 * contact surface; all preset objects are passed by value into `page.evaluate`.
 */
import type { Page } from "@playwright/test";
import { promises as fs } from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { PRESETS } from "film-lab-core";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const PRESET_NAMES = [
  "reset",
  "cinematic",
  "portra",
  "gold200",
  "pro400h",
  "bw",
  "ektar100",
  "superia400",
] as const;

export type PresetKey = (typeof PRESET_NAMES)[number];

const REPO_TEST_DIR = path.resolve(__dirname);
const GOLDEN_DIR = path.join(REPO_TEST_DIR, "golden");
const ADAPTER_INFO_PATH = path.join(GOLDEN_DIR, "adapter-info.json");
const SOURCE_IMAGES_DIR = path.join(GOLDEN_DIR, "source-images");
const SOURCE_MANIFEST_PATH = path.join(SOURCE_IMAGES_DIR, "manifest.json");

async function pathExists(p: string): Promise<boolean> {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

/**
 * Capture navigator.gpu adapter info into `test/golden/adapter-info.json`.
 * Idempotent — if the file already exists, skip.
 */
export async function captureAdapterInfo(page: Page): Promise<void> {
  if (await pathExists(ADAPTER_INFO_PATH)) {
    return;
  }
  const info = await page.evaluate(async () => {
    const nav = navigator as unknown as {
      gpu?: { requestAdapter: () => Promise<unknown> };
    };
    if (!nav.gpu) return { navigatorGpu: false };
    const adapter = (await nav.gpu.requestAdapter()) as
      | { info?: Record<string, unknown>; features?: Iterable<string> }
      | null;
    if (!adapter) return { navigatorGpu: true, adapter: null };
    const features: string[] = [];
    if (adapter.features) {
      for (const f of adapter.features as Iterable<string>) features.push(f);
    }
    return {
      navigatorGpu: true,
      adapter: {
        info: adapter.info ?? null,
        features,
      },
    };
  });
  await fs.mkdir(GOLDEN_DIR, { recursive: true });
  const payload = {
    ts: new Date().toISOString(),
    phase: "0",
    ...info,
  };
  await fs.writeFile(ADAPTER_INFO_PATH, JSON.stringify(payload, null, 2));
}

/**
 * Pull the data-URL body from a `toDataURL('image/png')` return value.
 */
function stripDataUrlPrefix(dataUrl: string): string {
  const comma = dataUrl.indexOf(",");
  return comma >= 0 ? dataUrl.slice(comma + 1) : dataUrl;
}

/**
 * Render a single (preset × image) cell and write the PNG to disk.
 */
export async function captureOne(
  page: Page,
  imagePath: string,
  presetName: PresetKey,
  outDir: string,
): Promise<void> {
  const presetData = PRESETS[presetName] as Record<string, number | string>;
  const imageBuf = await fs.readFile(imagePath);
  const imageBase64 = imageBuf.toString("base64");
  const imageStem = path.basename(imagePath, path.extname(imagePath));

  const ok = await page.evaluate(
    async (args: {
      base64: string;
      preset: Record<string, number | string>;
      width: number;
      height: number;
    }) => {
      const h = (window as any).__filmtoneTest;
      if (!h) return { ok: false, reason: "harness-missing" };
      const loaded = await h.loadImage(args.base64);
      if (!loaded) return { ok: false, reason: "loadImage-failed" };
      await h.waitTwoFrames();
      h.setCanvasSize(args.width, args.height);
      h.setParams(args.preset);
      await h.waitTwoFrames();
      h.setExportFlipY(true);
      await h.waitTwoFrames();
      const canvas = h.getCanvasEl() as HTMLCanvasElement | null;
      if (!canvas) return { ok: false, reason: "canvas-null" };
      const dataUrl = canvas.toDataURL("image/png");
      return { ok: true, dataUrl };
    },
    { base64: imageBase64, preset: presetData, width: 1280, height: 720 },
  );

  if (!ok.ok) {
    throw new Error(
      `captureOne failed for ${presetName}/${imageStem}: ${ok.reason ?? "unknown"}`,
    );
  }
  const pngBody = stripDataUrlPrefix(ok.dataUrl as string);
  const pngBuf = Buffer.from(pngBody, "base64");

  const presetDir = path.join(outDir, presetName);
  await fs.mkdir(presetDir, { recursive: true });
  await fs.writeFile(path.join(presetDir, `${imageStem}.png`), pngBuf);
}

type SourceManifestEntry = { filename?: string; path?: string };
type SourceManifest = {
  images: SourceManifestEntry[];
};

/**
 * Iterate every (preset × image) combination for the given baseline label.
 * Output goes to `test/golden/baseline-<label>/<preset>/<image>.png`.
 */
export async function runBaseline(
  page: Page,
  label: "A" | "B",
): Promise<{ count: number }> {
  const manifestRaw = await fs.readFile(SOURCE_MANIFEST_PATH, "utf8");
  const manifest = JSON.parse(manifestRaw) as SourceManifest;
  const outDir = path.join(GOLDEN_DIR, `baseline-${label}`);
  await fs.mkdir(outDir, { recursive: true });

  let count = 0;
  for (const preset of PRESET_NAMES) {
    for (const image of manifest.images) {
      const rel = image.filename ?? image.path;
      if (!rel) throw new Error(`manifest entry missing filename/path: ${JSON.stringify(image)}`);
      const absImagePath = path.isAbsolute(rel) ? rel : path.join(SOURCE_IMAGES_DIR, rel);
      await captureOne(page, absImagePath, preset, outDir);
      count += 1;
    }
  }
  return { count };
}
