# Filmtone iOS Capture Practicality Strategy

Date: 2026-05-09 JST

## Placement

This directory is the current source of truth for the Filmtone iOS
capture-practicality lane:

```text
docs/filmtone/ios/capture-practicality/
├── strategy.md
├── active.md
└── archive/
```

The closed V2 capture / Gyroflow lane remains read-only evidence for the
capture pipeline that this lane extends:

```text
docs/filmtone/ios/v2-capture-gyroflow/strategy.md
docs/filmtone/ios/v2-capture-gyroflow/archive/
```

## Product Direction

Make the existing native iOS capture surface more useful in real owner
shooting, without turning the work into broad QA, release process, or
documentation cleanup.

The priority order is:

1. Finish stabilization On / Off because gimbal usage needs an explicit
   non-stabilized master path.
2. Remove current capture-surface blockers found while exercising S1,
   especially developer diagnostics covering camera controls after Look
   changes.
3. Make the active lens unambiguous during capture.
4. Decide and implement a continuous-capture flow for shooting multiple
   takes without being forced into the editor after every clip.
5. Raise the external SSD recording ceiling to 5 minutes, keeping local
   internal recording capped.
6. Improve recording preview behavior last, because preview work can expand
   into render cadence, color honesty, and performance.
7. Let capture use owner-imported creative LUTs, with app-owned input
   conversion and visible warning when a loaded LUT looks like a technical
   transform LUT rather than a creative Look LUT.

## Execution Bias

- Product behavior comes first: capture truth, master quality, export
  truth, and owner-visible shooting control.
- Keep the outer shell minimal until the product path works. Do not add
  broad QA matrices, App Store work, screenshot work, or handoff sprawl
  unless the owner explicitly asks for QA after the core behavior passes.
- Do not choose conservative hedges over product quality. If a path lowers
  master quality, state the tradeoff and stop.
- No silent fallback. Stabilization, storage, codec, color space, fps,
  lens, and preview behavior must be explicit.

## Measurable Done Conditions

This lane is done when the owner can repeatedly:

1. Open the native capture surface.
2. Choose stabilization On for handheld capture or Off for gimbal capture.
3. Know which rear lens is active before pressing record.
4. Record multiple takes in one shooting session without being forced into
   the editor between takes.
5. Record with an external SSD for up to 5 minutes without silently copying
   the master into local iPhone storage.
6. See a recording preview that is stable enough for framing, exposure
   judgment, and Look choice.
7. Complete the existing capture loop: master/proxy package, editor handoff,
   master-quality export when available, and sidecar provenance.
8. Import a `.cube` Look LUT from the capture surface, preview it during
   recording, and have the chosen LUT travel with the take into editor and
   export provenance without silently double-transforming Apple Log footage.

## Milestones

### S1 - Capture Stabilization Toggle

Goal:

Expose stabilization as an intentional capture-time choice, so gimbal
footage can be recorded without AVFoundation electronic stabilization while
handheld footage keeps the current `cinematicExtendedEnhanced` baseline.

Done:

- Capture UI exposes a compact On / Off stabilization control in the
  existing capture surface, not a new Settings page.
- Default remains On to preserve the accepted handheld baseline.
- On selects `AVCaptureVideoStabilizationMode.cinematicExtendedEnhanced`
  and keeps the existing exact active-mode gate.
- Off selects `AVCaptureVideoStabilizationMode.off` and treats active
  `.off` as the expected result, not as a failure.
- Apple Log 2, ProRes 422 HQ, 4K24, selected lens, proxy generation,
  editor adoption, and master/proxy export truth are unchanged.
- `capture-package.json` records the requested and observed stabilization
  state so later export sidecars do not lose capture truth.
- UI text and accessibility labels make the state owner-visible.

Dependency:

- V2 capture / Gyroflow M14 closed state.

Out of scope:

- New stabilization modes beyond On / Off.
- Gyroflow / motion-library work.
- Preview tuning.
- SSD duration cap changes.
- Continuous-capture flow changes, except where the S1 UI must not block
  existing camera controls.

### S2 - Active Lens Visibility

Goal:

Make the currently active lens visible at a glance, so the owner does not
have to infer it from framing or from a selected chip that may be off-screen,
hidden, or too subtle while shooting.

Done:

- Active lens identity is visible in the capture cockpit even when only one
  qualified lens is available.
