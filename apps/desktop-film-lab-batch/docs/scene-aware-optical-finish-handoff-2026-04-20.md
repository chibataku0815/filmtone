# Filmtone Optical Finish Scene-Aware Recommendation Handoff

Last updated: 2026-04-20
Authoring context: Codex desktop session
Primary repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
User locale/context at time of work: Japan / Asia-Tokyo

## 1. Purpose

This document is a complete handoff for the Desktop Pro `Optical Finish` scene-aware recommendation work. It is intended to let a brand new chat continue without needing the prior conversation.

The work has already progressed beyond planning and into implementation, debugging, and UX cleanup. The analyzer now reaches `ready` on at least one real proof clip, recommendations render in the UI, debugging surfaces exist, and apply feedback was just strengthened. The remaining uncertainty is around final click/apply verification in the live Electron app.

## 2. User Intent And Product Direction

### Initial user questions

The user originally asked whether it is possible to analyze video scenes and apply suitable filter effects automatically.

The user also asked whether AI is necessary for detection and processing.

### Product position agreed during discussion

- v1 should **not require AI/ML**.
- v1 should ship as **Recommend Only**, not auto-apply, not per-shot switching.
- v1 should use deterministic heuristics and reuse existing optical params.
- Current Desktop architecture is `1 clip = 1 global grade state`, so v1 must stay at **clip-level recommendation**.

### Later user position on AI

Near the end of this session, the user explicitly said:

- If scene selection still effectively depends on human visual judgment, AI may be acceptable.
- If AI is introduced for deeper scene understanding or smarter shot selection, it likely belongs behind a **paid feature / monetized tier**.

This is important for future scope:

- v1 remains non-AI.
- v2+ can consider optional AI as a premium layer for better shot selection, segmentation, or deeper semantic understanding.

## 3. Canonical Implementation Plan Given By User

The user provided the following implementation direction. This was treated as the source of truth for v1:

- Add a scene-aware `Optical Finish` recommendation layer to `Finish Tools` for `Desktop Pro`.
- Keep v1 fixed to `Recommend Only`.
- Do not make AI mandatory.
- Reuse existing `bloom / halation / diffusion / cross / lens` params.
- Preserve deterministic render output.
- Because Desktop has one global grade state per clip, v1 outputs `one clip-level recommendation + alternates`, not per-shot auto switching.
- `Smart Look` restart, plugin surface, iOS sharing, and public AI-forward copy are out of scope.

### Required core contracts

Public types added to `packages/film-lab-core`:

- `OpticalFamily`
- `BehaviorProfile`
- `OpticalRecipeId`
- `SceneDescriptorV1`
- `OpticalRecommendationV1`
- `SceneAnalysisState`
- `OpticalAnalyzerProvider`

Public functions added:

- `recommendOpticalFinish(descriptor)`
- `buildOpticalParamPatch(recommendation)`

### Patch ownership

Only these lanes may be touched:

- `bloom*`
- `halation*`
- `diffusion`
- `crossFilter*`
- `rgbShift`
- `lensSoftness`

Must not touch:

- `Base Looks`
- `Trim`
- `Texture`
- `Motion`

### Recipe vocabulary

Vocabulary fixed to:

- `warmIndoor`
- `nightCity`
- `skinCloseUp`
- `nightSpot`
- `productEdge`
- `coverStillMatch`

Auto recommendation in v1 only targets:

- `warmIndoor`
- `nightCity`
- `skinCloseUp`
- `nightSpot`

`Lens` recipes stay manual-only in v1.

### Analyzer architecture

- Desktop gets a dedicated background analyzer service.
- It uses a hidden media element and must not seek the visible preview.
- Cache key is:
  - `sourcePath + trimStart + trimEnd + sourceDuration + analyzerVersion`
- Analysis target is the current trim window.
- If trim is unset, use full clip.
- Output stays clip-level, one recommendation only.

### Sampling and features

