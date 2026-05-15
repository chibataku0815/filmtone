# Active — Film Breath (Desktop + iOS)

Inserted 2026-05-15 JST as a cross-platform Native Desktop v2 / iOS / shared
contract task.

## Milestone

M3 / M4 / M5 quality work: shared color contract consolidation plus native
Desktop and iOS video preview/export behavior.

## Goal

Add `Film Breath` / `フィルムブレス` as a single Amount control for video preview
and video export on Desktop and iOS. It modulates exposure, contrast, and color
over time with smooth deterministic motion. Still-image UI stays hidden, and any
saved Look or sidecar value is inert for still processing by forcing
`timeSeconds = 0`.

## Edit Targets

- `packages/film-lab-core/`: Phase0 params, schema/defaults, presets, tests,
  Swift payload generation, and the shared `deriveFilmBreathOffsets` helper.
- `packages/film-lab-swift-core/`: generated payload plus handwritten runtime
  helper/wiring if generation does not own it.
- `apps/filmtone-desktop-macos/`: grade pipeline, video export/preview wiring,
  Advanced Motion control, recipes, and Verify tests.
- `apps/capacitor-film-lab-ios/`: Swift editor/export grade wiring, Advanced
  Motion control, recipes, DTO/merge preservation, and iOS verification.
- `docs/filmtone/articles/2026-05-15-film-breath/`: article foundation only.

## Read-Only References

- `AGENTS.md`
- `apps/filmtone-desktop-macos/README.md`
- `docs/filmtone/desktop/README.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `docs/filmtone/filmtone-copy-quality-harness.md`
- `docs/filmtone/filmtone-implementation-history.md`
- Dehancer Film Breath article, read only for the category framing: exposure,
  tonal contrast, and color fluctuation over time.

## Checklist

- [x] Add `filmBreathAmount` to the shared Phase0 contract directly after
  `trailIntensity`.
- [x] Add deterministic bounded `deriveFilmBreathOffsets(amount, timeSeconds,
  sourceSeed)` with exact identity at `amount = 0` or `timeSeconds = 0`.
- [x] Regenerate generated Swift payloads with `bun run generate:ios-swift`.
- [x] Wire Desktop grade pipeline so Film Breath applies after source/input
  transform and before the base grade, using video frame time and source seed.
- [x] Add Desktop Advanced Motion UI row, hidden for stills, plus Motion recipe
  defaults (`Default = 0`, `Strong = 0.28`).
- [x] Wire iOS editor preview/export grade path with the same still/video
  behavior and preserve `filmBreathAmount` through DTO / Backlight Veil merge.
- [x] Add iOS Advanced Motion UI row and recipe defaults
  (`Default = 0`, `Strong = 0.28`).
- [x] Add focused tests for contract defaults/bounds/order, helper identity /
  determinism / bounds / smoothness, Desktop catalog and pipeline behavior, and
  iOS DTO/merge preservation.
- [x] Record verification results below.
- [x] Archive this active file and append a short strategy note after Done.

## Verification

- [x] `bun test packages/film-lab-core/src/film-breath.test.ts packages/film-lab-core/src/phase0-schema.test.ts packages/film-lab-core/src/schema.test.ts packages/film-lab-core/src/ios-phase0.test.ts packages/film-lab-core/src/ios-swift-payload.test.ts` — 109 pass.
- [x] `bun run build:core` — passed.
- [x] `bun run generate:ios-swift` — regenerated shared Swift payload; later drift check passed in `verify:ios`.
- [x] `swift test --package-path packages/film-lab-swift-core` — 76 pass.
- [x] `bun run verify:desktop` — native macOS build passed.
- [x] `bash apps/filmtone-desktop-macos/Verify/run.sh` — 143 pass.
- [x] `./apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh` — passed after adding additive `filmBreathAmount = 0` decode support to the production DTO and verifier stub.
- [x] `bun run verify:ios` — passed; only pre-existing deprecation / Sendable warnings surfaced.
- [x] `bun run check:filmtone-context` — passed.
- [x] `bun run check:filmtone-copy` — passed.
- [x] `git diff --check` — passed.

## Completion Log

2026-05-15 JST: Film Breath landed as a single video-only Motion control across
shared core, generated Swift, Native Desktop, and iOS. The runtime applies
deterministic bounded exposure/contrast/temperature/tint offsets before the
base grade when frame time is positive; still paths remain identity through the
`timeSeconds = 0` short-circuit.

## Done Conditions

- Desktop and iOS video preview/export respond to `filmBreathAmount`.
- Still processing remains visually and numerically inert because
  `timeSeconds = 0` short-circuits Film Breath.
- The shared contract includes `filmBreathAmount` with default `0`, range
  `0...1`, generated Swift order directly after `trailIntensity`, and sidecar
  V1 additive compatibility.
- Film Breath exposes exactly one user control in Motion: `Film Breath` /
  `フィルムブレス`.
- Required verification is recorded and clean, or any remaining risk is
  explicitly documented.

## Stop Conditions

- Stop after 3 consecutive failures of the same verification command.
- Stop if generated Swift order cannot be made stable with
  `filmBreathAmount` directly after `trailIntensity`.
- Stop if still processing cannot be made exact-identity for saved/sidecar
  Film Breath values.
- Stop if implementing Film Breath requires Gate Weave, frame translation,
  scratches/dust, or scan jitter in this task.

## Out Of Scope

- Gate Weave, image shake, scratches, dust, scan jitter, and Dehancer-compatible
  multi-control UI.
- Static still-image Film Breath UI or still output changes.
- iOS live capture monitor support.
- Sidecar schema V2.
- Portfolio submodule bump, release metadata mutation, App Store submission, or
  public release/version claims.

## Copy / History Impact

- Public copy update required: release-note surface when Film Breath ships,
  because this is a visible video Motion control and export behavior.
- Implementation history update required: no source-of-truth rewrite expected;
  shared TypeScript contract plus generated Swift payload remains the current
  architecture story.
- Release/App Store claim: run truth scripts before any release/version wording.
- Article Opportunity: Release-note + Full article candidate — visible video
  output quality change with a concrete product story, but article copy should
  wait until verification proves the behavior.
- Change-History Opportunity: Context paragraph — useful to explain shared
  color truth driving native Desktop/iOS runtime behavior, not a standalone
  migration story.
