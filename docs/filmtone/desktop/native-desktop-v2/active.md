# M5-B Apple Liquid Glass Adoption (Pass 1)

Date: 2026-05-04 JST
Milestone: M5
Classification: Interrupt — user-requested UI material upgrade
Status: In progress
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

## Why

Strategy now lists Apple Liquid Glass as the primary UI material for
Native Desktop v2 control surfaces (`Goal` + `Done Conditions` updated
this session). Currently only `GlassControlGroup.swift` uses
`.glassEffect()`; every other floating control panel
(`GradeControls` / `ExportProgressBar` / `VideoScrubBar`) still uses
the legacy `.regularMaterial` background. Pass 1 closes that gap on the
visible control panels so the native app reads as a Liquid-Glass-first
surface, matching the Done Condition language. Toolbar / window chrome
is system-driven on macOS 26 and is treated as a separate
audit (Pass 2) so this slice stays small and reviewable.

## Scope (本質, Pass 1)

- Migrate the three currently-`.regularMaterial` floating panels to
  `.glassEffect(.regular, in: …)` matching the existing
  `GlassControlGroup` posture.
  - `GradeControls` panel
  - `ExportProgressBar` panel
  - `VideoScrubBar` panel
- Preserve the existing rounded-rectangle / capsule shape per panel —
  this slice is material substitution, not layout redesign.
- Keep the preview content layer (`PreviewSurface` `Color.black`
  backdrop) glass-free per strategy + Apple HIG.
- Build clean under Swift 6 strict concurrency.

## Out of scope (外殻 — Pass 2 / later)

- `GlassEffectContainer` grouping for refraction-coordinated nearby
  glass shapes — visually nice-to-have once panels overlap or interact;
  defer until Pass 1 lands and we have a real visual baseline.
- Toolbar / window chrome audit (system-driven on macOS 26; verify it
  is already Liquid Glass and document the conclusion in Pass 2).
- New sidebar / inspector design — none currently exist.
- Any color / opacity tuning beyond `.regular`.
- iOS surface — untouched.
- Export and pipeline logic — untouched.

## Stages

- [ ] S1 — `GradeControls` panel: replace
  `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))`
  with `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))`
  in `RootWindowView.swift`. Preserve padding.
- [ ] S2 — `ExportProgressBar` panel: same substitution.
- [ ] S3 — `VideoScrubBar` panel: same substitution.
- [ ] S4 — Build via `xcodebuild` → `BUILD SUCCEEDED` under Swift 6
  strict concurrency.
- [ ] S5 — CLI regression smoke (Stone @ 1.0 on
  `09-skin-light.png`) → hash must remain
  `436bfc81…d5f49931` (UI-only change must not perturb the grade
  pipeline). Visual material smoke deferred to user.
- [ ] S6 — Commit. One feat commit.

## Stage granularity

- S1 ~5 min
- S2 ~5 min
- S3 ~5 min
- S4 ~10 min
- S5 ~5 min
- S6 ~5 min

Total ≈ 35 min.

## Invariants

- Grade pipeline + sidecar + export paths: zero behavioural change. CLI
  hash regression check is the gate.
- Preview content layer remains a plain opaque backdrop.
- Existing `GlassControlGroup` (`.glassEffect(.regular, in: Capsule())`)
  is the reference posture for material + shape semantics.
- Padding and corner radius preserved on each panel.
- macOS 26 only — `.glassEffect` is the macOS 26 Liquid Glass API.

## Unexpected

(filled during implementation)

## Follow-up

- Pass 2: `GlassEffectContainer` audit to coordinate refraction across
  the right-rail stack (`GlassControlGroup` + `GradeControls` +
  `ExportProgressBar`).
- Pass 2: toolbar / window chrome audit on macOS 26 — document whether
  the system delivers Liquid Glass automatically or whether explicit
  modifiers are needed.
- Pass 2: visual smoke against a dark and a bright preview backdrop to
  confirm legibility on both poles.
- Tint / variant exploration (`.tinted` / `.identity`) once the base
  posture is stable.

## Result

(filled at completion)
