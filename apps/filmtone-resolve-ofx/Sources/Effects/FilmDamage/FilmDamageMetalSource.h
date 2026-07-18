#pragma once

namespace filmtone::resolve::damage::detail {

inline constexpr char kFilmDamageMetalFunctionName[] = "filmtoneFinishFilmDamage";
inline constexpr char kFilmDamageMetalCacheKey[] = "filmtone.finish.damage.metal.v1";

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

float spotFamilyMask(
    constant FilmDamageUniforms& uniforms,
    float2 point,
    float2 size,
    float antialiasWidth,
    bool stain) {
    const float4 family0 = stain ? uniforms.stain0 : uniforms.dust0;
    const float4 family1 = stain ? uniforms.stain1 : uniforms.dust1;
    const float4 family2 = stain ? uniforms.stain2 : uniforms.dust2;
    const float density = effectiveDensity(uniforms, family0.x);
    if (density <= 0.0f) {
        return 0.0f;
    }

    const uint stream = familyStream(
        uniforms.temporal.y,
        stain ? 0x53544149u : 0x44555354u);
    const float shortAxis = max(1.0f, min(size.x, size.y));
    const float scale = materialScale(uniforms);
    const float maxRadius = stain
        ? antialiasWidth + (1.5f + max(family1.x, family1.y) * shortAxis * 0.070f) * scale
        : antialiasWidth * 0.45f + (0.55f + max(family1.x, family1.y) * shortAxis * 0.010f) * scale;
    const float cellSize = max(
        antialiasWidth * 4.0f,
        maxRadius * (stain ? 2.55f : 3.65f));
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
                family2.xy,
                family2.zw,
                stain ? 0.35f : family0.z);
            if (event.fade <= 0.0f) {
                continue;
            }

            const float2 stableCenter = (
                float2(cell) +
                float2(
                    randomUnit(cell.x, cell.y, event.cycle * 5 + 1, stream),
                    randomUnit(cell.x, cell.y, event.cycle * 5 + 2, stream))) *
                cellSize;
            const float edge = edgeProximity(stableCenter, size);
            const float edgeWeight = 1.0f +
                family0.w * unitClamp(uniforms.global1.x) * edge * 1.85f;
            const float presence = unitClamp(
                density * (stain ? 0.40f : 0.52f) * edgeWeight);
            if (randomUnit(cell.x, cell.y, event.cycle * 5 + 3, stream) >= presence) {
                continue;
            }

            const float ageProgress = event.lifetime <= 1
                ? 0.0f
                : float(event.age) / float(event.lifetime - 1);
            const float angle = randomUnit(cell.x, cell.y, event.cycle * 5 + 4, stream) * kTau;
            const float driftAmount = maxRadius * (stain ? 0.018f : family0.z * 0.12f);
            const float2 drift = float2(cos(angle), sin(angle)) *
                (ageProgress - 0.5f) * driftAmount;
            const float2 center = stableCenter + drift;
            const float sizeValue = rangeValue(
                family1.xy,
                randomUnit(cell.x, cell.y, event.cycle * 5 + 5, stream));
            const float radius = stain
                ? antialiasWidth + (1.2f + sizeValue * shortAxis * 0.060f) * scale
                : antialiasWidth * 0.40f + (0.5f + sizeValue * shortAxis * 0.0085f) * scale;
            const float rotation = randomUnit(cell.x, cell.y, event.cycle * 5 + 6, stream) * kTau;
            const float anisotropy = stain
                ? mix(0.42f, 0.86f, randomUnit(cell.x, cell.y, event.cycle * 5 + 7, stream))
                : mix(0.68f, 1.12f, randomUnit(cell.x, cell.y, event.cycle * 5 + 7, stream));
            const float2 delta = point - center;
            const float2 rotated = float2(
                cos(rotation) * delta.x + sin(rotation) * delta.y,
                -sin(rotation) * delta.x + cos(rotation) * delta.y);
            const float2 shaped = float2(rotated.x, rotated.y / max(0.12f, anisotropy));
            const float normalizedDistance = length(shaped) / max(antialiasWidth, radius);
            const float contourAngle = atan2(shaped.y, shaped.x);
            const float contour =
                1.0f +
                sin(contourAngle * (stain ? 3.0f : 5.0f) + rotation) * (stain ? 0.10f : 0.16f) +
                sin(contourAngle * (stain ? 7.0f : 9.0f) - rotation * 1.7f) * (stain ? 0.05f : 0.09f);
            const float softness = unitClamp(family0.y);
            const float edgeStart = stain
                ? mix(0.12f, 0.48f, softness)
                : mix(0.48f, 0.78f, softness);
            const float shape = 1.0f - smoothstep(
                edgeStart,
                1.0f + antialiasWidth / max(radius, antialiasWidth),
                normalizedDistance / max(0.2f, contour));
            if (shape <= 0.0f) {
                continue;
            }

