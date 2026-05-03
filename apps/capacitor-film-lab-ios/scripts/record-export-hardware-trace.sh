#!/usr/bin/env bash
set -euo pipefail

DEVICE_UDID="${FILMTONE_XCTRACE_DEVICE_UDID:-00008150-001674883C84401C}"
DEVICETL_DEVICE_ID="${FILMTONE_DEVICE_ID:-3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9}"
BUNDLE_ID="${FILMTONE_BUNDLE_ID:-com.chibatakumi.film.lab.ios}"
TEMPLATE="${FILMTONE_TRACE_TEMPLATE:-Metal System Trace}"
TIME_LIMIT="${FILMTONE_TRACE_TIME_LIMIT:-4m}"
OUT_DIR="${FILMTONE_TRACE_OUT_DIR:-/tmp/filmtone-export-profile}"
STAMP="$(date +%Y%m%d-%H%M%S)"
SAFE_TEMPLATE="${TEMPLATE// /-}"
TRACE_PATH="${OUT_DIR}/filmtone-ios-export-${STAMP}-${SAFE_TEMPLATE}.trace"
LAUNCH_JSON="${OUT_DIR}/filmtone-ios-export-${STAMP}-launch.json"
APP_ENV_JSON="$(
  python3 - <<'PY'
import json
import os

env = {"FILMTONE_MEZZANINE_AUTO_PREWARM": "0"}
if os.environ.get("FILMTONE_EXPORT_DISABLE_GLOW_FAMILY"):
    env["FILMTONE_EXPORT_DISABLE_GLOW_FAMILY"] = os.environ["FILMTONE_EXPORT_DISABLE_GLOW_FAMILY"]
print(json.dumps(env, separators=(",", ":")))
PY
)"

mkdir -p "${OUT_DIR}"

cat <<EOF
Filmtone iOS export hardware trace
template: ${TEMPLATE}
device:   ${DEVICE_UDID}
duration: ${TIME_LIMIT}
output:   ${TRACE_PATH}
app env:  ${APP_ENV_JSON}

When Instruments starts recording, run the same Quality export on the device.
Do not enable FILMTONE_EXPORT_RENDER_STAGE_PROFILE for this pass; it changes render timing.
EOF

xcrun devicectl device process launch \
  --device "${DEVICETL_DEVICE_ID}" \
  --terminate-existing \
  --environment-variables "${APP_ENV_JSON}" \
  --json-output "${LAUNCH_JSON}" \
  "${BUNDLE_ID}" >/dev/null

APP_PID="$(
  python3 - "${LAUNCH_JSON}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

pid = payload.get("result", {}).get("process", {}).get("processIdentifier")
if not pid:
    raise SystemExit("missing processIdentifier in devicectl launch JSON")
print(pid)
PY
)"

echo "attached process pid: ${APP_PID}"

if [ "${FILMTONE_TRACE_ALL_PROCESSES:-0}" = "1" ]; then
  xcrun xctrace record \
    --template "${TEMPLATE}" \
    --device "${DEVICE_UDID}" \
    --all-processes \
    --time-limit "${TIME_LIMIT}" \
    --output "${TRACE_PATH}" \
    --no-prompt
else
  xcrun xctrace record \
    --template "${TEMPLATE}" \
    --device "${DEVICE_UDID}" \
    --attach "${APP_PID}" \
    --time-limit "${TIME_LIMIT}" \
    --output "${TRACE_PATH}" \
    --no-prompt
fi

cat <<EOF

Trace written:
${TRACE_PATH}

Table of contents:
xcrun xctrace export --input '${TRACE_PATH}' --toc
EOF
