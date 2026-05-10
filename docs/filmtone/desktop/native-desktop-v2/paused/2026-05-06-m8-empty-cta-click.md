# M8 Empty CTA Physical Click

Milestone: M5 Native Editing UI follow-up
Date opened: 2026-05-06 JST

## Goal

Make the empty-state `素材を開く` CTA respond to normal mouse / trackpad
clicks, not only accessibility activation.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift` only if
  root layering proves involved

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-empty-open-button-hit-testing.md`

## Checklist

- [x] Reproduce physical coordinate-click failure on the central CTA.
- [x] Confirm toolbar Open still responds to coordinate clicks.
- [ ] Replace or wrap the CTA so its visible shape owns a real mouse hit
  target without enlarging the button or reintroducing card-in-card.
- [ ] Confirm physical coordinate click opens the frontmost Open panel.
- [ ] Run Native Desktop verification and whitespace check.
- [ ] Launch current Debug build for visual confirmation.
- [ ] Archive this task and append a compact strategy note.

## Verification

- `bun run verify:macos` passed after the latest rejected visual experiment.
- `git diff --check` passed after the latest rejected visual experiment.
- Product verification is not complete: user rejected the current visual state,
  and full left/center/right coordinate-click confirmation is still missing.

## Done Conditions

- Normal coordinate click on the visible empty-state CTA opens the Open panel.
- Toolbar Open still opens the same panel.
- Verification passes.

## Stop Conditions

- Done conditions met.
- Root cause requires replacing the transparent launch window posture.
- 3 consecutive verification failures.

## Out Of Scope

- Empty-state visual redesign beyond click-target correctness.
- Media type or import pipeline changes.
- Release packaging or public metadata updates.

## Unexpected Blockers

- Latest `PreviewSurface.swift` experiment enlarged the CTA and drew a visible
  square opening plate. User rejected it as "button getting bigger" and
  "card-in-card".
- Handoff created:
  `docs/filmtone/desktop/native-desktop-v2/2026-05-06-m8-empty-cta-click-handoff.md`.

## Paused

Paused on 2026-05-06 JST for the Native Desktop v1.6 release interrupt.

Done:

- Reproduced the physical coordinate-click failure on the central CTA.
- Confirmed toolbar Open still responds to coordinate clicks.

Not done:

- Proper compact CTA hit-target fix remains unresolved.
- Product confirmation for a restored empty-state CTA is still needed.

Resume after the v1.6 release lane is archived unless the release scope changes
the empty-state direction.
