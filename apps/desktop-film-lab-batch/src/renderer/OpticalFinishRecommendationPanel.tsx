import type { CSSProperties } from "react";
import { ArrowClockwise, Sparkle } from "@phosphor-icons/react";
import { useTranslations } from "next-intl";
import type { OpticalRecommendationV1 } from "film-lab-core";
import type { AiScenePickResult } from "./ai-scene-pick";
import type { SampledAnalyzerFrame } from "./optical-scene-analysis";

const NO_DRAG_STYLE = { WebkitAppRegion: "no-drag" } as CSSProperties;

const AI_SCENE_PICK_UI_VISIBLE = false;

export type OpticalRecommendationDebugInfo = {
  effectState:
    | "idle"
    | "skipped"
    | "analyzing"
    | "ready"
    | "low-confidence"
    | "error";
  reason?: string;
  previewState: string;
  previewReason?: string;
  hasActiveVideo: boolean;
  interactiveSourceKind: string;
  smartLookDerived: boolean;
  absolutePath?: string | null;
  sourcePath?: string | null;
  currentSrc?: string | null;
  activeSourcePath?: string | null;
  durationSec?: number | null;
  progressiveStage: string;
  qualityLabel?: string | null;
  sourceUrlKind?: string;
  cacheKey?: string;
  analyzerVersion?: string;
  sampleCount?: number | null;
  activity?: string;
  lastError?: string;
  updatedAtIso: string;
};

export type OpticalFinishRecommendationPanelState =
  | { state: "idle" }
  | { state: "analyzing" }
  | { state: "error"; message?: string }
  | {
      state: Extract<OpticalRecommendationV1["state"], "ready" | "low-confidence">;
      recommendation: OpticalRecommendationV1;
    };

export type AiScenePickPanelState =
  | { status: "idle" }
  | { status: "running" }
  | {
      status: "ready";
      result: AiScenePickResult;
      frames: SampledAnalyzerFrame[];
    }
  | { status: "error"; message: string };

export type OpticalFinishRecommendationPanelProps = {
  analysis: OpticalFinishRecommendationPanelState;
  debugInfo?: OpticalRecommendationDebugInfo | null;
  debugLog?: string[];
  appliedSelection?: {
    family: OpticalRecommendationV1["primary"]["family"];
    recipe: OpticalRecommendationV1["primary"]["recipe"];
  } | null;
  /** @description Dev-only PoC. When true, renders a secondary AI card below alternates. */
  aiDevEnabled?: boolean;
  aiScenePick?: AiScenePickPanelState;
  onApplyAi?: () => void;
  onApply: (recommendation: OpticalRecommendationV1, index: number) => void;
  onRetry: () => void;
};

function formatDebugValue(
  value: boolean | number | string | null | undefined,
): string {
  if (value == null || value === "") {
    return "n/a";
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      return "n/a";
    }
    if (Number.isInteger(value)) {
      return String(value);
    }
    return value.toFixed(3).replace(/\.?0+$/, "");
  }
  return String(value);
}

function chipLabelKey(
  chip: OpticalRecommendationV1["primary"]["rationale"][number],
): string {
  switch (chip) {
    case "portraitSafe":
      return "controls.opticalRecommendationChipPortraitSafe";
    case "pointLights":
      return "controls.opticalRecommendationChipPointLights";
    case "mixedScenes":
      return "controls.opticalRecommendationChipMixedScenes";
    default:
      return "controls.opticalRecommendationChipPracticalLights";
  }
}

function recipeLabelKey(
  recipe: OpticalRecommendationV1["primary"]["recipe"],
): string {
  switch (recipe) {
    case "warmIndoor":
      return "controls.opticalRecipeWarmIndoor";
    case "nightCity":
      return "controls.opticalRecipeNightCity";
    case "skinCloseUp":
      return "controls.opticalRecipeSkinCloseUp";
    case "nightSpot":
      return "controls.opticalRecipeNightSpot";
    case "productEdge":
      return "controls.opticalRecipeProductEdge";
    case "coverStillMatch":
      return "controls.opticalRecipeCoverStillMatch";
    default:
      return "controls.opticalProfileClean";
  }
}

