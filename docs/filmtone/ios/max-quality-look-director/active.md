# M1 - Max Quality Look Director Pilot

Opened: 2026-05-13 JST
Lane: iOS Max Quality Look Director
Branch: `feature/ios-max-quality-look-director`
Worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-ios-max-quality-look-director`

## Status

**AI-executable scope**: Complete. Implementation at `27a14e30` carries the
Look Director resolver, the source-aware wiring into `applyCameraProfile` /
`applyProbe`, the `fade`-not-`shadowTone` shadow-latitude correction, the
1px-edge Laplacian guard, six resolver test cases, and the `bun run verify:ios`
+ `git diff --check` gates green on 2026-05-13 JST.

**Final Owner Gate**: Pending. Three-source on-device visual/performance check
(see the same-named section below) requires physical iPhone hardware and
owner-owned footage; visual delta judgement and device thermal / sidecar timing
fall outside the AI-executable scope. M1 closeout in this lane resumes when the
owner pastes back the measured table.

## Goal

Implement the first batched iOS pilot that materially raises built-in Look image
quality through source-aware decisions, while keeping verification intentionally
small. This active should produce a shippable-quality direction or a concrete
measured reason to route follow-up tuning/performance work to M2/M3.

## Product Posture

Maximum image quality is the primary objective. Do not avoid optical/detail
changes just because they cost more than color-only changes. Instead, make the
cost visible through existing profiler/sidecar metrics and keep preview/export
behavior tiered.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaTypes.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Source/SourceProbeService.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneBuiltInCatalog.swift`
- Potential new Swift file:
  `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneLookDirector.swift`
- If a new Swift file is added:
  `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- Focused Swift script test under
  `apps/capacitor-film-lab-ios/scripts/swift/`
- This lane doc, for checklist and verification updates only.

## Read-Only References

- `AGENTS.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `docs/filmtone/ios/README.md`
- `docs/filmtone/detail-softness/strategy.md`
- `apps/capacitor-film-lab-ios/docs/builtin-catalog.md`
- Existing editor apply paths:
  `FilmtoneEditorStore`, `EditorProjectMutationCoordinator`,
  `EditorCaptureRelay`
- Existing performance/profiler code:
  `FilmtoneExportSession`, `ExportMetrics`, `OpticsCompositor`

## Implementation Checklist

- [x] Create dedicated worktree from latest `origin/main`.
- [x] Create lane placement under
      `docs/filmtone/ios/max-quality-look-director/`.
- [x] Fix `sourceDetailBias` resolution so explicit built-in
      `CameraProfileSelection` contributes the matching `sourceProfileId`.
      (`FilmtoneExportSession.resolveSourceDetailBias(from:cameraProfile:)`
      now threads `cameraProfile.builtIn.catalogId` into the
      `FilmtoneSourceDetailCompensationInput.sourceProfileId` slot.)
- [x] Strengthen source tone analysis without per-frame render cost:
      - images: same thumbnail, but now also computes a 4-neighbor
        Laplacian and warm/saturated highlight ratios;
      - videos: sample at 20% / 50% / 80% (max 3 frames) and merge with
        percentile averaging plus max-merging coverage/score signals;
      - derived compact scores: `nightPracticalScore`, `highKeyScore`,
        `lowSaturationFlatScore`, `digitalHardnessScore` — all optional
        on `FilmtoneSourceToneDescriptor`.
- [x] Descriptor shape: backward-compatible optional fields on
      `FilmtoneSourceToneDescriptor` (no schema bump). Codable uses
      `decodeIfPresent` so legacy sidecars / saved looks load unchanged.
      Type moved to its own file `Source/FilmtoneSourceToneDescriptor.swift`
      so the focused test can link it without UIKit dependencies.
- [x] Implement Look Director resolution for current Creative Pack 01
      built-ins. (`Look/FilmtoneLookDirector.swift` +
      `Look/FilmtoneCreativePack01Adaptation.swift`.) Per-Look weights:
      Stone is the flagship at full scale, Urban at 0.7x, Noir at 0.55x
      with optics restraint because the bundled cube already carries
      heavy print structure.
- [x] Make the resolver intentionally high-impact:
      - `creativeLut.intensity` lifted up to 1.0 on Log/flat material,
        pulled back to ≥0.82 on night-practical to protect saturated
        signage;
      - `compressionAmount` / `compressionRange` adjusted on high-key
        and flat material;
      - `fade` (shadow-only toe-lift, the actual latitude handle) raised
        on shadow-heavy frames, capped at 0.10 so it never reads matte.
        The earlier draft wrote `shadowTone`, but `shadowTone` in
        baseGradeV2 is the density-dependent split-tone chroma direction
        (multiplies `shadowChroma` from `shadowHue`), not a latitude
        knob — using it would tip shadow color cast instead of giving
        the toe headroom;
      - `detailSoftness` added on digital-hardness source, then pulled
        back proportionally to `sourceDetailBias` so the export-stage
        bias is not double-applied;
      - `bloomStrength` / `bloomThreshold` / `halationIntensity` /
        `diffusion` raised over the catalog baseline for night
        material (Noir holds steady);
      - `vignette` deepens only on shadow-heavy frames on Stone /
        Urban; Noir's deep catalog vignette is preserved.
