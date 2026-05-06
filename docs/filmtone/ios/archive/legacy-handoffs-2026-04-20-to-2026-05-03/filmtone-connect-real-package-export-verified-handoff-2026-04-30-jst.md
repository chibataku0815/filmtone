# Filmtone Connect for DaVinci - Real Package Export Verified Handoff

- Date: 2026-04-30 JST
- Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- App: `apps/capacitor-film-lab-ios`
- Life hub: `/Volumes/SamsungPortableSSDX5001/documents/life`
- Status: implementation complete, local verification complete, committed in the
  commit containing this document
- Commit message: `feat(filmtone-ios): export DaVinci Connect package`
- Core result: Filmtone iOS now emits a DaVinci Connect package contract:

```text
media.mp4
media.filmtone-ios-export-session-v1.json
combined-color.cube
reference-after.jpg
```

This document is the handoff for a new chat. It intentionally captures the
work history, assumptions, implementation boundary, verification commands,
current repo truth, known gaps, and the next prompt to use.

---

## 1. Operating Instructions for the Next Chat

Start from the current facts, not from old handoffs.

1. In `/Volumes/SamsungPortableSSDX5001/documents/life`, read `AGENTS.md`.
2. Route Filmtone iOS work through:
   - `docs/guides/film-lab-current-index.md`
   - `scripts/check-filmtone-ios-truth.sh`
3. Open this document first:
   - `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-real-package-export-verified-handoff-2026-04-30-jst.md`
4. Then inspect the active code files listed in section 7.
5. Do not begin with broad file discovery.
6. Do not refactor docs architecture before product work.
7. Product quality is the priority. Keep outer-shell work minimal.
8. Use `sequential-thinking` for real design branches, product-quality
   tradeoffs, DaVinci integration choices, and ambiguous implementation plans.

The correct product direction remains:

```text
Filmtone = DaVinci's pre-grade companion
PeekLut = closer to a DaVinci replacement
```

Core claim:

```text
Pre-grade on iPhone. Finish in DaVinci.
```

Japanese product phrase:

```text
iPhone で下地を、DaVinci で仕上げを。
```

---

## 2. Current Truth Snapshot

Run on 2026-04-30 JST immediately before the final commit containing this
document. Re-run this command in a new chat; `git log -1 --oneline` is the
source of truth for the final commit hash.

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/life
./scripts/check-filmtone-ios-truth.sh
```

Result:

```text
branch/head: main, final hash should be read with git log -1 --oneline
upstream: origin/main
commits_ahead_of_upstream: 5
commits_behind_upstream: 0
xcode_marketing_versions: 1.2
xcode_build_versions: 1
ios_deployment_targets: 17.0
public_trackName: Filmtone
public_bundleId: com.chibatakumi.film.lab.ios
public_version: 1.1
public_minimumOsVersion: 17.0
public_releaseDate: 2026-04-21T07:00:00Z
public_currentVersionReleaseDate: 2026-04-26T03:24:53Z
public_formattedPrice: 無料
public_primaryGenreName: Photo & Video
public_trackViewUrl: https://apps.apple.com/jp/app/filmtone/id6762564806?uo=4
```

Local commits not in `origin/main` after this work was committed. The top hash
in a later checkout may differ if this documentation was amended into the final
commit; trust `git log -1 --oneline`.

```text
<final-hash> feat(filmtone-ios): export DaVinci Connect package
cc01bf52 feat(filmtone-ios): teach the reuse loop via onboarding + help sheet
aa691c1a fix(filmtone-ios): restore explicit return in localExportURIs
ced4c215 feat(filmtone-ios): add LUT library and Saved Looks reuse layer (v1.3 Item 3)
9a1c43e8 feat(filmtone-ios): add DaVinci connect v0 spike
```

Interpretation:

- Public App Store version is `1.1`.
- Local iOS code is `1.2 (1)` candidate / unreleased stream.
- `main` is ahead of `origin/main`; do not describe this as a clean remote
  release state without checking again.
- This handoff and implementation are included in the final commit with message
  `feat(filmtone-ios): export DaVinci Connect package`.

---

## 3. Context and Why This Work Exists

Filmtone iOS previously had a strong local pre-grade experience but no practical
bridge into a professional finishing workflow. The competitive/product pivot was
to stop trying to become a full DaVinci alternative on iPhone.

The intended product role is:

```text
Filmtone iOS:
  fast physical pre-grade, taste shaping, capture-aware look preparation

