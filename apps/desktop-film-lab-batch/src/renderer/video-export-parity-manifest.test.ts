import { describe, expect, it } from "vitest";
import {
  buildVideoExportParityManifest,
  checksumBytes,
  diffRgba8,
} from "./video-export-parity-manifest";

describe("video-export-parity-manifest", () => {
  it("computes stable checksums", () => {
    expect(checksumBytes(new Uint8Array([1, 2, 3, 4]))).toBe(
      "fnv1a32:5734a87d",
    );
  });

  it("computes rgba diff metrics without alpha noise", () => {
    const a = new Uint8Array([10, 10, 10, 255, 20, 20, 20, 255]);
    const b = new Uint8Array([13, 10, 7, 0, 20, 22, 20, 0]);
    const diff = diffRgba8(a, b);

    expect(diff.meanAbs).toBeCloseTo(8 / 6, 6);
    expect(diff.p95Abs).toBe(3);
    expect(diff.changedRatio).toBe(1 / 2);
  });

  it("builds the diagnostic manifest shape", () => {
    const manifest = buildVideoExportParityManifest({
      sourcePath: "/tmp/in.mp4",
      outputPath: "/tmp/out.mp4",
      decodeMode: "webcodecs",
      backendKind: "webgpu",
      createdAtIso: "2026-04-25T00:00:00.000Z",
      frames: [
        {
          label: "pre-ffmpeg",
          format: "rgba8",
          width: 1920,
          height: 1080,
          timeSec: 1,
          checksum: "fnv1a32:00000000",
        },
      ],
    });

    expect(manifest).toMatchObject({
      schema: "filmtone-video-export-parity-manifest",
      version: 1,
      sourcePath: "/tmp/in.mp4",
      outputPath: "/tmp/out.mp4",
      decodeMode: "webcodecs",
      backendKind: "webgpu",
      frames: [{ label: "pre-ffmpeg" }],
    });
  });
});
