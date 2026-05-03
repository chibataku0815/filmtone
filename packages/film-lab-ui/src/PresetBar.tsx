/**
 * @file Film Lab の Base Look 選択行。
 * @description
 * 概要: 右パネル幅に合わせて均等グリッドで並べる Base Look 行です。
 * 主な仕様:
 * - `film-lab-core` の `BASE_LOOK_BUTTONS` を **カテゴリ順**（Film Stock → Look → Utility）で並べます。
 * - カテゴリが変わるところにだけ、横いっぱいの薄い区切り線を入れます（大きな見出しは付けません）。
 * 制限事項:
 * - 狭い幅では 2 列、広い幅では列数を増やして整列します。
 * - Quick / Pro のパネル全体の作り直しは life#95 の仕事で、ここではしません。
 */
"use client";

import { Fragment, useMemo } from "react";
import { BASE_LOOK_BUTTONS, type BaseLookName } from "film-lab-core";
import { orderPresetButtonsForSurface } from "./presetSurfaceOrdering";

/**
 * グリッド内の Base Look ボタン行に渡す props です。
 */
interface PresetBarProps {
  /** いま選ばれている Base Look 名です。 */
  activePreset: BaseLookName | null;
  /** 候補が押されたときに親へ返します。 */
  onPreset: (name: BaseLookName) => void;
}

/**
 * カテゴリごとにまとめた塊を返します（順序は surface 用の並びのまま）。
 * @param orderedRows `orderPresetButtonsForSurface` 済みの配列
 */
function chunkPresetRowsByCategory(
  orderedRows: ReturnType<typeof orderPresetButtonsForSurface>,
) {
  const chunks: {
    category: (typeof orderedRows)[number]["category"];
    rows: typeof orderedRows;
  }[] = [];

  for (const row of orderedRows) {
    const lastChunk = chunks[chunks.length - 1];
    if (!lastChunk || lastChunk.category !== row.category) {
      chunks.push({ category: row.category, rows: [row] });
    } else {
      lastChunk.rows.push(row);
    }
  }

  return chunks;
}

/**
 * 右パネル用のプリセットグリッドです。
 * @param props 表示と選択に必要な設定です。
 */
export function PresetBar({ activePreset, onPreset }: PresetBarProps) {
  const presetCategoryChunks = useMemo(() => {
    const orderedRows = orderPresetButtonsForSurface(BASE_LOOK_BUTTONS);
    return chunkPresetRowsByCategory(orderedRows);
  }, []);

  return (
    <div className="w-full min-w-0">
      <div className="grid w-full min-w-0 grid-cols-2 gap-2 @min-[420px]:grid-cols-3 @min-[640px]:grid-cols-4">
        {presetCategoryChunks.map((chunk, chunkIndex) => (
          <Fragment key={chunk.category}>
            {chunkIndex > 0 ? (
              <div
                role="separator"
                aria-orientation="horizontal"
                className="col-span-full my-1 border-t border-white/[0.08]"
              />
            ) : null}
            {chunk.rows.map(({ name, label, subtitle }) => (
              <button
                key={name}
                type="button"
                data-testid={`film-lab-preset-${name}`}
                onClick={() => onPreset(name)}
                className={`flex min-h-[44px] w-full min-w-0 flex-col items-start justify-center rounded-2xl px-3 py-2 text-left transition-all duration-200 md:min-h-0 [@media(pointer:coarse)]:min-h-[44px] ${
                  activePreset === name
                    ? "bg-[var(--accent-amber1)]/14 text-[var(--accent-amber1)] ring-1 ring-[var(--accent-amber1)]/30"
                    : "bg-white/5 text-white/55 hover:bg-white/8 hover:text-white/75"
                }`}
              >
                <span className="w-full break-words font-mono text-[10px] tracking-wide">
                  {label}
                </span>
                <span className="mt-1 w-full break-words text-[10px] leading-tight text-white/38">
                  {subtitle}
                </span>
              </button>
            ))}
          </Fragment>
        ))}
      </div>
    </div>
  );
}
