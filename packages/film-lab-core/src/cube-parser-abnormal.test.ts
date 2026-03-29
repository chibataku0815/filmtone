/**
 * @fileoverview 壊れた・不完全な `.cube` テキストに対する `parseCube` / `packCubeLutToFloatRgbaGrid` の挙動を固定する。
 *
 * 主な仕様:
 * - 現状の `parseCube` は **例外を投げず**、欠損は 0 埋め・size 未指定は 0 になる。
 * - UI 側で厳密バリデーションを足す前に、**「何が起きるか」**をテストで文書化する。
 *
 * 制限事項:
 * - 本ファイルは挙動の回帰防止用。新規に厳格パースを追加するときは別テストで期待値を更新する。
 */
import { describe, expect, test } from "bun:test";
import { parseCube } from "./cube-parser";
import { packCubeLutToFloatRgbaGrid } from "./lut-pack-2d";

describe("parseCube — 異常・端の入力", () => {
  test("LUT_3D_SIZE が無い場合 size は 0（パックは空グリッド）", () => {
    const text = ["TITLE \"no-size\"", "0 0 0", "1 1 1"].join("\n");
    const lut = parseCube(text);
    expect(lut.size).toBe(0);
    const packed = packCubeLutToFloatRgbaGrid(lut);
    expect(packed.size).toBe(0);
    expect(packed.width).toBe(0);
    expect(packed.height).toBe(0);
    expect(packed.data.length).toBe(0);
  });

  test("RGB 行が足りない場合は 0 でパディングされる（例外なし）", () => {
    const text = [
      "TITLE \"underfill\"",
      "LUT_3D_SIZE 2",
      "0.1 0.0 0.0",
      "0.2 0.0 0.0",
    ].join("\n");
    const lut = parseCube(text);
    expect(lut.size).toBe(2);
    expect(lut.data.length).toBe(2 * 2 * 2 * 4);
    // 先頭テクセルのみ与えた — 残りは parseCube 内の ?? 0 で埋まる
    expect(lut.data[0]).toBeCloseTo(0.1);
    expect(lut.data[1]).toBeCloseTo(0);
    expect(lut.data[2]).toBeCloseTo(0);
    const packed = packCubeLutToFloatRgbaGrid(lut);
    expect(packed.data.length).toBe(4 * 2 * 4);
  });

  test("数値トークンが 2 つだけの行は無視される（3 列未満は values に入らない）", () => {
    const text = [
      "TITLE \"two-cols\"",
      "LUT_3D_SIZE 2",
      "0.5 0.5",
      "0.1 0.2 0.3",
    ].join("\n");
    const lut = parseCube(text);
    expect(lut.size).toBe(2);
    const triples = lut.data.length / 4;
    expect(triples).toBe(8);
    // 最初の有効 RGB 行は 0.1,0.2,0.3 のみ — 先頭テクセルがそれになる
    expect(lut.data[0]).toBeCloseTo(0.1);
  });

  test("4 列以上ある行は先頭 3 要素だけ採用される", () => {
    const text = [
      "TITLE \"extra-col\"",
      "LUT_3D_SIZE 2",
      "0.9 0.8 0.7 0.6",
    ].join("\n");
    const lut = parseCube(text);
    expect(lut.data[0]).toBeCloseTo(0.9);
    expect(lut.data[1]).toBeCloseTo(0.8);
    expect(lut.data[2]).toBeCloseTo(0.7);
  });

  test("空ファイルでも例外は出ず size 0", () => {
    const lut = parseCube("");
    expect(lut.size).toBe(0);
    expect(lut.title).toBe("");
  });

  test("コメント行と空行はスキップされる", () => {
    const text = [
      "# header",
      "",
      "TITLE \"c\"",
      "LUT_3D_SIZE 2",
      "  # inline skipped only at line start",
      "0.25 0.25 0.25",
    ].join("\n");
    const lut = parseCube(text);
    expect(lut.size).toBe(2);
    expect(lut.data[0]).toBeCloseTo(0.25);
  });
});

describe("packCubeLutToFloatRgbaGrid — 異常 LUT との組み合わせ", () => {
  test("size 0 の CubeLUT をパックしても例外にならない", () => {
    const lut = parseCube("TITLE \"x\"");
    expect(lut.size).toBe(0);
    const packed = packCubeLutToFloatRgbaGrid(lut);
    expect(packed.data.length).toBe(0);
  });
});