function familyLabelKey(
  family: OpticalRecommendationV1["primary"]["family"],
): string {
  switch (family) {
    case "glow":
      return "controls.finishToolsGlow";
    case "cross":
      return "controls.finishToolsCross";
    case "lens":
      return "controls.finishToolsLens";
    default:
      return "controls.finishToolsMist";
  }
}

function RecommendationCard(props: {
  recommendation: OpticalRecommendationV1["primary"];
  emphasized: boolean;
  applied: boolean;
  onApply: () => void;
}) {
  const { recommendation, emphasized, applied, onApply } = props;
  const t = useTranslations("film-lab");
  return (
    <div
      className={[
        "rounded-xl border px-3 py-3",
        applied
          ? "border-[var(--accent-amber1)]/55 bg-[var(--accent-amber1)]/[0.12]"
          : emphasized
          ? "border-[var(--accent-amber1)]/45 bg-[var(--accent-amber1)]/[0.08]"
          : "border-white/10 bg-white/[0.03]",
      ].join(" ")}
      style={NO_DRAG_STYLE}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-white/52">
            {t(
              emphasized
                ? "controls.opticalRecommendationPrimary"
                : "controls.opticalRecommendationAlternate",
            )}
          </p>
          <p className="mt-1 text-sm font-semibold text-white/92">
            {t(familyLabelKey(recommendation.family))}
          </p>
          <p className="mt-0.5 text-[11px] text-white/56">
            {t(recipeLabelKey(recommendation.recipe))}
          </p>
        </div>
        <button
          type="button"
          onClick={onApply}
          className={[
            "shrink-0 rounded-lg px-3 py-2 text-[11px] font-medium transition-colors",
            applied
              ? "bg-[var(--accent-amber1)] text-[var(--accent-amber12)]"
              : emphasized
              ? "bg-[var(--accent-amber1)] text-[var(--accent-amber12)] hover:brightness-105"
              : "border border-white/12 bg-white/[0.04] text-white/76 hover:bg-white/[0.08] hover:text-white/92",
          ].join(" ")}
          style={NO_DRAG_STYLE}
        >
          {applied
            ? t("controls.opticalRecommendationApplied")
            : t("controls.opticalRecommendationApply")}
        </button>
      </div>
      <div className="mt-3 flex flex-wrap gap-1.5">
        {recommendation.rationale.map((chip) => (
          <span
            key={chip}
            className="rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1 text-[10px] text-white/64"
          >
            {t(chipLabelKey(chip))}
          </span>
        ))}
      </div>
    </div>
  );
}

function AiDevToggle(props: { armedByModule: boolean }) {
  if (typeof window === "undefined") return null;
  let stored: string | null = null;
  try {
    stored = window.localStorage?.getItem("filmtone.scenePickDev") ?? null;
  } catch {
    return null;
  }
  const storageOn = stored === "1";
  const armed = props.armedByModule;
  const label = armed ? "ON" : "OFF";
  const willBe = storageOn ? "0" : "1";
  const buttonLabel = storageOn
    ? "OFF にして reload"
    : "ON にして reload";
  const handleClick = () => {
    try {
      window.localStorage.setItem("filmtone.scenePickDev", willBe);
    } catch {
      // ignore
    }
    window.location.reload();
  };
  return (
    <div
      className="mb-2 flex items-center justify-between gap-2"
      style={NO_DRAG_STYLE}
      data-testid="ai-scene-pick-dev-toggle"
    >
      <span
        className={[
          "rounded-full border px-2 py-0.5 text-[9px] font-semibold uppercase tracking-[0.2em]",
          armed
            ? "border-amber-400/30 bg-amber-400/10 text-amber-200/90"
            : "border-white/12 bg-white/[0.04] text-white/56",
        ].join(" ")}
      >
        AI PICK (DEV) — {label}
      </span>
      <button
        type="button"
        onClick={handleClick}
        className="rounded-md border border-white/12 bg-white/[0.04] px-2 py-1 text-[10px] font-medium text-white/76 transition-colors hover:bg-white/[0.08] hover:text-white/92"
        style={NO_DRAG_STYLE}
      >
        {buttonLabel}
      </button>
    </div>
  );
}

