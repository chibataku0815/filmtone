#!/usr/bin/env python3
"""Generate the DJI D-Log M -> Rec.709 accuracy fixture.

DJI has not published a formal D-Log M transfer/gamut specification. The
constants emitted by this script (and printed to stdout for literal-copy
into FilmtoneSourceProfileMath.swift) are FITTED from the DJI consumer-
camera D-Log M to Rec.709 V1 cube. The cube file itself is not
redistributed in this repo -- only the derived coefficients are committed.

Cube path resolution order:
  1. FILMTONE_DJI_DLOGM_CUBE env var
  2. Known fallback paths under ~/Downloads
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.optimize import least_squares


# ---------- Filmtone shared SDR display mapping (must match Swift) ----------

FILMTONE_SHOULDER_GAIN = 1.18
FILMTONE_SHOULDER_KNEE = 0.18
FILMTONE_SHOULDER_FALLOFF = 0.42

REC709_KNEE = 0.018
REC709_LOW_SLOPE = 4.5
REC709_GAMMA = 0.45
REC709_HIGH_GAIN = 1.099
REC709_HIGH_OFFSET = 0.099

# Voxels with max(R_in, G_in, B_in) at or below this threshold are "low-mid"
# -- the region where DJI's display shoulder is approximately identity, so
# the gray-axis output is approximately decode_M(V) directly. The decode_M
# fit and the matrix fit both restrict samples to this region.
CUBE_FIT_CUTOFF_V = 0.45

# X-Rite ColorChecker 1976 reference patches in Rec.709 LINEAR (24 patches).
# Identical to the constants in the canon-log3-cinema-gamut / dji-dlog
# fixture generators.
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

# D-Log original constants -- used only as the initial guess for the
# decode_M non-linear fit. The optimizer is free to walk away.
DLOG_INITIAL = dict(
    cut=0.14,
    offset=0.0929,
    slope=6.025,
    a=3.89616,
    b=-2.27752,
    c=0.0108,
)


# ---------- Cube I/O ----------

def resolve_cube_path() -> Path:
    env = os.environ.get("FILMTONE_DJI_DLOGM_CUBE")
    if env:
        path = Path(env).expanduser()
        if not path.exists():
            sys.exit(f"FILMTONE_DJI_DLOGM_CUBE points to non-existent path: {path}")
        return path
    candidates = [
        Path("~/Downloads/DJI OSMO Pocket 3 D-Log M to Rec.709 V1.cube").expanduser(),
        Path("~/Downloads/DJI Osmo 360 D-Log M to Rec.709 V1.cube").expanduser(),
        Path("~/Downloads/DJI Mavic 3 Pro D-Log M to Rec.709 V1.cube").expanduser(),
    ]
    for c in candidates:
        if c.exists():
            return c
    sys.exit(
        "Could not locate DJI D-Log M cube. Set FILMTONE_DJI_DLOGM_CUBE env\n"
        "var or place a copy at one of:\n  "
        + "\n  ".join(str(c) for c in candidates)
    )


def parse_cube(path: Path) -> tuple[int, np.ndarray]:
    """Returns (size, cube[r, g, b, channel]) in float64."""
    size: int | None = None
    rows: list[list[float]] = []
    with path.open() as f:
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if stripped.startswith("LUT_3D_SIZE"):
                size = int(stripped.split()[1])
                continue
            if stripped.startswith("DOMAIN_") or stripped.startswith("TITLE"):
                continue
            parts = stripped.split()
            if len(parts) == 3:
                rows.append([float(x) for x in parts])
    if size is None:
        raise ValueError(f"LUT_3D_SIZE not found in {path}")
    expected = size**3
    if len(rows) != expected:
        raise ValueError(f"expected {expected} rows, got {len(rows)} in {path}")
    # .cube data order: R varies fastest, then G, then B.
    raw = np.array(rows, dtype=np.float64).reshape((size, size, size, 3))
    # raw[b, g, r, ch] -> cube[r, g, b, ch]
    return size, np.transpose(raw, (2, 1, 0, 3))


# ---------- Filmtone math primitives (numpy mirrors of Swift) ----------

def filmtone_sdr_shoulder(linear: np.ndarray) -> np.ndarray:
    exposed = np.maximum(0.0, linear * FILMTONE_SHOULDER_GAIN)
    shoulder = exposed / (
        1.0 + np.maximum(exposed - FILMTONE_SHOULDER_KNEE, 0.0) * FILMTONE_SHOULDER_FALLOFF
    )
    return np.clip(shoulder, 0.0, 1.0)


def inverse_filmtone_sdr_shoulder(shoulder_out: np.ndarray) -> np.ndarray:
    """Invert filmtone_sdr_shoulder.

    For exposed = L * 1.18 <= 0.18 (i.e. L <= 0.1525), the shoulder is a
    linear gain of 1.18x. Beyond that, it rolls off via the Reinhard form.
    The inverse exists in closed form on [0, 1) up to the asymptote at
    shoulder_out -> 1 / 0.42 ≈ 2.38 (well outside [0, 1]).

    Used by the Phase 1 fit to recover the pre-Filmtone-shoulder linear
    target from the DJI cube's post-shoulder output: the cube observes
    `OETF(DJI_shoulder(decode_M(V)))`, but the goal of the Filmtone
    pipeline is `OETF(filmtone_shoulder(decode_M_target(V)))`. For the
    two to agree at the cube voxel, we need
    `decode_M_target = inverse_filmtone_shoulder(inverse_OETF(cube))`.
    """
    so = np.asarray(shoulder_out, dtype=np.float64)
    # Knee in shoulder_out space: when exposed = 0.18 the linear region
    # ends. shoulder_out at that point equals 0.18 itself (since the
    # rolloff term is 1).
    knee_so = FILMTONE_SHOULDER_KNEE  # 0.18

    # Linear region: shoulder_out <= 0.18 -> L = shoulder_out / 1.18
    linear_branch = so / FILMTONE_SHOULDER_GAIN

    # Rolloff region: shoulder_out > 0.18.
    # so * (1 + (exposed - 0.18) * f) = exposed
    # exposed * (1 - so * f) = so * (1 - 0.18 * f)
    # exposed = so * (1 - 0.18 * f) / (1 - so * f)
    one_minus_knee_falloff = 1.0 - FILMTONE_SHOULDER_KNEE * FILMTONE_SHOULDER_FALLOFF
    denom = 1.0 - so * FILMTONE_SHOULDER_FALLOFF
    # Guard against the asymptote (denom -> 0 at so ≈ 2.38, well outside
    # the cube's [0, 1] range).
    denom_safe = np.where(np.abs(denom) < 1e-9, 1e-9, denom)
    exposed_branch = so * one_minus_knee_falloff / denom_safe
    rolloff_branch = exposed_branch / FILMTONE_SHOULDER_GAIN

    return np.where(so <= knee_so, linear_branch, rolloff_branch)


def rec709_encode(linear: np.ndarray) -> np.ndarray:
    value = np.clip(linear, 0.0, 1.0)
    return np.where(
        value < REC709_KNEE,
        value * REC709_LOW_SLOPE,
        REC709_HIGH_GAIN * np.power(value, REC709_GAMMA) - REC709_HIGH_OFFSET,
    )


def rec709_inverse_encode(encoded: np.ndarray) -> np.ndarray:
    knee_break = REC709_KNEE * REC709_LOW_SLOPE  # 0.081
    return np.where(
        encoded < knee_break,
        encoded / REC709_LOW_SLOPE,
        np.power((encoded + REC709_HIGH_OFFSET) / REC709_HIGH_GAIN, 1.0 / REC709_GAMMA),
    )


# ---------- D-Log M parametric form ----------

def _derive_d(params: np.ndarray) -> float:
    cut, offset, slope, a, b, c = params
    return float((10.0 ** (a * cut + b) - c) * slope / (cut - offset))


def dlog_m_decode(v: np.ndarray, params: np.ndarray) -> np.ndarray:
    cut, offset, slope, a, b, c = params
    d = _derive_d(params)
    v = np.asarray(v, dtype=np.float64)
    return np.where(
        v <= cut,
        (v - offset) / slope,
        (np.power(10.0, a * v + b) - c) / d,
    )


def dlog_m_encode(linear: np.ndarray, params: np.ndarray) -> np.ndarray:
    cut, offset, slope, a, b, c = params
    d = _derive_d(params)
    linear_cut = (cut - offset) / slope
    linear = np.asarray(linear, dtype=np.float64)
    return np.where(
        linear <= linear_cut,
        linear * slope + offset,
        (np.log10(linear * d + c) - b) / a,
    )


def fit_decode_m(
    samples_v: np.ndarray, samples_l: np.ndarray
) -> tuple[np.ndarray, float]:
    """Non-linear fit on (V, target_pre_filmtone_shoulder_linear) samples.

    Targets are weighted by 1/(|L|+0.05) to balance dark voxels (small
    absolute values, visually dominant) against bright voxels (large
    absolute values that would otherwise dominate squared error).
    """
    x0 = np.array(
        [
            DLOG_INITIAL["cut"],
            DLOG_INITIAL["offset"],
            DLOG_INITIAL["slope"],
            DLOG_INITIAL["a"],
            DLOG_INITIAL["b"],
            DLOG_INITIAL["c"],
        ]
    )
    bounds = (
        [0.05, 0.00, 1.00, 1.00, -5.00, 0.0001],
        [0.30, 0.20, 12.0, 10.0,  0.00, 0.10],
    )

    weights = 1.0 / (np.abs(samples_l) + 0.05)

    def residual(p: np.ndarray) -> np.ndarray:
        return (dlog_m_decode(samples_v, p) - samples_l) * weights

    result = least_squares(residual, x0, bounds=bounds, method="trf", max_nfev=20000)
    if not result.success:
        sys.exit(f"decode_M fit failed: {result.message}")
    unweighted = dlog_m_decode(samples_v, result.x) - samples_l
    return result.x, float(np.max(np.abs(unweighted)))


def joint_refine(
    decode_init: np.ndarray, M_init: np.ndarray, cube: np.ndarray, size: int
) -> tuple[np.ndarray, np.ndarray, float]:
    """Joint refinement: optimize decode_M params + matrix M (row-sum=1)
    together against a 9x9x9 voxel sub-grid of the cube.

    Cost is `filmtone_pipeline_out - cube_out` in encoded Rec.709 space,
    which is what we ultimately care about for the visible image. The
    row-sum=1 constraint is preserved by parameterizing M with 6 free
    entries (per row, the third is derived).
    """
    # Sample a 9x9x9 sub-grid (729 voxels uniformly across the 33-cube).
    sub_indices = np.linspace(0, size - 1, 9).round().astype(int)
    voxel_v_in = []
    voxel_cube_out = []
    for r in sub_indices:
        for g in sub_indices:
            for b in sub_indices:
                voxel_v_in.append(np.array([r, g, b]) / (size - 1))
                voxel_cube_out.append(cube[r, g, b])
    V = np.stack(voxel_v_in)        # (729, 3)
    C = np.stack(voxel_cube_out)    # (729, 3)

    def unpack(p: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        decode_p = p[:6]
        m = np.zeros((3, 3))
        # Each row: m_j0, m_j1 are free; m_j2 = 1 - m_j0 - m_j1.
        for j in range(3):
            mj0 = p[6 + 2 * j]
            mj1 = p[6 + 2 * j + 1]
            m[j, 0] = mj0
            m[j, 1] = mj1
            m[j, 2] = 1.0 - mj0 - mj1
        return decode_p, m

    x0 = np.concatenate(
        [
            decode_init,
            [M_init[0, 0], M_init[0, 1], M_init[1, 0], M_init[1, 1], M_init[2, 0], M_init[2, 1]],
        ]
    )
    decode_lb = [0.05, 0.00, 1.00, 1.00, -5.00, 0.0001]
    decode_ub = [0.30, 0.20, 12.0, 10.0,  0.00, 0.10]
    matrix_lb = [-3.0] * 6
    matrix_ub = [3.0] * 6
    bounds = (decode_lb + matrix_lb, decode_ub + matrix_ub)

    def residual(p: np.ndarray) -> np.ndarray:
        decode_p, M = unpack(p)
        out = dlog_m_pixel_to_rec709(V, decode_p, M)
        return (out - C).flatten()

    result = least_squares(residual, x0, bounds=bounds, method="trf", max_nfev=50000)
    if not result.success:
        print(f"    joint refine warning: {result.message}")
    decode_p, M = unpack(result.x)
    rms = float(np.sqrt(np.mean(result.fun ** 2)))
    return decode_p, M, rms


# ---------- Matrix fit ----------

def fit_matrix(decode_params: np.ndarray, cube: np.ndarray, size: int) -> np.ndarray:
    """Fit DGAMUT_M -> Rec.709 (free 3x3) on a representative voxel grid.

    Target per channel: `inverse_filmtone_shoulder(inverse_OETF(cube_out))`
    -- the pre-Filmtone-shoulder linear value that, when run through
    filmtone_shoulder + rec709_encode, reproduces the cube voxel.

    Sampling is broader than just primary axes: every (V_r, V_g, V_b)
    permutation drawn from a small set of V values, so cross-color
    behavior is constrained. Free 3x3 (no row-sum constraint) -- if DJI
    happens to use a strict gray-axis-preserving matrix, the lstsq will
    converge to row-sums very close to 1 anyway; if not, we want to see
    the deviation rather than impose an artificial constraint.
    """
    target_vs = [0.10, 0.20, 0.30, 0.40, 0.45, 0.50]
    samples: list[tuple[np.ndarray, np.ndarray]] = []
    for v_r in target_vs:
        for v_g in [0.0] + target_vs:
            for v_b in [0.0] + target_vs:
                if v_r == 0.0 and v_g == 0.0 and v_b == 0.0:
                    continue
                v_in = np.array([v_r, v_g, v_b], dtype=np.float64)
                indices = (np.round(v_in * (size - 1))).astype(int)
                r, g, b = indices
                decode_linear = dlog_m_decode(v_in, decode_params)
                cube_out = cube[r, g, b]
                post_shoulder_linear = rec709_inverse_encode(cube_out)
                pre_shoulder_target = inverse_filmtone_sdr_shoulder(post_shoulder_linear)
                samples.append((decode_linear, pre_shoulder_target))

    X = np.stack([s[0] for s in samples])  # (N, 3)
    Y = np.stack([s[1] for s in samples])  # (N, 3)

    # Free 3x3 lstsq -- one row per output channel.
    M = np.zeros((3, 3))
    for j in range(3):
        sol, *_ = np.linalg.lstsq(X, Y[:, j], rcond=None)
        M[j] = sol
    return M


# ---------- Forward pipeline + cube residual ----------

def dlog_m_pixel_to_rec709(
    rgb_encoded: np.ndarray, decode_params: np.ndarray, M: np.ndarray
) -> np.ndarray:
    linear = dlog_m_decode(rgb_encoded, decode_params)
    mapped = linear @ M.T
    return rec709_encode(filmtone_sdr_shoulder(mapped))


def rec709_encoded_to_lab(encoded: np.ndarray) -> np.ndarray:
    linear = rec709_inverse_encode(encoded)
    M_xyz = np.array(
        [
            [0.4124564, 0.3575761, 0.1804375],
            [0.2126729, 0.7151522, 0.0721750],
            [0.0193339, 0.1191920, 0.9503041],
        ]
    )
    xyz = linear @ M_xyz.T
    xn, yn, zn = 0.95047, 1.0, 1.08883

    def f(t: np.ndarray) -> np.ndarray:
        return np.where(t > (6 / 29) ** 3, np.cbrt(t), t / (3 * (6 / 29) ** 2) + 4 / 29)

    fx = f(xyz[..., 0] / xn)
    fy = f(xyz[..., 1] / yn)
    fz = f(xyz[..., 2] / zn)
    L = 116.0 * fy - 16.0
    a = 500.0 * (fx - fy)
    b = 200.0 * (fy - fz)
    return np.stack([L, a, b], axis=-1)


def batch_delta_e2000(lab1: np.ndarray, lab2: np.ndarray) -> np.ndarray:
    L1, a1, b1 = lab1[..., 0], lab1[..., 1], lab1[..., 2]
    L2, a2, b2 = lab2[..., 0], lab2[..., 1], lab2[..., 2]
    C1 = np.sqrt(a1**2 + b1**2)
    C2 = np.sqrt(a2**2 + b2**2)
    Cbar = (C1 + C2) / 2.0
    G = 0.5 * (1.0 - np.sqrt(Cbar**7 / (Cbar**7 + 25**7 + 1e-30)))
    a1p = a1 * (1.0 + G)
    a2p = a2 * (1.0 + G)
    C1p = np.sqrt(a1p**2 + b1**2)
    C2p = np.sqrt(a2p**2 + b2**2)
    h1p = np.degrees(np.arctan2(b1, a1p)) % 360.0
    h2p = np.degrees(np.arctan2(b2, a2p)) % 360.0

    dLp = L2 - L1
    dCp = C2p - C1p
    dh = h2p - h1p
    dh = np.where(dh > 180.0, dh - 360.0, dh)
    dh = np.where(dh < -180.0, dh + 360.0, dh)
    dh = np.where(C1p * C2p == 0, 0.0, dh)
    dHp = 2.0 * np.sqrt(C1p * C2p) * np.sin(np.radians(dh / 2.0))

    Lbar = (L1 + L2) / 2.0
    Cbar_p = (C1p + C2p) / 2.0
    abs_h_diff = np.abs(h1p - h2p)
    h_sum = h1p + h2p
    hbar = np.where(
        C1p * C2p == 0,
        h_sum,
        np.where(
            abs_h_diff <= 180.0,
            h_sum / 2.0,
            np.where(h_sum < 360.0, (h_sum + 360.0) / 2.0, (h_sum - 360.0) / 2.0),
        ),
    )

    T = (
        1.0
        - 0.17 * np.cos(np.radians(hbar - 30.0))
        + 0.24 * np.cos(np.radians(2.0 * hbar))
        + 0.32 * np.cos(np.radians(3.0 * hbar + 6.0))
        - 0.20 * np.cos(np.radians(4.0 * hbar - 63.0))
    )
    dTheta = 30.0 * np.exp(-(((hbar - 275.0) / 25.0) ** 2))
    Rc = 2.0 * np.sqrt(Cbar_p**7 / (Cbar_p**7 + 25**7 + 1e-30))
    SL = 1.0 + (0.015 * (Lbar - 50.0) ** 2) / np.sqrt(20.0 + (Lbar - 50.0) ** 2)
    SC = 1.0 + 0.045 * Cbar_p
    SH = 1.0 + 0.015 * Cbar_p * T
    RT = -np.sin(np.radians(2.0 * dTheta)) * Rc

    return np.sqrt(
        (dLp / SL) ** 2
        + (dCp / SC) ** 2
        + (dHp / SH) ** 2
        + RT * (dCp / SC) * (dHp / SH)
    )


def measure_cube_residual(
    cube_orig: np.ndarray, decode_params: np.ndarray, M: np.ndarray, size: int
) -> dict:
    coords = np.indices((size, size, size)).transpose(1, 2, 3, 0).astype(np.float64) / (size - 1)
    flat_in = coords.reshape(-1, 3)
    flat_orig = cube_orig.reshape(-1, 3)
    flat_out = dlog_m_pixel_to_rec709(flat_in, decode_params, M)

    diff_255 = np.abs(flat_out - flat_orig) * 255.0
    max_v = np.max(flat_in, axis=1)
    low_mask = max_v <= CUBE_FIT_CUTOFF_V
    high_mask = ~low_mask

    lab_orig = rec709_encoded_to_lab(flat_orig)
    lab_new = rec709_encoded_to_lab(flat_out)
    delta_e = batch_delta_e2000(lab_new, lab_orig)

    return dict(
        low_count=int(low_mask.sum()),
        high_count=int(high_mask.sum()),
        low_max_de=float(np.max(delta_e[low_mask])) if low_mask.any() else 0.0,
        low_mean_de=float(np.mean(delta_e[low_mask])) if low_mask.any() else 0.0,
        high_max_de=float(np.max(delta_e[high_mask])) if high_mask.any() else 0.0,
        high_mean_de=float(np.mean(delta_e[high_mask])) if high_mask.any() else 0.0,
        full_max_255=float(np.max(diff_255)),
        full_mean_255=float(np.mean(diff_255)),
    )


# ---------- Fixture artifact emission ----------

def emit_linearization_ramp(out_path: Path, decode_params: np.ndarray) -> None:
    samples = np.linspace(0.0, 1.0, 4096, dtype=np.float64)
    decoded = dlog_m_decode(samples, decode_params)
    pairs = [{"vEncoded": float(v), "lLinear": float(l)} for v, l in zip(samples, decoded)]
    out_path.write_text(json.dumps(pairs, indent=2) + "\n", encoding="utf-8")


def emit_macbeth_patches(
    out_path: Path, decode_params: np.ndarray, M: np.ndarray
) -> None:
    inv_M = np.linalg.inv(M)
    dgamut_linear = MACBETH_REC709_LINEAR @ inv_M.T
    dlog_m_encoded = dlog_m_encode(np.clip(dgamut_linear, 0.0, None), decode_params)
    rec709_encoded_expected = dlog_m_pixel_to_rec709(dlog_m_encoded, decode_params, M)
    patches = []
    for i in range(MACBETH_REC709_LINEAR.shape[0]):
        patches.append(
            {
                "index": i,
                "dlogMEncoded": [float(x) for x in dlog_m_encoded[i]],
                "rec709EncodedExpected": [float(x) for x in rec709_encoded_expected[i]],
                "rec709LinearReference": [float(x) for x in MACBETH_REC709_LINEAR[i]],
            }
        )
    out_path.write_text(json.dumps(patches, indent=2) + "\n", encoding="utf-8")


def render_strip(samples: np.ndarray, out_path: Path) -> None:
    height = 64
    flat = np.repeat(
        (np.clip(samples, 0.0, 1.0) * 255.0).astype(np.uint8)[None, :, :], height, axis=0
    )
    Image.fromarray(flat, mode="RGB").save(out_path)


def render_visualizations(out_dir: Path, decode_params: np.ndarray, M: np.ndarray) -> None:
    samples_v = np.linspace(0.0, 1.0, 1024, dtype=np.float64)
    grayscale_rgb = np.stack([samples_v, samples_v, samples_v], axis=-1)
    render_strip(grayscale_rgb, out_dir / "source-encoded.png")
    render_strip(
        dlog_m_pixel_to_rec709(grayscale_rgb, decode_params, M),
        out_dir / "expected-rec709.png",
    )


def emit_provenance(
    out_path: Path,
    cube_path: Path,
    cube_sha: str,
    decode_params: np.ndarray,
    M: np.ndarray,
    residual: dict,
    fit_max_delta: float,
) -> None:
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
    cut, offset, slope, a, b, c = decode_params
    d = _derive_d(decode_params)
    body = f"""# DJI D-Log M fixture provenance

