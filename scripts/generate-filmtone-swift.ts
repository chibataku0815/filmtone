import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import {
  renderFilmtoneIosSwiftPayload,
} from "../packages/film-lab-core/src/ios-swift-payload";

interface SwiftTarget {
  id: string;
  outputPath: string;
}

const repoRoot = resolve(import.meta.dir, "..");

const targets: SwiftTarget[] = [
  {
    id: "ios",
    outputPath: resolve(
      repoRoot,
      "apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift",
    ),
  },
  {
    id: "macos",
    outputPath: resolve(
      repoRoot,
      "apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift",
    ),
  },
];

const nextContent = renderFilmtoneIosSwiftPayload();
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
    if (currentContent !== nextContent) {
      console.error(
        `[filmtone-${target.id}] ${target.outputPath} is out of date.`,
      );
      exitCode = 1;
    }
  } else if (currentContent !== nextContent) {
    mkdirSync(dirname(target.outputPath), { recursive: true });
    writeFileSync(target.outputPath, nextContent);
    console.log(`[filmtone-${target.id}] wrote ${target.outputPath}`);
  } else {
    console.log(`[filmtone-${target.id}] ${target.outputPath} is up to date`);
  }
}
process.exitCode = exitCode;
