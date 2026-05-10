# 2026-05-06 M8 Empty CTA Click Handoff

This handoff exists because the current chat lost product trust on the Native
Desktop empty-state `素材を開く` CTA. The next chat should continue from this
document and the current `active.md`, but must not assume the latest local UI
experiment is acceptable.

## Current User Request

The user is handing off to a new chat after rejecting the latest attempt.

The rejected state:

- The empty-state `素材を開く` button was made visually larger.
- The opening screen again looked like a card inside a card.
- The user explicitly objected to both.

Important user wording:

- `押下できる範囲がおかしいです`
- `素材の「素」の手前ぐらいまでしかクリック範囲がありません`
- `中のカードの大きさを最大値をして下さい`
- `小さい方に合わせんだよ`
- `なんで素材を開くボタンどんどん大きくしてんの？`
- `またカードインカードになっているし`

Interpretation for the next chat:

- Do not enlarge the `素材を開く` button.
- Do not draw a second obvious inner card / plate inside the already-rounded
  app window.
- If a sizing guide is needed for the opening composition, it should use the
  smaller window side as the maximum layout dimension, but that guide should not
  become another visible card.
- Preserve a compact, native-feeling CTA while making the entire visible CTA
  respond to physical mouse / trackpad clicks.

## Repository And Rules

Repository:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Native Desktop v2 source:

```text
apps/filmtone-desktop-macos/
```

Planning docs:

```text
docs/filmtone/desktop/native-desktop-v2/
```

Current active task:

```text
docs/filmtone/desktop/native-desktop-v2/active.md
```

Follow `AGENTS.md`:

- Start Native Desktop v2 sessions by reading `strategy.md`, then `active.md`.
- Do not implement Native Desktop v2 work without an `active.md`.
- Use `bun`.
- For this surface, primary verification is `bun run verify:macos`, plus the
  smallest interactive check proving physical click behavior.
- Do not revert unrelated dirty worktree changes.
- Do not stage, commit, push, tag, or alter portfolio unless explicitly asked.

## Release Truth As Of 2026-05-06 JST

Truth scripts were run during this handoff.

Desktop:

```text
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Result summary:

- Branch/head: `main @ 4f772587`.
- Native Desktop `MARKETING_VERSION`: `1.5`.
- Native Desktop build: `2`.
- Public update metadata `latestVersion`: `1.5`.
- Latest desktop tag: `desktop-v1.4`.
- Commits after latest tag: `39`.
- Native release notes v1.5 exist.

iOS:

```text
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Result summary:

- Branch/head: `main @ 4f772587`.
- Public App Store version: `1.5`.
- Local Xcode marketing version: `1.6`.
- Local Xcode build: `5`.
- iOS dirty working tree files exist and are unrelated to this Desktop CTA task.

Do not repeat release/version claims without rerunning the truth scripts.

## Dirty Worktree Snapshot

`git status --short --branch` currently shows many unrelated iOS and docs
changes. Do not revert them.

Native Desktop files relevant to this handoff:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `docs/filmtone/desktop/native-desktop-v2/active.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

Untracked / related docs from earlier work include:

- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.5.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-inspector-bottom-hit-testing.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-opening-open-panel-foreground.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-empty-open-button-hit-testing.md`

## Prior Work In This Chat

### 1. Native Desktop v1.5 Release Lane

The user first asked to proceed with the next native desktop release and asked
for the changes to be explained. Release-related docs and files were updated in
this repo. Current truth script output says public Desktop update metadata now
reports `latestVersion: "1.5"`, while the latest local tag is still
`desktop-v1.4`. Treat release truth as script-driven.

This is not the current task. Do not touch release packaging or metadata unless
the user explicitly asks.

### 2. Inspector Bottom Hit-Testing

User reported visible right-rail controls near the bottom of the inspector that
could not be clicked unless scrolled upward. Root cause was the video scrub
overlay occupying a full-window layout region and stealing taps through
transparent bottom / spacer areas.

Relevant current `RootWindowView.swift` changes:

- `videoScrubOverlay(duration:)` scopes hit testing to the visible scrub area.
- Spacer and bottom padding regions use `.allowsHitTesting(false)`.
- Inspector z-index was raised above the scrub overlay.

This fix was accepted enough to move on and should not be casually reverted.

### 3. Empty-State Open Panel Foreground

