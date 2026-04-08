import { beforeEach, describe, expect, it, vi } from "vitest";
import type { BrowserWindow } from "electron";
import { DesktopUpdateService } from "./desktop-update-service";
import { fetchDesktopUpdateMeta } from "./desktop-update-meta";

vi.mock("electron-store", () => {
  class MockStore<T extends Record<string, unknown>> {
    private readonly data = new Map<string, unknown>();

    get<K extends keyof T & string>(key: K): T[K] | undefined {
      return this.data.get(key) as T[K] | undefined;
    }

    set<K extends keyof T & string>(key: K, value: T[K]): void {
      this.data.set(key, value);
    }
  }

  return { default: MockStore };
});

vi.mock("./desktop-update-meta", () => ({
  fetchDesktopUpdateMeta: vi.fn(),
}));

function createWindow({
  loading = false,
  send = vi.fn(),
}: {
  loading?: boolean;
  send?: ReturnType<typeof vi.fn>;
} = {}): BrowserWindow {
  return {
    isDestroyed: () => false,
    webContents: {
      isLoadingMainFrame: () => loading,
      send,
    },
  } as unknown as BrowserWindow;
}

describe("DesktopUpdateService", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("runs the first update check when the renderer finishes loading", async () => {
    const send = vi.fn();
    const fetchDesktopUpdateMetaMock = fetchDesktopUpdateMeta as ReturnType<
      typeof vi.fn
    >;
    fetchDesktopUpdateMetaMock.mockResolvedValue({
      schemaVersion: 1,
      latestVersion: "0.6.0",
      downloadPageUrl: "https://example.com/download",
    });
    const service = new DesktopUpdateService(
      () => createWindow({ send }),
      () => "https://example.com/update-meta.json",
      () => "0.5.0",
      () => false,
    );

    service.startSchedule();
    service.onRendererLoaded();
    await Promise.resolve();

    expect(fetchDesktopUpdateMeta).toHaveBeenCalledTimes(1);
    expect(send).toHaveBeenCalledWith(
      "film-lab-desktop-update-available",
      {
        latestVersion: "0.6.0",
        downloadPageUrl: "https://example.com/download",
      },
    );
  });

  it("queues the notification while the renderer is still loading and flushes it later", async () => {
    const send = vi.fn();
    let loading = true;
    const fetchDesktopUpdateMetaMock = fetchDesktopUpdateMeta as ReturnType<
      typeof vi.fn
    >;
    fetchDesktopUpdateMetaMock.mockResolvedValue({
      schemaVersion: 1,
      latestVersion: "0.6.0",
      downloadPageUrl: "https://example.com/download",
      releaseNotesUrl: "https://example.com/release-notes",
    });
    const service = new DesktopUpdateService(
      () => createWindow({ loading, send }),
      () => "https://example.com/update-meta.json",
      () => "0.5.0",
      () => false,
    );

    await service.runCheckOnce();
    expect(send).not.toHaveBeenCalled();

    loading = false;
    service.onRendererLoaded();

    expect(send).toHaveBeenCalledWith(
      "film-lab-desktop-update-available",
      {
        latestVersion: "0.6.0",
        downloadPageUrl: "https://example.com/download",
        releaseNotesUrl: "https://example.com/release-notes",
      },
    );
  });
});
