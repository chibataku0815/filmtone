/**
 * @file Filmtone Desktop の配布物メタ情報
 * @description `package.json` を 1 箇所だけ読んで、配布名・版数・release notes 名を揃えます。
 * @limitations 版数の正本は `package.json` の `version` です。新しい Desktop を出すときは、先にここを更新してください。
 */
import fsPromises from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirPath = path.dirname(currentFilePath);

/** @description `apps/desktop-film-lab-batch` の絶対パス */
export const desktopRootPath = path.resolve(currentDirPath, "..");

const packageJsonPath = path.join(desktopRootPath, "package.json");

/**
 * @description 製品名をファイル名向けの slug に整えます。
 * @param {string} productName - 例: `Filmtone`
 * @returns {string} 例: `filmtone`
 */
export function slugifyProductName(productName) {
  return (
    productName
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "") || "filmtone"
  );
}

/**
 * @description release notes の版付きファイル名を返します。
 * @param {string} version - `package.json` の version
 * @returns {string} 例: `RELEASE_NOTES-v0.1.0.md`
 */
export function buildReleaseNotesFileName(version) {
  return `RELEASE_NOTES-v${version}.md`;
}

/**
 * @description `package.json` から Desktop 配布の基礎メタを読みます。
 * @returns {Promise<{
 *   version: string;
 *   productName: string;
 *   artifactSlug: string;
 *   dmgFileName: string;
 *   releaseNotesFileName: string;
 *   releaseNotesPath: string;
 * }>}
 */
export async function readDesktopReleaseMeta() {
  const functionName = "readDesktopReleaseMeta";
  let packageJsonText;
  try {
    packageJsonText = await fsPromises.readFile(packageJsonPath, "utf8");
  } catch (error) {
    throw new Error(
      `[${functionName}] package.json を読めません。path=${packageJsonPath} error=${String(error)}`,
    );
  }

  let packageJson;
  try {
    packageJson = JSON.parse(packageJsonText);
  } catch (error) {
    throw new Error(`[${functionName}] package.json JSON が不正です。error=${String(error)}`);
  }

  const version = packageJson?.version;
  if (typeof version !== "string" || version.trim().length === 0) {
    throw new Error(`[${functionName}] package.json の version が空です。`);
  }

  const productName = packageJson?.build?.productName;
  if (typeof productName !== "string" || productName.trim().length === 0) {
    throw new Error(`[${functionName}] build.productName が空です。`);
  }

  const artifactSlug = slugifyProductName(productName);
  const dmgFileName = `${artifactSlug}-${version}-arm64.dmg`;
  const releaseNotesFileName = buildReleaseNotesFileName(version);
  const releaseNotesPath = path.join(desktopRootPath, releaseNotesFileName);

  return {
    version,
    productName,
    artifactSlug,
    dmgFileName,
    releaseNotesFileName,
    releaseNotesPath,
  };
}