User reported that clicking `素材を開く` appeared to do nothing.

Investigation found multiple separate issues:

- `NSOpenPanel.runModal()` could appear behind / not feel foregrounded.
- `beginSheetModal` could make the app modal-disabled while the sheet was
  invisible on the transparent Liquid Glass window.
- Toolbar Open and accessibility activation could open the picker, proving the
  import pipeline was not the core issue.

Relevant current `RootWindowView.swift` change:

- `presentOpenPanel()` now guards with `openPanelPresented`.
- It activates the app and raises the target Filmtone window.
- It presents an app-modal `NSOpenPanel` via `panel.begin { ... }`.
- `completeOpenPanel(response:url:)` handles selected media and resizing.

This Open panel route is probably worth preserving unless direct evidence shows
it is causing the current CTA hit-area bug.

## Current Bug

The visible empty-state CTA does not have a matching physical click region.

Observed / reported behavior:

- The CTA is visible.
- The user says only the area up to around just before the first character
  `素` is clickable.
- Scrolling is irrelevant on the empty state; this is a CTA hit-target mismatch.
- Accessibility activation can be misleading because it may work even when
  normal pixel-coordinate clicking fails.

Important test lesson:

- Do not use Computer Use `element_index` clicks as proof. Those can invoke AX
  Press and bypass physical mouse hit testing.
- Use pixel-coordinate clicks from the screenshot and confirm the frontmost
  Open panel appears.

## Failed Attempts

### Failed Attempt A: SwiftUI Plain Button

The original empty state used:

- `GlassEffectContainer`
- bounded luminous plate
- SwiftUI `Button`
- `.buttonStyle(.glass)`
- `.controlSize(.large)`
- `.fixedSize()`

A first attempted fix removed glass button styling and used a plain SwiftUI
Button/capsule style. This produced an ugly focus ring and did not prove the
physical click range was fixed.

Do not repeat that style-only change.

### Failed Attempt B: Custom `NSControl`

A custom `NSViewRepresentable` / `NSControl` was introduced to own the full
visible button bounds. It custom-drew the capsule, icon, and text, overrode
`hitTest`, and called `onOpen()` in `mouseUp`.

Problems:

- Initial version failed compile due a property named `action` conflicting with
  `NSControl.action`.
- Initial icon drawing used a nonexistent `withTintColor` API.
- After compile fixes, a physical right-side coordinate click focused the
  button but did not open the panel.
- The visual became less native.

Do not continue from this exact implementation.

### Failed Attempt C: Oversized Square Opening Plate + Large Custom Button

The most recent rejected code changed `EmptyPreviewLabel` to:

- `GeometryReader`
- visible square opening plate sized to `min(width, height)`
- visible rounded rectangle plate fill/stroke
- custom `OpeningOpenButton`
- button width up to `360`, height `72`

This compiled, but the user rejected it immediately because:

- The button kept getting bigger.
- It still read as card-in-card.

This current local state in `PreviewSurface.swift` is not product-accepted.
The next chat should revise it, not present it as the solution.

## Current Code State To Treat Carefully

`PreviewSurface.swift` currently contains a rejected experiment:

- `EmptyPreviewLabel` uses `GeometryReader`.
- `openingPlate(side:)` draws a visible rounded rectangle background.
- `OpeningOpenButton` is a custom `NSButton` subclass drawn manually.
- The CTA is visually too large.

The next chat should probably remove the visible plate background and return
the CTA to a compact native size. The useful idea to preserve is not the visual
design; it is the need for the visible CTA area to own the actual hit target.

`RootWindowView.swift` contains useful changes:

- scrub overlay hit-testing fix
- raised inspector z-index
- app-modal Open panel presentation guard

Do not revert those without direct evidence.

## Recommended Next Approach

Start by restoring the empty-state visual direction while keeping a robust hit
target:

1. Use an invisible layout square based on `min(proxy.size.width, proxy.size.height)`
   only if needed for composition. Do not draw it as a visible card.
2. Keep the brand stack centered and calm.
3. Keep `素材を開く` compact. Do not increase it beyond a normal large native
   button footprint.
4. Avoid a second visible rounded rectangle plate inside the rounded app
   window.
5. Make physical hit testing match the visible CTA:
   - either use a compact AppKit `NSButton` whose frame exactly matches the
     visual button;
   - or keep a native SwiftUI visual and overlay an invisible AppKit hit target
     with the same frame;
   - but do not make the overlay larger than the visible button unless it stays
     inside the same perceived button affordance.
