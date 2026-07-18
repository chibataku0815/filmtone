#include "LensSoftnessProcessor.h"

#include <array>
#include <cmath>
#include <cstdint>
#include <string>

namespace filmtone::resolve::effects::lens_softness {
namespace {

constexpr double kLensAmountExponent = 0.78;
constexpr double kBaseRadiusFullResolutionPixels = 1.6;
constexpr double kRadiusBoostFullResolutionPixels = 1.85;
constexpr char kLensSoftnessPipelineCacheKey[] =
    "filmtone.resolve.lens-softness.optical.v1";
constexpr char kLensSoftnessMetalFunction[] =
    "filmtoneLensSoftnessOpticalV1";

constexpr char kLensSoftnessMetalSource[] = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct LensSoftnessUniformsV1 {
    uint width;
    uint height;
    float amount;
    float lensDrive;

    float radiusX;
    float radiusY;
    float canonicalUnitsPerPixelX;
    float canonicalUnitsPerPixelY;

    float halfDiagonalCanonical;
    float padding0;
    float padding1;
    float padding2;
};

constant float2 kLensSoftnessInnerDirectionsV1[8] = {
    float2(1.0f, 0.0f),
    float2(0.7071067812f, 0.7071067812f),
    float2(0.0f, 1.0f),
    float2(-0.7071067812f, 0.7071067812f),
    float2(-1.0f, 0.0f),
    float2(-0.7071067812f, -0.7071067812f),
    float2(0.0f, -1.0f),
    float2(0.7071067812f, -0.7071067812f),
};

constant float2 kLensSoftnessOuterDirectionsV1[8] = {
    float2(0.9238795325f, 0.3826834324f),
    float2(0.3826834324f, 0.9238795325f),
    float2(-0.3826834324f, 0.9238795325f),
    float2(-0.9238795325f, 0.3826834324f),
    float2(-0.9238795325f, -0.3826834324f),
    float2(-0.3826834324f, -0.9238795325f),
    float2(0.3826834324f, -0.9238795325f),
    float2(0.9238795325f, -0.3826834324f),
};

float3 sampleLensSoftnessBilinearClampV1(
    texture2d<float, access::read> source,
    float2 position) {
    const int2 maximum = int2(
        int(source.get_width()) - 1,
        int(source.get_height()) - 1);
    const float2 safePosition = clamp(
        position,
        float2(0.0f),
        float2(maximum));
    const int2 base = int2(floor(safePosition));
    const int2 next = min(base + int2(1), maximum);
    const float2 fraction = safePosition - float2(base);

    const float3 row0 = mix(
        source.read(uint2(base)).rgb,
        source.read(uint2(next.x, base.y)).rgb,
        fraction.x);
    const float3 row1 = mix(
        source.read(uint2(base.x, next.y)).rgb,
        source.read(uint2(next)).rgb,
        fraction.x);
    return mix(row0, row1, fraction.y);
}

kernel void filmtoneLensSoftnessOpticalV1(
    texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant LensSoftnessUniformsV1& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) {
        return;
    }

    const float4 sourceColor = source.read(gid);
    if (uniforms.amount <= 0.0f) {
        output.write(sourceColor, gid);
        return;
    }

    const float2 centeredCanonical =
        (float2(gid) + 0.5f -
         float2(float(uniforms.width), float(uniforms.height)) * 0.5f) *
        float2(
            uniforms.canonicalUnitsPerPixelX,
            uniforms.canonicalUnitsPerPixelY);
    const float radial = clamp(
        length(centeredCanonical) / uniforms.halfDiagonalCanonical,
        0.0f,
        1.0f);

    // Frozen native half-diagonal peripheral response. It leaves the optical
    // center coherent, grows continuously through the field, and prevents the
    // feature from becoming a uniform full-frame blur.
    const float edgeMask = smoothstep(0.25f, 1.0f, radial);
    const float lensWeight = clamp(
        uniforms.lensDrive * pow(radial, 1.52f),
        0.0f,
        1.0f);
    const float softenAmount = lensWeight * 0.72f * edgeMask;
    if (softenAmount <= 0.0f) {
        output.write(sourceColor, gid);
        return;
    }

