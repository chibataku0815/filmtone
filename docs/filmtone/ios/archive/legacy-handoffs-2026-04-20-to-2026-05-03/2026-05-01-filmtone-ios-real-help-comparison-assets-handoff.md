# Filmtone iOS Real Help Comparison Assets Handoff

Date: 2026-05-01 12:32 JST
Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
Target app: `apps/capacitor-film-lab-ios/`

## Current State

The iOS adjustment help UI has been implemented and committed on `main`.

Commit:

```text
832e841 feat(ios): add adjustment help sheets
```

What that commit added:

- Help buttons on the iOS strength sheet for:
  - overall Strength
  - Adjust / quick adjustment section
  - Exposure / Contrast / Saturation quick controls
  - Advanced Params section
  - each Advanced group: Tone, Optics, Glow, Grain, Motion
  - each individual advanced parameter
- A reusable `FilmtoneAdjustmentHelpSheet`.
- A SwiftUI-rendered before/after-style comparison visual.
- Japanese and English help copy in `FilmtoneStrings.swift`.
- Snapshot test coverage / identifiers were also adjusted in the same committed work.

Important correction:

The current comparison visual is **not a real comparison image file**. It is a SwiftUI-drawn abstract sample view inside `FilmtoneStrengthSheet.swift`. It does not use the user's actual media, does not use generated PNG/HEIC assets, and does not show actual Filmtone render output.

The next task is to replace or augment that placeholder with real comparison image files generated from real source footage.

## Current Worktree

At handoff time:

```text
## main...origin/main [ahead 1]
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift
 M apps/capacitor-film-lab-ios/ios/App/App/Localizable.xcstrings
```

Uncommitted diff in `FilmtoneRootView.swift` only moves/removes accessibility identifiers:

- removes `filmtone.section.presets` from the `presetSection` container call site
- removes `filmtone.activePreset.label` from the active preset title
- adds `filmtone.section.presets` to the `FilmtoneSectionHeader` inside `presetSection`

Do not revert this unless the user explicitly asks. Inspect it before making snapshot or accessibility edits.

Uncommitted diff in `Localizable.xcstrings` adds the `filmtone.preset.default` localized key (`Default` / `デフォルト`) and a trailing newline. This appears related to the already committed `presetDefaultLabel` usage. Inspect it and keep it if the next work touches localization.

## Verification Already Run

These passed after commit `832e841` was created:

```bash
git diff --check
bun run verify:ios
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

The `xcodebuild` output included existing Core Image deprecation warnings in `FilmtoneExportSession.swift`; no build failure remained.

## User Intent

The user wants the help sheets to show real visual differences:

- Not abstract illustrations.
- Not marketing-style decorative graphics.
- Real comparison image files created from actual source footage.
- The attached videos are likely appropriate source material and should be used as reference/input.

User-provided source files:

```text
/Users/chibatakumi/Downloads/6608500_Intimate Lighter Warm Glow Cozy Ambiance_By_Pressmaster_Artlist_HD.mp4
/Users/chibatakumi/Downloads/6454597_Woman Hand Gua Sha Window_By_Zed_Artlist_HD.mp4
```

Likely use:

- `6608500_Intimate Lighter Warm Glow...`
  - best for Glow, Bloom, Halation, Highlight softness, warm tone, light-source comparisons
- `6454597_Woman Hand Gua Sha Window...`
  - best for skin, window light, exposure, contrast, saturation, softness, grain, tone/process comparisons

The next chat should inspect the actual video frames before choosing timestamps.

## Product Quality Target

The help image should teach users what the control does at a glance. The image must be truthful enough that the user can connect slider movement to visual effect.

Preferred output:

- A small curated set of real before/after image pairs, not one asset per every low-level parameter unless that is clearly worth it.
- Individual parameters may map to shared effect families:
  - Exposure
  - Contrast / Print Contrast
  - Saturation / CMY balance
  - Highlight softness / compression
  - Optics / softness / vignette / color fringing
  - Glow / bloom
  - Halation
  - Diffusion
  - Grain
  - Motion
  - Strength / overall look
- Each pair should be generated from the same source frame and crop.
- The "after" side should visibly demonstrate the effect without becoming exaggerated or ugly.
- The comparison image should fit the existing iOS dark help sheet and remain legible on small screens.

Avoid:

- Generic stock thumbnails unrelated to the controls.
- SwiftUI-only fake drawings.
- Overly subtle pairs where the difference is invisible.
- Overcooked examples that misrepresent Filmtone's export quality.
- Adding a new guide/settings screen before the help asset integration is good.

## Candidate Implementation Plan

Start by following repo routing:

1. Read `AGENTS.md`.
2. Run `git status --short --branch`.
3. Open `apps/capacitor-film-lab-ios/CLAUDE.md`.
4. Go directly to the exact iOS surfaces:
   - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift`
   - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
   - existing asset catalog / bundle conventions under `apps/capacitor-film-lab-ios/ios/App/App/Assets.xcassets`

