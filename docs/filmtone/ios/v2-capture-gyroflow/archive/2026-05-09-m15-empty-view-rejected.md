# Archived: M15 — Editor Empty View + Library Chip Liquid Glass parity (REJECTED 20点)

Status: **REJECTED** — owner rated 20/100. Two material implementation
flaws drove the rejection:

1. The custom button style applied glass via
   `.background(Color.clear.glassEffect(...))`. SwiftUI 26's correct
   pattern is to apply `glassEffect(_:in:)` directly on the padded
   content; the background-Color.clear trick caused the label to
   render behind the material rather than on top, making the text
   diffused and unreadable.
2. The `Color.filmtoneAmber.opacity(0.18)` primary tint was too
   saturated. Stacked on the dark substrate, it produced opaque
   brown blobs — three nearly-identical CTA pills with amber wash
   instead of a coherent Liquid Glass surface. The library chip's
   amber 0.10 tint had the same problem at smaller scale.

Beyond the mechanics, the design itself was wrong: three equal-weight
stacked CTAs with no hierarchy, no atmospheric substrate for Liquid
Glass to refract, no design language referenced. M15-bis (next
active) starts the page over from the design level using the owner's
TIDE iOS Mar 2026 reference.

Original active.md content follows below for traceability.

---

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **installed on iPhone 17 Pro #7, ready for owner walk** — autonomous execution complete 2026-05-09 02:06 JST

## Why this active exists

Owner-provided screenshot (2026-05-09) of `FilmtoneEmptyView`
identifies two gaps in the post-M13 visual language:

1. **Saved Looks chips (Stone / Urban) read as opaque amber leather
   buttons, not Apple Liquid Glass.** `FilmtoneLibraryChip` uses
   `.background(RoundedRectangle.fill)` + `.overlay(stroke)`, never
   calling `glassEffect`. The chip silhouette is a flat tinted rect
   over the dark substrate — refraction is impossible because there
   is no Liquid Glass material in the composite.
2. **Empty-view CTA stack mixes a bright `.glassProminent` system-
   blue Photo Library button with two `.glass` neutral buttons.** The
   blue button is the loudest object on screen, contradicting the
   Filmtone-amber accent system used elsewhere (capture cockpit,
   library section, export panel, toast view all already speak
   amber). The visual hierarchy reads as "do the blue thing" rather
   than "pick where your source comes from."

M15 closes both gaps by lifting the chip to a real Liquid Glass
surface and replacing the system button styles with a Filmtone-amber
CTA style.

## Scope

### A. New file — `FilmtoneEmptyCTAButtonStyle.swift`

Custom `ButtonStyle` for the three empty-view CTAs. Uses Liquid
Glass on a `RoundedRectangle(cornerRadius: 12, .continuous)` with
two visual kinds:

- `.primary` — amber-tinted (`Color.filmtoneAmber.opacity(0.18)`) +
  thin amber rim (0.6pt at 0.32 opacity). Used for "Photo Library"
  and "Record" — Filmtone's two recommended source paths.
- `.secondary` — plain `.regular` Liquid Glass with no tint, white
  rim 0.4pt at 0.14 opacity. Used for "Files" — the third path,
  the one that is intentionally less promoted.

Pressed-state ripple comes from `.regular.interactive()`, not a
manual `configuration.isPressed` overlay.

The style ships as its own file because:
- It encapsulates the empty-view CTA visual language in one place
  (responsibility separation).
- A shared file (`FilmtoneRootChrome.swift`) is reserved for tokens +
  truly shared chrome views (top chrome, toast). A button style with
  amber/Filmtone-specific decisions does not belong there.

### B. Refactor `FilmtoneLibraryChip`

In `FilmtoneLibrarySection.swift`:

- Remove `.background(RoundedRectangle.fill)` and `.overlay(stroke)`.
- Replace with `glassEffect(.regular.tint(...).interactive(), in:
  RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, style:
  .continuous))`.
- Tint hierarchy:
  - `isBundled == true` → `Color.filmtoneAmber.opacity(0.10)` +
    `Color.filmtoneAmber.opacity(0.28)` rim 0.6pt.
  - `isBundled == false` → no tint (plain `.regular`) + `Color.white
    .opacity(0.14)` rim 0.4pt.
- Keep `filmtoneControlCornerRadius = 10` (already the editor's
  chip token; matches M13-M-2 cockpit `hudShape` 10pt vocabulary).

This change automatically propagates everywhere the chip is rendered
(empty view, library section, anywhere `FilmtoneSavedLooksStrip` or
`FilmtoneSavedLutsStrip` is used).

### C. Update `FilmtoneEmptyView`

Replace the three button modifiers:

```swift
.buttonStyle(.glassProminent)    →  .buttonStyle(FilmtoneEmptyCTAButtonStyle(kind: .primary))
.buttonStyle(.glass)             →  .buttonStyle(FilmtoneEmptyCTAButtonStyle(kind: .secondary or .primary))
```

Mapping rationale:
- Photo Library → `.primary` (most-used source path).
- Files → `.secondary` (deliberately quieter — files is the rare path).
- Record → `.primary` (Filmtone's authored capture path; should not
  be visually subordinate).

