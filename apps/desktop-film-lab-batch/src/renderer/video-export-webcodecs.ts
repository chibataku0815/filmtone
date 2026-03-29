/**
 * @fileoverview WebGL 正確エクスポート用の WebCodecs（MP4/H.264）デコード経路
 *
 * @overview mp4box で NAL を取り出し、VideoDecoder で逐次デコードする。テクスチャは
 *   Session 3 で破綻した「生 gl.texImage2D」ではなく、Canvas 2D の drawImage(VideoFrame)
 *   経由で THREE.CanvasTexture と SRGBColorSpace を揃える（計画の経路 A）。
 * @limitations 非断片 MP4/MOV（コンテナとして mp4box が扱えるもの）かつ avc1（H.264）のみ。
 *   断片 MP4・HEVC・巨大ファイルはフォールバックする。メモリ上にファイル全体を載せる。
 */

import * as THREE from "three";
import {
  createFile,
  DataStream,
  MP4BoxBuffer,
  type ISOFile,
  type Sample,
  type Track,
} from "mp4box";

/** @description 日本語ログ（ファイル全体を載せない最大サイズ。超えると WebCodecs 経路を試さない） */
export const WEBCODECS_ACC_EXPORT_MAX_FILE_BYTES = 512 * 1024 * 1024;

/** @description デコードキューが詰まりすぎないよう出力を待つしきい値（大きすぎると出力ゼロ時に長く無応答になる） */
const MAX_PENDING_DECODE_CHUNKS = 8;

/** @description 初回出力が来ないときに「固まった」と切り分けられるよう待つ上限（ms） */
const DECODE_OUTPUT_WAIT_MS = 30_000;

/**
 * @description ファイルパスが mp4box 前提の拡張子かどうか（大文字小文字無視）
 */
export function isMp4LikeContainerForWebCodecs(absPath: string): boolean {
  const lower = absPath.replace(/\\/g, "/").toLowerCase();
  return (
    lower.endsWith(".mp4") || lower.endsWith(".m4v") || lower.endsWith(".mov")
  );
}

/**
 * @description WebCodecs 経路を試みてよい条件（必ず成功はしない — あとは mp4 / デコーダが決める）
 */
export function shouldAttemptWebCodecsAccurateExport(opts: {
  videoCodec: string;
  fileSizeBytes: number;
  absPath: string;
}): boolean {
  if (typeof VideoDecoder !== "function") return false;
  if (!isMp4LikeContainerForWebCodecs(opts.absPath)) return false;
  if (opts.fileSizeBytes > WEBCODECS_ACC_EXPORT_MAX_FILE_BYTES) return false;
  const c = opts.videoCodec.toLowerCase();
  return c === "h264" || c === "avc";
}

/**
 * @description mp4box がパースした avcC 相当フィールドから **AVCDecoderConfigurationRecord 本体だけ**を書く。
 * Chromium の `VideoDecoder.configure({ description })` は ISO 14496-15 のこのペイロードを期待し、
 * mp4box の `avcC.write()` が付ける **MP4 box ヘッダー（size + fourcc）付きバッファを渡すと
 * 「Failed to parse avcC」になる**ため、`writeHeader` 相当は行わない。
 */
type AvcCBoxLike = {
  configurationVersion?: number;
  AVCProfileIndication?: number;
  profile_compatibility?: number;
  AVCLevelIndication?: number;
  /** @description パース後は下位 2bit のみ有効なことがある */
  lengthSizeMinusOne?: number;
  SPS?: Array<{ length: number; data: Uint8Array }>;
  PPS?: Array<{ length: number; data: Uint8Array }>;
  ext?: Uint8Array;
};

