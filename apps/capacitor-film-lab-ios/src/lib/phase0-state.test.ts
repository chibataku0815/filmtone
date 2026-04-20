import { describe, expect, test } from "bun:test";
import {
  serializeCubeLut,
  type ParsedCubeLut,
} from "film-lab-core";
import { parseCube } from "film-lab-core";
import {
  applyInputLutSelection,
  applyPresetSelection,
  applyQuickState,
  applyStrength,
  createInitialEditorState,
} from "./phase0-state";

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
    expect(next.project.params.contrast).toBeLessThan(initial.project.params.contrast);
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
