#import <Metal/Metal.h>

#include "WatermarkPass.h"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <vector>

#include "../Host/MetalPipelineCache.h"

namespace filmtone::resolve::watermark {
namespace {

constexpr std::size_t kFloatRGBABytesPerPixel = sizeof(float) * 4u;
constexpr double kDegreesToRadians = 0.017453292519943295769236907684886;
constexpr char kPipelineCacheKey[] = "filmtone.resolve.license.trial-watermark.v1";
constexpr char kMetalFunctionName[] = "filmtoneTrialWatermark";

// Default look — intentional placeholder for owner visual review (§3): a low
// opacity, mid-gray, diagonally tiled "FILMTONE TRIAL" text. Global canonical
// coordinates keep the pattern identical across proxy/full renders.
constexpr double kRotationDegrees = 30.0;
constexpr float kTexelCanonicalSize = 4.0f;       // canonical px per font texel
constexpr float kTileGapCanonicalX = 160.0f;      // horizontal space between repeats
constexpr float kTileGapCanonicalY = 130.0f;      // vertical space between repeats
constexpr float kOpacity = 0.16f;
constexpr float kColorR = 0.5f;
constexpr float kColorG = 0.5f;
constexpr float kColorB = 0.5f;

constexpr char kMetalSource[] = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct WatermarkUniforms {
    int renderOriginX;
    int renderOriginY;
    uint renderWidth;
    uint renderHeight;
    int outputOriginX;
    int outputOriginY;
    uint outputStridePixels;
    uint maskWidth;
    uint maskHeight;
    float renderScaleX;
    float renderScaleY;
    float cosT;
    float sinT;
    float texelSize;
    float tileWidth;
    float tileHeight;
    float opacity;
    float colorR;
    float colorG;
    float colorB;
};

kernel void filmtoneTrialWatermark(
    device float4* image [[buffer(0)]],
    constant uchar* mask [[buffer(1)]],
    constant WatermarkUniforms& u [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= u.renderWidth || gid.y >= u.renderHeight) {
        return;
    }
    const int px = u.renderOriginX + int(gid.x);
    const int py = u.renderOriginY + int(gid.y);
    const uint idx =
        uint(py - u.outputOriginY) * u.outputStridePixels +
        uint(px - u.outputOriginX);
    const float4 c = image[idx];

    // Resolution-independent canonical coordinates, then rotate + tile.
    const float cx = float(px) / u.renderScaleX;
    const float cy = float(py) / u.renderScaleY;
    const float ru = u.cosT * cx - u.sinT * cy;
    const float rv = u.sinT * cx + u.cosT * cy;
    const float lu = ru - floor(ru / u.tileWidth) * u.tileWidth;
    const float lv = rv - floor(rv / u.tileHeight) * u.tileHeight;
    const float tx = lu / u.texelSize;
    const float ty = lv / u.texelSize;

    float coverage = 0.0f;
    if (tx >= 0.0f && ty >= 0.0f &&
        tx < float(u.maskWidth) && ty < float(u.maskHeight)) {
        const uint mx = uint(tx);
        const uint my = uint(ty);
        const float a = float(mask[my * u.maskWidth + mx]) * (1.0f / 255.0f);
        coverage = a * u.opacity;
    }
    if (coverage > 0.0f) {
        const float3 wm = float3(u.colorR, u.colorG, u.colorB);
        // Alpha preserved; extended-range RGB left unclamped.
        image[idx] = float4(mix(c.rgb, wm, coverage), c.a);
    }
}
)METAL";

struct alignas(16) WatermarkUniforms final {
    std::int32_t renderOriginX;
    std::int32_t renderOriginY;
    std::uint32_t renderWidth;
    std::uint32_t renderHeight;
    std::int32_t outputOriginX;
    std::int32_t outputOriginY;
    std::uint32_t outputStridePixels;
    std::uint32_t maskWidth;
    std::uint32_t maskHeight;
    float renderScaleX;
    float renderScaleY;
    float cosT;
    float sinT;
    float texelSize;
    float tileWidth;
    float tileHeight;
    float opacity;
    float colorR;
    float colorG;
    float colorB;
};

static_assert(sizeof(WatermarkUniforms) == 80u);
static_assert(alignof(WatermarkUniforms) == 16u);

struct MaskData final {
    std::vector<std::uint8_t> pixels;
    std::uint32_t width = 0u;
    std::uint32_t height = 0u;
};

// Composed once: "FILMTONE TRIAL" in a 5x7 bitmap font (6px advance). Embedding
// the font avoids any render-time font-environment assumption.
const MaskData& trialMask() {
    static const MaskData mask = [] {
        struct Glyph {
            char c;
            std::uint8_t rows[7];  // 5 columns, bit 4 = leftmost
        };
        static const Glyph glyphs[] = {
            {'F', {0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10}},
            {'I', {0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x1F}},
            {'L', {0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F}},
            {'M', {0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11}},
            {'T', {0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04}},
            {'O', {0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E}},
            {'N', {0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11}},
            {'E', {0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F}},
            {'R', {0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11}},
            {'A', {0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11}},
            {' ', {0, 0, 0, 0, 0, 0, 0}},
        };
        const char text[] = "FILMTONE TRIAL";
        constexpr std::uint32_t advance = 6u;
        constexpr std::uint32_t glyphWidth = 5u;
        constexpr std::uint32_t glyphHeight = 7u;
        const std::uint32_t length =
            static_cast<std::uint32_t>(sizeof(text) - 1u);  // exclude NUL
        const std::uint32_t width = length * advance;
        const std::uint32_t height = glyphHeight;
        std::vector<std::uint8_t> pixels(
            static_cast<std::size_t>(width) * height, 0u);
        for (std::uint32_t i = 0u; i < length; ++i) {
            const char ch = text[i];
            const Glyph* glyph = nullptr;
            for (const Glyph& candidate : glyphs) {
                if (candidate.c == ch) {
                    glyph = &candidate;
                    break;
                }
            }
            if (glyph == nullptr) {
                continue;
            }
            for (std::uint32_t r = 0u; r < glyphHeight; ++r) {
                for (std::uint32_t col = 0u; col < glyphWidth; ++col) {
                    if ((glyph->rows[r] >> (4u - col)) & 1u) {
                        pixels[static_cast<std::size_t>(r) * width +
                               i * advance + col] = 255u;
                    }
                }
            }
        }
        return MaskData{std::move(pixels), width, height};
    }();
    return mask;
}

bool contains(const host::RectI& outer, const host::RectI& inner) noexcept {
    return inner.x1 >= outer.x1 && inner.y1 >= outer.y1 &&
           inner.x2 <= outer.x2 && inner.y2 <= outer.y2;
}

bool checkedOutputCapacity(
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
    if (width > std::numeric_limits<std::size_t>::max() / kFloatRGBABytesPerPixel) {
        return false;
    }
    const std::size_t rowBytes = width * kFloatRGBABytesPerPixel;
    if (rowBytes > stride ||
        stride / kFloatRGBABytesPerPixel >
            std::numeric_limits<std::uint32_t>::max()) {
        return false;
    }
    if (height == 0u ||
        height - 1u > std::numeric_limits<std::size_t>::max() / stride) {
        return false;
    }
    const std::size_t lastRowOffset = (height - 1u) * stride;
    if (lastRowOffset > std::numeric_limits<std::size_t>::max() - rowBytes ||
        lastRowOffset + rowBytes > bufferLength) {
        return false;
    }
    stridePixels = static_cast<std::uint32_t>(stride / kFloatRGBABytesPerPixel);
    return true;
}

}  // namespace

