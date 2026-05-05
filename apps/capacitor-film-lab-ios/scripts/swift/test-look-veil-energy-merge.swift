import Foundation

// Look × Backlight Veil energy max-merge contract test (iOS port, 2026-05-06).
//
// Mirrors macOS `FilmtonePresetCatalog.applyVeilPatch`
// (apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePresetCatalog.swift)
// and exercises the iOS canonical at
// `FilmtoneExportSession.applyBacklightVeilSpatialOverrides`.
//
// Bug being guarded: Veil profile patches are authored against the reset
// baseline. Stone / Urban Looks raise `lensSoftness` (0.095) and `rgbShift`
// (Stone 0.0032, Urban 0.0028) above Veil 1/8 (0.06 / 0.0005), Veil 1/4
// (0.08 / 0.0007), Veil 1/2 (0.10 / 0.0009). Pre-fix iOS absolute-overwrite
// dropped Stone's higher values to Veil's lower ones, perceptually weakening
// the Veil ("more Veil → less softness, less color fringing"). Post-fix:
//   * Energy keys (5):   max(base, veil)
//   * Structural keys (7): absolute overwrite — Veil's spatial shape wins
//
// The contract is duplicated here from production code so the test runs
// without compiling FilmtoneExportSession.swift's full dependency closure.
// If the production merge math drifts, update both sites.

struct MergeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw MergeError(message: message)
    }
}

func approxEq(_ a: Double, _ b: Double, eps: Double = 1e-9) -> Bool {
    abs(a - b) < eps
}

// MARK: - Minimal mirrors of production types

/// Subset of `Phase0ParamsDTO` covering the 12 spatial keys touched by Veil.
/// Other fields are immaterial to this contract test.
struct SpatialParams: Equatable {
    var bloomThreshold: Double
    var bloomStrength: Double
    var bloomRadius: Double
    var bloomSoftKnee: Double
    var diffusion: Double
    var halationIntensity: Double
    var halationThreshold: Double
    var halationRadius: Double
    var halationHue: Double
    var halationSoftKnee: Double
    var lensSoftness: Double
    var rgbShift: Double
}

/// Mirrors `FilmtoneOpticalFiltersGenerated.SpatialKeys`.
struct VeilSpatial {
    let bloomThreshold: Double
    let bloomStrength: Double
    let bloomRadius: Double
    let bloomSoftKnee: Double
    let diffusion: Double
    let halationIntensity: Double
    let halationThreshold: Double
    let halationRadius: Double
    let halationHue: Double
    let halationSoftKnee: Double
    let lensSoftness: Double
    let rgbShift: Double
}

// MARK: - Production constants (must stay in sync)

/// Reset baseline for the spatial keys, derived from
/// `FilmtonePhase0Params.reset`. Color-grade keys are zeroed for this test.
let resetBaseline = SpatialParams(
    bloomThreshold: 0.7,
    bloomStrength: 0.0,
    bloomRadius: 0.5,
    bloomSoftKnee: 0.5,
    diffusion: 0.0,
    halationIntensity: 0.0,
    halationThreshold: 0.6,
    halationRadius: 0.5,
    halationHue: 0.0,
    halationSoftKnee: 0.5,
    lensSoftness: 0.0,
    rgbShift: 0.0
)

/// Stone Look patch values — synced with
/// `FilmtoneBuiltInCatalog.creativePack01StonePatch`. Only spatial keys are
/// listed; missing keys = reset.
func applyStone(_ b: SpatialParams) -> SpatialParams {
    var p = b
    p.rgbShift = 0.0032
    p.bloomThreshold = 0.64
    p.bloomStrength = 0.20
    p.bloomRadius = 0.62
    p.halationIntensity = 0.07
    p.halationHue = 24
    p.diffusion = 0.06
    p.lensSoftness = 0.095
    return p
}

/// Urban Look patch values — synced with
/// `FilmtoneBuiltInCatalog.creativePack01UrbanPatch`.
func applyUrban(_ b: SpatialParams) -> SpatialParams {
    var p = b
    p.rgbShift = 0.0028
    p.bloomThreshold = 0.66
    p.bloomStrength = 0.18
    p.bloomRadius = 0.58
    p.halationIntensity = 0.055
    p.halationHue = 20
    p.diffusion = 0.065
    p.lensSoftness = 0.095
    return p
}

