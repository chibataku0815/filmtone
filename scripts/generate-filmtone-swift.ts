import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import {
  renderFilmtoneIosSwiftPayload,
} from "../packages/film-lab-core/src/ios-swift-payload";
import {
  renderFilmtoneIosOpticalFiltersSwift,
} from "../packages/film-lab-core/src/ios-optical-filters-swift";

interface SwiftTarget {
  id: string;
  outputPath: string;
  nextContent: string;
}

const repoRoot = resolve(import.meta.dir, "..");
const phase0Content = renderFilmtoneIosSwiftPayload();

const targets: SwiftTarget[] = [
  {
    id: "ios-phase0",
    outputPath: resolve(
      repoRoot,
      "apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift",
    ),
    nextContent: phase0Content,
  },
  {
    id: "ios-optical-filters",
    outputPath: resolve(
      repoRoot,
      "apps/capacitor-film-lab-ios/ios/App/App/FilmtoneOpticalFiltersGenerated.swift",
    ),
    nextContent: renderFilmtoneIosOpticalFiltersSwift(),
  },
  {
    id: "macos-phase0",
    outputPath: resolve(
      repoRoot,
      "apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift",
    ),
    nextContent: phase0Content,
  },
];

const checkOnly = process.argv.includes("--check");

let exitCode = 0;
for (const target of targets) {
  let currentContent = "";
  try {
    currentContent = readFileSync(target.outputPath, "utf8");
  } catch {
    currentContent = "";
  }
  if (checkOnly) {
    if (currentContent !== target.nextContent) {
      console.error(
        `[filmtone-${target.id}] ${target.outputPath} is out of date.`,
      );
      exitCode = 1;
    }
  } else if (currentContent !== target.nextContent) {
    mkdirSync(dirname(target.outputPath), { recursive: true });
    writeFileSync(target.outputPath, target.nextContent);
    console.log(`[filmtone-${target.id}] wrote ${target.outputPath}`);
  } else {
    console.log(`[filmtone-${target.id}] ${target.outputPath} is up to date`);
  }
}
process.exitCode = exitCode;