bool encodeMetalTrialWatermark(
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    host::MetalPipelineCache& pipelineCache,
    std::string& error) {
    if (invocation.commandQueue == nullptr ||
        invocation.output.buffer == nullptr) {
        error = "Filmtone watermark is missing a Metal command queue or output buffer.";
        return false;
    }
    if (invocation.output.format != host::PixelFormat::floatRGBA) {
        error = "Filmtone watermark requires a float RGBA output image.";
        return false;
    }
    if (invocation.output.rowBytes <= 0) {
        error = "Filmtone watermark requires a positive output row stride.";
        return false;
    }
    if (!contains(invocation.output.bounds, context.renderWindow)) {
        error = "Filmtone watermark render window lies outside the output bounds.";
        return false;
    }
    if (context.renderWindow.isEmpty()) {
        return true;
    }
    if (!std::isfinite(context.renderScale.x) || context.renderScale.x <= 0.0 ||
        !std::isfinite(context.renderScale.y) || context.renderScale.y <= 0.0) {
        error = "Filmtone watermark requires a positive render scale.";
        return false;
    }

    id<MTLCommandQueue> queue =
        static_cast<id<MTLCommandQueue>>(invocation.commandQueue);
    id<MTLBuffer> output =
        static_cast<id<MTLBuffer>>(invocation.output.buffer);
    if (queue == nil || output == nil) {
        error = "Filmtone watermark received an invalid Metal object.";
        return false;
    }

    std::uint32_t outputStridePixels = 0u;
    if (!checkedOutputCapacity(invocation.output, output.length, outputStridePixels)) {
        error = "Filmtone watermark output bounds or row stride exceed the Metal buffer.";
        return false;
    }

    const MaskData& mask = trialMask();
    if (mask.width == 0u || mask.height == 0u) {
        error = "Filmtone watermark mask is empty.";
        return false;
    }
    const double rotation = kRotationDegrees * kDegreesToRadians;
    const WatermarkUniforms uniforms{
        context.renderWindow.x1,
        context.renderWindow.y1,
        static_cast<std::uint32_t>(context.renderWindow.width()),
        static_cast<std::uint32_t>(context.renderWindow.height()),
        invocation.output.bounds.x1,
        invocation.output.bounds.y1,
        outputStridePixels,
        mask.width,
        mask.height,
        static_cast<float>(context.renderScale.x),
        static_cast<float>(context.renderScale.y),
        static_cast<float>(std::cos(rotation)),
        static_cast<float>(std::sin(rotation)),
        kTexelCanonicalSize,
        static_cast<float>(mask.width) * kTexelCanonicalSize + kTileGapCanonicalX,
        static_cast<float>(mask.height) * kTexelCanonicalSize + kTileGapCanonicalY,
        kOpacity,
        kColorR,
        kColorG,
        kColorB,
    };

    const host::MetalPipelineRequest pipelineRequest{
        kPipelineCacheKey,
        kMetalSource,
        kMetalFunctionName,
        false,
    };
    void* pipelinePointer =
        pipelineCache.getOrCreate(invocation.commandQueue, pipelineRequest, error);
    if (pipelinePointer == nullptr) {
        return false;
    }
    id<MTLComputePipelineState> pipeline =
        static_cast<id<MTLComputePipelineState>>(pipelinePointer);

    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    if (commandBuffer == nil) {
        error = "Filmtone watermark Metal command buffer creation failed.";
        return false;
    }
    commandBuffer.label = @"Filmtone Trial Watermark";
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    if (encoder == nil) {
        error = "Filmtone watermark Metal compute encoder creation failed.";
        return false;
    }
    encoder.label = @"Filmtone Trial Watermark";
    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:output offset:0u atIndex:0u];
    [encoder setBytes:mask.pixels.data()
               length:mask.pixels.size()
              atIndex:1u];
    [encoder setBytes:&uniforms length:sizeof(uniforms) atIndex:2u];

    const NSUInteger maximumThreads =
        std::max<NSUInteger>(1u, pipeline.maxTotalThreadsPerThreadgroup);
    const NSUInteger threadWidth = std::max<NSUInteger>(
        1u, std::min<NSUInteger>(pipeline.threadExecutionWidth, maximumThreads));
    const NSUInteger threadHeight = std::max<NSUInteger>(
        1u, std::min<NSUInteger>(16u, maximumThreads / threadWidth));
    [encoder dispatchThreads:MTLSizeMake(uniforms.renderWidth, uniforms.renderHeight, 1u)
        threadsPerThreadgroup:MTLSizeMake(threadWidth, threadHeight, 1u)];
    [encoder endEncoding];
    [commandBuffer commit];
    return true;
}

}  // namespace filmtone::resolve::watermark
