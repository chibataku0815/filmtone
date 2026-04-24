/**
 * @fileoverview FFmpeg HDR capability gap inline notice.
 *
 * @description
 * When the HDR preparation policy reports `reason === "ffmpeg-missing-hdr-filters"`
 * (S-4 capability probe in `electron/ffmpeg-capability-probe.ts`), the renderer
 * previously surfaced only an opaque log line buried in the export log.
 *
 * This component renders an inline, non-blocking callout right next to the
 * video source controls so that the user can see the practical consequence:
 *   1. The clip is HDR.
 *   2. This environment cannot make a reliable SDR conversion automatically.
 *   3. Export can continue, but color/brightness may differ in other apps.
 *
 * It does NOT block export — SDR content still exports fine; HDR content is
 * deferred to the existing "defer-unknown" policy path.
 *
 * This component is intentionally agnostic of the export trigger — it watches
 * the policy object passed by App.tsx and renders only when the capability-
 * gated variant is active.
 */

import { Warning } from "@phosphor-icons/react";
import { useTranslations } from "next-intl";
import type { HdrPreparationPolicy } from "./desktop-api";

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

export type HdrPolicyNoticeProps = {
  policy: HdrPreparationPolicy | null | undefined;
  /**
   * @description Deprecated compatibility prop. The user-facing notice no
   * longer links to internal fixture docs, but older call sites may still pass
   * the handler until their props are cleaned up.
   */
  onOpenFixtureDoc?: () => void;
};

/**
 * @description Inline, non-blocking callout shown near the video source
 * controls when the ffmpeg build lacks HDR linearization filters. Renders
 * nothing for any other policy reason (including SDR sources).
 */
export function HdrPolicyNotice(props: HdrPolicyNoticeProps) {
  const { policy } = props;
  const t = useTranslations("film-lab.desktop.batch");

  if (!shouldSurfaceHdrPolicyNotice(policy)) {
    return null;
  }

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
        </div>
      </div>
    </div>
  );
}
