# Archived: M15-bis — Editor Empty View Redesign (TIDE-inspired card grid) — REJECTED 30点

Status: **REJECTED 30/100**. Up from M15's 20点 but still failing.
Owner critique was tight and product-correct:

1. **Logo / title not mandatory** — owner gave permission to drop the
   hex symbol + wordmark + tagline if it helps the design. M15-bis
   kept all three out of conservative instinct; that real estate is
   stealing visual budget the gradient should own.
2. **背景がない** — the M15-bis backdrop was a pair of nearly-black
   layers (linear gradient `Color.black → Color(0.045, 0.035, 0.020)`
   + faint center radial). Apple Liquid Glass needs **substrate** to
   refract; near-black gives nothing to sample, so the cards / chips
   read as flat translucent rectangles rather than glass.
3. **素材がなければグランジ流体グラデーションでもいい** — owner
   handed two reference images (vibrant fluid gradient grid + soft
   sphere album cover). The empty surface should treat the gradient
   itself as the visual hero, with Liquid Glass elements floating on
   top.

M15-ter (next active) drops the hero block entirely and replaces the
backdrop with a `MeshGradient`-based fluid gradient in Filmtone-amber
+ coral + deep purple + black, blurred for the grunge quality of the
references.

Original active.md content follows for traceability.

---

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **installed on iPhone 17 Pro #7, ready for owner walk** — autonomous execution complete 2026-05-09 02:17 JST

## Why this active exists

M15 shipped at 20/100. Two failure modes:

1. **Mechanical**: the M15 button style applied glass via
   `.background(Color.clear.glassEffect(...))`. SwiftUI 26's correct
   pattern is `glassEffect(_:in:)` directly on the padded content view.
   The background-Color.clear pattern rendered the label behind the
   material, diffusing the text into illegibility.
2. **Design**: three equal-weight stacked CTA pills with amber tint at
   0.18 produced opaque brown rectangles, no hierarchy, no
   atmospheric substrate for Liquid Glass refraction.

Owner direction: **redesign from scratch** using TIDE iOS Mar 2026
references (`/Users/chibatakumi/Downloads/TIDE ios Mar 2026/`).

## TIDE language extracted from references

Reading `TIDE ios Mar 2026 0.png` (start screen), `1.png` / `2.png`
(goal-grid pickers), `4.png` (bedtime picker), `18.png` / `27.png`
(home), the TIDE pattern is:

- **Atmospheric substrate** — real photographs (forest, ocean, sunset)
  give Liquid Glass continuous variation to refract. Filmtone equivalent:
  subtle vertical gradient (near-black → black-with-warmth) so chips +
  cards have something to sample.
- **Silvery / clear Liquid Glass** — TIDE cards are nearly colorless,
  picking up gray-white tones from the photo. **No saturated tint.** The
  M15 amber 0.18 was the opposite of TIDE's restraint.
- **Card grid for "pick your goal"** — 2x2 cards with icon top-left,
  bold title bottom-left, muted subtitle below. Selected = white-filled
  pill; idle = clear glass with thin white rim.
- **Single dominant primary action** (TIDE 0's "Start" button) —
  white-filled pill, tap-target, mostly empty surrounding canvas.
- **Restrained typography** — thin spaced TIDE wordmark, small caps
  section labels ("Now for you"), simple sans-serif.
- **Hierarchy via shape + size, not color** — primary vs secondary
  reads from layout, not from tint differences.

Filmtone is a film-grading product with an existing amber accent
system. We adopt TIDE's *structure* and *material restraint* — not
TIDE's color palette. Filmtone amber stays on icons (camera aperture,
favorite star) but does **not** appear as material tint on chips /
cards / CTAs.

## Layout

```
┌────────────────────────────────────┐
│                                    │
│         [hex icon, ~110pt]         │
│                                    │
│           Filmtone                 │  ← thin spaced wordmark
│        映画調を、片手で。           │  ← muted gray tagline
│                                    │
│       ─── 保存したルック ───        │  ← small caps muted label
│       [Stone glass] [Urban glass]  │  ← clear chips, no amber bg
│                                    │
│  ┌─────────────┐ ┌─────────────┐   │  ← row 1: 2-up cards
│  │ 📷           │ │ 📁           │   │
│  │              │ │              │   │
│  │ フォトライブラリ │ │ ファイル      │   │
│  └─────────────┘ └─────────────┘   │
│                                    │
│  ┌─────────────────────────────┐   │  ← row 2: full-width emphasis
│  │ 🎥                            │   │
│  │                              │   │
│  │ 録画する                      │   │
│  └─────────────────────────────┘   │
│                                    │
└────────────────────────────────────┘
```

