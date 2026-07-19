#import <Metal/Metal.h>

#include "MetalIdentityBlit.h"

#include <cstddef>
#include <limits>

namespace filmtone::resolve::host {
namespace {

constexpr std::size_t kFloatRGBABytesPerPixel = sizeof(float) * 4;

bool contains(const RectI& outer, const RectI& inner) noexcept {
    return inner.x1 >= outer.x1 && inner.y1 >= outer.y1 &&
           inner.x2 <= outer.x2 && inner.y2 <= outer.y2;
}

bool checkedOffset(
    const MetalImageView& image,
    int x,
    int y,
    std::size_t byteCount,
    std::size_t bufferLength,
    std::size_t& offset) noexcept {
    const std::size_t row = static_cast<std::size_t>(y - image.bounds.y1);
    const std::size_t column = static_cast<std::size_t>(x - image.bounds.x1);
    const std::size_t stride = static_cast<std::size_t>(image.rowBytes);

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
    offset = rowOffset + columnOffset;
    return offset <= bufferLength && byteCount <= bufferLength - offset;
}

bool rowRangeFitsStride(
    const MetalImageView& image,
    const RectI& renderWindow,
    std::size_t byteCount) noexcept {
    const std::size_t column =
        static_cast<std::size_t>(renderWindow.x1 - image.bounds.x1);
    if (column > std::numeric_limits<std::size_t>::max() / kFloatRGBABytesPerPixel) {
        return false;
    }
    const std::size_t columnOffset = column * kFloatRGBABytesPerPixel;
    const std::size_t stride = static_cast<std::size_t>(image.rowBytes);
    return columnOffset <= stride && byteCount <= stride - columnOffset;
}

}  // namespace

bool encodeMetalIdentityBlit(
    const RenderContext& context,
    const MetalRenderInvocation& invocation,
    std::string& error) {
    if (invocation.commandQueue == nullptr ||
        invocation.source.buffer == nullptr ||
        invocation.output.buffer == nullptr) {
        error = "Metal identity render is missing a host buffer or command queue.";
        return false;
    }
    if (invocation.source.format != PixelFormat::floatRGBA ||
        invocation.output.format != PixelFormat::floatRGBA) {
        error = "Metal identity render requires float RGBA images.";
        return false;
    }
    if (invocation.source.rowBytes <= 0 || invocation.output.rowBytes <= 0) {
        error = "Metal identity render requires positive image row strides.";
        return false;
    }
    if (!contains(invocation.source.bounds, context.renderWindow) ||
        !contains(invocation.output.bounds, context.renderWindow)) {
        error = "Metal identity render window lies outside the host image bounds.";
        return false;
    }
    if (context.renderWindow.isEmpty()) {
        return true;
    }

    id<MTLCommandQueue> queue = static_cast<id<MTLCommandQueue>>(invocation.commandQueue);
    id<MTLBuffer> source = static_cast<id<MTLBuffer>>(invocation.source.buffer);
    id<MTLBuffer> output = static_cast<id<MTLBuffer>>(invocation.output.buffer);
    if (queue == nil || source == nil || output == nil) {
        error = "Metal identity render received an invalid host object.";
        return false;
    }

    if (source == output) {
        if (invocation.source.rowBytes == invocation.output.rowBytes &&
            invocation.source.bounds.x1 == invocation.output.bounds.x1 &&
            invocation.source.bounds.y1 == invocation.output.bounds.y1 &&
            invocation.source.bounds.x2 == invocation.output.bounds.x2 &&
            invocation.source.bounds.y2 == invocation.output.bounds.y2) {
            return true;
        }
        error = "Metal identity render cannot remap an aliased host buffer.";
        return false;
    }

    const std::size_t width = static_cast<std::size_t>(context.renderWindow.width());
    if (width > std::numeric_limits<std::size_t>::max() / kFloatRGBABytesPerPixel) {
        error = "Metal identity render width is not representable.";
        return false;
    }
    const std::size_t rowCopyBytes = width * kFloatRGBABytesPerPixel;
    if (!rowRangeFitsStride(invocation.source, context.renderWindow, rowCopyBytes) ||
        !rowRangeFitsStride(invocation.output, context.renderWindow, rowCopyBytes)) {
        error = "Metal identity render row exceeds a host image stride.";
        return false;
    }

    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    if (commandBuffer == nil) {
        error = "Metal command buffer creation failed.";
        return false;
    }
    commandBuffer.label = @"Filmtone Identity";

    id<MTLBlitCommandEncoder> encoder = [commandBuffer blitCommandEncoder];
    if (encoder == nil) {
        error = "Metal blit encoder creation failed.";
        return false;
    }

    for (int y = context.renderWindow.y1; y < context.renderWindow.y2; ++y) {
        std::size_t sourceOffset = 0;
        std::size_t outputOffset = 0;
        if (!checkedOffset(
                invocation.source,
                context.renderWindow.x1,
                y,
                rowCopyBytes,
                source.length,
                sourceOffset) ||
            !checkedOffset(
                invocation.output,
                context.renderWindow.x1,
                y,
                rowCopyBytes,
                output.length,
                outputOffset)) {
            [encoder endEncoding];
            error = "Metal identity render exceeds a host buffer.";
            return false;
        }

        [encoder copyFromBuffer:source
                   sourceOffset:sourceOffset
                       toBuffer:output
              destinationOffset:outputOffset
                           size:rowCopyBytes];
    }

    [encoder endEncoding];
    [commandBuffer commit];
    return true;
}

}  // namespace filmtone::resolve::host
