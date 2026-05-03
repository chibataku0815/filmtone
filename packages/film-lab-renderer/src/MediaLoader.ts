/**
 * MediaLoader — File-to-Texture converter for Film Lab
 *
 * iPhone Safari 向け: HEIC の早期拒否、GPU maxTextureSize 超過時の Canvas 縮小、
 * 呼び出し側で表示できるよう MediaLoadError を投げる。
 *
 * デスクトップ Safari: 埋め込み ICC（ディスプレイプロファイル付きスクリーンショット等）で
 * `new Image()` + blob URL のデコードが失敗し、Chrome では通ることがある。
 * その場合は `createImageBitmap` → Canvas 経由のフォールバックを試す。
 *
 * デバッグ: URL に `?filmLabDebugMedia=1`（例: /film-lab?filmLabDebugMedia=1）を付けると
 * 各デコード段階を console に出す。
 */

import * as THREE from "three";

export interface LoadResult {
  texture: THREE.Texture;
  width: number;
  height: number;
  type: "image" | "video";
}

/** ブラウザがデコードできない形式・サイズなど（UI メッセージ用 code 付き） */
export class MediaLoadError extends Error {
  constructor(
    message: string,
    public readonly code:
      | "HEIC_UNSUPPORTED"
      | "IMAGE_DECODE_FAILED"
      | "VIDEO_DECODE_FAILED"
      | "UNKNOWN",
  ) {
    super(message);
    this.name = "MediaLoadError";
  }
}

export interface LoadFileOptions {
  /** WebGL の gl.MAX_TEXTURE_SIZE。未指定時は縮小しない */
  maxTextureSize?: number;
}

const HEIC_MIME = /heic|heif/i;

/**
 * MIME が空・不正でも、拡張子が動画らしいときは `<video>` 経路へ回す（Finder ドロップの .mov 等）。
 * ブラウザが実際にデコードできない容器は loadVideo 内でエラーになる。
 */
export const LIKELY_VIDEO_EXTENSION = /\.(mp4|m4v|mov|webm|ogv|mkv)$/i;

/**
 * `?filmLabDebugMedia=1` のとき true。クライアント専用。
 */
export function isFilmLabMediaDebugEnabled(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return new URLSearchParams(window.location.search).get("filmLabDebugMedia") === "1";
  } catch {
    return false;
  }
}

/**
 * iPhone の写真（HEIC/HEIF）かどうか。MIME が空のときは拡張子で推定する。
 */
export function isLikelyHeicFile(file: File): boolean {
  if (file.type && HEIC_MIME.test(file.type)) return true;
  return /\.(heic|heif)$/i.test(file.name);
}

/**
 * 画像ソースの幅・高さを取得する（Image は natural*、Canvas は width/height）。
 */
function getDrawableSize(source: HTMLImageElement | HTMLCanvasElement): { w: number; h: number } {
  if (source instanceof HTMLCanvasElement) {
    return { w: source.width, h: source.height };
  }
  return { w: source.naturalWidth, h: source.naturalHeight };
}

/**
 * 長辺が maxDim を超える画像を Canvas に縮小する（WebGL テクスチャ上限対策）。
 * 縮小不要なら元ソースをそのまま返す。
 */
function scaleSourceToMaxDimension(
  source: HTMLImageElement | HTMLCanvasElement,
  maxDim: number,
): HTMLImageElement | HTMLCanvasElement {
  const { w, h } = getDrawableSize(source);
  if (!w || !h) return source;

  const longEdge = Math.max(w, h);
  if (longEdge <= maxDim) return source;

  const scale = maxDim / longEdge;
  const nw = Math.max(1, Math.floor(w * scale));
  const nh = Math.max(1, Math.floor(h * scale));

  const canvas = document.createElement("canvas");
  canvas.width = nw;
  canvas.height = nh;
  const ctx = canvas.getContext("2d");
  if (!ctx) return source;

  ctx.drawImage(source, 0, 0, nw, nh);
  return canvas;
}

/**
 * THREE.Texture を組み立てる共通処理。
 */
function textureFromDrawable(
  drawable: HTMLImageElement | HTMLCanvasElement,
  maxTextureSize: number | undefined,
): LoadResult {
  const maxDim = maxTextureSize ?? Number.POSITIVE_INFINITY;
  const scaled = scaleSourceToMaxDimension(drawable, maxDim);
  const { w, h } = getDrawableSize(scaled);

  const texture = new THREE.Texture(scaled);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.needsUpdate = true;

  return {
    texture,
    width: w,
    height: h,
    type: "image",
  };
}

/**
 * Blob を createImageBitmap でデコードし、Canvas に描画してから Texture 化する。
 * ImageBitmap はすぐ close し、THREE が Canvas を参照する形に統一する。
 */