            const float textureScale = max(antialiasWidth * (stain ? 5.0f : 2.0f), radius * 0.28f);
            const float texture = mix(
                stain ? 0.58f : 0.70f,
                1.0f,
                randomUnit(
                    int(floor(point.x / textureScale)),
                    int(floor(point.y / textureScale)),
                    event.cycle,
                    stream ^ 0x6d2b79f5u));
            const float opacity = rangeValue(
                family1.zw,
                randomUnit(cell.x, cell.y, event.cycle * 5 + 8, stream));
            const uint polarity = stain ? uniforms.polarities.w : uniforms.polarities.x;
            const float sign = polaritySign(polarity, cell.x, cell.y, stream);
            signedMask = clamp(
                signedMask +
                    shape * texture * opacity * event.fade * globalGain(uniforms) * sign,
                -1.0f,
                1.0f);
        }
    }
    return signedMask;
}

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
    const float bandSize = max(
        antialiasWidth * 7.0f,
        mix(shortAxis * 0.23f, shortAxis * 0.034f, density) *
            (0.70f + unitClamp(uniforms.global0.w) * 0.62f));
    const int baseLane = int(floor(axisCoordinate / bandSize));
    float signedMask = 0.0f;

    for (int laneOffset = -1; laneOffset <= 1; ++laneOffset) {
        const int lane = baseLane + laneOffset;
        const TemporalEvent event = resolveTemporalEvent(
            uniforms,
            lane,
            vertical ? 17 : 29,
            stream,
            uniforms.scratch4.xy,
            uniforms.scratch4.zw,
            0.65f);
        if (event.fade <= 0.0f) {
            continue;
        }

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
            (0.20f + areaWeight * 0.58f + gateWeight * unitClamp(uniforms.scratch5.z) * 0.42f));
        if (randomUnit(lane, event.cycle, 2, stream) >= presence) {
            continue;
        }

        const float lengthPixels = runSize * rangeValue(
            uniforms.scratch1.zw,
            randomUnit(lane, event.cycle, 3, stream));
        const float segmentCenter = randomUnit(lane, event.cycle, 4, stream) * runSize;
        const float halfLength = max(antialiasWidth, lengthPixels * 0.5f);
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
            ageProgress * unitClamp(uniforms.scratch3.w) * 0.7f;
        const float waveAmplitude = unitClamp(uniforms.scratch3.z) * bandSize *
            mix(0.055f, 0.20f, randomUnit(lane, event.cycle, 7, stream));
        const float runNormalized = runCoordinate / max(1.0f, runSize);
        const float curve =
            sin(runNormalized * waveFrequency * kTau + wavePhase) * waveAmplitude +
            sin(runNormalized * (waveFrequency * 2.37f) * kTau - wavePhase * 0.61f) *
                waveAmplitude * 0.28f;
        const float heldDrift = (
            valueNoise1D(
                float(as_type<int>(uniforms.temporal.x)) /
                    max(2.0f, uniforms.global1.y * 0.30f),
                lane,
                event.cycle,
                stream ^ 0x85ebca6bu) - 0.5f) *
            unitClamp(uniforms.scratch3.w) * bandSize * 0.075f;
        const float center = centerBase + curve + heldDrift;

        const float baseWidth = antialiasWidth * 0.20f +
            rangeValue(
                uniforms.scratch1.xy,
                randomUnit(lane, event.cycle, 8, stream)) *
                shortAxis * 0.0072f * materialScale(uniforms);
        const float edgeVariation = valueNoise1D(
            runCoordinate / max(antialiasWidth * 3.0f, baseWidth * 4.5f),
            lane,
            event.cycle,
            stream ^ 0xc2b2ae35u);
        const float localWidth = max(
            antialiasWidth * 0.18f,
            baseWidth * mix(
                1.0f - unitClamp(uniforms.scratch0.y) * 0.42f,
                1.0f + unitClamp(uniforms.scratch0.y) * 0.38f,
                edgeVariation));
        const float lineMask = 1.0f - smoothstep(
            max(0.0f, localWidth - antialiasWidth * 0.70f),
            localWidth + antialiasWidth * 0.82f,
            abs(axisCoordinate - center));
        if (lineMask <= 0.0f) {
            continue;
        }

        const float gapDensity = unitClamp(
            uniforms.scratch0.w * 0.58f + uniforms.scratch2.z * 0.42f);
        const float gapSize = rangeValue(
            uniforms.scratch3.xy,
            randomUnit(lane, event.cycle, 9, stream));
        const float gapCell = max(
            antialiasWidth * 3.0f,
            mix(52.0f, 8.0f, gapDensity) *
                mix(1.30f, 0.52f, gapSize) *
                materialScale(uniforms));
        const float gapNoise = valueNoise1D(
            runCoordinate / gapCell,
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
        const float gapFloor = mix(
            0.02f,
            0.42f,
            unitClamp(uniforms.scratch2.w));
        const float gapMask = mix(1.0f, gapFloor, hole);
        const float breakupTexture = mix(
            1.0f,
            0.48f + 0.52f * valueNoise1D(
                runCoordinate / max(antialiasWidth * 2.0f, localWidth * 2.8f),
                lane,
                event.cycle,
                stream ^ 0x165667b1u),
            unitClamp(uniforms.scratch0.w));
        const float opacity = rangeValue(
            uniforms.scratch2.xy,
            randomUnit(lane, event.cycle, 10, stream));
        const float sign = polaritySign(
            uniforms.polarities.y,
            lane,
            event.cycle,
            stream);
        signedMask = clamp(
            signedMask +
                lineMask * segmentMask * gapMask * breakupTexture * opacity *
                event.fade * globalGain(uniforms) * sign,
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
    const float bandSize = max(
        antialiasWidth * 9.0f,
        mix(shortAxis * 0.38f, shortAxis * 0.085f, density) *
            (0.76f + unitClamp(uniforms.global0.w) * 0.50f));
    const int baseLane = int(floor(point.x / bandSize));
    float signedMask = 0.0f;

    for (int laneOffset = -1; laneOffset <= 1; ++laneOffset) {
        const int lane = baseLane + laneOffset;
        const TemporalEvent event = resolveTemporalEvent(
            uniforms,
            lane,
            41,
            stream,
            uniforms.fiber2.zw,
            uniforms.fiber3.xy,
            1.0f - unitClamp(uniforms.fiber0.w) * 0.75f);
        if (event.fade <= 0.0f) {
            continue;
        }

        const float baseX = (
            float(lane) + randomUnit(lane, event.cycle, 1, stream)) * bandSize;
        const float gateWeight = gateProximity(baseX, size.x);
        const float presence = unitClamp(
            density *
            (0.18f + gateWeight * unitClamp(uniforms.fiber3.z) * 0.72f));
        if (randomUnit(lane, event.cycle, 2, stream) >= presence) {
            continue;
        }

        const float lengthPixels = size.y * rangeValue(
            uniforms.fiber1.xy,
            randomUnit(lane, event.cycle, 3, stream));
        const float centerY = randomUnit(lane, event.cycle, 4, stream) * size.y;
        const float halfLength = max(antialiasWidth, lengthPixels * 0.5f);
        const float localY = (point.y - centerY) / halfLength;
        const float segmentMask = 1.0f - smoothstep(
            0.82f,
            1.0f + antialiasWidth / halfLength,
            abs(localY));
        if (segmentMask <= 0.0f) {
            continue;
        }

        const float ageProgress = event.lifetime <= 1
            ? 0.0f
            : float(event.age) / float(event.lifetime - 1);
        const float phase = randomUnit(lane, event.cycle, 5, stream) * kTau;
        const float slope = (
            randomUnit(lane, event.cycle, 6, stream) - 0.5f) *
            bandSize * 0.24f;
        const float primaryCurve =
            sin((localY * 0.72f + 0.48f) * 3.14159265359f + phase) *
            unitClamp(uniforms.fiber0.y) * bandSize * 0.25f;
        const float organicWiggle =
            sin(localY * 7.1f + phase * 1.73f + ageProgress * 0.55f) *
            unitClamp(uniforms.fiber0.z) * bandSize * 0.105f +
            sin(localY * 15.7f - phase * 0.43f) *
            unitClamp(uniforms.fiber0.z) * bandSize * 0.028f;
        const float centerX = baseX + localY * slope + primaryCurve + organicWiggle;
        const float baseWidth = antialiasWidth * 0.16f +
            rangeValue(
                uniforms.fiber1.zw,
                randomUnit(lane, event.cycle, 7, stream)) *
                shortAxis * 0.0048f * materialScale(uniforms);
        const float widthTexture = valueNoise1D(
            point.y / max(antialiasWidth * 4.0f, baseWidth * 5.0f),
            lane,
            event.cycle,
            stream ^ 0x9e3779b9u);
        const float localWidth = max(
            antialiasWidth * 0.14f,
            baseWidth * mix(0.66f, 1.24f, widthTexture));
        const float lineMask = 1.0f - smoothstep(
            max(0.0f, localWidth - antialiasWidth * 0.72f),
            localWidth + antialiasWidth * 0.88f,
            abs(point.x - centerX));
        if (lineMask <= 0.0f) {
            continue;
        }

        const float opacity = rangeValue(
            uniforms.fiber2.xy,
            randomUnit(lane, event.cycle, 8, stream));
        const float materialTexture = mix(0.62f, 1.0f, widthTexture);
        const float sign = polaritySign(
            uniforms.polarities.z,
            lane,
            event.cycle,
            stream);
        signedMask = clamp(
            signedMask +
                lineMask * segmentMask * materialTexture * opacity * event.fade *
                globalGain(uniforms) * sign,
            -1.0f,
            1.0f);
    }
    return signedMask;
}

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
    const float wearWidth = max(
        antialiasWidth,
        shortAxis * (0.006f + unitClamp(uniforms.gate0.y) * 0.048f) * gateScale);
    const float leftDistance = max(0.0f, point.x);
    const float rightDistance = max(0.0f, size.x - point.x);
    const bool left = leftDistance <= rightDistance;
    const float edgeDistance = left ? leftDistance : rightDistance;
    const float edgeMask = 1.0f - smoothstep(
        wearWidth * mix(0.16f, 0.38f, unitClamp(uniforms.gate0.w)),
        wearWidth * (0.92f + unitClamp(uniforms.gate0.w) * 0.80f),
        edgeDistance);
    if (edgeMask <= 0.0f) {
        return 0.0f;
    }

    const int side = left ? 0 : 1;
    const int frameIndex = as_type<int>(uniforms.temporal.x);
    const float epochLength = max(
        2.0f,
        max(1.0f, uniforms.global1.y) *
            mix(2.4f, 0.85f, unitClamp(uniforms.gate1.x)));
    const float epochCoordinate = float(frameIndex) / epochLength;
    const int epoch = int(floor(epochCoordinate));
    const float epochBlend = smoothUnit(epochCoordinate - floor(epochCoordinate));
    const float verticalCell = max(
        antialiasWidth * 6.0f,
        shortAxis * mix(0.050f, 0.018f, unitClamp(uniforms.gate1.x)));
    const float patternCoordinate = point.y / verticalCell;
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
        mix(0.62f, 0.72f, unitClamp(uniforms.gate0.w)),
        brokenPattern);
    const float streak = mix(
        0.58f,
        1.0f,
        0.5f + 0.5f * sin(
            point.y / max(antialiasWidth, wearWidth * 0.34f) +
            float(side) * 2.17f +
            brokenPattern * kTau));
    const float sign = polaritySign(
        uniforms.modes.x,
        side,
        int(floor(patternCoordinate)),
        stream);
    return clamp(
        edgeMask * mix(0.34f, 1.0f, breakMask) * streak * amount * opacity *
            globalGain(uniforms) * sign,
        -1.0f,
        1.0f);
}