- Multi-lens devices show both selected state and active lens text clearly.
- The quality contract line and lens controls do not disagree.
- Lens visibility works while stabilization On / Off exists and while
  recording disables unsafe controls.
- No new lens behavior ships in this milestone; it is readout clarity only.

Dependency:

- S1, because the cockpit must settle after the stabilization chip lands.

Out of scope:

- New lens switching behavior.
- Continuous zoom.
- Per-lens quality or format renegotiation beyond the existing contract.

### S3 - Continuous Capture Flow

Goal:

Support a real shooting session where the owner records multiple takes
without being forced into the editor after every completed clip.

Product direction:

After a successful recording, the capture surface should make the next action
explicit:

- Keep shooting: stay in capture, retain the completed package, and arm the
  next recording.
- Open editor: adopt the chosen package into the existing editor flow.
  One take opens directly; multiple takes require an explicit take choice.

Done:

- Recording completion no longer has only one implicit destination.
- The owner can record at least three clips in one capture session without
  visiting the editor between clips.
- Completed packages are not lost, silently overwritten, or orphaned.
- The UI shows enough session state to know how many clips were captured and
  which clip will open in the editor.
- Editor adoption still uses the existing `adoptCaptureResult(_:)` path.
- Master/proxy package persistence and export provenance remain intact for
  each clip.

Dependency:

- S2, so the capture surface has enough lens/readout clarity before adding
  post-record flow choices.

Out of scope:

- Full clip browser or timeline.
- Batch editing.
- Auto-export.
- Rewriting the editor adoption pipeline.

### S4 - External SSD 5-Minute Capture Ceiling

Goal:

Let external-SSD capture run up to 5 minutes while keeping local capture
short and explicit.

Done:

- External storage mode uses a 300 second recording ceiling.
- Internal local capture remains capped at 10 seconds.
- Status UI and package metadata show the resolved duration limit.
- Preflight capacity gate is raised to match 5-minute ProRes 422 HQ Apple
  Log 2 capture plus proxy/finalization headroom.
- SSD unavailable, not external, not writable, or insufficient-capacity
  paths fail visibly instead of writing a large master locally.
- Auto-stop and manual stop both preserve the existing master/proxy package
  and export behavior.

Dependency:

- S3, so longer SSD sessions build on the final post-record flow rather than
  reworking it immediately afterward.

Out of scope:

- Internal 5-minute recording.
- Adaptive bitrate / HEVC fallback.
- Thermal policy beyond visible failure if the writer interrupts.
- Broad device matrix.

### S5 - Recording Preview Behavior Improvement

Goal:

Improve the capture preview only after the capture controls, continuous
shooting flow, and SSD duration work are stable, because this work is heavier
and touches the render loop.

Done:

- The first active task identifies the dominant preview problem from the
  current surface: judder, first-frame black, Look-switch delay, color
  mismatch, or recording-time performance.
- The fix keeps the MovieFileOutput master path untouched.
- VDO remains preview-only; it does not become an alternate writer.
- Fallback preview behavior is explicit and does not claim graded preview
  if only raw `AVCaptureVideoPreviewLayer` is active.
- Owner-visible result is better for framing, exposure judgment, and Look
  choice.

Dependency:

- S4.

Out of scope:

- Full monitoring tools such as waveform, false color, zebra, or focus
  peaking unless the owner chooses them as a separate product lane.
- Replacing the export pipeline.
- App Store assets and public copy.

### S7 - Capture Custom LUT Intake

Goal:

Let the owner apply an arbitrary user-imported creative LUT while recording,
without making them understand capture-source conversion. Filmtone owns the
Apple Log 2 input conversion; imported LUTs in this lane are treated as
creative Look LUTs. If a loaded LUT appears to be a technical transform LUT,
the UI must warn that the image may break because the app already handles the
conversion stage.

Product direction:

- Capture master remains the strict ProRes 422 HQ / Apple Log 2 source unless
  a future lane explicitly chooses a baked-writer path.
- The LUT affects live monitoring, selected-take identity, editor adoption,
  and export render/provenance through the existing non-destructive Look
  pipeline.
- User-imported capture LUTs should reuse the existing `.cube` parser,
  library store, `CreativeLutBinding`, `FilmtoneSharedGradeProcessor`, and
  sidecar creative-LUT reference wherever possible.
- Transform-LUT detection is a warning contract, not a perfect classifier:
  use filename/title/profile keywords and simple cube-shape heuristics to flag
  likely input/conversion LUTs, then let the owner either cancel or use anyway.

