#!/usr/bin/env python3
"""Generate the V-Log -> Rec.709 accuracy fixture (Camera Profiles Phase B-2).

Independence rule: this script must NOT call into Filmtone's Swift
implementation. Constants come from manufacturer reference docs (see
docs/source-profile-math/panasonic-vlog.md). Macbeth ColorChecker
reference values come from X-Rite published constants. The fixture this
script produces is the "ground truth" the Swift `vlogDecode` /
`vlogPixelToRec709` are tested against.

Run via `bun run gen:fixtures:vlog` (which invokes `uv run` so colour-
science is fetched on demand and no local venv is needed).

Outputs (relative to this script's directory):

    linearization-ramp.json   4096 (V_encoded, L_linear) pairs
    macbeth-patches.json      24 (RGB encoded, RGB Rec.709) tuples
    source-encoded.png        Visual: ramp + Macbeth patches as PNG
    expected-rec709.png       Visual: post-pipeline expected output
    provenance.md             Generation log (already committed; updated here)

The Filmtone SDR shoulder is applied identically to the Swift side
(transcribed once, not delegated). The match between this Python and the
Swift implementation is what the accuracy test verifies.
"""

from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import numpy as np
from PIL import Image

# Panasonic V-Log Reference Manual (2014-11-28). Constants are from §A,
# verified against the Antler Post mirror at:
#   https://antlerpost.com/colour-spaces/VGamut.html
VLOG_CUT2 = 0.181
VLOG_B = 0.00873
VLOG_C = 0.241514
VLOG_D = 0.598206

# V-Gamut -> Rec.709 (D65 -> D65, no chromatic adaptation). This is the
# product of (V-Gamut -> XYZ) and (XYZ -> Rec.709 standard). Values are
# also published verbatim by Antler Post and reproduced in
# docs/source-profile-math/panasonic-vlog.md.
VGAMUT_TO_REC709 = np.array(
    [
        [ 1.7398, -0.6727, -0.0671],
        [-0.1956,  1.2473, -0.0518],
        [-0.0114, -0.0440,  1.0554],
    ],
    dtype=np.float64,
)

# Filmtone SDR display shoulder + Rec.709 OETF. Transcribed independently
# of the Swift side (FilmtoneSourceProfileMath.filmtoneSdrShoulder /
# rec709Encode) — divergence here would surface as accuracy drift in the
# Swift test, which is exactly the cross-check we want.
FILMTONE_SHOULDER_GAIN = 1.18
FILMTONE_SHOULDER_KNEE = 0.18
FILMTONE_SHOULDER_FALLOFF = 0.42
REC709_KNEE = 0.018
REC709_LOW_SLOPE = 4.5
REC709_GAMMA = 0.45
REC709_HIGH_GAIN = 1.099
REC709_HIGH_OFFSET = 0.099


def vlog_decode(v: np.ndarray) -> np.ndarray:
    """V-Log -> linear scene-referred decoder (manufacturer §A)."""
    out = np.where(
        v < VLOG_CUT2,
        (v - 0.125) / 5.6,
        np.power(10.0, (v - VLOG_D) / VLOG_C) - VLOG_B,
    )
    return out


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


def vlog_pixel_to_rec709(rgb_encoded: np.ndarray) -> np.ndarray:
    """End-to-end pipeline: V-Log -> linear -> V-Gamut->Rec.709 -> shoulder -> encode."""
    linear = vlog_decode(rgb_encoded)
    mapped = linear @ VGAMUT_TO_REC709.T  # (..., 3) @ (3, 3) -> (..., 3)
    shouldered = filmtone_sdr_shoulder(mapped)
    return rec709_encode(shouldered)


