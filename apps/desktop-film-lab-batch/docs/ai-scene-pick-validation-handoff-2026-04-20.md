# Filmtone AI Scene Pick Validation Handoff

Last updated: 2026-04-20
Primary repo at handoff time: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
Current implementation repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
Branch at handoff time: `feature/webgpu-migration-v1`
Latest feature commit already created for heuristic recommendation work: `db8cfdf52e1c9a6e0a44f5415992e78260cd68f2`
Related existing handoff: [scene-aware-optical-finish-handoff-2026-04-20.md](./scene-aware-optical-finish-handoff-2026-04-20.md)

## 1. Why This New Handoff Exists

The previous handoff document covers the full implementation and debugging history of the non-AI `scene-aware Optical Finish recommendation v1`.

This new document exists because the product discussion changed after that implementation:

- the heuristic recommendation feature now works well enough to be evaluated
- the user confirmed runtime behavior is working
- but the user judged that if recommendation still depends on human visual scene choice, the feature may not be worth much product complexity
- the user wants the **next new chat** to focus on the shortest possible validation of a stronger idea:
  - **Can AI choose the right scene/reference moment for the user?**
  - **Would that actually produce a meaningfully better UX?**

This document is therefore not just a coding handoff. It is a product + technical validation handoff for the next chat.

## 2. What Was Already Built Before This New Direction

The following already exists and should be treated as available infrastructure:

- deterministic heuristic scene analyzer
- clip-level recommendation generation
- recommendation UI inside Desktop Pro `Finish Tools`
- optical-only patch builder
- recommendation metadata export integration
- debug activity and event log UI
- hidden analyzer service that samples frames without seeking visible preview

Current implementation status:

- `scene-aware Optical Finish recommendation v1` is implemented
- runtime behavior was debugged and the user later confirmed: `動作は確認済みです`
- this means the baseline heuristic flow is available as a comparison target

Read the prior handoff before coding anything:

- [scene-aware-optical-finish-handoff-2026-04-20.md](./scene-aware-optical-finish-handoff-2026-04-20.md)

## 3. Final Product Judgment From The User

The user’s latest product judgment is the core reason for the next phase:

- If the recommendation still requires the user to visually decide which part of the clip should count as the “right scene”, then the analysis may not be worth much.
- If the product still depends on manual scene picking by eye, the feature is mostly an **initial value generator**, not a real decision-making substitute.
- Therefore, the strongest next hypothesis is not “better heuristics”.
- The strongest next hypothesis is:
  - **AI may be justified if it can remove the user’s need to choose the representative scene manually.**
- The user also explicitly said:
  - if AI becomes the meaningful differentiator here, it is likely a **paid feature / monetizable layer**

This means the product framing should be:

- Free/base:
  - deterministic heuristic recommendation
  - simple clip-level safe default
- Paid/advanced:
  - AI chooses representative scene / frame
  - AI rejects mixed clips when unsuitable
  - AI gives stronger semantic understanding

## 4. The Exact Validation Question For The Next Chat

The next chat should not try to build the final AI product.

The next chat should answer this narrow question as fast as possible:

### Main validation question

Can an AI-assisted `scene pick` layer, using a small set of sampled frames from a clip, choose a better representative scene for recommendation than the current non-AI clip-level heuristic?

### UX validation question

Does that AI scene pick reduce the need for the user to scrub or visually inspect the clip before accepting a look recommendation?

### Important framing

The validation target is not:

- AI-generated renderer params
- AI-based full video grading
- per-shot automatic switching
- replacing deterministic rendering

The validation target is specifically:

- AI chooses **which frame / representative moment** should drive recommendation
- AI optionally chooses `family + recipe`
- deterministic optical patch application remains the last step

## 5. Why The Recommended PoC Is Small

The shortest viable validation path is:

- keep the renderer deterministic
- keep `family / recipe / buildOpticalParamPatch()` deterministic
- keep the Desktop architecture as `1 clip = 1 global grade state`
- add AI only to the scene selection and recommendation-choice layer

This is the smallest possible way to test whether AI has product value here.

If AI cannot materially improve representative scene choice under this minimal PoC, then deeper AI investment is probably not worth it yet.

## 6. Recommended PoC Shape

### PoC concept

Create an internal/dev-only `AI Scene Pick` mode that:

1. samples 8 to 12 representative frames from the current trim window
2. sends those frames to a vision-capable model
3. asks the model to:
   - choose the best frame index to represent the clip for optical recommendation
   - choose an optical `family`
   - choose a `recipe`
   - provide confidence
   - explicitly admit when manual fallback is safer
4. feeds the returned `family / recipe` into existing deterministic patch logic
5. shows the chosen representative frame back to the user in the UI

### Key principle

AI should not directly output raw optical parameters in the PoC.

AI should output a constrained structured decision:

- `best_frame_index`
- `family`
- `recipe`
- `confidence`
- `reason`
- `manual_fallback`

Then the product uses existing deterministic machinery for actual param application.

This keeps validation focused and safe.

## 7. Strong Recommendation For Output Contract

