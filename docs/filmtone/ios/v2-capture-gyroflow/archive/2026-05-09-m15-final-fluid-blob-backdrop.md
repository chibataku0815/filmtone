# Archived: M15-final — Empty View Fluid Blob Backdrop (PASS after v1→v8 iteration)

Status: **PASS** — owner accepted v6 「かなり良くなりました」, v7
delivered dynamic σ pulse, v8 propagated the visual language to the
onboarding view. Single commit landed all M13 + M14-A/B + M15
iteration as `d851b5d8 feat(ios): land M13 capture cockpit + M14
export truth + M15 fluid empty view` (35 files / +6297 / -1096).

## v1 → v8 iteration log (2026-05-09)

The original M15-final scope below targeted a single sphere hero. It
was rejected at the implementation level when owner walked the device
and surfaced bugs and design failures. Each subsequent revision
addressed a specific axis:

- **v1**: sphere not rendering. Cause: `Rectangle().fill(.clear)`
  caused the SwiftUI rasterizer to skip the layer so `colorEffect`
  never invoked the shader. Fix: `.fill(.white)` so opaque pixels
  exist for the shader to operate on.
- **v2**: Apple Liquid Glass UI was removed from action triplet
  (replaced with text-links). Owner caught: 「なんで Apple Liquid
  Glass の UI なくなるの？」 Fix: restored 3 Liquid Glass capsule
  buttons (2-up Photo Library / Files + full-width Record) inside a
  `GlassEffectContainer`. Plus shader smoothing: Gaussian (σ=0.42)
  weighting in place of harsh inverse-square peaks; grain stepped
  at 6 Hz with ±0.025 amplitude instead of 60 Hz hash noise.
- **v3**: still read as a fixed sphere with stuff inside. Owner:
  「球体と流体って違いわかってる？」 Fix: dropped the sphere mask
  entirely. Shader renders 5 (later 8) drifting blobs across the
  full screen; alpha gating based on blob density gives an
  amorphous silhouette that flows.
- **v4**: blobs visible but background pure black, no atmosphere →
  cold contrast with warm pastel blobs. Effects (chromatic
  aberration / film grain / glow) were also static. Fix: shader
  covers full screen at α=1, dark-warm base color, dynamic pulses on
  chroma intensity / grain amp / glow blur radius (independent low
  frequencies).
- **v5**: still failing because tightening σ (0.18 → 0.13) shrank
  blob size while increasing count. Owner: 「blob のサイズが小さく
  なるのはだめ」 Fix: σ back to 0.20 wider, kept 8 blobs, muted
  palette so overlap doesn't blow out.
- **v6**: addressed 「黒があってない」 directly. Honest review
  acknowledged that 0.052 → 0.062 dark-warm bias tweaks were
  cosmetic — anything ≤ 0.10 lightness reads as black. References
  Image #7 / #8 are clearly LIGHT cream pastel substrate.
  **Substrate switched to warm cream `(0.86, 0.82, 0.78)`** + blob
  palette restored to vibrant pastel + `.preferredColorScheme(.light)`
  on the empty view + `Color.primary` for adaptive text/rim across
  shared chip components. **Owner accepted: 「かなり良くなりました」.**
- **v7** (post-acceptance refinement): per-blob anisotropic σ pulse.
  σx and σy each drift independently on unique freq+phase seeds,
  range [0.20, 0.28] with the v6 0.20 as the absolute floor. Shape
  morphs through round → ellipse-h → round → ellipse-v organically.
- **v8** (onboarding alignment): `FilmtoneOnboardingView.swift`
  rewritten to mirror the empty-view visual language so the two
  surfaces feel like one continuous environment. Cream substrate,
  `FilmtoneFluidSphere` backdrop, `.preferredColorScheme(.light)`,
  `Color.primary` adaptive text, Liquid Glass capsule primary CTA
  with amber tint, text-link Skip secondary, preview card uses
  `glassEffect` instead of opaque RoundedRectangle fill.

## Files landed in this lane

- `apps/.../FilmtoneFluidSphere.metal` — Metal `[[stitchable]]`
  color-effect shader. Anisotropic Gaussian blob mixing (8 blobs,
  σ pulse [0.20, 0.28]), 3-channel UV-offset chromatic aberration,
  per-channel hash film grain, full-screen α=1 cream-base composite.
- `apps/.../FilmtoneFluidSphere.swift` — SwiftUI wrapper. Time
  uniform via `TimelineView(.animation)`; sharp + plusLighter
  blurred copy for halation glow.
