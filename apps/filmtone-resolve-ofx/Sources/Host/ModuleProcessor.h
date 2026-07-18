#pragma once

#include <string>

#include "RenderContext.h"

namespace filmtone::resolve::host {

class MetalPipelineCache;

class ModuleProcessor {
public:
    virtual ~ModuleProcessor() = default;

    [[nodiscard]] virtual bool isIdentity(const RenderContext& context) const noexcept = 0;

    virtual bool encodeMetal(
        const RenderContext& context,
        const MetalRenderInvocation& invocation,
        MetalPipelineCache& pipelineCache,
        std::string& error) const = 0;
};

}  // namespace filmtone::resolve::host
