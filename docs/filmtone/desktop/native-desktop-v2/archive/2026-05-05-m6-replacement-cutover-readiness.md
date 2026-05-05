# M6 Replacement Cutover Readiness

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

## Milestone

M6 Release Cutover

## Goal

Prepare the Native Desktop v2 replacement path so the legacy Electron Desktop
rail can be switched over intentionally once the remaining product gates are
closed. This task was preparation only; it did not publish, upload to
production, notarize a public release, push, or archive the Electron workspace.

## Result

- Added a replacement readiness runbook:
  `docs/filmtone/desktop/release-cutover/2026-05-05-native-v2-replacement-readiness.md`.
- Added a Native Desktop v1.4 release notes draft:
  `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.4.md`.
- Added read-only cutover preflight:
  `scripts/release-cutover-preflight.mjs`.
- Added package script:
  `bun run release:cutover-preflight`.
- Corrected release script comments for the cutover artifact names
  `Filmtone.app` and `Filmtone-1.4.dmg`.
- Corrected upload-script guidance so production reruns include
  `--confirm-prod --sync-vercel-env`.
- Updated release-cutover docs and Native v2 strategy with the replacement
  readiness state and explicit product gates.

## Checklist

- [x] Reconcile current public Desktop / iOS truth for replacement planning.
- [x] Add a replacement readiness document with gates, run order, rollback, and
      non-goals.
- [x] Draft Native Desktop v1.4 release notes with macOS 26 and legacy Desktop
      messaging.
- [x] Harden dry-run / production-upload command guidance so cutover upload
      steps cannot be followed incorrectly.
- [x] Add a local cutover preflight check if it materially reduces release
      operator error.
- [x] Update release-cutover docs with the new readiness state.
- [x] Run focused verification.

## Verification

- `bun run release:cutover-preflight` passed with no blocking failures.
  Expected warning: `Filmtone-1.4.dmg` is not built yet.
- `git diff --check` passed.

Broader `bun run verify:macos` was not run because this task changed
documentation, release scripts, and package script wiring only. No Swift/Xcode
product files were changed.

## Done Conditions

- [x] The old Desktop replacement path has a concrete public cutover checklist.
- [x] The checklist states exactly when production Blob/update-meta writes are
      allowed.
- [x] Native Desktop v1.4 release notes draft exists.
- [x] Dry-run/preflight commands verify identity/version/artifact expectations
      without writing production state.
- [x] Remaining product gates are explicit rather than hidden.

## Remaining Product Gates

Public update-meta must stay on Desktop `1.0.4` until these are closed or the
user explicitly defers each one:

- Source Auto / Conversion LUT parity.
- Backlight Veil parity.
- Advanced recipe chip discoverability (`None` / `Default` / `Strong`;
  Japanese `なし` / `標準` / `強め`).

## Out Of Scope

- Shipping a public release.
- Running notarization or production Blob upload.
- Pushing, tagging, staging, or committing.
- Implementing Source Auto, Backlight Veil, or Advanced Recipe Chip parity.
- Archiving or deleting the legacy Electron workspace.

## Unexpected Blockers

- None.