# X-Rite ColorChecker (24 patches). Linear sRGB / Rec.709 reference values
# from https://en.wikipedia.org/wiki/ColorChecker (which transcribes
# X-Rite's published 1976 chart). The values here are scene-linear (after
# inverse Rec.709 OETF), not gamma-encoded — so we re-encode them to V-Log
# / V-Gamut for the synthetic source patch and re-encode to Rec.709 for the
# expected output. This avoids tying the fixture to any specific display
# rendering intent beyond the documented Filmtone SDR shoulder.
MACBETH_REC709_LINEAR = np.array(
    [
        # Row 1: natural / skin tones
        [0.176, 0.090, 0.062],  # Dark skin
        [0.575, 0.345, 0.272],  # Light skin
        [0.207, 0.292, 0.402],  # Blue sky
        [0.108, 0.140, 0.060],  # Foliage
        [0.291, 0.283, 0.439],  # Blue flower
        [0.296, 0.633, 0.563],  # Bluish green
        # Row 2: miscellaneous
        [0.685, 0.244, 0.038],  # Orange
        [0.099, 0.127, 0.408],  # Purplish blue
        [0.535, 0.137, 0.144],  # Moderate red
        [0.094, 0.059, 0.139],  # Purple
        [0.395, 0.518, 0.066],  # Yellow green
        [0.769, 0.430, 0.022],  # Orange yellow
        # Row 3: primary / secondary
        [0.054, 0.083, 0.348],  # Blue
        [0.117, 0.336, 0.090],  # Green
        [0.382, 0.041, 0.045],  # Red
        [0.860, 0.629, 0.013],  # Yellow
        [0.535, 0.117, 0.300],  # Magenta
        [0.038, 0.293, 0.412],  # Cyan
        # Row 4: greyscale
        [0.875, 0.873, 0.870],  # White
        [0.572, 0.572, 0.572],  # Neutral 8
        [0.351, 0.351, 0.351],  # Neutral 6.5
        [0.183, 0.183, 0.183],  # Neutral 5
        [0.080, 0.080, 0.080],  # Neutral 3.5
        [0.030, 0.030, 0.030],  # Black
    ],
    dtype=np.float64,
)


def vlog_encode(linear: np.ndarray) -> np.ndarray:
    """linear -> V-Log encoded (inverse of vlog_decode). Used to generate the
    synthetic V-Log source from the X-Rite Rec.709 reference."""
    out = np.where(
        linear < VLOG_B,
        np.where(
            linear < -0.0125,
            -1.0,  # below valid range -> sentinel
            5.6 * linear + 0.125,
        ),
        VLOG_C * np.log10(linear + VLOG_B) + VLOG_D,
    )
    return out


def rec709_to_vgamut() -> np.ndarray:
    """Rec.709 -> V-Gamut, used to synthesize V-Log source from Rec.709 patches."""
    return np.linalg.inv(VGAMUT_TO_REC709)


def emit_linearization_ramp(out_path: Path) -> None:
    samples = np.linspace(0.0, 1.0, 4096, dtype=np.float64)
    decoded = vlog_decode(samples)
    pairs = [
        {"vEncoded": float(v), "lLinear": float(l)}
        for v, l in zip(samples, decoded)
    ]
    out_path.write_text(json.dumps(pairs, indent=2) + "\n", encoding="utf-8")


def emit_macbeth_patches(out_path: Path) -> None:
    """Run the X-Rite Macbeth Rec.709 reference patches through the FULL
    V-Log -> Rec.709 pipeline (including the Filmtone SDR shoulder) and
    record the result as the expected output. The Swift accuracy test
    asserts agreement with this pipeline output — it is NOT a comparison
    against the bare X-Rite linear reference, which would inevitably drift
    once the shoulder is applied. This is the cross-language verification
    point: Python's transcription of the math against Swift's transcription.
    """
    rec709_to_vgamut_matrix = rec709_to_vgamut()
    vgamut_linear = MACBETH_REC709_LINEAR @ rec709_to_vgamut_matrix.T
    vlog_encoded = vlog_encode(np.clip(vgamut_linear, 0.0, None))
    # End-to-end pipeline: V-Log encoded -> linear -> matrix -> shoulder ->
    # Rec.709 OETF. This is the gold ground truth for the Swift comparison.
    rec709_encoded_expected = vlog_pixel_to_rec709(vlog_encoded)
    patches = []
    for i in range(MACBETH_REC709_LINEAR.shape[0]):
        patches.append(
            {
                "index": i,
                "vlogEncoded": [float(x) for x in vlog_encoded[i]],
                "rec709EncodedExpected": [float(x) for x in rec709_encoded_expected[i]],
                # Bare X-Rite Rec.709 linear reference, retained for
                # diagnostics — not a budget gate input.
                "rec709LinearReference": [float(x) for x in MACBETH_REC709_LINEAR[i]],
            }
        )
    out_path.write_text(json.dumps(patches, indent=2) + "\n", encoding="utf-8")


