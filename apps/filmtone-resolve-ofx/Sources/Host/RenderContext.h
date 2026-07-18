#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>

namespace filmtone::resolve::host {

struct PointD final {
    const double x;
    const double y;
};

struct RectI final {
    const int x1;
    const int y1;
    const int x2;
    const int y2;

    [[nodiscard]] int width() const noexcept { return x2 - x1; }
    [[nodiscard]] int height() const noexcept { return y2 - y1; }
    [[nodiscard]] bool isEmpty() const noexcept { return width() <= 0 || height() <= 0; }
};

struct FrameRates final {
    const double source;
    const double timeline;
};

enum class PixelFormat {
    floatRGBA,
};

struct RenderContext final {
    const double time;
    const FrameRates frameRates;
    const std::optional<std::uint64_t> explicitSeed;
    const PointD renderScale;
    const RectI renderWindow;
    const std::optional<RectI> sourceBounds;
    const std::optional<RectI> outputBounds;
};

struct MetalImageView final {
    void* const buffer;
    const std::ptrdiff_t rowBytes;
    const RectI bounds;
    const PixelFormat format;
};

struct MetalRenderInvocation final {
    void* const commandQueue;
    const MetalImageView source;
    const MetalImageView output;
};

}  // namespace filmtone::resolve::host