The AI response should be constrained JSON.

Suggested v0 contract:

```ts
type AiScenePickResult = {
  bestFrameIndex: number | null;
  family: "mist" | "glow" | "cross" | "lens" | null;
  recipe:
    | "warmIndoor"
    | "nightCity"
    | "skinCloseUp"
    | "nightSpot"
    | "productEdge"
    | "coverStillMatch"
    | "clean"
    | null;
  confidence: "low" | "medium" | "high";
  manualFallback: boolean;
  reason: string;
};
```

Suggested behavior rules:

- If the clip is mixed or uncertain, prefer:
  - `manualFallback: true`
  - low confidence
  - conservative family/recipe or null
- Do not let the model invent arbitrary labels.
- Keep the output vocabulary closed and deterministic.

## 8. Best Technical Validation Strategy

### The shortest realistic strategy

Use the existing frame sampler.

Do not build a full temporal model path first.

Instead:

- reuse sampled frames already conceptually aligned with existing analyzer
- produce small JPEG thumbnails for AI inspection
- send those to a multimodal model
- get a structured selection response

### Why this is the right first cut

- no per-shot architecture changes
- no renderer changes
- no export changes
- minimal UI surface needed
- the current heuristic version becomes a built-in A/B baseline

### What the PoC should compare

Three candidate flows:

1. manual user judgment
2. current heuristic clip-level recommendation
3. AI scene pick + deterministic recommendation

## 9. UX Validation Criteria

The PoC is only worthwhile if it reduces user effort, not just if it is technically cool.

Recommended evaluation criteria:

- time to first acceptable recommendation
- whether the user scrubbed before accepting
- whether the user changed away from the AI-picked scene
- whether the user accepted the AI recommendation directly
- whether the user said the chosen representative scene felt correct

### Practical success signal

The feature is promising if users frequently:

- open a clip
- see the AI-picked representative scene
- accept the recommendation without needing to scrub much or at all

### Practical failure signal

The feature is weak if users often:

- still scrub around to find “the real scene”
- think the AI-picked frame is not the right reference
- treat the AI output as just another suggestion card they must evaluate manually

## 10. Non-Goals For The Next Chat

The next chat should not:

- redesign the whole Desktop architecture
- implement per-shot grade state
- build production billing or entitlements
- ship a full premium plan
- implement generalized semantic video understanding
- replace existing heuristic code entirely

The goal is proof, not finalization.

## 11. Suggested UX Surface For The PoC

Recommended minimal UI:

- keep current heuristic recommendation surface intact
- add a dev-only toggle or internal mode:
  - `AI scene pick (experimental)`
- show:
  - selected representative frame thumbnail
  - chosen `family`
  - chosen `recipe`
  - confidence
  - short reason
  - fallback warning if low confidence

Do not overbuild polish first.

The UI only needs to be good enough to evaluate:

- whether users trust the picked scene
- whether they save time

## 12. Concrete Suggested Implementation Plan For The Next Chat

### Step 1

Read:

- [scene-aware-optical-finish-handoff-2026-04-20.md](./scene-aware-optical-finish-handoff-2026-04-20.md)
- this document

### Step 2

Inspect current files:

- `apps/desktop-film-lab-batch/src/renderer/optical-scene-analysis.ts`
- `apps/desktop-film-lab-batch/src/renderer/OpticalFinishRecommendationPanel.tsx`
- `apps/desktop-film-lab-batch/src/renderer/App.tsx`
- `packages/film-lab-core/src/optical-recommendation.ts`

### Step 3

Add a new dev-only AI validation path, preferably side-by-side with current heuristic analyzer rather than replacing it.

### Step 4

Reuse current sampling behavior or very close variation:

- 8 to 12 frames
- trim-window based
- small thumbnails

### Step 5

Build an internal provider interface for AI scene pick so the implementation can be swapped later.

Suggested shape:

```ts
type AiScenePickProvider = {
  pick(input: {
    sourcePath: string;
    trimStartSec: number;
    trimEndSec: number;
    frames: Array<{
      index: number;
      timeSec: number;
      jpegDataUrl: string;
    }>;
  }): Promise<AiScenePickResult>;
};
```

### Step 6

Do not let the AI directly own renderer params.

Map the AI result back into existing deterministic patch/recommendation machinery.

### Step 7

Expose enough debug surface to evaluate:

- request payload summary
- selected frame index
- latency
- raw structured response
- fallback reason

### Step 8

Add a tiny evaluation workflow using a handful of proof clips.

## 13. Suggested Engineering Constraints

The next chat should preserve these decisions unless there is a strong reason not to:

- deterministic rendering remains authoritative
- AI output vocabulary stays closed
- no auto-apply during playback
- no public-facing billing work yet
- no permanent product copy that overclaims AI value

## 14. Existing Architectural Constraint That Still Matters

Desktop currently has:

- `1 clip = 1 global grade state`

This means the first AI PoC should not pretend to solve per-shot adaptation.

Instead, it should answer:

- which scene best represents the clip for a single recommendation?

