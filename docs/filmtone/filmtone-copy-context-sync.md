# Filmtone Copy / History Context Sync

Purpose: keep product implementation updates from drifting away from the copy,
history, and claim truth that future writing must reference.

This is not a broad documentation requirement. It is a lightweight impact
decision gate. Core implementation progress stays first; copy/history work is
required only when the implementation change affects a user-facing claim,
release claim, or implementation-history story.

## Rule

When changing a product surface that can affect public claims, record one of
these outcomes before handoff:

- Update the relevant copy, release notes, metadata, copy harness, or
  implementation-history source.
- Add a `Copy / History Impact` section to the changed lane doc and state the
  required follow-up.
- If nothing changes for public writing, add
  `No copy/history impact: <reason>`.

Do not write full marketing copy just to satisfy the rule. The required unit is
the impact decision. Write or revise public copy only when the changed behavior,
architecture story, or release claim actually needs it.

## High-Risk Changes

Treat these as likely to need a copy/history impact decision:

- iOS native runtime, capture, export, sidecar, library, SwiftUI, or Fastlane
  metadata.
- Native Desktop runtime, color pipeline, export, verification, or Mac App
  Store metadata.
- Shared `film-lab-core`, `film-lab-renderer`, or `film-lab-smart-look`
  contracts, especially preset, LUT, source profile, renderer, schema, or
  generated Swift payload changes.
- Public copy sources such as `messages/{ja,en}.json` and App Store metadata.
- Release/version scripts, copy-quality scripts, and verification scripts that
  affect what Filmtone can safely claim.

Private refactors can be marked as no-impact when they do not change behavior,
public availability, architecture story, or release wording.

## Where To Record The Decision

Prefer the smallest durable location:

- Current lane `active.md` while work is ongoing.
- The archived lane doc when closing a task.
- The relevant `strategy.md` only when the product direction or milestone state
  changed.
- `docs/filmtone/filmtone-implementation-history.md` when the WebGPU / WebGL →
  React + Capacitor → native SwiftUI / AVFoundation story changes.
- `docs/filmtone/filmtone-copy-quality-harness.md` when authoring rules or
  public claim boundaries change.

Use this exact shape when possible:

```md
## Copy / History Impact

- Public copy update required: <surface and reason>
- Implementation history update required: <source and reason>
- Release/App Store claim: <truth script or source to run before writing>
- Article Opportunity: <No story | Release-note only | Short post | Full article | Developer note> — <reason>
- Change-History Opportunity: <No history story | Context paragraph | Developer note | Full history article | Hold> — <reason>
- No copy/history impact: <reason>
```

Keep it short. The goal is recoverable context, not a second handoff.

## Article Opportunity Gate

Implementation agents should decide the article opportunity proactively. Do not
ask the owner whether every change deserves a post.

Classify each substantial product change into one of these outcomes:

| Outcome | Use when | Default action |
|---|---|---|
| `No story` | Internal refactor, plumbing, cleanup, or bug fix with no user-visible change and no durable implementation lesson. | Record the reason only. |
| `Release-note only` | User-visible but narrow change, small fix, compatibility note, or App Store metadata item. | Keep it in release notes / handoff; no draft. |
| `Short post` | A shipped change gives a clear reason to try Filmtone now, but does not need diagrams or long history. | Draft 1 short post when the public claim is verified. |
| `Full article` | A shipped release changes the workflow, introduces a visible quality step, or has a useful product story with proof. | Draft an article brief plus first-pass article. |
| `Developer note` | The value is mostly implementation history, architecture, or a reusable technical lesson. | Draft a technical note only if current source and history docs support it. |

Use this scorecard before choosing the outcome:

- User-visible workflow changed: `0-2`
- Visible output quality, performance, or reliability improved: `0-2`
- Public release / App Store state is already verified: `0-2`
- There is a clear reader and next action: `0-2`
- The implementation story prevents future misunderstanding: `0-2`
- Proof exists: screenshot, video, release note, test, benchmark, or source:
  `0-2`
- Claim risk is low after truth scripts/source checks: `0-2`

Default thresholds:

