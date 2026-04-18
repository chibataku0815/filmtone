import {
  applyQuickStateToPhase0Params,
  buildPhase0ExportRequest,
  createPhase0ProjectState,
  mergePhase0Params,
  pickPhase0Params,
  PRESETS,
  type ParsedCubeLut,
  type Phase0ExportRequest,
  type Phase0ExportResult,
  type Phase0ExportProgress,
  type Phase0Params,
  type Phase0ProjectState,
  type PresetName,
  type QuickState,
  type SourceInfo,
  type SourceProbe,
} from "film-lab-core";

export interface Phase0EditorState {
  project: Phase0ProjectState;
  source: SourceInfo | null;
  probe: SourceProbe | null;
  exportProgress: Phase0ExportProgress | null;
  exportResult: Phase0ExportResult | null;
  saveToPhotosState: "not-run" | "saved" | "failed";
  isBusy: boolean;
  notice: string | null;
  error: string | null;
}

export function createInitialEditorState(
  project?: Phase0ProjectState,
): Phase0EditorState {
  return {
    project: project ?? createPhase0ProjectState(),
    source: null,
    probe: null,
    exportProgress: null,
    exportResult: null,
    saveToPhotosState: "not-run",
    isBusy: false,
    notice: null,
    error: null,
  };
}

export function applyPresetSelection(
  state: Phase0EditorState,
  presetName: PresetName,
): Phase0EditorState {
  const base = pickPhase0Params(PRESETS[presetName]);
  return {
    ...state,
    project: {
      ...state.project,
      presetName,
      quickState: {
        filmCharacter: 0,
        era: 0,
        dynamics: 0,
      },
      params: base,
      updatedAt: new Date().toISOString(),
    },
  };
}

export function applyQuickState(
  state: Phase0EditorState,
  quickState: QuickState,
): Phase0EditorState {
  const presetName = state.project.presetName as PresetName;
  const base = pickPhase0Params(PRESETS[presetName]);
  return {
    ...state,
    project: {
      ...state.project,
      quickState,
      params: applyQuickStateToPhase0Params(base, quickState),
      updatedAt: new Date().toISOString(),
    },
  };
}

export function applyLutSelection(
  state: Phase0EditorState,
  lut: ParsedCubeLut | null,
): Phase0EditorState {
  return {
    ...state,
    project: {
      ...state.project,
      lut,
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
  return buildPhase0ExportRequest({
    source: state.source,
    probe: state.probe,
    project: state.project,
  });
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