- Max 12 frames.
- Must include first, middle, last.
- Other frames are evenly spaced.
- Each frame downscales to max long edge 256 px before feature extraction.
- Shot boundary detection:
  - sampled-frame `HSV histogram delta + edge-density delta`
  - if dominant shot coverage `< 45%`, force confidence to `low`
- v1 features fixed to:
  - `medianLuma`
  - `highlightCoverage`
  - `specularIslands`
  - `pointLightScore`
  - `globalContrast`
  - `warmthScore`
  - `portraitLikelihood`
  - `nightScore`
  - `sceneComplexity`
- `FaceDetector` is optional enhancement only.
- Fallback portrait detection must exist without it.

### Policy rules

- `Cross` only wins if:
  - `pointLightScore >= 0.60`
  - and `CrossScore >= 0.72`
- `Glow` can become primary only if:
  - `highlightCoverage >= 0.08`
  - and `GlowScore >= 0.62`
- otherwise default to `Mist`
- `Lens` is never auto-promoted in v1

### Mapping rules

- `Glow + warmthScore >= 0.58 -> warmIndoor`
- `Glow + nightScore >= 0.55 -> nightCity`
- `Mist + portraitLikelihood >= 0.55 -> skinCloseUp`
- `Cross winner -> nightSpot`
- otherwise `clean`

### UI rules

- First UI surface is `apps/desktop-film-lab-batch`
- `packages/film-lab-ui` should only get minimal diffs
- Add `Recommended For This Clip` module at top of `Finish Tools`
- Allowed states:
  - `idle`
  - `analyzing`
  - `ready`
  - `low-confidence`
  - `error`
- `ready` shows 1 primary + up to 2 alternates
- Rationale must be human-readable chips only
- No numeric scores shown
- `low-confidence` copy must shift to safe starting points
- Export path must never be blocked by low confidence
- `Apply` must:
  - write optical-only patch to current batch grade state
  - set look source to `analysisRecommendation`
  - open the relevant family card
- No auto-apply during play, scrub, or shot change
- Manual edits after apply always win until explicit reapply
- Optional sidecar metadata may store:
  - `family`
  - `profile`
  - `recipe`
  - `analyzerVersion`
  - `appliedAtIso`

## 4. High-Level Chronology Of This Session

### Phase 1: Initial implementation

The scene-aware recommendation feature was implemented across:

- `packages/film-lab-core`
- `apps/desktop-film-lab-batch`
- `packages/film-lab-ui`
- metadata/export integration

### Phase 2: UX copy complaints

The user objected strongly to unclear copy such as:

- `Recommended For This Clip`
- `Analyzing the current clip in the background. The visible preview will not seek.`
- `Optical Finish`

These were rewritten to more direct Japanese user-facing strings.

### Phase 3: “analysis is not running”

The user reported there was no sign of analysis.

Root cause found:

- In the unsupported-codec progressive loading path, the canvas texture was swapped, but `previewStatus` was not updated to `ready`.
- The analyzer effect in `App.tsx` was gated on `previewStatus.state === "ready"` and `hasActiveVideo`.

Fix:

- In `packages/film-lab-ui/src/FilmLabCanvas.tsx`, `swapProgressiveTexture()` was updated to call `setReadyPreviewStatus(...)` after texture swap.

### Phase 4: panel visibility

To prevent the recommendation module from being hidden under collapsed `Finish Tools`, the `renderBeforeFinishTools` slot was moved above the `CollapsibleHeader` in `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx`.

### Phase 5: explicit debug surface

The user asked to make the feature debuggable.

A debug surface was added:

- analyzer state
- skip reason
- preview state
- source path
- current URL
- duration
- progressive stage
- cache key
- analyzer version
- sample count
- error

### Phase 6: real runtime diagnosis from screenshot

The user shared a screenshot showing:

- `解析状態: analyzing`
- `プレビュー状態: ready`
- `動画あり: true`
- `入力種別: file`
- `解析入力` and `ファイルパス` both resolved
- `動画長: 6`
- `読込段階: idle`
- `サンプル枚数: n/a`
- `エラー: n/a`