The Record card spans full width on row 2 to read as the Filmtone-
authored capture path (slightly emphasized over the two source-import
paths). All three cards share the same glass material; emphasis is
shape-only.

## Scope

### A. New file — `FilmtoneEmptySourceCard.swift`

Replaces the rejected `FilmtoneEmptyCTAButtonStyle.swift`. View component
(not a ButtonStyle) so layout flexibility (`.compact` square cell vs
`.wide` full-width row) is encapsulated rather than fighting SwiftUI's
button-style minimum-frame constraints.

```swift
struct FilmtoneEmptySourceCard: View {
    enum Width { case compact, wide }
    let title: String
    let subtitle: String?
    let systemImage: String
    let width: Width
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) { cardContent }
            .buttonStyle(.plain)
            .disabled(isDisabled)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
                .symbolRenderingMode(.hierarchical)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .frame(
            maxWidth: width == .wide ? .infinity : nil,
            minHeight: width == .wide ? 84 : 110,
            alignment: .topLeading
        )
        .frame(maxWidth: .infinity)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .opacity(isDisabled ? 0.45 : 1)
    }
}
```

Glass is applied **directly** on the padded VStack (correct SwiftUI 26
pattern). No `Color.clear` background trick. No tint — `.regular` only.

### B. `FilmtoneLibraryChip` — drop amber bg tint

Bundled chips communicate "Filmtone-curated" through the **icon color**
(the camera-aperture symbol is already amber via
`Color.filmtoneAmber.opacity(0.86)`). The material becomes plain
`.regular.interactive()` — no amber tint, no opaque brown wash.

Rim drops to a single hairline `Color.white.opacity(0.10)` regardless
of bundled state. Bundled / non-bundled hierarchy reads from the
icon, not from a chip-shape decoration.

### C. `FilmtoneEmptyView` — full body rebuild

- Background: subtle vertical `LinearGradient` from `Color.black` (top)
  to `Color(red: 0.05, green: 0.04, blue: 0.02)` (bottom) so Liquid
  Glass has refraction substrate. The center-warmth radial in the M15
  build stays.
- Symbol hero: kept at 110pt (was 140 in M15). Slightly tighter so
  there's room for wordmark + tagline.
- Wordmark: thin spaced `"FILMTONE"` caps below the symbol, tracking
  ~6pt. Muted white.
- Tagline (Japanese-locale): `"映画調を、片手で。"` muted gray.
- Saved Looks: small caps centered `"保存したルック"` label, then
  `FilmtoneSavedLooksStrip` rendered at compact density. Hidden when
  `library.looks.isEmpty`.
- Source-card grid:
  - HStack: Photo Library `.compact` + Files `.compact`.
  - Below: Record `.wide`.
- Bottom safe-area inset: 24pt.

### D. Drop the M15 button-style file

`FilmtoneEmptyCTAButtonStyle.swift` is deleted (file + 4 pbxproj
entries) so no caller can reach the broken pattern again.

## In Scope

