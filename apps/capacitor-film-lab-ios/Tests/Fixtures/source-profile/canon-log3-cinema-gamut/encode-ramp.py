#!/usr/bin/env python3
"""Generate the Canon Log 3 + Cinema Gamut -> Rec.709 accuracy fixture."""

from __future__ import annotations

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image

# Canon Log 3 v1.2 (Canon 2020 spec) constants. Cross-checked byte-for-byte
# against colour-science colour/models/rgb/transfer_functions/canon.py
# log_decoding_CanonLog3_v1_2 / log_encoding_CanonLog3_v1_2.
CLOG3_LOW_BREAK = 0.097465473
CLOG3_HIGH_BREAK = 0.15277891
CLOG3_LOG_SCALE = 0.36726845
CLOG3_LOG_GAIN = 14.98325
CLOG3_LINEAR_SLOPE = 1.9754798
CLOG3_LINEAR_OFFSET = 0.12512219
CLOG3_LOW_OFFSET = 0.12783901
CLOG3_HIGH_OFFSET = 0.12240537
CLOG3_REFLECTION_SCALE = 0.9

# Cinema Gamut RGB -> XYZ (D65), from the Antler Post Cinema Gamut reference.
CINEMA_GAMUT_TO_XYZ = np.array(
    [
        [ 0.71604965,  0.12968348,  0.10472280],
        [ 0.26126136,  0.86964215, -0.13090350],
        [-0.00967635, -0.23648164,  1.33521573],
    ],
    dtype=np.float64,
)

# XYZ -> Rec.709 (D65), ITU-R BT.709-6 / Bruce Lindbloom standard.
XYZ_TO_REC709 = np.array(
    [
        [ 3.2404542, -1.5371385, -0.4985314],
        [-0.9692660,  1.8760108,  0.0415560],
        [ 0.0556434, -0.2040259,  1.0572252],
    ],
    dtype=np.float64,
)

# Combined Cinema Gamut -> Rec.709. No chromatic adaptation needed because
# both spaces share D65 white. This matches the constants compiled into
# FilmtoneSourceProfileMath.cineGamutToRec709 — if the Antler Post matrix
# above is ever revised, the Swift side must be regenerated together.
CINEMA_GAMUT_TO_REC709 = XYZ_TO_REC709 @ CINEMA_GAMUT_TO_XYZ

FILMTONE_SHOULDER_GAIN = 1.18
FILMTONE_SHOULDER_KNEE = 0.18
FILMTONE_SHOULDER_FALLOFF = 0.42
REC709_KNEE = 0.018
REC709_LOW_SLOPE = 4.5
REC709_GAMMA = 0.45
REC709_HIGH_GAIN = 1.099
REC709_HIGH_OFFSET = 0.099

MACBETH_REC709_LINEAR = np.array(
    [
        [0.176, 0.090, 0.062],
        [0.575, 0.345, 0.272],
        [0.207, 0.292, 0.402],
        [0.108, 0.140, 0.060],
        [0.291, 0.283, 0.439],
        [0.296, 0.633, 0.563],
        [0.685, 0.244, 0.038],
        [0.099, 0.127, 0.408],
        [0.535, 0.137, 0.144],
        [0.094, 0.059, 0.139],
        [0.395, 0.518, 0.066],
        [0.769, 0.430, 0.022],
        [0.054, 0.083, 0.348],
        [0.117, 0.336, 0.090],
        [0.382, 0.041, 0.045],
        [0.860, 0.629, 0.013],
        [0.535, 0.117, 0.300],
        [0.038, 0.293, 0.412],
        [0.875, 0.873, 0.870],
        [0.572, 0.572, 0.572],
        [0.351, 0.351, 0.351],
        [0.183, 0.183, 0.183],
        [0.080, 0.080, 0.080],
        [0.030, 0.030, 0.030],
    ],
    dtype=np.float64,
)


