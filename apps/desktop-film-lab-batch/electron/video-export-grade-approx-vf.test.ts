/**
 * @fileoverview `buildGradeApproximationVF` の回帰テスト（ffmpeg ヴィネット写像など）
 */
import { describe, expect, it } from "vitest";
import { PRESETS } from "film-lab-core";

import { buildGradeApproximationVF } from "./video-export-grade-approx-vf";

describe("video-export-grade-approx-vf", () => {
  it("uses a softer vignette angle for cinematic than the legacy PI*(0.14+v*0.95) mapping", () => {
    const vf = buildGradeApproximationVF(PRESETS.cinematic);
    const m = vf.match(/vignette=angle=([^:]+)/);
    expect(m).toBeTruthy();
    const angle = Number(m![1]);
    const v = PRESETS.cinematic.vignette;
    const legacyStrong = Math.PI * (0.14 + v * 0.95);
    expect(angle).toBeLessThan(legacyStrong * 0.72);
    expect(angle).toBeGreaterThanOrEqual(Math.PI / 5 - 0.02);
  });

  it("omits vignette when preset has no vignette", () => {
    const vf = buildGradeApproximationVF(PRESETS.reset);
    expect(vf).not.toContain("vignette=");
  });
});
