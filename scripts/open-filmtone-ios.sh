#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${REPO_ROOT}/apps/capacitor-film-lab-ios"
WORKSPACE_PATH="${APP_DIR}/ios/App/App.xcworkspace"

cd "${REPO_ROOT}"

echo "[filmtone-ios] Building web shell"
bun run build:ios

echo "[filmtone-ios] Syncing Capacitor iOS shell"
bun run --cwd "${APP_DIR}" cap:sync:ios

echo "[filmtone-ios] Opening Xcode workspace"
open "${WORKSPACE_PATH}"

cat <<EOF

Filmtone iOS is ready for device validation.

Workspace:
${WORKSPACE_PATH}

Next:
1. Select the same successful iPhone 15+ if available.
2. Run the app on device.
3. Use one fixed exact 60-second segment trimmed from the known-good 4m29s source clip.
4. Keep the run at preset + creative LUT.
5. Complete: import -> preview -> export -> save to Photos.
6. Inspect the exported file at the start, middle, and end.
7. Treat 60s <= 2.5x realtime as pass, and <= 2.0x as strong-go.
8. Report the result in this chat.

Historical v1.0 checklist:
${APP_DIR}/IOS-DEVICE-CHECKLIST.md
EOF
