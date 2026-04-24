/**
 * @fileoverview ffprobe camera optics derivation tests.
 */
import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import { describe, expect, it } from "vitest";

import { deriveCameraOpticsFromFfprobeMeta } from "./video-export-camera-optics";

const execFileAsync = promisify(execFile);

async function commandPath(command: "ffmpeg" | "ffprobe"): Promise<string | null> {
  try {
    const result = await execFileAsync("sh", ["-lc", `command -v ${command}`]);
    return String(result.stdout).trim() || null;
  } catch {
    return null;
  }
}

describe("video-export-camera-optics", () => {
  it("builds assumed centered intrinsics from 70 degree diagonal FOV", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
    });

    expect(optics.source).toBe("assumed");
    expect(optics.cxPx).toBe(960);
    expect(optics.cyPx).toBe(540);
    expect(optics.fxPx).toBeCloseTo(optics.fyPx ?? 0, 5);
    expect(optics.fovXDeg).toBeCloseTo(62.8, 1);
    expect(optics.fovYDeg).toBeCloseTo(37.9, 1);
  });

  it("uses stream focal metadata before format metadata", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        tags: {
          "com.apple.quicktime.camera.focal_length.35mm_equivalent": "28 mm",
          "com.apple.quicktime.camera.lens_model": "Wide Camera",
        },
      },
      format: {
        tags: {
          "com.apple.quicktime.camera.focal_length.35mm_equivalent": "50 mm",
          "com.apple.quicktime.camera.make": "Apple",
          "com.apple.quicktime.camera.model": "iPhone",
        },
      },
    });

    expect(optics.source).toBe("metadata");
    expect(optics.focalLength35mm).toBe(28);
    expect(optics.lensModel).toBe("Wide Camera");
    expect(optics.cameraMake).toBe("Apple");
    expect(optics.cameraModel).toBe("iPhone");
  });

  it("falls back to assumed optics when focal metadata is invalid", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        tags: {
          "camera.focal_length.35mm_equivalent": "unknown",
        },
      },
    });

    expect(optics.source).toBe("assumed");
    expect(optics.focalLength35mm).toBeUndefined();
  });

  it("uses display-matrix rotation for display-space intrinsics", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        side_data_list: [
          {
            side_data_type: "Display Matrix",
            rotation: 90,
          },
        ],
      },
    });

    expect(optics.source).toBe("assumed");
    expect(optics.cxPx).toBe(540);
    expect(optics.cyPx).toBe(960);
    expect(optics.fovXDeg).toBeCloseTo(37.9, 1);
    expect(optics.fovYDeg).toBeCloseTo(62.8, 1);
  });

  it("uses negative display-matrix rotation for portrait display-space intrinsics", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        side_data_list: [
          {
            side_data_type: "Display Matrix",
            rotation: -90,
          },
        ],
      },
    });

    expect(optics.source).toBe("assumed");
    expect(optics.cxPx).toBe(540);
    expect(optics.cyPx).toBe(960);
    expect(optics.fovXDeg).toBeCloseTo(37.9, 1);
    expect(optics.fovYDeg).toBeCloseTo(62.8, 1);
  });

  it("derives metadata optics from a horizontal FOV tag", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        tags: {
          horizontal_field_of_view: "60",
        },
      },
    });

    expect(optics.source).toBe("metadata");
    expect(optics.fovXDeg).toBe(60);
    expect(optics.fovYDeg).toBeCloseTo(36, 0);
    expect(optics.fxPx).toBeCloseTo(1662.8, 1);
  });

  it("prefers rational side-data horizontal FOV over tag fallback", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        side_data_list: [
          {
            side_data_type: "Stereo 3D",
            horizontal_field_of_view: "62800/1000",
          },
        ],
        tags: {
          horizontal_field_of_view: "70",
        },
      },
    });

    expect(optics.source).toBe("metadata");
    expect(optics.fovXDeg).toBeCloseTo(62.8, 5);
    expect(optics.fxPx).toBeCloseTo(1572.7, 1);
  });

  it("accepts thousandths-degree side-data HFOV values", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        side_data_list: [
          {
            side_data_type: "Stereo 3D",
            hfov: 62800,
          },
        ],
      },
    });

    expect(optics.source).toBe("metadata");
    expect(optics.fovXDeg).toBeCloseTo(62.8, 5);
  });

  it("preserves Filmtone source semantics from the camera tags embedded into exported MP4 files", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      format: {
        tags: {
          "filmtone.camera_optics.source": "manual",
          "camera.make": "Filmtone",
          "camera.model": "RoundTrip",
          "camera.lens_model": "Wide Camera",
          "camera.focal_length.35mm_equivalent": "28",
          "camera.horizontal_field_of_view": "62.8",
        },
      },
    });

    expect(optics.source).toBe("manual");
    expect(optics.cameraMake).toBe("Filmtone");
    expect(optics.cameraModel).toBe("RoundTrip");
    expect(optics.lensModel).toBe("Wide Camera");
    expect(optics.focalLength35mm).toBe(28);
    expect(optics.fovXDeg).toBe(62.8);
  });

  it("keeps assumed Filmtone optics as assumed after a metadata round-trip", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      format: {
        tags: {
          "filmtone.camera_optics.source": "assumed",
          "camera.horizontal_field_of_view": "62.8",
        },
      },
    });

    expect(optics.source).toBe("assumed");
    expect(optics.fovXDeg).toBe(62.8);
  });

  it("re-probes ffmpeg embedded MP4 camera metadata when ffmpeg and ffprobe are available", async () => {
    const ffmpeg = await commandPath("ffmpeg");
    const ffprobe = await commandPath("ffprobe");
    if (!ffmpeg || !ffprobe) {
      return;
    }

    const dir = await fs.mkdtemp(path.join(os.tmpdir(), "filmtone-camera-optics-"));
    const outputPath = path.join(dir, "camera-tags.mp4");
    try {
      await execFileAsync(ffmpeg, [
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "lavfi",
        "-i",
        "testsrc2=size=160x90:rate=1",
        "-frames:v",
        "1",
        "-c:v",
        "mpeg4",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "use_metadata_tags",
        "-metadata",
        "camera.make=Filmtone",
        "-metadata",
        "camera.model=RoundTrip",
        "-metadata",
        "camera.lens_model=Wide Camera",
        "-metadata",
        "camera.horizontal_field_of_view=62.8",
        outputPath,
      ]);

      const probe = await execFileAsync(ffprobe, [
        "-v",
        "error",
        "-show_streams",
        "-show_format",
        "-of",
        "json",
        outputPath,
      ]);
      const parsed = JSON.parse(String(probe.stdout)) as {
        streams?: Array<Record<string, unknown>>;
        format?: Record<string, unknown>;
      };
      const videoStream = parsed.streams?.find(
        (stream) => stream.codec_type === "video",
      );

      const optics = deriveCameraOpticsFromFfprobeMeta({
        rawWidth: 160,
        rawHeight: 90,
        stream: videoStream,
        format: parsed.format,
      });

      expect(optics.source).toBe("metadata");
      expect(optics.cameraMake).toBe("Filmtone");
      expect(optics.cameraModel).toBe("RoundTrip");
      expect(optics.lensModel).toBe("Wide Camera");
      expect(optics.fovXDeg).toBe(62.8);
    } finally {
      await fs.rm(dir, { recursive: true, force: true });
    }
  });
});