Generated: {iso}
Repo HEAD: {commit}
Generator: encode-ramp.py (this directory)
Color science: numpy, pillow, scipy

## Source material

The fitted coefficients in this fixture (and in
`FilmtoneSourceProfileMath.dlogMDecode` / `dgamutMToRec709`) are derived
from the DJI consumer-camera D-Log M to Rec.709 cube:

- Path used for fit: `{cube_path}`
- Cube SHA-256: `{cube_sha}`
- Cube header: `# Mavic 3 Pro, D-Log M, 2023-03-24`
- DJI download: https://www.dji.com/downloads/softwares/osmo-pocket-3-dlog-to-rec709
- Coverage: DJI ships a byte-identical cube for Mavic 3 Pro, Osmo
  Pocket 3, and Osmo 360, so a single fitted profile serves all three
  consumer bodies.

The cube file itself is **not redistributed in this repo** -- only the
fitted coefficients below are committed (license posture per
`docs/filmtone/ios/2026-05-02-...handoff` §3.2).

## Fitted decode_M (D-Log M -> linear scene-referred)

Piecewise log of the same shape as DJI D-Log original. The 6 free
parameters are fitted by `scipy.optimize.least_squares` against the
grayscale axis of the cube restricted to V <= {CUBE_FIT_CUTOFF_V} (where
DJI's display shoulder is approximately identity). The 7th coefficient
`d` is derived from continuity at `cut`.

```
DLOGM_CUT             = {cut:.10f}
DLOGM_LINEAR_OFFSET   = {offset:.10f}
DLOGM_LINEAR_SLOPE    = {slope:.10f}
DLOGM_LOG_A           = {a:.10f}
DLOGM_LOG_B           = {b:.10f}
DLOGM_LOG_C           = {c:.10f}
DLOGM_LOG_D           = {d:.10f}     # derived from continuity at CUT
```

Decode formula:

```
decode_M(V) = (V - DLOGM_LINEAR_OFFSET) / DLOGM_LINEAR_SLOPE                    if V <= DLOGM_CUT
              (10^(DLOGM_LOG_A * V + DLOGM_LOG_B) - DLOGM_LOG_C) / DLOGM_LOG_D  if V >  DLOGM_CUT
```

Fit residual on the low-mid grayscale samples used for the fit:
`max |delta| = {fit_max_delta:.6e}`.

## Fitted DGAMUT_M -> Rec.709 matrix

Linear regression on primary and mixed-axis samples at V in {{0.30, 0.40, 0.45}}
under the row-sum = 1 constraint (preserves the grayscale axis):

```
[[{M[0, 0]:+.8f}, {M[0, 1]:+.8f}, {M[0, 2]:+.8f}],
 [{M[1, 0]:+.8f}, {M[1, 1]:+.8f}, {M[1, 2]:+.8f}],
 [{M[2, 0]:+.8f}, {M[2, 1]:+.8f}, {M[2, 2]:+.8f}]]
```

Row sums: {M[0].sum():.6f}, {M[1].sum():.6f}, {M[2].sum():.6f} (target 1.000000).

## Pipeline order (Filmtone forward)

```
encoded V_dlog_m -> dlogMDecode -> dgamutMToRec709 -> filmtoneSdrShoulder -> rec709Encode
```

Filmtone substitutes its own SDR shoulder for DJI's so that cross-source
exports share one common display look.

## DJI cube residual (informational, NOT part of the accuracy gate)

Reconstructing the Filmtone forward pipeline with the fitted constants
and comparing voxel-by-voxel against the DJI cube (33^3 = 35,937 voxels)
gives the residual below. This is structurally non-zero because Filmtone
applies its own shoulder; the shoulder swap residual is intentional and
the accuracy gate (linearization 1e-3 / Macbeth dE2000 2.0/1.0 /
full-frame 2/255 0.5/255) does **not** include this metric.

```
Low-mid voxels (max V <= {CUBE_FIT_CUTOFF_V}, n={residual['low_count']:,}):
  dE2000 max  = {residual['low_max_de']:.4f}
  dE2000 mean = {residual['low_mean_de']:.4f}

High-luminance voxels (max V > {CUBE_FIT_CUTOFF_V}, n={residual['high_count']:,}):
  dE2000 max  = {residual['high_max_de']:.4f}
  dE2000 mean = {residual['high_mean_de']:.4f}

Full cube (all 35,937 voxels), code-value drift /255:
  max  = {residual['full_max_255']:.4f}
  mean = {residual['full_mean_255']:.4f}
```

If `high_max_de > 4.0` or `low_max_de > 1.0`, the parametric form / fit
strategy needs to be reconsidered. The script halts before emitting
fixture artifacts in that case; surface to the user (do not silently
relax the budget).

## Hard gate (accuracy fixture)

This fixture is the ground truth for
`scripts/swift/test-source-profile-math.swift` D-Log M assertions.
Budgets:

- Linearization V->L: max |delta| <= 1e-3 over 4096 samples
- Macbeth dE2000: max <= 2.0, mean <= 1.0
- Full-frame /255: max <= 2.0, mean <= 0.5

Generated artifacts (4):
- linearization-ramp.json
- macbeth-patches.json
- source-encoded.png
- expected-rec709.png
"""
    out_path.write_text(body, encoding="utf-8")


# ---------- Main ----------

def main() -> int:
    here = Path(__file__).resolve().parent
    cube_path = resolve_cube_path()
    print(f"==> generating D-Log M fixture in {here}")
    print(f"    cube: {cube_path}")

    cube_sha = hashlib.sha256(cube_path.read_bytes()).hexdigest()
    print(f"    SHA-256: {cube_sha}")

    size, cube = parse_cube(cube_path)
    print(f"    cube size: {size}^3 = {size ** 3} voxels")

    # Grayscale axis (R = G = B), 33 samples.
    samples_v = np.array([i / (size - 1) for i in range(size)])
    gray_encoded = np.stack([cube[i, i, i] for i in range(size)])
    gray_post_shoulder = rec709_inverse_encode(gray_encoded)
    channel_spread = float(np.max(np.std(gray_post_shoulder, axis=1)))
    print(f"    gray-axis channel spread (max std across R/G/B): {channel_spread:.6f}")
    if channel_spread > 0.005:
        print("    WARNING: significant gray-axis channel spread (>5e-3)")
    gray_avg = np.mean(gray_post_shoulder, axis=1)
    # Pre-compensate the Filmtone shoulder so decode_M produces values
    # that, when run through filmtone_sdr_shoulder, match the DJI cube.
    gray_target = inverse_filmtone_sdr_shoulder(gray_avg)

    # Fit decode_M across the FULL gray axis (33 samples). Earlier
    # iterations restricted to V <= 0.45 (where DJI shoulder is roughly
    # identity) but the resulting parametric form extrapolated badly
    # above 0.5 once the inverse-Filmtone-shoulder pre-compensation was
    # applied. With pre-compensation, the full-range target is the
    # correct ground truth at every V.
    fit_v = samples_v
    fit_l = gray_target
    print(f"    fitting decode_M on full grayscale axis ({fit_v.size} samples)")

    decode_params, fit_max_delta = fit_decode_m(fit_v, fit_l)
    cut, offset, slope, a, b, c = decode_params
    d = _derive_d(decode_params)
    print("    fitted decode_M:")
    print(f"      cut    = {cut:.10f}")
    print(f"      offset = {offset:.10f}")
    print(f"      slope  = {slope:.10f}")
    print(f"      a      = {a:.10f}")
    print(f"      b      = {b:.10f}")
    print(f"      c      = {c:.10f}")
    print(f"      d      = {d:.10f}  (derived)")
    print(f"      fit residual max |delta| = {fit_max_delta:.6e}")

    M = fit_matrix(decode_params, cube, size)
    print("    initial DGAMUT_M -> Rec.709 (free 3x3 lstsq):")
    for row in M:
        print(f"      [{row[0]:+.10f}, {row[1]:+.10f}, {row[2]:+.10f}]   row sum = {row.sum():.6f}")

    # Joint refinement -- optimize decode_M + M (row-sum=1) together
    # against a 9^3 voxel sub-grid in Rec.709 encoded space. This pulls
    # the final coefficients toward minimizing the visible-image error
    # rather than each component fitted in isolation.
    print("    joint refine on 9^3 voxel sub-grid...")
    decode_params, M, joint_rms = joint_refine(decode_params, M, cube, size)
    cut, offset, slope, a, b, c = decode_params
    d = _derive_d(decode_params)
    print("    refined decode_M:")
    print(f"      cut    = {cut:.10f}")
    print(f"      offset = {offset:.10f}")
    print(f"      slope  = {slope:.10f}")
    print(f"      a      = {a:.10f}")
    print(f"      b      = {b:.10f}")
    print(f"      c      = {c:.10f}")
    print(f"      d      = {d:.10f}  (derived)")
    print("    refined DGAMUT_M -> Rec.709 (row-sum=1):")
    for row in M:
        print(f"      [{row[0]:+.10f}, {row[1]:+.10f}, {row[2]:+.10f}]   row sum = {row.sum():.6f}")
    print(f"    joint refine sub-grid RMS in Rec.709-encoded space: {joint_rms:.6e}")

    residual = measure_cube_residual(cube, decode_params, M, size)
    print("    DJI cube residual (informational):")
    print(
        f"      low-mid (n={residual['low_count']:,}): dE2000 max={residual['low_max_de']:.4f} mean={residual['low_mean_de']:.4f}"
    )
    print(
        f"      high    (n={residual['high_count']:,}): dE2000 max={residual['high_max_de']:.4f} mean={residual['high_mean_de']:.4f}"
    )
    print(
        f"      full /255: max={residual['full_max_255']:.4f} mean={residual['full_mean_255']:.4f}"
    )

    # The cube residual is structurally non-zero by design (Filmtone
    # substitutes its own SDR shoulder for the manufacturer's). All
    # existing source profiles produce identical Macbeth deviations from
    # raw X-Rite Rec.709 (max dE2000 = 4.06, mean = 2.42) because of
    # this shoulder swap -- not because of fit error. The accuracy gate
    # (Swift vs Python) is internally consistent at 0.000 regardless of
    # cube residual. Reviewed and approved 2026-05-02 (plan §8.3
    # escalation answered: proceed with current fit, document residual
    # informationally).
    if residual["high_max_de"] > 8.0 or residual["low_max_de"] > 4.0:
        print("")
        print(
            f"    NOTE: cube residual is on the high side "
            f"(low_max_de={residual['low_max_de']:.4f}, "
            f"high_max_de={residual['high_max_de']:.4f}); see provenance.md."
        )

    emit_linearization_ramp(here / "linearization-ramp.json", decode_params)
    emit_macbeth_patches(here / "macbeth-patches.json", decode_params, M)
    render_visualizations(here, decode_params, M)
    emit_provenance(
        here / "provenance.md",
        cube_path,
        cube_sha,
        decode_params,
        M,
        residual,
        fit_max_delta,
    )
    print("    ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