Suggested work sequence:

1. Inspect the two MP4s and pick timestamps/crops.
   - Use a real frame extraction path such as `ffmpeg`, `AVAssetImageGenerator`, or a small local script.
   - Prefer frames with visible faces/skin, highlights, light sources, and clean shadow areas.
2. Generate before frames.
   - Same crop/aspect for every pair.
   - Use a compact help-sheet-friendly resolution, for example 900x520 or similar.
3. Generate after frames.
   - Highest quality path: use Filmtone's actual native/CoreImage pipeline or the closest local rendering path already in the app.
   - If a full app render pipeline is too heavy, create a clearly named asset-generation script that applies deterministic CoreImage/AVFoundation transforms matching the effect family. Do not present these as export-parity fixtures unless they really are.
4. Store image files in the iOS app bundle.
   - Prefer `Assets.xcassets` if that matches existing Xcode conventions.
   - Use explicit names such as:
     - `HelpCompareExposureBefore`
     - `HelpCompareExposureAfter`
     - `HelpCompareGlowBefore`
     - `HelpCompareGlowAfter`
   - Or use pair-oriented names if more ergonomic:
     - `HelpCompareExposure.before`
     - `HelpCompareExposure.after`
5. Replace the SwiftUI placeholder comparison renderer.
   - Current placeholder lives in `FilmtoneStrengthSheet.swift` around `FilmtoneHelpComparisonImage` / `FilmtoneHelpSampleFrame`.
   - Replace with an image-backed view that displays the relevant before/after files.
   - Keep labels from `store.strings.adjustmentHelpBeforeLabel` and `store.strings.adjustmentHelpAfterLabel`.
   - Preserve accessibility identifiers already added for help sheets where possible.
6. Map help topics to image pairs.
   - The existing enum is `FilmtoneAdjustmentComparisonStyle`.
   - It currently drives abstract SwiftUI styles.
   - Rework it into asset selection, for example `var assetPair: FilmtoneHelpComparisonAssetPair`.
7. Verify.
   - Run `git diff --check`.
   - Run `bun run verify:ios`.
   - Run the documented `xcodebuild` command if Swift / asset catalog changes are made.
   - If snapshot tests are affected, update only the intended assertions and keep the change narrow.

## Existing Files To Understand

Committed help UI:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift
```

Related UI and snapshot surfaces:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift
apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift
```

Rendering / color pipeline candidates if using real app logic:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneColorPipeline.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtonePreviewView.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
```

Generated Swift warning:

Do not hand-edit:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift
```

Regenerate through the documented script only if needed.

## Acceptance Criteria

The next task is done when:

- Real image files exist in the app bundle or asset catalog.
- The images are derived from the provided MP4s or another explicitly selected real source.
- The help sheet uses those files rather than SwiftUI-drawn placeholder samples.
- The same help topic consistently shows the correct effect family.
- At least these effect families have real image-backed comparisons:
  - overall Strength / Look intensity
  - Exposure
  - Contrast
  - Saturation / color density
  - Tone / print process
  - Optics
  - Glow / Bloom
  - Halation
  - Grain
  - Motion, if a video-motion comparison can be made honestly as a still
- The visual difference is clear on an iPhone-sized help sheet.
- The image styling does not occlude labels or compress text awkwardly.
- `git diff --check` passes.
- `bun run verify:ios` passes.
- `xcodebuild ... CODE_SIGNING_ALLOWED=NO` passes if Swift or asset catalog integration changed.

## Risks And Decisions For Next Chat

1. Real render path vs illustrative asset-generation script
   - Best product truth: generate after images using actual Filmtone rendering code.
   - Faster but weaker: generate after images using a local CoreImage script that approximates effect families.
   - If approximation is used, name it honestly in the asset-generation script and do not claim export parity.

2. Number of assets
   - Do not create 30+ pairs immediately unless the UI really benefits.
   - A curated family set is likely higher quality and easier to maintain.

3. Motion as a still
   - Motion blur/trail is harder to explain from one still.
   - Use a frame with hand movement or camera movement if available.
   - If the chosen footage does not show motion clearly, create only the family mapping needed now and document that Motion needs a better clip.

4. Asset licensing / provenance
   - The user provided local Artlist MP4 files as reference/input.
   - Do not commit source MP4 files.
   - Commit only generated compact help images if the user accepts that they belong in-app.

