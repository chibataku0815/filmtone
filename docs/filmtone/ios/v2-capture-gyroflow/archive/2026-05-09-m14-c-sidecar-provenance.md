# Archived: M14-C — Sidecar Provenance for Master / Proxy Decision

Status: **PASS** — owner accepted 2026-05-09 ("OK"). **M14 milestone
closed** — all six Done conditions met across M14-A (decision logic
+ decision-aware toasts) + M14-B (security-scoped bookmark for SSD
persistence) + M14-C (sidecar `captureProvenance` block).

Date: 2026-05-09 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Original status: installed on iPhone 17 Pro #7, ready for owner smoke verify — autonomous execution complete 2026-05-09 03:47 JST

## Why this active exists

M14-A landed the master/proxy decision logic in
`FilmtoneEditorStore.export()` and surfaced it via decision-aware
toasts. M14-B made SSD-stored masters reachable across capture-view
dismiss + app relaunch via per-package security-scoped bookmarks. The
remaining piece of the M14 done conditions per `strategy.md` is:

> sidecar / export metadata に master/proxy provenance を残す。

Today the export sidecar (`filmtone-ios-export-session-v1`) records
which Saved Look / Camera Profile / depth path was used, but NOT
whether the export sourced from the capture-package master or the
proxy. That field is the difference between "DaVinci can trust this
came from ProRes 422 HQ Apple Log 2 4K master" vs. "this is the H.264
proxy export — treat as derivative". M14-C closes that gap.

## Decision shape

New optional sidecar block:

```json
"captureProvenance": {
  "mode": "master",
  "masterUriUsed": "file:///.../<captureId>/master.mov"
}
```

```json
"captureProvenance": {
  "mode": "proxy",
  "reason": "masterFileMissing",
  "masterUriUsed": "file:///.../<captureId>/master.mov",
  "proxyUriUsed": "file:///.../<captureId>/proxy.mov"
}
```

For Photos / Files non-capture-package edits the block is omitted
entirely (V1 contract: additive optional fields, omit when nil).

Field semantics:
- `mode: "master" | "proxy"` — which file the export pipeline read.
- `reason: String?` — present only on `mode == "proxy"`. Values:
  `"masterFileMissing"` (M14-A `.usingProxyMasterMissing`),
  `"masterProbeFailed:<NSError-localized>"` (M14-A
  `.usingProxyMasterUnreadable(reason)`).
- `masterUriUsed: String?` — the master file URI in absolute form.
  Present whenever a capture package was in play (master mode + both
  proxy fallback modes), so DaVinci importers can see which master
  was *intended* even when a fallback happened.
- `proxyUriUsed: String?` — present only on `mode == "proxy"` to
  identify the actual proxy file the export read.

## Plumbing path

`ExportSourceDecision` originates in `FilmtoneEditorStore.export()` /
`exportAndSave()` (added in M14-A). It needs to thread through:

```
FilmtoneEditorStore.export()
  → FilmtoneEditorFacade.runExport(captureProvenance: ...)
    → FilmtoneMediaRuntime.runExport(captureProvenance: ...)
      → FilmtoneMediaRuntime.makeExportSession(captureProvenance: ...)
        → FilmtoneExportSession.init(captureProvenance: ...)
          → FilmtoneExportSession.writeExportSidecar()
            → SidecarBuildInputs(captureProvenance: ...)
              → FilmtoneExportSidecarV1.captureProvenance
```

This mirrors the existing pattern for `appliedSavedLook` /
`cameraProfile` (iOS-side state, not part of the JS-bridge
`Phase0ExportRequestDTO`). New parameter is optional with `nil`
default so all existing call sites compile unchanged.

## Scope

### A. `FilmtoneExportSidecarBuilder.swift`

- New `struct SidecarCaptureProvenance: Encodable` with the four
  fields above (omit-on-nil for `reason` / `masterUriUsed` /
  `proxyUriUsed`).
- New optional field on `FilmtoneExportSidecarV1`:
  `let captureProvenance: SidecarCaptureProvenance?`.
- New optional field on `SidecarBuildInputs`:
  `let captureProvenance: SidecarCaptureProvenance?`.
- `makePayload(_:)` copies the field through.

### B. Plumbing parameters

- `FilmtoneEditorFacade.runExport(captureProvenance:)` — new optional
  parameter, default nil. Forwarded to runtime.
- `FilmtoneMediaRuntime.runExport(captureProvenance:)` — new optional
  parameter, default nil. Forwarded to `makeExportSession`.
- `FilmtoneMediaRuntime.makeExportSession(captureProvenance:)` — new
  optional parameter, default nil. Forwarded to session init.
- `FilmtoneExportSession.init(captureProvenance:)` — new optional
  parameter, default nil. Stored as `private let
  captureProvenance: SidecarCaptureProvenance?`.
