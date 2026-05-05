/**
 * @file Filmtone Desktop (Native v2) 更新案内 JSON を Vercel Blob にアップロード。
 * @description 固定 pathname `film-lab/desktop/update-meta.json` (Electron 1.0.4 までと同じ)。
 *              `--sync-vercel-env` で `FILM_LAB_DESKTOP_UPDATE_CHECK_URL` を production に反映。
 *              Electron 1.0.4 のクライアントもこの URL を polling し続けるので、
 *              `latestVersion: 1.4` を書いておくと Electron user に upgrade 通知が出る
 *              (cutover-architecture.md decision G)。
 * @limitations DMG アップロードとは別コマンド。順序: DMG upload → update-meta upload。
 */
import { spawnSync } from "node:child_process";
import fsPromises from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {
  readDesktopReleaseMeta,
  resolvePortfolioRootPath,
} from "./release-artifact-meta.mjs";

async function mergeBlobTokenFromEnvFile(envFilePath) {
  if (process.env.BLOB_READ_WRITE_TOKEN?.trim()) return;
  let text;
  try {
    text = await fsPromises.readFile(envFilePath, "utf8");
  } catch {
    return;
  }
  for (const rawLine of text.split("\n")) {
    const line = rawLine.trim();
    if (line.length === 0 || line.startsWith("#")) continue;
    if (!line.startsWith("BLOB_READ_WRITE_TOKEN=")) continue;
    let value = line.slice("BLOB_READ_WRITE_TOKEN=".length).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (value.length > 0) process.env.BLOB_READ_WRITE_TOKEN = value;
    break;
  }
}

