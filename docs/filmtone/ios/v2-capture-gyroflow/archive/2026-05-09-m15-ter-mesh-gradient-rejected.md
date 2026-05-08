# Archived: M15-ter — REJECTED ≤20点 (low-quality MeshGradient backdrop + oversized cards)

Status: **REJECTED ≤20**. Owner critique was direct:

- **「設計し直せって入ってんだろ」** — three rounds of "redesign" had
  produced iteration, not redesign. The core structure (cards + chips
  + some-kind-of-background) had not been questioned at the design
  level once. The owner finally said it explicitly.
- **「なんで意味なく要素でかくすんの？」** — the card sizes
  (`minHeight: 110` compact, `84` wide) had no design intent. They
  were copied from TIDE references that justified their size with
  long-form text content; my cards held only an icon + a one-line
  title. The card area was not earning its size.
- **「なんで背景こんな低クオリティ？」** — the M15-ter MeshGradient
  3×3 with hardcoded RGB stops + `blur(radius: 18)` + a vignette
  overlay produced a muddy, amateur substrate. Reference Image #8
  (single soft pastel sphere with specular highlight, subtle grain,
  smooth color falloff) is on a completely different quality tier
  that pure SwiftUI gradient stacks can not reach.

After acknowledging the failures and asking for direction, owner
committed to direction A (Image #8 single-sphere hero) under the
condition: 「**最高レベルの美しい流体グランジアニメーション**」.
M15-final implementation moves to a Metal-shader-driven sphere so
the quality ceiling matches the bar. SwiftUI gradient stacks are
abandoned for the empty-view backdrop.

Original active.md content follows for traceability.

---

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **installed on iPhone 17 Pro #7, ready for owner walk** — autonomous execution complete 2026-05-09 02:27 JST

## Why this active exists

M15-bis improved on M15 (20→30) by fixing the `glassEffect` mechanical
mistake and dropping the amber wash from materials, but the surface
still failed because Apple Liquid Glass had **no substrate to refract**.
Near-black backdrops produce flat translucent rectangles; Liquid Glass
only reads as glass when there is meaningful color variation behind it.

Owner gave clear direction:

- ロゴやタイトルは必須ではない — drop hero block if it helps.
- 背景がない → Apple Liquid Glass が活かせていない — the substrate
  must give the cards / chips something rich to refract.
- 素材がなければ**グランジ流体グラデーション**でもいい — references:
  vibrant amber / coral / pink / purple fluid blob grid + soft pastel
  sphere album cover.

M15-ter drops the symbol / wordmark / tagline and replaces the
backdrop with a SwiftUI `MeshGradient` fluid gradient. The cards +
chips from M15-bis stay verbatim — the mechanical glass implementation
landed; only the substrate behind it was wrong.

## Decision: MeshGradient + soft blur, no animation

`MeshGradient(width: 3, height: 3, ...)` with 9 color stops:

- Filmtone-amber bloom in the upper-mid region (warm hero color).
- Coral / deep amber on the left and bottom-mid (extending the warm
  palette).
- Cool counterpoint (deep purple-blue) at center-right and
  bottom-right (so the gradient breathes between warm and cool —
  matches the references' multi-hue balance).
- Black / near-black at the corners (so the gradient feels grounded,
  not a flat color field).

Add `.blur(radius: 18)` for the grunge / hand-painted quality of the
references. No motion in M15-ter — calm static gradient is the right
first step; animation is a polish lane that can land later if owner
asks.

A faint vignette overlay (radial gradient `clear → black 0.18` from
center to edge) tightens the corners without darkening the central
bloom area, helping the Liquid Glass cards stand out without bleeding
into the gradient.

## Layout

```
┌────────────────────────────────────┐
│   [Mesh fluid gradient — full]     │
│                                    │
│        ── vignette tightens ──     │
│                                    │
│                                    │
│                                    │
│                                    │
│  ── 保存したルック ──              │  ← appears only when looks.count > 0
│  [Stone] [Urban]                   │
│                                    │
│                                    │
│  ┌───────────┐ ┌───────────┐       │
│  │ Photo     │ │ Files     │       │
│  └───────────┘ └───────────┘       │
│  ┌─────────────────────────┐       │
│  │ Record                  │       │
│  └─────────────────────────┘       │
└────────────────────────────────────┘
```

No hero block. No wordmark. No tagline. The gradient IS the hero.

## Scope

### A. New file — `FilmtoneEmptyGradientBackdrop.swift`

Owns the `MeshGradient` + vignette stack. Lives in its own file so
future iteration on the gradient (different palette, motion,
photographic substrate) stays focused. ~50 lines.

```swift
struct FilmtoneEmptyGradientBackdrop: View {
    var body: some View {
        ZStack {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
                ],
                colors: meshColors
            )
            .blur(radius: 18)

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.18)],
                center: .center, startRadius: 240, endRadius: 720
            )
        }
    }

    private var meshColors: [Color] {
        [
            Color(red: 0.10, green: 0.06, blue: 0.04),  // top-left dark warm
            Color(red: 0.95, green: 0.55, blue: 0.22),  // top-mid amber bloom
            Color(red: 0.08, green: 0.05, blue: 0.06),  // top-right dark
            Color(red: 0.78, green: 0.32, blue: 0.20),  // mid-left coral
            Color(red: 1.00, green: 0.72, blue: 0.25),  // center filmtone amber
            Color(red: 0.32, green: 0.22, blue: 0.42),  // mid-right cool purple
            Color(red: 0.04, green: 0.03, blue: 0.02),  // bottom-left black
            Color(red: 0.55, green: 0.26, blue: 0.18),  // bottom-mid deep amber
            Color(red: 0.06, green: 0.06, blue: 0.10),  // bottom-right cool dark
        ]
    }
}
```

### B. `FilmtoneEmptyView` body — drop hero, swap backdrop

- Replace `backgroundLayer` block with `FilmtoneEmptyGradientBackdrop()`.
- Delete `hero` property (symbol + wordmark + tagline).
- Body collapses to: backdrop + Spacer + Saved Looks (when present) +
  card grid + bottom inset.
- Top safe-area inset becomes ~24pt of breathing room before the
  Saved Looks section, ensuring the gradient bloom is visible above
  the chip strip.

### C. Cards / chips stay verbatim

`FilmtoneEmptySourceCard` and `FilmtoneLibraryChip` from M15-bis are
unchanged. The mechanical glass implementation was correct; only the
substrate behind it was wrong. With a vibrant gradient under them, the
existing `.glassEffect(.regular.interactive(), in: ...)` calls now
actually produce refraction at the rims — the missing Liquid Glass
behavior the owner flagged.

## In Scope

- NEW `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptyGradientBackdrop.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptyView.swift`
  — backdrop swap + hero block removal.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  — 4-section registration for the new file.

## Out of Scope (deferred)

- Animation on the gradient (slow drift / breathing). Calm static
  gradient first.
- Photographic substrate (TIDE-style real photos). Synthesized
  MeshGradient is the right baseline; photo backdrops add asset and
  attribution complexity.
- Card-internal gradient blobs (the Image #7 reference style where
  each card has its own gradient). Would compete with the backdrop;
  card transparency is the cleaner direction.
- Other editor surfaces (top chrome, library sheet, export panel) —
  unchanged in M15-ter.
- M14-C (sidecar provenance) — paused while empty view ships.

## Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/feature+ios-m9-recording-export-completion

grep -c FilmtoneEmptyGradientBackdrop.swift apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
# expect 4

xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug -derivedDataPath /tmp/filmtone-m15ter-dd build
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-m15ter-dd/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

## Owner walk (acceptance gate)

Each must be clearly true before M15-ter archives:

1. **Backdrop is a fluid gradient** — vibrant amber / coral / cool
   counterpoint blooms fill the screen. Reads as authored atmosphere,
   not a placeholder.
2. **Liquid Glass refracts** — Saved Looks chips and source cards
   pick up gradient color through the glass. Rims show specular /
   refraction, not just an opaque outline.
3. **Hierarchy reads at a glance** — Record card stands as the
   Filmtone-authored path; Photo Library / Files share the 2-up.
   Saved Looks (when present) anchor above the cards.
4. **No hero clutter** — symbol / wordmark / tagline are gone. The
   gradient is the visual hero; cards anchor the bottom; Saved Looks
   chips bridge between.
5. **No capture-cockpit regression** — open the camera, M14-B owner-
   walk state intact.

If any FAIL: iterate before commit.

## Stop Conditions

- Any edit to capture chrome / session / writer / package / facade /
  export.
- Two simulator build failures from the same root cause.
- pbxproj 4-section grep returns < 4 for the new file.
- Owner says the gradient feels generic or the colors fight the
  Filmtone identity (cinematic / amber-led).

## Execution log (autonomous run 2026-05-09)

- 02:18-02:27 JST: Step 1-4 executed continuously per active scope.
- M15-bis archived as REJECTED 30 to
  `archive/2026-05-09-m15-bis-empty-view-rejected.md`. Strategy.md
  Completion Log + Sub-milestones updated with the 30 verdict + the
  three-point owner critique (drop-hero permission / no-substrate /
  grunge-fluid-gradient direction).
- New file `FilmtoneEmptyGradientBackdrop.swift` (~75 lines):
  `MeshGradient` 3×3 with 9 color stops (warm amber center bloom +
  coral/deep amber along the upper-mid axis + cool-purple
  counterpoint at center-right and bottom-right + dark-warm corners).
  18pt blur for grunge / hand-painted feel. Outer-radial vignette
  on top tightens the corners.
- `FilmtoneEmptyView.swift` rebuilt:
  - dropped `backgroundLayer` (the M15-bis near-black layer
    that gave Liquid Glass nothing to refract);
  - dropped `hero` block (symbol + wordmark + tagline) per owner
    permission;
  - body collapsed to backdrop + flexible spacer + Saved Looks
    teaser (when present) + source card grid + bottom inset.
- `FilmtoneEmptySourceCard.swift` and `FilmtoneLibraryChip` (in
  `FilmtoneLibrarySection.swift`) unchanged — their mechanical glass
  implementation was correct, only the substrate behind them was
  wrong. With the MeshGradient in place, the existing
  `.glassEffect(.regular.interactive(), in: ...)` calls now produce
  visible refraction at the rims.
- pbxproj 4-section gate: `FilmtoneEmptyGradientBackdrop.swift` = 4 ✓
- Simulator build: PASS.
- Device build: PASS (signed).
- Install + launch: PASS — running on iPhone 17 Pro #7.

## Owner walk pending — five reads

(See "Owner walk (acceptance gate)" above.) The 5 reads validate
fluid backdrop, Liquid Glass refraction, hierarchy, no hero clutter,
and capture-cockpit non-regression.

If all 5 PASS: archive this active.md →
`2026-05-09-m15-ter-empty-view-fluid-gradient.md`, append 1-3 line
strategy.md Completion Log entry, return to M14-C (sidecar
provenance) as the next active.

If any FAIL: iterate the specific axis (gradient palette / blur /
vignette / layout) before commit.

## Outcome

(Filled at archive time after owner walk acceptance.)
