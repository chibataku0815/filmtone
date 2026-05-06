# Active: M5-H.2 Adjustment / Library Parity

Date opened: 2026-05-05 JST (M5-H lane parallel branch)

## Milestone

M5 Native Editing UI / 5-gap follow-up `M5-H.2`. Sister branches:
M5-H.1 (chrome layout), M5-H.3 (dual LUT spike), M5-D.2 (AVPlayer
spike). Each runs in its own worktree off `65e3f3f6`.

## Goal

Bring the Native Desktop Adjust panel + Saved Look library up to iOS
canonical parity in two visible dimensions:

1. Advanced Adjust parameter labels match the iOS canonical
   `FilmtoneStrings.paramLabels` + group titles (so a label saved on
   one platform reads as the same control on the other), and each
   group surfaces the iOS `standardAdvancedRecipes` chips
   (`なし` / `標準` / `強め`) — plus the four-chip tone variant
   (`Standard` / `Airy` / `Sunset` / `Depth`) for the `process`
   group.
2. Saved Looks become operable: rename, delete, favorite via Mac-
   native idioms. iOS uses a context menu — we surface the same three
   actions inline beside the Picker (always-visible glass buttons that
   light up only when the currently-selected Look is user-saved).

Backlight Veil is investigated and intentionally not added in this
slice — see `Backlight Veil decision` below.

## Why this slice

`feature/native-desktop-m5-g` closed M5-G architecture thin cuts; the
v1.4 user smoke surfaced that:

- Advanced Adjust labels diverge from the iOS canonical strings, so
  the user can't trust that the same slider name means the same param
  across platforms.
- Adjust panel has no recipe chips, forcing the user to discover the
  iOS-canonical "Default / Strong" presets manually one slider at a
  time.
- Saved Looks have no rename / delete / favorite path — the user can
  Save and Apply but can't curate.

Closing all three is a Library / Adjustment parity gap that the same
release cycle closes for iOS (v1.4 already ships these on iOS).

## Scope

### In

1. **`Domain/AdvancedAdjustCatalog.swift`**
   - Relabel keys to match iOS canonical (`rgbShift` → "Color
     fringing", `grainIntensity` → "Grain Strength", `grainRadialMix`
     → "Grain edge emphasis", `compressionAmount` → "Highlight
     softness", `compressionRange` → "Tone span", `trailIntensity` →
     "Trail Length", `lensSoftness` → "Lens softness", group `process`
     → "Tone").
   - Add `Recipe` value type (`id`, `label`, `values: (FilmtonePhase0Params) -> [String: Double]`).
   - Wire `standardAdvancedRecipes(default:strong:)` for the optics /
     glow / grain / motion groups; tone-specific 4-recipe variant for
     the `process` (now "Tone") group; basic group remains chip-less
     to mirror iOS.
