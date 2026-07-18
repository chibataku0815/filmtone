#pragma once

#include "../../Generated/Contracts/filmtone_resolve_spatial.hpp"
#include "../../Host/Spatial/SpatialModuleProcessor.h"

namespace filmtone::resolve::texture_softness {

class TextureSoftnessProcessor final
    : public host::spatial::SpatialModuleProcessor {
public:
    explicit TextureSoftnessProcessor(
        spatial::TextureSoftnessParameterViewV1 parameters) noexcept;

    [[nodiscard]] const char* name() const noexcept override;

    [[nodiscard]] bool isIdentity(
        const host::RenderContext& context) const noexcept override;

    bool makeResourcePlan(
        const host::RenderContext& context,
        const host::spatial::SpatialFrameDescriptor& frame,
        host::spatial::SpatialResourcePlan& plan,
        std::string& error) const override;

    bool encodeSpatialMetal(
        const host::RenderContext& context,
        const host::spatial::SpatialEncodeInvocation& invocation,
        std::string& error) const override;

    [[nodiscard]] const spatial::TextureSoftnessParameterViewV1& parameters()
        const noexcept {
        return parameters_;
    }

private:
    spatial::TextureSoftnessParameterViewV1 parameters_;
};

}  // namespace filmtone::resolve::texture_softness
