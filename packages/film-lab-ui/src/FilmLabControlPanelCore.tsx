"use client";

import {
  useReducer,
  useState,
  useCallback,
  useEffect,
  useRef,
  type ReactNode,
} from "react";
import { useTranslations } from "next-intl";
import { PRESETS, findMatchingPreset, halationHueToHex, type PresetName } from "film-lab-core";
import { ControlSlider } from "./ui/ControlSlider";
import { LUTPanel } from "./LUTPanel";
import { PresetBar } from "./PresetBar";
import { FilmLabInfoTip } from "./FilmLabInfoTip";
import type { Viewport } from "film-lab-renderer";
import type { Params } from "film-lab-core";
import {
  filmLabReducer,
  createInitialState,
  createInitialStateFromSharedParams,
  type GradeSlotState,
} from "./film-lab-reducer";
import {
  quickMetaDisplayValue,
  quickMetaPatchForValue,
  type QuickMetaAxis,
} from "./quick-meta-sliders";

/** UI の見せ方だけを切り替える。グレードの数値（reducer）は Quick でも Pro でも同じ */
type UiMode = "quick" | "pro";

const RGB_SHIFT_UI_MAX = 0.01;
const RGB_SHIFT_UI_STEP = 0.0001;

function getRgbShiftSliderMax(rgbShift: number): number {
  return Math.max(RGB_SHIFT_UI_MAX, rgbShift);
}

function formatRgbShiftValue(rgbShift: number): string {
  return `${Math.round((rgbShift / RGB_SHIFT_UI_MAX) * 100)}%`;
}

/** フルページ用: プレゼンモード（寄付 UI 全消し）のトグルをコントロールパネルに出す */
export type FilmLabDonationUiBinding = {
  presentMode: boolean;
  onPresentModeChange: (next: boolean) => void;
};

/**
 * Web wrapper から Core の reducer/state にアクセスするためのインタフェース。
 * Web の ControlPanel.tsx はこれを受け取り、smart look / browser storage / share の
 * セクションを自前で描画する。
 */
export interface FilmLabControlPanelCoreSlots {
  /** Preset セクションの直後に挿入するノード（Desktop の smart look prominent 位置） */
  afterPresets?: ReactNode;
  /** LUT の後に挿入するノード（browser storage, share, smart look non-prominent 等） */
  afterLut?: ReactNode;
  /** Donation/present mode UI */
  donationUi?: FilmLabDonationUiBinding;
  /** LP 展開ボタンのカスタム表示（tryFirstLayout で使う） */
  lpExpandButton?: ReactNode;
  /** LP レイアウト時に LUT 以下の補助パネルを隠すフラグ */
  hideAuxPanels?: boolean;
}

interface FilmLabControlPanelCoreProps {
  viewport: Viewport | null;
  histogramVisible?: boolean;
  onHistogramToggle?: () => void;
  /** サーバーで ?v=1&p= から復元したパラメータ */
  initialSharedParams?: Params | null;
  onCompareUiChange?: (ui: { compareMode: boolean; activeSlot: "A" | "B" }) => void;
  /** .cube 読み込み成功時 */
  onLutLoadSuccess?: () => void;
  /** 初期 UI モード */
  defaultUiMode?: UiMode;
  /** 拡張スロット */
  slots?: FilmLabControlPanelCoreSlots;
}

