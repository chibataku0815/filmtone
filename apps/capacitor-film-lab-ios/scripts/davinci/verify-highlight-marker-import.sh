#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
APP_DIR="$REPO_ROOT/apps/capacitor-film-lab-ios"
IMPORTER="$SCRIPT_DIR/filmtone_connect_import_package.lua"
DEFAULT_SIDECAR="$REPO_ROOT/packages/film-lab-swift-core/Tests/Fixtures/highlight-markers/C0061.filmtone-ios-export-session-v1.json"
HLG_FIXTURE="$APP_DIR/scripts/fixtures/phase0-contract/hlg-export-request.json"
SWIFT_SUPPORT="$APP_DIR/scripts/swift/phase0-contract-support.swift"
SOURCE_PROFILE_SCHEMA="$APP_DIR/ios/App/App/FilmtoneSourceProfileSchema.swift"
SWIFT_CORE_DIR="$REPO_ROOT/packages/film-lab-swift-core/Sources/FilmLabSwiftCore"
SIDECAR_BUILDER_SCRIPT="$APP_DIR/scripts/swift/test-sidecar-builder.swift"
SIDECAR_SRC="$APP_DIR/ios/App/App/FilmtoneExportSidecarBuilder.swift"
LUT_BLOB_CODEC_SRC="$APP_DIR/ios/App/App/FilmtoneLutBlobCodec.swift"
FUSCRIPT="${FUSCRIPT:-/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript}"
FFMPEG="${FFMPEG:-$(command -v ffmpeg || true)}"
PROJECT_NAME="Filmtone Highlight Marker Smoke $(date +%Y%m%d-%H%M%S)"
CUSTOM_DATA="filmtone-highlight-marker:filmtone-marker-001"
SIDECAR_INPUT="$DEFAULT_SIDECAR"
APP_GENERATED_SIDECAR=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--sidecar PATH | --app-generated-sidecar]

  --sidecar PATH              Use an existing sidecar JSON as DaVinci input.
  --app-generated-sidecar     Compile the iOS sidecar builder and emit the
                              marker sidecar used by this smoke.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sidecar)
      [ "$#" -ge 2 ] || { usage >&2; exit 1; }
      SIDECAR_INPUT="$2"
      shift 2
      ;;
    --app-generated-sidecar)
      APP_GENERATED_SIDECAR=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$APP_GENERATED_SIDECAR" == "1" && "$SIDECAR_INPUT" != "$DEFAULT_SIDECAR" ]]; then
  echo "[Filmtone Resolve Smoke] choose either --sidecar or --app-generated-sidecar, not both" >&2
  exit 1
fi

if [[ ! -x "$FUSCRIPT" ]]; then
  echo "[Filmtone Resolve Smoke] missing fuscript: $FUSCRIPT" >&2
  exit 1
fi

if [[ -z "$FFMPEG" || ! -x "$FFMPEG" ]]; then
  echo "[Filmtone Resolve Smoke] ffmpeg is required to generate smoke media" >&2
  exit 1
fi

if [[ "$APP_GENERATED_SIDECAR" == "0" && ! -f "$SIDECAR_INPUT" ]]; then
  echo "[Filmtone Resolve Smoke] missing sidecar input: $SIDECAR_INPUT" >&2
  exit 1
fi

resolve_was_running=0
if pgrep -fl "DaVinci Resolve.app/Contents/MacOS/Resolve" >/dev/null 2>&1; then
  resolve_was_running=1
fi

PACKAGE_DIR="$(mktemp -d /tmp/filmtone-highlight-marker-resolve.XXXXXX)"
SETUP_SCRIPT="$(mktemp /tmp/filmtone-resolve-setup.XXXXXX)"
CHECK_SCRIPT="$(mktemp /tmp/filmtone-resolve-check.XXXXXX)"
VERIFY_SCRIPT="$(mktemp /tmp/filmtone-resolve-verify.XXXXXX)"
CLEANUP_SCRIPT="$(mktemp /tmp/filmtone-resolve-cleanup.XXXXXX)"
SWIFT_BUILD_TMP=""
SIDECAR_DEST="$PACKAGE_DIR/C0061.filmtone-ios-export-session-v1.json"

