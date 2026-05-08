# Active: M13-J — TIDE-Informed Capture UI Refinement

Date: 2026-05-08 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **in implementation**

## Why this active exists

M13-H improved the capture UI slightly, but owner reaction was still only about
40% acceptable: 「突貫工事を行ったようにしか感じず根本的に解決できていない」.
M13-I then improved the structure to roughly 60%, but the remaining issue is
visual sophistication: the UI still feels engineered rather than authored.

Treat this as a product-quality miss, not a QA miss. The current screen has
working controls, but it does not yet feel like a deliberately designed camera.
The issue is not missing camera functionality; it is composition, hierarchy,
and tactile identity.

## Product Thesis

**Cinematic Liquid Glass Camera, TIDE material language**

- Live preview is the stage.
- Record / Stop is the emotional center.
- Look and lens are capture rails, not equal-weight tags.
- Storage and quality are camera HUD facts, not long labels.
- Advanced controls are a tray for exceptional use.
- Motion and haptics should make actions feel physical, not decorative.

Signature law:

> One hero action, two capture rails, one compact HUD, one hidden tool tray.

M13-J keeps that structure and changes the material language:

> Halide provides camera hierarchy; TIDE provides polish language.

If a frozen screenshot does not immediately read as a premium camera surface,
the implementation is not done even if every button works.

## Interpretation Sheet

- Source intent: make the capture surface feel fun and desirable to use, not
  merely operable.
- Known facts: M10〜M12 camera behavior works; M13 refactor split the view into
  feature-local child files; writer/session/package/proxy must remain untouched.
- Assumption: the owner wants stronger product experience now, not more camera
  features.
- Risk: adding glow, scale, and more glass to the current layout will repeat
  M13-H's failure because it keeps the same equal-weight capsule pile.
- Motion thesis: only the camera's intent should move strongly. Record breathes;
  selected rail items settle; everything else stays calm.
- Negative constraint: do not make every control shiny, glowing, or animated.
  That is exactly the "突貫工事" failure mode.

## Reference Decomposition — TIDE iOS Mar 2026

Use `/Users/chibatakumi/Downloads/TIDE ios Mar 2026` as visual-language
evidence, not as a literal clone.

What works:

- Soft atmospheric surfaces: dark panels feel like one calm sheet, not a
  stack of controls.
- Muted warm/cool palettes: active states can be visible without screaming.
- Rounded controls have generous air; typography is sparse and quiet.
- Selected states are filled softly or lit from inside, not outlined with
  repeated glow.
- Sheets and drawers are single surfaces with rows embedded inside them.
- Motion feels cushioned and calm; the UI does not bounce for attention.

What to preserve:

- One coherent material system.
- Low-contrast glass/translucency.
- Calm selected state.
- A dark console that feels physically stable.
- Advanced rows as instruments inside one tray.

What to ignore:

- TIDE content, meditation semantics, bottom branding, exact colors, exact
  cards, and any navigation pattern unrelated to capture.

Failure mode to avoid:

- Taking TIDE's rounded shapes while retaining Filmtone's independent capsule
  pile. The causal property is quiet coherence, not the radius.

## Reference Decomposition — Owner Screenshots (Halide / Mobbin)

Use the screenshots as product structure evidence, not as a brand/style to
copy.

What works:

- The live image owns the upper stage. Controls do not fight the subject.
- The bottom third is a deliberate camera console: dark, stable, and physical.
- The shutter is centered and materially distinct from every other control.
- Frequently touched controls sit around the shutter as reachable rails /
  wheels, not as long text chips.
- Tool icons are terse. They communicate mode and state without paragraphs.
- Advanced values use instrument language: scales, ticks, numeric readouts,
  compact state labels.
- The overlay/info panel reads as a single sheet over image, not a stack of
  separate cards.

What to preserve:

- Preview-first composition.
- Bottom camera console with one hero shutter.
- Look / lens as tactile rails near the shutter.
- Compact HUD / instrument readouts instead of descriptive copy.
- A single tray/sheet feel for Advanced.

What to ignore:

- Halide branding, exact icons, bottom advertisement, AR controls, photo-only
  metadata labels, and any UI that conflicts with Filmtone's video capture
  contract.

Failure mode to avoid:

