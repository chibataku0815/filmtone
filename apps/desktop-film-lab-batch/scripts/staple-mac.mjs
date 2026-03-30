/**
 * @file Film Lab Desktop の staple 補助スクリプト。
 * @description 公証の対象は **.app** です。electron-builder は .app を notarize したあと DMG を作るため、
 *   **DMG に stapler してもチケットが無くエラー 65 になる**ことがあります。既定では
 *   `release/mac-arm64/<productName>.app` に対して staple / validate を行います。
 * @limitations .app が未公証だと失敗します。パスを渡すときは **.app の絶対または相対パス**を指定してください。
 */

import fsSync from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const currentFilePath = fileURLToPath(import.meta.url);
const currentDirPath = path.dirname(currentFilePath);
const desktopRootPath = path.resolve(currentDirPath, "..");
const defaultReleaseDirPath = path.join(desktopRootPath, "release");
const packageJsonPath = path.join(desktopRootPath, "package.json");

/**
 * 子プロセスを実行し、stdout / stderr をまとめて返します。
 *
 * @param {string} command - 実行するコマンド名。
 * @param {string[]} args - コマンド引数。
 * @returns {Promise<{ stdout: string; stderr: string }>} 実行結果。
 */
function runCommand(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += String(chunk);
    });
    child.stderr.on("data", (chunk) => {
      stderr += String(chunk);
    });
    child.on("error", (error) => {
      reject(error);
    });
    child.on("close", (code) => {
      if (code === 0) {
        resolve({ stdout, stderr });
        return;
      }
      reject(
        new Error(
          `[runCommand] command=${command} args=${args.join(" ")} exitCode=${String(code)} stdout=${stdout.trim()} stderr=${stderr.trim()}`,
        ),
      );
    });
  });
}

/**
 * package.json から productName を読みます。
 *
 * @returns {string} 製品名（未検出時は Filmtone）。
 */
function readProductName() {
  const functionName = "readProductName";
  try {
    const text = fsSync.readFileSync(packageJsonPath, "utf8");
    const pkg = JSON.parse(text);
    const name = pkg?.build?.productName;
    return typeof name === "string" && name.length > 0 ? name : "Filmtone";
  } catch (error) {
    throw new Error(`[${functionName}] package.json を読めません。path=${packageJsonPath} error=${String(error)}`);
  }
}

/**
 * stapler 対象の .app パスを解決します。
 *
 * @param {string[]} rawArgs - CLI 引数（先頭が .app ならそれを優先）。
 * @returns {Promise<string>} .app の絶対パス。
 */
async function resolveAppBundlePath(rawArgs) {
  const functionName = "resolveAppBundlePath";
  if (rawArgs.length > 0) {
    const requested = path.resolve(process.cwd(), rawArgs[0]);
    if (requested.endsWith(".app")) {
      return requested;
    }
    throw new Error(
      `[${functionName}] 第 1 引数は .app にしてください（DMG に stapler するのは別途 DMG 単体の公証が必要です）。got=${requested}`,
    );
  }

  const productName = readProductName();
  const candidates = [
    path.join(defaultReleaseDirPath, "mac-arm64", `${productName}.app`),
    path.join(defaultReleaseDirPath, "mac", `${productName}.app`),
  ];

  for (const candidatePath of candidates) {
    try {
      await fs.access(candidatePath);
      return candidatePath;
    } catch {
      continue;
    }
  }

  throw new Error(
    `[${functionName}] stapler 対象の .app が見つかりません。` +
      `先に dist:mac:release を実行するか、次を確認: ${candidates.join(", ")}`,
  );
}

/**
 * 1 つの .app に staple と validate を行います。
 *
 * @param {string} appPath - .app の絶対パス。
 * @returns {Promise<void>} 完了したら resolve。
 */
async function stapleOneApp(appPath) {
  const functionName = "stapleOneApp";
  try {
    await fs.access(appPath);
  } catch (error) {
    throw new Error(
      `[${functionName}] .app が見つかりません。appPath=${appPath} error=${String(error)}`,
    );
  }

  console.log(`[${functionName}] Staple start: appPath=${appPath}`);
  await runCommand("xcrun", ["stapler", "staple", appPath]);
  await runCommand("xcrun", ["stapler", "validate", appPath]);
  console.log(`[${functionName}] Staple done: appPath=${appPath}`);
}

/**
 * CLI エントリポイントです。
 *
 * @returns {Promise<void>} 完了したら resolve。
 */
async function main() {
  const appPath = await resolveAppBundlePath(process.argv.slice(2));
  await stapleOneApp(appPath);
}

await main();
