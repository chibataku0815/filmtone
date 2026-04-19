import {
  phase0ProjectSchema,
  type Phase0ExportBenchmarkRecord,
  type Phase0ProjectState,
} from "film-lab-core";

const PROJECT_STORAGE_KEY = "filmtone-capacitor-ios-phase0/project/v1";
const BENCHMARK_STORAGE_KEY = "filmtone-capacitor-ios-phase0/benchmarks/v1";

function isStorageAvailable(): boolean {
  return typeof window !== "undefined" && typeof window.localStorage !== "undefined";
}

function safeRead(key: string): string | null {
  if (!isStorageAvailable()) return null;
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function safeWrite(key: string, value: string): void {
  if (!isStorageAvailable()) return;
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // Non-fatal for the kill-test shell.
  }
}

export function loadPhase0Project(): Phase0ProjectState | null {
  const raw = safeRead(PROJECT_STORAGE_KEY);
  if (!raw) return null;

  try {
    return phase0ProjectSchema.parse(JSON.parse(raw));
  } catch {
    return null;
  }
}

export function savePhase0Project(project: Phase0ProjectState): void {
  safeWrite(PROJECT_STORAGE_KEY, JSON.stringify(project));
}

function isBenchmarkRecord(value: unknown): value is Phase0ExportBenchmarkRecord {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.deviceModel === "string" &&
    typeof candidate.iosVersion === "string" &&
    typeof candidate.elapsedMs === "number"
  );
}

export function loadBenchmarkRecords(): Phase0ExportBenchmarkRecord[] {
  const raw = safeRead(BENCHMARK_STORAGE_KEY);
  if (!raw) return [];

  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(isBenchmarkRecord);
  } catch {
    return [];
  }
}

export function appendBenchmarkRecord(
  record: Phase0ExportBenchmarkRecord,
): Phase0ExportBenchmarkRecord[] {
  const next = [...loadBenchmarkRecords(), record];
  safeWrite(BENCHMARK_STORAGE_KEY, JSON.stringify(next));
  return next;
}
