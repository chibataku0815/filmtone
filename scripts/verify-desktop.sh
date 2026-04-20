#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

echo "==> typecheck:desktop (report-only)"
if ! bun run typecheck:desktop; then
  echo "typecheck:desktop reported existing issues; continuing because this rail is report-only."
fi

echo "==> typecheck:shared"
bun run typecheck:shared

echo "==> desktop narrow smoke"
bun run --cwd apps/desktop-film-lab-batch test:smart-look-pending
