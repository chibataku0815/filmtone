/**
 * @file Film Lab Desktop の macOS notarization フック。
 * @description electron-builder の `afterSign` から呼ばれ、署名済み `.app` を Apple へ提出します。
 * @limitations Developer ID 証明書と Apple 認証情報が必要です。`FILM_LAB_DESKTOP_SKIP_NOTARIZE=true`
 *   のときはローカルの unsigned build 用として何もせず終了します。
 */

import fs from "node:fs/promises";
import path from "node:path";
import { notarize } from "@electron/notarize";

const filmLabDesktopAppBundleId = "com.chibatakumi.film-lab-desktop";

/**
 * 環境変数を trim 済み文字列で返します。
 *
 * @param {string} name - 読みたい環境変数名。
 * @returns {string} 空なら空文字。
 */
function readTrimmedEnv(name) {
  const raw = process.env[name];
  return typeof raw === "string" ? raw.trim() : "";
}

/**
 * true / 1 / yes を「有効」とみなします。
 *
 * @param {string | undefined} value - 判定したい値。
 * @returns {boolean} 有効とみなせるとき true。
 */
function isTruthy(value) {
  if (typeof value !== "string") return false;
  const normalized = value.trim().toLowerCase();
  return normalized === "1" || normalized === "true" || normalized === "yes";
}

/**
 * App Store Connect API key モードを解決します。
 *
 * @param {string} functionName - エラー文に出す関数名。
 * @returns {{
 *   appleApiKey: string;
 *   appleApiKeyId: string;
 *   appleApiIssuer?: string;
 *   authMode: "api-key";
 * } | null} API key モードが未設定なら null。
 */
async function resolveApiKeyCredentials(functionName) {
  const appleApiKey = readTrimmedEnv("APPLE_API_KEY");
  const appleApiKeyId = readTrimmedEnv("APPLE_API_KEY_ID");
  const appleApiIssuer = readTrimmedEnv("APPLE_API_ISSUER");
  const someApiKeyEnvIsSet =
    appleApiKey.length > 0 || appleApiKeyId.length > 0 || appleApiIssuer.length > 0;

  if (!someApiKeyEnvIsSet) {
    return null;
  }

  const missing = [];
  if (appleApiKey.length === 0) missing.push("APPLE_API_KEY");
  if (appleApiKeyId.length === 0) missing.push("APPLE_API_KEY_ID");
  if (missing.length > 0) {
    throw new Error(
      `[${functionName}] App Store Connect API key 認証が不完全です。missing=${missing.join(", ")}`,
    );
  }

  try {
    await fs.access(appleApiKey);
  } catch (error) {
    throw new Error(
      `[${functionName}] APPLE_API_KEY のファイルが読めません。APPLE_API_KEY=${appleApiKey} error=${String(
        error,
      )}`,
    );
  }

  return {
    appleApiKey,
    appleApiKeyId,
    ...(appleApiIssuer.length > 0 ? { appleApiIssuer } : {}),
    authMode: "api-key",
  };
}

/**
 * Apple ID + app-specific password モードを解決します。
 *
 * @param {string} functionName - エラー文に出す関数名。
 * @returns {{
 *   appleId: string;
 *   appleIdPassword: string;
 *   teamId: string;
 *   authMode: "apple-id";
 * } | null} Apple ID モードが未設定なら null。
 */
function resolveAppleIdCredentials(functionName) {
  const appleId = readTrimmedEnv("APPLE_ID");
  const appleIdPassword = readTrimmedEnv("APPLE_APP_SPECIFIC_PASSWORD");
  const teamId = readTrimmedEnv("APPLE_TEAM_ID");
  const someAppleIdEnvIsSet =
    appleId.length > 0 || appleIdPassword.length > 0 || teamId.length > 0;

  if (!someAppleIdEnvIsSet) {
    return null;
  }

  const missing = [];
  if (appleId.length === 0) missing.push("APPLE_ID");
  if (appleIdPassword.length === 0) missing.push("APPLE_APP_SPECIFIC_PASSWORD");
  if (teamId.length === 0) missing.push("APPLE_TEAM_ID");
  if (missing.length > 0) {
    throw new Error(
      `[${functionName}] Apple ID 認証が不完全です。missing=${missing.join(", ")}`,
    );
  }

  return {
    appleId,
    appleIdPassword,
    teamId,
    authMode: "apple-id",
  };
}

