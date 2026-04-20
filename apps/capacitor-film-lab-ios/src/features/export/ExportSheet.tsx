import {
  getPhase0SourceCapViolations,
  type Phase0ExportProgress,
  type Phase0ExportResult,
  type Phase0ProjectState,
  type SourceInfo,
  type SourceProbe,
} from "film-lab-core";
import {
  CheckIcon,
  ExportIcon,
  ShareIcon,
} from "@/components/FilmtoneIcons";

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
    sourceInfoTitle: string;
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

function formatDuration(value?: number): string {
  if (typeof value !== "number" || Number.isNaN(value)) return "—";
  const roundedTenth = Math.round(value * 10) / 10;
  if (roundedTenth < 60) return `${roundedTenth.toFixed(1)}s`;
  const totalSeconds = Math.round(value);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}m ${seconds}s`;
}

function formatSourceDetails(probe: SourceProbe | null): string[] {
  if (!probe) return [];
  const parts: string[] = [];
  if (typeof probe.width === "number" && typeof probe.height === "number") {
    parts.push(`${probe.width}×${probe.height}`);
  }
  if (typeof probe.durationSec === "number") {
    parts.push(formatDuration(probe.durationSec));
  }
  if (probe.codec) {
    parts.push(probe.codec.toUpperCase());
  }
  return parts;
}

export function ExportSheet({
  project,
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
  const sourceDetails = formatSourceDetails(probe);
  const outputSummary = `${project.output.longEdge}px · ${project.output.codec.toUpperCase()} · ${project.output.fps}fps`;

  return (
    <section className="squircle-xl p-5 liquid-panel">
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <h2 className="text-[1.25rem] font-semibold tracking-[-0.02em] text-white">
            {exportResult ? strings.resultTitle : strings.exportSectionTitle}
          </h2>
          <p className="mt-1 text-sm leading-6 text-[var(--text-base-70)]">
            {isBusy ? strings.exportRunning : strings.exportIdle}
          </p>
        </div>
        <button
          type="button"
          onClick={onExport}
          disabled={!canExport}
          className="inline-flex min-h-[44px] shrink-0 items-center gap-2 squircle-pill bg-[var(--accent-amber1)] px-5 py-2.5 text-xs font-semibold text-black transition active:brightness-[0.98] disabled:cursor-not-allowed disabled:bg-white/10 disabled:text-white/40"
        >
          <ExportIcon className="h-4 w-4" />
          {strings.exportStart}
        </button>
      </div>

      <div className="mt-5 space-y-4">
        {probe ? (
          <p className="font-mono text-[11px] text-white/54">
            {violations.length === 0 ? "✓" : "!"} {sourceDetails.join(" · ")}
          </p>
        ) : null}

        {probe && violations.length > 0 ? (
          <div className="squircle-md bg-amber-500/8 px-4 py-3 text-sm text-amber-50/95">
            <ul className="list-disc space-y-1 pl-5 text-amber-50/80">
              {violations.map((violation) => (
                <li key={violation}>{violation}</li>
              ))}
            </ul>
          </div>
        ) : null}

        {exportProgress ? (
          <div className="squircle-md bg-black/[0.16] p-4">
            <div className="h-2.5 overflow-hidden rounded-full bg-white/[0.05]">
              <div
                className="h-full rounded-full bg-[var(--accent-amber1)] transition-[width]"
                style={{ width: `${Math.max(0, Math.min(100, exportProgress.progress * 100))}%` }}
              />
            </div>
            <p className="mt-3 text-sm text-white/84">
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
              <p className="mt-2 text-xs leading-5 text-[var(--text-muted)]">
                {strings.exportWritingHint}
              </p>
            ) : null}
          </div>
        ) : exportResult ? (
          <div className="grid gap-3 sm:grid-cols-2">
            <MetricTile
              label={strings.metricsElapsed}
              value={elapsedSeconds ? `${elapsedSeconds}s` : "—"}
            />
            <MetricTile
              label={strings.metricsOutput}
              value={`${exportResult.outputWidth}×${exportResult.outputHeight} @ ${exportResult.outputFps}fps`}
            />
            <MetricTile
              label={strings.metricsFileSize}
              value={formatBytes(exportResult.fileSizeBytes)}
            />
            <MetricTile
              label={strings.saveToPhotos}
              value={formatSaveState(saveToPhotosState)}
            />
          </div>
        ) : (
          <p className="font-mono text-[11px] text-white/54">{outputSummary}</p>
        )}

        {exportResult ? (
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={onSave}
              disabled={isSaveBusy || saveToPhotosState === "saved"}
              className="inline-flex min-h-[44px] items-center gap-2 squircle-pill bg-[var(--accent-amber1)] px-4 py-2.5 text-xs font-semibold text-black transition active:brightness-[0.98] disabled:cursor-not-allowed disabled:bg-white/10 disabled:text-white/40"
            >
              <CheckIcon className="h-4 w-4" />
              {strings.saveToPhotos}
            </button>
            <button
              type="button"
              onClick={onShare}
              className="inline-flex min-h-[44px] items-center gap-2 squircle-pill bg-white/[0.03] px-4 py-2.5 text-xs font-medium text-[var(--text-base-70)] transition active:bg-white/[0.06] active:text-white"
            >
              <ShareIcon className="h-4 w-4" />
              {strings.shareOutput}
            </button>
          </div>
        ) : null}
      </div>
    </section>
  );
}

function MetricTile({ label, value }: { label: string; value: string }) {
  return (
    <div className="squircle-sm bg-white/[0.03] p-3">
      <p className="editor-kicker">{label}</p>
      <p className="mt-2 text-[15px] leading-6 text-white/92">{value}</p>
    </div>
  );
}