Done:

- The capture Look picker exposes a compact User LUT import / selection path
  without adding a broad library-management surface.
- Imported `.cube` files are parsed, normalized, deduplicated, and stored via
  the existing LUT library with `preferredSlot = .creative`.
- Capture live preview applies the app-owned Apple Log 2 input conversion
  before the selected creative LUT, including cold-start capture with no
  editor source loaded.
- Built-in Looks and user LUT Looks share one capture selection model so the
  LOOK chip, take picker metadata, package, editor adoption, and export path do
  not disagree.
- `capture-package.json` records enough custom-LUT truth to recover the Look:
  stable library id when available, title, size, source hash or embedded
  fallback, intensity, conversion policy, and whether a transform-LUT warning
  was shown / accepted.
- Export sidecar provenance identifies the capture-time custom LUT and the
  app-owned input-conversion policy.
- If the imported LUT is likely a transform / input / Log-to-Rec709 LUT, the
  owner sees a clear warning before applying it in capture.
- No silent fallback: parser failure, missing LUT blob, unsupported cube size,
  or preview-grade build failure must be visible as ungraded or failed
  capture-LUT state, not presented as a successful graded preview.

Dependency:

- S6 orientation contract should land first unless the owner explicitly
  chooses to switch active work. Custom LUT preview quality is hard to judge if
  the capture preview can rotate incorrectly.

Out of scope:

- Baking the custom LUT into the recorded ProRes master.
- Treating user LUTs as replacement input transforms inside the capture path.
- Full LUT library management, folders, tags, batch import, marketplace, or
  cloud sync.
- Supporting non-`.cube` LUT formats in this lane.

## Current Active

S6 - Capture Orientation Contract.

`active.md` owns the current live work. It starts from the containment
hotfix commit `12978262 Lock iOS capture surface orientation` and turns
iPhone rotation into an explicit capture contract covering preview
orientation, chrome layout, tap-to-focus coordinates, recorded master/proxy
truth, and sidecar provenance.

The S1-S5 lane remains fully advanced from the coder side; owner-device smoke
for those paused lanes is still pending. S7 code-side work is also complete
and paused for owner-device smoke.

Paused (code-complete, awaiting owner-device smoke):

- `paused/2026-05-09-s1-stabilization-toggle-pending-owner-smoke.md`
- `paused/2026-05-09-s2-active-lens-visibility-pending-owner-smoke.md`
- `paused/2026-05-09-s3-continuous-capture-flow-pending-owner-smoke.md`
- `paused/2026-05-09-s4-ssd-5min-ceiling-pending-owner-smoke.md`
- `paused/2026-05-09-s5-preview-scoping-pending-owner-defect-pick.md`
- `paused/2026-05-10-s7-capture-custom-lut-intake-pending-owner-smoke.md`

## Known Constraints

- Native SwiftUI capture surface is the product path.
- `FilmtoneProductCapture` remains legacy/fixed-duration evidence unless a
  future active task explicitly scopes it.
- Master quality gates remain strict: ProRes 422 HQ (`apch`), Apple Log 2,
  4K24, selected lens contract, and explicit stabilization state.
- External SSD access remains security-scoped and explicit.
- Internal capture must not silently become a large-master path.
- New Swift files require Xcode project registration in the 4 standard
  sections.

## Verification Policy

Use the smallest verification that proves the changed surface:

