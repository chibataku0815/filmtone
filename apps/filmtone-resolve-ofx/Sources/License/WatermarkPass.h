#pragma once

#include <string>

#include "../Host/MetalPipelineCache.h"
#include "../Host/RenderContext.h"

// Deterministic trial watermark composited in place on the final output when the
// license state is not a valid full/active-trial license. It reads and writes the
// same output buffer per pixel (no cross-pixel dependency), preserves alpha, does
// not clamp extended-range RGB, and positions the pattern in global output-bounds
// canonical coordinates so proxy and full-resolution renders match.
//
// The visual (wording, size, opacity, placement) is an intentional default for
// owner review; monetization/implementation-plan.md §3 defers the final look to
// owner visual judgment (2-3 candidates).

namespace filmtone::resolve::watermark {

bool encodeMetalTrialWatermark(
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    host::MetalPipelineCache& pipelineCache,
    std::string& error);

}  // namespace filmtone::resolve::watermark