export function FilmLabControlPanelCore({
  viewport,
  histogramVisible = true,
  onHistogramToggle,
  initialSharedParams = null,
  onCompareUiChange,
  onLutLoadSuccess,
  defaultUiMode = "pro",
  slots = {},
}: FilmLabControlPanelCoreProps) {
  const tFilmLab = useTranslations("film-lab");

  const [state, dispatch] = useReducer(
    filmLabReducer,
    undefined,
    () =>
      initialSharedParams
        ? createInitialStateFromSharedParams(initialSharedParams)
        : createInitialState({ ...PRESETS.cinematic } as Params, "cinematic"),
  );
  const [activePreset, setActivePreset] = useState<PresetName>(() =>
    initialSharedParams ? findMatchingPreset(initialSharedParams) ?? "reset" : "cinematic",
  );
  const [savedBloomStrength, setSavedBloomStrength] = useState(0.3);
  const [savedHalationIntensity, setSavedHalationIntensity] = useState(0.25);
  const [effectsOpen, setEffectsOpen] = useState(true);
  const [showHelp, setShowHelp] = useState(false);
  const beforeAfterPointerActiveRef = useRef(false);
  const prevCompareModeRef = useRef(false);
  const prevBeforeAfterActiveRef = useRef(false);
  const [uiMode, setUiMode] = useState<UiMode>(defaultUiMode);

  useEffect(() => {
    if (defaultUiMode === "quick") {
      setEffectsOpen(false);
      setUiMode("quick");
    }
  }, [defaultUiMode]);

  const isPro = uiMode === "pro";

  const activeSlotState = state.activeSlot === "A" ? state.slotA : state.slotB;
  const params = activeSlotState.params;

  const presetIntensityAvailable =
    activeSlotState.basePreset != null && activeSlotState.basePreset !== "reset";

  const presetBarActive: PresetName =
    presetIntensityAvailable && activeSlotState.basePreset
      ? activeSlotState.basePreset
      : activePreset;

  const gradeToViewportRecord = useCallback((slot: GradeSlotState) => {
    return {
      ...slot.params,
      halationColor: halationHueToHex(slot.params.halationHue),
    } as Record<string, number | string>;
  }, []);

  useEffect(() => {
    if (!viewport) return;

    const compareOn = state.compareMode;
    const beforeAfterActive = state.beforeAfterStash != null;

    if (compareOn) {
      viewport.setComparePair(
        true,
        gradeToViewportRecord(state.slotA),
        gradeToViewportRecord(state.slotB),
      );
      if (!prevCompareModeRef.current) {
        viewport.setSplitPosition(0.5);
      }
    } else {
      viewport.setComparePair(false, {}, {});
      const active = state.activeSlot === "A" ? state.slotA : state.slotB;
      viewport.setParams(gradeToViewportRecord(active));

      if (prevCompareModeRef.current && !compareOn) {
        if (!beforeAfterActive) {
          viewport.setSplitPosition(-1.0);
        }
      } else if (beforeAfterActive && !prevBeforeAfterActiveRef.current) {
        viewport.setSplitPosition(0.5);
      } else if (!beforeAfterActive && prevBeforeAfterActiveRef.current) {
        viewport.setSplitPosition(-1.0);
      }
    }

    prevCompareModeRef.current = compareOn;
    prevBeforeAfterActiveRef.current = beforeAfterActive;
  }, [
    viewport,
    state.compareMode,
    state.slotA,
    state.slotB,
    state.activeSlot,
    state.beforeAfterStash,
    gradeToViewportRecord,
  ]);

  useEffect(() => {
    onCompareUiChange?.({
      compareMode: state.compareMode,
      activeSlot: state.activeSlot,
    });
  }, [state.compareMode, state.activeSlot, onCompareUiChange]);

  const bloomEnabled = params.bloomStrength > 0;
  const halationEnabled = params.halationIntensity > 0;

  const updateParam = useCallback((key: keyof Params, value: number) => {
    dispatch({ type: "SET_PARAM", key, value });
    setActivePreset("reset");
  }, []);

  const commit = useCallback(() => {
    dispatch({ type: "COMMIT" });
  }, []);

  const updateHalationHue = useCallback((hue: number) => {
    dispatch({ type: "SET_PARAM", key: "halationHue", value: hue });
    setActivePreset("reset");
  }, []);

  const applyQuickMetaChange = useCallback((axis: QuickMetaAxis, value01: number) => {
    dispatch({ type: "MERGE_PARAMS", patch: quickMetaPatchForValue(axis, value01) });
  }, []);

  const commitQuickMeta = useCallback(() => {
    dispatch({ type: "COMMIT" });
    setActivePreset("reset");
  }, []);

  const toggleBloom = useCallback(
    (on: boolean) => {
      if (on) {
        dispatch({ type: "SET_PARAM", key: "bloomStrength", value: savedBloomStrength || 0.3 });
      } else {
        if (params.bloomStrength > 0) setSavedBloomStrength(params.bloomStrength);
        dispatch({ type: "SET_PARAM", key: "bloomStrength", value: 0 });
      }
      dispatch({ type: "COMMIT" });
      setActivePreset("reset");
    },
    [params.bloomStrength, savedBloomStrength],
  );

  const toggleHalation = useCallback(
    (on: boolean) => {
      if (on) {
        dispatch({ type: "SET_PARAM", key: "halationIntensity", value: savedHalationIntensity || 0.25 });
      } else {
        if (params.halationIntensity > 0) setSavedHalationIntensity(params.halationIntensity);
        dispatch({ type: "SET_PARAM", key: "halationIntensity", value: 0 });
      }
      dispatch({ type: "COMMIT" });
      setActivePreset("reset");
    },
    [params.halationIntensity, savedHalationIntensity],
  );

  const applyPreset = useCallback((name: PresetName) => {
    const preset = PRESETS[name];
    dispatch({ type: "APPLY_PRESET", presetName: name, preset: { ...preset } as Params });
    setActivePreset(name);
  }, []);

  const handleBeforeAfterPointerDown = useCallback((e: React.PointerEvent<HTMLButtonElement>) => {
    e.preventDefault();
    const target = e.currentTarget;
    target.setPointerCapture(e.pointerId);
    if (!beforeAfterPointerActiveRef.current) {
      beforeAfterPointerActiveRef.current = true;
      dispatch({ type: "BEFORE_AFTER_ON" });
    }
  }, []);

  const handleBeforeAfterPointerEnd = useCallback((e: React.PointerEvent<HTMLButtonElement>) => {
    try {
      e.currentTarget.releasePointerCapture(e.pointerId);
    } catch {
      /* capture already released */
    }
    if (beforeAfterPointerActiveRef.current) {
      beforeAfterPointerActiveRef.current = false;
      dispatch({ type: "BEFORE_AFTER_OFF" });
    }
  }, []);

  const handleBeforeAfterLostCapture = useCallback(() => {
    if (beforeAfterPointerActiveRef.current) {
      beforeAfterPointerActiveRef.current = false;
      dispatch({ type: "BEFORE_AFTER_OFF" });
    }
  }, []);

  // Keyboard shortcuts
  useEffect(() => {
    const presetKeys: Record<string, PresetName> = {
      "1": "cinematic", "2": "portra", "3": "gold200", "4": "pro400h",
      "5": "ektar100", "6": "superia400", "7": "cinestill800t", "8": "bw", "0": "reset",
    };

    const handleKeyDown = (e: KeyboardEvent) => {
      if (
        e.target instanceof HTMLInputElement ||
        e.target instanceof HTMLTextAreaElement ||
        (e.target instanceof HTMLElement && e.target.isContentEditable)
      ) return;

      const meta = e.metaKey || e.ctrlKey;

      if (meta && e.shiftKey && e.key.toLowerCase() === "z") {
        e.preventDefault();
        dispatch({ type: "REDO" });
        setActivePreset("reset");
        return;
      }
      if (meta && !e.shiftKey && e.key.toLowerCase() === "z") {
        e.preventDefault();
        dispatch({ type: "UNDO" });
        setActivePreset("reset");
        return;
      }

      if (e.key === " ") {
        e.preventDefault();
        if (!e.repeat) {
          dispatch({ type: "BEFORE_AFTER_ON" });
        }
        return;
      }

      if (e.repeat) return;

      if (presetKeys[e.key]) {
        applyPreset(presetKeys[e.key]);
        return;
      }
      if (e.key === "h" || e.key === "H") {
        onHistogramToggle?.();
        return;
      }
      if (e.key === "Tab" && state.compareMode) {
        e.preventDefault();
        dispatch({ type: "SWITCH_SLOT" });
        return;
      }
      if (e.key === "v" || e.key === "V") {
        e.preventDefault();
        dispatch({ type: "TOGGLE_COMPARE" });
        return;
      }
      if (e.key === "p" || e.key === "P") {
        e.preventDefault();
        setUiMode((m) => (m === "quick" ? "pro" : "quick"));
        return;
      }
      if (e.key === "?") {
        setShowHelp((prev) => !prev);
        return;
      }
      if (e.key === "Escape") {
        setShowHelp(false);
        return;
      }
    };

    const handleKeyUp = (e: KeyboardEvent) => {
      if (e.key !== " ") return;
      if (
        e.target instanceof HTMLInputElement ||
        e.target instanceof HTMLTextAreaElement ||
        (e.target instanceof HTMLElement && e.target.isContentEditable)
      ) {
        return;
      }
      e.preventDefault();
      dispatch({ type: "BEFORE_AFTER_OFF" });
    };

    document.addEventListener("keydown", handleKeyDown, { capture: true });
    document.addEventListener("keyup", handleKeyUp, { capture: true });
    return () => {
      document.removeEventListener("keydown", handleKeyDown, { capture: true });
      document.removeEventListener("keyup", handleKeyUp, { capture: true });
    };
  }, [applyPreset, onHistogramToggle, state.compareMode]);

  return (
    <>
      <div className="@container w-full min-w-0 rounded-lg border border-white/[0.06] bg-black/60 p-4 backdrop-blur-xl sm:p-5">
        <div className="mb-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div
            className="flex rounded-lg border border-white/10 p-0.5"
            role="group"
            aria-label={tFilmLab("mode.hintShort")}
          >
            <button
              type="button"
              onClick={() => setUiMode("quick")}
              className={`flex-1 rounded-md px-3 py-2 text-center text-[11px] font-medium transition-colors sm:flex-none sm:px-4 ${
                uiMode === "quick"
                  ? "bg-[var(--accent-amber1)] text-black"
                  : "text-white/55 hover:text-white/75"
              }`}
            >
              {tFilmLab("mode.quick")}
            </button>
            <button
              type="button"
              onClick={() => setUiMode("pro")}
              className={`flex-1 rounded-md px-3 py-2 text-center text-[11px] font-medium transition-colors sm:flex-none sm:px-4 ${
                uiMode === "pro"
                  ? "bg-[var(--accent-amber1)] text-black"
                  : "text-white/55 hover:text-white/75"
              }`}
            >
              {tFilmLab("mode.pro")}
            </button>
          </div>
          <div className="flex items-start justify-end gap-1 sm:max-w-[260px]">
            <p className="min-w-0 flex-1 text-right text-[10px] leading-snug text-white/35">
              {tFilmLab("mode.hintShort")}
            </p>
            <FilmLabInfoTip
              tip={tFilmLab("mode.hint")}
              assistiveLabel={tFilmLab("mode.hintInfoAria")}
              className="mt-0.5 text-white/35 hover:text-amber-200/80"
            />
          </div>
        </div>

        {slots.donationUi ? (
          <label className="mt-2 flex cursor-pointer items-start gap-2.5 rounded-lg border border-white/[0.06] bg-white/[0.03] p-2.5">
            <input
              type="checkbox"
              checked={slots.donationUi.presentMode}
              onChange={(e) => slots.donationUi!.onPresentModeChange(e.target.checked)}
              className="mt-0.5 h-4 w-4 shrink-0 rounded border-white/20 bg-black/40 text-[var(--accent-amber1)] focus:ring-[var(--accent-amber1)]"
            />
            <span className="min-w-0">
              <span className="block text-[11px] font-medium text-white/80">
                {tFilmLab("donation.present_mode.toggleLabel")}
              </span>
              <span className="mt-1 block text-[10px] leading-snug text-white/38">
                {tFilmLab("donation.present_mode.description")}
              </span>
              <span className="mt-0.5 block text-[10px] text-white/28">
                {tFilmLab("donation.present_mode.urlHint")}
              </span>
            </span>
          </label>
        ) : null}

        <div className="mb-4 min-w-0 border-b border-white/[0.06] pb-4">
          <SectionHeader title={tFilmLab("controls.presets")} />
          <PresetBar activePreset={presetBarActive} onPreset={applyPreset} />
          {presetIntensityAvailable ? (
            <div className="mt-3">
              <ControlSlider
                label={tFilmLab("controls.presetIntensity")}
                value={activeSlotState.intensity}
                min={0}
                max={1}
                step={0.01}
                defaultValue={1}
                formatValue={(v) => `${Math.round(v * 100)}%`}
                onChange={(v) => dispatch({ type: "SET_INTENSITY", value: v })}
                onCommit={() => dispatch({ type: "COMMIT" })}
              />
            </div>
          ) : null}
        </div>

        {slots.afterPresets}

        <div className="grid w-full min-w-0 grid-cols-1 gap-4 @min-[560px]:grid-cols-2 @min-[560px]:gap-6">
          {/* === COLOR GRADING === */}
          <div className={`min-w-0 ${isPro ? "" : "order-2 @min-[560px]:order-2"}`}>
            <SectionHeader title={tFilmLab("controls.color")} />
            {isPro ? (
            <div className="flex flex-col gap-2.5">
              <ControlSlider label={tFilmLab("controls.exposure")} value={params.exposure} min={-3} max={3} step={0.01} defaultValue={0} onChange={(v) => updateParam("exposure", v)} onCommit={commit} />
              <ControlSlider label={tFilmLab("controls.contrast")} value={params.contrast} min={0} max={3} step={0.01} defaultValue={1} onChange={(v) => updateParam("contrast", v)} onCommit={commit} />
              <ControlSlider label={tFilmLab("controls.saturation")} value={params.saturation} min={0} max={3} step={0.01} defaultValue={1} onChange={(v) => updateParam("saturation", v)} onCommit={commit} />
              <ControlSlider label={tFilmLab("controls.temperature")} value={params.temperature} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("temperature", v)} onCommit={commit} />
              <ControlSlider
                label={tFilmLab("color.tint")}
                value={params.tint}
                min={-1}
                max={1}
                step={0.01}
                defaultValue={0}
                onChange={(v) => updateParam("tint", v)}
                onCommit={commit}
              />
              <ControlSlider label={tFilmLab("controls.highlights")} value={params.highlights} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("highlights", v)} onCommit={commit} />
              <ControlSlider label={tFilmLab("controls.shadows")} value={params.shadows} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("shadows", v)} onCommit={commit} />
              <SplitToneHueSlider
                label={tFilmLab("color.shadowHue")}
                value={params.shadowHue}
                onChange={(v) => updateParam("shadowHue", v)}
                onCommit={commit}
              />
              <ControlSlider
                label={tFilmLab("color.shadowTone")}
                value={params.shadowTone}
                min={-1}
                max={1}
                step={0.01}
                defaultValue={0}
                onChange={(v) => updateParam("shadowTone", v)}
                onCommit={commit}
              />
              <SplitToneHueSlider
                label={tFilmLab("color.highlightHue")}
                value={params.highlightHue}
                onChange={(v) => updateParam("highlightHue", v)}
                onCommit={commit}
              />
              <ControlSlider
                label={tFilmLab("color.highlightTone")}
                value={params.highlightTone}
                min={-1}
                max={1}
                step={0.01}
                defaultValue={0}
                onChange={(v) => updateParam("highlightTone", v)}
                onCommit={commit}
              />
              <ControlSlider label={tFilmLab("controls.fade")} value={params.fade} min={0} max={0.3} step={0.01} defaultValue={0} onChange={(v) => updateParam("fade", v)} onCommit={commit} />
            </div>
            ) : (
            <div className="flex flex-col gap-2.5">
              <p className="text-[10px] leading-snug text-white/45">
                {tFilmLab("controls.quick.summary")}
              </p>
              <ControlSlider
                label={tFilmLab("controls.quick.filmLook")}
                hint={tFilmLab("controls.quick.filmLookHint")}
                value={quickMetaDisplayValue("filmLook", params)}
                min={0}
                max={1}
                step={0.01}
                defaultValue={0.5}
                formatValue={(v) => `${Math.round(v * 100)}%`}
                onChange={(v) => applyQuickMetaChange("filmLook", v)}
                onCommit={commitQuickMeta}
              />
              <ControlSlider
                label={tFilmLab("controls.quick.era")}
                hint={tFilmLab("controls.quick.eraHint")}
                value={quickMetaDisplayValue("era", params)}
                min={0}
                max={1}
                step={0.01}
                defaultValue={0.5}
                formatValue={(v) => `${Math.round(v * 100)}%`}
                onChange={(v) => applyQuickMetaChange("era", v)}
                onCommit={commitQuickMeta}
              />
              <ControlSlider
                label={tFilmLab("controls.quick.dynamics")}
                hint={tFilmLab("controls.quick.dynamicsHint")}
                value={quickMetaDisplayValue("dynamics", params)}
                min={0}
                max={1}
                step={0.01}
                defaultValue={0.5}
                formatValue={(v) => `${Math.round(v * 100)}%`}
                onChange={(v) => applyQuickMetaChange("dynamics", v)}
                onCommit={commitQuickMeta}
              />
            </div>
            )}
          </div>

          {/* === EFFECTS (Pro only) === */}
          {isPro ? (
          <div className="min-w-0">
            <CollapsibleHeader title={tFilmLab("controls.effects")} open={effectsOpen} onToggle={() => setEffectsOpen(!effectsOpen)} />
            {effectsOpen && (
              <div className="flex flex-col gap-2.5">
                <ControlSlider
                  label={tFilmLab("controls.rgbShift")}
                  hint={tFilmLab("effects.rgbShiftHint")}
                  value={params.rgbShift}
                  min={0}
                  max={getRgbShiftSliderMax(params.rgbShift)}
                  step={RGB_SHIFT_UI_STEP}
                  defaultValue={0}
                  formatValue={formatRgbShiftValue}
                  onChange={(v) => updateParam("rgbShift", v)}
                  onCommit={commit}
                />
                <ControlSlider
                  label={tFilmLab("controls.lensSoftness")}
                  hint={tFilmLab("effects.lensSoftnessHint")}
                  value={params.lensSoftness}
                  min={0}
                  max={1}
                  step={0.01}
                  defaultValue={0}
                  formatValue={(v) => `${Math.round(v * 100)}%`}
                  onChange={(v) => updateParam("lensSoftness", v)}
                  onCommit={commit}
                />
                <ControlSlider label={tFilmLab("controls.filmGrain")} value={params.grainIntensity} min={0} max={0.5} step={0.01} defaultValue={0} onChange={(v) => updateParam("grainIntensity", v)} onCommit={commit} />
                <ControlSlider
                  label={tFilmLab("controls.grainRadialMix")}
                  hint={tFilmLab("controls.grainRadialMixHint")}
                  value={params.grainRadialMix}
                  min={0}
                  max={1}
                  step={0.01}
                  defaultValue={1}
                  onChange={(v) => updateParam("grainRadialMix", v)}
                  onCommit={commit}
                />
                <ControlSlider label={tFilmLab("controls.vignette")} value={params.vignette} min={0} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("vignette", v)} onCommit={commit} />
              </div>
            )}

            <ToggleHeader title={tFilmLab("controls.bloom")} enabled={bloomEnabled} onToggle={toggleBloom} />
            <div className={`flex flex-col gap-2.5 ${!bloomEnabled ? "pointer-events-none opacity-30" : ""}`}>
              <ControlSlider label={tFilmLab("controls.strength")} value={params.bloomStrength} min={0} max={3} step={0.01} defaultValue={0} onChange={(v) => updateParam("bloomStrength", v)} onCommit={commit} />
              <ControlSlider label={tFilmLab("controls.threshold")} value={params.bloomThreshold} min={0} max={1} step={0.01} defaultValue={0.8} onChange={(v) => updateParam("bloomThreshold", v)} onCommit={commit} />
              <ControlSlider label={tFilmLab("controls.radius")} value={params.bloomRadius} min={0} max={1} step={0.01} defaultValue={0.4} onChange={(v) => updateParam("bloomRadius", v)} onCommit={commit} />
            </div>

            <ToggleHeader title={tFilmLab("controls.halation")} enabled={halationEnabled} onToggle={toggleHalation} />
            <div className={`flex flex-col gap-2.5 ${!halationEnabled ? "pointer-events-none opacity-30" : ""}`}>
              <ControlSlider label={tFilmLab("controls.intensity")} value={params.halationIntensity} min={0} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("halationIntensity", v)} onCommit={commit} />
              <ControlSlider label={tFilmLab("controls.spread")} value={params.halationSpread} min={0} max={50} step={0.5} defaultValue={15} onChange={(v) => updateParam("halationSpread", v)} onCommit={commit} />
              <HueSlider
                label={tFilmLab("controls.halationHue")}
                value={params.halationHue}
                onChange={updateHalationHue}
                onCommit={commit}
              />
            </div>
          </div>
          ) : null}

          {/* === LUT + extension slots === */}
          {slots.hideAuxPanels && slots.lpExpandButton ? (
            <div className="min-w-0 @min-[560px]:col-span-2">
              {slots.lpExpandButton}
            </div>
          ) : (
          <div
            className={`min-w-0 ${isPro ? "@min-[560px]:col-span-2" : "order-1 @min-[560px]:order-1"}`}
          >
            <LUTPanel viewport={viewport} onCubeLutLoaded={onLutLoadSuccess} />
            {slots.afterLut}
            <div className="mt-3 rounded-xl border border-white/[0.08] bg-gradient-to-b from-white/[0.04] to-black/20 p-3">
              <p className="mb-3 text-[10px] font-medium uppercase tracking-[0.12em] text-white/60">
                {tFilmLab("compare.sectionTitle")}
              </p>

              <div className="flex gap-3 rounded-lg border border-white/12 bg-[#111]/90 p-2.5">
                <BeforeAfterPreviewIcon />
                <div className="min-w-0 flex-1">
                  <p className="text-[11px] font-medium leading-snug text-white/85">
                    {tFilmLab("compare.beforeAfterTitle")}
                  </p>
                  <p className="mt-0.5 text-[10px] leading-snug text-white/52">
                    {tFilmLab("compare.beforeAfterHint")}
                  </p>
                </div>
              </div>
              <button
                type="button"
                onPointerDown={handleBeforeAfterPointerDown}
                onPointerUp={handleBeforeAfterPointerEnd}
                onPointerCancel={handleBeforeAfterPointerEnd}
                onLostPointerCapture={handleBeforeAfterLostCapture}
                className="mt-2 w-full rounded-xl border border-white/10 bg-white/5 px-3 py-3 text-left text-[11px] text-white/65 transition-colors hover:bg-white/8 hover:text-white/80 active:bg-white/12 sm:py-2"
              >
                <span className="font-medium text-white/85">{tFilmLab("compare.holdTitle")}</span>
                <span className="mt-0.5 block text-[10px] text-white/52">{tFilmLab("compare.holdHint")}</span>
              </button>

              <div className="my-3 h-px bg-white/[0.08]" />

              <div className="flex gap-3">
                <SplitLooksPreviewIcon />
                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-2">
                    <h3 className="text-[11px] font-medium leading-snug text-white/85">
                      {tFilmLab("compare.title")}
                    </h3>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={state.compareMode}
                      onClick={() =>
                        dispatch({ type: state.compareMode ? "COMPARE_OFF" : "COMPARE_ON" })
                      }
                      className={`mt-0.5 h-4 w-7 shrink-0 rounded-full transition-colors ${
                        state.compareMode ? "bg-[var(--accent-amber1)]" : "bg-white/15"
                      }`}
                    >
                      <span className="sr-only">{tFilmLab("compare.title")}</span>
                      <span
                        className={`block h-3 w-3 rounded-full bg-white transition-transform ${
                          state.compareMode ? "translate-x-3.5" : "translate-x-0.5"
                        }`}
                      />
                    </button>
                  </div>
                  <p className="mt-1.5 text-[10px] leading-relaxed text-white/52">
                    {state.compareMode ? tFilmLab("compare.taglineOn") : tFilmLab("compare.taglineOff")}
                  </p>
                  {state.compareMode ? (
                    <div className="mt-2 flex flex-col gap-1.5 sm:flex-row sm:items-center sm:justify-between">
                      <span className="text-[10px] font-medium text-white/55">
                        {tFilmLab("compare.editLabel")}
                      </span>
                      <div
                        className="inline-flex rounded-lg border border-white/18 bg-black/50 p-0.5 shadow-inner shadow-black/30"
                        role="group"
                        aria-label={tFilmLab("compare.editLabel")}
                      >
                        <button
                          type="button"
                          title={tFilmLab("compare.slotTooltipLeft")}
                          onClick={() => dispatch({ type: "SWITCH_SLOT", slot: "A" })}
                          className={`min-w-[3rem] rounded-md px-2.5 py-1.5 text-[11px] font-semibold transition-colors sm:py-1.5 ${
                            state.activeSlot === "A"
                              ? "bg-[var(--accent-amber1)] text-black shadow-sm"
                              : "bg-transparent text-white/88 hover:bg-white/10 hover:text-white"
                          }`}
                        >
                          {tFilmLab("compare.slotLeft")}
                        </button>
                        <button
                          type="button"
                          title={tFilmLab("compare.slotTooltipRight")}
                          onClick={() => dispatch({ type: "SWITCH_SLOT", slot: "B" })}
                          className={`min-w-[3rem] rounded-md px-2.5 py-1.5 text-[11px] font-semibold transition-colors sm:py-1.5 ${
                            state.activeSlot === "B"
                              ? "bg-[var(--accent-amber1)] text-black shadow-sm"
                              : "bg-transparent text-white/88 hover:bg-white/10 hover:text-white"
                          }`}
                        >
                          {tFilmLab("compare.slotRight")}
                        </button>
                      </div>
                    </div>
                  ) : null}
                </div>
              </div>
            </div>
            <div className="mt-3 border-t border-white/[0.06] pt-3">
              <ToggleHeader title={tFilmLab("controls.histogram")} enabled={histogramVisible} onToggle={() => onHistogramToggle?.()} />
            </div>
          </div>
          )}
        </div>
      </div>
      <ShortcutHelp open={showHelp} onClose={() => setShowHelp(false)} />
    </>
  );
}