- `apps/.../FilmtoneEmptyView.swift` — cream substrate + FluidSphere
  backdrop + Liquid Glass action capsules + `.preferredColorScheme
  (.light)`.
- `apps/.../FilmtoneLibrarySection.swift` — `FilmtoneLibraryChip`
  text + rim use `.primary` for adaptive cross-surface behavior.
- `apps/.../FilmtoneOnboardingView.swift` — aligned to same
  vocabulary (v8).

Filename `FluidSphere` is a legacy from the v1 sphere attempt; the
behavior is now "FluidBlobBackdrop". Rename deferred — not blocking.

## Original active.md content follows for traceability

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status (at active time): scoped — owner committed to direction A under "最高レベルの美しい流体グランジアニメーション" bar 2026-05-09

## Why this active exists

Three SwiftUI-only iteration rounds (M15 / M15-bis / M15-ter) failed
at 20 → 30 → ≤20. Owner correctly identified that:

1. The "redesign" instruction had been treated as iteration, not
   structural rethinking.
2. Card sizes were copied from TIDE references without earning
   their footprint with content.
3. MeshGradient 3×3 + blur + vignette is on a fundamentally lower
   quality tier than the polished pastel sphere of reference Image
   #8 — pure SwiftUI gradient stacks have a ceiling that does not
   reach the bar.

After the third rejection, owner asked me to self-assess: "if you
can hit 最高レベル, go A — otherwise stop and propose wireframes." I
committed honestly to "Metal shader for the quality ceiling, otherwise
risk another rejection." Owner then locked direction A under the
explicit bar 「**最高レベルの美しい流体グランジアニメーション**」.

## Design

Reference: Image #8 (album cover, soft pastel sphere on neutral
substrate). Filmtone takes the **structure** (single hero sphere,
minimal supporting elements) and adapts the **palette** for cinematic
identity (warm-leaning pastel + cool counterpoint).

```
┌─────────────────────────────────┐
│                                 │  ← top safe area
│                                 │
│                                 │
│                                 │
│        ╭─────────────╮          │
│       ╱  ✦           ╲         │  ← FilmtoneFluidSphere
│      │  pastel sphere │         │      ~280pt diameter
│      │   blobs drift  │         │      animated, grunge,
│      │  specular HL   │         │      specular highlight
│       ╲              ╱          │      hash-based grain
│        ╰─────────────╯          │
│                                 │
│                                 │
│                                 │
│                                 │
│   保存したルック                   │  ← FilmtoneSavedLooksStrip
│   [Stone] [Urban]                │      (existing chip system)
│                                 │
│                                 │
│   フォトライブラリから始める       │  ← primary text-link
│                                 │      bold white, large
│                                 │
│   ファイル  ·  録画する             │  ← inline secondary
│                                 │      smaller, dimmed
│                                 │
└─────────────────────────────────┘
```

No hero block, no wordmark, no tagline. The sphere is the hero. The
text-link triplet replaces the M15-bis card grid so nothing competes
with the sphere visually.

## Scope

### A. New file — `FilmtoneFluidSphere.metal`

SwiftUI `[[stitchable]]` color-effect shader. Single-pass GPU render
of the sphere's pixels. Function signature receives the local pixel
position + the `half4` sampled color and returns the new color.

Algorithm:

1. **Distance from sphere center** → if outside radius, return clear.
2. **Map position to UV (0..1)** inside the sphere.
3. **Animated blob centers** — 4 blobs, each at a base position +
   `sin(time * freq) * amp` drift. Each blob has a unique frequency
   pair so the motion never re-syncs (organic feel).
4. **Inverse-distance-squared weighting** — for each blob, weight =
   `1 / (distance + ε)²`. Sum weighted colors / sum weights. This
   produces smooth pastel mixing without harsh seams.
5. **Specular highlight** — additive white based on distance from
   upper-left lit point.
6. **Procedural grain** — hash function `fract(sin(dot(pos, vec)) *
   43758.5453)` gives noise; subtract 0.5, scale to ±0.04, add to
   color. Position offset by time gives the grunge-flicker.
7. **Edge falloff** — `smoothstep(radius, radius*0.92, dist)` softens
   the sphere edge so it blends instead of clipping hard.

Pastel palette (Filmtone identity, warm-leaning):

| Blob | Color (RGB) | Note |
|---|---|---|
| 1 | 0.55 / 0.78 / 0.92 | ice blue (cool counterpoint) |
| 2 | 0.96 / 0.62 / 0.50 | coral (warm anchor) |
| 3 | 0.98 / 0.83 / 0.62 | soft amber (Filmtone-aligned) |
| 4 | 0.94 / 0.78 / 0.85 | soft pink (warm-rose accent) |

