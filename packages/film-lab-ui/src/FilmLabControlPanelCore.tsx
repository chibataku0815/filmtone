"use client";

import {
  type ComponentProps,
  forwardRef,
  useReducer,
  useState,
  useCallback,
  useEffect,
  useImperativeHandle,
  useRef,
  type ReactNode,
} from "react";
import { useTranslations } from "next-intl";
import { PRESETS, findMatchingPreset, halationHueToHex, type PresetName } from "film-lab-core";
import { ControlSlider as BaseControlSlider } from "./ui/ControlSlider";
import { SectionHeader } from "./ui/SectionHeader";
import { SegmentedControl } from "./ui/SegmentedControl";
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

const COMPRESSION_AMOUNT_UI_MAX = 0.4;
const COMPRESSION_RANGE_UI_MAX = 0.6;
const COMPRESSION_AMOUNT_DEFAULT = 0.1;

function getCompressionAmountSliderMax(compressionAmount: number): number {
  return Math.max(COMPRESSION_AMOUNT_UI_MAX, compressionAmount);
}

function getCompressionRangeSliderMax(compressionRange: number): number {
  return Math.max(COMPRESSION_RANGE_UI_MAX, compressionRange);
}

/**
 * @description 親から `FilmLabControlPanelCore` を命令的に操作するための ref API。
 * `FilmLabCanvas` の HUD 解除ボタンなど、兄弟コンポーネントから compare を閉じるときに使います。
 */
export type FilmLabCoreRef = {
  /** compare モードを強制的に OFF にします。 */
  compareOff(): void;
};

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
  /**
   * @description true かつ Compare モードでないとき、`Space` を「オリジナル一時表示」に使わず、
   * 動画トランスポート（`VideoTransportControls`）へ渡します。
   */
  deferSpaceKeyToVideoTransportWhenNoCompare?: boolean;
}

/**
 * @description Control Panel 用の安定したスライダーラッパーです。
 * 親コンポーネントの中で別コンポーネントを毎回作ると、再描画のたびに
 * `input[type="range"]` が差し替わり、つまみドラッグが途中で切れることがあります。
 * そのため module scope に置き、native range の DOM を保ちます。
 */
type PanelControlSliderProps = ComponentProps<typeof BaseControlSlider> & {
  /** Panel 内で使う翻訳済みの「ラベルを押すと初期値へ戻る」説明文 */
  sliderLabelResetHint: string;
};

/**
 * @description 右パネル用の `ControlSlider` です。
 * 共有 UI の見た目は保ちつつ、Panel 固有の余白と reset hint をまとめます。
 */
function PanelControlSlider({
  sliderLabelResetHint,
  className,
  labelClassName,
  labelResetHint,
  ...props
}: PanelControlSliderProps) {
  const panelSliderLabelClassName = [
    "min-w-[7.5rem] shrink-0 cursor-pointer text-[11px] leading-tight text-[var(--text-muted)] select-none whitespace-nowrap sm:min-w-[8.5rem]",
    labelClassName,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <BaseControlSlider
      {...props}
      labelClassName={panelSliderLabelClassName}
      labelResetHint={labelResetHint ?? sliderLabelResetHint}
      className={["lg:pr-4", className].filter(Boolean).join(" ")}
    />
  );
}

type FinishToolStarterState = {
  id: "subtle" | "signature";
  labelKey: "controls.finishToolsStarterSubtle" | "controls.finishToolsStarterSignature";
  patch: Partial<Params>;
};

const CROSS_STARTER_STATES: readonly FinishToolStarterState[] = [
  {
    id: "subtle",
    labelKey: "controls.finishToolsStarterSubtle",
    patch: {
      crossFilterStrength: 0.25,
      crossFilterSpikes: 4,
      crossFilterAngle: 0,
      crossFilterLength: 0.38,
      crossFilterThreshold: 0.92,
      crossFilterChromatic: 0.18,
      crossFilterSizeLimit: 0.12,
      crossFilterRandomness: 0.9,
      crossFilterHardMode: 1,
      crossFilterMinSpacing: 0.1,
    },
  },
  {
    id: "signature",
    labelKey: "controls.finishToolsStarterSignature",
    patch: {
      crossFilterStrength: 0.55,
      crossFilterSpikes: 6,
      crossFilterAngle: 15,
      crossFilterLength: 0.62,
      crossFilterThreshold: 0.92,
      crossFilterChromatic: 0.4,
      crossFilterSizeLimit: 0.24,
      crossFilterRandomness: 0.75,
      crossFilterHardMode: 1,
      crossFilterMinSpacing: 0.22,
    },
  },
] as const;

