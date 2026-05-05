# M6 Clean Public Release After Main Merge

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`
Release HEAD: `4f2e5eba`

## Milestone

M6 Release Cutover

## Goal

Release Native Desktop v2 `1.4` from the corrected parent branch after merging
`origin/main`.

## Edit Targets

- `docs/filmtone/desktop/native-desktop-v2/active.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-05-m6-clean-public-release-after-main-merge.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/release-cutover/README.md`
- `docs/filmtone/desktop/release-cutover/cutover-architecture.md`
- `docs/filmtone/desktop/release-cutover/2026-05-05-native-v2-replacement-readiness.md`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.4.md`

## Read-Only References

- `scripts/release-cutover-preflight.mjs`
- `scripts/release-macos.sh`
- `scripts/package-dmg.sh`
- public update metadata
- release truth scripts

## Checklist

- [x] Run preflight and product verification after `main` merge.
- [x] Rebuild/sign/notarize/staple `Filmtone.app` from HEAD `4f2e5eba`.
- [x] Repackage/sign/notarize/staple `Filmtone-1.4.dmg`.
- [x] Upload the regenerated DMG to Vercel Blob and sync download env.
- [x] Redeploy production web so fixed download page points at the regenerated
      DMG.
- [x] Verify fixed download page and DMG URL.
- [x] Upload update metadata as the final public switch.
- [x] Verify release truth reports public Desktop `1.4`.
- [x] Archive this active and update release docs.

## Verification

- `bun run release:cutover-preflight` passed before the public switch while
  public update metadata still reported `1.0.4`.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed (`99/99`).
- `bun run verify:macos` passed (`** BUILD SUCCEEDED **`).
- `git diff --check` passed.
- `scripts/release-macos.sh` passed all 6 steps for release HEAD `4f2e5eba`;
  `Filmtone.app` was notarized, stapled, and Gatekeeper accepted as
  `Notarized Developer ID`.
- `scripts/package-dmg.sh` passed all 6 steps; `Filmtone-1.4.dmg` was
  notarized, stapled, and Gatekeeper accepted for open assessment.
- DMG sha256:
  `40d2b2fd745c648849d310856e2bcd5d0db0afd948b3842fd83800f68e705cb8`.
- Public DMG HEAD returned `content-length: 9219296` and
  `filename="Filmtone-1.4.dmg"`.
- Production Vercel redeploy:
  `chibatakumi-portfolio-1bttmm5np-forestones-projects.vercel.app`, aliased to
  `https://www.chibatakumi.studio`.
- Public update metadata now reports `latestVersion: "1.4"`.
- Release truth script reports public Desktop latest `1.4`.

## Done Conditions

- Public update metadata reports `latestVersion: "1.4"`.
- Fixed download page references `Filmtone-1.4.dmg`.
- Regenerated DMG checksum is recorded.
- No `active.md` remains open.

## Stop Conditions

- Done met.
- Unexpected blocker.
- 3 consecutive verification failures.

## Out Of Scope

- Pushing.
- Tagging.
- Cleaning unrelated untracked handoff/evidence files.
- Portfolio local worktree cleanup.

## Unexpected Blockers

- None.
