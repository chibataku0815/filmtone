/**
 * @fileoverview ラベル + **スイッチ**の行（Bloom / Halation / Histogram 等）です。
 *
 * @description
 * ON/OFF がはっきり分かるヘッダ行を共通化し、Web / Desktop で同じ family に見せます。
 * トラック幅の計算ミス・親の flex での潰れを避けるため、スイッチ本体は Radix Switch に任せます。
 *
 * @limitations
 * - 見た目は Tailwind ＋既存トークン依存。`apps/web` は globals.css の `@source` で film-lab-ui をスキャンする必要があります。
 */
import * as Switch from "@radix-ui/react-switch";
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
    <div className="mb-2 mt-3 flex min-h-[1.5rem] min-w-0 items-center justify-between gap-3">
      <h3 className={`min-w-0 flex-1 ${filmLabToggleHeaderTitle}`}>{title}</h3>
      <Switch.Root
        checked={enabled}
        onCheckedChange={onToggle}
        className={[
          "relative inline-flex h-5 w-9 shrink-0 cursor-pointer items-center rounded-full border px-0.5 transition-colors",
          "outline-none focus-visible:ring-2 focus-visible:ring-amber-400/55 focus-visible:ring-offset-2 focus-visible:ring-offset-transparent",
          enabled ? filmLabToggleHeaderTrackOn : filmLabToggleHeaderTrackOff,
        ].join(" ")}
      >
        <Switch.Thumb
          className={[
            "pointer-events-none block size-4 shrink-0 rounded-full bg-white shadow-sm",
            "transition-transform duration-200 ease-out will-change-transform",
            "translate-x-0 data-[state=checked]:translate-x-4",
          ].join(" ")}
        />
      </Switch.Root>
    </div>
  );
}
