import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  resolve: {
    alias: {
      "@/shared/analytics": path.join(
        __dirname,
        "src/renderer/shims/shared-analytics.ts",
      ),
      "next/navigation": path.join(
        __dirname,
        "src/renderer/shims/next-navigation.ts",
      ),
    },
  },
  test: {
    environment: "node",
    include: [
      "src/**/*.test.ts",
      "src/**/*.test.tsx",
      "electron/**/*.test.ts",
    ],
  },
});
