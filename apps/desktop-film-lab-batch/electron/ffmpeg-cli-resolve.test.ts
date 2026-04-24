/**
 * @fileoverview Filmtone Desktop の `ffmpeg` / `ffprobe` 解決ルールの回帰テスト
 */
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";

import { afterEach, describe, expect, it } from "vitest";

import {
  mergeVideoCliPath,
  resolveVideoCliBinaryFromPath,
  splitPathEntries,
  VIDEO_CLI_FALLBACK_DIRS,
} from "./ffmpeg-cli-resolve";

describe("ffmpeg-cli-resolve", () => {
  const tempDirs: string[] = [];

  function createTempDir(): string {
    const tempDir = mkdtempSync(path.join(os.tmpdir(), "filmtone-cli-"));
    tempDirs.push(tempDir);
    return tempDir;
  }

  function createExecutableFile(absPath: string): string {
    mkdirSync(path.dirname(absPath), { recursive: true });
    writeFileSync(absPath, "#!/bin/sh\nexit 0\n");
    chmodSync(absPath, 0o755);
    return absPath;
  }

  afterEach(() => {
    for (const tempDir of tempDirs.splice(0)) {
      rmSync(tempDir, { recursive: true, force: true });
    }
  });

  it("keeps existing PATH order and appends fallback dirs once", () => {
    const merged = mergeVideoCliPath(
      ["/custom/bin", "/usr/bin", "/opt/homebrew/bin"].join(":"),
    );

    expect(splitPathEntries(merged)).toEqual([
      "/custom/bin",
      "/usr/bin",
      "/opt/homebrew/bin",
      "/usr/local/bin",
      "/bin",
    ]);
  });

  it("prefers explicit env override over bundled resource and PATH binaries", () => {
    const tempDir = createTempDir();
    const bundledResourceRoot = path.join(tempDir, "resources");
    const pathBinDir = path.join(tempDir, "path-bin");
    const overridePath = createExecutableFile(
      path.join(tempDir, "override", "custom-ffprobe"),
    );
    createExecutableFile(
      path.join(
        bundledResourceRoot,
        "bin",
        "darwin-arm64",
        "ffprobe",
      ),
    );
    createExecutableFile(path.join(pathBinDir, "ffprobe"));

    const resolved = resolveVideoCliBinaryFromPath("ffprobe", {
      envPath: pathBinDir,
      envOverridePath: overridePath,
      bundledResourceRoots: [bundledResourceRoot],
      platform: "darwin",
      arch: "arm64",
    });

    expect(resolved.commandPath).toBe(overridePath);
    expect(resolved.source).toBe("env-override");
  });

  it("prefers bundled resource binary before PATH search", () => {
    const tempDir = createTempDir();
    const bundledResourceRoot = path.join(tempDir, "resources");
    const pathBinDir = path.join(tempDir, "path-bin");
    const bundledFfmpeg = createExecutableFile(
      path.join(
        bundledResourceRoot,
        "bin",
        "darwin-arm64",
        "ffmpeg",
      ),
    );
    createExecutableFile(path.join(pathBinDir, "ffmpeg"));

    const resolved = resolveVideoCliBinaryFromPath("ffmpeg", {
      envPath: pathBinDir,
      bundledResourceRoots: [bundledResourceRoot],
      platform: "darwin",
      arch: "arm64",
    });

    expect(resolved.commandPath).toBe(bundledFfmpeg);
    expect(resolved.source).toBe("bundled-resource");
  });

  it("falls back to PATH search when no env override or bundled binary exists", () => {
    const tempDir = createTempDir();
    const pathBinDir = path.join(tempDir, "path-bin");
    const pathFfmpeg = createExecutableFile(path.join(pathBinDir, "ffmpeg"));

    const resolved = resolveVideoCliBinaryFromPath("ffmpeg", {
      envPath: pathBinDir,
      bundledResourceRoots: [path.join(tempDir, "resources")],
      platform: "darwin",
      arch: "arm64",
    });

    expect(resolved.commandPath).toBe(pathFfmpeg);
    expect(resolved.source).toBe("path-search");
  });

  it("throws a diagnostic error when no executable is found", () => {
    expect(() =>
      resolveVideoCliBinaryFromPath("ffprobe", {
        envPath: VIDEO_CLI_FALLBACK_DIRS.join(":"),
        bundledResourceRoots: [],
        isExecutable: () => false,
      }),
    ).toThrowError(/ffprobe 実行ファイルが見つかりません/);
  });
});
