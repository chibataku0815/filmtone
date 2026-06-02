#!/usr/bin/env bash
# check-pad-route.sh — M7 Drift Guard.
#
# Asserts that the normal `App-iPad` root path cannot mount the
# forbidden iPhone product surfaces named in the iPad Desktop Edition
# strategy:
#   - FilmtoneOnboardingView
#   - FilmtoneEmptyView
#   - FilmtoneFullscreenLutEditor
#   - FilmtoneSourceProfileSheet
#   - FilmtoneStrengthSheet
#
# Approach: static text guard.
#   1. The iPad route in `FilmtoneRootView.swift` lives between the
#      `// MARK: iPad route` marker and the `// MARK: iPhone route`
#      marker. Extract that block and ensure none of the forbidden
#      symbols appear inside it.
#   2. Every file under `ios/App/App/Editor/Pad/` must also be free of
#      references to the forbidden symbols.
#
# Exits non-zero on any match, printing the matched line so CI logs
# point at the regression.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_FILE="$REPO_ROOT/ios/App/App/Root/FilmtoneRootView.swift"
PAD_DIR="$REPO_ROOT/ios/App/App/Editor/Pad"

FORBIDDEN=(
  "FilmtoneOnboardingView"
  "FilmtoneEmptyView"
  "FilmtoneFullscreenLutEditor"
  "FilmtoneSourceProfileSheet"
  "FilmtoneStrengthSheet"
)

if [[ ! -f "$ROOT_FILE" ]]; then
  echo "check-pad-route: missing $ROOT_FILE" >&2
  exit 2
fi

# Extract the iPad route block. Use awk so the markers are anchored
# uniquely (they live inside `// MARK: iPad route` / `// MARK: iPhone
# route` comments authored by M7).
ipad_block=$(awk '
  /^[[:space:]]*\/\/ MARK: iPad route/ { capture = 1 }
  capture { print }
  /^[[:space:]]*\/\/ MARK: iPhone route/ && capture { capture = 0; exit }
' "$ROOT_FILE")

if [[ -z "$ipad_block" ]]; then
  echo "check-pad-route: failed to extract iPad route block from $ROOT_FILE" >&2
  echo "  expected '// MARK: iPad route' followed by '// MARK: iPhone route'" >&2
  exit 2
fi

# Strip Swift line-comment-only and triple-slash-doc lines before grep
# so authors can name the forbidden symbols in MARK / doc commentary
# without the guard mistaking documentation for a real reference. The
# guard still catches real Swift code (`FilmtoneEmptyView(...)`,
# `.sheet(...) { FilmtoneOnboardingView(...) }`, type references in
# parameter lists, member access like `FilmtoneStrengthSheet.foo`).
strip_comments() {
  # Drop everything from `//` to end-of-line. This naive strip is
  # accurate enough: Swift `//` cannot appear inside strings without
  # being escaped or split, and the forbidden symbols are not used as
  # string literals anywhere in the iPad route.
  sed -E 's@//.*$@@'
}

failures=0
for symbol in "${FORBIDDEN[@]}"; do
  # iPad route block in FilmtoneRootView
  matches=$(echo "$ipad_block" | strip_comments | grep -nE "\b${symbol}\b" || true)
  if [[ -n "$matches" ]]; then
    echo "check-pad-route: FORBIDDEN symbol '$symbol' present in iPad route block of FilmtoneRootView.swift" >&2
    echo "$matches" >&2
    failures=$((failures + 1))
  fi
  # Editor/Pad/ tree
  pad_matches=""
  while IFS= read -r -d '' file; do
    file_match=$(strip_comments < "$file" | grep -nE "\b${symbol}\b" || true)
    if [[ -n "$file_match" ]]; then
      while IFS= read -r line; do
        pad_matches+="$file:$line"$'\n'
      done <<< "$file_match"
    fi
  done < <(find "$PAD_DIR" -type f -name '*.swift' -print0)
  if [[ -n "$pad_matches" ]]; then
    echo "check-pad-route: FORBIDDEN symbol '$symbol' present in Editor/Pad/" >&2
    printf '%s' "$pad_matches" >&2
    failures=$((failures + 1))
  fi
done

if (( failures > 0 )); then
  echo "" >&2
  echo "check-pad-route: $failures forbidden-symbol violation(s) detected." >&2
  echo "  See docs/filmtone/ios/ipad-desktop-edition/strategy.md §Drift Guard." >&2
  exit 1
fi

echo "check-pad-route: PASS — iPad route is free of forbidden iPhone surfaces."
