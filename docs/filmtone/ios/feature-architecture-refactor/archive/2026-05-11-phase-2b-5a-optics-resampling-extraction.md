# Active — Phase 2B-5A Optics Inventory + Pure Helper Extraction

Date: 2026-05-11 JST
Phase: Phase 2B — ExportSession public-surface split (sub-stage 5A of N)
Milestone: Document the optics state boundary, then extract the
stateless half. `OpticsCompositor` itself (the stateful Metal-vs-CI
orchestrator) is deferred to 2B-5B — splitting the inventory pass from
the orchestrator move keeps the Metal flag mutation contract auditable
before any consumer of those flags is relocated.

## Owner directive

- Metal optics path is **alive but env-gated optional acceleration**
  (`FILMTONE_EXPORT_METAL_OPTICS=1`). It is not dead code; the env flag
  is off unless `FILMTONE_EXPORT_METAL_OPTICS=1` is injected at process
  launch, so production exports take the CI fallback path. The Metal
  branch must remain reachable. 2B-5A documents the state boundary in
  this file; 2B-5B carries Metal flag state intact into
  `OpticsCompositor`.
- 2B-4 owner correction still applies: scope-of-change reports must
  cite exact numbers + scope, never sweeping aggregates
  (`feedback_no_sweeping_diff_claims`).
- No `extension FilmtoneExportSession {}` shell file
  (`feedback_no_extension_only_file_for_god_object_split`). The 5A
  extraction lands as an independent `enum OpticsResampling`
  namespace, same shape as `ExportInputLutBuilder` /
  `ExportSourceProfileResolver` / `ExportDepthPayloadManager`.

## Goal

Two deliverables in one sub-stage:

1. **Optics state-boundary inventory** — written into the
   "State-boundary inventory" section below. Documents every optics-
   related stored property + its writers / readers / lifetime / Metal
   gate dependency. 5B reads this to size its compositor move.
2. **Pure helper extraction** — move 15 `private static let` constants
   and 14 `private static func` helpers from
   `FilmtoneExportSession.swift` to a new
   `Export/Internal/OpticsResampling.swift` (`enum OpticsResampling`
   namespace). `FilmtoneExportSession` loses 29 type-level
   declarations. 42 `Self.<name>` call sites rewrite to
   `OpticsResampling.<name>`.

This sub-stage moves no instance methods (`applyEdgeOpticsStage`,
`applyGlowFamilyStage`, `applyVignetteStage`, `vignetteFrameParams`,
`extractHighlightPlate`, `applyRadialRGBShift`, `applyEdgeSoftness`,
`buildMipBlurComposite`, `currentBacklightVeilProfile`,
`applyBacklightVeilSpatialOverrides`) and touches none of the Metal
flags — all of that is 5B's job. The 5A move is **purely stateless**.

## State-boundary inventory (Optics surface as of 2B-4)

### Stored properties involved in optics

| Member | Decl line | Kind | Write sites | Read sites | Metal-gated? | 5B owner |
|---|---|---|---|---|---|---|
| `disableGlowFamilyForExport: Bool` | 76 | `private let` | init L207 (env `FILMTONE_EXPORT_DISABLE_GLOW_FAMILY`) | applyGlowFamilyStage L1963/2024, sidecar telemetry L306 | no | OpticsCompositor (input) |
| `useMetalOpticsForExport: Bool` | 81 | `private let` | init L208 (env `FILMTONE_EXPORT_METAL_OPTICS`) | log L244, applyGlowFamilyStage L1962 | yes (the flag itself) | OpticsCompositor (input) |
| `metalOpticsRenderer: FilmtoneMetalOpticsRenderer?` | 82 | `private lazy var` | first read in applyGlowFamilyStage L1967 | applyGlowFamilyStage L1967, L2010 | yes | OpticsCompositor |
| `metalOpticsActiveOnce: Bool` | 87 | `private var` | applyGlowFamilyStage L2015 | sidecar `acceleratedRenderStages` L310 | yes (telemetry) | OpticsCompositor (writer) → ExportSession sidecar reads via accessor |
| `metalVignetteActiveOnce: Bool` | 91 | `private var` | applyGlowFamilyStage L2017 | sidecar L313 | yes (telemetry) | same as above |
| `metalVignetteAppliedThisFrame: Bool` | 95 | `private var` | applyGrade L1665 (reset), applyGlowFamilyStage L2018 | applyVignetteStage L2248 | yes (per-frame flag) | OpticsCompositor (writer + reader inside one frame) |
| `loadedDepthMap: FilmtoneDepthMap?` | 112 | `private var` | exportStillImage path (sets pre-grade); never set for video | applyGlowFamilyStage L1966 (gate), L2041 (CI prefilter) | yes (gate — Metal path requires nil) | stays on ExportSession; OpticsCompositor reads via parameter |
| `request: Phase0ExportRequestDTO` | (class init) | `private let` | init | applyGlowFamilyStage L1964/1965 (sourceKind, renderMode), L2042 (sourceProbe), vignetteFrameParams L2216, applyVignetteStage L2258, currentBacklightVeilProfile L1878 | yes (gate inputs) | stays on ExportSession; OpticsCompositor reads via parameter |

