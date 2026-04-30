/**
 * エントリ — process ポリフィル後に React を起動（film-lab モジュールより先に実行する）
 */
import "./process-polyfill";
import "./globals.css";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { NextIntlClientProvider } from "next-intl";
import App from "./App";
import en from "../../../../messages/en.json";
import ja from "../../../../messages/ja.json";

/**
 * @description OS／ブラウザの優先言語リストから、サポートするロケール（ja / en）を選ぶ
 */
function pickRendererLocale(): string {
  if (typeof navigator === "undefined") return "en";
  const list = navigator.languages?.length
    ? navigator.languages
    : [navigator.language];
  for (const raw of list) {
    const lower = raw.toLowerCase();
    if (lower.startsWith("ja")) return "ja";
  }
  return "en";
}

const locale = pickRendererLocale();
const messages = locale === "ja" ? ja : en;

const rootEl = document.getElementById("root");
if (!rootEl) {
  throw new Error("main.tsx: #root がありません");
}

const timeZone =
  typeof Intl !== "undefined"
    ? Intl.DateTimeFormat().resolvedOptions().timeZone
    : "UTC";

createRoot(rootEl).render(
  <StrictMode>
    <NextIntlClientProvider
      locale={locale}
      messages={messages}
      timeZone={timeZone}
    >
      <App />
    </NextIntlClientProvider>
  </StrictMode>,
);
