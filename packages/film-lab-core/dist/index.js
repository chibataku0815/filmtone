// src/params.ts
var PARAM_KEYS = [
  "exposure",
  "contrast",
  "saturation",
  "temperature",
  "tint",
  "rgbShift",
  "grainIntensity",
  "vignette",
  "bloomThreshold",
  "bloomStrength",
  "bloomRadius",
  "halationIntensity",
  "halationSpread",
  "halationHue",
  "fade",
  "highlights",
  "shadows",
  "shadowTone",
  "highlightTone",
  "shadowHue",
  "highlightHue"
];
function cloneParams(params) {
  return { ...params };
}

// src/split-tone-default-hues.ts
var LEGACY_SHADOW_DIR = [0.12, 0.18, 0.42];
var LEGACY_HIGHLIGHT_DIR = [0.38, 0.16, 0.06];
function hslToRgb01(hDegrees, s, l) {
  const hNorm = (hDegrees % 360 + 360) % 360 / 360;
  if (s <= 0) {
    return { r: l, g: l, b: l };
  }
  const hue2rgb = (p2, q2, t) => {
    let tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return p2 + (q2 - p2) * 6 * tt;
    if (tt < 1 / 2) return q2;
    if (tt < 2 / 3) return p2 + (q2 - p2) * (2 / 3 - tt) * 6;
    return p2;
  };
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  const r = hue2rgb(p, q, hNorm + 1 / 3);
  const g = hue2rgb(p, q, hNorm);
  const b = hue2rgb(p, q, hNorm - 1 / 3);
  return { r, g, b };
}
function chromaUnitFromHueDegrees(hueDegrees) {
  const { r, g, b } = hslToRgb01(hueDegrees, 1, 0.5);
  let x = r - 0.5;
  let y = g - 0.5;
  let z2 = b - 0.5;
  const len = Math.hypot(x, y, z2);
  if (len < 1e-9) {
    return [0, 0, 1];
  }
  const inv = 1 / len;
  return [x * inv, y * inv, z2 * inv];
}
function nearestHueDegreesToDirection(dir) {
  const [dx0, dy0, dz0] = dir;
  const len = Math.hypot(dx0, dy0, dz0);
  if (len < 1e-12) {
    return 0;
  }
  const dx = dx0 / len;
  const dy = dy0 / len;
  const dz = dz0 / len;
  let bestHue = 0;
  let bestDot = -2;
  for (let h = 0; h < 360; h += 1) {
    const [ux, uy, uz] = chromaUnitFromHueDegrees(h);
    const dot = ux * dx + uy * dy + uz * dz;
    if (dot > bestDot) {
      bestDot = dot;
      bestHue = h;
    }
  }
  return bestHue;
}
var FILM_LAB_DEFAULT_SHADOW_HUE = nearestHueDegreesToDirection(LEGACY_SHADOW_DIR);
var FILM_LAB_DEFAULT_HIGHLIGHT_HUE = nearestHueDegreesToDirection(LEGACY_HIGHLIGHT_DIR);
var LEGACY_SHADOW_TONE_MAGNITUDE = Math.hypot(...LEGACY_SHADOW_DIR);
var LEGACY_HIGHLIGHT_TONE_MAGNITUDE = Math.hypot(...LEGACY_HIGHLIGHT_DIR);

