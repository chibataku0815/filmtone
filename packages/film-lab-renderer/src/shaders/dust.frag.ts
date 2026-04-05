export const dustFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uDustTexture;
uniform sampler2D uScratchTexture;
uniform float uDustAmount;
uniform float uScratchAmount;
uniform float uTime;
uniform vec2 uResolution;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 color = texture(uSource, vUv);

  if (uDustAmount > 0.0) {
    vec2 dustUv = vUv * 3.0 + vec2(uTime * 0.02, uTime * 0.015);
    float dust = texture(uDustTexture, dustUv).r;
    vec2 dustUv2 = vUv * 1.7 + vec2(-uTime * 0.013, uTime * 0.009);
    float dust2 = texture(uDustTexture, dustUv2).r;
    float dustCombined = max(dust, dust2 * 0.7);
    vec3 dustColor = vec3(dustCombined * uDustAmount);
    // Screen blend: 1 - (1 - base) * (1 - overlay)
    color.rgb = 1.0 - (1.0 - color.rgb) * (1.0 - dustColor);
  }

  if (uScratchAmount > 0.0) {
    float jitterPhase = floor(uTime * 4.0);
    vec2 scratchUv = vec2(vUv.x * 2.0, vUv.y * 0.5 + jitterPhase * 0.37);
    float scratch = texture(uScratchTexture, scratchUv).r;
    // Additive blend
    color.rgb += vec3(scratch * uScratchAmount * 0.6);
  }

  color.rgb = clamp(color.rgb, 0.0, 1.0);
  fragColor = color;
}
`;
