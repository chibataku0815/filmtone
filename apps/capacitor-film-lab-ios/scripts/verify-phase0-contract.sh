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

SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)
SDK_MAJOR=${SDK_VERSION%%.*}
SIMULATOR_TARGET="arm64-apple-ios${SDK_MAJOR}.0-simulator"
HOST_BINARY=$(mktemp "${TMPDIR:-/tmp}/phase0-contract-check.XXXXXX")
trap 'rm -f "$HOST_BINARY"' EXIT

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

"$HOST_BINARY" "$CANONICAL_FIXTURE" "$LEGACY_FIXTURE"
