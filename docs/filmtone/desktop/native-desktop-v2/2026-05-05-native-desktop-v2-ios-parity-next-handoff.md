# Native Desktop v2 iOS Parity Next Handoff

Date: 2026-05-05 JST
Branch: `feature/native-desktop-plan`
Current parent worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`

## Current Commit State

- Current integrated HEAD: `f0e81e71`
  (`Update native desktop v2 plan after M5-K`)
- Product integration commit immediately before that: `6097acdd`
  (`Integrate M5-K native desktop polish`)
- M5-K integration base: `0b79861f`
- Push has not been done.
- The user visually confirmed the latest Debug app after the scrub thumbnail
  hover fixes.

Known untracked files at handoff time are unrelated DHM / evidence artifacts:

```text
docs/filmtone/desktop/native-desktop-v2/active.md
docs/filmtone/desktop/native-desktop-v2/archive/2026-05-05-dhm-*.md
docs/filmtone/desktop/native-desktop-v2/evidence/
```

Do not delete, move, stage, or rewrite those unless the user explicitly asks.
They are not part of the next Native Desktop parity task.

## Required Start Rules For The Next Chat

Follow `AGENTS.md` exactly:

1. Read `AGENTS.md`.
2. Run `git status --short --branch`.
3. Read
   `docs/filmtone/desktop/native-desktop-v2/strategy.md`.
4. Inspect the current `active.md` if present.
5. Do not implement without exactly one scoped `active.md` for the chosen slice.

There may already be a DHM `active.md`. If so, do not overwrite it silently.
Either ask the user whether to pause/replace it, or create implementation work
only after the active-task situation is resolved according to `AGENTS.md`.

## Product Context So Far

Native Desktop v2 is intended to replace the Electron Desktop product lane as
Desktop v1.4, aligned with iOS v1.4. The product goal is not a separate Mac-only
editor; the Mac app should feel like the native desktop expression of the iOS
Filmtone product model.

Current product direction:

- iOS remains the canonical product, color, and optics reference.
- Apple Liquid Glass should be used for control surfaces.
- Loaded media preview content must remain glass-free for color judgment.
- Compare, scrub, Look, strength, advanced parameters, source normalization,
  export, and sidecar behavior must stay preview/export-consistent.
- Product quality is the priority.

M5-K was integrated on the parent branch:

- K1: toolbar icon stability + opening readability.
- K2: Look picker and Look strength grouped into one conceptual control.
- K3: draggable before/after compare bar for still and video preview.
- K4: hover/drag video scrub thumbnail preview.

M5-K verification before commit:

```bash
bash apps/filmtone-desktop-macos/Verify/run.sh  # 86/86 passed
bun run verify:macos                            # xcodebuild Debug succeeded
git diff --check                                # clean
```

The latest Debug app was launched and visually checked by the user after the
scrub thumbnail follow-up fixes.

## New User-Reported Gaps

The user compared the Native Desktop app with iOS and identified three product
parity gaps:

1. iOS automatically chooses an appropriate conversion / camera LUT for the
   selected source to some degree, but Native Desktop does not provide an
   equally useful automatic behavior.
2. Native Desktop lacks the Backlight Veil optical filter / effect.
3. The advanced editing parameters do not expose the iOS-style preset buttons:
   `なし` / `標準` / `強め` (`None` / `Default` / `Strong`) where the user
   expects them.

Screenshot evidence provided by the user:

```text
/Users/chibatakumi/Downloads/スクリーンショット 0008-05-05 19.52.12.png
```

The screenshot shows the iOS Filmtone strength/advanced sheet:

- Header: `Filmtone`
- Top selected Look / profile label: `デフォルト`
- Section `階調`: selected `標準`; chips `標準`, `爽やか`, `夕景`, `深み`
- Section `光学`: selected `なし`; chips `なし`, `標準`, `強め`
- Section `グロー`: selected `なし`; chips `なし`, `標準`, `強め`
- Lower `グレイン` section begins below the visible area.

The user's complaint about missing buttons should be understood against that
iOS sheet. The desktop implementation may already have some recipe-chip plumbing
in a popover, but the product surface is not matching the iOS affordance or
discoverability that the user expects.

## Current Code Facts

### Source Profile / Conversion LUT

iOS canonical references:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`
- `apps/capacitor-film-lab-ios/src/features/editor/CameraProfilePill.tsx`
- `apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings`

