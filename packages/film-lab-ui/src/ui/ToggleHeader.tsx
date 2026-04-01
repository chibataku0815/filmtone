/**
 * @fileoverview ラベル + **スイッチ**の行（Bloom / Halation / Histogram 等）です。
 *
 * @description
 * ON/OFF がはっきり分かるヘッダ行を共通化し、Web / Desktop で同じ family に見せます。
 */
import { filmLabToggleHeaderTitle, filmLabToggleHeaderTrackOff, filmLabToggleHeaderTrackOn } from "../filmLabPanelTokens";

export interface ToggleHeaderProps {
  /** 行のタイトル */
  title: string;
  /** スイッチのオン状態 */
  enabled: boolean;
  /** クリックされたときに渡す次のオン状態 */
  onToggle: (on: boolean) => void;
}

/**
 * @param {ToggleHeaderProps} props トグル行 props
 */
export function ToggleHeader({ title, enabled, onToggle }: ToggleHeaderProps) {
  return (
    <div className="mb-2 mt-3 flex items-center justify-between gap-3">
      <h3 className={filmLabToggleHeaderTitle}>{title}</h3>
      <button
        type="button"
        role="switch"
        aria-checked={enabled}
        onClick={() => onToggle(!enabled)}
        className={[
          "relative box-border h-5 w-9 shrink-0 rounded-full border transition-colors",
          enabled ? filmLabToggleHeaderTrackOn : filmLabToggleHeaderTrackOff,
        ].join(" ")}
      >
        <span
          aria-hidden
          className={[
            "pointer-events-none absolute inset-y-0 my-auto block h-4 w-4 rounded-full bg-white transition-all",
            enabled ? "right-0.5 left-auto" : "left-0.5 right-auto",
          ].join(" ")}
        />
      </button>
    </div>
  );
}
