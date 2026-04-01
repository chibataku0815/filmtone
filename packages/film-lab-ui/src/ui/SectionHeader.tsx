/**
 * @fileoverview コントロールパネル内の **セクション見出し**（小さな uppercase ラベル）です。
 *
 * @description
 * Presets / Color などのブロック名を揃えるための共有コンポーネントです。
 * className を足すと余白だけ上書きできます（例: ブラウザ保存ブロック先頭では `mt-0`）。
 */
import { filmLabSectionHeaderTitle } from "../filmLabPanelTokens";

export interface SectionHeaderProps {
  /** 見出しに表示する文言（通常は next-intl の結果） */
  title: string;
  /** 追加の Tailwind クラス（`mt-0` など余白調整用） */
  className?: string;
}

/**
 * @param {SectionHeaderProps} props 見出し props
 */
export function SectionHeader({ title, className }: SectionHeaderProps) {
  return (
    <h3 className={[filmLabSectionHeaderTitle, className].filter(Boolean).join(" ")}>{title}</h3>
  );
}
