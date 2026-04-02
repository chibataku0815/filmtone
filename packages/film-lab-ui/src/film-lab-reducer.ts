import { PRESETS, type PresetName, PARAM_KEYS, cloneParams, type Params } from "film-lab-core";

export type SlotId = "A" | "B";

export interface GradeSlotState {
  params: Params;
  basePreset: PresetName | null;
  intensity: number;
}

/** 永続化・A/B 比較に使う「いまの盤面」（履歴とは別） */
export interface PresentState {
  slotA: GradeSlotState;
  slotB: GradeSlotState;
  compareMode: boolean;
  activeSlot: SlotId;
}

export interface State extends PresentState {
  history: PresentState[];
  historyIndex: number;
  beforeAfterStash: PresentState | null;
}

export type Action =
  | { type: "SET_PARAM"; key: keyof Params; value: number; preserveBasePreset?: boolean }
  /**
   * Quick モードのメタスライダー用: 指定キーだけをまとめて上書きし、履歴には COMMIT の 1 回だけ載せる。
   * basePreset は手動編集と同様に外れる。
   */
  | { type: "MERGE_PARAMS"; patch: Partial<Params> }
  | { type: "SET_INTENSITY"; value: number }
  | { type: "COMMIT" }
  | { type: "APPLY_PRESET"; presetName: PresetName; preset: Params }
  | { type: "APPLY_PARAMS"; params: Params; basePreset: PresetName | null; intensity?: number }
  | { type: "UNDO" }
  | { type: "REDO" }
  | { type: "COMPARE_ON" }
  | { type: "COMPARE_OFF" }
  | { type: "TOGGLE_COMPARE" }
  | { type: "SWITCH_SLOT"; slot?: SlotId }
  | { type: "BEFORE_AFTER_ON" }
  | { type: "BEFORE_AFTER_OFF" }
  /** localStorage などから復元した盤面を丸ごと適用（Undo 履歴は 1 スナップショットにリセット） */
  | { type: "RESTORE_PRESENT"; present: PresentState };

const MAX_HISTORY = 30;

/**
 * 0.4.0 で追加した render process の数値キー。
 *
 * @remarks
 * 既存の `Params` に無いキーでも、UI の state には runtime で持たせる。
 */
export const PROCESS_PARAM_DEFAULTS = {
  compressionAmount: 0,
  compressionRange: 0.5,
  printContrast: 0,
  cyan: 0,
  magenta: 0,
  yellow: 0,
} as const;

export type ProcessParamKey = keyof typeof PROCESS_PARAM_DEFAULTS;

export type ProcessParams = Record<ProcessParamKey, number>;

export const PROCESS_PARAM_KEYS = Object.keys(
  PROCESS_PARAM_DEFAULTS,
) as ProcessParamKey[];

/**
 * 古い保存データや preset に、process の既定値を補う。
 *
 * @param params - 現在のグレード数値
 */
export function normalizeParamsWithProcessDefaults(
  params: Params,
): Params & ProcessParams {
  const raw = params as unknown as Record<string, number | undefined>;
  return {
    ...params,
    compressionAmount:
      typeof raw.compressionAmount === "number"
        ? raw.compressionAmount
        : PROCESS_PARAM_DEFAULTS.compressionAmount,
    compressionRange:
      typeof raw.compressionRange === "number"
        ? raw.compressionRange
        : PROCESS_PARAM_DEFAULTS.compressionRange,
    printContrast:
      typeof raw.printContrast === "number"
        ? raw.printContrast
        : PROCESS_PARAM_DEFAULTS.printContrast,
    cyan:
      typeof raw.cyan === "number"
        ? raw.cyan
        : PROCESS_PARAM_DEFAULTS.cyan,
    magenta:
      typeof raw.magenta === "number"
        ? raw.magenta
        : PROCESS_PARAM_DEFAULTS.magenta,
    yellow:
      typeof raw.yellow === "number"
        ? raw.yellow
        : PROCESS_PARAM_DEFAULTS.yellow,
  };
}

