#!/usr/bin/env python3
"""Generate the Canon C-Log -> Rec.709 accuracy fixture."""

from __future__ import annotations

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image

CANON_LOG_PIVOT = 0.0730597
CANON_LOG_SCALE = 0.529136
CANON_LOG_GAIN = 10.1596
CANON_REFLECTION_SCALE = 0.9

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


def canon_log_decode(v: np.ndarray) -> np.ndarray:
    linear = np.where(
        v < CANON_LOG_PIVOT,
        -(np.power(10.0, (CANON_LOG_PIVOT - v) / CANON_LOG_SCALE) - 1.0) / CANON_LOG_GAIN,
        (np.power(10.0, (v - CANON_LOG_PIVOT) / CANON_LOG_SCALE) - 1.0) / CANON_LOG_GAIN,
    )
    return linear * CANON_REFLECTION_SCALE


def canon_log_encode(linear: np.ndarray) -> np.ndarray:
    scene = linear / CANON_REFLECTION_SCALE
    encoded = np.empty_like(scene)
    negative = scene < 0.0
    encoded[negative] = -(
        CANON_LOG_SCALE * np.log10(-scene[negative] * CANON_LOG_GAIN + 1.0) - CANON_LOG_PIVOT
    )
    encoded[~negative] = CANON_LOG_SCALE * np.log10(scene[~negative] * CANON_LOG_GAIN + 1.0) + CANON_LOG_PIVOT
    return encoded


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


def clog_pixel_to_rec709(rgb_encoded: np.ndarray) -> np.ndarray:
    linear = canon_log_decode(rgb_encoded)
    return rec709_encode(filmtone_sdr_shoulder(linear))


def emit_linearization_ramp(out_path: Path) -> None:
    samples = np.linspace(0.0, 1.0, 4096, dtype=np.float64)
    decoded = canon_log_decode(samples)
    pairs = [{"vEncoded": float(v), "lLinear": float(l)} for v, l in zip(samples, decoded)]
    out_path.write_text(json.dumps(pairs, indent=2) + "\n", encoding="utf-8")


def emit_macbeth_patches(out_path: Path) -> None:
    clog_encoded = canon_log_encode(np.clip(MACBETH_REC709_LINEAR, 0.0, None))
    rec709_encoded_expected = clog_pixel_to_rec709(clog_encoded)
    patches = []
    for i in range(MACBETH_REC709_LINEAR.shape[0]):
        patches.append(
            {
                "index": i,
                "clogEncoded": [float(x) for x in clog_encoded[i]],
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
    render_strip(clog_pixel_to_rec709(grayscale_rgb), out_dir / "expected-rec709.png")


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
    body = f"""# Canon C-Log fixture provenance

Generated: {iso}
Repo HEAD: {commit}
Generator: encode-ramp.py (this directory)
Color science: numpy, pillow

## Spec citations

- Canon, *Canon-Log Transfer Characteristic*, June 20, 2012.
  https://downloads.canon.com/CDLC/Canon-Log_Transfer_Characteristic_6-20-2012.pdf
- Colour Science Canon Log transfer function reference:
  https://colour.readthedocs.io/en/v0.3.12/_modules/colour/models/rgb/transfer_functions/canon_log.html
- ColorChecker reference patches: X-Rite 1976 chart constants.

## Hard gate

This fixture is the ground truth for
scripts/swift/test-source-profile-math.swift C-Log assertions.

Generated artifacts ({generated_count}):
- linearization-ramp.json
- macbeth-patches.json
- source-encoded.png
- expected-rec709.png
"""
    out_path.write_text(body, encoding="utf-8")


def main() -> int:
    here = Path(__file__).resolve().parent
    print(f"==> generating C-Log fixture in {here}")
    emit_linearization_ramp(here / "linearization-ramp.json")
    emit_macbeth_patches(here / "macbeth-patches.json")
    render_visualizations(here)
    emit_provenance(here / "provenance.md", generated_count=4)
    print("    ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