- [x] Preserve existing built-in apply surfaces so editor, saved-look
      apply, and capture relay resolve the same adaptation. All three
      now pass `sourceProfileId` + `sourceDetailBias` via
      `FilmtoneLookDirector.sourceProfileId(for:)` and
      `FilmtoneLookDirector.resolveSourceDetailBias(probe:cameraProfile:)`
      so they pick the same profile as the export pipeline.
- [x] Re-resolve adaptation when source / Camera Profile changes after
      the Look is already applied. The first draft baked adaptation at
      apply-time and never re-derived, so swapping clips or changing
      profile left a stale overlay. `FilmtoneEditorStore.refreshCreative`
      `Pack01AdaptationIfApplicable()` recomputes overlay + intensity
      from the current `probe.sourceToneDescriptor` /
      `sourceProfileId` / `sourceDetailBias`, restores catalog baseline
      on dropped overlay keys (no lingering values from a prior source),
      and is wired into both `applyCameraProfile` and `applyProbe`.
      Trade-off: user tweaks on overlay keys
      (`fade` / `compressionAmount` / `detailSoftness` / bloom / halation
      / diffusion / vignette) are overwritten on source/profile change —
      consistent with the M1 thesis that the Look is supposed to respond
      to the new source.
- [x] Guard the source-probe 4-neighbor Laplacian on
      `width > 2 && height > 2`. The first draft would trap with an
      invalid `1..<(n - 1)` range on 1px-edge images; the gate keeps the
      Laplacian a no-op for degenerate thumbnails and the descriptor
      still emits its base luma / saturation signals.
- [x] Add focused resolver tests covering five cases:
      night/practical light, bright/high-key, low-saturation, Log/profile
      material, and ordinary material. Plus a sixth `runLegacyDescriptorCase`
      that verifies the resolver still works when optional scores are nil.
- [x] Run minimum automated verification:
      - `bash apps/capacitor-film-lab-ios/scripts/swift/test-look-director.swift`
        is invoked via `verify-phase0-contract.sh` step
        `==> look director resolver test`. Reports `Look Director
        resolver tests passed`.
      - `bun run verify:ios` exit 0 (Phase 0 contract + iOS xcodebuild
        on Debug for `arm64-apple-ios26.0-simulator`).
      - `git diff --check` exit 0.
- [x] Prepare the three-source visual/performance check protocol for the
      owner. The on-device export run itself is the **Final Owner Gate**
      below — physical iPhone hardware + owner-owned footage + visual
      delta judgement cannot run inside the AI-executable scope, so it
      is split out as a final-stage gate rather than an
      AI-blocking implementation task.
- [x] Record Copy / History Impact and Article / Change-History Opportunity
      after the actual visual delta is known. (Recorded below; final
      Article Opportunity classification waits on the three-source
      visual run.)

## Verification

Run on 2026-05-13 JST in the dedicated worktree (head `27a14e30`,
`feature/ios-max-quality-look-director`, 1 commit ahead of `origin/main`,
worktree clean).

Re-verified after the three review-driven fixes (`fade`-not-`shadowTone`,
source/profile re-resolve in `applyCameraProfile` / `applyProbe`, small-image
Laplacian guard on `width > 2 && height > 2`) and once more on AI-executable
closeout — both gates green each time.

Minimum automated checks — all pass:

```bash
bun run verify:ios       # exit 0
git diff --check         # exit 0
```

Focused logic check — wired into the iOS swift contract gate, also
runnable standalone:

```bash
bash apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh
# reports: ==> look director resolver test
#          Look Director resolver tests passed
```

The focused test compiles `FilmtoneSourceToneDescriptor.swift`,
`FilmtoneCreativePack01Patches.swift`, `FilmtoneLookDirector.swift`,
`FilmtoneCreativePack01Adaptation.swift`, and
`test-look-director.swift` against the host-built `FilmLabSwiftCore`
module, then asserts six cases: night/practical, high-key,
low-saturation flat, Log/profile (Apple Log catalog id + bias 0.06),
ordinary, and a legacy descriptor with all optional scores nil.

## Final Owner Gate

Status: **pending**. AI-executable closeout is complete; the remaining work is
a final visual/performance signoff on physical hardware. This is not an
AI-blocking implementation task — it is the final-stage gate that flips M1 to
Done once the owner runs and reports.

Run on the target iPhone against the `27a14e30` build, comparing each export to
the prior build of the same source:

1. **Night / practical-light** source.
2. **Bright outdoor / high-key** source.
3. **Log / profile or low-saturation flat** source.

For one representative export, enable render-stage profiling:

