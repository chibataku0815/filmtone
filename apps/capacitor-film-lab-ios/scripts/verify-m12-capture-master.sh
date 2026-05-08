#!/usr/bin/env bash
# M12 / S12-F device verification helper.
#
# Validates the M11 master truth gate (codec=apch / colorspace=Apple Log 2 /
# fps=24 / pix_fmt=yuv422p10le / 3840x2160) and the M12 capture-package
# fields appropriate for a given run profile.  M12 must NOT change any of
# the master truth gate values regardless of which lens / exposure / WB
# combination the owner used.
#
# Usage:
#   ./scripts/verify-m12-capture-master.sh <profile> <package-dir>
#
# <profile> = wide-auto | wide-manual | tele-auto | ultraWide-auto
# <package-dir> = the captures/<id>/ folder containing master.mov +
#                 capture-package.json
#
# Run-type expectations (see docs/m12-s12f-runsheet.md):
#
#   wide-auto       lens=1× (Wide)        exposure=auto    WB=auto
#   wide-manual     lens=1× (Wide)        exposure=manual  WB=locked
#   tele-auto       lens=5×/2× (Tele)     exposure=auto    WB=auto
#   ultraWide-auto  lens=0.5× (UltraWide) exposure=auto    WB=auto
#
# Master truth (M10 baseline) is identical across profiles.  M12 fields are
# checked per profile.  No silent passes — every assertion is line-printed.

set -euo pipefail

if [ "${1-}" = "" ] || [ "${2-}" = "" ]; then
  echo "usage: $0 <profile> <package-dir>" >&2
  echo "  profile: wide-auto | wide-manual | tele-auto | ultraWide-auto" >&2
  exit 64
fi

PROFILE="$1"
PACKAGE_DIR="$2"
MASTER="$PACKAGE_DIR/master.mov"
JSON="$PACKAGE_DIR/capture-package.json"

case "$PROFILE" in
  wide-auto|wide-manual|tele-auto|ultraWide-auto) ;;
  *)
    echo "FAIL: unknown profile '$PROFILE'" >&2
    exit 64
    ;;
esac

if [ ! -d "$PACKAGE_DIR" ]; then
  echo "FAIL: package dir not found: $PACKAGE_DIR" >&2
  exit 1
fi
if [ ! -f "$MASTER" ]; then
  echo "FAIL: master.mov missing in $PACKAGE_DIR" >&2
  exit 1
fi
if [ ! -f "$JSON" ]; then
  echo "FAIL: capture-package.json missing in $PACKAGE_DIR" >&2
  exit 1
fi

echo "==> profile: $PROFILE"
echo "==> probing master: $MASTER"

PROBE_JSON="$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_tag_string,pix_fmt,width,height,r_frame_rate,color_space,color_transfer,color_primaries \
  -of json "$MASTER")"

echo "$PROBE_JSON"

CODEC_TAG="$(echo "$PROBE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["streams"][0].get("codec_tag_string",""))')"
PIX_FMT="$(echo   "$PROBE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["streams"][0].get("pix_fmt",""))')"
WIDTH="$(echo     "$PROBE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["streams"][0].get("width",0))')"
HEIGHT="$(echo    "$PROBE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["streams"][0].get("height",0))')"
RFR="$(echo       "$PROBE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["streams"][0].get("r_frame_rate",""))')"

FAIL=0
expect() {
  local label="$1"; local got="$2"; local want="$3"
  if [ "$got" = "$want" ]; then
    printf "  OK   %-22s = %s\n" "$label" "$got"
  else
    printf "  FAIL %-22s got=%s want=%s\n" "$label" "$got" "$want"
    FAIL=1
  fi
}
expect codec_tag    "$CODEC_TAG" "apch"
expect pix_fmt      "$PIX_FMT"   "yuv422p10le"
expect width        "$WIDTH"     "3840"
expect height       "$HEIGHT"    "2160"
expect frame_rate   "$RFR"       "24/1"

echo
echo "==> capture-package.json (M12 fields):"

PROFILE="$PROFILE" python3 - "$JSON" <<'PY'
import json, os, sys

with open(sys.argv[1]) as f:
    snap = json.load(f)
profile = os.environ["PROFILE"]
errs = []

def line(label, value):
    print(f"  {label} = {value!r}")

def ok(msg):
    print(f"  OK   {msg}")

def fail(msg):
    print(f"  FAIL {msg}")
    errs.append(msg)

# ---- master parameters (mirror of master truth in JSON) ----
for k in ("schemaVersion", "captureId",
          "parametersCodec", "parametersColorSpace",
          "parametersFrameRate", "parametersWidthPx", "parametersHeightPx",
          "parametersStabilization"):
    line(k, snap.get(k))

if snap.get("schemaVersion") != 2:
    fail(f"schemaVersion got={snap.get('schemaVersion')} want=2")
else:
    ok("schemaVersion = 2")

# ---- selected lens (S12-B / M12) ----
print()
print("  -- selectedLens --")
for k in ("lensIdentifier", "lensDisplayName", "lensDeviceType",
          "lensMagnificationLabel", "lensFormatIndex"):
    line(k, snap.get(k))

lens_required = ("lensIdentifier", "lensDisplayName", "lensDeviceType",
                 "lensMagnificationLabel", "lensFormatIndex")
if any(snap.get(k) is None for k in lens_required):
    fail("selectedLens incomplete (M12 requires all 5 lens fields)")
else:
    ok("selectedLens fields all present")

