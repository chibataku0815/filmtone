#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
APP_ROOT="$REPO_ROOT/apps/filmtone-desktop-macos"
SRC_ROOT="$APP_ROOT/FilmtoneDesktop"
AUTOMATION_ROOT="$APP_ROOT/AutomationCLI"
PKG_ROOT="$REPO_ROOT/packages/film-lab-swift-core"
OUT_DIR="$APP_ROOT/build/automation"
OUT="$OUT_DIR/FilmtoneAutomationCLI"

mkdir -p "$OUT_DIR"

echo "[automation] building FilmLabSwiftCore..." >&2
( cd "$PKG_ROOT" && swift build -c debug ) >&2

PKG_BIN_PATH="$(cd "$PKG_ROOT" && swift build -c debug --show-bin-path)"
PKG_OBJ_DIR="$PKG_BIN_PATH/FilmLabSwiftCore.build"

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
  "$SRC_ROOT/Color/FilmtonePresetCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneCreativePackCatalog.swift"
  "$SRC_ROOT/Color/FilmtoneSavedLookSchema.swift"
  "$SRC_ROOT/Color/FilmtoneImportedGradeSchema.swift"
  "$SRC_ROOT/Color/FilmtoneImportedGradeEvaluator.swift"
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
  "$SRC_ROOT/Export/FilmtoneStillExporter.swift"
  "$SRC_ROOT/Export/FilmtoneVideoExporter.swift"
  "$SRC_ROOT/State/FilmtoneCapturePackageImport.swift"
  "$SRC_ROOT/Media/FormatExtensionReader.swift"
  "$SRC_ROOT/Media/FilmtoneSourceProber.swift"
  "$SRC_ROOT/Media/FilmtoneVideoReader.swift"
  "$SRC_ROOT/Media/FilmtoneVideoWriter.swift"
  "$AUTOMATION_ROOT/FilmtoneAutomationCore.swift"
  "$AUTOMATION_ROOT/FilmtoneFrameMetricsHarness.swift"
  "$AUTOMATION_ROOT/FilmtoneAutomationCLI.swift"
)

swiftc \
  -I "$PKG_BIN_PATH/Modules" \
  -o "$OUT" \
  "${SOURCES[@]}" \
  "${PKG_OBJECTS[@]}"

echo "$OUT"
