import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import {
  renderFilmtoneIosSwiftPayload,
} from "../packages/film-lab-core/src/ios-swift-payload";
import {
  renderFilmtoneIosOpticalFiltersSwift,
} from "../packages/film-lab-core/src/ios-optical-filters-swift";

const repoRoot = resolve(import.meta.dir, "..");
const checkOnly = process.argv.includes("--check");

const targets: Array<{ outputPath: string; nextContent: string }> = [
  {
    outputPath: resolve(
      repoRoot,
      "apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift",
    ),
    nextContent: renderFilmtoneIosSwiftPayload(),
  },
  {
    outputPath: resolve(
      repoRoot,
      "apps/capacitor-film-lab-ios/ios/App/App/FilmtoneOpticalFiltersGenerated.swift",
    ),
    nextContent: renderFilmtoneIosOpticalFiltersSwift(),
  },
];

for (const { outputPath, nextContent } of targets) {
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
}
