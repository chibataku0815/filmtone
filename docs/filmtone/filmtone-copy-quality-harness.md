# Filmtone Copy Quality Harness

Purpose: keep Filmtone public copy from drifting back into generic AI-like phrasing. This is a product-quality gate, not a polishing checklist.

## Failure Mode

The rejected pattern is copy that treats obvious premises as value.

Bad examples:

- `撮った写真と動画を`
- `写真も動画も`
- `after you shoot`
- `photos and videos`
- `安心して`
- `世界観`
- `雰囲気`
- `cinematic`

These lines can sound harmless, but they do not say why Filmtone should exist. If the opposite is absurd or irrelevant, the phrase is probably filler.

## Copy Rules

1. Do not sell obvious premises.
   - Do not lead with the fact that media was shot, or that the app handles photos/videos.
   - Prefer the job Filmtone performs: choose a look, check it in playback or compare, export/save/share.

2. Do not turn categories into positioning.
   - `写真`, `動画`, `photos`, and `videos` are allowed in instructions and concrete support statements.
   - They are not enough for hero titles, subtitles, promotional text, or metadata headlines.

3. Do not make feature lists into copy.
   - A list such as `presets, Quick controls, LUTs, compare, export` must be attached to an action or decision.
   - Good shape: `Start with a preset, adjust only what you need, then compare before export.`

4. Do not use mood words as proof.
   - Avoid `安心`, `世界観`, `雰囲気`, `空気感`, `cinematic`, `movie-like`, and `film snapshots` in public copy.
   - If a mood word is ever used, the same sentence must still describe the product action and result.

5. Write the Filmtone-specific difference.
   - Web: try a look quickly in the browser.
   - iPhone: save/share from the iPhone workflow.
   - Mac: check video in playback and export with deeper controls.
   - Quick controls: start without opening the full control surface.
   - LUT/profile depth: available when the job needs it.
   - Local workflow: avoid making cloud sync or login the main path.

6. Do not turn gated depth work into a broad public claim.
   - Avoid `奥行きを読む`, `Depth-aware optics`, `where halation belongs`, and `rendered as physics` unless the shipped public build makes that behavior visible, default-relevant, and source-safe.
   - Prefer supportable output language: tune light bloom, grain, compare before/after, check playback, export/save/share.

## Mechanical Gate

Run:

```sh
bun run check:filmtone-copy
```

The gate checks public copy only:

- `apps/web/messages/{ja,en}.json`
- `apps/capacitor-film-lab-ios/fastlane/metadata/{ja,en-US}/*.txt`

Docs and handoffs may include bad examples for review context; they are not scanned by default.

Keywords are treated as ASO search terms. They are checked for length and forbidden claims, but not for prose style.

## Rewrite Standard

Before accepting a hero, subtitle, promo, feature heading, or metadata line, it must answer at least one concrete question:

- What does the user do next?
- What changes in the result?
- Which surface should they use?
- What depth is available when simple controls are not enough?
- What claim is uniquely true enough for Filmtone to say?