function AiScenePickCard(props: {
  state: AiScenePickPanelState;
  onApply: (() => void) | undefined;
  appliedSelection?: OpticalFinishRecommendationPanelProps["appliedSelection"];
}) {
  const { state, onApply, appliedSelection } = props;
  const appliedMatchesAi =
    state.status === "ready" &&
    !state.result.manualFallback &&
    state.result.family != null &&
    appliedSelection?.family === state.result.family &&
    appliedSelection?.recipe === (state.result.recipe ?? null);
  return (
    <div
      className={[
        "rounded-xl border border-dashed px-3 py-3",
        appliedMatchesAi
          ? "border-[var(--accent-amber1)]/55 bg-[var(--accent-amber1)]/[0.12]"
          : "border-white/15 bg-white/[0.03]",
      ].join(" ")}
      style={NO_DRAG_STYLE}
      data-testid="ai-scene-pick-card"
    >
      <div className="flex items-center justify-between gap-2">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-white/56">
          AI PICK
        </p>
        <span className="rounded-full border border-white/10 bg-white/[0.04] px-2 py-0.5 text-[9px] font-medium uppercase tracking-[0.18em] text-white/56">
          experimental / dev
        </span>
      </div>

      {state.status === "idle" ? (
        <p className="mt-2 text-[11px] text-white/52">
          heuristic 解析後に AI 判定を実行します
        </p>
      ) : null}

      {state.status === "running" ? (
        <p className="mt-2 text-[11px] text-white/64">
          AI にフレームを問い合わせ中...
        </p>
      ) : null}

      {state.status === "error" ? (
        <p className="mt-2 text-[11px] text-white/56">
          AI 呼び出しに失敗: {state.message}
        </p>
      ) : null}

      {state.status === "ready" ? (
        <div className="mt-2 flex flex-col gap-2">
          {state.result.bestFrameIndex != null &&
          state.frames[state.result.bestFrameIndex] ? (
            <div className="flex items-start gap-3">
              <img
                src={state.frames[state.result.bestFrameIndex].jpegDataUrl}
                alt={`AI picked frame ${state.result.bestFrameIndex}`}
                className="h-12 w-20 shrink-0 rounded-md border border-white/10 object-cover"
                draggable={false}
              />
              <div className="min-w-0 flex-1 text-[11px] leading-snug text-white/72">
                <p className="font-mono text-[10px] text-white/52">
                  frame #{state.result.bestFrameIndex} ·{" "}
                  {state.frames[state.result.bestFrameIndex].timeSec.toFixed(2)}s
                </p>
                <p className="mt-0.5 text-white/92">
                  {state.result.family ?? "—"} /{" "}
                  {state.result.recipe ?? "clean"}
                </p>
                <p className="mt-0.5 text-white/56">
                  conf: {state.result.confidence} · latency:{" "}
                  {Math.round(state.result.latencyMs)}ms
                </p>
              </div>
            </div>
          ) : (
            <p className="text-[11px] text-white/56">
              フレームが選択されませんでした
            </p>
          )}

          {state.result.reason ? (
            <p className="rounded-md border border-white/8 bg-black/20 px-2.5 py-2 text-[10px] leading-snug text-white/64">
              {state.result.reason}
            </p>
          ) : null}

          {state.result.manualFallback ? (
            <p className="text-[10px] text-white/48">
              AI は確信を持てませんでした — 手動選択を推奨
            </p>
          ) : null}

          <div className="flex justify-end">
            <button
              type="button"
              disabled={
                state.result.manualFallback || state.result.family == null || onApply == null
              }
              onClick={() => onApply?.()}
              className={[
                "rounded-lg px-3 py-2 text-[11px] font-medium transition-colors",
                state.result.manualFallback || state.result.family == null
                  ? "cursor-not-allowed border border-white/8 bg-white/[0.02] text-white/36"
                  : appliedMatchesAi
                    ? "bg-[var(--accent-amber1)] text-[var(--accent-amber12)]"
                    : "border border-white/12 bg-white/[0.06] text-white/88 hover:bg-white/[0.1]",
              ].join(" ")}
              style={NO_DRAG_STYLE}
            >
              {appliedMatchesAi ? "適用済み" : "AI の候補を適用"}
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function DebugRow(props: {
  label: string;
  value: boolean | number | string | null | undefined;
}) {
  const { label, value } = props;
  return (
    <div className="grid grid-cols-[104px,minmax(0,1fr)] gap-2">
      <dt className="text-white/42">{label}</dt>
      <dd className="min-w-0 break-all font-mono text-white/68">
        {formatDebugValue(value)}
      </dd>
    </div>
  );
}

export function OpticalFinishRecommendationPanel(
  props: OpticalFinishRecommendationPanelProps,
) {
  const {
    analysis,
    appliedSelection,
    debugInfo,
    debugLog,
    aiDevEnabled,
    aiScenePick,
    onApply,
    onApplyAi,
    onRetry,
  } = props;
  const t = useTranslations("film-lab");

  const title =
    analysis.state === "low-confidence"
      ? t("controls.opticalRecommendationSafeTitle")
      : t("controls.opticalRecommendationTitle");

  return (
    <section
      className="rounded-xl border border-white/10 bg-white/[0.04] px-3 py-3"
      style={NO_DRAG_STYLE}
    >
      {AI_SCENE_PICK_UI_VISIBLE ? (
        <AiDevToggle armedByModule={aiDevEnabled === true} />
      ) : null}
      <div className="flex items-start gap-2.5">
        <div className="mt-0.5 shrink-0 rounded-full border border-white/10 bg-white/[0.04] p-1.5">
          <Sparkle size={14} weight="duotone" className="text-white/72" />
        </div>
        <div className="min-w-0 flex-1">
          <h3 className="text-sm font-semibold text-white/92">{title}</h3>
          {analysis.state === "idle" ? (
            <p className="mt-1 text-[11px] leading-snug text-white/56">
              {t("controls.opticalRecommendationIdleBody")}
            </p>
          ) : null}
          {analysis.state === "analyzing" ? (
            <p className="mt-1 text-[11px] leading-snug text-white/56">
              {t("controls.opticalRecommendationAnalyzingBody")}
            </p>
          ) : null}
          {analysis.state === "error" ? (
            <>
              <p className="mt-1 text-[11px] leading-snug text-white/56">
                {t("controls.opticalRecommendationErrorBody")}
              </p>
              {analysis.message ? (
                <p className="mt-2 text-[10px] leading-snug text-white/40">
                  {analysis.message}
                </p>
              ) : null}
              <button
                type="button"
                onClick={onRetry}
                className="mt-3 inline-flex items-center gap-1.5 rounded-lg border border-white/12 bg-white/[0.04] px-3 py-2 text-[11px] font-medium text-white/76 transition-colors hover:bg-white/[0.08] hover:text-white/92"
              >
                <ArrowClockwise size={14} weight="bold" />
                {t("controls.opticalRecommendationRetry")}
              </button>
            </>
          ) : null}
          {analysis.state === "ready" ? (
            <p className="mt-1 text-[11px] leading-snug text-white/56">
              {t("controls.opticalRecommendationReadyBody")}
            </p>
          ) : null}
          {analysis.state === "low-confidence" ? (
            <p className="mt-1 text-[11px] leading-snug text-white/56">
              {t("controls.opticalRecommendationLowConfidenceBody")}
            </p>
          ) : null}
          {debugInfo?.activity ? (
            <p className="mt-2 rounded-md border border-white/8 bg-black/20 px-2.5 py-2 text-[10px] leading-snug text-white/68">
              {t("controls.opticalRecommendationDebugActivityPrefix")}{" "}
              {debugInfo.activity}
            </p>
          ) : null}
        </div>
      </div>

      {analysis.state === "ready" || analysis.state === "low-confidence" ? (
        <div className="mt-3 flex flex-col gap-2.5">
          <RecommendationCard
            recommendation={analysis.recommendation.primary}
            emphasized
            applied={
              appliedSelection?.family === analysis.recommendation.primary.family &&
              appliedSelection?.recipe === analysis.recommendation.primary.recipe
            }
            onApply={() => onApply(analysis.recommendation, 0)}
          />
          {analysis.recommendation.alternates.map((alternate, index) => (
            <RecommendationCard
              key={`${alternate.family}:${alternate.recipe ?? "clean"}:${index}`}
              recommendation={alternate}
              emphasized={false}
              applied={
                appliedSelection?.family === alternate.family &&
                appliedSelection?.recipe === alternate.recipe
              }
              onApply={() => onApply(analysis.recommendation, index + 1)}
            />
          ))}
        </div>
      ) : null}

      {AI_SCENE_PICK_UI_VISIBLE && aiDevEnabled && aiScenePick ? (
        <div className="mt-3">
          <AiScenePickCard
            state={aiScenePick}
            onApply={onApplyAi}
            appliedSelection={appliedSelection}
          />
        </div>
      ) : null}

      {debugInfo ? (
        <details
          className="mt-3 rounded-lg border border-white/10 bg-black/20 px-3 py-2 text-[10px] leading-snug text-white/58"
          style={NO_DRAG_STYLE}
        >
          <summary
            className="cursor-pointer list-none font-medium text-white/72"
            style={NO_DRAG_STYLE}
          >
            {t("controls.opticalRecommendationDebugTitle")}
          </summary>
          <dl className="mt-2 flex flex-col gap-1.5">
            <DebugRow
              label={t("controls.opticalRecommendationDebugEffectState")}
              value={debugInfo.effectState}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugSkipReason")}
              value={debugInfo.reason}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugPreviewState")}
              value={debugInfo.previewState}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugPreviewReason")}
              value={debugInfo.previewReason}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugActiveVideo")}
              value={debugInfo.hasActiveVideo}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugSourceKind")}
              value={debugInfo.interactiveSourceKind}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugSmartLook")}
              value={debugInfo.smartLookDerived}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugSourcePath")}
              value={debugInfo.sourcePath}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugAbsolutePath")}
              value={debugInfo.absolutePath}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugCurrentSrc")}
              value={debugInfo.currentSrc}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugActiveSourcePath")}
              value={debugInfo.activeSourcePath}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugDuration")}
              value={debugInfo.durationSec}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugProgressiveStage")}
              value={debugInfo.progressiveStage}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugQuality")}
              value={debugInfo.qualityLabel}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugSourceUrlKind")}
              value={debugInfo.sourceUrlKind}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugCacheKey")}
              value={debugInfo.cacheKey}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugActivity")}
              value={debugInfo.activity}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugAnalyzerVersion")}
              value={debugInfo.analyzerVersion}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugSampleCount")}
              value={debugInfo.sampleCount}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugError")}
              value={debugInfo.lastError}
            />
            <DebugRow
              label={t("controls.opticalRecommendationDebugUpdatedAt")}
              value={debugInfo.updatedAtIso}
            />
          </dl>
          {debugLog && debugLog.length > 0 ? (
            <div className="mt-3 border-t border-white/8 pt-2.5">
              <p className="text-white/42">
                {t("controls.opticalRecommendationDebugLog")}
              </p>
              <div className="mt-1.5 flex max-h-36 flex-col gap-1 overflow-auto rounded-md bg-black/25 p-2 font-mono text-[10px] text-white/62">
                {debugLog.map((line, index) => (
                  <p key={`${line}-${index}`}>{line}</p>
                ))}
              </div>
            </div>
          ) : null}
        </details>
      ) : null}
    </section>
  );
}
