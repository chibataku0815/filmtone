#!/usr/bin/env bash
# package-dmg.sh — wrap a notarized FilmtoneDesktop.app in a signed,
# notarized, stapled DMG ready for public distribution.
#
# Usage:
#   ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_PATH=... \
#     scripts/package-dmg.sh [VERSION] [OUTPUT_DIR]
#
# Defaults match release-macos.sh: VERSION = MARKETING_VERSION,
# OUTPUT_DIR = apps/filmtone-desktop-macos/build/release/<version>.
#
# Pre-condition:
#   $OUTPUT_DIR/FilmtoneDesktop.app exists, is notarized + stapled
#   (release-macos.sh produces this).
#
# Pipeline:
#   1. Stage .app + Applications symlink in a clean dir
#   2. hdiutil create UDZO DMG
#   3. codesign the DMG with Developer ID Application
#   4. notarytool submit DMG --wait
#   5. stapler staple DMG
#   6. spctl --assess --type open --context context:primary-signature
#
# Output:
#   $OUTPUT_DIR/FilmtoneDesktop-<version>.dmg  (notarized + stapled)

set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APP_DIR="$REPO_ROOT/apps/filmtone-desktop-macos"
readonly PROJECT="$APP_DIR/FilmtoneDesktop.xcodeproj"
readonly APP_NAME="FilmtoneDesktop"
readonly TEAM_ID="C3G77H8NM6"
readonly SIGN_IDENTITY="Developer ID Application: takumi chiba ($TEAM_ID)"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
err() { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }

read_marketing_version() {
    grep -m1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" \
        | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' \
        | tr -d ' '
}

VERSION="${1:-$(read_marketing_version)}"
OUTPUT_DIR_ARG="${2:-}"
OUTPUT_DIR="${OUTPUT_DIR_ARG:-$APP_DIR/build/release/$VERSION}"

[[ -n "${ASC_KEY_ID:-}" ]] || err "ASC_KEY_ID required"
[[ -n "${ASC_ISSUER_ID:-}" ]] || err "ASC_ISSUER_ID required"
[[ -n "${ASC_KEY_PATH:-}" ]] || err "ASC_KEY_PATH required"

ASC_KEY_PATH_ABS="$(cd "$(dirname "$ASC_KEY_PATH")" && pwd)/$(basename "$ASC_KEY_PATH")"
[[ -f "$ASC_KEY_PATH_ABS" ]] || err "ASC API key not found at $ASC_KEY_PATH_ABS"

readonly APP_PATH="$OUTPUT_DIR/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || err "$APP_PATH not found — run scripts/release-macos.sh first"

readonly STAGE_DIR="$OUTPUT_DIR/dmg-stage"
readonly DMG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"
readonly DMG_SUBMISSION_JSON="$OUTPUT_DIR/notarize-dmg-submission.json"

log "Version:    $VERSION"
log "Source app: $APP_PATH"
log "Target DMG: $DMG_PATH"

# --- 1. stage ---

log "1/6 stage .app + Applications symlink"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
ditto "$APP_PATH" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"

# --- 2. hdiutil create ---

log "2/6 hdiutil create"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "Filmtone Desktop $VERSION" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

# --- 3. codesign DMG ---

log "3/6 codesign DMG"
codesign \
    --sign "$SIGN_IDENTITY" \
    --timestamp \
    "$DMG_PATH"

# --- 4. notarize DMG ---

log "4/6 notarytool submit DMG --wait"
xcrun notarytool submit "$DMG_PATH" \
    --key "$ASC_KEY_PATH_ABS" \
    --key-id "$ASC_KEY_ID" \
    --issuer "$ASC_ISSUER_ID" \
    --output-format json \
    --wait \
    >"$DMG_SUBMISSION_JSON" \
    || { cat "$DMG_SUBMISSION_JSON" >&2; err "DMG notarize failed"; }

STATUS="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$DMG_SUBMISSION_JSON")"
if [[ "$STATUS" != "Accepted" ]]; then
    SUBMISSION_ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$DMG_SUBMISSION_JSON")"
    xcrun notarytool log "$SUBMISSION_ID" \
        --key "$ASC_KEY_PATH_ABS" \
        --key-id "$ASC_KEY_ID" \
        --issuer "$ASC_ISSUER_ID" \
        "$OUTPUT_DIR/notarize-dmg-rejection.json" || true
    err "DMG notarize status: $STATUS"
fi

# --- 5. staple DMG ---

log "5/6 stapler staple DMG"
xcrun stapler staple "$DMG_PATH"

# --- 6. Gatekeeper assess ---

log "6/6 spctl --assess --type open"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

# Cleanup staging.
rm -rf "$STAGE_DIR"

log "OK: $DMG_PATH (notarized + stapled, distribution-ready)"
log "    Size: $(du -h "$DMG_PATH" | awk '{print $1}')"
