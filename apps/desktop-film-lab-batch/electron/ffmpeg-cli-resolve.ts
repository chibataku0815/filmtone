/**
 * @fileoverview Filmtone Desktop の `ffmpeg` / `ffprobe` 解決ヘルパー
 *
 * @overview macOS の Finder から起動した GUI アプリは、ターミナルの `PATH` をそのまま受け取らないことがあります。
 * そのため、動画書き出しで必要な `ffmpeg` / `ffprobe` が Homebrew に入っていても、
 * packaged app だけ `spawn ... ENOENT` で失敗することがあります。
 *
 * このファイルでは、次の順で「どの実行ファイルを使うか」を決めます。
 * 1. 明示 override（`FILM_LAB_FFMPEG_PATH` / `FILM_LAB_FFPROBE_PATH`）
 * 2. 同梱 resource binary（packaged app では `process.resourcesPath/bin/<platform-arch>`）
 * 3. `fix-path` による GUI 用 `PATH` 補正
 * 4. 既知の Homebrew / system ディレクトリを追加した `PATH`
 */
import { accessSync, constants as fsConstants } from "node:fs";
import path from "node:path";

import fixPath from "fix-path";

/**
 * @description このアプリで扱う CLI 名。動画の probe / export に限定します。
 */
export type VideoCliBinaryName = "ffmpeg" | "ffprobe";

export type VideoCliBinarySource =
  | "env-override"
  | "bundled-resource"
  | "path-search";

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
  source: VideoCliBinarySource;
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

function getProcessResourcesPath(): string | undefined {
  const processWithElectronResources = process as NodeJS.Process & {
    resourcesPath?: string;
  };
  const resourcesPath = processWithElectronResources.resourcesPath?.trim();
  return resourcesPath && resourcesPath.length > 0 ? resourcesPath : undefined;
}

function getDefaultVideoCliResourceRoots(): string[] {
  return uniqueOrdered([
    getProcessResourcesPath() ?? "",
    path.resolve(process.cwd(), "resources"),
  ].filter((entry) => entry.length > 0));
}

export function getVideoCliResourcePlatformArch(
  platform: NodeJS.Platform = process.platform,
  arch: NodeJS.Architecture = process.arch,
): string {
  return `${platform}-${arch}`;
}

export function buildBundledVideoCliCandidatePaths(
  binaryName: VideoCliBinaryName,
  options: {
    resourceRoots?: readonly string[];
    platform?: NodeJS.Platform;
    arch?: NodeJS.Architecture;
  } = {},
): string[] {
  const resourceRoots =
    options.resourceRoots ?? getDefaultVideoCliResourceRoots();
  const platformArch = getVideoCliResourcePlatformArch(
    options.platform,
    options.arch,
  );
  return uniqueOrdered(
    resourceRoots
      .map((resourceRoot) => resourceRoot.trim())
      .filter((resourceRoot) => resourceRoot.length > 0)
      .map((resourceRoot) =>
        path.join(path.resolve(resourceRoot), "bin", platformArch, binaryName),
      ),
  );
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
 * @param options.bundledResourceRoots 同梱 resource root の差し替え
 * @param options.isExecutable 実行可否判定の差し替え
 */
export function resolveVideoCliBinaryFromPath(
  binaryName: VideoCliBinaryName,
  options: {
    envPath?: string;
    envOverridePath?: string;
    bundledResourceRoots?: readonly string[];
    platform?: NodeJS.Platform;
    arch?: NodeJS.Architecture;
    isExecutable?: (absPath: string) => boolean;
  } = {},
): Omit<ResolvedVideoCliBinary, "binaryName" | "childEnv"> {
  const checkExecutable = options.isExecutable ?? isExecutableFile;
  const searchedPaths: string[] = [];
  const pushSearchedPath = (absPath: string): boolean => {
    if (searchedPaths.includes(absPath)) {
      return false;
    }
    searchedPaths.push(absPath);
    return true;
  };
  const overridePath = options.envOverridePath?.trim() ?? "";
  if (overridePath.length > 0) {
    const resolvedOverride = path.resolve(overridePath);
    pushSearchedPath(resolvedOverride);
    if (checkExecutable(resolvedOverride)) {
      return {
        commandPath: resolvedOverride,
        source: "env-override",
        searchedPaths,
      };
    }
  }

  for (const absPath of buildBundledVideoCliCandidatePaths(binaryName, {
    resourceRoots: options.bundledResourceRoots,
    platform: options.platform,
    arch: options.arch,
  })) {
    if (!pushSearchedPath(absPath)) {
      continue;
    }
    if (checkExecutable(absPath)) {
      return {
        commandPath: absPath,
        source: "bundled-resource",
        searchedPaths,
      };
    }
  }

  for (const dirPath of splitPathEntries(options.envPath)) {
    const absPath = path.join(dirPath, binaryName);
    if (!pushSearchedPath(absPath)) {
      continue;
    }
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
      : `同梱 resource と PATH を確認してください。開発時は ${overrideEnvName} を指定できます。`;
  throw new Error(
    `${binaryName} 実行ファイルが見つかりません。${extraHint} searched=${searchedPaths.join(", ")}`,
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
