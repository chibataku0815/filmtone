#import <Metal/Metal.h>

#include "GateWeaveProcessor.h"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>

#include "../../Host/MetalIdentityBlit.h"
#include "../../Host/MetalPipelineCache.h"

namespace filmtone::resolve::gate_weave {
namespace {

constexpr std::size_t kFloatRGBABytesPerPixel = sizeof(float) * 4u;
constexpr double kDegreesToRadians =
    0.017453292519943295769236907684886;
constexpr double kCubicFootprintEpsilonPixels = 0.001;
constexpr char kPipelineCacheKey[] =
    "filmtone.finish.gate-weave.catmull-rom.v1";
constexpr char kMetalFunctionName[] = "filmtoneGateWeaveWarp";

constexpr char kMetalSource[] = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct GateWeaveUniforms {
    int renderOriginX;
    int renderOriginY;
    uint renderWidth;
    uint renderHeight;

    int sourceOriginX;
    int sourceOriginY;
    uint sourceWidth;
    uint sourceHeight;

    int outputOriginX;
    int outputOriginY;
    uint sourceStridePixels;
    uint outputStridePixels;

    float centerX;
    float centerY;
    float renderScaleX;
    float renderScaleY;

    float translationX;
    float translationY;
    float cosRotation;
    float sinRotation;

    float inverseCropScale;
    float padding0;
    float padding1;
    float padding2;
};

float catmullRomWeight(float value) {
    const float distance = abs(value);
    if (distance <= 1.0f) {
        return ((1.5f * distance - 2.5f) * distance) * distance + 1.0f;
    }
    if (distance < 2.0f) {
        return ((-0.5f * distance + 2.5f) * distance - 4.0f) * distance + 2.0f;
    }
    return 0.0f;
}

float4 loadSource(
    device const float4* source,
    int x,
    int y,
    constant GateWeaveUniforms& uniforms) {
    // The automatic crop keeps valid renders away from this defensive clamp;
    // it exists only to make sub-ulp coordinate drift memory-safe.
    const int safeX = clamp(x, 0, int(uniforms.sourceWidth) - 1);
    const int safeY = clamp(y, 0, int(uniforms.sourceHeight) - 1);
    const uint index =
        uint(safeY) * uniforms.sourceStridePixels + uint(safeX);
    return source[index];
}

float4 sampleCatmullRom(
    device const float4* source,
    float2 position,
    constant GateWeaveUniforms& uniforms) {
    const int2 base = int2(floor(position));
    float4 value = float4(0.0f);
    float weightSum = 0.0f;
    for (int row = -1; row <= 2; ++row) {
        const float weightY = catmullRomWeight(position.y - float(base.y + row));
        for (int column = -1; column <= 2; ++column) {
            const float weightX =
                catmullRomWeight(position.x - float(base.x + column));
            const float weight = weightX * weightY;
            value += loadSource(
                source,
                base.x + column,
                base.y + row,
                uniforms) * weight;
            weightSum += weight;
        }
    }
    return value / weightSum;
}

kernel void filmtoneGateWeaveWarp(
    device const float4* source [[buffer(0)]],
    device float4* output [[buffer(1)]],
    constant GateWeaveUniforms& uniforms [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.renderWidth || gid.y >= uniforms.renderHeight) {
        return;
    }

    const int outputX = uniforms.renderOriginX + int(gid.x);
    const int outputY = uniforms.renderOriginY + int(gid.y);
    const float2 outputPosition = float2(float(outputX), float(outputY));
    const float2 center = float2(uniforms.centerX, uniforms.centerY);
    const float2 translation =
        float2(uniforms.translationX, uniforms.translationY);
    const float2 renderScale =
        float2(uniforms.renderScaleX, uniforms.renderScaleY);
    const float2 translated = (outputPosition - center - translation) / renderScale;

    // OpenFX canonical Y points up. This is the inverse of a positive
    // screen-clockwise rotation after the screen-space Y offset was flipped on
    // the CPU.
    const float2 inverseRotated = float2(
        uniforms.cosRotation * translated.x -
            uniforms.sinRotation * translated.y,
        uniforms.sinRotation * translated.x +
            uniforms.cosRotation * translated.y);
    const float2 sourcePositionGlobal =
        center + inverseRotated * uniforms.inverseCropScale * renderScale;
    const float2 sourcePositionLocal =
        sourcePositionGlobal -
        float2(float(uniforms.sourceOriginX), float(uniforms.sourceOriginY));

    const uint outputIndex =
        uint(outputY - uniforms.outputOriginY) * uniforms.outputStridePixels +
        uint(outputX - uniforms.outputOriginX);
    output[outputIndex] = sampleCatmullRom(
        source,
        sourcePositionLocal,
        uniforms);
}
)METAL";

struct alignas(16) GateWeaveUniforms final {
    std::int32_t renderOriginX;
    std::int32_t renderOriginY;
    std::uint32_t renderWidth;
    std::uint32_t renderHeight;

