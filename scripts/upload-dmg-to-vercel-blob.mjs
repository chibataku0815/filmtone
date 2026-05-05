/**
 * @file Filmtone Desktop (Native v2) の DMG を Vercel Blob にアップロード。
 * @description 配布 pathname は固定規約 (`filmtone/desktop/Filmtone-${version}.dmg`)。
 *              `bunx vercel@50 blob put` を呼びます。Electron 1.0.4 までと同じ env var
 *              `FILM_LAB_DESKTOP_DOWNLOAD_URL` を更新するので、portfolio の download 導線は
 *              手動切替不要で 1.4 に切り替わります (cutover-architecture.md decision G)。
 * @limitations `BLOB_READ_WRITE_TOKEN` が必要。portfolio repo の `.env.local` に
 *              `vercel env pull` 済みなら自動読込。
 *              portfolio root の解決は `PORTFOLIO_ROOT` env or sibling
 *              `../chibatakumi-portfolio`。
 */

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import fsPromises from "node:fs/promises";
import path from "node:path";
import {
  readDesktopReleaseMeta,
  resolvePortfolioRootPath,
} from "./release-artifact-meta.mjs";

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
    if (
      candidateUrl.includes("blob.vercel-storage.com") ||
      candidateUrl.includes("vercel-storage.com")
    ) {
      return candidateUrl.replace(/[,;.)]+$/, "");
    }
  }
  return matches[0].replace(/[,;.)]+$/, "");
}

/**
 * Vercel の Production に `FILM_LAB_DESKTOP_DOWNLOAD_URL` を書き込みます。
 *
 * @param {string} portfolioRootPath - portfolio repo root。
 * @param {string} publicUrl - DMG の HTTPS URL。
 * @returns {number} 終了コード (0 なら成功)。
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

async function main() {
  const functionName = "upload-dmg";
  const rawArgs = process.argv.slice(2);
  const wantsSyncEnv = rawArgs.includes("--sync-vercel-env");
  // 本番 production blob への実 upload + env sync は明示 flag が必要。
  // 無い場合は dry-run (upload しない)。
  const wantsConfirmProd = rawArgs.includes("--confirm-prod");
  const filteredArgs = rawArgs.filter(
    (arg) => arg !== "--sync-vercel-env" && arg !== "--confirm-prod",
  );

  const portfolioRootPath = await resolvePortfolioRootPath();
  if (!portfolioRootPath) {
    console.error(
      `[${functionName}] portfolio repo root が見つかりません。\n` +
        `  - PORTFOLIO_ROOT env を絶対 path で設定するか\n` +
        `  - filmtone repo の sibling として ../chibatakumi-portfolio を配置し、\n` +
        `    そこで bunx vercel@50 link 済みであること (.vercel/project.json 必須)`,
    );
    return 1;
  }

  await mergeBlobTokenFromEnvFile(path.join(portfolioRootPath, ".env.local"));

  if (!process.env.BLOB_READ_WRITE_TOKEN?.trim()) {
    console.error(
      `[${functionName}] BLOB_READ_WRITE_TOKEN がありません。\n` +
        `1) Vercel で Blob をプロジェクトに接続\n` +
        `2) portfolio root で: bunx vercel@50 env pull .env.local\n` +
        `3) もう一度このスクリプトを実行`,
    );
    return 1;
  }

  let releaseMeta;
  try {
    releaseMeta = await readDesktopReleaseMeta();
  } catch (error) {
    console.error(`[${functionName}] release meta を読めません`, error);
    return 1;
  }

  try {
    await fsPromises.access(releaseMeta.releaseNotesPath);
  } catch {
    console.warn(
      `[${functionName}] 版付き release notes が見つかりません (informational)。` +
        ` version=${releaseMeta.version} expected=${releaseMeta.releaseNotesFileName}`,
    );
  }

  const dmgPath =
    filteredArgs.length > 0
      ? path.resolve(process.cwd(), filteredArgs[0])
      : releaseMeta.dmgPath;

  if (!fs.existsSync(dmgPath)) {
    console.error(
      `[${functionName}] DMG が見つかりません: ${dmgPath}\n` +
        `先に scripts/release-macos.sh + scripts/package-dmg.sh で生成するか、引数で path を渡してください。`,
    );
    return 1;
  }

  // Electron 1.0.4 と同じ `filmtone/desktop/` prefix 配下に配置 (cutover-architecture.md decision G)。
  // 旧 1.0.4 DMG (`filmtone-1.0.4-arm64.dmg`) と Native v2 DMG (`Filmtone-1.4.dmg`) は別 file 名なので衝突しない。
  const pathname = `${releaseMeta.artifactSlug}/desktop/${releaseMeta.dmgFileName}`;

  if (!wantsConfirmProd) {
    console.log(
      `[${functionName}] DRY-RUN (no upload — pass --confirm-prod to upload)\n` +
        `[${functionName}] portfolio root: ${portfolioRootPath}\n` +
        `[${functionName}] would upload: ${dmgPath}\n` +
        `[${functionName}] product: ${releaseMeta.productName} version=${releaseMeta.version}\n` +
        `[${functionName}] pathname: ${pathname}\n` +
        `[${functionName}] sync FILM_LAB_DESKTOP_DOWNLOAD_URL: ${wantsSyncEnv ? "yes" : "no"}`,
    );
    return 0;
  }

  console.log(
    `[${functionName}] portfolio root: ${portfolioRootPath}\n` +
      `[${functionName}] upload: ${dmgPath}\n` +
      `[${functionName}] product: ${releaseMeta.productName} version=${releaseMeta.version}\n` +
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
      `[${functionName}] 公開 URL を自動抽出できませんでした。CLI 出力からコピーし、\n` +
        `Vercel の FILM_LAB_DESKTOP_DOWNLOAD_URL (production) に貼るか、次を実行してください:\n` +
        `  cd "${portfolioRootPath}" && bunx vercel@50 env add FILM_LAB_DESKTOP_DOWNLOAD_URL production --value "<URL>" --yes --force`,
    );
    return 0;
  }

  console.log(`\n[${functionName}] PUBLIC_URL=${publicUrl}`);

  if (!wantsSyncEnv) {
    console.log(
      `\n[${functionName}] Production の env を自動更新するには次を付けて再実行:\n` +
        `  bun run release:upload-dmg -- --sync-vercel-env\n` +
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
