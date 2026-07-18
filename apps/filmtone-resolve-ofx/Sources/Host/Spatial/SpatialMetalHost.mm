#import <Metal/Metal.h>

#include "SpatialMetalHost.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <string>
#include <utility>
#include <vector>

namespace filmtone::resolve::host::spatial {
namespace {

constexpr std::size_t kFloatRGBABytesPerPixel = sizeof(float) * 4u;
constexpr std::size_t kMaximumTextureBindingsPerPass = 16u;
constexpr std::size_t kMaximumBytesBindingsPerPass = 16u;
constexpr std::uint32_t kMaximumShaderBindingIndex = 30u;

constexpr char kBridgeMetalSource[] = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct FilmtoneSpatialBufferToTextureUniformsV1 {
    uint sourceStridePixels;
    uint width;
    uint height;
    uint reserved;
};

struct FilmtoneSpatialTextureToBufferUniformsV1 {
    uint outputStridePixels;
    uint sourceX;
    uint sourceY;
    uint outputX;
    uint outputY;
    uint width;
    uint height;
    uint reserved;
};

kernel void filmtoneSpatialBufferToTextureV1(
    device const float4* source [[buffer(0)]],
    constant FilmtoneSpatialBufferToTextureUniformsV1& uniforms [[buffer(1)]],
    texture2d<float, access::write> output [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) {
        return;
    }
    output.write(source[gid.y * uniforms.sourceStridePixels + gid.x], gid);
}

kernel void filmtoneSpatialTextureToBufferV1(
    texture2d<float, access::read> source [[texture(0)]],
    device float4* output [[buffer(0)]],
    constant FilmtoneSpatialTextureToBufferUniformsV1& uniforms [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uniforms.width || gid.y >= uniforms.height) {
        return;
    }
    const uint2 sourceCoordinate = uint2(
        gid.x + uniforms.sourceX,
        gid.y + uniforms.sourceY);
    const uint outputIndex =
        (gid.y + uniforms.outputY) * uniforms.outputStridePixels +
        gid.x + uniforms.outputX;
    output[outputIndex] = source.read(sourceCoordinate);
}
)METAL";

struct BufferToTextureUniformsV1 final {
    std::uint32_t sourceStridePixels;
    std::uint32_t width;
    std::uint32_t height;
    std::uint32_t reserved;
};

struct TextureToBufferUniformsV1 final {
    std::uint32_t outputStridePixels;
    std::uint32_t sourceX;
    std::uint32_t sourceY;
    std::uint32_t outputX;
    std::uint32_t outputY;
    std::uint32_t width;
    std::uint32_t height;
    std::uint32_t reserved;
};

static_assert(sizeof(BufferToTextureUniformsV1) == 16u);
static_assert(sizeof(TextureToBufferUniformsV1) == 32u);

bool rectsEqual(const RectI& left, const RectI& right) noexcept {
    return left.x1 == right.x1 && left.y1 == right.y1 &&
           left.x2 == right.x2 && left.y2 == right.y2;
}

bool contains(const RectI& outer, const RectI& inner) noexcept {
    return inner.x1 >= outer.x1 && inner.y1 >= outer.y1 &&
           inner.x2 <= outer.x2 && inner.y2 <= outer.y2;
}

bool isPositiveFinite(double value) noexcept {
    return std::isfinite(value) && value > 0.0;
}

bool isKnownPlane(SpatialImagePlane plane) noexcept {
    return plane == SpatialImagePlane::ping ||
           plane == SpatialImagePlane::pong;
}

bool isKnownAccess(SpatialTextureAccess access) noexcept {
    return access == SpatialTextureAccess::readOnly ||
           access == SpatialTextureAccess::writeOnly;
}

bool checkedMultiply(
    std::size_t left,
    std::size_t right,
    std::size_t& result) noexcept {
    if (left != 0u && right > std::numeric_limits<std::size_t>::max() / left) {
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

std::uint32_t mipDimension(
    std::uint32_t dimension,
    std::uint32_t level) noexcept {
    for (std::uint32_t index = 0u; index < level && dimension > 1u; ++index) {
        dimension /= 2u;
    }
    return std::max<std::uint32_t>(1u, dimension);
}

std::uint32_t completeMipLevelCount(
    std::uint32_t width,
    std::uint32_t height) noexcept {
    std::uint32_t count = 1u;
    while (width > 1u || height > 1u) {
        width = std::max<std::uint32_t>(1u, width / 2u);
        height = std::max<std::uint32_t>(1u, height / 2u);
        ++count;
    }
    return count;
}

bool tightPyramidPairBytes(
    std::uint32_t width,
    std::uint32_t height,
    std::uint32_t levelCount,
    std::size_t& result) noexcept {
    std::size_t onePyramidBytes = 0u;
    for (std::uint32_t level = 0u; level < levelCount; ++level) {
        std::size_t pixelCount = 0u;
        std::size_t levelBytes = 0u;
        if (!checkedMultiply(
                static_cast<std::size_t>(mipDimension(width, level)),
                static_cast<std::size_t>(mipDimension(height, level)),
                pixelCount) ||
            !checkedMultiply(pixelCount, kFloatRGBABytesPerPixel, levelBytes) ||
            !checkedAdd(onePyramidBytes, levelBytes, onePyramidBytes)) {
            return false;
        }
    }
    return checkedMultiply(onePyramidBytes, 2u, result);
}

bool validateImageView(
    const MetalImageView& image,
    const char* label,
    id<MTLBuffer>& buffer,
    std::string& error) {
    if (image.buffer == nullptr || image.bounds.isEmpty()) {
        error = std::string("Spatial Metal ") + label +
            " image is missing its buffer or bounds.";
        return false;
    }
    if (image.format != PixelFormat::floatRGBA) {
        error = std::string("Spatial Metal ") + label +
            " image must be float RGBA.";
        return false;
    }
    if (image.rowBytes <= 0 ||
        image.rowBytes % static_cast<std::ptrdiff_t>(kFloatRGBABytesPerPixel) != 0) {
        error = std::string("Spatial Metal ") + label +
            " row stride must be positive and float4-aligned.";
        return false;
    }

    const std::size_t width = static_cast<std::size_t>(image.bounds.width());
    const std::size_t height = static_cast<std::size_t>(image.bounds.height());
    const std::size_t stridePixels =
        static_cast<std::size_t>(image.rowBytes) / kFloatRGBABytesPerPixel;
    std::size_t tightRowBytes = 0u;
    if (!checkedMultiply(width, kFloatRGBABytesPerPixel, tightRowBytes) ||
        static_cast<std::size_t>(image.rowBytes) < tightRowBytes ||
        stridePixels > std::numeric_limits<std::uint32_t>::max()) {
        error = std::string("Spatial Metal ") + label +
            " row stride is outside its RGBA32F or shader-index range.";
        return false;
    }

    buffer = static_cast<id<MTLBuffer>>(image.buffer);
    if (buffer == nil) {
        error = std::string("Spatial Metal ") + label +
            " buffer is not a valid Metal buffer.";
        return false;
    }

    std::size_t lastRowOffset = 0u;
    std::size_t minimumLength = 0u;
    if (height == 0u ||
        !checkedMultiply(
            height - 1u,
            static_cast<std::size_t>(image.rowBytes),
            lastRowOffset) ||
        !checkedAdd(lastRowOffset, tightRowBytes, minimumLength) ||
        minimumLength > static_cast<std::size_t>(buffer.length)) {
        error = std::string("Spatial Metal ") + label +
            " bounds and row stride exceed its Metal buffer.";
        return false;
    }
    std::size_t lastPixelIndex = 0u;
    if (!checkedMultiply(height - 1u, stridePixels, lastPixelIndex) ||
        !checkedAdd(lastPixelIndex, width - 1u, lastPixelIndex) ||
        lastPixelIndex > std::numeric_limits<std::uint32_t>::max()) {
        error = std::string("Spatial Metal ") + label +
            " pixel addressing exceeds the v1 shader index range.";
        return false;
    }
    return true;
}

bool makeFrameDescriptor(
    const RenderContext& context,
    const MetalRenderInvocation& invocation,
    double pixelAspectRatio,
    SpatialFrameDescriptor& frame,
    id<MTLCommandQueue>& queue,
    id<MTLBuffer>& source,
    id<MTLBuffer>& output,
    std::string& error) {
    if (invocation.commandQueue == nullptr) {
        error = "Spatial Metal requires the host-provided Metal command queue.";
        return false;
    }
    queue = static_cast<id<MTLCommandQueue>>(invocation.commandQueue);
    if (queue == nil || queue.device == nil) {
        error = "Spatial Metal received an invalid Metal command queue.";
        return false;
    }
    if (!validateImageView(invocation.source, "source", source, error) ||
        !validateImageView(invocation.output, "output", output, error)) {
        return false;
    }
    if (!rectsEqual(invocation.source.bounds, invocation.output.bounds)) {
        error = "Spatial Metal v1 requires identical source and output bounds.";
        return false;
    }
    if (context.sourceBounds.has_value() &&
        !rectsEqual(*context.sourceBounds, invocation.source.bounds)) {
        error = "Spatial Metal source bounds disagree with RenderContext.";
        return false;
    }
    if (context.outputBounds.has_value() &&
        !rectsEqual(*context.outputBounds, invocation.output.bounds)) {
        error = "Spatial Metal output bounds disagree with RenderContext.";
        return false;
    }
    if (!contains(invocation.output.bounds, context.renderWindow)) {
        error = "Spatial Metal render window lies outside the full image bounds.";
        return false;
    }
    if (!isPositiveFinite(context.renderScale.x) ||
        !isPositiveFinite(context.renderScale.y) ||
        !isPositiveFinite(pixelAspectRatio)) {
        error = "Spatial Metal requires finite positive render scale and pixel aspect ratio.";
        return false;
    }

    const std::size_t width =
        static_cast<std::size_t>(invocation.output.bounds.width());
    const std::size_t height =
        static_cast<std::size_t>(invocation.output.bounds.height());
    if (width > std::numeric_limits<std::uint32_t>::max() ||
        height > std::numeric_limits<std::uint32_t>::max()) {
        error = "Spatial Metal image dimensions exceed the v1 ABI range.";
        return false;
    }

    const double logicalDisplayWidth =
        static_cast<double>(width) * pixelAspectRatio / context.renderScale.x;
    const double logicalDisplayHeight =
        static_cast<double>(height) / context.renderScale.y;
    const double shortAxis = std::min(logicalDisplayWidth, logicalDisplayHeight);
    if (!isPositiveFinite(logicalDisplayWidth) ||
        !isPositiveFinite(logicalDisplayHeight) ||
        !isPositiveFinite(shortAxis)) {
        error = "Spatial Metal could not derive finite logical display dimensions.";
        return false;
    }

    const int renderWindowX =
        context.renderWindow.x1 - invocation.output.bounds.x1;
    const int renderWindowY =
        context.renderWindow.y1 - invocation.output.bounds.y1;
    frame = SpatialFrameDescriptor{
        invocation.output.bounds.x1,
        invocation.output.bounds.y1,
        static_cast<std::uint32_t>(width),
        static_cast<std::uint32_t>(height),
        static_cast<std::uint32_t>(renderWindowX),
        static_cast<std::uint32_t>(renderWindowY),
        static_cast<std::uint32_t>(context.renderWindow.width()),
        static_cast<std::uint32_t>(context.renderWindow.height()),
        context.renderScale.x,
        context.renderScale.y,
        pixelAspectRatio,
        logicalDisplayWidth,
        logicalDisplayHeight,
        logicalDisplayWidth / logicalDisplayHeight,
        2.0 * pixelAspectRatio / (context.renderScale.x * shortAxis),
        2.0 / (context.renderScale.y * shortAxis),
    };
    return true;
}

class SpatialTexturePool final {
public:
    SpatialTexturePool() = default;

    ~SpatialTexturePool() {
        for (id<MTLTexture> texture : textures_) {
            [texture release];
        }
    }

    SpatialTexturePool(const SpatialTexturePool&) = delete;
    SpatialTexturePool& operator=(const SpatialTexturePool&) = delete;

    bool allocate(
        id<MTLDevice> device,
        std::uint32_t width,
        std::uint32_t height,
        std::uint32_t mipLevelCount,
        std::size_t reservedFollowingQueueBytes,
        SpatialExecutionReport& report,
        std::string& error) {
        if (device == nil || width == 0u || height == 0u || mipLevelCount == 0u) {
            error = "Spatial Metal cannot allocate an empty texture pool.";
            return false;
        }

        std::size_t tightBytes = 0u;
        if (!tightPyramidPairBytes(
                width,
                height,
                mipLevelCount,
                tightBytes)) {
            error = "Spatial Metal texture-pyramid size is not representable.";
            return false;
        }
        if (tightBytes > kSpatialTransientMemoryCeilingBytes) {
            error = "Spatial Metal texture plan exceeds the 384 MiB transient ceiling.";
            return false;
        }

        MTLTextureDescriptor* descriptor =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                                               width:width
                                                              height:height
                                                           mipmapped:NO];
        descriptor.mipmapLevelCount = mipLevelCount;
        descriptor.storageMode = MTLStorageModePrivate;
        descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;

        const MTLSizeAndAlign estimated =
            [device heapTextureSizeAndAlignWithDescriptor:descriptor];
        std::size_t estimatedPairBytes = 0u;
        if (estimated.size == 0u ||
            !checkedMultiply(
                static_cast<std::size_t>(estimated.size),
                2u,
                estimatedPairBytes) ||
            estimatedPairBytes > kSpatialTransientMemoryCeilingBytes) {
            error = "Spatial Metal aligned texture plan exceeds the 384 MiB transient ceiling.";
            return false;
        }

        textures_[0] = [device newTextureWithDescriptor:descriptor];
        textures_[1] = [device newTextureWithDescriptor:descriptor];
        if (textures_[0] == nil || textures_[1] == nil) {
            error = "Spatial Metal could not allocate its bounded RGBA32F ping-pong pool.";
            return false;
        }
        textures_[0].label = @"Filmtone Spatial Ping Pyramid";
        textures_[1].label = @"Filmtone Spatial Pong Pyramid";

        std::size_t actualAllocatedBytes = 0u;
        if (!checkedAdd(
                static_cast<std::size_t>(textures_[0].allocatedSize),
                static_cast<std::size_t>(textures_[1].allocatedSize),
                actualAllocatedBytes)) {
            error = "Spatial Metal actual texture allocation is not representable.";
            return false;
        }
        const std::size_t accountedAllocatedBytes = std::max(
            estimatedPairBytes,
            actualAllocatedBytes);
        if (accountedAllocatedBytes > kSpatialTransientMemoryCeilingBytes) {
            error = "Spatial Metal actual texture allocation exceeds the 384 MiB transient ceiling.";
            return false;
        }
        std::size_t combinedAccountedBytes = 0u;
        if (!checkedAdd(
                accountedAllocatedBytes,
                reservedFollowingQueueBytes,
                combinedAccountedBytes) ||
            combinedAccountedBytes >
                kIntegratedUhdTransientMemoryCeilingBytes) {
            error = "Spatial Metal plus following queue resources exceed the 640 MiB integrated transient ceiling.";
            return false;
        }

        width_ = width;
        height_ = height;
        mipLevelCount_ = mipLevelCount;
        report.allocatedMipLevelCount = mipLevelCount;
        report.tightTextureBytes = tightBytes;
        report.allocatedTextureBytes = accountedAllocatedBytes;
        report.reservedFollowingQueueBytes = reservedFollowingQueueBytes;
        report.combinedAccountedBytes = combinedAccountedBytes;
        return true;
    }

    [[nodiscard]] id<MTLTexture> baseTexture(
        SpatialImagePlane plane) const noexcept {
        return textures_[plane == SpatialImagePlane::ping ? 0u : 1u];
    }

    [[nodiscard]] id<MTLTexture> newLevelView(
        const SpatialImageView& image) const noexcept {
        if (image.mipLevel >= mipLevelCount_) {
            return nil;
        }
        id<MTLTexture> texture = baseTexture(image.plane);
        if (texture == nil) {
            return nil;
        }
        return [texture
            newTextureViewWithPixelFormat:MTLPixelFormatRGBA32Float
                              textureType:MTLTextureType2D
                                   levels:NSMakeRange(image.mipLevel, 1u)
                                   slices:NSMakeRange(0u, 1u)];
    }

    [[nodiscard]] std::uint32_t width() const noexcept { return width_; }
    [[nodiscard]] std::uint32_t height() const noexcept { return height_; }
    [[nodiscard]] std::uint32_t mipLevelCount() const noexcept {
        return mipLevelCount_;
    }

private:
    std::array<id<MTLTexture>, 2> textures_{nil, nil};
    std::uint32_t width_ = 0u;
    std::uint32_t height_ = 0u;
    std::uint32_t mipLevelCount_ = 0u;
};

struct ResourceScopeState final {
    std::uint64_t executionToken = 0u;
    std::uint32_t width = 0u;
    std::uint32_t height = 0u;
    std::uint32_t declaredMipLevelCount = 0u;
};

struct CommandContextState final {
    id<MTLCommandQueue> queue = nil;
    id<MTLCommandBuffer> commandBuffer = nil;
    MetalPipelineCache* pipelineCache = nullptr;
    SpatialTexturePool* pool = nullptr;
    std::uint64_t executionToken = 0u;

    bool moduleEncoding = false;
    SpatialImageView moduleSource{};
    SpatialImageView moduleOutput{};
    std::uint32_t moduleMipLevelCount = 0u;
    std::size_t moduleStartPassCount = 0u;
    bool moduleOutputWritten = false;
    std::size_t encodedFeaturePassCount = 0u;
};

bool imageHandlesEqual(
    const SpatialImageView& left,
    const SpatialImageView& right) noexcept {
    return left.executionToken == right.executionToken &&
           left.plane == right.plane &&
           left.mipLevel == right.mipLevel;
}

bool validateImageCapability(
    const CommandContextState& state,
    const SpatialImageView& image,
    std::string& error) {
    if (!state.moduleEncoding ||
        image.executionToken == 0u ||
        image.executionToken != state.executionToken ||
        !isKnownPlane(image.plane) ||
        image.mipLevel >= state.moduleMipLevelCount ||
        image.mipLevel >= state.pool->mipLevelCount()) {
        error = "Spatial compute pass received an expired or undeclared image capability.";
        return false;
    }
    const std::uint32_t expectedWidth =
        mipDimension(state.pool->width(), image.mipLevel);
    const std::uint32_t expectedHeight =
        mipDimension(state.pool->height(), image.mipLevel);
    if (image.width != expectedWidth || image.height != expectedHeight) {
        error = "Spatial compute pass image dimensions disagree with its mip capability.";
        return false;
    }
    return true;
}

void releaseTextureViews(std::vector<id<MTLTexture>>& views) noexcept {
    for (id<MTLTexture> view : views) {
        [view release];
    }
    views.clear();
}

bool dispatchPipeline(
    id<MTLComputeCommandEncoder> encoder,
    id<MTLComputePipelineState> pipeline,
    const SpatialThreadGrid& grid,
    std::string& error) {
    const NSUInteger executionWidth = pipeline.threadExecutionWidth;
    const NSUInteger maximumThreads = pipeline.maxTotalThreadsPerThreadgroup;
    if (executionWidth == 0u || maximumThreads < executionWidth) {
        error = "Spatial Metal pipeline reported an invalid thread capacity.";
        return false;
    }
    const NSUInteger groupHeight = std::max<NSUInteger>(
        1u,
        std::min<NSUInteger>(16u, maximumThreads / executionWidth));
    [encoder dispatchThreads:MTLSizeMake(grid.width, grid.height, grid.depth)
        threadsPerThreadgroup:MTLSizeMake(executionWidth, groupHeight, 1u)];
    return true;
}

bool encodeBufferToTexture(
    CommandContextState& state,
    id<MTLBuffer> source,
    std::ptrdiff_t sourceRowBytes,
    std::uint32_t width,
    std::uint32_t height,
    std::string& error) {
    const MetalPipelineRequest request{
        "filmtone.resolve.spatial.bridge.v1.buffer-to-texture.rgba32f",
        kBridgeMetalSource,
        "filmtoneSpatialBufferToTextureV1",
        false,
    };
    void* pipelineValue = state.pipelineCache->getOrCreate(
        static_cast<void*>(state.queue),
        request,
        error);
    if (pipelineValue == nullptr) {
        return false;
    }
    id<MTLComputePipelineState> pipeline =
        static_cast<id<MTLComputePipelineState>>(pipelineValue);
    id<MTLComputeCommandEncoder> encoder =
        [state.commandBuffer computeCommandEncoder];
    if (encoder == nil) {
        error = "Spatial Metal could not create its buffer-to-texture encoder.";
        return false;
    }
    encoder.label = @"Filmtone Spatial Buffer To Texture";
    const BufferToTextureUniformsV1 uniforms{
        static_cast<std::uint32_t>(
            sourceRowBytes / static_cast<std::ptrdiff_t>(kFloatRGBABytesPerPixel)),
        width,
        height,
        0u,
    };
    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:source offset:0u atIndex:0u];
    [encoder setBytes:&uniforms length:sizeof(uniforms) atIndex:1u];
    [encoder setTexture:state.pool->baseTexture(SpatialImagePlane::ping)
               atIndex:0u];
    const bool dispatched = dispatchPipeline(
        encoder,
        pipeline,
        SpatialThreadGrid{width, height, 1u},
        error);
    [encoder endEncoding];
    return dispatched;
}

bool encodeTextureToBuffer(
    CommandContextState& state,
    SpatialImagePlane sourcePlane,
    id<MTLBuffer> output,
    std::ptrdiff_t outputRowBytes,
    const SpatialFrameDescriptor& frame,
    std::string& error) {
    const MetalPipelineRequest request{
        "filmtone.resolve.spatial.bridge.v1.texture-to-buffer.rgba32f",
        kBridgeMetalSource,
        "filmtoneSpatialTextureToBufferV1",
        false,
    };
    void* pipelineValue = state.pipelineCache->getOrCreate(
        static_cast<void*>(state.queue),
        request,
        error);
    if (pipelineValue == nullptr) {
        return false;
    }
    id<MTLComputePipelineState> pipeline =
        static_cast<id<MTLComputePipelineState>>(pipelineValue);
    id<MTLComputeCommandEncoder> encoder =
        [state.commandBuffer computeCommandEncoder];
    if (encoder == nil) {
        error = "Spatial Metal could not create its texture-to-buffer encoder.";
        return false;
    }
    encoder.label = @"Filmtone Spatial Texture To Buffer";
    const TextureToBufferUniformsV1 uniforms{
        static_cast<std::uint32_t>(
            outputRowBytes / static_cast<std::ptrdiff_t>(kFloatRGBABytesPerPixel)),
        frame.renderWindowX,
        frame.renderWindowY,
        frame.renderWindowX,
        frame.renderWindowY,
        frame.renderWindowWidth,
        frame.renderWindowHeight,
        0u,
    };
    [encoder setComputePipelineState:pipeline];
    [encoder setTexture:state.pool->baseTexture(sourcePlane) atIndex:0u];
    [encoder setBuffer:output offset:0u atIndex:0u];
    [encoder setBytes:&uniforms length:sizeof(uniforms) atIndex:1u];
    const bool dispatched = dispatchPipeline(
        encoder,
        pipeline,
        SpatialThreadGrid{
            frame.renderWindowWidth,
            frame.renderWindowHeight,
            1u,
        },
        error);
    [encoder endEncoding];
    return dispatched;
}

SpatialImageView makeImageView(
    const ResourceScopeState& state,
    SpatialImagePlane plane,
    std::uint32_t mipLevel) noexcept {
    return SpatialImageView{
        state.executionToken,
        plane,
        mipLevel,
        mipDimension(state.width, mipLevel),
        mipDimension(state.height, mipLevel),
    };
}

SpatialImagePlane opposite(SpatialImagePlane plane) noexcept {
    return plane == SpatialImagePlane::ping
        ? SpatialImagePlane::pong
        : SpatialImagePlane::ping;
}

struct ActiveSpatialModule final {
    const SpatialModuleProcessor* processor = nullptr;
    SpatialResourcePlan plan{};
};

std::atomic<std::uint64_t> gNextExecutionToken{1u};

}  // namespace

