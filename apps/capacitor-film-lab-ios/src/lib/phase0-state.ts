import {
  applyQuickStateToPhase0Params,
  buildPhase0ExportRequest,
  createPhase0ProjectState,
  interpolatePhase0PresetParams,
  mergePhase0Params,
  PHASE0_PRESET_STRENGTH_DEFAULT,
  type ParsedCubeLut,
  type Phase0ExportRequest,
  type Phase0ExportResult,
  type Phase0ExportProgress,
  type Phase0Params,
  type Phase0PreviewRenderResult,
  type Phase0ProjectState,
  type Phase0RenderMode,
  type PresetName,
  type QuickState,
  type SourceInfo,
  type SourceProbe,
} from "film-lab-core";

/**
 * v1.3 Stream A — UI render mode is tracked separately from the persisted
 * Phase0ProjectState because the wire-level enum ("quality" | "speed") is the
 * v1.2 native gate contract; the new "Master / Postcard" naming is UI-only.
 *
 * Default is "quality" (Master) — matches the native runtime default of
 * `request.renderMode ?? .quality` in FilmtoneMediaRuntime / FilmtoneExportSession.
 */
export const PHASE0_RENDER_MODE_DEFAULT: Phase0RenderMode = "quality";

export interface Phase0EditorState {
  project: Phase0ProjectState;
  source: SourceInfo | null;
  probe: SourceProbe | null;
  preview: {
    originalPosterUri: string | null;
    gradedPosterUri: string | null;
    width: number | null;
    height: number | null;
    posterTimeSec: number | null;
    isRendering: boolean;
    error: string | null;
  };
  isCompareHeld: boolean;
  exportProgress: Phase0ExportProgress | null;
  exportResult: Phase0ExportResult | null;
  saveToPhotosState: "not-run" | "saved" | "failed";
  isBusy: boolean;
  notice: string | null;
  error: string | null;
  /**
   * v1.3 Stream A — wire-level enum, persisted only in editor session memory.
   * UI surfaces this as "Master" ("quality") / "Postcard" ("speed").
   */
  renderMode: Phase0RenderMode;
}

function createEmptyPreviewState(): Phase0EditorState["preview"] {
  return {
    originalPosterUri: null,
    gradedPosterUri: null,
    width: null,
    height: null,
    posterTimeSec: null,
    isRendering: false,
    error: null,
  };
}

function deriveProjectParams(project: Pick<Phase0ProjectState, "presetName" | "strength" | "quickState">): Phase0Params {
  const presetName = project.presetName as PresetName;
  const base = interpolatePhase0PresetParams(presetName, project.strength);
  return applyQuickStateToPhase0Params(base, project.quickState);
}

export function createInitialEditorState(
  project?: Phase0ProjectState,
): Phase0EditorState {
  return {
    project: project ?? createPhase0ProjectState(),
    source: null,
    probe: null,
    preview: createEmptyPreviewState(),
    isCompareHeld: false,
    exportProgress: null,
    exportResult: null,
    saveToPhotosState: "not-run",
    isBusy: false,
    notice: null,
    error: null,
    renderMode: PHASE0_RENDER_MODE_DEFAULT,
  };
}

/**
 * v1.3 Stream A — UI render-mode reducer.
 * Wire-level enum stays "quality" | "speed" (v1.2 native gate contract).
 * UI label mapping: "quality" -> "Master", "speed" -> "Postcard".
 */
export function applyRenderMode(
  state: Phase0EditorState,
  mode: Phase0RenderMode,
): Phase0EditorState {
  if (state.renderMode === mode) {
    return state;
  }
  return {
    ...state,
    renderMode: mode,
  };
}

export function applyPresetSelection(
  state: Phase0EditorState,
  presetName: PresetName,
): Phase0EditorState {
  const quickState = {
    filmCharacter: 0,
    era: 0,
    dynamics: 0,
  } as const;
  const strength = PHASE0_PRESET_STRENGTH_DEFAULT;
  return {
    ...state,
    project: {
      ...state.project,
      presetName,
      strength,
      quickState,
      params: deriveProjectParams({
        presetName,
        strength,
        quickState,
      }),
      updatedAt: new Date().toISOString(),
    },
  };
}

