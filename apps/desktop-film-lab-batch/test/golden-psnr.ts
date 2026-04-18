export function psnr(a: Buffer, b: Buffer, width: number, height: number): number {
  if (a.length !== b.length) throw new Error('buffer length mismatch');
  const n = width * height * 3;
  let sse = 0;
  for (let i = 0; i < a.length; i += 4) {
    const dr = a[i]! - b[i]!;
    const dg = a[i + 1]! - b[i + 1]!;
    const db = a[i + 2]! - b[i + 2]!;
    sse += dr * dr + dg * dg + db * db;
  }
  const mse = sse / n;
  return mse === 0 ? Infinity : 10 * Math.log10((255 * 255) / mse);
}
