/**
 * Web Film Lab の film-lab-donation-config / feature-flags が参照する process.env を Electron レンダラに用意する。
 *
 * @limitations 寄付・共有などは空で実質オフ。スマートルックだけは Vite の import.meta（vite.config define）と同じ真偽を入れ、
 * 空文字で上書きすると UI が一生出ないバグがあったので除外していた。
 */
const smartLookUiFromVite =
  import.meta.env.VITE_FILM_LAB_SMART_LOOK_UI === "true" ? "true" : "";
const smartLookRasterFromVite =
  import.meta.env.VITE_FILM_LAB_SMART_LOOK_RASTER === "true" ? "true" : "";

const env: Record<string, string> = {
  NODE_ENV: import.meta.env.PROD ? "production" : "development",
  NEXT_PUBLIC_FILM_LAB_STRIPE_SUPPORT_URL: "",
  NEXT_PUBLIC_FILM_LAB_STRIPE_SUPPORT_URL_9: "",
  NEXT_PUBLIC_FILM_LAB_STRIPE_SUPPORT_URL_25: "",
  NEXT_PUBLIC_FILM_LAB_BMC_URL: "",
  NEXT_PUBLIC_FILM_LAB_DONATION_UI: "",
  NEXT_PUBLIC_FILM_LAB_SHARE_UI: "",
  NEXT_PUBLIC_FILM_LAB_SMART_LOOK_UI: smartLookUiFromVite,
  NEXT_PUBLIC_FILM_LAB_SMART_LOOK_RASTER: smartLookRasterFromVite,
  NEXT_PUBLIC_FILM_LAB_DEBUG_DONATION: "",
};

const g = globalThis as unknown as {
  process?: { env: Record<string, string | undefined> };
};

if (!g.process) {
  g.process = { env: { ...env } };
} else {
  g.process.env = { ...g.process.env, ...env };
}
