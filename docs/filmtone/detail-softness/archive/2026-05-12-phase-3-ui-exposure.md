# Phase 3: Detail Softness UI Exposure & Recipe Decision

Date opened: 2026-05-12 JST
Phase: 3 of 5 (see `strategy.md`; Phase 2 archived at
`archive/2026-05-12-phase-2-renderer-parity.md`).

## Gating

Phase 2 renderer parity is committed on `feature/detail-softness-contract`
through HEAD `444db1e0`:

- `e277e9f3` macOS native pilot.
- `eac47d53` iOS export port.
- `444db1e0` WebGPU + WebGL parity.

Final visual A/B at `detailSoftness ∈ {0.00, 0.18, 0.30}` is deferred to
final QA per owner direction and is **not** a precondition for Phase 3.

## Goal

Expose `detailSoftness` as a user-facing Advanced control on the live native
surfaces, without overloading `lensSoftness` or disturbing existing Looks /
recipes. Keep copy minimal but precise enough that a user reads `Lens
softness` and `Detail softness` next to each other and understands they are
different optical axes.

Live Advanced surfaces in scope:

- iOS native SwiftUI: `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneStrengthSheetData.swift`
  + `apps/capacitor-film-lab-ios/ios/App/App/Strings/FilmtoneStrings.swift`.
