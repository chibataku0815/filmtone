import {
  getPhase0SourceCapViolations,
  type Phase0ExportProgress,
  type Phase0ExportResult,
  type Phase0ProjectState,
  type SourceInfo,
  type SourceProbe,
} from "film-lab-core";

interface ExportSheetProps {
  project: Phase0ProjectState;
  source: SourceInfo | null;
  probe: SourceProbe | null;
  exportProgress: Phase0ExportProgress | null;
  exportResult: Phase0ExportResult | null;
  saveToPhotosState: "not-run" | "saved" | "failed";
  isBusy: boolean;
  isSaveBusy: boolean;
  error: string | null;
  strings: {
    exportSectionTitle: string;
    exportIdle: string;
    exportRunning: string;
    exportWritingHint: string;
    exportStart: string;
    exportDisabled: string;
    saveToPhotos: string;
    shareOutput: string;
    resultTitle: string;
    sourceViolationsTitle: string;
    sourceAllowedTitle: string;
    metricsElapsed: string;
    metricsOutput: string;
    metricsFileSize: string;
    metricsSaveToPhotos: string;
  };
  onExport: () => void;
  onSave: () => void;
  onShare: () => void;
}

function formatBytes(value?: number): string {
  if (typeof value !== "number") return "—";
  if (value > 1024 * 1024) return `${(value / (1024 * 1024)).toFixed(1)} MB`;
  if (value > 1024) return `${(value / 1024).toFixed(1)} KB`;
  return `${value} B`;
}

function formatSaveState(value: "not-run" | "saved" | "failed"): string {
  switch (value) {
    case "saved":
      return "Saved";
    case "failed":
      return "Failed";
    default:
      return "—";
  }
}

export function ExportSheet({
  source: _source,
  probe,
  exportProgress,
  exportResult,
  saveToPhotosState,
  isBusy,
  isSaveBusy,
  strings,
  onExport,
  onSave,
  onShare,
}: ExportSheetProps) {
  const violations = probe ? getPhase0SourceCapViolations(probe) : [];
  const canExport = probe != null && violations.length === 0 && !isBusy && !isSaveBusy;
  const progressPercent = exportProgress ? Math.round(exportProgress.progress * 100) : null;
  const elapsedSeconds =
    typeof exportResult?.elapsedMs === "number"
      ? (exportResult.elapsedMs / 1000).toFixed(1)
      : null;

  return (
    <section className="rounded-[24px] border border-[var(--panel-stroke)] bg-[var(--panel-fill)] p-4">
      <div className="flex items-center justify-between gap-3">
        <p className="section-header">{strings.exportSectionTitle}</p>
        <button
          type="button"
          onClick={onExport}
          disabled={!canExport}
          className="rounded-full bg-[var(--accent-amber1)] px-5 py-2 text-xs font-medium text-black transition disabled:cursor-not-allowed disabled:bg-white/10 disabled:text-white/40"
        >
          {strings.exportStart}
        </button>
      </div>

      <p className="mt-2 text-sm leading-6 text-[var(--text-base-70)]">
        {isBusy ? strings.exportRunning : strings.exportIdle}
      </p>

      {exportProgress ? (
        <div className="mt-4">
          <div className="h-2 overflow-hidden rounded-full bg-white/[0.06]">
            <div
              className="h-full rounded-full bg-[var(--accent-amber1)] transition-[width]"
              style={{ width: `${Math.max(0, Math.min(100, exportProgress.progress * 100))}%` }}
            />
          </div>
          <p className="mt-2 text-xs text-[var(--text-base-70)]">
            {progressPercent}% · {exportProgress.stage}
            {exportProgress.message ? ` · ${exportProgress.message}` : ""}
          </p>
          {typeof exportProgress.currentFrame === "number" &&
          typeof exportProgress.totalFrames === "number" ? (
            <p className="mt-1 text-xs text-[var(--text-muted)]">
              {exportProgress.currentFrame.toLocaleString()} / {exportProgress.totalFrames.toLocaleString()} frames
            </p>
          ) : null}
          {exportProgress.stage === "writing" ? (
            <p className="mt-1 text-xs text-[var(--text-muted)]">
              {strings.exportWritingHint}
            </p>
          ) : null}
        </div>
      ) : null}

      {probe && violations.length > 0 ? (
        <div className="mt-4 rounded-2xl border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-sm text-amber-100">
          <p className="font-medium">{strings.sourceViolationsTitle}</p>
          <ul className="mt-1 list-disc space-y-1 pl-5 text-amber-100/90">
            {violations.map((violation) => (
              <li key={violation}>{violation}</li>
            ))}
          </ul>
        </div>
      ) : null}

      {exportResult ? (
        <div className="mt-4 rounded-2xl border border-[var(--panel-stroke)] bg-black/20 p-3">
          <p className="section-header">{strings.resultTitle}</p>
          <div className="mt-3 grid gap-3 text-sm text-[var(--text-base-70)] sm:grid-cols-2">
            <div>
              <div className="section-header">{strings.metricsElapsed}</div>
              <div className="mt-1 text-white">{elapsedSeconds ? `${elapsedSeconds}s` : "—"}</div>
            </div>
            <div>
              <div className="section-header">{strings.metricsOutput}</div>
              <div className="mt-1 text-white">
                {exportResult.outputWidth}×{exportResult.outputHeight} @ {exportResult.outputFps}fps
              </div>
            </div>
            <div>
              <div className="section-header">{strings.metricsFileSize}</div>
              <div className="mt-1 text-white">{formatBytes(exportResult.fileSizeBytes)}</div>
            </div>
            <div>
              <div className="section-header">{strings.metricsSaveToPhotos}</div>
              <div className="mt-1 text-white">{formatSaveState(saveToPhotosState)}</div>
            </div>
          </div>

          <div className="mt-4 flex flex-wrap gap-2">
            <button
              type="button"
              onClick={onSave}
              disabled={isSaveBusy || saveToPhotosState === "saved"}
              className="rounded-full border border-white/12 bg-white/[0.05] px-3 py-2 text-xs text-white transition hover:bg-white/[0.08] disabled:cursor-not-allowed disabled:bg-white/[0.03] disabled:text-white/40"
            >
              {strings.saveToPhotos}
            </button>
            <button
              type="button"
              onClick={onShare}
              className="rounded-full border border-white/12 px-3 py-2 text-xs text-[var(--text-base-70)] transition hover:bg-white/[0.05] hover:text-white"
            >
              {strings.shareOutput}
            </button>
          </div>
        </div>
      ) : null}
    </section>
  );
}
