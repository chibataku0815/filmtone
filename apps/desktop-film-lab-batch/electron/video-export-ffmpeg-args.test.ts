import { describe, expect, it } from "vitest";

import {
  buildCameraOpticsMetadataArgs,
  buildFfmpegMezzanineVideoFilter,
  buildFfmpegRawvideoExportArgs,
  buildHdrToSdrFilterChain,
  normalizeCameraOptics,
} from "./video-export-ffmpeg-args";

describe("video-export-ffmpeg-args", () => {
  it("keeps the rawvideo export args unchanged when camera optics are absent", () => {
    const args = buildFfmpegRawvideoExportArgs({
      width: 1280,
      height: 720,
      fps: 30,
      hasAudio: true,
      inputVideoPath: "/tmp/input.mov",
      outputVideoPath: "/tmp/output.mp4",
      dropFirstFrame: false,
      platform: "linux",
    });

    expect(args).toEqual([
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-f",
      "rawvideo",
      "-pix_fmt",
      "rgba",
      "-s",
      "1280x720",
      "-r",
      "30",
      "-i",
      "pipe:0",
      "-i",
      "/tmp/input.mov",
      "-map",
      "0:v:0",
      "-map",
      "1:a:0",
      "-shortest",
      "-vf",
      "vflip,scale=in_range=full:out_range=limited",
      "-color_range",
      "tv",
      "-colorspace",
      "bt709",
      "-color_trc",
      "bt709",
      "-color_primaries",
      "bt709",
      "-c:v",
      "libx264",
      "-preset",
      "veryfast",
      "-crf",
      "21",
      "-c:a",
      "copy",
      "/tmp/output.mp4",
    ]);
    expect(args).not.toContain("-metadata");
    expect(args).not.toContain("-movflags");
  });

  it("adds whitelisted camera optics metadata before MP4 output path", () => {
    const args = buildFfmpegRawvideoExportArgs({
      width: 1920,
      height: 1080,
      fps: 30,
      hasAudio: false,
      inputVideoPath: "/tmp/input.mov",
      outputVideoPath: "/tmp/output.mp4",
      dropFirstFrame: true,
      platform: "darwin",
      cameraOptics: {
        source: "manual",
        fovXDeg: 62.8,
        focalLength35mm: 28,
        lensModel: "Wide Camera",
        cameraMake: "Filmtone",
        cameraModel: "RoundTrip",
      },
    });

    const outputIndex = args.length - 1;
    const movflagsIndex = args.indexOf("-movflags");

    expect(args[outputIndex]).toBe("/tmp/output.mp4");
    expect(movflagsIndex).toBeGreaterThan(-1);
    expect(movflagsIndex).toBeLessThan(outputIndex);
    expect(args.slice(movflagsIndex, outputIndex)).toEqual([
      "-movflags",
      "use_metadata_tags",
      "-metadata",
      "filmtone.camera_optics.source=manual",
      "-metadata",
      "camera.make=Filmtone",
      "-metadata",
      "camera.model=RoundTrip",
      "-metadata",
      "camera.lens_model=Wide Camera",
      "-metadata",
      "camera.focal_length.35mm_equivalent=28",
      "-metadata",
      "camera.horizontal_field_of_view=62.8",
    ]);
  });

  it("also embeds camera optics metadata for MOV outputs", () => {
    expect(
      buildCameraOpticsMetadataArgs({
        outputVideoPath: "/tmp/output.mov",
        cameraOptics: {
          source: "metadata",
          fovXDeg: 60,
          cameraMake: "Apple",
        },
      }),
    ).toEqual([
      "-movflags",
      "use_metadata_tags",
      "-metadata",
      "filmtone.camera_optics.source=metadata",
      "-metadata",
      "camera.make=Apple",
      "-metadata",
      "camera.horizontal_field_of_view=60",
    ]);
  });

  it("skips QuickTime metadata tags for unsupported containers", () => {
    expect(
      buildCameraOpticsMetadataArgs({
        outputVideoPath: "/tmp/output.mkv",
        cameraOptics: {
          source: "metadata",
          fovXDeg: 60,
          cameraMake: "Filmtone",
        },
      }),
    ).toEqual([]);
  });

  it("normalizes IPC camera optics payloads to whitelisted finite fields", () => {
    expect(
      normalizeCameraOptics({
        source: "manual",
        fxPx: 1234,
        fyPx: Number.NaN,
        cameraMake: "  Filmtone  ",
        cameraModel: "",
        inputLut: "not camera optics",
      }),
    ).toEqual({
      source: "manual",
      fxPx: 1234,
      cameraMake: "Filmtone",
    });
  });

  it("builds the PQ zscale + tonemap candidate without touching export wiring", () => {
    expect(
      buildHdrToSdrFilterChain({
        kind: "zscale-tonemap",
        source: "hdr-pq",
        chainId: "pq-zscale-hable-npl100",
        enabledByEnv: true,
        ffmpegPath: "/tmp/ffmpeg",
        transferIn: "smpte2084",
        tonemap: "hable",
        nominalPeakNits: 100,
        desat: 0,
        output: "bt709-sdr",
      }),
    ).toBe(
      "zscale=tin=smpte2084:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=100,format=gbrpf32le,zscale=p=709,tonemap=tonemap=hable:desat=0,zscale=t=709:m=709:r=tv,format=yuv420p",
    );
  });

  it("builds the HLG zscale + mobius candidate", () => {
    expect(
      buildHdrToSdrFilterChain({
        kind: "zscale-tonemap",
        source: "hdr-hlg",
        chainId: "hlg-zscale-mobius-npl100",
        enabledByEnv: true,
        ffmpegPath: "/tmp/ffmpeg",
        transferIn: "arib-std-b67",
        tonemap: "mobius",
        nominalPeakNits: 100,
        desat: 0,
        output: "bt709-sdr",
      }),
    ).toBe(
      "zscale=tin=arib-std-b67:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=100,format=gbrpf32le,zscale=p=709,tonemap=tonemap=mobius:desat=0,zscale=t=709:m=709:r=tv,format=yuv420p",
    );
  });

  it("builds the libplacebo BT.2390 candidate", () => {
    expect(
      buildHdrToSdrFilterChain({
        kind: "libplacebo",
        source: "hdr-pq",
        chainId: "pq-libplacebo-bt2390",
        enabledByEnv: true,
        ffmpegPath: "/tmp/ffmpeg",
        tonemapping: "bt.2390",
        gamutMode: "perceptual",
        output: "bt709-sdr",
      }),
    ).toBe(
      "libplacebo=colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv:tonemapping=bt.2390:gamut_mode=perceptual,format=yuv420p",
    );
  });

  it("places scale before final yuv420p conversion for HDR mezzanine filters", () => {
    expect(
      buildFfmpegMezzanineVideoFilter({
        outW: 320,
        hdrFilterSelection: {
          kind: "zscale-tonemap",
          source: "hdr-pq",
          chainId: "pq-zscale-hable-npl100",
          enabledByEnv: true,
          ffmpegPath: "/tmp/ffmpeg",
          transferIn: "smpte2084",
          tonemap: "hable",
          nominalPeakNits: 100,
          desat: 0,
          output: "bt709-sdr",
        },
      }),
    ).toBe(
      "zscale=tin=smpte2084:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=100,format=gbrpf32le,zscale=p=709,tonemap=tonemap=hable:desat=0,zscale=t=709:m=709:r=tv,scale=320:-2,format=yuv420p",
    );
  });

  it("returns null when no HDR filter was selected", () => {
    expect(buildHdrToSdrFilterChain(null)).toBeNull();
    expect(buildHdrToSdrFilterChain(undefined)).toBeNull();
  });
});
