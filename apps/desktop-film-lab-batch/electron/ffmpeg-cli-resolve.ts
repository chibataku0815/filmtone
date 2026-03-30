/**
 * @fileoverview Filmtone Desktop の `ffmpeg` / `ffprobe` 解決ヘルパー
 *
 * @overview macOS の Finder から起動した GUI アプリは、ターミナルの `PATH` をそのまま受け取らないことがあります。
 * そのため、動画書き出しで必要な `ffmpeg` / `ffprobe` が Homebrew に入っていても、
 * packaged app だけ `spawn ... ENOENT` で失敗することがあります。
 *
 * このファイルでは、次の順で「どの実行ファイルを使うか」を決めます。
 * 1. 明示 override（`FILM_LAB_FFMPEG_PATH` / `FILM_LAB_FFPROBE_PATH`）
 * 2. `fix-path` による GUI 用 `PATH` 補正
 * 3. 既知の Homebrew / system ディレクトリを追加した `PATH`
 *
 * @limitations いまは同梱バイナリ（`process.resourcesPath` 配下）は扱いません。
 * 将来バンドルする場合は、この resolver の優先順位に追加します。
 */
import { accessSync, constants as fsConstants } from "node:fs";
import path from "node:path";

import fixPath from "fix-path";

/**
 * @description このアプリで扱う CLI 名。動画の probe / export に限定します。
 */
export type VideoCliBinaryName = "ffmpeg" | "ffprobe";

/**
 * @description resolver が返す診断情報。
 * @property binaryName どちらの CLI を解決したか
 * @property commandPath `spawn` / `execFile` にそのまま渡す絶対パス
 * @property childEnv 子プロセス用に整えた環境変数
 * @property source どのルールで見つけたか
 * @property searchedPaths 探した絶対パス一覧（失敗時ログ用）
 */
export type ResolvedVideoCliBinary = {
  binaryName: VideoCliBinaryName;
  commandPath: string;
  childEnv: NodeJS.ProcessEnv;
  source: "env-override" | "path-search";
  searchedPaths: string[];
};

/**
 * @description GUI 起動時に見えづらいが、macOS で実際によく使われるパスを追加候補として固定します。
 * Apple Silicon の Homebrew は `/opt/homebrew/bin`、Intel 系は `/usr/local/bin` が主です。
 */
export const VIDEO_CLI_FALLBACK_DIRS = [
  "/opt/homebrew/bin",
  "/usr/local/bin",
  "/usr/bin",
  "/bin",
] as const;

const VIDEO_CLI_OVERRIDE_ENV: Record<VideoCliBinaryName, string> = {
  ffmpeg: "FILM_LAB_FFMPEG_PATH",
  ffprobe: "FILM_LAB_FFPROBE_PATH",
};

let videoCliPathPrepared = false;

/**
 * @description `PATH` 文字列を配列へほどき、空要素を落としつつ順序を保ちます。
 * @param envPath 元の `PATH`
 */
export function splitPathEntries(envPath: string | undefined): string[] {
  if (!envPath) {
    return [];
  }
  return envPath
    .split(path.delimiter)
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

/**
 * @description 配列を左から順に見て、同じ文字列の重複を 1 個に詰めます。
 * @param values ディレクトリやパスの配列
 */
function uniqueOrdered(values: readonly string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const value of values) {
    if (seen.has(value)) {
      continue;
    }
    seen.add(value);
    out.push(value);
  }
  return out;
}

/**
 * @description 子プロセスに渡す `PATH` を組み立てます。
 * 既存 `PATH` の順序を尊重しつつ、足りない既知パスだけ後ろへ足します。
 * @param envPath 現在の `PATH`
 */
export function mergeVideoCliPath(envPath: string | undefined): string {
  const mergedEntries = uniqueOrdered([
    ...splitPathEntries(envPath),
    ...VIDEO_CLI_FALLBACK_DIRS,
  ]);
  return mergedEntries.join(path.delimiter);
}

/**
 * @description 絶対パスの実行可否を小さく判定します。
 * @param absPath 実行候補の絶対パス
 */