function extractPublicUrlFromOutput(combinedOutput) {
  const matches = combinedOutput.match(/https:\/\/[^\s"'<>]+/g);
  if (!matches || matches.length === 0) return null;
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

function syncUpdateCheckUrlToVercelEnv(portfolioRootPath, publicUrl) {
  const functionName = "syncUpdateCheckUrlToVercelEnv";
  const result = spawnSync(
    "bunx",
    [
      "vercel@50",
      "env",
      "add",
      "FILM_LAB_DESKTOP_UPDATE_CHECK_URL",
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
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  return result.status ?? 1;
}

async function main() {
  const functionName = "upload-update-meta";
  const rawArgs = process.argv.slice(2);
  const wantsSyncEnv = rawArgs.includes("--sync-vercel-env");
  // 本番 production blob への実 upload は明示 flag が必要。
  // 無い場合は dry-run (生成 JSON を print して exit 0)。
  // 直前 incident の再発防止: smoke 実行で本番 upload が走ってしまう事故を guard する。
  const wantsConfirmProd = rawArgs.includes("--confirm-prod");
  let downloadPageOverride = "";
  let releaseNotesOverride = "";
  for (let i = 0; i < rawArgs.length; i += 1) {
    const a = rawArgs[i];
    if (a === "--sync-vercel-env") continue;
    if (a === "--confirm-prod") continue;
    if (a === "--download-page" && rawArgs[i + 1]) {
      downloadPageOverride = rawArgs[i + 1];
      i += 1;
      continue;
    }
    if (a === "--release-notes-url" && rawArgs[i + 1]) {
      releaseNotesOverride = rawArgs[i + 1];
      i += 1;
      continue;
    }
  }

  const portfolioRootPath = await resolvePortfolioRootPath();
  if (!portfolioRootPath) {
    console.error(
      `[${functionName}] portfolio repo root が見つかりません (PORTFOLIO_ROOT env or sibling ../chibatakumi-portfolio)。`,
    );
    return 1;
  }

  await mergeBlobTokenFromEnvFile(path.join(portfolioRootPath, ".env.local"));

  if (!process.env.BLOB_READ_WRITE_TOKEN?.trim()) {
    console.error(
      `[${functionName}] BLOB_READ_WRITE_TOKEN がありません。env pull を確認してください。`,
    );
    return 1;
  }

  let releaseMeta;
  try {
    releaseMeta = await readDesktopReleaseMeta();
  } catch (e) {
    console.error(`[${functionName}] release meta 不正`, e);
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

  const downloadPageUrl =
    downloadPageOverride.trim() ||
    process.env.FILM_LAB_DESKTOP_DOWNLOAD_PAGE_URL?.trim() ||
    "https://www.chibatakumi.studio/film-lab/download";

  const releaseNotesUrl =
    releaseNotesOverride.trim() ||
    process.env.FILM_LAB_DESKTOP_RELEASE_NOTES_URL?.trim() ||
    undefined;

  const metaBody = {
    schemaVersion: 1,
    latestVersion: releaseMeta.version,
    downloadPageUrl,
    ...(releaseNotesUrl ? { releaseNotesUrl } : {}),
  };

  // Electron 1.0.4 までと同じ pathname。Electron client は polling し続ける前提なので、
  // 1.4 を書いた瞬間に in-app upgrade 通知が走る。
  const pathname = "film-lab/desktop/update-meta.json";

  if (!wantsConfirmProd) {
    console.log(
      `[${functionName}] DRY-RUN (no upload — pass --confirm-prod to upload)\n` +
        `[${functionName}] would write to ${pathname}:\n` +
        `${JSON.stringify(metaBody, null, 2)}\n` +
        `[${functionName}] Electron 1.0.4 client は次回 polling でこの latestVersion を取得するため、\n` +
        `[${functionName}] 実 DMG が download URL に着地済の状態でのみ確定実行してください。`,
    );
    return 0;
  }

  const tmpPath = path.join(
    os.tmpdir(),
    `film-lab-update-meta-${Date.now()}.json`,
  );
  await fsPromises.writeFile(tmpPath, `${JSON.stringify(metaBody, null, 2)}\n`, "utf8");

  console.log(
    `[${functionName}] upload meta latestVersion=${releaseMeta.version} pathname=${pathname}`,
  );

  const putResult = spawnSync(
    "bunx",
    [
      "vercel@50",
      "blob",
      "put",
      tmpPath,
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

  try {
    await fsPromises.unlink(tmpPath);
  } catch {
    /* ignore */
  }

  const combinedOutput = `${putResult.stdout ?? ""}${putResult.stderr ?? ""}`;
  if (putResult.stdout) process.stdout.write(putResult.stdout);
  if (putResult.stderr) process.stderr.write(putResult.stderr);

  if (putResult.error) {
    console.error(`[${functionName}] blob put 起動失敗`, putResult.error);
    return 1;
  }
  if (putResult.status !== 0) {
    console.error(`[${functionName}] blob put 失敗 exit=${putResult.status}`);
    return putResult.status ?? 1;
  }

  const publicUrl = extractPublicUrlFromOutput(combinedOutput);
  if (!publicUrl) {
    console.warn(
      `[${functionName}] 公開 URL を自動抽出できませんでした。CLI 出力からコピーし、\n` +
        `FILM_LAB_DESKTOP_UPDATE_CHECK_URL を手動設定するか、--sync-vercel-env で再実行してください。`,
    );
    return 0;
  }

  console.log(`\n[${functionName}] PUBLIC_URL=${publicUrl}`);

  if (!wantsSyncEnv) {
    console.log(
      `\n[${functionName}] production env を更新するには:\n` +
        `  bun run release:upload-update-meta -- --sync-vercel-env`,
    );
    return 0;
  }

  const syncCode = syncUpdateCheckUrlToVercelEnv(portfolioRootPath, publicUrl);
  if (syncCode !== 0) {
    console.error(`[${functionName}] env 同期失敗`);
    return syncCode;
  }
  console.log(
    `[${functionName}] FILM_LAB_DESKTOP_UPDATE_CHECK_URL を production に反映しました。\n` +
      `次: portfolio 側を本番 deploy すると Electron 1.0.4 / Native 1.4 双方が新 latestVersion を polling 取得します。`,
  );
  return 0;
}

const code = await main();
process.exit(code);
