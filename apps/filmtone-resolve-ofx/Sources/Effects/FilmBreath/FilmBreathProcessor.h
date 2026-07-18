#pragma once

#include <string>

#include "FilmBreathParameters.h"
#include "../../Host/ModuleProcessor.h"

namespace filmtone::resolve::effects::film_breath {

class FilmBreathProcessor final : public host::ModuleProcessor {
public:
    explicit FilmBreathProcessor(FilmBreathParameters parameters) noexcept;

    [[nodiscard]] const FilmBreathParameters& parameters() const noexcept;

    [[nodiscard]] bool isIdentity(
        const host::RenderContext& context) const noexcept override;

    bool encodeMetal(
        const host::RenderContext& context,
        const host::MetalRenderInvocation& invocation,
        host::MetalPipelineCache& pipelineCache,
        std::string& error) const override;

private:
    FilmBreathParameters parameters_;
};

}  // namespace filmtone::resolve::effects::film_breath
