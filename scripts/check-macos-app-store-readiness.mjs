/**
 * @file Mac App Store readiness checks for Filmtone Desktop.
 * @description Read-only guard for the sandbox/App Store distribution lane.
 */

import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const appRoot = path.join(repoRoot, "apps", "filmtone-desktop-macos");
const appStoreEntitlements = path.join(
  appRoot,
  "FilmtoneDesktop",
  "FilmtoneDesktopAppStore.entitlements",
);
const developerIdEntitlements = path.join(
  appRoot,
  "FilmtoneDesktop",
  "FilmtoneDesktop.entitlements",
);
const appStoreExportOptions = path.join(appRoot, "ExportOptionsAppStore.plist");
const developerIdExportOptions = path.join(appRoot, "ExportOptions.plist");
const releaseScript = path.join(repoRoot, "scripts", "release-macos-app-store.sh");

const checks = [];

function pass(label, detail = "") {
  checks.push({ level: "pass", label, detail });
}

function fail(label, detail = "") {
  checks.push({ level: "fail", label, detail });
}

function readPlist(filePath) {
  const raw = execFileSync("/usr/bin/plutil", ["-convert", "json", "-o", "-", filePath], {
    encoding: "utf8",
  });
  return JSON.parse(raw);
}

function assertFile(filePath) {
  if (fs.existsSync(filePath)) {
    pass("File exists", path.relative(repoRoot, filePath));
    return true;
  }
  fail("File missing", path.relative(repoRoot, filePath));
  return false;
}

console.log("Filmtone Mac App Store readiness check");
console.log(`repo: ${repoRoot}`);

if (assertFile(appStoreEntitlements)) {
  const entitlements = readPlist(appStoreEntitlements);
  if (entitlements["com.apple.security.app-sandbox"] === true) {
    pass("MAS App Sandbox entitlement", "enabled");
  } else {
    fail("MAS App Sandbox entitlement", "com.apple.security.app-sandbox must be true");
  }
  if (entitlements["com.apple.security.files.user-selected.read-write"] === true) {
    pass("MAS user-selected file access", "read-write");
  } else {
    fail(
      "MAS user-selected file access",
      "com.apple.security.files.user-selected.read-write must be true",
    );
  }
  const temporaryExceptions = Object.keys(entitlements).filter((key) =>
    key.startsWith("com.apple.security.temporary-exception"),
  );
  if (temporaryExceptions.length === 0) {
    pass("MAS temporary exceptions", "none");
  } else {
    fail("MAS temporary exceptions", temporaryExceptions.join(", "));
  }
}

if (assertFile(appStoreExportOptions)) {
  const options = readPlist(appStoreExportOptions);
  if (options.method === "app-store-connect") {
    pass("MAS export method", options.method);
  } else {
    fail("MAS export method", `expected app-store-connect, found ${options.method}`);
  }
  if (options.signingStyle === "automatic") {
    pass("MAS signing style", options.signingStyle);
  } else {
    fail("MAS signing style", `expected automatic, found ${options.signingStyle}`);
  }
  if (options.destination === "export") {
    pass("MAS export destination", options.destination);
  } else {
    fail("MAS export destination", `expected export, found ${options.destination}`);
  }
  if (options.teamID === "C3G77H8NM6") {
    pass("MAS teamID", options.teamID);
  } else {
    fail("MAS teamID", `expected C3G77H8NM6, found ${options.teamID}`);
  }
}

if (assertFile(developerIdEntitlements)) {
  const entitlements = readPlist(developerIdEntitlements);
  if (!("com.apple.security.app-sandbox" in entitlements)) {
    pass("Developer ID entitlements remain non-sandboxed", "unchanged");
  } else {
    fail("Developer ID entitlements", "must not be silently converted to App Sandbox");
  }
}

if (assertFile(developerIdExportOptions)) {
  const options = readPlist(developerIdExportOptions);
  if (options.method === "developer-id") {
    pass("Developer ID export method remains", options.method);
  } else {
    fail("Developer ID export method", `expected developer-id, found ${options.method}`);
  }
}

if (assertFile(releaseScript)) {
  const text = fs.readFileSync(releaseScript, "utf8");
  if (
    text.includes("ExportOptionsAppStore.plist") &&
    text.includes("FilmtoneDesktopAppStore.entitlements") &&
    text.includes("app-store-connect") &&
    text.includes("Apple Development") &&
    text.includes('CODE_SIGN_IDENTITY="$ARCHIVE_SIGN_IDENTITY"') &&
    text.includes("verify_archived_app")
  ) {
    pass("MAS release script wiring", "export options + sandbox entitlements");
  } else {
    fail("MAS release script wiring", "missing App Store export, signing, or entitlements wiring");
  }
  if (!text.includes("notarytool") && !text.includes("package-dmg")) {
    pass("MAS release script avoids DMG/notary path", "App Store lane only");
  } else {
    fail("MAS release script scope", "must not package DMG or notarize");
  }
}

const helpResult = spawnSync("xcodebuild", ["-help"], { encoding: "utf8" });
const help = `${helpResult.stdout ?? ""}\n${helpResult.stderr ?? ""}`;
if (help.includes("app-store-connect")) {
  pass("Xcode export support", "app-store-connect");
} else {
  fail("Xcode export support", "app-store-connect not advertised by xcodebuild");
}

for (const check of checks) {
  const prefix = check.level === "pass" ? "PASS" : "FAIL";
  console.log(`${prefix} ${check.label}${check.detail ? `: ${check.detail}` : ""}`);
}

const failures = checks.filter((check) => check.level === "fail");
if (failures.length > 0) {
  console.error(`\n${failures.length} Mac App Store readiness check(s) failed.`);
  process.exit(1);
}

console.log("\nMac App Store readiness checks passed.");