    const float2 position = float2(gid);
    const float2 radius = float2(uniforms.radiusX, uniforms.radiusY);

    // Two rotated rings approximate a compact optical point-spread function.
    // All weights are exact binary fractions and sum to one: DC/flat-field
    // energy remains unchanged before the spatial blend.
    float3 filtered = sourceColor.rgb * 0.25f;
    for (uint index = 0u; index < 8u; ++index) {
        filtered += sampleLensSoftnessBilinearClampV1(
            source,
            position +
                kLensSoftnessInnerDirectionsV1[index] * radius * 0.45f) *
            0.0625f;
        filtered += sampleLensSoftnessBilinearClampV1(
            source,
            position + kLensSoftnessOuterDirectionsV1[index] * radius) *
            0.03125f;
    }

    const float3 result = mix(sourceColor.rgb, filtered, softenAmount);

    // RGB remains unclamped. Alpha is the exact center/source alpha rather
    // than a filtered or spatially attenuated value.
    output.write(float4(result, sourceColor.a), gid);
}
)METAL";

struct alignas(16) LensSoftnessUniformsV1 final {
    std::uint32_t width;
    std::uint32_t height;
    float amount;
    float lensDrive;

    float radiusX;
    float radiusY;
    float canonicalUnitsPerPixelX;
    float canonicalUnitsPerPixelY;

    float halfDiagonalCanonical;
    float padding0;
    float padding1;
    float padding2;
};

static_assert(sizeof(LensSoftnessUniformsV1) == 48u);
static_assert(alignof(LensSoftnessUniformsV1) == 16u);

bool isPositiveFinite(double value) noexcept {
    return std::isfinite(value) && value > 0.0;
}

bool makeUniforms(
    const spatial::LensSoftnessParameterViewV1& parameters,
    const host::spatial::SpatialFrameDescriptor& frame,
    LensSoftnessUniformsV1& uniforms,
    std::string& error) {
    if (!parameters.active || !std::isfinite(parameters.amount) ||
        parameters.amount <= 0.0f || parameters.amount > 1.0f) {
        error = "Lens Softness requires an active frozen parameter view.";
        return false;
    }
    if (frame.width == 0u || frame.height == 0u ||
        !isPositiveFinite(frame.renderScaleX) ||
        !isPositiveFinite(frame.renderScaleY) ||
        !isPositiveFinite(frame.canonicalUnitsPerPixelX) ||
        !isPositiveFinite(frame.canonicalUnitsPerPixelY)) {
        error = "Lens Softness received invalid spatial frame semantics.";
        return false;
    }

    const double lensDrive = std::pow(
        static_cast<double>(parameters.amount),
        kLensAmountExponent);
    const double fullResolutionRadius =
        kBaseRadiusFullResolutionPixels +
        lensDrive * kRadiusBoostFullResolutionPixels;
    const double radiusX = fullResolutionRadius * frame.renderScaleX;
    const double radiusY = fullResolutionRadius * frame.renderScaleY;
    const double halfWidthCanonical =
        static_cast<double>(frame.width) * 0.5 *
        frame.canonicalUnitsPerPixelX;
    const double halfHeightCanonical =
        static_cast<double>(frame.height) * 0.5 *
        frame.canonicalUnitsPerPixelY;
    const double halfDiagonalCanonical = std::hypot(
        halfWidthCanonical,
        halfHeightCanonical);
    if (!isPositiveFinite(lensDrive) ||
        !isPositiveFinite(fullResolutionRadius) ||
        !isPositiveFinite(radiusX) || !isPositiveFinite(radiusY) ||
        !isPositiveFinite(halfDiagonalCanonical)) {
        error = "Lens Softness could not derive a finite radius or optical field.";
        return false;
    }

    uniforms = LensSoftnessUniformsV1{
        frame.width,
        frame.height,
        parameters.amount,
        static_cast<float>(lensDrive),
        static_cast<float>(radiusX),
        static_cast<float>(radiusY),
        static_cast<float>(frame.canonicalUnitsPerPixelX),
        static_cast<float>(frame.canonicalUnitsPerPixelY),
        static_cast<float>(halfDiagonalCanonical),
        0.0f,
        0.0f,
        0.0f,
    };
    if (!std::isfinite(uniforms.lensDrive) || uniforms.lensDrive <= 0.0f ||
        !std::isfinite(uniforms.radiusX) || uniforms.radiusX <= 0.0f ||
        !std::isfinite(uniforms.radiusY) || uniforms.radiusY <= 0.0f ||
        !std::isfinite(uniforms.canonicalUnitsPerPixelX) ||
        uniforms.canonicalUnitsPerPixelX <= 0.0f ||
        !std::isfinite(uniforms.canonicalUnitsPerPixelY) ||
        uniforms.canonicalUnitsPerPixelY <= 0.0f ||
        !std::isfinite(uniforms.halfDiagonalCanonical) ||
        uniforms.halfDiagonalCanonical <= 0.0f) {
        error = "Lens Softness uniforms exceed the Metal float range.";
        return false;
    }
    return true;
}

}  // namespace

