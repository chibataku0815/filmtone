#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(CDPATH= cd -- "$APP_DIR/../.." && pwd)
FIXTURE_DIR="$SCRIPT_DIR/fixtures/phase0-contract"
SWIFT_SUPPORT="$SCRIPT_DIR/swift/phase0-contract-support.swift"
SWIFT_CHECK="$SCRIPT_DIR/swift/verify-phase0-contract.swift"
SWIFT_CORE_DIR="$REPO_ROOT/packages/film-lab-swift-core/Sources/FilmLabSwiftCore"
PHASE0_MATH="$APP_DIR/ios/App/App/Source/FilmtonePhase0Math.swift"
MOTION_MATH="$APP_DIR/ios/App/App/Optics/FilmtoneMotionBlurMath.swift"
# v1.3 Camera Profiles Phase A — `FilmtoneProjectState.cameraProfile` references
# `CameraProfileSelection` from this schema file, so the standalone Phase 0
# compile must pull it in alongside Math/Motion. The schema's dependencies
# (`SourceInputTransformStrategyDTO`, `SourceColorClassDTO`) are stubbed in
# `phase0-contract-support.swift` so this stays target-free.
SOURCE_PROFILE_SCHEMA="$APP_DIR/ios/App/App/Source/FilmtoneSourceProfileSchema.swift"
CANONICAL_FIXTURE="$FIXTURE_DIR/canonical-export-request.json"
LEGACY_FIXTURE="$FIXTURE_DIR/legacy-project-state.json"
HLG_FIXTURE="$FIXTURE_DIR/hlg-export-request.json"

SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)
SDK_MAJOR=${SDK_VERSION%%.*}
SIMULATOR_TARGET="arm64-apple-ios${SDK_MAJOR}.0-simulator"
HOST_BINARY=$(mktemp "${TMPDIR:-/tmp}/phase0-contract-check.XXXXXX")
HOST_CORE_MODULE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/filmtone-swift-core-host.XXXXXX")
IOS_CORE_MODULE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/filmtone-swift-core-ios.XXXXXX")
HOST_CORE_LIB="$HOST_CORE_MODULE_DIR/libFilmLabSwiftCore.a"
CLEANUP_FILES="$HOST_BINARY"
trap 'rm -f $CLEANUP_FILES; rm -rf "$HOST_CORE_MODULE_DIR" "$IOS_CORE_MODULE_DIR"' EXIT

