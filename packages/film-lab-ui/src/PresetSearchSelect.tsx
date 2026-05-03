/**
 * @file Look を検索しながら選ぶセレクト (Look Unification canonical)。
 * @description
 * 概要: Look の数が増えても 1 つの入口で選べるようにする、検索付きの Look ピッカー。
 * 主な仕様:
 * - ボタンを押すと候補一覧を開く。
 * - 入力欄に名前や雰囲気の言葉を入れると候補を絞り込める。
 * - 候補を選ぶと一覧を閉じ、選んだ Look を親へ返す。
 * 制限事項:
 * - 検索対象は `BASE_LOOK_BUTTONS`（`PRESET_BUTTONS` の Look-first alias）に入っている名前・表示名・短い説明。
 * - 長い一覧の仮想スクロールはまだ行わない。
 *
 * Backward compat: 旧 `PresetSearchSelect` / `PresetSearchSelectProps` は本ファイル末尾で
 * deprecated alias として再 export する。新しい consumer は `LookSearchSelect` を使う。
 */
"use client";

import { Fragment, useEffect, useMemo, useRef, useState } from "react";
import { BASE_LOOK_BUTTONS, type BaseLookName } from "film-lab-core";
import {
  filterPresetRowsForSearch,
  orderPresetButtonsForSurface,
  type PresetButtonRow,
} from "./presetSurfaceOrdering";

/**
 * 検索付き Look セレクトが受け取る設定。
 */
export interface LookSearchSelectProps {
  /** いま選ばれている Look 名。 */
  activeLook: BaseLookName | null;
  /** 候補が選ばれたときに親へ返す。 */
  onLook: (name: BaseLookName) => void;
  /** ボタンの読み上げ用ラベル。 */
  triggerAriaLabel: string;
  /** 検索ボックスのプレースホルダー。 */
  searchPlaceholder: string;
  /** 候補が 0 件のときに見せる短い文。 */
  emptyLabel: string;
}

/**
 * トリガーに出す表示用メタを返す。
 * @param lookName いま選ばれている Look 名（まだ無いときは null）
 * @param orderedRows surface 用に並べ替え済みの一覧（先頭をフォールバックに使う）
 */
function getLookMetaForTrigger(
  lookName: BaseLookName | null,
  orderedRows: readonly PresetButtonRow[],
): PresetButtonRow {
  const fallbackRow = orderedRows[0];
  if (!fallbackRow) {
    throw new Error(
      "getLookMetaForTrigger: orderedRows が空です。BASE_LOOK_BUTTONS に最低 1 件必要です。",
    );
  }
  if (lookName == null) {
    return fallbackRow;
  }
  return (
    orderedRows.find((lookButton) => lookButton.name === lookName) ??
    fallbackRow
  );
}

/**
 * 検索用の文字列を小文字 1 本にまとめる。
 * @param lookButton 絞り込み対象の Look。
 * @returns 名前・表示名・説明を結合した検索文字列。
 */
function buildSearchText(lookButton: (typeof BASE_LOOK_BUTTONS)[number]): string {
  return [
    lookButton.name,
    lookButton.label,
    lookButton.subtitle,
  ]
    .join(" ")
    .toLowerCase();
}

/**
 * Look を検索しながら 1 つ選ぶ UI (Look Unification canonical)。
 */
