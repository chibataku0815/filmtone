/**
 * @file Film Lab のプリセット選択行。
 * @description 右パネル幅に合わせて均等グリッドで並べるプリセット行です。不要な横スクロールを作らず、狭い幅では 2 列、広い幅では列数を増やして整列させます。
 */
"use client";

import { PRESET_BUTTONS, type PresetName } from "film-lab-core";

interface PresetBarProps {
  activePreset: PresetName | null;
  onPreset: (name: PresetName) => void;
}

export function PresetBar({ activePreset, onPreset }: PresetBarProps) {
  return (
    <div className="w-full min-w-0">
      <div className="grid w-full min-w-0 grid-cols-2 gap-2 @min-[420px]:grid-cols-3 @min-[640px]:grid-cols-4">
        {PRESET_BUTTONS.map(({ name, label, subtitle }) => (
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
      </div>
    </div>
  );
}