```bash
git diff --check
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

For behavior changes, run a focused owner-device smoke:

- S1: one On clip and one Off clip, with package/sidecar truth checked.
- S2: visual capture-surface check showing active lens readout on single-lens
  and multi-lens states where available.
- S3: three consecutive captures in one session, then editor adoption of the
  intended clip.
- S4: one external SSD clip near the new cap when practical, plus a shorter
  smoke for iteration.
- S5: a preview-specific before/after check that matches the problem being
  fixed.

Broader QA only follows after the core product result passes and the owner
asks for that level of confidence.

## Open Questions

- Should the UI label be "Stabilization", "Gimbal", or an icon-only state
  once S1 is implemented? Start with explicit wording during S1, then
  compact it only if the cockpit gets crowded.
- What exact SSD free-space gate should S4 use after measuring the current
  4K24 ProRes 422 HQ Apple Log 2 file rate on owner hardware?
- Should continuous capture default to "Keep shooting" with an explicit
  "Open editor" action, or show a short post-record choice sheet every time?
  Product direction currently favors staying in capture with an explicit
  editor action.
- Which preview defect matters most to the owner after S1-S4 land?

## Completion Log

- 2026-05-09: Strategy opened. Active task set to S1 stabilization On / Off.
- 2026-05-09: S1 implementation landed in active worktree — capture
  cockpit `STAB` chip, requested/observed stabilization persisted in
  `capture-package.json` and export sidecar; xcodebuild + verify:swift-contract
  green. Owner-device smoke (On / Off clips + master-quality + export)
  pending before archive.
- 2026-05-09: Owner added three capture-practicality findings: continuous
  shooting should not force editor entry after every clip, active lens must
  be clearer, and developer diagnostics after Look changes block ISO /
  camera controls. Strategy now routes them as S2 active lens visibility,
  S3 continuous capture flow, and an S1 acceptance blocker for the debug
  overlay.
- 2026-05-09: S1 revision pass — F3-R DIAG developer overlay removed
  from the capture cockpit (S1 acceptance blocker resolved) and the
  post-record stabilization gate now fails loudly on a missing AV
  connection instead of silently recording the requested mode as
  observed. xcodebuild + verify:swift-contract green. Owner-device
  smoke still pending before archive.
- 2026-05-09: S2 implementation landed — `qualityContractText` always
  prepends the active lens magnification (`1× · 4K24 · Log2 · ProRes`)
  regardless of single-vs-multi-lens topology. xcodebuild green, no
  Phase0 contract surface touched. Owner-device smoke pending before
  archive. S3 - Continuous Capture Flow now active.
- 2026-05-09: S3 implementation landed — capture session auto-rearms
  on `.completed`, captured packages accumulate in the view, and a
  new persistent commit pill (`FilmtoneCapturePostRecordChoice`,
  registered in pbxproj 4 sections) carries the explicit "Open
  editor" affordance. Owner-smoke revision added an explicit take
  chooser for multi-take sessions, then revised it to show proxy
  thumbnails; the second visual revision replaced the heavy grouped
  sheet with a clear Liquid Glass overlay and four-frame proxy contact
  strips for long SSD takes. LOOK moved to the bottom-right capture
  control so the top row stays five chips. xcodebuild +
  verify:swift-contract green. Owner-device smoke (3-take session,
  chosen contact strip opens, earlier survive on disk) pending before
  archive.
  S4 - External SSD 5min ceiling now active.
- 2026-05-09: S4 implementation landed —
  `externalDurationCapSeconds` raised 60 s → 300 s,
  `Preflight.minimumFreeBytes` raised 10 GB → 30 GB to fit the
  longer master + proxy + finalize headroom, storage pill formats
  as `Internal 10s` / `External 5m` for both modes. xcodebuild
  green. Owner-device smoke (real 5 min SSD take, 30 GB preflight
  refusal, durationLimitSeconds round-trip) pending. S5 -
  Recording Preview Behavior Improvement now active in scoping
  phase.
- 2026-05-09: S5 scoping pass landed — fallback preview now
  renders an explicit "Ungraded preview" badge when the VDO is
  rejected at `prepare(lens:)`; candidate-problem map (judder /
  first-frame black / Look-switch delay / color mismatch /
  recording-time perf) documented for the next S5 active.
  xcodebuild green. Full preview-improvement implementation
  awaits owner's dominant-defect pick on hardware.
- 2026-05-09: S5/S3 integration revision — moved the fallback
  "Ungraded preview" badge into the cockpit overlay flow below the
  top controls so it cannot collide with the S3 take-commit pill.
  xcodebuild + verify:swift-contract green.
- 2026-05-10: S6 opened after owner-device smoke exposed iPhone
  rotation problems in the capture preview/chrome. The immediate
  containment hotfix (`12978262`) locks the capture surface to
  portrait while preserving the existing `videoRotationAngle = 90`
  master/proxy contract; `active.md` now tracks the full orientation
  contract lane.
- 2026-05-10: S7 code-side implementation landed in isolated worktree —
  capture LOOK sheet imports / selects user `.cube` creative LUTs, warns on
  likely transform LUTs, carries custom-LUT truth through package, editor
  adoption, and export sidecar provenance. `git diff --check`, xcodebuild,
  and app-level `verify:swift-contract` green. Owner-device smoke pending.