### Metal gate condition (applyGlowFamilyStage L1962-1968)

The Metal acceleration path is entered only when **all six** predicates
hold:

```
useMetalOpticsForExport          // env flag at init
&& !disableGlowFamilyForExport   // separate env flag
&& request.sourceKind == .video  // image exports always take CI path
&& (request.renderMode ?? .quality) == .quality  // Draft/Fast keep CI
&& loadedDepthMap == nil         // depth requires CI prefilter
&& metalOpticsRenderer != nil    // renderer init succeeded
```

If any predicate fails, control falls through to the CI path
(L2024-onwards). Inside the Metal branch, a further internal failure
in `renderer.renderOpticsChain` returns nil and **also** falls through
to CI (L2010-2021). This is the canonical fail-loud → fail-soft seam
(L2010 `if let metalResult = …`); no silent partial Metal output.

### Sidecar surface (read-only consumer of Metal flags)

`writeExportSidecar` accumulates `acceleratedRenderStages` at L309-315:

```swift
var acceleratedRenderStages: [String] = []
if metalOpticsActiveOnce {
    acceleratedRenderStages.append(FilmtoneExportRenderSubstage.glowFamily.rawValue + "/metal")
}
if metalVignetteActiveOnce {
    acceleratedRenderStages.append(FilmtoneExportRenderSubstage.vignette.rawValue + "/metal")
}
```

When 5B moves the compositor, these two `Once` flags become the
compositor's `private(set) var` so the sidecar callsite reads via a
getter rather than direct field. No sidecar V1 schema change.

### Methods on ExportSession that touch optics (deferred to 5B)

| Method | Decl line | Reads | Writes | Move target (5B) |
|---|---|---|---|---|
| `applyEdgeOpticsStage(to:params:)` | 1850 | request.opticalFilterProfileId via callees, OpticsResampling consts | — | OpticsCompositor |
| `applyGlowFamilyStage(to:params:)` | 1954 | all 6 stored props above, OpticalKernels, OpticsResampling consts | metalOpticsActiveOnce, metalVignetteActiveOnce, metalVignetteAppliedThisFrame | OpticsCompositor (the orchestrator) |
| `applyVignetteStage(to:params:)` | 2244 | metalVignetteAppliedThisFrame, request.sourceProbe, OpticalKernels.vignette | — | OpticsCompositor |
| `vignetteFrameParams(image:params:)` | 2209 | request.sourceProbe.cameraOptics | — | OpticsCompositor (helper) |
| `currentBacklightVeilProfile()` | 1875 | request.opticalFilterProfileId | — | OpticsCompositor (helper) |
| `applyBacklightVeilSpatialOverrides(_:spatial:)` | 1911 | (pure data transform, can be static) | — | OpticsCompositor (helper, made static) |
| `extractHighlightPlate(from:threshold:knee:tintColor:)` | 2367 | OpticalKernels.softKneeHighlight | — | OpticsCompositor (helper, made static) |
| `applyRadialRGBShift(_:to:)` | 2385 | OpticalKernels.radialRGBSplit | — | OpticsCompositor (helper, made static) |
| `applyEdgeSoftness(to:aberrationSoften:lensSoftness:)` | 2405 | OpticalKernels.edgeSoftnessBlend | — | OpticsCompositor (helper, made static) |
| `buildMipBlurComposite(from:radius:levelCount:spreadMultiplier:useTentResampling:)` | 2448 | OpticsResampling.* | — | OpticsCompositor (helper, made static) |

