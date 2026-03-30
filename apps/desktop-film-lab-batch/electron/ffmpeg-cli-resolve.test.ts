/**
 * @fileoverview Filmtone Desktop の `ffmpeg` / `ffprobe` 解決ルールの回帰テスト
 */
import { describe, expect, it } from "vitest";

import {
  mergeVideoCliPath,
  resolveVideoCliBinaryFromPath,
  splitPathEntries,
  VIDEO_CLI_FALLBACK_DIRS,
} from "./ffmpeg-cli-resolve";

describe("ffmpeg-cli-resolve", () => {
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

  it("prefers explicit env override when it is executable", () => {
    const resolved = resolveVideoCliBinaryFromPath("ffprobe", {
      envPath: ["/usr/bin", "/opt/homebrew/bin"].join(":"),
      envOverridePath: "/tmp/tools/custom-ffprobe",
      isExecutable: (absPath) => absPath === "/tmp/tools/custom-ffprobe",
    });

    expect(resolved.commandPath).toBe("/tmp/tools/custom-ffprobe");
    expect(resolved.source).toBe("env-override");
  });

  it("falls back to PATH search when override is absent", () => {
    const resolved = resolveVideoCliBinaryFromPath("ffmpeg", {
      envPath: ["/usr/bin", "/opt/homebrew/bin"].join(":"),
      isExecutable: (absPath) => absPath === "/opt/homebrew/bin/ffmpeg",
    });

    expect(resolved.commandPath).toBe("/opt/homebrew/bin/ffmpeg");
    expect(resolved.source).toBe("path-search");
  });

  it("throws a diagnostic error when no executable is found", () => {
    expect(() =>
      resolveVideoCliBinaryFromPath("ffprobe", {
        envPath: VIDEO_CLI_FALLBACK_DIRS.join(":"),
        isExecutable: () => false,
      }),
    ).toThrowError(/ffprobe が見つかりません/);
  });
});
