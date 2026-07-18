#pragma once

namespace filmtone::resolve::damage::detail {

inline constexpr char kFilmDamageMetalFunctionName[] = "filmtoneResolveFilmDamage";
inline constexpr char kFilmDamageMetalCacheKey[] = "filmtone.resolve.damage.metal.v2";

inline constexpr char kFilmDamageMetalLibrarySource[] = R"FILMTONE_METAL(
#include <metal_stdlib>

using namespace metal;

constant float kTau = 6.28318530717958647692f;

struct FilmDamageUniforms {
    uint4 io;
    int4 origins;
    int4 outputAndDebug;

    float4 context;
    float4 bounds;
    uint4 temporal;

    float4 global0;
    float4 global1;

    float4 dust0;
    float4 dust1;
    float4 dust2;

    float4 scratch0;
    float4 scratch1;
    float4 scratch2;
    float4 scratch3;
    float4 scratch4;
    float4 scratch5;

    float4 fiber0;
    float4 fiber1;
    float4 fiber2;
    float4 fiber3;

    float4 stain0;
    float4 stain1;
    float4 stain2;

    float4 gate0;
    float4 gate1;

    uint4 polarities;
    uint4 modes;
};

struct TemporalEvent {
    float fade;
    int cycle;
    int age;
    int lifetime;
};

float unitClamp(float value) {
    return clamp(value, 0.0f, 1.0f);
}

float smoothUnit(float value) {
    const float t = unitClamp(value);
    return t * t * (3.0f - 2.0f * t);
}

uint avalanche32(uint value) {
    value ^= value >> 16u;
    value *= 0x7feb352du;
    value ^= value >> 15u;
    value *= 0x846ca68bu;
    value ^= value >> 16u;
    return value;
}

uint familyStream(uint streamSeed, uint familySalt) {
    return avalanche32(streamSeed ^ (familySalt * 0x9e3779b1u));
}

uint eventHash(int a, int b, int c, uint seed) {
    uint value = seed;
    value ^= uint(a) * 0x8da6b343u;
    value ^= uint(b) * 0xd8163841u;
    value ^= uint(c) * 0xcb1ab31fu;
    return avalanche32(value);
}

float randomUnit(int a, int b, int c, uint seed) {
    return float(eventHash(a, b, c, seed) >> 8u) * (1.0f / 16777216.0f);
}

float rangeValue(float2 range, float t) {
    const float low = min(range.x, range.y);
    const float high = max(range.x, range.y);
    return mix(low, high, unitClamp(t));
}

int floorDivide(int value, int divisor) {
    int quotient = value / divisor;
    const int remainder = value % divisor;
    if (remainder < 0) {
        quotient -= 1;
    }
    return quotient;
}

float valueNoise1D(float coordinate, int eventId, int cycle, uint seed) {
    const int cell = int(floor(coordinate));
    const float t = smoothUnit(coordinate - floor(coordinate));
    const float first = randomUnit(cell, eventId, cycle, seed);
    const float second = randomUnit(cell + 1, eventId, cycle, seed);
    return mix(first, second, t);
}

uint eventStream(uint stream, int a, int b, int c) {
    uint value = stream;
    value ^= uint(a) * 0x27d4eb2fu;
    value ^= uint(b) * 0x9e3779b1u;
    value ^= uint(c) * 0x85ebca6bu;
    return avalanche32(value);
}

float valueNoise2D(float2 coordinate, uint seed) {
    const int2 cell = int2(floor(coordinate));
    const float2 t = coordinate - floor(coordinate);
    const float tx = smoothUnit(t.x);
    const float ty = smoothUnit(t.y);
    const float v00 = randomUnit(cell.x, cell.y, 0, seed);
    const float v10 = randomUnit(cell.x + 1, cell.y, 0, seed);
    const float v01 = randomUnit(cell.x, cell.y + 1, 0, seed);
    const float v11 = randomUnit(cell.x + 1, cell.y + 1, 0, seed);
    return mix(mix(v00, v10, tx), mix(v01, v11, tx), ty);
}

// Wrapped value noise over a full turn so silhouette raggedness has no seam
// and no low-order harmonic signature.
float angularRaggedNoise(float angle, int cells, uint seed) {
    const float coordinate = fract(angle * (1.0f / kTau)) * float(cells);
    int cell0 = int(floor(coordinate)) % cells;
    if (cell0 < 0) {
        cell0 += cells;
    }
    const int cell1 = (cell0 + 1) % cells;
    const float t = smoothUnit(coordinate - floor(coordinate));
    return mix(
        randomUnit(cell0, 11, 0, seed),
        randomUnit(cell1, 11, 0, seed),
        t);
}

// Fast soft attack into a held material presence, easing only near the fade
// boundaries; avoids long translucent ghosting while keeping contract fades.
float heldVisibility(float fade, float holdFloor) {
    if (fade <= 0.0f) {
        return 0.0f;
    }
    const float eased = smoothstep(0.01f, 0.30f, fade);
    return eased * mix(holdFloor, 1.0f, pow(unitClamp(fade), 0.25f));
}

// 0 in the held middle of an event, rising toward 1 while the artifact
// materializes or dissolves.
float transitionPhase(TemporalEvent event, float2 fadeFrames) {
    const float attackFrames = max(1.0f, fadeFrames.x * 1.25f);
    const float attack = 1.0f - smoothstep(0.0f, attackFrames, float(event.age));
    const float releaseFrames = max(1.0f, fadeFrames.y * 1.2f);
    const float releaseStart = max(
        fadeFrames.x,
        float(event.lifetime) - releaseFrames);
    const float release = smoothstep(
        releaseStart,
        float(event.lifetime),
        float(event.age));
    return pow(unitClamp(max(attack, release)), 0.6f);
}

// Roll-position dirt clustering: defect density is uneven along a physical
// roll, so event birth probability breathes slowly and occasionally bursts.
// Sampled at the event birth frame so an event never vanishes mid-life.
float clusterGain(
    constant FilmDamageUniforms& uniforms,
    uint familySalt,
    int birthFrame,
    float amplitude) {
    if (amplitude <= 0.0f) {
        return 1.0f;
    }
    const uint stream = familyStream(
        uniforms.temporal.y,
        familySalt ^ 0x524f4c4cu);
    const float period = max(4.0f, uniforms.global1.y * 3.2f);
    const float coordinate = float(birthFrame) / period;
    const float slow = valueNoise1D(coordinate, 3, 1, stream);
    const float fast = valueNoise1D(coordinate * 3.7f, 5, 2, stream);
    const float field = slow * 0.72f + fast * 0.28f;
    const float burst = smoothstep(0.80f, 0.97f, field);
    return max(
        0.0f,
        1.0f + amplitude * (field - 0.5f) * 1.6f + burst * amplitude * 1.3f);
}

float4 profileParameters(uint profile) {
    if (profile == 2u) {
        return float4(1.58f, 1.40f, 1.30f, 1.48f);
    }
    if (profile == 1u) {
        return float4(1.24f, 1.20f, 1.15f, 1.23f);
    }
    return float4(1.0f);
}

float globalGain(constant FilmDamageUniforms& uniforms) {
    return unitClamp(uniforms.global0.x) * unitClamp(uniforms.global0.y);
}

float materialScale(constant FilmDamageUniforms& uniforms) {
    const float profileScale = profileParameters(uniforms.temporal.z).x;
    return (0.58f + unitClamp(uniforms.global0.w) * 1.22f) * profileScale;
}

float effectiveDensity(
    constant FilmDamageUniforms& uniforms,
    float density) {
    return unitClamp(density * profileParameters(uniforms.temporal.z).y);
}

TemporalEvent resolveTemporalEvent(
    constant FilmDamageUniforms& uniforms,
    int eventA,
    int eventB,
    uint stream,
    float2 lifetimeRange,
    float2 fadeFrames,
    float variation) {
    const float temporalRate = profileParameters(uniforms.temporal.z).z;
    const int frameIndex = as_type<int>(uniforms.temporal.x);
    const int lifetime = max(
        1,
        int(floor(rangeValue(
            lifetimeRange,
            randomUnit(eventA, eventB, 0, stream)) + 0.5f)));
    const float cadenceSpread = mix(
        0.68f,
        2.16f,
        randomUnit(eventA, eventB, 1, stream));
    const float basePeriod = max(1.0f, uniforms.global1.y) / max(0.01f, temporalRate);
    const int period = max(
        lifetime + 1,
        int(floor(
            basePeriod * cadenceSpread +
            float(lifetime) * (1.0f + unitClamp(variation)) +
            0.5f)));
    const int offset = int(floor(
        randomUnit(eventA, eventB, 2, stream) *
        float(period) *
        unitClamp(variation)));
    const int localFrame = frameIndex + offset;
    const int cycle = floorDivide(localFrame, period);
    const int age = localFrame - cycle * period;
    if (age < 0 || age >= lifetime) {
        return TemporalEvent{0.0f, cycle, age, lifetime};
    }

    const float fadeInFrames = min(float(lifetime), max(0.0f, fadeFrames.x));
    const float fadeOutFrames = min(float(lifetime), max(0.0f, fadeFrames.y));
    const float fadeIn = fadeInFrames <= 0.0f
        ? 1.0f
        : smoothstep(0.0f, max(1.0f, fadeInFrames), float(age) + 1.0f);
    const float fadeOutLength = fadeOutFrames * mix(
        0.80f,
        1.20f,
        randomUnit(eventA, cycle, 3, stream));
    const float fadeOutStart = max(
        fadeInFrames,
        float(lifetime) - fadeOutLength);
    const float fadeOutEdge = min(
        fadeOutStart,
        float(lifetime) - 0.0001f);
    const float fadeOut = fadeOutFrames <= 0.0f
        ? 1.0f
        : 1.0f - smoothstep(fadeOutEdge, float(lifetime), float(age));
    return TemporalEvent{fadeIn * fadeOut, cycle, age, lifetime};
}

float edgeProximity(float2 point, float2 size) {
    const float distance = min(
        min(point.x, point.y),
        min(size.x - point.x, size.y - point.y));
    return 1.0f - unitClamp(distance / max(1.0f, min(size.x, size.y) * 0.46f));
}

float gateProximity(float coordinate, float size) {
    const float distance = min(coordinate, size - coordinate);
    return 1.0f - unitClamp(distance / max(1.0f, size * 0.31f));
}

float polaritySign(uint polarity, int a, int b, uint stream) {
    if (polarity == 0u) {
        return 1.0f;
    }
    if (polarity == 1u) {
        return -1.0f;
    }
    // Filmtone's mixed material remains overwhelmingly dark; light events are
    // a deliberately rare sparkle/scratch accent.
    return randomUnit(a, b, 97, stream) > 0.925f ? 1.0f : -1.0f;
}

float dustFamilyMask(
    constant FilmDamageUniforms& uniforms,
    float2 point,
    float2 size,
    float antialiasWidth) {
    const float density = effectiveDensity(uniforms, uniforms.dust0.x);
    if (density <= 0.0f) {
        return 0.0f;
    }

    const uint stream = familyStream(uniforms.temporal.y, 0x44555354u);
    const float shortAxis = max(1.0f, min(size.x, size.y));
    const float scale = materialScale(uniforms);
    // Event geometry stays in canonical space so proxy and full-resolution
    // renders resolve identical events; antialiasWidth may only widen edge
    // transitions and sub-pixel visibility floors.
    const float maxRadius =
        (0.55f + max(uniforms.dust1.x, uniforms.dust1.y) * shortAxis * 0.010f) *
        scale;
    const float cellSize = max(6.0f, maxRadius * 3.65f);
    const int2 baseCell = int2(floor(point / cellSize));
    float signedMask = 0.0f;

    for (int offsetY = -1; offsetY <= 1; ++offsetY) {
        for (int offsetX = -1; offsetX <= 1; ++offsetX) {
            const int2 cell = baseCell + int2(offsetX, offsetY);
            const TemporalEvent event = resolveTemporalEvent(
                uniforms,
                cell.x,
                cell.y,
                stream,
                uniforms.dust2.xy,
                uniforms.dust2.zw,
                uniforms.dust0.z);
            if (event.fade <= 0.0f) {
                continue;
            }

            const int birthFrame = as_type<int>(uniforms.temporal.x) - event.age;
            const float cluster = clusterGain(
                uniforms,
                0x44555354u,
                birthFrame,
                0.26f + unitClamp(uniforms.dust0.z) * 0.30f);
            const float2 stableCenter = (
                float2(cell) +
                float2(
                    randomUnit(cell.x, cell.y, event.cycle * 5 + 1, stream),
                    randomUnit(cell.x, cell.y, event.cycle * 5 + 2, stream))) *
                cellSize;
            const float edge = edgeProximity(stableCenter, size);
            const float edgeWeight = 1.0f +
                uniforms.dust0.w * unitClamp(uniforms.global1.x) * edge * 1.85f;
            const float presence = unitClamp(
                density * 0.52f * edgeWeight * cluster);
            if (randomUnit(cell.x, cell.y, event.cycle * 5 + 3, stream) >= presence) {
                continue;
            }

            const uint estream = eventStream(stream, cell.x, cell.y, event.cycle);
            const float ageProgress = event.lifetime <= 1
                ? 0.0f
                : float(event.age) / float(event.lifetime - 1);
            const float transition = transitionPhase(event, uniforms.dust2.zw);
            const float angle = randomUnit(cell.x, cell.y, event.cycle * 5 + 4, stream) * kTau;
            const float driftAmount = maxRadius * uniforms.dust0.z * 0.12f;
            const float transitionAngle = randomUnit(3, 7, 5, estream) * kTau;
            // Skewed size statistics: mostly small motes, with a rare chunk
            // drawn from the top of the contract size range.
            float sizeT = pow(
                randomUnit(cell.x, cell.y, event.cycle * 5 + 5, stream),
                2.35f);
            const bool chunk = randomUnit(3, 9, 1, estream) > 0.955f;
            if (chunk) {
                sizeT = mix(0.86f, 1.0f, randomUnit(5, 11, 2, estream));
            }
            const float sizeValue = rangeValue(uniforms.dust1.xy, sizeT);
            float radius = (0.5f + sizeValue * shortAxis * 0.0085f) * scale;
            radius *= 1.0f + transition * 0.16f;
            const float2 drift =
                float2(cos(angle), sin(angle)) * (ageProgress - 0.5f) * driftAmount +
                float2(cos(transitionAngle), sin(transitionAngle)) *
                    transition * radius * 0.38f;
            const float2 center = stableCenter + drift;
            const float rotation = randomUnit(cell.x, cell.y, event.cycle * 5 + 6, stream) * kTau;
            const float anisotropy = mix(
                0.62f,
                1.22f,
                randomUnit(cell.x, cell.y, event.cycle * 5 + 7, stream));
            const float2 delta = point - center;
            const float2 rotated = float2(
                cos(rotation) * delta.x + sin(rotation) * delta.y,
                -sin(rotation) * delta.x + cos(rotation) * delta.y);
            const float2 shaped = float2(rotated.x, rotated.y / max(0.12f, anisotropy));
            const float effectiveRadius = max(radius, antialiasWidth * 0.75f);
            const float normalizedDistance = length(shaped) / effectiveRadius;
            const float contourAngle = atan2(shaped.y, shaped.x);
            const float raggedness = chunk ? 0.50f : 0.34f;
            const float contour = 1.0f +
                (angularRaggedNoise(contourAngle, 5, estream) - 0.5f) * raggedness +
                (angularRaggedNoise(contourAngle, 11, estream ^ 0x9e3779b9u) - 0.5f) *
                    raggedness * 0.55f;
            const float softness = unitClamp(uniforms.dust0.y);
            const float edgeStart = mix(0.48f, 0.78f, softness) - transition * 0.18f;
            const float shape = 1.0f - smoothstep(
                max(0.05f, edgeStart),
                1.0f + antialiasWidth / effectiveRadius,
                normalizedDistance / max(0.2f, contour));

            const float chipAngle = randomUnit(7, 13, 3, estream) * kTau;
            const float chipReach = radius * mix(0.55f, 1.05f, randomUnit(9, 17, 4, estream));
            const float2 chipCenter = float2(cos(chipAngle), sin(chipAngle)) * chipReach;
            const float chipRadius = max(
                antialiasWidth * 0.60f,
                radius * mix(0.32f, 0.62f, randomUnit(11, 19, 5, estream)));
            const float chipDistance = length(shaped - chipCenter) / chipRadius;
            const float chipShape =
                (1.0f - smoothstep(
                    0.55f,
                    1.0f + antialiasWidth / chipRadius,
                    chipDistance)) *
                mix(0.45f, 0.90f, randomUnit(13, 23, 6, estream));
            const float silhouette = max(shape, chipShape);
            if (silhouette <= 0.0f) {
                continue;
            }

            const float mottleScale = max(1.5f, radius * 0.55f);
            const float mottle = mix(
                0.58f,
                1.0f,
                valueNoise2D(shaped / mottleScale, estream ^ 0x6d2b79f5u));
            const float opacity = rangeValue(
                uniforms.dust1.zw,
                randomUnit(cell.x, cell.y, event.cycle * 5 + 8, stream));
            const float visibility = heldVisibility(event.fade, 0.60f);
            const float sign = polaritySign(
                uniforms.polarities.x,
                cell.x,
                cell.y,
                stream);
            signedMask = clamp(
                signedMask +
                    silhouette * mottle * opacity * visibility *
                    globalGain(uniforms) * sign,
                -1.0f,
                1.0f);
        }
    }
    return signedMask;
}

// Drying/chemical marks deposit minerals where the droplet boundary dried:
// an irregular rim carries most of the density, the interior is a faint
// mottled veil, and the outer edge stays comparatively defined.
float stainFamilyMask(
    constant FilmDamageUniforms& uniforms,
    float2 point,
    float2 size,
    float antialiasWidth) {
    const float density = effectiveDensity(uniforms, uniforms.stain0.x);
    if (density <= 0.0f) {
        return 0.0f;
    }

    const uint stream = familyStream(uniforms.temporal.y, 0x53544149u);
    const float shortAxis = max(1.0f, min(size.x, size.y));
    const float scale = materialScale(uniforms);
    const float maxRadius =
        (1.5f + max(uniforms.stain1.x, uniforms.stain1.y) * shortAxis * 0.070f) *
        scale;
    const float cellSize = max(12.0f, maxRadius * 2.55f);
    const int2 baseCell = int2(floor(point / cellSize));
    float signedMask = 0.0f;

    for (int offsetY = -1; offsetY <= 1; ++offsetY) {
        for (int offsetX = -1; offsetX <= 1; ++offsetX) {
            const int2 cell = baseCell + int2(offsetX, offsetY);
            const TemporalEvent event = resolveTemporalEvent(
                uniforms,
                cell.x,
                cell.y,
                stream,
                uniforms.stain2.xy,
                uniforms.stain2.zw,
                0.35f);
            if (event.fade <= 0.0f) {
                continue;
            }

            const int birthFrame = as_type<int>(uniforms.temporal.x) - event.age;
            const float cluster = clusterGain(
                uniforms,
                0x53544149u,
                birthFrame,
                0.30f);
            const float2 stableCenter = (
                float2(cell) +
                float2(
                    randomUnit(cell.x, cell.y, event.cycle * 5 + 1, stream),
                    randomUnit(cell.x, cell.y, event.cycle * 5 + 2, stream))) *
                cellSize;
            const float edge = edgeProximity(stableCenter, size);
            const float edgeWeight = 1.0f +
                uniforms.stain0.w * unitClamp(uniforms.global1.x) * edge * 1.85f;
            const float presence = unitClamp(
                density * 0.40f * edgeWeight * cluster);
            if (randomUnit(cell.x, cell.y, event.cycle * 5 + 3, stream) >= presence) {
                continue;
            }

            const uint estream = eventStream(stream, cell.x, cell.y, event.cycle);
            const float ageProgress = event.lifetime <= 1
                ? 0.0f
                : float(event.age) / float(event.lifetime - 1);
            const float angle = randomUnit(cell.x, cell.y, event.cycle * 5 + 4, stream) * kTau;
            const float driftAmount = maxRadius * 0.018f;
            const float2 drift = float2(cos(angle), sin(angle)) *
                (ageProgress - 0.5f) * driftAmount;
            const float2 center = stableCenter + drift;
            const float sizeValue = rangeValue(
                uniforms.stain1.xy,
                randomUnit(cell.x, cell.y, event.cycle * 5 + 5, stream));
            const float radius = (1.2f + sizeValue * shortAxis * 0.060f) * scale;
            const float rotation = randomUnit(cell.x, cell.y, event.cycle * 5 + 6, stream) * kTau;
            const float anisotropy = mix(
                0.42f,
                0.86f,
                randomUnit(cell.x, cell.y, event.cycle * 5 + 7, stream));
            const float2 delta = point - center;
            const float2 rotated = float2(
                cos(rotation) * delta.x + sin(rotation) * delta.y,
                -sin(rotation) * delta.x + cos(rotation) * delta.y);
            const float2 shaped = float2(rotated.x, rotated.y / max(0.12f, anisotropy));
            const float effectiveRadius = max(radius, antialiasWidth);

            // Merged second pool lobe, then an irregular tide-line contour.
            const float lobeAngle = randomUnit(3, 7, 1, estream) * kTau;
            const float lobeReach = radius * mix(0.55f, 0.95f, randomUnit(5, 9, 2, estream));
            const float2 lobeCenter = float2(cos(lobeAngle), sin(lobeAngle)) * lobeReach;
            const float lobeRadius = radius * mix(0.45f, 0.75f, randomUnit(7, 11, 3, estream));
            const float mainDistance = length(shaped) / effectiveRadius;
            const float lobeDistance = length(shaped - lobeCenter) /
                max(lobeRadius, antialiasWidth);
            const float poolDistance = min(
                mainDistance,
                lobeDistance / mix(0.85f, 1.0f, randomUnit(9, 13, 4, estream)));
            const float contourAngle = atan2(shaped.y, shaped.x);
            const float contour = 1.0f +
                (angularRaggedNoise(contourAngle, 4, estream) - 0.5f) * 0.30f +
                (angularRaggedNoise(contourAngle, 9, estream ^ 0x9e3779b9u) - 0.5f) *
                    0.12f;
            const float normalizedDistance = poolDistance / max(0.2f, contour);

            // Rim-weighted deposit profile with a defined outer edge and a
            // faint mottled interior veil.
            const float softness = unitClamp(uniforms.stain0.y);
            const float edgeTransition = mix(0.035f, 0.16f, softness * 0.55f) +
                antialiasWidth / effectiveRadius;
            const float outer = 1.0f - smoothstep(
                1.0f,
                1.0f + edgeTransition,
                normalizedDistance);
            if (outer <= 0.0f) {
                continue;
            }
            const float rimCenter = mix(0.86f, 0.94f, randomUnit(11, 17, 5, estream));
            const float rimWidth = mix(0.05f, 0.12f, randomUnit(13, 19, 6, estream));
            const float rim = smoothstep(
                rimCenter - rimWidth,
                rimCenter,
                normalizedDistance);
            const float veilLevel = mix(0.16f, 0.30f, randomUnit(17, 23, 7, estream));
            const float veilMottle = mix(
                0.55f,
                1.0f,
                valueNoise2D(shaped / max(3.0f, radius * 0.90f), estream ^ 0x2545f491u));
            const float profile = outer * (
                rim +
                veilLevel * veilMottle * (1.0f - rim));
            const float mottle = mix(
                0.70f,
                1.0f,
                valueNoise2D(shaped / max(2.0f, radius * 0.33f), estream ^ 0x6d2b79f5u));
            const float shape = profile * mottle;
            if (shape <= 0.0f) {
                continue;
            }

            const float opacity = rangeValue(
                uniforms.stain1.zw,
                randomUnit(cell.x, cell.y, event.cycle * 5 + 8, stream));
            const float visibility = heldVisibility(event.fade, 0.80f);
            const float sign = polaritySign(
                uniforms.polarities.w,
                cell.x,
                cell.y,
                stream);
            signedMask = clamp(
                signedMask +
                    shape * opacity * visibility * globalGain(uniforms) * sign,
                -1.0f,
                1.0f);
        }
    }
    return signedMask;
}

// Two scratch populations share the lane architecture and contract ranges:
// long-lived "tramline" lanes (continuous transport scratches, upper part of
// the contract lifetime range) and short-lived fine "cinch" marks (coil
// slippage, lower part). A lane's class is stable so tramlines recur at
// consistent lateral positions like a persistent gate defect.
float scratchAxisMask(
    constant FilmDamageUniforms& uniforms,
    float2 point,
    float2 size,
    float antialiasWidth,
    bool vertical,
    float directionWeight) {
    const float density = effectiveDensity(uniforms, uniforms.scratch0.x) * directionWeight;
    if (density <= 0.0f) {
        return 0.0f;
    }

    const uint stream = familyStream(
        uniforms.temporal.y,
        vertical ? 0x53435256u : 0x53435248u);
    const float axisCoordinate = vertical ? point.x : point.y;
    const float runCoordinate = vertical ? point.y : point.x;
    const float axisSize = vertical ? size.x : size.y;
    const float runSize = vertical ? size.y : size.x;
    const float shortAxis = max(1.0f, min(size.x, size.y));
    const float scale = materialScale(uniforms);
    // Lane geometry stays canonical; antialiasWidth may only touch edge
    // transitions and minimum visible widths.
    const float bandSize = max(
        10.0f,
        mix(shortAxis * 0.23f, shortAxis * 0.034f, density) *
            (0.70f + unitClamp(uniforms.global0.w) * 0.62f));
    const int dirSalt = vertical ? 17 : 29;
    const int frameIndex = as_type<int>(uniforms.temporal.x);
    const float jitterAmount = unitClamp(uniforms.scratch3.w);
    const float roughness = unitClamp(uniforms.scratch0.y);
    const int baseLane = int(floor(axisCoordinate / bandSize));
    float signedMask = 0.0f;

    for (int laneOffset = -1; laneOffset <= 1; ++laneOffset) {
        const int lane = baseLane + laneOffset;
        const bool tramline = randomUnit(lane, dirSalt, 4, stream) < 0.38f;
        const float2 contractLifetime = uniforms.scratch4.xy;
        const float2 classLifetime = tramline
            ? float2(
                  mix(contractLifetime.x, contractLifetime.y, 0.45f),
                  contractLifetime.y)
            : float2(
                  contractLifetime.x,
                  mix(contractLifetime.x, contractLifetime.y, 0.35f));
        const TemporalEvent event = resolveTemporalEvent(
            uniforms,
            lane,
            dirSalt,
            stream,
            classLifetime,
            uniforms.scratch4.zw,
            0.65f);
        if (event.fade <= 0.0f) {
            continue;
        }

        const uint estream = eventStream(stream, lane, dirSalt, event.cycle);
        const int birthFrame = frameIndex - event.age;
        const float cluster = clusterGain(
            uniforms,
            vertical ? 0x53435256u : 0x53435248u,
            birthFrame,
            0.18f);
        const float centerBase = (
            float(lane) + randomUnit(lane, event.cycle, 1, stream)) * bandSize;
        const float centerNormalized = unitClamp(centerBase / max(1.0f, axisSize));
        const float areaHalfWidth = max(0.01f, unitClamp(uniforms.scratch5.y) * 0.5f);
        const float areaDistance = abs(centerNormalized - unitClamp(uniforms.scratch5.x));
        const float areaWeight = 1.0f - smoothstep(
            areaHalfWidth,
            min(1.0f, areaHalfWidth + 0.16f),
            areaDistance);
        const float gateWeight = gateProximity(centerBase, axisSize);
        const float presence = unitClamp(
            density *
            (0.20f + areaWeight * 0.58f +
             gateWeight * unitClamp(uniforms.scratch5.z) * 0.42f) *
            cluster * (tramline ? 1.0f : 1.12f));
        if (randomUnit(lane, event.cycle, 2, stream) >= presence) {
            continue;
        }

        const float lengthDraw = randomUnit(lane, event.cycle, 3, stream);
        // Both classes stay inside the configured contract range. Tramlines
        // draw from its upper region; fine cinch-like marks draw from its
        // lower region and obtain their shorter visible runs from breakup and
        // gaps rather than a hidden post-range multiplier.
        const float classLengthT = tramline
            ? mix(0.55f, 1.0f, lengthDraw)
            : pow(lengthDraw, 1.8f) * 0.35f;
        const float lengthPixels = runSize * rangeValue(
            uniforms.scratch1.zw,
            classLengthT);
        if (lengthPixels <= 0.0f) {
            continue;
        }
        const float segmentCenter = randomUnit(lane, event.cycle, 4, stream) * runSize;
        const float halfLength = max(0.000001f, lengthPixels * 0.5f);
        const float normalizedAlong = abs(runCoordinate - segmentCenter) / halfLength;
        const float taperWidth = mix(0.025f, 0.30f, unitClamp(uniforms.scratch0.z));
        const float segmentMask = 1.0f - smoothstep(
            1.0f - taperWidth,
            1.0f + antialiasWidth / halfLength,
            normalizedAlong);
        if (segmentMask <= 0.0f) {
            continue;
        }

        const float ageProgress = event.lifetime <= 1
            ? 0.0f
            : float(event.age) / float(event.lifetime - 1);
        const float waveFrequency = mix(
            1.2f,
            5.2f,
            randomUnit(lane, event.cycle, 5, stream));
        const float wavePhase = randomUnit(lane, event.cycle, 6, stream) * kTau +
            ageProgress * jitterAmount * 0.7f;
        const float waveAmplitude = unitClamp(uniforms.scratch3.z) * bandSize *
            mix(0.055f, 0.20f, randomUnit(lane, event.cycle, 7, stream));
        const float runNormalized = runCoordinate / max(1.0f, runSize);
        const float curve =
            sin(runNormalized * waveFrequency * kTau + wavePhase) * waveAmplitude +
            sin(runNormalized * (waveFrequency * 2.37f) * kTau - wavePhase * 0.61f) *
                waveAmplitude * 0.28f +
            (valueNoise1D(runNormalized * 3.1f, 21, 4, estream) - 0.5f) *
                unitClamp(uniforms.scratch3.z) * bandSize * 0.09f;
        const float heldDrift = (
            valueNoise1D(
                float(frameIndex) /
                    max(2.0f, uniforms.global1.y * 0.30f),
                lane,
                event.cycle,
                stream ^ 0x85ebca6bu) - 0.5f) *
            jitterAmount * bandSize * 0.075f;
        // A scratch groove crosses a different physical frame every frame:
        // its lateral position micro-jumps on a per-event tick and shimmers
        // very slightly per frame, restoring the public reference's
        // per-frame jitter semantics in a restrained, stepped form.
        const int tickLength = 4 + int(floor(randomUnit(1, 3, 5, estream) * 6.0f));
        const int tickIndex = floorDivide(frameIndex, tickLength);
        const float tickJump =
            (randomUnit(tickIndex, 2, 1, estream) - 0.5f) * 2.0f *
            jitterAmount * shortAxis * 0.0024f * (tramline ? 1.4f : 0.9f);
        const float frameShimmer =
            (randomUnit(frameIndex, 3, 2, estream) - 0.5f) * 2.0f *
            jitterAmount * shortAxis * 0.0008f;
        const float center = centerBase + curve + heldDrift + tickJump + frameShimmer;

        const float widthEnvelope = mix(0.52f, 1.0f, smoothUnit(segmentMask));
        const float baseWidth = (0.30f +
            rangeValue(
                uniforms.scratch1.xy,
                randomUnit(lane, event.cycle, 8, stream)) *
                shortAxis * 0.0072f) * scale *
            widthEnvelope * (tramline ? 1.0f : 0.72f);
        const float edgeVariation = valueNoise1D(
            runCoordinate / max(2.5f, baseWidth * 4.5f),
            lane,
            event.cycle,
            stream ^ 0xc2b2ae35u);
        const float localWidth = max(
            antialiasWidth * 0.18f,
            baseWidth * mix(
                1.0f - roughness * 0.42f,
                1.0f + roughness * 0.38f,
                edgeVariation));
        const float axisDistance = abs(axisCoordinate - center);
        const float lineCore = 1.0f - smoothstep(
            max(0.0f, localWidth - antialiasWidth * 0.70f),
            localWidth + antialiasWidth * 0.82f,
            axisDistance);
        const float scuffWidth = localWidth * mix(
            2.4f,
            3.6f,
            randomUnit(10, 17, 9, estream));
        const float scuffNoise = valueNoise1D(
            runCoordinate / max(6.0f, localWidth * 7.0f),
            23,
            5,
            estream ^ 0x51ed270bu);
        const float scuff =
            (1.0f - smoothstep(localWidth * 0.9f, scuffWidth, axisDistance)) *
            smoothstep(0.35f, 0.85f, scuffNoise) *
            mix(0.10f, 0.26f, roughness);
        const float lineMask = clamp(lineCore + scuff * (1.0f - lineCore), 0.0f, 1.0f);
        if (lineMask <= 0.0f) {
            continue;
        }

        const float gapDensity = unitClamp(
            uniforms.scratch0.w * 0.58f + uniforms.scratch2.z * 0.42f);
        const float gapSize = rangeValue(
            uniforms.scratch3.xy,
            randomUnit(lane, event.cycle, 9, stream));
        const float gapCell = max(
            2.5f,
            mix(52.0f, 8.0f, gapDensity) *
                mix(1.30f, 0.52f, gapSize) *
                scale);
        // The broken pattern slides slowly along the scratch while gap depth
        // flutters on a stepped cadence and the fine breakup boils on a
        // short tick — the event itself stays anchored.
        const float travelOffset =
            (randomUnit(3, 7, 11, estream) - 0.5f) * runSize * 0.10f +
            (valueNoise1D(
                float(frameIndex) / max(2.0f, uniforms.global1.y * 0.60f),
                25,
                6,
                estream ^ 0x8f1bbcdcu) - 0.5f) * runSize * 0.02f;
        const float gapNoise = valueNoise1D(
            (runCoordinate + travelOffset) / gapCell,
            lane,
            event.cycle,
            stream ^ 0x27d4eb2fu);
        const float gapThreshold = 1.0f - gapDensity * 0.72f;
        const float gapTransition = mix(
            0.025f,
            0.20f,
            unitClamp(uniforms.scratch2.w));
        const float hole = smoothstep(
            gapThreshold - gapTransition,
            gapThreshold + gapTransition,
            gapNoise);
        const int flutterPeriod = 5 + int(floor(randomUnit(4, 9, 3, estream) * 4.0f));
        const int flutterIndex = floorDivide(frameIndex, flutterPeriod);
        const float gapFloor = mix(0.02f, 0.42f, unitClamp(uniforms.scratch2.w)) *
            mix(0.75f, 1.0f, randomUnit(flutterIndex, 5, 4, estream));
        const float gapMask = mix(1.0f, gapFloor, hole);
        const int boilPeriod = 2 + int(floor(randomUnit(6, 9, 5, estream) * 3.0f));
        const int boilIndex = floorDivide(frameIndex, boilPeriod);
        const float breakupTexture = mix(
            1.0f,
            0.48f + 0.52f * valueNoise1D(
                runCoordinate / max(1.6f, localWidth * 2.8f),
                lane,
                event.cycle * 131 + boilIndex,
                stream ^ 0x165667b1u),
            unitClamp(uniforms.scratch0.w));
        const float breathPeriod = mix(7.0f, 15.0f, randomUnit(7, 11, 8, estream));
        const float breath = mix(
            0.82f,
            1.14f,
            valueNoise1D(
                float(frameIndex) / breathPeriod,
                27,
                7,
                estream ^ 0x94d049bbu));
        const float opacity = rangeValue(
            uniforms.scratch2.xy,
            randomUnit(lane, event.cycle, 10, stream)) *
            (tramline ? 1.0f : 0.80f);
        const float visibility = heldVisibility(
            event.fade,
            tramline ? 0.72f : 0.58f);
        const float sign = polaritySign(
            uniforms.polarities.y,
            lane,
            event.cycle,
            stream);
        signedMask = clamp(
            signedMask +
                lineMask * segmentMask * gapMask * breakupTexture * breath *
                opacity * visibility * globalGain(uniforms) * sign,
            -1.0f,
            1.0f);
    }
    return signedMask;
}

float scratchMask(
    constant FilmDamageUniforms& uniforms,
    float2 point,
    float2 size,
    float antialiasWidth) {
    const uint direction = uniforms.modes.y;
    if (direction == 0u) {
        return scratchAxisMask(uniforms, point, size, antialiasWidth, true, 1.0f);
    }
    if (direction == 1u) {
        return scratchAxisMask(uniforms, point, size, antialiasWidth, false, 1.0f);
    }
    const float vertical = scratchAxisMask(
        uniforms,
        point,
        size,
        antialiasWidth,
        true,
        1.0f);
    const float horizontal = scratchAxisMask(
        uniforms,
        point,
        size,
        antialiasWidth,
        false,
        0.30f);
    return clamp(vertical + horizontal * 0.62f, -1.0f, 1.0f);
}

// Hairs lodge at the gate aperture, so every fiber is anchored at a frame
// edge and intrudes partway with a curved, tapering, subtly trembling path.
// Along-edge travel (tilt + bend + hook + wiggle + sway) is capped below two
// anchor slots so the +/-2 lane iteration covers every reachable event while
// the configured length range remains authoritative.
float fiberMask(
    constant FilmDamageUniforms& uniforms,
    float2 point,
    float2 size,
    float antialiasWidth) {
    const float density = effectiveDensity(uniforms, uniforms.fiber0.x);
    if (density <= 0.0f) {
        return 0.0f;
    }

    const uint stream = familyStream(uniforms.temporal.y, 0x46494252u);
    const float shortAxis = max(1.0f, min(size.x, size.y));
    const float scale = materialScale(uniforms);
    const float curl = unitClamp(uniforms.fiber0.y);
    const float wiggle = unitClamp(uniforms.fiber0.z);
    const float gateBias = unitClamp(uniforms.fiber3.z);
    const float slotSize = max(
        24.0f,
        shortAxis * mix(0.36f, 0.11f, density) *
            (0.76f + unitClamp(uniforms.global0.w) * 0.50f));
    const float time = uniforms.context.x;
    const int frameIndex = as_type<int>(uniforms.temporal.x);
    float signedMask = 0.0f;

    for (int side = 0; side < 4; ++side) {
        const bool verticalSide = side < 2;
        const float normalExtent = verticalSide ? size.x : size.y;
        const float maxLength =
            max(uniforms.fiber1.x, uniforms.fiber1.y) * normalExtent;
        // Curvature can move the path slightly deeper than its projected
        // length. The bounded slot allowance covers that movement without
        // changing the public length value.
        const float sideReach = maxLength + slotSize * 0.90f + 8.0f;
        const float edgeCoord = side == 0 ? point.x
            : side == 1 ? (size.x - point.x)
            : side == 2 ? point.y
            : (size.y - point.y);
        if (edgeCoord > sideReach) {
            continue;
        }
        const float2 into = side == 0 ? float2(1.0f, 0.0f)
            : side == 1 ? float2(-1.0f, 0.0f)
            : side == 2 ? float2(0.0f, 1.0f)
            : float2(0.0f, -1.0f);
        const float2 alongDir = verticalSide
            ? float2(0.0f, 1.0f)
            : float2(1.0f, 0.0f);
        const float along = verticalSide ? point.y : point.x;
        const float sideWeight = verticalSide
            ? mix(0.55f, 1.0f, gateBias)
            : mix(0.85f, 0.26f, gateBias);
        const int baseLane = int(floor(along / slotSize));

        for (int laneOffset = -2; laneOffset <= 2; ++laneOffset) {
            const int lane = baseLane + laneOffset;
            const TemporalEvent event = resolveTemporalEvent(
                uniforms,
                lane,
                41 + side * 23,
                stream,
                uniforms.fiber2.zw,
                uniforms.fiber3.xy,
                1.0f - unitClamp(uniforms.fiber0.w) * 0.75f);
            if (event.fade <= 0.0f) {
                continue;
            }

            const float presence = unitClamp(density * sideWeight * 0.42f);
            if (randomUnit(lane, side * 31 + 2, event.cycle, stream) >= presence) {
                continue;
            }

            const uint estream = eventStream(
                stream,
                lane,
                side * 131 + 7,
                event.cycle);
            const float rootAlong = (
                float(lane) +
                randomUnit(lane, side * 31 + 1, event.cycle, stream)) * slotSize;
            const float2 edgeOrigin = side == 0 ? float2(0.0f, rootAlong)
                : side == 1 ? float2(size.x, rootAlong)
                : side == 2 ? float2(rootAlong, 0.0f)
                : float2(rootAlong, size.y);
            const float lengthT = pow(randomUnit(1, 3, 5, estream), 1.4f);
            const float len =
                rangeValue(uniforms.fiber1.xy, lengthT) * normalExtent;
            if (len <= 0.0f) {
                continue;
            }
            const float sinTiltLimit = min(0.72f, 0.92f * slotSize / len);
            const float sinTilt =
                (randomUnit(2, 5, 7, estream) - 0.5f) * 2.0f * sinTiltLimit;
            const float cosTilt = sqrt(max(0.0f, 1.0f - sinTilt * sinTilt));
            const float2 dir = into * cosTilt + alongDir * sinTilt;
            const float2 normal = float2(-dir.y, dir.x);
            const float baseWidth = (0.35f +
                rangeValue(
                    uniforms.fiber1.zw,
                    randomUnit(3, 7, 9, estream)) * shortAxis * 0.0048f) * scale;
            const float2 root = edgeOrigin - into * (baseWidth * 1.2f);
            const float2 offsetFromRoot = point - root;
            const float t = dot(offsetFromRoot, dir) / len;
            if (t < -0.06f || t > 1.10f) {
                continue;
            }
            const float arcT = unitClamp(t);

            const float bendAmp = clamp(
                len * curl * (randomUnit(4, 9, 11, estream) - 0.5f) * 0.68f,
                -0.28f * slotSize,
                0.28f * slotSize);
            const float hookAmp = clamp(
                len * curl * (randomUnit(5, 11, 13, estream) - 0.5f) * 1.10f,
                -0.24f * slotSize,
                0.24f * slotSize);
            const float bend =
                bendAmp * arcT * arcT + hookAmp * arcT * arcT * arcT;
            const float rawWiggleNoise =
                (valueNoise1D(t * 5.3f, 3, 1, estream) - 0.5f) *
                    len * 0.045f * wiggle +
                (valueNoise1D(t * 13.7f, 5, 2, estream) - 0.5f) *
                    len * 0.016f * wiggle;
            const float wiggleNoise = clamp(
                rawWiggleNoise,
                -slotSize * 0.16f,
                slotSize * 0.16f);
            const float swayFrequency1 = mix(
                1.1f,
                2.9f,
                randomUnit(6, 13, 17, estream));
            const float swayFrequency2 = mix(
                4.6f,
                8.4f,
                randomUnit(7, 17, 19, estream));
            const float swayPhase1 = randomUnit(8, 19, 23, estream) * kTau;
            const float swayPhase2 = randomUnit(9, 23, 29, estream) * kTau;
            const float tipSway = (1.1f + len * 0.006f) * wiggle * 2.2f;
            const int tickLength = 3 + int(floor(
                randomUnit(10, 29, 31, estream) * 5.0f));
            const int tickIndex = floorDivide(frameIndex, tickLength);
            const float tickJump =
                (randomUnit(tickIndex, 12, 3, estream) - 0.5f) * tipSway * 0.8f;
            const float rawSway =
                (sin(time * swayFrequency1 * kTau + swayPhase1) * 0.7f +
                 sin(time * swayFrequency2 * kTau + swayPhase2) * 0.3f) *
                    tipSway +
                tickJump;
            const float sway = clamp(
                rawSway,
                -slotSize * 0.14f,
                slotSize * 0.14f);
            const float swayEnvelope = pow(arcT, 1.6f);
            const float lateral = dot(offsetFromRoot, normal) -
                (bend + wiggleNoise + sway * swayEnvelope);

            const float widthTexture = valueNoise1D(
                t * len / max(3.0f, baseWidth * 5.0f),
                lane,
                event.cycle,
                estream ^ 0x9e3779b9u);
            const float taper = mix(1.0f, 0.26f, pow(arcT, 1.3f));
            const float localWidth = max(
                antialiasWidth * 0.14f,
                baseWidth * taper * mix(0.66f, 1.24f, widthTexture));
            const float lineMask = 1.0f - smoothstep(
                max(0.0f, localWidth - antialiasWidth * 0.72f),
                localWidth + antialiasWidth * 0.88f,
                abs(lateral));
            if (lineMask <= 0.0f) {
                continue;
            }
            const float segmentMask =
                smoothstep(-0.02f, 0.05f, t) *
                (1.0f - smoothstep(0.88f, 1.02f, t));
            if (segmentMask <= 0.0f) {
                continue;
            }

            const float opacity = rangeValue(
                uniforms.fiber2.xy,
                randomUnit(11, 31, 37, estream));
            const float materialTexture = mix(0.62f, 1.0f, widthTexture);
            const float visibility = heldVisibility(event.fade, 0.78f);
            const float sign = polaritySign(
                uniforms.polarities.z,
                lane,
                event.cycle,
                stream);
            signedMask = clamp(
                signedMask +
                    lineMask * segmentMask * materialTexture * opacity *
                    visibility * globalGain(uniforms) * sign,
                -1.0f,
                1.0f);
        }
    }
    return signedMask;
}

// Worn gate rails: broken edge bands whose width wobbles along the edge,
// streaky dirt buildup (non-periodic, two noise scales), grit across the
// band depth, complementary per-seed side asymmetry, and stepped epoch
// evolution. All geometry canonical.
float gateWearMask(
    constant FilmDamageUniforms& uniforms,
    float2 point,
    float2 size,
    float antialiasWidth) {
    const float amount = unitClamp(uniforms.gate0.x);
    const float opacity = unitClamp(uniforms.gate0.z);
    if (amount <= 0.0f || opacity <= 0.0f) {
        return 0.0f;
    }

    const uint stream = familyStream(uniforms.temporal.y, 0x47415445u);
    const float shortAxis = max(1.0f, min(size.x, size.y));
    const float gateScale = profileParameters(uniforms.temporal.z).w;
    const float softness = unitClamp(uniforms.gate0.w);
    const float jitter = unitClamp(uniforms.gate1.x);
    const float wearBase = max(
        2.5f,
        shortAxis * (0.006f + unitClamp(uniforms.gate0.y) * 0.048f) * gateScale);
    const float leftDistance = max(0.0f, point.x);
    const float rightDistance = max(0.0f, size.x - point.x);
    const bool left = leftDistance <= rightDistance;
    const float edgeDistance = left ? leftDistance : rightDistance;
    const int side = left ? 0 : 1;

    const int frameIndex = as_type<int>(uniforms.temporal.x);
    const float epochLength = max(
        2.0f,
        max(1.0f, uniforms.global1.y) *
            mix(2.4f, 0.85f, jitter));
    const float epochCoordinate = float(frameIndex) / epochLength;
    const int epoch = int(floor(epochCoordinate));
    const float epochBlend = smoothUnit(epochCoordinate - floor(epochCoordinate));
    const float verticalCell = max(
        4.0f,
        shortAxis * mix(0.050f, 0.018f, jitter));
    const float patternCoordinate = point.y / verticalCell;

    // One rail wears harder than the other; the draws are complementary so
    // one side always carries near-full wear.
    const float sideBalance = randomUnit(1, 2, 3, stream);
    const float sideGain = side == 0
        ? mix(0.72f, 1.0f, sideBalance)
        : mix(0.72f, 1.0f, 1.0f - sideBalance);

    const float widthWobble = mix(
        0.72f,
        1.32f,
        mix(
            valueNoise1D(
                point.y / (verticalCell * 2.3f),
                side + 4,
                epoch,
                stream ^ 0x51ed270bu),
            valueNoise1D(
                point.y / (verticalCell * 2.3f),
                side + 4,
                epoch + 1,
                stream ^ 0x51ed270bu),
            epochBlend));
    const float wearWidth = wearBase * widthWobble;
    const float edgeMask = 1.0f - smoothstep(
        wearWidth * mix(0.16f, 0.38f, softness),
        wearWidth * (0.92f + softness * 0.80f) + antialiasWidth,
        edgeDistance);
    if (edgeMask <= 0.0f) {
        return 0.0f;
    }

    const float firstPattern = valueNoise1D(
        patternCoordinate,
        side,
        epoch,
        stream);
    const float secondPattern = valueNoise1D(
        patternCoordinate,
        side,
        epoch + 1,
        stream);
    const float brokenPattern = mix(firstPattern, secondPattern, epochBlend);
    const float breakMask = smoothstep(
        mix(0.34f, 0.52f, amount),
        mix(0.62f, 0.72f, softness),
        brokenPattern);

    const float fineCell = max(1.5f, wearBase * 0.42f);
    const float coarseCell = max(3.0f, wearBase * 1.6f);
    const float fineStreak = mix(
        valueNoise1D(point.y / fineCell, side + 12, epoch, stream ^ 0xc2b2ae35u),
        valueNoise1D(point.y / fineCell, side + 12, epoch + 1, stream ^ 0xc2b2ae35u),
        epochBlend);
    const float coarseStreak = mix(
        valueNoise1D(point.y / coarseCell, side + 16, epoch, stream ^ 0x94d049bbu),
        valueNoise1D(point.y / coarseCell, side + 16, epoch + 1, stream ^ 0x94d049bbu),
        epochBlend);
    const float streak = mix(
        0.55f,
        1.0f,
        unitClamp(fineStreak * 0.65f + coarseStreak * 0.35f));
    const float depthGrit = mix(
        0.72f,
        1.0f,
        mix(
            valueNoise1D(
                edgeDistance / max(1.5f, wearBase * 0.55f),
                side + 8,
                epoch,
                stream ^ 0x2545f491u),
            valueNoise1D(
                edgeDistance / max(1.5f, wearBase * 0.55f),
                side + 8,
                epoch + 1,
                stream ^ 0x2545f491u),
            epochBlend));

    const float sign = polaritySign(
        uniforms.modes.x,
        side,
        int(floor(patternCoordinate)),
        stream);
    return clamp(
        edgeMask * mix(0.34f, 1.0f, breakMask) * streak * depthGrit *
            amount * opacity * sideGain * globalGain(uniforms) * sign,
        -1.0f,
        1.0f);
}

float3 applyMaterialDamage(
    float3 rgb,
    float signedMask,
    float chromaticity,
    float3 lightTint) {
    if (signedMask == 0.0f) {
        return rgb;
    }

    const float magnitude = unitClamp(abs(signedMask));
    const float chroma = unitClamp(chromaticity);
    const float luminance = dot(rgb, float3(0.2126f, 0.7152f, 0.0722f));
    if (signedMask < 0.0f) {
        // Mineral/chemical deposits lean warm; only families that pass a
        // non-zero chromaticity (stains) pick this up.
        const float3 neutralMaterial = luminance * float3(
            0.18f + chroma * 0.060f,
            0.18f,
            0.18f - chroma * 0.045f);
        return mix(rgb, neutralMaterial, magnitude * 0.91f);
    }

    // Positive material is intentionally lower gain than dark material. With
    // mixed polarity it is also selected rarely by polaritySign(). lightTint
    // lets a family bias its rare light marks (emulsion-side scratches strip
    // dye layers and read pale green-cyan rather than pure white).
    const float sparkleLevel = 0.38f + abs(luminance) * 0.07f;
    const float3 sparkleTint = lightTint * float3(
        1.0f + chroma * 0.08f,
        1.0f,
        1.0f - chroma * 0.06f);
    return rgb + sparkleTint * (magnitude * sparkleLevel * 0.42f);
}

kernel void filmtoneResolveFilmDamage(
    device const float4* source [[buffer(0)]],
    device float4* output [[buffer(1)]],
    constant FilmDamageUniforms& uniforms [[buffer(2)]],
    uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uniforms.io.x || position.y >= uniforms.io.y) {
        return;
    }

