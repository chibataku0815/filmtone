#!/bin/sh
# MON-2 canonical-parity + adversarial-vector cross-verification.
# Generates envelopes + authoritative verdicts from the TS core.ts reference,
# then confirms the C++ LicenseStore::evaluateBytes() reproduces every verdict.
#
# Requires: bun, clang/clang++ (macOS), and ~/.filmtone/secrets/*.key.json whose
# public keys match apps/filmtone-resolve-ofx/Sources/License/PublicKeys.h.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
LIC="$DIR/../../../apps/filmtone-resolve-ofx/Sources/License"
BUILD="$DIR/build"
mkdir -p "$BUILD"

echo "== 1. generate vectors (TS core.ts reference verdicts) =="
bun run "$DIR/gen_vectors.ts" "$BUILD/vectors.json"

echo "== 2. compile C++ harness (LicenseStore + vendored ed25519) =="
for c in fe ge sc sha512 verify; do
  clang -std=c11 -O2 -c "$LIC/vendor/ed25519/$c.c" -o "$BUILD/$c.o"
done
clang++ -std=c++17 -O2 -I"$LIC" -c "$LIC/LicenseStore.mm" -o "$BUILD/LicenseStore.o"
clang++ -std=c++17 -O2 -I"$LIC" -c "$DIR/harness.mm" -o "$BUILD/harness.o"
clang++ "$BUILD"/*.o -framework Foundation -o "$BUILD/harness"

echo "== 3. run cross-verification (C++ must match TS on every vector) =="
"$BUILD/harness" "$BUILD/vectors.json"
