import os from "node:os";
import path from "node:path";
import fs from "node:fs/promises";
import { afterEach, describe, expect, it } from "vitest";

import {
  PROXY_CACHE_MAX_AGE_DAYS,
  buildProxyCacheKey,
  getProxyCacheInfo,
  proxyCacheFilePath,
  pruneProxyCache,
  purgeProxyCache,
  roundProxyCacheDurationSec,
  touchProxyCacheEntry,
  upsertProxyCacheEntry,
  type ProxyCacheManifestEntry,
  type ProxyCacheProfile,
  type ProxyCacheSourceSignature,
} from "./proxy-cache";

const tempRoots: string[] = [];

async function makeCacheRoot(): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "film-lab-proxy-cache-"));
  tempRoots.push(root);
  return root;
}

function makeProfile(overrides?: Partial<ProxyCacheProfile>): ProxyCacheProfile {
  return {
    version: "proxy-cache-v1",
    width: 1280,
    height: 720,
    encoderFlavor: "h264_videotoolbox-or-libx264",
    codec: "h264",
    bitrateLabel: "8M",
    gop: 1,
    scaleFilter: "colorspace=iall=bt709:all=bt709,scale=1280:-2,format=yuv420p",
    ...overrides,
  };
}

function makeSourceSignature(
  overrides?: Partial<ProxyCacheSourceSignature>,
): ProxyCacheSourceSignature {
  return {
    sourcePath: "/tmp/source.mov",
    sizeBytes: 1234,
    mtimeMs: 1000,
    durationSecRounded: roundProxyCacheDurationSec(12.34567),
    ...overrides,
  };
}

async function addEntry(
  cacheRoot: string,
  opts: {
    keySuffix: string;
    sizeBytes: number;
    lastAccessedAt: string;
    createdAt?: string;
    sourceSignature?: ProxyCacheSourceSignature;
    proxyProfile?: ProxyCacheProfile;
  },
): Promise<ProxyCacheManifestEntry> {
  const entry: ProxyCacheManifestEntry = {
    key: `key-${opts.keySuffix}`,
    sourcePath: `/tmp/source-${opts.keySuffix}.mov`,
    proxyPath: proxyCacheFilePath(cacheRoot, `key-${opts.keySuffix}`),
    sizeBytes: opts.sizeBytes,
    createdAt: opts.createdAt ?? "2026-04-07T00:00:00.000Z",
    lastAccessedAt: opts.lastAccessedAt,
    sourceSignature:
      opts.sourceSignature ??
      makeSourceSignature({ sourcePath: `/tmp/source-${opts.keySuffix}.mov` }),
    proxyProfile: opts.proxyProfile ?? makeProfile(),
  };
  await fs.writeFile(entry.proxyPath, Buffer.alloc(opts.sizeBytes, 1));
  await upsertProxyCacheEntry(cacheRoot, entry);
  return entry;
}

afterEach(async () => {
  await Promise.all(
    tempRoots.splice(0).map(async (root) => {
      await fs.rm(root, { recursive: true, force: true });
    }),
  );
});

