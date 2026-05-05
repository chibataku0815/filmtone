#!/usr/bin/env bash
# release-macos.sh — build / sign / notarize / staple FilmtoneDesktop.app
#
# Usage:
#   ASC_KEY_ID=... ASC_ISSUER_ID=... \
#     ASC_KEY_PATH=... | ASC_KEY_CONTENT=... \
#     scripts/release-macos.sh [VERSION] [OUTPUT_DIR]
#
# Defaults:
#   VERSION    = MARKETING_VERSION read from project.pbxproj
#   OUTPUT_DIR = apps/filmtone-desktop-macos/build/release/<version>
#
# ASC API key env (matches iOS Fastfile pattern):
#   ASC_KEY_CONTENT — raw .p8 content, "\n" literal escapes accepted (CI flow)
#   ASC_KEY_PATH    — file path to .p8 (local dev flow)
#   At least one of the two must be set.
#
# Requirements:
#   - Developer ID Application cert in keychain (Team C3G77H8NM6)
#   - Xcode 16+ (notarytool, xcodebuild)
#
# Pipeline:
#   1. xcodebuild archive (Release, Manual signing pinned to Developer ID)
#   2. xcodebuild -exportArchive (developer-id export method)
#   3. Wrap exported .app in a zip for notarytool
#   4. xcrun notarytool submit --wait (fail-fast on rejection)
#   5. xcrun stapler staple FilmtoneDesktop.app
#   6. spctl --assess to verify Gatekeeper accepts the stapled bundle
#
# Output:
#   $OUTPUT_DIR/FilmtoneDesktop.app                 (notarized + stapled)
#   $OUTPUT_DIR/FilmtoneDesktop.xcarchive
#   $OUTPUT_DIR/FilmtoneDesktop.notarize.zip
#   $OUTPUT_DIR/notarize-submission.json
#   $OUTPUT_DIR/build.log
#
# DMG packaging is handled by package-dmg.sh (M6-4).

set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APP_DIR="$REPO_ROOT/apps/filmtone-desktop-macos"
readonly PROJECT="$APP_DIR/FilmtoneDesktop.xcodeproj"
readonly EXPORT_OPTIONS="$APP_DIR/ExportOptions.plist"
readonly SCHEME="FilmtoneDesktop"
readonly APP_NAME="Filmtone"
readonly BUNDLE_ID="com.chibatakumi.film-lab-desktop"
readonly TEAM_ID="C3G77H8NM6"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
err() { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }

# --- args + env ---

read_marketing_version() {
    grep -m1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" \
        | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' \
        | tr -d ' '
}

# Resolve the App Store Connect API key (.p8) to an absolute file path.
# Mirrors iOS Fastfile (asc_api_key_configured? + resolve_asc_key_file_path!).
#   ASC_KEY_CONTENT — raw key content with optional "\n" escapes
#       → write to mktemp 0600, register cleanup trap, set ASC_KEY_PATH_ABS
#   ASC_KEY_PATH    — file path; "~/" expanded, resolved to absolute
# Note: returns via the global ASC_KEY_PATH_ABS so the EXIT trap survives in
# the parent shell. Capturing via $(...) would discard the trap when the
# command substitution subshell exits, deleting the temp key prematurely.
resolve_asc_key_path() {
    if [[ -n "${ASC_KEY_CONTENT:-}" ]]; then
        local tmp
        tmp="$(mktemp -t filmtone-asc-key.XXXXXX)"
        # Mirror iOS Fastfile: convert literal "\n" sequences to real newlines.
        printf '%s' "$ASC_KEY_CONTENT" | sed $'s/\\\\n/\\\n/g' >"$tmp"
        chmod 600 "$tmp"
        # shellcheck disable=SC2064
        trap "rm -f '$tmp'" EXIT
        ASC_KEY_PATH_ABS="$tmp"
        return
    fi

    if [[ -n "${ASC_KEY_PATH:-}" ]]; then
        local expanded="${ASC_KEY_PATH/#\~\//$HOME/}"
        [[ -f "$expanded" ]] || err "ASC API key not found at $expanded"
        ASC_KEY_PATH_ABS="$(cd "$(dirname "$expanded")" && pwd)/$(basename "$expanded")"
        return
    fi

    err "Set either ASC_KEY_CONTENT or ASC_KEY_PATH"
}

