import * as THREE from "three";
import { Viewport } from "film-lab-renderer";
import type { BatchGradeState } from "../batch-pipeline";
import { applyBatchGradeToViewport } from "./apply-batch-grade-to-viewport";
import type {
  OffscreenRenderSource,
  WebGLOffscreenRenderSession,
} from "./offscreen-render-session";

type CreateWebGLOffscreenRenderSessionOptions = {
  width: number;
  height: number;
  powerPreference?: WebGLPowerPreference;
};

class WebGLOffscreenRenderSessionImpl implements WebGLOffscreenRenderSession {
  readonly backendKind = "webgl" as const;
  readonly canvas: HTMLCanvasElement;
  readonly maxTextureSize: number;

  constructor(
    readonly renderer: THREE.WebGLRenderer,
    private readonly scene: THREE.Scene,
    private readonly camera: THREE.OrthographicCamera,
    private readonly viewport: Viewport,
  ) {
    this.canvas = renderer.domElement;
    this.maxTextureSize = renderer.capabilities.maxTextureSize;
  }

  setRenderSize(width: number, height: number): void {
    this.renderer.setSize(width, height, false);
    this.viewport.setResolution(width, height);
  }

  setSource(source: OffscreenRenderSource): void {
    this.viewport.setTexture(source.texture);
    this.viewport.setImageResolution(source.imageWidth, source.imageHeight);
  }

  setGrade(grade: BatchGradeState): void {
    applyBatchGradeToViewport(this.viewport, grade);
  }

  setTime(timeSeconds: number): void {
    this.viewport.setTime(timeSeconds);
  }

  resetMotionBlurHistory(): void {
    this.viewport.resetMotionBlurHistory();
  }

  render(): void {
    this.viewport.render(this.renderer, this.scene, this.camera);
  }

  readbackRgba8(): Uint8Array {
    const gl = this.getWebGLContext();
    const out = new Uint8Array(this.canvas.width * this.canvas.height * 4);
    gl.readPixels(
      0,
      0,
      this.canvas.width,
      this.canvas.height,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      out,
    );
    return out;
  }

  toDataURL(mimeType: string, quality?: number): string {
    return this.canvas.toDataURL(mimeType, quality as never);
  }

  getWebGLContext(): WebGL2RenderingContext {
    return this.renderer.getContext() as WebGL2RenderingContext;
  }

  dispose(): void {
    this.viewport.dispose();
    disposeWebGLRenderer(this.renderer);
  }
}

/**
 * @description Export 用の一時 renderer は `dispose()` だけでなく context も明示的に落とします。
 * Chromium/Electron では WebGL context の解放が遅れることがあり、preview 側まで黒化する温床になります。
 */
export function disposeWebGLRenderer(renderer: THREE.WebGLRenderer | null): void {
  if (!renderer) {
    return;
  }
  try {
    renderer.dispose();
  } catch {
    /* ignore */
  }
  try {
    renderer.forceContextLoss();
  } catch {
    /* ignore */
  }
  try {
    const canvas = renderer.domElement;
    canvas.width = 1;
    canvas.height = 1;
  } catch {
    /* ignore */
  }
}

export async function createWebGLOffscreenRenderSession(
  options: CreateWebGLOffscreenRenderSessionOptions,
): Promise<WebGLOffscreenRenderSession> {
  const { width, height, powerPreference } = options;

  const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
  camera.position.z = 1;

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0a0a0a);

  const renderer = new THREE.WebGLRenderer({
    antialias: false,
    alpha: false,
    preserveDrawingBuffer: true,
    powerPreference,
  });
  renderer.setPixelRatio(1);
  renderer.setSize(width, height, false);
  renderer.outputColorSpace = THREE.SRGBColorSpace;

  let viewport: Viewport | null = null;
  try {
    viewport = await Viewport.create(renderer.domElement, {
      prefer: "webgl",
      width,
      height,
    });
    if (viewport.backendKind !== "webgl" || !viewport.mesh) {
      throw new Error(
        "createWebGLOffscreenRenderSession: webgl viewport の初期化に失敗しました",
      );
    }
    scene.add(viewport.mesh);
    return new WebGLOffscreenRenderSessionImpl(
      renderer,
      scene,
      camera,
      viewport,
    );
  } catch (error) {
    viewport?.dispose();
    disposeWebGLRenderer(renderer);
    throw error;
  }
}