None of these moves in 2B-5A. They are listed here so 5B sizing is
explicit.

## Move targets (5A scope only)

### 15 `private static let` constants (Export/FilmtoneExportSession.swift:142-156)

```
aberrationEdgeSoftenScale, aberrationEdgeSoftenMax, aberrationEdgeSoftenCurve,
aberrationBlurRadiusMin, aberrationBlurRadiusMax, aberrationBlurRadiusCap,
lensSoftnessBlurBoost,
glowBaseScale, bloomSpreadBoost, halationSpreadDivisor, diffusionCompositeBase,
bloomMipLevels, halationMipLevels, diffusionMipLevels,
glowUpsampleBlurRadius
```

All values land on `enum OpticsResampling` as `static let` (default
internal). No public API widening; module-internal visibility on these
constants is acceptable because they are physical constants for the
glow/halation/diffusion chain, owned by the resampling/composite math
not the session, and no non-App target consumes them.

### 14 `private static func` helpers

| Function | Decl line | Inputs | Internal deps |
|---|---|---|---|
| `blackImage(for:)` | 2640 | `CGRect` | none |
| `extentOriginVector(for:)` | 2644 | `CGRect` | none |
| `extentSizeVector(for:)` | 2648 | `CGRect` | none |
| `scaledImage(_:scale:)` | 2604 | `CIImage`, `Double` | none |
| `weightedImage(_:weight:)` | 2614 | `CIImage`, `Double` | `blackImage` |
| `addImages(_:_:)` | 2632 | `CIImage` × 2 | none |
| `downsampledImage(_:scale:)` | 2519 | `CIImage`, `Double` | `scaledImage` |
| `upsampledImage(_:to:)` | 2529 | `CIImage`, `CGRect` | `scaledImage`, `blackImage`, `glowUpsampleBlurRadius` |
| `tentDownsampledImage(_:scale:)` | 2548 | `CIImage`, `Double` | `OpticalKernels.tentDownsample`, `downsampledImage`, `extentOriginVector`, `extentSizeVector` |
| `tentUpsampledImage(_:to:)` | 2577 | `CIImage`, `CGRect` | `OpticalKernels.tentUpsample`, `upsampledImage`, `blackImage`, `extentOriginVector`, `extentSizeVector` |
| `buildMipPyramid(from:levelCount:initialScale:useTentResampling:)` | 2489 | `CIImage`, `Int`, `Double`, `Bool` | `downsampledImage`, `tentDownsampledImage` |
| `computeMipWeights(radius:levels:)` | 2652 | `Double`, `Int` | `Foundation.exp` |
| `halationColor(for:)` | 2661 | `Double` | **`clamp`** (5A scope-out — see "Internal `clamp` duplication") |
| `aberrationEdgeSoften(for:)` | 2669 | `Double` | `aberrationEdgeSoftenScale/Max/Curve`, `FilmtonePhase0Generated.rgbShiftMax`, **`clamp`** |

All become `static func` on `OpticsResampling` (no rename, no signature
change). Bodies move verbatim except `Self.<helper>` → `Self.<helper>`
resolves correctly inside the new namespace because the callee also
moves.

### Internal `clamp` duplication

`halationColor` and `aberrationEdgeSoften` reference bare `clamp` (Swift
resolves to `FilmtoneExportSession.clamp` static at L2689). 5A does
**not** move `clamp` because it is used at 30+ other sites across the
ExportSession class body and moving it would expand scope into
non-optics call sites. Instead `OpticsResampling` carries a private
duplicate:

```swift
private static func clamp(
    _ value: Double,
    min minValue: Double = 0,
    max maxValue: Double = 1
) -> Double {
    Swift.min(Swift.max(value, minValue), maxValue)
}
```

Identical body to `FilmtoneExportSession.clamp` (L2689-2691). Pure
2-arg fallback semantics, byte-identical numeric output. Deduplication
into a shared math namespace is a separate concern — out of scope here.

`lerp` (L2693) is **not** referenced by any 5A move target (audited
via grep). Stays on ExportSession.

## Call-site rewrite (5A scope)

42 `Self.<name>` references in `FilmtoneExportSession.swift` need to
become `OpticsResampling.<name>`. Listed by line for verification:

- L1860 (aberrationEdgeSoften) × 1
- L1985, L1992, L1994, L1996 (mipLevels family) × 3 (bloom/halation/diffusion)
- L1986 (bloomSpreadBoost) × 1
- L1994 (halationSpreadDivisor) × 1
- L1997 (diffusionCompositeBase) × 1
- L1998 (glowBaseScale) × 1
- L2029 (blackImage) × 1
- L2075-2076 (bloomMipLevels, bloomSpreadBoost) × 2
- L2107 (halationColor) × 1
- L2112-2113 (halationMipLevels, halationSpreadDivisor) × 2
- L2143 (diffusionMipLevels) × 1
- L2201 (diffusionCompositeBase) × 1
- L2281-2282 (extentOriginVector, extentSizeVector) × 2
- L2310-2311 (extentOriginVector, extentSizeVector) × 2
- L2374, L2382 (blackImage) × 2
- L2399-2400 (extentOriginVector, extentSizeVector) × 2
- L2412 (aberrationEdgeSoftenMax) × 1
- L2417-2418 (aberrationBlurRadiusMin/Max) × 2
- L2420 (lensSoftnessBlurBoost) × 1
- L2421 (aberrationBlurRadiusCap) × 1
- L2442-2443 (extentOriginVector, extentSizeVector) × 2
- L2457, L2467 (blackImage) × 2
- L2460, L2463 (buildMipPyramid, glowBaseScale) × 2
- L2470 (computeMipWeights) × 1
- L2476-2479 (tentUpsampledImage, upsampledImage, weightedImage, addImages) × 4
- L2484-2485 (tentUpsampledImage, upsampledImage) × 2

Total: **42 site rewrites**, all mechanical token-level. None changes
semantics.

`Self.clamp(...)` at L2412 stays as `Self.clamp(...)` — clamp does
not move in 5A.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  (delete 15 constants L142-156 + 14 static funcs L2489-2678; rewrite
  42 `Self.<name>` call sites; no instance-state or modifier changes)
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsResampling.swift`
  (new — `enum OpticsResampling` containing the 15 constants + 14
  static functions + 1 internal `clamp` duplicate)
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  (4-section registration × 1 new file)
- `docs/filmtone/ios/feature-architecture-refactor/active.md` (this file)

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md` (commit gate; §3 4-section grep)
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md` Phase 2B
  milestone — 5A is preparation for the OpticsCompositor target listed
  there.
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-2-source-profile-input-lut-helpers-extraction.md`
  (precedent for the `enum X` namespace pattern; same `Self.<helper>`
  → `<Namespace>.<helper>` rewrite shape)
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
  (read-only collaborator — `tentDownsample` / `tentUpsample` referenced
  by the moved static funcs)

## Anti-pattern boundaries

- **Do not move** `clamp` or `lerp` in 5A. They have >30 ExportSession
  call sites outside optics and moving them expands the rewrite scope
  into non-optics methods.
- **Do not move** any of the 10 instance methods listed in the
  "Methods on ExportSession that touch optics" table. Those are 5B.
- **Do not touch** any Metal flag (`useMetalOpticsForExport`,
  `metalOpticsRenderer`, `metalOpticsActiveOnce`,
  `metalVignetteActiveOnce`, `metalVignetteAppliedThisFrame`,
  `loadedDepthMap`) — these are 5B's contract. The 5A move is
  stateless by design.
