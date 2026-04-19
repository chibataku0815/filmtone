import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { renderFilmtoneIosSwiftPayload } from "./ios-swift-payload";

test("generated Swift payload stays in sync with shared film-lab-core truth", () => {
  const repoRoot = resolve(import.meta.dir, "../../..");
  const generatedPath = resolve(
    repoRoot,
    "apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift",
  );

  const actual = readFileSync(generatedPath, "utf8");
  const expected = renderFilmtoneIosSwiftPayload();

  expect(actual).toBe(expected);
});
