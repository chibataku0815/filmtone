# M8 Right Rail Lower-Half Hit-Test Dead Zone — Handoff

**Date**: 2026-05-06
**Status**: RESOLVED 2026-05-06. Root cause: macOS 26
`GlassEffectContainer` claimed hits in the lower window y-band via its
NSView-backed morphing surface; SwiftUI `.zIndex(2)` on the inspector
could not reorder past it. Fix: removed the container from
`EditorSidebar.body`. Per-panel `.glassEffect` (innocent) remains, so
panels render as discrete Liquid Glass capsules without morphing
between adjacent ones. See §13 below for the diagnostic chain that led
to this conclusion.
**Repo**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
**Branch**: `main`
**Platform**: macOS 26 (Tahoe), Apple Silicon, Filmtone Desktop Native v2.

## 1. The bug (precise statement)

When a **video** source is loaded into Filmtone Desktop, the **lower
portion of the right rail (`EditorSidebar`)** silently swallows mouse
hover and click events. The rail's content (panels) is **fully visible
and rendered correctly**, but pointer events do not reach the SwiftUI
buttons / chips / sliders inside the lower band.

The user confirmed the diagnosis themselves:

> 触れる範囲の問題だよ？ 勘違いしてない？
> Backlight Veilでも上部にスクロールすれば触れるし

Translation: "It's a hit-area problem — aren't you misunderstanding?
Even Backlight Veil chips can be touched if you scroll to the upper part."

So the **same chip** (e.g. `1/8` Backlight Veil density) is:

- **Clickable** when the ScrollView is scrolled so that the chip sits in
  the **upper half** of the visible rail.
- **NOT clickable** when scrolled so the chip sits in the **lower half**
  of the visible rail. Cursor does not change to pointing-hand on hover;
  click does nothing.

The visual is identical in both cases — only the y-position in window
coordinates differs. The dead zone is bound to **window y**, not to
specific buttons.

## 2. What you must NOT redo (failed attempts)

### Failed attempt #1 — Misread "Backlight Veil" as a visual issue

**Wrong assumption**: I read user image #6/#7 as "Intensity slider is
disabled when None is selected and looks broken; the user wants the
disabled-state visualization changed."

**What I changed (`apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`)**:
the Intensity row is now mounted only when `state.opticalFilterProfileId != nil`
(hidden when None). With a `.easeInOut(0.18)` opacity+slide transition.

**Result**: User said this is **not** the issue. The change is unrelated
to the hit-test problem. The change itself is a tiny cosmetic improvement
(no inactive widget when None) — leave it in place if it doesn't conflict,
but do **not** treat it as the fix.

### Failed attempt #2 — Restructured `videoScrubOverlay` + added `.contentShape(Rectangle())`

**Theory at the time**: the `videoScrubOverlay` is a `VStack { Spacer(); HStack(scrubBar); bottomPadding }`
wrapped in `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)`.
The top `Spacer` had `.allowsHitTesting(false)` but I suspected SwiftUI
might still claim its y-band as layout extent and intercept hits.

**What I changed**:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  (`videoScrubOverlay(duration:)`, around line 320): removed the top
  `Spacer(minLength: 0).allowsHitTesting(false)`. The VStack now hugs its
  content (scrub bar HStack + bottom padding only); outer
  `.frame(maxHeight: .infinity, alignment: .bottom)` anchors the strip to
  the window bottom without filling the upper space.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`
  (around line 41): added `.contentShape(Rectangle())` on
  `EditorSidebar.body` after `.frame(width: 320)`.

**Result**: User reports **zero improvement** — chips at the lower rail
still unresponsive. The dead zone persists. This means:

- Either the dead zone is not caused by `videoScrubOverlay` at all.
- Or it IS caused by `videoScrubOverlay` but in a way the restructure
  didn't address.
- Or the `.contentShape(Rectangle())` on the rail isn't being honored.

**Important**: do NOT revert these two changes blindly. They are at worst
neutral. But DO consider whether the cause is somewhere else entirely.

## 3. Project / repo guardrails (non-negotiable)

These are repository constitution rules from
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md`,
its referenced `apps/capacitor-film-lab-ios/CLAUDE.md`, and the
auto-memory at
`/Users/chibatakumi/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-forestone-filmtone/memory/`.
Violating them is a higher-priority bug than not solving this one.

- **Git operations are user-driven.** Auto-commit is BLOCKED by hook in
  this project. You can `git add`/stage but the user must run `git
  commit` themselves. Do not attempt to bypass.
