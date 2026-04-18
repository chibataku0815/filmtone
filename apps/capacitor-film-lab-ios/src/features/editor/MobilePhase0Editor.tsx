import { Capacitor } from "@capacitor/core";
import { useEffect, useState } from "react";
import {
  PRESET_BUTTONS,
  parseCube,
  serializeCubeLut,
  type ParsedCubeLut,
  type QuickAxisId,
  type PresetName,
} from "film-lab-core";
import type { AppStrings } from "@/lib/messages";
import {
  appendBenchmarkRecord,
  loadPhase0Project,
  savePhase0Project,
} from "@/lib/phase0-storage";
import {
  applyLutSelection,
  applyPresetSelection,
  applyProbe,
  applyQuickState,
  buildEditorExportRequest,
  createInitialEditorState,
} from "@/lib/phase0-state";
import { filmtoneMedia } from "@/native/filmtoneMedia";
import { ExportSheet } from "@/features/export/ExportSheet";
import { TopChrome } from "./TopChrome";
import { PreviewCanvas } from "./PreviewCanvas";
import { CameraProfilePill, type CameraProfile } from "./CameraProfilePill";
import { PresetRow } from "./PresetRow";
import { StrengthSheet } from "./StrengthSheet";

interface MobilePhase0EditorProps {
  strings: AppStrings;
}