/* ── Sub-components ───────────────────────────────────────────── */

function BeforeAfterPreviewIcon() {
  return (
    <svg width={44} height={32} viewBox="0 0 44 32" className="shrink-0 text-white/30" aria-hidden>
      <rect x="1" y="5" width="19" height="22" rx="3" fill="currentColor" opacity="0.45" />
      <rect x="24" y="5" width="19" height="22" rx="3" fill="var(--accent-amber1)" opacity="0.55" />
    </svg>
  );
}

function SplitLooksPreviewIcon() {
  return (
    <svg width={44} height={32} viewBox="0 0 44 32" className="shrink-0 text-white/30" aria-hidden>
      <rect x="1" y="5" width="42" height="22" rx="3" fill="currentColor" opacity="0.15" />
      <rect x="1" y="5" width="20" height="22" rx="3" fill="var(--accent-amber1)" opacity="0.35" />
      <rect x="23" y="5" width="20" height="22" rx="3" fill="var(--accent-amber1)" opacity="0.6" />
      <line x1="22" y1="5" x2="22" y2="27" stroke="white" strokeWidth="1.2" opacity="0.45" />
    </svg>
  );
}

export function SectionHeader({ title }: { title: string }) {
  return (
    <h3 className="mb-2 mt-3 text-[10px] font-medium uppercase tracking-[0.15em] text-white/40 first:mt-0">
      {title}
    </h3>
  );
}

