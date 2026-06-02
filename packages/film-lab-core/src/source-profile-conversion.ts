/**
 * Source profile conversion (Camera Profiles for Log → Rec.709 SDR).
 *
 * Catalog + math ported from `FilmtoneSourceProfileMath.swift` /
 * `FilmtoneSourceProfileCatalog.swift` so Filmtone Desktop's Log Conversion
 * lane (lut1) gets the same built-in input transforms iOS ships in v1.4:
 * Apple Log / Apple Log 2 / ARRI LogC3 / DJI D-Log / DJI D-Log M /
 * Canon C-Log / Canon Log 3 + Cinema Gamut / Panasonic V-Log /
 * Sony S-Log3, plus Rec.709 passthrough.
 *
 * Math constants are copied verbatim from the Swift SSOT. Drift between
 * Swift and TS is a hard product-quality bug — fixture parity tests in
 * `source-profile-conversion.test.ts` read the iOS reference fixtures
 * (`apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/<curve>/`)
 * to lock TS output against Swift output.
 *
 * `buildSourceProfileLut` returns a Float32Array in the same RGBA layout
 * `parseCube` produces (size³ × 4 floats, alpha = 1, sample-major with R
 * fastest), so `viewport.setLUT1` / WebGPU `Lut3DTexture.upload` accept
 * built-in and custom `.cube` data interchangeably.
 */

export type SourceProfileCurve =
  | "apple-log"
  | "apple-log-2"
  | "arri-logc3"
  | "dji-dlog"
  | "dji-dlog-m"
  | "canon-clog"
  | "canon-log3-cinema-gamut"
  | "panasonic-vlog"
  | "sony-slog3";

export type SourceProfileImplKind =
  | "nil-profile"
  | "native-policy"
  | "synthesized";

export type SourceProfileId =
  | "built-in:source-profile.rec709"
  | "built-in:source-profile.apple-log"
  | "built-in:source-profile.apple-log-2"
  | "built-in:source-profile.arri-logc3"
  | "built-in:source-profile.dji-dlog"
  | "built-in:source-profile.dji-dlog-m"
  | "built-in:source-profile.canon-clog"
  | "built-in:source-profile.canon-log3-cinema-gamut"
  | "built-in:source-profile.panasonic-vlog"
  | "built-in:source-profile.sony-slog3";

export interface SourceProfileCatalogEntry {
  readonly id: SourceProfileId;
  readonly displayName: string;
  readonly curve: SourceProfileCurve | null;
  readonly impl: SourceProfileImplKind;
  readonly builtIn: true;
  readonly immutable: true;
}

export const SOURCE_PROFILE_CATALOG: readonly SourceProfileCatalogEntry[] = [
  {
    id: "built-in:source-profile.rec709",
    displayName: "Rec.709",
    curve: null,
    impl: "nil-profile",
    builtIn: true,
    immutable: true,
  },
  {
    id: "built-in:source-profile.apple-log",
    displayName: "Apple Log",
    curve: "apple-log",
    impl: "native-policy",
    builtIn: true,
    immutable: true,
  },
  {
    id: "built-in:source-profile.apple-log-2",
    displayName: "Apple Log 2",
    curve: "apple-log-2",
    impl: "native-policy",
    builtIn: true,
    immutable: true,
  },
  {
    id: "built-in:source-profile.arri-logc3",
    displayName: "ARRI LogC3",
    curve: "arri-logc3",
    impl: "synthesized",
    builtIn: true,
    immutable: true,
  },
  {
    id: "built-in:source-profile.dji-dlog",
    displayName: "DJI D-Log",
    curve: "dji-dlog",
    impl: "synthesized",
    builtIn: true,
    immutable: true,
  },
  {
    id: "built-in:source-profile.dji-dlog-m",
    displayName: "DJI D-Log M",
    curve: "dji-dlog-m",
    impl: "synthesized",
    builtIn: true,
    immutable: true,
  },
  {
    id: "built-in:source-profile.canon-clog",
    displayName: "Canon C-Log",
    curve: "canon-clog",
    impl: "synthesized",
    builtIn: true,
    immutable: true,
  },
  {
    id: "built-in:source-profile.canon-log3-cinema-gamut",
    displayName: "Canon Log 3 / Cinema Gamut",
    curve: "canon-log3-cinema-gamut",
    impl: "synthesized",
    builtIn: true,
    immutable: true,
  },
  {
    id: "built-in:source-profile.panasonic-vlog",
    displayName: "V-Log",
    curve: "panasonic-vlog",
    impl: "synthesized",
    builtIn: true,
    immutable: true,
  },
  {
    id: "built-in:source-profile.sony-slog3",
    displayName: "S-Log3",
    curve: "sony-slog3",
    impl: "synthesized",
    builtIn: true,
    immutable: true,
  },
];

