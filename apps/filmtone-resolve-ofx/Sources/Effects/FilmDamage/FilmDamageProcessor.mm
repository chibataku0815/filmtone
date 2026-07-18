#import <Metal/Metal.h>

#include "FilmDamageProcessor.h"

#include "FilmDamageMetalSource.h"
#include "../../Host/MetalIdentityBlit.h"
#include "../../Host/MetalPipelineCache.h"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <string>
#include <utility>

namespace filmtone::resolve::damage {
namespace {

constexpr std::size_t kFloatRGBABytesPerPixel = sizeof(float) * 4u;

struct alignas(16) PackedFloat4 final {
    float x;
    float y;
    float z;
    float w;
};

struct alignas(16) PackedUInt4 final {
    std::uint32_t x;
    std::uint32_t y;
    std::uint32_t z;
    std::uint32_t w;
};

struct alignas(16) PackedInt4 final {
    std::int32_t x;
    std::int32_t y;
    std::int32_t z;
    std::int32_t w;
};

struct alignas(16) FilmDamageMetalUniforms final {
    PackedUInt4 io;
    PackedInt4 origins;
    PackedInt4 outputAndDebug;

    PackedFloat4 context;
    PackedFloat4 bounds;
    PackedUInt4 temporal;

    PackedFloat4 global0;
    PackedFloat4 global1;

    PackedFloat4 dust0;
    PackedFloat4 dust1;
    PackedFloat4 dust2;

    PackedFloat4 scratch0;
    PackedFloat4 scratch1;
    PackedFloat4 scratch2;
    PackedFloat4 scratch3;
    PackedFloat4 scratch4;
    PackedFloat4 scratch5;

    PackedFloat4 fiber0;
    PackedFloat4 fiber1;
    PackedFloat4 fiber2;
    PackedFloat4 fiber3;

    PackedFloat4 stain0;
    PackedFloat4 stain1;
    PackedFloat4 stain2;

    PackedFloat4 gate0;
    PackedFloat4 gate1;

