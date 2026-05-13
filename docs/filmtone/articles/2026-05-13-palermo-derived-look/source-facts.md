# Source Facts

- Palermo PowerGrade analysis is recorded at
  `docs/filmtone/handoff/2026-05-13-palermo-powergrade-analysis.md`.
- The useful implementation inputs are measured behavior: print-like white
  ceiling, warm neutral blue suppression, dense skin, cyan/sky separation,
  green density, and native spatial optics.
- Do not ship or copy vendor `.drx`, `.cube`, or preview images.
- M3 implementation uses an original `applyStonePalermoSignature` pass after
  the display-domain Palermo sample. It gates neutral warmth, skin density,
  sky/cyan separation, and green density by input luma/chroma/hue.
- Stone transform id moved from `filmtone-stone-dlogm-palermo-display-v1` to
  `filmtone-stone-dlogm-palermo-display-v2`; baker version moved to
  `1.5.0-stone-palermo-signature`.
- After owner review, Stone-only localized optics were raised without lowering
  `bloomThreshold` or adding fade/broad diffusion: bloom strength/radius,
  halation, rgb shift, and lens softness increased modestly.
