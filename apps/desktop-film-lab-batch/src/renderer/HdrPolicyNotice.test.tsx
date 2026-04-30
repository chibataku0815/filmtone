/**
 * @fileoverview Tests for `<HdrPolicyNotice />` and its pure helpers.
 *
 * @description
 * The Filmtone desktop test harness is node-based (`vitest` with
 * `environment: "node"`) and does not use `@testing-library/react` or `jsdom`
 * — instead components are smoke-tested via `renderToStaticMarkup` (see
 * `desktop-smart-look-render.test.tsx`, `batch-tab/BatchTabPanel.test.tsx`).
 *
 * This suite follows the same shape:
 *   - pure predicates are tested directly
 *   - rendered markup is asserted with `renderToStaticMarkup`
 *   - developer-only install commands and diagnostics stay out of the user UI
 */

import type { ReactElement } from "react";
import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { NextIntlClientProvider } from "next-intl";

import jaMessages from "../../../../messages/ja.json";
import enMessages from "../../../../messages/en.json";
import type { HdrPreparationPolicy } from "./desktop-api";
import {
  HdrPolicyNotice,
  shouldSurfaceHdrPolicyNotice,
} from "./HdrPolicyNotice";

function withIntl(locale: "ja" | "en", ui: ReactElement): string {
  return renderToStaticMarkup(
    <NextIntlClientProvider
      locale={locale}
      messages={locale === "ja" ? jaMessages : enMessages}
      timeZone="Asia/Tokyo"
    >
      {ui}
    </NextIntlClientProvider>,
  );
}

const capabilityGatedPolicy: HdrPreparationPolicy = {
  strategy: "defer-unknown",
  reason: "ffmpeg-missing-hdr-filters",
  requiresFixtureValidation: true,
  warning:
    "Source transfer is PQ; local ffmpeg is missing zscale, libplacebo — HDR→SDR preparation deferred.",
};

const sdrPolicy: HdrPreparationPolicy = {
  strategy: "none",
  reason: "source-is-sdr-bt709",
  requiresFixtureValidation: false,
  warning: null,
};

const hdrPqReadyPolicy: HdrPreparationPolicy = {
  strategy: "prepare-sdr-mezzanine",
  reason: "source-is-hdr-pq",
  requiresFixtureValidation: true,
  warning: null,
};

describe("shouldSurfaceHdrPolicyNotice", () => {
  it("returns false for null / undefined policy", () => {
    expect(shouldSurfaceHdrPolicyNotice(null)).toBe(false);
    expect(shouldSurfaceHdrPolicyNotice(undefined)).toBe(false);
  });

  it("returns false for SDR and other non-capability-gated reasons", () => {
    expect(shouldSurfaceHdrPolicyNotice(sdrPolicy)).toBe(false);
    expect(shouldSurfaceHdrPolicyNotice(hdrPqReadyPolicy)).toBe(false);
    expect(
      shouldSurfaceHdrPolicyNotice({
        ...sdrPolicy,
        reason: "source-color-unknown",
      }),
    ).toBe(false);
    expect(
      shouldSurfaceHdrPolicyNotice({
        ...sdrPolicy,
        reason: "wide-gamut-transfer-unknown",
      }),
    ).toBe(false);
  });

  it("returns true only for ffmpeg-missing-hdr-filters", () => {
    expect(shouldSurfaceHdrPolicyNotice(capabilityGatedPolicy)).toBe(true);
  });
});

describe("<HdrPolicyNotice /> rendering", () => {
  it("renders nothing for null policy", () => {
    const html = withIntl("en", <HdrPolicyNotice policy={null} />);
    expect(html).toBe("");
  });

  it("renders nothing for SDR source policy", () => {
    const html = withIntl("en", <HdrPolicyNotice policy={sdrPolicy} />);
    expect(html).toBe("");
  });

  it("renders nothing for the HDR-ready (prepare-sdr-mezzanine) policy", () => {
    const html = withIntl("en", <HdrPolicyNotice policy={hdrPqReadyPolicy} />);
    expect(html).toBe("");
  });

  it("renders a user-facing inline notice without install commands or raw diagnostics (en)", () => {
    const html = withIntl(
      "en",
      <HdrPolicyNotice policy={capabilityGatedPolicy} />,
    );
    expect(html).toContain('data-testid="hdr-policy-notice"');
    expect(html).toContain("HDR video loaded");
    expect(html).toContain("standard SDR video");
    expect(html).not.toContain("brew");
    expect(html).not.toContain("ffmpeg");
    expect(html).not.toContain("zscale");
    expect(html).not.toContain("libplacebo");
    expect(html).not.toContain('data-testid="hdr-policy-notice-command"');
    expect(html).not.toContain('data-testid="hdr-policy-notice-copy-btn"');
    expect(html).not.toContain('data-testid="hdr-policy-notice-doc-btn"');
  });

  it("renders the Japanese copy when locale is ja", () => {
    const html = withIntl(
      "ja",
      <HdrPolicyNotice policy={capabilityGatedPolicy} />,
    );
    expect(html).toContain("HDR動画を読み込みました");
    expect(html).toContain("標準のSDR動画");
    expect(html).not.toContain("brew");
    expect(html).not.toContain("ffmpeg");
    expect(html).not.toContain("zscale");
    expect(html).not.toContain("libplacebo");
  });

  it("does not render internal fixture links even when a handler is provided", () => {
    const html = withIntl(
      "en",
      <HdrPolicyNotice
        policy={capabilityGatedPolicy}
        onOpenFixtureDoc={() => {}}
      />,
    );
    expect(html).not.toContain('data-testid="hdr-policy-notice-doc-btn"');
  });
});

// ---------------------------------------------------------------------------
// Ensure default exports do not regress when imported from the barrel file
// ---------------------------------------------------------------------------

describe("barrel-free imports", () => {
  it("exposes all expected named exports", () => {
    expect(typeof HdrPolicyNotice).toBe("function");
    expect(typeof shouldSurfaceHdrPolicyNotice).toBe("function");
  });
});
