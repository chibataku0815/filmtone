/**
 * Passthrough blit (WGSL) — writes an `rgba16float` offscreen texture to
 * the swapchain (`rgba8unorm-srgb`). The hardware OETF does the final
 * linear → sRGB transform, so the shader itself stays linear.
 *
 * Phase 2 T2-1: used as the final present pass while composite.wgsl is
 * still being authored (T2-3). Once composite is live, this shader goes
 * away and composite writes directly to the swapchain.
 */
export const blitFragmentWgsl = /* wgsl */ `
@group(1) @binding(0) var uSource: texture_2d<f32>;
@group(1) @binding(1) var uSampler: sampler;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  return textureSampleLevel(uSource, uSampler, uv, 0.0);
}
`;