// src/presets.ts
var PRESETS = {
  reset: {
    exposure: 0,
    contrast: 1,
    saturation: 1,
    temperature: 0,
    tint: 0,
    rgbShift: 0,
    grainIntensity: 0,
    vignette: 0,
    bloomThreshold: 0.8,
    bloomStrength: 0,
    bloomRadius: 0.4,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    fade: 0,
    highlights: 0,
    shadows: 0,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE
  },
  /**
   * cinematic プリセット（v2・2026-03-31）
   * @description 初見のフィルター感とシアン肌を抑えつつ Teal & Orange の意図は維持。変更理由はリポ外ドキュメントに記載可。
   */
  cinematic: {
    exposure: 0.09,
    contrast: 1.24,
    saturation: 0.87,
    temperature: -0.11,
    tint: 0,
    rgbShift: 2e-3,
    grainIntensity: 0.07,
    vignette: 0.32,
    bloomThreshold: 0.86,
    bloomStrength: 0.24,
    bloomRadius: 0.48,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    fade: 0.025,
    highlights: -0.08,
    shadows: -0.11,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE
  },
  portra: {
    exposure: 0.2,
    contrast: 1.1,
    saturation: 0.9,
    temperature: 0.1,
    tint: 0,
    rgbShift: 0,
    grainIntensity: 0.12,
    vignette: 0.2,
    bloomThreshold: 0.7,
    bloomStrength: 0.15,
    bloomRadius: 0.3,
    halationIntensity: 0.25,
    halationSpread: 20,
    halationHue: 20,
    fade: 0.05,
    highlights: 0,
    shadows: 0.1,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE
  },
  gold200: {
    exposure: 0.15,
    contrast: 1.2,
    saturation: 1.15,
    temperature: 0.18,
    tint: 0,
    rgbShift: 12e-4,
    grainIntensity: 0.1,
    vignette: 0.25,
    bloomThreshold: 0.75,
    bloomStrength: 0.2,
    bloomRadius: 0.35,
    halationIntensity: 0.15,
    halationSpread: 18,
    halationHue: 30,
    fade: 0.03,
    highlights: 0.05,
    shadows: 0,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE
  },
  pro400h: {
    exposure: 0.25,
    contrast: 1.05,
    saturation: 0.85,
    temperature: -0.1,
    tint: 0,
    rgbShift: 0,
    grainIntensity: 0.06,
    vignette: 0.15,
    bloomThreshold: 0.65,
    bloomStrength: 0.1,
    bloomRadius: 0.45,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    fade: 0.08,
    highlights: 0.05,
    shadows: 0.15,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE
  },
  bw: {
    exposure: 0.1,
    contrast: 1.4,
    saturation: 0,
    temperature: 0,
    tint: 0,
    rgbShift: 0,
    grainIntensity: 0.15,
    vignette: 0.5,
    bloomThreshold: 0.75,
    bloomStrength: 0.2,
    bloomRadius: 0.6,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    fade: 0.02,
    highlights: -0.1,
    shadows: -0.1,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE
  },
  ektar100: {
    exposure: 0.05,
    contrast: 1.25,
    saturation: 1.3,
    temperature: 0.02,
    tint: 0,
    rgbShift: 0,
    grainIntensity: 0.04,
    vignette: 0.15,
    bloomThreshold: 0.85,
    bloomStrength: 0.1,
    bloomRadius: 0.3,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    fade: 0,
    highlights: 0.1,
    shadows: -0.1,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE
  },
  superia400: {
    exposure: 0.1,
    contrast: 1.18,
    saturation: 1.08,
    temperature: -0.08,
    tint: 0,
    rgbShift: 0,
    grainIntensity: 0.1,
    vignette: 0.2,
    bloomThreshold: 0.8,
    bloomStrength: 0.1,
    bloomRadius: 0.35,
    halationIntensity: 0.1,
    halationSpread: 15,
    halationHue: 10,
    fade: 0.04,
    highlights: 0,
    shadows: 0.05,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE
  },
  cinestill800t: {
    exposure: 0.15,
    contrast: 1.15,
    saturation: 0.95,
    temperature: -0.3,
    tint: 0,
    rgbShift: 115e-5,
    grainIntensity: 0.12,
    vignette: 0.3,
    bloomThreshold: 0.6,
    bloomStrength: 0.35,
    bloomRadius: 0.5,
    halationIntensity: 0.4,
    halationSpread: 25,
    halationHue: 15,
    fade: 0.03,
    highlights: -0.05,
    shadows: 0,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE
  }
};

// src/look-ids.ts
var PRESET_VERSION = "v1";
function lookIdForPreset(name) {
  return `look:mp:${String(name)}:${PRESET_VERSION}`;
}
var LOOK_ID_BY_PRESET = {
  reset: lookIdForPreset("reset"),
  cinematic: lookIdForPreset("cinematic"),
  portra: lookIdForPreset("portra"),
  gold200: lookIdForPreset("gold200"),
  pro400h: lookIdForPreset("pro400h"),
  bw: lookIdForPreset("bw"),
  ektar100: lookIdForPreset("ektar100"),
  superia400: lookIdForPreset("superia400"),
  cinestill800t: lookIdForPreset("cinestill800t")
};

// src/schema.ts
import { z } from "zod";
var paramShape = Object.fromEntries(
  PARAM_KEYS.map((key) => [key, z.number()])
);
var filmLabParamsSchema = z.object(paramShape);
var filmLookGradeInputSchema = z.object({
  lookPresetId: z.string().min(1),
  presetVersion: z.literal(PRESET_VERSION),
  grade: filmLabParamsSchema,
  /**
   * Remotion `public/` からの相対パス（例: `luts/warm-cinematic.cube`）。
   * 未指定のときは LUT をかけない。
   */
  lutCubeRelPath: z.string().min(1).optional(),
  /** `false` のとき `lutCubeRelPath` があっても LUT を無効化する。未指定は `true` 扱い。 */
  lutEnabled: z.boolean().optional(),
  /** ブラウザ Film Lab の `uLUTIntensity` に相当（0〜1）。未指定は `1`。 */
  lutIntensity: z.number().min(0).max(1).optional(),
  /**
   * Remotion `public/` 内の動画（.mov / .mp4 等）。
   * 指定時は `film-lab-default.jpg` の代わりにフレームをテクスチャに焼く（`@remotion/media`）。
   */
  gradeSourceVideoRelPath: z.string().min(1).optional(),
  /** 動画の実ピクセル幅（アスペクト・cover 用）。未指定は 3840（4K 横想定）。 */
  gradeSourceVideoWidth: z.number().int().positive().max(7680).optional(),
  /** 動画の実ピクセル高さ。未指定は 2160。 */
  gradeSourceVideoHeight: z.number().int().positive().max(4320).optional()
});
var filmLookSpikeInputSchema = z.object({
  title: z.string().min(1)
});
function gradeMatchesPreset(presetName, grade) {
  const expected = PRESETS[presetName];
  return PARAM_KEYS.every((key) => grade[key] === expected[key]);
}

