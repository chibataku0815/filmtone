#pragma once

#include <cstdint>

#include "../../Generated/Contracts/filmtone_finish_contracts.hpp"
#include "../../Host/ModuleProcessor.h"

namespace filmtone::resolve::damage {

// Local-only inspection modes for the later quality workstream. Production
// integration should leave this at composite.
enum class FilmDamageDebugView : std::uint32_t {
    composite = 0u,
    dust = 1u,
    fibers = 2u,
    scratches = 3u,
    stains = 4u,
    gateWear = 5u,
    combined = 6u,
};

// Consumes only Dust, Fibers, Scratches, Stains, and Gate Wear from the frozen
// recipe. Flicker, Gate Weave, and Defocus remain outside this module.
class FilmDamageProcessor final : public host::ModuleProcessor {
public:
    explicit FilmDamageProcessor(
        forestone::visual_render::FilmDamageRenderUniformsV1 uniforms,
        FilmDamageDebugView debugView = FilmDamageDebugView::composite) noexcept;

    FilmDamageProcessor(
        const forestone::filmtone::FilmtoneFinishMappingV1& mapping,
        const contracts::ResolveRenderContextV1& renderContext,
        FilmDamageDebugView debugView = FilmDamageDebugView::composite) noexcept;

    [[nodiscard]] bool isIdentity(
        const host::RenderContext& context) const noexcept override;

    bool encodeMetal(
        const host::RenderContext& context,
        const host::MetalRenderInvocation& invocation,
        host::MetalPipelineCache& pipelineCache,
        std::string& error) const override;

    [[nodiscard]] const forestone::visual_render::FilmDamageRenderUniformsV1&
    uniforms() const noexcept {
        return uniforms_;
    }

    [[nodiscard]] FilmDamageDebugView debugView() const noexcept {
        return debugView_;
    }

private:
    forestone::visual_render::FilmDamageRenderUniformsV1 uniforms_;
    FilmDamageDebugView debugView_;
};

}  // namespace filmtone::resolve::damage