function cloneSlot(slot: GradeSlotState): GradeSlotState {
  return {
    params: normalizeParamsWithProcessDefaults(cloneParams(slot.params)),
    basePreset: slot.basePreset,
    intensity: slot.intensity,
  };
}

function snapshot(state: PresentState): PresentState {
  return {
    slotA: cloneSlot(state.slotA),
    slotB: cloneSlot(state.slotB),
    compareMode: state.compareMode,
    activeSlot: state.activeSlot,
  };
}

function activeSlotKey(activeSlot: SlotId): "slotA" | "slotB" {
  return activeSlot === "A" ? "slotA" : "slotB";
}

function withActiveSlot(
  state: State,
  update: (slot: GradeSlotState) => GradeSlotState,
): State {
  const key = activeSlotKey(state.activeSlot);
  return {
    ...state,
    [key]: update(state[key]),
  };
}

function pushHistory(state: State): State {
  const nextHistory = [
    ...state.history.slice(0, state.historyIndex + 1),
    snapshot(state),
  ].slice(-MAX_HISTORY);

  return {
    ...state,
    history: nextHistory,
    historyIndex: nextHistory.length - 1,
  };
}

function interpolatePreset(presetName: PresetName, intensity: number): Params {
  const clamped = Math.max(0, Math.min(1, intensity));
  const params = normalizeParamsWithProcessDefaults(PRESETS.reset);
  const preset = PRESETS[presetName];

  for (const key of PARAM_KEYS) {
    params[key] = PRESETS.reset[key] + (preset[key] - PRESETS.reset[key]) * clamped;
  }

  return params;
}

function slotsMatch(slotA: GradeSlotState, slotB: GradeSlotState): boolean {
  const slotAProcess = slotA.params as unknown as Record<ProcessParamKey, number>;
  const slotBProcess = slotB.params as unknown as Record<ProcessParamKey, number>;
  return (
    slotA.basePreset === slotB.basePreset &&
    slotA.intensity === slotB.intensity &&
    PARAM_KEYS.every((key) => slotA.params[key] === slotB.params[key]) &&
    PROCESS_PARAM_KEYS.every((key) => slotAProcess[key] === slotBProcess[key])
  );
}

function restoreSnapshot(state: State, nextPresent: PresentState): State {
  return {
    ...state,
    slotA: cloneSlot(nextPresent.slotA),
    slotB: cloneSlot(nextPresent.slotB),
    compareMode: nextPresent.compareMode,
    activeSlot: nextPresent.activeSlot,
  };
}