function CollapsibleHeader({
  title,
  open,
  onToggle,
}: {
  title: string;
  open: boolean;
  onToggle: () => void;
}) {
  return (
    <button
      className="mb-2 mt-3 flex w-full items-center gap-1.5 text-[10px] font-medium uppercase tracking-[0.15em] text-white/40 transition-colors hover:text-white/60 first:mt-0"
      onClick={onToggle}
    >
      <span className={`text-[8px] transition-transform duration-150 ${open ? "rotate-90" : ""}`}>
        &#9654;
      </span>
      {title}
    </button>
  );
}

function SplitToneHueSlider({
  label,
  value,
  onChange,
  onCommit,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  onCommit?: () => void;
}) {
  const h = ((value % 360) + 360) % 360;
  return (
    <div className="flex min-h-[44px] items-center gap-3 sm:min-h-0">
      <span className="w-16 shrink-0 text-[11px] text-white/50 sm:w-24">{label}</span>
      <div className="relative flex-1">
        <input
          type="range"
          min={0}
          max={360}
          step={1}
          value={h}
          onChange={(e) => onChange(Number(e.target.value))}
          onPointerUp={() => onCommit?.()}
          onTouchEnd={() => onCommit?.()}
          className="split-tone-hue-slider h-1.5 w-full cursor-pointer appearance-none rounded-full touch-none"
          style={{
            background:
              "linear-gradient(to right, hsl(0,100%,50%), hsl(60,100%,50%), hsl(120,100%,50%), hsl(180,100%,50%), hsl(240,100%,50%), hsl(300,100%,50%), hsl(360,100%,50%))",
          }}
        />
      </div>
      <div
        className="h-4 w-4 shrink-0 rounded-full border border-white/20"
        style={{ backgroundColor: `hsl(${h} 100% 50%)` }}
      />
    </div>
  );
}