const GLOW_STARTER_STATES: readonly FinishToolStarterState[] = [
  {
    id: "subtle",
    labelKey: "controls.finishToolsStarterSubtle",
    patch: {
      bloomStrength: 0.22,
      bloomThreshold: 0.72,
      bloomRadius: 0.52,
      diffusion: 0.08,
      halationIntensity: 0.10,
      halationSpread: 22,
      halationRadius: 0.44,
      halationHue: 20,
    },
  },
  {
    id: "signature",
    labelKey: "controls.finishToolsStarterSignature",
    patch: {
      bloomStrength: 0.42,
      bloomThreshold: 0.64,
      bloomRadius: 0.62,
      diffusion: 0.16,
      halationIntensity: 0.22,
      halationSpread: 30,
      halationRadius: 0.60,
      halationHue: 26,
    },
  },
] as const;

export const FilmLabControlPanelCore = forwardRef<
  FilmLabCoreRef,
  FilmLabControlPanelCoreProps
>(function FilmLabControlPanelCore({
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
  deferSpaceKeyToVideoTransportWhenNoCompare = false,
}: FilmLabControlPanelCoreProps, ref) {
  const tFilmLab = useTranslations(FILM_LAB_NEXT_INTL_NAMESPACE);

  /** Pro「階調」ブロックの長い日本語ラベルが不自然に折り返されないよう、列幅と nowrap を確保する */
  const processSliderLabelClassName =
    "min-w-[6.75rem] shrink-0 cursor-pointer text-[11px] leading-tight text-[var(--text-muted)] select-none whitespace-nowrap sm:min-w-[7.25rem]";

  const sliderLabelResetHint = tFilmLab("controls.sliderLabelReset");

  const [state, dispatch] = useReducer(
    filmLabReducer,
    undefined,
    () =>
      initialSharedParams
        ? createInitialStateFromSharedParams(initialSharedParams)
        : createInitialState({ ...PRESETS.cinematic } as Params, "cinematic"),
  );

  useImperativeHandle(ref, () => ({
    compareOff: () => dispatch({ type: "COMPARE_OFF" }),
  }), []);

  const [activePreset, setActivePreset] = useState<PresetName>(() =>
    initialSharedParams ? findMatchingPreset(initialSharedParams) ?? "reset" : "cinematic",
  );
  const [savedBloomStrength, setSavedBloomStrength] = useState(0.3);
  const [savedHalationIntensity, setSavedHalationIntensity] = useState(0.25);
  const [savedShaftIntensity, setSavedShaftIntensity] = useState(0.4);
  const [savedCrossFilterStrength, setSavedCrossFilterStrength] = useState(0.5);
  const [artifactsOpen, setArtifactsOpen] = useState(true);
  const [glowAdvancedOpen, setGlowAdvancedOpen] = useState(false);
  const [crossAdvancedOpen, setCrossAdvancedOpen] = useState(false);
  // v0.5.0: postEffectsOpen removed — motionBlur moved to ARTIFACTS, section eliminated
  const [showHelp, setShowHelp] = useState(false);
  const [sourceTrimOpen, setSourceTrimOpen] = useState(false);
  const [compareOpen, setCompareOpen] = useState(false);
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
   * Quick から Pro に切り替えたときは、Finish Tools セクションを見える状態に戻す。
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
  const initialCompressionAmount = initialSharedParams?.compressionAmount;

  /**
   * @description ハイライト圧縮の最後の非ゼロ値を覚える。いったん 0 にしても、次にオンへ戻すと前の強さを使う。
   */
  const compressionAmountLastNonZeroRef = useRef<number>(
    initialCompressionAmount != null && initialCompressionAmount > 0
      ? initialCompressionAmount
      : COMPRESSION_AMOUNT_DEFAULT,
  );

  /**
   * @description compressionAmount が 0 より大きい間だけ、最後の非ゼロ値を更新する。
   * これでプリセットや共有セッションを開き直したあとでも、オンに戻したとき自然な値へ戻せる。
   */
  useEffect(() => {
    if (params.compressionAmount > 0) {
      compressionAmountLastNonZeroRef.current = params.compressionAmount;
    }
  }, [params.compressionAmount]);

  /**
   * @description 色収差の最後の非ゼロ値を覚える。いったん 0 にしても、次にオンへ戻すと前の強さを使う。
   */
  const rgbShiftLastNonZeroRef = useRef<number>(
    initialSharedParams?.rgbShift ?? PRESETS.cinematic.rgbShift,
  );

  /**
   * @description rgbShift が 0 より大きい間だけ、最後の非ゼロ値を更新する。
   * これでプリセットや共有セッションを開き直したあとでも、オンに戻したとき自然な値へ戻せる。
   */
  useEffect(() => {
    if (params.rgbShift > 0) {
      rgbShiftLastNonZeroRef.current = params.rgbShift;
    }
  }, [params.rgbShift]);

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
  const compressionAmountEnabled = params.compressionAmount > 0;
  const rgbShiftEnabled = params.rgbShift > 0;
  const shaftEnabled = params.shaftIntensity > 0;
  const crossFilterEnabled = params.crossFilterStrength > 0;
  const canToggleHistogram = typeof onHistogramToggle === "function";

  const updateParam = useCallback((key: keyof Params, value: number) => {
    dispatch({ type: "SET_PARAM", key, value });
    setActivePreset("reset");
  }, []);

  const commit = useCallback(() => {
    dispatch({ type: "COMMIT" });
  }, []);

  const applyParamPatch = useCallback((patch: Partial<Params>) => {
    dispatch({ type: "MERGE_PARAMS", patch });
    dispatch({ type: "COMMIT" });

    if (typeof patch.bloomStrength === "number" && patch.bloomStrength > 0) {
      setSavedBloomStrength(patch.bloomStrength);
    }
    if (typeof patch.halationIntensity === "number" && patch.halationIntensity > 0) {
      setSavedHalationIntensity(patch.halationIntensity);
    }
    if (typeof patch.crossFilterStrength === "number" && patch.crossFilterStrength > 0) {
      setSavedCrossFilterStrength(patch.crossFilterStrength);
    }

    setActivePreset("reset");
  }, []);

  const applyCrossStarterState = useCallback((patch: Partial<Params>) => {
    setCrossAdvancedOpen(false);
    applyParamPatch(patch);
  }, [applyParamPatch]);

  const applyGlowStarterState = useCallback((patch: Partial<Params>) => {
    setGlowAdvancedOpen(true);
    applyParamPatch(patch);
  }, [applyParamPatch]);

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

  const toggleShaft = useCallback(
    (on: boolean) => {
      if (on) {
        dispatch({ type: "SET_PARAM", key: "shaftIntensity", value: savedShaftIntensity || 0.4 });
      } else {
        if (params.shaftIntensity > 0) setSavedShaftIntensity(params.shaftIntensity);
        dispatch({ type: "SET_PARAM", key: "shaftIntensity", value: 0 });
      }
      dispatch({ type: "COMMIT" });
      setActivePreset("reset");
    },
    [params.shaftIntensity, savedShaftIntensity],
  );

  const toggleCrossFilter = useCallback(
    (on: boolean) => {
      if (on) {
        dispatch({ type: "SET_PARAM", key: "crossFilterStrength", value: savedCrossFilterStrength || 0.5 });
      } else {
        if (params.crossFilterStrength > 0) setSavedCrossFilterStrength(params.crossFilterStrength);
        dispatch({ type: "SET_PARAM", key: "crossFilterStrength", value: 0 });
      }
      dispatch({ type: "COMMIT" });
      setActivePreset("reset");
    },
    [params.crossFilterStrength, savedCrossFilterStrength],
  );

  /**
   * @description ハイライト圧縮をオン/オフする。オフにすると 0 にし、オンにすると最後の非ゼロ値か既定値へ戻す。
   * @param {boolean} on - つけるなら true、消すなら false。
   */
  const toggleCompressionAmount = useCallback(
    (on: boolean) => {
      if (on) {
        const nextCompressionAmount =
          compressionAmountLastNonZeroRef.current > 0
            ? compressionAmountLastNonZeroRef.current
            : COMPRESSION_AMOUNT_DEFAULT;
        dispatch({
          type: "SET_PARAM",
          key: "compressionAmount",
          value: nextCompressionAmount,
        });
      } else {
        if (params.compressionAmount > 0) {
          compressionAmountLastNonZeroRef.current = params.compressionAmount;
        }
        dispatch({ type: "SET_PARAM", key: "compressionAmount", value: 0 });
      }
      dispatch({ type: "COMMIT" });
      setActivePreset("reset");
    },
    [params.compressionAmount],
  );

  /**
   * @description 色収差をオン/オフする。オフにすると 0 にし、オンにすると最後の非ゼロ値か既定値へ戻す。
   * @param {boolean} on - つけるなら true、消すなら false。
   */
  const toggleRgbShift = useCallback(
    (on: boolean) => {
      if (on) {
        const nextRgbShift =
          rgbShiftLastNonZeroRef.current > 0
            ? rgbShiftLastNonZeroRef.current
            : PRESETS.cinematic.rgbShift;
        dispatch({ type: "SET_PARAM", key: "rgbShift", value: nextRgbShift });
      } else {
        if (params.rgbShift > 0) {
          rgbShiftLastNonZeroRef.current = params.rgbShift;
        }
        dispatch({ type: "SET_PARAM", key: "rgbShift", value: 0 });
      }
      dispatch({ type: "COMMIT" });
      setActivePreset("reset");
    },
    [params.rgbShift],
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
        if (deferSpaceKeyToVideoTransportWhenNoCompare && !state.compareMode) {
          return;
        }
        e.preventDefault();
        e.stopPropagation();
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
      if (deferSpaceKeyToVideoTransportWhenNoCompare && !state.compareMode) {
        return;
      }
      e.preventDefault();
      e.stopPropagation();
      dispatch({ type: "BEFORE_AFTER_OFF" });
    };

    document.addEventListener("keydown", handleKeyDown, { capture: true });
    document.addEventListener("keyup", handleKeyUp, { capture: true });
    return () => {
      document.removeEventListener("keydown", handleKeyDown, { capture: true });
      document.removeEventListener("keyup", handleKeyUp, { capture: true });
    };
  }, [applyPreset, onHistogramToggle, state.compareMode, deferSpaceKeyToVideoTransportWhenNoCompare]);

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
              <PanelControlSlider
                sliderLabelResetHint={sliderLabelResetHint}
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

        {/* === LUT — placed directly below presets (v0.5.0) === */}
        {isPro && !(slots.hideAuxPanels && slots.lpExpandButton) && (
          <div className="min-w-0">
            <LUTPanel viewport={viewport} onCubeLutLoaded={onLutLoadSuccess} onLutChange={onLutChange} />
            {slots.renderAfterLut ? slots.renderAfterLut(coreRenderContext) : slots.afterLut}
          </div>
        )}

        <div className="flex flex-col gap-4">

          {/* === PROCESS — film-process-first controls === */}
          {isPro && (
            <div className="min-w-0">
              <SectionHeader title={tFilmLab("controls.process")} />
              <div className="flex flex-col gap-2.5">
                {/* v0.5.0: Compression (ハイライトの柔らかさ) + printContrast (仕上げのコントラスト) hidden — rarely used */}
                <PanelControlSlider
                  sliderLabelResetHint={sliderLabelResetHint}
                  label={tFilmLab("controls.cyan")}
                  labelClassName={processSliderLabelClassName}
                  value={params.cyan}
                  min={-1} max={1} step={0.01} defaultValue={0}
                  onChange={(v) => updateParam("cyan", v)}
                  onCommit={commit}
                />
                <PanelControlSlider
                  sliderLabelResetHint={sliderLabelResetHint}
                  label={tFilmLab("controls.magenta")}
                  labelClassName={processSliderLabelClassName}
                  value={params.magenta}
                  min={-1} max={1} step={0.01} defaultValue={0}
                  onChange={(v) => updateParam("magenta", v)}
                  onCommit={commit}
                />
                <PanelControlSlider
                  sliderLabelResetHint={sliderLabelResetHint}
                  label={tFilmLab("controls.yellow")}
                  labelClassName={processSliderLabelClassName}
                  value={params.yellow}
                  min={-1} max={1} step={0.01} defaultValue={0}
                  onChange={(v) => updateParam("yellow", v)}
                  onCommit={commit}
                />
              </div>
            </div>
          )}

          {/* === FINISH TOOLS (replaces former Artifacts block) — Pro only === */}
          {isPro && (
            <div className="min-w-0">
              <CollapsibleHeader
                title={tFilmLab("controls.finishTools")}
                titleHint={tFilmLab("controls.finishToolsSectionHint")}
                open={artifactsOpen}
                onToggle={() => setArtifactsOpen(!artifactsOpen)}
              />
              {artifactsOpen && (
                <div className="mt-2 flex flex-col gap-3">
                  {tFilmLab("controls.finishToolsSectionHint") ? (
                    <p className="text-[10px] leading-snug text-white/50">
                      {tFilmLab("controls.finishToolsSectionHint")}
                    </p>
                  ) : null}

                  <FinishToolFamilyCard
                    first
                    title={tFilmLab("controls.finishToolsMist")}
                  >
                    <PanelControlSlider
                      sliderLabelResetHint={sliderLabelResetHint}
                      label={tFilmLab("controls.diffusion")}
                      value={params.diffusion}
                      min={0}
                      max={1}
                      step={0.01}
                      defaultValue={0}
                      onChange={(v) => updateParam("diffusion", v)}
                      onCommit={commit}
                    />
                  </FinishToolFamilyCard>

                  <FinishToolFamilyCard
                    title={tFilmLab("controls.finishToolsGlow")}
                    headerAccessory={(
                      <StarterStateButtonRow
                        states={GLOW_STARTER_STATES}
                        params={params}
                        onApply={applyGlowStarterState}
                        tFilmLab={tFilmLab}
                      />
                    )}
                  >
                    <ToggleHeader
                      title={tFilmLab("controls.bloom")}
                      titleHint={tFilmLab("controls.bloomToggleHint")}
                      enabled={bloomEnabled}
                      onToggle={toggleBloom}
                    />
                    <div className={`flex flex-col gap-2.5 ${!bloomEnabled ? "pointer-events-none opacity-30" : ""}`}>
                      <PanelControlSlider
                        sliderLabelResetHint={sliderLabelResetHint}
                        label={tFilmLab("controls.strength")}
                        value={params.bloomStrength}
                        min={0}
                        max={3}
                        step={0.01}
                        defaultValue={0}
                        onChange={(v) => updateParam("bloomStrength", v)}
                        onCommit={commit}
                      />
                    </div>
                    <button
                      type="button"
                      onClick={() => setGlowAdvancedOpen(!glowAdvancedOpen)}
                      className="mt-3 rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2 text-[10px] font-medium tracking-[0.08em] text-white/68 transition-colors hover:bg-white/[0.06] hover:text-white/84"
                    >
                      {glowAdvancedOpen
                        ? tFilmLab("controls.finishToolsAdvancedHide")
                        : tFilmLab("controls.finishToolsAdvancedShow")}
                    </button>

                    {glowAdvancedOpen ? (
                      <div className="mt-3 flex flex-col gap-2.5 border-t border-white/[0.08] pt-3">
                        <div className={`flex flex-col gap-2.5 ${!bloomEnabled ? "pointer-events-none opacity-30" : ""}`}>
                          <PanelControlSlider
                            sliderLabelResetHint={sliderLabelResetHint}
                            label={tFilmLab("controls.threshold")}
                            hint={tFilmLab("controls.bloomThresholdHint")}
                            value={params.bloomThreshold}
                            min={0}
                            max={1}
                            step={0.01}
                            defaultValue={0.8}
                            onChange={(v) => updateParam("bloomThreshold", v)}
                            onCommit={commit}
                          />
                          <PanelControlSlider
                            sliderLabelResetHint={sliderLabelResetHint}
                            label={tFilmLab("controls.radius")}
                            value={params.bloomRadius}
                            min={0}
                            max={1}
                            step={0.01}
                            defaultValue={0.4}
                            onChange={(v) => updateParam("bloomRadius", v)}
                            onCommit={commit}
                          />
                        </div>

                        <ToggleHeader
                          title={tFilmLab("controls.halation")}
                          titleHint={tFilmLab("controls.halationToggleHint")}
                          enabled={halationEnabled}
                          onToggle={toggleHalation}
                        />
                        <div className={`flex flex-col gap-2.5 ${!halationEnabled ? "pointer-events-none opacity-30" : ""}`}>
                          <PanelControlSlider
                            sliderLabelResetHint={sliderLabelResetHint}
                            label={tFilmLab("controls.intensity")}
                            value={params.halationIntensity}
                            min={0}
                            max={1}
                            step={0.01}
                            defaultValue={0}
                            onChange={(v) => updateParam("halationIntensity", v)}
                            onCommit={commit}
                          />
                          <PanelControlSlider
                            sliderLabelResetHint={sliderLabelResetHint}
                            label={tFilmLab("controls.spread")}
                            value={params.halationSpread}
                            min={0}
                            max={50}
                            step={0.5}
                            defaultValue={15}
                            onChange={(v) => updateParam("halationSpread", v)}
                            onCommit={commit}
                          />
                          <HueSlider
                            label={tFilmLab("controls.halationHue")}
                            value={params.halationHue}
                            onChange={updateHalationHue}
                            onCommit={commit}
                          />
                        </div>
                      </div>
                    ) : null}
                  </FinishToolFamilyCard>

                  <FinishToolFamilyCard
                    title={tFilmLab("controls.finishToolsCross")}
                    headerAccessory={(
                      <StarterStateButtonRow
                        states={CROSS_STARTER_STATES}
                        params={params}
                        onApply={applyCrossStarterState}
                        tFilmLab={tFilmLab}
                      />
                    )}
                  >
                    <ToggleHeader
                      title={tFilmLab("controls.crossFilter")}
                      titleHint={tFilmLab("controls.crossFilterToggleHint")}
                      enabled={crossFilterEnabled}
                      onToggle={toggleCrossFilter}
                    />
                    <div className={`flex flex-col gap-2.5 ${!crossFilterEnabled ? "pointer-events-none opacity-30" : ""}`}>
                      <PanelControlSlider
                        sliderLabelResetHint={sliderLabelResetHint}
                        label={tFilmLab("controls.crossFilterStrengthLabel")}
                        value={params.crossFilterStrength}
                        min={0}
                        max={1}
                        step={0.01}
                        defaultValue={0}
                        onChange={(v) => updateParam("crossFilterStrength", v)}
                        onCommit={commit}
                      />
                      <div className="flex items-start gap-3 lg:pr-4">
                        <div className="min-w-[7.5rem] shrink-0 text-[11px] leading-tight text-[var(--text-muted)] whitespace-nowrap sm:min-w-[8.5rem]">
                          <div>{tFilmLab("controls.crossFilterSpikes")}</div>
                          <div className="mt-1 whitespace-normal text-[10px] leading-snug text-white/42">
                            {tFilmLab("controls.crossFilterSpikesHint")}
                          </div>
                        </div>
                        <div className="flex-1">
                          <SegmentedControl<"4" | "6" | "8">
                            options={[
                              { value: "4", label: "4" },
                              { value: "6", label: "6" },
                              { value: "8", label: "8" },
                            ]}
                            value={String(params.crossFilterSpikes) as "4" | "6" | "8"}
                            onChange={(value) => {
                              updateParam("crossFilterSpikes", Number(value));
                              commit();
                            }}
                            ariaLabel={tFilmLab("controls.crossFilterSpikes")}
                          />
                        </div>
                      </div>
                      <PanelControlSlider
                        sliderLabelResetHint={sliderLabelResetHint}
                        label={tFilmLab("controls.crossFilterAngle")}
                        hint={tFilmLab("controls.crossFilterAngleHint")}
                        value={params.crossFilterAngle}
                        min={0}
                        max={360}
                        step={1}
                        defaultValue={0}
                        onChange={(v) => updateParam("crossFilterAngle", v)}
                        onCommit={commit}
                        formatValue={(v) => `${Math.round(v)}°`}
                      />
                      <PanelControlSlider
                        sliderLabelResetHint={sliderLabelResetHint}
                        label={tFilmLab("controls.crossFilterLength")}
                        hint={tFilmLab("controls.crossFilterLengthHint")}
                        value={params.crossFilterLength}
                        min={0}
                        max={1}
                        step={0.01}
                        defaultValue={0.5}
                        onChange={(v) => updateParam("crossFilterLength", v)}
                        onCommit={commit}
                      />
                    </div>

                    <button
                      type="button"
                      onClick={() => setCrossAdvancedOpen(!crossAdvancedOpen)}
                      className="mt-3 rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2 text-[10px] font-medium tracking-[0.08em] text-white/68 transition-colors hover:bg-white/[0.06] hover:text-white/84"
                    >
                      {crossAdvancedOpen
                        ? tFilmLab("controls.finishToolsAdvancedHide")
                        : tFilmLab("controls.finishToolsAdvancedShow")}
                    </button>

                    {crossAdvancedOpen ? (
                      <div className={`mt-3 flex flex-col gap-2.5 border-t border-white/[0.08] pt-3 ${!crossFilterEnabled ? "pointer-events-none opacity-30" : ""}`}>
                        <div className="rounded-lg border border-white/8 bg-white/[0.03] px-3 py-2 text-[11px] leading-relaxed text-white/66">
                          {tFilmLab("controls.crossFilterSoftModeFrozenHint")}
                        </div>
                        <PanelControlSlider
                          sliderLabelResetHint={sliderLabelResetHint}
                          label={tFilmLab("controls.crossFilterChromatic")}
                          hint={tFilmLab("controls.crossFilterChromaticHint")}
                          value={params.crossFilterChromatic}
                          min={0}
                          max={1}
                          step={0.01}
                          defaultValue={0.3}
                          onChange={(v) => updateParam("crossFilterChromatic", v)}
                          onCommit={commit}
                        />
                        <PanelControlSlider
                          sliderLabelResetHint={sliderLabelResetHint}
                          label={tFilmLab("controls.crossFilterMinSpacing")}
                          hint={tFilmLab("controls.crossFilterMinSpacingHint")}
                          value={params.crossFilterMinSpacing}
                          min={0}
                          max={1}
                          step={0.01}
                          defaultValue={0}
                          onChange={(v) => updateParam("crossFilterMinSpacing", v)}
                          onCommit={commit}
                        />
                      </div>
                    ) : null}
                  </FinishToolFamilyCard>

                  <FinishToolFamilyCard
                    title={tFilmLab("controls.finishToolsTexture")}
                  >
                    <PanelControlSlider
                      sliderLabelResetHint={sliderLabelResetHint}
                      label={tFilmLab("controls.filmGrain")}
                      value={params.grainIntensity}
                      min={0}
                      max={0.5}
                      step={0.01}
                      defaultValue={0}
                      onChange={(v) => updateParam("grainIntensity", v)}
                      onCommit={commit}
                    />
                    <PanelControlSlider
                      sliderLabelResetHint={sliderLabelResetHint}
                      label={tFilmLab("controls.grainSize")}
                      value={params.grainSize}
                      min={0}
                      max={1}
                      step={0.01}
                      defaultValue={0.3}
                      onChange={(v) => updateParam("grainSize", v)}
                      onCommit={commit}
                    />
                    <PanelControlSlider
                      sliderLabelResetHint={sliderLabelResetHint}
                      label={tFilmLab("controls.vignette")}
                      value={params.vignette}
                      min={0}
                      max={1}
                      step={0.01}
                      defaultValue={0}
                      onChange={(v) => updateParam("vignette", v)}
                      onCommit={commit}
                    />
                    <PanelControlSlider
                      sliderLabelResetHint={sliderLabelResetHint}
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
                  </FinishToolFamilyCard>

                  <FinishToolFamilyCard
                    title={tFilmLab("controls.finishToolsLens")}
                  >
                    <ToggleHeader
                      title={tFilmLab("controls.rgbShift")}
                      titleHint={tFilmLab("controls.rgbShiftToggleHint")}
                      enabled={rgbShiftEnabled}
                      onToggle={toggleRgbShift}
                    />
                    <div className={`flex flex-col gap-2.5 ${!rgbShiftEnabled ? "pointer-events-none opacity-30" : ""}`}>
                      <PanelControlSlider
                        sliderLabelResetHint={sliderLabelResetHint}
                        label={tFilmLab("controls.strength")}
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
                    </div>
                    <PanelControlSlider
                      sliderLabelResetHint={sliderLabelResetHint}
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
                  </FinishToolFamilyCard>

                  <FinishToolFamilyCard
                    title={tFilmLab("controls.finishToolsMotion")}
                  >
                    <PanelControlSlider
                      sliderLabelResetHint={sliderLabelResetHint}
                      label={tFilmLab("controls.shutterAngle")}
                      hint={tFilmLab("controls.shutterAngleHint")}
                      value={params.shutterAngle}
                      min={0}
                      max={720}
                      step={10}
                      defaultValue={0}
                      onChange={(v) => updateParam("shutterAngle", v < 90 ? 0 : Math.max(180, v))}
                      onCommit={commit}
                    />
                    <PanelControlSlider
                      sliderLabelResetHint={sliderLabelResetHint}
                      label={tFilmLab("controls.trailIntensity")}
                      hint={tFilmLab("controls.trailIntensityHint")}
                      value={params.trailIntensity}
                      min={0}
                      max={0.95}
                      step={0.05}
                      defaultValue={0}
                      onChange={(v) => updateParam("trailIntensity", v)}
                      onCommit={commit}
                    />
                  </FinishToolFamilyCard>
                </div>
              )}
            </div>
          )}

          {/* === SOURCE TRIM — Pro only, collapsed by default === */}
          {isPro && (
            <div className="min-w-0">
              <CollapsibleHeader
                title={tFilmLab("controls.sourceTrim")}
                titleHint={tFilmLab("controls.sourceTrimSectionHint")}
                open={sourceTrimOpen}
                onToggle={() => setSourceTrimOpen(!sourceTrimOpen)}
              />
              {sourceTrimOpen && (
                <div className="flex flex-col gap-2.5">
                  <PanelControlSlider sliderLabelResetHint={sliderLabelResetHint} label={tFilmLab("controls.exposure")} value={params.exposure} min={-3} max={3} step={0.01} defaultValue={0} onChange={(v) => updateParam("exposure", v)} onCommit={commit} />
                  <PanelControlSlider sliderLabelResetHint={sliderLabelResetHint} label={tFilmLab("controls.sourceTemp")} value={params.temperature} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("temperature", v)} onCommit={commit} />
                  <PanelControlSlider sliderLabelResetHint={sliderLabelResetHint} label={tFilmLab("controls.sourceTint")} value={params.tint} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("tint", v)} onCommit={commit} />
                  <PanelControlSlider sliderLabelResetHint={sliderLabelResetHint} label={tFilmLab("controls.highlightsTrim")} value={params.highlights} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("highlights", v)} onCommit={commit} />
                  <PanelControlSlider sliderLabelResetHint={sliderLabelResetHint} label={tFilmLab("controls.shadowsTrim")} value={params.shadows} min={-1} max={1} step={0.01} defaultValue={0} onChange={(v) => updateParam("shadows", v)} onCommit={commit} />
                </div>
              )}
            </div>
          )}

          {/* === Quick mode: LUT + exposure / LP expand button === */}
          {!isPro && (
            slots.hideAuxPanels && slots.lpExpandButton ? (
              <div className="min-w-0">
                {slots.lpExpandButton}
              </div>
            ) : (
              <div className="min-w-0">
                <LUTPanel viewport={viewport} onCubeLutLoaded={onLutLoadSuccess} onLutChange={onLutChange} />
                {slots.renderAfterLut ? slots.renderAfterLut(coreRenderContext) : slots.afterLut}
                <div className="mt-3">
                  <PanelControlSlider
                    sliderLabelResetHint={sliderLabelResetHint}
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
              </div>
            )
          )}

          {/* === Pro mode: LP expand button (when hideAuxPanels) === */}
          {isPro && slots.hideAuxPanels && slots.lpExpandButton && (
            <div className="min-w-0">
              {slots.lpExpandButton}
            </div>
          )}

          <div className="min-w-0">
            {/* Compare section — Pro のみ、折りたたみ式（デフォルト閉じ） */}
            {isPro ? (
            <div className="min-w-0">
              <CollapsibleHeader
                title={tFilmLab("compare.sectionTitle")}
                open={compareOpen}
                onToggle={() => setCompareOpen(!compareOpen)}
              />
              {compareOpen && (
                <div className="flex flex-col gap-2.5">
                  <button
                    type="button"
                    onPointerDown={handleBeforeAfterPointerDown}
                    onPointerUp={handleBeforeAfterPointerEnd}
                    onPointerCancel={handleBeforeAfterPointerEnd}
                    onLostPointerCapture={handleBeforeAfterLostCapture}
                    className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2.5 text-left text-[11px] text-white/65 transition-colors hover:bg-white/8 hover:text-white/80 active:bg-white/12"
                  >
                    <span className="font-medium text-white/85">{tFilmLab("compare.holdTitle")}</span>
                    <span className="mt-0.5 block text-[10px] text-white/52">{tFilmLab("compare.holdHint")}</span>
                  </button>

                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[11px] font-medium text-white/85">
                      {tFilmLab("compare.title")}
                    </span>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={state.compareMode}
                      onClick={() =>
                        dispatch({ type: state.compareMode ? "COMPARE_OFF" : "COMPARE_ON" })
                      }
                      className={`h-4 w-7 shrink-0 rounded-full transition-colors ${
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
                  {state.compareMode ? (
                    <div className="flex flex-col gap-1.5 sm:flex-row sm:items-center sm:justify-between">
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
              )}
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
        </div>
      </div>
      <ShortcutHelp open={showHelp} onClose={() => setShowHelp(false)} />
    </>
  );
});

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
  titleHint,
  open,
  onToggle,
}: {
  title: string;
  /** 折りたたみ見出しホバー時の補足（ネイティブ `title`） */
  titleHint?: string;
  open: boolean;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      title={titleHint}
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

function FinishToolFamilyCard({
  title,
  first = false,
  headerAccessory,
  children,
}: {
  title: string;
  first?: boolean;
  headerAccessory?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className={first ? "" : "border-t border-white/[0.08] pt-4"}>
      <div className="mb-2 flex items-center justify-between gap-3">
        <h3 className="text-[11px] font-semibold uppercase tracking-[0.18em] text-white/82">
          {title}
        </h3>
        {headerAccessory ? (
          <div className="shrink-0">
            {headerAccessory}
          </div>
        ) : null}
      </div>

      <div>
        {children}
      </div>
    </section>
  );
}

function StarterStateButtonRow({
  states,
  params,
  onApply,
  tFilmLab,
}: {
  states: readonly FinishToolStarterState[];
  params: Params;
  onApply: (patch: Partial<Params>) => void;
  tFilmLab: ReturnType<typeof useTranslations>;
}) {
  return (
    <div className="flex flex-wrap justify-end gap-2">
        {states.map((state) => {
          const active = (Object.keys(state.patch) as Array<keyof Params>).every(
            (key) => params[key] === state.patch[key],
          );
          return (
            <button
              key={state.id}
              type="button"
              onClick={() => onApply(state.patch)}
              className={[
                "rounded-full border px-2.5 py-1 text-[10px] font-medium tracking-[0.08em] transition-colors",
                active
                  ? "border-[var(--accent-amber1)]/45 bg-[var(--accent-amber1)]/12 text-[var(--accent-amber1)]"
                  : "border-white/[0.1] bg-white/[0.03] text-white/72 hover:bg-white/[0.06] hover:text-white/88",
              ].join(" ")}
            >
              {tFilmLab(state.labelKey)}
            </button>
          );
        })}
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
    <div className="flex min-h-[44px] min-w-0 items-center gap-3 sm:min-h-0 lg:pr-4">
      <span className="w-16 shrink-0 text-[11px] text-white/50 sm:w-24">{label}</span>
      <div className="relative min-w-0 flex-1">
        <input
          type="range"
          min={0}
          max={100}
          step={1}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          onPointerUp={() => onCommit?.()}
          onTouchEnd={() => onCommit?.()}
          className="halation-hue-slider h-1.5 min-w-0 w-full cursor-pointer appearance-none rounded-full touch-none sm:h-1"
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
