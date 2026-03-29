/**
 * Film Lab バッチ — Electron メインプロセス
 *
 * @overview フォルダ選択とファイルの読み書きだけを担い、GPU はレンダラ（Chromium）に任せる。
 * @limitations パス検証は最小限。信頼できるローカル用途のスパイク向け。
 */
import { app, BrowserWindow, dialog, ipcMain } from "electron";
import fs from "node:fs/promises";
import path from "node:path";

const IMAGE_EXT = new Set([".jpg", ".jpeg", ".png"]);

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

function createWindow(): void {
  const devServer = process.env.VITE_DEV_SERVER_URL;

  const win = new BrowserWindow({
    width: 960,
    height: 720,
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  if (devServer) {
    void win.loadURL(devServer);
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

ipcMain.handle("pick-input-dir", async () => {
  const r = await dialog.showOpenDialog({
    properties: ["openDirectory", "createDirectory"],
  });
  if (r.canceled || r.filePaths.length === 0) return null;
  return r.filePaths[0]!;
});

ipcMain.handle("pick-output-dir", async () => {
  const r = await dialog.showOpenDialog({
    properties: ["openDirectory", "createDirectory"],
  });
  if (r.canceled || r.filePaths.length === 0) return null;
  return r.filePaths[0]!;
});

ipcMain.handle("pick-grade-json", async () => {
  const r = await dialog.showOpenDialog({
    properties: ["openFile"],
    filters: [{ name: "JSON", extensions: ["json"] }],
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
