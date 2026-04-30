import type { Phase0Params } from "./phase0-schema";

/**
 * iOS Phase 0 ships with a deliberately small preset set.
 *
 * Shared PRESETS remain the canonical Desktop/Web defaults. iOS uses these
 * mobile-specific patches over Filmtone's soft default base so the phone app
 * has fewer, clearer choices without changing other product surfaces.
 *
 * v1.4 Look V2 — values re-derived against CD reference frames:
 *   - Filmtone Signature ↔ warmglow-4s/6.5s (warm cozy candle, portra-like)
 *   - Soft Blue        ↔ guasha-1s/3s/5s (cool window highlight + warm
 *                         interior shadow — split-tone via new shadowHue/
 *                         highlightHue/shadowTone/highlightTone fields)
 *   - Amber Glow       ↔ warmglow-1.5s (dramatic warm flame, gold200-like)
 *
 * Each value carries a reason (which reference / which desktop stock pulled
 * it). handoff §3.7 — no arbitrary bumps.
 */
export const FILMTONE_IOS_PRESET_NAMES = [
  "reset",
  "iphone",
  "softBlue",
  "amberGlow",
] as const;

export type FilmtoneIosPresetName =
  (typeof FILMTONE_IOS_PRESET_NAMES)[number];

export const FILMTONE_IOS_PRESET_PATCHES = {
  reset: {
    halationIntensity: 0,
  },
  // Filmtone Signature — portra-like warm-cozy DNA. Reference: warmglow mid
  // frames (4s/6.5s) — single-source warm scene with subtle skin tone and
  // soft halation around the candle. Desktop nearest: portra (contrast 1.10,
  // saturation 0.90, halation 0.18, halationHue 28). We push spatial up
  // toward portra (halation 0.018 → 0.10 — handoff §3.6 reversal of "Filmtone
  // Signature is spatial-weakest" contradiction) while keeping skin-friendly
  // gentle desat. New crosstalk fields paint shadow cool-blue (220°) and
  // highlight warm-amber (30°) — matches portra's classic film-look DNA.
  iphone: {
    exposure: 0.04,
    contrast: 1.12,
    saturation: 0.95,
    temperature: 0.06,        // warmglow scene warmth (was 0.04)
    tint: 0.02,
    rgbShift: 0.0012,
    lensSoftness: 0.14,
    grainSize: 0.26,
    bloomThreshold: 0.72,     // -0.02 — bloom triggers earlier on candlelit highlights
    bloomStrength: 0.18,      // +0.02 — soft warm halo around lights
    bloomRadius: 0.48,
    diffusion: 0.06,          // +0.01 — atmosphere
    halationIntensity: 0.10,  // 0.018 → 0.10 — handoff §3.6 spatial-strengthening (portra=0.18 reference)
    halationSpread: 20,
    halationHue: 28,          // portra reference (warm orange)
    halationRadius: 0.42,
    compressionAmount: 0.28,  // 0.35 → 0.28 — gentler latitude, preserve highlight punch
    compressionRange: 0.5,
    printContrast: 0.08,      // 0.10 → 0.08 — subtler print effect
    fade: 0.04,               // 0.06 → 0.04 — minimal matte
    shadowTone: 0.08,         // NEW — gentle cool shadow lift (Portra-style)
    highlightTone: 0.06,      // NEW — gentle warm highlight glow (skin)
    shadowHue: 220,           // NEW — cool-blue shadow direction
    highlightHue: 30,         // NEW — warm-amber highlight direction
    vignette: 0.18,
    grainIntensity: 0.012,
  },
  // Soft Blue — cool window light per Gua Sha Window reference. The reference
  // is NOT uniformly cool — it's a *split-tone*: window highlights are
  // cyan-blue, room shadows hold warm beige. Desktop nearest: cinestill800t
  // (cool but uniform). v1.4 unique value comes from new highlightHue/
  // shadowHue fields encoding the *direction* of cool-warm split, not just
  // overall cool shift. Strong window bloom + halation reflect Cinestill's
  // remjet-removal halo character.
  softBlue: {
    exposure: 0.04,
    contrast: 1.05,           // 0.99 → 1.05 — Gua Sha mid-strong contrast (was too flat)
    saturation: 0.92,         // 1.02 → 0.92 — Cinestill 800T-like desat (cool comes from hue, not sat)
    temperature: -0.06,       // -0.14 → -0.06 — easing global cool, since highlight cool now lives in highlightHue
    tint: -0.04,              // -0.06 → -0.04 — easing global tint
    rgbShift: 0.0016,
    lensSoftness: 0.22,
    grainSize: 0.34,
    bloomThreshold: 0.60,     // 0.66 → 0.60 — window blooms earlier (Gua Sha visible window glow)
    bloomStrength: 0.24,      // 0.18 → 0.24 — toward Cinestill (0.40) but mid-way for control
    bloomRadius: 0.72,
    diffusion: 0.10,          // 0.075 → 0.10 — Cinestill atmospheric haze (cinestill=0.16 reference)
    halationIntensity: 0.06,  // 0.02 → 0.06 — subtle warm window-edge halo
    halationSpread: 24,
    halationHue: 14,          // 18 → 14 — Cinestill-style deep-red halation tint
    halationThreshold: 0.54,
    halationRadius: 0.5,
    bloomSoftKnee: 0.72,
    halationSoftKnee: 0.42,
    compressionAmount: 0.40,  // 0.45 → 0.40 — gentler latitude
    compressionRange: 0.5,
    printContrast: 0.10,      // 0.12 → 0.10
    cyan: 0.015,
    magenta: -0.03,
    yellow: -0.025,
    fade: 0.10,               // 0.18 → 0.10 — Gua Sha is a clear-light scene, not high matte
    shadowTone: 0.10,         // NEW — warm beige shadow lift (Gua Sha interior warmth)
    highlightTone: 0.18,      // NEW — strong cool cyan window highlight
    shadowHue: 30,            // NEW — warm-amber shadow direction (split-tone reversal)
    highlightHue: 200,        // NEW — cyan-blue highlight direction (Gua Sha window)
    vignette: 0.16,
    grainIntensity: 0.014,
  },
  // Amber Glow — dramatic warm-glow per warmglow-1.5s reference. Single
  // strong warm key light + intense bloom around the flame. Desktop nearest:
  // gold200 (contrast 1.20, saturation 1.15, temperature 0.18, halation 0.12,
  // halationHue 32). Push toward / past gold200 since reference shows a more
  // dramatic warm-saturation than typical Gold-200 daylight scenes.
  amberGlow: {
    exposure: 0.01,
    contrast: 1.18,           // 1.03 → 1.18 — gold200-class punch (gold200=1.20 reference)
    saturation: 1.10,         // 1.03 → 1.10 — warm-vibrant (gold200=1.15 reference)
    temperature: 0.20,        // 0.16 → 0.20 — strong warm dominance (gold200=0.18, push past)
    tint: 0.04,
    rgbShift: 0.0015,
    lensSoftness: 0.16,
    grainSize: 0.32,
    bloomThreshold: 0.62,     // 0.64 → 0.62 — flame highlight blooms easily
    bloomStrength: 0.24,      // 0.20 → 0.24 — dramatic warm halo (toward Cinestill)
    bloomRadius: 0.5,
    diffusion: 0.10,
    halationIntensity: 0.16,  // 0.04 → 0.16 — heavy warm halation (>gold200 0.12 since reference is more dramatic)
    halationSpread: 22,
    halationHue: 35,          // 30 → 35 — slightly more orange (gold200=32 reference)
    halationThreshold: 0.52,
    halationRadius: 0.46,
    bloomSoftKnee: 0.62,
    halationSoftKnee: 0.44,
    compressionAmount: 0.35,  // 0.40 → 0.35 — preserve warm highlight punch (don't crush)
    compressionRange: 0.5,
    printContrast: 0.12,      // 0.15 → 0.12
    cyan: -0.025,
    magenta: 0.06,            // 0.05 → 0.06 — slight magenta for warm skin
    yellow: 0.08,             // 0.06 → 0.08 — stronger yellow for amber glow
    fade: 0.04,
    shadowTone: 0.06,         // NEW — warm shadow tint (warmglow scene unifies warm)
    highlightTone: 0.18,      // NEW — strong warm-amber highlight
    shadowHue: 30,            // NEW — warm-amber shadow direction (NOT cool, matching warmglow scene unity)
    highlightHue: 40,         // NEW — warm-orange highlight direction (gold200/flame DNA)
    vignette: 0.22,
    grainIntensity: 0.016,
  },
} satisfies Partial<Record<FilmtoneIosPresetName, Partial<Phase0Params>>>;
