#!/usr/bin/env bash
# M5-C.3a verification harness runner.
#
# After M4-B Phase 2, Verify links FilmLabSwiftCore as a real Swift module —
# plain SOURCES additions don't work because the package uses public access
# modifiers + explicit memberwise inits that need module resolution, not
# source concatenation. So we `swift build` the package first, then `swiftc`
# the remaining Foundation-only Desktop sources with `-I $PKG_BIN_PATH/Modules`
# and link the SwiftPM-emitted `.swift.o` objects from
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
PKG_OBJECTS=()
while IFS= read -r object; do
  PKG_OBJECTS+=("$object")
done < <(find "$PKG_OBJ_DIR" -maxdepth 1 -name '*.swift.o' -print | sort)

SOURCES=(
  "$SRC_ROOT/Domain/CameraOpticsDTO.swift"
  "$SRC_ROOT/Domain/SourceColorTypes.swift"
  "$SRC_ROOT/Domain/FilmtoneDesktopStrings.swift"
  "$SRC_ROOT/Domain/FilmtoneOpticalScatterMath.swift"
  "$SRC_ROOT/Domain/AdvancedAdjustCatalog.swift"
  "$SRC_ROOT/Domain/FilmtoneCompareSplitMath.swift"
  "$SRC_ROOT/Color/FilmtonePresetCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneCreativePackCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneSavedLookSchema.swift"
  "$SRC_ROOT/Color/FilmtoneSavedLookStore.swift"
  "$SRC_ROOT/Color/FilmtoneImportedGradeSchema.swift"
  "$SRC_ROOT/Color/FilmtoneImportedGradeEvaluator.swift"
  "$SRC_ROOT/Color/FilmtoneImportedGradeStore.swift"
  "$SRC_ROOT/Color/FilmtoneGradeRecipe.swift"
  "$SRC_ROOT/Color/FilmtoneGradeResolution.swift"
  "$SRC_ROOT/Color/SourceColorMetadataNormalizer.swift"
  "$SRC_ROOT/Color/SourceColorClassifier.swift"
  "$SRC_ROOT/Color/FilmtoneSourceProfileCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneSourceProfileMath.swift"
  "$SRC_ROOT/Color/FilmtoneSourceInputTransform.swift"
  "$SRC_ROOT/Color/FilmtoneCubeParser.swift"
  "$SRC_ROOT/Color/FilmtoneLutBlobCodec.swift"
  "$SRC_ROOT/Color/FilmtoneCreativeLutLoader.swift"
  "$SRC_ROOT/Color/FilmtoneCIContext.swift"
  "$SRC_ROOT/Color/FilmtoneGradeKernels.swift"
  "$SRC_ROOT/Color/FilmtoneRayAngleOptics.swift"
  "$SRC_ROOT/Color/FilmtoneColorPipelineContract.swift"
  "$SRC_ROOT/Color/FilmtoneColorPipeline.swift"
  "$SRC_ROOT/Color/FilmtoneGradePipeline.swift"
  "$SRC_ROOT/Export/FilmtoneSidecarTypes.swift"
  "$SRC_ROOT/Export/FilmtoneSidecarWriter.swift"
  "$SRC_ROOT/Export/FilmtoneExportSnapshot.swift"
  "$SRC_ROOT/Export/FilmtoneStillExporter.swift"
  "$SRC_ROOT/Export/FilmtoneVideoExporter.swift"
  "$SRC_ROOT/Media/FormatExtensionReader.swift"
  "$SRC_ROOT/Media/FilmtoneSourceProber.swift"
  "$SRC_ROOT/Media/FilmtoneScrubThumbnailMath.swift"
  "$SRC_ROOT/Media/FilmtoneVideoReader.swift"
  "$SRC_ROOT/Media/FilmtoneVideoWriter.swift"
  "$SRC_ROOT/State/FilmtoneCapturePackageImport.swift"
  "$SRC_ROOT/State/FilmtoneImportedGradePackageImport.swift"
  "$SRC_ROOT/State/FilmtoneDrxImport.swift"
  "$APP_ROOT/AutomationCLI/FilmtoneAutomationCore.swift"
  "$APP_ROOT/AutomationCLI/FilmtoneFrameMetricsHarness.swift"
  "$HERE/TestSupport.swift"
  "$HERE/CoreQuickSidecarStateTests.swift"
  "$HERE/CoreCatalogStoreStringTests.swift"
  "$HERE/CoreOpticalFilterTests.swift"
  "$HERE/ImportedGradeRuntimeTests.swift"
  "$HERE/DBM13GradeResolutionTests.swift"
  "$HERE/DBM13DrxImportTests.swift"
  "$HERE/AutomationRuntimeTests.swift"
  "$HERE/FrameMetricsHarnessTests.swift"
  "$HERE/main.swift"
)

OUT="${TMPDIR:-/tmp}/filmtone-desktop-verify-m5c3a"
swiftc \
  -I "$PKG_BIN_PATH/Modules" \
  -o "$OUT" \
  "${SOURCES[@]}" \
  "${PKG_OBJECTS[@]}"
export FILMTONE_CREATIVE_LUT_ROOT="$SRC_ROOT/Resources/CreativeLuts"
"$OUT"