- DELETE `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptyCTAButtonStyle.swift`
- NEW `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptySourceCard.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySection.swift`
  — chip Liquid Glass re-tune (drop amber tint).
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptyView.swift`
  — full body rebuild with the card grid.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  — swap the pbxproj registration (4 entries out, 4 entries in).
- New strings (Japanese / English): `emptyTagline`, optional
  `emptySourcePhotoLibrarySubtitle` / `emptySourceFilesSubtitle` /
  `emptySourceRecordSubtitle` if subtitles ship in M15-bis. **Decision:
  ship without subtitles** in this round to keep the cards compact;
  the subtitle slot in `FilmtoneEmptySourceCard` stays optional for
  future rounds.

## Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/feature+ios-m9-recording-export-completion

# pbxproj 4-section grep gates (expect new file = 4, removed file = 0)
grep -c FilmtoneEmptySourceCard.swift apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
grep -c FilmtoneEmptyCTAButtonStyle.swift apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj

xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug -derivedDataPath /tmp/filmtone-m15bis-dd build
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-m15bis-dd/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

## Owner walk (acceptance gate)

Each must be clearly true before M15-bis archives:

1. **Card text is crisp** — Photo Library / Files / Record titles
   render as sharp white text on Liquid Glass material. No diffusion.
   Glass refracts the gradient backdrop at the rim.
2. **No amber wash** — none of the cards or chips are tinted brown.
   Amber appears only on icons (camera aperture, video.fill,
   folder favorite stars). Background tint is plain `.regular` glass.
3. **Hierarchy reads at a glance** — Record stands out as the wide
   card (Filmtone-authored path). Photo Library / Files share the
   2-up row (external import paths). Saved Looks chips above frame
   the screen as "you have looks; pick a source to use them."
4. **Saved Looks chips refract** — Stone / Urban silhouettes show
   the gradient through the glass; amber survives only as the
   camera-aperture icon. No opaque amber leather feel.
5. **Atmosphere reads as authored, not generic** — center-warm radial
   + vertical gradient + symbol hero land in the upper third; cards
   anchor the lower half; nothing fights for visual dominance.
6. **No capture-cockpit regression** — open the camera, M14-B owner-
   walk state intact.

If any FAIL: iterate before commit.

## Stop Conditions

- Any edit to capture chrome (`FilmtoneCaptureChrome` and friends).
- Any edit to capture session / writer / package / facade / export.
- Two simulator build failures from the same root cause.
- Owner says the redesign still misses the TIDE quality bar.

## Out of Scope (deferred)

- Tagline localization expansion (English-locale string can come later).
- Other editor surfaces (top chrome, library sheet, export panel) —
  unchanged in M15-bis. Audit-and-tune passes after acceptance.
- M14-C (sidecar provenance) — paused while empty view ships.

## Execution log (autonomous run 2026-05-09)

- 02:08-02:17 JST: Step 1-5 executed continuously per active scope.
- M15 archived as REJECTED to
  `archive/2026-05-09-m15-empty-view-rejected.md`. Strategy.md
  Completion Log + Sub-milestones updated with REJECTED + M15-bis
  open log.
- Deleted `FilmtoneEmptyCTAButtonStyle.swift` (the rejected M15
  custom button style with the
  `.background(Color.clear.glassEffect(...))` mistake).
- New file `FilmtoneEmptySourceCard.swift` (~115 lines): View
  component (not a `ButtonStyle`). Glass via direct
  `.glassEffect(.regular.interactive(), in: RoundedRectangle(18))`
  on the padded VStack — canonical SwiftUI 26 pattern. Two widths:
  `.compact` (110pt min height, equal in 2-up row) and `.wide`
  (84pt min height, full row). No tint on material.
- `FilmtoneLibrarySection.swift` `FilmtoneLibraryChip` re-tuned:
  dropped both bundled amber tint and amber rim. Material is plain
  `.regular.interactive()` (silvery clear); rim is hairline white
  0.10 0.5pt. Bundled status now communicated through icon color
  (camera-aperture stays amber) + favorite star. Glass applied
  directly on the padded HStack — no `Color.clear.glassEffect`.
- `FilmtoneEmptyView.swift` body rebuilt: vertical gradient backdrop
  (`Color.black` → `Color(0.045, 0.035, 0.020)`) + center-warm
  radial; symbol hero 110pt centered; `"FILMTONE"` thin spaced
  wordmark + locale-aware tagline (`"映画調を、片手で。"` JA /
  `"Cinematic tone, one tap away."` EN); Saved Looks teaser; card
  grid (Photo Library + Files compact 2-up, Record wide). M15's
  `GlassEffectContainer { VStack { 3 buttons } }` block is gone.
- pbxproj swap: 4-entry replace (id `94` retained) — old
  `FilmtoneEmptyCTAButtonStyle.swift` count = 0, new
  `FilmtoneEmptySourceCard.swift` count = 4.
- Simulator build: PASS.
- Device build: PASS (signed).
- Install + launch: PASS — running on iPhone 17 Pro #7.

## Owner walk pending — six reads

(See "Owner walk (acceptance gate)" above.) The 6 reads validate
crisp card text, no amber wash on material, hierarchy via shape /
size, library chip refraction, atmospheric authored feel, and
capture-cockpit non-regression.

If all 6 PASS: archive this active.md →
`2026-05-09-m15-bis-empty-view-tide.md`, append 1-3 line strategy.md
Completion Log entry, return to M14-C (sidecar provenance).

If any FAIL: iterate before commit.

## Outcome

(Filled at archive time after owner walk acceptance.)
