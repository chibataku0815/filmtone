/**
 * Procedural fullscreen-triangle vertex shader.
 *
 * Phase 1 T1-3. Replaces the GLSL `filmlab.vert` buffer-based quad with a
 * WebGPU-idiomatic vertex-less triangle. Covers the entire clip-space
 * rectangle with exactly 3 vertices (no buffer binding needed).
 *
 * uFlipY is a `0 or 1` toggle (matching the GLSL version's semantics) and
 * lives on the per-frame uniform struct — see `WebGPUBackend` bind group 0.
 *
 * Entry: `vs_main` returns `VsOut { @builtin(position), @location(0) uv }`.
 */
export const fullscreenVertexWgsl = /* wgsl */ `
struct VsOut {
  @builtin(position) pos: vec4f,
  @location(0) uv: vec2f,
};

struct FrameFlags {
  flipY: f32,
  _pad0: f32,
  _pad1: f32,
  _pad2: f32,
};

@group(0) @binding(0) var<uniform> uFlags: FrameFlags;

@vertex
fn vs_main(@builtin(vertex_index) vi: u32) -> VsOut {
  // Three-vertex fullscreen triangle: the triangle covers the full
  // [-1..3] clip rectangle; the GPU rasterizer clips everything outside
  // [-1..1], so the visible region is exactly the viewport.
  let x = f32(((vi << 1u) & 2u)) * 2.0 - 1.0;
  let y = f32((vi & 2u)) * 2.0 - 1.0;
  let uvRaw = vec2f(x * 0.5 + 0.5, y * 0.5 + 0.5);
  let uv = vec2f(uvRaw.x, mix(uvRaw.y, 1.0 - uvRaw.y, uFlags.flipY));

  var out: VsOut;
  out.pos = vec4f(x, y, 0.0, 1.0);
  out.uv = uv;
  return out;
}
`;
