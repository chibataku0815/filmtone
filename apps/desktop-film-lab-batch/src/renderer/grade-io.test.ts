import { describe, expect, it } from "vitest";
import {
  filmLookGradeInputSchema,
  LOOK_ID_BY_PRESET,
  normalizeFilmLookGradeInputIdentity,
  PRESETS,
  PRESET_VERSION,
} from "film-lab-core";
import { buildGradeJsonPayload, exportGradeJsonText } from "./grade-io";
import { resolveGradeFromJsonText } from "./batch-pipeline";
import type { FilmLabBatchBridge } from "./desktop-api";

describe("buildGradeJsonPayload — Look Unification dual emit", () => {
  it("emits legacy lookPresetId / presetVersion AND Look-first lookId / lookVersion", () => {
    const payload = buildGradeJsonPayload(PRESETS.portra);
    expect(payload.lookPresetId).toBe(LOOK_ID_BY_PRESET.portra);
    expect(payload.presetVersion).toBe(PRESET_VERSION);
    expect(payload.lookId).toBe(LOOK_ID_BY_PRESET.portra);
    expect(payload.lookVersion).toBe(PRESET_VERSION);
    expect(payload.grade).toBe(PRESETS.portra);
  });

  it("self-parses through filmLookGradeInputSchema with both legacy and Look-first ids present", () => {
    const payload = buildGradeJsonPayload(PRESETS.cinematic);
    const r = filmLookGradeInputSchema.safeParse(payload);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.lookId).toBe(LOOK_ID_BY_PRESET.cinematic);
      expect(r.data.lookVersion).toBe(PRESET_VERSION);
    }
  });

  it("survives normalizeFilmLookGradeInputIdentity round-trip with the same identity object", () => {
    const payload = buildGradeJsonPayload(PRESETS.gold200);
    const normalized = normalizeFilmLookGradeInputIdentity(payload);
    expect(normalized).toBe(payload);
  });

  it("falls back to FILMTONE_DEFAULT_BASE_PRESET when no preset matches", () => {
    const customGrade = { ...PRESETS.cinematic, exposure: 0.999 };
    const payload = buildGradeJsonPayload(customGrade);
    expect(payload.lookPresetId).toBe(LOOK_ID_BY_PRESET.reset);
    expect(payload.lookId).toBe(LOOK_ID_BY_PRESET.reset);
    expect(payload.lookId).toBe(payload.lookPresetId);
  });

  it("exportGradeJsonText emits a JSON string carrying both id fields", () => {
    const text = exportGradeJsonText(PRESETS.bw);
    const parsed = JSON.parse(text) as Record<string, unknown>;
    expect(parsed.lookPresetId).toBe(LOOK_ID_BY_PRESET.bw);
    expect(parsed.lookId).toBe(LOOK_ID_BY_PRESET.bw);
    expect(parsed.presetVersion).toBe(PRESET_VERSION);
    expect(parsed.lookVersion).toBe(PRESET_VERSION);
  });
});

describe("resolveGradeFromJsonText — discriminator accepts legacy / dual / Look-only wrappers", () => {
  const apiStub = {} as FilmLabBatchBridge;

  it("recognises a legacy-only sidecar (lookPresetId + presetVersion, no lookId)", async () => {
    const json = JSON.stringify({
      lookPresetId: LOOK_ID_BY_PRESET.portra,
      presetVersion: PRESET_VERSION,
      grade: PRESETS.portra,
    });
    const result = await resolveGradeFromJsonText(apiStub, "/tmp/grade.json", json);
    expect(result.params.exposure).toBe(PRESETS.portra.exposure);
  });

  it("recognises a dual sidecar (lookPresetId + lookId both present, identity matches)", async () => {
    const json = JSON.stringify({
      lookPresetId: LOOK_ID_BY_PRESET.gold200,
      presetVersion: PRESET_VERSION,
      lookId: LOOK_ID_BY_PRESET.gold200,
      lookVersion: PRESET_VERSION,
      grade: PRESETS.gold200,
    });
    const result = await resolveGradeFromJsonText(apiStub, "/tmp/grade.json", json);
    expect(result.params.exposure).toBe(PRESETS.gold200.exposure);
  });

  it("throws on a dual sidecar with mismatched lookId / lookPresetId identity", async () => {
    const json = JSON.stringify({
      lookPresetId: LOOK_ID_BY_PRESET.portra,
      presetVersion: PRESET_VERSION,
      lookId: LOOK_ID_BY_PRESET.gold200,
      lookVersion: PRESET_VERSION,
      grade: PRESETS.portra,
    });
    await expect(
      resolveGradeFromJsonText(apiStub, "/tmp/grade.json", json),
    ).rejects.toThrow(/lookId\/lookPresetId mismatch/);
  });
});
