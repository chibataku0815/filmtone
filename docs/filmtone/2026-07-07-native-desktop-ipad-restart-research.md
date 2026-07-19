# Filmtone Native Desktop / iPad Restart Research

Date: 2026-07-07 JST

## Purpose

この調査は、しばらく止まっていた Filmtone の次の本質作業を決めるための
再開メモである。主戦場は性能余力がある Native Desktop と Native iPad
版に置く。iPhone はそこから性能的に成立し、操作面でも破綻しない機能だけを
選別して取り込む。

外殻作業は最小限にする。release hygiene、portfolio bump、広い QA、
過剰な文書整理は、製品挙動・画質・書き出し品質が十分に良くなった後にだけ
行う。

## Method

- Read routing and source-of-truth docs:
  - `AGENTS.md`
  - `README.md`
  - `CLAUDE.md`
  - `apps/filmtone-desktop-macos/README.md`
  - `docs/filmtone/desktop/README.md`
  - `docs/filmtone/desktop/native-desktop-v2/strategy.md`
  - `apps/capacitor-film-lab-ios/CLAUDE.md`
  - `docs/filmtone/ios/README.md`
- Inspected current git state and diffs without reverting or staging existing
  changes.
- Ran release truth scripts because this document states current public
  release/version truth.
- Queried Apple App Store lookup for the separate iPhone and iPad bundle IDs.
- Searched Apple developer documentation only for current platform constraints
  relevant to performance and App Store screenshot assets.

No tests or test-like verification were run. The repository global rule says to
skip tests unless the user explicitly asks for testing in the current task.

## Current Repo State

- Branch: `main`
- Upstream: `origin/main`
- State: ahead by 2 commits, with a dirty working tree.
- No `docs/filmtone/desktop/native-desktop-v2/active.md` exists. That means no
  current Native Desktop v2 implementation subtask is open.
- The dirty tree is not random. It clusters around:
  - Native Desktop Film Damage, export, Highlight Reel, and release docs.
  - Native iPad release rail, editor ergonomics, Highlight Reel, Film Damage,
    and App Store screenshot upload behavior.
  - Shared Swift highlight marker contract.
  - Focused verification files touched by previous work. These were inspected
    as existing changes only; this task did not modify tests.

## Current Public Truth

Checked on 2026-07-07 JST.

### Desktop

`check-filmtone-release-truth.sh` reports:

- Native Desktop local marketing version: `1.16`
- Native Desktop local build version: `12`
- Public update metadata `latestVersion`: `1.16`
- Latest desktop tag: `desktop-v1.12`
- Commits after latest tag: `11`

Interpretation: public Desktop is `1.16`, but tag/history hygiene has not caught
up with the release rail. Treat `1.16` as public truth and do not infer Desktop
state from the latest tag.

### iPad

Apple App Store lookup for `com.chibatakumi.film.lab.ipad` reports:

- Track name: `Filmtone Studio`
- Public version: `1.4`
- Current version release date: `2026-06-07T15:50:15Z`
- Minimum OS: `26.0`

Interpretation: the iPad App Review submission recorded in the June 7 release
log appears to have gone public. Older notes saying public iPad remained `1.3`
are now stale.

### iPhone

`check-filmtone-ios-truth.sh` and Apple lookup for
`com.chibatakumi.film.lab.ios` report:

- Public version: `1.13`
- Public current version release date: `2026-05-22T04:50:19Z`
- Local Xcode marketing version: `1.11`
- Local Xcode build version: `15`

Interpretation: iPhone public and local implementation state are not aligned.
Do not make iPhone the lead rail until the local candidate story is cleaned up.
Use iPhone as a selective downstream target after Desktop/iPad quality and cost
are known.

## Product Direction

The intended product direction is:

1. Build the strongest editing/export experience first on Native Desktop and
   Native iPad.
2. Use iPad as the touch-first, large-preview editor rail.
3. Use Desktop as the performance and long-session export rail.
4. Pull only suitable pieces into iPhone after measuring or reasoning about
   performance cost, UI density, battery/thermal risk, and export duration.