- **bun, not npm.** `bun install` / `bun run verify:macos`.
- **Native Desktop v2 docs are 2-layer.**
  `docs/filmtone/desktop/native-desktop-v2/strategy.md` is long-lived.
  An `active.md` (when present) is the current sub-task. Archive
  `active.md` when the task is closed.
- **`packages/film-lab-renderer/dist/` and `packages/film-lab-smart-look/dist/`
  are intentionally tracked**. Don't add them to `.gitignore`.
- **iOS public ≠ local candidate.** Don't fabricate version states; use
  the truth scripts in life repo (see §10).
- **Vocabulary lock**: `動画`/`video` (no `短尺動画`/`short-form video`),
  `Preset` ≠ `Look` (Look = LUT pack only).
- **No JSX comment directly under `return (`.**
- **No black matte / continuous rail to fix glass-over-media exposure**
  (use media-derived blurred backdrop). Already applied in
  `PreviewSurface.swift` `MediaDerivedBackdrop` — keep it.
- **NSViewRepresentable blocks Liquid Glass sampling.** This is a
  load-bearing reason `FilmtoneDesktopPlayerView` and the rail's
  `Image(nsImage:)` exist as they do — don't refactor without a real
  reason.

## 4. The architecture under suspicion

### 4.1 Window posture

`RootWindowView.configureWindowForTransparentGlass(_:)` at
`apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift:476-492`:

- `window.styleMask.insert(.fullSizeContentView)`
- `window.isOpaque = false`
- `window.backgroundColor = .clear`
- `window.titlebarAppearsTransparent = true`
- `window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor`

So the AppKit window itself is fully transparent. SwiftUI content draws
on top of nothing.

### 4.2 Top-level layout

`RootWindowView.editorOverlayLayout` at
`apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift:247-313`:

```swift
ZStack(alignment: .topTrailing) {
    PreviewSurface(state, sourceURL, …)              // base layer (no zIndex)
        .ignoresSafeArea(.container, edges: .all)
    if inspectorVisible {
        EditorSidebar(state, library, exportCoordinator)
            .padding(.top, 72)
            .padding(.bottom, sidebarBottomPadding)   // 200 for landscape video
            .padding(.trailing, 12)
            .transition(.move(edge: .trailing))
            .zIndex(2)
    }
    if state.sourceKind == .video, let duration = state.videoDurationSeconds, duration > 0 {
        videoScrubOverlay(duration: duration)
            .zIndex(1)
    }
}
.animation(.spring(response: 0.35, dampingFraction: 0.85), value: inspectorVisible)
```

Key insets:

- `sidebarBottomPadding`:
  - landscape video: **200**
  - portrait video: 160
  - other: 24
- `scrubBarBottomPadding`:
  - landscape: **64**
  - portrait: 24

### 4.3 The right rail

`apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`:

```swift
struct EditorSidebar: View {
    var body: some View {
        GlassEffectContainer(spacing: 16) {
            ScrollView(.vertical, showsIndicators: true) {
                EditorPanelStack(state, library, exportCoordinator)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 320)
        .contentShape(Rectangle())   // ← added in failed attempt #2
    }
}

struct EditorPanelStack: View {
    var body: some View {
        VStack(spacing: 16) {
            if state.sourceURL != nil {
                SourceProfileControls(state).modifier(EditorSidebarPanelGlass())
                LookLibraryControls(state, library).modifier(EditorSidebarPanelGlass())
                QuickAdjustControls(state).modifier(EditorSidebarPanelGlass())
                ExportInspectorPanel(state, …).modifier(EditorSidebarPanelGlass())
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EditorSidebarPanelGlass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .glassEffect(
                .clear.tint(.black.opacity(0.32)),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}
```

So per panel: dark-tinted clear `.glassEffect` in a 16pt-radius rounded
rectangle.

### 4.4 The Backlight Veil chips inside `QuickAdjustControls`

`apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`,
`opticalFilterChip(_:)` near line 137:

```swift
return Button {
    let newProfileId: String? = option.id == FilmtoneOpticalFilterCatalog.noneIdentifier ? nil : option.id
    if newProfileId != state.opticalFilterProfileId, newProfileId != nil {
        state.opticalFilterIntensity = 1.0
    }
    state.opticalFilterProfileId = newProfileId
} label: {
    Text(option.label)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .foregroundStyle(active ? .black : .white.opacity(0.88))
        .background(
            active ? Color.white.opacity(0.92) : Color.white.opacity(0.12),
            in: Capsule()
        )
        .overlay { Capsule().strokeBorder(...) }
        .contentShape(Capsule())
}
.buttonStyle(.plain)
.help(option.help)
.filmtonePointingHandCursor()
```

