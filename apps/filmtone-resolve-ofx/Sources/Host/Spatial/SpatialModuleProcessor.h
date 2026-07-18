#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

#include "../MetalPipelineCache.h"
#include "../RenderContext.h"

namespace filmtone::resolve::host::spatial {

inline constexpr std::uint32_t kSpatialModuleAbiVersion = 1u;
inline constexpr std::size_t kSpatialMaxInlineBytesPerBinding = 4096u;
inline constexpr std::uint32_t kSpatialMaxPassesPerModule = 64u;

// Spatial v1 is deliberately texture-only inside the graph. Host float RGBA
// buffers are converted at the graph boundary; feature modules never receive
// a command queue, command buffer, or raw Metal resource.
enum class SpatialImagePlane : std::uint8_t {
    ping = 0u,
    pong = 1u,
};

enum class SpatialTextureAccess : std::uint8_t {
    readOnly = 0u,
    writeOnly = 1u,
};

enum class SpatialEdgeMode : std::uint8_t {
    // Spatial v1 requires explicit coordinate clamping in feature kernels.
    // Kernels use integer reads and manual interpolation; no filterability
    // assumption or raw sampler is exposed for RGBA32Float. Transparent/zero,
    // repeat, and mirror sampling are not accepted.
    clampToEdge = 0u,
};

struct SpatialFrameDescriptor final {
    int boundsX1 = 0;
    int boundsY1 = 0;
    std::uint32_t width = 0u;
    std::uint32_t height = 0u;

    // Render-window coordinates are local to boundsX1/boundsY1. Spatial
    // modules still populate the complete full-resolution destination so
    // downstream full-frame sampling never observes an undefined tile.
    std::uint32_t renderWindowX = 0u;
    std::uint32_t renderWindowY = 0u;
    std::uint32_t renderWindowWidth = 0u;
    std::uint32_t renderWindowHeight = 0u;

    double renderScaleX = 1.0;
    double renderScaleY = 1.0;
    double pixelAspectRatio = 1.0;
    double logicalDisplayWidth = 0.0;
    double logicalDisplayHeight = 0.0;
    double logicalDisplayAspect = 1.0;

    // Texture row zero corresponds to boundsY1; positive canonical Y follows
    // increasing Host Y. Canonical feature coordinates are centered,
    // display-aspect-correct,
    // and normalized so the nearer pair of frame edges is approximately
    // -1/+1. For a local pixel center (x + 0.5, y + 0.5):
    //   cx = (x + 0.5 - width / 2)  * canonicalUnitsPerPixelX
    //   cy = (y + 0.5 - height / 2) * canonicalUnitsPerPixelY
    double canonicalUnitsPerPixelX = 0.0;
    double canonicalUnitsPerPixelY = 0.0;
};

struct SpatialResourcePlan final {
    std::uint32_t abiVersion = kSpatialModuleAbiVersion;
    std::uint32_t passCount = 0u;

    // Total levels including full resolution at level zero. Every level uses
    // RGBA32Float. The host takes the maximum requested by active modules and
    // reuses the same two pyramids for every module in sequence.
    std::uint32_t mipLevelCount = 1u;
    SpatialEdgeMode edgeMode = SpatialEdgeMode::clampToEdge;

    bool requiresFullFrame = true;
    bool preservesExtendedRange = true;
    bool preservesAlpha = true;
};

// This is an execution-scoped capability, not a raw Metal handle. Tokens are
// validated by the host and become invalid when the encode call returns.
struct SpatialImageView final {
    std::uint64_t executionToken = 0u;
    SpatialImagePlane plane = SpatialImagePlane::ping;
    std::uint32_t mipLevel = 0u;
    std::uint32_t width = 0u;
    std::uint32_t height = 0u;
};

struct SpatialTextureBinding final {
    std::uint32_t shaderIndex = 0u;
    SpatialImageView image{};
    SpatialTextureAccess access = SpatialTextureAccess::readOnly;
};

struct SpatialBytesBinding final {
    std::uint32_t shaderIndex = 0u;
    const void* bytes = nullptr;
    std::size_t length = 0u;
};

struct SpatialThreadGrid final {
    std::uint32_t width = 0u;
    std::uint32_t height = 0u;
    std::uint32_t depth = 1u;
};

struct SpatialComputePass final {
    const char* label = nullptr;
    const MetalPipelineRequest* pipeline = nullptr;
    const SpatialTextureBinding* textureBindings = nullptr;
    std::size_t textureBindingCount = 0u;
    const SpatialBytesBinding* bytesBindings = nullptr;
    std::size_t bytesBindingCount = 0u;
    SpatialThreadGrid grid{};
};

class SpatialMetalExecutionDriver;

class SpatialMetalCommandContext final {
public:
    SpatialMetalCommandContext(const SpatialMetalCommandContext&) = delete;
    SpatialMetalCommandContext& operator=(const SpatialMetalCommandContext&) = delete;

    // Encodes immediately into the coordinator-owned command buffer. It does
    // not commit, wait, read back, or expose the underlying Metal objects.
    bool encodeComputePass(
        const SpatialComputePass& pass,
        std::string& error);

    [[nodiscard]] std::size_t encodedPassCount() const noexcept;

private:
    friend class SpatialMetalExecutionDriver;

    explicit SpatialMetalCommandContext(void* state) noexcept;

    void* state_ = nullptr;
};

class SpatialResourceScope final {
public:
    SpatialResourceScope(const SpatialResourceScope&) = delete;
    SpatialResourceScope& operator=(const SpatialResourceScope&) = delete;

    // Returns a view only when the requested level was declared during
    // resource planning. Level zero is the graph ping-pong surface; higher
    // levels are module-scoped scratch and are reusable by the next module.
    bool image(
        SpatialImagePlane plane,
        std::uint32_t mipLevel,
        SpatialImageView& view,
        std::string& error) const noexcept;

private:
    friend class SpatialMetalExecutionDriver;

    explicit SpatialResourceScope(void* state) noexcept;

    void* state_ = nullptr;
};

struct SpatialEncodeInvocation final {
    const SpatialFrameDescriptor& frame;
    const SpatialImageView source;
    const SpatialImageView output;
    SpatialResourceScope& resources;
    SpatialMetalCommandContext& commands;
};

class SpatialModuleProcessor {
public:
    virtual ~SpatialModuleProcessor() = default;

    [[nodiscard]] virtual const char* name() const noexcept = 0;
    [[nodiscard]] virtual bool isIdentity(
        const RenderContext& context) const noexcept = 0;

    virtual bool makeResourcePlan(
        const RenderContext& context,
        const SpatialFrameDescriptor& frame,
        SpatialResourcePlan& plan,
        std::string& error) const = 0;

    virtual bool encodeSpatialMetal(
        const RenderContext& context,
        const SpatialEncodeInvocation& invocation,
        std::string& error) const = 0;
};

}  // namespace filmtone::resolve::host::spatial
