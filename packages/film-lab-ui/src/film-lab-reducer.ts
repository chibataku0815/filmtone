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

function cloneSlot(slot: GradeSlotState): GradeSlotState {
  return {
    params: cloneParams(slot.params),
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
  const params = { ...PRESETS.reset };
  const preset = PRESETS[presetName];

  for (const key of PARAM_KEYS) {
    params[key] = PRESETS.reset[key] + (preset[key] - PRESETS.reset[key]) * clamped;
  }

  return params;
}

function slotsMatch(slotA: GradeSlotState, slotB: GradeSlotState): boolean {
  return (
    slotA.basePreset === slotB.basePreset &&
    slotA.intensity === slotB.intensity &&
    PARAM_KEYS.every((key) => slotA.params[key] === slotB.params[key])
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
        params: cloneParams(action.preset),
        basePreset: action.presetName,
        intensity: 1,
      }));
      return pushHistory(next);
    }

    case "APPLY_PARAMS": {
      const next = withActiveSlot(state, () => ({
        params: cloneParams(action.params),
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
        params: cloneParams(PRESETS.reset),
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
    params: cloneParams(shared),
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
    params: cloneParams(initialParams),
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
