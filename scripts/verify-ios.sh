#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

APP_DIR=".worktrees/filmtone-ios-phase0/apps/capacitor-film-lab-ios"

if [ -d "/opt/homebrew/opt/ruby/bin" ]; then
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
fi

echo "==> ios build"
bun run --cwd "$APP_DIR" build

echo "==> ios cap sync"
bun run --cwd "$APP_DIR" cap:sync:ios

echo "==> ios swift contract"
bun run --cwd "$APP_DIR" verify:swift-contract