export function MobilePhase0Editor({ strings }: MobilePhase0EditorProps) {
  const [state, setState] = useState(() =>
    createInitialEditorState(loadPhase0Project() ?? undefined),
  );
  const [isSaveBusy, setIsSaveBusy] = useState(false);
  const [inputLut, setInputLut] = useState<ParsedCubeLut | null>(null);
  const [inputLutEnabled, setInputLutEnabled] = useState(true);
  const [cameraProfile, setCameraProfile] = useState<CameraProfile>("auto");
  const [strengthSheetOpen, setStrengthSheetOpen] = useState(false);
  const displaySourceUri =
    state.source && Capacitor.isNativePlatform()
      ? Capacitor.convertFileSrc(state.source.uri)
      : state.source?.uri;

  useEffect(() => {
    let cancelled = false;

    filmtoneMedia
      .addListener("exportProgress", (progress) => {
        if (cancelled) return;
        setState((current) => ({
          ...current,
          exportProgress: progress,
        }));
      })
      .then((handle) => {
        if (cancelled) {
          handle.remove();
        }
      });

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    savePhase0Project(state.project);
  }, [state.project]);

  async function handlePickSource() {
    try {
      setIsSaveBusy(false);
      setState((current) => ({ ...current, isBusy: true, error: null, notice: null }));
      const source = await filmtoneMedia.pickSource();
      if (!source) {
        setState((current) => ({ ...current, isBusy: false }));
        return;
      }
      setState((current) => ({ ...current, notice: strings.probePending }));
      const probe = await filmtoneMedia.probeSource({ uri: source.uri });
      setState((current) => ({
        ...applyProbe(current, source, probe),
        isBusy: false,
      }));
    } catch (error) {
      setState((current) => ({
        ...current,
        isBusy: false,
        error: error instanceof Error ? error.message : String(error),
      }));
      setIsSaveBusy(false);
    }
  }

  function handlePresetSelect(presetName: PresetName) {
    setState((current) => applyPresetSelection(current, presetName));
  }

  function handlePresetReTap(_presetName: PresetName) {
    setStrengthSheetOpen(true);
  }

  function handleQuickChange(axis: QuickAxisId, value: number) {
    setState((current) =>
      applyQuickState(current, {
        ...current.project.quickState,
        [axis]: value,
      }),
    );
  }

  function handleStrengthChange(value: number) {
    setState((current) =>
      applyLutSelection(
        current,
        current.project.lut ? { ...current.project.lut, intensity: value } : current.project.lut,
      ),
    );
  }

  function handleStrengthReset() {
    setState((current) =>
      applyQuickState(current, { filmCharacter: 0, era: 0, dynamics: 0 }),
    );
    setState((current) =>
      applyLutSelection(
        current,
        current.project.lut ? { ...current.project.lut, intensity: 1 } : current.project.lut,
      ),
    );
  }

  function handleCameraProfileSelect(profile: CameraProfile) {
    setCameraProfile(profile);
    if (profile === "auto") {
      setInputLut(null);
      setInputLutEnabled(true);
    } else if (profile !== "custom") {
      setInputLut(null);
      setInputLutEnabled(true);
    }
  }

  async function handlePickCustomCameraLut() {
    try {
      const picked = await filmtoneMedia.pickLutFile({ slot: "inputLut" });
      if (!picked) return;
      let parsed;
      try {
        parsed = parseCube(picked.text);
      } catch (err) {
        const detail = err instanceof Error ? err.message : String(err);
        setState((current) => ({
          ...current,
          error: `${strings.lutInputParseError}: ${detail}`,
        }));
        return;
      }
      const lut = serializeCubeLut(parsed, {
        title: parsed.title || picked.filename,
        intensity: 1,
      });
      setInputLut(lut);
      setInputLutEnabled(true);
      setCameraProfile("custom");
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      setState((current) => ({
        ...current,
        error: `${strings.lutInputImportError}: ${detail}`,
      }));
    }
  }

  async function handleExport() {
    try {
      const baseRequest = buildEditorExportRequest(state);
      if (!baseRequest) {
        setState((current) => ({ ...current, error: strings.exportDisabled }));
        return;
      }
      const request = {
        ...baseRequest,
        inputLut: inputLutEnabled ? inputLut : null,
      };
      setIsSaveBusy(false);
      setState((current) => ({
        ...current,
        isBusy: true,
        error: null,
        notice: null,
        exportResult: null,
        saveToPhotosState: "not-run",
      }));
      const result = await filmtoneMedia.runExport(request);
      if (result.benchmarkRecord) {
        appendBenchmarkRecord(result.benchmarkRecord);
      }
      setState((current) => ({
        ...current,
        isBusy: false,
        exportProgress: null,
        exportResult: result,
        notice: null,
      }));
      setIsSaveBusy(false);
    } catch (error) {
      setState((current) => ({
        ...current,
        isBusy: false,
        exportProgress: null,
        error: error instanceof Error ? error.message : String(error),
      }));
      setIsSaveBusy(false);
    }
  }

  async function handleSave() {
    if (!state.exportResult || isSaveBusy || state.saveToPhotosState === "saved") return;
    setIsSaveBusy(true);
    try {
      await filmtoneMedia.saveToPhotos({ uri: state.exportResult.outputUri });
      setState((current) => ({
        ...current,
        saveToPhotosState: "saved",
        notice: strings.saveToPhotosDone,
        error: null,
      }));
    } catch (error) {
      setState((current) => ({
        ...current,
        saveToPhotosState: "failed",
        error: error instanceof Error ? error.message : String(error),
      }));
    } finally {
      setIsSaveBusy(false);
    }
  }

  async function handleShare() {
    if (!state.exportResult) return;
    try {
      await filmtoneMedia.shareOutput({ uri: state.exportResult.outputUri });
    } catch (error) {
      setState((current) => ({
        ...current,
        error: error instanceof Error ? error.message : String(error),
      }));
    }
  }

  const activePresetButton = PRESET_BUTTONS.find(
    (preset) => preset.name === state.project.presetName,
  );
  const activePresetLabel = activePresetButton?.label ?? state.project.presetName;
  const cameraProfileLabels: Record<CameraProfile, string> = {
    auto: strings.cameraProfileAuto,
    rec709: strings.cameraProfileRec709,
    "apple-log": strings.cameraProfileAppleLog,
    slog3: strings.cameraProfileSlog3,
    vlog: strings.cameraProfileVlog,
    custom: strings.cameraProfileCustom,
  };

  return (
    <div className="relative min-h-screen">
      <TopChrome
        appName={strings.appName}
        sourceLabel={state.source?.filename}
        onMenuOpen={() => {
          /* M3: open LUT manager + Help + Settings */
        }}
        menuLabel={strings.topMenuLabel}
        autoHide={state.source != null}
      />

      <div className="mx-auto flex w-full max-w-3xl flex-col gap-5 px-4 pb-10 pt-[calc(env(safe-area-inset-top,0px)+72px)] sm:px-6">
        <PreviewCanvas
          source={state.source}
          displayUri={displaySourceUri}
          emptyMessage={strings.sourceEmpty}
          compareLabel={strings.compareLabel}
        />

        <div className="flex justify-center">
          <button
            type="button"
            onClick={handlePickSource}
            disabled={state.isBusy || isSaveBusy}
            className="rounded-full bg-[var(--accent-amber1)] px-5 py-2.5 text-xs font-medium text-black transition disabled:cursor-not-allowed disabled:bg-white/10 disabled:text-white/40"
          >
            {state.source ? strings.repickSource : strings.pickSource}
          </button>
        </div>

        <div className="flex items-center gap-3">
          <CameraProfilePill
            active={cameraProfile}
            customLutTitle={cameraProfile === "custom" ? inputLut?.title : undefined}
            onSelect={handleCameraProfileSelect}
            onPickCustomLut={handlePickCustomCameraLut}
            cameraLabel={strings.lutInputSlotName}
            profileLabels={cameraProfileLabels}
          />
        </div>

        <PresetRow
          activePreset={state.project.presetName as PresetName}
          presets={PRESET_BUTTONS.map((preset) => ({
            name: preset.name,
            label: preset.label,
            subtitle: preset.subtitle,
          }))}
          onPresetSelect={handlePresetSelect}
          onPresetReTap={handlePresetReTap}
          ariaLabel={strings.presetRowAriaLabel}
        />

        <ExportSheet
          project={state.project}
          source={state.source}
          probe={state.probe}
          exportProgress={state.exportProgress}
          exportResult={state.exportResult}
          saveToPhotosState={state.saveToPhotosState}
          isBusy={state.isBusy}
          isSaveBusy={isSaveBusy}
          error={state.error}
          strings={strings}
          onExport={handleExport}
          onSave={handleSave}
          onShare={handleShare}
        />

        {state.notice ? (
          <section className="rounded-[20px] border border-sky-400/20 bg-sky-400/10 px-4 py-3 text-sm text-sky-100">
            <strong>{strings.noticePrefix}:</strong> {state.notice}
          </section>
        ) : null}
        {state.error ? (
          <section className="rounded-[20px] border border-rose-400/20 bg-rose-400/10 px-4 py-3 text-sm text-rose-100">
            <strong>{strings.errorPrefix}:</strong> {state.error}
          </section>
        ) : null}
      </div>

      <StrengthSheet
        isOpen={strengthSheetOpen}
        onClose={() => setStrengthSheetOpen(false)}
        presetLabel={activePresetLabel}
        strength={state.project.lut?.intensity ?? 1}
        onStrengthChange={handleStrengthChange}
        onReset={handleStrengthReset}
        resetLabel={strings.resetLabel}
        compareLabel={strings.compareLabel}
        strengthLabel={strings.strengthLabel}
        adjustDisclosureLabel={strings.adjustLabel}
        quickAxes={{
          filmCharacter: state.project.quickState.filmCharacter,
          era: state.project.quickState.era,
          dynamics: state.project.quickState.dynamics,
          onChange: handleQuickChange,
          labels: {
            filmCharacter: strings.quickFilmCharacter,
            era: strings.quickEra,
            dynamics: strings.quickDynamics,
          },
        }}
      />
    </div>
  );
}
