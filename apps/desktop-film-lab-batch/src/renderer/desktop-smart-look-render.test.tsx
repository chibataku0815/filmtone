import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { NextIntlClientProvider } from "next-intl";

import en from "../../messages/en.json";

describe("Desktop smart-look pending render", () => {
  it("renders the desktop control panel without mounting Smart Look controls", async () => {
    await import("./process-polyfill");
    const { ControlPanel } = await import("@film-lab/components/ControlPanel");

    const html = renderToStaticMarkup(
      <NextIntlClientProvider locale="en" messages={en} timeZone="UTC">
        <ControlPanel
          viewport={null}
          histogramVisible
          onHistogramToggle={() => {}}
          smartLookApiBaseUrl="http://127.0.0.1:3000"
          serverVerifiedSupporter
          autoRestoreStoredSession={false}
        />
      </NextIntlClientProvider>,
    );

    expect(html).toContain('data-testid="film-lab-preset-cinematic"');
    expect(html).not.toContain("Match colors to a sample (AI, beta)");
    expect(html).not.toContain("Pick sample photo");
    expect(html).not.toContain("Match sample look");
    expect(html).not.toContain("見本に色味を合わせる（AI・beta）");
  });
});
