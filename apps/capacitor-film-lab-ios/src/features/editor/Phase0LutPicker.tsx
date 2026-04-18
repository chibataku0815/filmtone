import { ControlSlider } from "film-lab-ui";
import type { ParsedCubeLut } from "film-lab-core";

interface Phase0LutPickerStrings {
  lutSectionTitle: string;
  pickLut: string;
  clearLut: string;
  sliderResetHint: string;
  lutInputSlotName: string;
  lutInputSlotDescription: string;
  lutInputSlotEmpty: string;
  lutInputSlotEnabled: string;
  lutCreativeSlotName: string;
  lutCreativeSlotDescription: string;
  lutCreativeSlotEmpty: string;
  lutInputMixLabel: string;
  lutCreativeMixLabel: string;
  lutMixDisabledHint: string;
}

interface Phase0LutPickerProps {
  inputLut: ParsedCubeLut | null;
  inputLutEnabled: boolean;
  creativeLut: ParsedCubeLut | null;
  strings: Phase0LutPickerStrings;
  onPickInputLut: () => void;
  onClearInputLut: () => void;
  onToggleInputLut: (enabled: boolean) => void;
  onInputIntensityChange: (value: number) => void;
  onPickCreativeLut: () => void;
  onClearCreativeLut: () => void;
  onCreativeIntensityChange: (value: number) => void;
}

export function Phase0LutPicker({
  inputLut,
  inputLutEnabled,
  creativeLut,
  strings,
  onPickInputLut,
  onClearInputLut,
  onToggleInputLut,
  onInputIntensityChange,
  onPickCreativeLut,
  onClearCreativeLut,
  onCreativeIntensityChange,
}: Phase0LutPickerProps) {
  return (
    <section className="rounded-[24px] border border-white/10 bg-white/[0.03] p-4">
      <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
        {strings.lutSectionTitle}
      </p>

      <div className="mt-4 rounded-[18px] border border-white/8 bg-black/20 p-4">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-[11px] font-medium uppercase tracking-[0.12em] text-white">
              {strings.lutInputSlotName}
            </p>
            <p className="mt-1 text-[11px] leading-5 text-[var(--text-base-70)]">
              {inputLut ? `${inputLut.title} · ${inputLut.size}³` : strings.lutInputSlotDescription}
            </p>
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <label className="flex select-none items-center gap-2 text-[10px] uppercase tracking-[0.12em] text-[var(--text-base-70)]">
              <input
                type="checkbox"
                checked={inputLutEnabled}
                onChange={(event) => onToggleInputLut(event.target.checked)}
                className="h-3.5 w-3.5 accent-[var(--accent-amber1)]"
              />
              {strings.lutInputSlotEnabled}
            </label>
            <button
              type="button"
              onClick={onPickInputLut}
              className="rounded-full border border-white/12 bg-white/[0.05] px-3 py-2 text-xs text-white transition hover:bg-white/[0.08]"
            >
              {strings.pickLut}
            </button>
            {inputLut ? (
              <button
                type="button"
                onClick={onClearInputLut}
                className="rounded-full border border-white/12 px-3 py-2 text-xs text-[var(--text-muted)] transition hover:bg-white/[0.05] hover:text-white"
              >
                {strings.clearLut}
              </button>
            ) : null}
          </div>
        </div>
        <div className="mt-4">
          <ControlSlider
            label={strings.lutInputMixLabel}
            hint={!inputLut ? strings.lutMixDisabledHint : undefined}
            labelResetHint={strings.sliderResetHint}
            value={inputLut?.intensity ?? 1}
            min={0}
            max={1}
            step={0.01}
            defaultValue={1}
            disabled={!inputLut || !inputLutEnabled}
            onChange={onInputIntensityChange}
          />
        </div>
      </div>

      <div className="mt-3 rounded-[18px] border border-white/8 bg-black/20 p-4">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-[11px] font-medium uppercase tracking-[0.12em] text-white">
              {strings.lutCreativeSlotName}
            </p>
            <p className="mt-1 text-[11px] leading-5 text-[var(--text-base-70)]">
              {creativeLut
                ? `${creativeLut.title} · ${creativeLut.size}³`
                : strings.lutCreativeSlotDescription}
            </p>
          </div>
          <div className="flex shrink-0 gap-2">
            <button
              type="button"
              onClick={onPickCreativeLut}
              className="rounded-full border border-white/12 bg-white/[0.05] px-3 py-2 text-xs text-white transition hover:bg-white/[0.08]"
            >
              {strings.pickLut}
            </button>
            {creativeLut ? (
              <button
                type="button"
                onClick={onClearCreativeLut}
                className="rounded-full border border-white/12 px-3 py-2 text-xs text-[var(--text-muted)] transition hover:bg-white/[0.05] hover:text-white"
              >
                {strings.clearLut}
              </button>
            ) : null}
          </div>
        </div>
        <div className="mt-4">
          <ControlSlider
            label={strings.lutCreativeMixLabel}
            hint={!creativeLut ? strings.lutMixDisabledHint : undefined}
            labelResetHint={strings.sliderResetHint}
            value={creativeLut?.intensity ?? 1}
            min={0}
            max={1}
            step={0.01}
            defaultValue={1}
            disabled={!creativeLut}
            onChange={onCreativeIntensityChange}
          />
        </div>
      </div>
    </section>
  );
}
