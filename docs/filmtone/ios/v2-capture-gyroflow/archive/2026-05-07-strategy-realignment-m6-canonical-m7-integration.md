# Active: Strategy Realignment — M6 Canonical / M7 Product Integration

Date: 2026-05-07 JST
Worktree: `filmtone-worktrees/ios-v2-m6-avfoundation-stabilization-smoke`
Branch: `feature/ios-v2-capture-m6-avfoundation-stabilization-smoke`
Base: `3968eafd` (M6 PASS commit)

## Why this active exists

The M6 PASS commit (`3968eafd`) reused the `M6` label by stream necessity.
strategy.md body still defines `M6 - Editor Handoff And Honest Preview` and
`M7 - Owner Clip Trial`. The next product-integration active needs strategy.md
to be coherent before it opens, otherwise that active either reuses a stale
`M7` label or repeats the label-reuse problem the M6 archive already flagged.

This active **only realigns strategy.md text**. It does not touch app code,
capture surface, Swift, pbxproj, or Filmtone-optimized motion library
implementation. It is the held owner review the M6 archive points to.

## Done conditions (minimum)

1. strategy.md `### M6` is renamed to "AVFoundation Stabilization Smoke" with
   a concise Done block matching the archived findings and a pointer to
   `archive/2026-05-07-m6-avfoundation-stabilization-smoke.md`.
2. strategy.md gains a new `### M7 - Product Capture Stabilization
   Integration` with a small Done block describing the minimum needed for the
   M7 active to enter without scope drift (see Proposed text below).
3. Old `### M6 - Editor Handoff And Honest Preview` is renumbered to
   `### M8` with its Done block preserved verbatim and dependency updated
   from "M4 / M5" to "M4 / M5 / M7".
4. Old `### M7 - Owner Clip Trial` is renumbered to `### M9` with its Done
   block preserved verbatim and dependency updated from "M6" to "M8".
5. A short note in `## Known Constraints` (or a new sub-bullet near the lane
   notes) marks the Filmtone-optimized motion / stabilization library as
   **deprioritized for capture-time stabilization** because M6 PASS solves
   that need; if it survives at all it is narrowed to "post-capture
   motion-data uses AVFoundation cannot handle" and not a milestone.
6. `## Open Questions` updates the existing line "Which stabilization / lens
   path makes gyro data agree with the image path?" to reflect that M6
   answers it for the capture-time path (`cinematicExtendedEnhanced` on the
   M5-A locked format).
7. `## Completion Log` gains a 1-line realignment entry. M1-M6 prior entries
   remain untouched.
8. Coherence read confirms the next active (M7 Product Capture Stabilization
   Integration) can open on this strategy.md without label-reuse or
   ambiguity.

## Owner Stop Conditions

- Renumbering edits a substantive Done condition (not just the milestone
  number/label) → STOP, escalate.
- Realignment introduces new content beyond the 8 Done items above → STOP.
- M1-M6 Completion Log history is rewritten or reordered → STOP. History is
  frozen.
- Edits applied to strategy.md before owner OK on the Proposed text below →
  STOP. This active is propose-then-apply.

## Out of scope

- Product capture surface UI / Swift / pbxproj / app code edits.
- Filmtone-optimized motion library implementation work.
- Broader strategy rewrite (Final Goal / Measurable Done Conditions
  unchanged).
- Editing M1-M6 Completion Log history.
- Opening or scoping the M7 product-integration active itself (separate
  active after closure).

## 30-min granular subtasks

1. **Confirm exact edit targets.** Read strategy.md `### M6`, `### M7`,
   `## Known Constraints`, `## Open Questions`. Note prior wording verbatim
   in this active under "Proposed strategy.md edits" so owner can diff.
2. **Draft Proposed text inline.** Write the new `### M6` / new `### M7` /
   renumbered `### M8` / renumbered `### M9` blocks and the lane
   deprioritization note inside this active. **No strategy.md edits yet.**
3. **STOP for owner OK.** Wait for explicit owner sign-off on the proposed
   text. Do not apply.