- **Do not rename** any moved declaration. Mechanical token rewrite
  only.
- **Do not dedupe** `clamp` across the codebase here. The 4-line
  duplicate inside `OpticsResampling` is intentional 5A scope.

## Checklist

- [x] Confirmed cross-file consumer scan: `grep -nE 'Self\.(blackImage|extent(Origin|Size)Vector|computeMipWeights|halationColor|aberrationEdgeSoften|buildMipPyramid|downsampledImage|upsampledImage|tentDownsampledImage|tentUpsampledImage|scaledImage|weightedImage|addImages|aberrationEdgeSoftenScale|aberrationEdgeSoftenMax|aberrationEdgeSoftenCurve|aberrationBlurRadiusMin|aberrationBlurRadiusMax|aberrationBlurRadiusCap|lensSoftnessBlurBoost|glowBaseScale|bloomSpreadBoost|halationSpreadDivisor|diffusionCompositeBase|bloomMipLevels|halationMipLevels|diffusionMipLevels|glowUpsampleBlurRadius)' apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift | wc -l` == 42 pre-move, and the post-move `OpticsResampling.<name>` count matches 42.
- [x] Confirmed no external file references these helpers: `grep -rnE 'FilmtoneExportSession\.(blackImage|aberrationEdgeSoften|computeMipWeights|halationColor|buildMipPyramid|down|upsampledImage|tent|scaledImage|weightedImage|addImages)' apps/capacitor-film-lab-ios/ios/App/App/` returned 0 hits.
- [x] Created `Export/Internal/OpticsResampling.swift` with the 15
  constants + 14 static funcs + 1 private `clamp` duplicate. Imports:
  `CoreGraphics` (for `CGRect` / `CGSize`), `CoreImage`, `FilmLabSwiftCore`
  (for `FilmtonePhase0Generated.rgbShiftMax`, required by
  `aberrationEdgeSoften`), `Foundation` (for `exp`).
- [x] Deleted the 15 constants (L142-156) and the 14 static funcs from
  `FilmtoneExportSession.swift`. Deletion was **contiguous** for the
  funcs (originally L2489-2678) and **contiguous** for the constants.
- [x] Rewrote the 42 `Self.<name>` call sites via perl (BSD sed `\b`
  word-boundary fallback not supported); each token (e.g.
  `Self.blackImage` → `OpticsResampling.blackImage`) matched exactly
  once per occurrence with no false positives.
- [x] Registered the new file in `project.pbxproj` (4 sections,
  IDs `B1E10001000000000000B207` / `B1E10001000000000000B208`).
- [x] `grep -c 'OpticsResampling.swift' project.pbxproj` == 4.
- [x] `bun run verify:ios` — PASS.
- [x] `git diff --check` — PASS.

## Verification gates

- pbxproj 4-section registration verified for `OpticsResampling.swift`
- `bun run verify:ios` green (same gate chain as 2B-1/2B-2/2B-3/2B-4
  including all source-profile math accuracy gates, motion blur math,
  look × veil energy merge, sidecar builder)
- `git diff --check` clean (whitespace)
- `git diff --stat` shows roughly: `−ish 200` in
  `FilmtoneExportSession.swift` (15 constants × 1 line + 14 functions
  × avg 12 lines = ~185, plus 42 Self.* rewrites = 0 net line delta on
  those, plus blank-line cleanup) and `+ish 250` in
  `OpticsResampling.swift` (29 decls + namespace shell + internal
  `clamp` duplicate + import header)
- App target `PBXSourcesBuildPhase` file count changes by exactly +1
- ExportActivity target `PBXSourcesBuildPhase` file count unchanged
- No behavior-bearing external Swift diffs; one mirror-pointer comment
  in `Optics/FilmtoneMetalOpticsRenderer.swift:832` updated
  (`Mirrors FilmtoneExportSession.halationColor` →
  `Mirrors OpticsResampling.halationColor`) so the pointer doesn't
  dangle. Flagged in Unexpected/Follow-up per
  `feedback_no_sweeping_diff_claims`.

## Done Conditions

