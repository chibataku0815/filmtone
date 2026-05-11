# Active — Phase 2B-4 SharedGradeProcessor / MotionBlur / OpticalKernels Bundle

Date: 2026-05-11 JST
Phase: Phase 2B — ExportSession public-surface split (sub-stage 4 of N)
Milestone: Bounded handoff slice. Lift the three coupled top-level types
that make up the live-preview ↔ export shared visual contract out of
`FilmtoneExportSession.swift`. The three types share an access-modifier
ladder (`fileprivate ↔ private ↔ default internal`) so they have to move
atomically. Public API of `FilmtoneExportSession` is unchanged.

## Owner directive (carry-over from 2B-1 / 2B-2 / 2B-3)

The `feedback_no_extension_only_file_for_god_object_split` rule still
applies. None of the moved types becomes an `extension
FilmtoneExportSession` file. Each is its own top-level type in a new
file. No public surface change.

## Goal

Move three top-level Swift types out of `FilmtoneExportSession.swift`:

| Type | Current lines | Kind | New path |
|---|---|---|---|
| `final class FilmtoneSharedGradeProcessor` | 3185–3257 (~73 lines) | default `internal` cross-file type | `Look/FilmtoneSharedGradeProcessor.swift` |
| `fileprivate final class FilmtoneMotionBlurAccumulator` | 3265–3447 (~183 lines) | `fileprivate`, all 5 consumers live inside ExportSession.swift today | `Export/Internal/FilmtoneMotionBlurAccumulator.swift` |
| `private enum OpticalKernels` | 3449–4094 (~646 lines) | `private`, all 18 consumers live inside ExportSession.swift today | `Export/Internal/OpticalKernels.swift` |

Total: ~902 source lines move out of `FilmtoneExportSession.swift`. Type
names are preserved — keeping the names avoids edits at the 18
`OpticalKernels.<kernel>` call sites and at the 9 cross-file
`FilmtoneSharedGradeProcessor` consumers.

These three types are bundled into one sub-stage because they share an
access-modifier ladder that has to change atomically:

- `FilmtoneSharedGradeProcessor.motionBlurAccumulator` is lazily set
  from `session.makeMotionBlurAccumulator()` which returns
  `FilmtoneMotionBlurAccumulator`. Once `FilmtoneSharedGradeProcessor`
  lives in another file, that return type is no longer reachable while
  it stays `fileprivate`, so `FilmtoneMotionBlurAccumulator` must drop
  its `fileprivate` in the same commit.
- `FilmtoneMotionBlurAccumulator.apply(...)` reads
  `OpticalKernels.motionFeedback` and `OpticalKernels.motionBlend`. If
  `FilmtoneMotionBlurAccumulator` moves out while `OpticalKernels`
  stays `private` in `FilmtoneExportSession.swift`, those reads break.
  So `OpticalKernels` must drop its `private` in the same commit.

The 2B-1 inventory called this out as Risk Rank #4 and marked the
bundle as the only safe shape.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  (delete the ~902 lines, relax 6 `fileprivate` modifiers in the
  class body, relax 1 `private` modifier on a free function, no other
  edits)
- `apps/capacitor-film-lab-ios/ios/App/App/Look/FilmtoneSharedGradeProcessor.swift`
  (new — sole owner of `FilmtoneSharedGradeProcessor`)
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/FilmtoneMotionBlurAccumulator.swift`
  (new — sole owner of `FilmtoneMotionBlurAccumulator`)
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
  (new — sole owner of `OpticalKernels`)
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  (4-section registration × 3 new files; App target source build phase
  count changes by exactly +3)
- `docs/filmtone/ios/feature-architecture-refactor/active.md` (this file)

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md` (commit gate; §3 4-section grep)
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  (Phase 2B target = 6 helper files; this is sub-stage 4 and is the
  largest single move in 2B)
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-1-sidecar-formatter-extraction.md`
  (Compatibility Table — `FilmtoneSharedGradeProcessor` /
  `FilmtoneMotionBlurAccumulator` / `OpticalKernels` rows + Risk Rank #4)
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-3-depth-payload-manager-extraction.md`
  (precedent for keeping byte-identical semantics in a coupled extraction)
