# Shadow Latitude Strategy

## Goal

Restore separation inside high-contrast low shadows while keeping Filmtone's black density anchored. `shadowLatitude` is an authored render parameter, not a fade, global shadow lift, or weakening of `FilmCompressionV3`.

## Done Conditions

- `shadowLatitude` is shared across Phase0 contracts, renderer params, Swift payloads, and native pipelines.
- Default behavior is neutral at `0`.
- The toe pass preserves the black anchor below about `0.025`, peaks in low-mid shadows, and releases by about `0.30`.
- The default grade path remains neutral; authored Look adoption is limited to explicitly reviewed runtime patches.
- UI remains hidden in this pass.

## Constraints

- Schema version remains unchanged.
- Do not add `shadowLatitude` to `BAKE_COLOR_PARAM_KEYS`.
- Do not hand-edit generated Swift; regenerate it with `bun run generate:ios-swift`.
- Stop after 3 consecutive verification failures or if black-anchor invariants fail.

## Completion Log

- 2026-05-12: Added hidden `shadowLatitude` / `toeSeparation` across core, Swift, iOS/macOS native, WebGL, and WebGPU. The default grade path stays neutral until a separate authored tuning pass adopts the parameter for selected Looks.
