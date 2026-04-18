import { test, expect } from "@playwright/test";
import { runBaseline, captureAdapterInfo } from "./golden.harness";

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
