/**
 * @fileoverview Fixture-driven integration test helpers.
 *
 * @overview Each video fixture under `fixtures/video/**` ships with an adjacent
 * `<basename>.ffprobe.json` oracle file. The oracle is *not* a verbatim copy of
 * ffprobe's output — it is a minimal, human-authored declaration of what the
 * fixture represents:
 *
 *   {
 *     "expected": {
 *       "colorClass":  "hdr-hlg" | "hdr-pq" | "sdr-bt709" | ...,
 *       "policyByCapability": {
 *         "missingHdrFilters":  { "strategy": "...", "reason": "..." },
 *         "zscaleOnly":         { "strategy": "...", "reason": "..." },
 *         "libplaceboOnly":     { "strategy": "...", "reason": "..." },
 *         "zscaleAndLibplacebo": { "strategy": "...", "reason": "..." }
 *       }
 *     },
 *     "ffprobe":  {
 *       "streams": [ { "color_transfer": "...", ... } ],
 *       "format":  { "tags": { ... } }
 *     }
 *   }
 *
 * Helpers in this module:
 *  - `parseFixtureOracle`: runtime-validate a parsed JSON object into the
 *    strongly-typed `FixtureOracle` shape, with precise error messages that
 *    point at the first missing field.
 *  - `isStructuralSubset`: compare a live probe result against the oracle's
 *    `ffprobe` subtree. Arrays are matched positionally; `undefined` on the
 *    expected side allows the live value to be anything; non-object scalars
 *    must equal strictly (so timing-jitter fields like `bit_rate` / `duration`
 *    are simply omitted from the oracle).
 *
 * Neither helper performs I/O. File enumeration and ffprobe execution live in
 * `fixture-policy.integration.test.ts`.
 *
 * @limitations By design the oracle is *not* a Zod-validated shape — Zod lives
 * on the renderer side and the oracle is only consumed from Node-side tests.
 * Keeping this helper dependency-free means the test can boot before the Zod
 * sidecar schema imports the renderer tree.
 */

import type {
  HdrPreparationPolicy,
  SourceColorClass,
} from "./video-export-source-metadata";

const VALID_COLOR_CLASSES: readonly SourceColorClass[] = [
  "sdr-bt709",
  "hdr-pq",
  "hdr-hlg",
  "wide-gamut-unknown",
  "unknown",
] as const;

const VALID_POLICY_STRATEGIES: readonly HdrPreparationPolicy["strategy"][] = [
  "none",
  "prepare-sdr-mezzanine",
  "defer-unknown",
] as const;

const VALID_POLICY_REASONS: readonly HdrPreparationPolicy["reason"][] = [
  "source-is-sdr-bt709",
  "source-is-hdr-pq",
  "source-is-hdr-hlg",
  "wide-gamut-transfer-unknown",
  "source-color-unknown",
  "ffmpeg-missing-hdr-filters",
] as const;

const VALID_POLICY_CAPABILITY_KEYS = [
  "missingHdrFilters",
  "zscaleOnly",
  "libplaceboOnly",
  "zscaleAndLibplacebo",
] as const;

/**
 * @description The portion of ffprobe JSON that fixture oracles may pin.
 * Any property is optional; only the keys the oracle explicitly lists will
 * be checked against the live probe.
 */
export type FixtureOracleProbeShape = {
  streams?: Array<Record<string, unknown>>;
  format?: {
    tags?: Record<string, unknown>;
  } & Record<string, unknown>;
};

export type FixturePolicyCapabilityKey =
  (typeof VALID_POLICY_CAPABILITY_KEYS)[number];

export type FixtureOracleExpectedPolicy = {
  strategy: HdrPreparationPolicy["strategy"];
  reason: HdrPreparationPolicy["reason"];
};

export type FixtureOracleExpected = {
  colorClass: SourceColorClass;
  /**
   * @deprecated Single-policy oracles are accepted for old local fixtures only.
   * New fixtures should use `policyByCapability` so tests are deterministic
   * across stock and HDR-capable ffmpeg builds.
   */
  policy?: FixtureOracleExpectedPolicy;
  policyByCapability?: Record<
    FixturePolicyCapabilityKey,
    FixtureOracleExpectedPolicy
  >;
};

export type FixtureOracle = {
  expected: FixtureOracleExpected;
  ffprobe: FixtureOracleProbeShape;
};

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireOneOf<T extends string>(
  value: unknown,
  candidates: readonly T[],
  path: string,
): T {
  if (typeof value !== "string") {
    throw new Error(`${path} must be a string, got ${typeof value}`);
  }
  if (!(candidates as readonly string[]).includes(value)) {
    throw new Error(
      `${path} must be one of [${candidates.join(", ")}], got "${value}"`,
    );
  }
  return value as T;
}

function parseExpectedPolicy(
  raw: unknown,
  path: string,
): FixtureOracleExpectedPolicy {
  if (!isPlainObject(raw)) {
    throw new Error(`${path} must be an object`);
  }
  const strategy = requireOneOf(
    raw.strategy,
    VALID_POLICY_STRATEGIES,
    `${path}.strategy`,
  );
  const reason = requireOneOf(
    raw.reason,
    VALID_POLICY_REASONS,
    `${path}.reason`,
  );
  return { strategy, reason };
}

