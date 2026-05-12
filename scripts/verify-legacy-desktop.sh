#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

echo "==> typecheck:legacy-desktop (report-only)"
if ! bun run typecheck:legacy-desktop; then
  echo "typecheck:legacy-desktop reported existing issues; continuing because this rail is report-only."
fi

echo "==> typecheck:shared"
bun run typecheck:shared

echo "==> legacy desktop narrow smoke"
bun run --cwd apps/desktop-film-lab-batch test:smart-look-pending
