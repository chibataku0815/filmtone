import { test, expect } from "@playwright/test";
import { PRESETS } from "film-lab-core";
import {
  runBaseline,
  captureAdapterInfo,
  captureParamsPngBuffer,
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
