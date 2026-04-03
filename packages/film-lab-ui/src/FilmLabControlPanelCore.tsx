"use client";

import {
  type ComponentProps,
  useReducer,
  useState,
  useCallback,
  useEffect,
  useRef,
  type ReactNode,
} from "react";
import { useTranslations } from "next-intl";
import { PRESETS, findMatchingPreset, halationHueToHex, type PresetName } from "film-lab-core";
import { ControlSlider as BaseControlSlider } from "./ui/ControlSlider";
import { SectionHeader } from "./ui/SectionHeader";
import { ToggleHeader } from "./ui/ToggleHeader";
import { LUTPanel } from "./LUTPanel";
import { PresetSearchSelect } from "./PresetSearchSelect";
import type { Viewport } from "film-lab-renderer";
import type { Params } from "film-lab-core";
import {
  filmLabReducer,
  createInitialState,
  createInitialStateFromSharedParams,
  type Action,
  type GradeSlotState,
  type PresentState,
  type State,
} from "./film-lab-reducer";
import { FILM_LAB_NEXT_INTL_NAMESPACE } from "./filmLabUiContract";
import {
  filmLabCollapsibleHeaderButton,
  filmLabDonationPresentRowShell,
  filmLabModeToggleButtonClassName,
  filmLabModeToggleGroupShell,
  filmLabPanelRootClassName,
  filmLabPresetSectionDividerBlock,
} from "./filmLabPanelTokens";

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
  /** Preset セクション内、プリセットバーの前に挿入するノード（Desktop の初期ルック等） */
  beforePresets?: ReactNode;
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
  /** Render-prop: Core state を受け取り Presets 直後に Web 専用セクションを挿入 */
  renderAfterPresets?: (ctx: FilmLabCoreRenderContext) => ReactNode;
  /** Render-prop: Core state を受け取り LUT 直後に Web 専用セクションを挿入 */
  renderAfterLut?: (ctx: FilmLabCoreRenderContext) => ReactNode;
}

/**
 * Web wrapper 等が Core 内部の state / dispatch にアクセスするためのコンテキスト。
 * render-prop slots (`renderAfterPresets`, `renderAfterLut`) に渡される。
 */
export interface FilmLabCoreRenderContext {
  state: State;
  dispatch: React.Dispatch<Action>;
  activePreset: PresetName;
  activeSlotState: GradeSlotState;
  savedBloomStrength: number;
  savedHalationIntensity: number;
  setSavedBloomStrength: (v: number) => void;
  setSavedHalationIntensity: (v: number) => void;
  setActivePreset: (p: PresetName) => void;
  /** Dispatch RESTORE_PRESENT + 補助 state を一括復元 */
  restoreSession: (session: {
    present: PresentState;
    savedBloomStrength: number;
    savedHalationIntensity: number;
    activePreset: PresetName;
  }) => void;
}

interface FilmLabControlPanelCoreProps {
  viewport: Viewport | null;
  histogramVisible?: boolean;
  onHistogramToggle?: () => void;
  surface?: "card" | "bare";
  /** サーバーで ?v=1&p= から復元したパラメータ */
  initialSharedParams?: Params | null;
  onCompareUiChange?: (ui: { compareMode: boolean; activeSlot: "A" | "B" }) => void;
  /** .cube 読み込み成功時 */
  onLutLoadSuccess?: () => void;
  /** LUT が変更されたとき */
  onLutChange?: (state: {
    lut1: { name: string; data: Float32Array; size: number; intensity: number } | null;
    lut2: { name: string; data: Float32Array; size: number; intensity: number } | null;
  }) => void;
  /** パラメータが変更されたとき */
  onParamsChange?: () => void;
  /** プリセットが選ばれたとき */
  onPresetChange?: (preset: PresetName) => void;
  /** 初期 UI モード */
  defaultUiMode?: UiMode;
  /** UI モード変更通知（wrapper が LP 補助パネル開閉に利用） */
  onUiModeChange?: (mode: UiMode) => void;
  /** 拡張スロット */
  slots?: FilmLabControlPanelCoreSlots;
}