4. **Apply edits.** Once owner OKs, edit strategy.md to match Proposed text
   (5 edits + 1 Completion Log line).
5. **Coherence read.** Re-read strategy.md end-to-end; confirm milestone
   numbering is linear M1-M9, dependencies resolve, no orphan references,
   no contradictions with M1-M6 log entries.
6. **Archive + log.** Move this active to
   `archive/2026-05-07-strategy-realignment-m6-canonical-m7-integration.md`
   and add a 1-line entry to `## Completion Log` noting realignment.

## Verification status

- [x] Subtask 1: edit targets confirmed (strategy.md L148-186 milestones,
  L188-209 Known Constraints, L211-228 Open Questions, L230+ Completion Log).
- [x] Subtask 2: Proposed text drafted inline (see below).
- [x] Subtask 3: owner OK received 2026-05-07. Three confirmation points
  acknowledged: (a) 5 edits scope is correct, (b) new M7 Done 5 items
  pass as product-integration minimum core (with explicit owner caveat
  "unsupported 時は silent fallback せず明示 fail/disable"), (c) M8 dep
  extension wording accepted with note that "preview が本当に
  stabilized image path か" must be evidenced separately during M8.
  Owner caveat: keep Completion Log realignment entry minimal; do not
  inline M7 implementation detail.
- [x] Subtask 4: strategy.md edits applied (5 edits land on this branch
  HEAD as a follow-up commit unit). Edit 1 = M6 + M7 → M6 / M7 / M8 / M9
  4-block replacement. Edit 2 = Known Constraints lane-deprioritization
  bullet appended. Edit 3 = Open Questions stabilization line closed
  with strikethrough + Closed 2026-05-07 note. Edit 4 = 1-line
  realignment Completion Log entry appended (numbering + deps + lane
  note only; per owner caveat, no M7 implementation detail inlined).
  Edit 5 = none.
- [x] Subtask 5: coherence read passed. Milestones linear `M1 → M9`
  (strategy.md L51 / L67 / L88 / L108 / L129 / L148 / L181 / L210 /
  L235). All Dependency blocks resolve to existing milestone numbers
  (M2→M1, M3→M1, M4→M2/M3, M5→M4, M6→M5, M7→M6, M8→M4/M5/M7,
  M9→M8). M1-M6 Completion Log history references "M6 AVFoundation
  stabilization smoke" consistent with new M6 definition; realignment
  entry explicitly contextualizes the old M6/M7 → M8/M9 move so prior
  entries that say "M5-A drove M5-B" / etc. remain unambiguous.
  No orphan references to a deleted milestone number.
- [x] Subtask 6: archived + Completion Log line added.

## Proposed strategy.md edits (subtask 2 — held for owner OK)

Five edit points. Each block shows OLD (verbatim from current strategy.md)
and NEW (proposed). Apply only after owner sign-off.

### Edit 1 — replace `### M6 - Editor Handoff And Honest Preview`
### plus `### M7 - Owner Clip Trial` (strategy.md L148-186)
### with four renumbered milestone blocks

OLD (L148-186, two milestone blocks — verbatim, do not paraphrase on apply):

```text
### M6 - Editor Handoff And Honest Preview

Goal:

Make captured clips useful inside Filmtone, then make capture-time preview good
enough for shooting decisions.

Done:

- A captured clip opens in the existing editor.
- Matching Source Profile is preselected or attached.
- Export sidecar references capture package metadata.
- Capture preview is close enough for exposure, framing, and Look choice.
- Any omitted preview effect classes are explicitly labeled during development.
- Capture preview reuses the existing Filmtone grade graph through a
  `AVCaptureVideoDataOutput` -> `CIImage` -> `CIContext` -> `MTKView` style
  path unless a later active task records why that is not viable.

Dependency:

- M4 for editor handoff.
- M5 before public Gyroflow-facing claims.

### M7 - Owner Clip Trial

Goal:

Decide whether this actually replaces the stock camera for the target personal
use case.

Done:

- Three real owner clips complete capture -> edit -> export or capture ->
  Gyroflow handoff.
- Any fallback to the stock camera is recorded with a concrete reason.

Dependency:

- M6.
```

