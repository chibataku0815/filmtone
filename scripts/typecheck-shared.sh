#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

bun run --cwd packages/film-lab-core tsc -p tsconfig.typecheck.json --noEmit
bun run --cwd packages/film-lab-renderer tsc -p tsconfig.typecheck.json --noEmit
bun run --cwd packages/film-lab-ui tsc -p tsconfig.typecheck.json --noEmit