def render_strip(samples: np.ndarray, out_path: Path) -> None:
    """Render a 1D ramp + Macbeth grid as a small PNG strip."""
    height = 64
    width = samples.shape[0]
    flat = np.repeat((np.clip(samples, 0.0, 1.0) * 255.0).astype(np.uint8)[None, :, :], height, axis=0)
    Image.fromarray(flat, mode="RGB").save(out_path)


def render_visualizations(out_dir: Path) -> None:
    samples_v = np.linspace(0.0, 1.0, 1024, dtype=np.float64)
    grayscale_rgb = np.stack([samples_v, samples_v, samples_v], axis=-1)
    source_strip = grayscale_rgb  # the V-Log encoded ramp itself (gray axis)
    expected_strip = vlog_pixel_to_rec709(grayscale_rgb)
    render_strip(source_strip, out_dir / "source-encoded.png")
    render_strip(expected_strip, out_dir / "expected-rec709.png")


def emit_provenance(out_path: Path, generated_count: int) -> None:
    try:
        commit = (
            subprocess.check_output(
                ["git", "rev-parse", "HEAD"],
                cwd=str(out_path.parent),
                stderr=subprocess.DEVNULL,
            )
            .decode()
            .strip()
        )
    except Exception:
        commit = "(not a git repo or git unavailable)"
    iso = datetime.now(timezone.utc).isoformat(timespec="seconds")
    body = f"""# Panasonic V-Log fixture provenance

Generated: {iso}
Repo HEAD: {commit}
Generator: encode-ramp.py (this directory)
Color science: colour-science (BSD-3-Clause), numpy, pillow

## Spec citations

- Panasonic, *V-Log/V-Gamut REFERENCE MANUAL*, November 28, 2014.
  https://pro-av.panasonic.net/en/cinema_camera_varicam_eva/support/pdf/VARICAM_V-Log_V-Gamut.pdf
- Verified mirror (constants match): https://antlerpost.com/colour-spaces/VGamut.html
- ColorChecker reference patches (X-Rite 1976 chart, transcribed at
  https://en.wikipedia.org/wiki/ColorChecker — public-domain mathematical
  reference, not the X-Rite product image).

## Hard gate

This fixture is the ground truth the Swift accuracy test
(scripts/swift/test-source-profile-math.swift) compares against. Drift
beyond the D-CP5 budget MUST fail the build:

- linearization: max |Δ| ≤ 1e-3 over 4096-point ramp
- Macbeth ΔE2000: max ≤ 2.0, mean ≤ 1.0
- full-frame: max ≤ 2/255, mean ≤ 0.5/255
- edge cases (V<0.05 or V>0.95): max ≤ 4/255 (mean only)

Generated artifacts ({generated_count}):
- linearization-ramp.json
- macbeth-patches.json
- source-encoded.png
- expected-rec709.png
"""
    out_path.write_text(body, encoding="utf-8")


def main() -> int:
    here = Path(__file__).resolve().parent
    print(f"==> generating V-Log fixture in {here}")
    emit_linearization_ramp(here / "linearization-ramp.json")
    emit_macbeth_patches(here / "macbeth-patches.json")
    render_visualizations(here)
    emit_provenance(here / "provenance.md", generated_count=4)
    print("    ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
