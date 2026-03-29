/**
 * @/shared/analytics のデスクトップ用スタブ（計測なし）
 */
export const META_PIXEL_ID = "";
export const GA_MEASUREMENT_ID = "";

export function trackPageView(_path: string): void {}

export function trackFilmLabDonationEvent(
  _name: string,
  _details: Record<string, unknown>,
): void {}

export function trackFilmLabSmartLookEvent(
  _name: string,
  _details: Record<string, unknown>,
): void {}

export function trackPhotographyLead(_details: {
  locale: string;
  eventType: string;
}): void {}