/// Veil 1/4 spatial — synced with
/// `FilmtoneOpticalFiltersGenerated.backlightVeilProfiles[1].spatial`.
let veil14 = VeilSpatial(
    bloomThreshold: 0.56,
    bloomStrength: 0.38,
    bloomRadius: 0.8,
    bloomSoftKnee: 0.76,
    diffusion: 0.24,
    halationIntensity: 0.14,
    halationThreshold: 0.52,
    halationRadius: 0.62,
    halationHue: 22.0,
    halationSoftKnee: 0.56,
    lensSoftness: 0.08,
    rgbShift: 0.0007
)

/// Veil 1/2 spatial.
let veil12 = VeilSpatial(
    bloomThreshold: 0.5,
    bloomStrength: 0.6,
    bloomRadius: 0.88,
    bloomSoftKnee: 0.82,
    diffusion: 0.38,
    halationIntensity: 0.22,
    halationThreshold: 0.46,
    halationRadius: 0.74,
    halationHue: 22.0,
    halationSoftKnee: 0.64,
    lensSoftness: 0.1,
    rgbShift: 0.0009
)

/// Veil 1/8 spatial.
let veil18 = VeilSpatial(
    bloomThreshold: 0.66,
    bloomStrength: 0.2,
    bloomRadius: 0.7,
    bloomSoftKnee: 0.7,
    diffusion: 0.12,
    halationIntensity: 0.07,
    halationThreshold: 0.58,
    halationRadius: 0.52,
    halationHue: 22.0,
    halationSoftKnee: 0.48,
    lensSoftness: 0.06,
    rgbShift: 0.0005
)

// MARK: - Merge function (contract; mirror of production)

/// Mirrors `FilmtoneExportSession.applyBacklightVeilSpatialOverrides` post-fix
/// (commit fix/ios-look-veil-energy-max-merge, 2026-05-06).
func mergeVeil(_ p: SpatialParams, _ s: VeilSpatial) -> SpatialParams {
    SpatialParams(
        // Structural — absolute overwrite (Veil shape wins)
        bloomThreshold: s.bloomThreshold,
        // Energy — max-merge (Look's higher baseline preserved)
        bloomStrength: max(p.bloomStrength, s.bloomStrength),
        bloomRadius: s.bloomRadius,
        bloomSoftKnee: s.bloomSoftKnee,
        diffusion: max(p.diffusion, s.diffusion),
        halationIntensity: max(p.halationIntensity, s.halationIntensity),
        halationThreshold: s.halationThreshold,
        halationRadius: s.halationRadius,
        halationHue: s.halationHue,
        halationSoftKnee: s.halationSoftKnee,
        lensSoftness: max(p.lensSoftness, s.lensSoftness),
        rgbShift: max(p.rgbShift, s.rgbShift)
    )
}

// MARK: - Tests

func runStoneVeil14LensSoftnessFloor() throws {
    let stone = applyStone(resetBaseline)
    let merged = mergeVeil(stone, veil14)
    try expect(
        approxEq(merged.lensSoftness, 0.095),
        "Stone+Veil1/4 lensSoftness regressed (got \(merged.lensSoftness), expected 0.095)"
    )
}

func runStoneVeil14RgbShiftFloor() throws {
    let stone = applyStone(resetBaseline)
    let merged = mergeVeil(stone, veil14)
    try expect(
        approxEq(merged.rgbShift, 0.0032),
        "Stone+Veil1/4 rgbShift regressed (got \(merged.rgbShift), expected 0.0032)"
    )
}

func runStoneVeil14BloomStrengthRises() throws {
    let stone = applyStone(resetBaseline)
    let merged = mergeVeil(stone, veil14)
    try expect(
        approxEq(merged.bloomStrength, 0.38),
        "Stone+Veil1/4 bloomStrength should rise to 0.38 (got \(merged.bloomStrength))"
    )
}

func runStoneVeil14StructuralOverwrite() throws {
    let stone = applyStone(resetBaseline)
    let merged = mergeVeil(stone, veil14)
    try expect(
        approxEq(merged.bloomThreshold, 0.56),
        "Stone+Veil1/4 bloomThreshold should be Veil's 0.56 (got \(merged.bloomThreshold))"
    )
    try expect(
        approxEq(merged.bloomRadius, 0.8),
        "Stone+Veil1/4 bloomRadius should be Veil's 0.80 (got \(merged.bloomRadius))"
    )
}

func runStoneVeil12LensSoftnessRises() throws {
    let stone = applyStone(resetBaseline)
    let merged = mergeVeil(stone, veil12)
    try expect(
        approxEq(merged.lensSoftness, 0.10),
        "Stone+Veil1/2 lensSoftness should be 0.10 (got \(merged.lensSoftness))"
    )
}