build_swift_core_module() {
  module_dir="$1"
  sdk="$2"
  shift 2

  if [ -n "$sdk" ]; then
    swiftc_cmd="xcrun --sdk $sdk swiftc"
  else
    swiftc_cmd="xcrun swiftc"
  fi

  $swiftc_cmd \
    -parse-as-library \
    -emit-module \
    -emit-library \
    -static \
    -module-name FilmLabSwiftCore \
    -emit-module-path "$module_dir/FilmLabSwiftCore.swiftmodule" \
    "$@" \
    -o "$module_dir/libFilmLabSwiftCore.a" \
    "$SWIFT_CORE_DIR"/*.swift \
    "$SWIFT_CORE_DIR"/Generated/*.swift
}

build_swift_core_module "$IOS_CORE_MODULE_DIR" iphonesimulator -target "$SIMULATOR_TARGET"
build_swift_core_module "$HOST_CORE_MODULE_DIR" ""

xcrun --sdk iphonesimulator swiftc \
  -target "$SIMULATOR_TARGET" \
  -I "$IOS_CORE_MODULE_DIR" \
  -typecheck \
  "$SWIFT_SUPPORT" \
  "$SOURCE_PROFILE_SCHEMA" \
  "$PHASE0_MATH" \
  "$MOTION_MATH" \
  "$SWIFT_CHECK"

xcrun swiftc \
  -I "$HOST_CORE_MODULE_DIR" \
  "$HOST_CORE_LIB" \
  -o "$HOST_BINARY" \
  "$SWIFT_SUPPORT" \
  "$SOURCE_PROFILE_SCHEMA" \
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
CUBE_PARSER_SRC="$APP_DIR/ios/App/App/Look/FilmtoneCubeParser.swift"
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

# --- S7: capture transform-LUT warning classifier ---
CAPTURE_TRANSFORM_LUT_CLASSIFIER_SCRIPT="$SCRIPT_DIR/swift/test-capture-transform-lut-classifier.swift"
CAPTURE_TRANSFORM_LUT_CLASSIFIER_SRC="$APP_DIR/ios/App/App/Capture/FilmtoneCaptureTransformLutClassifier.swift"
if [ -f "$CAPTURE_TRANSFORM_LUT_CLASSIFIER_SCRIPT" ] && [ -f "$CAPTURE_TRANSFORM_LUT_CLASSIFIER_SRC" ]; then
  echo "==> capture transform LUT classifier test"
  CAPTURE_TRANSFORM_LUT_CLASSIFIER_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-capture-transform-lut-classifier-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $CAPTURE_TRANSFORM_LUT_CLASSIFIER_BIN"
  xcrun swiftc \
    -o "$CAPTURE_TRANSFORM_LUT_CLASSIFIER_BIN" \
    "$CAPTURE_TRANSFORM_LUT_CLASSIFIER_SRC" \
    "$CAPTURE_TRANSFORM_LUT_CLASSIFIER_SCRIPT"
  "$CAPTURE_TRANSFORM_LUT_CLASSIFIER_BIN"
fi

# --- Cache store retention / cleanup policy test ---
CACHE_STORE_SCRIPT="$SCRIPT_DIR/swift/test-cache-store.swift"
CACHE_STORE_SRC="$APP_DIR/ios/App/App/Services/CacheStore.swift"
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
    -I "$HOST_CORE_MODULE_DIR" \
    "$HOST_CORE_LIB" \
    "$SWIFT_SUPPORT" \
    "$APP_DIR/ios/App/App/Source/SourceColorMetadataNormalizer.swift" \
    "$APP_DIR/ios/App/App/Source/SourceColorClassifier.swift" \
    "$APP_DIR/ios/App/App/Look/FilmtoneColorPipeline.swift" \
    "$APP_DIR/ios/App/App/Export/HdrPreparationPolicyDeriver.swift" \
    "$CLASSIFIER_SCRIPT"
  "$CLASSIFIER_BIN" "$HLG_FIXTURE"
fi

# --- Stream 2: ray-angle optics test (may not exist yet at Wave 2 branch time) ---
RAYANGLE_SCRIPT="$SCRIPT_DIR/swift/test-ray-angle-optics.swift"
RAYANGLE_SRC="$APP_DIR/ios/App/App/Optics/FilmtoneRayAngleOptics.swift"
if [ -f "$RAYANGLE_SCRIPT" ] && [ -f "$RAYANGLE_SRC" ]; then
  echo "==> ray-angle optics test"
  RAYANGLE_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-rayangle-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $RAYANGLE_BIN"
  xcrun swiftc \
    -o "$RAYANGLE_BIN" \
    -I "$HOST_CORE_MODULE_DIR" \
    "$HOST_CORE_LIB" \
    "$SWIFT_SUPPORT" \
    "$RAYANGLE_SRC" \
    "$RAYANGLE_SCRIPT"
  "$RAYANGLE_BIN"
fi

# --- v1.3 Camera Profiles Phase B-3 / C: source-profile math accuracy gate ---
SOURCE_PROFILE_MATH_SCRIPT="$SCRIPT_DIR/swift/test-source-profile-math.swift"
SOURCE_PROFILE_MATH_SRC="$APP_DIR/ios/App/App/Source/FilmtoneSourceProfileMath.swift"
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

# --- M1 Max Quality Look Director resolver test ---
LOOK_DIRECTOR_SCRIPT="$SCRIPT_DIR/swift/test-look-director.swift"
LOOK_DIRECTOR_SRC="$APP_DIR/ios/App/App/Look/FilmtoneLookDirector.swift"
PACK01_PATCHES_SRC="$APP_DIR/ios/App/App/Look/FilmtoneCreativePack01Patches.swift"
PACK01_ADAPTATION_SRC="$APP_DIR/ios/App/App/Look/FilmtoneCreativePack01Adaptation.swift"
SOURCE_TONE_DESCRIPTOR_SRC="$APP_DIR/ios/App/App/Source/FilmtoneSourceToneDescriptor.swift"
if [ -f "$LOOK_DIRECTOR_SCRIPT" ] && [ -f "$LOOK_DIRECTOR_SRC" ] && [ -f "$PACK01_PATCHES_SRC" ]; then
  echo "==> look director resolver test"
  LOOK_DIRECTOR_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-look-director-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $LOOK_DIRECTOR_BIN"
  xcrun swiftc \
    -o "$LOOK_DIRECTOR_BIN" \
    -I "$HOST_CORE_MODULE_DIR" \
    "$HOST_CORE_LIB" \
    "$SOURCE_TONE_DESCRIPTOR_SRC" \
    "$PACK01_PATCHES_SRC" \
    "$LOOK_DIRECTOR_SRC" \
    "$PACK01_ADAPTATION_SRC" \
    "$LOOK_DIRECTOR_SCRIPT"
  "$LOOK_DIRECTOR_BIN"
fi

# --- Look × Veil energy max-merge contract (2026-05-06 iOS port) ---
LOOK_VEIL_MERGE_SCRIPT="$SCRIPT_DIR/swift/test-look-veil-energy-merge.swift"
if [ -f "$LOOK_VEIL_MERGE_SCRIPT" ]; then
  echo "==> look × veil energy merge test"
  LOOK_VEIL_MERGE_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-look-veil-merge-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $LOOK_VEIL_MERGE_BIN"
  xcrun swiftc \
    -o "$LOOK_VEIL_MERGE_BIN" \
    "$LOOK_VEIL_MERGE_SCRIPT"
  "$LOOK_VEIL_MERGE_BIN"
fi

# --- Stream 5: sidecar builder test (may not exist yet at Wave 2 branch time) ---
SIDECAR_SCRIPT="$SCRIPT_DIR/swift/test-sidecar-builder.swift"
SIDECAR_SRC="$APP_DIR/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift"
LUT_BLOB_CODEC_SRC="$APP_DIR/ios/App/App/Look/FilmtoneLutBlobCodec.swift"
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
    -I "$HOST_CORE_MODULE_DIR" \
    "$HOST_CORE_LIB" \
    "$SWIFT_SUPPORT" \
    "$SOURCE_PROFILE_SCHEMA" \
    "$APP_DIR/ios/App/App/Look/FilmtoneColorPipeline.swift" \
    "$LUT_BLOB_CODEC_SRC" \
    "$SIDECAR_SRC" \
    "$SIDECAR_SCRIPT"
  "$SIDECAR_BIN" "$HLG_FIXTURE"
fi

# --- iOS capture package persistence payload round-trip ---
CAPTURE_PACKAGE_SCRIPT="$SCRIPT_DIR/swift/test-capture-package-persistence.swift"
CAPTURE_PACKAGE_SRC="$APP_DIR/ios/App/App/Capture/FilmtoneCapturePackage.swift"
CAPTURE_PACKAGE_PERSISTENCE_SRC="$APP_DIR/ios/App/App/Capture/FilmtoneCapturePackagePersistence.swift"
if [ -f "$CAPTURE_PACKAGE_SCRIPT" ] &&
   [ -f "$CAPTURE_PACKAGE_SRC" ] &&
   [ -f "$CAPTURE_PACKAGE_PERSISTENCE_SRC" ]; then
  echo "==> capture package persistence payload round-trip test"
  CAPTURE_PACKAGE_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-capture-package-check.XXXXXX")
  CAPTURE_PACKAGE_TMP=$(mktemp "${TMPDIR:-/tmp}/FilmtoneCapturePackage.XXXXXX.swift")
  CAPTURE_PACKAGE_PERSISTENCE_TMP=$(mktemp "${TMPDIR:-/tmp}/FilmtoneCapturePackagePersistence.XXXXXX.swift")
  CLEANUP_FILES="$CLEANUP_FILES $CAPTURE_PACKAGE_BIN $CAPTURE_PACKAGE_TMP $CAPTURE_PACKAGE_PERSISTENCE_TMP"

  sed '/^#if os(iOS)$/d;/^#endif$/d' "$CAPTURE_PACKAGE_SRC" > "$CAPTURE_PACKAGE_TMP"
  sed '/^#if os(iOS)$/d;/^#endif$/d' "$CAPTURE_PACKAGE_PERSISTENCE_SRC" > "$CAPTURE_PACKAGE_PERSISTENCE_TMP"

  xcrun swiftc \
    -o "$CAPTURE_PACKAGE_BIN" \
    "$LUT_BLOB_CODEC_SRC" \
    "$CAPTURE_PACKAGE_TMP" \
    "$CAPTURE_PACKAGE_PERSISTENCE_TMP" \
    "$CAPTURE_PACKAGE_SCRIPT"
  "$CAPTURE_PACKAGE_BIN"
fi