describe("proxy-cache", () => {
  it("buildProxyCacheKey returns the same key for the same signature", () => {
    const first = buildProxyCacheKey({
      sourceSignature: makeSourceSignature(),
      proxyProfile: makeProfile(),
    });
    const second = buildProxyCacheKey({
      sourceSignature: makeSourceSignature(),
      proxyProfile: makeProfile(),
    });
    expect(first).toBe(second);
  });

  it("buildProxyCacheKey changes when source or profile changes", () => {
    const base = buildProxyCacheKey({
      sourceSignature: makeSourceSignature(),
      proxyProfile: makeProfile(),
    });
    const changedMtime = buildProxyCacheKey({
      sourceSignature: makeSourceSignature({ mtimeMs: 2000 }),
      proxyProfile: makeProfile(),
    });
    const changedEncoder = buildProxyCacheKey({
      sourceSignature: makeSourceSignature(),
      proxyProfile: makeProfile({ encoderFlavor: "libx264" }),
    });
    expect(changedMtime).not.toBe(base);
    expect(changedEncoder).not.toBe(base);
  });

  it("touchProxyCacheEntry updates lastAccessedAt and removes stale missing files", async () => {
    const cacheRoot = await makeCacheRoot();
    const entry = await addEntry(cacheRoot, {
      keySuffix: "a",
      sizeBytes: 5,
      lastAccessedAt: "2026-04-01T00:00:00.000Z",
    });
    await fs.unlink(entry.proxyPath);

    const touched = await touchProxyCacheEntry(cacheRoot, entry.key);
    expect(touched).toBeNull();

    const info = await getProxyCacheInfo(cacheRoot);
    expect(info.entryCount).toBe(0);
    expect(info.totalBytes).toBe(0);
  });

  it("pruneProxyCache removes oldest entries over count/bytes and clears orphan files", async () => {
    const cacheRoot = await makeCacheRoot();
    await addEntry(cacheRoot, {
      keySuffix: "old",
      sizeBytes: 10,
      lastAccessedAt: "2026-04-01T00:00:00.000Z",
    });
    await addEntry(cacheRoot, {
      keySuffix: "mid",
      sizeBytes: 10,
      lastAccessedAt: "2026-04-02T00:00:00.000Z",
    });
    const newest = await addEntry(cacheRoot, {
      keySuffix: "new",
      sizeBytes: 10,
      lastAccessedAt: "2026-04-03T00:00:00.000Z",
    });
    await fs.writeFile(path.join(cacheRoot, "proxy-orphan.mp4"), "orphan");

    const result = await pruneProxyCache(cacheRoot, {
      maxEntries: 2,
      maxTotalBytes: 15,
      maxAgeDays: PROXY_CACHE_MAX_AGE_DAYS,
      nowMs: Date.parse("2026-04-07T00:00:00.000Z"),
    });

    expect(result.removedEntries).toBe(2);
    expect(result.remainingEntries).toBe(1);
    expect(await fs.stat(newest.proxyPath)).toBeTruthy();
    expect(
      await fs
        .stat(path.join(cacheRoot, "proxy-orphan.mp4"))
        .then(() => true)
        .catch(() => false),
    ).toBe(false);
  });

  it("pruneProxyCache removes expired entries by lastAccessedAt", async () => {
    const cacheRoot = await makeCacheRoot();
    const stale = await addEntry(cacheRoot, {
      keySuffix: "stale",
      sizeBytes: 10,
      lastAccessedAt: "2026-03-01T00:00:00.000Z",
    });
    await addEntry(cacheRoot, {
      keySuffix: "fresh",
      sizeBytes: 10,
      lastAccessedAt: "2026-04-06T00:00:00.000Z",
    });

    const result = await pruneProxyCache(cacheRoot, {
      nowMs: Date.parse("2026-04-07T00:00:00.000Z"),
    });

    expect(result.removedEntries).toBe(1);
    expect(
      await fs
        .stat(stale.proxyPath)
        .then(() => true)
        .catch(() => false),
    ).toBe(false);
    const info = await getProxyCacheInfo(cacheRoot);
    expect(info.entryCount).toBe(1);
  });

  it("purgeProxyCache removes manifest entries and files", async () => {
    const cacheRoot = await makeCacheRoot();
    await addEntry(cacheRoot, {
      keySuffix: "a",
      sizeBytes: 10,
      lastAccessedAt: "2026-04-01T00:00:00.000Z",
    });
    await addEntry(cacheRoot, {
      keySuffix: "b",
      sizeBytes: 20,
      lastAccessedAt: "2026-04-02T00:00:00.000Z",
    });

    const result = await purgeProxyCache(cacheRoot);
    const info = await getProxyCacheInfo(cacheRoot);

    expect(result.removedEntries).toBe(2);
    expect(result.removedBytes).toBe(30);
    expect(info.entryCount).toBe(0);
    expect(info.totalBytes).toBe(0);
  });
});
