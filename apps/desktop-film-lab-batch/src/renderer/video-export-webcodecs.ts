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

/**
 * @description H.264（B フレーム）では表示順の関係で、ある程度 **decode を先に積んだあと**初めて output が連続する。
 *   この「飛び」より小さいとデコーダと `waitForOutput` が互いを待って止まる。
 */
const MAX_PENDING_DECODE_CHUNKS = 64;

/**
 * @description **1 回の pumpDecoderImpl** で `decode` するサンプル数の上限。
 *   無制限に回すと `outputQueue` に `VideoFrame` が積み上がり **暗転・OOM** の原因になる一方、
 *   小さすぎると `ensureDecoderFedForTarget` がポンプを繰り返し **`mediaSync` が嵩む**。
 *   値を大きくしすぎると **非同期 output が一斉に届き `outputQueue` が膨らむ**。`liveFrameCount` 足切りと yield で抑える。
 *   16 と 24 の **中間の 20**。
 */
const MAX_DECODE_SUBMITS_PER_PUMP = 20;

/**
 * @description `presentAtMediaTimeSec` の初回付近はまだ holder / outputQueue が空なので、
 *   B フレーム並べ替えぶんを見込んで少し広めに先読みする。
 */
const INITIAL_DECODE_LEAD_FRAMES = 30;

/**
 * @description 平常時の PTS 先読み幅（フレーム換算）。薄いと長尺で `mediaSync` が後半だけ悪化しやすい。
 *   滞留は `MAX_LIVE_VIDEO_FRAMES` が抑える。`mediaSync` 枯れ対策で **11**。
 */
const STEADY_DECODE_LEAD_FRAMES = 11;

/**
 * @description future バッファがこれ未満になったら、描画後に background prefetch を再開する。
 *   早めに再開すると枯れにくい（4→6）。
 */
const PREFETCH_RESUME_THRESHOLD_FRAMES = 6;

/**
 * @description まずは stall 回避を優先し、VideoDecoder には「出せる output を早く返してほしい」と伝える。
 *   速度比較は同一クリップで別途 A/B するが、現時点では `targetBudget stop` との相互作用を安全側で見る。
 */
const WEBCODECS_OPTIMIZE_FOR_LATENCY = true;

/**
 * @description JS が同時に保持する `VideoFrame` 数の上限（`holder` + `outputQueue`）。
 *   ここに達したら caller へ返し、`advanceHolderToTargetPts` で消費させる。
 */
const MAX_LIVE_VIDEO_FRAMES = 8;

/** @description 初回出力が来ないときに「固まった」と切り分けられるよう待つ上限（ms） */
const DECODE_OUTPUT_WAIT_MS = 30_000;

/**
 * @description フェーズ番号付きの詳細 trace は verbose 指定時だけ有効。
 *   quiet run では bucket / summary だけを残し、速度判定に trace overhead を混ぜない。
 */
const WEBCODECS_FINE_TRACE =
  import.meta.env.VITE_FILM_LAB_VERBOSE_VIDEO_EXPORT === "true";

/**
 * @description `FILM_LAB_DEBUG_VIDEO_EXPORT=1` で起動したときだけ有効（Vite define 経由）。
 *   将来バッファがどの帯で薄くなるかを、100 フレームごとの 1 行で追う。
 */
const WEBCODECS_BUCKET_PROFILE =
  import.meta.env.VITE_FILM_LAB_DEBUG_VIDEO_EXPORT === "true";

/** @description bucket ログを出す間隔（エクスポートの `present` 回数） */
const WEBCODECS_BUCKET_EVERY_PRESENT_FRAMES = 100;

/**
 * @description mp4box が 1 回の `onSamples` で渡す最大サンプル数。大きいほど **JS ↔ mp4box 往復が減る**。
 *   `onSamplesBatch` の「最終バッチ判定」と一致させること。
 */
const MP4_EXTRACTION_SAMPLES_PER_PULL = 256;

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
 * @description probe の尺とサンプル数から 1 フレーム時間の概算（µs）を作る。
 *   可変フレームレートでも「target の少し先まで decode する」ための rough hint に使う。
 */
export function estimateNominalFrameDurationUs(opts: {
  durationSec: number;
  nbSamples: number;
}): number {
  if (
    Number.isFinite(opts.durationSec) &&
    opts.durationSec > 0 &&
    Number.isFinite(opts.nbSamples) &&
    opts.nbSamples > 0
  ) {
    return Math.max(1, Math.round((opts.durationSec * 1_000_000) / opts.nbSamples));
  }
  return Math.round(1_000_000 / 30);
}

/**
 * @description 現在の target PTS に対して decode してよい future 側の上界（µs）。
 *   「holder が 1 枚あるだけ」では B フレーム並べ替え待ちを見誤るため、
 *   target をまたぐ表示候補が揃うまでは warmup 幅を維持する。
 */
export function computeDecodeUpperBoundUs(opts: {
  targetUs: number;
  frameDurationUs: number;
  hasSatisfiedSelection: boolean;
}): number {
  const leadFrames = opts.hasSatisfiedSelection
    ? STEADY_DECODE_LEAD_FRAMES
    : INITIAL_DECODE_LEAD_FRAMES;
  return opts.targetUs + Math.max(1, opts.frameDurationUs) * leadFrames;
}

/**
 * @description prefetch が `outputQueue + pendingDecodes` の合算で止まったとき、
 *   「usable output は薄いのに pending だけで予算を食っている」状態かを返す。
 *   いまは診断専用で、Phase 4 で prefetch 条件を見直すときの観測に使う。
 */
export function isPrefetchBudgetDominatedByPendingDecodes(opts: {
  bufferedFrameBudgetCount: number;
  outputQueueLength: number;
  pendingDecodes: number;
  steadyLeadFrames: number;
  resumeThresholdFrames: number;
}): boolean {
  if (opts.bufferedFrameBudgetCount < opts.steadyLeadFrames) return false;
  if (opts.outputQueueLength >= opts.resumeThresholdFrames) return false;
  return (
    opts.pendingDecodes >= opts.steadyLeadFrames &&
    opts.pendingDecodes > opts.outputQueueLength
  );
}

/**
 * @description `waitForOutputOrError()` をどこから呼んだか。summary / bucket で待ちの主因を分けて読む。
 */