5. Dirty worktree
   - `FilmtoneRootView.swift` has an uncommitted accessibility identifier adjustment at handoff time.
   - Work with it; do not revert silently.

## Suggested Asset Taxonomy

Recommended first pass:

```text
HelpCompareStrengthBefore / HelpCompareStrengthAfter
HelpCompareExposureBefore / HelpCompareExposureAfter
HelpCompareContrastBefore / HelpCompareContrastAfter
HelpCompareSaturationBefore / HelpCompareSaturationAfter
HelpCompareToneBefore / HelpCompareToneAfter
HelpCompareOpticsBefore / HelpCompareOpticsAfter
HelpCompareGlowBefore / HelpCompareGlowAfter
HelpCompareHalationBefore / HelpCompareHalationAfter
HelpCompareGrainBefore / HelpCompareGrainAfter
HelpCompareMotionBefore / HelpCompareMotionAfter
```

Possible mapping:

```text
strength -> Strength
quick -> Strength or Exposure/Contrast/Saturation montage only if implemented
exposure -> Exposure
contrast, printContrast -> Contrast
saturation, colorBalance, cyan, magenta, yellow -> Saturation or Tone
highlight, compressionAmount, compressionRange -> Tone or Highlight
optics, softness, vignette, colorFringe -> Optics
glow, bloom -> Glow
halation -> Halation
diffusion -> Optics or Glow depending on generated sample
grain -> Grain
motion -> Motion
advanced -> Tone
```

## Ready-To-Paste Next Chat Prompt

```text
We are continuing Filmtone iOS work in:

/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

Read AGENTS.md first, run git status --short --branch, then open apps/capacitor-film-lab-ios/CLAUDE.md. Do not do broad repo discovery. This is an iOS product-surface task.

Context:
- Commit 832e841 feat(ios): add adjustment help sheets is already on main.
- That commit added help buttons and help sheets for iOS adjustment categories and parameters.
- The current help comparison visual is only a SwiftUI-drawn abstract placeholder in FilmtoneStrengthSheet.swift. It is not a real comparison image file and not actual render output.
- The user explicitly wants real material-based comparison image files.
- At handoff time main is ahead of origin/main by 1 commit, and FilmtoneRootView.swift has a small uncommitted accessibility identifier diff. Inspect it and do not revert it silently.

Use these source videos as the primary reference/input:

/Users/chibatakumi/Downloads/6608500_Intimate Lighter Warm Glow Cozy Ambiance_By_Pressmaster_Artlist_HD.mp4
/Users/chibatakumi/Downloads/6454597_Woman Hand Gua Sha Window_By_Zed_Artlist_HD.mp4

Goal:
Create and integrate real before/after comparison image files for the iOS adjustment help sheets.

Requirements:
- Use real frames from the provided MP4s or another explicitly selected real source.
- Do not commit the MP4 source files.
- Commit only compact generated help images if they are intended to ship in the app.
- Replace or augment the current SwiftUI fake comparison renderer with image-backed comparisons.
- Preserve the existing help sheet UI and copy unless a small change improves the product.
- The images must clearly show how each effect family changes the image.
- Prioritize product quality over conservative minimalism, but keep outer QA/documentation minimal until the core visual result is good.
- Use sequential-thinking for the asset/rendering strategy and any tradeoff between actual Filmtone rendering and an approximation script.
- If AVFoundation/CoreImage/asset catalog behavior is uncertain, search or inspect official docs; do not guess.

Target files to inspect first:
- apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift
- apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift
- apps/capacitor-film-lab-ios/ios/App/App/Assets.xcassets
- apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift

Potential rendering files if using the real pipeline:
- apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
- apps/capacitor-film-lab-ios/ios/App/App/FilmtoneColorPipeline.swift
- apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift
- apps/capacitor-film-lab-ios/ios/App/App/FilmtonePreviewView.swift
- apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift

Acceptance criteria:
- Real image-backed comparisons exist for at least:
  Strength, Exposure, Contrast, Saturation, Tone/Process, Optics, Glow/Bloom, Halation, Grain, and Motion if the footage supports it.
- Each pair uses the same source frame/crop for before and after.
- Differences are visible on iPhone-sized help sheets but not overcooked.
- Current help topics map to the correct asset pair.
- No generated Swift is hand-edited.
- git diff --check passes.
- bun run verify:ios passes.
- xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO passes if Swift or asset catalog integration changed.

When done, summarize:
- generated asset names and source timestamps
- how each help topic maps to assets
- verification run
- known visual limitations or follow-up footage needs
```
