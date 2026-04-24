/**
 * @fileoverview ローカル ffmpeg が HDR→SDR 変換に必要な filter を持っているかを確認する。
 *
 * @overview Homebrew 既定の ffmpeg は `tonemap` / `colorspace` だけを含み、
 * PQ EOTF 逆変換や HLG OOTF を正しく扱うための `zscale` / `libplacebo` は省略されています。
 * HDR fixture が揃う前でも、HDR source を受けた時に pixel を変えずに
 * `defer-unknown` を返すための可視化データだけをここで用意します。
 *
 * @limitations capability probe を実行する API はここにまとめますが、
 * HdrPreparationPolicy の最終判定は video-export-source-metadata.ts 側で行います。
 * 実 filter を走らせる pipeline 変更はこの PR には含めません。
 */
import { execFile } from "node:child_process";
import { promisify } from "node:util";

import type { FFmpegHdrCapabilities } from "./video-export-source-metadata";

const execFileAsync = promisify(execFile);

/**
 * @description ffmpeg -filters 出力から HDR 変換に関係する filter の有無を抽出する純関数。
 * 行の先頭はフラグ（slice/timeline/command）、その後に filter 名・I/O・description が並ぶ。
 * 例: " TS colorspace        V->V       Convert between colorspaces."
 *
 * @param stdout `ffmpeg -hide_banner -filters` の標準出力
 */
export function parseFfmpegFilterList(stdout: string): FFmpegHdrCapabilities {
  const filterNames = new Set<string>();
  for (const rawLine of stdout.split(/\r?\n/)) {
    const match = rawLine.match(/^\s*[.A-Z]{2,4}\s+([A-Za-z0-9_]+)\s+\S+->\S+/);
    if (match) {
      filterNames.add(match[1]);
    }
  }
  return {
    hasZscale: filterNames.has("zscale"),
    hasLibplacebo: filterNames.has("libplacebo"),
    hasTonemap: filterNames.has("tonemap"),
    hasColorspace: filterNames.has("colorspace"),
  };
}

/**
 * @description HDR→SDR 変換を正しく書ける ffmpeg ビルドかを判定する。
 * `zscale` または `libplacebo` のいずれかが必須。`tonemap` 単独では PQ EOTF / HLG OOTF を処理できない。
 */
export function supportsHdrToSdrPreparation(
  capabilities: FFmpegHdrCapabilities,
): boolean {
  return capabilities.hasZscale || capabilities.hasLibplacebo;
}

/**
 * @description 欠けている HDR filter を人間可読な短い文字列で返す。警告文の組み立て用。
 */
export function summarizeMissingHdrFilters(
  capabilities: FFmpegHdrCapabilities,
): string {
  const missing: string[] = [];
  if (!capabilities.hasZscale) missing.push("zscale");
  if (!capabilities.hasLibplacebo) missing.push("libplacebo");
  return missing.join(", ");
}

type CapabilityProbeOptions = {
  /** @description ffmpeg 実行ファイルの絶対パス */
  commandPath: string;
  /** @description 子プロセス用 env（PATH 補正済み） */
  env?: NodeJS.ProcessEnv;
  /** @description テスト差し替え用 execFile。実装は stdout を返すだけでよい */
  runner?: (
    commandPath: string,
    args: readonly string[],
    env: NodeJS.ProcessEnv | undefined,
  ) => Promise<{ stdout: string }>;
};

const capabilityCache = new Map<string, Promise<FFmpegHdrCapabilities>>();

async function defaultRunner(
  commandPath: string,
  args: readonly string[],
  env: NodeJS.ProcessEnv | undefined,
): Promise<{ stdout: string }> {
  const r = await execFileAsync(commandPath, [...args], {
    maxBuffer: 4 * 1024 * 1024,
    env,
  });
  return { stdout: r.stdout as string };
}

/**
 * @description ffmpeg -hide_banner -filters を 1 回だけ実行して capability を確定する。
 * 同じ実行ファイルパスに対しては結果を cache する。失敗時は「何も持たない」ビルドとして扱う。
 * @param options.commandPath 解決済みの ffmpeg 絶対パス
 */
export async function probeFfmpegHdrCapabilities(
  options: CapabilityProbeOptions,
): Promise<FFmpegHdrCapabilities> {
  const cached = capabilityCache.get(options.commandPath);
  if (cached) return cached;
  const runner = options.runner ?? defaultRunner;
  const task = (async () => {
    try {
      const { stdout } = await runner(
        options.commandPath,
        ["-hide_banner", "-filters"],
        options.env,
      );
      return parseFfmpegFilterList(stdout);
    } catch {
      return {
        hasZscale: false,
        hasLibplacebo: false,
        hasTonemap: false,
        hasColorspace: false,
      };
    }
  })();
  capabilityCache.set(options.commandPath, task);
  return task;
}

/**
 * @description テスト間で capability cache を初期化するための hook。
 */
export function __resetFfmpegHdrCapabilityCacheForTesting(): void {
  capabilityCache.clear();
}
