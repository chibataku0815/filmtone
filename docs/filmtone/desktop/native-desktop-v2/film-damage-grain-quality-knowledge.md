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

- Grain now uses a 24 fps material clock without sub-frame morphing.
- Film Damage builds a `materialMask` from gate wear, edge soil, dirt, stain,
  dust, sparkle, scratch, and fiber blends.
- Damaged regions receive neutral micro re-grain, source-luma tone return, and
  a small bright-defect soil pass.
- Dust should read as small, clear physical specks. Large dirt/stain fields are
  kept subtle so the Dust control does not produce oversized spots.
- Scratches should use a thin core with only a restrained scuffed edge; raising
  visibility should not make the line body broad.
- Scratches remain film/gate-space material rather than source-tracked marks,
  but must not be perfectly static. Add subtle gate weave, per-scratch drift,
  density breathing, and live gap flutter so they do not read as a fixed overlay.
- The probe now emits damage-only and grain+damage sheets so future iterations
  can compare integration quality.

## Performance Rule

Final optical kernels run for every export pixel, so integration quality cannot
depend on smooth multi-sample noise over the whole frame.

- Guard local re-grain work behind the `materialMask`; clean pixels should skip
  the damage-integration tail.
- Prefer cheap quantized cell hashes for damaged-region micro texture over
  smooth value-noise calls in the final pass.
- Reject absent Film Damage events before fade and shape work. `damageSpot` and
  `damageScratch` are called repeatedly per pixel, so presence and lifetime
  checks must happen before contour, roughness, gap, and texture calculations.
- Avoid sub-frame grain morphing in export kernels unless there is a measured
  need; one stable frame-material grain pattern is cheaper and less synthetic.
- Keep smooth Grain noise only where it carries density/large-scale texture.
  High-frequency grain and scratch/dust material texture can use direct cell
  hashes; film material should read granular, not interpolated everywhere.
- Gate Film Damage families explicitly. Dust-only exports should not run
  scratch/fiber work, and scratch-only exports should not run dirt/stain/dust
  cell work.
- Desktop video export should use an export-only CoreImage context with
  intermediate caching disabled, matching the iOS export path. The shared
  preview context is the wrong lifetime model for long 4K exports.
- Wait for writer readiness before rendering the next frame. Rendering into a
  fresh pixel buffer while AVAssetWriter is already backpressured increases
  memory pressure without increasing throughput.
- Do not use short writer-ready or finish timeouts as proof of failure in
  offline heavy-optics exports. Surface writer status and finalization progress
  separately so a final encoder flush does not look like a render hang.
- Keep Desktop and iOS/iPad kernels aligned before judging visual parity.

## Export Timing Rule

Use `FILMTONE_EXPORT_TIMING=1` for real-source export diagnosis before guessing
where performance was lost. The opt-in Desktop timing summary separates:

- source frame read;
- writer readiness wait;
- CoreImage graph construction;
- CoreImage render;
- writer append;
- audio, validation, sidecar, and final writer finish.

On the 2026-06-01 4K/24fps 10s DJI heavy Grain + Film Damage stress export,
`render` dominated the profile: 240 frames exported in 6.04s wall time, with
render at 4356.7ms / 78.3% of measured elapsed time. `writer_wait`, `append`,
and `finish` were not material bottlenecks in that run.

On 2026-06-02, a 1080x1920 60fps ~59.67s source with AAC audio reproduced a
different failure: heavy export reached the final frames then failed after about
148s with `waitForReadyTimedOut`; the same source without audio completed in
about 27.6s. Treat this as AVAssetWriter audio/video input coordination, not
visual kernel cost. Desktop should preserve audio with a separate audio reader
and an `audioInput.requestMediaDataWhenReady` pump, matching the iOS queue
model; do not append audio through a polling async wait loop while the video
render loop is also feeding the writer.

## Embed Rule

Do not solve floating damage by simply lowering opacity. Preserve visible
defects, but reintroduce a neutralized version of the source tone into damaged
pixels:

- keep a pre-damage source RGB sample and source luma;
- build a nearly monochrome source texture from that sample;
- scale it by the damaged pixel's luma ratio;
- blend it back only under the damage material mask;
- apply neutral lock after this embed pass so source texture does not become
warm/brown tint.

This makes dirt, scratches, and damaged grain inherit a little of the source
surface variation without turning defects into colorized overlays.

## Remaining Quality Ceiling

This pass is still procedural. The next larger quality jump would come from:

- splitting damage into pre-print and post-projector layers;
- adding real or authored plate/material assets;
- using source softness or motion information to blur/smear defects;
- making grain response stock/profile-aware rather than only intensity/size
  controlled;
- building side-by-side visual regression probes from real footage instead of
  synthetic plates only.
