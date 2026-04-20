/**
 * compare-source.frag (WGSL) — WebGPU compare present pass.
 *
 * Mixes the raw `mediaTexture` and the graded post-composite texture using
 * the current split position, then draws a thin divider line. Wired by
 * `WebGPUBackend.renderFrame` as a replacement for the blit / motion-blur
 * present passes whenever `frameState.compareEnabled` is true. Slot params
 * (paramsA / paramsB) passed through `setComparePair` are still ignored on
 * WebGPU v1 — the visible split compare interaction is restored, but the
 * WebGL dual-slot simultaneous A/B render parity stays deferred.
 *
 * Bind group layout (group 1) — count verified side-by-side with WGSL
 * `@binding(N)` declarations (part-9 §5.3 miscount class of error):
 *   binding(0) uCompare : CompareSource uniform (vec4 × 2 = 32 B)
 *   binding(1) uMedia   : texture_2d<f32>  (rgba8unorm-srgb media tex)
 *   binding(2) uGraded  : texture_2d<f32>  (rgba16float post-composite)
 *   binding(3) uSampler : sampler          (linear, clamp-to-edge)
 *
 * Color management: media is `rgba8unorm-srgb` so `textureSampleLevel`
 * decodes sRGB->linear automatically; the post-composite source is already
 * linear `rgba16float`; the swap chain (`rgba8unorm-srgb`) encodes
 * linear->sRGB on store. No in-shader gamma math.
 */
export const compareSourceFragmentWgsl = /* wgsl */ `
struct CompareSource {
  // (resolutionX, resolutionY, imgResX, imgResY)
  resolution: vec4f,
  // (fitMode, splitPosition, dividerWidthPx, _)
  fit: vec4f,
};

@group(1) @binding(0) var<uniform> uCompare: CompareSource;
@group(1) @binding(1) var uMedia: texture_2d<f32>;
@group(1) @binding(2) var uGraded: texture_2d<f32>;
@group(1) @binding(3) var uSampler: sampler;

fn fitUv(uv: vec2f, resolution: vec2f, imageResolution: vec2f, fitMode: f32) -> vec2f {
  let screenAspect = resolution.x / max(resolution.y, 1.0);
  let imageAspect = imageResolution.x / max(imageResolution.y, 1.0);
  let coverScale = select(
    vec2f(screenAspect / imageAspect, 1.0),
    vec2f(1.0, imageAspect / screenAspect),
    screenAspect > imageAspect,
  );
  let containScale = select(
    vec2f(1.0, imageAspect / screenAspect),
    vec2f(screenAspect / imageAspect, 1.0),
    screenAspect > imageAspect,
  );
  let scale = mix(coverScale, containScale, fitMode);
  var result = (uv - vec2f(0.5)) * scale + vec2f(0.5);
  let narrowPortrait = step(2.0, scale.x) * fitMode;
  result.x = result.x + 0.18 * scale.x * narrowPortrait;
  return result;
}

fn insideUv(uv: vec2f) -> f32 {
  let s = step(vec2f(0.0), uv) * step(uv, vec2f(1.0));
  return s.x * s.y;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let resolution = uCompare.resolution.xy;
  let imageResolution = uCompare.resolution.zw;
  let fitMode = uCompare.fit.x;
  let splitPosition = clamp(uCompare.fit.y, 0.0, 1.0);
  let dividerWidthUv = max(uCompare.fit.z, 1.0) / max(resolution.x, 1.0);
  let mediaUv = fitUv(uv, resolution, imageResolution, fitMode);
  let inside = insideUv(mediaUv);
  let beforeColor = textureSampleLevel(uMedia, uSampler, mediaUv, 0.0).rgb * inside;
  let gradedColor = textureSampleLevel(uGraded, uSampler, uv, 0.0).rgb;
  let baseColor = select(beforeColor, gradedColor, uv.x >= splitPosition);
  let dividerMask = 1.0 - step(0.5 * dividerWidthUv, abs(uv.x - splitPosition));
  let dividerColor = vec3f(1.0, 0.82, 0.18);
  let mixed = mix(baseColor, dividerColor, dividerMask);
  return vec4f(mixed, 1.0);
}
`;
