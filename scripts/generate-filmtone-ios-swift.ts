import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import {
  renderFilmtoneIosSwiftPayload,
} from "../packages/film-lab-core/src/ios-swift-payload";

const repoRoot = resolve(import.meta.dir, "..");
const outputPath = resolve(
  repoRoot,
  "apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift",
);

const nextContent = renderFilmtoneIosSwiftPayload();
const checkOnly = process.argv.includes("--check");

let currentContent = "";
try {
  currentContent = readFileSync(outputPath, "utf8");
} catch {
  currentContent = "";
}

if (checkOnly) {
  if (currentContent !== nextContent) {
    console.error(`[filmtone-ios] ${outputPath} is out of date.`);
    process.exitCode = 1;
  }
} else if (currentContent !== nextContent) {
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, nextContent);
  console.log(`[filmtone-ios] wrote ${outputPath}`);
} else {
  console.log(`[filmtone-ios] ${outputPath} is up to date`);
}
