# Film Damage And Grain Quality Knowledge

Date: 2026-06-01 JST
Scope: Native Desktop and iOS/iPad optical kernels.

## Problem Signal

Film Damage and Film Grain can look detached when they read as clean
screen-space overlays instead of material marks inside the image. The most
visible failure modes are:

- grain that slowly swims or morphs over the image;
- damage masks that remain too clean after the grain and print stages;
- white scratches or dust that look digitally pasted because they have no
  internal grain, soil, or local luminance response;
- defects with uniform opacity across shadows, midtones, and highlights.

## Industry Pattern

The relevant pattern across film-emulation tools is not "put noise on top." The
stronger model is material response:

- grain is tied to exposure, color, density, stock/profile, and scan texture;
- damage has rough edges, gaps, local softness, defocus, and temporal behavior;
- visible defects are reabsorbed by the same print/scan/grain response as the
  image, or deliberately treated as projector/gate material with its own
  physical texture.

Useful references:

- Dehancer Film Grain: https://www.dehancer.com/learn/article/grain
- FilmConvert Nitrate: https://www.filmconvert.com/nitrate
- Adobe Add Grain / Match Grain: https://helpx.adobe.com/after-effects/using/noise-grain-effects.html
- Boris FX FilmDamage family: https://borisfx.com/documentation/sapphire/ofx/filmdamage/

## Filmtone-Specific Cause

The Filmtone native order is effectively:

```text
base/film compression/detail/optics -> grain -> creative LUT -> print -> film damage
```

This is a pragmatic order, but it means Film Damage can bypass the grain and
print response and appear as a clean final overlay. Earlier work improved the
damage shape and polarity, but it did not fully solve the integration problem.

## Applied Rule

The first reliable fix is to integrate the final damage marks locally rather
than lowering their strength globally:

- track a total damage/material mask from all damage sublayers;
- re-grain only pixels where damage exists;
- soil bright damage slightly with neutral luma texture;
- return a small amount of local source tone into damaged areas;
- lock damaged pixels toward neutral grayscale to avoid warm/brown tint;
- make grain update like frame material instead of a slow smooth overlay.

This keeps defects visible while reducing the "clean mask pasted on top" read.

## Current Implementation

Implemented in:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/filmtone-desktop-macos/Verify/FilmDamageVisualProbe.swift`

Behavior:

- Grain now uses a 24 fps material clock with a very small sub-frame blend.
- Film Damage builds a `materialMask` from gate wear, edge soil, dirt, stain,
  dust, sparkle, scratch, and fiber blends.
- Damaged regions receive neutral micro re-grain, source-luma tone return, and
  a small bright-defect soil pass.
- The probe now emits damage-only and grain+damage sheets so future iterations
  can compare integration quality.

## Remaining Quality Ceiling

This pass is still procedural. The next larger quality jump would come from:

- splitting damage into pre-print and post-projector layers;
- adding real or authored plate/material assets;
- using source softness or motion information to blur/smear defects;
- making grain response stock/profile-aware rather than only intensity/size
  controlled;
- building side-by-side visual regression probes from real footage instead of
  synthetic plates only.