def canon_log3_decode(v: np.ndarray) -> np.ndarray:
    scene = np.select(
        (v < CLOG3_LOW_BREAK, v <= CLOG3_HIGH_BREAK, v > CLOG3_HIGH_BREAK),
        (
            -(np.power(10.0, (CLOG3_LOW_OFFSET - v) / CLOG3_LOG_SCALE) - 1.0) / CLOG3_LOG_GAIN,
            (v - CLOG3_LINEAR_OFFSET) / CLOG3_LINEAR_SLOPE,
            (np.power(10.0, (v - CLOG3_HIGH_OFFSET) / CLOG3_LOG_SCALE) - 1.0) / CLOG3_LOG_GAIN,
        ),
    )
    return scene * CLOG3_REFLECTION_SCALE


def canon_log3_encode(linear: np.ndarray) -> np.ndarray:
    scene = linear / CLOG3_REFLECTION_SCALE
    # Encode-side break points expressed in scene linear, derived from the
    # decode break points: ±0.014 scene-linear equals encoded ≈ 0.097465473
    # / 0.15277891. The canon.py v1.2 implementation derives these by
    # inverse-decoding; we do the same numerically.
    low_scene = (CLOG3_LOW_BREAK - CLOG3_LINEAR_OFFSET) / CLOG3_LINEAR_SLOPE
    high_scene = (CLOG3_HIGH_BREAK - CLOG3_LINEAR_OFFSET) / CLOG3_LINEAR_SLOPE
    return np.select(
        (scene < low_scene, scene <= high_scene, scene > high_scene),
        (
            -CLOG3_LOG_SCALE * np.log10(-scene * CLOG3_LOG_GAIN + 1.0) + CLOG3_LOW_OFFSET,
            CLOG3_LINEAR_SLOPE * scene + CLOG3_LINEAR_OFFSET,
            CLOG3_LOG_SCALE * np.log10(scene * CLOG3_LOG_GAIN + 1.0) + CLOG3_HIGH_OFFSET,
        ),
    )


def filmtone_sdr_shoulder(linear: np.ndarray) -> np.ndarray:
    exposed = np.maximum(0.0, linear * FILMTONE_SHOULDER_GAIN)
    shoulder = exposed / (
        1.0 + np.maximum(exposed - FILMTONE_SHOULDER_KNEE, 0.0) * FILMTONE_SHOULDER_FALLOFF
    )
    return np.clip(shoulder, 0.0, 1.0)


def rec709_encode(linear: np.ndarray) -> np.ndarray:
    value = np.clip(linear, 0.0, 1.0)
    return np.where(
        value < REC709_KNEE,
        value * REC709_LOW_SLOPE,
        REC709_HIGH_GAIN * np.power(value, REC709_GAMMA) - REC709_HIGH_OFFSET,
    )


def clog3_pixel_to_rec709(rgb_encoded: np.ndarray) -> np.ndarray:
    linear = canon_log3_decode(rgb_encoded)
    mapped = linear @ CINEMA_GAMUT_TO_REC709.T
    return rec709_encode(filmtone_sdr_shoulder(mapped))


def emit_linearization_ramp(out_path: Path) -> None:
    samples = np.linspace(0.0, 1.0, 4096, dtype=np.float64)
    decoded = canon_log3_decode(samples)
    pairs = [{"vEncoded": float(v), "lLinear": float(l)} for v, l in zip(samples, decoded)]
    out_path.write_text(json.dumps(pairs, indent=2) + "\n", encoding="utf-8")