async function decodeViaCreateImageBitmap(
  blob: Blob,
  maxTextureSize: number | undefined,
  debug: boolean,
  label: string,
): Promise<LoadResult> {
  if (typeof createImageBitmap !== "function") {
    throw new Error("createImageBitmap is not available");
  }

  let bitmap: ImageBitmap | null = null;
  try {
    bitmap = await createImageBitmap(blob);
    if (debug) {
      console.info(`[FilmLab MediaLoader] createImageBitmap OK (${label})`, {
        width: bitmap.width,
        height: bitmap.height,
      });
    }

    const canvas = document.createElement("canvas");
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;
    const ctx = canvas.getContext("2d");
    if (!ctx) {
      throw new Error("Could not get 2d context for ImageBitmap transfer");
    }
    ctx.drawImage(bitmap, 0, 0);
    bitmap.close();
    bitmap = null;

    return textureFromDrawable(canvas, maxTextureSize);
  } catch (err) {
    if (bitmap) {
      try {
        bitmap.close();
      } catch {
        /* ignore */
      }
    }
    if (debug) {
      console.warn(`[FilmLab MediaLoader] createImageBitmap failed (${label})`, err);
    }
    throw err;
  }
}

/**
 * 古典的な Image + object URL 経路。
 */
function decodeViaImageElement(file: File, maxTextureSize: number | undefined): Promise<LoadResult> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    // blob: では crossOrigin を付けない（Safari で読み込み失敗の原因になりうる）

    const cleanupUrl = () => {
      try {
        URL.revokeObjectURL(url);
      } catch {
        /* ignore */
      }
    };

    img.onload = () => {
      try {
        const result = textureFromDrawable(img, maxTextureSize);
        cleanupUrl();
        resolve(result);
      } catch (err) {
        cleanupUrl();
        const message = err instanceof Error ? err.message : String(err);
        reject(
          new MediaLoadError(
            `Could not build texture from image (${message}). Try JPEG or PNG.`,
            "IMAGE_DECODE_FAILED",
          ),
        );
      }
    };

    img.onerror = () => {
      cleanupUrl();
      reject(new Error("HTMLImageElement failed to decode (onerror)"));
    };

    img.src = url;
  });
}

export class MediaLoader {
  async loadFile(file: File, options: LoadFileOptions = {}): Promise<LoadResult> {
    if (isLikelyHeicFile(file)) {
      throw new MediaLoadError(
        "HEIC/HEIF is not supported in the browser. Export as JPEG in Photos, then try again.",
        "HEIC_UNSUPPORTED",
      );
    }

    if (file.type.startsWith("video/") || LIKELY_VIDEO_EXTENSION.test(file.name)) {
      return this.loadVideo(file);
    }
    return this.loadImage(file, options.maxTextureSize);
  }

  /**
   * 画像をデコードしてテクスチャにする。
   * Safari 等で Image 経路が落ちた場合は createImageBitmap を順に試す。
   */
  private async loadImage(file: File, maxTextureSize?: number): Promise<LoadResult> {
    const debug = isFilmLabMediaDebugEnabled();
    const meta = {
      name: file.name,
      type: file.type || "(empty)",
      size: file.size,
      ua: typeof navigator !== "undefined" ? navigator.userAgent : "",
    };

    if (debug) {
      console.info("[FilmLab MediaLoader] loadImage start", meta);
    }

    let imageElementError: unknown;
    try {
      return await decodeViaImageElement(file, maxTextureSize);
    } catch (err) {
      imageElementError = err;
      if (debug) {
        console.warn("[FilmLab MediaLoader] Image() + blob URL path failed", err);
      }
    }

    const safariHint =
      typeof navigator !== "undefined" && /Safari/i.test(navigator.userAgent) &&
      !/Chrome|Chromium|CriOS/i.test(navigator.userAgent)
        ? " Safari では、ディスプレイプロファイル付きの PNG スクリーンショットが Image デコードに失敗することがあります。"
        : "";

    try {
      return await decodeViaCreateImageBitmap(file, maxTextureSize, debug, "from File");
    } catch (err2) {
      if (debug) {
        console.warn("[FilmLab MediaLoader] createImageBitmap(File) failed", err2);
      }

      const mime = file.type && file.type.startsWith("image/") ? file.type : "image/png";
      try {
        const blob = new Blob([await file.arrayBuffer()], { type: mime });
        return await decodeViaCreateImageBitmap(blob, maxTextureSize, debug, `from Blob(${mime})`);
      } catch (err3) {
        if (debug) {
          console.warn("[FilmLab MediaLoader] createImageBitmap(retyped Blob) failed", err3);
        }

        const detail = debug
          ? ` Debug: ImageError=${String(imageElementError)}; Bitmap1=${String(err2)}; Bitmap2=${String(err3)}`
          : "";

        throw new MediaLoadError(
          `Could not decode this image. Try JPEG, PNG, or WebP.${safariHint} If it still fails, re-export without an embedded display profile (e.g. Preview → Export).${detail}`,
          "IMAGE_DECODE_FAILED",
        );
      }
    }
  }