SpatialMetalCommandContext::SpatialMetalCommandContext(void* state) noexcept
    : state_(state) {}

bool SpatialMetalCommandContext::encodeComputePass(
    const SpatialComputePass& pass,
    std::string& error) {
    auto* state = static_cast<CommandContextState*>(state_);
    if (state == nullptr || !state->moduleEncoding || state->pipelineCache == nullptr ||
        state->pool == nullptr || state->commandBuffer == nil) {
        error = "Spatial compute pass is outside an active module encode scope.";
        return false;
    }
    if (pass.label == nullptr || pass.label[0] == '\0' || pass.pipeline == nullptr) {
        error = "Spatial compute pass requires a label and pipeline request.";
        return false;
    }
    if (pass.pipeline->fastMathEnabled) {
        error = "Spatial ABI v1 rejects fast-math pipelines to keep fidelity explicit.";
        return false;
    }
    if (pass.textureBindingCount == 0u ||
        pass.textureBindingCount > kMaximumTextureBindingsPerPass ||
        pass.textureBindings == nullptr ||
        pass.bytesBindingCount > kMaximumBytesBindingsPerPass ||
        (pass.bytesBindingCount != 0u && pass.bytesBindings == nullptr) ||
        pass.grid.width == 0u || pass.grid.height == 0u || pass.grid.depth != 1u) {
        error = "Spatial compute pass has invalid bindings or dispatch dimensions.";
        return false;
    }

    bool hasRead = false;
    bool hasWrite = false;
    bool targetsModuleOutput = false;
    for (std::size_t index = 0u; index < pass.textureBindingCount; ++index) {
        const SpatialTextureBinding& binding = pass.textureBindings[index];
        if (binding.shaderIndex > kMaximumShaderBindingIndex ||
            !isKnownAccess(binding.access) ||
            !validateImageCapability(*state, binding.image, error)) {
            if (error.empty()) {
                error = "Spatial compute pass has an invalid texture binding.";
            }
            return false;
        }
        for (std::size_t previous = 0u; previous < index; ++previous) {
            const SpatialTextureBinding& earlier = pass.textureBindings[previous];
            if (earlier.shaderIndex == binding.shaderIndex) {
                error = "Spatial compute pass binds two textures at the same shader index.";
                return false;
            }
            if (earlier.image.plane == binding.image.plane &&
                earlier.access != binding.access) {
                error = "Spatial ABI v1 forbids read/write aliasing within one ping-pong plane.";
                return false;
            }
        }

        if (binding.access == SpatialTextureAccess::readOnly) {
            hasRead = true;
            continue;
        }
        hasWrite = true;
        if (imageHandlesEqual(binding.image, state->moduleSource)) {
            error = "Spatial module cannot overwrite its retained full-resolution input.";
            return false;
        }
        if (binding.image.width != pass.grid.width ||
            binding.image.height != pass.grid.height) {
            error = "Spatial write target dimensions must match the full dispatch grid.";
            return false;
        }
        if (imageHandlesEqual(binding.image, state->moduleOutput)) {
            targetsModuleOutput = true;
        }
    }
    if (!hasRead || !hasWrite) {
        error = "Spatial compute pass requires at least one read and one write texture.";
        return false;
    }

    for (std::size_t index = 0u; index < pass.bytesBindingCount; ++index) {
        const SpatialBytesBinding& binding = pass.bytesBindings[index];
        if (binding.shaderIndex > kMaximumShaderBindingIndex ||
            binding.bytes == nullptr || binding.length == 0u ||
            binding.length > kSpatialMaxInlineBytesPerBinding) {
            error = "Spatial compute pass has an invalid inline-bytes binding.";
            return false;
        }
        for (std::size_t previous = 0u; previous < index; ++previous) {
            if (pass.bytesBindings[previous].shaderIndex == binding.shaderIndex) {
                error = "Spatial compute pass binds inline bytes at a duplicate shader index.";
                return false;
            }
        }
    }

    void* pipelineValue = state->pipelineCache->getOrCreate(
        static_cast<void*>(state->queue),
        *pass.pipeline,
        error);
    if (pipelineValue == nullptr) {
        return false;
    }
    id<MTLComputePipelineState> pipeline =
        static_cast<id<MTLComputePipelineState>>(pipelineValue);

    std::vector<id<MTLTexture>> textureViews;
    textureViews.reserve(pass.textureBindingCount);
    for (std::size_t index = 0u; index < pass.textureBindingCount; ++index) {
        id<MTLTexture> textureView =
            state->pool->newLevelView(pass.textureBindings[index].image);
        if (textureView == nil) {
            releaseTextureViews(textureViews);
            error = "Spatial compute pass could not create a scoped mip texture view.";
            return false;
        }
        textureViews.push_back(textureView);
    }

    id<MTLComputeCommandEncoder> encoder =
        [state->commandBuffer computeCommandEncoder];
    if (encoder == nil) {
        releaseTextureViews(textureViews);
        error = "Spatial compute pass could not create a Metal compute encoder.";
        return false;
    }
    encoder.label = [NSString stringWithUTF8String:pass.label];
    [encoder setComputePipelineState:pipeline];
    for (std::size_t index = 0u; index < pass.textureBindingCount; ++index) {
        [encoder setTexture:textureViews[index]
                   atIndex:pass.textureBindings[index].shaderIndex];
    }
    for (std::size_t index = 0u; index < pass.bytesBindingCount; ++index) {
        const SpatialBytesBinding& binding = pass.bytesBindings[index];
        [encoder setBytes:binding.bytes
                   length:binding.length
                  atIndex:binding.shaderIndex];
    }
    const bool dispatched = dispatchPipeline(
        encoder,
        pipeline,
        pass.grid,
        error);
    [encoder endEncoding];
    releaseTextureViews(textureViews);
    if (!dispatched) {
        return false;
    }
    if (targetsModuleOutput) {
        state->moduleOutputWritten = true;
    }
    ++state->encodedFeaturePassCount;
    return true;
}