### B. New file — `FilmtoneFluidSphere.swift`

SwiftUI wrapper. `TimelineView(.animation)` drives the time uniform.
The shader is bound via `ShaderLibrary.filmtoneFluidSphere(...)` and
applied via `.colorEffect`. Adds:

- Outer drop shadow for separation from substrate.
- Subtle scale-breath via `scaleEffect(1 + sin(t * 0.13) * 0.018)`.
- Frame at 280pt × 280pt.

### C. `FilmtoneEmptyView.swift` body rebuild

- Background: dark warm `Color(red: 0.05, green: 0.04, blue: 0.025)`
  (very dark, slight warmth bias). The sphere brings the light.
- Hero: `FilmtoneFluidSphere()` centered, top third.
- Saved Looks: existing `FilmtoneSavedLooksStrip` (rendered when
  `library.looks` not empty). Chrome unchanged from M15-bis re-tune.
- Action triplet:
  - Primary: large bold white text-link "フォトライブラリから始める"
    centered, with a small ▶ glyph.
  - Secondary: inline "ファイル  ·  録画する" centered, 50% opacity.
  - Both `Button(_:action:)` with `.buttonStyle(.plain)` so they read
    as text-links not chrome buttons.

### D. Files to delete

- `FilmtoneEmptyGradientBackdrop.swift` (M15-ter MeshGradient — replaced).
- `FilmtoneEmptySourceCard.swift` (M15-bis card — replaced by text-links).

## Edit Targets

- DELETE `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptyGradientBackdrop.swift`
- DELETE `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptySourceCard.swift`
- NEW `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneFluidSphere.metal`
- NEW `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneFluidSphere.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEmptyView.swift` —
  full body rebuild for sphere + text-link layout.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  — pbxproj 4-section swap (-2 +2 net 0). Note: `.metal` files use
  `lastKnownFileType = sourcecode.metal`; the rest of the four-section
  registration is identical to a `.swift` file.

## Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/feature+ios-m9-recording-export-completion

# pbxproj 4-section gates
for f in FilmtoneEmptyGradientBackdrop.swift FilmtoneEmptySourceCard.swift FilmtoneFluidSphere.metal FilmtoneFluidSphere.swift; do
  echo "$f $(grep -c "$f" apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj)"
done
# expect: backdrop=0, source-card=0, sphere.metal=4, sphere.swift=4

xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug -derivedDataPath /tmp/filmtone-m15final-dd build
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-m15final-dd/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

## Owner walk (acceptance gate)

Sphere quality:

1. **Sphere is fluid + grunge + animated** — pastel blobs visibly
   drift inside the sphere; specular highlight reads as soft glass
   reflection at upper-left; subtle grain is present (film-stock feel,
   not noisy).
2. **Color mixing is smooth** — no hard seams between blobs; the
   transition from coral → amber → pink → ice-blue reads as one
   continuous fluid surface.
3. **Animation is calm** — drift is slow enough to feel meditative,
   not nervous. Breath scaling is barely noticeable but present.
4. **Sphere shape is clean** — edge falls off softly into the
   substrate (no hard circle clip), background does not bleed
   through harshly.

Layout:

5. **No hero clutter** — no symbol, no wordmark, no tagline. The
   sphere is the only large visual element.
6. **Saved Looks chips quiet, functional** — Stone / Urban present
   when applicable, do not compete with the sphere.
7. **Action triplet quiet** — primary text-link reads as the
   recommended path, secondary as inline alternates. No card chrome.

System:

8. **No capture-cockpit regression** — open the camera, M14-B owner-
   walk state intact.

If sphere quality fails: iterate the shader (palette, drift rates,
grain density, blob count). If layout fails: iterate spacing /
typography. **Do not** open M14-C until M15-final passes.

## Stop Conditions

- Any edit to capture chrome / session / writer / package / facade /
  export.
- Two simulator build failures from the same root cause.
- Metal shader compile error after one fix attempt — escalate to
  pure-SwiftUI fallback (multi-radial-gradient stack) and document.
- pbxproj registrations off (any of the 4 expected counts wrong).
- Owner says the sphere quality still misses 最高レベル.

## Execution log (autonomous run 2026-05-09)

- 02:30-02:45 JST: Step 1-6 executed continuously per active scope.
- M15-ter archived to
  `archive/2026-05-09-m15-ter-mesh-gradient-rejected.md` with the
  three failure reasons: iteration-vs-redesign / unjustified card
  size / low-quality MeshGradient. Strategy.md Completion Log +
  Sub-milestones updated with M15-ter REJECTED + M15-final open.