iOS behavior worth preserving:

- `CameraProfileSelection.auto` is a sentinel, not a catalog entry.
- Auto resolves from probe metadata / color class.
- Apple Log and Apple Log 2 can be auto-detected and surfaced as
  `Auto -> Apple Log detected` or `Auto -> Apple Log 2 detected`.
- Manual choices for non-detectable log profiles stay sticky across source
  changes where appropriate.
- The source profile / camera LUT is source-side normalization, separate from
  creative Look LUTs.

Desktop references:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSourceProfileCatalog.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSourceInputTransform.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSourceProfileMath.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/SourceProfileControls.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneStillExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift`

Desktop already has important pieces:

- `CameraProfileSelection.auto`
- source profile catalog parity with iOS slugs
- source probe color class
- source input transform cube generation
- preview / export wiring that passes `sourceProfileSelection`
- Source Profile right-rail control with `Auto` and catalog entries
- `Detected: <entry>` caption for Auto when a detection hint resolves

Likely gap:

- The desktop behavior is technically present but not product-equivalent.
  The user perceives that Native Desktop does not automatically choose a useful
  conversion LUT/profile for selected media. The next chat must verify whether
  this is:
  - a real behavior bug in probe / auto resolution,
  - a UI communication/discoverability problem,
  - a missing iOS source-change retention rule,
  - or a still-image vs video discrepancy.

Do not assume the fix is only copy. Test with source probes and inspect how
`probedSourceColorClass` is set for stills and videos.

### Backlight Veil

Relevant shared/web references:

- `packages/film-lab-core/src/optical-filter-profiles.ts`
- `packages/film-lab-core/src/optical-filter-profiles.test.ts`
- `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx`

`Backlight Veil` appears in the shared/web optical filter profile catalog:

- `backlightVeil-1-8`
- `backlightVeil-1-4`
- `backlightVeil-1-2`

Descriptions in the shared catalog frame it as source-reactive haze / veiling
glare for window and sun backlight while protecting shadows.

Native Desktop current likely state:

- The macOS native color pipeline has bloom / halation / diffusion / vignette /
  grain / edge optics primitives.
- It does not expose a Backlight Veil product control as a named optical filter.
- It likely does not carry the `optical-filter-profiles.ts` profile family into
  native Swift.

The next chat should decide whether Backlight Veil is a v1.4 parity blocker or
a scoped follow-up, then implement the smallest native surface that matches the
iOS/product expectation without widening into the whole optical filter library.

Important constraint:

- Do not compromise color judgment in the preview layer.
- If Backlight Veil changes render params, it must affect preview and export
  consistently and should sidecar/Look-save correctly if it is user state.

### Advanced Parameter Preset Buttons

iOS canonical references:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheetData.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneAdvancedParamsModel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`

iOS shape:

- `basic` group has no recipe chips.
- `process` / tone group has four chips:
  `標準`, `爽やか`, `夕景`, `深み`
  (`Standard`, `Airy`, `Sunset`, `Depth`)
- `optics`, `glow`, `grain`, and video-only `motion` use:
  `なし`, `標準`, `強め`
  (`None`, `Default`, `Strong`)
- The selected chip is visible at the group level.
- The chips are near the group title and before individual sliders.