Other empty-view structure (background, symbol hero, saved-Looks
teaser placement) is untouched — it already reads correctly.

## In Scope

- NEW `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptyCTAButtonStyle.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySection.swift`
  — chip refactor (the chip struct only; the strip wrapper is unchanged).
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptyView.swift`
  — wire the new CTA style into the three buttons.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  — 4-section registration for the new button-style file.

## Out of Scope (later lanes)

- Editor top chrome, export panel, advanced params, source-load
  state, library section header — all separate surfaces, all already
  use `glassEffect` in some form. Audit-and-tune passes are deferred.
- New illustration / Filmtone symbol changes.
- M14-C (sidecar provenance) — paused while M15 ships.
- Localizable.xcstrings additions — no new strings in M15.

## Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/feature+ios-m9-recording-export-completion
git diff --check

# pbxproj 4-section grep gate
grep -c FilmtoneEmptyCTAButtonStyle.swift apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
# expect 4

xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug -derivedDataPath /tmp/filmtone-m15-dd build
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-m15-dd/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

## Owner walk (acceptance gate)

Each must be clearly true before M15 archives:

1. **Saved Looks chips read as Liquid Glass** — Stone / Urban (and
   any owner-saved Look) silhouettes show specular at the rim,
   refract the underlying substrate, and the amber tint is a hint not
   a fill. No more opaque amber leather feel.
2. **CTA stack is one coherent system** — Photo Library, Files,
   Record all share the same Liquid Glass material on the same shape.
   The bright system blue is gone. Visual hierarchy is expressed
   through tint (amber for primary paths, neutral for the third
   path), not through a category-mismatched system style.
3. **No capture-cockpit regression** — open the camera, the chip
   row + ruler scrubber + lens chips + record cluster look identical
   to M14-B's owner-walk state. M15 only adds the new style + chip
   refactor; capture cockpit code is untouched.
4. **Library section parity** — open the editor's library sheet
   (where Saved Looks + Saved LUTs are also listed). The chips there
   inherit the new Liquid Glass treatment automatically (same chip
   struct).

If any FAIL: iterate before commit.

## Stop Conditions

- Any edit to capture session / writer / package / facade / export.
- Any edit to capture cockpit chrome (`FilmtoneCaptureChrome`,
  `FilmtoneCaptureCockpitTopBar`, `FilmtoneCaptureBottomDeck`,
  `FilmtoneCaptureLensChipRow`).
- Two simulator build failures from the same root cause.
- pbxproj 4-section grep returns < 4 for the new file.
- Owner says the new chip / CTA hierarchy is too quiet or too loud.

## Execution log (autonomous run 2026-05-09)

- 01:57-02:06 JST: Step 1-5 executed continuously per active scope.
- M14-B archived as PASS to
  `archive/2026-05-09-m14-b-master-bookmark.md`. Strategy.md
  Completion Log + Sub-milestones updated. New **M15** milestone added
  as a parallel lane to M14-C (deferred until M15 lands).
- New file `FilmtoneEmptyCTAButtonStyle.swift` (~80 lines):
  ButtonStyle with `.primary` (amber-tinted Liquid Glass + 0.6pt amber
  rim) and `.secondary` (plain Liquid Glass + 0.4pt white rim) on
  `RoundedRectangle(cornerRadius: 12, .continuous)`. Pressed-state
  ripple via `.regular.interactive()`.
- `FilmtoneLibrarySection.swift` `FilmtoneLibraryChip` refactor:
  removed `.background(RoundedRectangle.fill).overlay(stroke)`,
  replaced with `glassEffect(.regular.tint(...).interactive(), in:
  RoundedRectangle(cornerRadius: filmtoneControlCornerRadius, .continuous))`.
  Bundled = `Color.filmtoneAmber.opacity(0.10)` tint + 0.28 rim;
  unbundled = plain `.regular` + white 0.14 rim. Refraction now reads
  at the rim instead of being killed by the opaque tinted RoundedRectangle.
- `FilmtoneEmptyView.swift`: Photo Library + Record buttons now use
  `FilmtoneEmptyCTAButtonStyle(kind: .primary)`; Files uses
  `.secondary`. Bright system-blue `.glassProminent` is gone.
- pbxproj 4-section gate: PASS — `FilmtoneEmptyCTAButtonStyle.swift`
  appears 4 times.
- Simulator build: PASS.
- Device build: PASS (signed).
- Install + launch: PASS — running on iPhone 17 Pro #7.

## Owner walk pending — four reads

(See "Owner walk (acceptance gate)" above.) The 4 reads validate
chip Liquid Glass refraction, CTA hierarchy harmonization, capture
cockpit non-regression, and library-section parity.

If all 4 PASS: archive this active.md →
`2026-05-09-m15-empty-view-liquid-glass.md`, append 1-3 line
strategy.md Completion Log entry, return to M14-C (sidecar provenance
for the master/proxy decision in `export.json`) as the next active.

If any FAIL: iterate before commit.

## Outcome

(Filled at archive time after owner walk acceptance.)
