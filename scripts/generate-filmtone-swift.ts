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

// FilmLabSwiftCore (SwiftPM package) emits `public enum FilmtonePhase0Generated`
// + `public static let ...` so all consumers — Desktop (M4-B Phase 2)
// and iOS App (M4-B Phase 3) — reach the symbols through `import FilmLabSwiftCore`.
// After Phase 3 the generator collapses to a single output (was 3 targets in
// Phase 1, 2 targets in Phase 2 with iOS still consuming the legacy internal
// emit, 1 target now).
const publicContent = renderFilmtoneIosSwiftPayload(undefined, {
  accessLevel: "public",
});

const targets: SwiftTarget[] = [
  {
    id: "package",
    outputPath: resolve(
      repoRoot,
      "packages/film-lab-swift-core/Sources/FilmLabSwiftCore/Generated/FilmtonePhase0Generated.swift",
    ),
    nextContent: publicContent,
  },
  {
    id: "ios-optical-filters",
    outputPath: resolve(
      repoRoot,
      "apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneOpticalFiltersGenerated.swift",
    ),
    nextContent: renderFilmtoneIosOpticalFiltersSwift(),
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
