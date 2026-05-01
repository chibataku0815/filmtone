#!/usr/bin/env bash
# Render the 12 help-sheet comparison JPEGs (2 shared "before" + 10 family
# "after") through the real Filmtone iOS pipeline and stage them into
# Assets.xcassets. One-shot dev tool: requires the two Artlist source MP4s
# under $FILMTONE_HELP_ASSET_SOURCE_DIR (default: ~/Downloads). The MP4s are
# read in-place and never copied into the repo.
#
# Mechanism:
#   1. Build App for the iPhone 17 Pro Max simulator (no codesign).
#   2. Install + launch with -filmtoneGenerateHelpAssets <sourceDir>.
#      AppDelegate intercepts the arg, runs FilmtoneHelpAssetGenerator
#      synchronously, NSLogs FILMTONE_HELP_ASSET_GENERATOR_DONE, exit(0).
#   3. Pull the resulting JPEGs from the app's caches container.
#   4. Stage each JPEG into the matching .imageset/ with a Contents.json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE="$APP_DIR/ios/App/App.xcworkspace"
ASSETS="$APP_DIR/ios/App/App/Assets.xcassets"
SCHEME="App"
BUNDLE_ID="com.chibatakumi.film.lab.ios"
SIM_UDID="${FILMTONE_SIM_UDID:-D3011FE4-52CA-4B7F-B181-A55D9998E192}"
SOURCE_DIR="${FILMTONE_HELP_ASSET_SOURCE_DIR:-$HOME/Downloads}"

SOURCE_SKIN="6454597_Woman Hand Gua Sha Window_By_Zed_Artlist_HD.mp4"
SOURCE_GLOW="6608500_Intimate Lighter Warm Glow Cozy Ambiance_By_Pressmaster_Artlist_HD.mp4"

for src in "$SOURCE_SKIN" "$SOURCE_GLOW"; do
  if [[ ! -f "$SOURCE_DIR/$src" ]]; then
    echo "error: missing source MP4: $SOURCE_DIR/$src" >&2
    echo "  set FILMTONE_HELP_ASSET_SOURCE_DIR or place the file at \$HOME/Downloads/" >&2
    exit 1
  fi
done

echo "==> boot simulator $SIM_UDID"
xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null

DERIVED_DATA="$(mktemp -d -t filmtone-help-assets)"
trap 'rm -rf "$DERIVED_DATA"' EXIT

echo "==> xcodebuild App for simulator (Debug, no codesign)"
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$SIM_UDID" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build CODE_SIGNING_ALLOWED=NO \
  | tail -40

APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/App.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "error: App.app not found at $APP_BUNDLE" >&2
  exit 1
fi

echo "==> simctl install"
xcrun simctl install "$SIM_UDID" "$APP_BUNDLE"

echo "==> launch with -filmtoneGenerateHelpAssets $SOURCE_DIR"
LAUNCH_LOG="$DERIVED_DATA/launch.log"
xcrun simctl launch \
  --console-pty "$SIM_UDID" "$BUNDLE_ID" \
  -filmtoneGenerateHelpAssets "$SOURCE_DIR" 2>&1 | tee "$LAUNCH_LOG" || true

if grep -q "FILMTONE_HELP_ASSET_GENERATOR_FAILED" "$LAUNCH_LOG"; then
  echo "error: generator failed; see $LAUNCH_LOG" >&2
  grep "FILMTONE_HELP_ASSET_GENERATOR_FAILED" "$LAUNCH_LOG" >&2
  exit 1
fi
if ! grep -q "FILMTONE_HELP_ASSET_GENERATOR_DONE" "$LAUNCH_LOG"; then
  echo "error: generator did not signal completion; see $LAUNCH_LOG" >&2
  exit 1
fi

APP_DATA="$(xcrun simctl get_app_container "$SIM_UDID" "$BUNDLE_ID" data)"
HELP_ASSETS_DIR="$APP_DATA/Library/Caches/FilmtonePhase0/help-assets"
if [[ ! -d "$HELP_ASSETS_DIR" ]]; then
  echo "error: help-assets directory not found at $HELP_ASSETS_DIR" >&2
  exit 1
fi

stage_imageset() {
  local source_basename="$1"
  local imageset_name="$2"
  local out_filename="$3"

  local src_jpg="$HELP_ASSETS_DIR/$source_basename.jpg"
  if [[ ! -f "$src_jpg" ]]; then
    echo "error: missing rendered image $src_jpg" >&2
    exit 1
  fi

  local dest_dir="$ASSETS/$imageset_name.imageset"
  mkdir -p "$dest_dir"
  cp "$src_jpg" "$dest_dir/$out_filename"

  cat > "$dest_dir/Contents.json" <<EOF
{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "$out_filename"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "filmtone-help-asset-generator"
  }
}
EOF
}

stage_imageset "before-skin"     "HelpCompareSceneSkin"     "help-compare-scene-skin.jpg"
stage_imageset "before-glow"     "HelpCompareSceneGlow"     "help-compare-scene-glow.jpg"
stage_imageset "after-strength"  "HelpCompareStrengthAfter" "help-compare-strength-after.jpg"
stage_imageset "after-exposure"  "HelpCompareExposureAfter" "help-compare-exposure-after.jpg"
stage_imageset "after-contrast"  "HelpCompareContrastAfter" "help-compare-contrast-after.jpg"
stage_imageset "after-saturation" "HelpCompareSaturationAfter" "help-compare-saturation-after.jpg"
stage_imageset "after-tone"      "HelpCompareToneAfter"     "help-compare-tone-after.jpg"
stage_imageset "after-optics"    "HelpCompareOpticsAfter"   "help-compare-optics-after.jpg"
stage_imageset "after-glow"      "HelpCompareGlowAfter"     "help-compare-glow-after.jpg"
stage_imageset "after-halation"  "HelpCompareHalationAfter" "help-compare-halation-after.jpg"
stage_imageset "after-grain"     "HelpCompareGrainAfter"    "help-compare-grain-after.jpg"
stage_imageset "after-motion"    "HelpCompareMotionAfter"   "help-compare-motion-after.jpg"

echo "==> staged 12 imagesets in $ASSETS"
