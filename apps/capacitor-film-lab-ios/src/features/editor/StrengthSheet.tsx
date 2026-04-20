/**
 * @file Strength 調整用ボトムシート（M2）。
 * @description
 * 概要: プリセット適用後の Strength（強度）と Quick 3 軸を 1 シートで触れる UI。
 *       選択中プリセットの再タップで開き、Compare（長押し比較）と Reset を備える。
 * 主な仕様:
 * - HTML/CSS の純粋なボトムシート（M3+ で必要なら Capacitor 経由のネイティブシートに差し替え）。
 * - medium detent: viewport の約 60vh まで。背景タップでクローズ。
 * - Adjust（filmCharacter / era / dynamics）はディスクロージャで折り畳み、デフォルトは閉。
 * 制限事項:
 * - スワイプダウンで閉じるジェスチャは未実装（背景タップ + 上部 Close 想定）。
 * - ESC キーやブラウザ専用ハンドラは付けない（Capacitor WebView 想定）。
 */

import { useEffect, useRef, useState } from "react";
import { ControlSlider } from "film-lab-ui";
import {
  ChevronDownIcon,
  CompareIcon,
} from "@/components/FilmtoneIcons";

type QuickAxisKey = "filmCharacter" | "era" | "dynamics";

interface QuickAxes {
  filmCharacter: number;
  era: number;
  dynamics: number;
  onChange: (axis: QuickAxisKey, v: number) => void;
  labels: { filmCharacter: string; era: string; dynamics: string };
}

interface StrengthSheetProps {
  isOpen: boolean;
  onClose: () => void;
  /** シートヘッダに出すプリセット表示名 */
  presetLabel: string;
  /** 0..1 */
  strength: number;
  onStrengthChange: (next: number) => void;
  /** Compare 長押し開始 */
  onCompareHoldStart?: () => void;
  /** Compare 長押し解除（pointerup / pointercancel 共通） */
  onCompareHoldEnd?: () => void;
  onReset: () => void;
  closeLabel: string;
  resetLabel: string;
  compareLabel: string;
  strengthLabel: string;
  quickHint: string;
  sliderResetHint: string;
  /** Adjust（Quick 3）ディスクロージャ。未指定なら非表示 */
  quickAxes?: QuickAxes;
  adjustDisclosureLabel: string;
}

function formatStrengthPercent(value: number): string {
  return `${Math.round(value * 100)}%`;
}

function formatSignedPercent(value: number): string {
  const sign = value > 0 ? "+" : "";
  return `${sign}${Math.round(value * 100)}%`;
}

