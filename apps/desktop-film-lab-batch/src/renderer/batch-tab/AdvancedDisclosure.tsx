/**
 * @fileoverview Advanced disclosure（詳細設定）— proxy cache / preview-export bridge を格納
 *
 * @description
 * DaVinci Deliver 型の disclosure triangle。日常使用で画面ノイズをゼロにするため既定閉。
 * native `<details>` を使って state 管理をブラウザに委ねる（Filmtone 全体の frost material を維持）。
 *
 * @limitations
 * - open 状態を localStorage に永続化しない（v1 スコープ外、既定は常に閉）
 * - 内部コンテンツは frost material を継承、card 積層禁止（rulebook R1.5）
 */

import { CaretDown, Info } from "@phosphor-icons/react";
import { useLocale, useTranslations } from "next-intl";
import { HelpHint } from "./HelpHint";
import type { VideoPreviewProxyCacheInfo } from "../desktop-api";

function formatBytes(locale: string, value: number): string {
  if (!Number.isFinite(value) || value <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let unitIndex = 0;
  let current = value;
  while (current >= 1024 && unitIndex < units.length - 1) {
    current /= 1024;
    unitIndex += 1;
  }
  const digits = current >= 10 || unitIndex === 0 ? 0 : 1;
  return `${new Intl.NumberFormat(locale === "ja" ? "ja-JP" : locale, {
    maximumFractionDigits: digits,
    minimumFractionDigits: digits,
  }).format(current)} ${units[unitIndex]}`;
}

export type PreviewBridgeLines = {
  tone: "neutral" | "caution";
  previewLine: string;
  exportLine: string;
};

export type AdvancedDisclosureProps = {
  /** @description プレビューと書き出しの関係（存在時のみ 1 行プレーンテキストで表示） */
  previewExportBridge: PreviewBridgeLines | null;
  /** @description proxy cache 情報（null 時は読込中） */
  proxyCacheInfo: VideoPreviewProxyCacheInfo | null;
  /** @description purge 処理中フラグ */
  isPurgingProxyCache: boolean;
  /** @description 実行中フラグ（true 時は操作不可） */
  running: boolean;
  /** @description purge ハンドラ */
  onPurgeProxyCache: () => void | Promise<void>;
};

/**
 * @description 日常使用では存在を意識させない管理機能のコンテナ。
 */
export function AdvancedDisclosure(props: AdvancedDisclosureProps) {
  const {
    previewExportBridge,
    proxyCacheInfo,
    isPurgingProxyCache,
    running,
    onPurgeProxyCache,
  } = props;
  const t = useTranslations("film-lab.desktop.batch");
  const locale = useLocale();

  const proxyCacheSummary =
    proxyCacheInfo == null
      ? t("proxyCacheSummaryLoading")
      : t("proxyCacheSummary", {
          entries: String(proxyCacheInfo.entryCount),
          totalSize: formatBytes(locale, proxyCacheInfo.totalBytes),
        });

  return (
    <details className="fl-disclosure">
      <summary className="fl-disclosure-summary">
        <CaretDown
          className="fl-disclosure-caret shrink-0 text-[var(--fl-text-tertiary)]"
          size={14}
          aria-hidden
        />
        <span className="text-sm font-medium text-[var(--fl-text-primary)]">
          {t("advancedDisclosureTitle")}
        </span>
      </summary>
      <div className="flex flex-col gap-4 pt-3">
        {previewExportBridge ? (
          <div className="flex items-start gap-2">
            <Info
              className={`mt-0.5 shrink-0 ${
                previewExportBridge.tone === "caution"
                  ? "text-[var(--amber-11)]"
                  : "text-[var(--fl-text-tertiary)]"
              }`}
              size={14}
              aria-hidden
            />
            <div className="min-w-0 flex-1">
              <p className="fl-caption leading-relaxed text-[var(--fl-text-secondary)]">
                {previewExportBridge.previewLine}
              </p>
              <p className="fl-caption mt-1 leading-relaxed text-[var(--fl-text-secondary)]">
                {previewExportBridge.exportLine}
              </p>
            </div>
          </div>
        ) : null}

        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-1.5">
            <p className="text-sm font-medium text-[var(--fl-text-primary)]">
              {t("proxyCacheTitle")}
            </p>
            <HelpHint
              tip={t("tipProxyCache")}
              assistiveLabel={t("proxyCacheHintAria")}
            />
          </div>
          <p className="fl-caption text-[var(--fl-text-secondary)]">
            {proxyCacheSummary}
          </p>
          <button
            type="button"
            className="fl-btn-destructive self-start"
            disabled={running || isPurgingProxyCache}
            onClick={() => void onPurgeProxyCache()}
          >
            {isPurgingProxyCache
              ? t("proxyCachePurgingBtn")
              : t("proxyCacheClearBtn")}
          </button>
        </div>
      </div>
    </details>
  );
}
