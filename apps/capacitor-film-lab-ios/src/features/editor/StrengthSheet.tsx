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

import { useState } from "react";
import { ControlSlider } from "film-lab-ui";

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
  resetLabel: string;
  compareLabel: string;
  strengthLabel: string;
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
  resetLabel,
  compareLabel,
  strengthLabel,
  quickAxes,
  adjustDisclosureLabel,
}: StrengthSheetProps) {
  const [adjustOpen, setAdjustOpen] = useState(false);

  // unmount completely when closed so backdrop doesn't intercept taps
  // and so transitions reset cleanly when re-opened. Keep the wrapper
  // mounted for entrance animation by always rendering and toggling
  // pointer-events / opacity / translate via Tailwind.
  return (
    <div
      aria-hidden={!isOpen}
      className={[
        "fixed inset-0 z-50",
        isOpen ? "pointer-events-auto" : "pointer-events-none",
      ].join(" ")}
    >
      {/* Backdrop */}
      <button
        type="button"
        aria-label={resetLabel /* keep aria minimal: backdrop is decorative click target */}
        tabIndex={-1}
        onClick={onClose}
        className={[
          "fixed inset-0 bg-black/40 transition-opacity duration-200 ease-out",
          isOpen ? "opacity-100" : "opacity-0 pointer-events-none",
        ].join(" ")}
      />

      {/* Sheet */}
      <section
        role="dialog"
        aria-modal="true"
        aria-label={`${presetLabel} — ${strengthLabel}`}
        className={[
          "fixed bottom-0 left-0 right-0 max-h-[60vh] overflow-y-auto glass-panel border-t border-white/12 rounded-t-[28px] p-5 pb-8 pointer-events-auto transition-transform duration-200 ease-out",
          isOpen ? "translate-y-0" : "translate-y-full",
        ].join(" ")}
      >
        {/* Drag handle */}
        <div className="mx-auto h-1 w-10 rounded-full bg-white/24 mb-4" />

        {/* Header row */}
        <header className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex flex-col gap-1">
            <p className="section-header truncate">{presetLabel}</p>
            <CompareHoldButton
              label={compareLabel}
              onHoldStart={onCompareHoldStart}
              onHoldEnd={onCompareHoldEnd}
            />
          </div>
          <button
            type="button"
            onClick={onReset}
            className="text-[11px] text-[var(--text-base-70)] hover:text-white px-2 py-1 transition-colors"
          >
            {resetLabel}
          </button>
        </header>

        {/* Strength slider */}
        <div className="mt-5">
          <ControlSlider
            label={strengthLabel}
            value={strength}
            min={0}
            max={1}
            step={0.01}
            defaultValue={1}
            formatValue={formatStrengthPercent}
            onChange={onStrengthChange}
          />
        </div>

        {/* Adjust disclosure */}
        {quickAxes && (
          <div className="mt-5 border-t border-white/8 pt-4">
            <button
              type="button"
              onClick={() => setAdjustOpen((prev) => !prev)}
              aria-expanded={adjustOpen}
              className="flex items-center justify-between w-full text-left"
            >
              <span className="section-header">{adjustDisclosureLabel}</span>
              <span
                aria-hidden="true"
                className={[
                  "text-[var(--text-muted)] text-xs transition-transform duration-150 ease-out",
                  adjustOpen ? "rotate-180" : "rotate-0",
                ].join(" ")}
              >
                ▾
              </span>
            </button>

            <div
              className={[
                "grid transition-[grid-template-rows] duration-150 ease-out",
                adjustOpen ? "grid-rows-[1fr] mt-3" : "grid-rows-[0fr]",
              ].join(" ")}
            >
              <div className="overflow-hidden">
                <div className="space-y-3">
                  <ControlSlider
                    label={quickAxes.labels.filmCharacter}
                    value={quickAxes.filmCharacter}
                    min={-1}
                    max={1}
                    step={0.01}
                    defaultValue={0}
                    formatValue={formatSignedPercent}
                    onChange={(v) => quickAxes.onChange("filmCharacter", v)}
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
                  />
                </div>
              </div>
            </div>
          </div>
        )}
      </section>
    </div>
  );
}

interface CompareHoldButtonProps {
  label: string;
  onHoldStart?: () => void;
  onHoldEnd?: () => void;
}

function CompareHoldButton({ label, onHoldStart, onHoldEnd }: CompareHoldButtonProps) {
  return (
    <button
      type="button"
      onPointerDown={() => onHoldStart?.()}
      onPointerUp={() => onHoldEnd?.()}
      onPointerCancel={() => onHoldEnd?.()}
      onPointerLeave={() => onHoldEnd?.()}
      className="flex items-center gap-2 px-3 py-1.5 rounded-full border border-white/12 text-[10px] uppercase tracking-[0.12em] text-[var(--text-base-70)] active:bg-white/[0.08] active:text-white select-none touch-none"
    >
      {label}
    </button>
  );
}