- Plain Button with `.contentShape(Capsule())` on the label.
- Cursor is pushed via `.filmtonePointingHandCursor()` (`.onHover` →
  `NSCursor.pointingHand.push()`).
- The chip is functionally correct; it works at the upper rail position.

`QuickAdjustControls.body` outer is `.frame(width: 220)`. The panel glass
modifier adds `.padding(.horizontal, 16)` so the panel is **252pt
wide**, centered in the 320pt rail.

### 4.5 The video scrub overlay (current state, post-failed-attempt-#2)

`apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`,
`videoScrubOverlay(duration:)` near line 320:

```swift
@ViewBuilder
private func videoScrubOverlay(duration: Double) -> some View {
    VStack(spacing: 0) {
        HStack(spacing: 0) {
            Spacer(minLength: 0).allowsHitTesting(false)
            VideoScrubBar(state, duration)
                .padding(.horizontal, isPortraitSource ? 12 : 0)
            Spacer(minLength: 0).allowsHitTesting(false)
        }
        if scrubBarBottomPadding > 0 {
            Color.clear.frame(height: scrubBarBottomPadding).allowsHitTesting(false)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
}
```

`VideoScrubBar` itself has `.frame(maxWidth: 600)` so the actual capsule
is centered with a 600pt cap.

### 4.6 The video player layer (probable root cause to investigate)

`apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift:96-97`:

```swift
if sourceKind == .video, let session = state.videoSession {
    FilmtoneDesktopPlayerView(player: session.player)
}
```

`FilmtoneDesktopPlayerView` is at
`apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneDesktopPlayerView.swift`:

```swift
struct FilmtoneDesktopPlayerView: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = false
        view.allowsPictureInPicturePlayback = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return view
    }
    …
}
```

**This is the strongest remaining suspect.** `AVPlayerView` is a full
NSView with its own AppKit responder chain. Even with
`controlsStyle = .none` it still:

- Returns `self` from `hitTest(_:)` for any in-bounds point.
- Sits inside `PreviewSurface`'s ZStack with no `.frame(...)` constraint,
  so SwiftUI lays it out at full container size.
- Is wrapped by an `NSViewRepresentable`, which **inserts an AppKit view
  into the window's NSView hierarchy** at a position SwiftUI's `.zIndex`
  may not be able to override. SwiftUI's `.zIndex(2)` on `EditorSidebar`
  reorders SwiftUI siblings within a host, but the underlying NSView
  ordering of an `NSViewRepresentable`-introduced child can break the
  expected hit cascade.

Memory says exactly this kind of NSViewRepresentable interferes:
`feedback_nsviewrepresentable_blocks_liquid_glass.md` —
"Liquid Glass は SwiftUI render tree しか sample 不可、NSImageView/UIImageView/MTKView は不可視".
Same render-tree opacity that prevents glass sampling can also break
hit-test cascading.

**Why upper rail works but lower rail doesn't** under this theory:

- The upper portion of the rail aligns vertically with the toolbar /
  empty top of the AVPlayerView area, where AppKit's NSView responder
  chain has historically been less "sticky" (window chrome / fullSize
  content view boundary).
- The lower portion sits squarely over the AVPlayerView's center body —
  exactly where AVPlayerView's mouse responder is most aggressive.
- There may be a **first-responder / movable-by-window-background
  interaction**: clicks in the rail's lower band might be routed to
  AVPlayerView, which then calls
  `NSWindow.performMouseEvent(...)` in a way that swallows them rather
  than letting SwiftUI's hit cascade try the rail next.

(This is a hypothesis — the next chat must verify it before fixing.)

## 5. Things that already exist and DO work

- The toolbar buttons (Open / Compare / Export / Inspector) all work.
- ⌘O opens the file panel.
- ⌘\\ toggles the inspector.
- VideoScrubBar (the floating capsule at the bottom) works — play /
  pause / scrub / hover-thumbnail / rate menu.
- The empty state CTA (`素材を開く` button) works — fixed in a prior
  M8 round with an invisible AppKit click-catcher overlay
  (`OpeningCTAClickCatcher`) in `PreviewSurface.swift:608-742`.