function avcCDescriptionBytesFromSampleEntry(description: unknown): Uint8Array | null {
  if (description === null || typeof description !== "object") return null;
  const entry = description as { avcC?: AvcCBoxLike };
  const avcC = entry.avcC;
  if (!avcC) return null;

  const stream = new DataStream();
  stream.endianness = DataStream.BIG_ENDIAN;

  const cfgVer = avcC.configurationVersion ?? 1;
  const profile = avcC.AVCProfileIndication ?? 0;
  const compat = avcC.profile_compatibility ?? 0;
  const level = avcC.AVCLevelIndication ?? 0;
  const lsOne = avcC.lengthSizeMinusOne ?? 3;
  const spsList = avcC.SPS ?? [];
  const ppsList = avcC.PPS ?? [];

  if (spsList.length === 0) {
    return null;
  }

  stream.writeUint8(cfgVer);
  stream.writeUint8(profile);
  stream.writeUint8(compat);
  stream.writeUint8(level);
  stream.writeUint8(lsOne + (63 << 2));
  stream.writeUint8(spsList.length + (7 << 5));
  for (let i = 0; i < spsList.length; i++) {
    const nal = spsList[i]!;
    stream.writeUint16(nal.length);
    stream.writeUint8Array(nal.data);
  }
  stream.writeUint8(ppsList.length);
  for (let i = 0; i < ppsList.length; i++) {
    const nal = ppsList[i]!;
    stream.writeUint16(nal.length);
    stream.writeUint8Array(nal.data);
  }
  if (avcC.ext && avcC.ext.byteLength > 0) {
    stream.writeUint8Array(avcC.ext);
  }

  return new Uint8Array(stream.buffer, 0, stream.byteLength);
}

type ProbeShape = {
  width: number;
  height: number;
  durationSec: number;
};

/**
 * @description stsd / tkhd の解像度を ffprobe より優先（VideoDecoder.configure と canvas サイズを一致させる）
 */
function codedDimensionsFromMp4VideoTrack(
  vtrack: Track,
  probe: ProbeShape,
): { codedWidth: number; codedHeight: number } {
  const vw = vtrack.video?.width;
  const vh = vtrack.video?.height;
  const tw = vtrack.track_width;
  const th = vtrack.track_height;
  const codedWidth =
    typeof vw === "number" && vw > 0
      ? vw
      : typeof tw === "number" && tw > 0
        ? tw
        : probe.width;
  const codedHeight =
    typeof vh === "number" && vh > 0
      ? vh
      : typeof th === "number" && th > 0
        ? th
        : probe.height;
  return { codedWidth, codedHeight };
}

/**
 * @description MP4 を読み込み、WebGL エクスポート用に VideoFrame を時系列で canvas に載せるセッション
 */
export class WebCodecsMp4ExportSession {
  readonly canvas: HTMLCanvasElement;
  readonly texture: THREE.CanvasTexture;
  private readonly probe: ProbeShape;
  private readonly onTrace: (line: string) => void;
  private readonly mp4: ISOFile;
  private readonly videoTrack: Track;
  private readonly videoTrackId: number;
  private readonly decoder: VideoDecoder;
  private inputQueue: Sample[] = [];
  private readonly outputQueue: VideoFrame[] = [];
  private extractionDone = false;
  private samplesReceived = 0;
  private decoderConfigured = false;
  private readonly nbSamplesTotal: number;
  private holder: VideoFrame | null = null;
  private pendingDecodes = 0;
  /** @description diagnoseStall のスナップショット用（decode 成功回数） */
  private decodeSubmitCount = 0;
  /** @description diagnoseStall のスナップショット用（output コールバック回数） */
  private decodeOutputCount = 0;
  private flushPromise: Promise<void> | null = null;
  /** @description decoder.flush() まで完了したら true（末尾ホールド判定用） */
  private flushCompleted = false;
  private outputWaiters: Array<() => void> = [];
  private decodeFatal: Error | null = null;
  /** @description pumpDecoder の再入防止（逐次デコードキュー） */
  private pumpChain: Promise<void> = Promise.resolve();

  private constructor(
    probe: ProbeShape,
    onTrace: (line: string) => void,
    mp4: ISOFile,
    videoTrack: Track,
    videoTrackId: number,
    decoder: VideoDecoder,
    canvas: HTMLCanvasElement,
    texture: THREE.CanvasTexture,
  ) {
    this.probe = probe;
    this.onTrace = onTrace;
    this.mp4 = mp4;
    this.videoTrack = videoTrack;
    this.videoTrackId = videoTrackId;
    this.decoder = decoder;
    this.canvas = canvas;
    this.texture = texture;
    this.nbSamplesTotal =
      typeof videoTrack.nb_samples === "number" && videoTrack.nb_samples > 0
        ? videoTrack.nb_samples
        : 0;
  }

