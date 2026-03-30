/**
 * @file Film Lab Desktop のチェックサム生成スクリプト。
 * @description release 配下の DMG を走査し、SHA-256 を計算して `SHA256SUMS.txt` に保存します。
 * @limitations 既に生成済みの配布物が必要です。ファイルが無いときはエラーで止めます。
 */

import crypto from "node:crypto";
import fs from "node:fs";
import fsPromises from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { readDesktopReleaseMeta } from "./release-artifact-meta.mjs";

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirPath = path.dirname(currentFilePath);
const defaultReleaseDirPath = path.resolve(currentDirPath, "..", "release");
const defaultOutputPath = path.join(defaultReleaseDirPath, "SHA256SUMS.txt");

/**
 * SHA-256 を計算します。
 *
 * @param {string} filePath - ハッシュを取りたいファイルの絶対パス。
 * @returns {Promise<string>} 16進表現の SHA-256。
 */
function computeSha256(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const stream = fs.createReadStream(filePath);

    stream.on("error", (error) => {
      reject(error);
    });
    stream.on("data", (chunk) => {
      hash.update(chunk);
    });
    stream.on("end", () => {
      resolve(hash.digest("hex"));
    });
  });
}

/**
 * チェックサム対象ファイルを解決します。
 *
 * @param {string[]} rawArgs - CLI 引数。
 * @returns {Promise<string[]>} 対象ファイルの絶対パス一覧。
 */
async function resolveArtifactPaths(rawArgs) {
  const functionName = "resolveArtifactPaths";
  if (rawArgs.length > 0) {
    return rawArgs.map((rawPath) => path.resolve(process.cwd(), rawPath));
  }

  const releaseMeta = await readDesktopReleaseMeta();
  const expectedCurrentDmgPath = path.join(
    defaultReleaseDirPath,
    releaseMeta.dmgFileName,
  );
  try {
    await fsPromises.access(expectedCurrentDmgPath);
    return [expectedCurrentDmgPath];
  } catch {
    /* current version artifact がまだ無いときだけ後方互換で全 .dmg を見る */
  }

  const entries = await fsPromises.readdir(defaultReleaseDirPath, { withFileTypes: true });
  const preferredDmgPaths = entries
    .filter(
      (entry) =>
        entry.isFile() &&
        entry.name.endsWith(".dmg") &&
        entry.name.startsWith(`${releaseMeta.artifactSlug}-`),
    )
    .map((entry) => path.join(defaultReleaseDirPath, entry.name))
    .sort();
  const dmgPaths = (preferredDmgPaths.length > 0 ? preferredDmgPaths : entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".dmg"))
    .map((entry) => path.join(defaultReleaseDirPath, entry.name))
    .sort());

  if (dmgPaths.length === 0) {
    throw new Error(
      `[${functionName}] release 配下に .dmg がありません。releaseDir=${defaultReleaseDirPath}`,
    );
  }

  return dmgPaths;
}

/**
 * 1 行ぶんの SHA256SUMS 形式を作ります。
 *
 * @param {string} filePath - 対象ファイルの絶対パス。
 * @param {string} sha256 - 計算済み SHA-256。
 * @returns {string} `sha256  filename` 形式の 1 行。
 */
function formatChecksumLine(filePath, sha256) {
  return `${sha256}  ${path.basename(filePath)}`;
}

/**
 * CLI エントリポイントです。
 *
 * @returns {Promise<void>} 完了したら resolve。
 */
async function main() {
  const functionName = "main";
  const artifactPaths = await resolveArtifactPaths(process.argv.slice(2));
  const lines = [];

  for (const artifactPath of artifactPaths) {
    try {
      await fsPromises.access(artifactPath);
    } catch (error) {
      throw new Error(
        `[${functionName}] artifact が見つかりません。artifactPath=${artifactPath} error=${String(
          error,
        )}`,
      );
    }

    const sha256 = await computeSha256(artifactPath);
    const line = formatChecksumLine(artifactPath, sha256);
    lines.push(line);
    console.log(line);
  }

  await fsPromises.writeFile(defaultOutputPath, `${lines.join("\n")}\n`, "utf8");
  console.log(`[${functionName}] Wrote: outputPath=${defaultOutputPath}`);
}

await main();