Conclusion:

- The analyzer effect had started.
- The Promise inside `analyze()` was not resolving.
- The issue had moved from gating to the hidden analyzer internals.

### Phase 7: hidden analyzer hardening

The hidden analyzer was hardened in two ways:

1. If an absolute file path exists, use the desktop `film-lab-video://...` protocol instead of a transient `blob:` preview URL.
2. Add timeouts to:
   - hidden metadata load
   - `requestVideoFrameCallback` wait

Progress logging was also added:

- `resolve-source`
- `load-video`
- `metadata-ready`
- `sample-frame`
- `face-detect`
- `recommend`
- `complete`
- `cache-hit`

### Phase 8: ready state confirmed

The user shared a later screenshot showing:

- recommendations rendered (`Mist`, `Glow`, `Cross`)
- console logs for:
  - sampling frames
  - face-assist step
  - building recommendation
  - `analysis complete: ready`

At that point, the analyzer path was confirmed to complete on a real clip.

### Phase 9: Apply button complaint

The user then reported that the recommendation cards appear, but pressing `適用` feels nonresponsive and there is no visible change.

This was not fully closed before handoff.

Latest mitigation added:

- force recommendation panel/card/button to `-webkit-app-region: no-drag`
- add explicit visual state:
  - applied card changes to `適用済み`
- add apply event feedback:
  - debug activity updates
  - event log appends `apply clicked: ...`
  - console logs `[optical-analysis] apply clicked`

The user accepted the current state as “good enough for now” and asked to commit plus prepare a perfect handoff.

## 5. Current Status Summary

### Working

- Core scene-aware recommendation contracts exist.
- Optical recommendation heuristics exist.
- Optical-only patch builder exists.
- Hidden analyzer service exists.
- Recommendation UI renders above `Finish Tools`.
- Analyzer reaches `ready` on a real clip.
- Console progress logs exist.
- On-screen debug activity and event history exist.
- Export metadata support for analysis recommendation exists.
- Manual edit precedence after apply is implemented in state logic.

### Implemented but needs live re-verification

- `Apply` button feedback:
  - `適用済み` visual state
  - `apply clicked: ...` event log
  - `[optical-analysis] apply clicked` console log

### Not in scope / not implemented

- per-shot auto switching
- AI/ML dependency
- segmentation
- plugin surface
- iOS sharing of this feature
- public AI-forward positioning

## 6. Files Added Or Changed For This Feature

### Core

- `packages/film-lab-core/src/optical-recommendation.ts`
- `packages/film-lab-core/src/optical-recommendation.test.ts`
- `packages/film-lab-core/src/index.ts`
- `packages/film-lab-core/dist/index.js`
- `packages/film-lab-core/dist/index.d.ts`

### Desktop renderer / app

- `apps/desktop-film-lab-batch/src/renderer/optical-scene-analysis.ts`
- `apps/desktop-film-lab-batch/src/renderer/optical-scene-analysis.test.ts`
- `apps/desktop-film-lab-batch/src/renderer/OpticalFinishRecommendationPanel.tsx`
- `apps/desktop-film-lab-batch/src/renderer/OpticalFinishRecommendationPanel.test.tsx`
- `apps/desktop-film-lab-batch/src/renderer/App.tsx`
- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts`
- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts`
- `apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.ts`
- `apps/desktop-film-lab-batch/src/renderer/batch-tab/BatchTabPanel.tsx`
- `apps/desktop-film-lab-batch/src/renderer/batch-tab/BatchTabPanel.test.tsx`
- `apps/desktop-film-lab-batch/messages/ja.json`
- `apps/desktop-film-lab-batch/messages/en.json`

### Shared UI

- `packages/film-lab-ui/src/FilmLabCanvas.tsx`
- `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx`
- `packages/film-lab-ui/src/filmLabUiContract.ts`

### Potential parity changes made earlier in session