- `FilmtoneExportSession.swift` no longer declares any of the 15
  `private static let` constants listed in "Move targets" or any of
  the 14 `private static func` helpers listed there.
- `Export/Internal/OpticsResampling.swift` owns them as `static let`
  / `static func` on `enum OpticsResampling`.
- All 42 call sites compile against `OpticsResampling.<name>`.
- Metal flag stored properties (`useMetalOpticsForExport`,
  `metalOpticsRenderer`, `metalOpticsActiveOnce`,
  `metalVignetteActiveOnce`, `metalVignetteAppliedThisFrame`) and
  their writers / readers are **untouched** in this sub-stage.
- All gates green.
- Sidecar field order, kernel chain order, vignette / mip pyramid
  numeric output unchanged by verbatim move (function bodies copied
  byte-for-byte; only `Self.` resolution scope shifts); `bun run
  verify:ios` covers build and existing math / contract gates.

## Stop Conditions

- Stop if any rewritten call site changes signature, argument order,
  or argument count.
- Stop if any moved function's body needs an edit beyond removing
  `private` (becoming default internal in the new enum). The 5A move
  is verbatim.
- Stop if Swift complains about `clamp` ambiguity after the move —
  that means the audit missed a moved-target callee that needs the
  duplicate.
- Stop if `verify:ios` math accuracy gates regress in any source-profile
  / motion-blur / sidecar / look-veil-merge accuracy run.
- Stop after 3 consecutive build/verification failures.

## Out Of Scope

- Moving `clamp`, `lerp`, `makeStableSourceSeed`, or any other static
  helper not listed in "Move targets".
- Moving any of the 10 optics-touching instance methods (those are
  5B).
- Renaming any moved declaration.
- Editing `OpticalKernels` (kernel strings are 2B-4-frozen).
- Touching Metal flag state machine.
- Sidecar V1 schema, sidecar serialization order.
- Editor / Capture / Source / Look files.

## Unexpected / Follow-up

- 2026-05-11 JST — One additional external `.swift` file was edited
  beyond the planned scope: `Optics/FilmtoneMetalOpticsRenderer.swift`
  line 832, the mirror-pointer comment `// Mirrors
  FilmtoneExportSession.halationColor.` → `// Mirrors
  OpticsResampling.halationColor.`. The renderer's
  `halationColor(forHue:)` is a hand-rewritten SIMD3<Float> version of
  the moved CIColor helper kept here for the Metal compute path;
  leaving the stale pointer would dangle to a symbol that no longer
  exists on `FilmtoneExportSession`. The active.md plan said "No
  external `.swift` file diffs" — strictly this is a 1-line text-only
  delta with no code-behavior change, but flagging it explicitly per
  `feedback_no_sweeping_diff_claims`.
- 2026-05-11 JST — Verification gate summary: `bun run verify:ios`
  exit 0; all math accuracy gates (motion blur, cube parser, capture
  transform LUT classifier, cache store, source-color classifier,
  ray-angle optics, D-Log / D-Log M / C-Log / C-Log 3 / V-Log /
  S-Log3 Macbeth ΔE2000 / full-frame, look × veil energy merge,
  sidecar builder) green; `git diff --check` exit 0; pbxproj
  `OpticsResampling.swift` 4-section grep = 4; `Self.<name>` rewrite
  count = 42 (matches plan); `Self.clamp` (10 sites) / `Self.lerp`
  (1 site) / `Self.makeStableSourceSeed` (1 site) preserved as
  scope-out per plan.
- 2026-05-11 JST — `FilmtoneExportSession.swift` 3189 → 2984 lines
  (−205); `OpticsResampling.swift` = 234 lines (15 constants + 14
  static funcs + 1 private `clamp` duplicate + 4-line module header
  + doc comments). Metal flag stored properties
  (`useMetalOpticsForExport` / `metalOpticsRenderer` /
  `metalOpticsActiveOnce` / `metalVignetteActiveOnce` /
  `metalVignetteAppliedThisFrame` / `loadedDepthMap`) untouched per
  5A scope; deferred to 5B's `OpticsCompositor` extraction.
