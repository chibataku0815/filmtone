/**
 * Film Lab デスクトップ — カスタム動画プロトコル補助
 *
 * @overview Chromium の seek が効くように、Range ヘッダを解釈して byte-range を返す。
 */

export const FILM_LAB_VIDEO_PROTOCOL = "film-lab-video";

/**
 * @description レンダラの video 要素用 URL（クエリに path を載せる）
 */
export function absolutePathToVideoSrcUrl(absPath: string): string {
  return `${FILM_LAB_VIDEO_PROTOCOL}://local/?path=${encodeURIComponent(absPath)}`;
}

/**
 * @description 動画とサムネイル画像の拡張子から最低限の Content-Type を返す。
 * Progressive loading では JPEG サムネイルも同じ custom protocol で配るため、
 * 画像拡張子もここで吸収します。
 */
export function guessVideoContentType(filePath: string): string {
  const lower = filePath.toLowerCase();
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".webp")) return "image/webp";
  if (lower.endsWith(".gif")) return "image/gif";
  if (lower.endsWith(".mov")) return "video/quicktime";
  if (lower.endsWith(".webm")) return "video/webm";
  if (lower.endsWith(".mkv")) return "video/x-matroska";
  return "video/mp4";
}

export type HttpByteRange = {
  start: number;
  end: number;
};

/**
 * @description `Range: bytes=...` を単一レンジとして解釈する。
 * 解析不能または範囲外なら null。
 */
export function parseHttpByteRange(
  rawRangeHeader: string | null,
  totalBytes: number,
): HttpByteRange | null {
  if (
    rawRangeHeader == null ||
    !Number.isFinite(totalBytes) ||
    totalBytes <= 0
  ) {
    return null;
  }
  const m = /^bytes=(\d*)-(\d*)$/i.exec(rawRangeHeader.trim());
  if (!m) return null;

  const rawStart = m[1] ?? "";
  const rawEnd = m[2] ?? "";

  if (rawStart === "" && rawEnd === "") return null;

  if (rawStart === "") {
    const suffixLen = Number.parseInt(rawEnd, 10);
    if (!Number.isFinite(suffixLen) || suffixLen <= 0) return null;
    const clampedLen = Math.min(suffixLen, totalBytes);
    return {
      start: totalBytes - clampedLen,
      end: totalBytes - 1,
    };
  }

  const start = Number.parseInt(rawStart, 10);
  if (!Number.isFinite(start) || start < 0 || start >= totalBytes) return null;

  if (rawEnd === "") {
    return { start, end: totalBytes - 1 };
  }

  const end = Number.parseInt(rawEnd, 10);
  if (!Number.isFinite(end) || end < start) return null;

  return {
    start,
    end: Math.min(end, totalBytes - 1),
  };
}