    std::int32_t sourceOriginX;
    std::int32_t sourceOriginY;
    std::uint32_t sourceWidth;
    std::uint32_t sourceHeight;

    std::int32_t outputOriginX;
    std::int32_t outputOriginY;
    std::uint32_t sourceStridePixels;
    std::uint32_t outputStridePixels;

    float centerX;
    float centerY;
    float renderScaleX;
    float renderScaleY;

    float translationX;
    float translationY;
    float cosRotation;
    float sinRotation;

    float inverseCropScale;
    float padding0;
    float padding1;
    float padding2;
};

static_assert(sizeof(GateWeaveUniforms) == 96u);
static_assert(alignof(GateWeaveUniforms) == 16u);

bool rectsEqual(const host::RectI& a, const host::RectI& b) noexcept {
    return a.x1 == b.x1 && a.y1 == b.y1 &&
           a.x2 == b.x2 && a.y2 == b.y2;
}

bool contains(const host::RectI& outer, const host::RectI& inner) noexcept {
    return inner.x1 >= outer.x1 && inner.y1 >= outer.y1 &&
           inner.x2 <= outer.x2 && inner.y2 <= outer.y2;
}

bool checkedImageCapacity(
    const host::MetalImageView& image,
    std::size_t bufferLength,
    std::uint32_t& stridePixels) noexcept {
    if (image.rowBytes <= 0 || image.bounds.isEmpty() ||
        image.rowBytes % static_cast<std::ptrdiff_t>(kFloatRGBABytesPerPixel) != 0) {
        return false;
    }

    const std::size_t stride = static_cast<std::size_t>(image.rowBytes);
    const std::size_t width = static_cast<std::size_t>(image.bounds.width());
    const std::size_t height = static_cast<std::size_t>(image.bounds.height());
    if (width > std::numeric_limits<std::size_t>::max() /
                    kFloatRGBABytesPerPixel) {
        return false;
    }
    const std::size_t rowBytes = width * kFloatRGBABytesPerPixel;
    if (rowBytes > stride ||
        stride / kFloatRGBABytesPerPixel >
            std::numeric_limits<std::uint32_t>::max()) {
        return false;
    }
    if (height - 1u > std::numeric_limits<std::size_t>::max() / stride) {
        return false;
    }
    const std::size_t lastRowOffset = (height - 1u) * stride;
    if (lastRowOffset > std::numeric_limits<std::size_t>::max() - rowBytes ||
        lastRowOffset + rowBytes > bufferLength) {
        return false;
    }

    stridePixels = static_cast<std::uint32_t>(
        stride / kFloatRGBABytesPerPixel);
    return true;
}

std::optional<contracts::ResolveRenderContextV1> makeDeterministicContext(
    const host::RenderContext& context,
    const host::RectI& sourceBounds,
    std::uint32_t recipeSeed) noexcept {
    if (!std::isfinite(context.frameRates.timeline) ||
        context.frameRates.timeline <= 0.0 ||
        !std::isfinite(context.renderScale.x) || context.renderScale.x <= 0.0 ||
        !std::isfinite(context.renderScale.y) || context.renderScale.y <= 0.0) {
        return std::nullopt;
    }

    forestone::visual_render::DeterministicRenderContextV1 deterministic{};
    deterministic.renderScaleX = static_cast<float>(context.renderScale.x);
    deterministic.renderScaleY = static_cast<float>(context.renderScale.y);
    deterministic.boundsX = static_cast<float>(
        static_cast<double>(sourceBounds.x1) / context.renderScale.x);
    deterministic.boundsY = static_cast<float>(
        static_cast<double>(sourceBounds.y1) / context.renderScale.y);
    deterministic.boundsWidth = static_cast<float>(
        static_cast<double>(sourceBounds.width()) / context.renderScale.x);
    deterministic.boundsHeight = static_cast<float>(
        static_cast<double>(sourceBounds.height()) / context.renderScale.y);
    deterministic.seed = context.explicitSeed.has_value()
        ? static_cast<std::uint32_t>(*context.explicitSeed)
        : recipeSeed;
    return contracts::makeResolveRenderContextV1(
        context.time,
        context.frameRates.timeline,
        deterministic);
}

std::optional<double> requiredAutomaticCropScale(
    const host::RectI& sourceBounds,
    const host::RectI& outputBounds,
    const host::PointD& renderScale,
    const GateWeaveMotionEnvelope& envelope) noexcept {
    if (sourceBounds.width() < 4 || sourceBounds.height() < 4) {
        return std::nullopt;
    }

    const double centerX =
        (static_cast<double>(sourceBounds.x1) +
         static_cast<double>(sourceBounds.x2 - 1)) * 0.5;
    const double centerY =
        (static_cast<double>(sourceBounds.y1) +
         static_cast<double>(sourceBounds.y2 - 1)) * 0.5;
    const double outputExtentX = std::max(
        std::abs(static_cast<double>(outputBounds.x1) - centerX),
        std::abs(static_cast<double>(outputBounds.x2 - 1) - centerX)) /
        renderScale.x;
    const double outputExtentY = std::max(
        std::abs(static_cast<double>(outputBounds.y1) - centerY),
        std::abs(static_cast<double>(outputBounds.y2 - 1) - centerY)) /
        renderScale.y;
    const double translationX = envelope.maxOffsetX / renderScale.x;
    const double translationY = envelope.maxOffsetY / renderScale.y;
    const double maximumRotationRadians =
        envelope.maxRotationDegrees * kDegreesToRadians;
    const double maximumAbsSine = maximumRotationRadians >= 1.5707963267948966
        ? 1.0
        : std::sin(maximumRotationRadians);

    // Bounds are conservative for every translation sign and rotation phase.
    const double requiredHalfX =
        outputExtentX + translationX +
        maximumAbsSine * (outputExtentY + translationY);
    const double requiredHalfY =
        outputExtentY + translationY +
        maximumAbsSine * (outputExtentX + translationX);
    const double safeHalfX =
        ((static_cast<double>(sourceBounds.width()) - 3.0) * 0.5 -
         kCubicFootprintEpsilonPixels) /
        renderScale.x;
    const double safeHalfY =
        ((static_cast<double>(sourceBounds.height()) - 3.0) * 0.5 -
         kCubicFootprintEpsilonPixels) /
        renderScale.y;
    if (!std::isfinite(requiredHalfX) || !std::isfinite(requiredHalfY) ||
        !std::isfinite(safeHalfX) || !std::isfinite(safeHalfY) ||
        safeHalfX <= 0.0 || safeHalfY <= 0.0) {
        return std::nullopt;
    }

    const double cropScale = std::max(
        {1.0, requiredHalfX / safeHalfX, requiredHalfY / safeHalfY});
    if (!std::isfinite(cropScale) || cropScale <= 0.0) {
        return std::nullopt;
    }
    return cropScale;
}

}  // namespace

