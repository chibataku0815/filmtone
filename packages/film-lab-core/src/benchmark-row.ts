import type { Phase0ExportBenchmarkRecord, Phase0ExportResult, SourceProbe } from "./native-bridge";

export type BenchmarkVisualFloor = "pass" | "fail" | "not-checked";
export type BenchmarkSaveResult = "ok" | "fail" | "not-run";

export interface BenchmarkRow {
  date: string;
  deviceModel: string;
  iosVersion: string;
  clipId: string;
  inputResolution: string;
  outputResolution: string;
  realtimeRatio: number | null;
  fileSizeMb: number | null;
  thermalState: string;
  memoryWarningCount: number;
  saveResult: BenchmarkSaveResult;
  visualFloor: BenchmarkVisualFloor;
  errorDomain: string | null;
  errorCode: string | null;
  durationSec: number | null;
}

export interface BenchmarkRowInput {
  result: Phase0ExportResult;
  benchmark: Phase0ExportBenchmarkRecord;
  probe?: SourceProbe | null;
  clipId: string;
  visualFloor: BenchmarkVisualFloor;
  saveResult: BenchmarkSaveResult;
  date?: Date;
}

const ROW_HEADER =
  "| date | device | iOS | clip_id | input_resolution | output_resolution | realtime_ratio | file_size_mb | thermal | memory_warnings | save | visual | error | duration_sec |";

const ROW_DIVIDER =
  "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |";

export function buildBenchmarkRow(input: BenchmarkRowInput): BenchmarkRow {
  const { result, benchmark, probe, clipId, visualFloor, saveResult } = input;
  const date = (input.date ?? new Date()).toISOString().slice(0, 10);

  const inputResolution =
    benchmark.sourceResolution ??
    (probe?.width && probe?.height ? `${probe.width}x${probe.height}` : "unknown");

  const outputResolution = `${result.outputWidth}x${result.outputHeight}@${result.outputFps}`;

  const fileSizeMb =
    typeof result.fileSizeBytes === "number"
      ? Math.round((result.fileSizeBytes / (1024 * 1024)) * 10) / 10
      : null;

  return {
    date,
    deviceModel: benchmark.deviceModel,
    iosVersion: benchmark.iosVersion,
    clipId,
    inputResolution,
    outputResolution,
    realtimeRatio:
      typeof result.realtimeRatio === "number" ? Math.round(result.realtimeRatio * 100) / 100 : null,
    fileSizeMb,
    thermalState: benchmark.thermalState ?? "unknown",
    memoryWarningCount:
      typeof benchmark.memoryWarningCount === "number" ? benchmark.memoryWarningCount : 0,
    saveResult,
    visualFloor,
    errorDomain: benchmark.errorDomain ?? null,
    errorCode: benchmark.errorCode ?? null,
    durationSec:
      typeof benchmark.sourceDurationSec === "number" ? benchmark.sourceDurationSec : null,
  };
}

export function formatBenchmarkRow(row: BenchmarkRow): string {
  const realtime = row.realtimeRatio != null ? `${row.realtimeRatio}x` : "—";
  const fileSize = row.fileSizeMb != null ? `${row.fileSizeMb}MB` : "—";
  const errorCell =
    row.errorDomain || row.errorCode ? `${row.errorDomain ?? "—"}:${row.errorCode ?? "—"}` : "none";
  const durationCell = row.durationSec != null ? row.durationSec.toFixed(1) : "—";

  return [
    "",
    row.date,
    row.deviceModel,
    row.iosVersion,
    row.clipId,
    row.inputResolution,
    row.outputResolution,
    realtime,
    fileSize,
    `thermal=${row.thermalState}`,
    `mem_warn=${row.memoryWarningCount}`,
    `save=${row.saveResult}`,
    `visual=${row.visualFloor}`,
    `err=${errorCell}`,
    durationCell,
    "",
  ].join(" | ").trim();
}

export function benchmarkMarkdownTableHeader(): string {
  return `${ROW_HEADER}\n${ROW_DIVIDER}`;
}

export interface ParsedBenchmarkRow extends BenchmarkRow {
  raw: string;
}

const ROW_PATTERN =
  /^\|\s*(?<date>[^|]+?)\s*\|\s*(?<device>[^|]+?)\s*\|\s*(?<iosVersion>[^|]+?)\s*\|\s*(?<clipId>[^|]+?)\s*\|\s*(?<inputRes>[^|]+?)\s*\|\s*(?<outputRes>[^|]+?)\s*\|\s*(?<realtime>[^|]+?)\s*\|\s*(?<fileSize>[^|]+?)\s*\|\s*thermal=(?<thermal>[^|]+?)\s*\|\s*mem_warn=(?<mem>[^|]+?)\s*\|\s*save=(?<save>[^|]+?)\s*\|\s*visual=(?<visual>[^|]+?)\s*\|\s*err=(?<err>[^|]+?)\s*\|\s*(?<durationSec>[^|]+?)\s*\|\s*$/;

export function parseBenchmarkRow(line: string): ParsedBenchmarkRow | null {
  const trimmed = line.trim();
  if (!trimmed.startsWith("|")) return null;
  if (trimmed.startsWith("| date |") || trimmed.startsWith("| --- |")) return null;
  const match = trimmed.match(ROW_PATTERN);
  if (!match || !match.groups) return null;
  const g = match.groups;

  const realtimeRaw = g.realtime.trim().replace(/x$/, "");
  const realtimeRatio = realtimeRaw === "—" ? null : Number.parseFloat(realtimeRaw);
  const fileRaw = g.fileSize.trim().replace(/MB$/, "");
  const fileSizeMb = fileRaw === "—" ? null : Number.parseFloat(fileRaw);

  const errorRaw = g.err.trim();
  let errorDomain: string | null = null;
  let errorCode: string | null = null;
  if (errorRaw && errorRaw !== "none") {
    const [domain, code] = errorRaw.split(":");
    errorDomain = domain && domain !== "—" ? domain : null;
    errorCode = code && code !== "—" ? code : null;
  }

  const durationRaw = g.durationSec.trim();
  const durationSec = durationRaw === "—" ? null : Number.parseFloat(durationRaw);

  return {
    raw: trimmed,
    date: g.date.trim(),
    deviceModel: g.device.trim(),
    iosVersion: g.iosVersion.trim(),
    clipId: g.clipId.trim(),
    inputResolution: g.inputRes.trim(),
    outputResolution: g.outputRes.trim(),
    realtimeRatio: realtimeRatio != null && Number.isFinite(realtimeRatio) ? realtimeRatio : null,
    fileSizeMb: fileSizeMb != null && Number.isFinite(fileSizeMb) ? fileSizeMb : null,
    thermalState: g.thermal.trim(),
    memoryWarningCount: Number.parseInt(g.mem.trim(), 10) || 0,
    saveResult: (g.save.trim() as BenchmarkSaveResult) ?? "not-run",
    visualFloor: (g.visual.trim() as BenchmarkVisualFloor) ?? "not-checked",
    errorDomain,
    errorCode,
    durationSec: durationSec != null && Number.isFinite(durationSec) ? durationSec : null,
  };
}