DaVinci Resolve:
  final timeline, node graph, scopes, color management, delivery
```

DaVinci Connect is the bridge between those roles.

The DaVinci-side v0 spike already proved that Resolve can:

- read a Filmtone sidecar package,
- import the media,
- create or use a timeline,
- stage and apply a `.cube` LUT to node 1,
- write a Filmtone marker note,
- import a reference still into the Gallery.

The current work completed the missing iOS side:

```text
iOS export -> real Connect package files -> share package -> Resolve import
```

---

## 4. Product Boundary and Non-Claims

The Connect package is not a promise that DaVinci can reproduce every Filmtone
rendering effect through a LUT.

The package is split by what can be faithfully transported:

```text
Color-only transform
  -> combined-color.cube

Rendered optics / texture / temporal / depth-dependent effects
  -> baked media + reference-after.jpg + sidecar provenance
```

The `.cube` intentionally includes only color-transformable stages:

- optional input LUT,
- auto Apple Log style source transform where applicable,
- base grade,
- tone compression,
- creative or legacy LUT,
- print stage.

The `.cube` does not recreate:

- depth rendering,
- ray-angle optics,
- grain texture,
- motion blur,
- halation spread,
- diffusion/glow spatial behavior,
- any temporal or image-structure effect that cannot be represented as a 3D LUT.

The sidecar marker text preserves this explicitly as a non-claim:

```text
Non-claim: LUT does not recreate depth, ray-angle optics, grain, motion blur,
or halation spread; those are baked/reference provenance.
```

This boundary is a product-quality decision, not a conservative fallback. It
prevents Filmtone from making a false professional workflow claim.

---

## 5. Implemented Package Contract

Package files are produced next to the exported media:

```text
<exported-media>.mp4
<exported-media>.filmtone-ios-export-session-v1.json
combined-color.cube
reference-after.jpg
```

The export result now carries:

```swift
packageFileUris: [String]?
```

When companions are successfully written, `packageFileUris` is ordered:

```text
1. media output URI
2. sidecar URI
3. combined-color.cube URI
4. reference-after.jpg URI
```

This order is used by the native share path. If package companion generation
fails, the export still succeeds and falls back to the legacy media/sidecar
behavior.

Sidecar `package` block:

```json
{
  "layout": "filmtone-connect-package-v1",
  "mediaFilename": "media.mp4",
  "referenceAfterFilename": "reference-after.jpg",
  "luts": {
    "combinedColor": "combined-color.cube"
  }
}
```

The layout is package-relative. DaVinci importer resolution order is:

1. sidecar package block filenames,
2. legacy sidecar output URI basename,
3. default names:
   - `combined-color.cube`
   - `reference-after.jpg`

---

## 6. Implementation Summary

### 6.1 Swift Data Contract

File:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
```

Change:

- `Phase0ExportResultDTO` now includes `packageFileUris: [String]?`.
- Initializer was widened.

Purpose:

- Return the complete package file list from export to runtime/store/UI/share.

### 6.2 Export Session

File:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
```

Change:

- Added package companion filenames:
  - `combined-color.cube`
  - `reference-after.jpg`
- After media export, the session writes package companions:
  - `.cube` via `FilmtoneConnectCubeWriter.writeCombinedColorCube(...)`
  - reference still via `writeReferenceAfterImage(...)`
- Sidecar builder receives a `SidecarPackage`.
- Export result receives `packageFileUris`.
- Completed progress is emitted after package/sidecar work, so the returned
  result reflects the package state.

Reference still behavior:

- It is extracted from the finished output media with `AVAssetImageGenerator`.
- This matters because the reference should match the baked export, not a
  separate pre-export preview path.

Failure behavior:

- Companion generation failure logs:

```text
Filmtone Connect package companion write failed: ...
```

- The export does not fail solely because `.cube` or reference generation failed.
- In that failure case, `packageFileUris` is nil and legacy share behavior stays
  intact.

### 6.3 Sidecar Builder and Cube Writer

File:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
```

Change:

- `SidecarBuildInputs.package: SidecarPackage?`
- `FilmtoneExportSidecarV1.package: SidecarPackage?`
- New types:
  - `SidecarPackage`
  - `SidecarPackageLuts`
  - `FilmtoneConnectCubeWriter`