GateWeaveProcessor::GateWeaveProcessor(
    const forestone::filmtone::FilmtoneFinishMappingV1& mapping,
    GateWeaveEdgeSafetyMode edgeSafetyMode) noexcept
    : recipe_(mapping.filmDamageRecipe), edgeSafetyMode_(edgeSafetyMode) {}

bool GateWeaveProcessor::isIdentity(
    const host::RenderContext& context) const noexcept {
    static_cast<void>(context);
    return isGateWeaveConfiguredIdentity(recipe_);
}

bool GateWeaveProcessor::encodeMetal(
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    host::MetalPipelineCache& pipelineCache,
    std::string& error) const {
    if (!isGateWeaveConfigurationValid(recipe_)) {
        error = "Gate Weave received a non-finite or unknown frozen-contract value.";
        return false;
    }
    if (isIdentity(context)) {
        return host::encodeMetalIdentityBlit(context, invocation, error);
    }
    if (edgeSafetyMode_ != GateWeaveEdgeSafetyMode::automaticCrop) {
        error = "Gate Weave received an unsupported edge-safety mode.";
        return false;
    }
    if (invocation.commandQueue == nullptr ||
        invocation.source.buffer == nullptr ||
        invocation.output.buffer == nullptr) {
        error = "Gate Weave is missing a Metal command queue or image buffer.";
        return false;
    }
    if (invocation.source.format != host::PixelFormat::floatRGBA ||
        invocation.output.format != host::PixelFormat::floatRGBA) {
        error = "Gate Weave requires float RGBA source and output images.";
        return false;
    }
    if (context.sourceBounds.has_value() &&
        !rectsEqual(*context.sourceBounds, invocation.source.bounds)) {
        error = "Gate Weave source bounds disagree with the Host render context.";
        return false;
    }
    if (context.outputBounds.has_value() &&
        !rectsEqual(*context.outputBounds, invocation.output.bounds)) {
        error = "Gate Weave output bounds disagree with the Host render context.";
        return false;
    }
    if (!contains(invocation.output.bounds, context.renderWindow)) {
        error = "Gate Weave render window lies outside the output bounds.";
        return false;
    }
    if (context.renderWindow.isEmpty()) {
        return true;
    }

    id<MTLCommandQueue> queue =
        static_cast<id<MTLCommandQueue>>(invocation.commandQueue);
    id<MTLBuffer> source =
        static_cast<id<MTLBuffer>>(invocation.source.buffer);
    id<MTLBuffer> output =
        static_cast<id<MTLBuffer>>(invocation.output.buffer);
    if (queue == nil || source == nil || output == nil) {
        error = "Gate Weave received an invalid Metal object.";
        return false;
    }
    if (source == output) {
        error = "Gate Weave requires distinct source and output buffers for an active warp.";
        return false;
    }

    std::uint32_t sourceStridePixels = 0u;
    std::uint32_t outputStridePixels = 0u;
    if (!checkedImageCapacity(
            invocation.source,
            source.length,
            sourceStridePixels) ||
        !checkedImageCapacity(
            invocation.output,
            output.length,
            outputStridePixels)) {
        error = "Gate Weave image bounds or row strides exceed a Metal buffer.";
        return false;
    }

    const auto renderContext = makeDeterministicContext(
        context,
        invocation.source.bounds,
        recipe_.seed);
    if (!renderContext.has_value()) {
        error = "Gate Weave could not resolve a deterministic Host render context.";
        return false;
    }
    const GateWeaveTransform transform =
        resolveGateWeaveTransform(recipe_, renderContext->deterministic);
    const GateWeaveMotionEnvelope envelope =
        resolveGateWeaveMotionEnvelope(recipe_, renderContext->deterministic);
    const auto cropScale = requiredAutomaticCropScale(
        invocation.source.bounds,
        invocation.output.bounds,
        context.renderScale,
        envelope);
    if (!cropScale.has_value()) {
        error = "Gate Weave cannot fit its cubic sampling footprint inside these bounds.";
        return false;
    }

    const double centerX =
        (static_cast<double>(invocation.source.bounds.x1) +
         static_cast<double>(invocation.source.bounds.x2 - 1)) * 0.5;
    const double centerY =
        (static_cast<double>(invocation.source.bounds.y1) +
         static_cast<double>(invocation.source.bounds.y2 - 1)) * 0.5;
    const double rotationRadians = transform.rotationDegrees * kDegreesToRadians;
    const GateWeaveUniforms uniforms{
        context.renderWindow.x1,
        context.renderWindow.y1,
        static_cast<std::uint32_t>(context.renderWindow.width()),
        static_cast<std::uint32_t>(context.renderWindow.height()),
        invocation.source.bounds.x1,
        invocation.source.bounds.y1,
        static_cast<std::uint32_t>(invocation.source.bounds.width()),
        static_cast<std::uint32_t>(invocation.source.bounds.height()),
        invocation.output.bounds.x1,
        invocation.output.bounds.y1,
        sourceStridePixels,
        outputStridePixels,
        static_cast<float>(centerX),
        static_cast<float>(centerY),
        static_cast<float>(context.renderScale.x),
        static_cast<float>(context.renderScale.y),
        static_cast<float>(transform.offsetX),
        static_cast<float>(-transform.offsetY),
        static_cast<float>(std::cos(rotationRadians)),
        static_cast<float>(std::sin(rotationRadians)),
        static_cast<float>(1.0 / *cropScale),
        0.0f,
        0.0f,
        0.0f,
    };

    const host::MetalPipelineRequest pipelineRequest{
        kPipelineCacheKey,
        kMetalSource,
        kMetalFunctionName,
        false,
    };
    void* pipelinePointer = pipelineCache.getOrCreate(
        invocation.commandQueue,
        pipelineRequest,
        error);
    if (pipelinePointer == nullptr) {
        return false;
    }
    id<MTLComputePipelineState> pipeline =
        static_cast<id<MTLComputePipelineState>>(pipelinePointer);

    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    if (commandBuffer == nil) {
        error = "Gate Weave Metal command buffer creation failed.";
        return false;
    }
    commandBuffer.label = @"Filmtone Gate Weave";
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    if (encoder == nil) {
        error = "Gate Weave Metal compute encoder creation failed.";
        return false;
    }
    encoder.label = @"Gate Weave Inverse Warp";
    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:source offset:0u atIndex:0u];
    [encoder setBuffer:output offset:0u atIndex:1u];
    [encoder setBytes:&uniforms length:sizeof(uniforms) atIndex:2u];

    const NSUInteger maximumThreads = std::max<NSUInteger>(
        1u,
        pipeline.maxTotalThreadsPerThreadgroup);
    const NSUInteger threadWidth = std::max<NSUInteger>(
        1u,
        std::min<NSUInteger>(pipeline.threadExecutionWidth, maximumThreads));
    const NSUInteger threadHeight = std::max<NSUInteger>(
        1u,
        std::min<NSUInteger>(
            16u,
            maximumThreads / threadWidth));
    [encoder dispatchThreads:MTLSizeMake(
                                 uniforms.renderWidth,
                                 uniforms.renderHeight,
                                 1u)
        threadsPerThreadgroup:MTLSizeMake(threadWidth, threadHeight, 1u)];
    [encoder endEncoding];
    [commandBuffer commit];
    return true;
}

}  // namespace filmtone::resolve::gate_weave
