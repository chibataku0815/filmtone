/**
 * @file Native Desktop v2 release preflight.
 * @description Read-only checks for the current Filmtone Desktop release
 *              candidate. This script does not notarize, upload, mutate Vercel
 *              env, or write update-meta.json. It exists so production
 *              releases can be rehearsed without touching public state.
 */

import fsPromises from "node:fs/promises";
import path from "node:path";
import {
  desktopRootPath,
  readDesktopReleaseMeta,
  repoRootPath,
  resolvePortfolioRootPath,
} from "./release-artifact-meta.mjs";

const EXPECTED_PRODUCT_NAME = "Filmtone";
const EXPECTED_BUNDLE_ID = "com.chibatakumi.film-lab-desktop";
const EXPECTED_PUBLIC_LEGACY_VERSION = "1.0.4";
const PUBLIC_UPDATE_META_URL =
  process.env.FILMTONE_DESKTOP_PUBLIC_UPDATE_META_URL?.trim() ||
  "https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json";

const checks = [];

function cleanBuildSettingValue(value) {
  return value.trim().replace(/^"(.*)"$/, "$1");
}

function collectBuildSettings(projectText, key) {
  const values = [];
  const regex = new RegExp(`${key} = ([^;]+);`, "g");
  let match;
  while ((match = regex.exec(projectText)) !== null) {
    values.push(cleanBuildSettingValue(match[1]));
  }
  return values;
}

function unique(values) {
  return [...new Set(values)];
}

function compareDottedVersions(a, b) {
  const aParts = String(a)
    .split(".")
    .map((part) => Number.parseInt(part, 10));
  const bParts = String(b)
    .split(".")
    .map((part) => Number.parseInt(part, 10));
  if (
    aParts.some((part) => Number.isNaN(part)) ||
    bParts.some((part) => Number.isNaN(part))
  ) {
    return null;
  }
  const length = Math.max(aParts.length, bParts.length);
  for (let i = 0; i < length; i += 1) {
    const av = aParts[i] ?? 0;
    const bv = bParts[i] ?? 0;
    if (av < bv) return -1;
    if (av > bv) return 1;
  }
  return 0;
}

function pass(label, detail = "") {
  checks.push({ level: "pass", label, detail });
}

function warn(label, detail = "") {
  checks.push({ level: "warn", label, detail });
}

function fail(label, detail = "") {
  checks.push({ level: "fail", label, detail });
}

async function fileExists(filePath) {
  try {
    await fsPromises.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function readText(filePath) {
  return fsPromises.readFile(filePath, "utf8");
}

async function fetchPublicUpdateMeta(expectedVersion) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5_000);
  try {
    const response = await fetch(PUBLIC_UPDATE_META_URL, {
      cache: "no-store",
      signal: controller.signal,
    });
    if (!response.ok) {
      warn(
        "Public update-meta fetch",
        `${PUBLIC_UPDATE_META_URL} returned HTTP ${response.status}`,
      );
      return;
    }
    const body = await response.json();
    const latestVersion = String(body.latestVersion ?? "");
    if (latestVersion === EXPECTED_PUBLIC_LEGACY_VERSION) {
      pass(
        "Public update-meta is still on legacy Desktop",
        `latestVersion=${latestVersion}`,
      );
      return;
    }
    if (latestVersion === expectedVersion) {
      warn(
        "Public update-meta already points at this release candidate",
        `latestVersion=${latestVersion}; do not re-cut unless this is intentional`,
      );
      return;
    }
    const ordering = compareDottedVersions(latestVersion, expectedVersion);
    if (ordering === -1) {
      pass(
        "Public update-meta is still before this release candidate",
        `latestVersion=${latestVersion || "(missing)"} target=${expectedVersion}`,
      );
      return;
    }
    if (ordering === 1) {
      warn(
        "Public update-meta is newer than this release candidate",
        `latestVersion=${latestVersion} target=${expectedVersion}`,
      );
      return;
    }
    warn(
      "Public update-meta latestVersion is not comparable",
      `latestVersion=${latestVersion || "(missing)"} target=${expectedVersion}`,
    );
  } catch (error) {
    warn("Public update-meta fetch", String(error));
  } finally {
    clearTimeout(timeout);
  }
}

