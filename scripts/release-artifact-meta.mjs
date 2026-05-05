/**
 * @file Filmtone Desktop (Native v2) の配布物メタ情報。
 * @description `FilmtoneDesktop.xcodeproj/project.pbxproj` を 1 箇所だけ読み、
 *              `MARKETING_VERSION` と `PRODUCT_NAME` を正本として配布名を組み立てます。
 *              旧 Electron の `apps/desktop-film-lab-batch/scripts/release-artifact-meta.mjs`
 *              の Native v2 移植版。pathname / env var 名は cutover-architecture.md
 *              decisions A/G (Bundle ID 引継 + distribution channel) と整合させ Electron 1.0.4 user の自動 upgrade 経路を保ちます。
 * @limitations 版の正本は pbxproj。Marketing version を上げる時は Debug + Release
 *              両 buildSettings を必ず一致させてください (release-macos.sh が一方しか読まないため)。
 */
import fsPromises from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirPath = path.dirname(currentFilePath);

/** @description filmtone repo の絶対パス (このファイルの 1 つ上) */
export const repoRootPath = path.resolve(currentDirPath, "..");

/** @description Native macOS app の絶対パス */
export const desktopRootPath = path.join(repoRootPath, "apps", "filmtone-desktop-macos");

const pbxprojPath = path.join(
  desktopRootPath,
  "FilmtoneDesktop.xcodeproj",
  "project.pbxproj",
);

/**
 * @description 製品名をファイル名向けの slug に整えます (Electron 互換)。
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
 * @description release notes の版付きファイル名を返します (Electron 互換)。
 * @param {string} version - pbxproj の MARKETING_VERSION
 * @returns {string} 例: `RELEASE_NOTES-v1.4.md`
 */
export function buildReleaseNotesFileName(version) {
  return `RELEASE_NOTES-v${version}.md`;
}

/**
 * @description pbxproj から最初の MARKETING_VERSION を読みます。
 *              `release-macos.sh` の `read_marketing_version` と同一 regex。
 * @param {string} pbxprojText - project.pbxproj の中身
 * @returns {string | null}
 */
function extractMarketingVersion(pbxprojText) {
  const match = pbxprojText.match(/MARKETING_VERSION = ([^;]+);/);
  if (!match) return null;
  return match[1].trim();
}

/**
 * @description pbxproj から最初の PRODUCT_NAME を読みます。
 *              `$(TARGET_NAME)` のような変数展開はサポートしません (Native v2 は `Filmtone` 固定値)。
 * @param {string} pbxprojText - project.pbxproj の中身
 * @returns {string | null}
 */
function extractProductName(pbxprojText) {
  const match = pbxprojText.match(/PRODUCT_NAME = ([^;]+);/);
  if (!match) return null;
  const value = match[1].trim();
  if (value.startsWith("$(")) {
    return null;
  }
  return value.replace(/^"(.*)"$/, "$1");
}

/**
 * @description Native v2 Desktop 配布の基礎メタを返します。
 * @returns {Promise<{
 *   version: string;
 *   productName: string;
 *   artifactSlug: string;
 *   dmgFileName: string;
 *   dmgPath: string;
 *   releaseNotesFileName: string;
 *   releaseNotesPath: string;
 * }>}
 */
export async function readDesktopReleaseMeta() {
  const functionName = "readDesktopReleaseMeta";
  let pbxprojText;
  try {
    pbxprojText = await fsPromises.readFile(pbxprojPath, "utf8");
  } catch (error) {
    throw new Error(
      `[${functionName}] project.pbxproj を読めません。path=${pbxprojPath} error=${String(error)}`,
    );
  }

  const version = extractMarketingVersion(pbxprojText);
  if (!version) {
    throw new Error(`[${functionName}] MARKETING_VERSION を pbxproj から抽出できません。`);
  }

  const productName = extractProductName(pbxprojText);
  if (!productName) {
    throw new Error(
      `[${functionName}] PRODUCT_NAME を pbxproj から抽出できません。 ($(TARGET_NAME) は未対応; cutover では "Filmtone" 固定値が必要)`,
    );
  }

  const artifactSlug = slugifyProductName(productName);
  // package-dmg.sh:92 の `$APP_NAME-$VERSION.dmg` と一致させる ── DMG の実名を blob pathname にも使う。
  // 旧 Electron は `${slug}-${version}-arm64.dmg` (lowercase + arm64 suffix) だったが、
  // Native v2 は `Filmtone-${version}.dmg` (PRODUCT_NAME ベース)。同じ `filmtone/desktop/` prefix
  // 配下に共存するので衝突しない。
  const dmgFileName = `${productName}-${version}.dmg`;
  const dmgPath = path.join(desktopRootPath, "build", "release", version, dmgFileName);
  const releaseNotesFileName = buildReleaseNotesFileName(version);
  const releaseNotesPath = path.join(desktopRootPath, releaseNotesFileName);

  return {
    version,
    productName,
    artifactSlug,
    dmgFileName,
    dmgPath,
    releaseNotesFileName,
    releaseNotesPath,
  };
}

/**
 * @description portfolio repo (`.vercel/project.json` を保有) の root を解決します。
 *              優先順:
 *                1. `PORTFOLIO_ROOT` env var (絶対 path)
 *                2. filmtone repo の sibling: `<repoRootPath>/../chibatakumi-portfolio`
 *              Electron 版は同一 repo 内で walk-up していたが、Native v2 は別 repo
 *              なので明示解決に切り替えた。
 * @returns {Promise<string | null>}
 */
export async function resolvePortfolioRootPath() {
  const candidates = [];
  if (process.env.PORTFOLIO_ROOT?.trim()) {
    candidates.push(path.resolve(process.env.PORTFOLIO_ROOT.trim()));
  }
  candidates.push(path.resolve(repoRootPath, "..", "chibatakumi-portfolio"));

  for (const candidate of candidates) {
    try {
      await fsPromises.access(path.join(candidate, ".vercel", "project.json"));
      return candidate;
    } catch {
      // 次の候補
    }
  }
  return null;
}
