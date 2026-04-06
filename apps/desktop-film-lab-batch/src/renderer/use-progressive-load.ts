"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { FilmLabBatchBridge } from "./desktop-api";

/**
 * @description Progressive loading の現在地です。
 * `stage` は「いま裏で何を進めているか」も表すため、サムネイル表示中でも proxy 生成が始まると
 * `proxy` へ進みます。
 */
export type ProgressiveStage = "idle" | "thumbnail" | "proxy" | "mezzanine" | "ready";

/**
 * @description 画面にいま見せているプレビュー品質ラベルです。
 * `thumbnail` と `proxy` はどちらも SD バッジ表示に使います。
 */
export type ProgressiveQualityLabel = "thumbnail" | "proxy" | "hd" | null;

/**
 * @description 初回ロードで FilmLabCanvas へ返すメディアの種類です。
 */
export type ProgressiveMediaKind = "image" | "video";

/**
 * @description 初回ロードで FilmLabCanvas に返す結果です。
 * サムネイル失敗時は proxy / mezzanine が最初の成功ステージになることがあります。
 */
export type ProgressiveInitialPreviewResult = {
  /** @description custom protocol 経由で読める URL */
  url: string;
  /** @description 元ファイル名。VideoTexture 読み込み時のラベルに使います */
  fileName: string;
  /** @description 画像か動画か。FilmLabCanvas 側の load 経路分岐用です */
  mediaKind: ProgressiveMediaKind;
  /** @description 初回に返したステージ */
  stage: "thumbnail" | "proxy" | "mezzanine";
  /** @description 読み込む画像 / 動画の横幅 */
  width: number;
  /** @description 読み込む画像 / 動画の縦幅 */
  height: number;
};

/**
 * @description 背景で新しいテクスチャが準備できたとき、FilmLabCanvas へ swap を依頼する最小ペイロードです。
 */
export type ProgressiveTextureSwapPayload = {
  /** @description custom protocol 経由で読める URL */
  url: string;
  /** @description 元ファイル名。VideoTexture 読み込み時のラベルに使います */
  fileName: string;
  /** @description 背景 swap の対象。初回ロードの thumbnail は含みません */
  stage: "proxy" | "mezzanine";
};

/**
 * @description hook 内部で追跡する tmp ファイル一覧です。
 */
type ProgressiveTempFiles = {
  /** @description Stage 1 の JPEG サムネイル */
  thumbnailPath: string | null;
  /** @description Stage 2 の proxy MP4 */
  proxyPath: string | null;
  /** @description Stage 3 の mezzanine MP4 */
  mezzaninePath: string | null;
};

/**
 * @description 画面表示用の state です。
 */
type ProgressiveLoadState = {
  /** @description いま裏で進めている段階。完了時は ready */
  stage: ProgressiveStage;
  /** @description 画面に見せている品質ラベル */
  qualityLabel: ProgressiveQualityLabel;
  /** @description 0-100 の進捗。proxy / mezzanine 中だけ動きます */
  stageProgress: number;
  /** @description 単調増加のセッション番号。古い完了通知を無効化するために使います */
  sessionId: number;
  /** @description 背景変換がまだ続いているか */
  isTranscoding: boolean;
  /** @description いま Progressive loading を管理している元動画の絶対パス */
  activeSourcePath: string | null;
  /** @description cleanup 用の tmp ファイル一覧 */
  tempFiles: ProgressiveTempFiles;
};

/**
 * @description hook の公開 API です。
 */
export type UseProgressiveLoadReturn = {
  /** @description 画面に見せている品質ラベル */
  qualityLabel: ProgressiveQualityLabel;
  /** @description 0-100 の進捗 */
  stageProgress: number;
  /** @description 背景変換が走っているか */
  isTranscoding: boolean;
  /** @description いま裏で進めている段階 */
  stage: ProgressiveStage;
  /** @description Progressive loading 管理中の元動画の絶対パス */
  activeSourcePath: string | null;
  /** @description 生成済み mezzanine の tmp パス。エクスポートで再利用可能。stage=ready のとき有効 */
  mezzaninePath: string | null;
  /**
   * @description 高速に最初のプレビューを返し、背景で proxy → mezzanine を進めます。
   * サムネイル失敗時は proxy / mezzanine が初回結果になることがあります。
   */
  startProgressiveLoad: (
    absPath: string,
    fileName: string,
    probe: Awaited<ReturnType<FilmLabBatchBridge["videoExportProbe"]>>,
    onTextureSwap: (payload: ProgressiveTextureSwapPayload) => Promise<void>,
  ) => Promise<ProgressiveInitialPreviewResult | null>;
  /** @description 進行中セッションを無効化し、proxy / mezzanine を止めて tmp を掃除します */
  cancel: () => void;
};

