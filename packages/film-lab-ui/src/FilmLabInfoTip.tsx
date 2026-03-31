"use client";

export type FilmLabInfoTipProps = {
  tip: string;
  assistiveLabel: string;
  className?: string;
};

export function FilmLabInfoTip(props: FilmLabInfoTipProps) {
  const { tip, assistiveLabel, className = "" } = props;
  return (
    <button
      type="button"
      className={`inline-flex size-[18px] shrink-0 items-center justify-center rounded text-white/40 outline-none hover:bg-white/10 hover:text-amber-200/90 focus-visible:ring-1 focus-visible:ring-amber-400/60 ${className}`}
      title={tip}
      aria-label={`${assistiveLabel}（ホバーで詳細）`}
    >
      <span className="text-[11px] font-semibold leading-none" aria-hidden>
        ?
      </span>
    </button>
  );
}
