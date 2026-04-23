import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { NextIntlClientProvider } from "next-intl";

import en from "../../messages/en.json";

describe("Desktop control panel core render", () => {
  it("renders the searchable preset select without Web-only controls", async () => {
    await import("./process-polyfill");
    const { FilmLabControlPanelCore } = await import("film-lab-ui");

    const html = renderToStaticMarkup(
      <NextIntlClientProvider locale="en" messages={en} timeZone="UTC">
        <FilmLabControlPanelCore
          viewport={null}
          histogramVisible
          onHistogramToggle={() => {}}
        />
      </NextIntlClientProvider>,
    );

    expect(html).toContain('data-testid="film-lab-preset-select-trigger"');
    expect(html).toContain("Neutral");
    expect(html).toContain("Clean Base");
    // Core does not include Smart Look, Share, or Browser Storage sections
    expect(html).not.toContain("Match colors to a sample (AI, beta)");
    expect(html).not.toContain("Pick sample photo");
    expect(html).not.toContain("Match sample look");
  });
});
