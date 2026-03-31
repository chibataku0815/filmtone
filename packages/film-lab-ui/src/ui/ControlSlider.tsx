"use client";

/**
 * Film Lab 用の横スライダー行。
 * - ラベルタップで defaultValue に戻す（モバイル向け。ダブルクリックも従来どおり可）。
 * - スマホでは行の高さを確保し、指で押しやすいヒット領域にする（44px 目安）。
 */
interface ControlSliderProps {
  label: string;
  /** ラベル行に付けるネイティブ title（ツールチップ） */
  hint?: string;
  value: number;
  min: number;
  max: number;
  step: number;
  defaultValue: number;
  onChange: (value: number) => void;
  onCommit?: () => void;
  disabled?: boolean;
  formatValue?: (value: number) => string;
}

export function ControlSlider({
  label,
  hint,
  value,
  min,
  max,
  step,
  defaultValue,
  onChange,
  onCommit,
  disabled = false,
  formatValue,
}: ControlSliderProps) {
  // ダブルクリックでデフォルト値にリセット
  const handleDoubleClick = () => {
    if (!disabled) onChange(defaultValue);
  };

  // 値に応じたトラック塗り率（%）
  const percent = ((value - min) / (max - min)) * 100;

  return (
    <div
      className={`group flex min-h-[44px] items-center gap-3 sm:min-h-0 ${disabled ? "opacity-45" : ""}`}
      onDoubleClick={handleDoubleClick}
      title={hint}
    >
      {/* ラベル（左） */}
      <span
        className="w-16 shrink-0 cursor-pointer text-[11px] text-[var(--text-muted)] select-none sm:w-24"
        onClick={() => {
          if (!disabled) onChange(defaultValue);
        }}
        title="Tap to reset"
      >
        {label}
      </span>

      {/* スライダー（中央） */}
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))}
        onPointerUp={() => onCommit?.()}
        onTouchEnd={() => onCommit?.()}
        disabled={disabled}
        className="film-lab-slider h-1.5 flex-1 cursor-pointer appearance-none rounded-full touch-none disabled:cursor-not-allowed sm:h-1"
        style={{
          background: `linear-gradient(to right, var(--accent-amber1) 0%, var(--accent-amber1) ${percent}%, rgba(255,255,255,0.08) ${percent}%, rgba(255,255,255,0.08) 100%)`,
        }}
      />

      {/* 値表示（右） */}
      <span className="w-10 shrink-0 text-right font-mono text-[10px] text-[var(--text-base-70)] tabular-nums sm:w-12 sm:text-[11px]">
        {formatValue ? formatValue(value) : value.toFixed(2)}
      </span>
    </div>
  );
}
