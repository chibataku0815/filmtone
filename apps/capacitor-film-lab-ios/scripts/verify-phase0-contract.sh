#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
FIXTURE_DIR="$SCRIPT_DIR/fixtures/phase0-contract"
SWIFT_SUPPORT="$SCRIPT_DIR/swift/phase0-contract-support.swift"
SWIFT_CHECK="$SCRIPT_DIR/swift/verify-phase0-contract.swift"
PHASE0_GENERATED="$APP_DIR/ios/App/App/FilmtonePhase0Generated.swift"
PHASE0_MATH="$APP_DIR/ios/App/App/FilmtonePhase0Math.swift"
MOTION_MATH="$APP_DIR/ios/App/App/FilmtoneMotionBlurMath.swift"
# v1.3 Camera Profiles Phase A — `FilmtoneProjectState.cameraProfile` references
# `CameraProfileSelection` from this schema file, so the standalone Phase 0
# compile must pull it in alongside Math/Motion. The schema's dependencies
# (`SourceInputTransformStrategyDTO`, `SourceColorClassDTO`) are stubbed in
# `phase0-contract-support.swift` so this stays target-free.
SOURCE_PROFILE_SCHEMA="$APP_DIR/ios/App/App/FilmtoneSourceProfileSchema.swift"
CANONICAL_FIXTURE="$FIXTURE_DIR/canonical-export-request.json"
LEGACY_FIXTURE="$FIXTURE_DIR/legacy-project-state.json"
HLG_FIXTURE="$FIXTURE_DIR/hlg-export-request.json"

SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)
SDK_MAJOR=${SDK_VERSION%%.*}
SIMULATOR_TARGET="arm64-apple-ios${SDK_MAJOR}.0-simulator"
HOST_BINARY=$(mktemp "${TMPDIR:-/tmp}/phase0-contract-check.XXXXXX")
CLEANUP_FILES="$HOST_BINARY"
trap 'rm -f $CLEANUP_FILES' EXIT

xcrun --sdk iphonesimulator swiftc \
  -target "$SIMULATOR_TARGET" \
  -typecheck \
  "$SWIFT_SUPPORT" \
  "$SOURCE_PROFILE_SCHEMA" \
  "$PHASE0_GENERATED" \
  "$PHASE0_MATH" \
  "$MOTION_MATH" \
  "$SWIFT_CHECK"

xcrun swiftc \
  -o "$HOST_BINARY" \
  "$SWIFT_SUPPORT" \
  "$SOURCE_PROFILE_SCHEMA" \
  "$PHASE0_GENERATED" \
  "$PHASE0_MATH" \
  "$MOTION_MATH" \
  "$SWIFT_CHECK"

"$HOST_BINARY" "$CANONICAL_FIXTURE" "$LEGACY_FIXTURE" "$HLG_FIXTURE"

# --- Motion blur 180° baseline math parity ---
MOTION_MATH_SCRIPT="$SCRIPT_DIR/swift/test-motion-blur-math.swift"
if [ -f "$MOTION_MATH_SCRIPT" ] && [ -f "$MOTION_MATH" ]; then
  echo "==> motion blur math test"
  MOTION_MATH_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-motion-blur-math-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $MOTION_MATH_BIN"
  xcrun swiftc \
    -o "$MOTION_MATH_BIN" \
    "$MOTION_MATH" \
    "$MOTION_MATH_SCRIPT"
  "$MOTION_MATH_BIN"
fi

# --- Stream C: .cube parser DOMAIN_MIN / DOMAIN_MAX test ---
CUBE_PARSER_SCRIPT="$SCRIPT_DIR/swift/test-cube-parser.swift"
CUBE_PARSER_SRC="$APP_DIR/ios/App/App/FilmtoneCubeParser.swift"
if [ -f "$CUBE_PARSER_SCRIPT" ] && [ -f "$CUBE_PARSER_SRC" ]; then
  echo "==> cube parser test"
  CUBE_PARSER_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-cube-parser-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $CUBE_PARSER_BIN"
  xcrun swiftc \
    -o "$CUBE_PARSER_BIN" \
    "$CUBE_PARSER_SRC" \
    "$CUBE_PARSER_SCRIPT"
  "$CUBE_PARSER_BIN"
fi

# --- Cache store retention / cleanup policy test ---
CACHE_STORE_SCRIPT="$SCRIPT_DIR/swift/test-cache-store.swift"
CACHE_STORE_SRC="$APP_DIR/ios/App/App/CacheStore.swift"
if [ -f "$CACHE_STORE_SCRIPT" ] && [ -f "$CACHE_STORE_SRC" ]; then
  echo "==> cache store test"
  CACHE_STORE_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-cache-store-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $CACHE_STORE_BIN"
  xcrun swiftc \
    -o "$CACHE_STORE_BIN" \
    "$CACHE_STORE_SRC" \
    "$CACHE_STORE_SCRIPT"
  "$CACHE_STORE_BIN"
