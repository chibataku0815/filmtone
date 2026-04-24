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
 *   - the copy handler is tested by stubbing `globalThis.navigator` /
 *     `globalThis.document` and invoking `copyInstallCommandToClipboard`
 *     directly. This mirrors how the live component would dispatch the
 *     action when the button is clicked in Electron.
 */

import type { ReactElement } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { NextIntlClientProvider } from "next-intl";

import jaMessages from "../../messages/ja.json";
import enMessages from "../../messages/en.json";
import type { HdrPreparationPolicy } from "./desktop-api";
import {
  HDR_FFMPEG_INSTALL_COMMAND,
  HdrPolicyNotice,
  copyInstallCommandToClipboard,
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

  it("renders the inline notice with title, install command and copy button (en)", () => {
    const html = withIntl(
      "en",
      <HdrPolicyNotice policy={capabilityGatedPolicy} />,
    );
    expect(html).toContain('data-testid="hdr-policy-notice"');
    expect(html).toContain("HDR source detected");
    // install command is shown verbatim (HTML-entity-encoded `&&` in SSR output)
    const escapedCommand = HDR_FFMPEG_INSTALL_COMMAND.replace(/&/g, "&amp;");
    expect(html).toContain(escapedCommand);
    // the raw `pre` block holds the command for clipboard fidelity
    expect(html).toContain('data-testid="hdr-policy-notice-command"');
    // copy button exists and exposes a clear aria-label
    expect(html).toContain('data-testid="hdr-policy-notice-copy-btn"');
    expect(html).toContain("Copy command");
    // policy.warning flows through
    expect(html).toContain("zscale");
    expect(html).toContain("libplacebo");
    // fixture doc link is NOT rendered when no handler is passed
    expect(html).not.toContain('data-testid="hdr-policy-notice-doc-btn"');
  });

  it("renders the Japanese copy when locale is ja", () => {
    const html = withIntl(
      "ja",
      <HdrPolicyNotice policy={capabilityGatedPolicy} />,
    );
    expect(html).toContain("コマンドをコピー");
    expect(html).toContain("HDR");
  });

  it("renders the fixture doc button when a handler is provided", () => {
    const html = withIntl(
      "en",
      <HdrPolicyNotice
        policy={capabilityGatedPolicy}
        onOpenFixtureDoc={() => {}}
      />,
    );
    expect(html).toContain('data-testid="hdr-policy-notice-doc-btn"');
    expect(html).toContain("HDR fixture status");
  });
});

describe("copyInstallCommandToClipboard", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("invokes navigator.clipboard.writeText with the exact install command", async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    vi.stubGlobal("navigator", { clipboard: { writeText } });

    const ok = await copyInstallCommandToClipboard(HDR_FFMPEG_INSTALL_COMMAND);

    expect(ok).toBe(true);
    expect(writeText).toHaveBeenCalledTimes(1);
    expect(writeText).toHaveBeenCalledWith(HDR_FFMPEG_INSTALL_COMMAND);
  });

  it("falls back to textarea + execCommand when navigator.clipboard is unavailable", async () => {
    vi.stubGlobal("navigator", {});

    const appendChild = vi.fn();
    const removeChild = vi.fn();
    const execCommand = vi.fn().mockReturnValue(true);
    const textarea: Record<string, unknown> = {
      value: "",
      setAttribute: vi.fn(),
      select: vi.fn(),
      style: {},
    };
    const createElement = vi.fn().mockReturnValue(textarea);
    vi.stubGlobal("document", {
      createElement,
      execCommand,
      body: { appendChild, removeChild },
    });

    const ok = await copyInstallCommandToClipboard("brew install test");

    expect(ok).toBe(true);
    expect(createElement).toHaveBeenCalledWith("textarea");
    expect(textarea.value).toBe("brew install test");
    expect(appendChild).toHaveBeenCalledWith(textarea);
    expect(execCommand).toHaveBeenCalledWith("copy");
    expect(removeChild).toHaveBeenCalledWith(textarea);
  });

  it("returns false and does not throw when both paths are unavailable", async () => {
    vi.stubGlobal("navigator", {});
    vi.stubGlobal("document", undefined);

    const ok = await copyInstallCommandToClipboard("brew install test");
    expect(ok).toBe(false);
  });

  it("returns false and falls back gracefully when navigator.clipboard rejects", async () => {
    const writeText = vi.fn().mockRejectedValue(new Error("denied"));
    const appendChild = vi.fn();
    const removeChild = vi.fn();
    const execCommand = vi.fn().mockReturnValue(true);
    const textarea: Record<string, unknown> = {
      value: "",
      setAttribute: vi.fn(),
      select: vi.fn(),
      style: {},
    };
    const createElement = vi.fn().mockReturnValue(textarea);
    vi.stubGlobal("navigator", { clipboard: { writeText } });
    vi.stubGlobal("document", {
      createElement,
      execCommand,
      body: { appendChild, removeChild },
    });

    const ok = await copyInstallCommandToClipboard("brew install test");

    expect(writeText).toHaveBeenCalled();
    expect(execCommand).toHaveBeenCalledWith("copy");
    expect(ok).toBe(true);
  });
});

describe("HDR_FFMPEG_INSTALL_COMMAND literal", () => {
  it("is the exact homebrew-ffmpeg tap command (contract with the S-4 runbook)", () => {
    expect(HDR_FFMPEG_INSTALL_COMMAND).toBe(
      "brew tap homebrew-ffmpeg/ffmpeg && brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-libzimg --with-libplacebo",
    );
  });
});

// ---------------------------------------------------------------------------
// Ensure default exports do not regress when imported from the barrel file
// ---------------------------------------------------------------------------

describe("barrel-free imports", () => {
  it("exposes all expected named exports", () => {
    expect(typeof HdrPolicyNotice).toBe("function");
    expect(typeof copyInstallCommandToClipboard).toBe("function");
    expect(typeof shouldSurfaceHdrPolicyNotice).toBe("function");
    expect(typeof HDR_FFMPEG_INSTALL_COMMAND).toBe("string");
  });
});