const CATALOG_BY_ID: Map<string, SourceProfileCatalogEntry> = new Map(
  SOURCE_PROFILE_CATALOG.map((entry) => [entry.id, entry] as const),
);

export function getSourceProfile(id: string): SourceProfileCatalogEntry | null {
  return CATALOG_BY_ID.get(id) ?? null;
}

export interface BuiltSourceProfileLut {
  readonly id: SourceProfileId;
  readonly displayName: string;
  readonly data: Float32Array;
  readonly size: number;
}

const LUT_CACHE: Map<string, Float32Array> = new Map();

/**
 * Generate the built-in conversion LUT for the given catalog entry.
 *
 * Returns null for the Rec.709 nil-profile (= passthrough; callers should
 * `viewport.clearLUT1()` instead of uploading an identity cube) and for
 * unknown ids.
 */
export function buildSourceProfileLut(
  id: string,
  size: number = 33,
): BuiltSourceProfileLut | null {
  const entry = getSourceProfile(id);
  if (!entry) return null;
  if (entry.impl === "nil-profile") return null;

  if (size < 2 || !Number.isInteger(size)) {
    throw new Error(`source-profile cube size must be an integer ≥ 2 (got ${size})`);
  }

  const cacheKey = `${entry.id}|${size}`;
  const cached = LUT_CACHE.get(cacheKey);
  if (cached) {
    return {
      id: entry.id,
      displayName: entry.displayName,
      data: cached,
      size,
    };
  }

  const data = generateCubeForEntry(entry, size);
  LUT_CACHE.set(cacheKey, data);

  return {
    id: entry.id,
    displayName: entry.displayName,
    data,
    size,
  };
}

function generateCubeForEntry(
  entry: SourceProfileCatalogEntry,
  size: number,
): Float32Array {
  switch (entry.curve) {
    case "apple-log":
      return makeAppleLogToRec709Cube(size, false);
    case "apple-log-2":
      return makeAppleLogToRec709Cube(size, true);
    case "arri-logc3":
      return makeArriLogC3ToRec709Cube(size);
    case "dji-dlog":
      return makeDlogToRec709Cube(size);
    case "dji-dlog-m":
      return makeDlogMToRec709Cube(size);
    case "canon-clog":
      return makeCanonClogToRec709Cube(size);
    case "canon-log3-cinema-gamut":
      return makeCanonLog3CineGamutToRec709Cube(size);
    case "panasonic-vlog":
      return makeVlogToRec709Cube(size);
    case "sony-slog3":
      return makeSlog3ToRec709Cube(size);
    case null:
      throw new Error(`source-profile ${entry.id} has no curve; cannot build a cube`);
    default: {
      const exhaustive: never = entry.curve;
      throw new Error(`Unhandled source-profile curve: ${String(exhaustive)}`);
    }
  }
}

// =====================================================================
// Math primitives — verbatim from FilmtoneSourceProfileMath.swift
// =====================================================================

function clamp01(v: number): number {
  return Math.min(Math.max(v, 0), 1);
}

/**
 * Filmtone identity SDR shoulder. Anchors `0.18` linear ≈ middle gray and
 * rolls highlights via a soft-knee Reinhard-style curve. Output clamped
 * to [0, 1]. Identical math across every Camera Profile.
 */
function filmtoneSdrShoulder(linear: number): number {
  const exposed = Math.max(0, linear * 1.18);
  const shoulder = exposed / (1 + Math.max(exposed - 0.18, 0) * 0.42);
  return clamp01(shoulder);
}

/** ITU-R BT.709 OETF (encode) with the standard 0.018 knee. */
function rec709Encode(linear: number): number {
  const value = clamp01(linear);
  if (value < 0.018) {
    return value * 4.5;
  }
  return 1.099 * Math.pow(value, 0.45) - 0.099;
}

// ---------- Apple Log / Apple Log 2 ----------

/**
 * Apple Log → linear scene-referred decoder. Apple Log 2 reuses this
 * curve (only the gamut differs — known limitation logged in iOS
 * `docs/source-profile-math/apple-log-2.md`).
 */
