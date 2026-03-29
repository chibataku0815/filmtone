/**
 * Film Lab バッチ — Electron メインプロセス
 *
 * @overview フォルダ選択とファイルの読み書きだけを担い、GPU はレンダラ（Chromium）に任せる。
 * @limitations パス検証は最小限。信頼できるローカル用途のスパイク向け。
 *
 * @description 設定は electron-store（userData 内 JSON）。ウィンドウ矩形と最後に選んだ入出力フォルダを覚える。
 */
import { app, BrowserWindow, dialog, ipcMain } from "electron";
import Store from "electron-store";
import fs from "node:fs/promises";
import path from "node:path";

const IMAGE_EXT = new Set([".jpg", ".jpeg", ".png"]);

/**
 * @description デスクトップアプリ用の永続キー（型で書き忘れを防ぐ）
 */
type DesktopFilmLabSettings = {
  /** @description 前回終了時のウィンドウ bounds */
  windowBounds?: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  /** @description 入力フォルダ選択の最後のパス（存在しなければ無視） */
  lastInputDir: string | null;
  /** @description 出力フォルダ選択の最後のパス */
  lastOutputDir: string | null;
};

/**
 * @description アプリ設定ストア。バッチ再開 JSON とは別ファイル。
 */
const desktopSettingsStore = new Store<DesktopFilmLabSettings>({
  name: "film-lab-desktop-settings",
  defaults: {
    lastInputDir: null,
    lastOutputDir: null,
  },
});

/** @description バッチ再開用セッション JSON（レンダラが V1 形で保存） */
const BATCH_SESSION_BASENAME = "film-lab-batch-session.json";

/**
 * @description app ready 後に呼ぶ。userData 配下のセッションファイル絶対パス。
 */
function batchSessionFilePath(): string {
  return path.join(app.getPath("userData"), BATCH_SESSION_BASENAME);
}

function isImageFile(fileName: string): boolean {
  const lower = fileName.toLowerCase();
  const ext = path.extname(lower);
  return IMAGE_EXT.has(ext);
}

async function listImagePathsInDir(dir: string): Promise<string[]> {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const out: string[] = [];
  for (const e of entries) {
    if (!e.isFile()) continue;
    if (!isImageFile(e.name)) continue;
    out.push(path.join(dir, e.name));
  }
  return out.sort((a, b) => path.basename(a).localeCompare(path.basename(b)));
}

/**
 * @description フォルダが実在するか確認し、ダイアログの defaultPath に使える文字列だけ返す。
 */
async function resolveExistingDir(
  dir: string | null | undefined,
): Promise<string | undefined> {
  if (dir == null || typeof dir !== "string" || dir.length === 0) {
    return undefined;
  }
  try {
    const st = await fs.stat(dir);
    if (st.isDirectory()) return dir;
  } catch {
    /* パス無効 */
  }
  return undefined;
}