  private async loadVideo(file: File): Promise<LoadResult> {
    return new Promise((resolve, reject) => {
      const url = URL.createObjectURL(file);
      const video = document.createElement("video");
      video.muted = true;
      video.loop = true;
      video.playsInline = true;
      video.preload = "auto";
      // blob URL はローカルファイルなので crossOrigin を付けないほうが安全です。
      video.src = url;

      /**
       * @description video 要素が実際に表示できるフレームを持てた段階で Texture を作ります。
       * `loadedmetadata` だけだと幅高さは分かっても、最初のフレームがまだ黒いことがあります。
       * @param eventName 失敗したイベント名
       * @param extra 追加で残したい詳細
       */
      const rejectVideoLoad = (eventName: string, extra?: unknown) => {
        try {
          URL.revokeObjectURL(url);
        } catch {
          /* ignore */
        }
        reject(
          new MediaLoadError(
            `MediaLoader.loadVideo("${file.name}", "${file.type || "unknown"}") failed at ${eventName}. Try MP4 (H.264), WebM, or a MOV codec your browser can decode.`,
            "VIDEO_DECODE_FAILED",
          ),
        );
        if (extra != null) {
          console.error("MediaLoader.loadVideo detailed failure", {
            fileName: file.name,
            fileType: file.type,
            eventName,
            extra,
          });
        }
      };

      video.onloadeddata = () => {
        const texture = new THREE.VideoTexture(video);
        texture.colorSpace = THREE.SRGBColorSpace;
        texture.minFilter = THREE.LinearMipmapLinearFilter;
        texture.magFilter = THREE.LinearFilter;
        texture.generateMipmaps = true;

        video.play().catch((err) => {
          console.warn("MediaLoader.loadVideo: autoplay blocked", err);
        });

        resolve({
          texture,
          width: video.videoWidth,
          height: video.videoHeight,
          type: "video",
        });
      };

      video.onerror = () => {
        rejectVideoLoad("error", video.error);
      };

      video.onabort = () => {
        rejectVideoLoad("abort");
      };

      video.load();
    });
  }

  /**
   * @description URL から直接動画を読み込む。Desktop の mezzanine 変換後パス（`film-lab-video://…`）等、
   * blob URL を経由しない動画ソース向け。`loadVideo(file)` とほぼ同じだが `createObjectURL` / `revokeObjectURL` を使わない。
   * @param url 動画の URL（`film-lab-video://…` や `file://…` 等）
   * @param label エラーメッセージに表示する任意のラベル（元ファイル名等）
   */
  async loadVideoFromURL(url: string, label?: string): Promise<LoadResult> {
    return new Promise((resolve, reject) => {
      const video = document.createElement("video");
      video.muted = true;
      video.loop = true;
      video.playsInline = true;
      video.preload = "auto";
      video.src = url;

      const displayLabel = label ?? url;

      const rejectVideoLoad = (eventName: string, extra?: unknown) => {
        reject(
          new MediaLoadError(
            `MediaLoader.loadVideoFromURL("${displayLabel}") failed at ${eventName}. Try MP4 (H.264), WebM, or a MOV codec your browser can decode.`,
            "VIDEO_DECODE_FAILED",
          ),
        );
        if (extra != null) {
          console.error("MediaLoader.loadVideoFromURL detailed failure", {
            url,
            label: displayLabel,
            eventName,
            extra,
          });
        }
      };

      video.onloadeddata = () => {
        const texture = new THREE.VideoTexture(video);
        texture.colorSpace = THREE.SRGBColorSpace;
        texture.minFilter = THREE.LinearMipmapLinearFilter;
        texture.magFilter = THREE.LinearFilter;
        texture.generateMipmaps = true;

        video.play().catch((err) => {
          console.warn("MediaLoader.loadVideoFromURL: autoplay blocked", err);
        });

        resolve({
          texture,
          width: video.videoWidth,
          height: video.videoHeight,
          type: "video",
        });
      };

      video.onerror = () => {
        rejectVideoLoad("error", video.error);
      };

      video.onabort = () => {
        rejectVideoLoad("abort");
      };

      video.load();
    });
  }

  async loadURL(url: string): Promise<LoadResult> {
    return new Promise((resolve, reject) => {
      const loader = new THREE.TextureLoader();
      loader.load(
        url,
        (texture) => {
          texture.colorSpace = THREE.SRGBColorSpace;
          texture.minFilter = THREE.LinearFilter;
          texture.magFilter = THREE.LinearFilter;
          resolve({
            texture,
            width: texture.image.width as number,
            height: texture.image.height as number,
            type: "image",
          });
        },
        undefined,
        (err) => {
          reject(
            err instanceof Error
              ? new MediaLoadError(err.message, "IMAGE_DECODE_FAILED")
              : new MediaLoadError(String(err), "UNKNOWN"),
          );
        },
      );
    });
  }
}
