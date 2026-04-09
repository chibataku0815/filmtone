import { PresetSearchSelect } from "film-lab-ui";
import type { PresetName } from "film-lab-core";

interface Phase0PresetPickerProps {
  activePreset: PresetName;
  strings: {
    presetLabel: string;
    presetSelectTriggerLabel: string;
    presetSearchPlaceholder: string;
    presetSearchEmpty: string;
  };
  onPresetChange: (preset: PresetName) => void;
}

export function Phase0PresetPicker({
  activePreset,
  strings,
  onPresetChange,
}: Phase0PresetPickerProps) {
  return (
    <section className="rounded-[24px] border border-white/10 bg-white/[0.03] p-4">
      <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
        {strings.presetLabel}
      </p>
      <div className="mt-3">
        <PresetSearchSelect
          activePreset={activePreset}
          onPreset={onPresetChange}
          triggerAriaLabel={strings.presetSelectTriggerLabel}
          searchPlaceholder={strings.presetSearchPlaceholder}
          emptyLabel={strings.presetSearchEmpty}
        />
      </div>
    </section>
  );
}
