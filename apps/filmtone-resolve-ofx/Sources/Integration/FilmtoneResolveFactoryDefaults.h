#pragma once

#include <array>
#include <string_view>

namespace filmtone::resolve::integration {

// Resolve-only factory defaults for the Filmtone parameter surface.
//
// The generated contracts keep identity-oriented defaults (every Amount at
// its identity value) so generic consumers and old projects resolve to a
// neutral state. The Resolve descriptor instead stores a meaningful non-zero
// adjustment on every feature while all Enabled toggles stay false: the
// plugin is exact identity when added and after a full reset, and turning on
// one Quick Enable checkbox immediately produces a visible, restrained
// result.
//
// Both the OFX descriptor defaults and the non-finite runtime fallbacks in
// FilmtoneParameters.cpp resolve through this single table. Enabled,
// Node Role, and Variation intentionally have no entry, so they keep the
// generated identity defaults (false / All / 0). Entries are validated
// against the generated definitions at compile time in
// FilmtoneParameters.cpp: every ID must name an existing real-kind
// persistent parameter and every value must stay inside its accepted range.

struct FilmtoneResolveFactoryDefault final {
    const char* id;
    double value;
};

inline constexpr std::array<FilmtoneResolveFactoryDefault, 16>
    kFilmtoneResolveFactoryDefaults{{
        {"com.forestone.filmtone.finish.deepGlow.amount", 0.40},
        {"com.forestone.filmtone.finish.deepGlow.threshold", 0.75},
        {"com.forestone.filmtone.finish.deepGlow.radius", 0.60},
        {"com.forestone.filmtone.finish.deepGlow.softKnee", 0.50},
        {"com.forestone.filmtone.finish.peripheralChromaticShift.amount",
         0.0015},
        {"com.forestone.filmtone.finish.lensSoftness.amount", 0.30},
        {"com.forestone.filmtone.finish.textureSoftness.amount", 0.50},
        {"com.forestone.filmtone.finish.vignette.amount", 0.40},
        {"com.forestone.filmtone.finish.filmBreath.amount", 0.45},
        {"com.forestone.filmtone.finish.gateWeave.amount", 0.40},
        {"com.forestone.filmtone.finish.filmDamage.amount", 0.40},
        {"com.forestone.filmtone.finish.filmDamage.dust", 0.40},
        {"com.forestone.filmtone.finish.filmDamage.scratches", 0.30},
        {"com.forestone.filmtone.finish.filmDamage.fibers", 0.20},
        {"com.forestone.filmtone.finish.filmDamage.stains", 0.20},
        {"com.forestone.filmtone.finish.filmDamage.gateWear", 0.25},
    }};

// Resolves the Resolve factory default for one persistent parameter ID,
// falling back to the generated contract default when no Resolve-specific
// entry exists.
[[nodiscard]] constexpr double resolveFactoryDefault(
    const char* id,
    double contractDefault) noexcept {
    for (const auto& entry : kFilmtoneResolveFactoryDefaults) {
        if (std::string_view(entry.id) == std::string_view(id)) {
            return entry.value;
        }
    }
    return contractDefault;
}

}  // namespace filmtone::resolve::integration
