import { beforeEach, describe, expect, it, vi } from "vitest";
import { PRESETS } from "film-lab-core";
import type { BatchGradeState } from "../batch-pipeline";

const mocks = vi.hoisted(() => {
  const gl = {
    kind: "webgl2",
    RGBA: 0x1908,
    UNSIGNED_BYTE: 0x1401,
    readPixels: vi.fn(),
  };
  const renderer = {
    domElement: {
      width: 320,
      height: 180,
      toDataURL: vi.fn(),
    },
    capabilities: {
      maxTextureSize: 8192,
    },
    setPixelRatio: vi.fn(),
    setSize: vi.fn(),
    outputColorSpace: null as unknown,
    getContext: vi.fn(() => gl),
    dispose: vi.fn(),
    forceContextLoss: vi.fn(),
  };
  const scene = {
    background: null as unknown,
    add: vi.fn(),
  };
  const camera = {
    position: { z: 0 },
  };
  const viewport = {
    backendKind: "webgl" as const,
    mesh: { id: "mesh" },
    setResolution: vi.fn(),
    setTexture: vi.fn(),
    setImageResolution: vi.fn(),
    setParams: vi.fn(),
    setLUT1: vi.fn(),
    setLUT1Intensity: vi.fn(),
    clearLUT1: vi.fn(),
    setLUT2: vi.fn(),
    setLUT2Intensity: vi.fn(),
    clearLUT2: vi.fn(),
    setTime: vi.fn(),
    resetMotionBlurHistory: vi.fn(),
    render: vi.fn(),
    dispose: vi.fn(),
  };

  return {
    renderer,
    gl,
    scene,
    camera,
    viewport,
    WebGLRenderer: vi.fn(function WebGLRenderer() {
      return renderer;
    }),
    Scene: vi.fn(function Scene() {
      return scene;
    }),
    OrthographicCamera: vi.fn(function OrthographicCamera() {
      return camera;
    }),
    Color: vi.fn(function Color(value: number) {
      return { value };
    }),
    viewportCreate: vi.fn(async () => viewport),
  };
});

vi.mock("three", () => ({
  WebGLRenderer: mocks.WebGLRenderer,
  Scene: mocks.Scene,
  OrthographicCamera: mocks.OrthographicCamera,
  Color: mocks.Color,
  SRGBColorSpace: "srgb",
}));

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

describe("createWebGLOffscreenRenderSession", () => {
  beforeEach(() => {
    Object.values(mocks.renderer).forEach((value) => {
      if (typeof value === "function" && "mockClear" in value) {
        (value as ReturnType<typeof vi.fn>).mockClear();
      }
    });
    Object.values(mocks.scene).forEach((value) => {
      if (typeof value === "function" && "mockClear" in value) {
        (value as ReturnType<typeof vi.fn>).mockClear();
      }
    });
    Object.values(mocks.viewport).forEach((value) => {
      if (typeof value === "function" && "mockClear" in value) {
        (value as ReturnType<typeof vi.fn>).mockClear();
      }
    });
    mocks.WebGLRenderer.mockClear();
    mocks.Scene.mockClear();
    mocks.OrthographicCamera.mockClear();
    mocks.Color.mockClear();
    mocks.viewportCreate.mockClear();
    mocks.gl.readPixels.mockClear();
    mocks.renderer.domElement.toDataURL.mockClear();
    mocks.renderer.domElement.width = 320;
    mocks.renderer.domElement.height = 180;
    mocks.renderer.outputColorSpace = null;
  });

  it("wraps the existing Three.js shell behind the session contract", async () => {
    const { createWebGLOffscreenRenderSession } = await import(
      "./webgl-offscreen-render-session"
    );
    const session = await createWebGLOffscreenRenderSession({
      width: 640,
      height: 360,
      powerPreference: "high-performance",
    });

    expect(mocks.WebGLRenderer).toHaveBeenCalledWith({
      antialias: false,
      alpha: false,
      preserveDrawingBuffer: true,
      powerPreference: "high-performance",
    });
    expect(mocks.renderer.setPixelRatio).toHaveBeenCalledWith(1);
    expect(mocks.renderer.setSize).toHaveBeenCalledWith(640, 360, false);
    expect(mocks.renderer.outputColorSpace).toBe("srgb");
    expect(mocks.viewportCreate).toHaveBeenCalledWith(mocks.renderer.domElement, {
      prefer: "webgl",
      width: 640,
      height: 360,
    });
    expect(mocks.camera.position.z).toBe(1);
    expect(mocks.scene.add).toHaveBeenCalledWith(mocks.viewport.mesh);
    expect(session.backendKind).toBe("webgl");
    expect(session.canvas).toBe(mocks.renderer.domElement);
    expect(session.maxTextureSize).toBe(8192);

    const texture = { id: "texture" } as never;
    session.setRenderSize(1920, 1080);
    session.setSource({
      texture,
      imageWidth: 3840,
      imageHeight: 2160,
    });
    session.setGrade(makeGrade());
    session.setTime(1.25);
    session.resetMotionBlurHistory();
    session.render();
    session.readbackRgba8();
    session.toDataURL("image/png", 0.92);

    expect(mocks.viewport.setResolution).toHaveBeenCalledWith(1920, 1080);
    expect(mocks.viewport.setTexture).toHaveBeenCalledWith(texture);
    expect(mocks.viewport.setImageResolution).toHaveBeenCalledWith(
      3840,
      2160,
    );
    expect(mocks.viewport.setParams).toHaveBeenCalledTimes(1);
    expect(mocks.viewport.setLUT1).toHaveBeenCalledTimes(1);
    expect(mocks.viewport.setLUT2).toHaveBeenCalledTimes(1);
    expect(mocks.viewport.setTime).toHaveBeenCalledWith(1.25);
    expect(mocks.viewport.resetMotionBlurHistory).toHaveBeenCalledTimes(1);
    expect(mocks.viewport.render).toHaveBeenCalledWith(
      mocks.renderer,
      mocks.scene,
      mocks.camera,
    );
    expect(mocks.gl.readPixels).toHaveBeenCalledWith(
      0,
      0,
      320,
      180,
      0x1908,
      0x1401,
      expect.any(Uint8Array),
    );
    expect(mocks.renderer.domElement.toDataURL).toHaveBeenCalledWith(
      "image/png",
      0.92,
    );
    expect(session.getWebGLContext()).toMatchObject({ kind: "webgl2" });

    session.dispose();

    expect(mocks.viewport.dispose).toHaveBeenCalledTimes(1);
    expect(mocks.renderer.dispose).toHaveBeenCalledTimes(1);
    expect(mocks.renderer.forceContextLoss).toHaveBeenCalledTimes(1);
    expect(mocks.renderer.domElement.width).toBe(1);
    expect(mocks.renderer.domElement.height).toBe(1);
  });
});
