#import <Metal/Metal.h>

#include "FilmBreathProcessor.h"

#include "FilmBreathOffsets.h"
#include "../../Host/MetalIdentityBlit.h"
#include "../../Host/MetalPipelineCache.h"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <string>

namespace filmtone::resolve::effects::film_breath {
namespace {

constexpr std::size_t kFloatRGBABytesPerPixel = sizeof(float) * 4u;
constexpr char kFilmBreathPipelineCacheKey[] =
    "filmtone.finish.film-breath.photometric.v4";
constexpr char kFilmBreathKernelFunction[] = "filmtoneFilmBreathV4";

constexpr char kFilmBreathMetalSource[] = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct FilmBreathUniformsV2 {
    uint sourceRowStridePixels;
    uint outputRowStridePixels;
    uint width;
    uint height;
    float exposure;
    float contrast;
    float cyanDensity;
    float magentaDensity;
    float yellowDensity;
    float padding0;
    float padding1;
    float padding2;
};

kernel void filmtoneFilmBreathV4(
    device const float4* source [[buffer(0)]],
    device float4* output [[buffer(1)]],
    constant FilmBreathUniformsV2& uniforms [[buffer(2)]],
    uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uniforms.width || position.y >= uniforms.height) {
        return;
    }

    const ulong sourceIndex =
        ulong(position.y) * ulong(uniforms.sourceRowStridePixels) +
        ulong(position.x);
    const ulong outputIndex =
        ulong(position.y) * ulong(uniforms.outputRowStridePixels) +
        ulong(position.x);
    const float4 sourceColor = source[sourceIndex];

    if (uniforms.exposure == 0.0f &&
        uniforms.contrast == 0.0f &&
        uniforms.cyanDensity == 0.0f &&
        uniforms.magentaDensity == 0.0f &&
        uniforms.yellowDensity == 0.0f) {
        output[outputIndex] = sourceColor;
        return;
    }

    float3 color = sourceColor.rgb;

    // Resolve does not expose a reliable working-encoding contract here, so
    // this is an encoding-agnostic signal operation rather than a claim of
    // scene- or display-referred equivalence. Exposure stays neutral. Tonal
    // variation uses one bounded log-luminance slope and therefore remains
    // distinct from exposure while preserving channel ratios.
    const float positiveLuminance = dot(
        max(color, float3(0.0f)),
        float3(0.2126f, 0.7152f, 0.0722f));
    float tonalGain = 1.0f;
    if (positiveLuminance > 1.0e-6f) {
        const float logLuminance = clamp(
            log2(positiveLuminance),
            -8.0f,
            8.0f);
        const float contrastSlope = clamp(
            uniforms.contrast,
            -0.45f,
            0.45f);
        tonalGain = exp2(contrastSlope * logLuminance);
    }
    color *= exp2(uniforms.exposure) * tonalGain;

    // The offset model supplies signed CMY optical densities in stops.
    // Positive C, M, and Y primarily absorb R, G, and B respectively. The
    // small non-negative off-diagonal terms model broad, imperfect dye
    // absorption without turning these into ideal digital-primary gains.
    // Negative density follows the complementary direction. Transmission is
    // intentionally not luminance-normalized: subtractive filtration can
    // change both colour and density.
    const float3 cmyDensity = float3(
        uniforms.cyanDensity,
        uniforms.magentaDensity,
        uniforms.yellowDensity);
    const float3 channelDensityStops = float3(
        dot(cmyDensity, float3(1.00f, 0.06f, 0.04f)),
        dot(cmyDensity, float3(0.05f, 1.00f, 0.07f)),
        dot(cmyDensity, float3(0.03f, 0.08f, 1.00f)));
    color *= exp2(-channelDensityStops);

    // Every RGB operation is a positive finite multiplier: exact black and
    // channel sign survive, negative/HDR RGB remains unclamped, and source
    // alpha passes through unchanged.
    output[outputIndex] = float4(color, sourceColor.a);
}
)METAL";

struct alignas(16) FilmBreathMetalUniformsV2 final {
    std::uint32_t sourceRowStridePixels;
    std::uint32_t outputRowStridePixels;
    std::uint32_t width;
    std::uint32_t height;
    float exposure;
    float contrast;
    float cyanDensity;
    float magentaDensity;
    float yellowDensity;
    float padding[3];
};

static_assert(sizeof(FilmBreathMetalUniformsV2) == 48u);
static_assert(alignof(FilmBreathMetalUniformsV2) == 16u);

struct PreparedBuffer final {
    std::size_t offset;
    std::uint32_t rowStridePixels;
};

bool contains(
    const host::RectI& outer,
    const host::RectI& inner) noexcept {
    return inner.x1 >= outer.x1 &&
           inner.y1 >= outer.y1 &&
           inner.x2 <= outer.x2 &&
           inner.y2 <= outer.y2;
}