type WaitOutputReason = "ensureFed" | "pendingHardCap";

/**
 * @description 1 回の pump がどの理由で caller へ戻ったか。後半でどの exit が増えるかを見る。
 */
type PumpStopReason =
  | "liveBudget"
  | "pumpBudget"
  | "targetBudget";

/**
 * @description holder / outputQueue だけで、target に必要な表示選択がもう決まったかを返す。
 *   holder が 1 枚あるだけでは「次の future frame がまだ無い」場合を見逃すため、
 *   `computeDecodeUpperBoundUs` の steady への切り替え条件はこれに合わせる。
 */
export function hasSatisfiedSelectionByBufferedFrames(opts: {
  targetUs: number;
  holderUs: number | null;
  nextOutputUs: number | null;
  flushCompleted: boolean;
}): boolean {
  if (opts.holderUs === null) {
    return false;
  }
  if (opts.holderUs > opts.targetUs) {
    return true;
  }
  if (opts.nextOutputUs !== null) {
    return opts.holderUs <= opts.targetUs && opts.nextOutputUs > opts.targetUs;
  }
  return opts.flushCompleted;
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
  private readonly canvasContext: CanvasRenderingContext2D;
  private readonly probe: ProbeShape;
  private readonly onTrace: (line: string) => void;
  private readonly mp4: ISOFile;
  private readonly videoTrack: Track;
  private readonly videoTrackId: number;
  /** @description description 以外は固定（hwaccel / optimizeForLatency を create 時に決める） */
  private readonly decoderConfigureBase: VideoDecoderConfig;
  private readonly decoder: VideoDecoder;
  private inputQueue: Sample[] = [];
  /**
   * @description 先頭から既にデコード済み／スキップ済みのサンプル数。`shift()` は O(n) なのでインデックスで進み、
   *   たまに `slice` で捨てる（長尺で 400 フレーム以降が急に遅くなるのを防ぐ）。
   */
  private inputQueueReadOffset = 0;
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
  /** @description fineTrace と schedulePump の相関用連番 */
  private traceSeq = 0;
  /** @description schedulePump 呼び出しの連番（どのポンプ完了待ちで止まったか追う） */
  private pumpScheduleId = 0;
  /** @description 直近の `presentAtMediaTimeSec` の target PTS（先読み上界と stall summary 用） */
  private requestedTargetUs: number | null = null;
  /** @description sample.duration が分かるたび更新する 1 フレーム時間の rough hint */
  private frameDurationUsHint = 0;
  /** @description JS が同時に保持した `VideoFrame` 数のピーク（H1 切り分け用） */
  private liveFramePeak = 0;
  /** @description `close()` 済みのフレーム数（close 漏れ監査用） */
  private closedFrameCount = 0;
  /** @description future 側を保つ background prefetch が走っているか */
  private prefetchInFlight = false;
  /** @description background prefetch が次に満たしたい target PTS */
  private queuedPrefetchTargetUs: number | null = null;

  /** @description デバッグ: `presentAtMediaTimeSec` が何回目か（書き出しフレーム番号と一致） */
  private presentExportOrdinal = 0;
  /** @description bucket 内で `ensureDecoderFedForTarget` が即 return した回数 */
  private bucketEnsureFedFastPathHits = 0;
  /** @description bucket 内の `schedulePump` 呼び出し回数 */
  private bucketSchedulePumpCalls = 0;
  /** @description bucket 内で `waitForOutputOrError` が実際に待った回数 */
  private bucketWaitOutputCalls = 0;
  /** @description bucket 内の wait 合計 ms */
  private bucketWaitOutputTotalMs = 0;
  /** @description bucket 内の `bufferedFrameBudgetCount` 最小（サンプル無しは 0 表示） */
  private bucketBufferedMin: number | null = null;
  /** @description bucket 内の `bufferedFrameBudgetCount` 最大 */
  private bucketBufferedMax = 0;
  /** @description bucket 内の `pendingDecodes` 最大 */
  private bucketPendingDecodesPeak = 0;
  /** @description bucket 内の `outputQueue.length` 最大 */
  private bucketOutputQueuePeak = 0;
  /** @description bucket 内で `waitOutput` が `ensureFed` 起点だった回数。 */
  private bucketWaitOutputEnsureFedCalls = 0;
  /** @description bucket 内で `waitOutput` が `pendingHardCap` 起点だった回数。 */
  private bucketWaitOutputPendingHardCapCalls = 0;
  /** @description bucket 内で `pump` が live budget で返った回数。 */
  private bucketPumpStopLiveBudgetCalls = 0;
  /** @description bucket 内で `pump` が per-pump budget で返った回数。 */
  private bucketPumpStopPumpBudgetCalls = 0;
  /** @description bucket 内で `pump` が target budget で返った回数。 */
  private bucketPumpStopTargetBudgetCalls = 0;
  /** @description bucket 内で prefetch が future budget 超過で見送られた回数。 */
  private bucketPrefetchBudgetSkips = 0;
  /** @description bucket 内で prefetch が pending 主導の budget 超過だった回数。 */
  private bucketPrefetchPendingDominatedSkips = 0;
  /** @description セッション全体で見た `pendingDecodes` の最大。後半で decode が溜まるかを見る。 */
  private sessionPendingDecodesPeak = 0;
  /** @description セッション全体で見た `outputQueue.length` の最大。output burst の大きさを見る。 */
  private sessionOutputQueuePeak = 0;
  /** @description セッション全体で `waitForOutputOrError` が実際に待った回数。 */
  private sessionWaitOutputCalls = 0;
  /** @description セッション全体の wait 合計 ms。mediaSync のうち output 待ちがどれだけ支配的かを見る。 */
  private sessionWaitOutputTotalMs = 0;
  /** @description セッション全体で `ensureFed` 起点の wait が何回あったか。 */
  private sessionWaitOutputEnsureFedCalls = 0;
  /** @description セッション全体で `pendingHardCap` 起点の wait が何回あったか。 */
  private sessionWaitOutputPendingHardCapCalls = 0;
  /** @description セッション全体で prefetch が pending 主導 budget に塞がれた回数。 */
  private sessionPrefetchPendingDominatedSkips = 0;

  private constructor(
    probe: ProbeShape,
    onTrace: (line: string) => void,
    mp4: ISOFile,
    videoTrack: Track,
    videoTrackId: number,
    decoderConfigureBase: VideoDecoderConfig,
    decoder: VideoDecoder,
    canvas: HTMLCanvasElement,
    canvasContext: CanvasRenderingContext2D,
    texture: THREE.CanvasTexture,
  ) {
    this.probe = probe;
    this.onTrace = onTrace;
    this.mp4 = mp4;
    this.videoTrack = videoTrack;
    this.videoTrackId = videoTrackId;
    this.decoderConfigureBase = decoderConfigureBase;
    this.decoder = decoder;
    this.canvas = canvas;
    this.canvasContext = canvasContext;
    this.texture = texture;
    this.nbSamplesTotal =
      typeof videoTrack.nb_samples === "number" && videoTrack.nb_samples > 0
        ? videoTrack.nb_samples
        : 0;
    this.frameDurationUsHint = estimateNominalFrameDurationUs({
      durationSec: probe.durationSec,
      nbSamples: this.nbSamplesTotal,
    });
  }

  /**
   * @description 開発時だけ 1 行トレース（時刻は performance.now() の ms）
   * @param note 人間が grep しやすい短文（英語キー推奨）
   */
  private fineTrace(note: string): void {
    if (!WEBCODECS_FINE_TRACE) return;
    this.traceSeq += 1;
    const wallMs = performance.now().toFixed(1);
    this.onTrace(`[動画][WebCodecs][trace] seq=${this.traceSeq} wall=${wallMs}ms ${note}`);
  }

  /**
   * @description waitOutput / stall と共用するデコーダ状態の短い要約（fineTrace 用）
   */
  private snapshotForTrace(): string {
    let decodeQueueSize = "n/a";
    try {
      const d = this.decoder as VideoDecoder & { decodeQueueSize?: number };
      if (typeof d.decodeQueueSize === "number") decodeQueueSize = String(d.decodeQueueSize);
    } catch {
      /* ignore */
    }
    return this.diagnoseStallSummary(decodeQueueSize);
  }

  /**
   * @description 1 フレームぶんの bucket 用に、バッファ厚みのスナップショットを取る。
   */
  private sampleBucketQueues(): void {
    if (!WEBCODECS_BUCKET_PROFILE) return;
    const buf = this.bufferedFrameBudgetCount();
    this.bucketBufferedMin =
      this.bucketBufferedMin === null ? buf : Math.min(this.bucketBufferedMin, buf);
    this.bucketBufferedMax = Math.max(this.bucketBufferedMax, buf);
    this.bucketPendingDecodesPeak = Math.max(this.bucketPendingDecodesPeak, this.pendingDecodes);
    this.bucketOutputQueuePeak = Math.max(this.bucketOutputQueuePeak, this.outputQueue.length);
  }

  /**
   * @description bucket / session に wait reason を積む。
   * @param reason `waitOutput` へ入った呼び出し元
   */
  private noteWaitOutputReason(reason: WaitOutputReason): void {
    if (reason === "ensureFed") {
      this.bucketWaitOutputEnsureFedCalls += 1;
      this.sessionWaitOutputEnsureFedCalls += 1;
      return;
    }
    this.bucketWaitOutputPendingHardCapCalls += 1;
    this.sessionWaitOutputPendingHardCapCalls += 1;
  }

  /**
   * @description bucket 内で `pump` がどの理由で caller へ返ったかを記録する。
   * @param reason 現在の pump 停止理由
   */
  private notePumpStopReason(reason: PumpStopReason): void {
    if (reason === "liveBudget") {
      this.bucketPumpStopLiveBudgetCalls += 1;
      return;
    }
    if (reason === "pumpBudget") {
      this.bucketPumpStopPumpBudgetCalls += 1;
      return;
    }
    if (reason === "targetBudget") {
      this.bucketPumpStopTargetBudgetCalls += 1;
      return;
    }
  }

  /**
   * @description prefetch を budget 超過で見送ったとき、pending 主導だったかまで bucket / session に残す。
   */
  private notePrefetchBudgetSkip(): void {
    this.bucketPrefetchBudgetSkips += 1;
    if (
      isPrefetchBudgetDominatedByPendingDecodes({
        bufferedFrameBudgetCount: this.bufferedFrameBudgetCount(),
        outputQueueLength: this.outputQueue.length,
        pendingDecodes: this.pendingDecodes,
        steadyLeadFrames: STEADY_DECODE_LEAD_FRAMES,
        resumeThresholdFrames: PREFETCH_RESUME_THRESHOLD_FRAMES,
      })
    ) {
      this.bucketPrefetchPendingDominatedSkips += 1;
      this.sessionPrefetchPendingDominatedSkips += 1;
    }
  }

  /**
   * @description 次の 100 フレーム区間へ進む前にカウンタを戻す。
   */
  private resetBucketAccumulators(): void {
    this.bucketEnsureFedFastPathHits = 0;
    this.bucketSchedulePumpCalls = 0;
    this.bucketWaitOutputCalls = 0;
    this.bucketWaitOutputTotalMs = 0;
    this.bucketBufferedMin = null;
    this.bucketBufferedMax = 0;
    this.bucketPendingDecodesPeak = 0;
    this.bucketOutputQueuePeak = 0;
    this.bucketWaitOutputEnsureFedCalls = 0;
    this.bucketWaitOutputPendingHardCapCalls = 0;
    this.bucketPumpStopLiveBudgetCalls = 0;
    this.bucketPumpStopPumpBudgetCalls = 0;
    this.bucketPumpStopTargetBudgetCalls = 0;
    this.bucketPrefetchBudgetSkips = 0;
    this.bucketPrefetchPendingDominatedSkips = 0;
  }

  /**
   * @description `[動画][WebCodecs][bucket]` 1 行を出す（人間が区間比較しやすい英字キー）。
   */
  private emitWebCodecsBucketLine(lo: number, hi: number, reason: string): void {
    const bufLo = this.bucketBufferedMin ?? 0;
    this.onTrace(
      `[動画][WebCodecs][bucket] frames=${lo}-${hi} reason=${reason} ` +
        `ensureFedFast=${this.bucketEnsureFedFastPathHits} schedulePump=${this.bucketSchedulePumpCalls} ` +
        `waitOut=${this.bucketWaitOutputCalls} waitOutMs=${this.bucketWaitOutputTotalMs.toFixed(1)} ` +
        `waitEnsure=${this.bucketWaitOutputEnsureFedCalls} waitPend=${this.bucketWaitOutputPendingHardCapCalls} ` +
        `stopLive=${this.bucketPumpStopLiveBudgetCalls} stopPump=${this.bucketPumpStopPumpBudgetCalls} stopTarget=${this.bucketPumpStopTargetBudgetCalls} ` +
        `prefetchSkip=${this.bucketPrefetchBudgetSkips} prefetchPendDom=${this.bucketPrefetchPendingDominatedSkips} ` +
        `bufMin=${bufLo} bufMax=${this.bucketBufferedMax} pendPeak=${this.bucketPendingDecodesPeak} outQPeak=${this.bucketOutputQueuePeak} ` +
        `inQ=${this.inQPendingCount()} live=${this.liveFrameCount()} livePeakSession=${this.liveFramePeak}`,
    );
  }

  /**
   * @description 書き出しループ正常終了直前に呼ぶ。100 フレームに満たない端数区間を 1 行で吐く。
   */
  flushExportDebugBuckets(reason: string): void {
    if (!WEBCODECS_BUCKET_PROFILE) return;
    const ord = this.presentExportOrdinal;
    if (ord <= 0) return;
    const rem = ord % WEBCODECS_BUCKET_EVERY_PRESENT_FRAMES;
    if (rem === 0) return;
    const lo = ord - rem + 1;
    this.emitWebCodecsBucketLine(lo, ord, reason);
    this.resetBucketAccumulators();
  }

  /**
   * @description inputQueue 先頭の PTS（µs）。いま decode しようとしている位置の観測用。
   */
  private peekNextInputPtsUs(): number | null {
    const sample = this.inputQueue[this.inputQueueReadOffset];
    if (!sample) return null;
    return Math.max(0, Math.round((sample.cts / sample.timescale) * 1_000_000));
  }

  /**
   * @description mp4box からまだデコードしていないサンプル数。
   */
  private inQPendingCount(): number {
    return this.inputQueue.length - this.inputQueueReadOffset;
  }

  /**
   * @description 先頭 1 サンプル分だけ読み取り位置を進め、オフセットが大きいときは配列を圧縮する。
   * @param reason fineTrace 用ラベル（空サンプル破棄か decode 後か）
   */
  private consumeInputQueueHead(reason: string): void {
    this.inputQueueReadOffset += 1;
    this.compactInputQueuePrefixIfNeeded(reason);
  }

  /**
   * @description `readOffset` が数百溜まるたびに先頭を切り捨て、内蔵配列の前詰めコストを抑える。
   */
  private compactInputQueuePrefixIfNeeded(reason: string): void {
    const off = this.inputQueueReadOffset;
    if (off < 384) return;
    const lenBefore = this.inputQueue.length;
    this.inputQueue = this.inputQueue.slice(off);
    this.inputQueueReadOffset = 0;
    if (WEBCODECS_FINE_TRACE) {
      this.fineTrace(
        `STEP inQ compact reason=${reason} droppedPrefix=${off} lenBefore=${lenBefore} lenAfter=${this.inputQueue.length}`,
      );
    }
  }

  /**
   * @description 現在表示中の VideoFrame を返す（Canvas 2D バイパス用）。
   *   Three.js r152+ は VideoFrame を TexImageSource としてネイティブサポートするため、
   *   drawImage(canvas) 経由の色空間二重変換を回避できる。
   */
  get currentFrame(): VideoFrame | null {
    return this.holder;
  }

  /**
   * @description JS がいま保持している `VideoFrame` 数（future queue + 表示中 holder）。
   */
  private liveFrameCount(): number {
    return this.outputQueue.length + (this.holder ? 1 : 0);
  }

  /**
   * @description peak を更新し、黒画面時に「何フレーム抱えていたか」を追えるようにする。
   */
  private noteLiveFramePeak(reason: string): void {
    const live = this.liveFrameCount();
    if (live <= this.liveFramePeak) return;
    this.liveFramePeak = live;
    if (WEBCODECS_FINE_TRACE && (live <= MAX_LIVE_VIDEO_FRAMES || live % 4 === 0)) {
      this.fineTrace(`STEP liveFramePeak live=${live} reason=${reason}`);
    }
  }

  /**
   * @description `decode()` を投げた直後の `pendingDecodes` ピークを記録する。
   *   live frame とは別の「裏で溜まっている decode 量」を summary に残す。
   */
  private notePendingDecodesPeak(): void {
    if (this.pendingDecodes <= this.sessionPendingDecodesPeak) return;
    this.sessionPendingDecodesPeak = this.pendingDecodes;
  }

  /**
   * @description `decoder.output` が burst したときの queue ピークを記録する。
   *   100-frame bucket の観測より細かく、瞬間的な膨らみも落とさず残す。
   */
  private noteOutputQueuePeak(): void {
    if (this.outputQueue.length <= this.sessionOutputQueuePeak) return;
    this.sessionOutputQueuePeak = this.outputQueue.length;
  }

  /**
   * @description sample.duration が読めたとき、target 上界の rough hint を更新する。
   */
  private noteFrameDurationHint(frameDurationUs: number | undefined): void {
    if (
      frameDurationUs !== undefined &&
      Number.isFinite(frameDurationUs) &&
      frameDurationUs > 0
    ) {
      this.frameDurationUsHint = Math.max(1, Math.round(frameDurationUs));
    }
  }

  /**
   * @description 現在すでに抱えている future 量の rough count。
   * `pendingDecodes` も足しておくと、decode 済み待ちだけでなく in-flight も含めて見積もれる。
   */
  private bufferedFrameBudgetCount(): number {
    return this.outputQueue.length + this.pendingDecodes;
  }

  /**
   * @description いまの holder / outputQueue だけで target の表示候補が決まっているか。
   *   `targetBudget stop` はこの条件が true になってから初めて強く効かせる。
   */
  private hasSatisfiedBufferedSelection(targetUs: number): boolean {
    return hasSatisfiedSelectionByBufferedFrames({
      targetUs,
      holderUs: this.holder?.timestamp ?? null,
      nextOutputUs: this.outputQueue[0]?.timestamp ?? null,
      flushCompleted: this.flushCompleted,
    });
  }

  /**
   * @description 現在の target PTS に対して decode を止める future 側の上界。
   */
  private decodeUpperBoundUsForTarget(targetUs: number): number {
    return computeDecodeUpperBoundUs({
      targetUs,
      frameDurationUs: this.frameDurationUsHint,
      hasSatisfiedSelection: this.hasSatisfiedBufferedSelection(targetUs),
    });
  }

  /**
   * @description 現在 target から見て future バッファが薄いとき、描画後に top-up を走らせる。
   * これで fast path でも buffer を枯らし切らず、序盤の速さを維持しやすくする。
   */
  private requestPrefetchAhead(targetUs: number): void {
    if (this.decodeFatal) return;
    if (this.flushPromise || this.flushCompleted) return;
    if (this.inQPendingCount() === 0) return;
    if (this.bufferedFrameBudgetCount() >= STEADY_DECODE_LEAD_FRAMES) {
      this.notePrefetchBudgetSkip();
      return;
    }

    const desiredTargetUs = this.decodeUpperBoundUsForTarget(targetUs);
    this.queuedPrefetchTargetUs =
      this.queuedPrefetchTargetUs === null
        ? desiredTargetUs
        : Math.max(this.queuedPrefetchTargetUs, desiredTargetUs);
    if (this.prefetchInFlight) return;

    this.prefetchInFlight = true;
    void (async () => {
      try {
        while (!this.decodeFatal && this.queuedPrefetchTargetUs !== null) {
          const prefetchTargetUs = this.queuedPrefetchTargetUs;
          this.queuedPrefetchTargetUs = null;
          await this.schedulePump(prefetchTargetUs);
          if (this.decodeFatal) return;
          if (this.inQPendingCount() === 0) return;
          if (this.liveFrameCount() >= MAX_LIVE_VIDEO_FRAMES) return;
          if (this.bufferedFrameBudgetCount() >= STEADY_DECODE_LEAD_FRAMES) {
            this.notePrefetchBudgetSkip();
            return;
          }
          const nextInputPtsUs = this.peekNextInputPtsUs();
          if (nextInputPtsUs !== null && nextInputPtsUs <= prefetchTargetUs) {
            this.queuedPrefetchTargetUs = prefetchTargetUs;
          }
        }
      } finally {
        this.prefetchInFlight = false;
        if (
          !this.decodeFatal &&
          this.queuedPrefetchTargetUs === null &&
          this.requestedTargetUs !== null &&
          this.inQPendingCount() > 0 &&
          this.bufferedFrameBudgetCount() < PREFETCH_RESUME_THRESHOLD_FRAMES
        ) {
          this.requestPrefetchAhead(this.requestedTargetUs);
        }
      }
    })();
  }

  /**
   * @description `close()` を 1 箇所に集約し、例外と監査カウンタをそろえる。
   */
  private closeVideoFrame(frame: VideoFrame | null, reason: string): void {
    if (!frame) return;
    try {
      frame.close();
    } catch {
      /* ignore */
    }
    this.closedFrameCount += 1;
    if (
      WEBCODECS_FINE_TRACE &&
      (this.closedFrameCount <= 24 || this.closedFrameCount % 32 === 0)
    ) {
      this.fineTrace(
        `STEP closeFrame reason=${reason} closed=${this.closedFrameCount} live=${this.liveFrameCount()}`,
      );
    }
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
            /**
             * Electron では HW デコード連打で不安定な事例があるため **ソフト優先**を維持。
             * 今回は stall 側の切り分けを優先し、`optimizeForLatency` は safe side の定数でまとめて切り替える。
             */
            const preferSoftware: VideoDecoderConfig = {
              codec,
              codedWidth,
              codedHeight,
              hardwareAcceleration: "prefer-software",
              optimizeForLatency: WEBCODECS_OPTIMIZE_FOR_LATENCY,
            };
            let sup = await VideoDecoder.isConfigSupported(preferSoftware);
            let decoderConfigureBase: VideoDecoderConfig = preferSoftware;
            if (!sup.supported) {
              const fallback: VideoDecoderConfig = {
                codec,
                codedWidth,
                codedHeight,
                optimizeForLatency: WEBCODECS_OPTIMIZE_FOR_LATENCY,
              };
              sup = await VideoDecoder.isConfigSupported(fallback);
              decoderConfigureBase = fallback;
            }
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
                  if (WEBCODECS_FINE_TRACE && s.decodeOutputCount <= 40) {
                    s.fineTrace(
                      `STEP decoder.output cb#${s.decodeOutputCount} ts=${frame.timestamp}µs pendAfter=${s.pendingDecodes}`,
                    );
                  }
                  if (s.decodeOutputCount <= 3) {
                    s.onTrace(
                      `[動画][WebCodecs][dbg] output #${s.decodeOutputCount} ts=${frame.timestamp}µs dur=${frame.duration ?? "n/a"}`,
                    );
                  }
                  s.outputQueue.push(frame);
                  s.noteOutputQueuePeak();
                  s.noteLiveFramePeak("decoder.output");
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
                  s.onTrace(`[動画][WebCodecs][error] VideoDecoder.error — ${e.message}`);
                  s.fineTrace(`STEP decoder.error ${e.message}`);
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
              decoderConfigureBase,
              decoder,
              canvas,
              ctx,
              texture,
            );
            sessionRef.current = session;
            resolvedSession = session;

            mp4.onSamples = (_id, _user, samples) => {
              session.onSamplesBatch(samples);
            };
            mp4.setExtractionOptions(vtrack.id, {}, { nbSamples: MP4_EXTRACTION_SAMPLES_PER_PULL });
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
   * @param reason `waitOutput` に入った呼び出し元
   */
  private async waitForOutputOrError(
    timeoutMs: number = DECODE_OUTPUT_WAIT_MS,
    reason: WaitOutputReason = "ensureFed",
  ): Promise<void> {
    if (this.outputQueue.length > 0 || this.decodeFatal) return;
    const waitStartedMs = performance.now();
    this.fineTrace(
      `STEP waitOutput BEFORE race timeout=${timeoutMs}ms reason=${reason} | ${this.snapshotForTrace()}`,
    );
    let timer: ReturnType<typeof setTimeout> | undefined;
    let waiter: (() => void) | null = null;
    try {
      await Promise.race([
        new Promise<void>((resolve) => {
          waiter = resolve;
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
      if (waiter) {
        const idx = this.outputWaiters.indexOf(waiter);
        if (idx >= 0) {
          this.outputWaiters.splice(idx, 1);
        }
      }
    }
    if (WEBCODECS_BUCKET_PROFILE) {
      this.bucketWaitOutputCalls += 1;
      this.bucketWaitOutputTotalMs += performance.now() - waitStartedMs;
    }
    this.noteWaitOutputReason(reason);
    this.sessionWaitOutputCalls += 1;
    this.sessionWaitOutputTotalMs += performance.now() - waitStartedMs;
    this.fineTrace(
      `STEP waitOutput AFTER race reason=${reason} | ${this.snapshotForTrace()}`,
    );
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
    const nextInputPtsUs = this.peekNextInputPtsUs();
    const targetUs = this.requestedTargetUs;
    const upperBoundUs =
      targetUs === null ? null : this.decodeUpperBoundUsForTarget(targetUs);
    const selectionReady =
      targetUs === null ? null : this.hasSatisfiedBufferedSelection(targetUs);
    return (
      `decoderState=${this.decoder.state} pendingDecodes=${this.pendingDecodes} ` +
      `inQ=${this.inQPendingCount()} outQ=${this.outputQueue.length} decodeQueueSize=${decodeQueueSize} ` +
      `submitted=${this.decodeSubmitCount} outputCb=${this.decodeOutputCount} ` +
      `liveFrames=${this.liveFrameCount()} liveFramePeak=${this.liveFramePeak} closedFrames=${this.closedFrameCount} ` +
      `frameDurationHintUs=${this.frameDurationUsHint} targetUs=${targetUs ?? "none"} ` +
      `nextInputPtsUs=${nextInputPtsUs ?? "none"} upperBoundUs=${upperBoundUs ?? "none"} selectionReady=${selectionReady ?? "none"} ` +
      `configured=${this.decoderConfigured} extractionDone=${this.extractionDone} fatal=${this.decodeFatal ? this.decodeFatal.message : "none"}`
    );
  }

  /**
   * @description 最初の onSamples より先に present が走ると decode も起きず wait が永久になる。イベントループに譲りつつ configure 完了を待つ。
   */
  private async waitUntilDecoderConfiguredOrThrow(): Promise<void> {
    const deadlineMs = performance.now() + 60_000;
    let spins = 0;
    while (!this.decoderConfigured && !this.decodeFatal) {
      spins += 1;
      if (WEBCODECS_FINE_TRACE && (spins <= 30 || spins % 125 === 0)) {
        this.fineTrace(
          `STEP waitConfigured spin=${spins} decoderConfigured=${this.decoderConfigured}`,
        );
      }
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
    this.fineTrace("STEP waitConfigured EXIT ok");
  }

  private onSamplesBatch(samples: Sample[]): void {
    if (samples.length === 0) return;
    this.fineTrace(
      `STEP onSamplesBatch n=${samples.length} samplesReceivedWill=${this.samplesReceived + samples.length} nbTotal=${this.nbSamplesTotal}`,
    );
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
          ...this.decoderConfigureBase,
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
      const hw =
        this.decoderConfigureBase.hardwareAcceleration ?? "no-preference";
      this.onTrace(
        `[動画][WebCodecs] VideoDecoder.configure coded=${codedWidth}×${codedHeight}（stsd 優先） hwaccel=${hw}`,
      );
    }
    for (const s of samples) {
      this.inputQueue.push(s);
    }
    this.samplesReceived += samples.length;
    const extractionBatchSize = MP4_EXTRACTION_SAMPLES_PER_PULL;
    if (
      (this.nbSamplesTotal > 0 &&
        this.samplesReceived >= this.nbSamplesTotal) ||
      samples.length < extractionBatchSize
    ) {
      this.extractionDone = true;
    }
    this.fineTrace(
      `STEP onSamplesBatch afterPush inQ=${this.inQPendingCount()} bufLen=${this.inputQueue.length} extractionDone=${this.extractionDone} dec=${this.decoder.state}`,
    );
    if (this.requestedTargetUs !== null || this.outputWaiters.length > 0) {
      void this.schedulePump(this.requestedTargetUs);
    } else if (WEBCODECS_FINE_TRACE) {
      this.fineTrace("STEP onSamplesBatch defer pump until present target arrives");
    }
  }

  /**
   * @description 非同期デコードを 1 本のチェーンに直列化する（再入による二重 decode を防ぐ）
   * @returns 今回キューした pumpDecoderImpl 1 回ぶんの完了 Promise（待つと入力キューが一段進む）
   */
  private schedulePump(targetUs: number | null = this.requestedTargetUs): Promise<void> {
    if (WEBCODECS_BUCKET_PROFILE) {
      this.bucketSchedulePumpCalls += 1;
    }
    const scheduleId = (this.pumpScheduleId += 1);
    this.fineTrace(
      `STEP schedulePump#${scheduleId} BEFORE chain targetUs=${targetUs ?? "none"} | inQ=${this.inQPendingCount()} pend=${this.pendingDecodes} sub=${this.decodeSubmitCount} out=${this.decodeOutputCount}`,
    );
    const p = this.pumpChain
      .then(async () => {
        this.fineTrace(`STEP schedulePump#${scheduleId} pumpImpl START`);
        await this.pumpDecoderImpl(targetUs);
        this.fineTrace(
          `STEP schedulePump#${scheduleId} pumpImpl END | inQ=${this.inQPendingCount()} pend=${this.pendingDecodes} sub=${this.decodeSubmitCount} out=${this.decodeOutputCount} dec=${this.decoder.state}`,
        );
      })
      .catch((e) => {
        const msg = e instanceof Error ? e.message : String(e);
        this.fineTrace(`STEP schedulePump#${scheduleId} CHAIN CATCH ${msg}`);
        if (!this.decodeFatal) {
          this.decodeFatal = new Error(`WebCodecsMp4ExportSession.pump 失敗: ${msg}`);
        }
        this.drainOutputWaiters();
      });
    this.pumpChain = p;
    return p;
  }

  /**
   * @description Chromium がデコード完了をマイクロタスクより後に吐く経路があるため、decode の直後に 1 ターン返す。
   */
  private yieldToEventLoopForDecoder(): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(resolve, 0);
    });
  }

  /**
   * @description 初回 output 前は毎 decode で譲り、流れ始めたら **4 回に 1 回** `setTimeout(0)`（output を間に受けやすくする）。
   */
  private shouldYieldAfterDecode(decodeSubmitsThisPump: number): boolean {
    if (this.decodeOutputCount === 0) return true;
    if (this.pendingDecodes >= Math.floor(MAX_PENDING_DECODE_CHUNKS / 2)) {
      return true;
    }
    return decodeSubmitsThisPump % 4 === 0;
  }

  /**
   * @description inputQueue を decode するが、target PTS と live `VideoFrame` 数で future 側を縛る。
   * @param targetUs このポンプが満たしたい target PTS。null のときはまだ present 前。
   */
  private async pumpDecoderImpl(targetUs: number | null): Promise<void> {
    if (this.decodeFatal || !this.decoderConfigured) {
      this.fineTrace(
        `STEP pumpImpl early-return fatal=${!!this.decodeFatal} configured=${this.decoderConfigured}`,
      );
      return;
    }
    /** @description 今回の pump 内で decode した回数（VideoFrame 滞留を抑えるバジェット） */
    let decodeSubmitsThisPump = 0;
    let loopTurn = 0;
    while (this.inQPendingCount() > 0) {
      if (this.decodeFatal) return;
      /**
       * @description すでに JS が抱えている `VideoFrame`（holder + outputQueue）だけで足切りする。
       *   `pendingDecodes` を同じ閾値に足すと、B フレーム並べ替えで **まだ `decode` が必要なのに送れず**詰まり、
       *   暗転・無応答に繋がったため入れない（burst 抑制は `MAX_DECODE_SUBMITS_PER_PUMP` と yield に任せる）。
       */
      if (this.liveFrameCount() >= MAX_LIVE_VIDEO_FRAMES) {
        this.notePumpStopReason("liveBudget");
        this.fineTrace(
          `STEP pumpImpl liveBudget stop live=${this.liveFrameCount()} max=${MAX_LIVE_VIDEO_FRAMES} targetUs=${targetUs ?? "none"}`,
        );
        break;
      }
      if (decodeSubmitsThisPump >= MAX_DECODE_SUBMITS_PER_PUMP) {
        this.notePumpStopReason("pumpBudget");
        this.fineTrace(
          `STEP pumpImpl budget stop decodeSubmitsThisPump=${decodeSubmitsThisPump} inQ=${this.inQPendingCount()} outQ=${this.outputQueue.length}`,
        );
        break;
      }
      loopTurn += 1;
      if (WEBCODECS_FINE_TRACE && (loopTurn <= 32 || loopTurn % 64 === 0)) {
        this.fineTrace(
          `STEP pumpImpl loop=${loopTurn} inQ=${this.inQPendingCount()} pend=${this.pendingDecodes} dec=${this.decoder.state}`,
        );
      }
      while (this.pendingDecodes >= MAX_PENDING_DECODE_CHUNKS) {
        if (this.liveFrameCount() > 0) {
          this.fineTrace(
            `STEP pumpImpl pendingBudget yield-to-caller pending=${this.pendingDecodes} live=${this.liveFrameCount()} targetUs=${targetUs ?? "none"}`,
          );
          return;
        }
        this.fineTrace(
          `STEP pumpImpl BLOCKED pending>=${MAX_PENDING_DECODE_CHUNKS} → waitOutput | ${this.snapshotForTrace()}`,
        );
        await this.waitForOutputOrError(
          DECODE_OUTPUT_WAIT_MS,
          "pendingHardCap",
        );
        if (this.decodeFatal) return;
      }
      const sample = this.inputQueue[this.inputQueueReadOffset]!;
      const data = sample.data;
      if (!data || data.byteLength === 0) {
        this.fineTrace("STEP pumpImpl SKIP empty sample.data（drop 1）");
        this.consumeInputQueueHead("skip-empty-sample");
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
      this.noteFrameDurationHint(dur);
      if (targetUs !== null) {
        const upperBoundUs = this.decodeUpperBoundUsForTarget(targetUs);
        const selectionReady = this.hasSatisfiedBufferedSelection(targetUs);
        if (stamp > upperBoundUs && this.liveFrameCount() > 0) {
          this.notePumpStopReason("targetBudget");
          this.fineTrace(
            `STEP pumpImpl targetBudget stop nextStamp=${stamp} upperBoundUs=${upperBoundUs} targetUs=${targetUs} live=${this.liveFrameCount()} selectionReady=${selectionReady ? "Y" : "N"}`,
          );
          break;
        }
      }
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
        if (WEBCODECS_FINE_TRACE && this.decodeSubmitCount < 24) {
          this.fineTrace(
            `STEP pumpImpl BEFORE decode sub#${this.decodeSubmitCount + 1} type=${chunkType} stampµs=${stamp} bytes=${data.byteLength} dec=${this.decoder.state}`,
          );
        }
        this.pendingDecodes++;
        this.notePendingDecodesPeak();
        this.decoder.decode(chunk);
        this.decodeSubmitCount++;
        this.consumeInputQueueHead("after-decode");
        if (WEBCODECS_FINE_TRACE && this.decodeSubmitCount <= 24) {
          this.fineTrace(
            `STEP pumpImpl AFTER decode sub=${this.decodeSubmitCount} pend=${this.pendingDecodes} dec=${this.decoder.state}`,
          );
        }
        decodeSubmitsThisPump += 1;
        if (this.shouldYieldAfterDecode(decodeSubmitsThisPump)) {
          await this.yieldToEventLoopForDecoder();
        }
      } catch (e) {
        this.pendingDecodes = Math.max(0, this.pendingDecodes - 1);
        const msg = e instanceof Error ? e.message : String(e);
        this.decodeFatal = new Error(`VideoDecoder.decode 失敗: ${msg}`);
        this.drainOutputWaiters();
        return;
      }
    }
    if (this.extractionDone && this.inQPendingCount() === 0 && !this.flushPromise) {
      this.fineTrace(
        `STEP pumpImpl scheduling decoder.flush sub=${this.decodeSubmitCount} out=${this.decodeOutputCount}`,
      );
      this.flushPromise = this.decoder
        .flush()
        .then(() => {
          this.flushCompleted = true;
          this.fineTrace("STEP decoder.flush THEN ok flushCompleted=true");
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
    this.requestedTargetUs = targetUs;
    this.fineTrace(
      `STEP present ENTER timeSec=${t.toFixed(6)} targetUs=${targetUs} | ${this.snapshotForTrace()}`,
    );
    await this.ensureDecoderFedForTarget(targetUs);
    this.fineTrace("STEP present AFTER ensureDecoderFed BEFORE advanceHolder");
    this.advanceHolderToTargetPts(targetUs);
    if (this.decodeFatal) throw this.decodeFatal;
    this.fineTrace(
      `STEP present BEFORE draw holderTs=${this.holder?.timestamp ?? "null"} outQ=${this.outputQueue.length}`,
    );
    this.drawHolderToCanvas();
    this.texture.needsUpdate = true;
    this.requestPrefetchAhead(targetUs);
    const advanceMs = performance.now() - t0;
    this.fineTrace(`STEP present EXIT advanceMs=${advanceMs.toFixed(1)}`);
    if (WEBCODECS_BUCKET_PROFILE) {
      this.sampleBucketQueues();
      this.presentExportOrdinal += 1;
      if (this.presentExportOrdinal % WEBCODECS_BUCKET_EVERY_PRESENT_FRAMES === 0) {
        const hi = this.presentExportOrdinal;
        const lo = hi - WEBCODECS_BUCKET_EVERY_PRESENT_FRAMES + 1;
        this.emitWebCodecsBucketLine(lo, hi, "every100");
        this.resetBucketAccumulators();
      }
    }
    return { advanceMs };
  }

  private async ensureDecoderFedForTarget(targetUs: number): Promise<void> {
    await this.waitUntilDecoderConfiguredOrThrow();
    this.requestedTargetUs = targetUs;
    this.advanceHolderToTargetPts(targetUs);
    if (this.selectionSatisfied(targetUs)) {
      if (WEBCODECS_BUCKET_PROFILE) {
        this.bucketEnsureFedFastPathHits += 1;
      }
      if (WEBCODECS_FINE_TRACE) {
        this.fineTrace(
          `STEP ensureFed fast-path sat=true holderTs=${this.holder?.timestamp ?? "null"} nextOutTs=${this.outputQueue[0]?.timestamp ?? "none"}`,
        );
      }
      return;
    }
    const maxIter = Math.max(4096, this.nbSamplesTotal * 2 + 64);
    for (let i = 0; i < maxIter; i++) {
      if (this.decodeFatal) throw this.decodeFatal;
      if (WEBCODECS_FINE_TRACE && (i < 24 || i % 25 === 0)) {
        this.fineTrace(
          `STEP ensureFed i=${i}/${maxIter} BEFORE schedulePump targetUs=${targetUs} | ${this.snapshotForTrace()}`,
        );
      }
      await this.schedulePump(targetUs);
      this.advanceHolderToTargetPts(targetUs);
      const sat = this.selectionSatisfied(targetUs);
      if (WEBCODECS_FINE_TRACE && (i < 24 || i % 25 === 0)) {
        this.fineTrace(
          `STEP ensureFed i=${i} AFTER pump+advance sat=${sat} holderTs=${this.holder?.timestamp ?? "null"} nextOutTs=${this.outputQueue[0]?.timestamp ?? "none"}`,
        );
      }
      if (sat) return;
      if (this.flushPromise) {
        if (WEBCODECS_FINE_TRACE) {
          this.fineTrace(`STEP ensureFed i=${i} BEFORE await flushPromise`);
        }
        await this.flushPromise;
        if (WEBCODECS_FINE_TRACE) {
          this.fineTrace(`STEP ensureFed i=${i} AFTER flushPromise flushCompleted=${this.flushCompleted}`);
        }
      }
      if (this.decodeFatal) throw this.decodeFatal;
      if (this.outputQueue.length === 0) {
        if (WEBCODECS_FINE_TRACE) {
          this.fineTrace(
            `STEP ensureFed i=${i} outputQueue empty → waitOutput | holderTs=${this.holder?.timestamp ?? "null"}`,
          );
        }
        await this.waitForOutputOrError(DECODE_OUTPUT_WAIT_MS, "ensureFed");
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
    return this.hasSatisfiedBufferedSelection(targetUs);
  }

  private advanceHolderToTargetPts(targetUs: number): void {
    while (
      this.outputQueue.length > 0 &&
      this.outputQueue[0]!.timestamp <= targetUs
    ) {
      this.closeVideoFrame(this.holder, "advanceHolder.replace");
      this.holder = this.outputQueue.shift() ?? null;
    }
    if (this.holder === null && this.outputQueue.length > 0) {
      this.holder = this.outputQueue.shift() ?? null;
    }
  }

  private drawHolderToCanvas(): void {
    if (!this.holder) {
      throw new Error(
        "drawHolderToCanvas: VideoFrame がありません（デコード不足）",
      );
    }
    this.canvasContext.drawImage(
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
    if (this.decodeSubmitCount > 0 || this.decodeOutputCount > 0) {
      this.onTrace(
        `[動画][WebCodecs][summary] submitted=${this.decodeSubmitCount} outputCb=${this.decodeOutputCount} ` +
          `liveFramePeak=${this.liveFramePeak} outQPeak=${this.sessionOutputQueuePeak} ` +
          `pendingPeak=${this.sessionPendingDecodesPeak} waitOut=${this.sessionWaitOutputCalls} ` +
          `waitOutMs=${this.sessionWaitOutputTotalMs.toFixed(1)} waitEnsure=${this.sessionWaitOutputEnsureFedCalls} ` +
          `waitPend=${this.sessionWaitOutputPendingHardCapCalls} ` +
          `prefetchPendDom=${this.sessionPrefetchPendingDominatedSkips} closedFrames=${this.closedFrameCount}`,
      );
    }
    for (const f of this.outputQueue) this.closeVideoFrame(f, "dispose.outputQueue");
    this.outputQueue.length = 0;
    this.closeVideoFrame(this.holder, "dispose.holder");
    this.holder = null;
    try {
      this.decoder.close();
    } catch {
      /* ignore */
    }
    // テクスチャ本体の dispose は Viewport / pipeline の srcTexture と重複しないようここでは行わない
  }
}
