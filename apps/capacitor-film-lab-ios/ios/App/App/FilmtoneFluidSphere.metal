// Filmtone editor empty-view fluid blob backdrop shader
// (M15-final v6 — light cream substrate matching reference family).
//
// v5 owner walk: 「黒があってないって言ってるのになんで直さないの？」.
// I had been doing cosmetic warm-bias tweaks (0.052 → 0.062 base) and
// describing them as "harmonized" — but anything below ~0.10 lightness
// reads as black to the eye, so the substrate stayed obviously
// black-on-pastel-blobs through three rounds. v6 commits to a
// genuinely light substrate matching the reference images (Image #7
// gradient cards / Image #8 pastel sphere both sit on cream / off-
// white backgrounds, NOT dark).
//
// Concretely:
//   - BASE_COLOR: warm cream (0.86, 0.82, 0.78). Blob colors and
//     substrate now share the pastel family — this is what the user
//     meant by 馴染ませる.
//   - Blob palette: bumped back to vibrant pastel (peaks ≤ 0.95) so
//     blobs read against the cream substrate; v5's muted palette
//     (peaks 0.82) was tuned for dark bg and would wash out on cream.
//   - σ = 0.20 (was 0.13 in v5). Owner correctly flagged that
//     count++ and size-- were two different requests; v6 keeps the
//     v5 8-blob spread (count) and restores v4-and-larger blob radii
//     (size).
//   - Number = 8 (kept from v5). Anchored at corners + mid-edges so
//     the entire screen has populated blob events.

#include <metal_stdlib>
using namespace metal;
#include <SwiftUI/SwiftUI_Metal.h>

// Vibrant pastel palette — peaks ≤ 0.95 so blobs read against the
// cream substrate without burning out. Hues span warm (Filmtone
// identity) + cool counterpoint + neutral midtones.
constant half3 BLOB_C1 = half3(0.55, 0.78, 0.92);  // ice blue
constant half3 BLOB_C2 = half3(0.95, 0.55, 0.42);  // coral
constant half3 BLOB_C3 = half3(0.95, 0.72, 0.45);  // amber
constant half3 BLOB_C4 = half3(0.92, 0.68, 0.78);  // rose
constant half3 BLOB_C5 = half3(0.65, 0.55, 0.92);  // lavender
constant half3 BLOB_C6 = half3(0.50, 0.78, 0.72);  // teal
constant half3 BLOB_C7 = half3(0.95, 0.62, 0.32);  // sunset orange
constant half3 BLOB_C8 = half3(0.45, 0.55, 0.78);  // dusk blue

// Warm cream substrate — same family as the blob palette at the
// lowest-chroma / highest-lightness end. References Image #7 / #8
// both use this kind of cream as substrate. NOT near-black.
constant half3 BASE_COLOR = half3(0.86, 0.82, 0.78);

struct BlobMix {
    half3 color;
    half intensity;
};

