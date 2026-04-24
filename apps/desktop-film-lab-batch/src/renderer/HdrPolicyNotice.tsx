/**
 * @fileoverview FFmpeg HDR capability gap inline notice.
 *
 * @description
 * When the HDR preparation policy reports `reason === "ffmpeg-missing-hdr-filters"`
 * (S-4 capability probe in `electron/ffmpeg-capability-probe.ts`), the renderer
 * previously surfaced only an opaque log line buried in the export log.
 *
 * This component renders an inline, non-blocking callout right next to the
 * video source controls so that the user can see:
 *   1. What is missing (PQ / HLG cannot be linearized by the local ffmpeg).
 *   2. Which specific filters were reported missing (flows through `warning`).
 *   3. A one-click copy of the upgrade command (homebrew-ffmpeg tap).
 *   4. A link to the fixture inventory doc for deeper context.
 *
 * It does NOT block export — SDR content still exports fine; HDR content is
 * deferred to the existing "defer-unknown" policy path.
 *
 * This component is intentionally agnostic of the export trigger — it watches
 * the policy object passed by App.tsx and renders only when the capability-
 * gated variant is active.
 */

import { Copy, Info, Warning } from "@phosphor-icons/react";
import { useCallback, useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import type { HdrPreparationPolicy } from "./desktop-api";

/**
 * @description Exact install command for the homebrew-ffmpeg tap build that
 * ships `libzimg` (zscale) and `libplacebo` — the two filters required to
 * linearize PQ / HLG sources inside the ffmpeg pipeline.
 *
 * Exported so tests can assert the literal string without duplicating it.
 */
export const HDR_FFMPEG_INSTALL_COMMAND =
  "brew tap homebrew-ffmpeg/ffmpeg && brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-libzimg --with-libplacebo";

/**
 * @description Relative path of the fixture inventory doc inside the app.
 * Used for the "why" link; the renderer opens it via `openExternalUrl`
 * which accepts `file://` URLs handled by the main process.
 */
export const HDR_FIXTURE_INVENTORY_DOC_PATH =
  "apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-hdr-fixture-inventory-2026-04-24.md";

/**
 * @description Pure predicate: true when the current policy is the capability
 * gated defer that this notice targets. Exported for test use.
 * @param policy HDR preparation policy from `sourceVideoMetadata.hdrPreparationPolicy`
 */
export function shouldSurfaceHdrPolicyNotice(
  policy: HdrPreparationPolicy | null | undefined,
): boolean {
  if (!policy) return false;
  return policy.reason === "ffmpeg-missing-hdr-filters";
}

/**
 * @description Best-effort clipboard writer. In an Electron renderer the
 * standard `navigator.clipboard.writeText` works under secure contexts, but
 * some packaged windows (and node-env vitest) do not expose it. We fall back
 * to a detached textarea + `document.execCommand('copy')` path so the copy
 * button is never dead in the field.
 * @returns true if the command was accepted by one of the two paths.
 */
export async function copyInstallCommandToClipboard(
  text: string,
): Promise<boolean> {
  if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      // fall through to textarea fallback
    }
  }
  if (typeof document === "undefined") return false;
  try {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.top = "-1000px";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    const ok = document.execCommand("copy");
    document.body.removeChild(textarea);
    return ok;
  } catch {
    return false;
  }
}

export type HdrPolicyNoticeProps = {
  policy: HdrPreparationPolicy | null | undefined;
  /**
   * @description Optional hook for opening the fixture inventory doc in the
   * system default handler. When omitted the link is not rendered — keeps
   * the notice safe to use in contexts without `openExternalUrl` wiring.
   */
  onOpenFixtureDoc?: () => void;
};

/**
 * @description Inline, non-blocking callout shown near the video source
 * controls when the ffmpeg build lacks HDR linearization filters. Renders
 * nothing for any other policy reason (including SDR sources).
 */
export function HdrPolicyNotice(props: HdrPolicyNoticeProps) {
  const { policy, onOpenFixtureDoc } = props;
  const t = useTranslations("film-lab.desktop.batch");
  const [copyState, setCopyState] = useState<"idle" | "copied" | "failed">(
    "idle",
  );
  const resetTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    return () => {
      if (resetTimerRef.current !== null) {
        clearTimeout(resetTimerRef.current);
        resetTimerRef.current = null;
      }
    };
  }, []);

  const handleCopy = useCallback(async () => {
    const ok = await copyInstallCommandToClipboard(HDR_FFMPEG_INSTALL_COMMAND);
    setCopyState(ok ? "copied" : "failed");
    if (resetTimerRef.current !== null) {
      clearTimeout(resetTimerRef.current);
    }
    resetTimerRef.current = setTimeout(() => {
      setCopyState("idle");
      resetTimerRef.current = null;
    }, 2000);
  }, []);

  if (!shouldSurfaceHdrPolicyNotice(policy)) {
    return null;
  }

  // policy is narrowed by the predicate above; reaffirm for TS
  const warning = policy?.warning ?? null;
  const copyLabel =
    copyState === "copied"
      ? t("hdrPolicyNoticeCopied")
      : copyState === "failed"
        ? t("hdrPolicyNoticeCopyFailed")
        : t("hdrPolicyNoticeCopyBtn");

  return (
    <div
      className="mt-2 flex flex-col gap-2 rounded-md border border-[var(--amber-9)]/40 bg-[color-mix(in_srgb,var(--amber-9)_10%,transparent)] px-3 py-2.5"
      role="status"
      aria-live="polite"
      data-testid="hdr-policy-notice"
    >
      <div className="flex items-start gap-2">
        <Warning
          size={16}
          weight="fill"
          className="mt-0.5 shrink-0 text-[var(--amber-11)]"
          aria-hidden
        />
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold text-[var(--fl-text-primary)]">
            {t("hdrPolicyNoticeTitle")}
          </p>
          <p className="fl-caption mt-0.5 max-w-prose text-[var(--fl-text-secondary)]">
            {t("hdrPolicyNoticeBody")}
          </p>
          {warning ? (
            <p className="fl-caption mt-1 max-w-prose text-[var(--fl-text-tertiary)]">
              {t("hdrPolicyNoticeDetailLabel")}
              <span className="ml-1">{warning}</span>
            </p>
          ) : null}
        </div>
      </div>

      <div className="flex flex-col gap-2 border-t border-white/10 pt-2">
        <p className="fl-caption text-[var(--fl-text-tertiary)]">
          {t("hdrPolicyNoticeInstallLead")}
        </p>
        <pre
          className="fl-log max-h-none overflow-x-auto whitespace-pre-wrap break-all text-xs"
          data-testid="hdr-policy-notice-command"
        >
          {HDR_FFMPEG_INSTALL_COMMAND}
        </pre>
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            className="fl-btn-secondary"
            onClick={() => void handleCopy()}
            aria-label={t("hdrPolicyNoticeCopyAria")}
            data-testid="hdr-policy-notice-copy-btn"
          >
            <Copy size={14} weight="bold" aria-hidden className="mr-1.5" />
            {copyLabel}
          </button>
          {onOpenFixtureDoc ? (
            <button
              type="button"
              className="fl-btn-secondary"
              onClick={onOpenFixtureDoc}
              aria-label={t("hdrPolicyNoticeFixtureDocAria")}
              data-testid="hdr-policy-notice-doc-btn"
            >
              <Info size={14} weight="bold" aria-hidden className="mr-1.5" />
              {t("hdrPolicyNoticeFixtureDocBtn")}
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}
