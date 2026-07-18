#pragma once

#include <string>

#include "RenderContext.h"

namespace filmtone::resolve::host {

bool encodeMetalIdentityBlit(
    const RenderContext& context,
    const MetalRenderInvocation& invocation,
    std::string& error);

}  // namespace filmtone::resolve::host
