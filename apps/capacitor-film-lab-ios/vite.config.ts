import path from "node:path";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "../..");

export default defineConfig({
  plugins: [react()],
  publicDir: path.resolve(repoRoot, "public"),
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
    dedupe: ["react", "react-dom"],
  },
  server: {
    host: "127.0.0.1",
    port: 4174,
    strictPort: true,
    fs: {
      allow: [
        path.resolve(__dirname, "."),
        path.resolve(repoRoot, "messages"),
        path.resolve(repoRoot, "packages"),
        path.resolve(repoRoot, "public"),
      ],
    },
  },
});