NEW (replaces the two blocks above with four milestone blocks: redefined M6,
new M7, renumbered M8 = old M6 with extended dep, renumbered M9 = old M7
with updated dep):

```text
### M6 - AVFoundation Stabilization Smoke

Goal:

Decide whether AVFoundation built-in video stabilization is acceptable as
Filmtone capture-time stabilization on the M5-A locked format, before
committing to a custom Filmtone stabilization library.

Done:

- The M5-A locked format survives mode probing — `formatIndex`, `pixelFormat`,
  `colorSpace`, `dimensions`, `fps`, and writer codec are unchanged after a
  non-`.off` `preferredVideoStabilizationMode` is set.
- Diagnostics include the supported-modes set probed against the full iOS 26
  `AVCaptureVideoStabilizationMode` enum, the chosen preferred mode, and the
  observed active mode after `startRecording`.
- `activeVideoStabilizationMode != .off` is asserted as a smoke gate when the
  requested mode was non-`.off`. No silent fallback.
- The recorded `.mov` first video track FourCC is read from the file via
  `AVURLAsset` and matches the requested writer codec. No silent ProRes →
  HEVC writer downgrade.
- Apple Log 2 is preserved (`activeColorSpace.rawValue == 4`) after recording.
- Owner visual A/B (off vs. on, single 30s pan or handheld walk) judged at
  owner-quality bar.

Dependency:

- M5.

(Outcome: PASS on iPhone 17 Pro / iOS 26.4.2; commit `3968eafd`; findings
in `archive/2026-05-07-m6-avfoundation-stabilization-smoke.md`.
`cinematicExtendedEnhanced` accepted on the M5-A locked format.)

### M7 - Product Capture Stabilization Integration

Goal:

Integrate the M6 PASS stabilization mode into the real Filmtone capture
surface so owner clips are recorded with stabilization as the default product
behavior, not via a smoke-only build.

Done:

- The non-smoke product capture path (not `Filmtone*Smoke.swift`) sets
  `connection.preferredVideoStabilizationMode = .cinematicExtendedEnhanced`
  by default on the M5-A locked format.
- A runtime guard falls back to the highest supported mode the M6 probe
  recorded when `.cinematicExtendedEnhanced` is not supported on a given
  format, and the chosen mode is recorded in the export sidecar.
- The recorded `.mov` carries the same Stop Condition guarantees as M6
  (active != .off when requested non-.off, Apple Log 2 preserved, no format
  swap, writer codec verified by AVURLAsset post-write).
- Product capture diagnostics expose the chosen and active stabilization
  modes alongside the M5-A baseline diagnostics already recorded.
- Owner records at least one real clip through the product surface (not the
  smoke build) with stabilization on and confirms parity with the M6 visual
  bar.

Dependency:

- M6.

### M8 - Editor Handoff And Honest Preview

Goal:

Make captured clips useful inside Filmtone, then make capture-time preview good
enough for shooting decisions.

Done:

- A captured clip opens in the existing editor.
- Matching Source Profile is preselected or attached.
- Export sidecar references capture package metadata.
- Capture preview is close enough for exposure, framing, and Look choice.
- Any omitted preview effect classes are explicitly labeled during development.
- Capture preview reuses the existing Filmtone grade graph through a
  `AVCaptureVideoDataOutput` -> `CIImage` -> `CIContext` -> `MTKView` style
  path unless a later active task records why that is not viable.

Dependency:

- M4 for editor handoff.
- M5 before public Gyroflow-facing claims.
- M7 so capture-time preview operates against the same stabilized image
  path as the recorded master.

### M9 - Owner Clip Trial

Goal:

Decide whether this actually replaces the stock camera for the target personal
use case.

Done:

- Three real owner clips complete capture -> edit -> export or capture ->
  Gyroflow handoff.
- Any fallback to the stock camera is recorded with a concrete reason.

Dependency:

- M8.
```

### Edit 2 — append bullet to `## Known Constraints` (after L209)

OLD (last bullet, L209):

