# M6 Public Replacement Cutover Attempt And Rollback

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`
HEAD after rollback truth: `60809f84`

## Goal

Run the actual public replacement cutover from legacy Electron Desktop `1.0.4`
to Native Desktop v2 `1.4`, using the fixed Desktop download/update rail. This
attempt was rolled back after the user clarified the desired sequence: correct
the parent branch, merge `main`, then release.

## User Direction

The user said: "では実際の置き換えに進みましょう".

During this attempt, the previously identified product parity gaps were treated
as user-approved deferrals rather than blockers:

- Source Auto / Conversion LUT parity.
- Backlight Veil parity.
- Advanced recipe chip discoverability (`None` / `Default` / `Strong`;
  Japanese `なし` / `標準` / `強め`).

After rollback, these remain pre-release risks or explicit-defer candidates.

## Result

- Built `Filmtone.app` Release with Developer ID signing.
- Notarized and stapled `Filmtone.app`; `spctl` accepted it as
  `Notarized Developer ID`.
- Packaged `Filmtone-1.4.dmg`.
- Signed, notarized, and stapled `Filmtone-1.4.dmg`; `spctl --type open`
  accepted it as `Notarized Developer ID`.
- Uploaded the DMG to Vercel Blob:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.4.dmg`.
- Synced `FILM_LAB_DESKTOP_DOWNLOAD_URL` to the production Vercel project.
- Redeployed the existing production Vercel deployment remotely, without using
  the dirty local portfolio worktree.
- Verified the public download complete page references `Filmtone-1.4.dmg`.
- Uploaded `film-lab/desktop/update-meta.json` with `latestVersion: "1.4"` as
  the final public switch.
- Synced `FILM_LAB_DESKTOP_UPDATE_CHECK_URL` to the production Vercel project.
- Release truth temporarily reported public Desktop latest `1.4`.
- Rollback restored update metadata to `latestVersion: "1.0.4"`.
- Rollback restored the production download env to the legacy Desktop DMG and
  redeployed the current production Vercel deployment.
- Release truth now again reports public Desktop latest `1.0.4`.

## Artifact

```text
apps/filmtone-desktop-macos/build/release/1.4/Filmtone.app
apps/filmtone-desktop-macos/build/release/1.4/Filmtone-1.4.dmg
```

DMG sha256:

```text
a891ccfdba470cd68e39273130485e92d21a89f4f7879a0650baca57abff3e68  Filmtone-1.4.dmg
```

Public update metadata during the attempted cutover:

```json
{
  "schemaVersion": 1,
  "latestVersion": "1.4",
  "downloadPageUrl": "https://www.chibatakumi.studio/film-lab/download"
}
```

Public update metadata after rollback:

```json
{
  "schemaVersion": 1,
  "latestVersion": "1.0.4",
  "downloadPageUrl": "https://www.chibatakumi.studio/film-lab/download"
}
```

## Verification

- `bun run release:cutover-preflight` passed before artifact generation.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed: `86/86`.
- `bun run verify:macos` passed: `** BUILD SUCCEEDED **`.
- `git diff --check` passed before release generation.
- `scripts/release-macos.sh` passed all 6 steps.
- `scripts/package-dmg.sh` passed all 6 steps.
- Post-DMG `bun run release:cutover-preflight` passed before upload.
- Public DMG `HEAD` returned `200`, `content-disposition:
  attachment; filename="Filmtone-1.4.dmg"`, and `content-length: 9071817`.
- Public download complete page contains `Filmtone-1.4.dmg`.
- Release truth script reported `public_latestVersion: 1.4` during the attempt.
- After rollback, release truth script reports `public_latestVersion: 1.0.4`.

## Notes

- The local portfolio worktree was dirty and behind origin. It was not used for
  deployment. Vercel `redeploy` rebuilt the existing production deployment
  remotely after the download URL env sync.
- No git staging, commit, push, tag, stash cleanup, or Electron workspace
  deletion was performed.

## Remaining Product Risks Before Clean Release

- Source Auto / Conversion LUT parity.
- Backlight Veil parity.
- Advanced recipe chip discoverability.

## Out Of Scope

- Implementing the deferred parity gaps.
- Archiving or deleting `apps/desktop-film-lab-batch/`.
- Pushing, tagging, staging, or committing.
- Adding Sparkle/background auto-update.

## Unexpected Blockers

- None.