function createWindow(): void {
  /**
   * @description ローカルで Vite が動いているとき、ウィンドウは `file://` ではなくこの URL を開く。
   * `FILM_LAB_DESKTOP_RENDERER_URL` を優先（製品向けの名前）。従来の `VITE_DEV_SERVER_URL` もそのまま使える。
   */
  const rendererHotReloadUrl =
    process.env.FILM_LAB_DESKTOP_RENDERER_URL?.trim() ||
    process.env.VITE_DEV_SERVER_URL?.trim() ||
    "";

  const savedBounds = desktopSettingsStore.get("windowBounds");
  const hasSavedSize =
    savedBounds &&
    Number.isFinite(savedBounds.width) &&
    Number.isFinite(savedBounds.height) &&
    savedBounds.width >= 400 &&
    savedBounds.height >= 320;

  const win = new BrowserWindow({
    ...(hasSavedSize
      ? {
          x: savedBounds!.x,
          y: savedBounds!.y,
          width: savedBounds!.width,
          height: savedBounds!.height,
        }
      : { width: 960, height: 720 }),
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  win.on("close", () => {
    if (!win.isDestroyed()) {
      const b = win.getBounds();
      desktopSettingsStore.set("windowBounds", b);
    }
  });

  if (rendererHotReloadUrl.length > 0) {
    void win.loadURL(rendererHotReloadUrl);
    // win.webContents.openDevTools();
  } else {
    void win.loadFile(
      path.join(__dirname, "../dist/renderer/index.html"),
    );
  }
}

app.whenReady().then(() => {
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

ipcMain.handle("desktop-prefs-get", async () => {
  const lastInputDir =
    (await resolveExistingDir(desktopSettingsStore.get("lastInputDir"))) ??
    null;
  const lastOutputDir =
    (await resolveExistingDir(desktopSettingsStore.get("lastOutputDir"))) ??
    null;
  return { lastInputDir, lastOutputDir };
});

/**
 * @description レンダラから最終フォルダを保存（バッチ実行開始時に同期する用）
 */
ipcMain.handle("desktop-prefs-set", async (_evt, payload: unknown) => {
  if (!payload || typeof payload !== "object" || payload === null) {
    throw new TypeError("desktop-prefs-set: payload がオブジェクトではありません");
  }
  const o = payload as Record<string, unknown>;
  if (typeof o.lastInputDir === "string" && o.lastInputDir.length > 0) {
    desktopSettingsStore.set("lastInputDir", o.lastInputDir);
  }
  if (typeof o.lastOutputDir === "string" && o.lastOutputDir.length > 0) {
    desktopSettingsStore.set("lastOutputDir", o.lastOutputDir);
  }
});

ipcMain.handle("pick-input-dir", async () => {
  const defaultPath = await resolveExistingDir(
    desktopSettingsStore.get("lastInputDir"),
  );
  const r = await dialog.showOpenDialog({
    properties: ["openDirectory", "createDirectory"],
    defaultPath,
  });
  if (r.canceled || r.filePaths.length === 0) return null;
  const chosen = r.filePaths[0]!;
  desktopSettingsStore.set("lastInputDir", chosen);
  return chosen;
});

ipcMain.handle("pick-output-dir", async () => {
  const defaultPath = await resolveExistingDir(
    desktopSettingsStore.get("lastOutputDir"),
  );
  const r = await dialog.showOpenDialog({
    properties: ["openDirectory", "createDirectory"],
    defaultPath,
  });
  if (r.canceled || r.filePaths.length === 0) return null;
  const chosen = r.filePaths[0]!;
  desktopSettingsStore.set("lastOutputDir", chosen);
  return chosen;
});

ipcMain.handle("pick-grade-json", async () => {
  const defaultPath =
    (await resolveExistingDir(desktopSettingsStore.get("lastInputDir"))) ??
    (await resolveExistingDir(desktopSettingsStore.get("lastOutputDir")));
  const r = await dialog.showOpenDialog({
    properties: ["openFile"],
    filters: [{ name: "JSON", extensions: ["json"] }],
    defaultPath,
  });
  if (r.canceled || r.filePaths.length === 0) return null;
  return r.filePaths[0]!;
});

ipcMain.handle("list-images", async (_evt, dir: string) => {
  if (typeof dir !== "string" || dir.length === 0) {
    throw new TypeError("pick-input-dir: list-images(dir) — dir が空です");
  }
  return listImagePathsInDir(dir);
});

ipcMain.handle("read-file-utf8", async (_evt, filePath: string) => {
  if (typeof filePath !== "string") {
    throw new TypeError("read-file-utf8: filePath が文字列ではありません");
  }
  return fs.readFile(filePath, "utf-8");
});

ipcMain.handle("read-file-buffer", async (_evt, filePath: string) => {
  if (typeof filePath !== "string") {
    throw new TypeError("read-file-buffer: filePath が文字列ではありません");
  }
  const buf = await fs.readFile(filePath);
  return new Uint8Array(buf);
});

ipcMain.handle(
  "read-cube-relative-to-grade",
  async (_evt, gradeJsonPath: string, relPath: string) => {
    if (typeof gradeJsonPath !== "string" || typeof relPath !== "string") {
      throw new TypeError(
        "read-cube-relative-to-grade: gradeJsonPath / relPath が不正です",
      );
    }
    const abs = path.resolve(path.dirname(gradeJsonPath), relPath);
    return fs.readFile(abs, "utf-8");
  },
);

ipcMain.handle("batch-session-read", async () => {
  const target = batchSessionFilePath();
  try {
    const txt = await fs.readFile(target, "utf-8");
    return JSON.parse(txt) as unknown;
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    if (err.code === "ENOENT") return null;
    throw e;
  }
});

ipcMain.handle("batch-session-write", async (_evt, payload: unknown) => {
  if (payload === undefined) {
    throw new TypeError("batch-session-write: payload が undefined です");
  }
  const target = batchSessionFilePath();
  await fs.writeFile(target, JSON.stringify(payload, null, 2), "utf-8");
});

ipcMain.handle("batch-session-clear", async () => {
  const target = batchSessionFilePath();
  try {
    await fs.unlink(target);
  } catch (e) {
    const err = e as NodeJS.ErrnoException;
    if (err.code === "ENOENT") return;
    throw e;
  }
});

ipcMain.handle(
  "write-output-file",
  async (
    _evt,
    payload: { outputDir: string; fileName: string; data: Uint8Array },
  ) => {
    const { outputDir, fileName, data } = payload;
    if (
      typeof outputDir !== "string" ||
      typeof fileName !== "string" ||
      !(data instanceof Uint8Array)
    ) {
      throw new TypeError(
        "write-output-file: outputDir / fileName / data が不正です",
      );
    }
    const safeName = path.basename(fileName);
    const target = path.join(outputDir, safeName);
    await fs.mkdir(outputDir, { recursive: true });
    await fs.writeFile(target, Buffer.from(data));
    return target;
  },
);
