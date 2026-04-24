#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
FIXTURE_DIR="$SCRIPT_DIR/fixtures/phase0-contract"
SWIFT_SUPPORT="$SCRIPT_DIR/swift/phase0-contract-support.swift"
SWIFT_CHECK="$SCRIPT_DIR/swift/verify-phase0-contract.swift"
PHASE0_GENERATED="$APP_DIR/ios/App/App/FilmtonePhase0Generated.swift"
PHASE0_MATH="$APP_DIR/ios/App/App/FilmtonePhase0Math.swift"
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
  "$PHASE0_GENERATED" \
  "$PHASE0_MATH" \
  "$SWIFT_CHECK"

xcrun swiftc \
  -o "$HOST_BINARY" \
  "$SWIFT_SUPPORT" \
  "$PHASE0_GENERATED" \
  "$PHASE0_MATH" \
  "$SWIFT_CHECK"

"$HOST_BINARY" "$CANONICAL_FIXTURE" "$LEGACY_FIXTURE" "$HLG_FIXTURE"

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

# --- Stream 5: sidecar builder test (may not exist yet at Wave 2 branch time) ---
SIDECAR_SCRIPT="$SCRIPT_DIR/swift/test-sidecar-builder.swift"
SIDECAR_SRC="$APP_DIR/ios/App/App/FilmtoneExportSidecarBuilder.swift"
if [ -f "$SIDECAR_SCRIPT" ] && [ -f "$SIDECAR_SRC" ]; then
  echo "==> sidecar builder test"
  SIDECAR_BIN=$(mktemp "${TMPDIR:-/tmp}/phase0-sidecar-check.XXXXXX")
  CLEANUP_FILES="$CLEANUP_FILES $SIDECAR_BIN"
  xcrun swiftc \
    -o "$SIDECAR_BIN" \
    "$SWIFT_SUPPORT" \
    "$SIDECAR_SRC" \
    "$SIDECAR_SCRIPT"
  "$SIDECAR_BIN" "$HLG_FIXTURE"
fi