/**
 * notarize に渡す認証情報を 2 方式から解決します。
 *
 * @param {string} functionName - エラー文に出す関数名。
 * @returns {Promise<
 *   | {
 *       appleApiKey: string;
 *       appleApiKeyId: string;
 *       appleApiIssuer?: string;
 *       authMode: "api-key";
 *     }
 *   | {
 *       appleId: string;
 *       appleIdPassword: string;
 *       teamId: string;
 *       authMode: "apple-id";
 *     }
 * >} notarize にそのまま渡せる認証情報。
 */
async function resolveNotarizeCredentials(functionName) {
  const apiKeyCredentials = await resolveApiKeyCredentials(functionName);
  if (apiKeyCredentials != null) {
    return apiKeyCredentials;
  }

  const appleIdCredentials = resolveAppleIdCredentials(functionName);
  if (appleIdCredentials != null) {
    return appleIdCredentials;
  }

  throw new Error(
    `[${functionName}] notarization 認証情報がありません。` +
      `Provide either { APPLE_API_KEY, APPLE_API_KEY_ID, [APPLE_API_ISSUER] } ` +
      `or { APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID }.`,
  );
}

/**
 * electron-builder の afterSign から呼ばれる main 関数です。
 *
 * @param {{
 *   appOutDir?: string;
 *   packager?: {
 *     appInfo?: {
 *       productFilename?: string;
 *     };
 *   };
 * }} context - electron-builder の実行コンテキスト。
 * @returns {Promise<void>} 完了したら resolve。
 */
export default async function notarizeMacApp(context) {
  const functionName = "notarizeMacApp";

  if (process.platform !== "darwin") {
    console.log(`[${functionName}] Skip: process.platform=${process.platform}`);
    return;
  }

  if (isTruthy(process.env.FILM_LAB_DESKTOP_SKIP_NOTARIZE)) {
    console.log(
      `[${functionName}] Skip: FILM_LAB_DESKTOP_SKIP_NOTARIZE=${process.env.FILM_LAB_DESKTOP_SKIP_NOTARIZE}`,
    );
    return;
  }

  const appOutDir = context?.appOutDir;
  const productFilename = context?.packager?.appInfo?.productFilename;
  if (typeof appOutDir !== "string" || appOutDir.length === 0) {
    throw new Error(
      `[${functionName}] appOutDir が取得できません。context.appOutDir=${String(context?.appOutDir)}`,
    );
  }
  if (typeof productFilename !== "string" || productFilename.length === 0) {
    throw new Error(
      `[${functionName}] productFilename が取得できません。context.packager.appInfo.productFilename=${String(
        context?.packager?.appInfo?.productFilename,
      )}`,
    );
  }

  const appPath = path.join(appOutDir, `${productFilename}.app`);
  try {
    await fs.access(appPath);
  } catch (error) {
    throw new Error(
      `[${functionName}] notarize 対象の app が見つかりません。appPath=${appPath} error=${String(
        error,
      )}`,
    );
  }

  const credentials = await resolveNotarizeCredentials(functionName);
  console.log(
    `[${functionName}] Start: appBundleId=${filmLabDesktopAppBundleId} appPath=${appPath} authMode=${credentials.authMode}`,
  );

  await notarize({
    appBundleId: filmLabDesktopAppBundleId,
    appPath,
    ...credentials,
  });

  console.log(`[${functionName}] Completed: appPath=${appPath}`);
}
