/**
 * Adobe `.cube` text serializer. Produces output that round-trips through
 * `cube-parser.ts` byte-identically (modulo float text precision). Used by
 * the v1.4 Creative LUT Pack baker to emit bundled cube assets.
 *
 * Format reference: Adobe Cube LUT Specification 1.0 (2013).
 */

import type { CreativeCube } from "./creative-cube";

const DEFAULT_PRECISION = 6;

export interface SerializeCubeOptions {
  /** Single-line title comment emitted as `TITLE "<value>"`. */
  title: string;
  /** Decimal places per channel value. Default 6 (matches IWLTBAP / Lattice). */
  precision?: number;
  /** Trailing comment lines emitted before the data (each prefixed by `# `). */
  comments?: string[];
}

function formatFloat(value: number, precision: number): string {
  // Negative zero is encoded as `0.000000` (matches Adobe / DaVinci output).
  const cleaned = Object.is(value, -0) ? 0 : value;
  return cleaned.toFixed(precision);
}

/**
 * Serialize a `CreativeCube` to Adobe `.cube` text. Emits the header
 * (TITLE / LUT_3D_SIZE / DOMAIN_MIN / DOMAIN_MAX) followed by R-fastest
 * RGB triples, one per line. Trailing newline included.
 */
export function serializeCreativeCubeToText(
  cube: CreativeCube,
  options: SerializeCubeOptions,
): string {
  const precision = options.precision ?? DEFAULT_PRECISION;
  const lines: string[] = [];
  lines.push(`TITLE "${options.title.replace(/"/g, "")}"`);
  if (options.comments && options.comments.length > 0) {
    for (const comment of options.comments) {
      lines.push(`# ${comment}`);
    }
  }
  lines.push(`LUT_3D_SIZE ${cube.size}`);
  lines.push("DOMAIN_MIN 0.0 0.0 0.0");
  lines.push("DOMAIN_MAX 1.0 1.0 1.0");
  lines.push("");

  const total = cube.size * cube.size * cube.size;
  for (let i = 0; i < total; i++) {
    const idx = i * 3;
    const r = formatFloat(cube.data[idx + 0], precision);
    const g = formatFloat(cube.data[idx + 1], precision);
    const b = formatFloat(cube.data[idx + 2], precision);
    lines.push(`${r} ${g} ${b}`);
  }
  lines.push("");
  return lines.join("\n");
}