export function StrengthSheet({
  isOpen,
  onClose,
  presetLabel,
  strength,
  onStrengthChange,
  onCompareHoldStart,
  onCompareHoldEnd,
  onReset,
  closeLabel,
  resetLabel,
  compareLabel,
  strengthLabel,
  quickHint,
  sliderResetHint,
  quickAxes,
  adjustDisclosureLabel,
}: StrengthSheetProps) {
  const [adjustOpen, setAdjustOpen] = useState(false);
  const [isMounted, setIsMounted] = useState(isOpen);
  const activeQuickAxes = quickAxes
    ? [
        {
          key: "filmCharacter",
          label: quickAxes.labels.filmCharacter,
          value: quickAxes.filmCharacter,
        },
        { key: "era", label: quickAxes.labels.era, value: quickAxes.era },
        {
          key: "dynamics",
          label: quickAxes.labels.dynamics,
          value: quickAxes.dynamics,
        },
      ].filter((entry) => Math.abs(entry.value) >= 0.01)
    : [];

  useEffect(() => {
    if (isOpen) {
      setIsMounted(true);
      return undefined;
    }

    const timeoutId = window.setTimeout(() => {
      setIsMounted(false);
    }, 220);

    return () => {
      window.clearTimeout(timeoutId);
    };
  }, [isOpen]);

  if (!isMounted) {
    return null;
  }

  return (
    <div
      aria-hidden={!isOpen}
      className={[
        "fixed inset-0 z-50 isolate",
        isOpen ? "pointer-events-auto" : "pointer-events-none",
      ].join(" ")}
    >
      {/* Backdrop */}
      <div
        aria-hidden="true"
        onClick={onClose}
        className={[
          "absolute inset-0 bg-black/46 backdrop-blur-[2px] transition-opacity duration-200 ease-out",
          isOpen ? "opacity-100" : "opacity-0",
        ].join(" ")}
      />

      {/* Sheet */}
      <div className="absolute inset-0 flex items-end">
        <section
          role="dialog"
          aria-modal="true"
          aria-label={`${presetLabel} — ${strengthLabel}`}
          className={[
            "relative z-10 max-h-[76vh] w-full overflow-y-auto overscroll-contain squircle-top-xl px-5 pt-4 pb-[calc(env(safe-area-inset-bottom,0px)+20px)] pointer-events-auto liquid-panel-strong transition-transform duration-200 ease-out",
            isOpen ? "translate-y-0" : "translate-y-full",
          ].join(" ")}
          style={{
            WebkitOverflowScrolling: "touch",
            touchAction: "pan-y",
          }}
        >
          <div className="-mx-5 sticky top-0 z-10 mb-5 bg-[linear-gradient(180deg,rgba(14,14,14,0.96),rgba(14,14,14,0.88)_72%,transparent)] px-5 pb-4 pt-1 backdrop-blur-xl">
            <div className="mx-auto mb-4 h-1.5 w-12 rounded-full bg-white/22" />

            <header className="flex items-start justify-between gap-4">
              <div className="min-w-0 flex flex-col gap-2">
                <h2 className="truncate text-[1.6rem] font-semibold tracking-[-0.03em] text-white">
                  {presetLabel}
                </h2>
                <CompareHoldButton
                  label={compareLabel}
                  onHoldStart={onCompareHoldStart}
                  onHoldEnd={onCompareHoldEnd}
                />
              </div>
              <div className="flex shrink-0 items-center gap-1">
                <button
                  type="button"
                  onClick={onReset}
                  className="min-h-[44px] px-3 text-sm font-medium text-white/60 active:text-white"
                >
                  {resetLabel}
                </button>
                <button
                  type="button"
                  onClick={onClose}
                  aria-label={closeLabel}
                  className="min-h-[44px] px-3 text-sm font-medium text-[var(--accent-amber1)] active:opacity-70"
                >
                  {closeLabel}
                </button>
              </div>
            </header>
          </div>

          {/* Strength slider */}
          <div className="mt-5 squircle-md bg-white/[0.02] p-4">
            <ControlSlider
              label={strengthLabel}
              value={strength}
              min={0}
              max={1}
              step={0.01}
              defaultValue={1}
              formatValue={formatStrengthPercent}
              onChange={onStrengthChange}
              labelResetHint={sliderResetHint}
            />
          </div>

          {/* Adjust disclosure */}
          {quickAxes && (
            <div className="mt-5 squircle-md bg-white/[0.02] p-4">
              <button
                type="button"
                onClick={() => setAdjustOpen((prev) => !prev)}
                aria-expanded={adjustOpen}
                className="flex w-full items-center justify-between gap-3 text-left"
              >
                <span className="editor-kicker">{adjustDisclosureLabel}</span>
                <ChevronDownIcon
                  aria-hidden="true"
                  className={[
                    "h-5 w-5 shrink-0 text-white/54 transition-transform duration-150 ease-out",
                    adjustOpen ? "rotate-180" : "rotate-0",
                  ].join(" ")}
                />
              </button>

              <div className="mt-4 flex flex-wrap gap-2">
                {activeQuickAxes.length > 0 ? (
                  activeQuickAxes.map((entry) => (
                    <span key={entry.key} className="editor-chip">
                      {entry.label} {formatSignedPercent(entry.value)}
                    </span>
                  ))
                ) : (
                  <p className="text-sm leading-6 text-[var(--text-muted)]">
                    {quickHint}
                  </p>
                )}
              </div>

              <div
                className={[
                  "grid transition-[grid-template-rows] duration-150 ease-out",
                  adjustOpen ? "mt-4 grid-rows-[1fr]" : "grid-rows-[0fr]",
                ].join(" ")}
              >
                <div className="overflow-hidden">
                  <div className="space-y-3 pt-1">
                    <ControlSlider
                      label={quickAxes.labels.filmCharacter}
                      value={quickAxes.filmCharacter}
                      min={-1}
                      max={1}
                      step={0.01}
                      defaultValue={0}
                      formatValue={formatSignedPercent}
                      onChange={(v) => quickAxes.onChange("filmCharacter", v)}
                      labelResetHint={sliderResetHint}
                    />
                    <ControlSlider
                      label={quickAxes.labels.era}
                      value={quickAxes.era}
                      min={-1}
                      max={1}
                      step={0.01}
                      defaultValue={0}
                      formatValue={formatSignedPercent}
                      onChange={(v) => quickAxes.onChange("era", v)}
                      labelResetHint={sliderResetHint}
                    />
                    <ControlSlider
                      label={quickAxes.labels.dynamics}
                      value={quickAxes.dynamics}
                      min={-1}
                      max={1}
                      step={0.01}
                      defaultValue={0}
                      formatValue={formatSignedPercent}
                      onChange={(v) => quickAxes.onChange("dynamics", v)}
                      labelResetHint={sliderResetHint}
                    />
                  </div>
                </div>
              </div>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}

interface CompareHoldButtonProps {
  label: string;
  onHoldStart?: () => void;
  onHoldEnd?: () => void;
}

function CompareHoldButton({ label, onHoldStart, onHoldEnd }: CompareHoldButtonProps) {
  const activePointerIdRef = useRef<number | null>(null);

  const handlePointerDown = (event: React.PointerEvent<HTMLButtonElement>) => {
    if (activePointerIdRef.current !== null) return;
    activePointerIdRef.current = event.pointerId;
    try {
      event.currentTarget.setPointerCapture(event.pointerId);
    } catch {
      // ignore
    }
    onHoldStart?.();
  };

  const handlePointerEnd = (event: React.PointerEvent<HTMLButtonElement>) => {
    if (activePointerIdRef.current !== event.pointerId) return;
    try {
      event.currentTarget.releasePointerCapture(event.pointerId);
    } catch {
      // ignore
    }
    activePointerIdRef.current = null;
    onHoldEnd?.();
  };

  return (
    <button
      type="button"
      onPointerDown={handlePointerDown}
      onPointerUp={handlePointerEnd}
      onPointerCancel={handlePointerEnd}
      className="inline-flex min-h-[44px] items-center gap-2 squircle-pill border border-white/12 bg-white/[0.02] px-4 py-2 text-[11px] font-medium text-[var(--text-base-70)] active:bg-white/[0.08] active:text-white select-none touch-none"
    >
      <CompareIcon className="h-3.5 w-3.5" />
      {label}
    </button>
  );
}
