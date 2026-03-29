import { describe, expect, it, vi } from "vitest";
import { resolveDesktopFilmLabImportMeta } from "../../vite.config";

async function renderDesktopControlPanelHtml(
  smartLookUiFlag: "" | "true",
): Promise<string> {
  const originalFlag = process.env.NEXT_PUBLIC_FILM_LAB_SMART_LOOK_UI;

  if (smartLookUiFlag === "true") {
    process.env.NEXT_PUBLIC_FILM_LAB_SMART_LOOK_UI = "true";
  } else {
    delete process.env.NEXT_PUBLIC_FILM_LAB_SMART_LOOK_UI;
  }

  vi.resetModules();

  try {
    const React = await import("react");
    const { renderToStaticMarkup } = await import("react-dom/server");
    const { NextIntlClientProvider } = await import("next-intl");
    const { ControlPanel } = await import("@film-lab/components/ControlPanel");
    const messages = (await import("../../messages/ja.json")).default;

    return renderToStaticMarkup(
      React.createElement(
        NextIntlClientProvider,
        { locale: "ja", messages },
        React.createElement(ControlPanel, {
          viewport: null,
          histogramVisible: true,
          onHistogramToggle: () => {},
          filmLabCanvasRef: { current: null },
          smartLookApiBaseUrl: "http://127.0.0.1:3000",
          serverVerifiedSupporter: true,
          autoRestoreStoredSession: false,
        }),
      ),
    );
  } finally {
    if (typeof originalFlag === "string") {
      process.env.NEXT_PUBLIC_FILM_LAB_SMART_LOOK_UI = originalFlag;
    } else {
      delete process.env.NEXT_PUBLIC_FILM_LAB_SMART_LOOK_UI;
    }
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

  it("keeps Smart Look controls unmounted in the desktop control panel while pending", async () => {
    const html = await renderDesktopControlPanelHtml("");

    expect(html).toContain("Presets");
    expect(html).not.toContain("見本に色味を合わせる（AI・beta）");
    expect(html).not.toContain("Match colors to a sample (AI, beta)");
  });

  it("would mount Smart Look controls on desktop only when the UI flag is explicitly true", async () => {
    const html = await renderDesktopControlPanelHtml("true");

    expect(html).toContain("見本に色味を合わせる（AI・beta）");
  });
});
