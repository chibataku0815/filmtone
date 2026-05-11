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
    file.includes("/DerivedData/") ||
    file.includes("/build/") ||
    file.includes("/build-device/") ||
    file.includes("/.build/") ||
    file.endsWith(".xcuserstate") ||
    file.endsWith(".DS_Store")
  );
}

const highRiskRules = [
  {
    id: "ios-native-runtime",
    pattern:
      /^apps\/capacitor-film-lab-ios\/(ios\/App\/App\/.*\.(swift|m|h)|ios\/App\/.*\.xcodeproj\/|src\/|fastlane\/(Fastfile|README\.md|metadata\/)|RELEASE\.md|CLAUDE\.md|package\.json)/,
  },
  {
    id: "macos-native-runtime",
    pattern:
      /^apps\/filmtone-desktop-macos\/(FilmtoneDesktop\/|Verify\/|fastlane\/metadata\/|scripts\/|.*\.xcodeproj\/|Gemfile|Package\.swift)/,
  },
  {
    id: "desktop-web-runtime",
    pattern:
      /^apps\/desktop-film-lab-batch\/(src\/|public\/|fastlane\/metadata\/|package\.json|.*\.config\.)/,
  },
  {
    id: "shared-color-render-contract",
    pattern:
      /^packages\/film-lab-(core|renderer|smart-look)\/(src\/|docs\/|package\.json|.*\.(ts|tsx|json|wgsl|glsl|metal))/,
  },
  {
    id: "public-web-copy",
    pattern: /^messages\/(ja|en)\.json$/,
  },
  {
    id: "filmtone-claim-script",
    pattern:
      /^scripts\/(generate-filmtone-swift\.ts|check-filmtone-copy-quality\.mjs|check-ios-grain-catalog\.mjs|release-.*|verify-(desktop|ios)\.sh)/,
  },
];

const directContextRules = [
  /^docs\/filmtone\/filmtone-copy-context-sync\.md$/,
  /^docs\/filmtone\/filmtone-copy-quality-harness\.md$/,
  /^docs\/filmtone\/filmtone-implementation-history\.md$/,
  /^docs\/filmtone\/filmtone-release-version-sources\.md$/,
  /^messages\/(ja|en)\.json$/,
  /^apps\/[^/]+\/RELEASE\.md$/,
  /^apps\/[^/]+\/fastlane\/metadata\//,
];

const laneDocPattern =
  /^docs\/filmtone\/.*(active|strategy|archive|handoff|release|copy|context).*\.md$/;

const impactMarkerPatterns = [
  /Copy\s*\/\s*History\s*Impact/i,
  /No\s+copy\s*\/\s*history\s+impact/i,
  /Implementation\s+history\s+update\s+required/i,
  /Public\s+copy\s+update\s+required/i,
  /Article\s+Opportunity/i,
  /Change-History\s+Opportunity/i,
  /Release\s*\/\s*App Store\s+claim/i,
  /copy\/history\s+impact/i,
  /変更経緯/,
  /コピー\s*\/\s*経緯影響/,
];

function highRiskMatch(file) {
  return highRiskRules.find((rule) => rule.pattern.test(file));
}

function isDirectContext(file) {
  return directContextRules.some((pattern) => pattern.test(file));
}

function hasImpactMarker(file) {
  if (!laneDocPattern.test(file)) return false;
  const absolutePath = path.join(repoRoot, file);
  if (!fs.existsSync(absolutePath)) return false;
  const text = fs.readFileSync(absolutePath, "utf8");
  return impactMarkerPatterns.some((pattern) => pattern.test(text));
}

function formatList(files, limit = 12) {
  const shown = files.slice(0, limit);
  const suffix = files.length > limit ? `\n  ... and ${files.length - limit} more` : "";
  return shown.map((file) => `  - ${file}`).join("\n") + suffix;
}

const files = changedPaths();
const highRiskFiles = files
  .map((file) => ({ file, rule: highRiskMatch(file) }))
  .filter((entry) => entry.rule);

if (highRiskFiles.length === 0) {
  console.log("Filmtone context sync: no high-risk product/copy changes detected.");
  process.exit(0);
}

const directContextFiles = files.filter(isDirectContext);
const impactMarkerFiles = files.filter(hasImpactMarker);

if (directContextFiles.length > 0 || impactMarkerFiles.length > 0) {
  console.log("Filmtone context sync: high-risk changes have copy/history context.");
  if (directContextFiles.length > 0) {
    console.log("\nContext/copy sources changed:");
    console.log(formatList(directContextFiles));
  }
  if (impactMarkerFiles.length > 0) {
    console.log("\nImpact markers found:");
    console.log(formatList(impactMarkerFiles));
  }
  process.exit(0);
}

const riskLines = highRiskFiles.map(
  ({ file, rule }) => `  - ${file} (${rule.id})`,
);

console.error(`Filmtone context sync failed.

High-risk product/copy changes were detected, but no copy/history context update
or explicit impact decision was found.

High-risk changes:
${riskLines.slice(0, 16).join("\n")}${riskLines.length > 16 ? `\n  ... and ${riskLines.length - 16} more` : ""}

Add one of the following before handoff:

- Update the relevant public copy, release notes, metadata, copy harness, or
  implementation-history source.
- Add a changed lane doc section named "Copy / History Impact" that states the
  required copy/history update.
- If there is no effect, add "No copy/history impact: <reason>" to the changed
  active/archive/strategy/handoff doc.

This check only proves that the decision is recorded. Run
"bun run check:filmtone-copy" for public-copy wording quality.`);

process.exit(1);