Cube writer behavior:

- Default 3D LUT size: `33`
- Writes:
  - `TITLE "Filmtone Combined Color"`
  - `LUT_3D_SIZE`
  - `DOMAIN_MIN 0.000000 0.000000 0.000000`
  - `DOMAIN_MAX 1.000000 1.000000 1.000000`
- Samples RGB cube coordinates and emits RGB rows.
- Supports RGB and RGBA LUT source arrays.
- Blends LUT application by intensity.
- Applies only color stages that can reasonably travel as a 3D LUT.

### 6.4 Runtime / Store / Share

Files:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorFacade.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaPlugin.swift
```

Changes:

- `shareOutput` accepts `packageFileUris`.
- If package files are present, share uses the full package file list.
- If not present, share falls back to media + sidecar.
- `localExportURIs(for:)` returns `packageFileUris` when available so cleanup /
  cache protection includes cube and reference.
- Benchmark-result rebuild preserves `packageFileUris`.

### 6.5 TypeScript / Web Contract

Files:

```text
apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx
apps/capacitor-film-lab-ios/src/native/filmtoneMedia.ts
apps/capacitor-film-lab-ios/src/native/filmtoneMedia.web.ts
packages/film-lab-core/src/native-bridge.ts
packages/film-lab-core/dist/index.d.ts
```

Changes:

- `Phase0ExportResult` has `packageFileUris?: string[]`.
- Native `shareOutput` options accept:
  - `sidecarUri?: string`
  - `packageFileUris?: string[]`
- Mobile editor passes `sidecarUri` and `packageFileUris` into share.
- `film-lab-core` dist types were rebuilt.

### 6.6 Swift Contract Tests

File:

```text
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
```

Changes:

- Added sidecar package block assertions.
- Added cube writer test:
  - size 2 cube emits 8 RGB rows,
  - rows are RGB only,
  - first identity row is black,
  - last identity row is white,
  - file write succeeds.

---

## 7. Active Files to Inspect First

When resuming in a new chat, inspect these files first. Do not start with broad
repo discovery.

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaPlugin.swift
apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx
apps/capacitor-film-lab-ios/src/native/filmtoneMedia.ts
packages/film-lab-core/src/native-bridge.ts
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
```

---

## 8. Verification Performed

### 8.1 Swift Contract

Command:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
bun run verify:swift-contract
```

Result:

```text
Phase0 contract fixtures verified
motion blur math tests passed
cube parser tests passed
CacheStore tests passed
Source color classifier + normalizer + HDR policy tests passed
Ray-angle optics tests passed
Sidecar builder tests passed
```

### 8.2 App TS Build

Command:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
bun run build
```

Result:

```text
tsc --noEmit && vite build
✓ built
```

Note:

- A parallel run failed once because `packages/film-lab-core` was being cleaned
  and rebuilt at the same time, so app TypeScript temporarily could not find
  `film-lab-core/dist/index.d.ts`.
- After `film-lab-core` build completed, app build passed on a clean single run.

### 8.3 App State Tests

Command:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
bun test src/lib/phase0-state.test.ts
```

Result:

```text
14 pass
0 fail
```

### 8.4 Core Build and Tests

Command:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/packages/film-lab-core
bun run build
bun test src/ios-phase0.test.ts
```

Result:

```text
DTS Build success
13 pass
0 fail
```

### 8.5 Capacitor Copy

Command:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
bunx cap copy ios
```

Result:

```text
copy ios succeeded
```

Important note:

- `bun run cap:sync:ios` was not used as the final verification path because
  the local system Ruby/Bundler environment attempted to use
  `/Library/Ruby/Gems/2.6.0` and hit permissions / extension issues.
- Pods were not changed. `cap copy ios` was enough to copy web assets.

### 8.6 Xcode Build

Generic Simulator build:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/capacitor-film-lab-ios
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build \
  CODE_SIGNING_ALLOWED=NO
```

Result:

```text
** BUILD SUCCEEDED **
```

Specific Simulator build:

```bash
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -destination 'platform=iOS Simulator,id=D47FDCA4-BB84-41E1-9683-319D0F059CDF' \
  -configuration Debug \
  build \
  CODE_SIGNING_ALLOWED=NO
```

Result:

```text
** BUILD SUCCEEDED **
```

### 8.7 Simulator Install and Launch

Device:

```text
iPhone 17
D47FDCA4-BB84-41E1-9683-319D0F059CDF
iOS 26.4.1
```

Commands:

```bash
APP_PATH='/Users/chibatakumi/Library/Developer/Xcode/DerivedData/App-arftmmyypcuyquajtkvftzufdlus/Build/Products/Debug-iphonesimulator/App.app'
BUNDLE_ID='com.chibatakumi.film.lab.ios'
DEVICE='D47FDCA4-BB84-41E1-9683-319D0F059CDF'

xcrun simctl install "$DEVICE" "$APP_PATH"
xcrun simctl launch --terminate-running-process "$DEVICE" "$BUNDLE_ID"
xcrun simctl io "$DEVICE" screenshot /tmp/filmtone-ios-simulator-launch.png
```

Result:

- App installed.
- App launched.
- Initial Filmtone screen displayed.
- Screenshot path:

```text
/tmp/filmtone-ios-simulator-launch.png
```

Diagnostic note:

- A `FilmtoneExportActivity` DiagnosticReports file existed, but its embedded
  `captureTime` was `2026-04-29 20:44:57 +0900`, before this verification.
- Targeted grep found no `2026-04-30 01:5x` Filmtone/App crash capture.
- Treat that report as historical residue, not a current launch crash.

### 8.8 Diff Hygiene

Command:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
git diff --check
```

Result:

```text
clean
```

---

## 9. DaVinci Resolve Real-App Verification

DaVinci Resolve version:

```text
20.3.2.9
```

Confirmed by:

```bash
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  -l lua \
  -x 'local r=Resolve(); print(r and r:GetVersionString() or "NO_RESOLVE")'
```

### 9.1 Synthetic Valid Package

A valid package was created at:

```text
/tmp/filmtone-connect-real-package-verify.yKZOai
```

Files:

```text
combined-color.cube
media.filmtone-ios-export-session-v1.json
media.mp4
reference-after.jpg
```

File checks:

```text
media.mp4: ISO Media, MP4 Base Media v1
reference-after.jpg: JPEG image data, 1280x720
combined-color.cube: ASCII text
media.filmtone-ios-export-session-v1.json: JSON data
```

This was not an iOS-exported media file. It was a synthetic package matching the
same Connect contract, used to verify the DaVinci side with real media/LUT/JPEG
files.

### 9.2 DaVinci Dry Run

Command:

```bash
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --dry-run \
  --package /tmp/filmtone-connect-real-package-verify.yKZOai
