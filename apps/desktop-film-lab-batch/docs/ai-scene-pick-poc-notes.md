# AI Scene Pick — PoC Evaluation Notes

Last updated: 2026-04-20
Status: dev-only PoC, not shipped.

## Purpose

Validate whether an AI-assisted scene-pick layer — given 8–12 sampled thumbnails from a clip — can choose a representative frame + family + recipe that lets the user accept a color grade without scrubbing.

Heuristic v1 remains the production path and the baseline for comparison. AI output never authors raw renderer params; it returns a constrained JSON decision that feeds the existing deterministic `buildOpticalParamPatch` machinery.

See prior handoffs:
- `scene-aware-optical-finish-handoff-2026-04-20.md`
- `ai-scene-pick-validation-handoff-2026-04-20.md`

## Architecture (what this PoC actually adds)

```
┌────────────────────────────────────────────────────────────────────┐
│ Desktop renderer                                                   │
│                                                                    │
│   DesktopOpticalAnalyzerService.analyze({captureFrameJpegs:true})  │
│          │                                                         │
│          ├── heuristic descriptor/recommendation (unchanged)       │
│          └── sampledFrames: [{index,timeSec,jpegDataUrl}]          │
│                                                                    │
│  [dev toggle on] ──► BffAiScenePickProvider.pick(frames)           │
│                             │                                      │
│                             ▼                                      │
│                       POST /api/film-lab/ai/scene-pick             │
│                             │                                      │
│  renderer ◄──── AiScenePickResult {bestFrameIndex,family,recipe,   │
│                 confidence, manualFallback, reason, latencyMs}     │
│          │                                                         │
│          └── buildAiRecommendation()                               │
│                   ▼                                                │
│          OpticalRecommendationV1                                   │
│                   ▼                                                │
│          buildOpticalParamPatch() [unchanged, deterministic]       │
│                   ▼                                                │
│          commitOpticalRecommendationToBatch()                      │
└────────────────────────────────────────────────────────────────────┘
```

## Quickstart

### 1. BFF env

In `apps/web/.env.local`:

```
FILM_LAB_SMART_LOOK_PROVIDER=openai
FILM_LAB_SMART_LOOK_OPENAI_COMPAT_BASE=https://openrouter.ai/api/v1
FILM_LAB_SMART_LOOK_OPENAI_COMPAT_API_KEY=<openrouter-key>
FILM_LAB_SMART_LOOK_CHAT_MODEL=google/gemini-2.5-flash
FILM_LAB_SMART_LOOK_CHAT_JSON_MODE=true
FILM_LAB_SMART_LOOK_ALLOW_DESKTOP_DEV=true
```

- Default is `gemini-2.5-flash`: scene-pick is a closed-vocab classification over 12 small thumbnails, so reasoning-heavy models are wasteful. Observed cost with `gemini-2.5-pro` was ~$0.018–$0.03 per call because reasoning tokens counted against output; flash is ~5–10× cheaper for the same task.
- Provider can be set to `mock` to exercise the full UI path without calling an LLM (returns the middle frame with `glow / warmIndoor`).
- Model is env-swappable for quality comparison: `google/gemini-2.5-pro`, `anthropic/claude-sonnet-4-6`, `openai/gpt-4o-mini` all work through the same OpenRouter base.
- Future depth-analysis work will likely want `gemini-2.5-pro` for spatial reasoning — keep the env swap as the escape hatch.

### 2. Run both apps

```
bun run --cwd apps/web dev
bun run --cwd apps/desktop-film-lab-batch dev
```

### 3. Enable the dev toggle

In Desktop DevTools (⌘⌥I):

```
localStorage.setItem('filmtone.scenePickDev', '1')
location.reload()
```

Or append `?aiScenePick=1` to the URL once to try it without persisting.

You should see an amber `AI PICK (DEV)` pill at the top of the Optical Finish recommendation panel.

### 4. Load a proof clip

Load a video clip as the interactive preview. Heuristic recommendations render as before; after heuristic resolves, the AI card below alternates will flip to `running`, then `ready` with:

- picked frame thumbnail
- family / recipe
- confidence + latency
- reason (Japanese)
- `AI の候補を適用` button (disabled when `manualFallback: true`)

### 5. Apply and compare

Apply the heuristic primary first and note the preview result. Reload (or load another clip), apply the AI pick instead. Fill in the scoring sheet below.

## Failure modes

| Case | What you see | What it means |
|---|---|---|
| BFF unreachable | AI card: `AI 呼び出しに失敗: fetch-failed: ...` | Event log has the reason. Heuristic path is unaffected. |
| BFF returns 403 | AI card: `AI 呼び出しに失敗: http-403` | `FILM_LAB_SMART_LOOK_ALLOW_DESKTOP_DEV` not set to `true`, or `NODE_ENV !== development`. |
| Model produces invalid JSON | AI card: `AI 呼び出しに失敗: http-422` | Prompt or model issue; inspect `rawJson` in DevTools via `[ai-scene-pick] result` log. |
| Mixed clip / model unsure | `manualFallback: true`, Apply button disabled, reason shown | Expected. Tester should fall back to heuristic or manual choice. |

## Proof-clip scoring sheet

Run the same set of clips through heuristic-only and AI-pick and note the outcome. Keep it brutally simple — the goal is a yes/no signal on whether AI reduces user decision burden.

| # | Clip | Heuristic family/recipe | AI frame idx | AI family/recipe | AI conf | Accepted AI without scrub? | Time to acceptable | Result better than heuristic? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | warm indoor practical lights | | | | | | | | |
| 2 | city night point lights | | | | | | | | |
| 3 | daylight close-up portrait | | | | | | | | |
| 4 | mixed montage | | | | | | | | |
| 5 | product / detail clip | | | | | | | | |

## Decision rule after the sheet

- **Yes across the board**: AI scene pick materially reduces scrubbing, users trust the picked frame → invest in premium AI scene selection (rejection logic, segmentation, richer semantics, eventually depth).
- **No / mixed**: heuristic remains the production path; do not expand AI scope. Revisit only if the underlying model gets meaningfully better at spatial/depth reasoning.

## Files in this PoC

New:
- `apps/desktop-film-lab-batch/src/renderer/ai-scene-pick.ts` + test
- `apps/desktop-film-lab-batch/src/renderer/ai-recommendation-builder.ts` + test
- `apps/web/src/app/api/film-lab/ai/scene-pick/route.ts`
- `apps/desktop-film-lab-batch/docs/ai-scene-pick-poc-notes.md` (this file)

Modified (minimal diffs):
- `apps/desktop-film-lab-batch/src/renderer/optical-scene-analysis.ts` (opt-in JPEG capture)
- `apps/desktop-film-lab-batch/src/renderer/App.tsx` (parallel AI path + onApplyAi)
- `apps/desktop-film-lab-batch/src/renderer/OpticalFinishRecommendationPanel.tsx` (AI card + dev pill)

No changes to `packages/film-lab-ui/*`, `packages/film-lab-core/*`, export metadata, or the renderer core.

## Tests

```
bun run --cwd apps/desktop-film-lab-batch test \
  src/renderer/ai-scene-pick.test.ts \
  src/renderer/ai-recommendation-builder.test.ts \
  src/renderer/optical-scene-analysis.test.ts \
  src/renderer/OpticalFinishRecommendationPanel.test.tsx
```

Last run: 4 files / 27 tests passed.