This is a better product path than treating all platforms as equal. Heavy
effects, longer Highlight clips, split exports, and larger preview controls
belong first on Desktop/iPad. iPhone should not inherit every feature by
default.

## Important Findings

### 1. Film Damage is the strongest current product theme

Recent work changed Film Damage from white-dot dust toward darker debris,
hairline scratches, and material surface damage. The same core direction exists
in Desktop and iPad/iOS kernel copies:

- Desktop kernel:
  `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- iPad/iOS export kernel:
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`

The June 6 archived notes record two important outcomes:

- Visual direction: dark debris and fine marks are now visible on bright
  material instead of white sparkle dominating the read.
- Performance direction: the 3840 strong probe improved from about
  `21.018ms/frame` to about `16.955ms/frame` after broad-phase exits and less
  unconditional debris work.

Product implication: Film Damage is ready to become a main Desktop/iPad value
proposition if it survives owner review on real footage. It should not be
watered down for iPhone first.

### 2. Highlight Reel has become a real export product, not a one-second tool

Dirty tree changes and archived notes show a cross-platform Highlight Reel
upgrade:

- Shared contract adds `FilmtoneHighlightReelOptions`, supported durations
  `[1, 3, 5, 10]`, and combined/separate output semantics.
- Desktop export can write one combined reel or separate clips.
- iPad export can save/share split clips and show finished-state clip counts.

Product implication: Highlight Reel can become a fast, useful output format for
Desktop/iPad. The next question is not whether the feature exists, but whether
the export flow feels obvious and whether longer clips remain performant with
Film Damage enabled.

### 3. Native iPad is now a real separate product rail

The iPad rail is no longer just a repackaged iPhone path:

- Bundle ID: `com.chibatakumi.film.lab.ipad`
- Scheme: `App-iPad`
- Payload: `Payload/App-iPad.app`
- Public App Store version: `1.4`

The Fastfile work also hardens screenshot upload by generating App Store
Connect-ready iPad display sets. Apple documents landscape iPad accepted sizes
including `2752 x 2064` for 13-inch displays and `2360 x 1640` for 11-inch
displays, which matches the current asset-generation direction.

Product implication: iPad should be treated as a first-class native editor with
its own interaction design, not as an iPhone derivative.

### 4. iPad touch ergonomics are in active improvement

The dirty tree introduces `FilmtonePadTouchControls.swift` and rewires iPad
Look / Adjust / Toolbar / Timeline controls around larger touch targets and
shared metrics. This is product work, not decoration:

- 48 pt minimum controls.
- Larger icon hit areas.
- Slider rows with stable value labels and reset buttons.
- Backlight Veil moved from a segmented picker into touch chips.
- Timeline scrub area and toolbar source label get more stable sizing.

Product implication: this should continue, because iPad value depends on
large-preview, low-friction editing. The work should stay focused on active
editing and export flows, not settings pages or ornamental UI.

### 5. Current docs have truth drift

`strategy.md` has mixed release truth:

- Top-level current state says public Desktop `1.16`.
- The Release Cutover State section still contains `1.15`.
- The June 7 archive says Desktop `1.16` public and iPad `1.4` submitted.
- Live Apple lookup now says iPad `1.4` public.

Product implication: this is not the next core product task, but before a
release claim or public copy claim, the strategy doc should be corrected with a
small truth-sync note. Do not spend a broad cleanup pass before product work.

## External Platform Notes

- Apple Core Image performance guidance says performance scales with output
  pixels and recommends smaller render targets where possible. This supports
  the existing FHD-default / 4K-explicit-choice direction and the kernel
  broad-phase optimization path.
- Apple AVFoundation + Metal material describes efficient video pipelines using
  AVFoundation, Metal, Core Image, or custom Metal shaders. This supports a
  future Desktop/iPad-only heavy-render path if Core Image kernels become the
  limiting factor.
- Apple Metal docs position Metal as a low-overhead graphics/compute API for
  Apple silicon, and Apple sample code includes multistage image filters using
  heaps and fences. That is relevant for future heavy effects, but it should not
  distract from finishing the current Core Image product path first.
- Apple App Store screenshot specs confirm the iPad 13-inch and 11-inch
  landscape sizes used by the current Fastfile generation approach.

