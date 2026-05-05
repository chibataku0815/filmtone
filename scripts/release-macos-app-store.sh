#!/usr/bin/env bash
# release-macos-app-store.sh — build/export a sandboxed Filmtone archive for
# Mac App Store validation or later upload. This does not upload metadata,
# submit for review, notarize, package a DMG, or touch the public update rail.
#
# Usage:
#   ASC_KEY_ID=... ASC_ISSUER_ID=... \
#     ASC_KEY_PATH=... | ASC_KEY_CONTENT=... \
#     scripts/release-macos-app-store.sh [VERSION] [OUTPUT_DIR]
#
# Defaults:
#   VERSION    = MARKETING_VERSION read from project.pbxproj
#   OUTPUT_DIR = apps/filmtone-desktop-macos/build/app-store/<version>
#
# Set FILMTONE_MAS_ARCHIVE_ONLY=1 to stop after the signed sandbox archive.
# The archive is development-signed by default so sandbox entitlements are
# materialized locally; app-store-connect export re-signs for distribution.

set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APP_DIR="$REPO_ROOT/apps/filmtone-desktop-macos"
readonly PROJECT="$APP_DIR/FilmtoneDesktop.xcodeproj"
readonly EXPORT_OPTIONS="$APP_DIR/ExportOptionsAppStore.plist"
readonly ENTITLEMENTS="FilmtoneDesktop/FilmtoneDesktopAppStore.entitlements"
readonly SCHEME="FilmtoneDesktop"
readonly APP_NAME="Filmtone"
readonly BUNDLE_ID="com.chibatakumi.film-lab-desktop"
readonly TEAM_ID="C3G77H8NM6"
readonly ARCHIVE_SIGN_IDENTITY="${FILMTONE_MAS_ARCHIVE_CODE_SIGN_IDENTITY:-Apple Development}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*" >&2; }
err() { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }

read_marketing_version() {
    grep -m1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" \
        | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' \
        | tr -d ' '
}

asc_api_key_configured() {
    [[ -n "${ASC_KEY_ID:-}" ]] &&
        [[ -n "${ASC_ISSUER_ID:-}" ]] &&
        { [[ -n "${ASC_KEY_CONTENT:-}" ]] || [[ -n "${ASC_KEY_PATH:-}" ]]; }
}

resolve_asc_key_path() {
    if [[ -n "${ASC_KEY_CONTENT:-}" ]]; then
        local tmp
        tmp="$(mktemp -t filmtone-asc-key.XXXXXX)"
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
}

preflight() {
    [[ -f "$EXPORT_OPTIONS" ]] || err "missing $EXPORT_OPTIONS"
    [[ -f "$APP_DIR/$ENTITLEMENTS" ]] || err "missing $APP_DIR/$ENTITLEMENTS"

    if ! xcodebuild -help 2>&1 | grep -F "app-store-connect" >/dev/null; then
        err "this Xcode does not advertise app-store-connect export support"
    fi

    if ! security find-identity -v -p codesigning 2>/dev/null \
        | grep -E "Apple Distribution:|Mac App Distribution:" >/dev/null
    then
        warn "No local Apple Distribution/Mac App Distribution identity found. Automatic signing may still create or fetch signing assets with -allowProvisioningUpdates."
    fi
}

verify_archived_app() {
    local app_path="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
    [[ -d "$app_path" ]] || err "archive did not produce $app_path"

    local signature_info
    signature_info="$(codesign -dv "$app_path" 2>&1 || true)"
    if grep -F "Signature=adhoc" <<<"$signature_info" >/dev/null; then
        err "archive is ad-hoc signed; sandbox entitlements were not materialized"
    fi
    if grep -F "TeamIdentifier=not set" <<<"$signature_info" >/dev/null; then
        err "archive has no TeamIdentifier; configure Xcode Accounts or ASC key auth"
    fi

    local entitlements
    entitlements="$(mktemp -t filmtone-mas-entitlements.XXXXXX.plist)"
    trap "rm -f '$entitlements'" RETURN
    codesign -d --entitlements :- "$app_path" >"$entitlements" 2>/dev/null \
        || err "archive has no readable entitlements"

    local sandbox
    sandbox="$(/usr/libexec/PlistBuddy -c "Print :com.apple.security.app-sandbox" "$entitlements" 2>/dev/null || true)"
    [[ "$sandbox" == "true" ]] || err "archive is missing com.apple.security.app-sandbox=true"

    local user_files
    user_files="$(/usr/libexec/PlistBuddy -c "Print :com.apple.security.files.user-selected.read-write" "$entitlements" 2>/dev/null || true)"
    [[ "$user_files" == "true" ]] || err "archive is missing user-selected read-write file access"
}

VERSION="${1:-$(read_marketing_version)}"
OUTPUT_DIR_ARG="${2:-}"
OUTPUT_DIR="${OUTPUT_DIR_ARG:-$APP_DIR/build/app-store/$VERSION}"

ASC_KEY_PATH_ABS=""
XCODEBUILD_AUTH_ARGS=(-allowProvisioningUpdates)
if asc_api_key_configured; then
    resolve_asc_key_path
    XCODEBUILD_AUTH_ARGS+=(
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
        -authenticationKeyID "$ASC_KEY_ID"
        -authenticationKeyPath "$ASC_KEY_PATH_ABS"
    )
else
    warn "ASC API key env is not set; xcodebuild will rely on Xcode Accounts automatic signing."
fi

preflight

mkdir -p "$OUTPUT_DIR"
readonly ARCHIVE_PATH="$OUTPUT_DIR/$APP_NAME.xcarchive"
readonly EXPORT_PATH="$OUTPUT_DIR/export"
readonly BUILD_LOG="$OUTPUT_DIR/build.log"

log "Version: $VERSION"
log "Output:  $OUTPUT_DIR"
log "Bundle:  $BUNDLE_ID"
log "Archive signing: $ARCHIVE_SIGN_IDENTITY"

log "1/2 archive (Release, Mac App Store sandbox)"
rm -rf "$ARCHIVE_PATH"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    "${XCODEBUILD_AUTH_ARGS[@]}" \
    archive \
    CODE_SIGN_STYLE=Automatic \
    CODE_SIGN_IDENTITY="$ARCHIVE_SIGN_IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS" \
    >"$BUILD_LOG" 2>&1 \
    || { tail -80 "$BUILD_LOG" >&2; err "archive failed (full log: $BUILD_LOG)"; }

verify_archived_app

if [[ "${FILMTONE_MAS_ARCHIVE_ONLY:-0}" == "1" ]]; then
    log "OK: $ARCHIVE_PATH (archive only)"
    exit 0
fi

log "2/2 exportArchive (app-store-connect)"
rm -rf "$EXPORT_PATH"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    "${XCODEBUILD_AUTH_ARGS[@]}" \
    >>"$BUILD_LOG" 2>&1 \
    || { tail -80 "$BUILD_LOG" >&2; err "exportArchive failed (full log: $BUILD_LOG)"; }

EXPORTED_PRODUCTS=()
while IFS= read -r product_path; do
    EXPORTED_PRODUCTS+=("$product_path")
done < <(find "$EXPORT_PATH" -maxdepth 1 \( -name "*.pkg" -o -name "*.app" -o -name "*.ipa" \) -print)
if [[ "${#EXPORTED_PRODUCTS[@]}" -eq 0 ]]; then
    find "$EXPORT_PATH" -maxdepth 2 -print >&2 || true
    err "exportArchive did not produce an App Store export product"
fi

log "OK: Mac App Store export product(s):"
printf '    %s\n' "${EXPORTED_PRODUCTS[@]}" >&2