    PackedUInt4 polarities;
    PackedUInt4 modes;
};

static_assert(sizeof(PackedFloat4) == 16u);
static_assert(sizeof(PackedUInt4) == 16u);
static_assert(sizeof(PackedInt4) == 16u);
static_assert(alignof(FilmDamageMetalUniforms) == 16u);
static_assert(sizeof(FilmDamageMetalUniforms) == 28u * 16u);

bool isPositiveFinite(float value) noexcept {
    return std::isfinite(value) && value > 0.0f;
}

bool rangeCanContribute(
    const forestone::visual_effect::FilmDamageRange& range) noexcept {
    return isPositiveFinite(range.min) || isPositiveFinite(range.max);
}

bool hasActiveMaterial(
    const forestone::visual_effect::FilmDamageRecipeV2& recipe) noexcept {
    if (recipe.enabled == 0u ||
        !isPositiveFinite(recipe.global.amount) ||
        !isPositiveFinite(recipe.global.opacity)) {
        return false;
    }

    const bool dust =
        isPositiveFinite(recipe.dust.density) &&
        rangeCanContribute(recipe.dust.opacity);
    const bool scratches =
        isPositiveFinite(recipe.scratches.density) &&
        rangeCanContribute(recipe.scratches.opacity);
    const bool fibers =
        isPositiveFinite(recipe.fibers.density) &&
        rangeCanContribute(recipe.fibers.opacity);
    const bool stains =
        isPositiveFinite(recipe.stains.density) &&
        rangeCanContribute(recipe.stains.opacity);
    const bool gateWear =
        isPositiveFinite(recipe.gateWear.amount) &&
        isPositiveFinite(recipe.gateWear.opacity);
    return dust || scratches || fibers || stains || gateWear;
}

bool contains(const host::RectI& outer, const host::RectI& inner) noexcept {
    return inner.x1 >= outer.x1 && inner.y1 >= outer.y1 &&
           inner.x2 <= outer.x2 && inner.y2 <= outer.y2;
}

bool validateImageView(
    const host::MetalImageView& image,
    const host::RectI& renderWindow,
    const char* label,
    std::string& error) {
    if (image.buffer == nullptr) {
        error = std::string("Film Damage is missing the ") + label + " Metal buffer.";
        return false;
    }
    if (image.format != host::PixelFormat::floatRGBA) {
        error = std::string("Film Damage requires float RGBA for the ") + label + " image.";
        return false;
    }
    if (image.rowBytes <= 0 ||
        image.rowBytes % static_cast<std::ptrdiff_t>(kFloatRGBABytesPerPixel) != 0) {
        error = std::string("Film Damage received an invalid ") + label + " image stride.";
        return false;
    }
    if (image.bounds.isEmpty() || !contains(image.bounds, renderWindow)) {
        error = std::string("Film Damage render window lies outside the ") + label + " image.";
        return false;
    }

    const auto stride = static_cast<std::size_t>(image.rowBytes);
    const auto width = static_cast<std::size_t>(image.bounds.width());
    if (width > std::numeric_limits<std::size_t>::max() / kFloatRGBABytesPerPixel ||
        width * kFloatRGBABytesPerPixel > stride) {
        error = std::string("Film Damage ") + label + " row is wider than its stride.";
        return false;
    }
    return true;
}

bool pixelFitsBuffer(
    const host::MetalImageView& image,
    int x,
    int y,
    std::size_t bufferLength) noexcept {
    const auto row = static_cast<std::size_t>(y - image.bounds.y1);
    const auto column = static_cast<std::size_t>(x - image.bounds.x1);
    const auto stride = static_cast<std::size_t>(image.rowBytes);
    if (row > std::numeric_limits<std::size_t>::max() / stride) {
        return false;
    }
    const std::size_t rowOffset = row * stride;
    if (column > std::numeric_limits<std::size_t>::max() / kFloatRGBABytesPerPixel) {
        return false;
    }
    const std::size_t columnOffset = column * kFloatRGBABytesPerPixel;
    if (rowOffset > std::numeric_limits<std::size_t>::max() - columnOffset) {
        return false;
    }
    const std::size_t offset = rowOffset + columnOffset;
    return offset <= bufferLength &&
           kFloatRGBABytesPerPixel <= bufferLength - offset;
}

bool renderWindowFitsBuffer(
    const host::MetalImageView& image,
    const host::RectI& renderWindow,
    std::size_t bufferLength) noexcept {
    if (renderWindow.isEmpty()) {
        return true;
    }
    return pixelFitsBuffer(image, renderWindow.x1, renderWindow.y1, bufferLength) &&
           pixelFitsBuffer(image, renderWindow.x2 - 1, renderWindow.y2 - 1, bufferLength);
}

bool validateDeterministicUniforms(
    const forestone::visual_render::FilmDamageRenderUniformsV1& uniforms,
    std::string& error) {
    if (!std::isfinite(uniforms.hostTimeSeconds) ||
        !std::isfinite(uniforms.frameRate) || uniforms.frameRate <= 0.0f ||
        !std::isfinite(uniforms.renderScaleX) || uniforms.renderScaleX <= 0.0f ||
        !std::isfinite(uniforms.renderScaleY) || uniforms.renderScaleY <= 0.0f ||
        !std::isfinite(uniforms.boundsX) ||
        !std::isfinite(uniforms.boundsY) ||
        !std::isfinite(uniforms.boundsWidth) || uniforms.boundsWidth <= 0.0f ||
        !std::isfinite(uniforms.boundsHeight) || uniforms.boundsHeight <= 0.0f) {
        error = "Film Damage received an invalid deterministic render context.";
        return false;
    }
    return true;
}

std::uint32_t checkedUInt(
    std::size_t value,
    const char* label,
    std::string& error) {
    if (value > std::numeric_limits<std::uint32_t>::max()) {
        error = std::string("Film Damage ") + label + " exceeds the Metal uniform range.";
        return 0u;
    }
    return static_cast<std::uint32_t>(value);
}

FilmDamageMetalUniforms makeMetalUniforms(
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    const forestone::visual_render::FilmDamageRenderUniformsV1& source,
    FilmDamageDebugView debugView,
    std::string& error) {
    const auto& recipe = source.recipe;
    const auto sourceStride = static_cast<std::size_t>(invocation.source.rowBytes) /
        kFloatRGBABytesPerPixel;
    const auto outputStride = static_cast<std::size_t>(invocation.output.rowBytes) /
        kFloatRGBABytesPerPixel;

    const std::uint32_t renderWidth = checkedUInt(
        static_cast<std::size_t>(context.renderWindow.width()),
        "render width",
        error);
    const std::uint32_t renderHeight = checkedUInt(
        static_cast<std::size_t>(context.renderWindow.height()),
        "render height",
        error);
    const std::uint32_t packedSourceStride = checkedUInt(
        sourceStride,
        "source stride",
        error);
    const std::uint32_t packedOutputStride = checkedUInt(
        outputStride,
        "output stride",
        error);

    FilmDamageMetalUniforms result{};
    result.io = PackedUInt4{
        renderWidth,
        renderHeight,
        packedSourceStride,
        packedOutputStride,
    };
    result.origins = PackedInt4{
        context.renderWindow.x1,
        context.renderWindow.y1,
        invocation.source.bounds.x1,
        invocation.source.bounds.y1,
    };
    result.outputAndDebug = PackedInt4{
        invocation.output.bounds.x1,
        invocation.output.bounds.y1,
        static_cast<std::int32_t>(debugView),
        0,
    };
    result.context = PackedFloat4{
        source.hostTimeSeconds,
        source.frameRate,
        source.renderScaleX,
        source.renderScaleY,
    };
    result.bounds = PackedFloat4{
        source.boundsX,
        source.boundsY,
        source.boundsWidth,
        source.boundsHeight,
    };
    result.temporal = PackedUInt4{
        static_cast<std::uint32_t>(source.frameIndex),
        source.filmDamageStreamSeed,
        static_cast<std::uint32_t>(recipe.formatProfile),
        recipe.enabled,
    };
    result.global0 = PackedFloat4{
        recipe.global.amount,
        recipe.global.opacity,
        recipe.global.chromaticity,
        recipe.global.artifactScale,
    };
    result.global1 = PackedFloat4{
        recipe.global.edgeBias,
        static_cast<float>(recipe.global.period),
        0.0f,
        0.0f,
    };

    result.dust0 = PackedFloat4{
        recipe.dust.density,
        recipe.dust.softness,
        recipe.dust.frameEntryVariation,
        recipe.dust.edgeBias,
    };
    result.dust1 = PackedFloat4{
        recipe.dust.size.min,
        recipe.dust.size.max,
        recipe.dust.opacity.min,
        recipe.dust.opacity.max,
    };
    result.dust2 = PackedFloat4{
        recipe.dust.lifetimeFrames.min,
        recipe.dust.lifetimeFrames.max,
        static_cast<float>(recipe.dust.fadeFrames.inFrames),
        static_cast<float>(recipe.dust.fadeFrames.outFrames),
    };

    result.scratch0 = PackedFloat4{
        recipe.scratches.density,
        recipe.scratches.roughness,
        recipe.scratches.taper,
        recipe.scratches.breakup,
    };
    result.scratch1 = PackedFloat4{
        recipe.scratches.width.min,
        recipe.scratches.width.max,
        recipe.scratches.length.min,
        recipe.scratches.length.max,
    };
    result.scratch2 = PackedFloat4{
        recipe.scratches.opacity.min,
        recipe.scratches.opacity.max,
        recipe.scratches.gaps.density,
        recipe.scratches.gaps.softness,
    };
    result.scratch3 = PackedFloat4{
        recipe.scratches.gaps.size.min,
        recipe.scratches.gaps.size.max,
        recipe.scratches.waviness,
        recipe.scratches.jitter,
    };
    result.scratch4 = PackedFloat4{
        recipe.scratches.lifetimeFrames.min,
        recipe.scratches.lifetimeFrames.max,
        static_cast<float>(recipe.scratches.fadeFrames.inFrames),
        static_cast<float>(recipe.scratches.fadeFrames.outFrames),
    };
    result.scratch5 = PackedFloat4{
        recipe.scratches.areaCenter,
        recipe.scratches.areaWidth,
        recipe.scratches.gateBias,
        0.0f,
    };

    result.fiber0 = PackedFloat4{
        recipe.fibers.density,
        recipe.fibers.curl,
        recipe.fibers.wiggle,
        recipe.fibers.persistence,
    };
    result.fiber1 = PackedFloat4{
        recipe.fibers.length.min,
        recipe.fibers.length.max,
        recipe.fibers.width.min,
        recipe.fibers.width.max,
    };
    result.fiber2 = PackedFloat4{
        recipe.fibers.opacity.min,
        recipe.fibers.opacity.max,
        recipe.fibers.lifetimeFrames.min,
        recipe.fibers.lifetimeFrames.max,
    };
    result.fiber3 = PackedFloat4{
        static_cast<float>(recipe.fibers.fadeFrames.inFrames),
        static_cast<float>(recipe.fibers.fadeFrames.outFrames),
        recipe.fibers.gateBias,
        0.0f,
    };

    result.stain0 = PackedFloat4{
        recipe.stains.density,
        recipe.stains.softness,
        recipe.stains.chromaticity,
        recipe.stains.edgeBias,
    };
    result.stain1 = PackedFloat4{
        recipe.stains.size.min,
        recipe.stains.size.max,
        recipe.stains.opacity.min,
        recipe.stains.opacity.max,
    };
    result.stain2 = PackedFloat4{
        recipe.stains.lifetimeFrames.min,
        recipe.stains.lifetimeFrames.max,
        static_cast<float>(recipe.stains.fadeFrames.inFrames),
        static_cast<float>(recipe.stains.fadeFrames.outFrames),
    };

    result.gate0 = PackedFloat4{
        recipe.gateWear.amount,
        recipe.gateWear.width,
        recipe.gateWear.opacity,
        recipe.gateWear.softness,
    };
    result.gate1 = PackedFloat4{
        recipe.gateWear.jitter,
        0.0f,
        0.0f,
        0.0f,
    };

    result.polarities = PackedUInt4{
        static_cast<std::uint32_t>(recipe.dust.polarity),
        static_cast<std::uint32_t>(recipe.scratches.polarity),
        static_cast<std::uint32_t>(recipe.fibers.polarity),
        static_cast<std::uint32_t>(recipe.stains.polarity),
    };
    result.modes = PackedUInt4{
        static_cast<std::uint32_t>(recipe.gateWear.polarity),
        static_cast<std::uint32_t>(recipe.scratches.direction),
        0u,
        0u,
    };
    return result;
}

bool buffersMayAliasSafely(
    const host::MetalRenderInvocation& invocation) noexcept {
    if (invocation.source.buffer != invocation.output.buffer) {
        return true;
    }
    return invocation.source.rowBytes == invocation.output.rowBytes &&
           invocation.source.bounds.x1 == invocation.output.bounds.x1 &&
           invocation.source.bounds.y1 == invocation.output.bounds.y1 &&
           invocation.source.bounds.x2 == invocation.output.bounds.x2 &&
           invocation.source.bounds.y2 == invocation.output.bounds.y2;
}

}  // namespace

FilmDamageProcessor::FilmDamageProcessor(
    forestone::visual_render::FilmDamageRenderUniformsV1 uniforms,
    FilmDamageDebugView debugView) noexcept
    : uniforms_(std::move(uniforms)),
      debugView_(debugView) {}

FilmDamageProcessor::FilmDamageProcessor(
    const forestone::filmtone::FilmtoneFinishMappingV1& mapping,
    const contracts::ResolveRenderContextV1& renderContext,
    FilmDamageDebugView debugView) noexcept
    : FilmDamageProcessor(
          contracts::makeFilmtoneFinishFilmDamageUniformsV1(mapping, renderContext),
          debugView) {}

bool FilmDamageProcessor::isIdentity(
    const host::RenderContext& context) const noexcept {
    (void)context;
    return !hasActiveMaterial(uniforms_.recipe);
}

bool FilmDamageProcessor::encodeMetal(
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    host::MetalPipelineCache& pipelineCache,
    std::string& error) const {
    error.clear();
    if (isIdentity(context)) {
        return host::encodeMetalIdentityBlit(context, invocation, error);
    }
    if (context.renderWindow.isEmpty()) {
        return true;
    }
    if (invocation.commandQueue == nullptr) {
        error = "Film Damage is missing the Metal command queue.";
        return false;
    }
    if (!validateImageView(invocation.source, context.renderWindow, "source", error) ||
        !validateImageView(invocation.output, context.renderWindow, "output", error) ||
        !validateDeterministicUniforms(uniforms_, error)) {
        return false;
    }
    if (!buffersMayAliasSafely(invocation)) {
        error = "Film Damage cannot remap aliased Metal buffers.";
        return false;
    }

    id<MTLCommandQueue> queue =
        static_cast<id<MTLCommandQueue>>(invocation.commandQueue);
    id<MTLBuffer> sourceBuffer =
        static_cast<id<MTLBuffer>>(invocation.source.buffer);
    id<MTLBuffer> outputBuffer =
        static_cast<id<MTLBuffer>>(invocation.output.buffer);
    if (queue == nil || sourceBuffer == nil || outputBuffer == nil) {
        error = "Film Damage received an invalid Metal object.";
        return false;
    }
    if (!renderWindowFitsBuffer(
            invocation.source,
            context.renderWindow,
            sourceBuffer.length) ||
        !renderWindowFitsBuffer(
            invocation.output,
            context.renderWindow,
            outputBuffer.length)) {
        error = "Film Damage render window exceeds a Metal buffer.";
        return false;
    }

    const host::MetalPipelineRequest request{
        detail::kFilmDamageMetalCacheKey,
        detail::kFilmDamageMetalLibrarySource,
        detail::kFilmDamageMetalFunctionName,
        false,
    };
    void* pipelineObject = pipelineCache.getOrCreate(
        invocation.commandQueue,
        request,
        error);
    if (pipelineObject == nullptr) {
        return false;
    }
    id<MTLComputePipelineState> pipeline =
        static_cast<id<MTLComputePipelineState>>(pipelineObject);

    FilmDamageMetalUniforms metalUniforms = makeMetalUniforms(
        context,
        invocation,
        uniforms_,
        debugView_,
        error);
    if (!error.empty()) {
        return false;
    }

    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    if (commandBuffer == nil) {
        error = "Film Damage could not create a Metal command buffer.";
        return false;
    }
    commandBuffer.label = @"Filmtone Film Damage";

    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    if (encoder == nil) {
        error = "Film Damage could not create a Metal compute encoder.";
        return false;
    }
    encoder.label = @"Filmtone Film Damage Material Pass";
    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:sourceBuffer offset:0 atIndex:0];
    [encoder setBuffer:outputBuffer offset:0 atIndex:1];
    [encoder setBytes:&metalUniforms length:sizeof(metalUniforms) atIndex:2];

    const NSUInteger executionWidth = pipeline.threadExecutionWidth;
    const NSUInteger maximumThreads = pipeline.maxTotalThreadsPerThreadgroup;
    if (executionWidth == 0u || maximumThreads < executionWidth) {
        [encoder endEncoding];
        error = "Film Damage received an invalid Metal threadgroup capability.";
        return false;
    }
    const NSUInteger groupHeight = std::max<NSUInteger>(
        1u,
        std::min<NSUInteger>(8u, maximumThreads / executionWidth));
    const MTLSize threadsPerGroup = MTLSizeMake(
        executionWidth,
        groupHeight,
        1u);
    const MTLSize grid = MTLSizeMake(
        static_cast<NSUInteger>(context.renderWindow.width()),
        static_cast<NSUInteger>(context.renderWindow.height()),
        1u);
    [encoder dispatchThreads:grid threadsPerThreadgroup:threadsPerGroup];
    [encoder endEncoding];
    [commandBuffer commit];
    return true;
}

}  // namespace filmtone::resolve::damage
