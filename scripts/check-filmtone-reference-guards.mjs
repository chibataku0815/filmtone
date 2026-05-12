#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

function git(args) {
  return execFileSync("git", args, { encoding: "utf8" });
}

const repoRoot = git(["rev-parse", "--show-toplevel"]).trim();
process.chdir(repoRoot);

function splitLines(output) {
  return output
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function changedPaths() {
  const diffPaths = splitLines(
    git(["diff", "--name-only", "--diff-filter=ACMRTUXB", "HEAD", "--"]),
  );
  const untrackedPaths = splitLines(
    git(["ls-files", "--others", "--exclude-standard"]),
  );
  return [...new Set([...diffPaths, ...untrackedPaths])]
    .map((file) => file.replaceAll(path.sep, "/"))
    .filter((file) => !isIgnored(file));
}

function isIgnored(file) {
  return (
    file.includes("/node_modules/") ||
    file.includes("/.git/") ||
    file.includes("/dist/") ||
    file.includes("/build/") ||
    file.includes("/DerivedData/") ||
    file.endsWith(".xcuserstate") ||
    file.endsWith(".DS_Store") ||
    !isTextPath(file)
  );
}

function isTextPath(file) {
  return /\.(cjs|css|glsl|h|html|js|json|jsx|md|mjs|mm|sh|swift|toml|ts|tsx|txt|wgsl|xcstrings|xml|yaml|yml)$/.test(
    file,
  );
}

const legacyPresetPattern = /(^|[^A-Za-z0-9_])(iphone|softBlue|amberGlow)([^A-Za-z0-9_]|$)/;

const allowedLegacyPresetPaths = [
  /^AGENTS\.md$/,
  /^CLAUDE\.md$/,
  /^scripts\/check-filmtone-reference-guards\.mjs$/,
  /^apps\/filmtone-desktop-macos\/README\.md$/,
  /^packages\/film-lab-core\/src\/ios-preset-overrides\.ts$/,
  /^packages\/film-lab-core\/src\/ios-phase0(\.test)?\.ts$/,
  /^packages\/film-lab-core\/src\/ios-swift-payload(\.test)?\.ts$/,
  /^packages\/film-lab-core\/src\/creative-pack-01(\.test)?\.ts$/,
  /^packages\/film-lab-swift-core\/Sources\/FilmLabSwiftCore\/Generated\//,
  /^packages\/film-lab-swift-core\/Tests\/FilmLabSwiftCoreTests\/Generated/,
  /^apps\/capacitor-film-lab-ios\/ios\/App\/App\/Source\/FilmtonePhase0Math\.swift$/,
  /^apps\/capacitor-film-lab-ios\/ios\/App\/App\/Smoke\/FilmtoneSnapshotSupport\.swift$/,
  /^apps\/capacitor-film-lab-ios\/ios\/App\/App\/Localizable\.xcstrings$/,
  /^apps\/capacitor-film-lab-ios\/scripts\/fixtures\/phase0-contract\//,
  /^apps\/filmtone-desktop-macos\/FilmtoneDesktop\/Color\/FilmtonePresetCatalog\.swift$/,
  /^docs\/filmtone\/.*\/archive\//,
  /^docs\/filmtone\/archive\//,
  /^docs\/filmtone\/shared-highlight-markers\/evidence\//,
];

function isAllowedLegacyPresetPath(file) {
  return allowedLegacyPresetPaths.some((pattern) => pattern.test(file));
}

function firstMatchingLine(file, text) {
  const lines = text.split("\n");
  const index = lines.findIndex((line) => legacyPresetPattern.test(line));
  return {
    lineNumber: index + 1,
    line: lines[index]?.trim() ?? "",
  };
}

const findings = [];

for (const file of changedPaths()) {
  if (isAllowedLegacyPresetPath(file)) continue;

  const absolutePath = path.join(repoRoot, file);
  if (!fs.existsSync(absolutePath)) continue;
  const stat = fs.statSync(absolutePath);
  if (!stat.isFile()) continue;

  const text = fs.readFileSync(absolutePath, "utf8");
  if (!legacyPresetPattern.test(text)) continue;

  findings.push({ file, ...firstMatchingLine(file, text) });
}

if (findings.length === 0) {
  console.log("Filmtone reference guards: legacy preset ID references are contained.");
  process.exit(0);
}

const lines = findings
  .slice(0, 12)
  .map((finding) => `  - ${finding.file}:${finding.lineNumber} ${finding.line}`);

console.error(`Filmtone reference guards failed.

Legacy iOS Phase 0 preset IDs were added outside the compatibility allowlist:
${lines.join("\n")}${findings.length > 12 ? `\n  ... and ${findings.length - 12} more` : ""}

Do not use lowercase preset IDs such as iphone, softBlue, or amberGlow as
current product truth. They are compatibility IDs for the old small iOS preset
rail and generated/parity fixtures.

Use these sources instead:

- Current shared Presets: packages/film-lab-core/src/presets.ts
- Current shared Look IDs: packages/film-lab-core/src/look-ids.ts
- Native Desktop / iOS product state: the active lane strategy.md / active.md

If this is truly compatibility work, add the exact file to the allowlist in
scripts/check-filmtone-reference-guards.mjs with a narrow path pattern.`);

process.exit(1);