  /**
   * @description ArrayBuffer（ファイル丸ごと）からセッションを生成。失敗時は例外（呼び出し側でフォールバック）
   */
  static async create(
    arrayBuffer: ArrayBuffer,
    probe: ProbeShape,
    onTrace: (line: string) => void,
  ): Promise<WebCodecsMp4ExportSession> {
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d", { colorSpace: "srgb" });
    if (!ctx) {
      throw new Error("WebCodecsMp4ExportSession: 2D context を取得できません");
    }

    const sessionRef: { current: WebCodecsMp4ExportSession | null } = {
      current: null,
    };
    let resolvedSession: WebCodecsMp4ExportSession | null = null;

    const mp4 = createFile(true);
    const buf = MP4BoxBuffer.fromArrayBuffer(arrayBuffer, 0);

    await new Promise<void>((resolve, reject) => {
      mp4.onError = (_m, msg) => {
        reject(new Error(`mp4box onError: ${msg}`));
      };
      mp4.onReady = (info) => {
        void (async () => {
          try {
            if (info.videoTracks.length === 0) {
              reject(new Error("WebCodecsMp4ExportSession: 動画トラックがありません"));
              return;
            }
            if (info.isFragmented) {
              reject(
                new Error(
                  "WebCodecsMp4ExportSession: 断片 MP4 は未対応（フォールバックしてください）",
                ),
              );
              return;
            }
            const vtrack = info.videoTracks[0]!;
            const codec = vtrack.codec ?? "";
            if (!codec.startsWith("avc1") && !codec.startsWith("avc3")) {
              reject(
                new Error(
                  `WebCodecsMp4ExportSession: コーデック ${codec} は H.264(avc) 以外です`,
                ),
              );
              return;
            }
            const { codedWidth, codedHeight } = codedDimensionsFromMp4VideoTrack(
              vtrack,
              probe,
            );
            canvas.width = codedWidth;
            canvas.height = codedHeight;
            const sup = await VideoDecoder.isConfigSupported({
              codec,
              codedWidth,
              codedHeight,
            });
            if (!sup.supported) {
              reject(
                new Error(
                  `WebCodecsMp4ExportSession: VideoDecoder.isConfigSupported unsupported — ${codec}`,
                ),
              );
              return;
            }

            const decoder = new VideoDecoder({
              output: (frame) => {
                const s = sessionRef.current;
                if (s) {
                  s.pendingDecodes = Math.max(0, s.pendingDecodes - 1);
                  s.decodeOutputCount++;
                  if (s.decodeOutputCount <= 3) {
                    s.onTrace(
                      `[動画][WebCodecs][dbg] output #${s.decodeOutputCount} ts=${frame.timestamp}µs dur=${frame.duration ?? "n/a"}`,
                    );
                  }
                  s.outputQueue.push(frame);
                  s.drainOutputWaiters();
                } else {
                  frame.close();
                }
              },
              error: (err) => {
                const s = sessionRef.current;
                const e =
                  err instanceof Error
                    ? err
                    : new Error(String(err ?? "VideoDecoder"));
                if (s) {
                  s.decodeFatal = e;
                  s.drainOutputWaiters();
                }
              },
            });

            const texture = new THREE.CanvasTexture(canvas);
            texture.colorSpace = THREE.SRGBColorSpace;
            texture.minFilter = THREE.LinearFilter;
            texture.magFilter = THREE.LinearFilter;

            const session = new WebCodecsMp4ExportSession(
              probe,
              onTrace,
              mp4,
              vtrack,
              vtrack.id,
              decoder,
              canvas,
              texture,
            );
            sessionRef.current = session;
            resolvedSession = session;

            mp4.onSamples = (_id, _user, samples) => {
              session.onSamplesBatch(samples);
            };
            mp4.setExtractionOptions(vtrack.id, {}, { nbSamples: 128 });
            mp4.start();
            onTrace(
              `[動画][WebCodecs] 初期化 OK track=${vtrack.id} codec=${codec} samples=${session.nbSamplesTotal}`,
            );
            resolve();
          } catch (e) {
            reject(e instanceof Error ? e : new Error(String(e)));
          }
        })();
      };
      mp4.appendBuffer(buf);
      mp4.flush();
    });

    if (!resolvedSession) {
      throw new Error("WebCodecsMp4ExportSession: セッション生成に失敗しました");
    }
    return resolvedSession;
  }

