// Source detail compensation resolver (Phase 4 of the Detail Softness lane).
//
// Maps available source metadata to a conservative `recommendedBias` that a
// renderer can pass to `deriveDetailSoftnessUniforms(...,
// { sourceDetailBias })`. Effective render softness remains
// `clamp(detailSoftness + sourceDetailBias, 0, DETAIL_SOFTNESS_EFFECTIVE_MAX)`.
//
// Constraints (see `docs/filmtone/detail-softness/active.md`):
// - Never patched into saved Looks. `sourceDetailBias` is session-derived,
//   not stored creative intent. The resolver returns the bias as a separate
//   number so a caller can log it without touching `FilmtonePhase0Params`.
// - Unknown log transfer → `0`. Unknown Rec.709 → tiny positive (`0.02`).
//   Missing metadata → `0`. The bias is always non-negative and never
//   exceeds `DETAIL_SOFTNESS_EFFECTIVE_MAX`.
// - The resolver consumes types that are already on the wire
//   (`SourceLogTransferFunction`, `SourceCodecFamily`, `SourceColorClass`,
//   `SourceInputTransformPolicy`, `SourceProfileId`) so no contract widening
//   is required to start using it.

import { DETAIL_SOFTNESS_EFFECTIVE_MAX } from "./detail-softness";
import type {
  SourceCodecFamily,
  SourceColorClass,
  SourceInputTransformPolicy,
  SourceLogTransferFunction,
} from "./native-bridge";
import type { SourceProfileId } from "./source-profile-conversion";

export type SourceDetailConfidence = "high" | "medium" | "low" | "none";

export type SourceDetailTransferClass =
  | "rec709-consumer"
  | "rec709-cinema"
  | "log-consumer"
  | "log-cinema"
  | "unknown";

export interface SourceDetailProfile {
  /**
   * Stable diagnostic id for the resolved source class. Safe to log /
   * surface in developer sidecar; not a user-facing label.
   */
  readonly id:
    | "iphone-sdr-hevc"
    | "apple-log"
    | "dji-action"
    | "gopro-action"
    | "sony-slog3"
    | "canon-clog"
    | "panasonic-vlog"
    | "rec709-unknown"
    | "log-unknown"
    | "metadata-missing";
  readonly confidence: SourceDetailConfidence;
  readonly transferClass: SourceDetailTransferClass;
  /**
   * Recommended additive softness bias. `0 ≤ recommendedBias ≤
   * DETAIL_SOFTNESS_EFFECTIVE_MAX`. Pass to
   * `deriveDetailSoftnessUniforms(detailSoftness, { sourceDetailBias })`.
   */
  readonly recommendedBias: number;
  /**
   * Mirror of `DETAIL_SOFTNESS_EFFECTIVE_MAX` so callers do not have to
   * import the renderer constant alongside the resolver result.
   */
  readonly effectiveMax: number;
  /**
   * Short, stable reason string. Suitable for diagnostic logging and
   * sidecar inspection. Not localized.
   */
  readonly reason: string;
}

export interface SourceDetailCompensationInput {
  readonly cameraMake?: string | null;
  readonly cameraModel?: string | null;
  readonly logTransferFunction?: SourceLogTransferFunction | null;
  readonly inputTransformPolicy?: SourceInputTransformPolicy | null;
  readonly codecFamily?: SourceCodecFamily | null;
  readonly colorClass?: SourceColorClass | null;
  readonly sourceProfileId?: SourceProfileId | string | null;
}

const APPLE_LOG_INPUT_STRATEGIES = new Set<string>([
  "apple-log-to-rec709",
  "apple-log2-to-rec709",
]);

const APPLE_LOG_SOURCE_PROFILE_IDS = new Set<string>([
  "built-in:source-profile.apple-log",
  "built-in:source-profile.apple-log-2",
]);

const DJI_SOURCE_PROFILE_IDS = new Set<string>([
  "built-in:source-profile.dji-dlog",
  "built-in:source-profile.dji-dlog-m",
]);

const CANON_LOG_SOURCE_PROFILE_IDS = new Set<string>([
  "built-in:source-profile.canon-clog",
  "built-in:source-profile.canon-log3-cinema-gamut",
]);

const PANASONIC_LOG_SOURCE_PROFILE_IDS = new Set<string>([
  "built-in:source-profile.panasonic-vlog",
]);

const SONY_LOG_SOURCE_PROFILE_IDS = new Set<string>([
  "built-in:source-profile.sony-slog3",
]);

const APPLE_COLOR_CLASSES = new Set<SourceColorClass>([
  "apple-log",
  "apple-log2",
]);

const REC709_COLOR_CLASSES = new Set<SourceColorClass>(["sdr-bt709"]);

function clampBias(value: number): number {
  if (!Number.isFinite(value) || value <= 0) return 0;
  return Math.min(value, DETAIL_SOFTNESS_EFFECTIVE_MAX);
}

function normalizeMake(make: string | null | undefined): string {
  if (!make) return "";
  return make.trim().toLowerCase();
}

