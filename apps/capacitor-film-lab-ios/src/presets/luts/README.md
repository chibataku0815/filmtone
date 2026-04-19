# Bundled LUT slot for Filmtone iOS Phase 0 signature preset

The signature preset (`SIGNATURE_PRESET_NAME` in `../signature.ts`) plans to ship two `.cube` LUTs at first launch:

| Slot | Intended file | Role |
|---|---|---|
| `inputLut` | `vlog-to-rec709.cube` | Camera Profile (Log -> Rec.709 input transform) |
| `creativeLut` | `filmtone-signature.cube` | Film Look (Filmtone signature creative grade) |

## Current state (2026-04-18)

No `.cube` assets ship in the worktree yet. `SIGNATURE_LUT_PLAN[*].bundledRelPath` is `null` for both slots.

The dual-LUT pipeline still works — the user picks LUT1 / LUT2 manually via `Phase0LutPicker` until bundled assets land here.

## How to bundle

1. Drop the two `.cube` files into this directory using the names listed above.
2. Update `bundledRelPath` for each slot in `../signature.ts` to the relative path (e.g. `"luts/vlog-to-rec709.cube"`).
3. Wire a one-time loader in `MobilePhase0Editor.tsx` that, on mount when `state.project.lut` is `null`, fetches the bundled `.cube` via `import.meta.url` (or Capacitor `Filesystem.readFile`), parses with `parseCube()` from `film-lab-core`, and applies via `applyLutSelection`.
4. Add a parallel loader for `inputLut` (local `useState` lives in `MobilePhase0Editor`, not in `state.project`).

## Why this is not blocking Phase 0

Phase 0 is a kill-test of export viability with dual-LUT support, not a polished first-run experience. The signature preset's params already produce a representative Filmtone look without LUTs. Bundled LUTs only sharpen the first-launch impression for non-technical testers.
