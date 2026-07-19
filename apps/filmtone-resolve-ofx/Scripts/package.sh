#!/bin/sh
# MON-5 packaging recipe (implementation-plan.md §6). Signs the OFX bundle with a
# Developer ID Application identity, builds a Developer ID Installer-signed .pkg,
# notarizes it, and staples the ticket. Fixed signing order: inner bundle first,
# then the outer pkg.
#
# The signing identities and notary credential are YOURS and stay in YOUR
# keychain — this script only references them by name; it never sees the secrets.
#
# Usage:
#   SIGN_APP="Developer ID Application: <Name> (<TEAMID>)" \
#   SIGN_INSTALLER="Developer ID Installer: <Name> (<TEAMID>)" \
#   NOTARY_PROFILE="<notarytool-keychain-profile>" \
#   sh apps/filmtone-resolve-ofx/Scripts/package.sh
#
# Prepare the notary profile once:
#   xcrun notarytool store-credentials <NOTARY_PROFILE> \
#     --apple-id <you@apple.id> --team-id <TEAMID> --password <app-specific-pw>
set -e
cd "$(dirname "$0")/.."   # -> apps/filmtone-resolve-ofx

VER="$(sed -n 's/^FILMTONE_RESOLVE_MARKETING_VERSION := //p' Resources/ProductVersion.mk)"
BUNDLE="build/Filmtone.ofx.bundle"
PKG="build/Filmtone-$VER.pkg"

: "${SIGN_APP:?set SIGN_APP to your 'Developer ID Application: ...' identity}"
: "${SIGN_INSTALLER:?set SIGN_INSTALLER to your 'Developer ID Installer: ...' identity}"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE to your notarytool keychain profile}"

echo "== 1. build + sign the OFX bundle (hardened runtime + secure timestamp) =="
make sign-bundle SIGN_IDENTITY="$SIGN_APP"
codesign --verify --deep --strict --verbose=2 "$BUNDLE"

echo "== 2. build the .pkg and sign it (Developer ID Installer) =="
rm -f build/raw.pkg "$PKG"
pkgbuild --component "$BUNDLE" \
  --install-location "/Library/OFX/Plugins" \
  --identifier com.chibatakumi.filmtone.resolve.pkg \
  --version "$VER" build/raw.pkg
productbuild --package build/raw.pkg --sign "$SIGN_INSTALLER" "$PKG"
pkgutil --check-signature "$PKG"

echo "== 3. notarize + staple =="
xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$PKG"
xcrun stapler validate "$PKG"

echo "== done: $PKG (signed, notarized, stapled) =="
