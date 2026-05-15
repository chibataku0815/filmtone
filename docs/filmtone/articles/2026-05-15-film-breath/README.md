# Film Breath Article Foundation

Created: 2026-05-15 JST
Status: foundation only; not publish-ready copy.

## Copy Brief

- Surface: future release note / article candidate for a shipped Film Breath
  video Motion control.
- Primary reader: a Filmtone Mac or iPhone editor checking a video in playback
  before export and deciding whether the result feels too static.
- Moment: after choosing a Preset or Look, before export, while reviewing motion
  and grade continuity.
- Unresolved feeling: the grade is technically set, but the clip can feel too
  fixed frame-to-frame.
- Next action: try one Film Breath Amount control on video, compare playback,
  then export only if the movement helps.
- Not for: still-image editing, Gate Weave / damage effects, or a Dehancer
  compatibility promise.
- Claim class: Candidate until Desktop and iOS verification passes and release
  state is confirmed.
- Source evidence: current Film Breath active lane, implementation source, and
  final verification logs after completion.
- Reversibility buffer: describe this as a video Motion control for subtle
  exposure / contrast / color variation; avoid release/version wording until the
  truth scripts are run.

## Product Foundation

Film Breath in Filmtone is one Amount control. It is not a set of Dehancer-style
profile/custom controls. The implementation target is a subtle time-domain
change in exposure, contrast, and color that remains continuous from frame to
frame and follows the existing native grade pipeline into export.

Reference category only: Dehancer describes Film Breath as frame-to-frame
changes in exposure, contrast, and color, with period/smoothness affecting how
fast the fluctuations move.

## Claim Boundaries

- Do not claim still-image support.
- Do not claim Gate Weave, physical film damage, scratches, dust, scan jitter,
  or camera weave.
- Do not claim Dehancer compatibility.
- Do not mention Desktop/iOS release versions until the truth scripts confirm
  public state.
- Do not flatten implementation history into a generic native rewrite story:
  shared TypeScript color truth and generated Swift payloads remain central.

## Article Opportunity

Release-note + Full article candidate. The article becomes draftable only after
the feature is verified in Desktop and iOS video preview/export and the public
release claim is known.