function normalizeModel(model: string | null | undefined): string {
  if (!model) return "";
  return model.trim().toLowerCase();
}

function makeProfile(
  id: SourceDetailProfile["id"],
  confidence: SourceDetailConfidence,
  transferClass: SourceDetailTransferClass,
  bias: number,
  reason: string,
): SourceDetailProfile {
  return {
    id,
    confidence,
    transferClass,
    recommendedBias: clampBias(bias),
    effectiveMax: DETAIL_SOFTNESS_EFFECTIVE_MAX,
    reason,
  };
}

/**
 * Resolve a `SourceDetailProfile` for the given metadata bundle. Pure,
 * deterministic, and side-effect free.
 *
 * The resolver intentionally treats unknown / partial metadata as a
 * conservative passthrough. The only way to coax a positive bias is for at
 * least one explicit signal (camera make, log transfer, or
 * built-in source-profile id) to match a known class.
 */
export function resolveSourceDetailCompensation(
  input: SourceDetailCompensationInput = {},
): SourceDetailProfile {
  const make = normalizeMake(input.cameraMake);
  const model = normalizeModel(input.cameraModel);
  const profileId = (input.sourceProfileId ?? "").toString();
  const transferStrategy = input.inputTransformPolicy?.strategy ?? null;

  const appleLogTransfer =
    input.logTransferFunction === "apple-log" ||
    input.logTransferFunction === "apple-log2";
  const appleLogColorClass = input.colorClass
    ? APPLE_COLOR_CLASSES.has(input.colorClass)
    : false;
  const appleLogStrategy = transferStrategy
    ? APPLE_LOG_INPUT_STRATEGIES.has(transferStrategy)
    : false;
  const appleLogProfile = APPLE_LOG_SOURCE_PROFILE_IDS.has(profileId);

  if (
    appleLogTransfer ||
    appleLogColorClass ||
    appleLogStrategy ||
    appleLogProfile
  ) {
    const matchedSignals =
      Number(appleLogTransfer) +
      Number(appleLogColorClass) +
      Number(appleLogStrategy) +
      Number(appleLogProfile);
    const confidence: SourceDetailConfidence =
      matchedSignals >= 2 ? "high" : "medium";
    return makeProfile(
      "apple-log",
      confidence,
      "log-consumer",
      0.06,
      "apple-log-smaller-positive",
    );
  }

  if (SONY_LOG_SOURCE_PROFILE_IDS.has(profileId) || make === "sony") {
    return makeProfile(
      "sony-slog3",
      profileId ? "high" : "medium",
      "log-cinema",
      0.02,
      "sony-log-near-zero",
    );
  }

  if (CANON_LOG_SOURCE_PROFILE_IDS.has(profileId) || make === "canon") {
    return makeProfile(
      "canon-clog",
      profileId ? "high" : "medium",
      "log-cinema",
      0.02,
      "canon-log-near-zero",
    );
  }

  if (
    PANASONIC_LOG_SOURCE_PROFILE_IDS.has(profileId) ||
    make === "panasonic"
  ) {
    return makeProfile(
      "panasonic-vlog",
      profileId ? "high" : "medium",
      "log-cinema",
      0.02,
      "panasonic-log-near-zero",
    );
  }

  if (DJI_SOURCE_PROFILE_IDS.has(profileId) || make === "dji") {
    return makeProfile(
      "dji-action",
      profileId ? "high" : "medium",
      "rec709-consumer",
      0.08,
      "dji-action-positive",
    );
  }

  if (make === "gopro") {
    return makeProfile(
      "gopro-action",
      "medium",
      "rec709-consumer",
      0.08,
      "gopro-action-positive",
    );
  }

  if (make === "apple" || model.startsWith("iphone")) {
    const codec = input.codecFamily ?? null;
    const isProRes = codec === "prores-422" || codec === "prores-4444";
    const isHevc = codec === "hevc";
    const reasonCodec = isProRes ? "iphone-prores" : isHevc ? "iphone-hevc" : "iphone-sdr";
    return makeProfile(
      "iphone-sdr-hevc",
      "high",
      "rec709-consumer",
      0.1,
      `${reasonCodec}-modest-positive`,
    );
  }

  if (
    input.logTransferFunction != null ||
    (transferStrategy != null && transferStrategy !== "none")
  ) {
    return makeProfile(
      "log-unknown",
      "low",
      "unknown",
      0,
      "unknown-log-zero",
    );
  }

  if (
    profileId === "built-in:source-profile.rec709" ||
    (input.colorClass ? REC709_COLOR_CLASSES.has(input.colorClass) : false) ||
    input.codecFamily != null
  ) {
    return makeProfile(
      "rec709-unknown",
      "low",
      "rec709-consumer",
      0.02,
      "unknown-rec709-tiny",
    );
  }

  return makeProfile(
    "metadata-missing",
    "none",
    "unknown",
    0,
    "metadata-missing-zero",
  );
}
