export type VideoExportCloseInfo = {
  code: number | null;
  signal: NodeJS.Signals | null;
};

type VideoExportChildLike = {
  stdin: NodeJS.WritableStream | null;
  once(
    event: "close",
    listener: (code: number | null, signal: NodeJS.Signals | null) => void,
  ): unknown;
};

export type VideoExportPipeController = {
  markFinishing(): void;
  getCloseInfo(): VideoExportCloseInfo | null;
  getFailure(): Error | null;
  waitForPendingDrain(): Promise<void>;
  waitForClose(): Promise<VideoExportCloseInfo>;
  write(chunk: Buffer): Promise<void>;
};

function normalizeError(error: unknown): Error {
  return error instanceof Error ? error : new Error(String(error));
}

function formatCloseInfo(info: VideoExportCloseInfo): string {
  const parts = [`code=${info.code ?? "null"}`];
  if (info.signal) {
    parts.push(`signal=${info.signal}`);
  }
  return parts.join(" ");
}

function buildCloseError(
  info: VideoExportCloseInfo,
  finishRequested: boolean,
): Error {
  if (finishRequested) {
    return new Error(`ffmpeg exited ${formatCloseInfo(info)}`);
  }
  return new Error(`ffmpeg exited before finish (${formatCloseInfo(info)})`);
}

export function describeVideoExportPipeUnavailable(opts: {
  stdin: Pick<NodeJS.WritableStream, "writable"> | null;
  controller: Pick<VideoExportPipeController, "getCloseInfo" | "getFailure">;
  childExitCode?: number | null;
  childSignal?: NodeJS.Signals | null;
}): string {
  const failure = opts.controller.getFailure();
  if (failure) {
    return failure.message;
  }

  const closeInfo = opts.controller.getCloseInfo();
  if (closeInfo) {
    return buildCloseError(closeInfo, false).message;
  }

  if (opts.childExitCode != null || opts.childSignal != null) {
    return buildCloseError(
      {
        code: opts.childExitCode ?? null,
        signal: opts.childSignal ?? null,
      },
      false,
    ).message;
  }

  if (opts.stdin == null) {
    return "ffmpeg stdin が初期化されていません";
  }
  if (!opts.stdin.writable) {
    return "ffmpeg stdin はすでに閉じています";
  }
  return "ffmpeg stdin が利用できません";
}

export function createVideoExportPipeController(
  child: VideoExportChildLike,
): VideoExportPipeController {
  const stdin = child.stdin;
  if (stdin == null) {
    throw new Error("video-export stdin が初期化されていません");
  }

  let pendingDrain: Promise<void> | null = null;
  let settlePendingDrain: (() => void) | null = null;
  let failure: Error | null = null;
  let closeInfo: VideoExportCloseInfo | null = null;
  let finishRequested = false;

  const fail = (error: unknown): Error => {
    const normalized = normalizeError(error);
    if (failure == null) {
      failure = normalized;
    }
    if (settlePendingDrain) {
      const settle = settlePendingDrain;
      settlePendingDrain = null;
      pendingDrain = null;
      settle();
    }
    return normalized;
  };

  stdin.on("error", (error) => {
    fail(error);
  });

  const closePromise = new Promise<VideoExportCloseInfo>((resolve) => {
    child.once("close", (code, signal) => {
      closeInfo = {
        code,
        signal: signal ?? null,
      };
      if (code !== 0 || signal != null || !finishRequested) {
        fail(buildCloseError(closeInfo, finishRequested));
      }
      resolve(closeInfo);
    });
  });

  const startDrainWait = (): void => {
    const drainPromise = new Promise<void>((resolve, reject) => {
      let settled = false;
      const cleanup = () => {
        if (settled) {
          return;
        }
        settled = true;
        stdin.removeListener("drain", onDrain);
        if (pendingDrain === drainPromise) {
          pendingDrain = null;
        }
        if (settlePendingDrain === settleDrain) {
          settlePendingDrain = null;
        }
      };
      const onDrain = () => {
        cleanup();
        resolve();
      };
      const settleDrain = () => {
        cleanup();
        resolve();
      };
      settlePendingDrain = settleDrain;
      stdin.once("drain", onDrain);
    });
    pendingDrain = drainPromise;
    if (failure && settlePendingDrain) {
      settlePendingDrain();
    }
  };

  return {
    markFinishing(): void {
      finishRequested = true;
    },

    getCloseInfo(): VideoExportCloseInfo | null {
      return closeInfo;
    },

    getFailure(): Error | null {
      if (failure) {
        return failure;
      }
      if (closeInfo) {
        if (finishRequested && closeInfo.code === 0 && closeInfo.signal == null) {
          return null;
        }
        return buildCloseError(closeInfo, finishRequested);
      }
      return null;
    },

    async waitForPendingDrain(): Promise<void> {
      if (pendingDrain) {
        await pendingDrain;
      }
      if (failure) {
        throw failure;
      }
    },

    async waitForClose(): Promise<VideoExportCloseInfo> {
      if (closeInfo) {
        return closeInfo;
      }
      return closePromise;
    },

    async write(chunk: Buffer): Promise<void> {
      if (failure) {
        throw failure;
      }
      if (pendingDrain) {
        await pendingDrain;
      }
      if (failure) {
        throw failure;
      }
      if (closeInfo) {
        throw buildCloseError(closeInfo, finishRequested);
      }
      try {
        const ok = stdin.write(chunk);
        if (!ok) {
          startDrainWait();
        }
      } catch (error) {
        throw fail(error);
      }
      if (failure) {
        throw failure;
      }
      if (closeInfo) {
        throw buildCloseError(closeInfo, finishRequested);
      }
    },
  };
}