There were also earlier message-key additions in web message files during development. They are not central to current desktop debugging and may be excluded from a minimal commit if desired.

## 7. Important Code Paths

### Recommendation computation

- `packages/film-lab-core/src/optical-recommendation.ts`

Exports:

- `recommendOpticalFinish(descriptor)`
- `buildOpticalParamPatch(recommendation)`

### Hidden analyzer

- `apps/desktop-film-lab-batch/src/renderer/optical-scene-analysis.ts`

Important behavior:

- `resolveSceneAnalysisSourceUrl()` now prefers desktop `film-lab-video://...` for absolute paths.
- `loadHiddenVideo()` now has a metadata timeout.
- `waitForVideoFrameReady()` wraps `requestVideoFrameCallback` with timeout fallback.
- `analyzeSource()` emits progress events and console logs.

### App-level analyzer orchestration

- `apps/desktop-film-lab-batch/src/renderer/App.tsx`

Important behavior:

- Gating conditions for analysis live in the analyzer `useEffect`.
- It now collects detailed debug info and event history.
- It passes progress callbacks to `DesktopOpticalAnalyzerService.analyze(...)`.
- It injects the recommendation panel via `renderBeforeFinishTools`.

### Panel UI

- `apps/desktop-film-lab-batch/src/renderer/OpticalFinishRecommendationPanel.tsx`

Important behavior:

- shows recommendation cards
- shows current debug activity inline
- shows expandable debug details
- shows event history
- marks applied card as `適用済み`
- recommendation panel and buttons explicitly use `no-drag`

### Apply flow

In `App.tsx`, `onApply` currently does:

1. choose `primary` or selected alternate
2. build optical-only patch via `buildOpticalParamPatch(...)`
3. dispatch to the panel reducer:
   - `MERGE_PARAMS`
   - `COMMIT`
4. commit to batch grade state via `commitOpticalRecommendationToBatch(...)`
5. append apply event log and console log

If apply is still visually ineffective, the likely next debugging area is:

- whether `FilmLabControlPanelCore` reducer state and viewport state are syncing as expected after external dispatch
- or whether the current clip simply has subtle effect values that are hard to notice

## 8. Runtime Commands

### Start Desktop app

```bash
bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch dev
```

### Focused tests used during this work

```bash
bun run --cwd apps/desktop-film-lab-batch test src/renderer/optical-scene-analysis.test.ts src/renderer/OpticalFinishRecommendationPanel.test.tsx
```

```bash
bun run --cwd apps/desktop-film-lab-batch test src/renderer/OpticalFinishRecommendationPanel.test.tsx src/renderer/batch-tab/BatchTabPanel.test.tsx src/renderer/optical-scene-analysis.test.ts src/renderer/export-metadata-session.test.ts
```

### Core tests/build previously run

```bash
bun test packages/film-lab-core/src/optical-recommendation.test.ts
```

```bash
bun test packages/film-lab-core/src/schema.test.ts
```

```bash
bun run --cwd packages/film-lab-core build
```

## 9. Test Status

### Passed during this session