LensSoftnessProcessor::LensSoftnessProcessor(
    const spatial::FilmtoneSpatialParametersV1& parameters) noexcept
    : parameters_(spatial::makeLensSoftnessParameterViewV1(parameters)) {}

const spatial::LensSoftnessParameterViewV1&
LensSoftnessProcessor::parameters() const noexcept {
    return parameters_;
}

const char* LensSoftnessProcessor::name() const noexcept {
    return "Lens Softness";
}

bool LensSoftnessProcessor::isIdentity(
    const host::RenderContext& context) const noexcept {
    static_cast<void>(context);
    return !parameters_.active;
}

bool LensSoftnessProcessor::makeResourcePlan(
    const host::RenderContext& context,
    const host::spatial::SpatialFrameDescriptor& frame,
    host::spatial::SpatialResourcePlan& plan,
    std::string& error) const {
    if (isIdentity(context)) {
        error = "Identity Lens Softness must be filtered before resource planning.";
        return false;
    }

    LensSoftnessUniformsV1 uniforms{};
    if (!makeUniforms(parameters_, frame, uniforms, error)) {
        return false;
    }

    plan = host::spatial::SpatialResourcePlan{
        host::spatial::kSpatialModuleAbiVersion,
        1u,
        1u,
        host::spatial::SpatialEdgeMode::clampToEdge,
        true,
        true,
        true,
    };
    return true;
}

bool LensSoftnessProcessor::encodeSpatialMetal(
    const host::RenderContext& context,
    const host::spatial::SpatialEncodeInvocation& invocation,
    std::string& error) const {
    if (isIdentity(context)) {
        error = "Identity Lens Softness must not enter spatial encoding.";
        return false;
    }

    LensSoftnessUniformsV1 uniforms{};
    if (!makeUniforms(parameters_, invocation.frame, uniforms, error)) {
        return false;
    }
    if (invocation.source.width != invocation.frame.width ||
        invocation.source.height != invocation.frame.height ||
        invocation.output.width != invocation.frame.width ||
        invocation.output.height != invocation.frame.height ||
        invocation.source.mipLevel != 0u ||
        invocation.output.mipLevel != 0u) {
        error = "Lens Softness requires full-resolution spatial source and output views.";
        return false;
    }

    const std::array<host::spatial::SpatialTextureBinding, 2u>
        textureBindings{{
            {0u, invocation.source,
             host::spatial::SpatialTextureAccess::readOnly},
            {1u, invocation.output,
             host::spatial::SpatialTextureAccess::writeOnly},
        }};
    const host::spatial::SpatialBytesBinding uniformBinding{
        0u,
        &uniforms,
        sizeof(uniforms),
    };
    static const host::MetalPipelineRequest pipelineRequest{
        kLensSoftnessPipelineCacheKey,
        kLensSoftnessMetalSource,
        kLensSoftnessMetalFunction,
        false,
    };
    const host::spatial::SpatialComputePass pass{
        "Filmtone Lens Softness Optical PSF",
        &pipelineRequest,
        textureBindings.data(),
        textureBindings.size(),
        &uniformBinding,
        1u,
        host::spatial::SpatialThreadGrid{
            invocation.frame.width,
            invocation.frame.height,
            1u,
        },
    };
    return invocation.commands.encodeComputePass(pass, error);
}

}  // namespace filmtone::resolve::effects::lens_softness
