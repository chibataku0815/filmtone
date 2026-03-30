/**
 * @file semver 比較のユニットテスト
 */
import { describe, expect, it } from "vitest";
import { compareSemverStrings } from "./semver-compare";

describe("compareSemverStrings", () => {
  it("新しいパッチは正", () => {
    expect(compareSemverStrings("0.1.1", "0.1.0")).toBe(1);
  });
  it("同版は 0", () => {
    expect(compareSemverStrings("1.0.0", "1.0.0")).toBe(0);
  });
  it("古い版は負", () => {
    expect(compareSemverStrings("0.1.0", "0.2.0")).toBe(-1);
  });
  it("欠けたトークンは 0 相当で埋める", () => {
    expect(compareSemverStrings("1.0.1", "1.0")).toBe(1);
  });
});