/**
 * @description 新しい空の tmp ファイル一覧を返します。
 */
function createEmptyTempFiles(): ProgressiveTempFiles {
  return {
    thumbnailPath: null,
    proxyPath: null,
    mezzaninePath: null,
  };
}

/**
 * @description 絶対パスから表示用ファイル名を取り出します。
 * Node.js の `path.basename` を使わず、renderer でもそのまま動く小さな関数にしています。
 */
function basenameFromAbsolutePath(absPath: string): string {
  const normalized = absPath.replace(/\\/g, "/");
  const lastSlash = normalized.lastIndexOf("/");
  return lastSlash >= 0 ? normalized.slice(lastSlash + 1) : normalized;
}

/**
 * @description thumbnail / proxy 用の表示サイズを計算します。
 * main 側の `scale=1280:-2` と合わせて、高さだけ偶数にそろえます。
 */
function computeProxyDimensions(sourceWidth: number, sourceHeight: number): {
  width: number;
  height: number;
} {
  const safeSourceWidth =
    Number.isFinite(sourceWidth) && sourceWidth > 0 ? sourceWidth : 1920;
  const safeSourceHeight =
    Number.isFinite(sourceHeight) && sourceHeight > 0 ? sourceHeight : 1080;
  const width = 1280;
  const height = Math.max(
    2,
    Math.round((width * safeSourceHeight) / safeSourceWidth) & ~1,
  );
  return { width, height };
}

/**
 * @description mezzanine の出力サイズを計算します。
 * 既存 export と同じく FHD を上限にし、高さは偶数へそろえます。
 */
function computeMezzanineDimensions(sourceWidth: number, sourceHeight: number): {
  outW: number;
  outH: number;
} {
  const safeSourceWidth =
    Number.isFinite(sourceWidth) && sourceWidth > 0 ? sourceWidth : 1920;
  const safeSourceHeight =
    Number.isFinite(sourceHeight) && sourceHeight > 0 ? sourceHeight : 1080;
  const outW = Math.min(safeSourceWidth, 1920);
  const outH = Math.max(
    2,
    Math.round((outW * safeSourceHeight) / safeSourceWidth) & ~1,
  );
  return { outW, outH };
}

/**
 * @description `null` や重複を除いたパス配列へ変換します。
 */
function compactPaths(paths: Array<string | null>): string[] {
  return [...new Set(paths.filter((value): value is string => typeof value === "string"))];
}

/**
 * @description Desktop Electron 専用の Progressive loading hook です。
 * Session ID で古い完了通知を捨て、tmp cleanup と IPC 購読解除もここでまとめて行います。
 */
