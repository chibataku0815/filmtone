import {
  PHASE0_APPROX_SOURCE_LONG_EDGE_MAX,
  PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES,
  PHASE0_MAX_SOURCE_DURATION_SEC,
  PHASE0_OUTPUT_PROFILE,
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
    validationTargetTitle: string;
    validationTargetBody: string;
    validationTargetFootnote: string;
    resultTitle: string;
    benchmarkTitle: string;
    benchmarkBody: string;
    reducedParamsTitle: string;
    reducedParamsBody: string;
    sourceViolationsTitle: string;
    sourceAllowedTitle: string;
    metricsElapsed: string;
    metricsRealtime: string;
    metricsOutput: string;
    metricsFileSize: string;
    metricsThermal: string;
    metricsMemoryWarnings: string;
    metricsSaveToPhotos: string;
    validationReportTitle: string;
    validationReportBody: string;
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

function formatDuration(value?: number): string {
  if (typeof value !== "number") return "—";
  if (value < 60) return `${value.toFixed(1)}s`;
  const minutes = Math.floor(value / 60);
  const seconds = Math.round(value % 60);
  return `${minutes}m ${seconds}s`;
}

function formatSaveState(value: "not-run" | "saved" | "failed"): string {
  switch (value) {
    case "saved":
      return "Pass";
    case "failed":
      return "Failed";
    default:
      return "Not run";
  }
}

export function ExportSheet({
  project,
  source,
  probe,
  exportProgress,
  exportResult,
  saveToPhotosState,
  isBusy,
  isSaveBusy,
  error,
  strings,
  onExport,
  onSave,
  onShare,
}: ExportSheetProps) {
  const violations = probe ? getPhase0SourceCapViolations(probe) : [];
  const canExport = probe != null && violations.length === 0 && !isBusy && !isSaveBusy;
  const benchmarkRecord = exportResult?.benchmarkRecord;
  const progressPercent = exportProgress ? Math.round(exportProgress.progress * 100) : null;
  const settingsProfile = [
    `preset=${project.presetName}`,
    `creativeLUT=${project.lut ? project.lut.title : "none"}`,
    `grain=${project.params.grainIntensity > 0 ? project.params.grainIntensity.toFixed(2) : "off"}`,
  ].join(" | ");
  const validationReport = exportResult
    ? [
        `Device: ${benchmarkRecord?.deviceModel ?? "—"}`,
        `iOS: ${benchmarkRecord?.iosVersion ?? "—"}`,
        `Clip: ${source?.filename ?? "—"}`,
        `Source codec: ${probe?.codec ?? "—"}`,
        `Source resolution: ${probe?.width && probe?.height ? `${probe.width}x${probe.height}` : "—"}`,
        `Source duration: ${formatDuration(probe?.durationSec)}`,
        `Settings profile: ${settingsProfile}`,
        `Import: ${source && probe ? "pass" : "not-run"}`,
        `Export: pass`,
        `Save to Photos: ${formatSaveState(saveToPhotosState)}`,
        `Elapsed: ${exportResult.elapsedMs} ms`,
        `Realtime ratio: ${typeof exportResult.realtimeRatio === "number" ? `${exportResult.realtimeRatio.toFixed(2)}x` : "—"}`,
        `Output resolution / fps: ${exportResult.outputWidth}x${exportResult.outputHeight} @ ${exportResult.outputFps}fps`,
        `Output file size: ${formatBytes(exportResult.fileSizeBytes)}`,
        `Thermal state: ${benchmarkRecord?.thermalState ?? "—"}`,
        `Memory warnings: ${typeof benchmarkRecord?.memoryWarningCount === "number" ? (benchmarkRecord.memoryWarningCount > 0 ? `yes (${benchmarkRecord.memoryWarningCount})` : "no") : "—"}`,
        `Black frame: manual-check`,
        `Visual floor: manual-check`,
        `Errors: ${error ?? benchmarkRecord?.errorCode ?? "—"}`,
      ].join("\n")
    : null;

  return (
    <section className="rounded-[24px] border border-white/10 bg-white/[0.03] p-4">
      <div className="flex items-center justify-between gap-3">
        <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
          {strings.exportSectionTitle}
        </p>
        <button
          type="button"
          onClick={onExport}
          disabled={!canExport}
          className="rounded-full bg-[var(--accent-amber1)] px-4 py-2 text-xs font-medium text-black transition disabled:cursor-not-allowed disabled:bg-white/10 disabled:text-white/40"
        >
          {strings.exportStart}
        </button>
      </div>

      <p className="mt-2 text-sm leading-6 text-[var(--text-base-70)]">
        {isBusy ? strings.exportRunning : strings.exportIdle}
      </p>

      {exportProgress ? (
        <div className="mt-4">
          <div className="h-2 overflow-hidden rounded-full bg-white/8">
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

      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        <div className="rounded-2xl border border-white/8 bg-black/20 p-3">
          <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
            {violations.length > 0
              ? strings.sourceViolationsTitle
              : strings.sourceAllowedTitle}
          </p>
          <div className="mt-2 space-y-2 text-sm leading-6 text-[var(--text-base-70)]">
            {probe ? (
              <>
                <p>
                  max {PHASE0_MAX_SOURCE_DURATION_SEC / 60} min · long edge {PHASE0_APPROX_SOURCE_LONG_EDGE_MAX}px · size {Math.round(
                    PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES / (1024 * 1024 * 1024),
                  )} GB
                </p>
                {violations.length > 0 ? (
                  <ul className="list-disc space-y-1 pl-5">
                    {violations.map((violation) => (
                      <li key={violation}>{violation}</li>
                    ))}
                  </ul>
                ) : null}
              </>
            ) : (
              <p>{strings.exportDisabled}</p>
            )}
          </div>
        </div>

        <div className="rounded-2xl border border-white/8 bg-black/20 p-3">
          <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
            {strings.benchmarkTitle}
          </p>
          <p className="mt-2 text-sm leading-6 text-[var(--text-base-70)]">
            {strings.benchmarkBody}
          </p>
          <p className="mt-3 text-xs text-[var(--text-muted)]">
            {PHASE0_OUTPUT_PROFILE.codec.toUpperCase()} / {PHASE0_OUTPUT_PROFILE.container.toUpperCase()} / {PHASE0_OUTPUT_PROFILE.fps}fps / {PHASE0_OUTPUT_PROFILE.longEdge}px long edge
          </p>
        </div>
      </div>

      <div className="mt-4 rounded-2xl border border-white/8 bg-black/20 p-3">
        <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
          {strings.validationTargetTitle}
        </p>
        <p className="mt-2 text-sm leading-6 text-[var(--text-base-70)]">
          {strings.validationTargetBody}
        </p>
        <p className="mt-3 text-xs text-[var(--text-muted)]">
          {strings.validationTargetFootnote}
        </p>
      </div>

      <div className="mt-4 rounded-2xl border border-white/8 bg-black/20 p-3">
        <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
          {strings.reducedParamsTitle}
        </p>
        <p className="mt-2 text-sm leading-6 text-[var(--text-base-70)]">
          {strings.reducedParamsBody}
        </p>
      </div>

      {exportResult ? (
        <div className="mt-4 rounded-2xl border border-white/8 bg-black/20 p-3">
          <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
            {strings.resultTitle}
          </p>
          <div className="mt-3 grid gap-3 text-sm text-[var(--text-base-70)] sm:grid-cols-2">
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.metricsElapsed}
              </div>
              <div className="mt-1 text-white">{exportResult.elapsedMs} ms</div>
            </div>
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.metricsRealtime}
              </div>
              <div className="mt-1 text-white">
                {typeof exportResult.realtimeRatio === "number"
                  ? `${exportResult.realtimeRatio.toFixed(2)}x`
                  : "—"}
              </div>
            </div>
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.metricsOutput}
              </div>
              <div className="mt-1 text-white">
                {exportResult.outputWidth}×{exportResult.outputHeight} @ {exportResult.outputFps}fps
              </div>
            </div>
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.metricsFileSize}
              </div>
              <div className="mt-1 text-white">{formatBytes(exportResult.fileSizeBytes)}</div>
            </div>
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.metricsThermal}
              </div>
              <div className="mt-1 text-white">{benchmarkRecord?.thermalState ?? "—"}</div>
            </div>
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.metricsMemoryWarnings}
              </div>
              <div className="mt-1 text-white">
                {typeof benchmarkRecord?.memoryWarningCount === "number"
                  ? benchmarkRecord.memoryWarningCount
                  : "—"}
              </div>
            </div>
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.metricsSaveToPhotos}
              </div>
              <div className="mt-1 text-white">{formatSaveState(saveToPhotosState)}</div>
            </div>
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                Settings
              </div>
              <div className="mt-1 text-white">{settingsProfile}</div>
            </div>
          </div>

          <div className="mt-4 flex gap-2">
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

          {validationReport ? (
            <div className="mt-4 rounded-2xl border border-white/8 bg-[#090909] p-3">
              <p className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.validationReportTitle}
              </p>
              <p className="mt-2 text-sm leading-6 text-[var(--text-base-70)]">
                {strings.validationReportBody}
              </p>
              <pre className="mt-3 overflow-x-auto whitespace-pre-wrap break-words rounded-xl border border-white/8 bg-black/30 p-3 text-xs leading-6 text-white">
                {validationReport}
              </pre>
            </div>
          ) : null}
        </div>
      ) : null}
    </section>
  );
}