function HueSlider({
  label,
  value,
  onChange,
  onCommit,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  onCommit?: () => void;
}) {
  const hex = halationHueToHex(value);
  return (
    <div className="flex min-h-[44px] items-center gap-3 sm:min-h-0">
      <span className="w-16 shrink-0 text-[11px] text-white/50 sm:w-24">{label}</span>
      <div className="relative flex-1">
        <input
          type="range"
          min={0}
          max={100}
          step={1}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          onPointerUp={() => onCommit?.()}
          onTouchEnd={() => onCommit?.()}
          className="halation-hue-slider h-1.5 w-full cursor-pointer appearance-none rounded-full touch-none"
          style={{
            background: `linear-gradient(to right, #e81020, #d83818, #c86010)`,
          }}
        />
      </div>
      <div
        className="h-4 w-4 shrink-0 rounded-full border border-white/20"
        style={{ backgroundColor: hex }}
      />
    </div>
  );
}

export function ToggleHeader({
  title,
  enabled,
  onToggle,
}: {
  title: string;
  enabled: boolean;
  onToggle: (on: boolean) => void;
}) {
  return (
    <div className="mb-2 mt-3 flex items-center justify-between gap-3">
      <h3 className="text-[10px] font-semibold uppercase tracking-[0.15em] text-white/65">
        {title}
      </h3>
      <button
        type="button"
        onClick={() => onToggle(!enabled)}
        className={`relative box-border h-5 w-9 shrink-0 rounded-full border transition-colors ${
          enabled
            ? "border-[color-mix(in_srgb,var(--accent-amber1)_70%,transparent)] bg-[var(--accent-amber1)]"
            : "border-white/25 bg-[#1c1c1c] hover:border-white/35"
        }`}
        aria-pressed={enabled}
      >
        <span
          aria-hidden
          className={`pointer-events-none absolute inset-y-0 my-auto block h-4 w-4 rounded-full bg-white transition-all ${
            enabled ? "right-0.5 left-auto" : "left-0.5 right-auto"
          }`}
        />
      </button>
    </div>
  );
}

