import { Capacitor } from "@capacitor/core";
import { useEffect, useMemo, useState } from "react";
import { FILM_LAB_SOURCE_DISPLAY_PRIORITY_ORDER } from "film-lab-ui";
import {
  buildBenchmarkRow,
  formatBenchmarkRow,
  parseCube,
  serializeCubeLut,
  getPhase0SourceCapViolations,
  type BenchmarkSaveResult,
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
import { Phase0PresetPicker } from "./Phase0PresetPicker";
import { Phase0QuickControls } from "./Phase0QuickControls";
import { Phase0LutPicker } from "./Phase0LutPicker";
import { ExportSheet, type VisualFloorState } from "@/features/export/ExportSheet";

interface MobilePhase0EditorProps {
  strings: AppStrings;
}

function formatDuration(value?: number): string {
  if (typeof value !== "number") return "—";
  if (value < 60) return `${value.toFixed(1)}s`;
  const minutes = Math.floor(value / 60);
  const seconds = Math.round(value % 60);
  return `${minutes}m ${seconds}s`;
}

export function MobilePhase0Editor({ strings }: MobilePhase0EditorProps) {
  const [state, setState] = useState(() =>
    createInitialEditorState(loadPhase0Project() ?? undefined),
  );
  const [isSaveBusy, setIsSaveBusy] = useState(false);
  const [inputLut, setInputLut] = useState<ParsedCubeLut | null>(null);
  const [inputLutEnabled, setInputLutEnabled] = useState(true);
  const [visualFloor, setVisualFloor] = useState<VisualFloorState>("not-checked");
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

  const sourceViolations = useMemo(
    () => (state.probe ? getPhase0SourceCapViolations(state.probe) : []),
    [state.probe],
  );

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

  function handlePresetChange(presetName: PresetName) {
    setState((current) => applyPresetSelection(current, presetName));
  }

  function handleQuickChange(axis: QuickAxisId, value: number) {
    setState((current) =>
      applyQuickState(current, {
        ...current.project.quickState,
        [axis]: value,
      }),
    );
  }

  async function handlePickInputLut() {
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
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      setState((current) => ({
        ...current,
        error: `${strings.lutInputImportError}: ${detail}`,
      }));
    }
  }

  function handleClearInputLut() {
    setInputLut(null);
  }

  function handleToggleInputLut(enabled: boolean) {
    setInputLutEnabled(enabled);
  }

  function handleInputIntensityChange(intensity: number) {
    setInputLut((current) => (current ? { ...current, intensity } : current));
  }

  async function handlePickCreativeLut() {
    try {
      const picked = await filmtoneMedia.pickLutFile({ slot: "creativeLut" });
      if (!picked) return;
      let parsed;
      try {
        parsed = parseCube(picked.text);
      } catch (err) {
        const detail = err instanceof Error ? err.message : String(err);
        setState((current) => ({
          ...current,
          error: `${strings.lutCreativeParseError}: ${detail}`,
        }));
        return;
      }
      const lut = serializeCubeLut(parsed, {
        title: parsed.title || picked.filename,
        intensity: 1,
      });
      setState((current) => applyLutSelection(current, lut));
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      setState((current) => ({
        ...current,
        error: `${strings.lutCreativeImportError}: ${detail}`,
      }));
    }
  }

  function handleCreativeIntensityChange(intensity: number) {
    setState((current) =>
      applyLutSelection(
        current,
        current.project.lut ? { ...current.project.lut, intensity } : null,
      ),
    );
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
      setVisualFloor("not-checked");
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

  async function handleShareBenchmark() {
    if (!state.exportResult || !state.exportResult.benchmarkRecord) return;
    const saveResult: BenchmarkSaveResult =
      state.saveToPhotosState === "saved"
        ? "ok"
        : state.saveToPhotosState === "failed"
        ? "fail"
        : "not-run";
    const clipId = state.source?.filename ?? "unknown-clip";
    const row = buildBenchmarkRow({
      result: state.exportResult,
      benchmark: state.exportResult.benchmarkRecord,
      probe: state.probe,
      clipId,
      visualFloor,
      saveResult,
    });
    const markdown = formatBenchmarkRow(row);

    try {
      if (typeof navigator !== "undefined" && typeof navigator.share === "function") {
        await navigator.share({ text: markdown, title: "Filmtone benchmark" });
      } else if (typeof navigator !== "undefined" && navigator.clipboard) {
        await navigator.clipboard.writeText(markdown);
      }
      setState((current) => ({
        ...current,
        notice: strings.benchmarkShareCopied,
        error: null,
      }));
    } catch (error) {
      setState((current) => ({
        ...current,
        error: error instanceof Error ? error.message : String(error),
      }));
    }
  }

  return (
    <div className="grid gap-4">
      <section className="rounded-[24px] border border-white/10 bg-white/[0.03] p-4">
        <div className="flex items-center justify-between gap-3">
          <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
            {strings.sourceSectionTitle}
          </p>
          <button
            type="button"
            onClick={handlePickSource}
            disabled={state.isBusy || isSaveBusy}
            className="rounded-full bg-[var(--accent-amber1)] px-4 py-2 text-xs font-medium text-black transition disabled:cursor-not-allowed disabled:bg-white/10 disabled:text-white/40"
          >
            {state.source ? strings.repickSource : strings.pickSource}
          </button>
        </div>

        <div className="mt-4 grid gap-4 md:grid-cols-[1.15fr_0.85fr]">
          <div className="overflow-hidden rounded-[22px] border border-white/8 bg-black/30">
            <div className="flex items-center justify-between border-b border-white/8 px-4 py-3">
              <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.previewTitle}
              </p>
              <p className="text-xs text-[var(--text-base-70)]">{strings.previewHint}</p>
            </div>
            <div className="aspect-[9/16] bg-[#090909]">
              {state.source?.kind === "video" ? (
                <video
                  className="h-full w-full object-contain"
                  src={displaySourceUri}
                  controls
                  playsInline
                />
              ) : state.source ? (
                <img
                  className="h-full w-full object-contain"
                  src={displaySourceUri}
                  alt={state.source.filename}
                />
              ) : (
                <div className="flex h-full items-center justify-center px-6 text-center text-sm leading-6 text-[var(--text-base-70)]">
                  {strings.sourceEmpty}
                </div>
              )}
            </div>
          </div>

          <div className="rounded-[22px] border border-white/8 bg-black/20 p-4">
            <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
              {strings.sourceInfoTitle}
            </p>
            <div className="mt-3 space-y-3 text-sm leading-6 text-[var(--text-base-70)]">
              {state.source ? (
                <>
                  {FILM_LAB_SOURCE_DISPLAY_PRIORITY_ORDER.includes("primaryFileIdentity") ? (
                    <div>
                      <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                        File
                      </div>
                      <div className="mt-1 break-all text-white">{state.source.filename}</div>
                    </div>
                  ) : null}
                  <div className="grid gap-2 sm:grid-cols-2">
                    <div>
                      <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                        Kind
                      </div>
                      <div className="mt-1 text-white">{state.source.kind}</div>
                    </div>
                    <div>
                      <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                        Duration
                      </div>
                      <div className="mt-1 text-white">{formatDuration(state.probe?.durationSec)}</div>
                    </div>
                    <div>
                      <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                        Resolution
                      </div>
                      <div className="mt-1 text-white">
                        {state.probe?.width && state.probe?.height
                          ? `${state.probe.width}×${state.probe.height}`
                          : "—"}
                      </div>
                    </div>
                    <div>
                      <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                        Codec
                      </div>
                      <div className="mt-1 text-white">{state.probe?.codec ?? "—"}</div>
                    </div>
                  </div>
                  {sourceViolations.length > 0 ? (
                    <div className="rounded-2xl border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-amber-100">
                      {sourceViolations.join(" · ")}
                    </div>
                  ) : (
                    <div className="rounded-2xl border border-emerald-500/20 bg-emerald-500/10 px-3 py-2 text-emerald-100">
                      {strings.sourceAllowedTitle}
                    </div>
                  )}
                </>
              ) : (
                <p>{strings.sourceEmpty}</p>
              )}
            </div>
          </div>
        </div>
      </section>

      <Phase0PresetPicker
        activePreset={state.project.presetName as PresetName}
        strings={strings}
        onPresetChange={handlePresetChange}
      />

      <Phase0QuickControls
        quickState={state.project.quickState}
        sliderResetHint={strings.sliderResetHint}
        strings={strings}
        onQuickChange={handleQuickChange}
      />

      <Phase0LutPicker
        inputLut={inputLut}
        inputLutEnabled={inputLutEnabled}
        creativeLut={state.project.lut}
        strings={strings}
        onPickInputLut={handlePickInputLut}
        onClearInputLut={handleClearInputLut}
        onToggleInputLut={handleToggleInputLut}
        onInputIntensityChange={handleInputIntensityChange}
        onPickCreativeLut={handlePickCreativeLut}
        onClearCreativeLut={() => setState((current) => applyLutSelection(current, null))}
        onCreativeIntensityChange={handleCreativeIntensityChange}
      />

      <ExportSheet
        project={state.project}
        source={state.source}
        probe={state.probe}
        exportProgress={state.exportProgress}
        exportResult={state.exportResult}
        saveToPhotosState={state.saveToPhotosState}
        visualFloor={visualFloor}
        isBusy={state.isBusy}
        isSaveBusy={isSaveBusy}
        error={state.error}
        strings={strings}
        onExport={handleExport}
        onSave={handleSave}
        onShare={handleShare}
        onVisualFloorChange={setVisualFloor}
        onShareBenchmark={handleShareBenchmark}
      />

      {state.notice ? (
        <section className="rounded-[24px] border border-sky-400/20 bg-sky-400/10 px-4 py-3 text-sm text-sky-100">
          <strong>{strings.noticePrefix}:</strong> {state.notice}
        </section>
      ) : null}
      {state.error ? (
        <section className="rounded-[24px] border border-rose-400/20 bg-rose-400/10 px-4 py-3 text-sm text-rose-100">
          <strong>{strings.errorPrefix}:</strong> {state.error}
        </section>
      ) : null}
    </div>
  );
}