function isExecutableFile(absPath: string): boolean {
  try {
    accessSync(absPath, fsConstants.X_OK);
    return true;
  } catch {
    return false;
  }
}

/**
 * @description GUI 起動で欠けた `PATH` を 1 回だけ補正します。
 * `fix-path` が失敗しても、後続の fallback 探索には進めるように握りつぶします。
 */
export function prepareVideoCliChildEnv(
  baseEnv: NodeJS.ProcessEnv = process.env,
): NodeJS.ProcessEnv {
  if (
    !videoCliPathPrepared &&
    (process.platform === "darwin" || process.platform === "linux")
  ) {
    try {
      fixPath();
    } catch (error) {
      const message =
        error instanceof Error ? error.message : String(error);
      console.warn(`[film-lab-desktop] fix-path failed: ${message}`);
    } finally {
      videoCliPathPrepared = true;
    }
  }

  const mergedPath = mergeVideoCliPath(baseEnv.PATH ?? process.env.PATH);
  process.env.PATH = mergedPath;
  return {
    ...baseEnv,
    PATH: mergedPath,
  };
}

/**
 * @description 実際に探索ロジックだけを行う純関数です。
 * テストではファイル実在確認を差し替え、packaged app 相当の `PATH` を再現します。
 * @param binaryName 探す CLI 名
 * @param options.envPath 探索対象の `PATH`
 * @param options.envOverridePath 明示指定があれば最優先
 * @param options.isExecutable 実行可否判定の差し替え
 */
export function resolveVideoCliBinaryFromPath(
  binaryName: VideoCliBinaryName,
  options: {
    envPath?: string;
    envOverridePath?: string;
    isExecutable?: (absPath: string) => boolean;
  } = {},
): Omit<ResolvedVideoCliBinary, "binaryName" | "childEnv"> {
  const checkExecutable = options.isExecutable ?? isExecutableFile;
  const searchedPaths: string[] = [];
  const overridePath = options.envOverridePath?.trim() ?? "";
  if (overridePath.length > 0) {
    const resolvedOverride = path.resolve(overridePath);
    searchedPaths.push(resolvedOverride);
    if (checkExecutable(resolvedOverride)) {
      return {
        commandPath: resolvedOverride,
        source: "env-override",
        searchedPaths,
      };
    }
  }

  for (const dirPath of splitPathEntries(options.envPath)) {
    const absPath = path.join(dirPath, binaryName);
    if (searchedPaths.includes(absPath)) {
      continue;
    }
    searchedPaths.push(absPath);
    if (checkExecutable(absPath)) {
      return {
        commandPath: absPath,
        source: "path-search",
        searchedPaths,
      };
    }
  }

  const overrideEnvName = VIDEO_CLI_OVERRIDE_ENV[binaryName];
  const extraHint =
    overridePath.length > 0
      ? `${overrideEnvName}=${path.resolve(overridePath)} でも解決できませんでした。`
      : `${overrideEnvName} を指定するか、Homebrew の ffmpeg を確認してください。`;
  throw new Error(
    `${binaryName} が見つかりません。${extraHint} searched=${searchedPaths.join(", ")}`,
  );
}

/**
 * @description 本番コード用の入口です。
 * GUI 用 `PATH` 補正と fallback ディレクトリ追加を済ませたうえで、`ffmpeg` / `ffprobe` を絶対パスへ解決します。
 * @param binaryName 探す CLI 名
 */
export function resolveVideoCliBinary(
  binaryName: VideoCliBinaryName,
): ResolvedVideoCliBinary {
  const childEnv = prepareVideoCliChildEnv();
  const overrideEnvName = VIDEO_CLI_OVERRIDE_ENV[binaryName];
  const resolved = resolveVideoCliBinaryFromPath(binaryName, {
    envPath: childEnv.PATH,
    envOverridePath: childEnv[overrideEnvName],
  });
  return {
    binaryName,
    commandPath: resolved.commandPath,
    childEnv,
    source: resolved.source,
    searchedPaths: resolved.searchedPaths,
  };
}