- `0-3`: `No story`
- `4-6`: `Release-note only`
- `7-9`: `Short post`
- `10+`: `Full article` or `Developer note`, depending on the reader

If the score is high but the claim is not public yet, classify it as
`Short post candidate` or `Full article candidate` and name the blocking truth
gate. Do not publish-language-draft it as current fact.

Draft proactively only when all are true:

- The change is shipped or clearly marked as candidate.
- The audience and next action are clear.
- The draft can be written from current source, truth scripts, and dated lane
  docs without asking the owner for missing facts.
- Writing it will not delay the core implementation or required verification.

Ask the owner only when the article would commit to positioning, pricing,
platform support, legal/privacy claims, or a public promise that is not already
settled in source or release truth.

## Change-History Story Gate

Implementation agents should also decide whether the change history itself is
worth writing up. This is separate from user-facing feature value.

Use this gate when a task changes or clarifies:

- why an old approach existed;
- why an approach was retired, replaced, or narrowed;
- the source of truth for a product lane;
- the boundary between Web / iOS / macOS / shared packages;
- the relationship between product quality and implementation choice;
- a rejected path that future agents are likely to rediscover;
- a release/cutover that changes how future claims should be explained.

Classify change-history opportunity like this:

| Outcome | Use when | Default action |
|---|---|---|
| `No history story` | Routine implementation with no lasting narrative, no changed source of truth, and no likely future confusion. | Record the reason only. |
| `Context paragraph` | The change needs one explanatory paragraph inside a release post, handoff, or strategy log. | Write the paragraph, not a standalone article. |
| `Developer note` | The lesson is mostly technical or architectural and useful for future implementation. | Draft a technical note from current source and lane docs. |
| `Full history article` | The before/after story explains a meaningful product direction, migration, or quality decision. | Draft a history article brief plus first pass when claims are verified. |
| `Hold` | The story is likely valuable, but release state, source proof, or product direction is not settled yet. | Record the blocking truth gate and do not publish-language-draft it as current fact. |

Trigger `Context paragraph` or higher when at least two of these are true:

- There is a clear before/after architecture or product workflow.
- The old approach was rational and needs to be explained, not dismissed.
- The new approach follows from product quality, performance, release
  correctness, or visual fidelity.
- A future agent could easily describe the change incorrectly without this
  context.
- The story changes public positioning, release notes, or implementation-history
  claims.
- Evidence exists in current source, strategy/archive docs, truth scripts, or
  shipped release notes.

For Filmtone, examples that should be considered:

- React + Capacitor existed to reuse the original WebGPU / WebGL renderer path;
  native SwiftUI / AVFoundation later became necessary for capture and Live
  Look runtime quality.
- Native Desktop v2 replaced the earlier Desktop rail after the public cutover;
  old Electron package versions are no longer the release truth.
- Source Profile and Creative Look LUT are separate concepts; a future article
  should not collapse them for elegance.
- Generated Swift payloads preserve shared color truth; native runtime work
  should not be described as forking Filmtone away from shared packages.

Avoid standalone history articles for:

- ordinary refactors with no reader consequence;
- temporary experiments without settled direction;
- bug fixes where a release note is enough;
- blame-shaped stories such as `X was a mistake`;
- claims that need unpublished or unverified state to sound compelling.

## Mechanical Check

Run:

```sh
bun run check:filmtone-context
```

The check reads the current git diff and fails when high-risk product/copy
changes exist without either:

- a changed context/copy source, or
- a changed lane doc containing `Copy / History Impact` or
  `No copy/history impact`.

Then run:

```sh
bun run check:filmtone-copy
```

when public copy or metadata changed. The context sync check proves that the
impact decision exists; the copy check proves wording quality for scanned
public surfaces.

## What This Prevents

- Explaining React + Capacitor as a generic cross-platform mistake instead of
  the bridge that reused the original WebGPU / WebGL renderer path.
- Describing native SwiftUI / AVFoundation work as a rewrite without preserving
  the shared TypeScript color contract.
- Publishing release or App Store copy from an old handoff instead of current
  truth scripts and current source.
- Letting implementation changes silently create future copy debt.
