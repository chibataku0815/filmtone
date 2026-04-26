import { describe, expect, test } from "bun:test";
import {
  createFilmtoneDefaultPhase0Params,
  serializeCubeLut,
  type ParsedCubeLut,
  type SourceInfo,
  type SourceProbe,
} from "film-lab-core";
import { parseCube } from "film-lab-core";
import {
  applyInputLutSelection,
  applyPresetSelection,
  applyProbe,
  applyQuickState,
  applyRenderMode,
  applyStrength,
  buildEditorExportRequest,
  createInitialEditorState,
  PHASE0_RENDER_MODE_DEFAULT,
} from "./phase0-state";

const sourceMock: SourceInfo = {
  uri: "file:///test.mov",
  filename: "test.mov",
  kind: "video",
};

const probeMock: SourceProbe = {
  ...sourceMock,
  width: 1920,
  height: 1080,
  durationSec: 30,
};

function makeTestLut(title: string): ParsedCubeLut {
  const cube = parseCube(`
TITLE "${title}"
LUT_3D_SIZE 2
0 0 0
1 0 0
0 1 0
1 1 0
0 0 1
1 0 1
0 1 1
1 1 1
`);

  return serializeCubeLut(cube, { title });
}

describe("phase0 state", () => {
  test("initial state uses the reset soft-finish default", () => {
    const initial = createInitialEditorState();

    expect(initial.project.presetName).toBe("reset");
    expect(initial.project.params).toEqual(createFilmtoneDefaultPhase0Params());
  });

  test("preset changes reset strength and quick state but preserve input LUT", () => {
    const inputLut = makeTestLut("Camera LUT");
    const initial = applyInputLutSelection(createInitialEditorState(), inputLut);
    const next = applyPresetSelection(initial, "portra");

    expect(next.project.inputLut).toEqual(inputLut);
    expect(next.project.strength).toBe(1);
    expect(next.project.quickState).toEqual({
      filmCharacter: 0,
      era: 0,
      dynamics: 0,
    });
    expect(next.project.params.exposure).toBeGreaterThan(0);
  });

  test("strength changes rebuild params without clearing input LUT", () => {
    const inputLut = makeTestLut("Camera LUT");
    const initial = applyInputLutSelection(createInitialEditorState(), inputLut);
    const next = applyStrength(initial, 0.35);

    expect(next.project.inputLut).toEqual(inputLut);
    expect(next.project.strength).toBeCloseTo(0.35, 5);
    expect(next.project.params.bloomStrength).toBeLessThan(initial.project.params.bloomStrength);
    expect(next.project.params.halationIntensity).toBeLessThan(initial.project.params.halationIntensity);
  });

  test("quick changes rebuild params on top of the current strength", () => {
    const strengthened = applyStrength(createInitialEditorState(), 0.5);
    const next = applyQuickState(strengthened, {
      filmCharacter: 0.4,
      era: -0.25,
      dynamics: 0.2,
    });

    expect(next.project.quickState.filmCharacter).toBeCloseTo(0.4, 5);
    expect(next.project.params.exposure).toBeGreaterThan(strengthened.project.params.exposure);
    expect(next.project.params.saturation).toBeGreaterThan(strengthened.project.params.saturation);
  });

  // v1.3 Stream A — Master / Postcard render mode (UI label rename only;
  // wire-level enum stays "quality" | "speed" for the v1.2 native gate).
  test("initial state defaults render mode to Master (wire: 'quality')", () => {
    const initial = createInitialEditorState();

    expect(initial.renderMode).toBe("quality");
    expect(PHASE0_RENDER_MODE_DEFAULT).toBe("quality");
  });

  test("applyRenderMode flips between Postcard and Master without touching project", () => {
    const initial = createInitialEditorState();
    const initialUpdatedAt = initial.project.updatedAt;

    const postcard = applyRenderMode(initial, "speed");
    expect(postcard.renderMode).toBe("speed");
    // Project should be reference-equal — render mode is editor-only state.
    expect(postcard.project).toBe(initial.project);
    expect(postcard.project.updatedAt).toBe(initialUpdatedAt);

    const master = applyRenderMode(postcard, "quality");
    expect(master.renderMode).toBe("quality");
    expect(master.project).toBe(initial.project);
  });

  test("applyRenderMode is a no-op when value is unchanged (preserves identity)", () => {
    const initial = createInitialEditorState();
    const same = applyRenderMode(initial, "quality");

    expect(same).toBe(initial);
  });

  test("buildEditorExportRequest omits renderMode when Master/Quality (default, v1.1 wire-compat)", () => {
    const state = {
      ...createInitialEditorState(),
      source: sourceMock,
      probe: probeMock,
    };
    const request = buildEditorExportRequest(state);
    expect(request).not.toBeNull();
    expect(request!.renderMode).toBeUndefined();
  });

  test("buildEditorExportRequest emits renderMode='speed' when Speed selected", () => {
    const initial = {
      ...createInitialEditorState(),
      source: sourceMock,
      probe: probeMock,
    };
    const state = applyRenderMode(initial, "speed");
    const request = buildEditorExportRequest(state);
    expect(request).not.toBeNull();
    expect(request!.renderMode).toBe("speed");
  });
});