- Toolbar **Export** pill size matches the other 3 toolbar pills via
  `.imageScale(.small)` on its `Label` (taller `square.and.arrow.up`
  symbol). See `RootWindowView.swift:137-220`.
- The loaded-state preview backdrop is `MediaDerivedBackdrop`
  (`scaledToFill + blur + dim`) inside `PreviewSurface.swift`. **This is
  intentional — do not replace with `Color.black` (rejected 2026-05-06,
  see `feedback_no_black_matte_for_glass_exposure.md`).**

## 6. Things to investigate next (ranked)

### 6.1 (high) Confirm AVPlayerView is the hit thief

Insert a temporary diagnostic: replace `FilmtoneDesktopPlayerView` with a
plain `Color.black` in the ZStack and load a video. If the rail's lower
half becomes clickable, AVPlayerView is confirmed culprit. Revert the
diagnostic, then fix.

Possible fixes:

- **Override AVPlayerView's hitTest** by subclassing `AVPlayerView` and
  returning `nil` from `hitTest(_:)` (or a custom view above it that
  passes through). The player's mouse events for play/pause aren't
  needed — Filmtone owns playback chrome via `VideoScrubBar`.
- **Add a transparent SwiftUI sibling** above the player but below the
  inspector with `.allowsHitTesting(true)` and an empty action — so the
  area below the rail's frame consumes hits at the SwiftUI level before
  reaching AppKit.
- **Constrain AVPlayerView's frame** with `.frame(width:, height:)` or
  `.padding(.trailing, 332)` when `inspectorVisible` so it physically
  doesn't occupy the rail's horizontal band.

### 6.2 (high) Check `GlassEffectContainer` for known hit-test issues

`GlassEffectContainer` is macOS 26-only and relatively new. Check the
release notes and known issues. In particular:

- Does `GlassEffectContainer { ScrollView { … } }` propagate hits
  correctly to ScrollView content? Try removing `GlassEffectContainer`
  and applying `.glassEffect` to each panel directly.
- Try moving `.contentShape(Rectangle())` from the outer
  `EditorSidebar` to the inner `EditorPanelStack` (after `padding(.vertical, 4)`).

### 6.3 (medium) `.zIndex` vs. AppKit responder chain

