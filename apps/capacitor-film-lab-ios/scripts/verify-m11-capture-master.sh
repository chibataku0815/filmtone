#!/usr/bin/env bash
# M11 / S11-F device verification helper.
#
# Validates two artifacts produced by a Filmtone iOS capture run with a
# capture-time Look chip selected:
#
#   1. master.mov   — must match the M10 baseline truth gate
#                     (codec=apch / colorspace=Apple Log 2 / fps=24 /
#                      pix_fmt=yuv422p10le / 3840x2160).  M11 must NOT
#                     change any of these.
#   2. capture-package.json — must carry schemaVersion=2 and (for
#                     Stone / Urban runs) the four selectedLook* fields.
#                     Filmtone (default chip) runs must have all four
#                     selectedLook* fields nil/missing.
#
# Usage:
#   ./scripts/verify-m11-capture-master.sh <package-dir>
#
# `<package-dir>` is the `Caches/Filmtone/captures/<id>/` directory
# (or the SSD-side mirror) containing master.mov + proxy.mov +
# capture-package.json.  Pull it from the device with
# `xcrun devicectl device copy from --device <UDID> --source ... --destination ...`
# (or via the Files app share-out path).

set -euo pipefail

if [ "${1-}" = "" ]; then
  echo "usage: $0 <package-dir>" >&2
  exit 64
fi

PACKAGE_DIR="$1"
MASTER="$PACKAGE_DIR/master.mov"
JSON="$PACKAGE_DIR/capture-package.json"

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

echo "==> probing master: $MASTER"

# ffprobe master.mov video stream — extract the four invariants.
PROBE_JSON="$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_tag_string,pix_fmt,width,height,r_frame_rate,color_space,color_transfer,color_primaries \
  -of json "$MASTER")"

echo "$PROBE_JSON"

CODEC_TAG="$(echo "$PROBE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["streams"][0].get("codec_tag_string",""))')"
PIX_FMT="$(echo   "$PROBE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["streams"][0].get("pix_fmt",""))')"
WIDTH="$(echo     "$PROBE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["streams"][0].get("width",0))')"
HEIGHT="$(echo    "$PROBE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["streams"][0].get("height",0))')"
RFR="$(echo       "$PROBE_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["streams"][0].get("r_frame_rate",""))')"

# M10 baseline:
#   codec_tag_string = apch  (kCMVideoCodecType_AppleProRes422HQ)
#   pix_fmt          = yuv422p10le
#   width x height   = 3840x2160
#   r_frame_rate     = 24/1
FAIL=0
expect() {
  local label="$1"; local got="$2"; local want="$3"
  if [ "$got" = "$want" ]; then
    printf "  OK  %-18s = %s\n" "$label" "$got"
  else
    printf "  FAIL %-18s got=%s want=%s\n" "$label" "$got" "$want"
    FAIL=1
  fi
}
expect codec_tag    "$CODEC_TAG" "apch"
expect pix_fmt      "$PIX_FMT"   "yuv422p10le"
expect width        "$WIDTH"     "3840"
expect height       "$HEIGHT"    "2160"
expect frame_rate   "$RFR"       "24/1"

echo
echo "==> capture-package.json contents:"
python3 -c '
import json,sys
with open(sys.argv[1]) as f: snap = json.load(f)
keys = ["schemaVersion","captureId","parametersCodec","parametersColorSpace",
        "parametersFrameRate","parametersWidthPx","parametersHeightPx",
        "selectedLookCanonicalUUID","selectedLookSlug","selectedLookEnglishName","selectedLookIntensity"]
for k in keys:
    print(f"  {k} = {snap.get(k)!r}")
ver = snap.get("schemaVersion")
if ver != 2:
    print(f"FAIL  schemaVersion got={ver} want=2"); sys.exit(2)
print("  OK   schemaVersion = 2")

uuid = snap.get("selectedLookCanonicalUUID")
nm   = snap.get("selectedLookEnglishName")
inten= snap.get("selectedLookIntensity")
if uuid is None and nm is None and inten is None:
    print("  OK   selectedLook = nil  (Filmtone default chip / no override)")
elif uuid is not None and nm is not None and inten is not None:
    print(f"  OK   selectedLook = {nm!r} canonicalUUID={uuid} intensity={inten}")
else:
    print("FAIL selectedLook* partial (UUID/name/intensity inconsistency)"); sys.exit(2)
' "$JSON"

if [ $FAIL -ne 0 ]; then
  echo
  echo "MASTER TRUTH GATE FAIL"
  exit 1
fi

echo
echo "MASTER TRUTH GATE PASS"
