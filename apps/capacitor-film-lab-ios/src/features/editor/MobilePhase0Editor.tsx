import { Capacitor } from "@capacitor/core";
import { useEffect, useState } from "react";
import {
  PRESET_BUTTONS,
  getPhase0SourceCapViolations,
  parseCube,
  serializeCubeLut,
  type ParsedCubeLut,
  type Phase0RenderMode,
  type QuickAxisId,
  type PresetName,
} from "film-lab-core";
import type { AppStrings } from "@/lib/messages";
import {
  appendBenchmarkRecord,
  appendImportedLut,
  loadImportedLuts,
  loadPhase0Project,
  removeImportedLut,
  renameImportedLut,
  savePhase0Project,
  type ImportedLut,
} from "@/lib/phase0-storage";
import {
  applyCompareHeld,
  applyDepthEnabled,
  applyInputLutSelection,
  applyPresetSelection,
  applyPreviewRenderFailure,
  applyPreviewRenderResult,
  applyPreviewRenderStart,
  applyProbe,
  applyQuickState,
  applyRenderMode,
  applyStrength,
  buildEditorExportRequest,
  createInitialEditorState,
} from "@/lib/phase0-state";
import { filmtoneMedia } from "@/native/filmtoneMedia";
import { ExportSheet } from "@/features/export/ExportSheet";
import { TopChrome } from "./TopChrome";
import { PreviewCanvas } from "./PreviewCanvas";
import { FullscreenPreview } from "./FullscreenPreview";
import { CameraProfilePill, type CameraProfile } from "./CameraProfilePill";
import { PresetRow } from "./PresetRow";
import { StrengthSheet } from "./StrengthSheet";
import { LutManagerModal } from "@/features/lut-manager/LutManagerModal";
import {
  ReplaceIcon,
} from "@/components/FilmtoneIcons";

const V1_CAMERA_PROFILES: ReadonlyArray<CameraProfile> = ["auto", "custom"];
const PREVIEW_RENDER_DEBOUNCE_MS = 120;

function makeImportedLutId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `lut_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

function toDisplayUri(uri: string | null | undefined): string | undefined {
  if (!uri) return undefined;
  if (Capacitor.isNativePlatform()) {
    return Capacitor.convertFileSrc(uri);
  }
  return uri;
}

function lutsMatch(a: ParsedCubeLut | null, b: ParsedCubeLut | null): boolean {
  if (a === b) return true;
  if (!a || !b) return false;
  if (a.title !== b.title || a.size !== b.size || a.data.length !== b.data.length) {
    return false;
  }
  for (let index = 0; index < a.data.length; index += 1) {
    if (a.data[index] !== b.data[index]) {
      return false;
    }
  }
  return true;
}

function findActiveImportedLutId(
  imports: readonly ImportedLut[],
  activeLut: ParsedCubeLut | null,
): string | null {
  const match = imports.find((entry) => lutsMatch(entry.lut, activeLut));
  return match?.id ?? null;
}

function formatPercentLabel(value: number): string {
  return `${Math.round(value * 100)}%`;
}

function formatSignedPercentLabel(value: number): string {
  const sign = value > 0 ? "+" : "";
  return `${sign}${Math.round(value * 100)}%`;
}

function formatDurationCompact(value?: number): string | null {
  if (typeof value !== "number" || Number.isNaN(value)) return null;
  const roundedTenth = Math.round(value * 10) / 10;
  if (roundedTenth < 60) return `${roundedTenth.toFixed(1)}s`;
  const totalSeconds = Math.round(value);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}m ${seconds}s`;
}

interface MobilePhase0EditorProps {
  strings: AppStrings;
}

