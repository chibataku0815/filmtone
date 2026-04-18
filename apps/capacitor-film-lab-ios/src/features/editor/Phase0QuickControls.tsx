import { ControlSlider } from "film-lab-ui";
import type { QuickAxisId, QuickState } from "film-lab-core";

interface Phase0QuickControlsProps {
  quickState: QuickState;
  sliderResetHint: string;
  strings: {
    quickSectionTitle: string;
    quickHint: string;
    quickFilmCharacter: string;
    quickEra: string;
    quickDynamics: string;
    quickFilmCharacterHint: string;
    quickEraHint: string;
    quickDynamicsHint: string;
  };
  onQuickChange: (axis: QuickAxisId, value: number) => void;
}

function formatPercent(value: number): string {
  return `${value > 0 ? "+" : ""}${Math.round(value * 100)}`;
}

export function Phase0QuickControls({
  quickState,
  sliderResetHint,
  strings,
  onQuickChange,
}: Phase0QuickControlsProps) {
  return (
    <section className="rounded-[24px] border border-white/10 bg-white/[0.03] p-4">
      <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
        {strings.quickSectionTitle}
      </p>
      <p className="mt-2 text-sm leading-6 text-[var(--text-base-70)]">
        {strings.quickHint}
      </p>
      <div className="mt-4 space-y-4">
        <ControlSlider
          label={strings.quickFilmCharacter}
          hint={strings.quickFilmCharacterHint}
          labelResetHint={sliderResetHint}
          value={quickState.filmCharacter}
          min={-1}
          max={1}
          step={0.01}
          defaultValue={0}
          formatValue={formatPercent}
          onChange={(value) => onQuickChange("filmCharacter", value)}
        />
        <ControlSlider
          label={strings.quickEra}
          hint={strings.quickEraHint}
          labelResetHint={sliderResetHint}
          value={quickState.era}
          min={-1}
          max={1}
          step={0.01}
          defaultValue={0}
          formatValue={formatPercent}
          onChange={(value) => onQuickChange("era", value)}
        />
        <ControlSlider
          label={strings.quickDynamics}
          hint={strings.quickDynamicsHint}
          labelResetHint={sliderResetHint}
          value={quickState.dynamics}
          min={-1}
          max={1}
          step={0.01}
          defaultValue={0}
          formatValue={formatPercent}
          onChange={(value) => onQuickChange("dynamics", value)}
        />
      </div>
    </section>
  );
}