Sources:

- Apple Core Image performance:
  https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_performance/ci_performance.html
- Apple AVFoundation / Metal EDR video:
  https://developer.apple.com/videos/play/wwdc2022/110565/
- Apple Metal:
  https://developer.apple.com/metal/
- Apple Metal sample code:
  https://developer.apple.com/metal/sample-code/
- Apple App Store screenshot specifications:
  https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## Recommended Next Active Task

Placement:

`docs/filmtone/desktop/native-desktop-v2/active.md`

Reason:

Recent completed cross-platform tasks for Film Damage, Highlight Reel, Desktop
release, and iPad release already use the Native Desktop v2 lane as the compact
coordination point. The work is Desktop/iPad-led and should not open a broad
iOS lane first.

Proposed title:

`Native Desktop And iPad Performance-Led Export Quality Reset`

Goal:

Make Film Damage and Highlight Reel feel production-ready on Native Desktop and
Native iPad before deciding what to carry to iPhone.

Scope:

- Confirm the current dirty Film Damage and Highlight changes represent the
  intended product state.
- Review real-footage behavior on Desktop/iPad conceptually and, when requested,
  with focused visual/export checks.
- Keep FHD as the default practical export rail and keep 4K explicit.
- Decide iPhone inclusion rules:
  - include lightweight default Film Damage only if cost is acceptable;
  - keep heavy Film Damage / 4K / long Highlight combinations Desktop/iPad-led;
  - avoid cramming Desktop/iPad controls into iPhone.
- Record a small truth-sync correction only if a release/version claim is needed
  during the task.

Out of scope:

- Portfolio bump.
- Legacy Electron.
- Full QA sweep.
- New App Store metadata unless a release is explicitly chosen.
- Broad iPhone parity.

Done conditions:

- Desktop/iPad product direction for Film Damage and Highlight Reel is decided.
- The next implementation edits are scoped to a single feature lane.
- iPhone adoption has a clear include/defer table instead of implicit parity.
- No public release claim remains based on stale `1.15` or iPad `1.3` text.

## Secondary Task Candidates

### iPad Native Editor Ergonomics Pass

Use this if the next priority is touch experience rather than export quality.

Focus:

- Finish `FilmtonePadTouchControls.swift` integration.
- Make Look, Adjust, Backlight Veil, Timeline, and Export controls comfortable
  under finger input.
- Preserve preview area and avoid dense iPhone-like controls.

Why it matters:

iPad's product advantage is a large, tactile editing surface. This is core
quality, not outer-shell polish.

### Release Truth Sync

Use this only after product work or before making release claims.

Focus:

- Update `strategy.md` so Desktop `1.16` and iPad public `1.4` are consistent.
- Confirm whether the untracked archive and release-note files should be kept.
- Do not tag, stage, commit, push, or bump portfolio unless explicitly asked.

Why it is lower priority:

It improves coordination, but does not improve the product surface by itself.

### iPhone Performance Filter

Use this after Desktop/iPad quality is settled.

Focus:

- Build a table of Desktop/iPad features and decide iPhone status:
  `ship`, `ship reduced`, `hide`, or `defer`.
- Criteria: frame/render cost, thermal risk, screen density, export wait, and
  whether the control can be made obvious on a small screen.

Why it should not lead:

iPhone local source truth is currently behind the public App Store rail, and the
device has less performance/UI margin for the heavy features that make the
Desktop/iPad product interesting.

## Open Questions

- Which real footage should be the visual acceptance target for Film Damage:
  pale sky/water footage, skin/interior footage, or both?
- Should Highlight Reel be positioned as a fast preview/social output, or as a
  practical editing extraction tool?
- For iPhone, is the desired stance "reduced but present" or "only stable
  essentials" for heavy effects?

These questions do not block the next active task. They should be answered when
the task reaches the product decision point.

## Copy / History Impact

No public copy was changed by this research document.

Article Opportunity: No story. This is an internal restart and prioritization
document.

Change-History Opportunity: Developer note. The notable history point is the
product split: Native Desktop and Native iPad now lead performance-heavy
editing/export work, while iPhone becomes a selective downstream rail.