    const int absoluteX = uniforms.origins.x + int(position.x);
    const int absoluteY = uniforms.origins.y + int(position.y);
    const int sourceX = absoluteX - uniforms.origins.z;
    const int sourceY = absoluteY - uniforms.origins.w;
    const int outputX = absoluteX - uniforms.outputAndDebug.x;
    const int outputY = absoluteY - uniforms.outputAndDebug.y;
    const uint sourceIndex = uint(sourceY) * uniforms.io.z + uint(sourceX);
    const uint outputIndex = uint(outputY) * uniforms.io.w + uint(outputX);
    const float4 sourceColor = source[sourceIndex];

    if (uniforms.temporal.w == 0u || globalGain(uniforms) <= 0.0f) {
        output[outputIndex] = sourceColor;
        return;
    }

    const float2 renderScale = max(uniforms.context.zw, float2(0.000001f));
    const float2 canonicalSize = max(uniforms.bounds.zw, float2(1.0f));
    const float2 canonicalPoint =
        (float2(absoluteX, absoluteY) + 0.5f) / renderScale -
        uniforms.bounds.xy;
    const float antialiasWidth = 1.0f / max(
        0.000001f,
        min(renderScale.x, renderScale.y));

    const float stain = stainFamilyMask(
        uniforms,
        canonicalPoint,
        canonicalSize,
        antialiasWidth);
    const float gateWear = gateWearMask(
        uniforms,
        canonicalPoint,
        canonicalSize,
        antialiasWidth);
    const float dust = dustFamilyMask(
        uniforms,
        canonicalPoint,
        canonicalSize,
        antialiasWidth);
    const float fibers = fiberMask(
        uniforms,
        canonicalPoint,
        canonicalSize,
        antialiasWidth);
    const float scratches = scratchMask(
        uniforms,
        canonicalPoint,
        canonicalSize,
        antialiasWidth);