def emit_macbeth_patches(out_path: Path) -> None:
    rec709_to_cine = np.linalg.inv(CINEMA_GAMUT_TO_REC709)
    cine_linear = MACBETH_REC709_LINEAR @ rec709_to_cine.T
    clog3_encoded = canon_log3_encode(np.clip(cine_linear, 0.0, None))
    rec709_encoded_expected = clog3_pixel_to_rec709(clog3_encoded)
    patches = []
    for i in range(MACBETH_REC709_LINEAR.shape[0]):
        patches.append(
            {
                "index": i,
                "clog3Encoded": [float(x) for x in clog3_encoded[i]],
                "rec709EncodedExpected": [float(x) for x in rec709_encoded_expected[i]],
                "rec709LinearReference": [float(x) for x in MACBETH_REC709_LINEAR[i]],
            }
        )
    out_path.write_text(json.dumps(patches, indent=2) + "\n", encoding="utf-8")


def render_strip(samples: np.ndarray, out_path: Path) -> None:
    height = 64
    flat = np.repeat((np.clip(samples, 0.0, 1.0) * 255.0).astype(np.uint8)[None, :, :], height, axis=0)
    Image.fromarray(flat, mode="RGB").save(out_path)


def render_visualizations(out_dir: Path) -> None:
    samples_v = np.linspace(0.0, 1.0, 1024, dtype=np.float64)
    grayscale_rgb = np.stack([samples_v, samples_v, samples_v], axis=-1)
    render_strip(grayscale_rgb, out_dir / "source-encoded.png")
    render_strip(clog3_pixel_to_rec709(grayscale_rgb), out_dir / "expected-rec709.png")


def emit_provenance(out_path: Path, generated_count: int) -> None:
    try:
        commit = (
            subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=str(out_path.parent), stderr=subprocess.DEVNULL)
            .decode()
            .strip()
        )
    except Exception:
        commit = "(not a git repo or git unavailable)"
    iso = datetime.now(timezone.utc).isoformat(timespec="seconds")
    body = f"""# Canon Log 3 + Cinema Gamut fixture provenance

Generated: {iso}
Repo HEAD: {commit}
Generator: encode-ramp.py (this directory)
Color science: numpy, pillow

## Spec citations

- Canon, *White Paper Canon Log Gamma Curves*.
  https://www.usa.canon.com/content/dam/canon-assets/white-papers/pro/white-paper-canon-log-gamma-curves.pdf
- Colour Science Canon Log 3 v1.2 (Canon 2020) reference implementation:
  https://github.com/colour-science/colour/blob/develop/colour/models/rgb/transfer_functions/canon.py
- Antler Post Cinema Gamut colour space reference (RGB->XYZ matrix):
  https://antlerpost.com/colour-spaces/CinemaGamut.html
- ITU-R BT.709-6 (XYZ->Rec.709 matrix at D65).
- ColorChecker reference patches: X-Rite 1976 chart constants.

## Combined matrix (Cinema Gamut -> Rec.709, D65 -> D65, no CAT)

```
[[ 1.92355517 -0.79863353 -0.12508072]
 [-0.20431556  1.49593305 -0.29159440]
 [-0.02369073 -0.42022784  1.44415855]]
```

Computed as `XYZ_TO_REC709 @ CINEMA_GAMUT_TO_XYZ`. Sanity:
`(1,1,1)_CinemaGamut -> (~1, ~1, ~1)_Rec709` because both share D65 white.

## Hard gate

This fixture is the ground truth for
scripts/swift/test-source-profile-math.swift Canon Log 3 + Cinema Gamut
assertions (linearization 1e-3 max |Δ|, Macbeth ΔE2000 max 2.0 / mean 1.0,
full-frame max 2/255 / mean 0.5/255).

Generated artifacts ({generated_count}):
- linearization-ramp.json
- macbeth-patches.json
- source-encoded.png
- expected-rec709.png
"""
    out_path.write_text(body, encoding="utf-8")


def main() -> int:
    here = Path(__file__).resolve().parent
    print(f"==> generating Canon Log 3 + Cinema Gamut fixture in {here}")
    emit_linearization_ramp(here / "linearization-ramp.json")
    emit_macbeth_patches(here / "macbeth-patches.json")
    render_visualizations(here)
    emit_provenance(here / "provenance.md", generated_count=4)
    print("    ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