std::size_t SpatialMetalCommandContext::encodedPassCount() const noexcept {
    const auto* state = static_cast<const CommandContextState*>(state_);
    return state == nullptr ? 0u : state->encodedFeaturePassCount;
}

SpatialResourceScope::SpatialResourceScope(void* state) noexcept
    : state_(state) {}

bool SpatialResourceScope::image(
    SpatialImagePlane plane,
    std::uint32_t mipLevel,
    SpatialImageView& view,
    std::string& error) const noexcept {
    const auto* state = static_cast<const ResourceScopeState*>(state_);
    if (state == nullptr || state->executionToken == 0u ||
        !isKnownPlane(plane) ||
        mipLevel >= state->declaredMipLevelCount) {
        error = "Spatial module requested an undeclared or expired mip resource.";
        return false;
    }
    view = makeImageView(*state, plane, mipLevel);
    return true;
}

class SpatialMetalExecutionDriver final {
public:
    static bool encode(
        const RenderContext& context,
        const MetalRenderInvocation& invocation,
        double pixelAspectRatio,
        std::size_t reservedFollowingQueueBytes,
        const SpatialModuleProcessor* const* modules,
        std::size_t moduleCount,
        MetalPipelineCache& pipelineCache,
        SpatialExecutionReport& report,
        std::string& error) {
        report = SpatialExecutionReport{};
        error.clear();

        if (context.renderWindow.isEmpty()) {
            return true;
        }
        if (moduleCount != 0u && modules == nullptr) {
            error = "Spatial Metal module array is missing.";
            return false;
        }

        std::vector<const SpatialModuleProcessor*> activeProcessors;
        activeProcessors.reserve(moduleCount);
        for (std::size_t index = 0u; index < moduleCount; ++index) {
            const SpatialModuleProcessor* processor = modules[index];
            if (processor == nullptr || processor->name() == nullptr ||
                processor->name()[0] == '\0') {
                error = "Spatial Metal received a null or unnamed module.";
                return false;
            }
            if (!processor->isIdentity(context)) {
                activeProcessors.push_back(processor);
            }
        }
        if (activeProcessors.empty()) {
            return true;
        }

        SpatialFrameDescriptor frame{};
        id<MTLCommandQueue> queue = nil;
        id<MTLBuffer> source = nil;
        id<MTLBuffer> output = nil;
        if (!makeFrameDescriptor(
                context,
                invocation,
                pixelAspectRatio,
                frame,
                queue,
                source,
                output,
                error)) {
            return false;
        }
        const std::uint32_t maximumMipLevels =
            completeMipLevelCount(frame.width, frame.height);
        std::uint32_t requestedMipLevelCount = 1u;
        std::vector<ActiveSpatialModule> activeModules;
        activeModules.reserve(activeProcessors.size());
        for (const SpatialModuleProcessor* processor : activeProcessors) {
            SpatialResourcePlan plan{};
            error.clear();
            if (!processor->makeResourcePlan(context, frame, plan, error)) {
                if (error.empty()) {
                    error = std::string(processor->name()) +
                        " could not create its spatial resource plan.";
                }
                return false;
            }
            if (plan.abiVersion != kSpatialModuleAbiVersion ||
                plan.passCount == 0u ||
                plan.passCount > kSpatialMaxPassesPerModule ||
                plan.mipLevelCount == 0u ||
                plan.mipLevelCount > maximumMipLevels ||
                plan.edgeMode != SpatialEdgeMode::clampToEdge ||
                !plan.requiresFullFrame ||
                !plan.preservesExtendedRange ||
                !plan.preservesAlpha) {
                error = std::string(processor->name()) +
                    " returned a resource plan outside Spatial ABI v1.";
                return false;
            }
            requestedMipLevelCount = std::max(
                requestedMipLevelCount,
                plan.mipLevelCount);
            activeModules.push_back(ActiveSpatialModule{processor, plan});
        }

        report.activeModuleCount = activeModules.size();
        SpatialTexturePool pool;
        if (!pool.allocate(
                queue.device,
                frame.width,
                frame.height,
                requestedMipLevelCount,
                reservedFollowingQueueBytes,
                report,
                error)) {
            return false;
        }

        id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
        if (commandBuffer == nil) {
            error = "Spatial Metal could not create its coordinator-owned command buffer.";
            return false;
        }
        commandBuffer.label = @"Filmtone Spatial Graph";

        std::uint64_t executionToken =
            gNextExecutionToken.fetch_add(1u, std::memory_order_relaxed);
        if (executionToken == 0u) {
            executionToken =
                gNextExecutionToken.fetch_add(1u, std::memory_order_relaxed);
        }
        ResourceScopeState resourceState{
            executionToken,
            frame.width,
            frame.height,
            1u,
        };
        CommandContextState commandState{
            queue,
            commandBuffer,
            &pipelineCache,
            &pool,
            executionToken,
        };
        SpatialResourceScope resources(&resourceState);
        SpatialMetalCommandContext commands(&commandState);

        if (!encodeBufferToTexture(
                commandState,
                source,
                invocation.source.rowBytes,
                frame.width,
                frame.height,
                error)) {
            return false;
        }

        SpatialImagePlane currentPlane = SpatialImagePlane::ping;
        for (const ActiveSpatialModule& module : activeModules) {
            resourceState.declaredMipLevelCount = module.plan.mipLevelCount;
            const SpatialImageView sourceView =
                makeImageView(resourceState, currentPlane, 0u);
            const SpatialImageView outputView =
                makeImageView(resourceState, opposite(currentPlane), 0u);

            commandState.moduleEncoding = true;
            commandState.moduleSource = sourceView;
            commandState.moduleOutput = outputView;
            commandState.moduleMipLevelCount = module.plan.mipLevelCount;
            commandState.moduleStartPassCount =
                commandState.encodedFeaturePassCount;
            commandState.moduleOutputWritten = false;

            const SpatialEncodeInvocation moduleInvocation{
                frame,
                sourceView,
                outputView,
                resources,
                commands,
            };
            error.clear();
            const bool encoded = module.processor->encodeSpatialMetal(
                context,
                moduleInvocation,
                error);
            commandState.moduleEncoding = false;
            resourceState.declaredMipLevelCount = 0u;
            if (!encoded) {
                if (error.empty()) {
                    error = std::string(module.processor->name()) +
                        " failed without a spatial encode error.";
                }
                return false;
            }

            const std::size_t modulePassCount =
                commandState.encodedFeaturePassCount -
                commandState.moduleStartPassCount;
            if (modulePassCount != module.plan.passCount ||
                !commandState.moduleOutputWritten) {
                error = std::string(module.processor->name()) +
                    " did not fulfill its declared pass/output resource plan.";
                return false;
            }
            currentPlane = opposite(currentPlane);
        }

        if (!encodeTextureToBuffer(
                commandState,
                currentPlane,
                output,
                invocation.output.rowBytes,
                frame,
                error)) {
            return false;
        }

        report.encodedFeaturePassCount =
            commandState.encodedFeaturePassCount;
        report.outcome = SpatialExecutionOutcome::encoded;
        [commandBuffer commit];
        return true;
    }
};

bool encodeSpatialMetalSequence(
    const RenderContext& context,
    const MetalRenderInvocation& invocation,
    double pixelAspectRatio,
    std::size_t reservedFollowingQueueBytes,
    const SpatialModuleProcessor* const* modules,
    std::size_t moduleCount,
    MetalPipelineCache& pipelineCache,
    SpatialExecutionReport& report,
    std::string& error) {
    return SpatialMetalExecutionDriver::encode(
        context,
        invocation,
        pixelAspectRatio,
        reservedFollowingQueueBytes,
        modules,
        moduleCount,
        pipelineCache,
        report,
        error);
}

}  // namespace filmtone::resolve::host::spatial