export function useProgressiveLoad(): UseProgressiveLoadReturn {
  const [state, setState] = useState<ProgressiveLoadState>({
    stage: "idle",
    qualityLabel: null,
    stageProgress: 0,
    sessionId: 0,
    isTranscoding: false,
    activeSourcePath: null,
    tempFiles: createEmptyTempFiles(),
  });
  const sessionIdRef = useRef(0);
  const tempFilesRef = useRef<ProgressiveTempFiles>(createEmptyTempFiles());
  const proxyUnsubscribeRef = useRef<(() => void) | null>(null);
  const mezzanineUnsubscribeRef = useRef<(() => void) | null>(null);
  const unmountedRef = useRef(false);

  /**
   * @description いまの session がまだ有効かを返します。
   * 新しいファイル選択や cancel 後に古い Promise が終わっても、ここで弾きます。
   */
  const isCurrentSession = useCallback((sessionId: number): boolean => {
    return !unmountedRef.current && sessionIdRef.current === sessionId;
  }, []);

  /**
   * @description tempFilesRef を正として、画面表示用 state へ必要な差分だけ流し込みます。
   */
  const updateSessionState = useCallback(
    (
      sessionId: number,
      patch: Partial<Omit<ProgressiveLoadState, "sessionId" | "tempFiles">>,
    ): void => {
      if (!isCurrentSession(sessionId)) {
        return;
      }
      setState((prev) => ({
        ...prev,
        ...patch,
        sessionId,
        tempFiles: { ...tempFilesRef.current },
      }));
    },
    [isCurrentSession],
  );

  /**
   * @description progress 購読を両方解除します。
   */
  const unsubscribeProgress = useCallback((): void => {
    proxyUnsubscribeRef.current?.();
    proxyUnsubscribeRef.current = null;
    mezzanineUnsubscribeRef.current?.();
    mezzanineUnsubscribeRef.current = null;
  }, []);

  /**
   * @description tmp ファイルをまとめて削除します。
   */
  const unlinkPaths = useCallback(async (paths: Array<string | null>): Promise<void> => {
    const uniquePaths = compactPaths(paths);
    await Promise.all(
      uniquePaths.map(async (tempPath) => {
        try {
          await window.filmLabBatch.videoExportUnlinkStaged(tempPath);
        } catch {
          /* ignore */
        }
      }),
    );
  }, []);

  /**
   * @description progress stage 用 subprocess を止めます。
   * thumbnail は短命なので abort IPC を作らず、proxy / mezzanine のみ止めます。
   */
  const abortBackgroundStages = useCallback(async (): Promise<void> => {
    await Promise.all([
      window.filmLabBatch.videoPreviewAbortProxy().catch(() => {}),
      window.filmLabBatch.videoExportAbortMezzanine().catch(() => {}),
    ]);
  }, []);

  /**
   * @description 新しいセッション開始前に旧セッションを片付けます。
   * state はすぐ新しい sourcePath へ切り替え、旧 subprocess 側の完了は sessionId で無効化します。
   */
  const beginSession = useCallback(
    async (absPath: string): Promise<number> => {
      const previousTempFiles = tempFilesRef.current;
      const nextSessionId = sessionIdRef.current + 1;
      sessionIdRef.current = nextSessionId;
      tempFilesRef.current = createEmptyTempFiles();
      unsubscribeProgress();
      await abortBackgroundStages();
      void unlinkPaths(Object.values(previousTempFiles));
      setState({
        stage: "idle",
        qualityLabel: null,
        stageProgress: 0,
        sessionId: nextSessionId,
        isTranscoding: false,
        activeSourcePath: absPath,
        tempFiles: createEmptyTempFiles(),
      });
      return nextSessionId;
    },
    [abortBackgroundStages, unlinkPaths, unsubscribeProgress],
  );

  /**
   * @description state と ref の両方へ tmp パスを書き込みます。
   */
  const assignTempFile = useCallback(
    (
      sessionId: number,
      key: keyof ProgressiveTempFiles,
      nextPath: string | null,
    ): void => {
      if (!isCurrentSession(sessionId)) {
        return;
      }
      tempFilesRef.current = {
        ...tempFilesRef.current,
        [key]: nextPath,
      };
      updateSessionState(sessionId, {});
    },
    [isCurrentSession, updateSessionState],
  );

  /**
   * @description 指定ステージの tmp を削除し、ref/state の参照も消します。
   */
  const unlinkStageTempFile = useCallback(
    async (sessionId: number, key: keyof ProgressiveTempFiles): Promise<void> => {
      const tempPath = tempFilesRef.current[key];
      if (tempPath == null) {
        return;
      }
      assignTempFile(sessionId, key, null);
      await unlinkPaths([tempPath]);
    },
    [assignTempFile, unlinkPaths],
  );

  /**
   * @description 外から呼ぶ cancel API です。
   * 新しい sessionId を払い出して古い完了通知を全部 stale にし、UI は idle へ戻します。
   */
  const cancel = useCallback((): void => {
    const previousTempFiles = tempFilesRef.current;
    const nextSessionId = sessionIdRef.current + 1;
    sessionIdRef.current = nextSessionId;
    tempFilesRef.current = createEmptyTempFiles();
    unsubscribeProgress();
    void abortBackgroundStages();
    void unlinkPaths(Object.values(previousTempFiles));
    setState({
      stage: "idle",
      qualityLabel: null,
      stageProgress: 0,
      sessionId: nextSessionId,
      isTranscoding: false,
      activeSourcePath: null,
      tempFiles: createEmptyTempFiles(),
    });
  }, [abortBackgroundStages, unlinkPaths, unsubscribeProgress]);

  /**
   * @description アンマウント時の片付けです。
   */
  useEffect(() => {
    unmountedRef.current = false;
    return () => {
      unmountedRef.current = true;
      unsubscribeProgress();
      void abortBackgroundStages();
      void unlinkPaths(Object.values(tempFilesRef.current));
    };
  }, [abortBackgroundStages, unlinkPaths, unsubscribeProgress]);

  /**
   * @description Progressive loading を開始し、最初に見せられる結果を返します。
   */
  const startProgressiveLoad = useCallback(
    async (
      absPath: string,
      fileName: string,
      probe: Awaited<ReturnType<FilmLabBatchBridge["videoExportProbe"]>>,
      onTextureSwap: (payload: ProgressiveTextureSwapPayload) => Promise<void>,
    ): Promise<ProgressiveInitialPreviewResult | null> => {
      const sessionId = await beginSession(absPath);
      const resolvedFileName =
        fileName.trim().length > 0 ? fileName : basenameFromAbsolutePath(absPath);
      const proxyDimensions = computeProxyDimensions(probe.width, probe.height);
      const { outW, outH } = computeMezzanineDimensions(probe.width, probe.height);

      /**
       * @description main が作った tmp から custom protocol URL を作り、stale ならすぐ掃除します。
       */
      const createUrlForCurrentSession = async (tempPath: string): Promise<string | null> => {
        const url = await window.filmLabBatch.pathToFileURL(tempPath);
        if (!isCurrentSession(sessionId)) {
          await unlinkPaths([tempPath]);
          return null;
        }
        return url;
      };

      /**
       * @description Stage 1 の JPEG サムネイルを作ります。
       */
      const extractThumbnail = async (): Promise<ProgressiveInitialPreviewResult | null> => {
        try {
          console.log("[progressive-hook] extractThumbnail: calling IPC, sessionId=", sessionId, "current=", sessionIdRef.current);
          const result = await window.filmLabBatch.videoPreviewExtractThumbnail({
            filePath: absPath,
            sourceWidth: probe.width,
            sourceHeight: probe.height,
          });
          console.log("[progressive-hook] extractThumbnail: IPC returned, sessionId=", sessionId, "current=", sessionIdRef.current, "match=", isCurrentSession(sessionId));
          if (!isCurrentSession(sessionId)) {
            console.warn("[progressive-hook] extractThumbnail: session stale after IPC!", { expected: sessionId, actual: sessionIdRef.current });
            await unlinkPaths([result.thumbnailPath]);
            return null;
          }
          assignTempFile(sessionId, "thumbnailPath", result.thumbnailPath);
          const url = await createUrlForCurrentSession(result.thumbnailPath);
          console.log("[progressive-hook] extractThumbnail: url=", url ? url.slice(0, 60) : null, "sessionMatch=", isCurrentSession(sessionId));
          if (url == null) {
            return null;
          }
          updateSessionState(sessionId, {
            stage: "thumbnail",
            qualityLabel: "thumbnail",
            stageProgress: 100,
            isTranscoding: true,
            activeSourcePath: absPath,
          });
          return {
            url,
            fileName: resolvedFileName,
            mediaKind: "image",
            stage: "thumbnail",
            width: result.width,
            height: result.height,
          };
        } catch (err) {
          console.warn("useProgressiveLoad: thumbnail extraction failed", {
            functionName: "extractThumbnail",
            absPath,
            err,
          });
          return null;
        }
      };

      /**
       * @description Stage 2 の proxy を作ります。
       * `visibleQuality` は画面に見えている品質を表し、バッジの維持に使います。
       */
      const generateProxy = async (
        visibleQuality: ProgressiveQualityLabel,
      ): Promise<{ path: string; url: string } | null> => {
        updateSessionState(sessionId, {
          stage: "proxy",
          qualityLabel: visibleQuality,
          stageProgress: 0,
          isTranscoding: true,
          activeSourcePath: absPath,
        });
        unsubscribeProgress();
        proxyUnsubscribeRef.current = window.filmLabBatch.subscribeProxyProgress(
          (payload) => {
            updateSessionState(sessionId, {
              stage: "proxy",
              qualityLabel: visibleQuality,
              stageProgress: payload.current,
              isTranscoding: true,
              activeSourcePath: absPath,
            });
          },
        );
        try {
          const result = await window.filmLabBatch.videoPreviewGenerateProxy({
            filePath: absPath,
            durationSec: probe.durationSec,
          });
          proxyUnsubscribeRef.current?.();
          proxyUnsubscribeRef.current = null;
          if (!isCurrentSession(sessionId)) {
            await unlinkPaths([result.proxyPath]);
            return null;
          }
          assignTempFile(sessionId, "proxyPath", result.proxyPath);
          const url = await createUrlForCurrentSession(result.proxyPath);
          if (url == null) {
            return null;
          }
          return { path: result.proxyPath, url };
        } catch (err) {
          proxyUnsubscribeRef.current?.();
          proxyUnsubscribeRef.current = null;
          console.warn("useProgressiveLoad: proxy generation failed", {
            functionName: "generateProxy",
            absPath,
            err,
          });
          return null;
        }
      };

      /**
       * @description Stage 3 の mezzanine を作ります。
       */
      const generateMezzanine = async (
        visibleQuality: ProgressiveQualityLabel,
      ): Promise<{ path: string; url: string } | null> => {
        updateSessionState(sessionId, {
          stage: "mezzanine",
          qualityLabel: visibleQuality,
          stageProgress: 0,
          isTranscoding: true,
          activeSourcePath: absPath,
        });
        unsubscribeProgress();
        mezzanineUnsubscribeRef.current =
          window.filmLabBatch.subscribeMezzanineProgress((payload) => {
            updateSessionState(sessionId, {
              stage: "mezzanine",
              qualityLabel: visibleQuality,
              stageProgress: payload.current,
              isTranscoding: true,
              activeSourcePath: absPath,
            });
          });
        try {
          const result = await window.filmLabBatch.videoExportTranscodeMezzanine({
            filePath: absPath,
            durationSec: probe.durationSec,
            outW,
            outH,
          });
          mezzanineUnsubscribeRef.current?.();
          mezzanineUnsubscribeRef.current = null;
          if (!isCurrentSession(sessionId)) {
            await unlinkPaths([result.mezzaninePath]);
            return null;
          }
          assignTempFile(sessionId, "mezzaninePath", result.mezzaninePath);
          const url = await createUrlForCurrentSession(result.mezzaninePath);
          if (url == null) {
            return null;
          }
          return { path: result.mezzaninePath, url };
        } catch (err) {
          mezzanineUnsubscribeRef.current?.();
          mezzanineUnsubscribeRef.current = null;
          console.warn("useProgressiveLoad: mezzanine generation failed", {
            functionName: "generateMezzanine",
            absPath,
            err,
          });
          return null;
        }
      };

      /**
       * @description 表示中の成功ステージから mezzanine までを背景で進めます。
       */
      const continueFromVisibleStage = (
        initialVisibleKey: keyof ProgressiveTempFiles,
        initialVisibleQuality: Exclude<ProgressiveQualityLabel, null | "hd">,
      ): void => {
        void (async () => {
          let visibleKey: keyof ProgressiveTempFiles = initialVisibleKey;
          let visibleQuality: Exclude<ProgressiveQualityLabel, null | "hd"> =
            initialVisibleQuality;

          if (visibleKey === "thumbnailPath") {
            console.log("[progressive-hook] generating proxy...");
            const proxyAsset = await generateProxy("thumbnail");
            console.log("[progressive-hook] proxy result", proxyAsset ? "ok" : "null");
            if (proxyAsset != null && isCurrentSession(sessionId)) {
              try {
                await onTextureSwap({
                  url: proxyAsset.url,
                  fileName: resolvedFileName,
                  stage: "proxy",
                });
                if (!isCurrentSession(sessionId)) {
                  return;
                }
                visibleKey = "proxyPath";
                visibleQuality = "proxy";
                updateSessionState(sessionId, {
                  stage: "proxy",
                  qualityLabel: "proxy",
                  stageProgress: 100,
                  isTranscoding: true,
                  activeSourcePath: absPath,
                });
                await unlinkStageTempFile(sessionId, "thumbnailPath");
              } catch (err) {
                console.warn("useProgressiveLoad: proxy texture swap failed", {
                  functionName: "continueFromVisibleStage",
                  absPath,
                  err,
                });
              }
            }
          }

          console.log("[progressive-hook] generating mezzanine...");
          const mezzanineAsset = await generateMezzanine(visibleQuality);
          console.log("[progressive-hook] mezzanine result", mezzanineAsset ? "ok" : "null");
          if (mezzanineAsset != null && isCurrentSession(sessionId)) {
            try {
              await onTextureSwap({
                url: mezzanineAsset.url,
                fileName: resolvedFileName,
                stage: "mezzanine",
              });
              if (!isCurrentSession(sessionId)) {
                return;
              }
              updateSessionState(sessionId, {
                stage: "ready",
                qualityLabel: "hd",
                stageProgress: 100,
                isTranscoding: false,
                activeSourcePath: absPath,
              });
              if (visibleKey === "proxyPath") {
                await unlinkStageTempFile(sessionId, "proxyPath");
              } else if (visibleKey === "thumbnailPath") {
                await unlinkStageTempFile(sessionId, "thumbnailPath");
              }
              return;
            } catch (err) {
              console.warn("useProgressiveLoad: mezzanine texture swap failed", {
                functionName: "continueFromVisibleStage",
                absPath,
                err,
              });
            }
          }

          if (!isCurrentSession(sessionId)) {
            return;
          }
          updateSessionState(sessionId, {
            stage: visibleKey === "proxyPath" ? "proxy" : "thumbnail",
            qualityLabel: visibleQuality,
            stageProgress: 100,
            isTranscoding: false,
            activeSourcePath: absPath,
          });
        })();
      };

      const thumbnailInitial = await extractThumbnail();
      console.log("[progressive-hook] thumbnailInitial", thumbnailInitial ? { stage: thumbnailInitial.stage, mediaKind: thumbnailInitial.mediaKind } : null);
      if (thumbnailInitial != null) {
        continueFromVisibleStage("thumbnailPath", "thumbnail");
        return thumbnailInitial;
      }

      const proxyInitial = await generateProxy(null);
      if (proxyInitial != null && isCurrentSession(sessionId)) {
        updateSessionState(sessionId, {
          stage: "proxy",
          qualityLabel: "proxy",
          stageProgress: 100,
          isTranscoding: true,
          activeSourcePath: absPath,
        });
        continueFromVisibleStage("proxyPath", "proxy");
        return {
          url: proxyInitial.url,
          fileName: resolvedFileName,
          mediaKind: "video",
          stage: "proxy",
          width: proxyDimensions.width,
          height: proxyDimensions.height,
        };
      }

      const mezzanineInitial = await generateMezzanine(null);
      if (mezzanineInitial != null && isCurrentSession(sessionId)) {
        updateSessionState(sessionId, {
          stage: "ready",
          qualityLabel: "hd",
          stageProgress: 100,
          isTranscoding: false,
          activeSourcePath: absPath,
        });
        return {
          url: mezzanineInitial.url,
          fileName: resolvedFileName,
          mediaKind: "video",
          stage: "mezzanine",
          width: outW,
          height: outH,
        };
      }

      if (isCurrentSession(sessionId)) {
        updateSessionState(sessionId, {
          stage: "idle",
          qualityLabel: null,
          stageProgress: 0,
          isTranscoding: false,
          activeSourcePath: absPath,
        });
      }
      return null;
    },
    [assignTempFile, beginSession, isCurrentSession, unlinkPaths, unlinkStageTempFile, unsubscribeProgress, updateSessionState],
  );

  return {
    qualityLabel: state.qualityLabel,
    stageProgress: state.stageProgress,
    isTranscoding: state.isTranscoding,
    stage: state.stage,
    activeSourcePath: state.activeSourcePath,
    mezzaninePath: state.tempFiles.mezzaninePath,
    startProgressiveLoad,
    cancel,
  };
}
