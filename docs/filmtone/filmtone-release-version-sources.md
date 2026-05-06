# Filmtone Release Version Sources

This file exists to prevent release-version drift between `life` planning docs and the actual Desktop release rail.

## Rule

Do not infer Filmtone Desktop's latest or next version from historical `life` handoffs, old marketing docs, or the web release notes page alone.

Use these sources, in order:

1. Public update metadata: `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json`
2. Native Desktop marketing version:
   `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
   (`MARKETING_VERSION`)
3. Git tags in this repo: `desktop-v*`
4. Native Desktop release notes:
   `apps/filmtone-desktop-macos/RELEASE_NOTES-v<version>.md`
5. Release cutover docs: `docs/filmtone/desktop/release-cutover/`
6. Legacy Electron package version, only when discussing the frozen legacy rail:
   `apps/desktop-film-lab-batch/package.json`

If these sources disagree, report the disagreement explicitly before planning.

After the Native Desktop v1.4 replacement cutover, the Electron package version
is not the Desktop public release version source. The Electron workspace remains
in the repo for compatibility, reference, and frozen legacy support; Native
Desktop release versioning is read from the macOS Xcode project.

## Quick Check

From `life`, run:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
```

From this repo, run the same script with the repo root if needed:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh "$(pwd)"
```

## Why This Exists

The `life` repo intentionally keeps long-lived planning and handoff history. That history includes v0.x Filmtone release documents. Those documents are still useful context, but they are not the current release-version authority.
