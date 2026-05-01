#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/load-release-env.sh
. "${script_dir}/load-release-env.sh"

if command -v brew >/dev/null 2>&1; then
  ruby_prefix="$(brew --prefix ruby 2>/dev/null || true)"
  if [ -n "${ruby_prefix}" ] && [ -x "${ruby_prefix}/bin/bundle" ]; then
    export PATH="${ruby_prefix}/bin:${PATH}"
  fi
fi

if ! command -v bundle >/dev/null 2>&1; then
  echo "bundle was not found. Install Homebrew ruby or another managed Ruby with Bundler." >&2
  exit 1
fi

exec bundle "$@"
