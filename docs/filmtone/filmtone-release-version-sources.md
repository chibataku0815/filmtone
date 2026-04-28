# Filmtone Release Version Sources

This file exists to prevent release-version drift between `life` planning docs and the actual Desktop release rail.

## Rule

Do not infer Filmtone Desktop's latest or next version from historical `life` handoffs, old marketing docs, or the web release notes page alone.

Use these sources, in order:

1. Public update metadata: `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json`
2. Git tags in this repo: `desktop-v*`
3. Desktop package version: `apps/desktop-film-lab-batch/package.json`
4. Desktop release notes: `apps/desktop-film-lab-batch/RELEASE_NOTES-v<version>.md`
5. Candidate QA handoff docs: `docs/filmtone/desktop/filmtone-desktop-v*-qa-handoff-*.md`

If these sources disagree, report the disagreement explicitly before planning.

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
