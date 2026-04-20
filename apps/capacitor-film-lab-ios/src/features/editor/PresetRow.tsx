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

type PresetCategory = "filmStock" | "look" | "utility";

interface PresetRowItem {
  name: PresetName;
  label: string;
  subtitle?: string;
  category: PresetCategory;
}

interface PresetRowProps {
  activePreset: PresetName;
  presets: ReadonlyArray<PresetRowItem>;
  /** 別のプリセットを選んだとき（親が適用） */
  onPresetSelect: (name: PresetName) => void;
  /** 選択中プリセットを再タップしたとき（親が Strength シートを開く） */
  onPresetReTap: (name: PresetName) => void;
  ariaLabel: string;
  activeHint: string;
  categoryLabels: Record<PresetCategory, string>;
}

export function PresetRow({
  activePreset,
  presets,
  onPresetSelect,
  onPresetReTap,
  ariaLabel,
  activeHint,
  categoryLabels,
}: PresetRowProps) {
  const focusPresetButton = (name: PresetName) => {
    window.requestAnimationFrame(() => {
      document
        .querySelector<HTMLButtonElement>(`button[data-preset-name="${name}"]`)
        ?.focus();
    });
  };

  const moveSelection = (index: number) => {
    const nextPreset = presets[index];
    if (!nextPreset) return;
    onPresetSelect(nextPreset.name);
    focusPresetButton(nextPreset.name);
  };

  return (
    <div
      role="radiogroup"
      aria-label={ariaLabel}
      className="flex gap-3 overflow-x-auto pb-2 px-1 -mx-1 [scrollbar-width:none] [-webkit-overflow-scrolling:touch] [&::-webkit-scrollbar]:hidden snap-x snap-mandatory"
    >
      {presets.map((preset, index) => {
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
            onMovePrevious={() =>
              moveSelection((index - 1 + presets.length) % presets.length)
            }
            onMoveNext={() => moveSelection((index + 1) % presets.length)}
            onMoveFirst={() => moveSelection(0)}
            onMoveLast={() => moveSelection(presets.length - 1)}
            tabIndex={isActive ? 0 : -1}
            activeHint={activeHint}
            categoryLabel={categoryLabels[preset.category]}
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
  onMovePrevious: () => void;
  onMoveNext: () => void;
  onMoveFirst: () => void;
  onMoveLast: () => void;
  tabIndex: number;
  activeHint: string;
  categoryLabel: string;
}

function categorySurfaceClasses(category: PresetCategory): string {
  switch (category) {
    case "filmStock":
      return "from-[rgba(255,183,64,0.14)] via-transparent to-transparent";
    case "look":
      return "from-[rgba(116,174,255,0.12)] via-transparent to-transparent";
    default:
      return "from-[rgba(255,255,255,0.08)] via-transparent to-transparent";
  }
}

function PresetCard({
  preset,
  isActive,
  onTap,
  onMovePrevious,
  onMoveNext,
  onMoveFirst,
  onMoveLast,
  tabIndex,
}: PresetCardProps) {
  const handleKeyDown = (event: React.KeyboardEvent<HTMLButtonElement>) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      onTap();
      return;
    }

    if (event.key === "ArrowRight" || event.key === "ArrowDown") {
      event.preventDefault();
      onMoveNext();
      return;
    }

    if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
      event.preventDefault();
      onMovePrevious();
      return;
    }

    if (event.key === "Home") {
      event.preventDefault();
      onMoveFirst();
      return;
    }

    if (event.key === "End") {
      event.preventDefault();
      onMoveLast();
    }
  };

  return (
    <button
      type="button"
      role="radio"
      aria-checked={isActive}
      aria-label={preset.subtitle ? `${preset.label} — ${preset.subtitle}` : preset.label}
      data-preset-name={preset.name}
      tabIndex={tabIndex}
      onClick={onTap}
      onKeyDown={handleKeyDown}
      className="relative w-[142px] shrink-0 snap-start squircle-lg outline-none focus-visible:ring-2 focus-visible:ring-[var(--accent-amber1)]/50 focus-visible:ring-offset-2 focus-visible:ring-offset-black"
    >
      <div
        className={[
          "relative h-[148px] overflow-hidden squircle-lg p-3.5 text-left transition-[box-shadow] duration-150",
          isActive
            ? "bg-white/[0.05] ring-1 ring-[var(--accent-amber1)]"
            : "bg-white/[0.02]",
        ].join(" ")}
      >
        <div
          className={[
            "pointer-events-none absolute inset-0 bg-gradient-to-br opacity-50",
            categorySurfaceClasses(preset.category),
          ].join(" ")}
        />
        <div className="relative z-10 flex h-full flex-col justify-end">
          <p className="text-[15px] font-semibold tracking-[-0.02em] text-white">
            {preset.label}
          </p>
          <p className="mt-1 min-h-[2.5rem] text-[11px] leading-5 text-[var(--text-base-70)]">
            {preset.subtitle}
          </p>
        </div>
      </div>
    </button>
  );
}