bool checkedMultiply(
    std::size_t left,
    std::size_t right,
    std::size_t& result) noexcept {
    if (left != 0u &&
        right > std::numeric_limits<std::size_t>::max() / left) {
        return false;
    }
    result = left * right;
    return true;
}

bool checkedAdd(
    std::size_t left,
    std::size_t right,
    std::size_t& result) noexcept {
    if (right > std::numeric_limits<std::size_t>::max() - left) {
        return false;
    }
    result = left + right;
    return true;
}

bool prepareBuffer(
    const host::MetalImageView& image,
    const host::RectI& renderWindow,
    std::size_t width,
    std::size_t height,
    std::size_t bufferLength,
    PreparedBuffer& prepared) noexcept {
    if (image.rowBytes <= 0 ||
        image.rowBytes % static_cast<std::ptrdiff_t>(kFloatRGBABytesPerPixel) != 0 ||
        !contains(image.bounds, renderWindow)) {
        return false;
    }

    const std::size_t stride = static_cast<std::size_t>(image.rowBytes);
    const std::size_t stridePixels = stride / kFloatRGBABytesPerPixel;
    if (stridePixels > std::numeric_limits<std::uint32_t>::max()) {
        return false;
    }

    const std::size_t firstRow = static_cast<std::size_t>(
        static_cast<std::int64_t>(renderWindow.y1) -
        static_cast<std::int64_t>(image.bounds.y1));
    const std::size_t firstColumn = static_cast<std::size_t>(
        static_cast<std::int64_t>(renderWindow.x1) -
        static_cast<std::int64_t>(image.bounds.x1));

    std::size_t columnBytes = 0u;
    std::size_t widthBytes = 0u;
    if (!checkedMultiply(
            firstColumn,
            kFloatRGBABytesPerPixel,
            columnBytes) ||
        !checkedMultiply(width, kFloatRGBABytesPerPixel, widthBytes) ||
        columnBytes > stride ||
        widthBytes > stride - columnBytes) {
        return false;
    }

    std::size_t firstRowBytes = 0u;
    std::size_t firstOffset = 0u;
    if (!checkedMultiply(firstRow, stride, firstRowBytes) ||
        !checkedAdd(firstRowBytes, columnBytes, firstOffset)) {
        return false;
    }

    std::size_t trailingRowsBytes = 0u;
    std::size_t lastRowOffset = 0u;
    std::size_t requiredEnd = 0u;
    if (!checkedMultiply(height - 1u, stride, trailingRowsBytes) ||
        !checkedAdd(firstOffset, trailingRowsBytes, lastRowOffset) ||
        !checkedAdd(lastRowOffset, widthBytes, requiredEnd) ||
        requiredEnd > bufferLength) {
        return false;
    }

    prepared = PreparedBuffer{
        firstOffset,
        static_cast<std::uint32_t>(stridePixels),
    };
    return true;
}

bool makeUniforms(
    const FilmBreathOffsets& offsets,
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    id<MTLBuffer> source,
    id<MTLBuffer> output,
    PreparedBuffer& preparedSource,
    PreparedBuffer& preparedOutput,
    FilmBreathMetalUniformsV2& uniforms,
    std::string& error) {
    if (invocation.source.format != host::PixelFormat::floatRGBA ||
        invocation.output.format != host::PixelFormat::floatRGBA) {
        error = "Film Breath requires float RGBA images.";
        return false;
    }
    if (!contains(invocation.source.bounds, context.renderWindow) ||
        !contains(invocation.output.bounds, context.renderWindow)) {
        error = "Film Breath render window lies outside the host image bounds.";
        return false;
    }

    const auto widthValue =
        static_cast<std::int64_t>(context.renderWindow.x2) -
        static_cast<std::int64_t>(context.renderWindow.x1);
    const auto heightValue =
        static_cast<std::int64_t>(context.renderWindow.y2) -
        static_cast<std::int64_t>(context.renderWindow.y1);
    if (widthValue <= 0 || heightValue <= 0 ||
        static_cast<std::uint64_t>(widthValue) >
            std::numeric_limits<std::uint32_t>::max() ||
        static_cast<std::uint64_t>(heightValue) >
            std::numeric_limits<std::uint32_t>::max()) {
        error = "Film Breath render dimensions are invalid.";
        return false;
    }

    const std::size_t width = static_cast<std::size_t>(widthValue);
    const std::size_t height = static_cast<std::size_t>(heightValue);
    if (!prepareBuffer(
            invocation.source,
            context.renderWindow,
            width,
            height,
            source.length,
            preparedSource) ||
        !prepareBuffer(
            invocation.output,
            context.renderWindow,
            width,
            height,
            output.length,
            preparedOutput)) {
        error = "Film Breath render exceeds a host buffer or row stride.";
        return false;
    }

    if (source == output &&
        (preparedSource.offset != preparedOutput.offset ||
         preparedSource.rowStridePixels != preparedOutput.rowStridePixels)) {
        error = "Film Breath cannot remap differently laid out aliased buffers.";
        return false;
    }

    uniforms = FilmBreathMetalUniformsV2{
        preparedSource.rowStridePixels,
        preparedOutput.rowStridePixels,
        static_cast<std::uint32_t>(width),
        static_cast<std::uint32_t>(height),
        static_cast<float>(offsets.exposure),
        static_cast<float>(offsets.contrast),
        static_cast<float>(offsets.cyanDensity),
        static_cast<float>(offsets.magentaDensity),
        static_cast<float>(offsets.yellowDensity),
        {0.0f, 0.0f, 0.0f},
    };
    return true;
}

}  // namespace

