#pragma once

namespace filmtone::resolve::effects::peripheral_chromatic_shift::detail {

inline constexpr char kPeripheralChromaticShiftMetalSource[] = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct PeripheralChromaticShiftUniformsV1 {
    uint width;
    uint height;
    float amount;
    float radialExponent;

    float canonicalUnitsPerPixelX;
    float canonicalUnitsPerPixelY;
    float maximumOffsetX;
    float maximumOffsetY;
};

float4 filmtoneSampleClampedBilinearV1(
    texture2d<float, access::read> source,
    float2 position,
    constant PeripheralChromaticShiftUniformsV1& uniforms) {
    const uint2 maximumCoordinate = uint2(
        uniforms.width - 1u,
        uniforms.height - 1u);
    const float2 clampedPosition = clamp(
        position,
        float2(0.0f),
        float2(float(maximumCoordinate.x), float(maximumCoordinate.y)));
    const uint2 lower = uint2(floor(clampedPosition));
    const uint2 upper = min(lower + uint2(1u), maximumCoordinate);
    const float2 fraction = clampedPosition -
        float2(float(lower.x), float(lower.y));

    const float4 lowerRow = mix(
        source.read(uint2(lower.x, lower.y)),
        source.read(uint2(upper.x, lower.y)),
        fraction.x);
    const float4 upperRow = mix(
        source.read(uint2(lower.x, upper.y)),
        source.read(uint2(upper.x, upper.y)),
        fraction.x);
    return mix(lowerRow, upperRow, fraction.y);
}

kernel void filmtonePeripheralChromaticShiftV1(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant PeripheralChromaticShiftUniformsV1& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) {
        return;
    }

    const float2 localPixelCenter =
        float2(float(gid.x) + 0.5f, float(gid.y) + 0.5f);
    const float2 opticalCenter =
        float2(float(uniforms.width), float(uniforms.height)) * 0.5f;
    const float2 canonicalPosition =
        (localPixelCenter - opticalCenter) *
        float2(
            uniforms.canonicalUnitsPerPixelX,
            uniforms.canonicalUnitsPerPixelY);
    const float canonicalDistance = length(canonicalPosition);
    const float2 radialDirection = canonicalDistance > 0.0f
        ? canonicalPosition / canonicalDistance
        : float2(0.0f);
    const float radialWeight = pow(
        clamp(canonicalDistance, 0.0f, 1.0f),
        uniforms.radialExponent);
    const float2 offset = radialDirection * radialWeight *
        float2(uniforms.maximumOffsetX, uniforms.maximumOffsetY);
    const float2 sourcePosition = float2(float(gid.x), float(gid.y));

    const float4 center = source.read(gid);
    const float red = filmtoneSampleClampedBilinearV1(
        source,
        sourcePosition + offset,
        uniforms).r;
    const float blue = filmtoneSampleClampedBilinearV1(
        source,
        sourcePosition - offset,
        uniforms).b;
    output.write(float4(red, center.g, blue, center.a), gid);
}
)METAL";

}  // namespace filmtone::resolve::effects::peripheral_chromatic_shift::detail