- Deleted `FilmtoneEmptyGradientBackdrop.swift` (M15-ter mesh
  gradient) and `FilmtoneEmptySourceCard.swift` (M15-bis card grid).
- New file `FilmtoneFluidSphere.metal` (~110 lines): SwiftUI
  `[[stitchable]]` color-effect shader. Inverse-distance-squared
  weighted blob mixing (4 pastel blobs: ice blue / coral / soft
  amber / soft pink), per-blob sin/cos drift on unique frequency
  pairs, additive specular at upper-left, hash-based grain offset
  by time, smoothstep edge falloff.
- New file `FilmtoneFluidSphere.swift` (~55 lines): SwiftUI wrapper.
  `TimelineView(.animation)` drives time uniform; `Rectangle().fill(.clear).colorEffect(...)`
  hosts the shader; subtle scale-breath via
  `scaleEffect(1 + 0.018 * sin(t * 0.13))`; soft drop-shadow.
- `FilmtoneEmptyView.swift` rebuilt: dark-warm substrate, sphere
  centered top-third, `FilmtoneSavedLooksStrip` (M15-bis chip re-tune
  intact), action triplet = single primary text-link
  ("フォトライブラリから始める" with ▶ glyph) + inline secondary
  ("ファイル · 録画する"). No card chrome, no hero block.
- pbxproj: 2 deleted (Backdrop / SourceCard) + 2 added (Sphere.swift
  / Sphere.metal with `lastKnownFileType = sourcecode.metal` for
  the Metal file). All 4 grep gates: 0 / 0 / 4 / 4 ✓.
- **Initial build error**: Metal Toolchain not installed locally.
  Recovered with `xcodebuild -downloadComponent MetalToolchain`
  (~688MB asset download, no sudo required).
- Simulator build: PASS (Metal compile clean).
- Device build: PASS (signed).
- Install + launch: PASS — running on iPhone 17 Pro #7.

## Owner walk pending — eight reads

(See "Owner walk (acceptance gate)" above.) Sphere quality (1-4),
layout (5-7), system (8). Sphere quality is the load-bearing axis;
if any of 1-4 misses 最高レベル the shader needs another iteration.

If all 8 PASS: archive this active.md →
`2026-05-09-m15-final-fluid-sphere.md`, append 1-3 line strategy.md
Completion Log entry, return to M14-C as the next active.

If sphere quality fails: iterate the shader (palette, drift
frequencies, grain density, blob count, specular intensity). If
layout fails: iterate spacing / typography. **Do not** open M14-C
until M15-final passes.

## Fix log (2026-05-09 02:55)

Owner walked first M15-final cut and called out two failures:
"なんで Apple Liquid Glass の UI なくなるの？" + "流体も表示できてない"
+ "なんで適当に対応するの？".

**Bug 1 — sphere not rendering**:
`Rectangle().fill(Color.clear).colorEffect(...)` was the source. The
SwiftUI rasterizer can skip layers with no opaque pixels →
`colorEffect` shader never invoked → sphere invisible. Fixed by
switching to `Rectangle().fill(.white)` so the rasterizer commits
pixels for the shader to operate on. The shader ignores the input
color (computes its own pastel pixel from `position + size + time`)
and returns alpha=0 outside the radius, so white fill does not bleed
into the corners.

**Bug 2 — Apple Liquid Glass UI removed from actions**:
The first M15-final replaced the action triplet with plain text-
links. That dropped the Apple Liquid Glass UI the owner had been
asking for since R1. The text-link pattern was over-applied from
TIDE 0 reference; the actual user requirement was "fluid sphere as
gradient hero **+** Liquid Glass UI on actions" (the sphere provides
the substrate; the glass actions refract it). Fixed by replacing
text-links with three Liquid Glass capsule buttons — 2-up Photo
Library / Files compact + full-width Record — inside a shared
`GlassEffectContainer` so adjacent capsules merge as one material.

**Bug 3 — shader blob mixing too sharp**:
`1/d²` weighting produced harsh peaks at blob centers (visible
"dots"). Replaced with Gaussian `exp(-d² / σ²)` (σ = 0.42) for
smooth pastel cloud blending matching reference Image #8.

**Bug 4 — grain too noisy**:
Per-frame hash refresh at 60Hz produced harsh static. Stepped to
6Hz refresh (`floor(time * 6)`) for film-stock flicker; amplitude
±0.025 instead of ±0.04 so it reads as grain texture, not noise.

Sim + device builds: PASS. Install + launch: PASS — running on
iPhone 17 Pro #7.

## Outcome

(Filled at archive time after owner walk acceptance.)
