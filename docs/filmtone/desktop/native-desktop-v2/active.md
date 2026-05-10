# Active - Native Desktop v1.6 Release

Date opened: 2026-05-06 JST
Milestone: `M8 Native Desktop v1.6 Release`

## Goal

Ship Native Desktop v1.6 as a focused follow-up to the already-public Desktop
v1.5. The release must include the M8 right-rail bottom extension and lower-half
hit dead-zone fix, plus the user-approved UI deltas that are already in the
working tree: empty-state CTA strip-down / media-derived loaded backdrop and
conditional Backlight Veil Intensity row mounting.

Primary public exit: signed, notarized, stapled Developer ID DMG uploaded to
the fixed Desktop download rail, with update metadata reporting `1.6`.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.6.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- this `active.md`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/2026-05-06-v1-6-release-handoff.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m7-native-desktop-v1-5-release.md`
- `docs/filmtone/desktop/release-cutover/README.md`

## Checklist

- [x] Confirm release truth scripts and current git state.
- [x] Confirm v1.6 scope includes the working-tree UI deltas.
- [x] Bump Native Desktop marketing version to `1.6` and build number to `3`.
- [x] Add v1.6 release notes covering right-rail reachability, hit testing,
  empty-state simplification, loaded backdrop, and Intensity row behavior.
- [x] Run local product/release verification:
  `bash apps/filmtone-desktop-macos/Verify/run.sh`,
  `bun run verify:macos`, `bun run release:cutover-preflight`,
  `git diff --check`.
- [x] Build/sign/notarize/staple `Filmtone.app` with `scripts/release-macos.sh`.
- [x] Package/sign/notarize/staple `Filmtone-1.6.dmg` with
  `scripts/package-dmg.sh`.
- [x] Verify DMG checksum and local release truth.
- [ ] Upload DMG to Vercel Blob and sync the fixed download URL after explicit
  public-upload confirmation.
- [ ] Upload update metadata with `latestVersion: "1.6"` after explicit
  public-update confirmation.
- [ ] Verify public download/update truth.
- [ ] Archive this task and append a short completion note to `strategy.md`.

## Verification

2026-05-06 JST:

- Release truth reports local Native Desktop `1.6` build `3`, public Desktop
  latest `1.5`, and v1.6 release notes present.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed (`121/121`).
- `bun run verify:macos` passed (`** BUILD SUCCEEDED **`).
- `bun run release:cutover-preflight` passed before packaging; expected warning
  only that `Filmtone-1.6.dmg` was not built yet.
- `git diff --check` passed.
- `scripts/release-macos.sh` passed; `Filmtone.app` is signed, notarized,
  stapled, and Gatekeeper accepted as Notarized Developer ID.
- `scripts/package-dmg.sh` passed; `Filmtone-1.6.dmg` is signed, notarized,
  stapled, and Gatekeeper accepted as Notarized Developer ID.
- `Filmtone-1.6.dmg` sha256:
  `5437abbc2aa7a01ee0d1d5a8f9a23945d5d3cabbae60916ca2a19eaafad0fa94`.
- `bun run release:cutover-preflight` passed again after the DMG existed.
- Mounted DMG check passed: `Filmtone.app` exists, Applications symlink exists,
  Bundle ID is `com.chibatakumi.film-lab-desktop`, short version is `1.6`,
  build version is `3`, and the mounted app is Gatekeeper accepted.

## Done Conditions

- Native Desktop release truth reports local Desktop `1.6` build `3`.
- Public Desktop release truth reports latest `1.6`.
- The fixed public download rail resolves to `Filmtone-1.6.dmg`.
- The release artifact is signed, notarized, stapled, and Gatekeeper accepted.
- Local release notes and strategy record the release outcome.

## Stop Conditions

- Done conditions are met.
- Stop on an unexpected blocker requiring secrets, Apple account state, Vercel
  project access, schema changes, or release-scope product fixes.
- Stop after 3 consecutive verification failures on the same step.
- Stop before production DMG upload and before production update metadata
  switch unless the user has explicitly confirmed that public mutation.

## Out Of Scope

- iOS lane changes.
- Mac App Store review submission.
- Portfolio submodule bump, staging, commit, push, or source-level web content
  edits.
- Restoring the empty-state CTA hit target; v1.6 intentionally ships the
  strip-down direction approved for this release.

## Unexpected / Blockers

None.