- `FilmtoneExportSession.writeExportSidecar` populates the field on
  `SidecarBuildInputs`.

### C. Mapping in `FilmtoneEditorStore.swift`

New private helper `sidecarProvenance(from decision: ExportSourceDecision,
package: FilmtoneCapturePackage?) -> SidecarCaptureProvenance?`. Maps:
- `.noCapturePackage` → `nil`
- `.usingMaster` → `mode="master"`, `masterUriUsed=package.masterURL.absoluteString`
- `.usingProxyMasterMissing` → `mode="proxy"`, `reason="masterFileMissing"`,
  `masterUriUsed=intended`, `proxyUriUsed=package.proxyURL.absoluteString`
- `.usingProxyMasterUnreadable(let r)` → `mode="proxy"`,
  `reason="masterProbeFailed:\(r)"`, both URIs.

`export()` and `exportAndSave()` call sites pass the mapped block
through `facade.runExport(captureProvenance: ...)`.

### Files

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorFacade.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`

No new files → no `project.pbxproj` 4-section gate needed.

## Out of Scope

- Highlight reel exports (`runHighlightReel` path) — separate sidecar
  call site, M14-C preserves existing behavior; revisit in a later
  lane if needed.
- Any change to the sidecar V1 schema version — additive optional
  fields are V1-compatible per the existing contract (CLAUDE.md §5
  in this repo).
- DaVinci-side importer changes to consume the new block.
- `Phase0ExportRequestDTO` shape — captureProvenance stays iOS-side
  state, not on the JS bridge.

## Verification

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/.claude/worktrees/feature+ios-m9-recording-export-completion

xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS' \
  -configuration Debug -derivedDataPath /tmp/filmtone-m14c-dd build
xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  /tmp/filmtone-m14c-dd/Build/Products/Debug-iphoneos/App.app
xcrun devicectl device process launch --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 \
  com.chibatakumi.film.lab.ios
```

## Owner walk (acceptance gate)

Smoke verify on iPhone 17 Pro #7:

1. **Internal-Documents capture** — record without SSD, edit + export,
   inspect sidecar JSON. Expect
   `"captureProvenance": { "mode": "master", "masterUriUsed": "..." }`.
2. **SSD-mounted capture** — record to SSD, edit + export. Expect
   same `mode: "master"` block (M14-B made this reachable).
3. **SSD unmounted fallback** — record to SSD, unmount, export. Expect
   `"mode": "proxy"`, `"reason": "masterFileMissing"`, both URIs.
4. **Photos / Files edit** — open a Photos source + export. Expect
   `captureProvenance` field absent from the sidecar JSON.

If any FAIL: iterate before commit.

## Stop Conditions

- Any edit to capture session / writer / package / Capacitor.
- Two simulator build failures from the same root cause.
- Sidecar contract test breakage (the field is additive, but breaking
  byte-identity for legacy fixtures is a regression).

## Execution log (autonomous run 2026-05-09)

- 03:35-03:47 JST executed continuously per active scope.
- `FilmtoneExportSidecarBuilder.swift`: new
  `SidecarCaptureProvenance` Encodable struct with
  `mode / reason / masterUriUsed / proxyUriUsed`. Added optional
  `captureProvenance` field on `FilmtoneExportSidecarV1` and
  `SidecarBuildInputs`. `makePayload` propagates the field.
  `encodeIfPresent` for the optional fields keeps sidecar JSON tight.
- `FilmtoneEditorFacade.swift`,
  `FilmtoneMediaRuntime.swift` (`runExport` + `makeExportSession`),
  `FilmtoneExportSession.swift` (init + property + writeExportSidecar
  call site): new optional `captureProvenance` parameter / property
  threaded through, default nil so legacy call sites compile.
- `FilmtoneEditorStore.swift`: new
  `sidecarCaptureProvenance(from:package:)` mapping helper from M14-A
  `ExportSourceDecision` to the new sidecar struct. `export()` and
  `exportAndSave()` capture `lastCapturePackage` at trigger time and
  pass through `facade.runExport(captureProvenance:)`.
- Sim build: PASS.
- Device build: PASS (signed).
- Install + launch: PASS — running on iPhone 17 Pro #7.
- No new files → no pbxproj 4-section gate needed.

## Owner smoke verify pending — four reads

(See "Owner walk (acceptance gate)" above.) Internal-Documents
master / SSD-mounted master / SSD-unmounted fallback / Photos-Files
parity. Sidecar JSON should expose `captureProvenance` with the
expected `mode` + `reason` per case (or omit entirely for non-capture
sources).

If all 4 PASS: archive this active.md →
`2026-05-09-m14-c-sidecar-provenance.md`, append 1-3 line strategy.md
Completion Log entry + close **M14 milestone** as PASS, commit.

If any FAIL: iterate before commit.

## Outcome

(Filled at archive time after smoke verify.)
