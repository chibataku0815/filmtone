#pragma once

#include <string>

#include "FilmtoneFinishParameters.h"
#include "../Host/MetalPipelineCache.h"
#include "../Host/RenderContext.h"

namespace filmtone::resolve::integration {

// Configuration-only identity is independent of time and frame rate. It is
// true only when every accepted processor can prove identity without a valid
// temporal context (for example, all modules off or all local gains zero).
[[nodiscard]] bool isFilmtoneFinishConfiguredIdentity(
    const EvaluatedFilmtoneFinishParameters& parameters) noexcept;

// Exact identity means that all three accepted processors resolve to identity
// for the supplied host time/context. No module pass is scheduled in that
// state.
[[nodiscard]] bool isFilmtoneFinishIdentity(
    const EvaluatedFilmtoneFinishParameters& parameters,
    const host::RenderContext& context) noexcept;

// Encodes only active modules, always in Film Breath -> Gate Weave -> Film
// Damage order. Multi-pass stages use distinct source/destination buffers. A
// lone Gate Weave also gets a distinct output when the Host buffers alias;
// normal zero/one-pass work allocates no intermediate Metal storage.
bool encodeFilmtoneFinishMetal(
    const EvaluatedFilmtoneFinishParameters& parameters,
    const host::RenderContext& context,
    const host::MetalRenderInvocation& invocation,
    host::MetalPipelineCache& pipelineCache,
    std::string& error);

}  // namespace filmtone::resolve::integration
