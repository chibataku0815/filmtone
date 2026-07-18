#pragma once

#include <cstdint>
#include <string>

#include "FilmtoneFinishParameters.h"
#include "../Host/MetalPipelineCache.h"
#include "../Host/RenderContext.h"

namespace filmtone::resolve::integration {

enum class SourceAlphaAssociation : std::uint32_t {
    unassociatedOrOpaque = 0u,
    premultiplied = 1u,
};

// Temporal frame rate is needed only when the selected Node Role schedules a
// configured-active Film Breath, Gate Weave, or Film Damage module. Static
// Optics-only work never invents or requires a material clock.
[[nodiscard]] bool requiresFilmtoneFinishTemporalFrameRate(
    const EvaluatedFilmtoneFinishParameters& parameters) noexcept;

// Configuration-only identity is independent of time and frame rate. It is
// true only when every module scheduled by Node Role is neutral without a
// valid temporal context. Role masking never changes the stored values.
[[nodiscard]] bool isFilmtoneFinishConfiguredIdentity(
    const EvaluatedFilmtoneFinishParameters& parameters) noexcept;

// Exact identity means every role-scheduled spatial and accepted film module
// resolves to identity for the supplied host time/context.
[[nodiscard]] bool isFilmtoneFinishIdentity(
    const EvaluatedFilmtoneFinishParameters& parameters,
    const host::RenderContext& context) noexcept;

// Encodes only role-scheduled active modules in exact order:
// Texture Softness -> Peripheral Chromatic Shift -> Lens Softness -> Deep
// Glow -> Vignette -> Film Breath -> Gate Weave -> Film Damage. Spatial work
// uses one coordinator-owned command buffer; accepted film processors commit
// afterward on the same Host queue. At most two full-frame temporal buffers
// are reused, independent of the active module count.
bool encodeFilmtoneFinishMetal(
    const EvaluatedFilmtoneFinishParameters& parameters,
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    double pixelAspectRatio,
    SourceAlphaAssociation alphaAssociation,
    host::MetalPipelineCache& pipelineCache,
    std::string& error);

}  // namespace filmtone::resolve::integration
