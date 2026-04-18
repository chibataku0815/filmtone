import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createWebGPUOffscreenRenderSession: vi.fn(),
  createWebGLOffscreenRenderSession: vi.fn(),
}));

vi.mock("./webgpu-offscreen-render-session", () => ({
  createWebGPUOffscreenRenderSession: mocks.createWebGPUOffscreenRenderSession,
}));

vi.mock("./webgl-offscreen-render-session", () => ({
  createWebGLOffscreenRenderSession: mocks.createWebGLOffscreenRenderSession,
}));

describe("createOffscreenRenderSession", () => {
  beforeEach(() => {
    mocks.createWebGPUOffscreenRenderSession.mockReset();
    mocks.createWebGLOffscreenRenderSession.mockReset();
  });

  it("uses WebGPU by default", async () => {
    const webgpuSession = { backendKind: "webgpu" };
    mocks.createWebGPUOffscreenRenderSession.mockResolvedValue(webgpuSession);

    const { createOffscreenRenderSession } = await import(
      "./create-offscreen-render-session"
    );
    const session = await createOffscreenRenderSession({
      width: 640,
      height: 360,
    });

    expect(mocks.createWebGPUOffscreenRenderSession).toHaveBeenCalledWith({
      width: 640,
      height: 360,
      powerPreference: undefined,
    });
    expect(mocks.createWebGLOffscreenRenderSession).not.toHaveBeenCalled();
    expect(session).toBe(webgpuSession);
  });

  it("surfaces WebGPU init failures instead of falling back", async () => {
    const initError = new Error("device lost");
    mocks.createWebGPUOffscreenRenderSession.mockRejectedValue(initError);

    const { createOffscreenRenderSession } = await import(
      "./create-offscreen-render-session"
    );
    await expect(
      createOffscreenRenderSession({
        width: 640,
        height: 360,
        prefer: "webgpu",
      }),
    ).rejects.toThrow("device lost");
    expect(mocks.createWebGLOffscreenRenderSession).not.toHaveBeenCalled();
  });

  it("uses WebGL directly when requested", async () => {
    const webglSession = { backendKind: "webgl" };
    mocks.createWebGLOffscreenRenderSession.mockResolvedValue(webglSession);

    const { createOffscreenRenderSession } = await import(
      "./create-offscreen-render-session"
    );
    const session = await createOffscreenRenderSession({
      width: 800,
      height: 600,
      prefer: "webgl",
      powerPreference: "high-performance",
    });

    expect(mocks.createWebGLOffscreenRenderSession).toHaveBeenCalledWith({
      width: 800,
      height: 600,
      powerPreference: "high-performance",
    });
    expect(session).toBe(webglSession);
  });
});