export function appleLogDecode(encoded: number): number {
  const r0 = -0.05641088;
  const rt = 0.01;
  const sigma = 47.28711236;
  const beta = 0.00964052;
  const gamma = 0.08550479;
  const delta = 0.69336945;
  const pt = sigma * Math.pow(rt - r0, 2);

  if (encoded >= pt) {
    return Math.pow(2, (encoded - delta) / gamma) - beta;
  }
  if (encoded >= 0) {
    return Math.sqrt(Math.max(encoded / sigma, 0)) + r0;
  }
  return r0;
}

function appleLogPixelToRec709(
  red: number,
  green: number,
  blue: number,
  rec2020GamutMap: boolean,
): [number, number, number] {
  let lr = appleLogDecode(red);
  let lg = appleLogDecode(green);
  let lb = appleLogDecode(blue);
  if (rec2020GamutMap) {
    const mapped = rec2020ToRec709(lr, lg, lb);
    lr = mapped[0];
    lg = mapped[1];
    lb = mapped[2];
  }
  return [
    rec709Encode(filmtoneSdrShoulder(lr)),
    rec709Encode(filmtoneSdrShoulder(lg)),
    rec709Encode(filmtoneSdrShoulder(lb)),
  ];
}

// ---------- ARRI LogC3 + ARRI Wide Gamut 3 ----------

/**
 * ARRI LogC3 EI 800 → linear exposure-value decoder. Constants are from
 * ARRI's *ALEXA Log C Curve - Usage in VFX* exposure-value parameter table
 * for EI 800. Filmtone uses the EI 800 recommendation for normalized source
 * profiles when clip-specific EI metadata is unavailable.
 */
export function arriLogC3Decode(encoded: number): number {
  const cut = 0.010591;
  const a = 5.555556;
  const b = 0.052272;
  const c = 0.24719;
  const d = 0.385537;
  const e = 5.367655;
  const f = 0.092809;
  const threshold = e * cut + f;
  if (encoded > threshold) {
    return (Math.pow(10.0, (encoded - d) / c) - b) / a;
  }
  return (encoded - f) / e;
}

/** Linear ARRI Wide Gamut 3 → Rec.709 matrix from ARRI's LogC3 VFX guide. */
function arriWideGamut3ToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  return [
    1.617523 * red - 0.537287 * green - 0.080237 * blue,
    -0.070573 * red + 1.334613 * green - 0.26404 * blue,
    -0.021102 * red - 0.226954 * green + 1.248056 * blue,
  ];
}

export function arriLogC3PixelToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  const lr = arriLogC3Decode(red);
  const lg = arriLogC3Decode(green);
  const lb = arriLogC3Decode(blue);
  const m = arriWideGamut3ToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2])),
  ];
}

// ---------- DJI D-Log ----------

/**
 * D-Log → linear scene-referred decoder. From DJI's *White Paper on
 * D-Log and D-Gamut of DJI Cinema Color System* (Zenmuse X9 6K & 8K,
 * Rev.1.0). Documented D-Log / D-Gamut, not D-Log M.
 */
export function dlogDecode(encoded: number): number {
  if (encoded <= 0.14) {
    return (encoded - 0.0929) / 6.025;
  }
  return (Math.pow(10.0, 3.89616 * encoded - 2.27752) - 0.0108) / 0.9892;
}

/** D-Gamut → Rec.709 matrix from DJI's D-Gamut colorimetric section. */
function dgamutToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  return [
    1.6746 * red - 0.5797 * green - 0.0949 * blue,
    -0.0981 * red + 1.334 * green - 0.2359 * blue,
    -0.041 * red - 0.243 * green + 1.284 * blue,
  ];
}

export function dlogPixelToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  const lr = dlogDecode(red);
  const lg = dlogDecode(green);
  const lb = dlogDecode(blue);
  const m = dgamutToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2])),
  ];
}

// ---------- DJI D-Log M ----------

/**
 * D-Log M → linear scene-referred decoder. DJI has not published a
 * formal D-Log M transfer specification. These constants are fitted from
 * DJI's consumer-camera `D-Log M to Rec.709 V1.cube` and copied from the
 * Swift SSOT.
 */
export function dlogMDecode(encoded: number): number {
  const cut = 0.1113510236;
  const linearOffset = 0.000000012;
  const linearSlope = 7.5547639793;
  const logA = 1.538947658;
  const logB = -1.8459129538;
  const logC = 0.0165823994;
  const logD = 0.3103580873;
  if (encoded <= cut) {
    return (encoded - linearOffset) / linearSlope;
  }
  return (Math.pow(10.0, logA * encoded + logB) - logC) / logD;
}

