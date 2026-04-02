/**
 * @file フィルムプリセットを検索しながら選ぶセレクト。
 * @description
 * 概要: プリセット数が増えても 1 つの入口で選べるようにする、検索付きのプリセットピッカーです。
 * 主な仕様:
 * - ボタンを押すと候補一覧を開きます。
 * - 入力欄に名前や雰囲気の言葉を入れると候補を絞り込めます。
 * - 候補を選ぶと一覧を閉じ、選んだプリセットを親へ返します。
 * 制限事項:
 * - 検索対象は `PRESET_BUTTONS` に入っている名前・表示名・短い説明です。
 * - 長い一覧の仮想スクロールはまだ行いません。
 */
"use client";

import { Fragment, useEffect, useMemo, useRef, useState } from "react";
import { PRESET_BUTTONS, type PresetName } from "film-lab-core";
import {
  filterPresetRowsForSearch,
  orderPresetButtonsForSurface,
  type PresetButtonRow,
} from "./presetSurfaceOrdering";

/**
 * 検索付きプリセットセレクトが受け取る設定です。
 */
interface PresetSearchSelectProps {
  /** いま選ばれているプリセット名です。 */
  activePreset: PresetName | null;
  /** 候補が選ばれたときに親へ返します。 */
  onPreset: (name: PresetName) => void;
  /** ボタンの読み上げ用ラベルです。 */
  triggerAriaLabel: string;
  /** 検索ボックスのプレースホルダーです。 */
  searchPlaceholder: string;
  /** 候補が 0 件のときに見せる短い文です。 */
  emptyLabel: string;
}

/**
 * トリガーに出す表示用メタを返します。
 * @param presetName いま選ばれているプリセット名（まだ無いときは null）
 * @param orderedRows surface 用に並べ替え済みの一覧（先頭をフォールバックに使う）
 */
function getPresetMetaForTrigger(
  presetName: PresetName | null,
  orderedRows: readonly PresetButtonRow[],
): PresetButtonRow {
  const fallbackRow = orderedRows[0];
  if (!fallbackRow) {
    throw new Error(
      "getPresetMetaForTrigger: orderedRows が空です。PRESET_BUTTONS に最低 1 件必要です。",
    );
  }
  if (presetName == null) {
    return fallbackRow;
  }
  return (
    orderedRows.find((presetButton) => presetButton.name === presetName) ??
    fallbackRow
  );
}

/**
 * 検索用の文字列を小文字 1 本にまとめます。
 * @param {typeof PRESET_BUTTONS[number]} presetButton 絞り込み対象のプリセットです。
 * @returns {string} 名前・表示名・説明を結合した検索文字列です。
 */
function buildSearchText(presetButton: (typeof PRESET_BUTTONS)[number]): string {
  return [
    presetButton.name,
    presetButton.label,
    presetButton.subtitle,
  ]
    .join(" ")
    .toLowerCase();
}

/**
 * プリセットを検索しながら 1 つ選ぶ UI です。
 * @param {PresetSearchSelectProps} props 表示と選択に必要な設定です。
 */
