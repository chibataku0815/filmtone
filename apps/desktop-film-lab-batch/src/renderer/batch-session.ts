/**
 * バッチセッション — ディスク永続化用の JSON 形だけを定義する（レンダラ側）
 *
 * @overview 入力フォルダ内の画像パス一覧と、各ファイルの処理結果を覚えておき、
 * アプリ再起動後も「残りだけ再開」できるようにする。
 * @limitations LUT 付き Grade はファイルパス（importedGradePath）でしか復元しない。
 * 編集タブから同期しただけのルックは、セッションには params の JSON 文字列で残す。
 *
 * Look Unification: writer は `batchLookChoice` を canonical として書き、
 * parser は legacy `batchPresetChoice` を fallback として読める。
 * `FilmLabBatchSessionV1` の **on-disk shape は固定** (additive only、version bump しない)
 * で、新フィールド `batchLookChoice` を追加するのみ。Electron 専用 userData なので
 * writer は single emit (dual emit はしない、locked-in #3)。
 */
import {
  sanitizeBatchFilenameSuffix,
  type BatchFormat,
} from "./batch-pipeline";
import { PRESETS, type BaseLookName } from "film-lab-core";

/**
 * @description 1 枚ごとの処理状態（_ok は成功）
 */
export type BatchFileOutcome = "pending" | "ok" | "loadFail" | "writeFail";

/**
 * @description メインプロセスに保存するセッション v1
 */
export type FilmLabBatchSessionV1 = {
  version: 1;
  /** @description 最終更新時刻（ISO 8601） */
  updatedAtIso: string;
  inputDir: string;
  outputDir: string;
  format: BatchFormat;
  /** @description listImages と同じ順序の絶対パス一覧 */
  imagePaths: string[];
  /** @description imagePaths と同じ長さ。未処理は pending */
  outcomes: BatchFileOutcome[];
  batchLookChoice: BaseLookName;
  /** @description Grade JSON を読み込んだときの絶対パス。無ければ null */
  importedGradePath: string | null;
  /**
   * @description imported が無いときに復元する Params JSON（exportGradeJsonText 互換の 1 行でも可）
   * LUT のバイナリは入らない
   */
  gradeParamsJson: string | null;
  /**
   * @description 出力ファイル名の接尾辞（サニタイズ済み）。古い JSON に無い場合はパーサで "-graded"
   */
  outputFilenameSuffix: string;
};

/**
 * @description 空の outcomes 列を作る（最初は全部 pending）
 */
export function initialOutcomes(length: number): BatchFileOutcome[] {
  return Array.from({ length }, () => "pending" as const);
}

/**
 * @description セッションが「まだ終わっていない」か（再開 UI 用）
 */
export function sessionHasRemainingWork(s: FilmLabBatchSessionV1): boolean {
  if (s.imagePaths.length === 0) return false;
  return s.outcomes.some((o) => o !== "ok");
}

/**
 * @description まだ成功していないパスだけを元の順序で返す（再開・再試行の入力）
 */
export function pathsNotSucceeded(s: FilmLabBatchSessionV1): string[] {
  return s.imagePaths.filter((_, i) => s.outcomes[i] !== "ok");
}

const OUTCOME_SET = new Set<BatchFileOutcome>([
  "pending",
  "ok",
  "loadFail",
  "writeFail",
]);

function isBaseLookName(value: string): value is BaseLookName {
  return Object.prototype.hasOwnProperty.call(PRESETS, value);
}

/**
 * @description メインプロセスから渡した unknown を検証し、保存済みセッション v1 なら返す
 */
export function parseFilmLabBatchSessionV1(
  raw: unknown,
): FilmLabBatchSessionV1 | null {
  if (!raw || typeof raw !== "object") return null;
  const o = raw as Record<string, unknown>;
  if (o.version !== 1) return null;
  if (typeof o.inputDir !== "string" || typeof o.outputDir !== "string") {
    return null;
  }
  if (o.format !== "png" && o.format !== "jpeg") return null;
  if (!Array.isArray(o.imagePaths)) return null;
  if (!Array.isArray(o.outcomes)) return null;
  if (o.imagePaths.length !== o.outcomes.length) return null;
  for (const p of o.imagePaths) {
    if (typeof p !== "string" || p.length === 0) return null;
  }
  for (const oc of o.outcomes) {
    if (typeof oc !== "string" || !OUTCOME_SET.has(oc as BatchFileOutcome)) {
      return null;
    }
  }
  // Look Unification parser fallback: prefer canonical `batchLookChoice`,
  // fall back to legacy `batchPresetChoice` for older sessions.
  const rawBaseLookChoice = o.batchLookChoice ?? o.batchPresetChoice;
  if (typeof rawBaseLookChoice !== "string" || !isBaseLookName(rawBaseLookChoice)) {
    return null;
  }
  if (o.importedGradePath !== null && typeof o.importedGradePath !== "string") {
    return null;
  }
  if (o.gradeParamsJson !== null && typeof o.gradeParamsJson !== "string") {
    return null;
  }
  let outputFilenameSuffix = "-graded";
  if (typeof o.outputFilenameSuffix === "string") {
    outputFilenameSuffix = sanitizeBatchFilenameSuffix(o.outputFilenameSuffix);
  }
  return {
    version: 1,
    updatedAtIso: typeof o.updatedAtIso === "string" ? o.updatedAtIso : "",
    inputDir: o.inputDir,
    outputDir: o.outputDir,
    format: o.format,
    imagePaths: o.imagePaths as string[],
    outcomes: o.outcomes as BatchFileOutcome[],
    batchLookChoice: rawBaseLookChoice,
    importedGradePath: o.importedGradePath,
    gradeParamsJson: o.gradeParamsJson,
    outputFilenameSuffix,
  };
}
