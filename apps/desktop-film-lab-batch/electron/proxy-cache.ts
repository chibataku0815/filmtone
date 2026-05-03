import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

export const PROXY_CACHE_MANIFEST_VERSION = 1;
export const PROXY_CACHE_PROFILE_VERSION = "proxy-cache-v2";
export const PROXY_CACHE_MAX_ENTRIES = 8;
export const PROXY_CACHE_MAX_TOTAL_BYTES = 2 * 1024 * 1024 * 1024;
export const PROXY_CACHE_MAX_AGE_DAYS = 14;
const PROXY_CACHE_MANIFEST_BASENAME = "manifest.json";

export type ProxyCacheSourceSignature = {
  sourcePath: string;
  sizeBytes: number;
  mtimeMs: number;
  durationSecRounded: number;
};

export type ProxyCacheProfile = {
  version: string;
  width: number;
  height: number;
  encoderFlavor: string;
  codec: string;
  bitrateLabel: string;
  gop: number;
  scaleFilter: string;
};

export type ProxyCacheManifestEntry = {
  key: string;
  sourcePath: string;
  proxyPath: string;
  sizeBytes: number;
  createdAt: string;
  lastAccessedAt: string;
  sourceSignature: ProxyCacheSourceSignature;
  proxyProfile: ProxyCacheProfile;
};

type ProxyCacheManifest = {
  version: number;
  entries: ProxyCacheManifestEntry[];
};

export type ProxyCacheInfo = {
  entryCount: number;
  totalBytes: number;
  maxEntries: number;
  maxTotalBytes: number;
  maxAgeDays: number;
};

export type ProxyCachePruneResult = {
  removedEntries: number;
  removedBytes: number;
  remainingEntries: number;
  remainingBytes: number;
};

function manifestPath(cacheRoot: string): string {
  return path.join(cacheRoot, PROXY_CACHE_MANIFEST_BASENAME);
}

function proxyCacheManifestBaseline(): ProxyCacheManifest {
  return {
    version: PROXY_CACHE_MANIFEST_VERSION,
    entries: [],
  };
}

async function fileExists(targetPath: string): Promise<boolean> {
  try {
    const stat = await fs.stat(targetPath);
    return stat.isFile();
  } catch {
    return false;
  }
}

function sanitizeEntry(entry: ProxyCacheManifestEntry): ProxyCacheManifestEntry {
  return {
    ...entry,
    sourcePath: path.resolve(entry.sourcePath),
    proxyPath: path.resolve(entry.proxyPath),
  };
}

async function readManifest(cacheRoot: string): Promise<ProxyCacheManifest> {
  const target = manifestPath(cacheRoot);
  try {
    const raw = await fs.readFile(target, "utf8");
    const parsed = JSON.parse(raw) as unknown;
    if (
      typeof parsed !== "object" ||
      parsed == null ||
      !Array.isArray((parsed as { entries?: unknown[] }).entries)
    ) {
      return proxyCacheManifestBaseline();
    }
    return {
      version:
        typeof (parsed as { version?: unknown }).version === "number"
          ? (parsed as { version: number }).version
          : PROXY_CACHE_MANIFEST_VERSION,
      entries: (parsed as { entries: ProxyCacheManifestEntry[] }).entries.map(
        sanitizeEntry,
      ),
    };
  } catch {
    return proxyCacheManifestBaseline();
  }
}

async function writeManifest(
  cacheRoot: string,
  manifest: ProxyCacheManifest,
): Promise<void> {
  await fs.mkdir(cacheRoot, { recursive: true });
  await fs.writeFile(
    manifestPath(cacheRoot),
    `${JSON.stringify(manifest, null, 2)}\n`,
    "utf8",
  );
}

async function removeFileIfPresent(targetPath: string): Promise<number> {
  try {
    const stat = await fs.stat(targetPath);
    if (!stat.isFile()) {
      return 0;
    }
    await fs.unlink(targetPath);
    return stat.size;
  } catch {
    return 0;
  }
}

async function normalizeManifest(cacheRoot: string): Promise<{
  manifest: ProxyCacheManifest;
  removedEntries: number;
  removedBytes: number;
}> {
  await fs.mkdir(cacheRoot, { recursive: true });
  const manifest = await readManifest(cacheRoot);
  let changed = false;
  let removedEntries = 0;
  let removedBytes = 0;
  const existingEntries: ProxyCacheManifestEntry[] = [];

  for (const entry of manifest.entries) {
    if (await fileExists(entry.proxyPath)) {
      existingEntries.push(entry);
      continue;
    }
    changed = true;
    removedEntries += 1;
    removedBytes += entry.sizeBytes;
  }

  const trackedPaths = new Set(
    existingEntries.map((entry) => path.resolve(entry.proxyPath)),
  );
  const names = await fs.readdir(cacheRoot);
  for (const name of names) {
    if (name === PROXY_CACHE_MANIFEST_BASENAME) {
      continue;
    }
    const candidate = path.join(cacheRoot, name);
    if (trackedPaths.has(path.resolve(candidate))) {
      continue;
    }
    const removedSize = await removeFileIfPresent(candidate);
    if (removedSize > 0) {
      changed = true;
      removedBytes += removedSize;
    }
  }

  if (changed) {
    const nextManifest = {
      version: PROXY_CACHE_MANIFEST_VERSION,
      entries: existingEntries,
    };
    await writeManifest(cacheRoot, nextManifest);
    return { manifest: nextManifest, removedEntries, removedBytes };
  }

  return { manifest, removedEntries, removedBytes };
}

export async function ensureProxyCacheRoot(cacheRoot: string): Promise<void> {
  await fs.mkdir(cacheRoot, { recursive: true });
}

