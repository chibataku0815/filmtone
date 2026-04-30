#!/usr/bin/env python3
"""Generate the S-Log3 -> Rec.709 accuracy fixture (Camera Profiles Phase C).

Mirrors the V-Log fixture generator under panasonic-vlog/. See
docs/source-profile-math/sony-slog3.md for the spec citation and
constants. Constants and matrices are transcribed independently of the
Swift implementation so the resulting fixture cross-verifies the math.

Run: bun run gen:fixtures:slog3 (from apps/capacitor-film-lab-ios/).
"""

from __future__ import annotations

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image

# Sony S-Log3 / S-Gamut3.Cine reference. Constants from Sony's
# *Technical Summary for S-Gamut3.Cine/S-Log3 and S-Gamut3/S-Log3*.
# Verified mirror: https://antlerpost.com/colour-spaces/SLog3.html
SLOG3_THRESHOLD = 171.2102946929 / 1023.0

SGAMUT3_CINE_TO_REC709 = np.array(
    [
        [ 1.6269, -0.5365, -0.0904],
        [-0.1078,  1.1628, -0.0550],
        [-0.0140, -0.0240,  1.0379],
    ],
    dtype=np.float64,
)

# Filmtone SDR shoulder + Rec.709 OETF — transcribed independently of
# Swift FilmtoneSourceProfileMath. Values are byte-identical to the V-Log
# fixture generator (cross-curve display mapping is shared SSOT).
FILMTONE_SHOULDER_GAIN = 1.18
FILMTONE_SHOULDER_KNEE = 0.18
FILMTONE_SHOULDER_FALLOFF = 0.42
REC709_KNEE = 0.018
REC709_LOW_SLOPE = 4.5
REC709_GAMMA = 0.45
REC709_HIGH_GAIN = 1.099
REC709_HIGH_OFFSET = 0.099


def slog3_decode(v: np.ndarray) -> np.ndarray:
    """S-Log3 -> linear scene-referred decoder."""
    return np.where(
        v < SLOG3_THRESHOLD,
        ((v * 1023.0 - 95.0) * 0.01125) / (171.2102946929 - 95.0),
        np.power(10.0, (v * 1023.0 - 420.0) / 261.5) * (0.18 + 0.01) - 0.01,
    )


def slog3_encode(linear: np.ndarray) -> np.ndarray:
    """linear -> S-Log3 (inverse of slog3_decode). Used to synthesize
    S-Log3 source from a Rec.709 reference patch via S-Gamut3.Cine."""
    threshold_linear = ((SLOG3_THRESHOLD * 1023.0 - 95.0) * 0.01125) / (171.2102946929 - 95.0)
    safe = np.maximum(linear, -0.01 + 1e-9)  # avoid log10(0) on the boundary
    return np.where(
        linear < threshold_linear,
        ((linear * (171.2102946929 - 95.0) / 0.01125) + 95.0) / 1023.0,
        (np.log10((safe + 0.01) / (0.18 + 0.01)) * 261.5 + 420.0) / 1023.0,
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


def slog3_pixel_to_rec709(rgb_encoded: np.ndarray) -> np.ndarray:
    """End-to-end pipeline: S-Log3 -> linear -> S-Gamut3.Cine->Rec.709 ->
    Filmtone shoulder -> Rec.709 OETF."""
    linear = slog3_decode(rgb_encoded)
    mapped = linear @ SGAMUT3_CINE_TO_REC709.T
    shouldered = filmtone_sdr_shoulder(mapped)
    return rec709_encode(shouldered)


def rec709_to_sgamut3_cine() -> np.ndarray:
    return np.linalg.inv(SGAMUT3_CINE_TO_REC709)


# Same X-Rite Macbeth Rec.709 linear reference used by panasonic-vlog/.
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


def emit_linearization_ramp(out_path: Path) -> None:
    samples = np.linspace(0.0, 1.0, 4096, dtype=np.float64)
    decoded = slog3_decode(samples)
    pairs = [
        {"vEncoded": float(v), "lLinear": float(l)}
        for v, l in zip(samples, decoded)
    ]
    out_path.write_text(json.dumps(pairs, indent=2) + "\n", encoding="utf-8")


def emit_macbeth_patches(out_path: Path) -> None:
    rec709_to_sgamut = rec709_to_sgamut3_cine()
    sgamut_linear = MACBETH_REC709_LINEAR @ rec709_to_sgamut.T
    slog3_encoded = slog3_encode(np.clip(sgamut_linear, 0.0, None))
    rec709_encoded_expected = slog3_pixel_to_rec709(slog3_encoded)
    patches = []
    for i in range(MACBETH_REC709_LINEAR.shape[0]):
        patches.append(
            {
                "index": i,
                "slog3Encoded": [float(x) for x in slog3_encoded[i]],
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
    render_strip(slog3_pixel_to_rec709(grayscale_rgb), out_dir / "expected-rec709.png")


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
    body = f"""# Sony S-Log3 / S-Gamut3.Cine fixture provenance

Generated: {iso}
Repo HEAD: {commit}
Generator: encode-ramp.py (this directory)
Color science: colour-science (BSD-3-Clause), numpy, pillow

## Spec citations

- Sony, *Technical Summary for S-Gamut3.Cine/S-Log3 and S-Gamut3/S-Log3*.
  https://pro.sony/s3/cms-static-content/uploadfile/06/1237494271406.pdf
- Verified mirror (constants match): https://antlerpost.com/colour-spaces/SLog3.html
- ColorChecker reference patches: X-Rite 1976 chart constants
  (https://en.wikipedia.org/wiki/ColorChecker — public-domain math
  reference, not the X-Rite product image).

## Hard gate

This fixture is the ground truth for
scripts/swift/test-source-profile-math.swift S-Log3 assertions. Drift
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
    print(f"==> generating S-Log3 fixture in {here}")
    emit_linearization_ramp(here / "linearization-ramp.json")
    emit_macbeth_patches(here / "macbeth-patches.json")
    render_visualizations(here)
    emit_provenance(here / "provenance.md", generated_count=4)
    print("    ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
