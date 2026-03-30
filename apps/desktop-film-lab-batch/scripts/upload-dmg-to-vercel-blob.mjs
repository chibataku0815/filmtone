/**
 * @file Film Lab Desktop の DMG を Vercel Blob に載せるスクリプト。
 * @description 配布 pathname は固定規約のみ（判断不要）。`bunx vercel@50 blob put` を呼び出します。
 * @limitations `BLOB_READ_WRITE_TOKEN` が必要です。リポジトリルートの `.env.local` に `vercel env pull` した値があれば読み込みます。
 */

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import fsPromises from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirPath = path.dirname(currentFilePath);
const desktopRootPath = path.resolve(currentDirPath, "..");
const packageJsonPath = path.join(desktopRootPath, "package.json");

/**
 * 親ディレクトリを遡り、`.vercel/project.json` がある chibatakumi-portfolio ルートを返します。
 *
 * @param {string} startDirPath - 探索開始ディレクトリ。
 * @returns {string | null} ルートの絶対パス。見つからなければ null。
 */
function resolvePortfolioRootPath(startDirPath) {
  let dirPath = path.resolve(startDirPath);
  for (let depth = 0; depth < 24; depth += 1) {
    const candidatePath = path.join(dirPath, ".vercel", "project.json");
    if (fs.existsSync(candidatePath)) {
      return dirPath;
    }
    const parentPath = path.dirname(dirPath);
    if (parentPath === dirPath) {
      break;
    }
    dirPath = parentPath;
  }
  return null;
}

/**
 * `.env.local` から `BLOB_READ_WRITE_TOKEN` だけを読み、未設定なら `process.env` に足します。
 *
 * @param {string} envFilePath - `.env.local` の絶対パス。
 * @returns {Promise<void>}
 */
async function mergeBlobTokenFromEnvFile(envFilePath) {
  if (process.env.BLOB_READ_WRITE_TOKEN?.trim()) {
    return;
  }
  let text;
  try {
    text = await fsPromises.readFile(envFilePath, "utf8");
  } catch {
    return;
  }
  for (const rawLine of text.split("\n")) {
    const line = rawLine.trim();
    if (line.length === 0 || line.startsWith("#")) {
      continue;
    }
    if (!line.startsWith("BLOB_READ_WRITE_TOKEN=")) {
      continue;
    }
    let value = line.slice("BLOB_READ_WRITE_TOKEN=".length).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (value.length > 0) {
      process.env.BLOB_READ_WRITE_TOKEN = value;
    }
    break;
  }
}

/**
 * vercel の標準出力から公開 URL らしき文字列を 1 つ抜き出します。
 *
 * @param {string} combinedOutput - stdout + stderr。
 * @returns {string | null} https URL。無ければ null。
 */
function extractPublicUrlFromOutput(combinedOutput) {
  const matches = combinedOutput.match(/https:\/\/[^\s"'<>]+/g);
  if (!matches || matches.length === 0) {
    return null;
  }
  for (const candidateUrl of matches) {
    if (candidateUrl.includes("blob.vercel-storage.com") || candidateUrl.includes("vercel-storage.com")) {
      return candidateUrl.replace(/[,;.)]+$/, "");
    }
  }
  return matches[0].replace(/[,;.)]+$/, "");
}

/**
 * Vercel の Production に `FILM_LAB_DESKTOP_DOWNLOAD_URL` を書き込みます。
 *
 * @param {string} portfolioRootPath - リポジトリルート。
 * @param {string} publicUrl - DMG の HTTPS URL。
 * @returns {number} 終了コード（0 なら成功）。
 */
function syncDownloadUrlToVercelEnv(portfolioRootPath, publicUrl) {
  const functionName = "syncDownloadUrlToVercelEnv";
  const result = spawnSync(
    "bunx",
    [
      "vercel@50",
      "env",
      "add",
      "FILM_LAB_DESKTOP_DOWNLOAD_URL",
      "production",
      "--value",
      publicUrl,
      "--yes",
      "--force",
    ],
    {
      cwd: portfolioRootPath,
      encoding: "utf8",
      env: process.env,
    },
  );
  if (result.error) {
    console.error(`[${functionName}] spawn failed`, result.error);
    return 1;
  }
  if (result.stdout) {
    process.stdout.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }
  return result.status ?? 1;
}

/**
 * メイン処理です。
 *
 * @returns {Promise<number>} 終了コード。
 */
