import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './',
  testMatch: /golden\.spec\.ts$/,
  workers: 1,
  timeout: 120_000,
  fullyParallel: false,
  reporter: [['list']],
  use: {
    headless: true,
    viewport: { width: 1400, height: 900 },
  },
});
