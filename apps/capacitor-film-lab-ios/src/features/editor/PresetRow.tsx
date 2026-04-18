/**
 * @file 横スクロールのプリセットカード行（M2）。
 * @description
 * 概要: モバイル UI 第二章のプリセットセレクター。横スクロールでカードを並べ、
 *       1 タップで切替、選択中プリセットの再タップで親側の Strength sheet を開く。
 * 主な仕様:
 * - サムネイルはプレースホルダー（M2 では実画像レンダーをまだ行わない）。
 * - 選択中はサムネイルにアンバーリングのみを掛ける。
 * - role="radiogroup" + 各カード role="radio" でアクセシビリティを担保。
 * 制限事項:
 * - スワイプジェスチャの慣性スクロールはブラウザ任せ（CSS overflow-x-auto）。
 * - 実プレビュー画像差し込みは M2 ポリッシュ／将来タスク。
 */

import type { PresetName } from "film-lab-core";

interface PresetRowItem {
  name: PresetName;
  label: string;
  subtitle?: string;
}

interface PresetRowProps {
  activePreset: PresetName;
  presets: ReadonlyArray<PresetRowItem>;
  /** 別のプリセットを選んだとき（親が適用） */
  onPresetSelect: (name: PresetName) => void;
  /** 選択中プリセットを再タップしたとき（親が Strength シートを開く） */
  onPresetReTap: (name: PresetName) => void;
  ariaLabel: string;
}

export function PresetRow({
  activePreset,
  presets,
  onPresetSelect,
  onPresetReTap,
  ariaLabel,
}: PresetRowProps) {
  return (
    <div
      role="radiogroup"
      aria-label={ariaLabel}
      className="flex gap-2 overflow-x-auto pb-2 px-1 -mx-1 [scrollbar-width:none] [-webkit-overflow-scrolling:touch] [&::-webkit-scrollbar]:hidden snap-x snap-mandatory"
    >
      {presets.map((preset) => {
        const isActive = preset.name === activePreset;
        return (
          <PresetCard
            key={preset.name}
            preset={preset}
            isActive={isActive}
            onTap={() => {
              if (isActive) {
                onPresetReTap(preset.name);
              } else {
                onPresetSelect(preset.name);
              }
            }}
          />
        );
      })}
    </div>
  );
}

interface PresetCardProps {
  preset: PresetRowItem;
  isActive: boolean;
  onTap: () => void;
}

function PresetCard({ preset, isActive, onTap }: PresetCardProps) {
  const handleKeyDown = (event: React.KeyboardEvent<HTMLButtonElement>) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      onTap();
    }
  };

  return (
    <button
      type="button"
      role="radio"
      aria-checked={isActive}
      aria-label={preset.subtitle ? `${preset.label} — ${preset.subtitle}` : preset.label}
      tabIndex={0}
      onClick={onTap}
      onKeyDown={handleKeyDown}
      className="relative shrink-0 w-[88px] min-h-[44px] flex flex-col gap-1.5 items-center snap-start outline-none focus-visible:ring-2 focus-visible:ring-[var(--accent-amber1)]/65 focus-visible:rounded-2xl"
    >
      <div
        className={[
          "aspect-square w-[88px] rounded-2xl glass-panel border border-white/12 flex items-center justify-center text-[11px] text-white/80 bg-[#1a1a1a] transition-shadow",
          isActive
            ? "ring-2 ring-[var(--accent-amber1)]/65 ring-offset-2 ring-offset-black/40"
            : "",
        ]
          .filter(Boolean)
          .join(" ")}
      >
        <span className="px-1 text-center leading-tight line-clamp-2">
          {preset.label}
        </span>
      </div>
      <span className="text-[10px] text-[var(--text-base-70)] line-clamp-1 max-w-[88px] text-center">
        {preset.label}
      </span>
    </button>
  );
}
