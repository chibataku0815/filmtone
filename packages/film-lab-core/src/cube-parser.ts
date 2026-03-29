/**
 * .cube LUT パーサ — Film Lab / Remotion で共有（テキスト → Float32Array）
 * 元: apps/web の cube-parser と同一仕様
 */
export interface CubeLUT {
  title: string;
  size: number;
  domainMin: [number, number, number];
  domainMax: [number, number, number];
  data: Float32Array;
}

export function parseCube(text: string): CubeLUT {
  const lines = text.split("\n");
  let title = "";
  let size = 0;
  let domainMin: [number, number, number] = [0, 0, 0];
  let domainMax: [number, number, number] = [1, 1, 1];
  const values: number[] = [];

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
        parseFloat(p[3] ?? "0"),
      ];
    } else if (trimmed.startsWith("DOMAIN_MAX")) {
      const p = trimmed.split(/\s+/);
      domainMax = [
        parseFloat(p[1] ?? "1"),
        parseFloat(p[2] ?? "1"),
        parseFloat(p[3] ?? "1"),
      ];
    } else {
      const p = trimmed.split(/\s+/);
      if (p.length >= 3) {
        values.push(
          parseFloat(p[0] ?? "0"),
          parseFloat(p[1] ?? "0"),
          parseFloat(p[2] ?? "0"),
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
    data[i * 4 + 3] = 1.0;
  }

  return { title, size, domainMin, domainMax, data };
}
