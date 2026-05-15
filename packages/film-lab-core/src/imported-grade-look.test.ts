import { describe, expect, test } from "bun:test";
import {
  IMPORTED_GRADE_SCHEMA_ID,
  IMPORTED_GRADE_SCHEMA_VERSION,
  buildImportedGradeLookFromDrxImport,
  importedGradeLookSchema,
} from "./imported-grade-look";

const base = {
  schemaId: IMPORTED_GRADE_SCHEMA_ID,
  schemaVersion: IMPORTED_GRADE_SCHEMA_VERSION,
  id: "11111111-1111-4111-8111-111111111111",
  title: "Verify Grade",
  source: { kind: "davinci-powergrade-package", packagePath: "/tmp/pkg" },
  baseLook: { kind: "none" },
  preLutControls: [],
  postLutControls: [],
  sourceGraph: null,
  unsupportedMetadata: [],
} as const;

describe("imported grade look schema", () => {
  test("accepts package/cube-free imported grade look", () => {
    const parsed = importedGradeLookSchema.parse(base);
    expect(parsed.schemaId).toBe(IMPORTED_GRADE_SCHEMA_ID);
    expect(parsed.baseLook.kind).toBe("none");
    expect(parsed.sourceGraph).toBeNull();
  });

  test("rejects duplicate control ids across slots", () => {
    expect(() => importedGradeLookSchema.parse({
      ...base,
      preLutControls: [{
        id: "cubeIntensity",
        slot: "preLut",
        operation: "logExposure",
        paramKey: "exposure",
        label: "Exposure",
        defaultValue: 0,
        min: -2,
        max: 2,
      }],
      postLutControls: [{
        id: "cubeIntensity",
        slot: "postLut",
        operation: "cubeIntensity",
        paramKey: null,
        label: "Cube",
        defaultValue: 1,
        min: 0,
        max: 1,
      }],
    })).toThrow();
  });

  test("rejects control slot mismatch", () => {
    expect(() => importedGradeLookSchema.parse({
      ...base,
      preLutControls: [{
        id: "wrong",
        slot: "postLut",
        operation: "cubeIntensity",
        paramKey: null,
        label: "Wrong",
        defaultValue: 1,
        min: 0,
        max: 1,
      }],
    })).toThrow();
  });

  test("builder creates davinci-drx graph-only look", () => {
    const look = buildImportedGradeLookFromDrxImport({
      id: "22222222-2222-4222-8222-222222222222",
      title: "F-LIFT-R",
      drxPath: "/tmp/F-LIFT-R.drx",
      sourceGraph: {
        format: "davinci-drx",
        decoded: true,
        bodyVersionFlag: 129,
        rawTriplets: [],
        wheelAdjustmentBlocks: [{ path: [1, 7, 9, 1], floatValues: [1.004] }],
        nodes: [{
          index: 1,
          protobufPath: [1],
          recognizedOps: ["wheelAdjustment:1.7.9.1"],
          unsupportedPayloadBase64: null,
          approximateInnerFieldCount: 1,
        }],
        approximateNodeCount: 1,
        unsupportedNotes: ["graph-only"],
      },
    });

    expect(look.source.kind).toBe("davinci-drx");
    expect(look.preLutControls).toHaveLength(0);
    expect(look.sourceGraph?.nodes[0]?.recognizedOps).toEqual(["wheelAdjustment:1.7.9.1"]);
  });
});