```bash
xcrun devicectl device process launch --device <UDID> \
  --environment-variables FILMTONE_EXPORT_RENDER_STAGE_PROFILE=24 \
  com.forestone.filmtone
```

For each of the three sources, paste back the following row (sidecar JSON
fields are listed for reference):

| field | source |
|---|---|
| `avgRenderMsPerFrame` | sidecar `performance.avgRenderMsPerFrame` |
| `GlowFamily` substage ms | sidecar `performance.renderStageProfile.stages[GlowFamily].incrementalAvgMsPerSample` |
| `DetailSoftness` substage ms | sidecar `performance.renderStageProfile.stages[DetailSoftness].incrementalAvgMsPerSample` |
| thermal start → end | sidecar `thermalStateAtStart` / `thermalStateAtEnd` |
| export elapsed (ms) | sidecar `exportElapsedMs` |
| preview usability | manual: does the matching preview stay responsive? |
| visual delta clearly better | manual A/B against the prior build |

When the table arrives I will: record it in this active, classify performance
(`acceptable in M1` / `tune in M2` / `escalate to M3 optics`), finalize
`Article Opportunity` (`Short post` if 2+ sources show a clear delta, else
`Developer note`), archive this active to
`archive/2026-05-13-m1-max-quality-look-director.md`, and append a 1-3 line
completion note to `strategy.md`.

## Done Conditions

AI-executable conditions (all met at `27a14e30`):

- Implementation checklist items complete or explicitly moved out with a reason.
- Six resolver cases pass (`Look Director resolver tests passed`).
- `bun run verify:ios` passes.
- `git diff --check` passes.

Final Owner Gate conditions (pending):

- Three-source visual/performance check recorded in this active.
- At least two of the three sources show a clear visual improvement without a
  blocking artifact.
- Performance cost classified as `acceptable in M1`, `tune in M2`, or
  `escalate to M3 optics`.
- `Copy / History Impact`, `Article Opportunity`, and `Change-History
  Opportunity` finalized once the visual delta is known.

## Stop Conditions

Stop and report instead of looping when any of these fires:

- Done conditions are met.
- A descriptor/schema change requires a real `Profile.version` bump.
- New Swift file registration becomes ambiguous after one pbxproj repair
  attempt.
- `bun run verify:ios` or the Xcode build fails three consecutive times.
- The three-source check shows `avgRenderMsPerFrame` regresses by more than
  35% on all three sources, or thermal end state reaches `serious` / `critical`
  on the short check.
- Visual direction fails on two or more representative sources.

## Out Of Scope

- Metal optics productionization, unless M1 closes by routing to M3.
- Depth-aware video rendering.
- Depth-aware still-image implementation; only notes may be captured for M4.
- Desktop/macOS parity.
- Public web, App Store metadata, release notes, or portfolio updates.
- New settings UI or user-facing copy.
- Commit, push, PR, or portfolio submodule bump without explicit owner request.

## Unexpected Blockers

- None yet.

## Copy / History Impact

Implementation landed in the worktree on 2026-05-13 JST. Verification
gates pass; on-device three-source visual/performance check still
pending owner-side run before classification freezes.

- Copy / History Impact: No public-copy change in this active. The
  user-facing strings, Look picker labels, and App Store metadata are
  untouched. A future release note may mention "Stone / Urban / Noir
  now respond to source material" without specifying parameters, but
  that wording is deferred until the visual delta is signed off.
- Article Opportunity: **Pending — Short post or Developer note**.
  Defaults to Developer note (the change is a behavior-direction story
  rather than a UX surface change). Promotes to Short post only if
  the three-source visual check shows a clear, demonstrable
  before/after on at least two of three representative sources.
- Change-History Opportunity: **Developer note**. M1 changes the
  Filmtone iOS Look authoring narrative from "static recipes per
  Look" toward "source-aware Look Director coordinating LUT
  intensity, optics, and detail bias from import-time signals." This
  is worth recording because it explains why
  `FilmtoneCreativePack01Adaptation.resolve(...)` returns non-nil for
  Creative Pack 01 entries when it used to no-op, and why
  `FilmtoneSourceToneDescriptor` gained optional score fields.

## Performance posture

Per the lane brief, performance is treated as gate-by-measurement, not
a reason to dial back image quality. M1 records:

- Source probe: image path adds one 4-neighbor Laplacian sweep over
  the same 96-pixel-long-edge thumbnail (≤9216 pixels). Constant cost
  per import, runs off the render path.
- Video probe: was sampling 1 frame mid-clip; now samples 3 (20% /
  50% / 80%). Triples import-time decode but stays bounded and runs
  once per import.
- Per-frame export: zero new work. The Look Director runs at apply
  time and bakes results into `params` / `creativeLut.intensity`.
  Existing `avgRenderMsPerFrame` / `GlowFamily` / `DetailSoftness`
  sidecar fields cover any visual deltas. Classification of any
  observed regression (acceptable / M2 tune / M3 escalate) waits on
  the three-source on-device run.
