#pragma once

#include <string>

#include "../../Generated/Contracts/filmtone_resolve_spatial.hpp"
#include "../../Host/Spatial/SpatialModuleProcessor.h"

namespace filmtone::resolve::effects::peripheral_chromatic_shift {

class PeripheralChromaticShiftProcessor final
    : public host::spatial::SpatialModuleProcessor {
public:
    explicit PeripheralChromaticShiftProcessor(
        const spatial::FilmtoneSpatialParametersV1& parameters) noexcept;

    [[nodiscard]] const spatial::PeripheralChromaticShiftParameterViewV1&
    parameterView() const noexcept;

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

private:
    spatial::PeripheralChromaticShiftParameterViewV1 parameterView_;
};

}  // namespace filmtone::resolve::effects::peripheral_chromatic_shift