```

Result:

- sidecar found,
- media found,
- LUT found,
- reference found,
- marker note generated,
- no Resolve import attempted in dry run.

### 9.3 DaVinci Real Import

Project:

```text
Filmtone Connect Package Verify 20260430-015818
```

Command:

```bash
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /tmp/filmtone-connect-real-package-verify.yKZOai
```

Result:

```text
[Filmtone Connect] imported media: /tmp/filmtone-connect-real-package-verify.yKZOai/media.mp4
[Filmtone Connect] timeline item ready
[Filmtone Connect] applied staged LUT to node 1: Filmtone Connect/combined-color.cube
[Filmtone Connect] added Filmtone marker to timeline item
[Filmtone Connect] imported reference still into Gallery: /tmp/filmtone-connect-real-package-verify.yKZOai/reference-after.jpg
[Filmtone Connect] done. Verify node 1 LUT, marker note, and reference still visually in Resolve.
```

Staged LUT path:

```text
/Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/Filmtone Connect/combined-color.cube
```

Staged LUT was confirmed to exist and contain valid `.cube` header/rows.

### 9.4 Resolve API State Readback

Resolve API confirmed the real app state:

```text
RESOLVE_AVAILABLE=true
RESOLVE_VERSION=20.3.2.9
CURRENT_PROJECT_NAME=Filmtone Connect Package Verify 20260430-015818
CURRENT_PAGE=color
CURRENT_TIMELINE_NAME=Filmtone Connect - media
TIMELINE_FRAME_COUNT=25
VIDEO_TRACK_1_ITEM_COUNT=1
ITEM_1_NAME=media.mp4
ITEM_1_START=86400
ITEM_1_END=86424
ITEM_1_MARKER_COUNT=1
ITEM_1_MARKER_1_COLOR=Blue
ITEM_1_MARKER_1_NAME=Filmtone Connect
ROOT_CLIP_1_NAME=media.mp4
ROOT_CLIP_1_FILE_PATH=/tmp/filmtone-connect-real-package-verify.yKZOai/media.mp4
LUT_LIST_REFRESH=ok
```

Marker note contained:

```text
Package: /tmp/filmtone-connect-real-package-verify.yKZOai
Sidecar: media.filmtone-ios-export-session-v1.json
LUT: combined-color.cube -> node 1; inputLut=none; creativeLut=none
Reference: /tmp/filmtone-connect-real-package-verify.yKZOai/reference-after.jpg
Non-claim: LUT does not recreate depth, ray-angle optics, grain, motion blur, or halation spread; those are baked/reference provenance.
```

### 9.5 GUI Confirmation

Resolve window:

```text
Title: Filmtone Connect Package Verify 20260430-015818
Page: Color
Visible clip: media.mp4 / H.264 High L3.1
Visible node: 01
Visible scopes: vectorscope
```

Screenshot:

```text
/tmp/filmtone-davinci-real-window.png
```

The first attempt to capture Resolve showed Notes because Resolve was on another
screen/coordinate. After moving the Resolve window into view, the GUI screenshot
confirmed the Color page with the imported clip and node.

---

## 10. What Is Still Not Verified

The remaining important gap is:

```text
iOS UI real media selection -> actual export package -> share package -> DaVinci import
```

What has been verified:

- iOS export code compiles.
- Swift contract tests cover package sidecar and cube writer.
- App TypeScript build passes.
- Xcode Simulator build passes.
- Simulator install/launch passes.
- DaVinci import works on a valid synthetic package with the same contract.

What has not been executed end-to-end:

- A real iOS UI export with a user-selected video producing package files.
- Sharing that exact iOS-produced package.
- Importing that exact iOS-produced package into Resolve.

This is the best next product-quality verification target.

Do not misreport the current state as "real iOS export package imported into
DaVinci". The precise truthful state is:

```text
The iOS export path now generates the package contract in code and passes build
and contract verification. Resolve has imported and verified a valid synthetic
package conforming to that same contract.
```

---

## 11. Known Environmental Notes

### 11.1 `cap:sync:ios`

`bun run cap:sync:ios` is blocked by local Ruby/Bundler environment state:

- system Ruby tries to use `/Library/Ruby/Gems/2.6.0`,
- write permissions are not available,
- bundler / native gem extension state is inconsistent.

Because Pods were not changed in this work, use:

```bash
bunx cap copy ios
```

Then verify with Xcode build.

### 11.2 DaVinci Window Position

Resolve may be active and scriptable while its window is on another coordinate
space. `System Events` reported:

```text
Resolve, visible=true, frontmost=true, 1 window
Window title: Filmtone Connect Package Verify 20260430-015818
```

But screenshots may show another app until the Resolve window is moved into the
captured display area.

### 11.3 Temporary Evidence Paths

These files are evidence from this session, not source-controlled artifacts:

```text
/tmp/filmtone-ios-simulator-launch.png
/tmp/filmtone-davinci-real-window.png
/tmp/filmtone-connect-real-package-verify.yKZOai
```

They can be regenerated if needed.

---

## 12. Committed Git State

Commit:

```text
<final-hash> feat(filmtone-ios): export DaVinci Connect package
```

Committed implementation files:

```text
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorFacade.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaPlugin.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx
apps/capacitor-film-lab-ios/src/native/filmtoneMedia.ts
apps/capacitor-film-lab-ios/src/native/filmtoneMedia.web.ts
packages/film-lab-core/dist/index.d.ts
packages/film-lab-core/src/native-bridge.ts
```

Untracked docs intentionally left outside this commit:

```text
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-davinci-overall-plan-2026-04-30-jst.md
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-davinci-real-package-export-handoff-2026-04-30-jst.md
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-for-davinci-feasibility-handoff-2026-04-29-jst.md
```

Those docs pre-existed this final commit request in the working tree. They were
not staged in the real-package-export commit. This new handoff is the
commit-owned knowledge document:

```text
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-real-package-export-verified-handoff-2026-04-30-jst.md
```

Commit message used:

```text
feat(filmtone-ios): export DaVinci Connect package
```

---

## 13. Next Product Work

Highest-value next task:

```text
Run a real iOS export package through DaVinci.
```

Suggested path:

1. Use Simulator only if media picker/import can be controlled without fighting
   Photos permissions.
2. Prefer a real device if a test clip is already available and sharing/files
   behavior matters.
3. Export a short real clip from Filmtone iOS.
4. Confirm the output package contains:
   - media,
   - sidecar,
   - `combined-color.cube`,
   - `reference-after.jpg`.
5. Inspect sidecar `package` block.
6. Import that exact package with:

```bash
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --package /path/to/actual-ios-package
```

7. Confirm Resolve:
   - imports media,
   - applies node 1 LUT,
   - writes marker note,
   - imports reference still,
   - opens on the expected project/timeline.

Only after that should UI polish, zip packaging, multi-LUT split, PowerGrade,
DRX, DCTL, or OpenFX be considered.

---

## 14. Avoid These Mistakes

- Do not claim `.cube` recreates all Filmtone effects.
- Do not start with UI polish or zip packaging.
- Do not stage unrelated untracked docs unless intentionally requested.
- Do not use old "Waiting for Review" / App Store handoff state without running
  the truth script.
- Do not rerun `cap:sync:ios` unless the Ruby/Bundler environment is fixed or
  Pods actually changed.
- Do not treat a synthetic DaVinci package import as proof that an actual
  iOS-exported package has been imported.
- Do not broaden into desktop Filmtone release state unless the user asks.

---

## 15. Highest-Precision Handoff Prompt for a New Chat

Use this prompt verbatim in a new chat:

```text
We are working in:

/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

This is Filmtone iOS / DaVinci Connect work. First read:

/Volumes/SamsungPortableSSDX5001/documents/life/AGENTS.md
/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/film-lab-current-index.md
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-connect-real-package-export-verified-handoff-2026-04-30-jst.md

Then run:

cd /Volumes/SamsungPortableSSDX5001/documents/life
./scripts/check-filmtone-ios-truth.sh

Important constraints:

- Prioritize core product progress over outer-shell work.
- Product quality beats conservative generic advice.
- Use sequential-thinking for real design branches, DaVinci integration choices,
  product-quality tradeoffs, or ambiguous plans.
- If material facts are unknown, investigate locally first, then use web search
  if needed, and ask only if implementation depends on an undiscoverable answer.
- When multiple reads/checks are independent, run them in parallel.
- Do not begin with broad repo discovery.
- Do not revert user or unrelated changes.

Current implemented state:

Filmtone iOS export now generates a DaVinci Connect package contract:

1. media output
2. sidecar JSON
3. combined-color.cube
4. reference-after.jpg

The sidecar includes:

package: {
  layout: "filmtone-connect-package-v1",
  mediaFilename: "...",
  referenceAfterFilename: "reference-after.jpg",
  luts: { combinedColor: "combined-color.cube" }
}

Key implementation files:

apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift
apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaPlugin.swift
apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx
apps/capacitor-film-lab-ios/src/native/filmtoneMedia.ts
packages/film-lab-core/src/native-bridge.ts
apps/capacitor-film-lab-ios/scripts/swift/test-sidecar-builder.swift
apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua

Verification already completed:

- bun run verify:swift-contract passed
- apps/capacitor-film-lab-ios bun run build passed
- bun test src/lib/phase0-state.test.ts passed
- packages/film-lab-core bun run build passed
- bun test src/ios-phase0.test.ts passed
- bunx cap copy ios passed
- xcodebuild Simulator Debug build passed
- iPhone 17 Simulator install/launch passed
- DaVinci Resolve 20.3.2.9 dry-run and real import passed with a valid synthetic package
- Resolve API confirmed project, timeline, clip, marker note, and staged LUT
- Resolve GUI screenshot confirmed Color page with imported clip/node/scopes

Critical truth boundary:

The DaVinci real-app import was done with a valid synthetic package conforming
to the Filmtone Connect contract. It was not yet an actual package exported
from the iOS UI with a real user-selected clip.

Next highest-value task:

Run one actual iOS-produced package end-to-end:

iOS UI real clip export -> package files -> share/files extraction -> DaVinci
fuscript import -> verify node 1 LUT, marker note, reference still, and timeline.

Do not start with zip packaging, UI polish, multi-LUT split, PowerGrade, DRX,
DCTL, OpenFX, docs architecture, ASO, or broad audits. Those are outer shell
until the actual iOS-produced package has gone through Resolve.
```