export function roundProxyCacheDurationSec(durationSec: number): number {
  return Math.round(durationSec * 1000) / 1000;
}

export function buildProxyCacheKey(input: {
  sourceSignature: ProxyCacheSourceSignature;
  proxyProfile: ProxyCacheProfile;
}): string {
  return createHash("sha256")
    .update(
      JSON.stringify({
        sourceSignature: {
          ...input.sourceSignature,
          sourcePath: path.resolve(input.sourceSignature.sourcePath),
        },
        proxyProfile: input.proxyProfile,
      }),
    )
    .digest("hex");
}

export function proxyCacheFilePath(cacheRoot: string, key: string): string {
  return path.join(cacheRoot, `proxy-${key}.mp4`);
}

export async function touchProxyCacheEntry(
  cacheRoot: string,
  key: string,
): Promise<ProxyCacheManifestEntry | null> {
  const { manifest } = await normalizeManifest(cacheRoot);
  const entry = manifest.entries.find((item) => item.key === key);
  if (entry == null) {
    return null;
  }
  const now = new Date().toISOString();
  const nextEntries = manifest.entries.map((item) =>
    item.key === key ? { ...item, lastAccessedAt: now } : item,
  );
  const nextEntry = nextEntries.find((item) => item.key === key) ?? null;
  await writeManifest(cacheRoot, {
    version: PROXY_CACHE_MANIFEST_VERSION,
    entries: nextEntries,
  });
  return nextEntry;
}

export async function upsertProxyCacheEntry(
  cacheRoot: string,
  entry: ProxyCacheManifestEntry,
): Promise<void> {
  await fs.mkdir(cacheRoot, { recursive: true });
  const manifest = await readManifest(cacheRoot);
  const nextEntries = manifest.entries.filter((item) => item.key !== entry.key);
  nextEntries.push(sanitizeEntry(entry));
  await writeManifest(cacheRoot, {
    version: PROXY_CACHE_MANIFEST_VERSION,
    entries: nextEntries,
  });
}

export async function pruneProxyCache(
  cacheRoot: string,
  opts?: {
    maxEntries?: number;
    maxTotalBytes?: number;
    maxAgeDays?: number;
    nowMs?: number;
  },
): Promise<ProxyCachePruneResult> {
  const maxEntries = opts?.maxEntries ?? PROXY_CACHE_MAX_ENTRIES;
  const maxTotalBytes = opts?.maxTotalBytes ?? PROXY_CACHE_MAX_TOTAL_BYTES;
  const maxAgeDays = opts?.maxAgeDays ?? PROXY_CACHE_MAX_AGE_DAYS;
  const nowMs = opts?.nowMs ?? Date.now();
  const maxAgeMs = maxAgeDays * 24 * 60 * 60 * 1000;
  const normalized = await normalizeManifest(cacheRoot);
  const activeEntries = [...normalized.manifest.entries];
  let removedEntries = normalized.removedEntries;
  let removedBytes = normalized.removedBytes;

  const survivors = activeEntries.filter((entry) => {
    const lastAccessedMs = Date.parse(entry.lastAccessedAt);
    if (!Number.isFinite(lastAccessedMs)) {
      return true;
    }
    return nowMs - lastAccessedMs <= maxAgeMs;
  });

  for (const entry of activeEntries) {
    if (survivors.includes(entry)) {
      continue;
    }
    removedEntries += 1;
    removedBytes += await removeFileIfPresent(entry.proxyPath);
  }

  survivors.sort(
    (a, b) =>
      Date.parse(a.lastAccessedAt) - Date.parse(b.lastAccessedAt),
  );

  let totalBytes = survivors.reduce((sum, entry) => sum + entry.sizeBytes, 0);
  while (survivors.length > maxEntries || totalBytes > maxTotalBytes) {
    const oldest = survivors.shift();
    if (oldest == null) {
      break;
    }
    removedEntries += 1;
    totalBytes -= oldest.sizeBytes;
    removedBytes += await removeFileIfPresent(oldest.proxyPath);
  }

  await writeManifest(cacheRoot, {
    version: PROXY_CACHE_MANIFEST_VERSION,
    entries: survivors,
  });

  return {
    removedEntries,
    removedBytes,
    remainingEntries: survivors.length,
    remainingBytes: Math.max(0, totalBytes),
  };
}

export async function purgeProxyCache(
  cacheRoot: string,
): Promise<{ removedEntries: number; removedBytes: number }> {
  const { manifest } = await normalizeManifest(cacheRoot);
  let removedBytes = 0;
  for (const entry of manifest.entries) {
    removedBytes += await removeFileIfPresent(entry.proxyPath);
  }
  const names = await fs.readdir(cacheRoot).catch(() => [] as string[]);
  for (const name of names) {
    if (name === PROXY_CACHE_MANIFEST_BASENAME) {
      continue;
    }
    removedBytes += await removeFileIfPresent(path.join(cacheRoot, name));
  }
  await writeManifest(cacheRoot, proxyCacheManifestBaseline());
  return {
    removedEntries: manifest.entries.length,
    removedBytes,
  };
}

export async function getProxyCacheInfo(
  cacheRoot: string,
): Promise<ProxyCacheInfo> {
  const { manifest } = await normalizeManifest(cacheRoot);
  const totalBytes = manifest.entries.reduce(
    (sum, entry) => sum + entry.sizeBytes,
    0,
  );
  return {
    entryCount: manifest.entries.length,
    totalBytes,
    maxEntries: PROXY_CACHE_MAX_ENTRIES,
    maxTotalBytes: PROXY_CACHE_MAX_TOTAL_BYTES,
    maxAgeDays: PROXY_CACHE_MAX_AGE_DAYS,
  };
}