- macOS native: `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
  + `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtoneDesktopStrings.swift`.

Out of scope: `messages/{en,ja}.json` (legacy React/Electron surface — see
`project_native_v2_replaces_electron.md`), fastlane / App Store / LP copy,
Phase 4 `sourceDetailBias` automation.

## Owner-confirmed decisions (2026-05-12)

- **Range / default / key**: `0…1`, default `0`, stored key `detailSoftness`
  (already plumbed in Phase 1, render-active since Phase 2).
- **Placement**: Add to the existing **Optics** group, immediately after
  `lensSoftness`, on both Desktop and iOS canonical catalogs. The two
  "softness" labels sit adjacent so the contrast in copy
  (`Lens softness` vs `Detail softness`) is visible to the user.
- **Copy distinction**:
  - `Detail Softness` = reduces hard digital fine detail / local
    acutance.
  - `Lens Softness` = lens/periphery softness (unchanged meaning).
- **Hidden internals**: do not expose `kernelRadiusPx`, `edgeGuardLo/Hi`,
  `chromaAttenScale`, `highlightBias`, or `sourceDetailBias` to the user.
  They stay as derived uniforms from `deriveDetailSoftnessUniforms(...)`.
- **Recipe decision (recommended Phase 3 default)**: existing optical
  recipes (`AdvancedAdjustCatalog` default / strong, Backlight Veil
  profiles, Stone / Urban Looks) **do not** auto-apply `detailSoftness`.
  The user slider is the first exposure. Rationale below.

## Recipe decision

Existing optical / look-affecting recipe surfaces inspected:

- `AdvancedAdjustCatalog.swift` Optics group `default` / `strong` chips:
  raise `rgbShift` / `lensSoftness` / `vignette`. **Lens-character axis**
  (frame periphery falloff + RGB fringe). `detailSoftness` is a separate
  sensor-detail-acutance axis — folding it in would couple two semantically
  distinct intents.
- `FilmtoneOpticalFilterCatalog.profiles` (Backlight Veil 1/8, 1/4, 1/2):
  raise `bloomThreshold` / `bloomStrength` / `bloomRadius` /
  `bloomSoftKnee` / `diffusion` / `halationIntensity` / `halationThreshold` /
  `halationRadius` / `halationHue` / `halationSoftKnee` / `lensSoftness` /
  `rgbShift`. **Diffusion-filter axis** (glow + haze around highlights).
  Again, this is light-leak / scatter character, not sensor acutance —
  Veil profiles deliberately exclude `detailSoftness` so a Veil look does
  not pre-soften the underlying material the user is rendering.
- iOS canonical `standardAdvancedRecipes` mirrors the Desktop Optics chips
  with the same `rgbShift` / `lensSoftness` / `vignette` shape.

**Decision: keep existing recipes byte-identical in Phase 3.** Folding
`detailSoftness` into any of them would (a) silently change pixel output
for existing saved Looks / recipes that were authored before the slider
existed, (b) couple sensor-detail intent with lens-character intent, and
(c) reduce the value of the new slider as a discoverable independent
control. The user slider stays the first exposure; a later phase can
revisit recipe stamping once the slider has product feedback.

This decision is recorded here and consciously not encoded into the
Phase 2 closure — recipe authors changing later does not invalidate
Phase 3.

## Edit Targets

### iOS canonical — `apps/capacitor-film-lab-ios/ios/App/App/`

- `Editor/FilmtoneStrengthSheetData.swift`:
  - Add `control("detailSoftness", range: 0...1)` to the `optics` group
    immediately after `lensSoftness` (currently L116-119).
  - Add `case "detailSoftness": return .softness` to
    `comparisonStyleForParam(_:)` (currently L50-51). Reusing the existing
    `.softness` comparison family is the smallest-touch option: the
    `FilmtoneAdjustmentComparisonStyle.softness` case already maps to the
    `.optics` family (`HelpCompareOpticsAfter` asset). A dedicated demo
    clip is out of scope for Phase 3.
- `Strings/FilmtoneStrings.swift`:
  - Add `"detailSoftness": filmtoneLocalized("filmtone.param.detail_softness", defaultValue: "Detail softness", ...)`
    to `paramLabels` (currently L1077, after `lensSoftness`). Match the
    iOS convention of EN default on JA hosts (only `shutterAngle` /
    `trailIntensity` carry an explicit JA variant; the Desktop drift
    detector enforces this).
  - Add `case "detailSoftness":` to `paramHelpCopy(for:)` (currently
    L582, after `lensSoftness`). Copy is detail-axis-specific, contrasted
    with the adjacent `lensSoftness` help body without explicitly naming
    the other slider.

### Desktop canonical — `apps/filmtone-desktop-macos/FilmtoneDesktop/`

- `Domain/AdvancedAdjustCatalog.swift`:
  - Add `.init(key: "detailSoftness", label: strings.paramLabel(for: "detailSoftness"), range: 0...1, digits: 2)`
    to the Optics group immediately after `lensSoftness` (currently
    L138). The `clamp(_:for:)` switch already lists `"detailSoftness"`
    in the `[0,1]` case (L342), inherited from Phase 1.
  - **Do not** add `detailSoftness` to either Optics recipe (`default` /
    `strong`) per the recipe decision above.
- `Domain/FilmtoneDesktopStrings.swift`:
  - Add `"detailSoftness": "Detail softness"` to both
    `englishParamLabels` and `japaneseParamLabels`. JA mirrors EN per
    the iOS-canonical convention enforced by the drift detector.

### Drift-detector — `apps/filmtone-desktop-macos/Verify/main.swift`

- `iosCanonicalParamLabels` dictionary at L1038-1070 is the parity gate
  between Desktop and iOS labels. Add `"detailSoftness": "Detail softness"`
  to keep the drift detector authoritative.

## Verification

```bash
bun run verify:ios
bun run verify:macos
bun run check:filmtone-copy
bun run check:filmtone-context
git diff --check
```

Skip gates:

- `bun run --cwd packages/film-lab-core test` — no TS contract change.
- `bun run build:renderer` — no renderer change.

## Done Conditions

- iOS Advanced sheet renders a `Detail softness` slider in the Optics
  group immediately after `Lens softness`, with help copy distinct from
  `Lens softness`. Slider writes `detailSoftness` into
  `paramOverrides`; pre-existing Phase 2 render pipeline picks it up
  automatically.
- Desktop Advanced sheet renders the same control in the Optics group at
  the matching position, with the same label.
- Verify drift detector treats `detailSoftness: "Detail softness"` as
  canonical; Desktop catalog matches.
- `bun run verify:ios` + `bun run verify:macos` +
  `bun run check:filmtone-copy` + `bun run check:filmtone-context` pass.
  `git diff --check` clean.
- Recipe decision recorded above; existing recipes untouched.
- Identity check still holds: with the slider at `0` (default),
  pixel output is bitwise identical to pre-Phase 3 (no render change;
  Phase 2 short-circuits at `effectiveDetailSoftness < 0.0001`).

## Stop Conditions

- Any change would require introducing `sourceDetailBias` or metadata
  compensation. Halt — that is Phase 4.
- A recipe auto-application would change existing output at
  `detailSoftness == 0`. (Cannot happen if recipes don't write the key,
  but flagged as a hard line.)
- UI exposure requires broad redesign of the Advanced surface rather
  than adding one control to the existing Optics group.
- `bun run verify:ios` or `verify:macos` fails because Phase 1 Swift
  positional inits are out of sync. Halt and fix Phase 1 first.

## Copy / History Impact

UI exposure adds two short copy rows on each platform:

- `Detail softness` label (EN / JA both fall back to EN per the iOS
  paramLabels convention, like every non-motion param).
- Help body / effect / guidance copy for the slider, scoped to
  sensor-detail acutance reduction.

No App Store metadata, LP, release notes, fastlane, or
`messages/{en,ja}.json` change. No implementation-history claim moves —
`apps/web` Electron 1.0.3 surface is not touched.

`bun run check:filmtone-copy` and `bun run check:filmtone-context` must pass
on this declaration.

## Checklist

- [x] Phase 2 active archived; `strategy.md` Phase 2 status set to
      Complete with the three commit pointers.
- [x] iOS `FilmtoneStrengthSheetData.swift` Optics group + comparison
      style.
- [x] iOS `FilmtoneStrings.swift` `paramLabels` row + help copy case.
- [x] Desktop `AdvancedAdjustCatalog.swift` Optics group.
- [x] Desktop `FilmtoneDesktopStrings.swift` EN + JA label rows.
- [x] Desktop `Verify/main.swift` `iosCanonicalParamLabels` row.
- [x] `bun run verify:ios` PASS.
- [x] `bun run verify:macos` PASS.
- [x] `bash apps/filmtone-desktop-macos/Verify/run.sh` PASS.
- [x] `bun run check:filmtone-copy` PASS.
- [x] `bun run check:filmtone-context` PASS.
- [x] `git diff --check` clean.
- [x] Archive `active.md` →
      `archive/2026-05-12-phase-3-ui-exposure.md`; append 1–3 line
      completion note to `strategy.md` (commit `27a856fa`).

## Implementation Log

### 2026-05-12 JST — Advanced control exposed

- iOS: added `detailSoftness` to the Optics group immediately after
  `lensSoftness`, reused the existing `.softness` comparison style, and
  added the canonical `Detail softness` label plus help copy.
- macOS: added the matching Optics control and label rows; drift detector
  now treats `detailSoftness: "Detail softness"` as canonical.
- Recipe decision: existing recipes remain untouched. `detailSoftness` is a
  separate sensor-acutance axis, not a lens-character or diffusion-filter
  preset stamp.

**Verification gates run**

| Gate | Result |
|---|---|
| `bun run verify:macos` | BUILD SUCCEEDED. |
| `bash apps/filmtone-desktop-macos/Verify/run.sh` | 124 / 124 passed. |
| `bun run verify:ios` | EXIT 0. |
| `bun run check:filmtone-copy` | PASS. |
| `bun run check:filmtone-context` | PASS. |
| `git diff --check` | Clean. |

## Read-only references

- Phase 1 archive:
  `archive/2026-05-12-phase-1-contract-neutral-plumbing.md`.
- Phase 2-A archive: `archive/2026-05-12-phase-2a-research-charter.md`.
- Phase 2 archive: `archive/2026-05-12-phase-2-renderer-parity.md`.
- Copy harness: `docs/filmtone/filmtone-copy-quality-harness.md`.
- Source plan: `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`.
