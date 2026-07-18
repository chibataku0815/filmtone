#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

#include "SpatialModuleProcessor.h"

namespace filmtone::resolve::host::spatial {

inline constexpr std::uint32_t kSpatialUhdWidth = 3840u;
inline constexpr std::uint32_t kSpatialUhdHeight = 2160u;

// Two complete 3840x2160 RGBA32F pyramids consume 353,889,760 tight bytes
// (337.50 MiB). The enforced 384 MiB ceiling leaves 46.50 MiB for Metal's
// resource alignment/metadata. Host source/output buffers and pipeline state
// cache objects are externally owned and are not included in this transient
// spatial budget.
inline constexpr std::size_t kSpatialUhdFullPyramidPairTightBytes =
    353889760u;
inline constexpr std::size_t kSpatialTransientMemoryCeilingBytes =
    384u * 1024u * 1024u;

// The accepted three-module graph can require at most two additional UHD
// RGBA32F transition buffers. Integration reserves that queue-overlapping
// lifetime before spatial commit. 384 MiB + 253.125 MiB fits under the fixed
// 640 MiB integrated transient ceiling, independent of the number of active
// spatial modules.
inline constexpr std::size_t kAcceptedTemporalUhdTransitionTightBytes =
    265420800u;
inline constexpr std::size_t kIntegratedUhdTransientMemoryCeilingBytes =
    640u * 1024u * 1024u;

enum class SpatialExecutionOutcome : std::uint8_t {
    noWork = 0u,
    encoded = 1u,
};

struct SpatialExecutionReport final {
    SpatialExecutionOutcome outcome = SpatialExecutionOutcome::noWork;
    std::size_t activeModuleCount = 0u;
    std::size_t encodedFeaturePassCount = 0u;
    std::uint32_t allocatedMipLevelCount = 0u;
    std::size_t tightTextureBytes = 0u;
    std::size_t allocatedTextureBytes = 0u;
    std::size_t reservedFollowingQueueBytes = 0u;
    std::size_t combinedAccountedBytes = 0u;
};

// Returns true with noWork and performs no allocation or copy when the render
// window is empty or every supplied module is identity. For active spatial
// work, all conversion and feature passes are encoded into one command buffer
// and committed once, in array order, on invocation.commandQueue.
//
// pixelAspectRatio is additive input to the spatial ABI because the accepted
// RenderContext does not carry clip PAR. It must be finite and positive. The
// later integration owner obtains it from the OFX clip and passes it here.
// reservedFollowingQueueBytes accounts for later command buffers whose
// resources can overlap this command buffer's lifetime on the same queue.
// SPATIAL-INTEGRATION supplies its bounded temporal-transition requirement;
// feature modules do not allocate or reserve graph resources themselves.
// A false result before commit leaves the Host output untouched by this
// spatial graph. A true encoded result means the single command buffer was
// committed; GPU execution remains asynchronous and this ABI intentionally
// performs no wait, readback, or synchronous post-commit error polling.
bool encodeSpatialMetalSequence(
    const RenderContext& context,
    const MetalRenderInvocation& invocation,
    double pixelAspectRatio,
    std::size_t reservedFollowingQueueBytes,
    const SpatialModuleProcessor* const* modules,
    std::size_t moduleCount,
    MetalPipelineCache& pipelineCache,
    SpatialExecutionReport& report,
    std::string& error);

}  // namespace filmtone::resolve::host::spatial
