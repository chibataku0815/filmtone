import { z } from "zod";

export const IMPORTED_GRADE_SCHEMA_ID = "filmtone-imported-grade-v1";
export const IMPORTED_GRADE_SCHEMA_VERSION = 1;

export const importedGradeControlSlotSchema = z.enum(["preLut", "postLut"]);

export const importedGradeControlSchema = z.object({
  id: z.string().min(1),
  slot: importedGradeControlSlotSchema,
  operation: z.string().min(1),
  paramKey: z.string().min(1).nullable().default(null),
  label: z.string().min(1),
  defaultValue: z.number().finite(),
  min: z.number().finite(),
  max: z.number().finite(),
}).superRefine((control, ctx) => {
  if (control.min > control.max) {
    ctx.addIssue({
      code: "custom",
      path: ["min"],
      message: "min must be <= max",
    });
  }
  if (control.defaultValue < control.min || control.defaultValue > control.max) {
    ctx.addIssue({
      code: "custom",
      path: ["defaultValue"],
      message: "defaultValue must be inside min/max",
    });
  }
});

export const importedGradeBaseLookSchema = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("none") }),
  z.object({
    kind: z.literal("cube"),
    path: z.string().min(1),
    size: z.number().int().positive(),
    intensity: z.number().finite().min(0).max(1).default(1),
    sourceHash: z.string().min(1).nullable().default(null),
  }),
]);

export const importedGradeSourceSchema = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("davinci-powergrade-package"),
    packagePath: z.string().min(1).nullable().default(null),
  }),
  z.object({
    kind: z.literal("davinci-drx"),
    drxPath: z.string().min(1).nullable().default(null),
  }),
  z.object({
    kind: z.literal("cube-only"),
    packagePath: z.string().min(1).nullable().default(null),
  }),
]);

export const drxGraphTripletSchema = z.object({
  parameterId: z.number().int().nonnegative(),
  values: z.array(z.number().finite()).default([]),
});

export const drxGraphWheelBlockSchema = z.object({
  path: z.array(z.number().int().nonnegative()),
  floatValues: z.array(z.number().finite()).default([]),
});

export const importedGradeSourceGraphNodeSchema = z.object({
  index: z.number().int().nonnegative(),
  protobufPath: z.array(z.number().int().nonnegative()).default([]),
  recognizedOps: z.array(z.string()).default([]),
  unsupportedPayloadBase64: z.string().nullable().default(null),
  approximateInnerFieldCount: z.number().int().nonnegative().default(0),
});

export const importedGradeSourceGraphSchema = z.object({
  format: z.literal("davinci-drx"),
  decoded: z.boolean().default(false),
  bodyVersionFlag: z.number().int().nonnegative().nullable().default(null),
  rawTriplets: z.array(drxGraphTripletSchema).default([]),
  wheelAdjustmentBlocks: z.array(drxGraphWheelBlockSchema).default([]),
  nodes: z.array(importedGradeSourceGraphNodeSchema).default([]),
  approximateNodeCount: z.number().int().nonnegative().default(0),
  unsupportedNotes: z.array(z.string()).default([]),
});

export const importedGradeLookSchema = z.object({
  schemaId: z.literal(IMPORTED_GRADE_SCHEMA_ID),
  schemaVersion: z.literal(IMPORTED_GRADE_SCHEMA_VERSION),
  id: z.string().uuid(),
  title: z.string().min(1),
  source: importedGradeSourceSchema,
  baseLook: importedGradeBaseLookSchema.default({ kind: "none" }),
  preLutControls: z.array(importedGradeControlSchema).default([]),
  postLutControls: z.array(importedGradeControlSchema).default([]),
  sourceGraph: importedGradeSourceGraphSchema.nullable().default(null),
  unsupportedMetadata: z.array(z.string()).default([]),
}).superRefine((look, ctx) => {
  const ids = new Set<string>();
  for (const [slot, controls] of [
    ["preLutControls", look.preLutControls],
    ["postLutControls", look.postLutControls],
  ] as const) {
    for (const control of controls) {
      if (control.slot !== (slot === "preLutControls" ? "preLut" : "postLut")) {
        ctx.addIssue({
          code: "custom",
          path: [slot, control.id, "slot"],
          message: `control is in ${slot} but declares ${control.slot}`,
        });
      }
      if (ids.has(control.id)) {
        ctx.addIssue({
          code: "custom",
          path: [slot, control.id],
          message: `duplicate control id ${control.id}`,
        });
      }
      ids.add(control.id);
    }
  }
});

export type ImportedGradeControl = z.infer<typeof importedGradeControlSchema>;
export type ImportedGradeLook = z.infer<typeof importedGradeLookSchema>;
export type ImportedGradeSourceGraph = z.infer<typeof importedGradeSourceGraphSchema>;

export function buildImportedGradeLookFromDrxImport(input: {
  id: string;
  title: string;
  drxPath?: string | null;
  sourceGraph: ImportedGradeSourceGraph;
  preLutControls?: ImportedGradeControl[];
  unsupportedMetadata?: string[];
}): ImportedGradeLook {
  return importedGradeLookSchema.parse({
    schemaId: IMPORTED_GRADE_SCHEMA_ID,
    schemaVersion: IMPORTED_GRADE_SCHEMA_VERSION,
    id: input.id,
    title: input.title,
    source: {
      kind: "davinci-drx",
      drxPath: input.drxPath ?? null,
    },
    baseLook: { kind: "none" },
    preLutControls: input.preLutControls ?? [],
    postLutControls: [],
    sourceGraph: input.sourceGraph,
    unsupportedMetadata: input.unsupportedMetadata ?? [],
  });
}
