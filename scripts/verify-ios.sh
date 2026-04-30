#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

APP_DIR="apps/capacitor-film-lab-ios"

if [ -d "/opt/homebrew/opt/ruby/bin" ]; then
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
fi

echo "==> generated swift contract (drift check)"
bun run generate:ios-swift --check

echo "==> ios build"
bun run --cwd "$APP_DIR" build

echo "==> ios cap sync"
bun run --cwd "$APP_DIR" cap:sync:ios

echo "==> ios swift contract"
bun run --cwd "$APP_DIR" verify:swift-contract
