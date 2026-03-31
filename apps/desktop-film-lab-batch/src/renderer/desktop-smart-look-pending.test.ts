import { describe, expect, it, vi } from "vitest";
import { resolveDesktopFilmLabImportMeta } from "../../vite.config";

async function renderDesktopControlPanelCoreHtml(): Promise<string> {
  vi.resetModules();

  try {
    const React = await import("react");
    const { renderToStaticMarkup } = await import("react-dom/server");
    const { NextIntlClientProvider } = await import("next-intl");
    const { FilmLabControlPanelCore } = await import("film-lab-ui");
    const messages = (await import("../../messages/ja.json")).default;

    return renderToStaticMarkup(
      React.createElement(
        NextIntlClientProvider,
        { locale: "ja", messages, timeZone: "Asia/Tokyo" },
        React.createElement(FilmLabControlPanelCore, {
          viewport: null,
          histogramVisible: true,
          onHistogramToggle: () => {},
        }),
      ),
    );
  } finally {
    vi.resetModules();
  }
}

describe("resolveDesktopFilmLabImportMeta", () => {
  it("keeps Smart Look UI off by default", () => {
    expect(resolveDesktopFilmLabImportMeta("development", {}).smartLookUiFlag).toBe("");
    expect(resolveDesktopFilmLabImportMeta("production", {}).smartLookUiFlag).toBe("");
  });

  it("enables Smart Look UI only for an explicit true value", () => {
    expect(
      resolveDesktopFilmLabImportMeta("production", {
        VITE_FILM_LAB_SMART_LOOK_UI: "true",
      }).smartLookUiFlag,
    ).toBe("true");
    expect(
      resolveDesktopFilmLabImportMeta("production", {
        VITE_FILM_LAB_SMART_LOOK_UI: "false",
      }).smartLookUiFlag,
    ).toBe("");
    expect(
      resolveDesktopFilmLabImportMeta("production", {
        VITE_FILM_LAB_SMART_LOOK_UI: "1",
      }).smartLookUiFlag,
    ).toBe("");
  });

  it("keeps raster correction opt-in through either desktop or mirrored public env", () => {
    expect(
      resolveDesktopFilmLabImportMeta("production", {
        VITE_FILM_LAB_SMART_LOOK_RASTER: "true",
      }).smartLookRasterFlag,
    ).toBe("true");
    expect(
      resolveDesktopFilmLabImportMeta("production", {
        NEXT_PUBLIC_FILM_LAB_SMART_LOOK_RASTER: "true",
      }).smartLookRasterFlag,
    ).toBe("true");
    expect(resolveDesktopFilmLabImportMeta("production", {}).smartLookRasterFlag).toBe("");
  });

  it("renders the desktop control panel core with preset buttons", async () => {
    const html = await renderDesktopControlPanelCoreHtml();

    expect(html).toContain("プリセット");
    // Core does not include Smart Look or Browser Storage
    expect(html).not.toContain("見本に色味を合わせる（AI・beta）");
    expect(html).not.toContain("Match colors to a sample (AI, beta)");
  });
});
