import { ControlSlider } from "film-lab-ui";
import type { ParsedCubeLut } from "film-lab-core";

interface Phase0LutPickerProps {
  lut: ParsedCubeLut | null;
  strings: {
    lutSectionTitle: string;
    lutEmpty: string;
    pickLut: string;
    clearLut: string;
    lutMixLabel: string;
    lutMixDisabledHint: string;
    sliderResetHint: string;
  };
  onPick: () => void;
  onClear: () => void;
  onIntensityChange: (value: number) => void;
}

export function Phase0LutPicker({
  lut,
  strings,
  onPick,
  onClear,
  onIntensityChange,
}: Phase0LutPickerProps) {
  return (
    <section className="rounded-[24px] border border-white/10 bg-white/[0.03] p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
            {strings.lutSectionTitle}
          </p>
          <p className="mt-2 text-sm leading-6 text-[var(--text-base-70)]">
            {lut
              ? `${lut.title} · ${lut.size}³`
              : strings.lutEmpty}
          </p>
        </div>
        <div className="flex shrink-0 gap-2">
          <button
            type="button"
            onClick={onPick}
            className="rounded-full border border-white/12 bg-white/[0.05] px-3 py-2 text-xs text-white transition hover:bg-white/[0.08]"
          >
            {strings.pickLut}
          </button>
          {lut ? (
            <button
              type="button"
              onClick={onClear}
              className="rounded-full border border-white/12 px-3 py-2 text-xs text-[var(--text-muted)] transition hover:bg-white/[0.05] hover:text-white"
            >
              {strings.clearLut}
            </button>
          ) : null}
        </div>
      </div>
      <div className="mt-4">
        <ControlSlider
          label={strings.lutMixLabel}
          hint={!lut ? strings.lutMixDisabledHint : undefined}
          labelResetHint={strings.sliderResetHint}
          value={lut?.intensity ?? 1}
          min={0}
          max={1}
          step={0.01}
          defaultValue={1}
          disabled={!lut}
          onChange={onIntensityChange}
        />
      </div>
    </section>
  );
}
