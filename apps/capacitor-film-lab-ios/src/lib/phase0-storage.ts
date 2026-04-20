import {
  phase0ProjectSchema,
  type ParsedCubeLut,
  type Phase0ExportBenchmarkRecord,
  type Phase0ProjectState,
} from "film-lab-core";

const PROJECT_STORAGE_KEY = "filmtone-capacitor-ios-phase0/project/v1";
const BENCHMARK_STORAGE_KEY = "filmtone-capacitor-ios-phase0/benchmarks/v1";
const IMPORTED_LUTS_STORAGE_KEY = "filmtone-capacitor-ios-phase0/imported-luts/v1";

export interface ImportedLut {
  id: string;
  name: string;
  lut: ParsedCubeLut;
  importedAt: number;
}

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

function isImportedLut(value: unknown): value is ImportedLut {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.id === "string" &&
    typeof candidate.name === "string" &&
    typeof candidate.importedAt === "number" &&
    candidate.lut != null &&
    typeof candidate.lut === "object"
  );
}

export function loadImportedLuts(): ImportedLut[] {
  const raw = safeRead(IMPORTED_LUTS_STORAGE_KEY);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(isImportedLut);
  } catch {
    return [];
  }
}

export function saveImportedLuts(luts: readonly ImportedLut[]): void {
  safeWrite(IMPORTED_LUTS_STORAGE_KEY, JSON.stringify(luts));
}

export function appendImportedLut(entry: ImportedLut): ImportedLut[] {
  const next = [...loadImportedLuts(), entry];
  saveImportedLuts(next);
  return next;
}

export function renameImportedLut(id: string, name: string): ImportedLut[] {
  const next = loadImportedLuts().map((item) =>
    item.id === id ? { ...item, name } : item,
  );
  saveImportedLuts(next);
  return next;
}

export function removeImportedLut(id: string): ImportedLut[] {
  const next = loadImportedLuts().filter((item) => item.id !== id);
  saveImportedLuts(next);
  return next;
}
