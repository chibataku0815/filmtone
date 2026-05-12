import { describe, expect, test } from "bun:test";
import {
  DETAIL_SOFTNESS_EFFECTIVE_MAX,
  deriveDetailSoftnessUniforms,
} from "./detail-softness";

describe("deriveDetailSoftnessUniforms", () => {
  test("detailSoftness = 0 produces identity-neutral uniforms", () => {
    const u = deriveDetailSoftnessUniforms(0);
    expect(u.effectiveDetailSoftness).toBe(0);
    // Identity short-circuit in shader fires when effectiveDetailSoftness == 0;
    // the radius value at 0 is allowed but should still sit inside the
    // documented range so renderers without a short-circuit do not allocate
    // a 0-px kernel.
    expect(u.kernelRadiusPx).toBeGreaterThanOrEqual(1.0);
    expect(u.kernelRadiusPx).toBeLessThanOrEqual(2.5);
  });

  test("negative detailSoftness clamps to 0", () => {
    expect(deriveDetailSoftnessUniforms(-0.1).effectiveDetailSoftness).toBe(0);
    expect(deriveDetailSoftnessUniforms(-1).effectiveDetailSoftness).toBe(0);
  });

  test("detailSoftness above effectiveMax clamps to effectiveMax", () => {
    expect(deriveDetailSoftnessUniforms(0.7).effectiveDetailSoftness).toBe(
      DETAIL_SOFTNESS_EFFECTIVE_MAX,
    );
    expect(deriveDetailSoftnessUniforms(1.0).effectiveDetailSoftness).toBe(
      DETAIL_SOFTNESS_EFFECTIVE_MAX,
    );
  });

  test("sourceDetailBias defaults to 0", () => {
    const a = deriveDetailSoftnessUniforms(0.18);
    const b = deriveDetailSoftnessUniforms(0.18, {});
    expect(a.effectiveDetailSoftness).toBe(b.effectiveDetailSoftness);
    expect(a.effectiveDetailSoftness).toBeCloseTo(0.18, 10);
  });

  test("sourceDetailBias sums into effective then re-clamps to [0, effectiveMax]", () => {
    expect(
      deriveDetailSoftnessUniforms(0.4, { sourceDetailBias: 0.4 })
        .effectiveDetailSoftness,
    ).toBe(DETAIL_SOFTNESS_EFFECTIVE_MAX);

    expect(
      deriveDetailSoftnessUniforms(0.1, { sourceDetailBias: 0.1 })
        .effectiveDetailSoftness,
    ).toBeCloseTo(0.2, 10);

    expect(
      deriveDetailSoftnessUniforms(0, { sourceDetailBias: -0.5 })
        .effectiveDetailSoftness,
    ).toBe(0);
  });

  test("kernelRadiusPx stays inside [1.0, 2.5] across the input range", () => {
    for (const v of [0, 0.05, 0.18, 0.3, 0.45, 0.55, 0.65, 0.8, -0.1]) {
      const u = deriveDetailSoftnessUniforms(v);
      expect(u.kernelRadiusPx).toBeGreaterThanOrEqual(1.0);
      expect(u.kernelRadiusPx).toBeLessThanOrEqual(2.5);
    }
  });

  test("kernelRadiusPx increases monotonically with effectiveDetailSoftness", () => {
    const samples = [0, 0.05, 0.1, 0.18, 0.3, 0.45, 0.55, 0.65].map((v) =>
      deriveDetailSoftnessUniforms(v),
    );
    for (let i = 1; i < samples.length; i += 1) {
      expect(samples[i]!.kernelRadiusPx).toBeGreaterThanOrEqual(
        samples[i - 1]!.kernelRadiusPx,
      );
    }
    // Endpoints stake out the documented range.
    expect(samples[0]!.kernelRadiusPx).toBeCloseTo(1.0, 10);
    expect(samples.at(-1)!.kernelRadiusPx).toBeCloseTo(2.5, 10);
  });

  test("constants required by 4-renderer parity stay stable", () => {
    const u = deriveDetailSoftnessUniforms(0.18);
    // Any change here is a Phase 5-B tuning concern and must update
    // the Swift mirror in FilmLabSwiftCore + every shader port
    // (iOS CIKernel, macOS CIKernel, WebGL frag, WebGPU WGSL) in
    // lockstep.
    expect(u.rangeSigma).toBe(0.07);
    expect(u.detailAmplitudeLo).toBe(0.0);
    expect(u.detailAmplitudeHi).toBe(0.05);
    expect(u.chromaAttenScale).toBe(0.7);
    expect(u.highlightBias).toBe(1.18);
  });
});
