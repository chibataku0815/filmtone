/**
 * @fileoverview 折りたたみセクションの見出しボタン（Finish Tools / Source Trim / Compare 等）です。
 *
 * @description
 * `ToggleHeader`（ON/OFF スイッチ行）とは別に、セクションの開閉だけを担う見出しを共通化します。
 */
import { filmLabCollapsibleHeaderButton } from "../filmLabPanelTokens";

export interface CollapsibleHeaderProps {
  title: string;
  /** 折りたたみ見出しホバー時の補足（ネイティブ `title`） */
  titleHint?: string;
  open: boolean;
  onToggle: () => void;
}

/**
 * @param {CollapsibleHeaderProps} props 折りたたみ見出し props
 */
export function CollapsibleHeader({
  title,
  titleHint,
  open,
  onToggle,
}: CollapsibleHeaderProps) {
  return (
    <button
      type="button"
      title={titleHint}
      className={filmLabCollapsibleHeaderButton}
      onClick={onToggle}
    >
      <span className={`text-[8px] transition-transform duration-150 ${open ? "rotate-90" : ""}`}>
        &#9654;
      </span>
      {title}
    </button>
  );
}
