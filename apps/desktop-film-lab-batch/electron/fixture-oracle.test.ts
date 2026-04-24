/**
 * @fileoverview Pure unit tests for the fixture oracle parser + structural-subset
 * helper. These do not touch the filesystem and always run, so the oracle
 * schema contract is regression-guarded even when no fixtures are present.
 */
import { describe, expect, it } from "vitest";

import {
  isStructuralSubset,
  parseFixtureOracle,
} from "./fixture-oracle";

describe("parseFixtureOracle", () => {
  it("accepts a minimal HLG oracle with only expected + ffprobe subset", () => {
    const oracle = parseFixtureOracle({
      expected: {
        colorClass: "hdr-hlg",
        policy: {
          strategy: "prepare-sdr-mezzanine",
          reason: "source-is-hdr-hlg",
        },
      },
      ffprobe: {
        streams: [
          {
            color_transfer: "arib-std-b67",
            color_primaries: "bt2020",
          },
        ],
      },
    });

    expect(oracle.expected.colorClass).toBe("hdr-hlg");
    expect(oracle.expected.policy.strategy).toBe("prepare-sdr-mezzanine");
    expect(oracle.expected.policy.reason).toBe("source-is-hdr-hlg");
    expect(oracle.ffprobe.streams?.[0]?.color_transfer).toBe("arib-std-b67");
  });

  it("fills empty ffprobe when the oracle omits the key entirely", () => {
    const oracle = parseFixtureOracle({
      expected: {
        colorClass: "sdr-bt709",
        policy: { strategy: "none", reason: "source-is-sdr-bt709" },
      },
    });

    expect(oracle.ffprobe).toEqual({});
  });

  it("rejects an unknown colorClass with a path-qualified error", () => {
    expect(() =>
      parseFixtureOracle({
        expected: {
          colorClass: "hdr-dolby-vision",
          policy: { strategy: "none", reason: "source-is-sdr-bt709" },
        },
      }),
    ).toThrowError(/oracle\.expected\.colorClass/);
  });

  it("rejects a policy.strategy that is not part of the union", () => {
    expect(() =>
      parseFixtureOracle({
        expected: {
          colorClass: "hdr-pq",
          policy: { strategy: "auto-magic", reason: "source-is-hdr-pq" },
        },
      }),
    ).toThrowError(/oracle\.expected\.policy\.strategy/);
  });

  it("rejects a non-object at the oracle root", () => {
    expect(() => parseFixtureOracle("not-an-object")).toThrowError(
      /oracle root/,
    );
  });

  it("rejects a malformed ffprobe.streams entry", () => {
    expect(() =>
      parseFixtureOracle({
        expected: {
          colorClass: "sdr-bt709",
          policy: { strategy: "none", reason: "source-is-sdr-bt709" },
        },
        ffprobe: { streams: [42] },
      }),
    ).toThrowError(/oracle\.ffprobe\.streams\[0\]/);
  });
});

describe("isStructuralSubset", () => {
  it("returns no mismatches when expected keys are a subset of actual", () => {
    expect(
      isStructuralSubset(
        { color_transfer: "arib-std-b67" },
        {
          color_transfer: "arib-std-b67",
          color_space: "bt2020nc",
          bit_rate: "12345678",
        },
      ),
    ).toEqual([]);
  });

  it("tolerates unspecified (undefined) expected branches", () => {
    expect(
      isStructuralSubset(
        { streams: [{ color_transfer: "smpte2084" }] },
        {
          streams: [
            {
              color_transfer: "smpte2084",
              duration: "0.95",
            },
          ],
          format: { bit_rate: "9999" },
        },
      ),
    ).toEqual([]);
  });

  it("reports a path-qualified mismatch when primitives differ", () => {
    const mismatches = isStructuralSubset(
      { streams: [{ color_transfer: "smpte2084" }] },
      { streams: [{ color_transfer: "bt709" }] },
    );

    expect(mismatches).toHaveLength(1);
    expect(mismatches[0]).toContain("$.streams[0].color_transfer");
    expect(mismatches[0]).toContain("smpte2084");
    expect(mismatches[0]).toContain("bt709");
  });

  it("reports a mismatch when the actual side is the wrong shape", () => {
    const mismatches = isStructuralSubset(
      { streams: [{ color_transfer: "arib-std-b67" }] },
      { streams: "not-an-array" },
    );

    expect(mismatches).toHaveLength(1);
    expect(mismatches[0]).toContain("$.streams");
    expect(mismatches[0]).toContain("expected array");
  });

  it("accepts an exact primitive match at the root", () => {
    expect(isStructuralSubset("a", "a")).toEqual([]);
    expect(isStructuralSubset(1, 1)).toEqual([]);
    expect(isStructuralSubset(null, null)).toEqual([]);
  });

  it("flags NaN mismatch via Object.is", () => {
    const mismatches = isStructuralSubset(Number.NaN, 0);
    expect(mismatches).toHaveLength(1);
  });
});
