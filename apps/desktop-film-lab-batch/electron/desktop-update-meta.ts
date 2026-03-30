/**
 * @file 公開 JSON（更新案内用）の取得と検証
 * @overview HTTPS 上の小さな JSON を fetch し、Zod で形を確かめるだけです。
 * @limitations 署名は付けません（TLS と運用でカバー）。オフライン・5xx は呼び出し側で黙って無視します。
 */
import { z } from "zod";

/** @description 配布パイプラインが Blob 等に置く JSON の形 */
export const desktopUpdateMetaSchema = z.object({
  schemaVersion: z.number().int().positive(),
  latestVersion: z.string().min(1).max(64),
  downloadPageUrl: z.string().url().max(2048),
  releaseNotesUrl: z.string().url().max(2048).optional(),
});

export type DesktopUpdateMeta = z.infer<typeof desktopUpdateMetaSchema>;

/**
 * @description 更新メタ URL へ GET し、パース成功したら返す。失敗時は null（ログのみ推奨）。
 * @param updateCheckUrl HTTPS の JSON URL
 * @param currentAppVersion 差分判定用（ログや将来の拡張に使う）
 * @param timeoutMs ネットワーク待ちの上限
 */
export async function fetchDesktopUpdateMeta(
  updateCheckUrl: string,
  currentAppVersion: string,
  timeoutMs: number,
): Promise<DesktopUpdateMeta | null> {
  const functionName = "fetchDesktopUpdateMeta";
  const urlWithBust = `${updateCheckUrl}${updateCheckUrl.includes("?") ? "&" : "?"}t=${Date.now()}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(urlWithBust, {
      method: "GET",
      signal: controller.signal,
      headers: {
        Accept: "application/json",
        "User-Agent": `FilmLabDesktop/${currentAppVersion}`,
      },
    });
    if (!res.ok) {
      console.warn(
        `[film-lab-desktop] ${functionName}: HTTP ${res.status} for ${updateCheckUrl}`,
      );
      return null;
    }
    const raw: unknown = await res.json();
    const parsed = desktopUpdateMetaSchema.safeParse(raw);
    if (!parsed.success) {
      console.warn(
        `[film-lab-desktop] ${functionName}: JSON 検証失敗 — ${parsed.error.message}`,
      );
      return null;
    }
    return parsed.data;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn(`[film-lab-desktop] ${functionName}: fetch 失敗 — ${msg}`);
    return null;
  } finally {
    clearTimeout(timer);
  }
}