- Copying the reference's visible shapes while keeping Filmtone's current
  equal-weight capsule pile. The causal property is hierarchy, not the icon
  set.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureChrome.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureTopStatusBar.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureBottomDeck.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureAdvancedDrawer.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift`
- `docs/filmtone/ios/v2-capture-gyroflow/active.md`

Do **not** edit:

- `FilmtoneCaptureSession.swift`
- writer / package / proxy generation
- export pipeline
- React / Capacitor

## Read-Only References

- Current M13 archive:
  `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-08-m13-capture-screen-ui-consolidation-liquid-glass.md`
- Liquid Glass research note:
  `docs/filmtone/ios/v2-capture-gyroflow/2026-05-08-ios-camera-preview-liquid-glass-research.md`

Do not merge the research note into this active.

## Subtask Plan

### S13-I1 — Composition Lock (no code, 10 min)

Before editing, write a 5-line implementation note under this section:

1. hero zone
2. HUD zone
3. capture rails zone
4. advanced tray zone
5. what gets removed from first-read

No broad audit. Use the current split files only.

The composition lock must explicitly map the owner reference to Filmtone:

- upper stage = live preview
- bottom console = shutter + rails + Advanced tray
- top HUD = compact facts only
- removed from first-read = long contract strings, repeated storage wording,
  redundant glow

**Lock (2026-05-08 JST):**

1. **Hero zone** — bottom anchor: Record/Stop disc (116 pt). SSD-icon and
   Clear-icon flank as 40 pt circular peripherals so the shutter remains the
   sole large element. Recording status text attaches under the shutter as
   plain text (no pill, no glass), only while recording / stopping.
2. **HUD zone** — top, single tight row: close X at left; one merged glass
   capsule on the right joins storage + 4K30·Log2·ProRes contract with a
   thin internal divider. Manual / WB summary appears just under it as a
   thin amber line, only when active.
3. **Capture rails zone** — single column above the hero: Look strip on
   top, Lens strip below (only when more than one lens). Each rail is a
   single unified glass capsule that internally segments chips; selected
   chip is amber-on-black, unselected chips are plain text on transparent
   ground. No rail labels, no per-chip glass capsule, no per-chip glow, no
   per-chip lift.
4. **Advanced tray zone** — single header pill above the rails. Closed
   state shows `Auto` or `Manual · ISO ... · 1/...s · WB Locked` as one
   compact line. Open state expands a single glass panel above the header
   that contains dense rows; rows do not each carry their own glass
   capsule.
5. **Removed from first-read** — `captureSelectedGlow` and
   `capturePressedLift` (deleted from chrome and all call sites), `Lens` /
   `Look` rail labels, lens canonical-subtext text inside chips, "Controls"
   / "Tap values while idle" microcopy, per-row glass capsules inside the
   advanced drawer, the standalone status pill background, and the
   redundant `SSD` label text under the peripheral icons.

### S13-I2 — Camera Stage Frame

Rebuild the screen frame so the preview feels dominant.

- Top HUD becomes one compact camera status cluster.
- Bottom becomes one intentional camera console, not stacked rows. It should
  feel closer to an instrument deck than a settings form.
- Keep safe-area reach and one-handed use.
- Remove long text chips from first-read.
- No new features.

Acceptance:

- screenshot reads as preview-first
- no more "floating pile of capsules"
- Record area has enough breathing room

### S13-I3 — Hero Shutter

Make Record / Stop the only visually dominant control.

- Treat it like a physical shutter, not a generic button.
- Active state uses one controlled pulse / ring.
- Stop state is unmistakable.
- Status text is attached to the shutter, not another row.
- Haptic is local UI feedback only.
- Reference target: the shutter should be the visual anchor even when the eye
  catches Look / lens / Advanced first.

Acceptance:

- first glance lands on Record / Stop
- recording state feels alive but not noisy
- disabled rules remain unchanged

### S13-I4 — Look / Lens Capture Rails

Rebuild Look and lens controls as capture rails.

- Selected item should feel chosen, not merely tinted.
- Rail labels are secondary and compact.
- Keep Look and lens near the shutter, but not competing with it.
- Use one transition language: selected item settles; non-selected items stay calm.
- Prefer short instrument-like chips / wheels over long labels.

Acceptance:

- switching Look / lens feels intentional and clear
- rail does not feel like a settings form
- no change to Look / lens semantics

### S13-I5 — Advanced Tool Tray

Rework Advanced as a tray, not a settings section.

- Closed state: `Auto`, `Manual · ISO ... · 1/...s`, and/or `WB Locked`.
- Open state: compact controls with density, not a modal settings panel.
- Advanced values should read like camera instruments: ticks, numeric values,
  concise labels.
- Manual state stays visible when closed.
- Unsafe controls remain disabled while recording.

Acceptance:

- advanced is discoverable but secondary
- manual state cannot disappear
- no new camera controls

### S13-I6 — Remove Cheapness

Final visual pass focused on deleting the突貫 feel.

- Remove redundant glows / shadows.
- Use fewer glass styles, not more.
- Make type sizes intentional: HUD small, shutter/status strong, rails medium,
  advanced compact.
- Keep frozen-frame composition clean.

Acceptance:

- no equal-amplitude motion across all controls
- no decorative glass where hierarchy does not need it
- no long text truncation in normal state

### S13-I7 — Install + Owner Walk

Run only the minimum verification:

1. `xcodebuild ... iOS Simulator Debug CODE_SIGNING_ALLOWED=NO`
2. `git diff --check`
3. install on iPhone 17 Pro

Owner walk has only 3 checks:

1. Record / Stop feels like the main event.
2. Look / lens switching feels clear and enjoyable.
3. Advanced closed state still communicates manual / WB state.

## S13-J Implementation Delta

Apply this on top of M13-I:

- Replace the current component-polish look with one dark translucent console
  surface.
- Embed Look / lens / Advanced / SSD controls into that surface.
- Use soft filled selection for Look / lens; remove loud selected glow.
- Make idle Record a white/silver physical shutter; reserve red for recording
  pulse / stop only.
- Convert Advanced open state into one calm instrument tray, not per-row glass.
- Keep top HUD compact and low contrast.
- Do not add new features or touch capture behavior.

## S13-J Verification

- Simulator build.
- `git diff --check`.
- Install on iPhone 17 Pro.
- Owner walk remains:
  1. Record / Stop feels premium and central.
  2. Look / lens switching feels curated, not like settings.
  3. Advanced closed/open states feel calm and usable.

## Done Conditions

- Owner reaction is no longer "突貫工事".
- The capture screen has a clear authored composition in a screenshot.
- Record / Stop is the dominant focal point.
- Look / lens rails are enjoyable and legible.
- Advanced is secondary but not hidden beyond recognition.
- Existing capture behavior remains unchanged.

## Stop Conditions

- Any edit touches `FilmtoneCaptureSession.swift`, writer, package, proxy, or
  export behavior.
- The design adds new camera functionality instead of improving the existing
  surface.
- Simulator build fails twice on the same issue.
- Owner still rates the result below product bar after S13-I7.

## Out of Scope

- Master/proxy export truth (M14).
- New capture controls.
- New camera monitoring tools.
- Full visual design system.
- React / Capacitor cleanup.
- Broad QA matrix.

## Implementation Chat Prompt

Implement M13-I from this active.

The current M13-H UI is functionally okay but still feels like突貫工事 and only
about 40% acceptable. Do not add features. Do not touch capture session,
writer, package, proxy, or export behavior.

Goal: rebuild the capture screen composition so it feels like a premium
Cinematic Liquid Glass Camera:

- preview-first stage
- one hero shutter/stop control
- Look and lens as intentional capture rails
- compact camera HUD
- Advanced as a secondary tool tray

Use the owner reference screenshots as structure evidence:

- live image dominates
- bottom third behaves like a dark camera console
- shutter is centered and physically distinct
- values are instruments, not explanatory chips
- Advanced is one tray/sheet, not scattered cards

Do not copy Halide branding/icons or reproduce the screenshot literally.
Preserve the causal hierarchy.

Avoid the previous failure mode: adding glow/scale/glass to every capsule. The
screen needs authored hierarchy, not more decoration.

Work in this order:

1. Write S13-I1's 5-line composition lock into active.md.
2. Rebuild camera stage frame.
3. Rebuild hero shutter.
4. Rebuild Look / lens rails.
5. Rework Advanced tray.
6. Remove redundant visual noise.
7. Run simulator build, `git diff --check`, install to iPhone 17 Pro, then ask
   owner for the 3-point walk.

Keep verification minimal. Product feel is the gate.
