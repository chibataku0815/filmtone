/**
 * エントリ — process ポリフィル後に React を起動（film-lab モジュールより先に実行する）
 */
import "./process-polyfill";
import "./globals.css";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { NextIntlClientProvider } from "next-intl";
import App from "./App";
import en from "../../messages/en.json";
import ja from "../../messages/ja.json";

const locale =
  typeof navigator !== "undefined" && navigator.language.startsWith("ja")
    ? "ja"
    : "en";
const messages = locale === "ja" ? ja : en;

const rootEl = document.getElementById("root");
if (!rootEl) {
  throw new Error("main.tsx: #root がありません");
}

createRoot(rootEl).render(
  <StrictMode>
    <NextIntlClientProvider locale={locale} messages={messages}>
      <App />
    </NextIntlClientProvider>
  </StrictMode>,
);