export function filmLabReducer(state: State, action: Action): State {
  switch (action.type) {
    case "SET_PARAM": {
      return withActiveSlot(state, (slot) => ({
        ...slot,
        params: { ...slot.params, [action.key]: action.value },
        basePreset: action.preserveBasePreset ? slot.basePreset : null,
        intensity: action.preserveBasePreset ? slot.intensity : 1,
      }));
    }

    case "MERGE_PARAMS": {
      return withActiveSlot(state, (slot) => ({
        ...slot,
        params: { ...slot.params, ...action.patch },
        basePreset: null,
        intensity: 1,
      }));
    }

    case "SET_INTENSITY": {
      return withActiveSlot(state, (slot) => {
        if (!slot.basePreset || slot.basePreset === "reset") return slot;
        const nextIntensity = Math.max(0, Math.min(1, action.value));
        return {
          ...slot,
          params: interpolatePreset(slot.basePreset, nextIntensity),
          intensity: nextIntensity,
        };
      });
    }

    case "COMMIT":
      return pushHistory(state);

    case "APPLY_PRESET": {
      const next = withActiveSlot(state, () => ({
        params: normalizeParamsWithProcessDefaults(cloneParams(action.preset)),
        basePreset: action.presetName,
        intensity: 1,
      }));
      return pushHistory(next);
    }

    case "APPLY_PARAMS": {
      const next = withActiveSlot(state, () => ({
        params: normalizeParamsWithProcessDefaults(cloneParams(action.params)),
        basePreset: action.basePreset,
        intensity: action.intensity ?? 1,
      }));
      return pushHistory(next);
    }

    case "UNDO": {
      if (state.historyIndex <= 0) return state;
      const nextIndex = state.historyIndex - 1;
      return restoreSnapshot(
        {
          ...state,
          historyIndex: nextIndex,
        },
        state.history[nextIndex],
      );
    }

    case "REDO": {
      if (state.historyIndex >= state.history.length - 1) return state;
      const nextIndex = state.historyIndex + 1;
      return restoreSnapshot(
        {
          ...state,
          historyIndex: nextIndex,
        },
        state.history[nextIndex],
      );
    }

    case "COMPARE_ON":
      return {
        ...state,
        compareMode: true,
        activeSlot: slotsMatch(state.slotA, state.slotB) ? "B" : state.activeSlot,
      };

    case "COMPARE_OFF":
      return {
        ...state,
        compareMode: false,
      };

    case "TOGGLE_COMPARE":
      return state.compareMode
        ? filmLabReducer(state, { type: "COMPARE_OFF" })
        : filmLabReducer(state, { type: "COMPARE_ON" });

    case "SWITCH_SLOT":
      return {
        ...state,
        activeSlot:
          action.slot ??
          (state.activeSlot === "A" ? "B" : "A"),
      };

    case "BEFORE_AFTER_ON": {
      if (state.beforeAfterStash) return state;

      const key = activeSlotKey(state.activeSlot);
      const resetSlot: GradeSlotState = {
        params: normalizeParamsWithProcessDefaults(cloneParams(PRESETS.reset)),
        basePreset: "reset",
        intensity: 1,
      };

      return {
        ...state,
        beforeAfterStash: snapshot(state),
        compareMode: false,
        [key]: resetSlot,
      };
    }

    case "BEFORE_AFTER_OFF":
      if (!state.beforeAfterStash) return state;
      return {
        ...restoreSnapshot(state, state.beforeAfterStash),
        beforeAfterStash: null,
      };

    case "RESTORE_PRESENT": {
      const present = action.present;
      const next: PresentState = {
        slotA: cloneSlot(present.slotA),
        slotB: cloneSlot(present.slotB),
        compareMode: present.compareMode,
        activeSlot: present.activeSlot,
      };
      return {
        ...next,
        history: [snapshot(next)],
        historyIndex: 0,
        beforeAfterStash: null,
      };
    }

    default:
      return state;
  }
}

/**
 * ブラウザ保存用に、履歴を除いた現在の盤面だけを複製する。
 * @param state - reducer の State
 */
export function toPresentSnapshot(state: State): PresentState {
  return snapshot(state);
}

/**
 * URL 共有など「数値パラメータのスナップショット」から初期化する（basePreset は無し＝手動ルック扱い）。
 */
export function createInitialStateFromSharedParams(shared: Params): State {
  const slot: GradeSlotState = {
    params: normalizeParamsWithProcessDefaults(cloneParams(shared)),
    basePreset: null,
    intensity: 1,
  };

  const present: PresentState = {
    slotA: cloneSlot(slot),
    slotB: cloneSlot(slot),
    compareMode: false,
    activeSlot: "A",
  };

  return {
    ...present,
    history: [snapshot(present)],
    historyIndex: 0,
    beforeAfterStash: null,
  };
}

export function createInitialState(
  initialParams: Params,
  initialPresetName: PresetName | null = null,
): State {
  const slot: GradeSlotState = {
    params: normalizeParamsWithProcessDefaults(cloneParams(initialParams)),
    basePreset: initialPresetName,
    intensity: 1,
  };

  const present: PresentState = {
    slotA: cloneSlot(slot),
    slotB: cloneSlot(slot),
    compareMode: false,
    activeSlot: "A",
  };

  return {
    ...present,
    history: [snapshot(present)],
    historyIndex: 0,
    beforeAfterStash: null,
  };
}
