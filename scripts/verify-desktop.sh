#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

echo "==> verify:desktop (native macOS app)"
bun run verify:macos