Desktop references:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedAdjustEditor.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState+ParamOverrides.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/FilmtoneDesktopStrings.swift`
- `apps/filmtone-desktop-macos/Verify/main.swift`

Desktop already has some machinery:

- `AdvancedAdjustCatalog` defines iOS-like recipe chips.
- `AdvancedAdjustEditor` renders recipe chip rows inside disclosure groups.
- `EditorState.applyAdvancedRecipe(...)` applies them.
- Verify tests already assert the iOS labels:
  `None` / `なし`, `Default` / `標準`, `Strong` / `強め`, plus tone recipes.

Likely product gap:

- The chips are hidden inside a desktop popover behind `Quick` -> `Adjust...`.
- Initial expanded group is only `basic`, which has no recipe chips.
- Therefore the user can open the obvious editing surface and still not see
  the iOS-style `なし` / `標準` / `強め` controls.
- The next chat should treat this as a product surface / discoverability gap,
  not necessarily missing data-model support.

Possible direction:

- Keep the current catalog and state methods.
- Redesign or surface the advanced recipe chips so the first visible Desktop
  adjustment experience matches the iOS sheet structure.
- Consider opening `process`, `optics`, `glow`, and `grain` groups by default,
  or moving the group-level recipe rows into a more visible advanced panel.
- Preserve the 4px / 8px spacing discipline and Liquid Glass control posture.
- Avoid nested cards.
- Do not make the preview content glassy.

## Suggested Slice Order

Use one scoped `active.md` per slice. Do not bundle all three if risk is high.

Recommended order:

1. **M5-L1 Source Auto / Conversion LUT Parity**
   - Verify Desktop auto source profile behavior against iOS.
   - Fix probe / retention / UI resolved-state gaps.
   - Acceptance: selecting a source shows the resolved conversion profile
     clearly and applies it consistently to still preview, video preview,
     still export, video export, and sidecar.

2. **M5-L2 Advanced Recipe Chip Discoverability**
   - Make the iOS-like `なし` / `標準` / `強め` and tone recipe controls visible
     and understandable on Desktop.
   - Acceptance: the first advanced editing path visibly exposes the same
     group-level recipe choices as the iOS screenshot, without hiding them
     behind an initially-empty Basic section.

3. **M5-L3 Backlight Veil**
   - Add the Backlight Veil product feature in the native Mac surface.
   - Decide whether to use the existing shared optical profile constants as
     reference data or to implement a native thin subset.
   - Acceptance: Backlight Veil affects preview/export consistently, has clear
     UI affordance, and does not regress existing glow/optics behavior.

If the user wants minimum risk, do M5-L1 first. If the user wants immediate
visual parity with the attached screenshot, do M5-L2 first.

## Verification Expectations

Required before reporting any implemented slice done:

```bash
bash apps/filmtone-desktop-macos/Verify/run.sh
bun run verify:macos
git diff --check
pkill -x Filmtone 2>/dev/null || true
open -n /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
```

Additional verification by slice:

- Source Auto / Conversion LUT:
  - Add or update Verify coverage for source profile auto resolution and
    source-change retention if behavior changes.
  - Manually smoke still and video sources where `probedSourceColorClass` is
    Apple Log / Apple Log 2 / Rec.709 if sample footage is available.
- Advanced recipe chips:
  - Verify `AdvancedAdjustCatalog` and `EditorState.activeRecipeId` behavior.
  - Visual smoke the advanced UI with Japanese locale expectations if possible.
- Backlight Veil:
  - Add unit tests for profile selection / param mapping.
  - Run still and video preview/export smoke because this is render-affecting.

## Non-Goals For The Next Chat

- Do not rewrite the entire Native Desktop UI.
- Do not reintroduce Electron Desktop work.
- Do not change export/sidecar schema unless the feature genuinely requires it.
- Do not collapse Source Profile / Camera LUT and Creative Look LUT into one
  concept. They are separate product layers.
- Do not make loaded media preview content glassy.
- Do not clean unrelated DHM handoff/evidence files.
- Do not stage, commit, push, notarize, or bump portfolio submodules unless the
  user explicitly asks.

## English Handoff Prompt

```text
You are working on Filmtone Native Desktop v2.

Repository/worktree:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan

Base branch:
feature/native-desktop-plan

Current integrated HEAD:
f0e81e71