export function PresetSearchSelect({
  activePreset,
  onPreset,
  triggerAriaLabel,
  searchPlaceholder,
  emptyLabel,
}: PresetSearchSelectProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const rootRef = useRef<HTMLDivElement | null>(null);
  const searchInputRef = useRef<HTMLInputElement | null>(null);

  const orderedPresetSurfaceRows = useMemo(
    () => orderPresetButtonsForSurface(PRESET_BUTTONS),
    [],
  );

  const activePresetMeta = getPresetMetaForTrigger(
    activePreset,
    orderedPresetSurfaceRows,
  );

  const filteredPresetButtons = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.length === 0) {
      return orderedPresetSurfaceRows;
    }

    return filterPresetRowsForSearch(PRESET_BUTTONS, (presetButton) =>
      buildSearchText(presetButton).includes(normalizedQuery),
    );
  }, [searchQuery, orderedPresetSurfaceRows]);

  useEffect(() => {
    if (!isOpen) {
      setSearchQuery("");
      return;
    }

    searchInputRef.current?.focus();
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen) return;

    /**
     * パネルの外を押したら閉じます。
     * @param {MouseEvent} event クリックイベントです。
     */
    function handleDocumentMouseDown(event: MouseEvent) {
      if (!rootRef.current) return;
      if (rootRef.current.contains(event.target as Node)) return;
      setIsOpen(false);
    }

    document.addEventListener("mousedown", handleDocumentMouseDown);
    return () => {
      document.removeEventListener("mousedown", handleDocumentMouseDown);
    };
  }, [isOpen]);

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        data-testid="film-lab-preset-select-trigger"
        aria-label={triggerAriaLabel}
        aria-expanded={isOpen}
        className="flex min-h-[44px] w-full items-center justify-between gap-3 rounded-xl border border-white/[0.08] bg-white/[0.03] px-3 py-2 text-left transition-colors hover:border-white/[0.12] hover:bg-white/[0.05] [@media(pointer:coarse)]:min-h-[44px]"
        onClick={() => setIsOpen((prev) => !prev)}
      >
        <span className="min-w-0">
          <span className="block font-mono text-[11px] tracking-wide text-white/90">
            {activePresetMeta.label}
          </span>
          <span className="mt-1 block text-[10px] leading-tight text-white/42">
            {activePresetMeta.subtitle}
          </span>
        </span>
        <span className="shrink-0 text-white/35" aria-hidden>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
            <path
              d={isOpen ? "M7 14.5 12 9.5 17 14.5" : "M7 9.5 12 14.5 17 9.5"}
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </span>
      </button>

      {isOpen ? (
        <div className="mt-2 rounded-xl border border-white/[0.08] bg-[#0d0d0d]/95 p-2 shadow-[0_20px_50px_rgba(0,0,0,0.35)] backdrop-blur-xl">
          <label className="block">
            <span className="sr-only">{searchPlaceholder}</span>
            <input
              ref={searchInputRef}
              type="search"
              data-testid="film-lab-preset-search-input"
              value={searchQuery}
              placeholder={searchPlaceholder}
              className="w-full rounded-lg border border-white/[0.08] bg-white/[0.03] px-3 py-2 text-sm text-white outline-none transition-colors placeholder:text-white/28 focus:border-[var(--accent-amber1)]/40 focus:bg-white/[0.05]"
              onChange={(event) => setSearchQuery(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Escape") {
                  event.preventDefault();
                  setIsOpen(false);
                }
              }}
            />
          </label>

          <div className="film-lab-preset-search-scroll mt-2 max-h-64 overflow-y-auto pr-1">
            {filteredPresetButtons.length === 0 ? (
              <p className="rounded-lg px-3 py-2 text-sm text-white/45">
                {emptyLabel}
              </p>
            ) : (
              <div className="flex flex-col gap-1">
                {filteredPresetButtons.map((presetButton, itemIndex) => {
                  const isSelected = activePresetMeta.name === presetButton.name;
                  const previousRow =
                    itemIndex > 0 ? filteredPresetButtons[itemIndex - 1] : null;
                  const showCategoryDivider =
                    previousRow != null &&
                    previousRow.category !== presetButton.category;

                  return (
                    <Fragment key={presetButton.name}>
                      {showCategoryDivider ? (
                        <div
                          role="separator"
                          aria-orientation="horizontal"
                          className="my-1 border-t border-white/[0.08]"
                        />
                      ) : null}
                    <button
                      type="button"
                      role="option"
                      aria-selected={isSelected}
                      data-testid={`film-lab-preset-${presetButton.name}`}
                      className={`flex min-h-[44px] w-full items-center justify-between gap-3 rounded-lg px-3 py-2 text-left transition-colors [@media(pointer:coarse)]:min-h-[44px] ${
                        isSelected
                          ? "bg-[var(--accent-amber1)]/14 text-[var(--accent-amber1)]"
                          : "text-white/72 hover:bg-white/[0.05] hover:text-white"
                      }`}
                      onClick={() => {
                        onPreset(presetButton.name);
                        setIsOpen(false);
                      }}
                    >
                      <span className="min-w-0">
                        <span className="block font-mono text-[11px] tracking-wide">
                          {presetButton.label}
                        </span>
                        <span className="mt-1 block text-[10px] leading-tight text-white/40">
                          {presetButton.subtitle}
                        </span>
                      </span>
                      <span
                        className={`shrink-0 ${
                          isSelected ? "text-[var(--accent-amber1)]" : "text-transparent"
                        }`}
                        aria-hidden
                      >
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                          <path
                            d="m5 12 4.2 4.2L19 6.5"
                            stroke="currentColor"
                            strokeWidth="2"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                          />
                        </svg>
                      </span>
                    </button>
                    </Fragment>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}