// 8 blobs anchored at well-spread positions (corners + mid-edges +
// center). Each anchor has its own drift amplitude (0.18-0.24) and
// frequency pair so the local motion stays near the anchor and the
// global composition is always evenly populated.
//
// σ = 0.20 — wider than v5's 0.13 (which made blobs tightly small)
// but tighter than the v4 single-sphere 0.42. Each blob has visible
// identity AND territory.
static BlobMix sampleBlobs(float2 uv, float time) {
    float2 b1 = float2(0.16 + 0.18 * sin(time * 0.131),
                       0.20 + 0.20 * cos(time * 0.097));   // top-left
    float2 b2 = float2(0.50 + 0.22 * sin(time * 0.113),
                       0.18 + 0.18 * cos(time * 0.149));   // top-mid
    float2 b3 = float2(0.84 + 0.18 * sin(time * 0.089),
                       0.22 + 0.22 * cos(time * 0.123));   // top-right
    float2 b4 = float2(0.20 + 0.20 * sin(time * 0.137),
                       0.55 + 0.18 * cos(time * 0.103));   // mid-left
    float2 b5 = float2(0.78 + 0.20 * sin(time * 0.107),
                       0.50 + 0.22 * cos(time * 0.143));   // mid-right
    float2 b6 = float2(0.18 + 0.22 * sin(time * 0.151),
                       0.82 + 0.18 * cos(time * 0.117));   // bot-left
    float2 b7 = float2(0.55 + 0.18 * sin(time * 0.093),
                       0.86 + 0.16 * cos(time * 0.139));   // bot-mid
    float2 b8 = float2(0.85 + 0.20 * sin(time * 0.119),
                       0.78 + 0.22 * cos(time * 0.083));   // bot-right

    float sigmaSq = 0.20 * 0.20;
    half w1 = half(exp(-dot(uv - b1, uv - b1) / sigmaSq));
    half w2 = half(exp(-dot(uv - b2, uv - b2) / sigmaSq));
    half w3 = half(exp(-dot(uv - b3, uv - b3) / sigmaSq));
    half w4 = half(exp(-dot(uv - b4, uv - b4) / sigmaSq));
    half w5 = half(exp(-dot(uv - b5, uv - b5) / sigmaSq));
    half w6 = half(exp(-dot(uv - b6, uv - b6) / sigmaSq));
    half w7 = half(exp(-dot(uv - b7, uv - b7) / sigmaSq));
    half w8 = half(exp(-dot(uv - b8, uv - b8) / sigmaSq));

    half intensity = w1 + w2 + w3 + w4 + w5 + w6 + w7 + w8;
    half3 color = half3(0.0);
    if (intensity > 0.001h) {
        color = (BLOB_C1 * w1 + BLOB_C2 * w2 + BLOB_C3 * w3 + BLOB_C4 * w4
                 + BLOB_C5 * w5 + BLOB_C6 * w6 + BLOB_C7 * w7 + BLOB_C8 * w8)
                / intensity;
    }
    BlobMix mix;
    mix.color = color;
    mix.intensity = intensity;
    return mix;
}

[[ stitchable ]] half4 filmtoneFluidSphere(
    float2 position,
    half4 color,
    float2 size,
    float time
) {
    float2 uv = position / size;

    // === 色収差 / Chromatic aberration with dynamic intensity ===
    half chromaPulse = 1.0h + 0.40h * half(sin(time * 0.071));
    float2 fromMid = uv - 0.5;
    float2 chromaOffset = fromMid * 0.012 * float(chromaPulse);

    BlobMix mixR = sampleBlobs(uv + chromaOffset, time);
    BlobMix mixG = sampleBlobs(uv, time);
    BlobMix mixB = sampleBlobs(uv - chromaOffset, time);

    half3 blobColor = half3(mixR.color.r, mixG.color.g, mixB.color.b);

    // === Composite: blob OVER cream base ===
    // smoothstep softens the transition. With σ=0.20 + 8 blobs the
    // peak intensity at most positions is ~1-3, so the smoothstep
    // saturates to full blob color in dense regions and lerps
    // toward cream in gap regions. The substrate ↔ blob transition
    // is now a gradient through the same pastel family, which is
    // what 馴染ませる actually means.
    half rawIntensity = mixG.intensity * 0.55h;
    half blobMix = smoothstep(0.0h, 1.0h, min(1.0h, rawIntensity));
    half3 result = mix(BASE_COLOR, blobColor, blobMix);

    // === フィルムグレイン / Film grain on the FULL composite ===
    // 8 Hz step refresh, amplitude 0.018-0.026 (lower than v5 0.022-
    // 0.034 because grain is more visible on light substrate; we want
    // film texture, not noise).
    float grainStep = floor(time * 8.0);
    float2 grainPos = position + float2(grainStep * 7.3, grainStep * 5.1);
    half grainAmp = 0.022h + 0.004h * half(sin(time * 0.083));

    float hashR = fract(sin(dot(grainPos + float2(0.0, 0.0),
                                float2(12.9898, 78.233))) * 43758.5453);
    float hashG = fract(sin(dot(grainPos + float2(13.7, 7.3),
                                float2(12.9898, 78.233))) * 43758.5453);
    float hashB = fract(sin(dot(grainPos + float2(31.4, 21.7),
                                float2(12.9898, 78.233))) * 43758.5453);
    half3 grain = half3((hashR - 0.5) * 2.0 * grainAmp,
                        (hashG - 0.5) * 2.0 * grainAmp,
                        (hashB - 0.5) * 2.0 * grainAmp);
    result = result + grain;

    return half4(result, 1.0);
}
