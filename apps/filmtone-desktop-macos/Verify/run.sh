#!/usr/bin/env bash
# M5-C.3a verification harness runner.
#
# Compiles a pure-Foundation subset of FilmtoneDesktop sources together
# with Verify/M5C3aVerify.swift and runs the resulting binary. No Xcode
# project / test target needed — `swiftc` does all the work.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$HERE/.." && pwd)"
SRC_ROOT="$APP_ROOT/FilmtoneDesktop"

SOURCES=(
  "$SRC_ROOT/Domain/Phase0Types.swift"
  "$SRC_ROOT/Domain/CameraOpticsDTO.swift"
  "$SRC_ROOT/Domain/SourceColorTypes.swift"
  "$SRC_ROOT/SharedGenerated/FilmtonePhase0Generated.swift"
  "$SRC_ROOT/Color/FilmtonePhase0ParamsPatch.swift"
  "$SRC_ROOT/Color/FilmtonePresetCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneCreativePackCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneSavedLookSchema.swift"
  "$SRC_ROOT/Color/FilmtoneSourceProfileCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneCubeParser.swift"
  "$SRC_ROOT/Color/FilmtoneCreativeLutLoader.swift"
  "$SRC_ROOT/Export/FilmtoneSidecarTypes.swift"
  "$SRC_ROOT/Export/FilmtoneSidecarWriter.swift"
  "$SRC_ROOT/Export/FilmtoneExportSnapshot.swift"
  "$HERE/main.swift"
)

OUT="${TMPDIR:-/tmp}/filmtone-desktop-verify-m5c3a"
swiftc -o "$OUT" "${SOURCES[@]}"
"$OUT"
