import { beforeEach, describe, expect, it, vi } from "vitest";
import { PRESETS } from "film-lab-core";
import type { BatchGradeState } from "../batch-pipeline";

const mocks = vi.hoisted(() => {
  const canvas2dContext = {
    fillStyle: "",
    fillRect: vi.fn(),
  };
  const canvas = {
    width: 320,
    height: 180,
    toDataURL: vi.fn(() => "data:image/png;base64,AAA"),
    getContext: vi.fn(() => canvas2dContext),
  };
  const viewport = {
    backendKind: "webgpu" as const,
    getCapabilities: vi.fn(() => ({
      backendKind: "webgpu" as const,
      supportsCompare: false,
      supportsHistogram: false,
      supportsBeforeAfter: false,
      supportsABCompare: false,
      supportsLiveVideoTexture: true,
      maxTextureDimension2D: 16384,
    })),
    setResolution: vi.fn(),
    setMediaFromBitmap: vi.fn(),
    setTexture: vi.fn(),
    setParams: vi.fn(),
    setDepthFromBitmap: vi.fn(),
    setLUT1: vi.fn(),
    setLUT1Intensity: vi.fn(),
    clearLUT1: vi.fn(),
    setLUT2: vi.fn(),
    setLUT2Intensity: vi.fn(),
    clearLUT2: vi.fn(),
    setTime: vi.fn(),
    resetMotionBlurHistory: vi.fn(),
    render: vi.fn(),
    setReadbackEnabled: vi.fn(),
    readbackRgba8: vi.fn(async () => new Uint8Array([1, 2, 3, 4])),
    dispose: vi.fn(),
  };

  return {
    canvas,
    canvas2dContext,
    viewport,
    viewportCreate: vi.fn(async () => viewport),
    createElement: vi.fn(),
    createImageBitmap: vi.fn(async () => ({
      width: 3840,
      height: 2160,
      close: vi.fn(),
    })),
    fetch: vi.fn(async () => ({
      ok: true,
      status: 200,
      blob: async () => new Blob(["depth"], { type: "image/png" }),
    })),
  };
});

vi.mock("film-lab-renderer", () => ({
  Viewport: {
    create: mocks.viewportCreate,
  },
}));

function makeGrade(
  overrides: Partial<BatchGradeState> = {},
): BatchGradeState {
  return {
    params: {
      ...Object.values(PRESETS)[0]!,
      halationHue: 48,
    },
    depthTrack: null,
    lut1Intensity: 0.8,
    lut1Data: new Float32Array([0, 1]),
    lut1Size: 2,
    lutIntensity: 0.6,
    lutData: new Float32Array([1, 0]),
    lutSize: 2,
    ...overrides,
  };
}

