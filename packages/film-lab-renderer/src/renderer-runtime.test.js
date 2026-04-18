import { afterEach, describe, expect, test } from "bun:test";
import { Viewport } from "./Viewport";
import { GpuContext } from "./webgpu/GpuContext";

const WEBGPU_CAPABILITIES = Object.freeze({
  backendKind: "webgpu",
  supportsCompare: false,
  supportsHistogram: false,
  supportsBeforeAfter: false,
  supportsABCompare: false,
  supportsLiveVideoTexture: true,
  maxTextureDimension2D: 16384,
});

const restoreGlobals = [];

function replaceGlobal(name, value) {
  const scope = globalThis;
  const hadOwn = Object.prototype.hasOwnProperty.call(scope, name);
  const previous = scope[name];
  scope[name] = value;
  restoreGlobals.push(() => {
    if (hadOwn) scope[name] = previous;
    else delete scope[name];
  });
}

afterEach(() => {
  while (restoreGlobals.length > 0) {
    restoreGlobals.pop()();
  }
});

describe("Viewport WebGPU delegation", () => {
  test("routes HTMLVideoElement sources to the live video path", async () => {
    class FakeHTMLVideoElement {}
    replaceGlobal("HTMLVideoElement", FakeHTMLVideoElement);
    replaceGlobal("createImageBitmap", () => {
      throw new Error("createImageBitmap should not run for live video");
    });

    const video = Object.assign(new FakeHTMLVideoElement(), {
      videoWidth: 1920,
      videoHeight: 1080,
      readyState: 4,
    });
    let receivedVideo = null;
    const backend = {
      capabilities: WEBGPU_CAPABILITIES,
      setMediaFromVideoElement(value) {
        receivedVideo = value;
      },
      setMediaFromBitmap() {
        throw new Error("bitmap upload path should not run");
      },
      getSplitPosition() {
        return -1;
      },
    };

    const viewport = new Viewport(null, backend);
    await viewport.queueSetTextureWebGPU({
      source: { data: video },
    });

    expect(receivedVideo).toBe(video);
    expect(viewport.getCapabilities()).toEqual(WEBGPU_CAPABILITIES);
  });

  test("reads split position from the live WebGPU backend getter", () => {
    const backend = {
      capabilities: WEBGPU_CAPABILITIES,
      getSplitPosition() {
        return 0.375;
      },
    };

    const viewport = new Viewport(null, backend);
    expect(viewport.getSplitPosition()).toBe(0.375);
  });
});

describe("GpuContext runtime contract", () => {
  test("publishes capabilities and replays context-loss info", async () => {
    let resolveLost = null;
    const lossPromise = new Promise((resolve) => {
      resolveLost = resolve;
    });
    const device = {
      lost: lossPromise,
      destroy() {},
    };
    const context = new GpuContext(
      { limits: { maxTextureDimension2D: 16384 } },
      device,
      {},
      { unconfigure() {} },
      false,
    );

    const events = [];
    context.onContextLost((info) => {
      events.push(info);
    });

    expect(context.capabilities).toEqual(WEBGPU_CAPABILITIES);

    resolveLost({ reason: "destroyed", message: "device lost" });
    await Promise.resolve();

    expect(context.isContextLost()).toBe(true);
    expect(context.getContextLossInfo()).toMatchObject({
      reason: "device-lost",
    });
    expect(events).toHaveLength(1);

    const replayed = [];
    context.onContextLost((info) => {
      replayed.push(info);
    });
    expect(replayed).toHaveLength(1);
    expect(replayed[0]).toEqual(context.getContextLossInfo());
  });
});

describe("WebGPUBackend fatal loss reporting", () => {
  test("render reports fatal loss before rethrowing", async () => {
    replaceGlobal("GPUTextureUsage", {
      TEXTURE_BINDING: 1,
      COPY_DST: 2,
      RENDER_ATTACHMENT: 4,
      COPY_SRC: 8,
    });

    const { WebGPUBackend } = await import("./webgpu/WebGPUBackend");
    const error = new Error("render exploded");
    const reported = [];
    const backend = Object.create(WebGPUBackend.prototype);

    backend.ctx = {
      isContextLost: () => false,
      reportFatalLoss: (reason, reportedError) => {
        reported.push({ reason, error: reportedError });
      },
    };
    backend.destroyed = false;
    backend.renderFrame = () => {
      throw error;
    };

    expect(() => backend.render()).toThrow("render exploded");
    expect(reported).toEqual([{ reason: "render-failed", error }]);
  });

  test("prewarm reports fatal loss before rethrowing", async () => {
    replaceGlobal("GPUTextureUsage", {
      TEXTURE_BINDING: 1,
      COPY_DST: 2,
      RENDER_ATTACHMENT: 4,
      COPY_SRC: 8,
    });

    const { WebGPUBackend } = await import("./webgpu/WebGPUBackend");
    const error = new Error("prewarm exploded");
    const reported = [];
    const backend = Object.create(WebGPUBackend.prototype);

    backend.ctx = {
      isContextLost: () => false,
      reportFatalLoss: (reason, reportedError) => {
        reported.push({ reason, error: reportedError });
      },
    };
    backend.destroyed = false;
    backend.renderFrame = () => {
      throw error;
    };

    expect(() => backend.prewarm()).toThrow("prewarm exploded");
    expect(reported).toEqual([{ reason: "prewarm-failed", error }]);
  });
});
