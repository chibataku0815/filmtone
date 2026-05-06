# Filmtone Desktop Release Next Chat Handoff

Date: 2026-05-02 JST  
Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`  
Purpose: next chat will run Desktop release work from the current Filmtone
standalone repo state.

## 1. Current Truth

Run these again at the start of the next chat before stating any release
version or release status:

```bash
FILMTONE_REPO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone \
  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh

FILMTONE_REPO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone \
  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

Truth script output at this handoff:

- Desktop repo head: `main @ df0ffaf`
- Desktop package version: `1.0.3`
- Desktop latest tag: `desktop-v1.0.3`
- Desktop public `update-meta.json` latestVersion: `1.0.3`
- Desktop release notes for package version: `apps/desktop-film-lab-batch/RELEASE_NOTES-v1.0.3.md`
- Desktop commits after latest tag: `149`
- Public update meta URL:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json`
- Latest candidate doc:
  `docs/filmtone/desktop/filmtone-desktop-v1.0.3-qa-handoff-2026-04-24-jst.md`
- iOS local candidate is a separate axis:
  - Local Xcode MARKETING_VERSION: `1.4`
  - Local Xcode build: `3`
  - Public App Store version: `1.3`
  - Local branch is ahead of `origin/main` by 5 commits

Do not infer the next Desktop release number from old handoffs. Inspect
`docs/filmtone/filmtone-release-version-sources.md`, the truth script output,
and current release notes before choosing a version bump.

## 2. Git State And Branches

At handoff time:

```text
main...origin/main [ahead 5]
HEAD: df0ffaf feat(filmtone): add source profile core desktop parity
```

Local commits not on `origin/main`:

```text
df0ffaf feat(filmtone): add source profile core desktop parity
7a2e1d1 feat(ios): add DJI D-Log M source profile (#9) + bundle v1.4 mezzanine in-flight
739d94b feat(ios): add Canon Log 3 + Cinema Gamut source profile
fd1f512 feat(desktop): add built-in Camera Profile catalog parity with iOS
0fc5141 feat(ios): add D-Log and C-Log source profiles
```

Untracked files in the main checkout were intentionally left untouched:

```text
?? .claude/worktrees/
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/2026-05-02-filmtone-ios-information-design-spec-jst.md
?? docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/quality-mezzanine-cache-failure-next-chat-handoff-2026-05-02-jst.md
```

The source-profile core/Desktop parity work was implemented in this clean
worktree and then fast-forward merged into `main`:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-ios-source-profile-core-parity
branch: feature/ios-source-profile-core-parity
commit: df0ffaf
```

That worktree is clean and still exists. The next chat may keep it or remove it
after confirming it is no longer useful. Do not delete it reflexively during the
release work if it is still being used as a reference.

## 3. What Was Completed In This Chat

The completed goal was Source Profile Core/Desktop parity: iOS already had
manual source profiles for DJI D-Log M and Canon Log 3 / Cinema Gamut, while
shared core and Desktop were still behind. This chat brought shared core,
Desktop UI, Desktop sidecar parsing, and Desktop metadata runtime to the same
catalog.

Commit:

```text
df0ffaf feat(filmtone): add source profile core desktop parity
```

Key changes:

- `packages/film-lab-core/src/source-profile-conversion.ts`
  - Added `SourceProfileCurve` values:
    - `dji-dlog-m`
    - `canon-log3-cinema-gamut`
  - Added `SourceProfileId` values:
    - `built-in:source-profile.dji-dlog-m`
    - `built-in:source-profile.canon-log3-cinema-gamut`
  - Expanded `SOURCE_PROFILE_CATALOG` to 9 entries:
    - Rec.709
    - Apple Log
    - Apple Log 2
    - DJI D-Log
    - DJI D-Log M
    - Canon C-Log
    - Canon Log 3 / Cinema Gamut
    - V-Log
    - S-Log3
  - Ported TS math from Swift SSOT:
    - `dlogMDecode`
    - `dlogMPixelToRec709`
    - `makeDlogMToRec709Cube`
    - `canonLog3Decode`
    - `canonLog3CineGamutPixelToRec709`
    - `makeCanonLog3CineGamutToRec709Cube`
- `packages/film-lab-core/src/source-profile-conversion.test.ts`
  - Added catalog assertions for the 9-entry v1.4 catalog.
  - Added iOS fixture parity tests for:
    - `Tests/Fixtures/source-profile/dji-dlog-m`
    - `Tests/Fixtures/source-profile/canon-log3-cinema-gamut`
- `packages/film-lab-core/dist/index.js`
- `packages/film-lab-core/dist/index.d.ts`
  - Rebuilt by `bun run build:core`.
- `packages/film-lab-ui/src/LUTPanel.tsx`
  - Added Desktop Log Conversion chips for:
    - DJI D-Log M
    - Canon Log 3 / Cinema Gamut
- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts`
  - Sidecar schema now accepts the two new source-profile curves.
- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts`
  - Added Desktop sidecar round-trip coverage for both new profiles.
- `apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.test.ts`
  - Added import/runtime coverage proving both new built-in ids regenerate
    `lut1` without reading any `.cube` path.
- `apps/capacitor-film-lab-ios/src/presets/signature.ts`
- `apps/capacitor-film-lab-ios/src/presets/luts/README.md`
  - Refreshed stale source-profile copy so it no longer claims the old smaller
    synthesized set.

## 4. Verification Already Run

All of the following passed after the parity commit:

```bash
bun test packages/film-lab-core/src/source-profile-conversion.test.ts
bun run build:core
bun test apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts
bun test apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.test.ts
bun run typecheck:shared
bun run verify:desktop
bun run verify:ios
bun run check:filmtone-copy
git diff --check
```

Important verification details:

- Core fixture parity passed for D-Log, D-Log M, C-Log, Canon Log 3 + Cinema
  Gamut, V-Log, and S-Log3.
- `verify:ios` source-profile math gate printed `0.000` drift for D-Log M and
  C-Log 3 + Cinema Gamut.
- `verify:desktop` passed.
- `verify:ios` passed with only the existing Vite large chunk warning.
- No files were staged, committed, or pushed except the parity commit above.

## 5. Product State Now Relevant To Desktop Release

Desktop Log Conversion now has built-in Camera/Profile parity for the current
iOS catalog. Users should no longer need to import their own `.cube` for these
profiles in the Desktop Log Conversion lane:

- Rec.709 / none
- Apple Log
- Apple Log 2
- DJI D-Log
- DJI D-Log M
- Canon C-Log
- Canon Log 3 / Cinema Gamut
- Panasonic V-Log
- Sony S-Log3
- Custom `.cube`

Important behavioral expectations for release QA:

- Built-in profile selection should update preview by generating shared-core
  LUT data and applying it to `lut1`.
- Export should use the same `lut1` data as preview.
- Custom `.cube` remains supported.
- Built-in profile metadata should round-trip through
  `input.sourceProfile` in Desktop sidecars.
- Importing a Desktop sidecar with a built-in profile should regenerate `lut1`
  from `catalogId`, not require an absolute `.cube` path.
- Source profile id/curve/display name are metadata, not `Params`.

## 6. Release Work To Do In The Next Chat

Start with the repo rules and truth gates:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
sed -n '1,260p' AGENTS.md
git status --short --branch
FILMTONE_REPO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone \
  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
FILMTONE_REPO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone \
  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

Then use a branch or worktree for release edits. Do not do release edits
directly on dirty `main` unless the user explicitly chooses that.

Suggested branch name:

```bash
git switch -c feature/desktop-release
```

or create a release worktree if the original checkout should stay untouched.

Release preparation checklist:

1. Reconfirm Desktop public latest and package version with truth scripts.
2. Inspect `docs/filmtone/filmtone-release-version-sources.md`.
3. Inspect `apps/desktop-film-lab-batch/README.md` release command section.
4. Decide the next Desktop version only after the above checks.
5. If releasing a new Desktop version:
   - bump `apps/desktop-film-lab-batch/package.json` version
   - create/update `apps/desktop-film-lab-batch/RELEASE_NOTES-v<version>.md`
   - include source-profile parity in release notes
   - include any other release-scope commits after `desktop-v1.0.3`
6. Run release verification before packaging:
   - `bun run verify:desktop`
   - `bun run typecheck:shared`
   - targeted source-profile tests if touched:
     `bun test packages/film-lab-core/src/source-profile-conversion.test.ts`
   - `bun run check:filmtone-copy` if release notes/copy changed
   - `git diff --check`
7. For local package shape check, use unsigned packaging first if needed:
   - `cd apps/desktop-film-lab-batch`
   - `bun run dist:mac`
8. For production release, follow the Desktop README:
   - `bun run dist:mac:release`
   - `bun run release:staple`
   - `bun run release:checksums`
   - `bun run release:upload-blob -- --sync-vercel-env`
   - `bun run release:upload-update-meta -- --sync-vercel-env`
9. Do not commit secrets, signing material, Apple credentials, Blob tokens, or
   local `.env` files.
10. Do not push or tag unless the user explicitly asks for those release actions.

Release command facts from `apps/desktop-film-lab-batch/README.md`:

- `package.json` version is the source of truth for the DMG filename and
  update notification `latestVersion`.
- Official public artifact is signed + notarized macOS arm64 DMG.
- Fixed download URL is `https://www.chibatakumi.studio/film-lab/download`.
- Minimum macOS is `11.0+`.
- Public update is a manual DMG replacement, with in-app notification only.
- `BLOB_READ_WRITE_TOKEN` is required for Blob upload.
- Notarization uses Apple credentials resolved by `scripts/notarize.mjs`; do
  not print or commit those values.

## 7. Known Risks And Things Not To Confuse

- Desktop public latest is currently `1.0.3`; local code has 149 commits after
  `desktop-v1.0.3`. The next release likely needs a new version, but do not
  choose it without checking release version sources.
- `main` is ahead of `origin/main` by 5 commits. Decide whether to push these
  before or as part of the Desktop release lane.
- iOS public state and local iOS candidate state are separate. Do not describe
  local iOS `1.4` as public.
- The current task is Desktop release. Do not edit portfolio
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
  unless explicitly requested.
- The original untracked iOS docs are outside the Desktop release scope. Leave
  them alone unless the user asks to include them.
- The source-profile math SSOT for TS parity is the Swift implementation plus
  committed iOS fixtures. Do not refit D-Log M or Canon Log 3 during release
  unless a test exposes drift.
- `bun install` can regenerate unrelated tracked dist outputs because of
  postinstall. If that happens, review and keep only release-scope changes.

## 8. Highest-Precision Next Chat Prompt

Copy this prompt into the next chat:

```text
You are working in:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

Task: run Filmtone Desktop release preparation from the current main state.

First, read AGENTS.md, run git status --short --branch, and run both truth scripts:

FILMTONE_REPO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone \
  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh

FILMTONE_REPO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone \
  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh

Then read this handoff:
docs/filmtone/desktop/archive/legacy-handoffs-2026-04-25-to-2026-05-03/filmtone-desktop-release-next-chat-handoff-2026-05-02-jst.md

Release constraints:
- Use bun only.
- Product quality first; keep outer-shell/doc work minimal until release behavior is good.
- Use a branch or worktree before edits.
- Do not touch portfolio unless explicitly asked.
- Do not stage/commit/push/tag/upload unless I ask.
- Do not commit secrets, signing material, Apple credentials, Blob tokens, or local .env files.
- Do not infer Desktop version from memory. Trust the truth scripts and docs/filmtone/filmtone-release-version-sources.md.

Current important state from the previous chat:
- main HEAD was df0ffaf: feat(filmtone): add source profile core desktop parity.
- main was ahead of origin/main by 5 commits.
- Desktop public latest was 1.0.3; package version was 1.0.3; latest tag was desktop-v1.0.3.
- Source Profile Core/Desktop parity is implemented and verified:
  DJI D-Log M and Canon Log 3 / Cinema Gamut are now in shared core, Desktop Log Conversion chips, Desktop sidecar schema, and Desktop metadata runtime.
- Verification already passed:
  bun test packages/film-lab-core/src/source-profile-conversion.test.ts
  bun run build:core
  bun test apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts
  bun test apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.test.ts
  bun run typecheck:shared
  bun run verify:desktop
  bun run verify:ios
  bun run check:filmtone-copy
  git diff --check

Your goal:
1. Determine the correct Desktop release version and release scope from live truth.
2. Update Desktop release metadata/release notes/package version if needed.
3. Run the smallest verification that proves the release surface.
4. Prepare the signed/notarized Desktop release command sequence, and execute only the steps I explicitly authorize.
5. Keep a concise final report with exact commands run, pass/fail, changed files, and any release blockers.
```
