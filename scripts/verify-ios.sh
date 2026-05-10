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
xcodebuild -quiet \
  -workspace "$APP_DIR/ios/App/App.xcworkspace" \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build \
  CODE_SIGNING_ALLOWED=NO

echo "==> ios swift contract"
bun run --cwd "$APP_DIR" verify:swift-contract
