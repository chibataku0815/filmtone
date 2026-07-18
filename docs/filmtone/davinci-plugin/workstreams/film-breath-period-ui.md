# Film Breath Period And UI Contract

Date: 2026-07-19 JST  
Workstream ID: `FILM-BREATH-PERIOD-UI`  
Coordinator: Spatial Director  
State at dispatch: `Ready`

## Goal

Expose an explicit persistent Film Breath frame period and correct the user
surface from generic colour movement to subtractive CMY density variation,
without changing any existing parameter ID/default or another feature's UI.

## Product Evidence And Fixed Interpretation

- Film Breath provides a Period that determines the interval within which
  exposure, contrast, and colour vary, while Impact scales all components:
  <https://www.dehancer.com/learn/article/breath>
- Its Colour component is subtractive CMY-like variation, not temperature/tint.

The Filmtone unit is deliberately frames for deterministic Resolve-host
behavior; this is a Filmtone product decision, not a parity claim.

## Repository And Start Snapshot

- Implementation worktree:
  `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone`
- Git base: `202907ea34b43d1e03e78c2db5125d4d7a722fef`
- Pre-dispatch tracked diff SHA-256:
  `ca3ba2b4548e8dd7907748b3ae208ec66ffa5884257842f143e8a45f0e07bc40`
- Assigned-file start hashes:
  - `FilmBreathParameters.h`: `54ead255c17e2aac99203bf12c2b6114cd733d1a03445d75855cdcbd22ac4349`
  - `FilmtoneFinishParameters.h`: `811ad02cf8a064888042636fed60f84056239658bc64591e7a7e47a5527638f2`
  - `FilmtoneFinishParameters.cpp`: `8b4431e1408275786d4639a0e82b09d04fa896c7dd6b9fadd6f5b93aa63630f8`

The integration worktree is intentionally dirty while its installed bundle is
under owner review. Verify base and all assigned-file hashes before editing.
The coordinator authorizes only this narrow clean-start exception. Preserve
the existing combined diff and do not touch the installed bundle or Resolve.

## Exclusive Edit Area

- `apps/filmtone-resolve-ofx/Sources/Effects/FilmBreath/FilmBreathParameters.h`
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishParameters.h`
- `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneFinishParameters.cpp`
- `docs/filmtone/davinci-plugin/workstreams/progress/film-breath-period-ui.md`

## Frozen Parameter Contract

- New persistent ID:
  `com.forestone.filmtone.finish.filmBreath.periodFrames`
- Kind: real/double
- Label: `Period (Frames)`
- Default: `24.0`
- Range: `1.0...120.0`
- Parent: existing Film Breath `Advanced` group
- Animates: yes, using the same time-read path as existing double controls
- Runtime storage: `FilmBreathParameters::periodFrames`, default `24.0`

All existing IDs, defaults, ranges, labels outside the Film Breath group, and
old-project behavior remain unchanged. An existing project without stored data
receives the descriptor default.

## Copy And Wiring Requirements

1. Register, fetch, retain, and read the Period parameter into
   `FilmBreathParameters::periodFrames`.
2. Relabel the local Color response control to `Subtractive Color` and describe
   it as the amplitude of frame-correlated CMY density variation.
3. Film Breath group/enable hints must mention exposure, tonal contrast, and
   subtractive color variation. Do not imply temperature or tint.
4. Period hint must say that lower values change more quickly and higher values
   breathe over more frames.
5. Keep labels literal and technical. No parity, availability, or marketing
   claim is allowed.
6. Do not change Node Role, plugin display name `Filmtone`, plugin ID
   `com.chibatakumi.filmtone.finish`, or any other feature parameter.

## Acceptance

- Period is fully described, registered, fetched, and read into the Film Breath
  runtime struct.
- Existing parameter IDs/defaults are untouched.
- The visible color terminology is subtractive CMY, not white balance.
- Only the exclusive files and dedicated progress record change.
- Build, Resolve registration, persistence, and visual cadence proof are left
  explicit for coordinator verification after all handoffs.

## Prohibitions And Stop Conditions

Do not run tests, test-like checks, builds, Resolve, install, generation, or Git
writes. Do not edit this plan after dispatch. Stop on assigned-file drift,
parameter collision, out-of-scope Integration dependency, or implementation
completion.