function ControlSlider(props: ComponentProps<typeof BaseControlSlider>) {
  return <BaseControlSlider {...props} className={["lg:pr-4", props.className].filter(Boolean).join(" ")} />;
}

export function FilmLabControlPanelCore({
  viewport,
  histogramVisible = true,
  onHistogramToggle,
  surface = "card",
  initialSharedParams = null,
  onCompareUiChange,
  onLutLoadSuccess,
  onLutChange,
  onParamsChange,
  onPresetChange,
  defaultUiMode = "pro",
  onUiModeChange,
  slots = {},
}: FilmLabControlPanelCoreProps) {
  const tFilmLab = useTranslations(FILM_LAB_NEXT_INTL_NAMESPACE);

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
  const [artifactsOpen, setArtifactsOpen] = useState(true);
  const [showHelp, setShowHelp] = useState(false);
  const [sourceTrimOpen, setSourceTrimOpen] = useState(false);
  const beforeAfterPointerActiveRef = useRef(false);
  const prevCompareModeRef = useRef(false);
  const prevBeforeAfterActiveRef = useRef(false);
  const [uiMode, setUiMode] = useState<UiMode>(defaultUiMode);

  useEffect(() => {
    setUiMode(defaultUiMode);
    setArtifactsOpen(defaultUiMode !== "quick");
  }, [defaultUiMode]);

  useEffect(() => {
    onUiModeChange?.(uiMode);
  }, [uiMode, onUiModeChange]);

  /**
   * Quick から Pro に切り替えたときは、Artifacts の補助スライダーを見える状態に戻す。
   * 同じモードのまま手で閉じたときは、ここでは上書きしない。
   */
  useEffect(() => {
    if (uiMode === "quick") {
      setArtifactsOpen(false);
      return;
    }
    setArtifactsOpen(true);
  }, [uiMode]);

  const isPro = uiMode === "pro";

  const activeSlotState = state.activeSlot === "A" ? state.slotA : state.slotB;
  const params = activeSlotState.params;

  const restoreSession = useCallback(
    (session: {
      present: PresentState;
      savedBloomStrength: number;
      savedHalationIntensity: number;
      activePreset: PresetName;
    }) => {
      dispatch({ type: "RESTORE_PRESENT", present: session.present });
      setSavedBloomStrength(session.savedBloomStrength);
      setSavedHalationIntensity(session.savedHalationIntensity);
      setActivePreset(session.activePreset);
    },
    [],
  );

  const coreRenderContext: FilmLabCoreRenderContext = {
    state,
    dispatch,
    activePreset,
    activeSlotState,
    savedBloomStrength,
    savedHalationIntensity,
    setSavedBloomStrength,
    setSavedHalationIntensity,
    setActivePreset,
    restoreSession,
  };

  const presetIntensityAvailable =
    activeSlotState.basePreset != null && activeSlotState.basePreset !== "reset";

  const presetSelectActive: PresetName =
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
  const canToggleHistogram = typeof onHistogramToggle === "function";

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
    onPresetChange?.(name);
  }, [onPresetChange]);

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

  // ── パラメータ変更を親に通知（初回レンダーはスキップ） ──
  const isFirstParamsRender = useRef(true);
  useEffect(() => {
    if (isFirstParamsRender.current) {
      isFirstParamsRender.current = false;
      return;
    }
    onParamsChange?.();
  }, [state, onParamsChange]);

  return (
    <>
      <div className={filmLabPanelRootClassName(surface)}>
        <div className="mb-3">
          <div className={filmLabModeToggleGroupShell} role="group" aria-label={tFilmLab("mode.toggleGroupAria")}>
            <button
              type="button"
              onClick={() => setUiMode("quick")}
              className={filmLabModeToggleButtonClassName(uiMode === "quick")}
            >
              {tFilmLab("mode.quick")}
            </button>
            <button
              type="button"
              onClick={() => setUiMode("pro")}
              className={filmLabModeToggleButtonClassName(uiMode === "pro")}
            >
              {tFilmLab("mode.pro")}
            </button>
          </div>
        </div>

        {slots.donationUi ? (
          <label className={filmLabDonationPresentRowShell}>
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

        <div className={filmLabPresetSectionDividerBlock}>
          <SectionHeader title={tFilmLab("controls.presets")} />
          {slots.beforePresets ? <div className="mb-3">{slots.beforePresets}</div> : null}
          <PresetSearchSelect
            activePreset={presetSelectActive}
            onPreset={applyPreset}
            triggerAriaLabel={tFilmLab("controls.presetSelectTriggerLabel")}
            searchPlaceholder={tFilmLab("controls.presetSearchPlaceholder")}
            emptyLabel={tFilmLab("controls.presetSearchEmpty")}
          />
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

        {slots.renderAfterPresets ? slots.renderAfterPresets(coreRenderContext) : slots.afterPresets}

        <div className="flex flex-col gap-4">

          {/* === PROCESS — film-process-first controls === */}
          {isPro && (
            <div className="min-w-0">
              <SectionHeader title={tFilmLab("controls.process")} />
              <div className="flex flex-col gap-2.5">
                <ControlSlider
                  label={tFilmLab("controls.compression")}
                  value={params.compressionAmount}
                  min={0} max={1} step={0.01} defaultValue={0}
                  formatValue={(v) => `${Math.round(v * 100)}%`}
                  onChange={(v) => updateParam("compressionAmount", v)}
                  onCommit={commit}
                />
                {/*
                 * Range を 100% まで上げると輪郭付近の段差が出やすいため、UI 上限を 92% に抑える。
                 * 共有 URL 等で 1.0 が入っていても params はそのまま保持され、スライダを動かすと 0.92 以下に収まる。
                 */}
                <ControlSlider
                  label={tFilmLab("controls.compressionRange")}
                  value={params.compressionRange}
                  min={0}
                  max={0.92}
                  step={0.01}
                  defaultValue={0.5}
                  formatValue={(v) => `${Math.round(v * 100)}%`}
                  onChange={(v) => updateParam("compressionRange", v)}
                  onCommit={commit}
                />
                <ControlSlider
                  label={tFilmLab("controls.printContrast")}
                  value={params.printContrast}
                  min={0} max={1} step={0.01} defaultValue={0}
                  formatValue={(v) => `${Math.round(v * 100)}%`}
                  onChange={(v) => updateParam("printContrast", v)}
                  onCommit={commit}
                />
                <ControlSlider
                  label={tFilmLab("controls.cyan")}
                  value={params.cyan}
                  min={-1} max={1} step={0.01} defaultValue={0}
                  onChange={(v) => updateParam("cyan", v)}
                  onCommit={commit}
                />
                <ControlSlider
                  label={tFilmLab("controls.magenta")}
                  value={params.magenta}
                  min={-1} max={1} step={0.01} defaultValue={0}
                  onChange={(v) => updateParam("magenta", v)}
                  onCommit={commit}
                />
                <ControlSlider
                  label={tFilmLab("controls.yellow")}
                  value={params.yellow}
                  min={-1} max={1} step={0.01} defaultValue={0}
                  onChange={(v) => updateParam("yellow", v)}
                  onCommit={commit}
                />
              </div>
            </div>
          )}

          {/* === ARTIFACTS (旧 EFFECTS) — Pro only === */}
          {isPro && (
            <div className="min-w-0">
              <CollapsibleHeader title={tFilmLab("controls.artifacts")} open={artifactsOpen} onToggle={() => setArtifactsOpen(!artifactsOpen)} />
              {artifactsOpen && (
                <div className="flex flex-col gap-2.5">
                  <ControlSlider label={tFilmLab("controls.filmGrain")} value={params.grainIntensity} min={0} max={0.5} step={0.01} defaultValue={0} onChange={(v) => updateParam("grainIntensity", v)} onCommit={commit} />
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
              {/**
               * Grain/Vignette は `artifactsOpen` に連動。色収差・レンズ周辺ソフト・グレイン径方向は
               * Bloom/Halation と同様、Artifacts 見出しの折りたたみと無関係に常に出す（閉じると「消えた」ように見えるため）。
               */}
              <div className="mt-3 flex flex-col gap-2.5 border-t border-white/[0.08] pt-3">
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
              </div>
            </div>
          )}

          {/* === SOURCE TRIM — Pro only, collapsed by default === */}
          {isPro && (
            <div className="min-w-0">
              <CollapsibleHeader
                title={tFilmLab("controls.sourceTrim")}
                open={sourceTrimOpen}
                onToggle={() => setSourceTrimOpen(!sourceTrimOpen)}
              />
              {sourceTrimOpen && (
                <div className="flex flex-col gap-2.5">
                  <ControlSlider label={tFilmLab("controls.exposure")} value={params.exposure} min={-3} max={3} step={0.01} defaultValue={0} onChange={(v) => updateParam("exposure", v)} onCommit={commit} />
                  <ControlSlider label={tFilmLab("controls.sourceTemp")} value={params.temperature} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("temperature", v)} onCommit={commit} />
                  <ControlSlider label={tFilmLab("controls.sourceTint")} value={params.tint} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("tint", v)} onCommit={commit} />
                  <ControlSlider label={tFilmLab("controls.highlightsTrim")} value={params.highlights} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("highlights", v)} onCommit={commit} />
                  <ControlSlider label={tFilmLab("controls.shadowsTrim")} value={params.shadows} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("shadows", v)} onCommit={commit} />
                </div>
              )}
            </div>
          )}

          {/* === LUT + extension slots (全モード) === */}
          {slots.hideAuxPanels && slots.lpExpandButton ? (
            <div className="min-w-0">
              {slots.lpExpandButton}
            </div>
          ) : (
          <div className="min-w-0">
            <LUTPanel viewport={viewport} onCubeLutLoaded={onLutLoadSuccess} onLutChange={onLutChange} />
            {slots.renderAfterLut ? slots.renderAfterLut(coreRenderContext) : slots.afterLut}
            {!isPro ? (
              <div className="mt-3">
                <ControlSlider
                  label={tFilmLab("controls.exposure")}
                  value={params.exposure}
                  min={-3}
                  max={3}
                  step={0.01}
                  defaultValue={0}
                  onChange={(v) => updateParam("exposure", v)}
                  onCommit={commit}
                />
              </div>
            ) : null}

            {/* Compare section — Pro のみ */}
            {isPro ? (
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
            ) : null}
            {canToggleHistogram ? (
              <div className="mt-3 border-t border-white/[0.06] pt-3">
                <ToggleHeader
                  title={tFilmLab("controls.histogram")}
                  enabled={histogramVisible}
                  onToggle={() => onHistogramToggle?.()}
                />
              </div>
            ) : null}
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
      className={filmLabCollapsibleHeaderButton}
      onClick={onToggle}
    >
      <span className={`text-[8px] transition-transform duration-150 ${open ? "rotate-90" : ""}`}>
        &#9654;
      </span>
      {title}
    </button>
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
    <div className="flex min-h-[44px] items-center gap-3 sm:min-h-0 lg:pr-4">
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

function ShortcutHelp({ open, onClose }: { open: boolean; onClose: () => void }) {
  const t = useTranslations(`${FILM_LAB_NEXT_INTL_NAMESPACE}.shortcuts`);

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
