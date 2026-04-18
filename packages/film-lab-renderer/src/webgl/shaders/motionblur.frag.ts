/**
 * Feedback copy shader — writes sourceTexture into a ring buffer slot,
 * optionally mixing in the previous slot for extended trail effect.
 * uTrail=0: pure passthrough. uTrail=0.9: long afterimage tail.
 */
export const feedbackCopyFragmentShader = /* glsl */ `
precision highp float;
uniform sampler2D uSource;
uniform sampler2D uPrevSlot;
uniform float uTrail; // 0.0=clean copy, 0.0-0.95=feedback intensity
in vec2 vUv;
out vec4 fragColor;
void main() {
  vec4 src = texture(uSource, vUv);
  vec4 prev = texture(uPrevSlot, vUv);
  fragColor = mix(src, prev, uTrail);
}
`;

/**
 * Motion blur shader — N-frame ring buffer weighted average
 * with inline motion detection (branchless oldest-frame selection).
 *
 * CPU supplies pre-normalized weights (sum=1.0 for active slots)
 * and uActiveFrames (1..8).
 */
export const motionblurFragmentShader = /* glsl */ `
precision highp float;

// Ring buffer samplers: 0=newest, 7=oldest
uniform sampler2D uFrame0;
uniform sampler2D uFrame1;
uniform sampler2D uFrame2;
uniform sampler2D uFrame3;
uniform sampler2D uFrame4;
uniform sampler2D uFrame5;
uniform sampler2D uFrame6;
uniform sampler2D uFrame7;

// Pre-normalized weights from CPU (sum=1.0 for active slots)
uniform float uWeight0;
uniform float uWeight1;
uniform float uWeight2;
uniform float uWeight3;
uniform float uWeight4;
uniform float uWeight5;
uniform float uWeight6;
uniform float uWeight7;

uniform int uActiveFrames;      // 1..8
uniform float uMotionThreshold; // 0.0=disabled, 0.02-0.05=recommended

in vec2 vUv;
out vec4 fragColor;

float luma709(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
  vec4 f0 = texture(uFrame0, vUv);
  vec4 f1 = texture(uFrame1, vUv);
  vec4 f2 = texture(uFrame2, vUv);
  vec4 f3 = texture(uFrame3, vUv);
  vec4 f4 = texture(uFrame4, vUv);
  vec4 f5 = texture(uFrame5, vUv);
  vec4 f6 = texture(uFrame6, vUv);
  vec4 f7 = texture(uFrame7, vUv);

  // Weighted average
  vec4 blurred =
    f0 * uWeight0 + f1 * uWeight1 + f2 * uWeight2 + f3 * uWeight3 +
    f4 * uWeight4 + f5 * uWeight5 + f6 * uWeight6 + f7 * uWeight7;

  // Inline motion detection: branchless oldest frame selection
  float af = float(uActiveFrames);
  vec4 oldest = f0;
  oldest = mix(oldest, f1, step(2.0, af));
  oldest = mix(oldest, f2, step(3.0, af));
  oldest = mix(oldest, f3, step(4.0, af));
  oldest = mix(oldest, f4, step(5.0, af));
  oldest = mix(oldest, f5, step(6.0, af));
  oldest = mix(oldest, f6, step(7.0, af));
  oldest = mix(oldest, f7, step(8.0, af));

  float lumaDelta = abs(luma709(f0.rgb) - luma709(oldest.rgb));
  float motionMask = (uMotionThreshold > 0.0)
    ? smoothstep(uMotionThreshold * 0.5, uMotionThreshold * 2.0, lumaDelta)
    : 1.0;

  fragColor = mix(f0, blurred, motionMask);
}
`;