func runStoneVeil18LensSoftnessFloor() throws {
    let stone = applyStone(resetBaseline)
    let merged = mergeVeil(stone, veil18)
    try expect(
        approxEq(merged.lensSoftness, 0.095),
        "Stone+Veil1/8 lensSoftness should stay at Stone's 0.095 (got \(merged.lensSoftness))"
    )
}

func runUrbanVeil14Floors() throws {
    let urban = applyUrban(resetBaseline)
    let merged = mergeVeil(urban, veil14)
    try expect(
        approxEq(merged.lensSoftness, 0.095),
        "Urban+Veil1/4 lensSoftness regressed (got \(merged.lensSoftness))"
    )
    try expect(
        approxEq(merged.rgbShift, 0.0028),
        "Urban+Veil1/4 rgbShift regressed (got \(merged.rgbShift))"
    )
}

func runResetVeil14EqualsVeilDirect() throws {
    let merged = mergeVeil(resetBaseline, veil14)
    try expect(
        approxEq(merged.lensSoftness, 0.08),
        "Reset+Veil1/4 lensSoftness should be Veil's 0.08 (got \(merged.lensSoftness))"
    )
    try expect(
        approxEq(merged.rgbShift, 0.0007),
        "Reset+Veil1/4 rgbShift should be Veil's 0.0007 (got \(merged.rgbShift))"
    )
    try expect(
        approxEq(merged.bloomStrength, 0.38),
        "Reset+Veil1/4 bloomStrength should be Veil's 0.38 (got \(merged.bloomStrength))"
    )
    try expect(
        approxEq(merged.bloomThreshold, 0.56),
        "Reset+Veil1/4 bloomThreshold should be Veil's 0.56 (got \(merged.bloomThreshold))"
    )
}

func runDensityMonotonicityEnergyKeys() throws {
    let stone = applyStone(resetBaseline)
    let m18 = mergeVeil(stone, veil18)
    let m14 = mergeVeil(stone, veil14)
    let m12 = mergeVeil(stone, veil12)
    try expect(
        m18.bloomStrength <= m14.bloomStrength + 1e-9
        && m14.bloomStrength <= m12.bloomStrength + 1e-9,
        "bloomStrength density monotonicity broken: \(m18.bloomStrength), \(m14.bloomStrength), \(m12.bloomStrength)"
    )
    try expect(
        m18.halationIntensity <= m14.halationIntensity + 1e-9
        && m14.halationIntensity <= m12.halationIntensity + 1e-9,
        "halationIntensity density monotonicity broken: \(m18.halationIntensity), \(m14.halationIntensity), \(m12.halationIntensity)"
    )
    try expect(
        m18.diffusion <= m14.diffusion + 1e-9
        && m14.diffusion <= m12.diffusion + 1e-9,
        "diffusion density monotonicity broken: \(m18.diffusion), \(m14.diffusion), \(m12.diffusion)"
    )
}

func runStructuralKeysOverwriteByDensity() throws {
    let stone = applyStone(resetBaseline)
    let m18 = mergeVeil(stone, veil18)
    let m14 = mergeVeil(stone, veil14)
    let m12 = mergeVeil(stone, veil12)
    try expect(
        approxEq(m18.bloomThreshold, 0.66)
        && approxEq(m14.bloomThreshold, 0.56)
        && approxEq(m12.bloomThreshold, 0.5),
        "bloomThreshold should mirror Veil density (got \(m18.bloomThreshold), \(m14.bloomThreshold), \(m12.bloomThreshold))"
    )
}

// MARK: - Entry point

do {
    try runStoneVeil14LensSoftnessFloor()
    try runStoneVeil14RgbShiftFloor()
    try runStoneVeil14BloomStrengthRises()
    try runStoneVeil14StructuralOverwrite()
    try runStoneVeil12LensSoftnessRises()
    try runStoneVeil18LensSoftnessFloor()
    try runUrbanVeil14Floors()
    try runResetVeil14EqualsVeilDirect()
    try runDensityMonotonicityEnergyKeys()
    try runStructuralKeysOverwriteByDensity()
    print("[look-veil-energy-merge] all checks pass (10 tests)")
} catch let error as MergeError {
    print("FAIL: \(error.message)")
    exit(1)
} catch {
    print("FAIL: unexpected error: \(error)")
    exit(1)
}
