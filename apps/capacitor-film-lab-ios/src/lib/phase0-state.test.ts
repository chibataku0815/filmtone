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
  applyQuickState,
  applyRenderMode,
  applyStrength,
  buildEditorExportRequest,
  createInitialEditorState,
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
});

describe("phase0 state — render mode (v1.2)", () => {
  test("default render mode is quality", () => {
    expect(createInitialEditorState().renderMode).toBe("quality");
  });

  test("applyRenderMode updates state and preserves identity on no-op", () => {
    const initial = createInitialEditorState();
    const speed = applyRenderMode(initial, "speed");
    expect(speed.renderMode).toBe("speed");
    expect(speed).not.toBe(initial);
    expect(applyRenderMode(speed, "speed")).toBe(speed);
  });

  test("buildEditorExportRequest omits renderMode when Quality (default)", () => {
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