Try putting `videoScrubOverlay` BEFORE `EditorSidebar` in the ZStack
source order (so SwiftUI's natural sibling order has the inspector last).
Drop the explicit `.zIndex(...)` calls. SwiftUI's natural order is more
likely to align with the underlying NSView z-order than explicit zIndex
when NSViewRepresentables are involved.

### 6.4 (medium) Sidebar bottom padding semantics

`sidebarBottomPadding = 200` for landscape video shrinks the rail's
visible frame so its bottom edge is 200pt above the window bottom.
Inspect whether the rail's HIT frame matches the visual frame, or if
the padding exposes a region where the rail is visually "over" the
player but its frame ends earlier. Could explain the precise band the
user reports.

Use a temporary debug overlay:

```swift
EditorSidebar(...)
    .padding(.top, 72)
    .padding(.bottom, sidebarBottomPadding)
    .padding(.trailing, 12)
    .background(Color.red.opacity(0.3))   // ← TEMP
    .zIndex(2)
```

If the red tint matches the visible rail area exactly, hit frame ==
visual frame — rule out frame mismatch. If it's smaller than visual,
that's the smoking gun.

### 6.5 (low) `showsIndicators: true` on the ScrollView

The vertical scroll indicator on the right edge could intercept hits in
its column. Try `showsIndicators: false` to test.

### 6.6 (low) `.glassEffect` per panel

Each panel applies `.glassEffect`. Try removing it from one panel
(QuickAdjustControls) and see if its lower-half chips become clickable.

## 7. Verification protocol

After ANY fix, before claiming success:

1. `bun run verify:macos` must succeed (xcodebuild builds + signs).
2. Quit any running Filmtone, relaunch the Debug build.
3. Load a **landscape video** (this is the case where
   `sidebarBottomPadding == 200`, the worst case for the dead zone).
4. Open the right rail (default open for landscape; ⌘\\ toggles).
5. Scroll the right rail content so the **Backlight Veil chip row**
   (`None` / `1/8` / `1/4` / `1/2`) sits in the lower half of the
   visible rail viewport — i.e., somewhere near the rail's bottom edge.
6. Hover over `1/8` — the cursor must change to pointing-hand.
7. Click `1/8` — `Backlight Veil 1/8` must become the active chip; the
   `Intensity` row must appear (with its slider) below the chip row.
8. Repeat at: `1/4` and `1/2`. Each must respond to hover + click.
9. Repeat steps 6–8 with the chip row scrolled to the upper rail
   position — must still work (regression check).
10. Verify the floating scrub bar at the bottom still works
    (play/pause/scrub) — regression check on the scrub overlay
    restructure.
11. Verify ⌘\\ still toggles the rail.
12. Verify toolbar Open / Export still work.
13. **Do not declare victory based on a build pass.** Hit tests are not
    something the build catches.

`bun run verify:macos` only proves it builds. It does not prove the
hit-test bug is fixed. The user has to physically click.

The user has explicitly said:

- 目視するから勝手に動かすな (= "I'll inspect visually, don't move
  the window on your own"). Honor this — do not move the window
  programmatically without permission.
- After a fix is in place, ask the user to verify before moving on.

## 8. Truth scripts and external references

iOS / release truth (run from this repo or anywhere with
`FILMTONE_REPO_ROOT` env set):

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

When docs disagree with these scripts, **the scripts are authoritative**
(see `feedback_verify_before_documenting`).

Native Desktop v2 docs:

- `docs/filmtone/desktop/native-desktop-v2/strategy.md` — long-lived
  truth.
- `docs/filmtone/desktop/native-desktop-v2/active.md` — current sub-task
  if present.
- `docs/filmtone/desktop/native-desktop-v2/archive/` — completed
  sub-tasks.
- `docs/filmtone/desktop/native-desktop-v2/2026-05-06-m8-empty-cta-click-handoff.md`
  — adjacent M8 work (empty-state CTA hit-test fix). The
  `OpeningCTAClickCatcher` pattern in there is a precedent: a SwiftUI
  Button + invisible AppKit hit-target NSView overlay solved a similar
  hit-shape vs. visual-shape mismatch on the empty CTA. **A similar
  pattern may be the right fix here** — instead of adding
  `.contentShape(Rectangle())` to the SwiftUI rail, add an invisible
  AppKit "rail click catcher" that owns hit testing for the
  rail's bounds and forwards events to the SwiftUI buttons via AX or
  via direct frame mapping. (Speculative — verify before implementing.)

## 9. Current dirty state (as of handoff)

Run `git status` to confirm. At the time of writing:

**Staged (in flight, awaiting user `git commit`)**:

- `apps/capacitor-film-lab-ios/...` — iOS Phase0 contract / sidecar /
  strings updates from a prior lane.
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
  — `MediaDerivedBackdrop`, `EmptyPreviewLabel` rewrite,
  `OpeningCTAClickCatcher`.
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.5.md` (new)
- `docs/filmtone/desktop/native-desktop-v2/2026-05-06-m8-empty-cta-click-handoff.md` (new)
- `docs/filmtone/desktop/native-desktop-v2/active.md` (new)
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m7-...md` (new)
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-empty-open-button-hit-testing.md` (new)
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-inspector-bottom-hit-testing.md` (new)
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-opening-open-panel-foreground.md` (new)
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/release-cutover/2026-05-05-native-v2-replacement-readiness.md`
- `docs/filmtone/desktop/release-cutover/README.md`
- `docs/filmtone/ios/2026-05-06-filmtone-ios-meta-before-after-davinci-handoff.md`
- `scripts/release-cutover-preflight.mjs`

**Unstaged (this chat's work)**:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`
  (added `.contentShape(Rectangle())`)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
  (Intensity row hidden when None — keep, harmless)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  has both staged (M8 empty CTA / scrub hit scope / inspector zIndex)
  AND unstaged (videoScrubOverlay top-Spacer removed) chunks. This is
  the `MM` line in `git status --short`.

**Untracked (don't touch)**:

- `.codex_create_lut_wipe_l2r.lua` — stray codex artifact, ignore.

The user must `git commit` before the next session does any non-trivial
work. Hand them this command (do not run it yourself):

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git commit -m "feat(desktop): native v2 M8 empty CTA + media-derived backdrop"
```

## 10. The user — collaboration protocol

These are confirmed in this and prior chats. Honor them or you'll be
corrected and lose context budget.

- 日本語で出力。技術用語は英語可。
- ファイル参照: `path/to/file:line` 形式。
- 簡潔・行動志向。冗長な要約・装飾・絵文字なし。
- Don't speculate without verifying. Read source / grep / run the truth
  scripts. Don't quote handoffs without cross-checking the current
  source — handoffs go stale.
- Don't autonomously launch the app or move the window when the user is
  visually inspecting. Wait for them.
- Don't claim something "landed" until `git log` shows the commit.
- Bundle in-flight work into one commit; don't unstage / patch-split
  unless explicitly asked.
- Don't add black mattes / continuous rails to fix glass-over-media
  exposure (use media-derived blurred backdrops).
- Don't promise from a forced sub-stage profile (cost-only ranking, not
  for sizing).

## 11. Quick orientation commands

```bash
# Confirm dirty state
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git status
git diff apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift
git diff apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift
git diff apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift

# Build
bun run verify:macos

# Launch (only after the user has confirmed they want a relaunch)
osascript -e 'tell application "Filmtone" to quit' 2>/dev/null
open apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app

# Truth scripts (life repo)
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

---

# 12. New-chat handoff prompt (paste this verbatim into the next session)

> You are picking up a Filmtone Native Desktop v2 (macOS 26, SwiftUI +
> AppKit, Apple Silicon) hit-testing bug. The chat that originated the
> investigation has been written up at
> `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/native-desktop-v2/2026-05-06-m8-rail-lower-half-hit-deadzone-handoff.md`.
> Read that document in full before doing anything else — it is the
> authoritative state of the work. The summary below is a smaller
> orientation.
>
> **The bug**: when a landscape video source is loaded, the right rail
> (`EditorSidebar`, 320pt wide, `.zIndex(2)` over the preview, with
> `.padding(.bottom, 200)`) renders correctly but its **lower half is a
> hit-test dead zone**. The exact same SwiftUI Buttons (the Backlight
> Veil chips `None / 1/8 / 1/4 / 1/2` inside `QuickAdjustControls.opticalFilterSection`)
> respond to hover and click only when the ScrollView is scrolled so
> they sit in the upper half of the visible rail. When scrolled into the
> lower half their hit-shape silently goes dead — cursor doesn't change
> on hover, click does nothing — even though the visual is identical.
> The user verified this themselves: scroll up → works; scroll back
> down → broken.
>
> **Two fixes already failed**, do not redo them. They are described in
> the handoff doc §2:
>
> 1. Hiding the Intensity row when `opticalFilterProfileId == nil` (a
>    pure visual change — irrelevant to hit testing).
> 2. Removing the top `Spacer` from `videoScrubOverlay` so its VStack
>    hugs content, plus adding `.contentShape(Rectangle())` to
>    `EditorSidebar`. The user reports zero improvement.
>
> **Strongest remaining hypothesis**, per §4.6 / §6.1: the
> `FilmtoneDesktopPlayerView` `NSViewRepresentable` wrapping a full-bleed
> `AVPlayerView` is intercepting hits in its body via the AppKit
> responder chain in a way that SwiftUI's `.zIndex(2)` on `EditorSidebar`
> can't override. The auto-memory at
> `~/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-forestone-filmtone/memory/feedback_nsviewrepresentable_blocks_liquid_glass.md`
> documents that `NSViewRepresentable` already breaks SwiftUI render-tree
> sampling for Apple Liquid Glass; an analogous break of hit-test
> cascading is plausible.
>
> **First diagnostic to run** (per §6.1): temporarily replace
> `FilmtoneDesktopPlayerView` with a plain `Color.black` in
> `PreviewSurface.swift:96-97`, build, load a landscape video, and check
> whether the lower-half rail chips become clickable. If yes, the player
> view is the culprit and the fix is one of: subclass `AVPlayerView` to
> return `nil` from `hitTest(_:)`, constrain the player's
> `NSViewRepresentable` frame so it physically doesn't sit under the
> rail, or wrap with a SwiftUI sibling that consumes hits in the rail's
> column when the inspector is open. After the diagnostic, REVERT the
> `Color.black` substitution and apply the real fix.
>
> **Constraints (non-negotiable)**:
>
> - Output in 日本語 (technical terms in English are fine). File
>   references in `path/to/file:line` form. Be terse and action-oriented.
> - **Auto-commit is blocked by repo hook** (`CLAUDE.md §9`: Git 操作は
>   user が行う). You may stage but the user runs `git commit`. There
>   are already ~30 staged files from a prior commit-blocked attempt;
>   ask the user to commit before you do significant new work.
> - **Do not autonomously launch the Filmtone app or move its window
>   while the user is visually inspecting.** They have explicitly said
>   so this session ("目視するから勝手に動かすな"). Announce intent
>   and wait for permission.
> - **bun, not npm.** Build with `bun run verify:macos`. The build
>   succeeds with a stale-index SourceKit warning about
>   `FilmLabSwiftCore` — that is an LSP artifact, the actual `xcodebuild`
>   resolution succeeds and the binary signs cleanly. Don't chase it.
> - **Don't replace `MediaDerivedBackdrop` with a black matte** in
>   `PreviewSurface.swift`. The user explicitly rejected that 2026-05-06
>   (auto-memory `feedback_no_black_matte_for_glass_exposure.md`).
> - **Don't add `dist` to `.gitignore`.**
>   `packages/film-lab-renderer/dist/` and
>   `packages/film-lab-smart-look/dist/` are intentionally tracked for
>   submodule consumption.
> - Build verification (`bun run verify:macos` succeeding) is **not**
>   evidence the hit-test is fixed. The user has to click. Run the full
>   §7 verification protocol after every attempt and **wait for the
>   user's visual confirmation** before declaring success.
>
> **Files most likely to need edits** (read all of them before editing
> anything):
>
> - `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
>   (`editorOverlayLayout` ~247-313, `videoScrubOverlay` ~320-340,
>   `sidebarBottomPadding` ~349-352)
> - `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`
> - `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
> - `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
>   (the `if sourceKind == .video` branch ~96-97 mounts the player view)
> - `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneDesktopPlayerView.swift`
>   (the suspect — entire file is ~40 lines)
>
> Start by:
> 1. `cat /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/native-desktop-v2/2026-05-06-m8-rail-lower-half-hit-deadzone-handoff.md`
> 2. `git status` and `git diff` on the files in §9 of that doc to
>    confirm the dirty state matches.
> 3. `bun run verify:macos` to confirm the current code builds.
> 4. Ask the user whether to commit the staged work first, then proceed
>    with diagnostic §6.1. Do not skip the diagnostic — it is the
>    cheapest way to localize the bug.
>
> Reply in 日本語. Don't preface your first response with a recap of
> these instructions — just state which step you're starting and any
> question you have for the user.

## 13. Resolution (2026-05-06 同日中に解決)

新チャット (この doc を参照した次セッション) で以下の diagnostic chain を
実行し、真因を localize → 1 行の構造変更で修正完了。

### 13.1 Diagnostic chain

- **Step 0** — `PreviewSurface.swift:96-97` の `FilmtoneDesktopPlayerView`
  を `Color.black` に置換。user 視認: rail 下部依然 dead → AVPlayerView
  単独は犯人ではない。注意: `Color.black` 自体も SwiftUI で hit-testable
  なので、これは「AVPlayerView NSView responder + zIndex bypass」仮説の
  必要条件を否定するだけで十分条件は別途要検証だった。
- **Step 0b** — `RootWindowView.swift` の `videoScrubOverlay(...)` mount
  を `EmptyView()` に差し替え。user 視認: 依然 dead → scrub overlay の
  outer `.frame(maxHeight: .infinity)` も犯人ではない。
- **Step 0c** — `EditorSidebar.body` から `GlassEffectContainer(spacing:
  16) { ... }` wrapper を撤去 + `EditorPanelStack` から
  `.modifier(EditorSidebarPanelGlass())` を全 panel から外し +
  `.background(Color.red.opacity(0.35))` を追加。user 視認 (screenshots):
  rail 下部 chips (`1/8` 含む) **全て click 反応**。red 背景は rail visible
  領域を完全カバー → rail frame は OK だった (frame が短いという仮説 (Q)
  も否定)。**Liquid Glass (container or per-panel) が thief 確定**。
- **Step 0d** — Step 0c から `.modifier(EditorSidebarPanelGlass())` だけ
  re-apply (`GlassEffectContainer` は外したまま)。user 視認 (screenshot
  #11): `1/8` chip click 反応 + active 状態に切り替わり。
  **`GlassEffectContainer` が単独 hit thief 確定**、per-panel
  `.glassEffect` は innocent。
- **Step 0e** — Step 0d から `.background(Color.red...)` だけ撤去
  (production 視覚)。user 視認 (screenshot #13): Liquid Glass の discrete
  capsule 視覚が完全復活 + 全 click 反応 + regression なし。確定 fix。

### 13.2 Why GlassEffectContainer steals hits

`GlassEffectContainer(spacing:)` は macOS 26 SwiftUI が adjacent な
`.glassEffect` surfaces を morph させるための grouping container。実装上
はおそらく Metal-backed material 用の NSView (具体実装は private API) を
hosting view に挿入し、container 自身がそのコーディネート空間で hit-test
を保持する。SwiftUI の `.zIndex(2)` は SwiftUI sibling の z-order を
reorder するが、NSHostingView 配下の AppKit NSView ordering は変えられない
ため、container の NSView が下層に居ると EditorSidebar (zIndex 2) より
先に hit を吸ってしまう。AVPlayerView の hit-stealing と同種の SwiftUI ↔
AppKit responder chain の non-interaction 例。

`feedback_nsviewrepresentable_blocks_liquid_glass.md` (auto-memory) と同根:
NSView-backed surface は SwiftUI render tree の外側に居るため、
SwiftUI primitive (`.zIndex`) では制御できない。

なぜ rail **下部だけ** dead だったかは window 内の geometric overlap で
説明可能 — container の hit 主張が他の SwiftUI 要素 (toolbar, top padding)
に上半分は塞がれていたが、下部はちょうど container の active region と一致
していた。詳細な mechanism は SwiftUI 内部実装非公開のため断言不可だが、
empirical には container 撤去で全箇所の hit が回復した。

### 13.3 The fix (1 構造変更)

```swift
// Before
var body: some View {
    GlassEffectContainer(spacing: 16) {
        ScrollView(.vertical, showsIndicators: true) {
            EditorPanelStack(...)
                .frame(maxWidth: .infinity)
        }
    }
    .frame(width: 320)
    .contentShape(Rectangle())
}

// After
var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
        EditorPanelStack(...)
            .frame(maxWidth: .infinity)
    }
    .frame(width: 320)
    .contentShape(Rectangle())
}
```

`EditorSidebarPanelGlass` ViewModifier (per-panel `.glassEffect`) は
無変更 — 各 panel は引き続き dark-tinted clear glass capsule として
render される。

### 13.4 Trade-off

`GlassEffectContainer` は adjacent glass surfaces 間の morphing
transition を提供する macOS 26 機能。container 撤去により panel 間の
morphing は失われるが、各 panel は discrete な Liquid Glass capsule
として独立 render される。視覚的には「panels が個別の glass card」 vs
「panels が連続体として morph」の差で、この trade-off は user 視認 (screenshot
#13) で acceptable と判定。

### 13.5 Files actually modified

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`
  - `body`: `GlassEffectContainer { ScrollView { ... } }` → `ScrollView { ... }`
  - 補足コメントを更新 (なぜ container を外したか / per-panel glass は keep)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
  - 旧 chat の Failed Attempt #1 (Intensity row 条件 mount) は無関係だが副作用
    ないため留置
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  - 旧 chat の Failed Attempt #2 (videoScrubOverlay top Spacer 撤去) は無関係
    だが副作用ないため留置

`PreviewSurface.swift` / `FilmtoneDesktopPlayerView.swift` は **無変更**
(AVPlayerView subclass は不要だった)。

### 13.6 Verification

- `bun run verify:macos`: BUILD SUCCEEDED
- user 視認 (screenshot #13):
  - landscape video loaded、`sidebarBottomPadding = 200` (worst case)
  - rail 全領域でクリック反応 (上半分 / 下半分とも)
  - Liquid Glass の discrete capsule 視覚 OK
  - regression なし (Source / Look / Quick / Export 各 panel 操作・slider 反応)

### 13.7 Lessons

- macOS 26 Liquid Glass の **`GlassEffectContainer` は hit-test に副作用が
  ある**。本リポで使用する場合は hit critical な領域 (今回の inspector の
  ScrollView 内 buttons) では避けるか、別 wiring で morph 効果を実現する。
- `.zIndex` は SwiftUI sibling 限定 — NSView-backed component (AVPlayerView,
  GlassEffectContainer の内部 surface, etc.) との hit ordering は別 mechanism
  で制御する必要がある。今回も含めて auto-memory
  `feedback_nsviewrepresentable_blocks_liquid_glass` と同種パターン。
- 「hit-stealer 候補を 1 つずつ排除する diagnostic chain」が結果として最短経路
  だった。最初の仮説 (AVPlayerView) は誤りだったが、否定が次仮説への確定
  情報となり Step 0d で 1 ターンで真因確定に到達。`feedback_diagnostic_first_when_modifier_invisible`
  通り。