- `apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneMotionBlurMath.swift`
  (`FilmtoneMotionBlurMath.clampShutterAngle` / `isActive` /
  `activeFrameCount` / `blendWeights` — read-only collaborator of the
  accumulator)
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift`
  / `Editor/FilmtoneEditorFacade.swift` / `Capture/*.swift` /
  `Source/FilmtoneMediaRuntime.swift` (the 9 cross-file consumers of
  `FilmtoneSharedGradeProcessor`; none of them is edited in this
  sub-stage — type name preserved)

## Cross-file reader inventory (verified at extraction time)

| Type | External readers (file count / total references) |
|---|---|
| `FilmtoneSharedGradeProcessor` | 9 files / 17 references — `Capture/FilmtoneCaptureView.swift`, `Capture/FilmtoneCaptureLivePreview.swift`, `Capture/FilmtoneCaptureTakePickerOverlay.swift`, `Capture/FilmtoneCaptureTakePreviewModel.swift`, `Capture/FilmtoneCaptureTakePreviewLoader.swift`, `Editor/FilmtoneEditorFacade.swift`, `Editor/FilmtoneEditorStore.swift`, `Source/FilmtoneMediaRuntime.swift`, plus self-references inside ExportSession (lines 259, 260) |
| `FilmtoneMotionBlurAccumulator` | 0 external — all 5 references (lines 132, 1508, 1721, 1722, 1733) inside `FilmtoneExportSession.swift` |
| `OpticalKernels` | 0 external — all 18 references (16 inside ExportSession class body lines 1782–2584, 2 inside `FilmtoneMotionBlurAccumulator.apply` lines 3330 + 3369) inside `FilmtoneExportSession.swift` |

The 9 external `FilmtoneSharedGradeProcessor` files keep their imports
and type spellings unchanged. They will continue to resolve the type
from the same Swift module after the move because the type's access
level (default internal) is unchanged.

## Visibility relaxation plan (in `FilmtoneExportSession.swift`)

After the moves, `FilmtoneSharedGradeProcessor` (now in
`Look/FilmtoneSharedGradeProcessor.swift`) reads 6 session members and
1 free function across the module boundary, so each must lose its
`fileprivate` / `private` modifier and become default internal:

| Member (current line) | Current | After | Why the bump is needed |
|---|---|---|---|
| `let ciContext: CIContext` (65) | `fileprivate` | default internal | `FilmtoneSharedGradeProcessor.ciContext` getter (line 3222) returns `session.ciContext`; the composition handler closure on line 3240 calls `request.finish(with: processed, context: session.ciContext)` |
| `let colorPipeline: FilmtoneColorPipelineContract` (66) | `fileprivate` | default internal | `makeVideoComposition` (line 3254) calls `session.colorPipeline.applyOutputMetadata(to: composition)` |
| `func renderablePreviewVideoImage(...)` (1504) | `fileprivate` | default internal | composition handler closure at line 3234 calls `session.renderablePreviewVideoImage(...)` |
| `func applyLivePreviewGrade(...)` (1689) | `fileprivate` | default internal | `applyForLivePreview(_:mode:)` at line 3216 calls `session.applyLivePreviewGrade(to:timeSeconds:mode:)` |
| `var outputFrameRate: Int` (1717) | `fileprivate` | default internal | `makeVideoComposition` (line 3252) reads `session.outputFrameRate` for `frameDuration` |
| `func makeMotionBlurAccumulator()` (1721) | `fileprivate` | default internal | `FilmtoneSharedGradeProcessor.motionBlurAccumulator` lazy (line 3187) calls `session.makeMotionBlurAccumulator()` |
| `func filmtonePreviewCompositionDebugLog(_:)` (3259) — free top-level func | `private` | default internal | line 3242 inside `makeVideoComposition` calls it; the function has 12 other callers inside `FilmtoneExportSession.swift` (the class body) and the declaration remains in `FilmtoneExportSession.swift` after the move (it is module-internal, not class-internal) |

No member-level rename and no public API change. None of these
relaxations affects the rest of the module because Swift's default
access already is `internal`, which only widens visibility to inside
the same module.

`FilmtoneMotionBlurAccumulator` and `OpticalKernels` lose their
file-scope modifiers (`fileprivate` / `private`) when they are moved
out of `FilmtoneExportSession.swift`. The new files declare the types
with no access modifier (default internal). Same reasoning: no public
API change.

## New-file layout

### `Look/FilmtoneSharedGradeProcessor.swift`

Imports needed: `AVFoundation` (for `AVMutableVideoComposition` and
`CMTimeGetSeconds`), `CoreImage` (for `CIImage`), `Foundation`.

Body: the exact 73 lines from `FilmtoneExportSession.swift` 3185–3257,
moved verbatim. No method renames, no signature changes. The doc
comments are preserved character-for-character.

Why `Look/` and not `Export/Internal/` (per strategy.md §"Measurable
Done Conditions" and the 2B-1 inventory's "Move target" column): the
processor is the cross-cutting visual contract that both Export
(master grade) and Capture (live preview) read from. The strategy doc
explicitly places this class in `Look/` to mark it as shared, not as
an export-internal helper.

### `Export/Internal/FilmtoneMotionBlurAccumulator.swift`

Imports needed: `CoreImage` / `CoreVideo` / `Foundation`. (The current
code uses `CIContext`, `CIImage`, `CIColor`, `CVPixelBuffer`,
`CVPixelBufferCreate`, `kCVPixelBufferPixelFormatTypeKey`, `NSLock`.)

Body: the exact 183 lines from `FilmtoneExportSession.swift` 3265–3447,
with one change — drop the leading `fileprivate` modifier on the class
declaration. Static helpers (`slotCount`, `makePixelBuffer(...)`,
`clamp(...)`) stay private to the class.

### `Export/Internal/OpticalKernels.swift`

Imports needed: `CoreImage` (for `CIColorKernel` / `CIKernel`).

Body: the exact 646 lines from `FilmtoneExportSession.swift` 3449–4094,
with one change — drop the leading `private` modifier on the enum
declaration. All kernel `static let` definitions stay as-is. The
inline `//` comments (Moving Postcard rationale, Desktop divergence
notes, M1 owner tags, v1.1.1 portrait-optics notes) are preserved
character-for-character.

## Call-site repair list

| File | Lines | Change |
|---|---|---|
| `FilmtoneExportSession.swift` | 65, 66, 1504, 1689, 1717, 1721 | drop the `fileprivate` token preceding each declaration |
| `FilmtoneExportSession.swift` | 3259 | drop the `private` token preceding `func filmtonePreviewCompositionDebugLog` |
| `FilmtoneExportSession.swift` | 3185–4094 | delete the entire block (SharedGradeProcessor + blank + debug-log function + blank + MotionBlurAccumulator + blank + OpticalKernels). Important: the debug-log function (3259–3263) is **not** part of this block — it travels with FilmtoneExportSession because 12 of its 13 callers live there (the 13th caller moves with SharedGradeProcessor and becomes a cross-file caller) |

Wait — re-read carefully. The line range 3185–4094 contains both the
three types and the debug-log helper between them. The deletion is
**non-contiguous**:

- Delete 3185–3257 (`FilmtoneSharedGradeProcessor`) + the blank at 3258.
- **Keep 3259–3263** (`filmtonePreviewCompositionDebugLog`) in place,
  drop its `private` modifier.
- Delete 3265–3447 (`FilmtoneMotionBlurAccumulator`) + surrounding blanks.
- Delete 3449–4094 (`OpticalKernels`).

The cleanest edit order:

1. Drop the 6 `fileprivate` modifiers and 1 `private` modifier at the
   listed lines first (no line-count change).
2. Move the debug-log function so it does not sit between two deletions
   — leave it where it is and treat the 3 deletions as 3 separate
   `Edit` calls that target each type's exact `final class … { … }` /
   `enum … { … }` block.
3. After deletions: confirm `filmtonePreviewCompositionDebugLog` and
   one blank line above and below it are intact in the resulting file.

No external call site needs editing in this sub-stage — the type names
are preserved.

## Anti-pattern boundaries

- **Do not rename** `FilmtoneSharedGradeProcessor`,
  `FilmtoneMotionBlurAccumulator`, or `OpticalKernels`. The 2B-2
  precedent (renaming `Self.makeActiveInputLut` → namespace lookup)
  was for type-namespace shortening; here name preservation avoids
  edits at 17 + 5 + 18 = 40 call sites.
- **Do not change** any kernel source string in `OpticalKernels`.
  Each `static let` is a CIKernel definition that backs an active
  render path; the byte content is the canonical chain.
- **Do not convert** `FilmtoneMotionBlurAccumulator.apply` to any
  other thread/queue contract. Its `NSLock` + `apply(to:params:timeSeconds:outputSize:)`
  shape is consumed on `videoQueue` and depended on by the export
  frame loop's stability guarantees.
- **Do not move** the inline doc comments. The Portrait Optics
  physicalization plan, the Moving Postcard rationale, the
  Desktop-divergence notes and the M1-owner tags are non-trivial
  decision records inside `OpticalKernels`. They travel with the enum.

## Things deliberately *not* moved in this sub-stage

- `filmtonePreviewCompositionDebugLog` — stays in
  `FilmtoneExportSession.swift` because 12 of its 13 callers live in
  that file (the 13th caller is inside `SharedGradeProcessor.makeVideoComposition`
  and moves with the type to `Look/FilmtoneSharedGradeProcessor.swift`,
  becoming a cross-file caller). Visibility is relaxed `private` → internal.
- The 12 in-file `filmtonePreviewCompositionDebugLog` call sites
  (lines 582, 659, 722, 1218, 2990, 3029, 3032, 3035, 3038, 3041,
  3068, 3095) — unchanged.
- `FilmtoneMotionBlurMath` (already in `Optics/FilmtoneMotionBlurMath.swift`)
  — read-only collaborator, not moved.
- The 18 `OpticalKernels.<kernel>` call sites inside
  `FilmtoneExportSession.swift` (lines 1782, 1784, 1787, 1833, 1835,
  1838, 2169, 2189, 2254, 2299, 2333, 2373, 2386, 2423, 2557, 2584)
  — unchanged.
- The 9 cross-file `FilmtoneSharedGradeProcessor` consumer files
  (Capture/Editor/Source) — unchanged.
- `OpticsCompositor` (2B-5) / `GradeRenderPipeline` (2B-6 with 2C
  parity gate) / `ExportMediaWriter` (2B-7 with 2C) — out of scope.

## Checklist

- [ ] Confirm cross-file reader inventory matches the table above
  (`grep -rn 'FilmtoneSharedGradeProcessor\|FilmtoneMotionBlurAccumulator\|OpticalKernels' apps/capacitor-film-lab-ios/ios/App/App/`).
- [ ] In `FilmtoneExportSession.swift`, drop `fileprivate` from
  lines 65, 66, 1504, 1689, 1717, 1721 and drop `private` from
  line 3259.
- [ ] Create `Look/FilmtoneSharedGradeProcessor.swift` with the
  73-line `final class FilmtoneSharedGradeProcessor { ... }` body
  copied verbatim (only imports differ).
- [ ] Create `Export/Internal/FilmtoneMotionBlurAccumulator.swift`
  with the 183-line `final class FilmtoneMotionBlurAccumulator { ... }`
  body copied verbatim (`fileprivate` modifier dropped).
- [ ] Create `Export/Internal/OpticalKernels.swift` with the 646-line
  `enum OpticalKernels { ... }` body copied verbatim (`private`
  modifier dropped).
- [ ] Delete the three blocks from `FilmtoneExportSession.swift`
  (3185–3257, 3265–3447, 3449–4094) while keeping
  `filmtonePreviewCompositionDebugLog` (3259–3263) in place.
- [ ] Register all three new files in `project.pbxproj` (4 sections each).
- [ ] `grep -c 'FilmtoneSharedGradeProcessor' project.pbxproj` >= 4.
- [ ] `grep -c 'FilmtoneMotionBlurAccumulator' project.pbxproj` >= 4.
- [ ] `grep -c 'OpticalKernels' project.pbxproj` >= 4.
- [ ] `bun run verify:ios` — PASS.
- [ ] `git diff --check` — PASS.

## Verification gates

- pbxproj 4-section registration verified for all 3 new files
- `bun run verify:ios` green (CLAUDE.md §3; same gate chain as
  2B-1/2B-2/2B-3 including all 6 source-profile math accuracy gates,
  motion blur math, look × veil energy merge, sidecar builder)
- `git diff --check` clean (whitespace)
- `git diff --stat` shows roughly: −902 in
  `FilmtoneExportSession.swift` (with 7 visibility-only edits adding
  near-zero churn), +73 / +183 / +646 in the three new files (plus
  small import preambles), +12 in `project.pbxproj` (4-section × 3)
- App target `PBXSourcesBuildPhase` file count changes by exactly +3
- ExportActivity target `PBXSourcesBuildPhase` file count unchanged
- Capture and Editor `FilmtoneSharedGradeProcessor` consumer files
  show **zero** diff lines

## Done Conditions

- `FilmtoneExportSession.swift` no longer contains `final class
  FilmtoneSharedGradeProcessor`, `fileprivate final class
  FilmtoneMotionBlurAccumulator`, or `private enum OpticalKernels`.
- `Look/FilmtoneSharedGradeProcessor.swift`,
  `Export/Internal/FilmtoneMotionBlurAccumulator.swift`,
  `Export/Internal/OpticalKernels.swift` own these three types and no
  other source file in the module declares them.
- `filmtonePreviewCompositionDebugLog` is still declared in
  `FilmtoneExportSession.swift`, now without the `private` modifier,
  and its 13 call sites (12 in-file + 1 cross-file in
  `Look/FilmtoneSharedGradeProcessor.swift`'s `makeVideoComposition`)
  all compile.
- All gates green.
- Public API of `FilmtoneExportSession` is byte-identical: same
  signatures, same access levels at module boundary (since
  `fileprivate → internal` only widens *within* the module, and
  external API surface is `public`/`open` — none of the touched
  members are public).
- Sidecar field order, kernel chain order, motion-blur ring semantics,
  and live-preview composition contract are unchanged.

## Stop Conditions

- Stop if any of the 9 cross-file `FilmtoneSharedGradeProcessor`
  consumers requires a non-cosmetic edit. The premise of this
  sub-stage is that the type name is preserved and the consumers
  remain untouched.
- Stop if the 18 in-file `OpticalKernels.<kernel>` call sites or the
  5 in-file `FilmtoneMotionBlurAccumulator` references require any
  textual edit beyond declaration-line modifier drops. Their
  resolution is via type name, not via file scope.
- Stop if dropping `fileprivate` on any of the 6 ExportSession
  members causes a new compile error (the only legitimate outcome is
  a successful build; if Swift complains about a now-ambiguous symbol,
  that means the inventory missed a same-named declaration elsewhere
  — investigate before re-running).
- Stop if the App target's `PBXSourcesBuildPhase` file count changes
  by anything other than +3.
- Stop after 3 consecutive build/verification failures.

## Out Of Scope

- Renaming any of the three types.
- Editing any kernel source string in `OpticalKernels`.
- Editing any of the 9 cross-file `FilmtoneSharedGradeProcessor`
  consumer files.
- Splitting `applyGrade` or any `apply*` stage out of
  `FilmtoneExportSession`.
- View / Editor / Capture functional code.
- New tests, new fixtures, new parity gates.

## Unexpected / Follow-up

(empty — worker fills at completion)
