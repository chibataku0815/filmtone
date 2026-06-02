#!/usr/bin/env python3
"""Generate the ARRI LogC3 + AWG3 -> Rec.709 accuracy fixture."""

from __future__ import annotations

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image

# ARRI LogC3 EI 800 exposure-value parameters from "ALEXA Log C Curve -
# Usage in VFX" (2017), table 5.
LOGC3_CUT = 0.010591
LOGC3_A = 5.555556
LOGC3_B = 0.052272
LOGC3_C = 0.247190
LOGC3_D = 0.385537
LOGC3_E = 5.367655
LOGC3_F = 0.092809

# Linear ARRI Wide Gamut 3 -> Rec.709 matrix from ARRI's LogC3 VFX guide.
AWG3_TO_REC709 = np.array(
    [
        [ 1.617523, -0.537287, -0.080237],
        [-0.070573,  1.334613, -0.264040],
        [-0.021102, -0.226954,  1.248056],
    ],
    dtype=np.float64,
)

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


def logc3_decode(v: np.ndarray) -> np.ndarray:
    threshold = LOGC3_E * LOGC3_CUT + LOGC3_F
    return np.where(
        v > threshold,
        (np.power(10.0, (v - LOGC3_D) / LOGC3_C) - LOGC3_B) / LOGC3_A,
        (v - LOGC3_F) / LOGC3_E,
    )


def logc3_encode(linear: np.ndarray) -> np.ndarray:
    return np.where(
        linear > LOGC3_CUT,
        LOGC3_C * np.log10(LOGC3_A * linear + LOGC3_B) + LOGC3_D,
        LOGC3_E * linear + LOGC3_F,
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


def logc3_pixel_to_rec709(rgb_encoded: np.ndarray) -> np.ndarray:
    linear = logc3_decode(rgb_encoded)
    mapped = linear @ AWG3_TO_REC709.T
    return rec709_encode(filmtone_sdr_shoulder(mapped))


def emit_linearization_ramp(out_path: Path) -> None:
    samples = np.linspace(0.0, 1.0, 4096, dtype=np.float64)
    decoded = logc3_decode(samples)
    pairs = [{"vEncoded": float(v), "lLinear": float(l)} for v, l in zip(samples, decoded)]
    out_path.write_text(json.dumps(pairs, indent=2) + "\n", encoding="utf-8")


def emit_macbeth_patches(out_path: Path) -> None:
    rec709_to_awg3 = np.linalg.inv(AWG3_TO_REC709)
    awg3_linear = MACBETH_REC709_LINEAR @ rec709_to_awg3.T
    logc3_encoded = logc3_encode(np.clip(awg3_linear, 0.0, None))
    rec709_encoded_expected = logc3_pixel_to_rec709(logc3_encoded)
    patches = []
    for i in range(MACBETH_REC709_LINEAR.shape[0]):
        patches.append(
            {
                "index": i,
                "logC3Encoded": [float(x) for x in logc3_encoded[i]],
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
    render_strip(logc3_pixel_to_rec709(grayscale_rgb), out_dir / "expected-rec709.png")


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
    body = f"""# ARRI LogC3 + AWG3 fixture provenance

Generated: {iso}
Repo HEAD: {commit}
Generator: encode-ramp.py (this directory)
Color science: numpy, pillow

## Spec citations

- ARRI, *ALEXA Log C Curve - Usage in VFX*, exposure-value LogC3 EI 800 parameters.
  https://www.arri.com/resource/blob/31918/66f56e6abb6e5b6553929edf9aa7483e/2017-03-alexa-logc-curve-in-vfx-data.pdf
- ARRI Log C learning docs.
  https://www.arri.com/en/learn-help/learn-help-camera-system/image-science/log-c
- ARRI LUT Generator.
  https://www.arri.com/en/learn-help/learn-help-camera-system/tools/lut-generator
- Panasonic LUMIX S1II ARRI LogC3 product note.
  https://www.panasonic.com/uk/consumer/cameras-camcorders/lumix-s-mirrorless-full-frame-cameras-learn/article/s1ii-videography.html
- ColorChecker reference patches: X-Rite 1976 chart constants.

## Transform

Filmtone normalizes ARRI LogC3 / ARRI Wide Gamut 3 into Rec.709 SDR:

1. Decode LogC3 with EI 800 exposure-value parameters.
2. Convert linear AWG3 to Rec.709 with ARRI's matrix.
3. Apply Filmtone SDR shoulder.
4. Apply the Rec.709 OETF.

This fixture does not emulate or bundle ARRI Classic 709 / K1S1 looks.

## Combined matrix (AWG3 -> Rec.709)

```
[[ 1.617523 -0.537287 -0.080237]
 [-0.070573  1.334613 -0.264040]
 [-0.021102 -0.226954  1.248056]]
```

## Hard gate

This fixture is the ground truth for
scripts/swift/test-source-profile-math.swift ARRI LogC3 + AWG3 assertions
(linearization 1e-3 max |Δ|, Macbeth ΔE2000 max 2.0 / mean 1.0,
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
    emit_linearization_ramp(here / "linearization-ramp.json")
    emit_macbeth_patches(here / "macbeth-patches.json")
    render_visualizations(here)
    emit_provenance(here / "provenance.md", generated_count=4)
    print(f"Generated ARRI LogC3 fixture in {here}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