  private drainOutputWaiters(): void {
    const w = this.outputWaiters.splice(0, this.outputWaiters.length);
    for (const fn of w) fn();
  }

  /**
   * @description VideoDecoder の output / error が来るまで待つ。来なければタイムアウトで状態を詳細に投げる（無限待ちデバッグ用）。
   * @param timeoutMs この時間超えたら例外
   */
  private async waitForOutputOrError(timeoutMs: number = DECODE_OUTPUT_WAIT_MS): Promise<void> {
    if (this.outputQueue.length > 0 || this.decodeFatal) return;
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      await Promise.race([
        new Promise<void>((resolve) => {
          this.outputWaiters.push(resolve);
        }),
        new Promise<void>((_, reject) => {
          timer = setTimeout(() => {
            reject(new Error(this.diagnoseStall(`waitForOutputOrError>${timeoutMs}ms`)));
          }, timeoutMs);
        }),
      ]);
    } finally {
      if (timer !== undefined) clearTimeout(timer);
    }
  }

  /**
   * @description 進まないときにログ1行で済まない情報を例外メッセージにまとめる
   * @param where 呼び出し箇所のラベル
   */
  private diagnoseStall(where: string): string {
    let decodeQueueSize = "n/a";
    try {
      const d = this.decoder as VideoDecoder & { decodeQueueSize?: number };
      if (typeof d.decodeQueueSize === "number") decodeQueueSize = String(d.decodeQueueSize);
    } catch {
      /* ignore */
    }
    this.onTrace(`[動画][WebCodecs][stall] ${where} — ${this.diagnoseStallSummary(decodeQueueSize)}`);
    return `WebCodecsMp4ExportSession.${where}: デコーダが応答しません — ${this.diagnoseStallSummary(decodeQueueSize)}`;
  }

  /** @description diagnoseStall 本文（括弧で連結しやすい短い英語キー） */
  private diagnoseStallSummary(decodeQueueSize: string): string {
    return (
      `decoderState=${this.decoder.state} pendingDecodes=${this.pendingDecodes} ` +
      `inQ=${this.inputQueue.length} outQ=${this.outputQueue.length} decodeQueueSize=${decodeQueueSize} ` +
      `submitted=${this.decodeSubmitCount} outputCb=${this.decodeOutputCount} ` +
      `configured=${this.decoderConfigured} extractionDone=${this.extractionDone} fatal=${this.decodeFatal ? this.decodeFatal.message : "none"}`
    );
  }

  /**
   * @description 最初の onSamples より先に present が走ると decode も起きず wait が永久になる。イベントループに譲りつつ configure 完了を待つ。
   */
  private async waitUntilDecoderConfiguredOrThrow(): Promise<void> {
    const deadlineMs = performance.now() + 60_000;
    while (!this.decoderConfigured && !this.decodeFatal) {
      if (performance.now() > deadlineMs) {
        throw new Error(
          "WebCodecsMp4ExportSession: 60s 以内に mp4 の最初のサンプルが来ず VideoDecoder.configure できませんでした（抽出停滞）",
        );
      }
      await new Promise<void>((r) => {
        setTimeout(r, 8);
      });
    }
    if (this.decodeFatal) throw this.decodeFatal;
  }

  private onSamplesBatch(samples: Sample[]): void {
    if (samples.length === 0) return;
    if (!this.decoderConfigured) {
      const descBytes = avcCDescriptionBytesFromSampleEntry(
        samples[0]!.description,
      );
      const { codedWidth, codedHeight } = codedDimensionsFromMp4VideoTrack(
        this.videoTrack,
        this.probe,
      );
      try {
        this.decoder.configure({
          codec: this.videoTrack.codec,
          codedWidth,
          codedHeight,
          description:
            descBytes && descBytes.byteLength > 0 ? descBytes.slice() : undefined,
        });
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        this.decodeFatal = new Error(`VideoDecoder.configure 失敗: ${msg}`);
        this.drainOutputWaiters();
        return;
      }
      this.decoderConfigured = true;
      this.onTrace(
        `[動画][WebCodecs] VideoDecoder.configure coded=${codedWidth}×${codedHeight}（stsd 優先）`,
      );
    }
    for (const s of samples) {
      this.inputQueue.push(s);
    }
    this.samplesReceived += samples.length;
    const extractionBatchSize = 128;
    if (
      (this.nbSamplesTotal > 0 &&
        this.samplesReceived >= this.nbSamplesTotal) ||
      samples.length < extractionBatchSize
    ) {
      this.extractionDone = true;
    }
    void this.schedulePump();
  }

  /**
   * @description 非同期デコードを 1 本のチェーンに直列化する（再入による二重 decode を防ぐ）
   * @returns 今回キューした pumpDecoderImpl 1 回ぶんの完了 Promise（待つと入力キューが一段進む）
   */
  private schedulePump(): Promise<void> {
    const p = this.pumpChain
      .then(() => this.pumpDecoderImpl())
      .catch((e) => {
        const msg = e instanceof Error ? e.message : String(e);
        if (!this.decodeFatal) {
          this.decodeFatal = new Error(`WebCodecsMp4ExportSession.pump 失敗: ${msg}`);
        }
        this.drainOutputWaiters();
      });
    this.pumpChain = p;
    return p;
  }

  private async pumpDecoderImpl(): Promise<void> {
    if (this.decodeFatal || !this.decoderConfigured) return;
    while (this.inputQueue.length > 0) {
      if (this.decodeFatal) return;
      while (this.pendingDecodes >= MAX_PENDING_DECODE_CHUNKS) {
        await this.waitForOutputOrError(DECODE_OUTPUT_WAIT_MS);
        if (this.decodeFatal) return;
      }
      const sample = this.inputQueue[0]!;
      const data = sample.data;
      if (!data || data.byteLength === 0) {
        this.inputQueue.shift();
        continue;
      }
      const stamp = Math.max(
        0,
        Math.round((sample.cts / sample.timescale) * 1_000_000),
      );
      const dur =
        Number.isFinite(sample.duration) && sample.duration > 0
          ? Math.max(
              1,
              Math.round((sample.duration / sample.timescale) * 1_000_000),
            )
          : undefined;
      try {
        const ab = data.buffer.slice(
          data.byteOffset,
          data.byteOffset + data.byteLength,
        );
        /**
         * H.264 では先頭が誤って delta だと最初から output が来ないことがある。
         * `is_sync` が未設定のサンプルは mp4box では通常埋まるが、成立しない場合は key 側に倒す。
         */
        const chunkType: EncodedVideoChunkType =
          sample.is_sync === false ? "delta" : "key";
        const chunkInit: EncodedVideoChunkInit = {
          type: chunkType,
          timestamp: stamp,
          data: ab,
        };
        if (dur !== undefined) chunkInit.duration = dur;
        if (this.decodeSubmitCount === 0) {
          const dts =
            "dts" in sample && typeof (sample as Sample & { dts?: number }).dts === "number"
              ? (sample as Sample & { dts: number }).dts
              : "n/a";
          this.onTrace(
            `[動画][WebCodecs][dbg] 先頭 EncodedVideoChunk type=${chunkType} is_sync=${String(sample.is_sync)} cts=${sample.cts} dts=${dts} timescale=${sample.timescale} stampµs=${stamp} bytes=${data.byteLength}`,
          );
        }
        const chunk = new EncodedVideoChunk(chunkInit);
        this.decoder.decode(chunk);
        this.pendingDecodes++;
        this.decodeSubmitCount++;
        this.inputQueue.shift();
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        this.decodeFatal = new Error(`VideoDecoder.decode 失敗: ${msg}`);
        this.drainOutputWaiters();
        return;
      }
    }
    if (this.extractionDone && this.inputQueue.length === 0 && !this.flushPromise) {
      this.flushPromise = this.decoder
        .flush()
        .then(() => {
          this.flushCompleted = true;
        })
        .catch((e) => {
          const msg = e instanceof Error ? e.message : String(e);
          this.decodeFatal = new Error(`VideoDecoder.flush 失敗: ${msg}`);
        })
        .finally(() => {
          this.drainOutputWaiters();
        });
    }
  }

  /**
   * @description メディア時刻（秒）に合わせて canvas を更新（単調増加の呼び出しを想定）
   * @returns advanceMs — シーク相当の待ち時間指标（プロファイル用）
   */
  async presentAtMediaTimeSec(timeSec: number): Promise<{ advanceMs: number }> {
    const t0 = performance.now();
    if (this.decodeFatal) {
      throw this.decodeFatal;
    }
    const t = Math.max(0, timeSec);
    const targetUs = Math.round(t * 1_000_000);
    await this.ensureDecoderFedForTarget(targetUs);
    this.advanceHolderToTargetPts(targetUs);
    if (this.decodeFatal) throw this.decodeFatal;
    this.drawHolderToCanvas();
    this.texture.needsUpdate = true;
    return { advanceMs: performance.now() - t0 };
  }

  private async ensureDecoderFedForTarget(targetUs: number): Promise<void> {
    await this.waitUntilDecoderConfiguredOrThrow();
    const maxIter = Math.max(4096, this.nbSamplesTotal * 2 + 64);
    for (let i = 0; i < maxIter; i++) {
      if (this.decodeFatal) throw this.decodeFatal;
      await this.schedulePump();
      this.advanceHolderToTargetPts(targetUs);
      if (this.selectionSatisfied(targetUs)) return;
      if (this.flushPromise) {
        await this.flushPromise;
      }
      if (this.decodeFatal) throw this.decodeFatal;
      if (this.outputQueue.length === 0) {
        await this.waitForOutputOrError(DECODE_OUTPUT_WAIT_MS);
      }
    }
    const summary = this.diagnoseStallSummary("n/a");
    this.onTrace(`[動画][WebCodecs][stall] ensureDecoderFedForTarget 打ち切り — ${summary}`);
    throw new Error(
      `WebCodecsMp4ExportSession: 時刻 ${targetUs}µs へ進めきれませんでした — ${summary}`,
    );
  }

  /**
   * @description advanceHolderToTargetPts 直後、`targetUs` に対して表示すべきフレームが揃ったか
   */
  private selectionSatisfied(targetUs: number): boolean {
    if (this.decodeFatal) return false;
    if (this.holder === null) {
      return false;
    }
    if (this.holder.timestamp > targetUs) {
      return true;
    }
    const nextPts = this.outputQueue[0]?.timestamp;
    if (nextPts !== undefined) {
      return this.holder.timestamp <= targetUs && nextPts > targetUs;
    }
    if (!this.flushCompleted) {
      return false;
    }
    return true;
  }

  private advanceHolderToTargetPts(targetUs: number): void {
    while (
      this.outputQueue.length > 0 &&
      this.outputQueue[0]!.timestamp <= targetUs
    ) {
      this.holder?.close();
      this.holder = this.outputQueue.shift() ?? null;
    }
    if (this.holder === null && this.outputQueue.length > 0) {
      this.holder = this.outputQueue.shift() ?? null;
    }
  }

  private drawHolderToCanvas(): void {
    const ctx = this.canvas.getContext("2d", { colorSpace: "srgb" });
    if (!ctx) {
      throw new Error("drawHolderToCanvas: 2D context がありません");
    }
    if (!this.holder) {
      throw new Error(
        "drawHolderToCanvas: VideoFrame がありません（デコード不足）",
      );
    }
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.drawImage(
      this.holder,
      0,
      0,
      this.canvas.width,
      this.canvas.height,
    );
  }

  /**
   * @description VideoFrame / デコーダを開放
   */
  dispose(): void {
    for (const f of this.outputQueue) f.close();
    this.outputQueue.length = 0;
    this.holder?.close();
    this.holder = null;
    try {
      this.decoder.close();
    } catch {
      /* ignore */
    }
    // テクスチャ本体の dispose は Viewport / pipeline の srcTexture と重複しないようここでは行わない
  }
}