// src/cube-parser.ts
function parseCube(text) {
  const lines = text.split("\n");
  let title = "";
  let size = 0;
  let domainMin = [0, 0, 0];
  let domainMax = [1, 1, 1];
  const values = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed === "" || trimmed.startsWith("#")) continue;
    if (trimmed.startsWith("TITLE")) {
      title = trimmed.replace(/^TITLE\s+"?/, "").replace(/"$/, "");
    } else if (trimmed.startsWith("LUT_3D_SIZE")) {
      size = parseInt(trimmed.split(/\s+/)[1] ?? "0", 10);
    } else if (trimmed.startsWith("DOMAIN_MIN")) {
      const p = trimmed.split(/\s+/);
      domainMin = [
        parseFloat(p[1] ?? "0"),
        parseFloat(p[2] ?? "0"),
        parseFloat(p[3] ?? "0")
      ];
    } else if (trimmed.startsWith("DOMAIN_MAX")) {
      const p = trimmed.split(/\s+/);
      domainMax = [
        parseFloat(p[1] ?? "1"),
        parseFloat(p[2] ?? "1"),
        parseFloat(p[3] ?? "1")
      ];
    } else {
      const p = trimmed.split(/\s+/);
      if (p.length >= 3) {
        values.push(
          parseFloat(p[0] ?? "0"),
          parseFloat(p[1] ?? "0"),
          parseFloat(p[2] ?? "0")
        );
      }
    }
  }
  const total = size * size * size;
  const data = new Float32Array(total * 4);
  for (let i = 0; i < total; i++) {
    data[i * 4 + 0] = values[i * 3 + 0] ?? 0;
    data[i * 4 + 1] = values[i * 3 + 1] ?? 0;
    data[i * 4 + 2] = values[i * 3 + 2] ?? 0;
    data[i * 4 + 3] = 1;
  }
  return { title, size, domainMin, domainMax, data };
}

// src/lut-pack-2d.ts
function packCubeLutToFloatRgbaGrid(lut) {
  const n = lut.size;
  const width = n * n;
  const height = n;
  const data = new Float32Array(width * height * 4);
  const src = lut.data;
  for (let b = 0; b < n; b++) {
    for (let g = 0; g < n; g++) {
      for (let r = 0; r < n; r++) {
        const idx = r + n * g + n * n * b;
        const sx = idx * 4;
        const x = r + g * n;
        const y = b;
        const dst = (y * width + x) * 4;
        data[dst] = src[sx] ?? 0;
        data[dst + 1] = src[sx + 1] ?? 0;
        data[dst + 2] = src[sx + 2] ?? 0;
        data[dst + 3] = src[sx + 3] ?? 1;
      }
    }
  }
  return { width, height, size: n, data };
}

// src/defaults.ts
var filmLookSpikeDefaultProps = {
  title: "Film Lab \xD7 Remotion"
};
function createDefaultFilmLookGradeProps() {
  const grade = cloneParams(PRESETS.cinematic);
  return {
    lookPresetId: LOOK_ID_BY_PRESET.cinematic,
    presetVersion: PRESET_VERSION,
    grade
  };
}
var filmLookGradeDefaultProps = createDefaultFilmLookGradeProps();
export {
  FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  FILM_LAB_DEFAULT_SHADOW_HUE,
  LEGACY_HIGHLIGHT_TONE_MAGNITUDE,
  LEGACY_SHADOW_TONE_MAGNITUDE,
  LOOK_ID_BY_PRESET,
  PARAM_KEYS,
  PRESETS,
  PRESET_VERSION,
  chromaUnitFromHueDegrees,
  cloneParams,
  createDefaultFilmLookGradeProps,
  filmLabParamsSchema,
  filmLookGradeDefaultProps,
  filmLookGradeInputSchema,
  filmLookSpikeDefaultProps,
  filmLookSpikeInputSchema,
  gradeMatchesPreset,
  hslToRgb01,
  lookIdForPreset,
  nearestHueDegreesToDirection,
  packCubeLutToFloatRgbaGrid,
  parseCube
};
