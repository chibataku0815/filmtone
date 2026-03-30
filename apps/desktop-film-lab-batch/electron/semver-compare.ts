/**
 * @file セマンティックバージョン文字列の大小比較（electron-updater なしの最小実装）
 * @overview `1.2.3` 形式を前提に、先頭の数値トークンだけを比較します（ prerelease は文字列として後ろに付く前提で未対応）。
 * @limitations `1.0` と `1.0.0` はトークン数が違うため最後まで 0 埋め相当で比較します。
 */

/**
 * @description 「a が b より新しい」なら正、等しければ 0、古ければ負。
 * @param a 実行中アプリ側の版（例: package.json の version）
 * @param b メタ JSON の latestVersion
 */
export function compareSemverStrings(a: string, b: string): number {
  const parse = (s: string): number[] => {
    const core = s.trim().split(/[-+]/)[0] ?? s;
    const parts = core.split(".").map((p) => {
      const n = Number.parseInt(p.replace(/^\D+/, ""), 10);
      return Number.isFinite(n) ? n : 0;
    });
    return parts.length > 0 ? parts : [0];
  };
  const ap = parse(a);
  const bp = parse(b);
  const len = Math.max(ap.length, bp.length);
  for (let i = 0; i < len; i += 1) {
    const av = ap[i] ?? 0;
    const bv = bp[i] ?? 0;
    if (av > bv) return 1;
    if (av < bv) return -1;
  }
  return 0;
}
