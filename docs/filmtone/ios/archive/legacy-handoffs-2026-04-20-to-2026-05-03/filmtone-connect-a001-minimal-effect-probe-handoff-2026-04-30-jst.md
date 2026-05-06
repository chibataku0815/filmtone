# Filmtone Connect A001 Minimal Effect Probe Handoff

Date: 2026-04-30 JST

## Goal

Probe each missing Filmtone effect as the smallest Resolve DCTL unit before
continuing product implementation in a new chat.

Target fixture:

- Package: `/tmp/filmtone-connect-a001-v2-split-dctl-test`
- Source: `/tmp/filmtone-connect-a001-v2-split-dctl-test/filmtone-export-6d0b30ba-e7e2-46be-9108-5df226ebee8c-source.mov`
- iOS reference frame: `/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/ios-device-rendered.png`
- no-LUT Resolve frame: `/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/resolve-no-lut-normalized.png`
- Reference time: `2.2604195011337866s`

## Important DCTL Finding

Resolve accepts the minimal texture DCTL form, but rejects or silently no-ops
more complex DCTL structure.

Safe pattern observed:

- texture transform signature
- `DEFINE_LUT`
- `_tex2D`
- `APPLY_LUT`
- scalar helper functions
- direct scalar math inside `make_float3(...)`

Avoid for now:

- custom `float3` helper functions
- `float3` accumulation / vector arithmetic
- large multi-helper optical blocks

Failure mode to watch: Resolve UI shows the DCTL on node 1, but
`ResolveDebug.txt` logs `Error Processing DaVinci CTL` and the exported frame
matches no-LUT exactly.

## Probe Results

All probes below compiled and rendered with `ctl_error=false`.

| Probe | vs iOS MAE | vs iOS RMSE | vs no-LUT MAE | Result |
|---|---:|---:|---:|---|
| baseline split compensated DCTL | 19.042530 | 27.116449 | 25.848776 | current baseline |
| RGB shift only | 18.960514 | 26.957575 | 25.944052 | best single improvement |
| softness only | 19.032560 | 27.097082 | 25.839653 | tiny improvement |
| diffusion only | 32.180904 | 43.659882 | 33.471470 | bad approximation |
| bloom only | 19.455194 | 27.580306 | 27.757359 | worse |
| halation only | 19.025793 | 27.098546 | 25.965443 | tiny improvement |
| vignette only | 26.716019 | 32.419998 | 19.309742 | much worse |
| grain only | 21.039751 | 28.920228 | 24.921204 | worse by pixel metric |

Raw JSON:

`/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/probe-minimal-effects-results.json`

Rendered probe frames:

`/tmp/filmtone-connect-a001-v2-split-dctl-test/compare/probe-*.png`

Probe runner:

`/tmp/filmtone_dctl_effect_probe.py`

## Interpretation

RGB shift is the first production candidate. It is Resolve-valid and improved
A001 metrics in isolation.

Softness is also Resolve-valid, but the current 4-tap global version improves
only slightly. It should be promoted only after adding an edge/ray-angle mask.

Halation is Resolve-valid and slightly positive, but this probe is not a real
mip-pyramid halation model. Treat it as syntax feasibility, not product parity.

Diffusion, bloom, vignette, and grain should not be promoted from these probe
versions. They either darken/blur the A001 frame in the wrong direction or add
uncorrelated noise. This does not mean the effects are unimportant; it means
the minimal approximations are not good enough.

## Recommended Next Chat Order

1. Add production RGB shift to the split DCTL using the scalar-safe pattern.
2. Re-test cumulative `baseline + RGB shift`.
3. Add edge-masked softness, not global softness.
4. Rework halation/bloom as real bright-plate plus multi-radius taps; test
   lower strengths before adding to production.
5. Delay diffusion/vignette/grain until visual comparison is used alongside
   MAE/RMSE, because naive versions regress the A001 frame.

## Verification Commands Used

```sh
python3 /tmp/filmtone_dctl_effect_probe.py
```

The runner performs, per probe:

```sh
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-a001-v2-split-dctl-test

"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  /tmp/filmtone_export_resolve_split_still.lua
```

Then it normalizes the Resolve still to 1080x1920 RGB and computes MAE/RMSE
against the iOS frame and no-LUT frame.

## Current Repo State

The current implementation already includes package v2, source media sharing,
split pre/post LUT files, DCTL generation, and Resolve importer staging.

Do not claim full visual equivalence yet. Current best verified state is:

- baseline split compensated DCTL vs iOS: `MAE 19.042530`, `RMSE 27.116449`
- best minimal single effect probe, RGB shift: `MAE 18.960514`, `RMSE 26.957575`