export function LookSearchSelect({
  activeLook,
  onLook,
  triggerAriaLabel,
  searchPlaceholder,
  emptyLabel,
}: LookSearchSelectProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const rootRef = useRef<HTMLDivElement | null>(null);
  const searchInputRef = useRef<HTMLInputElement | null>(null);

  const orderedLookSurfaceRows = useMemo(
    () => orderPresetButtonsForSurface(BASE_LOOK_BUTTONS),
    [],
  );

  const activeLookMeta = getLookMetaForTrigger(
    activeLook,
    orderedLookSurfaceRows,
  );

  const filteredLookButtons = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.length === 0) {
      return orderedLookSurfaceRows;
    }

    return filterPresetRowsForSearch(BASE_LOOK_BUTTONS, (lookButton) =>
      buildSearchText(lookButton).includes(normalizedQuery),
    );
  }, [searchQuery, orderedLookSurfaceRows]);

  useEffect(() => {
    if (!isOpen) {
      setSearchQuery("");
      return;
    }

    searchInputRef.current?.focus();
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen) return;

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
        data-testid="film-lab-look-select-trigger"
        aria-label={triggerAriaLabel}
        aria-expanded={isOpen}
        className="flex min-h-[44px] w-full items-center justify-between gap-3 rounded-xl border border-white/[0.08] bg-white/[0.03] px-3 py-2 text-left transition-colors hover:border-white/[0.12] hover:bg-white/[0.05] [@media(pointer:coarse)]:min-h-[44px]"
        onClick={() => setIsOpen((prev) => !prev)}
      >
        <span className="min-w-0">
          <span className="block font-mono text-[11px] tracking-wide text-white/90">
            {activeLookMeta.label}
          </span>
          <span className="mt-1 block text-[10px] leading-tight text-white/42">
            {activeLookMeta.subtitle}
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
              data-testid="film-lab-look-search-input"
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

          <div className="film-lab-look-search-scroll mt-2 max-h-64 overflow-y-auto pr-1">
            {filteredLookButtons.length === 0 ? (
              <p className="rounded-lg px-3 py-2 text-sm text-white/45">
                {emptyLabel}
              </p>
            ) : (
              <div className="flex flex-col gap-1">
                {filteredLookButtons.map((lookButton, itemIndex) => {
                  const isSelected = activeLookMeta.name === lookButton.name;
                  const previousRow =
                    itemIndex > 0 ? filteredLookButtons[itemIndex - 1] : null;
                  const showCategoryDivider =
                    previousRow != null &&
                    previousRow.category !== lookButton.category;

                  return (
                    <Fragment key={lookButton.name}>
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
                      data-testid={`film-lab-look-${lookButton.name}`}
                      className={`flex min-h-[44px] w-full items-center justify-between gap-3 rounded-lg px-3 py-2 text-left transition-colors [@media(pointer:coarse)]:min-h-[44px] ${
                        isSelected
                          ? "bg-[var(--accent-amber1)]/14 text-[var(--accent-amber1)]"
                          : "text-white/72 hover:bg-white/[0.05] hover:text-white"
                      }`}
                      onClick={() => {
                        onLook(lookButton.name);
                        setIsOpen(false);
                      }}
                    >
                      <span className="min-w-0">
                        <span className="block font-mono text-[11px] tracking-wide">
                          {lookButton.label}
                        </span>
                        <span className="mt-1 block text-[10px] leading-tight text-white/40">
                          {lookButton.subtitle}
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

// === Look Unification — deprecated PresetSearchSelect alias ===
// 旧 consumer 互換のため、`PresetSearchSelect` / `PresetSearchSelectProps` を
// 同一実体への wrapper / type alias として残す。新しい consumer は
// `LookSearchSelect` / `LookSearchSelectProps` を使う。

/** @deprecated Use `LookSearchSelectProps`. */
export interface PresetSearchSelectProps {
  /** @deprecated Use `activeLook`. */
  activePreset: BaseLookName | null;
  /** @deprecated Use `onLook`. */
  onPreset: (name: BaseLookName) => void;
  triggerAriaLabel: string;
  searchPlaceholder: string;
  emptyLabel: string;
}

/** @deprecated Use `LookSearchSelect`. */
export function PresetSearchSelect({
  activePreset,
  onPreset,
  triggerAriaLabel,
  searchPlaceholder,
  emptyLabel,
}: PresetSearchSelectProps) {
  return (
    <LookSearchSelect
      activeLook={activePreset}
      onLook={onPreset}
      triggerAriaLabel={triggerAriaLabel}
      searchPlaceholder={searchPlaceholder}
      emptyLabel={emptyLabel}
    />
  );
}