cleanup() {
  set +e
  if [[ -x "$FUSCRIPT" && -f "$CLEANUP_SCRIPT" ]]; then
    "$FUSCRIPT" "$CLEANUP_SCRIPT" "$PROJECT_NAME" >/tmp/filmtone-resolve-cleanup.log 2>&1
    cat /tmp/filmtone-resolve-cleanup.log
  fi
  if [[ "$resolve_was_running" == "0" ]]; then
    osascript -e 'tell application id "com.blackmagic-design.DaVinciResolve" to quit' >/dev/null 2>&1
  fi
  if [[ -n "$SWIFT_BUILD_TMP" ]]; then
    rm -rf "$SWIFT_BUILD_TMP"
  fi
}
trap cleanup EXIT

build_app_generated_sidecar() {
  local output_path="$1"
  SWIFT_BUILD_TMP="$(mktemp -d /tmp/filmtone-sidecar-builder.XXXXXX)"
  local core_module_dir="$SWIFT_BUILD_TMP/core"
  local sidecar_bin="$SWIFT_BUILD_TMP/test-sidecar-builder"
  mkdir -p "$core_module_dir"

  xcrun swiftc \
    -parse-as-library \
    -emit-module \
    -emit-library \
    -static \
    -module-name FilmLabSwiftCore \
    -emit-module-path "$core_module_dir/FilmLabSwiftCore.swiftmodule" \
    -o "$core_module_dir/libFilmLabSwiftCore.a" \
    "$SWIFT_CORE_DIR"/*.swift \
    "$SWIFT_CORE_DIR"/Generated/*.swift

  xcrun swiftc \
    -I "$core_module_dir" \
    "$core_module_dir/libFilmLabSwiftCore.a" \
    -o "$sidecar_bin" \
    "$SWIFT_SUPPORT" \
    "$SOURCE_PROFILE_SCHEMA" \
    "$APP_DIR/ios/App/App/FilmtoneColorPipeline.swift" \
    "$LUT_BLOB_CODEC_SRC" \
    "$SIDECAR_SRC" \
    "$SIDECAR_BUILDER_SCRIPT"

  "$sidecar_bin" \
    --emit-highlight-marker-sidecar \
    "$HLG_FIXTURE" \
    "$output_path"
}

if [[ "$APP_GENERATED_SIDECAR" == "1" ]]; then
  build_app_generated_sidecar "$SIDECAR_DEST"
  echo "[Filmtone Resolve Smoke] sidecar=app-generated:$SIDECAR_DEST"
else
  cp "$SIDECAR_INPUT" "$SIDECAR_DEST"
  echo "[Filmtone Resolve Smoke] sidecar=$SIDECAR_INPUT"
fi
"$FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i color=c=black:s=320x180:r=30000/1001:d=60 \
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
  "$PACKAGE_DIR/C0061.mov"
cp "$PACKAGE_DIR/C0061.mov" "$PACKAGE_DIR/C0061-filmtone.mov"
"$FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i color=c=white:s=16x16 -frames:v 1 \
  "$PACKAGE_DIR/reference-after.jpg"

cat >"$PACKAGE_DIR/combined-color.cube" <<'CUBE'
TITLE "identity"
LUT_3D_SIZE 2
DOMAIN_MIN 0.0 0.0 0.0
DOMAIN_MAX 1.0 1.0 1.0
0.0 0.0 0.0
0.0 0.0 1.0
0.0 1.0 0.0
0.0 1.0 1.0
1.0 0.0 0.0
1.0 0.0 1.0
1.0 1.0 0.0
1.0 1.0 1.0
CUBE

cat >"$PACKAGE_DIR/filmtone-bridge.dctl" <<'DCTL'
__DEVICE__ float3 transform(int p_Width, int p_Height, int p_X, int p_Y, float p_R, float p_G, float p_B)
{
    return make_float3(p_R, p_G, p_B);
}
DCTL

cat >"$CHECK_SCRIPT" <<'LUA'
local resolve = Resolve()
if not resolve then error("resolve unavailable", 0) end
local pm = resolve:GetProjectManager()
if not pm then error("project manager unavailable", 0) end
print("resolve-ready")
LUA

cat >"$SETUP_SCRIPT" <<'LUA'
local name = arg[1]
local allowActive = os.getenv("FILMTONE_DAVINCI_SMOKE_ALLOW_ACTIVE_PROJECT") == "1"
local resolve = Resolve()
if not resolve then error("Resolve scripting object unavailable", 0) end
local pm = resolve:GetProjectManager()
if not pm then error("ProjectManager unavailable", 0) end
local current = pm:GetCurrentProject()
if current and not allowActive then
    local currentName = tostring(current:GetName())
    local timelineCount = current:GetTimelineCount() or 0
    if currentName:match("^Untitled Project") and timelineCount == 0 then
        print("[Filmtone Resolve Smoke] closing-empty-startup-project=" .. currentName)
        pm:CloseProject(current)
    else
        error("active Resolve project is loaded: " .. currentName .. ". Close it or set FILMTONE_DAVINCI_SMOKE_ALLOW_ACTIVE_PROJECT=1.", 0)
    end
end
local project = pm:CreateProject(name)
if not project then error("failed to create project " .. tostring(name), 0) end
print("[Filmtone Resolve Smoke] created-project=" .. tostring(project:GetName()))
LUA

cat >"$VERIFY_SCRIPT" <<'LUA'
local customData = arg[1]

local function fail(message)
    error("[Filmtone Resolve Smoke] " .. tostring(message), 0)
end

local function item_values(values)
    local result = {}
    if type(values) ~= "table" then
        return result
    end
    for key, value in pairs(values) do
        if type(key) == "number" and value ~= nil then
            result[#result + 1] = value
        end
    end
    return result
end

local function table_has_any_value(values)
    if type(values) ~= "table" then
        return false
    end
    for _, _ in pairs(values) do
        return true
    end
    return false
end

local function markers_by_custom_data(item)
    local result = {}
    if item and item.GetMarkers then
        for frame, marker in pairs(item:GetMarkers() or {}) do
            if type(marker) == "table" and marker.customData == customData then
                marker.__frame = frame
                result[#result + 1] = marker
            end
        end
    end
    if #result == 0 and item and item.GetMarkerByCustomData then
        local marker = item:GetMarkerByCustomData(customData)
        if table_has_any_value(marker) then
            result[#result + 1] = marker
        end
    end
    return result
end

local resolve = Resolve()
if not resolve then fail("Resolve scripting object unavailable") end
local project = resolve:GetProjectManager():GetCurrentProject()
if not project then fail("no current project") end

local sourceTimelineFound = false
local highlightMarkerFound = false
local highlightMarkerCount = 0
local roughTimelineFound = false
local roughItemCount = 0
local timelineCount = project:GetTimelineCount() or 0
print("[Filmtone Resolve Smoke] project=" .. tostring(project:GetName()))
print("[Filmtone Resolve Smoke] timelineCount=" .. tostring(timelineCount))

for index = 1, timelineCount do
    local timeline = project:GetTimelineByIndex(index)
    local name = timeline and timeline:GetName() or "<nil>"
    local items = item_values(timeline and timeline:GetItemListInTrack("video", 1) or {})
    print("[Filmtone Resolve Smoke] timeline[" .. tostring(index) .. "]=" .. tostring(name)
        .. " videoItems=" .. tostring(#items))
    if tostring(name):match("^Filmtone Connect Source") then
        sourceTimelineFound = true
        for _, item in ipairs(items) do
            for _, marker in ipairs(markers_by_custom_data(item)) do
                highlightMarkerFound = true
                highlightMarkerCount = highlightMarkerCount + 1
                print("[Filmtone Resolve Smoke] highlight marker customData=" .. customData
                    .. " name=" .. tostring(marker.name)
                    .. " color=" .. tostring(marker.color)
                    .. " duration=" .. tostring(marker.duration))
            end
        end
    end
    if tostring(name):match("^Highlight_Auto") then
        roughTimelineFound = true
        roughItemCount = #items
    end
end

if not sourceTimelineFound then fail("source timeline missing") end
if not highlightMarkerFound then fail("highlight marker customData missing") end
if highlightMarkerCount ~= 1 then fail("expected exactly one highlight marker customData, found " .. tostring(highlightMarkerCount)) end
if not roughTimelineFound then fail("Highlight_Auto timeline missing") end
if roughItemCount < 1 then fail("Highlight_Auto timeline has no video items") end

print("[Filmtone Resolve Smoke] PASS customData uniqueness + Highlight_Auto timeline verified")
LUA

cat >"$CLEANUP_SCRIPT" <<'LUA'
local tempName = arg[1]
local resolve = Resolve()
if not resolve then return end
local pm = resolve:GetProjectManager()
if not pm then return end
local current = pm:GetCurrentProject()
if current and current:GetName() == tempName then
    print("[Filmtone Resolve Smoke] closed-temp-project=" .. tostring(pm:CloseProject(current)))
end
print("[Filmtone Resolve Smoke] deleted-temp-project=" .. tostring(pm:DeleteProject(tempName)))
LUA

if [[ "$resolve_was_running" == "0" ]]; then
  open -a "DaVinci Resolve"
fi

for _ in $(seq 1 120); do
  if "$FUSCRIPT" "$CHECK_SCRIPT" 2>&1 | grep -q "resolve-ready"; then
    break
  fi
  sleep 2
done

"$FUSCRIPT" "$CHECK_SCRIPT" >/dev/null
setup_output="$("$FUSCRIPT" "$SETUP_SCRIPT" "$PROJECT_NAME" 2>&1)"
printf '%s\n' "$setup_output"
if ! grep -q "\[Filmtone Resolve Smoke\] created-project=$PROJECT_NAME" <<<"$setup_output"; then
  echo "[Filmtone Resolve Smoke] setup did not create the expected temporary project; aborting before import" >&2
  exit 1
fi
first_import_output="$("$FUSCRIPT" "$IMPORTER" --package "$PACKAGE_DIR" 2>&1)"
printf '%s\n' "$first_import_output"
if ! grep -q "created Highlight_Auto timeline with 1 source-relative range" <<<"$first_import_output"; then
  echo "[Filmtone Resolve Smoke] importer did not create the expected Highlight_Auto timeline" >&2
  exit 1
fi
second_import_output="$("$FUSCRIPT" "$IMPORTER" --package "$PACKAGE_DIR" 2>&1)"
printf '%s\n' "$second_import_output"
if ! grep -q "refreshed 1 existing Filmtone highlight marker" <<<"$second_import_output"; then
  echo "[Filmtone Resolve Smoke] repeated import did not refresh the existing highlight marker" >&2
  exit 1
fi
verify_output="$("$FUSCRIPT" "$VERIFY_SCRIPT" "$CUSTOM_DATA" 2>&1)"
printf '%s\n' "$verify_output"
if ! grep -q "PASS customData uniqueness + Highlight_Auto timeline verified" <<<"$verify_output"; then
  echo "[Filmtone Resolve Smoke] Resolve readback verification failed" >&2
  exit 1
fi

echo "[Filmtone Resolve Smoke] package=$PACKAGE_DIR"
