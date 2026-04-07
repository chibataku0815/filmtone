/**
 * @fileoverview 2 ボタン以上の相互排他的な選択を表す **セグメントコントロール**。
 *
 * @description
 * Quick/Pro mode toggle と同じカラートークン
 * (`filmLabModeToggleSegmentActive` / `filmLabModeToggleSegmentInactive`) を再利用しつつ、
 * モバイル時にボタンを画面いっぱいへ拡げる Quick/Pro 用クラスは流用しません。
 * セグメントコントロールはコンテンツ幅に収まる小型 UI として配置することを想定し、
 * 親側で `flex justify-center` 等の整列を選べる shrink-to-content 挙動にしています。
 *
 * @limitations
 * - 状態は親が `value` で持ち、`onChange` で更新する controlled component です。
 * - フォーカスリング・色などのスタイルは Tailwind ＋既存トークンに依存します。
 */
import {
  filmLabModeToggleSegmentActive,
  filmLabModeToggleSegmentInactive,
} from "../filmLabPanelTokens";

const segmentedShell =
  "inline-flex flex-nowrap items-stretch gap-0.5 rounded-lg border border-white/10 p-1";

const segmentedButtonBase =
  "min-w-[3.5rem] whitespace-nowrap rounded-md px-4 py-1 text-center text-[11px] font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400/65 focus-visible:ring-offset-2 focus-visible:ring-offset-black/50";

function buttonClassName(active: boolean): string {
  return [
    segmentedButtonBase,
    active ? filmLabModeToggleSegmentActive : filmLabModeToggleSegmentInactive,
  ].join(" ");
}

export interface SegmentedControlOption<T extends string> {
  value: T;
  label: string;
}

export interface SegmentedControlProps<T extends string> {
  options: SegmentedControlOption<T>[];
  value: T;
  onChange: (value: T) => void;
  ariaLabel?: string;
}

export function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
  ariaLabel,
}: SegmentedControlProps<T>) {
  return (
    <div className={segmentedShell} role="group" aria-label={ariaLabel}>
      {options.map((opt) => {
        const active = value === opt.value;
        return (
          <button
            key={opt.value}
            type="button"
            onClick={() => onChange(opt.value)}
            aria-pressed={active}
            className={buttonClassName(active)}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}