function parsePolicyByCapability(
  raw: unknown,
): Record<FixturePolicyCapabilityKey, FixtureOracleExpectedPolicy> {
  const path = "oracle.expected.policyByCapability";
  if (!isPlainObject(raw)) {
    throw new Error(`${path} must be an object`);
  }

  const allowedKeys = new Set<string>(VALID_POLICY_CAPABILITY_KEYS);
  for (const key of Object.keys(raw)) {
    if (!allowedKeys.has(key)) {
      throw new Error(
        `${path} contains unknown key "${key}"; expected [${VALID_POLICY_CAPABILITY_KEYS.join(", ")}]`,
      );
    }
  }

  const parsed = {} as Record<
    FixturePolicyCapabilityKey,
    FixtureOracleExpectedPolicy
  >;
  for (const key of VALID_POLICY_CAPABILITY_KEYS) {
    parsed[key] = parseExpectedPolicy(raw[key], `${path}.${key}`);
  }
  return parsed;
}

/**
 * @description Parse and validate a raw oracle JSON object. Throws a descriptive
 * error on any shape violation so a broken oracle fails loudly at test load time.
 */
export function parseFixtureOracle(raw: unknown): FixtureOracle {
  if (!isPlainObject(raw)) {
    throw new Error("oracle root must be a JSON object");
  }
  const expected = raw.expected;
  if (!isPlainObject(expected)) {
    throw new Error("oracle.expected must be an object");
  }
  const colorClass = requireOneOf(
    expected.colorClass,
    VALID_COLOR_CLASSES,
    "oracle.expected.colorClass",
  );
  const policy =
    expected.policy !== undefined
      ? parseExpectedPolicy(expected.policy, "oracle.expected.policy")
      : undefined;
  const policyByCapability =
    expected.policyByCapability !== undefined
      ? parsePolicyByCapability(expected.policyByCapability)
      : undefined;
  if (!policy && !policyByCapability) {
    throw new Error(
      "oracle.expected must include policyByCapability (preferred) or policy",
    );
  }

  let ffprobe: FixtureOracleProbeShape = {};
  if (raw.ffprobe !== undefined) {
    if (!isPlainObject(raw.ffprobe)) {
      throw new Error("oracle.ffprobe must be an object when provided");
    }
    const probeShape: FixtureOracleProbeShape = {};
    if (raw.ffprobe.streams !== undefined) {
      if (!Array.isArray(raw.ffprobe.streams)) {
        throw new Error("oracle.ffprobe.streams must be an array");
      }
      probeShape.streams = raw.ffprobe.streams.map((entry, index) => {
        if (!isPlainObject(entry)) {
          throw new Error(
            `oracle.ffprobe.streams[${index}] must be an object`,
          );
        }
        return entry;
      });
    }
    if (raw.ffprobe.format !== undefined) {
      if (!isPlainObject(raw.ffprobe.format)) {
        throw new Error("oracle.ffprobe.format must be an object");
      }
      probeShape.format = raw.ffprobe.format as FixtureOracleProbeShape["format"];
    }
    ffprobe = probeShape;
  }

  return {
    expected: {
      colorClass,
      ...(policy ? { policy } : {}),
      ...(policyByCapability ? { policyByCapability } : {}),
    },
    ffprobe,
  };
}

/**
 * @description Deep structural subset match. Returns a path list of mismatches
 * (empty = match). Extra keys on the live side are always allowed — the oracle
 * only pins the fields it declares. For arrays the expected length wins and
 * each index is compared; for primitives strict equality applies.
 *
 * @param expected the oracle's declared subtree (may be missing fields)
 * @param actual   the live probe subtree
 * @param pathHead prefix applied to mismatch paths for error messages
 */
export function isStructuralSubset(
  expected: unknown,
  actual: unknown,
  pathHead = "$",
): string[] {
  if (expected === undefined) return [];
  if (expected === null) {
    return actual === null ? [] : [`${pathHead}: expected null, got ${describeValue(actual)}`];
  }
  if (Array.isArray(expected)) {
    if (!Array.isArray(actual)) {
      return [`${pathHead}: expected array, got ${describeValue(actual)}`];
    }
    const mismatches: string[] = [];
    for (let i = 0; i < expected.length; i += 1) {
      mismatches.push(
        ...isStructuralSubset(expected[i], actual[i], `${pathHead}[${i}]`),
      );
    }
    return mismatches;
  }
  if (isPlainObject(expected)) {
    if (!isPlainObject(actual)) {
      return [`${pathHead}: expected object, got ${describeValue(actual)}`];
    }
    const mismatches: string[] = [];
    for (const key of Object.keys(expected)) {
      mismatches.push(
        ...isStructuralSubset(
          expected[key],
          actual[key],
          `${pathHead}.${key}`,
        ),
      );
    }
    return mismatches;
  }
  // primitives — strict equality, but numbers compare by Object.is to catch NaN.
  if (typeof expected === "number" && typeof actual === "number") {
    return Object.is(expected, actual)
      ? []
      : [`${pathHead}: expected ${expected}, got ${actual}`];
  }
  return expected === actual
    ? []
    : [`${pathHead}: expected ${describeValue(expected)}, got ${describeValue(actual)}`];
}

function describeValue(value: unknown): string {
  if (value === null) return "null";
  if (Array.isArray(value)) return `array(length=${value.length})`;
  if (typeof value === "object") return "object";
  if (typeof value === "string") return JSON.stringify(value);
  return String(value);
}