mag = snap.get("lensMagnificationLabel")
expected_mag = {
    "wide-auto": ("1×",),
    "wide-manual": ("1×",),
    "tele-auto": ("2×", "3×", "5×"),
    "ultraWide-auto": ("0.5×",),
}[profile]
if mag in expected_mag:
    ok(f"magnificationLabel {mag!r} matches profile {profile!r}")
else:
    fail(f"magnificationLabel {mag!r} not in {expected_mag} for profile {profile!r}")

device_type = snap.get("lensDeviceType") or ""
# Apple raw values: BuiltInWideAngleCamera / BuiltInUltraWideCamera /
# BuiltInTelephotoCamera.  Plain substring "Wide" matches both Wide
# and UltraWide, so we anchor on the disambiguating tokens.
def device_type_matches(profile: str, dt: str) -> bool:
    if profile in ("wide-auto", "wide-manual"):
        return ("WideAngle" in dt) and ("UltraWide" not in dt)
    if profile == "tele-auto":
        return "Telephoto" in dt
    if profile == "ultraWide-auto":
        return "UltraWide" in dt
    return False

if device_type_matches(profile, device_type):
    ok(f"lensDeviceType {device_type!r} matches profile {profile!r}")
else:
    fail(f"lensDeviceType {device_type!r} does not match profile {profile!r}")

# ---- exposure control (S12-C / S12-E) ----
print()
print("  -- exposureControl --")
for k in ("exposureMode", "exposureBiasEV",
          "focusPointNormalizedX", "focusPointNormalizedY",
          "meteringPointNormalizedX", "meteringPointNormalizedY",
          "manualISO", "manualShutterDurationSeconds",
          "manualInheritedFromAuto"):
    line(k, snap.get(k))

mode = snap.get("exposureMode")
want_mode = "manual" if profile == "wide-manual" else "auto"
if mode == want_mode:
    ok(f"exposureMode = {mode}")
else:
    fail(f"exposureMode got={mode!r} want={want_mode!r}")

if want_mode == "auto":
    # Auto: bias must be present (default 0.0 OK).  Manual fields must
    # all be nil — a stray manualISO etc. on an auto run means S12-E
    # gating regressed.
    if snap.get("exposureBiasEV") is None:
        fail("exposureBiasEV missing on auto run")
    else:
        ok(f"exposureBiasEV = {snap.get('exposureBiasEV')}")
    for k in ("manualISO", "manualShutterDurationSeconds",
              "manualInheritedFromAuto"):
        if snap.get(k) is not None:
            fail(f"{k} should be nil on auto run, got {snap.get(k)!r}")
        else:
            ok(f"{k} = nil (expected on auto)")
else:
    # Manual: ISO + shutter + inheritedFromAuto must all be present.
    # Bias is not meaningful on a setExposureModeCustom lock but the
    # field is still recorded (default 0.0).  Metering point must be
    # nil — tap-to-meter is auto-only.
    for k in ("manualISO", "manualShutterDurationSeconds",
             "manualInheritedFromAuto"):
        if snap.get(k) is None:
            fail(f"{k} missing on manual run")
        else:
            ok(f"{k} = {snap.get(k)}")
    iso = snap.get("manualISO") or 0
    shutter = snap.get("manualShutterDurationSeconds") or 0
    if shutter > 1.0 / 24.0 + 1e-6:
        fail(f"manualShutterDurationSeconds {shutter} exceeds 24fps cap (1/24s)")
    else:
        ok(f"manualShutterDurationSeconds within 24fps cap")
    for k in ("meteringPointNormalizedX", "meteringPointNormalizedY"):
        if snap.get(k) is not None:
            fail(f"{k} should be nil on manual run (tap-to-meter is auto-only)")

# ---- white balance (S12-D) ----
print()
print("  -- whiteBalance --")
for k in ("whiteBalanceMode",
          "whiteBalanceRedGain", "whiteBalanceGreenGain", "whiteBalanceBlueGain"):
    line(k, snap.get(k))

wb = snap.get("whiteBalanceMode")
want_wb = "locked" if profile == "wide-manual" else "auto"
if wb == want_wb:
    ok(f"whiteBalanceMode = {wb}")
else:
    fail(f"whiteBalanceMode got={wb!r} want={want_wb!r}")

if want_wb == "auto":
    # Auto WB: gains MUST be nil (S12-D decision — auto-state instantaneous
    # gains drift, persisting them is misleading).
    for k in ("whiteBalanceRedGain", "whiteBalanceGreenGain", "whiteBalanceBlueGain"):
        if snap.get(k) is not None:
            fail(f"{k} should be nil on auto-WB run, got {snap.get(k)!r}")
        else:
            ok(f"{k} = nil (expected on auto WB)")
else:
    # Locked WB: all three gains must be present and finite > 0.
    for k in ("whiteBalanceRedGain", "whiteBalanceGreenGain", "whiteBalanceBlueGain"):
        v = snap.get(k)
        if v is None:
            fail(f"{k} missing on locked-WB run")
        elif not (isinstance(v, (int, float)) and v > 0):
            fail(f"{k} not a positive finite number, got {v!r}")
        else:
            ok(f"{k} = {v}")

if errs:
    print()
    print(f"M12 PACKAGE GATE FAIL ({len(errs)} issue(s))")
    sys.exit(2)
else:
    print()
    print("M12 PACKAGE GATE PASS")
PY

if [ $FAIL -ne 0 ]; then
  echo
  echo "MASTER TRUTH GATE FAIL"
  exit 1
fi

echo
echo "S12-F GATE PASS — profile=$PROFILE"