If that cannot be made compelling, it is a strong signal against further investment.

## 15. Important Product Inference

The user is not asking for “AI because AI”.

The real product standard is:

- if the user still has to visually choose the correct scene, the feature is weak
- if AI can remove that decision burden, the feature becomes more meaningful

So the evaluation should focus on:

- reducing user decision burden
- not just improving technical classification quality

## 16. Known Repo State And Caution

The repo has unrelated dirty files outside this work.

Do not revert unrelated modifications.

There are known unrelated changes in areas like:

- `apps/web/*`
- renderer migration work
- `packages/film-lab-core/src/schema.ts`
- `packages/film-lab-ui/src/film-lab-reducer.ts`

The previous feature work itself is committed, but the worktree may still contain unrelated dirty state.

## 17. Suggested Verification Clips

At minimum, use a small internal set like:

- warm indoor practical light clip
- city night point light clip
- daylight close-up portrait clip
- mixed montage clip
- product/detail clip if relevant

For each clip, compare:

- heuristic recommendation
- AI scene pick recommendation
- user manual choice

## 18. Suggested Scoring Sheet

Keep it brutally simple.

For each clip:

- clip id
- heuristic family/recipe
- AI picked frame index
- AI family/recipe
- accepted without scrub: yes/no
- time to acceptable look
- user confidence note
- result better than heuristic: yes/no

## 19. Recommended Final Decision Rule

After the PoC, ask:

- Did AI materially reduce user effort?
- Did users trust the chosen representative frame?
- Did it outperform heuristic enough to justify premium positioning?

If the answer is no, stop expanding AI scope.

If the answer is yes, the next investment should be:

- premium AI representative-scene selection
- stronger fallback/rejection logic
- later, possibly richer semantic scene understanding

## 20. Files Most Likely To Be Touched In The Next Chat

Very likely:

- `apps/desktop-film-lab-batch/src/renderer/App.tsx`
- `apps/desktop-film-lab-batch/src/renderer/optical-scene-analysis.ts`
- `apps/desktop-film-lab-batch/src/renderer/OpticalFinishRecommendationPanel.tsx`
- new internal AI scene-pick service file under `apps/desktop-film-lab-batch/src/renderer/`
- possibly a tiny contract file in `packages/film-lab-core` if shared typing is useful

Possibly but avoid unless needed:

- `packages/film-lab-ui/*`

## 21. Best Handoff Prompt For The Next Chat

Paste the following as the opening prompt in the next chat.

```text
Read these two handoff documents first and treat them as the authoritative context:

1. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/desktop-film-lab-batch/docs/scene-aware-optical-finish-handoff-2026-04-20.md
2. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/desktop-film-lab-batch/docs/ai-scene-pick-validation-handoff-2026-04-20.md

Repo:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

Current branch at prior handoff:
feature/webgpu-migration-v1

Existing heuristic recommendation feature commit:
db8cfdf52e1c9a6e0a44f5415992e78260cd68f2

Important context:
- The non-AI scene-aware Optical Finish recommendation v1 has already been implemented and the user confirmed it is working.
- The user’s current product judgment is that if recommendation still depends on the human visually choosing the right scene, the feature is weak.
- The next task is NOT to finalize a production AI feature.
- The next task is to validate as quickly as possible whether an AI-assisted scene-pick layer can choose a representative scene/frame for a clip in a way that materially improves UX.
- If AI proves valuable here, it likely becomes a paid feature.
- Deterministic rendering should remain authoritative. Do not let AI directly emit arbitrary optical params.

Your job:
- Implement the shortest credible internal/dev-only PoC for “AI Scene Pick” on top of the current desktop recommendation system.
- Reuse existing frame sampling or a very close equivalent.
- AI should operate on sampled frames and return a constrained structured decision, ideally:
  - bestFrameIndex
  - family
  - recipe
  - confidence
  - manualFallback
  - reason
- Then map that back into the existing deterministic optical recommendation/patch system.
- Keep the current heuristic path available as the baseline for comparison.
- Add just enough UI/debugging to evaluate:
  - which frame AI chose
  - why
  - confidence
  - fallback state
  - latency / structured response summary if useful

Non-goals:
- no per-shot architecture work
- no billing implementation
- no public product polish
- no AI-authored raw renderer params unless absolutely required

Success criteria for this PoC:
- A tester can compare heuristic vs AI scene pick on a small set of proof clips.
- We can determine whether AI reduces the user’s need to scrub and visually choose the “right” scene.
- The implementation is small, debuggable, and does not destabilize the existing deterministic recommendation flow.

Before coding:
- inspect the current implementation files mentioned in the handoff docs
- summarize the minimum viable implementation path
- then implement it end-to-end
- run focused tests where appropriate
- report clearly what worked, what remains uncertain, and how to evaluate the PoC

Do not revert unrelated dirty files in the repo.
```

## 22. Final Bottom Line

The next chat should behave as if the question is:

“Can AI remove the need for the user to choose the representative scene by eye, using the smallest possible PoC built on top of the already-working heuristic recommendation system?”

That is the highest-value next step.
