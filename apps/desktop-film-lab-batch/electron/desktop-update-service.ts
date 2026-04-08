/**
 * @file 起動後の更新メタ取得とレンダラへの通知のまとめ役
 * @overview URL が無ければ何もしません。取得できて版が新しければ IPC で知らせ、書き出し中は後回しにキューします。
 * @limitations 自動インストールはしません（案 C: 通知 + 手動 DMG）。
 */
import type { BrowserWindow } from "electron";
import Store from "electron-store";
import { fetchDesktopUpdateMeta } from "./desktop-update-meta";
import { compareSemverStrings } from "./semver-compare";

/** @description レンダラがバナー表示に使うペイロード */
export type DesktopUpdateNotifyPayload = {
  latestVersion: string;
  downloadPageUrl: string;
  releaseNotesUrl?: string;
};

type UpdateDismissStore = {
  /** @description 「後で」で消した版。同じ版はしばらく再通知しない */
  dismissedUpdateVersion?: string;
};

const FETCH_TIMEOUT_MS = 15_000;
/** @description renderer ready が来ない異常系でも、一定時間後に初回チェックする */
const INITIAL_CHECK_DELAY_MS = 45_000;
/** @description 定期チェック間隔（24 時間） */
const PERIODIC_CHECK_MS = 24 * 60 * 60 * 1000;

/**
 * @description メイン内だけが持つ、更新チェックの状態機械
 */
export class DesktopUpdateService {
  /** @description ユーザーが「後で」した版の記憶 */
  private readonly dismissStore = new Store<UpdateDismissStore>({
    name: "film-lab-desktop-update-check",
  });

  /** @description 迷子にならないよう、ぶら下がり通知を 1 つまで保持 */
  private pendingPayload: DesktopUpdateNotifyPayload | null = null;

  /** @description レンダラから「長い書き出し中」 */
  private rendererExportBusy = false;

  private initialTimer: ReturnType<typeof setTimeout> | null = null;

  private periodicTimer: ReturnType<typeof setInterval> | null = null;

  private hasTriggeredInitialCheck = false;

  /**
   * @param getWindow いまのアクティブウィンドウ（閉じたら null）
   * @param getCheckUrl 更新 JSON の HTTPS URL（無ければチェック全体をオフ）
   * @param getAppVersion `app.getVersion()` など
   * @param isMainHeavy ffmpeg 動画パイプなどメインが忙しいとき true
   */
  constructor(
    private readonly getWindow: () => BrowserWindow | null,
    private readonly getCheckUrl: () => string | null,
    private readonly getAppVersion: () => string,
    private readonly isMainHeavy: () => boolean,
  ) {}

  /**
   * @description 写真バッチや動画 UI から、まとめて書き出し中フラグを同期する
   */
  setRendererExportBusy(busy: boolean): void {
    this.rendererExportBusy = busy;
    if (!busy) {
      this.flushPendingNotification();
    }
  }

  /**
   * @description ユーザーの「後で」。同じ latestVersion は store に残して抑止
   */
  dismissVersion(version: string): void {
    this.dismissStore.set("dismissedUpdateVersion", version);
    this.pendingPayload = null;
  }

  /**
   * @description キューに残っていた通知を、条件が整えば送り直す
   */
  flushPendingNotification(): void {
    const payload = this.pendingPayload;
    if (!payload) return;
    this.trySendOrQueue(payload);
  }

  /**
   * @description `did-finish-load` 後など、ウィンドウがReadyになったタイミングで呼ぶ
   */
  onRendererLoaded(): void {
    this.flushPendingNotification();
    this.triggerInitialCheck();
  }

  /**
   * @description 初回遅延 + 24h ごとのタイマーを張る
   */
  startSchedule(): void {
    const url = this.getCheckUrl();
    if (!url) {
      console.log(
        "[film-lab-desktop] desktop-update: チェック URL 未設定（FILM_LAB_DESKTOP_UPDATE_CHECK_URL / ビルド埋め込み）— スキップ",
      );
      return;
    }
    console.log("[film-lab-desktop] desktop-update: スケジュール開始");
    this.initialTimer = setTimeout(() => {
      this.triggerInitialCheck();
    }, INITIAL_CHECK_DELAY_MS);
    this.periodicTimer = setInterval(() => {
      void this.runCheckOnce();
    }, PERIODIC_CHECK_MS);
  }

  /**
   * @description アプリ終了時にタイマーを切る（テストや将来の hot reload 用）
   */
  dispose(): void {
    if (this.initialTimer != null) {
      clearTimeout(this.initialTimer);
      this.initialTimer = null;
    }
    if (this.periodicTimer != null) {
      clearInterval(this.periodicTimer);
      this.periodicTimer = null;
    }
  }

  /**
   * @description 外部（手動「更新を確認」ボタンが将来付く場合）向けの単発実行
   */
  async runCheckOnce(): Promise<void> {
    const url = this.getCheckUrl();
    if (!url) return;
    const current = this.getAppVersion();
    const meta = await fetchDesktopUpdateMeta(
      url,
      current,
      FETCH_TIMEOUT_MS,
    );
    if (!meta) return;
    if (compareSemverStrings(meta.latestVersion, current) <= 0) {
      return;
    }
    const dismissed = this.dismissStore.get("dismissedUpdateVersion");
    if (dismissed === meta.latestVersion) {
      return;
    }
    const payload: DesktopUpdateNotifyPayload = {
      latestVersion: meta.latestVersion,
      downloadPageUrl: meta.downloadPageUrl,
      ...(meta.releaseNotesUrl
        ? { releaseNotesUrl: meta.releaseNotesUrl }
        : {}),
    };
    this.trySendOrQueue(payload);
  }

  /**
   * @description 書き出し中・ロード中は pending に残す
   */
  private trySendOrQueue(payload: DesktopUpdateNotifyPayload): void {
    const win = this.getWindow();
    const loading =
      win != null &&
      !win.isDestroyed() &&
      win.webContents.isLoadingMainFrame();
    const busy =
      this.rendererExportBusy || this.isMainHeavy() || loading;
    if (busy) {
      this.pendingPayload = payload;
      return;
    }
    this.pendingPayload = null;
    if (win == null || win.isDestroyed()) {
      return;
    }
    win.webContents.send("film-lab-desktop-update-available", payload);
  }

  private triggerInitialCheck(): void {
    if (this.hasTriggeredInitialCheck) {
      return;
    }
    this.hasTriggeredInitialCheck = true;
    if (this.initialTimer != null) {
      clearTimeout(this.initialTimer);
      this.initialTimer = null;
    }
    void this.runCheckOnce();
  }
}

/**
 * @description ビルド時 define とランタイム env のどちらかで URL を決める
 */
export function resolveDesktopUpdateCheckUrl(): string | null {
  const env = process.env.FILM_LAB_DESKTOP_UPDATE_CHECK_URL?.trim() ?? "";
  if (env.length > 0) {
    return env;
  }
  const embedded =
    typeof FILM_LAB_EMBEDDED_UPDATE_CHECK_URL === "string"
      ? FILM_LAB_EMBEDDED_UPDATE_CHECK_URL.trim()
      : "";
  if (embedded.length > 0) {
    return embedded;
  }
  return null;
}