- `packages/film-lab-core/src/optical-recommendation.test.ts`
- `packages/film-lab-core/src/schema.test.ts`
- `apps/desktop-film-lab-batch/src/renderer/OpticalFinishRecommendationPanel.test.tsx`
- `apps/desktop-film-lab-batch/src/renderer/batch-tab/BatchTabPanel.test.tsx`
- `apps/desktop-film-lab-batch/src/renderer/optical-scene-analysis.test.ts`
- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts`

Latest focused result:

- `2 files / 8 tests passed` for `optical-scene-analysis.test.ts` and `OpticalFinishRecommendationPanel.test.tsx`
- later `1 file / 5 tests passed` for `OpticalFinishRecommendationPanel.test.tsx` after the apply-feedback patch

### Known typecheck caveat

Full workspace `tsc --noEmit -p apps/desktop-film-lab-batch/tsconfig.json` is known to hit unrelated pre-existing errors elsewhere in the repo.

During this session, filtered checks showed no new type errors for the files changed in this feature.

## 10. Known Unrelated Dirty Worktree State

The repo is dirty outside this feature. Do **not** assume the whole worktree belongs to this task.

Known unrelated or pre-existing dirty areas mentioned during work:

- `packages/film-lab-core/src/schema.ts`
- `packages/film-lab-ui/src/film-lab-reducer.ts`
- multiple `apps/web/*` files
- renderer/webgpu migration work
- other docs and output artifacts

When continuing, do not revert unrelated files.

## 11. Screenshots And What They Proved

### Screenshot 1

Path:

- `/Users/chibatakumi/Library/Application Support/CleanShot/media/media_V30zQfdcUa/CleanShot 2026-04-20 at 22.21.40@2x.png`

What it proved:

- analyzer effect started
- preview was ready
- source path was resolved
- analyzer Promise was hanging before completion

### Screenshot 2

Path:

- `/Users/chibatakumi/Library/Application Support/CleanShot/media/media_EqPOsTrCC1/CleanShot 2026-04-20 at 22.36.12@2x.png`

What it proved:

- analyzer completed
- recommendation cards rendered
- console progress logs flowed through frame sampling and recommendation completion
- next remaining issue was apply/click feedback

## 12. What The Next Chat Should Do First

### Immediate first task

Re-verify the `Apply` interaction in the live Electron app on the same proof clip.

Specifically check:

1. Does pressing `適用` change the button label to `適用済み`?
2. Does `状態を確認する > イベント履歴` append `apply clicked: ...`?
3. Does DevTools Console show `[optical-analysis] apply clicked`?
4. Does the image visibly change?

### Decision tree for next debugging step

#### Case A: button changes to `適用済み`, log appears, image changes

- Done. The apply issue was UX feedback only.

#### Case B: button changes to `適用済み`, log appears, but image does not visibly change

Then the click path is live. Next inspect:

- whether the patch values are too subtle on the current clip
- whether the viewport is receiving params but the chosen recipe looks too close to current state
- whether direct `viewport.setParams(...)` from `App.tsx` is needed as a stronger apply path

Practical next action:

- log the actual patch values at apply time
- compare them against current viewport params before and after apply

#### Case C: button does not change, no log appears

Then the click is still being intercepted.

Next inspect:

- frameless drag region overlap
- z-index stacking
- overlay layers intercepting input
- whether some parent container still behaves as drag region even though card/buttons use `no-drag`

#### Case D: log appears, button updates, but batch/export state changes only and preview does not

Then the issue is likely split between:

- `FilmLabControlPanelCore` reducer
- viewport sync effect
- or compare/before-after sync plan

Next inspect:

- `FilmLabControlPanelCore.tsx`
- reducer dispatch flow
- `viewport.setParams(...)` side effects

## 13. Suggested Follow-Up Product Discussion

The user’s latest product thinking should be carried forward explicitly:

- v1 non-AI heuristic recommendation is acceptable
- but if the product still forces the human to choose the “right scene” by eye, AI may be justified
- if AI is added for deeper semantic selection or scene understanding, that likely belongs in a paid tier

This creates a sensible product split:

### Free / base

- deterministic heuristic clip-level recommendation
- safe defaults
- manual apply

### Paid / advanced

- AI-assisted semantic scene selection
- segmentation
- portrait/product/light classification with stronger confidence
- possibly shot clustering or smart representative-shot choice

## 14. Recommended Commit Scope

If the goal is to commit just this feature work, stage only the optical recommendation files and the new handoff document. Avoid unrelated dirty files elsewhere in the repo.

## 15. Bottom Line

At handoff time:

- The feature is implemented enough to render real recommendations in Desktop Pro.
- The analyzer no longer appears stuck on the proof clip that previously hung.
- Debug instrumentation is strong enough to continue from a fresh chat.
- The remaining live uncertainty is the final polish around apply interaction feedback and visible effect confirmation.

