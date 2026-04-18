import type {
  CreateOffscreenRenderSessionOptions,
  OffscreenRenderSession,
} from "./offscreen-render-session";
import { createWebGLOffscreenRenderSession } from "./webgl-offscreen-render-session";
import { createWebGPUOffscreenRenderSession } from "./webgpu-offscreen-render-session";

export async function createOffscreenRenderSession(
  options: CreateOffscreenRenderSessionOptions,
): Promise<OffscreenRenderSession> {
  const { prefer = "webgpu", ...sessionOptions } = options;

  if (prefer === "webgl") {
    return createWebGLOffscreenRenderSession(sessionOptions);
  }

  return createWebGPUOffscreenRenderSession(sessionOptions);
}