async function main() {
  const functionName = "main";
  const rawArgs = process.argv.slice(2);
  const wantsSyncEnv = rawArgs.includes("--sync-vercel-env");
  const filteredArgs = rawArgs.filter((arg) => arg !== "--sync-vercel-env");

  const portfolioRootPath = resolvePortfolioRootPath(desktopRootPath);
  if (!portfolioRootPath) {
    console.error(
      `[${functionName}] .vercel/project.json が見つかりません。chibatakumi-portfolio のルートで vercel link 済みか確認してください。`,
    );
    return 1;
  }

  await mergeBlobTokenFromEnvFile(path.join(portfolioRootPath, ".env.local"));

  if (!process.env.BLOB_READ_WRITE_TOKEN?.trim()) {
    console.error(
      `[${functionName}] BLOB_READ_WRITE_TOKEN がありません。\n` +
        `1) Vercel で Blob をプロジェクトに接続\n` +
        `2) リポジトリルートで: bunx vercel@50 env pull .env.local\n` +
        `3) もう一度このスクリプトを実行`,
    );
    return 1;
  }

  let packageJsonText;
  try {
    packageJsonText = await fsPromises.readFile(packageJsonPath, "utf8");
  } catch (error) {
    console.error(`[${functionName}] package.json を読めません`, packageJsonPath, error);
    return 1;
  }
  let version;
  try {
    version = JSON.parse(packageJsonText).version;
  } catch (error) {
    console.error(`[${functionName}] package.json の version が不正です`, error);
    return 1;
  }
  if (typeof version !== "string" || version.length === 0) {
    console.error(`[${functionName}] package.json に version がありません`);
    return 1;
  }

  const dmgFileName = `film-lab-${version}-arm64.dmg`;
  const dmgPath =
    filteredArgs.length > 0
      ? path.resolve(process.cwd(), filteredArgs[0])
      : path.join(desktopRootPath, "release", dmgFileName);

  if (!fs.existsSync(dmgPath)) {
    console.error(
      `[${functionName}] DMG が見つかりません: ${dmgPath}\n` +
        `先に dist:mac:release 等で生成するか、引数に DMG のパスを渡してください。`,
    );
    return 1;
  }

  const pathname = `film-lab/desktop/${dmgFileName}`;

  console.log(
    `[${functionName}] portfolio root: ${portfolioRootPath}\n` +
      `[${functionName}] upload: ${dmgPath}\n` +
      `[${functionName}] pathname (固定): ${pathname}`,
  );

  const putResult = spawnSync(
    "bunx",
    [
      "vercel@50",
      "blob",
      "put",
      dmgPath,
      "--pathname",
      pathname,
      "--access",
      "public",
      "--allow-overwrite",
      "true",
    ],
    {
      cwd: portfolioRootPath,
      encoding: "utf8",
      env: process.env,
    },
  );

  const combinedOutput = `${putResult.stdout ?? ""}${putResult.stderr ?? ""}`;
  if (putResult.stdout) {
    process.stdout.write(putResult.stdout);
  }
  if (putResult.stderr) {
    process.stderr.write(putResult.stderr);
  }

  if (putResult.error) {
    console.error(`[${functionName}] vercel blob put の起動に失敗しました`, putResult.error);
    return 1;
  }
  if (putResult.status !== 0) {
    console.error(`[${functionName}] vercel blob put が失敗しました (exit ${putResult.status})`);
    return putResult.status ?? 1;
  }

  const publicUrl = extractPublicUrlFromOutput(combinedOutput);
  if (!publicUrl) {
    console.warn(
      `[${functionName}] 公開 URL を自動抽出できませんでした。上の CLI 出力から URL をコピーし、\n` +
        `Vercel の FILM_LAB_DESKTOP_DOWNLOAD_URL (production) に貼るか、次を実行してください:\n` +
        `  bunx vercel@50 env add FILM_LAB_DESKTOP_DOWNLOAD_URL production --value "<URL>" --yes --force`,
    );
    return 0;
  }

  console.log(`\n[${functionName}] PUBLIC_URL=${publicUrl}`);

  if (!wantsSyncEnv) {
    console.log(
      `\n[${functionName}] Production の env を自動更新するには次を付けて再実行:\n` +
        `  bun run release:upload-blob -- --sync-vercel-env\n` +
        `または手動:\n` +
        `  cd "${portfolioRootPath}" && bunx vercel@50 env add FILM_LAB_DESKTOP_DOWNLOAD_URL production --value "${publicUrl}" --yes --force`,
    );
    return 0;
  }

  const syncCode = syncDownloadUrlToVercelEnv(portfolioRootPath, publicUrl);
  if (syncCode !== 0) {
    console.error(`[${functionName}] env の同期に失敗しました。上の手動コマンドを実行してください。`);
    return syncCode;
  }
  console.log(
    `[${functionName}] FILM_LAB_DESKTOP_DOWNLOAD_URL を production に反映しました。本番デプロイを走らせてください。`,
  );
  return 0;
}

const exitCode = await main();
process.exit(exitCode);