Important existing commits:
- 6097acdd Integrate M5-K native desktop polish
- f0e81e71 Update native desktop v2 plan after M5-K

First, read:
1. AGENTS.md
2. docs/filmtone/desktop/native-desktop-v2/strategy.md
3. docs/filmtone/desktop/native-desktop-v2/2026-05-05-native-desktop-v2-ios-parity-next-handoff.md
4. docs/filmtone/desktop/native-desktop-v2/active.md if it exists

Critical process constraints:
- Do not implement without exactly one scoped active.md for the chosen slice.
- If active.md is an unrelated DHM task, do not overwrite it silently. Resolve the active-task situation according to AGENTS.md before coding.
- Do not revert unrelated dirty files.
- Do not stage, commit, push, delete stashes, clean old handoff files, or touch unrelated DHM evidence unless explicitly asked.
- Native Desktop v2 replaces the Electron Desktop lane and should align with iOS as Desktop v1.4.
- iOS is the canonical product/color/optics reference.
- Use Apple Liquid Glass for control surfaces, but keep loaded media preview content glass-free for color judgment.
- Preserve shortcuts: Command-O opens media, Command-\ toggles sidebar, V toggles compare, Space toggles video playback.

Current product baseline:
- M5-K1/K2/K3/K4 are integrated on feature/native-desktop-plan.
- The latest Debug app was visually checked after scrub thumbnail hover fixes.
- Verification before handoff was green:
  - bash apps/filmtone-desktop-macos/Verify/run.sh => 86/86 passed
  - bun run verify:macos => xcodebuild Debug succeeded
  - git diff --check => clean

New user-reported parity gaps:
1. iOS automatically chooses an appropriate conversion / camera LUT for selected media to some degree, but Native Desktop does not provide an equally useful automatic behavior.
2. Native Desktop lacks the Backlight Veil optical filter/effect.
3. The advanced editing parameters do not visibly expose the iOS-style preset buttons: None / Default / Strong (Japanese: なし / 標準 / 強め). The user attached an iOS screenshot showing the strength/advanced sheet with Tone chips (標準 / 爽やか / 夕景 / 深み) and Optics/Glow chips (なし / 標準 / 強め).

Relevant references:
- iOS source profile auto:
  - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift
  - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
  - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift
  - apps/capacitor-film-lab-ios/src/features/editor/CameraProfilePill.tsx
- Desktop source profile:
  - apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSourceProfileCatalog.swift
  - apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSourceInputTransform.swift
  - apps/filmtone-desktop-macos/FilmtoneDesktop/UI/SourceProfileControls.swift
  - apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift
  - apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift
- Backlight Veil references:
  - packages/film-lab-core/src/optical-filter-profiles.ts
  - packages/film-lab-core/src/optical-filter-profiles.test.ts
  - packages/film-lab-ui/src/FilmLabControlPanelCore.tsx
- iOS advanced recipe chips:
  - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift
  - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheetData.swift
  - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneAdvancedParamsModel.swift
- Desktop advanced recipes:
  - apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift
  - apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedAdjustEditor.swift
  - apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift
  - apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState+ParamOverrides.swift

Recommended slice order:
1. M5-L1 Source Auto / Conversion LUT Parity
2. M5-L2 Advanced Recipe Chip Discoverability
3. M5-L3 Backlight Veil

For the first slice you choose:
- Create exactly one scoped active.md.
- Keep edits scoped to that slice.
- Prefer existing local patterns and iOS parity over new abstractions.
- Preserve preview/export/sidecar consistency.
- Add focused tests proportional to the changed behavior.
- Run:
  bash apps/filmtone-desktop-macos/Verify/run.sh
  bun run verify:macos
  git diff --check
- Launch the Debug app for visual smoke:
  pkill -x Filmtone 2>/dev/null || true
  open -n /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app

When reporting done:
- State exactly what changed.
- State verification results.
- State remaining product risks.
- Mention any unrelated dirty files intentionally left untouched.
```