function ShortcutHelp({ open, onClose }: { open: boolean; onClose: () => void }) {
  const t = useTranslations("film-lab.shortcuts");

  if (!open) return null;

  const isMac = typeof navigator !== "undefined" && /Mac|iPod|iPhone|iPad/.test(navigator.userAgent);
  const mod = isMac ? "\u2318" : "Ctrl";

  const shortcuts: { key: string; action: string }[] = [
    { key: "1 \u2013 8", action: t("presetSelect") },
    { key: "0", action: t("reset") },
    { key: "Space", action: t("beforeAfter") },
    { key: "Hold button", action: t("holdButton") },
    { key: "Preset slider", action: t("presetSlider") },
    { key: `${mod}+Z`, action: t("undo") },
    { key: `${mod}+Shift+Z`, action: t("redo") },
    { key: "V", action: t("toggleCompare") },
    { key: "Tab", action: t("switchSlot") },
    { key: "P", action: t("toggleMode") },
    { key: "H", action: t("histogram") },
    { key: "?", action: t("help") },
  ];

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="max-w-sm rounded-xl border border-white/10 bg-[#1a1a1a] p-6 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="mb-4 text-sm font-medium text-white/80">{t("title")}</h2>
        <div className="space-y-2.5">
          {shortcuts.map((s) => (
            <div key={s.key} className="flex items-center justify-between gap-8">
              <kbd className="rounded bg-white/10 px-2 py-0.5 font-mono text-xs text-white/60">
                {s.key}
              </kbd>
              <span className="text-xs text-white/50">{s.action}</span>
            </div>
          ))}
        </div>
        <p className="mt-4 text-[10px] text-white/30">{t("closeHint")}</p>
      </div>
    </div>
  );
}