/** D-Gamut M → Rec.709 matrix fitted from DJI's D-Log M cube. */
function dgamutMToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  return [
    1.4312693292 * red - 0.4338679939 * green + 0.0025986647 * blue,
    -0.0747311522 * red + 1.1578502353 * green - 0.083119083 * blue,
    -0.0570111279 * red - 0.2731296886 * green + 1.3301408164 * blue,
  ];
}

export function dlogMPixelToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  const lr = dlogMDecode(red);
  const lg = dlogMDecode(green);
  const lb = dlogMDecode(blue);
  const m = dgamutMToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2])),
  ];
}

// ---------- Canon C-Log (original) ----------

/**
 * Canon Log original → linear scene-referred decoder. Canon's 2012
 * Canon-Log transfer characteristic via the Colour Science implementation.
 * Original C-Log is BT.709 gamut, so no chromaticity matrix is applied.
 * Canon Log 2/3 + Cinema Gamut should be separate profiles.
 */
export function canonLogDecode(encoded: number): number {
  const pivot = 0.0730597;
  const scale = 0.529136;
  const gain = 10.1596;
  let linear: number;
  if (encoded < pivot) {
    linear = -(Math.pow(10.0, (pivot - encoded) / scale) - 1.0) / gain;
  } else {
    linear = (Math.pow(10.0, (encoded - pivot) / scale) - 1.0) / gain;
  }
  return linear * 0.9;
}

export function canonClogPixelToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  const lr = canonLogDecode(red);
  const lg = canonLogDecode(green);
  const lb = canonLogDecode(blue);
  return [
    rec709Encode(filmtoneSdrShoulder(lr)),
    rec709Encode(filmtoneSdrShoulder(lg)),
    rec709Encode(filmtoneSdrShoulder(lb)),
  ];
}

// ---------- Canon Log 3 + Cinema Gamut ----------

/**
 * Canon Log 3 → linear scene-referred decoder. Constants from Canon
 * Log 3 v1.2 via the Colour Science reference, copied from the Swift SSOT.
 */
export function canonLog3Decode(encoded: number): number {
  const lowBreak = 0.097465473;
  const highBreak = 0.15277891;
  const logScale = 0.36726845;
  const logGain = 14.98325;
  const linearSlope = 1.9754798;
  const linearOffset = 0.12512219;
  const lowOffset = 0.12783901;
  const highOffset = 0.12240537;
  let scene: number;
  if (encoded < lowBreak) {
    scene = -(Math.pow(10.0, (lowOffset - encoded) / logScale) - 1.0) / logGain;
  } else if (encoded <= highBreak) {
    scene = (encoded - linearOffset) / linearSlope;
  } else {
    scene = (Math.pow(10.0, (encoded - highOffset) / logScale) - 1.0) / logGain;
  }
  return scene * 0.9;
}

/** Cinema Gamut → Rec.709 (D65 → D65, no chromatic adaptation). */
function cineGamutToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  return [
    1.92355517 * red - 0.79863353 * green - 0.12508072 * blue,
    -0.20431556 * red + 1.49593305 * green - 0.2915944 * blue,
    -0.02369073 * red - 0.42022784 * green + 1.44415855 * blue,
  ];
}

export function canonLog3CineGamutPixelToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  const lr = canonLog3Decode(red);
  const lg = canonLog3Decode(green);
  const lb = canonLog3Decode(blue);
  const m = cineGamutToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2])),
  ];
}

// ---------- Panasonic V-Log ----------

/**
 * V-Log → linear scene-referred decoder. From Panasonic *V-Log/V-Gamut
 * REFERENCE MANUAL* (2014-11-28).
 */
export function vlogDecode(encoded: number): number {
  const cut2 = 0.181;
  const b = 0.00873;
  const c = 0.241514;
  const d = 0.598206;

  if (encoded < cut2) {
    return (encoded - 0.125) / 5.6;
  }
  return Math.pow(10.0, (encoded - d) / c) - b;
}

/**
 * V-Gamut → Rec.709 (D65 → D65, no chromatic adaptation). Precomputed
 * product of (V-Gamut → XYZ) · (XYZ → Rec.709).
 */
function vgamutToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  return [
    1.7398 * red - 0.6727 * green - 0.0671 * blue,
    -0.1956 * red + 1.2473 * green - 0.0518 * blue,
    -0.0114 * red - 0.044 * green + 1.0554 * blue,
  ];
}

export function vlogPixelToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  const lr = vlogDecode(red);
  const lg = vlogDecode(green);
  const lb = vlogDecode(blue);
  const m = vgamutToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2])),
  ];
}

// ---------- Sony S-Log3 ----------

/**
 * S-Log3 → linear scene-referred decoder. From Sony's *Technical Summary
 * for S-Gamut3.Cine/S-Log3 and S-Gamut3/S-Log3*. The threshold
 * `171.2102946929 / 1023.0` is the breakpoint between linear toe and log
 * body.
 */
export function slog3Decode(encoded: number): number {
  const threshold = 171.2102946929 / 1023.0;
  if (encoded < threshold) {
    return ((encoded * 1023.0 - 95.0) * 0.01125) / (171.2102946929 - 95.0);
  }
  return Math.pow(10.0, (encoded * 1023.0 - 420.0) / 261.5) * (0.18 + 0.01) - 0.01;
}

/**
 * S-Gamut3.Cine → Rec.709 matrix (precomputed, D65 → D65, no chromatic
 * adaptation).
 */
function sgamut3CineToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  return [
    1.6269 * red - 0.5365 * green - 0.0904 * blue,
    -0.1078 * red + 1.1628 * green - 0.055 * blue,
    -0.014 * red - 0.024 * green + 1.0379 * blue,
  ];
}

export function slog3PixelToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  const lr = slog3Decode(red);
  const lg = slog3Decode(green);
  const lb = slog3Decode(blue);
  const m = sgamut3CineToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2])),
  ];
}

// ---------- Gamut helper ----------

/** Rec.2020 → Rec.709 (D65 → D65, no chromatic adaptation). */
function rec2020ToRec709(
  red: number,
  green: number,
  blue: number,
): [number, number, number] {
  return [
    1.6605 * red - 0.5876 * green - 0.0728 * blue,
    -0.1246 * red + 1.1329 * green - 0.0083 * blue,
    -0.0182 * red - 0.1006 * green + 1.1187 * blue,
  ];
}

// =====================================================================
// Cube builders — RGBA Float32Array, alpha = 1, sample-major (R fastest)
// =====================================================================

type PixelFn = (r: number, g: number, b: number) => [number, number, number];

function buildCubeRgba(size: number, pixel: PixelFn): Float32Array {
  const denom = size - 1;
  const data = new Float32Array(size * size * size * 4);
  let i = 0;
  for (let bIdx = 0; bIdx < size; bIdx++) {
    const blueIn = bIdx / denom;
    for (let gIdx = 0; gIdx < size; gIdx++) {
      const greenIn = gIdx / denom;
      for (let rIdx = 0; rIdx < size; rIdx++) {
        const redIn = rIdx / denom;
        const out = pixel(redIn, greenIn, blueIn);
        data[i] = out[0];
        data[i + 1] = out[1];
        data[i + 2] = out[2];
        data[i + 3] = 1;
        i += 4;
      }
    }
  }
  return data;
}

export function makeAppleLogToRec709Cube(
  size: number = 33,
  rec2020GamutMap: boolean = false,
): Float32Array {
  return buildCubeRgba(size, (r, g, b) =>
    appleLogPixelToRec709(r, g, b, rec2020GamutMap),
  );
}

export function makeArriLogC3ToRec709Cube(size: number = 33): Float32Array {
  return buildCubeRgba(size, arriLogC3PixelToRec709);
}

export function makeDlogToRec709Cube(size: number = 33): Float32Array {
  return buildCubeRgba(size, dlogPixelToRec709);
}

export function makeDlogMToRec709Cube(size: number = 33): Float32Array {
  return buildCubeRgba(size, dlogMPixelToRec709);
}

export function makeCanonClogToRec709Cube(size: number = 33): Float32Array {
  return buildCubeRgba(size, canonClogPixelToRec709);
}

export function makeCanonLog3CineGamutToRec709Cube(
  size: number = 33,
): Float32Array {
  return buildCubeRgba(size, canonLog3CineGamutPixelToRec709);
}

export function makeVlogToRec709Cube(size: number = 33): Float32Array {
  return buildCubeRgba(size, vlogPixelToRec709);
}

export function makeSlog3ToRec709Cube(size: number = 33): Float32Array {
  return buildCubeRgba(size, slog3PixelToRec709);
}
