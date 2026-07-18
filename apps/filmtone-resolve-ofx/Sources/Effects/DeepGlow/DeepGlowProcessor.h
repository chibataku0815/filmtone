#pragma once

#include <cstdint>

#include "../../Generated/Contracts/filmtone_resolve_spatial.hpp"
#include "../../Host/Spatial/SpatialModuleProcessor.h"

namespace filmtone::resolve::effects::deep_glow {

// This is Host image metadata, not a user-facing or artistic parameter.
// Integration must pass the source clip's OFX alpha association explicitly so
// Deep Glow can preserve the same association while leaving alpha untouched.
enum class DeepGlowAlphaAssociationV1 : std::uint32_t {
    unassociatedOrOpaque = 0u,
    premultiplied = 1u,
};

class DeepGlowProcessor final :
    public host::spatial::SpatialModuleProcessor {
public:
    // The generated view is the only artistic input. Callers obtain it with
    // makeDeepGlowParameterViewV1; this feature does not own duplicate
    // defaults, ranges, profiles, or hidden tuning controls.
    DeepGlowProcessor(
        spatial::DeepGlowParameterViewV1 parameters,
        DeepGlowAlphaAssociationV1 alphaAssociation) noexcept;

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

    [[nodiscard]] const spatial::DeepGlowParameterViewV1& parameters()
        const noexcept {
        return parameters_;
    }

    [[nodiscard]] DeepGlowAlphaAssociationV1 alphaAssociation()
        const noexcept {
        return alphaAssociation_;
    }

private:
    spatial::DeepGlowParameterViewV1 parameters_;
    DeepGlowAlphaAssociationV1 alphaAssociation_;
};

}  // namespace filmtone::resolve::effects::deep_glow