```text
- "Gyro recorded" is not the same as "Gyroflow-quality stabilization."
```

NEW (same line plus one new bullet appended directly under it):

```text
- "Gyro recorded" is not the same as "Gyroflow-quality stabilization."
- The Filmtone-optimized motion / stabilization library lane that M5-B
  BLOCKED implied is **deprioritized for capture-time stabilization**: M6
  PASS shows AVFoundation built-in `cinematicExtendedEnhanced` is
  acceptable on the M5-A locked format. If the lane survives at all,
  scope narrows to "post-capture motion-data uses AVFoundation cannot
  handle" (e.g. honest preview overlay, exporter metadata, off-device
  Gyroflow-equivalent integrations) and is not a milestone in this
  strategy.
```

### Edit 3 — update Open Questions stabilization line (L223)

OLD (L223):

```text
- Which stabilization / lens path makes gyro data agree with the image path?
```

NEW (close the question with a strikethrough + closure note, matching the
existing closed-question convention in L216-219 and L225-228):

```text
- ~~Which stabilization / lens path makes gyro data agree with the image
  path?~~ **Closed 2026-05-07**: M6 PASS — AVFoundation
  `cinematicExtendedEnhanced` on the M5-A locked format is the
  capture-time stabilization path. Gyro / image-path agreement for
  desktop stabilization lives downstream of capture and is not a
  capture-pipeline milestone.
```

### Edit 4 — append 1-line Completion Log entry (after current last entry)

OLD (last entry, L303-328 — the M5-B BLOCKED record + this active will
add the M6 PASS entry from commit `3968eafd` already on this branch).

NEW (append after the M6 PASS entry):

```text
- 2026-05-07: Strategy realigned — M6 redefined as "AVFoundation
  Stabilization Smoke" (PASS), new M7 = "Product Capture Stabilization
  Integration", old M6 / M7 renumbered to M8 / M9 with deps updated,
  Filmtone-optimized motion library lane deprioritized for capture-time
  stabilization (Known Constraints bullet added). M1-M6 prior history
  untouched. Realignment scope: numbering + deps + lane note only.
```

### Edit 5 — none (Final Goal / Measurable Done Conditions / Placement
### unchanged; M1-M5 milestone blocks unchanged).

### Edit summary (5 edit sites, 1 file)

| # | strategy.md location | change | substantive Done content rewritten? |
|---|---|---|---|
| 1 | L148-186 (M6 + M7 blocks) | replace with 4 blocks (new M6 / new M7 / M8 / M9) | M6 yes (intentional redefinition); M8/M9 no (verbatim move + dep extension); M7 new |
| 2 | after L209 (Known Constraints last bullet) | append 1 bullet | n/a |
| 3 | L223 (Open Questions) | strike through + add closure note | n/a |
| 4 | end of Completion Log | append 1 entry | n/a |
| 5 | — | no other edits | — |

Owner Stop Condition #1 ("Renumbering edits a substantive Done condition")
is satisfied: only the new M6 has a rewritten Done (intentional, this is
the milestone redefinition the realignment is about); M8 / M9 Done content
is verbatim from the old M6 / M7 with only the Dependency line extended /
renumbered.

## Closure rule

- **OK on Proposed text + applied + coherence pass** → archive this active,
  log line added, next active "M7 Product Capture Stabilization Integration"
  may open on a fresh worktree.
- **Owner rejects Proposed text** → revise inside this active, re-request OK.
  No partial application.
- **Owner expands scope** → close this active without applying, open a
  broader strategy rewrite active separately. Do not silently grow this one.

## Notes

- strategy.md state is currently on this branch's HEAD (`3968eafd`,
  M6 PASS commit). Realignment edits land on the same branch as a
  follow-up commit so M6 PASS + strategy realignment stay in one merge
  unit, unless owner prefers a thin follow-up branch off it.
- The M6 archive
  (`archive/2026-05-07-m6-avfoundation-stabilization-smoke.md`) already
  records the proposed lane re-scope verbatim; this active formalizes
  the strategy.md side of that proposal and nothing more.