FilmBreathProcessor::FilmBreathProcessor(
    FilmBreathParameters parameters) noexcept
    : parameters_(parameters) {}

const FilmBreathParameters& FilmBreathProcessor::parameters() const noexcept {
    return parameters_;
}

bool FilmBreathProcessor::isIdentity(
    const host::RenderContext& context) const noexcept {
    const auto offsets = resolveFilmBreathOffsets(parameters_, context);
    return offsets.has_value() && isFilmBreathIdentity(*offsets);
}

bool FilmBreathProcessor::encodeMetal(
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    host::MetalPipelineCache& pipelineCache,
    std::string& error) const {
    const auto offsets = resolveFilmBreathOffsets(parameters_, context);
    if (!offsets.has_value()) {
        error = "Film Breath could not resolve a valid deterministic time context.";
        return false;
    }
    if (isFilmBreathIdentity(*offsets)) {
        return host::encodeMetalIdentityBlit(context, invocation, error);
    }
    if (context.renderWindow.x2 <= context.renderWindow.x1 ||
        context.renderWindow.y2 <= context.renderWindow.y1) {
        return true;
    }
    if (invocation.commandQueue == nullptr ||
        invocation.source.buffer == nullptr ||
        invocation.output.buffer == nullptr) {
        error = "Film Breath is missing a Metal command queue or image buffer.";
        return false;
    }

    id<MTLCommandQueue> queue =
        static_cast<id<MTLCommandQueue>>(invocation.commandQueue);
    id<MTLBuffer> source =
        static_cast<id<MTLBuffer>>(invocation.source.buffer);
    id<MTLBuffer> output =
        static_cast<id<MTLBuffer>>(invocation.output.buffer);
    if (queue == nil || source == nil || output == nil) {
        error = "Film Breath received an invalid Metal host object.";
        return false;
    }

    PreparedBuffer preparedSource{};
    PreparedBuffer preparedOutput{};
    FilmBreathMetalUniformsV2 uniforms{};
    if (!makeUniforms(
            *offsets,
            context,
            invocation,
            source,
            output,
            preparedSource,
            preparedOutput,
            uniforms,
            error)) {
        return false;
    }

    const host::MetalPipelineRequest request{
        kFilmBreathPipelineCacheKey,
        kFilmBreathMetalSource,
        kFilmBreathKernelFunction,
        false,
    };
    void* pipelineValue = pipelineCache.getOrCreate(
        invocation.commandQueue,
        request,
        error);
    if (pipelineValue == nullptr) {
        return false;
    }
    id<MTLComputePipelineState> pipeline =
        static_cast<id<MTLComputePipelineState>>(pipelineValue);
    if (pipeline == nil) {
        error = "Film Breath received an invalid cached Metal pipeline.";
        return false;
    }

    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    if (commandBuffer == nil) {
        error = "Film Breath could not create a Metal command buffer.";
        return false;
    }
    commandBuffer.label = @"Filmtone Film Breath";

    id<MTLComputeCommandEncoder> encoder =
        [commandBuffer computeCommandEncoder];
    if (encoder == nil) {
        error = "Film Breath could not create a Metal compute encoder.";
        return false;
    }
    encoder.label = @"Filmtone Film Breath Photometric Pass";
    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:source offset:preparedSource.offset atIndex:0u];
    [encoder setBuffer:output offset:preparedOutput.offset atIndex:1u];
    [encoder setBytes:&uniforms length:sizeof(uniforms) atIndex:2u];

    const NSUInteger maxThreads = pipeline.maxTotalThreadsPerThreadgroup;
    if (maxThreads == 0u) {
        [encoder endEncoding];
        error = "Film Breath Metal pipeline reported no thread capacity.";
        return false;
    }
    const NSUInteger threadWidth = std::max<NSUInteger>(
        1u,
        std::min<NSUInteger>(pipeline.threadExecutionWidth, maxThreads));
    const NSUInteger threadHeight = std::max<NSUInteger>(
        1u,
        std::min<NSUInteger>(16u, maxThreads / threadWidth));
    const MTLSize grid = MTLSizeMake(uniforms.width, uniforms.height, 1u);
    const MTLSize group = MTLSizeMake(threadWidth, threadHeight, 1u);
    [encoder dispatchThreads:grid threadsPerThreadgroup:group];
    [encoder endEncoding];
    [commandBuffer commit];
    return true;
}

}  // namespace filmtone::resolve::effects::film_breath
