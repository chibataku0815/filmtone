# Bundled LUT slot for the Filmtone iOS signature preset

`SIGNATURE_PRESET_NAME` (`../signature.ts`) plans two `.cube` LUTs at first launch — those slots are intentionally empty in v1.4 (and were in v1.3).

## Signature preset slots remain unbundled in v1.4

Camera profiles are handled three ways (unchanged from v1.3):

1. **Apple Log / Apple Log 2** — native detection via `HdrPreparationPolicyDeriver` from AVFoundation metadata.
2. **V-Log / S-Log3** — synthesized math (Log decoder + gamut matrix + 33³ cube) in `FilmtoneSourceProfileMath` / `FilmtoneSourceProfileCatalog`. Accuracy fixtures (24-patch ΔE2000 + 8-bit drift) gate at `max = 0.000`.
3. **Rec.709** — passthrough default.

`SIGNATURE_LUT_PLAN[*].bundledRelPath` stays `null`; the canonical Filmtone Signature preset is params-only.

## Built-in Look catalog ships bundled `.cube` in v1.4

Separately from the Signature preset slots, `FilmtoneBuiltInCatalog.swift` ships **Creative LUT Pack 01** (Stone, Urban) as bundled `.cube` files under `Resources/CreativeLuts/`. Both Looks pin a Filmtone-signature rgbShift plus optics (bloom / halation / diffusion / lensSoftness / grain / vignette) on top of the cube. The 4 v1.3 preset-wrapper Looks (Filmtone Signature / Clean Base / Amber Glow / Soft Blue) are removed; their UUIDs are deprecated and intentionally not reused (see `BuiltInLookUUID`). v1.3 `...000005` reservation (retired Night Soft) is also not reused.

v1.5+ may revisit `SIGNATURE_LUT_PLAN` bundled `.cube` paths once licensing for non-Apple/non-synthesized curves (Nikon N-Log, Canon Log 3, ARRI LogC4, BMD Film Gen 5) is settled. The pipeline for adding new synthesized curves is documented in `.claude/knowledge/patterns/2026-04-30-source-profile-fixture-pipeline.md`.
