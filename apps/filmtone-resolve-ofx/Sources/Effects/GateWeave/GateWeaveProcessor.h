#pragma once

#include "../../Host/ModuleProcessor.h"
#include "GateWeaveTransform.h"

namespace filmtone::resolve::gate_weave {

enum class GateWeaveEdgeSafetyMode {
    // Apply one constant, parameter-derived crop that contains the complete
    // transform envelope and the four-by-four reconstruction footprint.
    automaticCrop,
};

class GateWeaveProcessor final : public host::ModuleProcessor {
public:
    explicit GateWeaveProcessor(
        const forestone::filmtone::FilmtoneFinishMappingV1& mapping,
        GateWeaveEdgeSafetyMode edgeSafetyMode =
            GateWeaveEdgeSafetyMode::automaticCrop) noexcept;

    [[nodiscard]] bool isIdentity(
        const host::RenderContext& context) const noexcept override;

    bool encodeMetal(
        const host::RenderContext& context,
        const host::MetalRenderInvocation& invocation,
        host::MetalPipelineCache& pipelineCache,
        std::string& error) const override;

    [[nodiscard]] const forestone::visual_effect::FilmDamageRecipeV2& recipe()
        const noexcept {
        return recipe_;
    }

    [[nodiscard]] GateWeaveEdgeSafetyMode edgeSafetyMode() const noexcept {
        return edgeSafetyMode_;
    }

private:
    forestone::visual_effect::FilmDamageRecipeV2 recipe_;
    GateWeaveEdgeSafetyMode edgeSafetyMode_;
};

}  // namespace filmtone::resolve::gate_weave