fi

# --- Stream 1: source-color-classifier test (landed in foundation branch) ---
CLASSIFIER_SCRIPT="$SCRIPT_DIR/swift/test-source-color-classifier.swift"
if [ -f "$CLASSIFIER_SCRIPT" ]; then
  echo "==> source-color-classifier test"
  CLASSIFIER_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-classifier-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $CLASSIFIER_BIN"
  xcrun swiftc \
    -o "$CLASSIFIER_BIN" \
    "$SWIFT_SUPPORT" \
    "$APP_DIR/ios/App/App/SourceColorMetadataNormalizer.swift" \
    "$APP_DIR/ios/App/App/SourceColorClassifier.swift" \
    "$APP_DIR/ios/App/App/FilmtoneColorPipeline.swift" \
    "$APP_DIR/ios/App/App/HdrPreparationPolicyDeriver.swift" \
    "$CLASSIFIER_SCRIPT"
  "$CLASSIFIER_BIN" "$HLG_FIXTURE"
fi

# --- Stream 2: ray-angle optics test (may not exist yet at Wave 2 branch time) ---
RAYANGLE_SCRIPT="$SCRIPT_DIR/swift/test-ray-angle-optics.swift"
RAYANGLE_SRC="$APP_DIR/ios/App/App/FilmtoneRayAngleOptics.swift"
if [ -f "$RAYANGLE_SCRIPT" ] && [ -f "$RAYANGLE_SRC" ]; then
  echo "==> ray-angle optics test"
  RAYANGLE_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-rayangle-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $RAYANGLE_BIN"
  xcrun swiftc \
    -o "$RAYANGLE_BIN" \
    "$SWIFT_SUPPORT" \
    "$RAYANGLE_SRC" \
    "$RAYANGLE_SCRIPT"
  "$RAYANGLE_BIN"
fi

# --- v1.3 Camera Profiles Phase B-3 / C: source-profile math accuracy gate ---
SOURCE_PROFILE_MATH_SCRIPT="$SCRIPT_DIR/swift/test-source-profile-math.swift"
SOURCE_PROFILE_MATH_SRC="$APP_DIR/ios/App/App/FilmtoneSourceProfileMath.swift"
SOURCE_PROFILE_FIXTURES="$APP_DIR/Tests/Fixtures/source-profile"
if [ -f "$SOURCE_PROFILE_MATH_SCRIPT" ] && [ -f "$SOURCE_PROFILE_MATH_SRC" ] && [ -d "$SOURCE_PROFILE_FIXTURES" ]; then
  echo "==> source profile math test"
  SOURCE_PROFILE_MATH_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-source-profile-math-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $SOURCE_PROFILE_MATH_BIN"
  xcrun swiftc \
    -o "$SOURCE_PROFILE_MATH_BIN" \
    "$SOURCE_PROFILE_MATH_SRC" \
    "$SOURCE_PROFILE_MATH_SCRIPT"
  "$SOURCE_PROFILE_MATH_BIN" "$SOURCE_PROFILE_FIXTURES"
fi

# --- Stream 5: sidecar builder test (may not exist yet at Wave 2 branch time) ---
SIDECAR_SCRIPT="$SCRIPT_DIR/swift/test-sidecar-builder.swift"
SIDECAR_SRC="$APP_DIR/ios/App/App/FilmtoneExportSidecarBuilder.swift"
LUT_BLOB_CODEC_SRC="$APP_DIR/ios/App/App/FilmtoneLutBlobCodec.swift"
if [ -f "$SIDECAR_SCRIPT" ] && [ -f "$SIDECAR_SRC" ]; then
  echo "==> sidecar builder test"
  SIDECAR_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-sidecar-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $SIDECAR_BIN"
  # Item 3 (v1.3): the sidecar builder now hashes LUT data via
  # FilmtoneLutBlobCodec to populate the optional `sourceHash` field on
  # `SidecarLutRef`. Compile the codec alongside so the contract gate stays
  # self-contained — both files come from the App target.
  # v1.3 Camera Profiles Phase E: phase0-contract-support's
  # `Phase0ExportRequestDTO` mirror now carries `cameraProfile`, so the
  # sidecar test compile must pull the schema in too.
  xcrun swiftc \
    -o "$SIDECAR_BIN" \
    "$SWIFT_SUPPORT" \
    "$SOURCE_PROFILE_SCHEMA" \
    "$APP_DIR/ios/App/App/FilmtoneColorPipeline.swift" \
    "$LUT_BLOB_CODEC_SRC" \
    "$SIDECAR_SRC" \
    "$SIDECAR_SCRIPT"
  "$SIDECAR_BIN" "$HLG_FIXTURE"
fi
