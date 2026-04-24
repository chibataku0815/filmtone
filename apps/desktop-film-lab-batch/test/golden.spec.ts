import { test, expect } from "@playwright/test";
import { PRESETS } from "film-lab-core";
import {
  runBaseline,
  captureAdapterInfo,
  captureParamsPngBuffer,
  captureParityPreviewPngBuffer,
  diffPngBuffers,
  sourceImagePath,
} from "./golden.harness";

test("phase-0 baseline capture", async ({ page }) => {
  await page.goto("http://127.0.0.1:5173/?__test=1");
  await page.waitForFunction(
    () => !!(window as any).__filmtoneTest?.getViewport(),
    { timeout: 30000 },
  );
  await captureAdapterInfo(page);
  const label = (process.env.FILMTONE_GOLDEN_BASELINE ?? "A") as "A" | "B";
  const { count } = await runBaseline(page, label);
  expect(count).toBe(80);
});

test("effect sensitivity canary", async ({ page }) => {
  await page.goto("http://127.0.0.1:5173/?__test=1");
  await page.waitForFunction(
    () => !!(window as any).__filmtoneTest?.getViewport(),
    { timeout: 30000 },
  );

  const base = {
    ...PRESETS.reset,
    bloomStrength: 0,
    halationIntensity: 0,
    diffusion: 0,
    grainIntensity: 0,
    rgbShift: 0,
    lensSoftness: 0,
  } as Record<string, number | string>;
  const highEffect = {
    ...base,
    bloomThreshold: 0.25,
    bloomStrength: 2.2,
    halationIntensity: 0.8,
    diffusion: 0.8,
    grainIntensity: 0.1,
    grainSize: 0.6,
    rgbShift: 0.004,
    lensSoftness: 0.7,
  };

  const source = sourceImagePath("02-highlight-backlit.png");
  const basePng = await captureParamsPngBuffer(page, source, base);
  const effectPng = await captureParamsPngBuffer(page, source, highEffect);
  const diff = diffPngBuffers(basePng, effectPng);

  expect(diff.meanAbs).toBeGreaterThan(2);
  expect(diff.changedRatio).toBeGreaterThan(0.05);
});

test("export parity preview keeps optical render stable across UI sizes", async ({ page }) => {
  await page.goto("http://127.0.0.1:5173/?__test=1");
  await page.waitForFunction(
    () => !!(window as any).__filmtoneTest?.getViewport(),
    { timeout: 30000 },
  );

  const params = {
    ...PRESETS.reset,
    bloomThreshold: 0.28,
    bloomStrength: 2.4,
    halationIntensity: 0.75,
    diffusion: 0.85,
    rgbShift: 0.004,
    lensSoftness: 0.8,
  } as Record<string, number | string>;
  const geometry = {
    renderWidth: 1280,
    renderHeight: 720,
    sourceWidth: 1920,
    sourceHeight: 1080,
    sourceDisplayWidth: 1920,
    sourceDisplayHeight: 1080,
    fitMode: "cover" as const,
    fps: 25,
  };
  const source = sourceImagePath("02-highlight-backlit.png");
  const wideUi = await captureParityPreviewPngBuffer(page, source, params, geometry, {
    width: 640,
    height: 360,
  });
  const compactUi = await captureParityPreviewPngBuffer(page, source, params, geometry, {
    width: 360,
    height: 240,
  });
  const diff = diffPngBuffers(wideUi, compactUi);

  expect(diff.meanAbs).toBeLessThan(0.25);
  expect(diff.changedRatio).toBeLessThan(0.01);
});