describe("createWebGPUOffscreenRenderSession", () => {
  beforeEach(() => {
    Object.values(mocks.viewport).forEach((value) => {
      if (typeof value === "function" && "mockClear" in value) {
        (value as ReturnType<typeof vi.fn>).mockClear();
      }
    });
    mocks.viewportCreate.mockClear();
    mocks.createElement.mockClear();
    mocks.createImageBitmap.mockClear();
    mocks.fetch.mockClear();
    mocks.canvas.toDataURL.mockClear();
    mocks.canvas.getContext.mockClear();
    mocks.canvas2dContext.fillRect.mockClear();
    mocks.canvas.width = 320;
    mocks.canvas.height = 180;
    mocks.createElement.mockImplementation(() => mocks.canvas);
    vi.stubGlobal("document", {
      createElement: mocks.createElement,
    });
    vi.stubGlobal("createImageBitmap", mocks.createImageBitmap);
    vi.stubGlobal("fetch", mocks.fetch);
  });

  it("wraps a WebGPU viewport behind the session contract", async () => {
    const { createWebGPUOffscreenRenderSession } = await import(
      "./webgpu-offscreen-render-session"
    );
    const session = await createWebGPUOffscreenRenderSession({
      width: 640,
      height: 360,
    });

    expect(mocks.createElement).toHaveBeenCalledWith("canvas");
    expect(mocks.viewportCreate).toHaveBeenCalledWith(mocks.canvas, {
      prefer: "webgpu",
      width: 640,
      height: 360,
    });
    expect(mocks.viewport.setReadbackEnabled).toHaveBeenCalledWith(true);
    expect(session.backendKind).toBe("webgpu");
    expect(session.maxTextureSize).toBe(16384);

    const imageSource = { tag: "image-source" };
    const texture = {
      source: {
        data: imageSource,
      },
    } as never;
    await session.setSource({
      texture,
      imageWidth: 3840,
      imageHeight: 2160,
    });
    session.setRenderSize(1920, 1080);
    session.setGrade(makeGrade());
    session.setTime(1.25);
    session.resetMotionBlurHistory();
    session.render();
    const rgba = await session.readbackRgba8();
    session.toDataURL("image/png", 0.92);
    session.dispose();

    expect(mocks.createImageBitmap).toHaveBeenCalledWith(
      imageSource,
    );
    const uploadedBitmap =
      mocks.viewport.setMediaFromBitmap.mock.calls[0]?.[0];
    expect(uploadedBitmap).toBeTruthy();
    expect(mocks.viewport.setResolution).toHaveBeenCalledWith(1920, 1080);
    expect(mocks.viewport.setParams).toHaveBeenCalledTimes(1);
    expect(mocks.viewport.setLUT1).toHaveBeenCalledTimes(1);
    expect(mocks.viewport.setLUT2).toHaveBeenCalledTimes(1);
    expect(mocks.viewport.setTime).toHaveBeenCalledWith(1.25);
    expect(mocks.viewport.resetMotionBlurHistory).toHaveBeenCalledTimes(1);
    expect(mocks.viewport.render).toHaveBeenCalledWith();
    expect(mocks.viewport.readbackRgba8).toHaveBeenCalledTimes(1);
    expect(rgba).toEqual(new Uint8Array([1, 2, 3, 4]));
    expect(mocks.canvas.toDataURL).toHaveBeenCalledWith("image/png", 0.92);
    expect(mocks.viewport.dispose).toHaveBeenCalledTimes(1);
    expect(mocks.canvas.width).toBe(1);
    expect(mocks.canvas.height).toBe(1);
    expect(uploadedBitmap.close).toHaveBeenCalledTimes(1);
  });

  it("routes live video textures through Viewport.setTexture without bitmap upload", async () => {
    class FakeHTMLVideoElement {}
    vi.stubGlobal("HTMLVideoElement", FakeHTMLVideoElement);

    const { createWebGPUOffscreenRenderSession } = await import(
      "./webgpu-offscreen-render-session"
    );
    const session = await createWebGPUOffscreenRenderSession({
      width: 640,
      height: 360,
    });

    const video = new FakeHTMLVideoElement();
    const texture = {
      source: {
        data: video,
      },
    } as never;
    await session.setSource({
      texture,
      imageWidth: 1920,
      imageHeight: 1080,
    });

    expect(mocks.viewport.setTexture).toHaveBeenCalledWith(texture);
    expect(mocks.createImageBitmap).not.toHaveBeenCalled();
    expect(mocks.viewport.setMediaFromBitmap).not.toHaveBeenCalled();
  });

  it("decodes a depth track and uploads nearest frames as time advances", async () => {
    const createdBitmaps: Array<{ close: ReturnType<typeof vi.fn> }> = [];
    mocks.createImageBitmap.mockImplementation(async () => {
      const bitmap = {
        width: 512,
        height: 288,
        close: vi.fn(),
      };
      createdBitmaps.push(bitmap);
      return bitmap;
    });

    const { createWebGPUOffscreenRenderSession } = await import(
      "./webgpu-offscreen-render-session"
    );
    const session = await createWebGPUOffscreenRenderSession({
      width: 640,
      height: 360,
    });

    await session.setDepthTrack({
      source: {
        kind: "frameSequence",
        fps: 2,
        frameRelPaths: ["depth/0001.png", "depth/0002.png", "depth/0003.png"],
      },
      absolutePaths: [
        "/tmp/depth/0001.png",
        "/tmp/depth/0002.png",
        "/tmp/depth/0003.png",
      ],
      frameUrls: ["blob:depth-1", "blob:depth-2", "blob:depth-3"],
    });
    session.setTime(0.51);
    session.setTime(1.02);
    session.dispose();

    expect(mocks.fetch).toHaveBeenCalledTimes(3);
    expect(mocks.viewport.setDepthFromBitmap).toHaveBeenCalledTimes(4);
    expect(mocks.viewport.setDepthFromBitmap.mock.calls[1]?.[0]).toBe(
      createdBitmaps[1],
    );
    expect(mocks.viewport.setDepthFromBitmap.mock.calls[2]?.[0]).toBe(
      createdBitmaps[2],
    );
    expect(mocks.viewport.setDepthFromBitmap.mock.calls[3]?.[0]).toBe(
      createdBitmaps[3],
    );
    expect(createdBitmaps[0]?.close).toHaveBeenCalledTimes(1);
    expect(createdBitmaps[1]?.close).toHaveBeenCalledTimes(1);
    expect(createdBitmaps[2]?.close).toHaveBeenCalledTimes(1);
    expect(createdBitmaps[3]?.close).toHaveBeenCalledTimes(1);
  });
});
