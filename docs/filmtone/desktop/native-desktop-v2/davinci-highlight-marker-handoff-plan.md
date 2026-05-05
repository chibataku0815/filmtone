# DaVinci Highlight Marker Handoff Plan

Date opened: 2026-05-04 JST

## Scope Decision

This is a future sidecar / Filmtone Connect slice, not part of the current
M4-B Shared Phase0 Core Package implementation.

Reason:

- M4-B is limited to Phase0 generated data types and app package wiring.
- Highlight markers are editorial intent, not color / optics Phase0 math.
- The feature crosses iOS, Desktop, sidecar/package, and DaVinci Lua scripts.
  It needs its own active.md before implementation.

## Product Goal

Filmtone iOS and Filmtone Desktop can capture highlight intent on source
media, move that intent with the source through Files / Finder / SSD handoff,
and let DaVinci Resolve scripts produce either:

- Resolve markers carrying the same Filmtone marker IDs.
- A marker-centered rough-cut timeline using the existing highlight-marker
  workflow.

The product shape is:

```text
iPhone marks the good moments
  -> source media + sidecar/package moves to Mac
  -> Desktop can read/write the same marker intent
  -> DaVinci imports package
  -> Resolve markers or Highlight_Auto timeline are created
```

## Current Feasibility Evidence

- Resolve scripting supports media import, relink, timeline creation, and
  appending clip ranges by `mediaPoolItem`, `startFrame`, and `endFrame`:
  `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/README.txt`.
- Resolve markers support `customData` on `MediaPoolItem`, `Timeline`, and
  `TimelineItem`, which is enough to preserve Filmtone marker IDs without
  exposing internal data in the Resolve UI.
- Existing user script
  `/Users/chibatakumi/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/marker_highlight_render.lua`
  already implements the core rough-cut behavior:
  timeline markers -> source clip lookup -> source frame ranges ->
  `MediaPool:AppendToTimeline`.
- Existing Filmtone Connect script
  `apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua`
  already imports a Filmtone package, creates/appends a timeline item, applies
  the bridge LUT/DCTL, writes a Filmtone marker note, and imports the reference
  still.
- iOS sidecar/package v2 already carries source media, rendered media, LUTs,
  DCTL, and reference still through `SidecarPackage`.

## Contract Principle

Highlight marker coordinates must be source-media-relative, not
output-relative.

Reason:

- Desktop master / 4K output and iPhone FHD / Postcard output may differ in
  size, codec, render path, and possibly frame cadence.
- The editorial intent is "this moment in the original source," not "this
  frame in one rendered output."
- Resolve scripts operate cleanly when given source frame ranges for
  `AppendToTimeline`.

## Draft Additive Sidecar Shape

The first contract should be an additive optional block on the existing
sidecar schema. Absence means "no highlight marker intent."

```json
{
  "highlightMarkers": {
    "schema": "filmtone-highlight-markers-v1",
    "sourceIdentity": {
      "filename": "C0061.mov",
      "durationSec": 123.45,
      "fps": 29.97,
      "fileSizeBytes": 123456789,
      "contentHash": null
    },
    "defaults": {
      "preRollSec": 2.0,
      "postRollSec": 3.0
    },
    "markers": [
      {
        "id": "filmtone-marker-uuid",
        "sourceTimeSec": 42.13,
        "sourceFrame": 1263,
        "sourceFps": 29.97,
        "preRollSec": 2.0,
        "postRollSec": 3.0,
        "color": "Blue",
        "name": "Highlight",
        "note": "",
        "createdOnPlatform": "ios",
        "createdAtIso": "2026-05-04T00:00:00.000Z"
      }
    ]
  }
}
```

Rules:

- `id` is the stable round-trip key. DaVinci should write it into marker
  `customData`.
- `sourceTimeSec` is the human/debug truth; `sourceFrame` is the Resolve editing
  truth when fps is stable.
- `preRollSec` and `postRollSec` are explicit. Do not overload Resolve marker
  `duration` as the only source of truth.
- `color`, `name`, and `note` are UI affordances and may map to Resolve marker
  fields.
