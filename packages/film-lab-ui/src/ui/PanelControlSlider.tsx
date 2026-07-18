"use client";

/**
 * @fileoverview コントロールパネル用の安定した `ControlSlider` ラッパーです。
 *
 * @description
 * 親コンポーネントの中で別コンポーネントを毎回作ると、再描画のたびに
 * `input[type="range"]` が差し替わり、つまみドラッグが途中で切れることがあります。
 * そのため module scope に置き、native range の DOM を保ちます。
 * `FilmLabControlPanelCore` 本体と `FinishToolsSection` の両方から使う共有 UI 部品です。
 */
import { type ComponentProps } from "react";
import { ControlSlider as BaseControlSlider } from "./ControlSlider";

export type PanelControlSliderProps = ComponentProps<typeof BaseControlSlider> & {
  /** Panel 内で使う翻訳済みの「ラベルを押すと初期値へ戻る」説明文 */
  sliderLabelResetHint: string;
};

/**
 * @description 右パネル用の `ControlSlider` です。
 * 共有 UI の見た目は保ちつつ、Panel 固有の余白と reset hint をまとめます。
 */
export function PanelControlSlider({
  sliderLabelResetHint,
  className,
  labelClassName,
  labelResetHint,
  ...props
}: PanelControlSliderProps) {
  const panelSliderLabelClassName = [
    "min-w-[7.5rem] shrink-0 cursor-pointer text-[11px] leading-tight text-[var(--text-muted)] select-none whitespace-nowrap sm:min-w-[8.5rem]",
    labelClassName,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <BaseControlSlider
      {...props}
      labelClassName={panelSliderLabelClassName}
      labelResetHint={labelResetHint ?? sliderLabelResetHint}
      className={["lg:pr-4", className].filter(Boolean).join(" ")}
    />
  );
}