6. Add temporary logging only if needed to distinguish `mouseUp` delivery from
   `presentOpenPanel()` failure; remove it before finishing.

Do not declare success until pixel-coordinate clicks on the left, center, and
right portions of the visible CTA all open the frontmost Open panel.

## Interactive Verification Procedure

Build:

```bash
bun run verify:macos
git diff --check
```

Launch a fresh app instance:

```bash
osascript -e 'tell application "Filmtone" to quit'
open apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
```

Use Computer Use:

1. Call `get_app_state` for `Filmtone`.
2. Use pixel-coordinate clicks, not element-index clicks.
3. Test at least three points inside the visible CTA:
   - left icon / left pill area
   - center label area
   - right pill area
4. After each successful click, the key/frontmost window should become the Open
   panel. Cancel it before the next coordinate test, or quit/reopen Filmtone.
5. Confirm toolbar Open still opens the same visible panel.

Earlier useful reference coordinate from a 960x768 screenshot:

- Right side of oversized CTA was approximately `x=710, y=552`. It should have
  opened the panel if the visible pill was truly clickable.

Do not rely on focus changes. The failed custom-control attempt could focus the
button without opening the picker.

## Verification Already Run

After the latest rejected visual experiment:

- `bun run verify:macos`: passed.
- `git diff --check`: passed.

Not completed after latest visual experiment:

- Full `apps/filmtone-desktop-macos/Verify/run.sh` verification.
- Accepted visual QA.
- Confirmed physical coordinate click on all visible CTA regions.

Therefore the active task is not done.

## Screenshots Mentioned By User

These are local screenshot paths from the conversation:

```text
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_mhngNO5exm/CleanShot 2026-05-06 at 15.34.36@2x.png
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_SyEhE1QSxl/CleanShot 2026-05-06 at 16.36.35@2x.png
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_LtCTUneVmB/CleanShot 2026-05-06 at 16.50.55@2x.png
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_xN20xGKHX2/CleanShot 2026-05-06 at 17.01.32@2x.png
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_sTfXpXBgCt/CleanShot 2026-05-06 at 17.01.39@2x.png
```

Use them to understand the rejected visual direction if needed.

## Stop Conditions For Next Chat

Stop and report instead of looping if:

- Pixel-coordinate click still focuses but does not invoke the picker after two
  different implementation routes.
- Fixing the hit target appears to require replacing the transparent opening
  window posture.
- The user rejects the visual direction again.

## English Handoff Prompt

You are continuing a Filmtone Native Desktop v2 task in:

`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`

First read `AGENTS.md`, then `docs/filmtone/desktop/native-desktop-v2/strategy.md`, `docs/filmtone/desktop/native-desktop-v2/active.md`, and this handoff:

`docs/filmtone/desktop/native-desktop-v2/2026-05-06-m8-empty-cta-click-handoff.md`

Goal: fix the empty-state `素材を開く` CTA so the entire visible button responds to normal physical mouse/trackpad clicks and opens the foreground `NSOpenPanel`.

Critical constraints:

- Do not enlarge the `素材を開く` button.
- Do not create a visible card inside the already-rounded app window.
- The latest local `PreviewSurface.swift` empty-state experiment is rejected by the user: it made the button too large and reintroduced card-in-card. Revise it; do not present it as done.
- Preserve useful `RootWindowView.swift` fixes unless evidence shows they are involved: scrub overlay hit-testing, inspector z-index, and app-modal Open panel presentation.
- Do not revert unrelated dirty iOS/docs changes.

Use pixel-coordinate testing, not accessibility element clicks. AX clicks can succeed while real mouse hit testing is still wrong. Build with `bun run verify:macos` and `git diff --check`, then launch the Debug app fresh and use Computer Use coordinate clicks on the left, center, and right portions of the visible CTA. Success means each coordinate click opens the frontmost Open panel. Also verify toolbar Open still works.

Recommended implementation direction: restore a compact native-looking opening CTA; if a layout square is needed, make it an invisible sizing guide based on the smaller window side, not a visible card. Use a compact AppKit-backed hit target or an invisible AppKit overlay whose frame exactly matches the visible CTA. Do not make the hit overlay visibly or spatially larger than the CTA.