    const uint debugView = uint(max(0, uniforms.outputAndDebug.z));
    if (debugView != 0u) {
        float debugMask = 0.0f;
        if (debugView == 1u) {
            debugMask = abs(dust);
        } else if (debugView == 2u) {
            debugMask = abs(fibers);
        } else if (debugView == 3u) {
            debugMask = abs(scratches);
        } else if (debugView == 4u) {
            debugMask = abs(stain);
        } else if (debugView == 5u) {
            debugMask = abs(gateWear);
        } else {
            debugMask = max(
                max(abs(dust), abs(fibers)),
                max(max(abs(scratches), abs(stain)), abs(gateWear)));
        }
        output[outputIndex] = float4(float3(unitClamp(debugMask)), sourceColor.a);
        return;
    }

    float3 rgb = sourceColor.rgb;
    const float3 neutralLight = float3(1.0f);
    const float3 emulsionScratchLight = float3(0.90f, 1.0f, 0.955f);
    rgb = applyMaterialDamage(
        rgb,
        stain,
        max(uniforms.global0.z, uniforms.stain0.z),
        neutralLight);
    rgb = applyMaterialDamage(rgb, gateWear, uniforms.global0.z, neutralLight);
    rgb = applyMaterialDamage(rgb, dust, uniforms.global0.z, neutralLight);
    rgb = applyMaterialDamage(rgb, fibers, uniforms.global0.z, neutralLight);
    rgb = applyMaterialDamage(
        rgb,
        scratches,
        uniforms.global0.z,
        emulsionScratchLight);

    // RGB is intentionally not clamped. Alpha is copied unchanged from the
    // source pixel for every active and debug path.
    output[outputIndex] = float4(rgb, sourceColor.a);
}
)FILMTONE_METAL";

}  // namespace filmtone::resolve::damage::detail
