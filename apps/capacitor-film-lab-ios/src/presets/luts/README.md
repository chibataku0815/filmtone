# Bundled LUT slot for the Filmtone iOS signature preset

`SIGNATURE_PRESET_NAME` (`../signature.ts`) used to plan two `.cube` LUTs at first launch — those slots are intentionally empty in v1.3.

## v1.3 ships zero bundled `.cube`

Camera profiles are handled three ways:

1. **Apple Log / Apple Log 2** — native detection via `HdrPreparationPolicyDeriver` from AVFoundation metadata.
2. **V-Log / S-Log3** — synthesized math (Log decoder + gamut matrix + 33³ cube) in `FilmtoneSourceProfileMath` / `FilmtoneSourceProfileCatalog`. Accuracy fixtures (24-patch ΔE2000 + 8-bit drift) gate at `max = 0.000`.
3. **Rec.709** — passthrough default.

Built-in Looks are params-only via `FilmtoneBuiltInCatalog.swift` (5 entries). `SIGNATURE_LUT_PLAN[*].bundledRelPath` stays `null`.

v1.4 may revisit bundled `.cube` paths once licensing for non-Apple/non-synthesized curves (Nikon N-Log, Canon Log 3, ARRI LogC4, BMD Film Gen 5) is settled. The pipeline for adding new synthesized curves is documented in `.claude/knowledge/patterns/2026-04-30-source-profile-fixture-pipeline.md`.