export function MobilePhase0Editor({ strings }: MobilePhase0EditorProps) {
  const [state, setState] = useState(() =>
    createInitialEditorState(loadPhase0Project() ?? undefined),
  );
  const [isSaveBusy, setIsSaveBusy] = useState(false);
  const [strengthSheetOpen, setStrengthSheetOpen] = useState(false);
  const [importedLuts, setImportedLuts] = useState<ImportedLut[]>(() => loadImportedLuts());
  const [lutManagerOpen, setLutManagerOpen] = useState(false);
  const [fullscreenOpen, setFullscreenOpen] = useState(false);

  const activeImportedLutId = findActiveImportedLutId(
    importedLuts,
    state.project.inputLut,
  );
  const cameraProfile: CameraProfile = state.project.inputLut ? "custom" : "auto";
  const selectedPreviewUri = state.isCompareHeld
    ? state.preview.originalPosterUri ?? state.preview.gradedPosterUri
    : state.preview.gradedPosterUri ?? state.preview.originalPosterUri;
  const displayPreviewUri = toDisplayUri(selectedPreviewUri);
  const previewEmptyMessage = state.source
    ? state.preview.error ?? strings.previewRendering
    : strings.sourceEmpty;
  const surfacedError = state.error ?? state.preview.error;
  const sourceCapViolations = state.probe ? getPhase0SourceCapViolations(state.probe) : [];
  const canGradeSource = state.probe != null && sourceCapViolations.length === 0;

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

  useEffect(() => {
    if (!state.source) {
      return undefined;
    }

    const request = buildEditorExportRequest(state);
    if (!request) {
      return undefined;
    }

    let cancelled = false;
    setState((current) => applyPreviewRenderStart(current));

    const timer = window.setTimeout(async () => {
      try {
        const result = await filmtoneMedia.renderPreviewFrame(request);
        if (cancelled) return;
        setState((current) => applyPreviewRenderResult(current, result));
      } catch (error) {
        if (cancelled) return;
        const detail = error instanceof Error ? error.message : String(error);
        setState((current) => applyPreviewRenderFailure(current, detail));
      }
    }, PREVIEW_RENDER_DEBOUNCE_MS);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [state.source?.uri, state.project.updatedAt]);

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
    setState((current) => applyStrength(current, value));
  }

  function handleStrengthReset() {
    setState((current) => {
      const quickReset = applyQuickState(current, {
        filmCharacter: 0,
        era: 0,
        dynamics: 0,
      });
      return applyStrength(quickReset, 1);
    });
  }

  function handleCompareHoldStart() {
    setState((current) => applyCompareHeld(current, true));
  }

  function handleCompareHoldEnd() {
    setState((current) => applyCompareHeld(current, false));
  }

  function handleRenderModeChange(mode: Phase0RenderMode) {
    setState((current) => applyRenderMode(current, mode));
  }

  function handleDepthEnabledChange(enabled: boolean) {
    setState((current) => applyDepthEnabled(current, enabled));
  }

  function handleCameraProfileSelect(profile: CameraProfile) {
    if (profile === "auto") {
      setState((current) => applyInputLutSelection(current, null));
    }
  }

  function handleActivateImportedLut(id: string) {
    const entry = importedLuts.find((item) => item.id === id);
    if (!entry) return;
    setState((current) => applyInputLutSelection(current, entry.lut));
  }

  function handleDeactivateImportedLut() {
    setState((current) => applyInputLutSelection(current, null));
  }

  function handleRenameImportedLut(id: string, name: string) {
    const next = renameImportedLut(id, name);
    setImportedLuts(next);
  }

  function handleDeleteImportedLut(id: string) {
    const next = removeImportedLut(id);
    setImportedLuts(next);
    if (activeImportedLutId === id) {
      setState((current) => applyInputLutSelection(current, null));
    }
  }

  async function handlePickFreshLut() {
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
      const entry: ImportedLut = {
        id: makeImportedLutId(),
        name: parsed.title || picked.filename,
        lut,
        importedAt: Date.now(),
      };
      const next = appendImportedLut(entry);
      setImportedLuts(next);
      setState((current) => applyInputLutSelection(current, lut));
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
      const request = buildEditorExportRequest(state);
      if (!request) {
        setState((current) => ({ ...current, error: strings.exportDisabled }));
        return;
      }
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
      await filmtoneMedia.shareOutput({
        uri: state.exportResult.outputUri,
        sidecarUri: state.exportResult.sidecarUri,
        packageFileUris: state.exportResult.packageFileUris,
      });
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
  const quickSummary = [
    {
      label: strings.quickFilmCharacter,
      value: state.project.quickState.filmCharacter,
    },
    {
      label: strings.quickEra,
      value: state.project.quickState.era,
    },
    {
      label: strings.quickDynamics,
      value: state.project.quickState.dynamics,
    },
  ].filter((entry) => Math.abs(entry.value) >= 0.01);
  const quickSummaryText =
    quickSummary.length > 0
      ? quickSummary
          .map((entry) => `${entry.label} ${formatSignedPercentLabel(entry.value)}`)
          .join(" · ")
      : strings.quickHint;
  const previewMetaLabel = [
    state.preview.width != null && state.preview.height != null
      ? `${state.preview.width}×${state.preview.height}`
      : state.probe?.width != null && state.probe?.height != null
        ? `${state.probe.width}×${state.probe.height}`
        : null,
    state.preview.posterTimeSec != null
      ? formatDurationCompact(state.preview.posterTimeSec)
      : null,
  ]
    .filter((value): value is string => value != null)
    .join(" · ");
  const previewAspectRatio =
    state.preview.width != null && state.preview.height != null
      ? state.preview.width / state.preview.height
      : state.probe?.width != null && state.probe?.height != null
        ? state.probe.width / state.probe.height
        : undefined;
  const cameraProfileLabels: Record<CameraProfile, string> = {
    auto: strings.cameraProfileAuto,
    rec709: strings.cameraProfileRec709,
    "apple-log": strings.cameraProfileAppleLog,
    "dji-dlog": strings.cameraProfileDlog,
    "canon-clog": strings.cameraProfileClog,
    "canon-log3-cinema-gamut": strings.cameraProfileClog3CineGamut,
    slog3: strings.cameraProfileSlog3,
    vlog: strings.cameraProfileVlog,
    custom: strings.cameraProfileCustom,
  };

  return (
    <div className="relative min-h-screen overflow-hidden">
      <TopChrome
        appName={strings.appName}
        modeLabel={strings.quickModeLabel}
        sourceLabel={state.source?.filename}
        onMenuOpen={() => setLutManagerOpen(true)}
        menuLabel={strings.topMenuLabel}
        autoHide={state.source != null}
      />

      <div className="mx-auto flex w-full max-w-3xl flex-col gap-5 px-4 pb-[calc(env(safe-area-inset-bottom,0px)+24px)] pt-[calc(env(safe-area-inset-top,0px)+80px)] sm:px-6">
        <section className="flex flex-col gap-4">
          <div className="flex items-center justify-between gap-4">
            <div className="flex min-w-0 items-center gap-2.5">
              <h1 className="truncate text-[1.5rem] font-semibold tracking-[-0.03em] text-white">
                {state.source ? activePresetLabel : strings.appName}
              </h1>
              {state.source && canGradeSource ? (
                <span
                  className="h-1.5 w-1.5 rounded-full bg-[var(--accent-amber1)]"
                  aria-label={strings.sourceAllowedTitle}
                />
              ) : null}
            </div>

            <button
              type="button"
              onClick={handlePickSource}
              disabled={state.isBusy || isSaveBusy}
              className="inline-flex min-h-[44px] shrink-0 items-center gap-2 squircle-pill bg-[var(--accent-amber1)] px-5 py-2.5 text-xs font-semibold text-black transition active:brightness-[0.98] disabled:cursor-not-allowed disabled:bg-white/10 disabled:text-white/40"
            >
              <ReplaceIcon className="h-4 w-4" />
              {state.source ? strings.repickSource : strings.pickSource}
            </button>
          </div>

          <PreviewCanvas
            source={state.source ? { filename: state.source.filename } : null}
            displayUri={displayPreviewUri}
            emptyMessage={previewEmptyMessage}
            compareLabel={strings.compareLabel}
            isRendering={state.preview.isRendering}
            metaLabel={previewMetaLabel || undefined}
            mediaAspectRatio={previewAspectRatio}
            isComparing={state.isCompareHeld}
            onPressHoldStart={handleCompareHoldStart}
            onPressHoldEnd={handleCompareHoldEnd}
            onExpand={state.source ? () => setFullscreenOpen(true) : undefined}
          />
        </section>

        <section className="grid gap-4">
          <PresetRow
            activePreset={state.project.presetName as PresetName}
            presets={PRESET_BUTTONS.map((preset) => ({
              name: preset.name,
              label: preset.label,
              subtitle: preset.subtitle,
              category: preset.category,
            }))}
            onPresetSelect={handlePresetSelect}
            onPresetReTap={handlePresetReTap}
            ariaLabel={strings.presetRowAriaLabel}
            activeHint={strings.presetTapAgainHint}
            categoryLabels={{
              filmStock: strings.presetCategoryFilmStock,
              look: strings.presetCategoryLook,
              utility: strings.presetCategoryUtility,
            }}
          />

          <div className="grid gap-4 sm:grid-cols-2">
            <button
              type="button"
              onClick={() => setStrengthSheetOpen(true)}
              className="squircle-lg bg-white/[0.02] p-4 text-left shadow-panel transition-transform active:scale-[0.98]"
            >
              <div className="flex items-baseline gap-2">
                <h2 className="text-[1.5rem] font-semibold tracking-[-0.03em] text-white">
                  {formatPercentLabel(state.project.strength)}
                </h2>
                <span className="text-[11px] text-white/50">
                  {strings.strengthLabel}
                </span>
              </div>
              <p className="mt-2 text-sm leading-6 text-[var(--text-base-70)]">
                {quickSummaryText}
              </p>
            </button>

            <CameraProfilePill
              active={cameraProfile}
              customLutTitle={cameraProfile === "custom" ? state.project.inputLut?.title : undefined}
              onSelect={handleCameraProfileSelect}
              onPickCustomLut={() => setLutManagerOpen(true)}
              cameraLabel={strings.lutInputSlotName}
              description={strings.lutInputSlotDescription}
              closeLabel={strings.lutManagerClose}
              profileLabels={cameraProfileLabels}
              profiles={V1_CAMERA_PROFILES}
            />
          </div>
        </section>

        <ExportSheet
          project={state.project}
          source={state.source}
          probe={state.probe}
          exportProgress={state.exportProgress}
          exportResult={state.exportResult}
          saveToPhotosState={state.saveToPhotosState}
          isBusy={state.isBusy}
          isSaveBusy={isSaveBusy}
          error={surfacedError}
          renderMode={state.renderMode}
          depthEnabled={state.depthEnabled}
          depthAvailable={state.probe?.hasDepth === true}
          strings={strings}
          onRenderModeChange={handleRenderModeChange}
          onDepthEnabledChange={handleDepthEnabledChange}
          onExport={handleExport}
          onSave={handleSave}
          onShare={handleShare}
        />

        {state.notice ? (
          <section className="squircle-lg bg-sky-400/10 px-4 py-3 text-sm text-sky-100">
            <strong>{strings.noticePrefix}:</strong> {state.notice}
          </section>
        ) : null}
        {surfacedError ? (
          <section className="squircle-lg bg-rose-400/10 px-4 py-3 text-sm text-rose-100">
            <strong>{strings.errorPrefix}:</strong> {surfacedError}
          </section>
        ) : null}
      </div>

      <FullscreenPreview
        isOpen={fullscreenOpen}
        onClose={() => setFullscreenOpen(false)}
        sourceKind={state.source?.kind ?? "image"}
        imageUri={displayPreviewUri}
        videoUri={state.source?.kind === "video" ? toDisplayUri(state.source.uri) : undefined}
        filename={state.source?.filename}
        closeLabel={strings.lutManagerClose}
      />

      <StrengthSheet
        isOpen={strengthSheetOpen}
        onClose={() => setStrengthSheetOpen(false)}
        presetLabel={activePresetLabel}
        strength={state.project.strength}
        onStrengthChange={handleStrengthChange}
        onCompareHoldStart={handleCompareHoldStart}
        onCompareHoldEnd={handleCompareHoldEnd}
        onReset={handleStrengthReset}
        closeLabel={strings.lutManagerClose}
        resetLabel={strings.resetLabel}
        compareLabel={strings.compareLabel}
        strengthLabel={strings.strengthLabel}
        quickHint={strings.quickHint}
        sliderResetHint={strings.sliderResetHint}
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

      <LutManagerModal
        isOpen={lutManagerOpen}
        onClose={() => setLutManagerOpen(false)}
        imports={importedLuts}
        activeLutId={activeImportedLutId}
        onPickFreshLut={handlePickFreshLut}
        onActivateLut={handleActivateImportedLut}
        onDeactivateLut={handleDeactivateImportedLut}
        onRenameLut={handleRenameImportedLut}
        onDeleteLut={handleDeleteImportedLut}
        strings={{
          lutManagerTitle: strings.lutManagerTitle,
          lutManagerEmpty: strings.lutManagerEmpty,
          lutManagerImport: strings.lutManagerImport,
          lutManagerActiveBadge: strings.lutManagerActiveBadge,
          lutManagerRename: strings.lutManagerRename,
          lutManagerDelete: strings.lutManagerDelete,
          lutManagerClose: strings.lutManagerClose,
        }}
      />
    </div>
  );
}