# Pre-flight: confirm Developer ID Application cert is in keychain so we
# fail in 1 second instead of after a multi-minute archive.
preflight_signing_cert() {
    if ! security find-identity -v -p codesigning 2>/dev/null \
        | grep -F "Developer ID Application: takumi chiba ($TEAM_ID)" \
        >/dev/null
    then
        err "Developer ID Application cert (Team $TEAM_ID) not found in keychain"
    fi
}

VERSION="${1:-$(read_marketing_version)}"
OUTPUT_DIR_ARG="${2:-}"
OUTPUT_DIR="${OUTPUT_DIR_ARG:-$APP_DIR/build/release/$VERSION}"

[[ -n "${ASC_KEY_ID:-}" ]] || err "ASC_KEY_ID required"
[[ -n "${ASC_ISSUER_ID:-}" ]] || err "ASC_ISSUER_ID required"

ASC_KEY_PATH_ABS=""
resolve_asc_key_path
preflight_signing_cert

# --- prep ---

mkdir -p "$OUTPUT_DIR"
readonly ARCHIVE_PATH="$OUTPUT_DIR/$APP_NAME.xcarchive"
readonly EXPORT_PATH="$OUTPUT_DIR/export"
readonly APP_PATH="$EXPORT_PATH/$APP_NAME.app"
readonly NOTARIZE_ZIP="$OUTPUT_DIR/$APP_NAME.notarize.zip"
readonly BUILD_LOG="$OUTPUT_DIR/build.log"
readonly SUBMISSION_JSON="$OUTPUT_DIR/notarize-submission.json"

log "Version: $VERSION"
log "Output:  $OUTPUT_DIR"

# --- 1. archive ---

log "1/6 archive (Release, Developer ID)"
rm -rf "$ARCHIVE_PATH"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    archive \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    >"$BUILD_LOG" 2>&1 \
    || { tail -50 "$BUILD_LOG" >&2; err "archive failed (full log: $BUILD_LOG)"; }

# --- 2. exportArchive ---

log "2/6 exportArchive (developer-id)"
rm -rf "$EXPORT_PATH"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    >>"$BUILD_LOG" 2>&1 \
    || { tail -50 "$BUILD_LOG" >&2; err "exportArchive failed (full log: $BUILD_LOG)"; }

[[ -d "$APP_PATH" ]] || err "exportArchive did not produce $APP_PATH"

# --- 3. zip for notarytool ---

log "3/6 zip for notarytool"
rm -f "$NOTARIZE_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

# --- 4. notarize ---

log "4/6 notarytool submit --wait (this can take several minutes)"
xcrun notarytool submit "$NOTARIZE_ZIP" \
    --key "$ASC_KEY_PATH_ABS" \
    --key-id "$ASC_KEY_ID" \
    --issuer "$ASC_ISSUER_ID" \
    --output-format json \
    --wait \
    >"$SUBMISSION_JSON" \
    || { cat "$SUBMISSION_JSON" >&2; err "notarytool submission failed"; }

STATUS="$(/usr/bin/plutil -extract status raw -o - "$SUBMISSION_JSON" 2>/dev/null \
    || python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$SUBMISSION_JSON")"

if [[ "$STATUS" != "Accepted" ]]; then
    SUBMISSION_ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$SUBMISSION_JSON")"
    log "fetching rejection log for submission $SUBMISSION_ID"
    xcrun notarytool log "$SUBMISSION_ID" \
        --key "$ASC_KEY_PATH_ABS" \
        --key-id "$ASC_KEY_ID" \
        --issuer "$ASC_ISSUER_ID" \
        "$OUTPUT_DIR/notarize-rejection.json" || true
    err "notarize status: $STATUS (see $OUTPUT_DIR/notarize-rejection.json)"
fi

# --- 5. staple ---

log "5/6 stapler staple"
xcrun stapler staple "$APP_PATH"

# --- 6. spctl assess ---

log "6/6 spctl --assess"
spctl --assess --type execute --verbose=4 "$APP_PATH" 2>&1 | tee -a "$BUILD_LOG"

# Move the stapled .app to OUTPUT_DIR root so DMG packaging picks it up
# without needing to know about the export/ subdirectory.
rm -rf "$OUTPUT_DIR/$APP_NAME.app"
mv "$APP_PATH" "$OUTPUT_DIR/$APP_NAME.app"

log "OK: $OUTPUT_DIR/$APP_NAME.app (notarized + stapled, Team $TEAM_ID)"
log "    Bundle ID: $BUNDLE_ID"
log "    Next: scripts/package-dmg.sh $VERSION $OUTPUT_DIR"