async function main() {
  console.log("Filmtone Native Desktop v2 release preflight");
  console.log(`repo: ${repoRootPath}`);

  const releaseMeta = await readDesktopReleaseMeta();
  const expectedVersion = releaseMeta.version;
  const projectPath = path.join(
    desktopRootPath,
    "FilmtoneDesktop.xcodeproj",
    "project.pbxproj",
  );
  const projectText = await readText(projectPath);

  const marketingVersions = unique(
    collectBuildSettings(projectText, "MARKETING_VERSION"),
  );
  if (marketingVersions.length === 1 && marketingVersions[0] === expectedVersion) {
    pass("MARKETING_VERSION", marketingVersions[0]);
  } else {
    fail(
      "MARKETING_VERSION",
      `expected only ${expectedVersion}; found ${marketingVersions.join(", ")}`,
    );
  }

  const productNames = unique(collectBuildSettings(projectText, "PRODUCT_NAME"));
  if (productNames.length === 1 && productNames[0] === EXPECTED_PRODUCT_NAME) {
    pass("PRODUCT_NAME", productNames[0]);
  } else {
    fail(
      "PRODUCT_NAME",
      `expected only ${EXPECTED_PRODUCT_NAME}; found ${productNames.join(", ")}`,
    );
  }

  const bundleIds = unique(
    collectBuildSettings(projectText, "PRODUCT_BUNDLE_IDENTIFIER"),
  );
  if (bundleIds.length === 1 && bundleIds[0] === EXPECTED_BUNDLE_ID) {
    pass("PRODUCT_BUNDLE_IDENTIFIER", bundleIds[0]);
  } else {
    fail(
      "PRODUCT_BUNDLE_IDENTIFIER",
      `expected only ${EXPECTED_BUNDLE_ID}; found ${bundleIds.join(", ")}`,
    );
  }

  const buildVersions = unique(
    collectBuildSettings(projectText, "CURRENT_PROJECT_VERSION"),
  );
  if (buildVersions.length === 1 && buildVersions[0]) {
    pass("CURRENT_PROJECT_VERSION", buildVersions[0]);
  } else {
    fail(
      "CURRENT_PROJECT_VERSION",
      `expected one consistent build number; found ${buildVersions.join(", ")}`,
    );
  }

  if (
    releaseMeta.version === expectedVersion &&
    releaseMeta.productName === EXPECTED_PRODUCT_NAME &&
    releaseMeta.dmgFileName === `${EXPECTED_PRODUCT_NAME}-${expectedVersion}.dmg`
  ) {
    pass(
      "Release artifact metadata",
      `${releaseMeta.productName} ${releaseMeta.version} -> ${releaseMeta.dmgFileName}`,
    );
  } else {
    fail(
      "Release artifact metadata",
      JSON.stringify(
        {
          version: releaseMeta.version,
          productName: releaseMeta.productName,
          dmgFileName: releaseMeta.dmgFileName,
        },
        null,
        2,
      ),
    );
  }

  if (await fileExists(releaseMeta.releaseNotesPath)) {
    pass("Release notes draft", releaseMeta.releaseNotesPath);
  } else {
    fail("Release notes draft missing", releaseMeta.releaseNotesPath);
  }

  if (await fileExists(releaseMeta.dmgPath)) {
    pass("Release DMG exists", releaseMeta.dmgPath);
  } else {
    warn(
      "Release DMG not built yet",
      `${releaseMeta.dmgPath} (expected before production upload)`,
    );
  }

  const releaseScriptText = await readText(path.join(repoRootPath, "scripts", "release-macos.sh"));
  if (
    releaseScriptText.includes('readonly APP_NAME="Filmtone"') &&
    releaseScriptText.includes('readonly BUNDLE_ID="com.chibatakumi.film-lab-desktop"')
  ) {
    pass("release-macos.sh identity", "Filmtone / com.chibatakumi.film-lab-desktop");
  } else {
    fail("release-macos.sh identity", "APP_NAME or BUNDLE_ID does not match cutover target");
  }

  const packageScriptText = await readText(path.join(repoRootPath, "scripts", "package-dmg.sh"));
  if (packageScriptText.includes('readonly APP_NAME="Filmtone"')) {
    pass("package-dmg.sh app name", "Filmtone");
  } else {
    fail("package-dmg.sh app name", "APP_NAME does not match cutover target");
  }

  const uploadDmgText = await readText(
    path.join(repoRootPath, "scripts", "upload-dmg-to-vercel-blob.mjs"),
  );
  const uploadMetaText = await readText(
    path.join(repoRootPath, "scripts", "upload-update-meta-to-vercel-blob.mjs"),
  );
  if (
    uploadDmgText.includes("--confirm-prod") &&
    uploadDmgText.includes("DRY-RUN") &&
    uploadMetaText.includes("--confirm-prod") &&
    uploadMetaText.includes("DRY-RUN")
  ) {
    pass("Production upload guard", "upload scripts default to dry-run");
  } else {
    fail("Production upload guard", "upload scripts must require --confirm-prod");
  }

  const portfolioRoot = await resolvePortfolioRootPath();
  if (portfolioRoot) {
    pass("Portfolio root", portfolioRoot);
  } else {
    warn("Portfolio root", "not found; set PORTFOLIO_ROOT before public upload");
  }

  await fetchPublicUpdateMeta(expectedVersion);

  for (const check of checks) {
    const prefix =
      check.level === "pass" ? "PASS" : check.level === "warn" ? "WARN" : "FAIL";
    console.log(`${prefix} ${check.label}${check.detail ? `: ${check.detail}` : ""}`);
  }

  console.log("\nProduction sequence after product gates are explicitly closed:");
  console.log("1. scripts/release-macos.sh");
  console.log("2. scripts/package-dmg.sh");
  console.log("3. bun run release:upload-dmg -- --confirm-prod --sync-vercel-env");
  console.log("4. Verify the fixed download page resolves to the new DMG.");
  console.log("5. bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env");
  console.log("6. Re-run release truth checks and portfolio deployment checks.");

  const failures = checks.filter((check) => check.level === "fail");
  if (failures.length > 0) {
    console.error(`\n${failures.length} cutover preflight check(s) failed.`);
    return 1;
  }
  console.log("\nCutover preflight passed with no blocking failures.");
  return 0;
}

try {
  const code = await main();
  process.exit(code);
} catch (error) {
  console.error("FAIL Unhandled preflight error:", error);
  process.exit(1);
}