export function applyQuickState(
  state: Phase0EditorState,
  quickState: QuickState,
): Phase0EditorState {
  return {
    ...state,
    project: {
      ...state.project,
      quickState,
      params: deriveProjectParams({
        presetName: state.project.presetName,
        strength: state.project.strength,
        quickState,
      }),
      updatedAt: new Date().toISOString(),
    },
  };
}

export function applyInputLutSelection(
  state: Phase0EditorState,
  lut: ParsedCubeLut | null,
): Phase0EditorState {
  return {
    ...state,
    project: {
      ...state.project,
      inputLut: lut,
      updatedAt: new Date().toISOString(),
    },
  };
}

export function applyCreativeLutSelection(
  state: Phase0EditorState,
  lut: ParsedCubeLut | null,
): Phase0EditorState {
  return {
    ...state,
    project: {
      ...state.project,
      creativeLut: lut,
      updatedAt: new Date().toISOString(),
    },
  };
}

export function applyStrength(
  state: Phase0EditorState,
  strength: number,
): Phase0EditorState {
  const nextStrength = Math.max(0, Math.min(1, strength));
  return {
    ...state,
    project: {
      ...state.project,
      strength: nextStrength,
      params: deriveProjectParams({
        presetName: state.project.presetName,
        strength: nextStrength,
        quickState: state.project.quickState,
      }),
      updatedAt: new Date().toISOString(),
    },
  };
}

export function applyProbe(
  state: Phase0EditorState,
  source: SourceInfo,
  probe: SourceProbe,
): Phase0EditorState {
  return {
    ...state,
    source,
    probe,
    preview: createEmptyPreviewState(),
    isCompareHeld: false,
    saveToPhotosState: "not-run",
    error: null,
    notice: null,
    exportResult: null,
    exportProgress: null,
  };
}

export function buildEditorExportRequest(
  state: Phase0EditorState,
): Phase0ExportRequest | null {
  if (!state.source) {
    return null;
  }
  const request = buildPhase0ExportRequest({
    source: state.source,
    probe: state.probe,
    project: state.project,
  });
  // v1.3 Stream A — attach UI-selected render mode. Native runtime defaults
  // to .quality when the field is absent, so emitting "quality" is also a
  // safe explicit no-op against the v1.2 native gate.
  return {
    ...request,
    renderMode: state.renderMode,
  };
}

export function applyProjectPatch(
  state: Phase0EditorState,
  patch: Partial<Phase0Params>,
): Phase0EditorState {
  return {
    ...state,
    project: {
      ...state.project,
      params: mergePhase0Params(state.project.params, patch),
      updatedAt: new Date().toISOString(),
    },
  };
}

export function applyPreviewRenderStart(
  state: Phase0EditorState,
): Phase0EditorState {
  return {
    ...state,
    preview: {
      ...state.preview,
      isRendering: true,
      error: null,
    },
  };
}

export function applyPreviewRenderResult(
  state: Phase0EditorState,
  result: Phase0PreviewRenderResult,
): Phase0EditorState {
  return {
    ...state,
    preview: {
      originalPosterUri: result.originalUri,
      gradedPosterUri: result.gradedUri,
      width: result.width,
      height: result.height,
      posterTimeSec: result.posterTimeSec ?? null,
      isRendering: false,
      error: null,
    },
  };
}

export function applyPreviewRenderFailure(
  state: Phase0EditorState,
  error: string,
): Phase0EditorState {
  return {
    ...state,
    preview: {
      ...state.preview,
      isRendering: false,
      error,
    },
  };
}

export function applyCompareHeld(
  state: Phase0EditorState,
  isCompareHeld: boolean,
): Phase0EditorState {
  return {
    ...state,
    isCompareHeld,
  };
}
