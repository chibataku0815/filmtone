# Filmtone iOS Max Quality Look Director Strategy

Date opened: 2026-05-13 JST
Last updated: 2026-05-13 JST

This lane is the iOS product-quality lane for raising the rendered image
ceiling from source-aware grade decisions, not a conservative cleanup lane.

## Placement

Canonical lane path:
`docs/filmtone/ios/max-quality-look-director/`

Worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-ios-max-quality-look-director`

Branch:
`feature/ios-max-quality-look-director`

Base:
`origin/main @ 45366bbb` (`merge: integrate ios capture package desktop parity`)

## Goal

Increase the maximum iOS image quality for built-in Creative Pack Looks by
making each Look respond to source material and scene character. The system may
intentionally drive optical and texture parameters when they improve the image;
performance concerns should be handled by measurement, preview/export tiering,
and follow-up acceleration rather than by reducing the visual target upfront.

## Product Direction

- Prefer visible image improvement over neutral defaults.
- Use source analysis to make stronger choices, not just defensive corrections.
- Keep analysis import-time or session-time; do not add per-frame scene analysis.
- Let export run the full-quality recipe.
- Keep preview responsive by relying on existing preview scale/proxy behavior and
  the existing recording monitor path.
- Treat performance as a gate with telemetry, not as a reason to avoid high-value
  optics in the first design.

## Measurable Done Conditions

- Manual Source Profile selection is included in iOS `sourceDetailBias`
  resolution so Log/profile sources get matching texture compensation.
- Source tone analysis is strong enough to distinguish at least:
  night/practical-light, bright/high-key, flat low-saturation, shadow-heavy, and
  ordinary material.
- `FilmtoneCreativePack01Adaptation.resolve(...)` returns non-nil adaptations
  for current Creative Pack 01 built-in Looks when the source descriptor warrants
  it.
- Adaptation may adjust LUT intensity, tone compression, shadow latitude, detail
  softness, bloom, halation, diffusion, and vignette. It must not be limited to
  color-only changes if optics are the better image-quality move.
- Existing built-in Look apply paths use the same resolved adaptation in editor,
  saved-look application, and capture relay paths.
- No generated Swift is hand-edited.
- The app builds through the iOS verification gate.
- Minimal visual/performance check is recorded against three representative
  sources: night/practical light, bright outdoor/high-key, and Log or low-sat
  material.
- Performance is inspected through existing export sidecar/profiler fields:
  `avgRenderMsPerFrame`, `GlowFamily`, `DetailSoftness`, thermal state, and
  export elapsed.

## Milestones

| ID | Milestone | Status | Done Condition |
|---|---|---|---|
| M1 | Max Quality Look Director Pilot | Active | Source-profile detail fix, stronger source descriptor, Look Director resolver, wiring, logic tests, iOS verify, and 3-source minimal visual/perf check. |
| M2 | Tuning Pass | Planned | Adjust constants only if M1 visual result is promising but too strong/weak on one of the three representative sources. |
| M3 | Optics Performance Escalation | Planned, gated | If M1/M2 proves image value but `GlowFamily` cost blocks acceptance, evaluate Metal optics productionization or lower-cost optical composition. |
| M4 | Depth-Aware Stills Experiment | Planned, gated | HEIC/depth still-image glow/mist experiment only after M1 is stable; video depth remains out of this lane until explicitly opened. |

## Current Active

`active.md` tracks M1 only. Do not mix M2/M3/M4 work into M1 unless the active
file is explicitly replaced or paused.

## Dependencies And Evidence

- iOS app rules: `apps/capacitor-film-lab-ios/CLAUDE.md`
- iOS lane index: `docs/filmtone/ios/README.md`
- Creative Pack hook: `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneBuiltInCatalog.swift`
- Existing source descriptor: `apps/capacitor-film-lab-ios/ios/App/App/Source/SourceProbeService.swift`
- Built-in Look apply paths:
  `FilmtoneEditorStore`, `EditorProjectMutationCoordinator`,
  `EditorCaptureRelay`
- Export render order and profiling:
  `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  and `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMetrics.swift`
- Detail Softness lane:
  `docs/filmtone/detail-softness/strategy.md`

## Constraints

- Do not state iOS public version, App Store state, or release scope without the
  truth scripts.
- Do not change App Store metadata or public copy in this lane unless the owner
  explicitly asks.
- Do not lower the image-quality target only to avoid performance work. If cost
  is high, record it and route to M2/M3.
- Do not add silent fallback behavior. If a required source signal is missing,
  resolve to a clear ordinary-material adaptation state.
- Do not bump `Profile.version` unless a real stored/cache schema change is
  introduced and the sidecar/reader contract is updated in the same scope.
- New Swift files require `project.pbxproj` four-section registration.
- Use `bun` for repo verification.

## Open Questions

- Whether the strengthened source descriptor can remain inside
  `FilmtoneSourceToneDescriptor` with backward-compatible optional fields, or
  should become a dedicated `FilmtoneLookDirectorDescriptor`.
- Exact video sample points for M1. Proposed default: 20%, 50%, 80% of source
  duration, capped to a maximum of three frames.
- Whether M1 should tune all current Creative Pack 01 looks equally, or make
  Stone the flagship and keep Urban/Noir slightly less aggressive.
- The actual runtime budget on the owner's target device for heavy optical
  scenes. M1 records the observed delta instead of guessing.

## Copy / History Impact

Pending final M1 result. If the visible output improvement survives the minimal
visual/performance check, likely classification is:

- Copy / History Impact: release-note wording may be appropriate, but no copy
  is changed in M1.
- Article Opportunity: Short post if the before/after delta is strong; otherwise
  Release-note only.
- Change-History Opportunity: Developer note, because the lane changes Look
  authoring from static recipes toward source-aware direction.

## Operating Rules

- Keep exactly one `active.md` in this lane.
- `active.md` owns the current subtask and must be archived to
  `archive/YYYY-MM-DD-<slug>.md` when complete.
- Half-day or longer interrupts move the active file to `paused/` with a short
  done/not-done summary, then open a new interrupt-only active.
- On completion, append only a 1-3 line note to this strategy.

## Completion Log

- 2026-05-13 JST: Lane opened from latest `origin/main` in a dedicated worktree.
  M1 active drafted for a batched iOS Max Quality Look Director pilot with
  minimal visual/performance verification.