2. **`State/EditorState+ParamOverrides.swift`**
   - Add `resolvedBaseWithoutOverrides()` helper (resolves preset + look
     + strength + quick **without** the overrides patch — what the
     recipes' `base` closure receives).
   - Add `applyAdvancedRecipe(values:in group:)` — overlays recipe
     keys onto `paramOverrides` (clamped via catalog), and clears
     non-recipe keys *within the same group* so chip selection acts as
     a group preset, not an additive overlay.
   - Add `clearGroupOverrides(in group:)` — clears every key in a
     group (the `なし` / `none` / `Standard` chip path).
3. **`UI/AdvancedAdjustEditor.swift`**
   - Per group, render a `Recipe chip row` above the slider list when
     `group.recipes` is non-empty. Chips use `.buttonStyle(.glass)` +
     `.controlSize(.small)`; the active recipe (best-match heuristic)
     rendered with `.glassProminent` so the user sees current state.
   - Spacing: 8 / 12 / 16 ladder (no off-grid pixel values).
4. **`UI/LookLibraryControls.swift`**
   - Below the picker, render an inline action row with three
     glass buttons — `★` favorite toggle, `Rename…`, `Delete`.
     Disabled (greyed) when the current selection is `None` or a
     built-in (Stone / Urban). Native NSAlert prompts for rename + a
     destructive confirm for delete, mirroring the existing Save
     prompt's modal style.
5. **`State/LibraryViewModel.swift`**
   - Wrappers `renameLook(id:newName:)`, `toggleFavorite(id:)`,
     `deleteLook(id:)` that call into the actor and surface
     `lastError` on failure (built-in immutability path).
6. **`Color/FilmtoneSavedLookStore.swift`**
   - Add `renameLook(id:newName:)` (rejects built-in via the existing
     `immutableEntry` error), `setFavorite(id:favorite:)`. Both atomic
     per-entry writes + index update, like `saveLook`. `deleteLook`
     already exists — no change there.
7. **`Verify/main.swift` + `Verify/run.sh`**
   - Add `Color/FilmtoneSavedLookStore.swift` to `SOURCES` so the
     harness can exercise the new store API.
   - Test group 10: AdvancedAdjustCatalog labels match iOS canonical
     spec (drift detector — fails if a relabel slips).
   - Test group 11: catalog recipes — every recipe key resolves
     through `FilmtonePhase0Params.keyPaths`; `Default` / `Strong`
     never lower a value where the iOS recipe `max(...)` semantics
     would raise it (sample check on a few keys).
   - Test group 12: SavedLookStore rename / favorite / delete round-
     trip on a temp directory — bundled-id rename / delete must
     `throw .immutableEntry`; user entry rename mutates `.name` +
     `updatedAt` and survives `loadOrRebuild()`; favorite toggle
     persists across reload.

### Out (deferred / out of scope)

- **Backlight Veil exposure on the Adjust panel.** See the dedicated
  decision section below — Native Desktop's render pipeline does not
  consume `OpticalFilterProfile` yet, so adding a `Backlight Veil`
  control would require either an entirely separate optical-filter
  selector (different layer than per-param sliders) or surfacing the
  3 named density profiles as canned recipes against a non-existent
  consumer, both of which exceed M5-H.2's parity scope. Tracked as a
  future M5-O slice.
- AdjustmentHelpSheet equivalent (per-control help text + before/after
  comparison cards). M5-H.2 mirrors data parity, not the help / topic
  layer.
- Search / filter across the 31 controls.
- Per-control help bubbles, drag-to-default haptics, keyboard
  shortcuts.
- Library import / quota / orphan GC (still tracked for M5-C.2c).

## Approach

Backend first (store), then view model, then UI, then catalog labels,
then recipes, then editor chips, then library row buttons, then verify
extension. Build after each meaningful seam to catch regressions
before stacking.

## Backlight Veil decision

Investigated. Conclusion: do not surface Backlight Veil from
`AdvancedAdjustEditor` in this slice.

Evidence:

- Backlight Veil ships in `packages/film-lab-core/src/optical-filter-profiles.ts`
  as 3 density profiles (`backlightVeil-1-8` / `-1-4` / `-1-2`) and is
  exposed in `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx` as
  an optical-filter family (alongside `blackMist`, `cineBloom`, etc).
- iOS canonical `FilmtoneStrengthSheetData.advancedParamGroups` does
  **not** include a Backlight Veil control — Backlight Veil isn't a
  per-param slider, it's a named filter that bundles bloom / halation
  / diffusion field values together.
- `apps/filmtone-desktop-macos/FilmtoneDesktop` does not consume
  `OpticalFilterProfile` anywhere. There is no render path that reads
  `.opticalFilterFamily` on the Native Desktop pipeline today —
  `M5-O Optical Filter Family Adoption` would be the slice that adds
  consumption + a family Picker; that's an entirely separate UI seam.

If we tried to fit Backlight Veil into M5-H.2 today the only honest
implementation would be a canned recipe inside the `glow` group that
sets the bloom / halation / diffusion keys to the 3 density profile
values — which would silently rewrite `paramOverrides` rather than
preserve the named "Backlight Veil 1/4" identity, and it would not
match iOS (iOS exposes the optical-filter family as a separate
selector, not a chip on the glow group).

So: no UI addition. Logged as `M5-O` candidate to add a real optical-
filter family selector + Native Desktop pipeline consumer.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift` (modify)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState+ParamOverrides.swift` (modify)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/LibraryViewModel.swift` (modify)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSavedLookStore.swift` (modify)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedAdjustEditor.swift` (modify)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/LookLibraryControls.swift` (modify)
- `apps/filmtone-desktop-macos/Verify/main.swift` (extend)
- `apps/filmtone-desktop-macos/Verify/run.sh` (add SavedLookStore.swift to SOURCES)

No new files → no pbxproj edit required.

## Read-Only References

- iOS canonical:
  - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheetData.swift`
    (group / control / recipe shape)
  - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
    (paramLabels + advanced* labels — drift detector source)
- Backlight Veil reference (read-only):
  - `packages/film-lab-core/src/optical-filter-profiles.ts`
  - `docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/backlight-veiling-glare-implementation-plan-2026-05-03-jst.md`
  - `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/backlight-veil-ios-port-next-chat-handoff-2026-05-03-jst.md`

## Done conditions

- AdvancedAdjustCatalog labels match the iOS spec verbatim (drift test
  green).
- Each non-basic group surfaces its iOS-canonical recipe chips; chip
  tap mutates `paramOverrides` so the slider thumbs jump in lockstep.
- Selected user Look exposes `★` / Rename / Delete inline; built-in
  selection greys all three; rename + favorite + delete round-trip
  through the actor and the snapshot reflects them.
- Backlight Veil decision recorded here (this file).
- `bun run verify:macos` + `apps/filmtone-desktop-macos/Verify/run.sh`
  green (count grows by the new tests).
- `xcodebuild -scheme FilmtoneDesktop -configuration Debug build`
  PASS, Swift 6 strict concurrency clean.

## Out Of Scope

- AdjustmentHelpSheet equivalent (M5-H.2.1 candidate).
- Optical filter family selector + Native Desktop pipeline consumer
  (M5-O candidate — gates Backlight Veil exposure).
- Library LUT subtree (still M5-C.2c).
- Drag / drop / reorder / search.

## Operating mode

Auto-mode. M5-H.2 is a parity slice with iOS canonical strings as the
spec — no novel design judgment. Implementation, build, verify, and
commit autonomously; user does the visual smoke (Save Look → apply →
rename → favorite → delete).

## Status

**Closed 2026-05-05** on `feature/native-desktop-m5-h2-adjust-library`.

Implementation summary (single commit; see commit message for details):

- `Domain/AdvancedAdjustCatalog.swift`: relabeled to iOS canonical
  (`Color fringing`, `Lens softness`, `Highlight softness`, `Tone span`,
  `Grain Strength`, `Grain edge emphasis`, `Trail Length`); group
  `process` retitled `Tone`; added `Recipe` value type + per-group
  recipes mirroring iOS `standardAdvancedRecipes` (None / Default /
  Strong) and the tone-specific 4-chip variant (Standard / Airy /
  Sunset / Depth). `basic` group keeps no chips per iOS canonical.
- `State/EditorState+ParamOverrides.swift`: `resolvedBaseWithoutOverrides()`,
  `applyAdvancedRecipe(_:in:)`, `clearGroupOverrides(in:)`, plus
  `activeRecipeId(in:)` so the chip row can reflect current state.
- `UI/AdvancedAdjustEditor.swift`: per-group recipe chip row above the
  slider list; chips use `.glass` / `.glassProminent` for inactive /
  active; spacing on 4 / 8 / 12 / 16 ladder.
- `UI/LookLibraryControls.swift`: inline `★ / Rename / Delete` glass-
  button row beneath the picker, Mac-native NSAlert for rename input
  and destructive confirm; built-in selections grey out the row;
  picker entries prefix `★` so the favorite is visible inside the
  menu.
- `State/LibraryViewModel.swift`: `renameLook`, `toggleFavorite`,
  `deleteLook` wrappers that surface actor errors as `lastError`.
- `Color/FilmtoneSavedLookStore.swift`: `renameLook`, `setFavorite`
  added; both reject built-in entries with `.immutableEntry` to mirror
  the existing `deleteLook` posture and persist atomically.
- `Verify/main.swift` + `Verify/run.sh`: `FilmtoneSavedLookStore.swift`
  added to SOURCES; new test groups 10 (label parity), 11 (recipe
  shape + clamp invariants), 12 (store rename / favorite / delete /
  immutability) — Verify 42 → 52, 0 failed.
- `xcodebuild -scheme FilmtoneDesktop -configuration Debug build`:
  BUILD SUCCEEDED, Swift 6 strict concurrency clean. Only Xcode-level
  noise was the destination disambiguation message.

Backlight Veil: deferred per the decision section. No UI added.

Visual smoke (Save Look → apply → rename → favorite → delete +
recipe chip cycle on each non-basic group) is user-driven.

Out-of-scope follow-ups recorded above (M5-O optical filter family
selector, M5-H.2.1 AdjustmentHelpSheet equivalent, M5-C.2c LUT
library subtree).

## Post-review P2 fixes (2026-05-05, follow-up commit)

Reviewer flagged two parity gaps after the initial commit. Both fixed
in a follow-up commit on the same branch:

1. **Quick / paramOverrides resolve order** — `FilmtonePresetCatalog
   .resolved` was applying paramOverrides before Quick (`preset →
   override → Quick`), opposite to iOS canonical
   `FilmtonePhase0Math.resolveParams` (`preset → Quick → override`).
   Effect: any user-overridden key (recipe stamp or direct slider)
   silently picked up an extra Quick delta on Desktop, so a recipe
   value `max(base.bloomStrength, 0.34)` rendered at `0.34 + Quick`
   on Desktop while iOS rendered at `0.34`. The Adjust panel slider
   also showed a different number than the rendered preview for the
   same reason. Swap landed in `Color/FilmtonePresetCatalog.swift`.
   The M5-C.3a Test group 6 was rewritten — its previous assertion
   (`override + Quick*weight`) was Desktop-current behavior
   incorrectly labeled "iOS canonical"; it now asserts override-
   wins-absolute and adds a regression test that recipe stamps +
   Quick land at the recipe value (not the doubled value).
2. **`FilmtonePhase0ParamsPatch.normalized(over:)`** — added as a
   Desktop-local extension on top of `AdvancedAdjustCatalog.clamp` +
   tolerance `0.0001`, mirroring iOS so trivial overrides that
   happen to match the post-Quick base drop out of the saved patch
   instead of pinning identity entries.
3. **Built-in Saved Look favorite** — Desktop refused with
   `.immutableEntry`; iOS allows favoriting built-ins via a
   UserDefaults-backed map (rename / delete still immutable).
   Implemented the same split: `FilmtoneSavedLookStore` now reads /
   writes `filmtone.library.builtInFavorites` from injected
   `UserDefaults` (default `.standard`). `setFavorite(id:favorite:)`
   dispatches built-in ↔ user; `currentSnapshot()` overlays the map
   onto the materialized bundled entry; rename / delete still throw
   `.immutableEntry` for built-ins. `LookLibraryControls`
   `selectedAnyLook` enables the favorite button regardless of
   bundled status, while `selectedUserLook` continues to gate rename
   / delete. Picker bundled section also gains the `★` prefix.

Verification after follow-up:

- `apps/filmtone-desktop-macos/Verify/run.sh`: 56/56 passed (was
  52, +4: order rewrite + normalized helper + recipe non-double-
  Quick + built-in favorite UserDefaults round-trip).
- `xcodebuild -scheme FilmtoneDesktop -configuration Debug build`:
  BUILD SUCCEEDED. Only warnings are pre-existing
  `FilmtoneGradeKernels.swift` Core Image Kernel deprecation and a
  pre-existing main-actor `bounds` warning in
  `ExportInspectorPanel.swift:262`; nothing new introduced by this
  follow-up.

Backlight Veil decision unchanged — still defer to M5-O. The
follow-up does NOT touch any other resolve path (look apply,
sidecar `gradeParams`, CLI export) — those all route through
`FilmtonePresetCatalog.resolved` so they pick up the canonical
order automatically.

## Post-review P1 fix (2026-05-05, third commit)

Reviewer flagged that the Test group 6 first assertion (`resolved
order: Quick then paramOverrides — overrides win absolute`) was
non-deterministic across hosts: it iterated
`FilmtonePhase0Generated.quickWeights[axis]` (a `[String: Double]`
dictionary) in unspecified order, so on some hosts it picked
`grainIntensity` and the chosen `absoluteValue = 0.123` got rounded
to the catalog max `0.1` by `AdvancedAdjustCatalog.clamp`,
making the equality assertion fail.

Fix: iterate axes / keys in sorted order, pick a key where the
chosen `absoluteValue` survives `clamp` unchanged AND differs from
`base + Quick` by more than `paramEqualityTolerance` so the
`normalized(over:)` step keeps the override. Same pattern applied
to the recipe non-double-Quick test for symmetry. 3 consecutive
local runs returned `56/56 passed, 0 failed` with the targeted
PASSes stable.

### Known follow-up (not a merge blocker, recorded for next slice)

Reviewer also noted: `normalized(over:)` runs inside
`FilmtonePresetCatalog.resolved` but is **not** routed back into
`EditorState.paramOverrides`. So a user-set override that happens to
match `base + Quick` within tolerance still counts toward
`paramOverridesActiveCount` (drives the QuickAdjust override chip
and the AdvancedAdjustEditor header badge) and still ends up in the
`SaveLookPayload` written to disk — even though it has zero render
effect. The conservative fix is to normalize the patch at
`paramOverridesActiveCount` / `currentLookSavePayload()` read time
(don't mutate `setParamOverride` so the slider's binding stays
stable mid-drag). Tracked as `M5-H.2.2` follow-up.