float3 applyMaterialDamage(
    float3 rgb,
    float signedMask,
    float chromaticity) {
    if (signedMask == 0.0f) {
        return rgb;
    }

    const float magnitude = unitClamp(abs(signedMask));
    const float chroma = unitClamp(chromaticity);
    const float luminance = dot(rgb, float3(0.2126f, 0.7152f, 0.0722f));
    if (signedMask < 0.0f) {
        const float3 neutralMaterial = luminance * float3(
            0.18f + chroma * 0.025f,
            0.18f,
            0.18f - chroma * 0.018f);
        return mix(rgb, neutralMaterial, magnitude * 0.91f);
    }

    // Positive material is intentionally lower gain than dark material. With
    // mixed polarity it is also selected rarely by polaritySign().
    const float sparkleLevel = 0.38f + abs(luminance) * 0.07f;
    const float3 sparkleTint = float3(
        1.0f + chroma * 0.08f,
        1.0f,
        1.0f - chroma * 0.06f);
    return rgb + sparkleTint * (magnitude * sparkleLevel * 0.42f);
}

kernel void filmtoneFinishFilmDamage(
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

    const float stain = spotFamilyMask(
        uniforms,
        canonicalPoint,
        canonicalSize,
        antialiasWidth,
        true);
    const float gateWear = gateWearMask(
        uniforms,
        canonicalPoint,
        canonicalSize,
        antialiasWidth);
    const float dust = spotFamilyMask(
        uniforms,
        canonicalPoint,
        canonicalSize,
        antialiasWidth,
        false);
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
    rgb = applyMaterialDamage(
        rgb,
        stain,
        max(uniforms.global0.z, uniforms.stain0.z));
    rgb = applyMaterialDamage(rgb, gateWear, uniforms.global0.z);
    rgb = applyMaterialDamage(rgb, dust, uniforms.global0.z);
    rgb = applyMaterialDamage(rgb, fibers, uniforms.global0.z);
    rgb = applyMaterialDamage(rgb, scratches, uniforms.global0.z);

    // RGB is intentionally not clamped. Alpha is copied unchanged from the
    // source pixel for every active and debug path.
    output[outputIndex] = float4(rgb, sourceColor.a);
}
)FILMTONE_METAL";

}  // namespace filmtone::resolve::damage::detail