- Resolve-only fields do not belong in shared Swift Phase0 core.

## Implementation Phases

### DHM-0 Plan Capture

Status: current document.

Done:

- Record the separate-scope decision.
- Record feasibility evidence.
- Preserve the sidecar/shared-core compatibility constraint in strategy and
  active.md.

### DHM-1 Shared Marker Contract

Goal:

- Add a platform-neutral marker intent model and JSON fixture tests.

Likely targets:

- A shared Swift sidecar/intent package after M4-B proves SPM integration.
- iOS sidecar builder contract tests.
- Desktop sidecar writer / reader contract tests.

Done conditions:

- iOS and Desktop can encode/decode the same marker intent fixture.
- Existing sidecars without `highlightMarkers` still parse.
- No schema bump unless a required breaking change appears.

### DHM-2 iOS Marker Capture And Package Emit

Goal:

- Let iOS place markers on source media and include them in sidecar/package
  exports.

Initial UX:

- A marker action tied to the video preview/scrubber.
- Default pre/post handles.
- Optional name/color/note can come later if it slows the first proof.

Done conditions:

- Marker intent survives export in the sidecar.
- Connect package includes source media and marker sidecar.
- Normal Photos save remains media-only; Connect package remains opt-in.

### DHM-3 Desktop Marker Read/Write

Goal:

- Let Native Desktop v2 read iOS marker sidecars and write compatible Desktop
  marker intent.

Done conditions:

- Desktop does not rewrite iOS markers destructively.
- Desktop can add/edit markers in the same source-relative contract.
- Desktop master / 4K export and iPhone FHD / Postcard output profile choices
  do not change marker coordinates.

### DHM-4 DaVinci Connect Import

Goal:

- Extend `filmtone_connect_import_package.lua` to consume
  `highlightMarkers`.

Mode A:

- Import source media.
- Add Resolve markers to the timeline item or media pool item.
- Put `filmtone-highlight-marker:<id>` or compact JSON into `customData`.

Mode B:

- Build a `Highlight_Auto` timeline directly from marker ranges by computing:
  `startFrame = max(0, sourceFrame - preRollFrames)`,
  `endFrame = min(sourceFrames, sourceFrame + postRollFrames)`.
- Use `MediaPool:AppendToTimeline([{ mediaPoolItem, startFrame, endFrame }])`.

Recommended first implementation:

- Land Mode A first because it is easiest to inspect visually in Resolve.
- Then land Mode B because it removes the extra step of manually running the
  existing highlight script.

### DHM-5 Resolve Smoke

Goal:

- Prove the full path on a real Resolve project.

Smoke:

```text
iOS sample package with highlightMarkers
  -> Filmtone Connect import script
  -> source media imported
  -> Resolve markers created with customData
  -> Highlight_Auto rough-cut timeline created
  -> clip ranges match sidecar pre/post handles
```

## Verification Gates

- JSON fixture: old sidecar without `highlightMarkers` parses.
- JSON fixture: marker fixture round-trips on iOS and Desktop.
- DaVinci dry run: script parses package and reports marker count.
- Resolve smoke: marker count and marker `customData` are present after import.
- Resolve smoke: generated rough-cut timeline segment count matches marker count
  after overlap policy is applied.
- Boundary smoke: moving package/source folder on SSD still relinks by package
  source filename and source identity fields.

## Non-Goals

- Do not implement inside M4-B.
- Do not put marker models into Phase0 color parameter types.
- Do not claim full edit interoperability with every NLE.
- Do not start with FCPXML / OTIO unless Resolve marker/range scripting proves
  insufficient.
- Do not make Photos save a package carrier.

## Open Questions

- What are the default pre/post handle values for Filmtone-created markers?
- Should overlapping marker ranges merge automatically in DaVinci Mode B?
- Should iOS marker color map to importance, category, or output duration?
- How much source identity is enough for SSD relink: filename + size + duration
  + fps, or a partial content hash?
- How should variable-frame-rate iPhone footage be represented: seconds-first
  with best-effort frames, or frame-first after source probe normalization?
- Should marker edits merge by marker `id` when both iOS and Desktop have
  modified the same sidecar?
