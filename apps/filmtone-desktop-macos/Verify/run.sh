#!/usr/bin/env bash
# M5-C.3a verification harness runner.
#
# After M4-B Phase 2, Verify links FilmLabSwiftCore as a real Swift module —
# plain SOURCES additions don't work because the package uses public access
# modifiers + explicit memberwise inits that need module resolution, not
# source concatenation. So we `swift build` the package first, then `swiftc`
# the remaining Foundation-only Desktop sources with `-I $PKG_BIN_PATH/Modules`
# and link the 5 SwiftPM-emitted `.swift.o` objects from
# `$PKG_BIN_PATH/FilmLabSwiftCore.build/` directly (SwiftPM does not emit
# `libFilmLabSwiftCore.a` / `.dylib` for library products by default).

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$HERE/.." && pwd)"
SRC_ROOT="$APP_ROOT/FilmtoneDesktop"
REPO_ROOT="$(cd "$APP_ROOT/../.." && pwd)"
PKG_ROOT="$REPO_ROOT/packages/film-lab-swift-core"

echo "[verify] building FilmLabSwiftCore (debug)..." >&2
( cd "$PKG_ROOT" && swift build -c debug ) >&2

PKG_BIN_PATH="$(cd "$PKG_ROOT" && swift build -c debug --show-bin-path)"
PKG_OBJ_DIR="$PKG_BIN_PATH/FilmLabSwiftCore.build"

# SwiftPM emits per-file `.o` objects under $PKG_BIN_PATH/FilmLabSwiftCore.build
# rather than a libFilmLabSwiftCore.a / .dylib by default, so feed the objects
# directly to swiftc alongside `-I $PKG_BIN_PATH/Modules` for module lookup.
PKG_OBJECTS=(
  "$PKG_OBJ_DIR/FilmtonePhase0Generated.swift.o"
  "$PKG_OBJ_DIR/FilmtoneQuickState.swift.o"
  "$PKG_OBJ_DIR/FilmtonePhase0Params.swift.o"
  "$PKG_OBJ_DIR/FilmtonePhase0ParamsPatch.swift.o"
  "$PKG_OBJ_DIR/Phase0OutputProfileDTO.swift.o"
)

SOURCES=(
  "$SRC_ROOT/Domain/CameraOpticsDTO.swift"
  "$SRC_ROOT/Domain/SourceColorTypes.swift"
  "$SRC_ROOT/Domain/FilmtoneDesktopStrings.swift"
  "$SRC_ROOT/Domain/AdvancedAdjustCatalog.swift"
  "$SRC_ROOT/Domain/FilmtoneCompareSplitMath.swift"
  "$SRC_ROOT/Color/FilmtonePresetCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneCreativePackCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneSavedLookSchema.swift"
  "$SRC_ROOT/Color/FilmtoneSavedLookStore.swift"
  "$SRC_ROOT/Color/FilmtoneSourceProfileCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneCubeParser.swift"
  "$SRC_ROOT/Color/FilmtoneCreativeLutLoader.swift"
  "$SRC_ROOT/Export/FilmtoneSidecarTypes.swift"
  "$SRC_ROOT/Export/FilmtoneSidecarWriter.swift"
  "$SRC_ROOT/Export/FilmtoneExportSnapshot.swift"
  "$SRC_ROOT/Media/FilmtoneScrubThumbnailMath.swift"
  "$HERE/main.swift"
)

OUT="${TMPDIR:-/tmp}/filmtone-desktop-verify-m5c3a"
swiftc \
  -I "$PKG_BIN_PATH/Modules" \
  -o "$OUT" \
  "${SOURCES[@]}" \
  "${PKG_OBJECTS[@]}"
"$OUT"
